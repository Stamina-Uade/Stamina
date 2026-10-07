package com.tecladus.trainer.core

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

/** Formateo consistente de métricas y fechas en toda la app (es-AR). */
object Formatters {

    private val locale: Locale = Locale.forLanguageTag("es-AR")
    private val dayMonthFormatter = DateTimeFormatter.ofPattern("d MMM", Locale.forLanguageTag("es-AR"))
    private val fullDateFormatter = DateTimeFormatter.ofPattern("EEEE d 'de' MMMM", Locale.forLanguageTag("es-AR"))

    fun duration(seconds: Int): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return if (h > 0) String.format(locale, "%d:%02d:%02d", h, m, s)
        else String.format(locale, "%02d:%02d", m, s)
    }

    fun durationShort(minutes: Int): String {
        val h = minutes / 60
        val m = minutes % 60
        return if (h > 0) "${h}h ${m}min" else "${m} min"
    }

    fun distance(km: Double): String = String.format(locale, "%.2f km", km)

    fun distanceShort(km: Double): String =
        if (km >= 10) String.format(locale, "%.0f km", km) else String.format(locale, "%.1f km", km)

    fun pace(secPerKm: Int): String =
        if (secPerKm <= 0) "--:--" else String.format(locale, "%d:%02d", secPerKm / 60, secPerKm % 60)

    fun speed(kmh: Double): String = String.format(locale, "%.1f km/h", kmh)

    fun decimal(value: Double, decimals: Int = 1): String = String.format(locale, "%.${decimals}f", value)

    fun date(date: LocalDate): String = date.format(dayMonthFormatter)

    fun fullDate(date: LocalDate): String = date.format(fullDateFormatter).replaceFirstChar { it.uppercase() }

    fun dayName(date: LocalDate): String =
        date.dayOfWeek.getDisplayName(TextStyle.SHORT, locale).replaceFirstChar { it.uppercase() }.take(3)

    fun relativeDay(date: LocalDate, today: LocalDate = LocalDate.now()): String = when (date) {
        today -> "Hoy"
        today.plusDays(1) -> "Mañana"
        today.minusDays(1) -> "Ayer"
        else -> fullDate(date)
    }
}
