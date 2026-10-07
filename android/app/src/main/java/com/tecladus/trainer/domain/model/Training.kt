package com.tecladus.trainer.domain.model

import java.time.LocalDate

/** Zonas de intensidad expresadas como % de la FC máxima. */
enum class HrZone(
    val label: String,
    val lowPct: Double,
    val highPct: Double,
    val purpose: String
) {
    Z1("Z1 Recuperación", 0.50, 0.60, "Regenerativo, deberías poder cantar"),
    Z2("Z2 Base aeróbica", 0.60, 0.70, "Podés mantener una conversación completa"),
    Z3("Z3 Tempo", 0.70, 0.80, "Cómodamente duro, frases cortas"),
    Z4("Z4 Umbral", 0.80, 0.90, "Duro, 2-3 palabras seguidas"),
    Z5("Z5 VO2 máx", 0.90, 1.00, "Máximo, sin hablar");

    fun bpmRange(maxHr: Int): IntRange = (lowPct * maxHr).toInt()..(highPct * maxHr).toInt()
}

enum class TrainingPhase(val label: String, val focus: String) {
    BASE("Base", "Construir volumen aeróbico y resistir sin fatiga"),
    BUILD("Construcción", "Sumar calidad: umbral, series y ritmo objetivo"),
    PEAK("Pico", "Máxima carga específica del evento"),
    TAPER("Afinamiento", "Bajar volumen, mantener intensidad, llegar fresco"),
    RACE("Evento", "Día de competencia")
}

enum class WorkoutType(
    val label: String,
    val zone: HrZone,
    /** Factor de intensidad para el cálculo de carga (tipo TRIMP simplificado). */
    val loadFactor: Double,
    val isQuality: Boolean
) {
    REST("Descanso", HrZone.Z1, 0.0, false),
    RECOVERY("Regenerativo", HrZone.Z1, 1.0, false),
    EASY("Rodaje suave", HrZone.Z2, 1.4, false),
    LONG("Fondo largo", HrZone.Z2, 1.6, false),
    TEMPO("Tempo", HrZone.Z3, 2.3, true),
    THRESHOLD("Umbral", HrZone.Z4, 2.8, true),
    INTERVALS("Series / VO2", HrZone.Z5, 3.4, true),
    HILLS("Cuestas", HrZone.Z4, 3.0, true),
    FARTLEK("Fartlek", HrZone.Z3, 2.4, true),
    RACE_PACE("Ritmo de carrera", HrZone.Z3, 2.6, true),
    BRICK("Brick (bici + carrera)", HrZone.Z3, 2.5, true),
    SWIM("Natación", HrZone.Z2, 1.8, false),
    STRENGTH("Fuerza", HrZone.Z2, 1.5, false),
    CROSS("Cross-training", HrZone.Z2, 1.3, false),
    RACE("Competencia", HrZone.Z4, 3.5, true)
}

/**
 * Una sesión planificada del calendario. [targetPaceLowSecPerKm] / [targetPaceHighSecPerKm]
 * son el rango de ritmo sugerido (segundos por km); nulos cuando no aplica.
 */
data class PlannedWorkout(
    val id: Long = 0L,
    val date: LocalDate,
    val sport: Sport,
    val type: WorkoutType,
    val title: String,
    val description: String,
    val durationMin: Int,
    val distanceKm: Double?,
    val targetPaceLowSecPerKm: Int?,
    val targetPaceHighSecPerKm: Int?,
    val phase: TrainingPhase,
    val weekNumber: Int,
    val estimatedKcal: Int,
    val fuelingTip: String,
    /** Hora prevista de la sesión (minuto del día), tomada de la agenda del usuario. */
    val scheduledMinuteOfDay: Int? = null,
    val completed: Boolean = false,
    val sessionId: Long? = null
) {
    val load: Double get() = durationMin * type.loadFactor
}

/** Resumen de una semana del plan, para las vistas de calendario. */
data class PlanWeek(
    val weekNumber: Int,
    val startDate: LocalDate,
    val phase: TrainingPhase,
    val workouts: List<PlannedWorkout>
) {
    val totalMinutes: Int get() = workouts.sumOf { it.durationMin }
    val totalKm: Double get() = workouts.sumOf { it.distanceKm ?: 0.0 }
    val totalLoad: Double get() = workouts.sumOf { it.load }
}

enum class LoadStatus(val label: String, val message: String) {
    DETRAINING("Baja carga", "Venís por debajo de tu carga habitual: podés sumar volumen con seguridad."),
    OPTIMAL("Carga óptima", "Tu progresión está en la zona segura de adaptación."),
    CAUTION("Carga alta", "Subiste rápido. Cuidá el sueño y sumá una sesión regenerativa."),
    RISK("Riesgo de lesión", "Aumento demasiado brusco. Bajá el volumen esta semana.")
}

data class TrainingLoadSummary(
    val acuteLoad: Double,
    val chronicLoad: Double,
    val ratio: Double,
    val status: LoadStatus,
    val weeklyLoads: List<Double>
)
