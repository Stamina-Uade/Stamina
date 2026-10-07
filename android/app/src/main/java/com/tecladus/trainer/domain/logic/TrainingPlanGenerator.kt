package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.FitnessLevel
import com.tecladus.trainer.domain.model.GoalType
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.TrainingPhase
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.WorkoutType
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * Generador de planes de entrenamiento periodizados.
 *
 * Principios aplicados:
 *  - Periodización clásica: Base -> Construcción -> Pico -> Afinamiento (taper).
 *  - Progresión de volumen contenida (regla del 10%) con semana de descarga cada 4.
 *  - Distribución polarizada: ~80% del volumen en zona aeróbica (Z1-Z2) y 20% en calidad.
 *  - Una sesión de fuerza semanal, que es el factor protector de lesiones mejor documentado.
 */
object TrainingPlanGenerator {

    /** Ranura semanal: qué papel cumple cada día de entrenamiento. */
    private enum class Slot { LONG, QUALITY, QUALITY2, EASY, RECOVERY, STRENGTH }

    private val slotWeights = mapOf(
        Slot.LONG to 0.32,
        Slot.QUALITY to 0.17,
        Slot.QUALITY2 to 0.15,
        Slot.EASY to 0.18,
        Slot.RECOVERY to 0.10,
        Slot.STRENGTH to 0.0
    )

    /**
     * Reparte los roles de la semana sobre los días que la persona realmente puede entrenar.
     *
     * Criterios: el fondo largo va al fin de semana si está disponible, la sesión de calidad
     * al día con más descanso previo, la segunda calidad lo más lejos posible de la primera,
     * el regenerativo al día siguiente del fondo y la fuerza a un día suave antes del fondo.
     */
    private fun assignSlots(days: List<DayOfWeek>): Map<DayOfWeek, Slot> {
        val sorted = days.distinct().sortedBy { it.value }
        if (sorted.isEmpty()) return emptyMap()
        if (sorted.size == 1) return mapOf(sorted[0] to Slot.LONG)

        val result = linkedMapOf<DayOfWeek, Slot>()
        val long = sorted.firstOrNull { it == DayOfWeek.SUNDAY }
            ?: sorted.firstOrNull { it == DayOfWeek.SATURDAY }
            ?: sorted.last()
        result[long] = Slot.LONG

        val free = sorted.filter { it != long }.toMutableList()

        // Días de descanso desde la sesión anterior (circular sobre la semana).
        fun gapBefore(day: DayOfWeek): Int =
            sorted.filter { it != day }.minOf { other -> (day.value - other.value + 7) % 7 }

        fun distance(a: DayOfWeek, b: DayOfWeek): Int {
            val forward = (a.value - b.value + 7) % 7
            return minOf(forward, 7 - forward)
        }

        val quality = free.maxByOrNull { gapBefore(it) } ?: free.first()
        result[quality] = Slot.QUALITY
        free.remove(quality)

        if (sorted.size >= 5 && free.isNotEmpty()) {
            val quality2 = free.maxByOrNull { day -> minOf(distance(day, quality), distance(day, long)) }
            if (quality2 != null) {
                result[quality2] = Slot.QUALITY2
                free.remove(quality2)
            }
        }

        if (sorted.size >= 6) {
            val recovery = free.firstOrNull { (it.value - long.value + 7) % 7 == 1 }
            if (recovery != null) {
                result[recovery] = Slot.RECOVERY
                free.remove(recovery)
            }
        }

        if (sorted.size >= 4 && free.isNotEmpty()) {
            val strength = free.minByOrNull { (long.value - it.value + 7) % 7 }
            if (strength != null) {
                result[strength] = Slot.STRENGTH
                free.remove(strength)
            }
        }

        free.forEach { result[it] = Slot.EASY }
        return result
    }

