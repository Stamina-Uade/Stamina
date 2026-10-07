package com.tecladus.trainer.tracking

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * Ubicación puntual del usuario, sin depender de Play Services.
 *
 * Primero se intenta con la última posición conocida (instantánea); si no hay o está
 * vieja, se pide una única actualización con tiempo límite para no dejar la pantalla
 * esperando.
 */
object LocationProvider {

    private const val MAX_AGE_MS = 10 * 60 * 1000L

    fun hasPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    suspend fun current(context: Context, timeoutMs: Long = 8000): Location? {
        if (!hasPermission(context)) return null
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null

        val cached = lastKnown(manager)
        if (cached != null && System.currentTimeMillis() - cached.time < MAX_AGE_MS) return cached

        val fresh = withTimeoutOrNull(timeoutMs) { singleUpdate(context, manager) }
        return fresh ?: cached
    }

    private fun lastKnown(manager: LocationManager): Location? {
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
        var best: Location? = null
        for (provider in providers) {
            val location = try {
                manager.getLastKnownLocation(provider)
            } catch (e: SecurityException) {
                null
            } catch (e: IllegalArgumentException) {
                null
            }
            if (location != null && (best == null || location.time > best.time)) best = location
        }
        return best
    }

    private suspend fun singleUpdate(context: Context, manager: LocationManager): Location? =
        withContext(Dispatchers.Main) {
            suspendCancellableCoroutine { continuation ->
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        try {
                            manager.removeUpdates(this)
                        } catch (e: SecurityException) {
                            // ignorado
                        }
                        if (continuation.isActive) continuation.resume(location)
                    }

                    @Deprecated("Requerido por compatibilidad con versiones anteriores")
                    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) = Unit

                    override fun onProviderEnabled(provider: String) = Unit
                    override fun onProviderDisabled(provider: String) = Unit
                }
                val provider = when {
                    manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                    manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                    else -> null
                }
                if (provider == null) {
                    if (continuation.isActive) continuation.resume(null)
                    return@suspendCancellableCoroutine
                }
                try {
                    manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
                } catch (e: SecurityException) {
                    if (continuation.isActive) continuation.resume(null)
                }
                continuation.invokeOnCancellation {
                    try {
                        manager.removeUpdates(listener)
                    } catch (e: SecurityException) {
                        // ignorado
                    }
                }
            }
        }
}
