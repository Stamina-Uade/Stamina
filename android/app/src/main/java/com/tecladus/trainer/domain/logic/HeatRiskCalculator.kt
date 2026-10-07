package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.RiskLevel
import com.tecladus.trainer.domain.model.SafetyAssessment
import com.tecladus.trainer.domain.model.WeatherSnapshot
import kotlin.math.roundToInt

/**
 * Evalúa si conviene salir a entrenar.
 *
 * El calor no se juzga por la temperatura sino por el **índice de calor** (fórmula de
 * Rothfusz del servicio meteorológico de EE.UU.), que combina temperatura y humedad:
 * con 32 °C y 70% de humedad la sensación es de 41 °C y el cuerpo ya no disipa calor
 * por evaporación. Ahí es donde aparecen el golpe de calor y los calambres.
 *
 * También se contemplan frío extremo, viento fuerte, tormenta y radiación UV alta.
 */
object HeatRiskCalculator {

    /** Índice de calor en °C a partir de temperatura (°C) y humedad relativa (%). */
    fun heatIndexC(tempC: Double, humidityPct: Double): Double {
        val t = tempC * 9.0 / 5.0 + 32.0
        if (t < 80.0) return tempC
        val r = humidityPct
        var hi = -42.379 + 2.04901523 * t + 10.14333127 * r -
            0.22475541 * t * r - 0.00683783 * t * t - 0.05481717 * r * r +
            0.00122874 * t * t * r + 0.00085282 * t * r * r - 0.00000199 * t * t * r * r
        // Ajustes de la fórmula original en los extremos de humedad.
        if (r < 13 && t in 80.0..112.0) {
            hi -= ((13 - r) / 4.0) * kotlin.math.sqrt((17 - kotlin.math.abs(t - 95.0)) / 17.0)
        } else if (r > 85 && t in 80.0..87.0) {
            hi += ((r - 85) / 10.0) * ((87 - t) / 5.0)
        }
        return (hi - 32.0) * 5.0 / 9.0
    }

    fun assess(weather: WeatherSnapshot, durationMin: Int): SafetyAssessment {
        val hi = heatIndexC(weather.tempC, weather.humidityPct)
        val hiText = "${hi.roundToInt()} °C de sensación térmica"
        val adjustments = mutableListOf<String>()

        // --- calor
        val heatLevel = when {
            hi >= 46 -> RiskLevel.EXTREME
            hi >= 39 -> RiskLevel.HIGH
            hi >= 31 -> RiskLevel.MODERATE
            else -> RiskLevel.GOOD
        }

        // --- frío, viento y tormenta
        val coldLevel = when {
            weather.apparentC <= -10 -> RiskLevel.EXTREME
            weather.apparentC <= -2 -> RiskLevel.HIGH
            weather.apparentC <= 4 -> RiskLevel.MODERATE
            else -> RiskLevel.GOOD
        }
        val stormLevel = when {
            weather.weatherCode in 95..99 -> RiskLevel.EXTREME
            weather.windKmh >= 55 -> RiskLevel.HIGH
            weather.windKmh >= 35 -> RiskLevel.MODERATE
            else -> RiskLevel.GOOD
        }

        val level = listOf(heatLevel, coldLevel, stormLevel).maxByOrNull { it.ordinal } ?: RiskLevel.GOOD

        val headline: String
        val advice: String
        when {
            stormLevel == RiskLevel.EXTREME -> {
                headline = "Tormenta eléctrica"
                advice = "No salgas: con actividad eléctrica no hay ruta segura. Movelo a mañana o hacé la " +
                    "sesión bajo techo."
            }
            heatLevel == RiskLevel.EXTREME -> {
                headline = "Calor peligroso"
                advice = "Hoy no conviene entrenar afuera: $hiText. Por encima de este punto el cuerpo deja " +
                    "de disipar calor y el riesgo de golpe de calor es real, aunque estés entrenado. " +
                    "Movelo al amanecer o a la noche."
            }
            coldLevel == RiskLevel.EXTREME -> {
                headline = "Frío extremo"
                advice = "Sensación de ${weather.apparentC.roundToInt()} °C: riesgo de hipotermia en sesiones " +
                    "largas. Mejor adentro o mucho más corto y muy abrigado."
            }
            heatLevel == RiskLevel.HIGH -> {
                headline = "Calor exigente"
                advice = "$hiText. Se puede entrenar, pero con la sesión recortada, sombra y bebida con sodio " +
                    "desde el minuto cero."
            }
            coldLevel == RiskLevel.HIGH -> {
                headline = "Frío fuerte"
                advice = "Sensación de ${weather.apparentC.roundToInt()} °C. Entrada en calor más larga, capas " +
                    "y cuidado con el ritmo en los primeros kilómetros."
            }
            stormLevel == RiskLevel.HIGH -> {
                headline = "Viento fuerte"
                advice = "Ráfagas de ${weather.windKmh.roundToInt()} km/h: elegí un circuito protegido y no " +
                    "busques el ritmo objetivo, buscá el esfuerzo."
            }
            level == RiskLevel.MODERATE && heatLevel == RiskLevel.MODERATE -> {
                headline = "Calor moderado"
                advice = "$hiText. Se entrena bien tomando más seguido y de a menos volumen."
            }
            level == RiskLevel.MODERATE && coldLevel == RiskLevel.MODERATE -> {
                headline = "Fresco"
                advice = "Se entrena bien: sumá una capa liviana y alargá la entrada en calor."
            }
            level == RiskLevel.MODERATE -> {
                headline = "Viento moderado"
                advice = "Ráfagas de ${weather.windKmh.roundToInt()} km/h: salí contra el viento y volvé a favor."
            }
            else -> {
                headline = "Buenas condiciones"
                advice = "${weather.description}, ${weather.tempC.roundToInt()} °C y " +
                    "${weather.humidityPct.roundToInt()}% de humedad. Buen día para entrenar."
            }
        }

        if (heatLevel >= RiskLevel.MODERATE) {
            adjustments += "Tomá cada 10-15 min, sin esperar la sed"
            if (durationMin > 60) adjustments += "Recortá la sesión a ${(durationMin * 0.75).roundToInt()} min"
            adjustments += "Buscá sombra y evitá el sol del mediodía"
        }
        if (weather.uvIndex >= 8) adjustments += "Índice UV ${weather.uvIndex.roundToInt()}: protector solar y gorra"
        if (weather.isRaining) adjustments += "Llueve: ropa técnica y cuidado con el piso en las curvas"
        if (coldLevel >= RiskLevel.MODERATE) adjustments += "Guantes y capa térmica: se pierde calor por las manos"

        return SafetyAssessment(
            level = level,
            headline = headline,
            advice = advice,
            heatIndexC = hi,
            adjustments = adjustments
        )
    }
}
