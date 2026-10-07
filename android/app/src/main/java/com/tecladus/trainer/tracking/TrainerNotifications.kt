package com.tecladus.trainer.tracking

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.tecladus.trainer.MainActivity
import com.tecladus.trainer.R
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.domain.model.FuelAlert
import com.tecladus.trainer.domain.model.IntakeType
import com.tecladus.trainer.domain.model.LiveSessionState
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.formatMinuteOfDay

/** Canales y notificaciones de la app: sesión en curso y alertas de hidratación. */
object TrainerNotifications {

    const val CHANNEL_TRACKING = "tracking"
    const val CHANNEL_ALERTS = "fuel_alerts"
    const val CHANNEL_REMINDERS = "workout_reminders"
    const val NOTIFICATION_ID_TRACKING = 1001
    const val NOTIFICATION_ID_ALERT = 1002
    const val NOTIFICATION_ID_REMINDER = 1003

    fun createChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val tracking = NotificationChannel(
            CHANNEL_TRACKING,
            context.getString(R.string.channel_tracking_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = context.getString(R.string.channel_tracking_desc)
            setShowBadge(false)
        }
        val alerts = NotificationChannel(
            CHANNEL_ALERTS,
            context.getString(R.string.channel_alerts_name),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = context.getString(R.string.channel_alerts_desc)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 350, 200, 350)
        }
        val reminders = NotificationChannel(
            CHANNEL_REMINDERS,
            context.getString(R.string.channel_reminders_name),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = context.getString(R.string.channel_reminders_desc)
            enableVibration(true)
        }
        manager.createNotificationChannel(tracking)
        manager.createNotificationChannel(alerts)
        manager.createNotificationChannel(reminders)
    }

    private fun contentIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun trackingNotification(context: Context, state: LiveSessionState): Notification {
        val title = "${Formatters.distance(state.distanceKm)} · ${Formatters.duration(state.elapsedSec)}"
        val plan = state.hydrationPlan
        val text = if (plan != null) {
            "Ritmo ${Formatters.pace(state.avgPaceSecPerKm)} · Tomaste ${state.fluidTakenMl} de " +
                "${(plan.fluidPerHourMl * state.elapsedSec / 3600.0).toInt()} ml previstos"
        } else {
            "Ritmo ${Formatters.pace(state.avgPaceSecPerKm)} · ${state.kcal} kcal"
        }
        return NotificationCompat.Builder(context, CHANNEL_TRACKING)
            .setSmallIcon(R.drawable.ic_run)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentIntent(context))
            .build()
    }

    fun showFuelAlert(context: Context, alert: FuelAlert) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val icon = when (alert.type) {
            IntakeType.WATER, IntakeType.ISOTONIC -> R.drawable.ic_water
            IntakeType.SALT -> R.drawable.ic_salt
            IntakeType.GEL -> R.drawable.ic_gel
            IntakeType.SOLID -> R.drawable.ic_food
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setSmallIcon(icon)
            .setContentTitle(alert.title)
            .setContentText(alert.message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(alert.message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 350, 200, 350))
            .setContentIntent(contentIntent(context))
            .build()
        manager.notify(NOTIFICATION_ID_ALERT, notification)
    }

    /** Recordatorio de la sesión del día, con su plan de hidratación resumido. */
    fun showWorkoutReminder(context: Context, workout: PlannedWorkout) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val hora = workout.scheduledMinuteOfDay?.let { " a las ${formatMinuteOfDay(it)}" } ?: ""
        val text = "${workout.title}. ${workout.fuelingTip}"
        val notification = NotificationCompat.Builder(context, CHANNEL_REMINDERS)
            .setSmallIcon(R.drawable.ic_calendar)
            .setContentTitle("Hoy$hora entrenás")
            .setContentText(workout.title)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(contentIntent(context))
            .build()
        manager.notify(NOTIFICATION_ID_REMINDER, notification)
    }

    fun cancelAll(context: Context) {
        context.getSystemService(NotificationManager::class.java)?.cancelAll()
    }
}
