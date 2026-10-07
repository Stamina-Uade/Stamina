package com.tecladus.trainer.data.repository

import android.content.Context
import com.tecladus.trainer.data.weather.WeatherClient
import com.tecladus.trainer.domain.model.WeatherSnapshot
import com.tecladus.trainer.domain.model.WeatherStatus
import com.tecladus.trainer.tracking.LocationProvider
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Clima y ubicación, resueltos por la app sin preguntarle nada al usuario.
 * La lectura se cachea 20 minutos: alcanza para un entrenamiento y evita gastar batería.
 */
interface WeatherRepository {
    val weather: StateFlow<WeatherSnapshot?>
    val status: StateFlow<WeatherStatus>
    suspend fun refresh(force: Boolean = false)
}

class LocalWeatherRepository(private val context: Context) : WeatherRepository {

    private val _weather = MutableStateFlow<WeatherSnapshot?>(null)
    override val weather: StateFlow<WeatherSnapshot?> = _weather.asStateFlow()

    private val _status = MutableStateFlow(WeatherStatus.IDLE)
    override val status: StateFlow<WeatherStatus> = _status.asStateFlow()

    override suspend fun refresh(force: Boolean) {
        val cached = _weather.value
        val fresh = cached != null && System.currentTimeMillis() - cached.fetchedAtMs < CACHE_MS
        if (fresh && !force) {
            _status.value = WeatherStatus.READY
            return
        }
        if (!LocationProvider.hasPermission(context)) {
            _status.value = WeatherStatus.NO_PERMISSION
            return
        }
        _status.value = WeatherStatus.LOADING
        val location = LocationProvider.current(context)
        if (location == null) {
            _status.value = WeatherStatus.NO_LOCATION
            return
        }
        val snapshot = WeatherClient.fetch(context, location.latitude, location.longitude)
        if (snapshot == null) {
            // Sin red igual sirve la ubicación: el mapa se dibuja y el clima queda en el valor previo.
            _status.value = if (_weather.value != null) WeatherStatus.READY else WeatherStatus.ERROR
            return
        }
        _weather.value = snapshot
        _status.value = WeatherStatus.READY
    }

    private companion object {
        const val CACHE_MS = 20 * 60 * 1000L
    }
}
