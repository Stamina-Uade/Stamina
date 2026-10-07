package com.tecladus.trainer.domain.model

/** Condiciones ambientales de la sesión: impactan directo en la tasa de sudoración. */
data class WeatherConditions(
    val tempC: Double = 22.0,
    val humidityPct: Double = 55.0,
    val underSun: Boolean = true
)

enum class EffortIntensity(val label: String, val factor: Double, val description: String) {
    EASY("Suave", 0.78, "Podés hablar sin cortarte"),
    MODERATE("Moderado", 1.0, "Ritmo cómodo-duro sostenido"),
    HARD("Fuerte", 1.25, "Series o tempo exigente"),
    RACE("Competencia", 1.4, "Ritmo de carrera, al límite")
}

/**
 * Plan de hidratación y combustible calculado para una sesión concreta.
 * Todos los valores son "por hora" salvo los que indican bolo/intervalo.
 */
data class HydrationPlan(
    val sport: Sport,
    val intensity: EffortIntensity,
    val weather: WeatherConditions,
    val expectedDurationMin: Int,
    /** Tasa de sudoración estimada o medida, en litros por hora. */
    val sweatRateLh: Double,
    val fluidPerHourMl: Int,
    val fluidBolusMl: Int,
    val fluidIntervalMin: Int,
    val sodiumPerHourMg: Int,
    val sodiumBolusMg: Int,
    val sodiumIntervalMin: Int,
    val carbsPerHourG: Int,
    val carbsBolusG: Int,
    val carbsIntervalMin: Int,
    val preSessionFluidMl: Int,
    val preSessionCarbsG: Int,
    val postSessionFluidMl: Int,
    val postSessionCarbsG: Int,
    val postSessionProteinG: Int,
    val notes: List<String>
) {
    val totalFluidMl: Int get() = (fluidPerHourMl * expectedDurationMin / 60.0).toInt()
    val totalSodiumMg: Int get() = (sodiumPerHourMg * expectedDurationMin / 60.0).toInt()
    val totalCarbsG: Int get() = (carbsPerHourG * expectedDurationMin / 60.0).toInt()
    val expectedSweatLossMl: Int get() = (sweatRateLh * 1000 * expectedDurationMin / 60.0).toInt()
    /** % del peso corporal que se perdería sin reponer nada. */
    fun dehydrationPctIfNoIntake(weightKg: Double): Double =
        if (weightKg > 0) expectedSweatLossMl / 10.0 / weightKg else 0.0
}

/** Una entrada de la agenda de avisos de la sesión (minuto -> qué tomar). */
data class FuelScheduleItem(
    val atMinute: Int,
    val type: IntakeType,
    val fluidMl: Int,
    val sodiumMg: Int,
    val carbsG: Int,
    val message: String
)
