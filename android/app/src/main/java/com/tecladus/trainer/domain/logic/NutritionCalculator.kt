package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.BodyGoal
import com.tecladus.trainer.domain.model.DayLoad
import com.tecladus.trainer.domain.model.FitnessLevel
import com.tecladus.trainer.domain.model.NutritionTargets
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.Sex
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.WorkoutType
import java.time.LocalDate
import kotlin.math.roundToInt

/**
 * Objetivos nutricionales del día, periodizados según la carga de entrenamiento.
 *
 * - Metabolismo basal: ecuación de Mifflin-St Jeor.
 * - Gasto diario = basal x factor de actividad no deportiva + kcal del entrenamiento del día.
 * - Hidratos por kg de peso según la carga del día (3,5 g/kg en descanso hasta 9,5 g/kg
 *   en carga de competencia): es la variable que más impacta en el rendimiento en resistencia.
 * - Proteína 1,6-2,0 g/kg y grasa como resto calórico, nunca por debajo de 0,8 g/kg.
 */
object NutritionCalculator {

    private const val NEAT_FACTOR = 1.35

    fun bmr(profile: UserProfile): Double {
        val base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * profile.age
        return if (profile.sex == Sex.MALE) base + 5 else base - 161
    }

    /** Clasifica el día según la sesión planificada y la cercanía del evento. */
    fun classifyDay(
        workout: PlannedWorkout?,
        date: LocalDate,
        eventDate: LocalDate?,
        eventDurationMin: Int
    ): DayLoad {
        if (eventDate != null && eventDurationMin >= 90) {
            val days = java.time.temporal.ChronoUnit.DAYS.between(date, eventDate)
            if (days in 0..1) return DayLoad.RACE_WEEK
        }
        if (workout == null || workout.type == WorkoutType.REST) return DayLoad.REST
        val minutes = workout.durationMin
        return when {
            workout.type == WorkoutType.RACE -> DayLoad.RACE_WEEK
            minutes >= 100 || (workout.type.isQuality && minutes >= 80) -> DayLoad.HIGH
            minutes >= 60 -> DayLoad.MODERATE
            else -> DayLoad.LOW
        }
    }

    fun targetsFor(
        profile: UserProfile,
        workout: PlannedWorkout?,
        date: LocalDate,
        eventDurationMin: Int = 0
    ): NutritionTargets {
        val basal = bmr(profile)
        val dayLoad = classifyDay(workout, date, profile.eventDate, eventDurationMin)
        val trainingKcal = workout?.estimatedKcal ?: 0

        var maintenance = basal * NEAT_FACTOR + trainingKcal
        val goalAdjustment = when (profile.bodyGoal) {
            // Déficit moderado: nunca más de 500 kcal ni por debajo de 1,15 x basal.
            BodyGoal.LOSE_FAT -> -minOf(500.0, maintenance * 0.15)
            BodyGoal.MAINTAIN -> 0.0
            BodyGoal.GAIN_MUSCLE -> maintenance * 0.10
        }
        maintenance += goalAdjustment
        val kcal = maxOf(maintenance, basal * 1.15)

        var carbsPerKg = dayLoad.carbsPerKg
        if (profile.bodyGoal == BodyGoal.LOSE_FAT && dayLoad != DayLoad.RACE_WEEK) carbsPerKg *= 0.85
        if (profile.level == FitnessLevel.BEGINNER && dayLoad == DayLoad.HIGH) carbsPerKg *= 0.9

        val proteinPerKg = when {
            profile.bodyGoal == BodyGoal.LOSE_FAT -> 2.0
            profile.bodyGoal == BodyGoal.GAIN_MUSCLE -> 1.9
            dayLoad == DayLoad.HIGH || dayLoad == DayLoad.RACE_WEEK -> 1.8
            else -> 1.6
        }

        var carbsG = (carbsPerKg * profile.weightKg).roundToInt()
        val proteinG = (proteinPerKg * profile.weightKg).roundToInt()
        val minFatG = (0.8 * profile.weightKg).roundToInt()

        var fatKcal = kcal - (carbsG * 4.0 + proteinG * 4.0)
        var fatG = (fatKcal / 9.0).roundToInt()
        if (fatG < minFatG) {
            // Si no entra la grasa mínima, se recortan hidratos (nunca proteína).
            fatG = minFatG
            val remaining = kcal - (proteinG * 4.0 + fatG * 9.0)
            carbsG = (remaining / 4.0).roundToInt().coerceAtLeast(50)
        }

        // Agua: 35 ml/kg de base + reposición del sudor de la sesión.
        val sessionSweatMl = if (workout != null && workout.type != WorkoutType.REST) {
            (workout.durationMin * 12).coerceAtMost(3000)
        } else 0
        val waterMl = (35 * profile.weightKg).roundToInt() + sessionSweatMl
        val sodiumMg = 2000 + (sessionSweatMl * profile.sweatSaltiness.sodiumMgPerLiter / 1000.0).roundToInt()

        val rationale = buildString {
            append("${dayLoad.label}: ${"%.1f".format(carbsPerKg)} g de hidratos por kg. ")
            append(dayLoad.description)
            if (trainingKcal > 0) append(". Sumamos $trainingKcal kcal del entrenamiento de hoy")
            when (profile.bodyGoal) {
                BodyGoal.LOSE_FAT -> append(". Déficit moderado para no perder rendimiento")
                BodyGoal.GAIN_MUSCLE -> append(". Superávit del 10% para ganar masa")
                BodyGoal.MAINTAIN -> {}
            }
            append(".")
        }

        return NutritionTargets(
            dayLoad = dayLoad,
            kcal = kcal.roundToInt(),
            carbsG = carbsG,
            proteinG = proteinG,
            fatG = fatG,
            waterMl = waterMl,
            sodiumMg = sodiumMg,
            bmr = basal.roundToInt(),
            trainingKcal = trainingKcal,
            rationale = rationale
        )
    }

    /** Sugerencia de comida pre-entreno según cuánto falta para la sesión. */
    fun preWorkoutAdvice(profile: UserProfile, minutesBefore: Int, durationMin: Int): String {
        val carbs = when {
            minutesBefore >= 180 -> (profile.weightKg * 2.0)
            minutesBefore >= 120 -> (profile.weightKg * 1.5)
            minutesBefore >= 60 -> (profile.weightKg * 1.0)
            else -> (profile.weightKg * 0.5)
        }.roundToInt()
        val fluid = (profile.weightKg * 6).roundToInt()
        val base = "Comé ~$carbs g de hidratos de fácil digestión y tomá ~$fluid ml de líquido antes de salir."
        return if (durationMin >= 90) "$base Para sesiones largas evitá fibra y grasa en las 2 h previas."
        else base
    }

    /** Ventana de recuperación posterior a la sesión. */
    fun recoveryAdvice(profile: UserProfile, kcalBurned: Int, fluidDeficitMl: Int): String {
        val carbs = (profile.weightKg * 1.0).roundToInt()
        val protein = (profile.weightKg * 0.3).roundToInt()
        val fluid = (fluidDeficitMl * 1.5).coerceAtLeast(400.0).roundToInt()
        return "Recuperación (primeros 30-60 min): $carbs g de hidratos + $protein g de proteína y $fluid ml de líquido con sodio."
    }
}
