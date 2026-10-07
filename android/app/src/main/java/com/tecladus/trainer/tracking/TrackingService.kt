package com.tecladus.trainer.tracking

import android.Manifest
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat
import com.tecladus.trainer.core.ServiceLocator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Servicio en primer plano que mantiene vivo el GPS y el reloj de la sesión aunque
 * la pantalla esté apagada, y que dispara las notificaciones de hidratación.
 */
class TrackingService : Service() {

    companion object {
        const val ACTION_START = "com.tecladus.trainer.START"
        const val ACTION_PAUSE = "com.tecladus.trainer.PAUSE"
        const val ACTION_RESUME = "com.tecladus.trainer.RESUME"
        const val ACTION_STOP = "com.tecladus.trainer.STOP"

        fun send(context: Context, action: String) {
            val intent = Intent(context, TrackingService::class.java).setAction(action)
            if (action == ACTION_START) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var tickerJob: Job? = null
    private var locationManager: LocationManager? = null
    private val manager by lazy { ServiceLocator.container.trackingManager }

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            manager.onLocation(location)
        }

        @Deprecated("Requerido por compatibilidad con versiones anteriores")
        override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) = Unit

        override fun onProviderEnabled(provider: String) = Unit
        override fun onProviderDisabled(provider: String) = Unit
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        TrainerNotifications.createChannels(this)
        scope.launch {
            manager.alerts.collect { alert ->
                TrainerNotifications.showFuelAlert(this@TrackingService, alert)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startTracking()
            ACTION_PAUSE -> {
                manager.pause()
                updateNotification()
            }
            ACTION_RESUME -> {
                manager.resume()
                updateNotification()
            }
            ACTION_STOP -> stopTracking()
            else -> Unit
        }
        return START_STICKY
    }

    private fun startTracking() {
        val notification = TrainerNotifications.trackingNotification(this, manager.state.value)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                TrainerNotifications.NOTIFICATION_ID_TRACKING,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(TrainerNotifications.NOTIFICATION_ID_TRACKING, notification)
        }
        manager.start()
        requestLocationUpdates()
        startTicker()
    }

    private fun requestLocationUpdates() {
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) return
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
        locationManager = lm
        try {
            if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, 1000L, 0f, locationListener, Looper.getMainLooper()
                )
            }
            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER, 3000L, 0f, locationListener, Looper.getMainLooper()
                )
            }
        } catch (e: SecurityException) {
            // Sin permiso de ubicación la sesión igual corre, pero sin distancia ni ruta.
        }
    }

    private fun startTicker() {
        tickerJob?.cancel()
        tickerJob = scope.launch {
            var counter = 0
            while (true) {
                delay(1000)
                manager.tick()
                counter++
                if (counter % 3 == 0) updateNotification()
            }
        }
    }

    private fun updateNotification() {
        val notification = TrainerNotifications.trackingNotification(this, manager.state.value)
        val nm = getSystemService(android.app.NotificationManager::class.java)
        nm?.notify(TrainerNotifications.NOTIFICATION_ID_TRACKING, notification)
    }

    private fun stopTracking() {
        tickerJob?.cancel()
        try {
            locationManager?.removeUpdates(locationListener)
        } catch (e: SecurityException) {
            // ignorado
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        tickerJob?.cancel()
        try {
            locationManager?.removeUpdates(locationListener)
        } catch (e: SecurityException) {
            // ignorado
        }
        scope.cancel()
        super.onDestroy()
    }
}
