package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.EffortIntensity
import com.tecladus.trainer.domain.model.FuelScheduleItem
import com.tecladus.trainer.domain.model.HydrationPlan
import com.tecladus.trainer.domain.model.IntakeType
import com.tecladus.trainer.domain.model.Sex
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.WeatherConditions
import kotlin.math.roundToInt

/**
 * Núcleo diferencial de la app: calcula cuánto tomar, cuánto sodio reponer y cuántos
 * hidratos consumir durante el esfuerzo, y arma la agenda de avisos.
 *
 * Criterios usados (consenso ACSM / ISSN de nutrición deportiva):
 *  - Reponer entre el 70 y el 80% de lo que se pierde por sudor; nunca más de ~800 ml/h
 *    (límite de vaciado gástrico) para no arriesgar hiponatremia.
 *  - Sodio: 300-1100 mg por litro de sudor según lo "salado" que sea el sudor de la persona.
 *  - Hidratos: nada hasta 45-60 min; 30-60 g/h entre 1 y 2,5 h; 60-90 g/h más allá
 *    (mezcla glucosa:fructosa) y siempre limitado por el entrenamiento intestinal.
 *  - Deshidratación > 2% del peso corporal = caída del rendimiento; 3-5% = calambres,
 *    apatía y desorientación.
 */
object HydrationCalculator {

    private const val MAX_FLUID_PER_HOUR_ML = 800
    private const val MIN_FLUID_PER_HOUR_ML = 300
    private const val REPLACEMENT_RATIO = 0.78

    /** Tasa base de sudoración en L/h para 70 kg a 18 °C y esfuerzo moderado. */
    private fun baseSweatRate(sport: Sport): Double = when (sport) {
        Sport.RUNNING -> 0.95
        Sport.TRIATHLON -> 0.90
        Sport.CYCLING -> 0.75
        Sport.TREKKING -> 0.60
        Sport.SWIMMING -> 0.40
        Sport.STRENGTH -> 0.50
        Sport.OTHER -> 0.70
    }

    /**
     * Estima la tasa de sudoración (L/h). Si el usuario midió la suya con el protocolo
     * de pesarse antes y después, se usa ese valor como base.
     */
    fun sweatRateLh(
        profile: UserProfile,
        sport: Sport,
        intensity: EffortIntensity,
        weather: WeatherConditions
    ): Double {
        val base = profile.measuredSweatRateLh ?: baseSweatRate(sport)
        val weightFactor = if (profile.measuredSweatRateLh != null) 1.0 else (profile.weightKg / 70.0)
        val sexFactor = if (profile.measuredSweatRateLh != null) 1.0
        else if (profile.sex == Sex.FEMALE) 0.85 else 1.0
        // Cada grado por encima de 18 °C suma ~3,5% de sudoración; por debajo resta.
        val tempFactor = (1.0 + 0.035 * (weather.tempC - 18.0)).coerceIn(0.65, 1.9)
        // La humedad alta impide la evaporación y aumenta la pérdida.
        val humidityFactor = (1.0 + 0.004 * (weather.humidityPct - 50.0)).coerceIn(0.9, 1.3)
        val sunFactor = if (weather.underSun && weather.tempC > 22) 1.08 else 1.0
        return (base * weightFactor * sexFactor * intensity.factor * tempFactor * humidityFactor * sunFactor)
            .coerceIn(0.25, 2.6)
    }

    /** Gramos de hidratos por hora según duración y tolerancia intestinal del usuario. */
    fun carbsPerHour(durationMin: Int, gutTrainingLevel: Int): Int {
        val raw = when {
            durationMin < 45 -> 0
            durationMin < 75 -> 25
            durationMin < 150 -> 50
            durationMin < 240 -> 75
            else -> 90
        }
        val cap = when (gutTrainingLevel) {
            1 -> 45
            2 -> 70
            else -> 95
        }
        return minOf(raw, cap)
    }