    /** Volumen semanal pico, en minutos, por objetivo y nivel. */
    private fun peakWeeklyMinutes(goal: GoalType, level: FitnessLevel): Int {
        val base = when (goal) {
            GoalType.RACE_5K -> 150
            GoalType.RACE_10K -> 180
            GoalType.RACE_21K -> 240
            GoalType.RACE_42K -> 300
            GoalType.CYCLING_100K -> 300
            GoalType.CYCLING_GRANFONDO -> 360
            GoalType.TREKKING_LONG -> 260
            GoalType.TRIATHLON_SPRINT -> 260
            GoalType.TRIATHLON_OLYMPIC -> 320
            GoalType.GENERAL_FITNESS -> 150
        }
        val factor = when (level) {
            FitnessLevel.BEGINNER -> 1.0
            FitnessLevel.INTERMEDIATE -> 1.45
            FitnessLevel.ADVANCED -> 1.9
        }
        return (base * factor).roundToInt()
    }

    fun generate(profile: UserProfile, startDate: LocalDate = LocalDate.now()): List<PlannedWorkout> {
        val eventDate = profile.eventDate ?: startDate.plusWeeks(8)
        val totalDays = ChronoUnit.DAYS.between(startDate, eventDate).toInt().coerceAtLeast(13)
        val weeks = ceil(totalDays / 7.0).toInt().coerceIn(2, 26)

        val taperWeeks = if (weeks >= 12) 2 else 1
        val peakWeeks = if (weeks >= 10) 2 else 1
        val remaining = (weeks - taperWeeks - peakWeeks).coerceAtLeast(1)
        val baseWeeks = ceil(remaining * 0.6).toInt().coerceAtLeast(1)
        val buildWeeks = (remaining - baseWeeks).coerceAtLeast(0)

        val peakMinutes = peakWeeklyMinutes(profile.goal, profile.level)
        val startMinutes = (peakMinutes * 0.55).roundToInt()
        val layout = assignSlots(profile.trainingDays)

        val workouts = mutableListOf<PlannedWorkout>()
        var date = startDate

        while (!date.isAfter(eventDate)) {
            val weekIndex = (ChronoUnit.DAYS.between(startDate, date) / 7).toInt()
            val weekNumber = weekIndex + 1
            val phase = phaseFor(weekIndex, baseWeeks, buildWeeks, peakWeeks, taperWeeks, weeks)
            val weeklyMinutes = weeklyVolume(
                weekIndex, weeks, baseWeeks, buildWeeks, peakWeeks, taperWeeks, startMinutes, peakMinutes
            )

            if (date == eventDate && profile.eventDate != null) {
                workouts += raceWorkout(profile, date, weekNumber)
                date = date.plusDays(1)
                continue
            }

            val slot = layout[date.dayOfWeek]
            if (slot == null) {
                workouts += restWorkout(date, weekNumber, phase)
            } else {
                workouts += buildWorkout(profile, date, weekNumber, phase, slot, weeklyMinutes, layout)
            }
            date = date.plusDays(1)
        }
        return workouts
    }

    private fun phaseFor(
        weekIndex: Int,
        baseWeeks: Int,
        buildWeeks: Int,
        peakWeeks: Int,
        taperWeeks: Int,
        totalWeeks: Int
    ): TrainingPhase = when {
        weekIndex >= totalWeeks - taperWeeks -> TrainingPhase.TAPER
        weekIndex >= totalWeeks - taperWeeks - peakWeeks -> TrainingPhase.PEAK
        weekIndex >= baseWeeks -> TrainingPhase.BUILD
        else -> TrainingPhase.BASE
    }

    private fun weeklyVolume(
        weekIndex: Int,
        totalWeeks: Int,
        baseWeeks: Int,
        buildWeeks: Int,
        peakWeeks: Int,
        taperWeeks: Int,
        startMinutes: Int,
        peakMinutes: Int
    ): Int {
        val progressionWeeks = (baseWeeks + buildWeeks).coerceAtLeast(1)
        return when {
            weekIndex >= totalWeeks - taperWeeks -> {
                val taperIndex = weekIndex - (totalWeeks - taperWeeks)
                val factor = if (taperWeeks == 1) 0.5 else if (taperIndex == 0) 0.65 else 0.45
                (peakMinutes * factor).roundToInt()
            }
            weekIndex >= totalWeeks - taperWeeks - peakWeeks -> {
                val peakIndex = weekIndex - (totalWeeks - taperWeeks - peakWeeks)
                (peakMinutes * if (peakIndex == 0) 1.0 else 0.95).roundToInt()
            }
            else -> {
                val progress = weekIndex.toDouble() / progressionWeeks
                val volume = startMinutes + (peakMinutes - startMinutes) * progress
                // Semana de descarga cada 4 semanas para consolidar adaptaciones.
                val deload = (weekIndex + 1) % 4 == 0
                (volume * if (deload) 0.72 else 1.0).roundToInt()
            }
        }
    }

