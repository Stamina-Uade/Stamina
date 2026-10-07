package com.tecladus.trainer.domain.model

import java.time.DayOfWeek
import java.time.LocalDate

enum class Sex(val label: String) {
    MALE("Masculino"),
    FEMALE("Femenino")
}

enum class FitnessLevel(val label: String, val description: String) {
    BEGINNER("Principiante", "Menos de 6 meses entrenando de forma regular"),
    INTERMEDIATE("Intermedio", "Entrenás hace más de 1 año y ya corriste/competiste"),
    ADVANCED("Avanzado", "Varias temporadas de entrenamiento estructurado")
}

enum class Sport(val label: String, val iconRes: String) {
    RUNNING("Running", "ic_run"),
    CYCLING("Ciclismo", "ic_bike"),
    TREKKING("Trekking", "ic_mountain"),
    TRIATHLON("Triatlón", "ic_swim"),
    SWIMMING("Natación", "ic_swim"),
    STRENGTH("Fuerza", "ic_heart"),
    OTHER("Otro", "ic_heart");

    val isGpsBased: Boolean
        get() = this == RUNNING || this == CYCLING || this == TREKKING || this == TRIATHLON
}

/**
 * Concentración de sodio en el sudor. Se usa para calcular cuántos mg de sodio
 * hay que reponer por litro perdido (rango de referencia: 200-2000 mg/L).
 */
enum class SweatSaltiness(val label: String, val sodiumMgPerLiter: Int, val hint: String) {
    LOW("Poco salado", 400, "Casi no quedan marcas blancas en la ropa"),
    MEDIUM("Normal", 700, "Alguna marca blanca ocasional"),
    HIGH("Muy salado", 1100, "Marcas blancas en gorra/remera, ardor en los ojos")
}

enum class BodyGoal(val label: String) {
    LOSE_FAT("Bajar grasa"),
    MAINTAIN("Mantener peso"),
    GAIN_MUSCLE("Ganar masa muscular")
}

/**
 * Objetivo deportivo. La distancia se usa para predecir ritmos y para dimensionar
 * el volumen semanal del plan.
 */
enum class GoalType(
    val label: String,
    val sport: Sport,
    val distanceKm: Double,
    val minWeeks: Int
) {
    RACE_5K("5K", Sport.RUNNING, 5.0, 4),
    RACE_10K("10K", Sport.RUNNING, 10.0, 6),
    RACE_21K("Media maratón (21K)", Sport.RUNNING, 21.097, 8),
    RACE_42K("Maratón (42K)", Sport.RUNNING, 42.195, 12),
    CYCLING_100K("Ciclismo 100K", Sport.CYCLING, 100.0, 6),
    CYCLING_GRANFONDO("Gran fondo (160K+)", Sport.CYCLING, 160.0, 10),
    TREKKING_LONG("Trekking de montaña", Sport.TREKKING, 20.0, 6),
    TRIATHLON_SPRINT("Triatlón sprint", Sport.TRIATHLON, 25.75, 8),
    TRIATHLON_OLYMPIC("Triatlón olímpico", Sport.TRIATHLON, 51.5, 12),
    GENERAL_FITNESS("Estado físico general", Sport.RUNNING, 10.0, 4);

    /** Duración estimada del evento en minutos, según nivel, para dimensionar la nutrición en carrera. */
    fun estimatedEventMinutes(level: FitnessLevel): Int = when (this) {
        RACE_5K -> when (level) { FitnessLevel.BEGINNER -> 35; FitnessLevel.INTERMEDIATE -> 27; FitnessLevel.ADVANCED -> 21 }
        RACE_10K -> when (level) { FitnessLevel.BEGINNER -> 72; FitnessLevel.INTERMEDIATE -> 55; FitnessLevel.ADVANCED -> 43 }
        RACE_21K -> when (level) { FitnessLevel.BEGINNER -> 160; FitnessLevel.INTERMEDIATE -> 122; FitnessLevel.ADVANCED -> 95 }
        RACE_42K -> when (level) { FitnessLevel.BEGINNER -> 330; FitnessLevel.INTERMEDIATE -> 255; FitnessLevel.ADVANCED -> 200 }
        CYCLING_100K -> when (level) { FitnessLevel.BEGINNER -> 260; FitnessLevel.INTERMEDIATE -> 210; FitnessLevel.ADVANCED -> 170 }
        CYCLING_GRANFONDO -> when (level) { FitnessLevel.BEGINNER -> 420; FitnessLevel.INTERMEDIATE -> 340; FitnessLevel.ADVANCED -> 280 }
        TREKKING_LONG -> when (level) { FitnessLevel.BEGINNER -> 360; FitnessLevel.INTERMEDIATE -> 300; FitnessLevel.ADVANCED -> 240 }
        TRIATHLON_SPRINT -> when (level) { FitnessLevel.BEGINNER -> 100; FitnessLevel.INTERMEDIATE -> 80; FitnessLevel.ADVANCED -> 65 }
        TRIATHLON_OLYMPIC -> when (level) { FitnessLevel.BEGINNER -> 200; FitnessLevel.INTERMEDIATE -> 165; FitnessLevel.ADVANCED -> 130 }
        GENERAL_FITNESS -> 60
    }
}

