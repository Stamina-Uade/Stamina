package com.tecladus.trainer.data.weather

import android.content.Context
import android.location.Geocoder
import com.tecladus.trainer.domain.model.WeatherSnapshot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/**
 * Clima actual desde Open-Meteo.
 *
 * Se eligió esta API porque es gratuita y **no necesita clave**: la app funciona recién
 * instalada, sin que nadie tenga que registrar credenciales. Sin red, el llamado falla
 * y la pantalla sigue funcionando con los valores por defecto.
 */
object WeatherClient {

    private const val ENDPOINT = "https://api.open-meteo.com/v1/forecast"

    suspend fun fetch(context: Context, latitude: Double, longitude: Double): WeatherSnapshot? =
        withContext(Dispatchers.IO) {
            val url = URL(
                "$ENDPOINT?latitude=${"%.4f".format(Locale.US, latitude)}" +
                    "&longitude=${"%.4f".format(Locale.US, longitude)}" +
                    "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day," +
                    "weather_code,wind_speed_10m,uv_index&timezone=auto"
            )
            val connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 8000
                readTimeout = 8000
                setRequestProperty("User-Agent", "Trainer/1.0 (Android)")
            }
            try {
                if (connection.responseCode !in 200..299) return@withContext null
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                val current = JSONObject(body).optJSONObject("current") ?: return@withContext null
                WeatherSnapshot(
                    tempC = current.optDouble("temperature_2m", 20.0),
                    humidityPct = current.optDouble("relative_humidity_2m", 55.0),
                    apparentC = current.optDouble("apparent_temperature", current.optDouble("temperature_2m", 20.0)),
                    windKmh = current.optDouble("wind_speed_10m", 0.0),
                    uvIndex = current.optDouble("uv_index", 0.0),
                    isDay = current.optInt("is_day", 1) == 1,
                    weatherCode = current.optInt("weather_code", 0),
                    place = placeName(context, latitude, longitude),
                    latitude = latitude,
                    longitude = longitude,
                    fetchedAtMs = System.currentTimeMillis()
                )
            } catch (e: Exception) {
                null
            } finally {
                connection.disconnect()
            }
        }

    /** Nombre del barrio o ciudad, sólo para mostrar de dónde salen los datos. */
    private fun placeName(context: Context, latitude: Double, longitude: Double): String? = try {
        @Suppress("DEPRECATION")
        val results = Geocoder(context, Locale("es", "AR")).getFromLocation(latitude, longitude, 1)
        val address = results?.firstOrNull()
        address?.locality ?: address?.subAdminArea ?: address?.adminArea
    } catch (e: Exception) {
        null
    }
}