    private fun restWorkout(date: LocalDate, weekNumber: Int, phase: TrainingPhase) = PlannedWorkout(
        date = date,
        sport = Sport.OTHER,
        type = WorkoutType.REST,
        title = "Descanso",
        description = "Día libre. Movilidad suave, elongación y buen descanso nocturno: la adaptación " +
            "ocurre cuando descansás, no mientras entrenás.",
        durationMin = 0,
        distanceKm = null,
        targetPaceLowSecPerKm = null,
        targetPaceHighSecPerKm = null,
        phase = phase,
        weekNumber = weekNumber,
        estimatedKcal = 0,
        fuelingTip = "Día de menor carga: bajá los hidratos y sostené la proteína e hidratación."
    )

    private fun raceWorkout(profile: UserProfile, date: LocalDate, weekNumber: Int): PlannedWorkout {
        val minutes = PaceCalculator.estimatedGoalTimeMinutes(profile)
        val pace = PaceCalculator.goalRacePace(profile)
        val plan = HydrationCalculator.buildPlan(
            profile = profile,
            sport = profile.goal.sport,
            intensity = com.tecladus.trainer.domain.model.EffortIntensity.RACE,
            weather = com.tecladus.trainer.domain.model.WeatherConditions(),
            expectedDurationMin = minutes
        )
        return PlannedWorkout(
            date = date,
            sport = profile.goal.sport,
            type = WorkoutType.RACE,
            title = "¡${profile.goal.label}! Día del evento",
            description = "Objetivo: ${profile.goal.label}. Ritmo estimado ${PaceCalculator.formatPace(pace)} min/km " +
                "para un tiempo aproximado de ${minutes / 60} h ${minutes % 60} min. Salí conservador los " +
                "primeros kilómetros y respetá el plan de hidratación desde el minuto uno.",
            durationMin = minutes,
            distanceKm = profile.goal.distanceKm,
            targetPaceLowSecPerKm = pace - 8,
            targetPaceHighSecPerKm = pace + 8,
            phase = TrainingPhase.RACE,
            weekNumber = weekNumber,
            estimatedKcal = EnergyCalculator.sessionKcal(
                profile.goal.sport, profile.weightKg, profile.goal.distanceKm * 1000, minutes * 60, 0.0,
                com.tecladus.trainer.domain.model.EffortIntensity.RACE
            ),
            fuelingTip = "En carrera: ${plan.fluidPerHourMl} ml/h, ${plan.sodiumPerHourMg} mg de sodio/h y " +
                "${plan.carbsPerHourG} g de hidratos/h. Desayuno 3 h antes con ${plan.preSessionCarbsG} g de hidratos.",
            scheduledMinuteOfDay = profile.timeFor(date.dayOfWeek)
        )
    }