/**
 * Perfil del usuario. Es la entrada de todos los cálculos: plan, nutrición e hidratación.
 */
data class UserProfile(
    val name: String = "",
    val sex: Sex = Sex.MALE,
    val age: Int = 30,
    val weightKg: Double = 70.0,
    val heightCm: Double = 175.0,
    val level: FitnessLevel = FitnessLevel.BEGINNER,
    val primarySport: Sport = Sport.RUNNING,
    val goal: GoalType = GoalType.RACE_10K,
    val eventDate: LocalDate? = null,
    /**
     * Agenda real de la persona: qué días puede entrenar y a qué hora (minuto del día).
     * Con esto se arma la semana del plan y se programan los recordatorios.
     */
    val trainingSchedule: Map<DayOfWeek, Int> = defaultSchedule(),
    val sweatSaltiness: SweatSaltiness = SweatSaltiness.MEDIUM,
    /** Tasa de sudoración medida por el usuario (L/h). Si existe, tiene prioridad sobre la estimación. */
    val measuredSweatRateLh: Double? = null,
    val restingHr: Int? = null,
    val maxHrOverride: Int? = null,
    /** Marca de referencia para predecir ritmos (Riegel). */
    val referenceDistanceKm: Double? = null,
    val referenceTimeMinutes: Double? = null,
    val bodyGoal: BodyGoal = BodyGoal.MAINTAIN,
    /** 1 = estómago sensible, 2 = normal, 3 = intestino entrenado (tolera 90 g CHO/h). */
    val gutTrainingLevel: Int = 2,
    val onboardingCompleted: Boolean = false
) {
    val trainingDaysPerWeek: Int get() = trainingSchedule.size

    val bmi: Double get() = if (heightCm > 0) weightKg / ((heightCm / 100.0) * (heightCm / 100.0)) else 0.0

    /** Días ordenados de lunes a domingo. */
    val trainingDays: List<DayOfWeek> get() = trainingSchedule.keys.sortedBy { it.value }

    fun timeFor(day: DayOfWeek): Int? = trainingSchedule[day]

    /** FC máxima estimada con la fórmula de Tanaka (208 - 0,7 x edad), más precisa que 220 - edad. */
    val maxHr: Int get() = maxHrOverride ?: (208 - 0.7 * age).toInt()

    fun daysToEvent(today: LocalDate): Long? =
        eventDate?.let { java.time.temporal.ChronoUnit.DAYS.between(today, it) }
}

/** Agenda por defecto: martes y jueves a la tarde, domingo a la mañana. */
fun defaultSchedule(): Map<DayOfWeek, Int> = linkedMapOf(
    DayOfWeek.TUESDAY to 18 * 60,
    DayOfWeek.THURSDAY to 18 * 60,
    DayOfWeek.SUNDAY to 9 * 60
)

/** Nombre del día en español, para la UI. */
fun DayOfWeek.esLabel(): String = when (this) {
    DayOfWeek.MONDAY -> "Lunes"
    DayOfWeek.TUESDAY -> "Martes"
    DayOfWeek.WEDNESDAY -> "Miércoles"
    DayOfWeek.THURSDAY -> "Jueves"
    DayOfWeek.FRIDAY -> "Viernes"
    DayOfWeek.SATURDAY -> "Sábado"
    DayOfWeek.SUNDAY -> "Domingo"
}

fun DayOfWeek.esShort(): String = esLabel().take(3)

/** Formatea un minuto del día como "18:30". */
fun formatMinuteOfDay(minuteOfDay: Int): String {
    val h = (minuteOfDay / 60).coerceIn(0, 23)
    val m = minuteOfDay % 60
    return "%02d:%02d".format(h, m)
}