    fun buildPlan(
        profile: UserProfile,
        sport: Sport,
        intensity: EffortIntensity,
        weather: WeatherConditions,
        expectedDurationMin: Int
    ): HydrationPlan {
        val sweatRate = sweatRateLh(profile, sport, intensity, weather)
        val rawFluid = sweatRate * 1000 * REPLACEMENT_RATIO
        val fluidPerHour = rawFluid.roundToInt().coerceIn(MIN_FLUID_PER_HOUR_ML, MAX_FLUID_PER_HOUR_ML)

        // Con mucho calor conviene tomar más seguido y de a menos volumen.
        val fluidInterval = when {
            expectedDurationMin < 40 -> 20
            sweatRate > 1.4 -> 10
            sweatRate > 1.0 -> 15
            else -> 20
        }
        val fluidBolus = (fluidPerHour * fluidInterval / 60.0).roundToInt()

        val sodiumPerLiter = profile.sweatSaltiness.sodiumMgPerLiter
        // Se repone entre el 60 y el 80% del sodio perdido; más si la sesión es larga.
        val sodiumReplacement = if (expectedDurationMin >= 120) 0.8 else 0.6
        // Tope de 1500 mg/h: por encima de ese valor la tolerancia gástrica cae y no hay
        // evidencia de beneficio adicional, incluso en personas que sudan mucho.
        val sodiumPerHour = if (expectedDurationMin < 60) 0
        else (sweatRate * sodiumPerLiter * sodiumReplacement).roundToInt().coerceAtMost(1500)
        val sodiumInterval = if (sodiumPerHour == 0) 0 else if (sweatRate > 1.3) 30 else 45
        val sodiumBolus = if (sodiumInterval == 0) 0 else (sodiumPerHour * sodiumInterval / 60.0).roundToInt()

        val carbsPerHour = carbsPerHour(expectedDurationMin, profile.gutTrainingLevel)
        val carbsInterval = when {
            carbsPerHour == 0 -> 0
            carbsPerHour >= 75 -> 20
            carbsPerHour >= 50 -> 25
            else -> 30
        }
        val carbsBolus = if (carbsInterval == 0) 0 else (carbsPerHour * carbsInterval / 60.0).roundToInt()

        // Pre-sesión: 5-7 ml/kg entre 2 y 4 horas antes.
        val preFluid = (profile.weightKg * 6).roundToInt()
        val preCarbs = when {
            expectedDurationMin < 60 -> (profile.weightKg * 0.5).roundToInt()
            expectedDurationMin < 150 -> (profile.weightKg * 1.2).roundToInt()
            else -> (profile.weightKg * 2.0).roundToInt()
        }
        // Post: 150% del líquido perdido y ventana de recuperación 1 g/kg CHO + 0,3 g/kg proteína.
        val expectedLoss = sweatRate * 1000 * expectedDurationMin / 60.0
        val postFluid = (expectedLoss * 1.5 - fluidPerHour * expectedDurationMin / 60.0)
            .coerceAtLeast(300.0).roundToInt()
        val postCarbs = (profile.weightKg * 1.0).roundToInt()
        val postProtein = (profile.weightKg * 0.3).roundToInt()

        val notes = buildList {
            add("Sudor estimado: ${(expectedLoss / 1000.0).format1()} L en ${expectedDurationMin} min.")
            val dehydration = if (profile.weightKg > 0) expectedLoss / 10.0 / profile.weightKg else 0.0
            if (dehydration >= 2.0) {
                add("Sin reponer perderías ${dehydration.format1()}% del peso corporal: por encima del 2% ya cae el rendimiento.")
            }
            if (weather.tempC >= 28) add("Calor alto: arrancá hidratado y buscá sombra en los descansos.")
            if (expectedDurationMin >= 90) add("Sesión larga: sumá sodio desde el inicio, no esperes a tener sed.")
            if (carbsPerHour >= 60) add("Usá mezcla glucosa + fructosa (2:1) para absorber más de 60 g/h sin molestias.")
            if (expectedDurationMin < 60) add("Menos de 60 min: alcanza con agua, no necesitás geles.")
            if (profile.gutTrainingLevel == 1) add("Entrená el intestino: subí de a 10 g/h por semana en los fondos.")
        }

        return HydrationPlan(
            sport = sport,
            intensity = intensity,
            weather = weather,
            expectedDurationMin = expectedDurationMin,
            sweatRateLh = sweatRate,
            fluidPerHourMl = fluidPerHour,
            fluidBolusMl = fluidBolus,
            fluidIntervalMin = fluidInterval,
            sodiumPerHourMg = sodiumPerHour,
            sodiumBolusMg = sodiumBolus,
            sodiumIntervalMin = sodiumInterval,
            carbsPerHourG = carbsPerHour,
            carbsBolusG = carbsBolus,
            carbsIntervalMin = carbsInterval,
            preSessionFluidMl = preFluid,
            preSessionCarbsG = preCarbs,
            postSessionFluidMl = postFluid,
            postSessionCarbsG = postCarbs,
            postSessionProteinG = postProtein,
            notes = notes
        )
    }

    /** Agenda de avisos minuto a minuto para la sesión. */
    fun buildSchedule(plan: HydrationPlan): List<FuelScheduleItem> {
        val items = mutableListOf<FuelScheduleItem>()
        val duration = plan.expectedDurationMin
        if (plan.fluidIntervalMin > 0) {
            var t = plan.fluidIntervalMin
            while (t <= duration) {
                items += FuelScheduleItem(
                    atMinute = t,
                    type = IntakeType.WATER,
                    fluidMl = plan.fluidBolusMl,
                    sodiumMg = 0,
                    carbsG = 0,
                    message = "Tomá ${plan.fluidBolusMl} ml"
                )
                t += plan.fluidIntervalMin
            }
        }
        if (plan.sodiumIntervalMin > 0) {
            var t = plan.sodiumIntervalMin
            while (t <= duration) {
                items += FuelScheduleItem(
                    atMinute = t,
                    type = IntakeType.SALT,
                    fluidMl = 0,
                    sodiumMg = plan.sodiumBolusMg,
                    carbsG = 0,
                    message = "Sales: ${plan.sodiumBolusMg} mg de sodio"
                )
                t += plan.sodiumIntervalMin
            }
        }
        if (plan.carbsIntervalMin > 0) {
            var t = maxOf(plan.carbsIntervalMin, 30)
            while (t <= duration) {
                items += FuelScheduleItem(
                    atMinute = t,
                    type = IntakeType.GEL,
                    fluidMl = 0,
                    sodiumMg = 0,
                    carbsG = plan.carbsBolusG,
                    message = "Gel / hidratos: ${plan.carbsBolusG} g"
                )
                t += plan.carbsIntervalMin
            }
        }
        return items.sortedBy { it.atMinute }
    }

    /** Tasa de sudoración medida: (peso antes - peso después + líquido tomado) / horas. */
    fun measuredSweatRate(
        weightBeforeKg: Double,
        weightAfterKg: Double,
        fluidIntakeMl: Int,
        durationMin: Int
    ): Double {
        if (durationMin <= 0) return 0.0
        val lossLiters = (weightBeforeKg - weightAfterKg) + fluidIntakeMl / 1000.0
        return (lossLiters / (durationMin / 60.0)).coerceIn(0.0, 3.5)
    }

    private fun Double.format1(): String = String.format("%.1f", this)
}