    private fun buildWorkout(
        profile: UserProfile,
        date: LocalDate,
        weekNumber: Int,
        phase: TrainingPhase,
        slot: Slot,
        weeklyMinutes: Int,
        layout: Map<DayOfWeek, Slot>
    ): PlannedWorkout {
        val usedWeights = layout.values.sumOf { slotWeights[it] ?: 0.0 }
        val weight = (slotWeights[slot] ?: 0.0) / (if (usedWeights > 0) usedWeights else 1.0)
        val type = typeFor(slot, phase, profile, weekNumber)
        val sport = sportFor(profile, slot, type)

        val duration = when (type) {
            WorkoutType.STRENGTH -> 35
            else -> (weeklyMinutes * weight).roundToInt().coerceIn(25, 240)
        }

        val paceRange = PaceCalculator.paceRangeFor(profile, type)
        val distance = estimateDistance(profile, sport, type, duration, paceRange)
        val kcal = EnergyCalculator.plannedKcal(sport, profile.weightKg, duration, type, distance)

        val plan = HydrationCalculator.buildPlan(
            profile = profile,
            sport = sport,
            intensity = EnergyCalculator.intensityFor(type),
            weather = com.tecladus.trainer.domain.model.WeatherConditions(),
            expectedDurationMin = duration
        )
        val fueling = when {
            type == WorkoutType.STRENGTH -> "Proteína dentro de la hora posterior (${(profile.weightKg * 0.3).roundToInt()} g)."
            duration < 60 -> "Agua a demanda (${plan.fluidPerHourMl} ml/h). No hacen falta geles."
            else -> "Llevá ${plan.totalFluidMl} ml, ${plan.totalCarbsG} g de hidratos y ${plan.totalSodiumMg} mg de sodio."
        }

        return PlannedWorkout(
            date = date,
            sport = sport,
            type = type,
            title = titleFor(type, sport, duration),
            description = descriptionFor(type, duration, profile, paceRange),
            durationMin = duration,
            distanceKm = distance,
            targetPaceLowSecPerKm = paceRange?.first,
            targetPaceHighSecPerKm = paceRange?.last,
            phase = phase,
            weekNumber = weekNumber,
            estimatedKcal = kcal,
            fuelingTip = fueling,
            scheduledMinuteOfDay = profile.timeFor(date.dayOfWeek)
        )
    }

    private fun typeFor(slot: Slot, phase: TrainingPhase, profile: UserProfile, weekNumber: Int): WorkoutType =
        when (slot) {
            Slot.STRENGTH -> WorkoutType.STRENGTH
            Slot.RECOVERY -> WorkoutType.RECOVERY
            Slot.EASY -> WorkoutType.EASY
            Slot.LONG -> WorkoutType.LONG
            Slot.QUALITY -> when (phase) {
                TrainingPhase.BASE -> if (weekNumber % 2 == 0) WorkoutType.HILLS else WorkoutType.FARTLEK
                TrainingPhase.BUILD -> WorkoutType.INTERVALS
                TrainingPhase.PEAK -> WorkoutType.RACE_PACE
                TrainingPhase.TAPER -> WorkoutType.RACE_PACE
                TrainingPhase.RACE -> WorkoutType.RACE
            }
            Slot.QUALITY2 -> when (phase) {
                TrainingPhase.BASE -> WorkoutType.TEMPO
                TrainingPhase.BUILD -> WorkoutType.THRESHOLD
                TrainingPhase.PEAK -> WorkoutType.INTERVALS
                TrainingPhase.TAPER -> WorkoutType.EASY
                TrainingPhase.RACE -> WorkoutType.EASY
            }
        }

    /** En triatlón se rotan los deportes; en el resto se entrena el deporte principal. */
    private fun sportFor(profile: UserProfile, slot: Slot, type: WorkoutType): Sport {
        if (type == WorkoutType.STRENGTH) return Sport.STRENGTH
        val main = if (profile.primarySport == Sport.OTHER) profile.goal.sport else profile.primarySport
        if (main != Sport.TRIATHLON) return main
        return when (slot) {
            Slot.QUALITY -> Sport.CYCLING
            Slot.QUALITY2 -> Sport.SWIMMING
            Slot.EASY, Slot.RECOVERY -> Sport.RUNNING
            Slot.LONG -> Sport.CYCLING
            Slot.STRENGTH -> Sport.STRENGTH
        }
    }

    private fun estimateDistance(
        profile: UserProfile,
        sport: Sport,
        type: WorkoutType,
        durationMin: Int,
        paceRange: IntRange?
    ): Double? = when (sport) {
        Sport.RUNNING -> {
            val pace = paceRange?.let { (it.first + it.last) / 2 }
                ?: PaceCalculator.predictedPaceSecPerKm(profile, 10.0)
            if (pace > 0) (durationMin * 60.0 / pace) else null
        }
        Sport.CYCLING -> durationMin / 60.0 * PaceCalculator.cyclingSpeedKmh(profile.level) *
            (if (type.isQuality) 1.05 else 0.95)
        Sport.TREKKING -> durationMin / 60.0 * PaceCalculator.trekkingSpeedKmh(profile.level)
        Sport.SWIMMING -> durationMin / 60.0 * 2.6
        else -> null
    }?.let { kotlin.math.round(it * 10) / 10.0 }

