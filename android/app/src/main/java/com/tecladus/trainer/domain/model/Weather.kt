package com.tecladus.trainer.domain.model

/** Lectura del clima en el momento y lugar donde va a entrenar la persona. */
data class WeatherSnapshot(
    val tempC: Double,
    val humidityPct: Double,
    val apparentC: Double,
    val windKmh: Double,
    val uvIndex: Double,
    val isDay: Boolean,
    val weatherCode: Int,
    val place: String?,
    val latitude: Double,
    val longitude: Double,
    val fetchedAtMs: Long
) {
    /** Se considera "bajo sol" si es de día y el cielo está despejado o poco nublado. */
    fun toConditions(): WeatherConditions =
        WeatherConditions(tempC = tempC, humidityPct = humidityPct, underSun = isDay && weatherCode <= 2)

    val isRaining: Boolean get() = weatherCode in 51..67 || weatherCode in 80..82 || weatherCode in 95..99

    val description: String
        get() = when (weatherCode) {
            0 -> "Despejado"
            1 -> "Mayormente despejado"
            2 -> "Parcialmente nublado"
            3 -> "Nublado"
            45, 48 -> "Niebla"
            51, 53, 55 -> "Llovizna"
            56, 57 -> "Llovizna helada"
            61, 63, 65 -> "Lluvia"
            66, 67 -> "Lluvia helada"
            71, 73, 75, 77 -> "Nieve"
            80, 81, 82 -> "Chaparrones"
            85, 86 -> "Chaparrones de nieve"
            95 -> "Tormenta"
            96, 99 -> "Tormenta con granizo"
            else -> "Sin datos"
        }
}

/** Estado de la lectura automática, para que la pantalla nunca se quede en blanco. */
enum class WeatherStatus {
    IDLE,
    LOADING,
    READY,
    NO_PERMISSION,
    NO_LOCATION,
    ERROR
}

enum class RiskLevel(val label: String) {
    GOOD("Buenas condiciones"),
    MODERATE("Precaución"),
    HIGH("Riesgo alto"),
    EXTREME("No conviene salir")
}

/**
 * Evaluación de las condiciones para entrenar al aire libre.
 * [advice] es la recomendación concreta; [adjustments] son los cambios sugeridos al plan.
 */
data class SafetyAssessment(
    val level: RiskLevel,
    val headline: String,
    val advice: String,
    val heatIndexC: Double,
    val adjustments: List<String>
) {
    val blocksTraining: Boolean get() = level == RiskLevel.EXTREME
}
