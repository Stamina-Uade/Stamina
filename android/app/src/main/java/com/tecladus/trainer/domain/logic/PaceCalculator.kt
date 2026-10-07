package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.FitnessLevel
import com.tecladus.trainer.domain.model.GoalType
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.WorkoutType
import kotlin.math.pow

/**
 * Predice ritmos de entrenamiento a partir de una marca de referencia usando la
 * fórmula de Riegel: T2 = T1 * (D2 / D1)^1.06.
 *
 * Si el usuario no cargó una marca, se usan ritmos por defecto según su nivel.
 */
object PaceCalculator {

    private const val RIEGEL_EXPONENT = 1.06

    /** Ritmo de referencia (seg/km) para 10K según nivel, cuando no hay marca cargada. */
    private fun default10kPace(level: FitnessLevel): Int = when (level) {
        FitnessLevel.BEGINNER -> 420      // 7:00 min/km
        FitnessLevel.INTERMEDIATE -> 330  // 5:30 min/km
        FitnessLevel.ADVANCED -> 258      // 4:18 min/km
    }

    /** Predice el tiempo (segundos) para [targetKm] a partir de una marca previa. */
    fun predictTimeSec(refDistanceKm: Double, refTimeSec: Double, targetKm: Double): Double =
        refTimeSec * (targetKm / refDistanceKm).pow(RIEGEL_EXPONENT)

    /** Ritmo previsto (seg/km) para una distancia objetivo. */
    fun predictedPaceSecPerKm(profile: UserProfile, targetKm: Double): Int {
        val refKm = profile.referenceDistanceKm
        val refMin = profile.referenceTimeMinutes
        return if (refKm != null && refMin != null && refKm > 0.5 && refMin > 1) {
            (predictTimeSec(refKm, refMin * 60.0, targetKm) / targetKm).toInt()
        } else {
            val base10k = default10kPace(profile.level)
            (predictTimeSec(10.0, base10k * 10.0, targetKm) / targetKm).toInt()
        }
    }

    /** Ritmo objetivo del evento del usuario. */
    fun goalRacePace(profile: UserProfile): Int =
        predictedPaceSecPerKm(profile, profile.goal.distanceKm.coerceAtLeast(1.0))

    /**
     * Rango de ritmo sugerido para cada tipo de sesión, derivado del ritmo de maratón
     * equivalente (referencia clásica de los sistemas tipo VDOT).
     */
    fun paceRangeFor(profile: UserProfile, type: WorkoutType): IntRange? {
        if (profile.primarySport.name == "CYCLING" || profile.primarySport.name == "SWIMMING") return null
        val marathonPace = predictedPaceSecPerKm(profile, 42.195)
        val tenKPace = predictedPaceSecPerKm(profile, 10.0)
        val fiveKPace = predictedPaceSecPerKm(profile, 5.0)
        return when (type) {
            WorkoutType.RECOVERY -> (marathonPace + 90)..(marathonPace + 130)
            WorkoutType.EASY -> (marathonPace + 55)..(marathonPace + 95)
            WorkoutType.LONG -> (marathonPace + 35)..(marathonPace + 80)
            WorkoutType.TEMPO -> (tenKPace + 20)..(tenKPace + 40)
            WorkoutType.THRESHOLD -> (tenKPace + 5)..(tenKPace + 20)
            WorkoutType.INTERVALS -> (fiveKPace - 10)..(fiveKPace + 8)
            WorkoutType.HILLS -> (fiveKPace + 10)..(fiveKPace + 40)
            WorkoutType.FARTLEK -> (tenKPace)..(tenKPace + 45)
            WorkoutType.RACE_PACE, WorkoutType.RACE -> {
                val goal = goalRacePace(profile)
                (goal - 8)..(goal + 8)
            }
            else -> null
        }
    }

    /** Velocidad media estimada en bici (km/h) según nivel, para dimensionar los planes. */
    fun cyclingSpeedKmh(level: FitnessLevel): Double = when (level) {
        FitnessLevel.BEGINNER -> 23.0
        FitnessLevel.INTERMEDIATE -> 28.0
        FitnessLevel.ADVANCED -> 32.0
    }

    /** Velocidad media caminando en montaña (km/h). */
    fun trekkingSpeedKmh(level: FitnessLevel): Double = when (level) {
        FitnessLevel.BEGINNER -> 3.5
        FitnessLevel.INTERMEDIATE -> 4.2
        FitnessLevel.ADVANCED -> 5.0
    }

    /** Tiempo estimado del evento objetivo en minutos, usando la predicción de ritmo. */
    fun estimatedGoalTimeMinutes(profile: UserProfile): Int {
        val goal = profile.goal
        return when (goal.sport.name) {
            "RUNNING" -> (goalRacePace(profile) * goal.distanceKm / 60.0).toInt()
            "CYCLING" -> (goal.distanceKm / cyclingSpeedKmh(profile.level) * 60).toInt()
            "TREKKING" -> (goal.distanceKm / trekkingSpeedKmh(profile.level) * 60).toInt()
            else -> goal.estimatedEventMinutes(profile.level)
        }
    }

    /** Formatea segundos por km como "m:ss". */
    fun formatPace(secPerKm: Int): String {
        if (secPerKm <= 0) return "--:--"
        val m = secPerKm / 60
        val s = secPerKm % 60
        return "%d:%02d".format(m, s)
    }

    fun formatPaceRange(range: IntRange?): String =
        if (range == null) "" else "${formatPace(range.first)} - ${formatPace(range.last)} min/km"

    fun goalTypeFor(sportName: String): GoalType = when (sportName) {
        "CYCLING" -> GoalType.CYCLING_100K
        "TREKKING" -> GoalType.TREKKING_LONG
        "TRIATHLON" -> GoalType.TRIATHLON_SPRINT
        else -> GoalType.RACE_10K
    }
}