    private fun titleFor(type: WorkoutType, sport: Sport, durationMin: Int): String = when (type) {
        WorkoutType.STRENGTH -> "Fuerza para corredores (35 min)"
        WorkoutType.LONG -> "${sport.label}: fondo largo ($durationMin min)"
        WorkoutType.RECOVERY -> "Regenerativo suave ($durationMin min)"
        WorkoutType.EASY -> "${sport.label} suave ($durationMin min)"
        else -> "${type.label} · ${sport.label} ($durationMin min)"
    }

    private fun descriptionFor(
        type: WorkoutType,
        durationMin: Int,
        profile: UserProfile,
        paceRange: IntRange?
    ): String {
        val zoneText = "Zona ${type.zone.label} (${type.zone.bpmRange(profile.maxHr).first}-" +
            "${type.zone.bpmRange(profile.maxHr).last} ppm)"
        val paceText = if (paceRange != null) " · Ritmo ${PaceCalculator.formatPaceRange(paceRange)}" else ""
        val body = when (type) {
            WorkoutType.EASY ->
                "Rodaje continuo en zona aeróbica. Deberías poder mantener una conversación completa. " +
                    "Cerrá con 4 progresiones de 20 segundos."
            WorkoutType.RECOVERY ->
                "Trote muy suave o bici liviana. El objetivo es mover la sangre, no entrenar."
            WorkoutType.LONG ->
                "Fondo continuo a ritmo cómodo. Es la sesión clave de la semana: usála también para " +
                    "ensayar tu estrategia de hidratación y geles tal como la usarías en carrera."
            WorkoutType.TEMPO -> {
                val block = (durationMin * 0.45).roundToInt()
                "15 min de entrada en calor + $block min continuos a ritmo tempo + 10 min de vuelta a la calma."
            }
            WorkoutType.THRESHOLD -> {
                val reps = ((durationMin - 25) / 12).coerceIn(2, 5)
                "15 min de entrada en calor + $reps x 8 min a ritmo umbral con 2 min de trote + 10 min suaves."
            }
            WorkoutType.INTERVALS -> {
                val reps = ((durationMin - 25) / 5).coerceIn(4, 10)
                "15 min de entrada en calor + $reps x 3 min fuertes con 2 min de trote de recuperación + " +
                    "10 min de vuelta a la calma."
            }
            WorkoutType.HILLS -> {
                val reps = ((durationMin - 25) / 4).coerceIn(6, 12)
                "15 min de entrada en calor + $reps x 60 seg en subida al 5-8% bajando trotando + 10 min suaves. " +
                    "Trabaja fuerza específica sin impacto excesivo."
            }
            WorkoutType.FARTLEK ->
                "15 min suaves + 20 min de juego de ritmos (1 min fuerte / 2 min suave) + 10 min de vuelta a la calma."
            WorkoutType.RACE_PACE -> {
                val block = (durationMin * 0.4).roundToInt()
                "15 min de entrada en calor + $block min a ritmo objetivo de carrera + 10 min suaves. " +
                    "Ensayá con la ropa y los geles que vas a usar el día del evento."
            }
            WorkoutType.STRENGTH ->
                "Circuito de fuerza: sentadillas, estocadas, puente de glúteo, plancha y trabajo excéntrico de " +
                    "gemelos e isquiotibiales. 3 series x 10-12 repeticiones. Reduce el riesgo de lesión por sobrecarga."
            WorkoutType.SWIM ->
                "Técnica + series cortas. 400 m suaves, 8 x 100 m con 20 seg de pausa, 200 m suaves."
            WorkoutType.BRICK ->
                "Bici a ritmo objetivo y, sin pausa, transición a carrera 15-20 min. Ensayá la transición completa."
            WorkoutType.CROSS ->
                "Actividad alternativa de bajo impacto (elíptico, natación o bici) para sumar volumen sin carga articular."
            WorkoutType.RACE -> "Día de competencia."
            WorkoutType.REST -> "Descanso."
        }
        return "$body\n$zoneText$paceText"
    }
}
