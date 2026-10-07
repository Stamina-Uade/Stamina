package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.EffortIntensity
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.WorkoutType

/**
 * Gasto energético de las sesiones.
 *
 * Para correr se usa el coeficiente clásico de ~1,036 kcal por kg y por km (costo
 * energético del transporte, casi independiente del ritmo). Para el resto de los
 * deportes se usa la ecuación de METs: kcal/min = MET x 3,5 x kg / 200.
 * El desnivel se suma aparte como trabajo mecánico vertical con 23% de eficiencia.
 */
object EnergyCalculator {

    private const val RUN_KCAL_PER_KG_KM = 1.036

    fun metFor(sport: Sport, intensity: EffortIntensity): Double = when (sport) {
        Sport.RUNNING -> when (intensity) {
            EffortIntensity.EASY -> 8.3
            EffortIntensity.MODERATE -> 10.0
            EffortIntensity.HARD -> 12.8
            EffortIntensity.RACE -> 14.5
        }
        Sport.CYCLING -> when (intensity) {
            EffortIntensity.EASY -> 6.0
            EffortIntensity.MODERATE -> 8.5
            EffortIntensity.HARD -> 11.0
            EffortIntensity.RACE -> 13.0
        }
        Sport.TREKKING -> when (intensity) {
            EffortIntensity.EASY -> 4.5
            EffortIntensity.MODERATE -> 6.0
            EffortIntensity.HARD -> 7.5
            EffortIntensity.RACE -> 8.5
        }
        Sport.SWIMMING, Sport.TRIATHLON -> when (intensity) {
            EffortIntensity.EASY -> 6.0
            EffortIntensity.MODERATE -> 8.3
            EffortIntensity.HARD -> 10.0
            EffortIntensity.RACE -> 11.5
        }
        Sport.STRENGTH -> 5.0
        Sport.OTHER -> 6.0
    }

    /** kcal por minuto para un peso y un MET dados. */
    fun kcalPerMinute(met: Double, weightKg: Double): Double = met * 3.5 * weightKg / 200.0

    /** Gasto de una sesión con distancia conocida (post-entrenamiento). */
    fun sessionKcal(
        sport: Sport,
        weightKg: Double,
        distanceM: Double,
        durationSec: Int,
        elevationGainM: Double,
        intensity: EffortIntensity = EffortIntensity.MODERATE
    ): Int {
        val minutes = durationSec / 60.0
        val km = distanceM / 1000.0
        val base = when (sport) {
            Sport.RUNNING, Sport.TREKKING -> RUN_KCAL_PER_KG_KM * weightKg * km
            else -> kcalPerMinute(metFor(sport, intensity), weightKg) * minutes
        }
        // Trabajo vertical: m*g*h con 23% de eficiencia metabólica.
        val vertical = weightKg * elevationGainM * 0.0102
        val floor = kcalPerMinute(3.0, weightKg) * minutes
        return maxOf(base + vertical, floor).toInt()
    }

    /**
     * Gasto estimado de una sesión planificada. Si ya se estimó la distancia se usa el
     * costo por kilómetro (más preciso que los METs, que asumen un ritmo fijo).
     */
    fun plannedKcal(
        sport: Sport,
        weightKg: Double,
        durationMin: Int,
        type: WorkoutType,
        distanceKm: Double? = null
    ): Int {
        val intensity = when {
            type == WorkoutType.REST -> return 0
            type.isQuality -> EffortIntensity.HARD
            type == WorkoutType.RECOVERY -> EffortIntensity.EASY
            else -> EffortIntensity.MODERATE
        }
        val effectiveSport = if (type == WorkoutType.STRENGTH) Sport.STRENGTH else sport
        if (distanceKm != null && distanceKm > 0 &&
            (effectiveSport == Sport.RUNNING || effectiveSport == Sport.TREKKING)
        ) {
            return sessionKcal(effectiveSport, weightKg, distanceKm * 1000, durationMin * 60, 0.0, intensity)
        }
        return (kcalPerMinute(metFor(effectiveSport, intensity), weightKg) * durationMin).toInt()
    }

    /** Intensidad equivalente a un tipo de sesión, usada por el plan de hidratación. */
    fun intensityFor(type: WorkoutType): EffortIntensity = when (type) {
        WorkoutType.RECOVERY, WorkoutType.REST -> EffortIntensity.EASY
        WorkoutType.EASY, WorkoutType.LONG, WorkoutType.SWIM, WorkoutType.CROSS, WorkoutType.STRENGTH -> EffortIntensity.MODERATE
        WorkoutType.RACE -> EffortIntensity.RACE
        else -> EffortIntensity.HARD
    }
}
