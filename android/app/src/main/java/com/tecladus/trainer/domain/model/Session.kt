package com.tecladus.trainer.domain.model

/** Un punto del recorrido registrado por el GPS. */
data class TrackPoint(
    val timestampMs: Long,
    val latitude: Double,
    val longitude: Double,
    val altitudeM: Double,
    val speedMps: Double,
    val accuracyM: Float
)

/** Parcial por kilómetro (o por unidad de distancia) de una sesión. */
data class Split(
    val index: Int,
    val distanceM: Double,
    val durationSec: Int,
    val elevationGainM: Double
) {
    val paceSecPerKm: Int
        get() = if (distanceM > 0) (durationSec / (distanceM / 1000.0)).toInt() else 0
}

enum class IntakeType(val label: String, val iconRes: String) {
    WATER("Agua", "ic_water"),
    ISOTONIC("Bebida deportiva", "ic_water"),
    SALT("Sales / electrolitos", "ic_salt"),
    GEL("Gel / CHO", "ic_gel"),
    SOLID("Sólido", "ic_food")
}

/** Registro de una ingesta durante el esfuerzo (lo que efectivamente tomó el usuario). */
data class IntakeEvent(
    val id: Long = 0L,
    val sessionId: Long,
    val timestampMs: Long,
    val type: IntakeType,
    val fluidMl: Int = 0,
    val sodiumMg: Int = 0,
    val carbsG: Int = 0,
    val note: String = ""
)

/** Sesión de entrenamiento finalizada y guardada. */
data class ActivitySession(
    val id: Long = 0L,
    val sport: Sport,
    val startTimeMs: Long,
    val endTimeMs: Long,
    val elapsedSec: Int,
    val movingSec: Int,
    val distanceM: Double,
    val elevationGainM: Double,
    val kcal: Int,
    val avgHr: Int? = null,
    val perceivedEffort: Int = 5,
    val tempC: Double = 20.0,
    val humidityPct: Double = 50.0,
    val plannedWorkoutId: Long? = null,
    val plannedType: WorkoutType? = null,
    val fluidMl: Int = 0,
    val sodiumMg: Int = 0,
    val carbsG: Int = 0,
    val plannedFluidMl: Int = 0,
    val plannedSodiumMg: Int = 0,
    val plannedCarbsG: Int = 0,
    val title: String = "",
    val notes: String = ""
) {
    val distanceKm: Double get() = distanceM / 1000.0
    val avgPaceSecPerKm: Int get() = if (distanceM > 200) (movingSec / (distanceM / 1000.0)).toInt() else 0
    val avgSpeedKmh: Double get() = if (movingSec > 0) distanceKm / (movingSec / 3600.0) else 0.0
    val durationMin: Int get() = elapsedSec / 60
    val load: Double get() = durationMin * (plannedType?.loadFactor ?: (perceivedEffort / 3.0))
    /** % del plan de hidratación efectivamente cumplido. */
    val hydrationCompliance: Double get() = if (plannedFluidMl > 0) (fluidMl.toDouble() / plannedFluidMl).coerceIn(0.0, 1.5) else 0.0
    val carbsCompliance: Double get() = if (plannedCarbsG > 0) (carbsG.toDouble() / plannedCarbsG).coerceIn(0.0, 1.5) else 0.0
}

/** Estado de la sesión en curso (lo que observa la pantalla en vivo). */
enum class TrackingState { IDLE, RUNNING, PAUSED, FINISHED }

data class LiveSessionState(
    val state: TrackingState = TrackingState.IDLE,
    val sport: Sport = Sport.RUNNING,
    val startTimeMs: Long = 0L,
    val elapsedSec: Int = 0,
    val movingSec: Int = 0,
    val distanceM: Double = 0.0,
    val elevationGainM: Double = 0.0,
    val currentPaceSecPerKm: Int = 0,
    val avgPaceSecPerKm: Int = 0,
    val currentSpeedKmh: Double = 0.0,
    val kcal: Int = 0,
    val points: List<TrackPoint> = emptyList(),
    val splits: List<Split> = emptyList(),
    val intakes: List<IntakeEvent> = emptyList(),
    val hydrationPlan: HydrationPlan? = null,
    val plannedWorkoutId: Long? = null,
    val plannedType: WorkoutType? = null,
    val gpsAccuracyM: Float = 0f,
    val hasGpsFix: Boolean = false,
    val pendingAlert: FuelAlert? = null
) {
    val distanceKm: Double get() = distanceM / 1000.0
    val fluidTakenMl: Int get() = intakes.sumOf { it.fluidMl }
    val sodiumTakenMg: Int get() = intakes.sumOf { it.sodiumMg }
    val carbsTakenG: Int get() = intakes.sumOf { it.carbsG }

    /** Litros de sudor estimados hasta el momento, según el plan de hidratación. */
    fun estimatedSweatLossMl(): Int {
        val plan = hydrationPlan ?: return 0
        return (plan.sweatRateLh * 1000.0 * (elapsedSec / 3600.0)).toInt()
    }

    /** Déficit de líquido = lo que debería haber tomado hasta ahora menos lo que tomó. */
    fun fluidDeficitMl(): Int {
        val plan = hydrationPlan ?: return 0
        val expected = (plan.fluidPerHourMl * (elapsedSec / 3600.0)).toInt()
        return expected - fluidTakenMl
    }

    fun carbsDeficitG(): Int {
        val plan = hydrationPlan ?: return 0
        val expected = (plan.carbsPerHourG * (elapsedSec / 3600.0)).toInt()
        return expected - carbsTakenG
    }
}

/** Alerta disparada por el motor de hidratación/nutrición durante la sesión. */
data class FuelAlert(
    val type: IntakeType,
    val title: String,
    val message: String,
    val suggestedFluidMl: Int,
    val suggestedSodiumMg: Int,
    val suggestedCarbsG: Int,
    val triggeredAtSec: Int
)
