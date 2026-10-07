package com.tecladus.trainer.tracking

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.tecladus.trainer.domain.model.UserProfile
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Programa los recordatorios semanales según la agenda que cargó la persona.
 *
 * Se avisa [LEAD_MINUTES] minutos antes de la hora elegida, que es cuando todavía se llega
 * a preparar la hidratación y la comida previa. Se usan alarmas inexactas (setRepeating)
 * para no necesitar el permiso de alarmas exactas de Android 12+.
 */
object ReminderScheduler {

    private const val LEAD_MINUTES = 60
    const val ACTION_REMINDER = "com.tecladus.trainer.WORKOUT_REMINDER"
    private const val WEEK_MILLIS = 7L * 24 * 60 * 60 * 1000

    fun reschedule(context: Context, profile: UserProfile) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        // Se cancelan todas y se vuelven a crear sólo las de los días elegidos.
        DayOfWeek.entries.forEach { day ->
            alarmManager.cancel(pendingIntent(context, day))
        }
        profile.trainingSchedule.forEach { (day, minuteOfDay) ->
            val triggerAt = nextTriggerMillis(day, minuteOfDay)
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                WEEK_MILLIS,
                pendingIntent(context, day)
            )
        }
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        DayOfWeek.entries.forEach { day -> alarmManager.cancel(pendingIntent(context, day)) }
    }

    /** Próxima ocurrencia de ese día de la semana a la hora indicada, menos el margen de aviso. */
    private fun nextTriggerMillis(day: DayOfWeek, minuteOfDay: Int): Long {
        val zone = ZoneId.systemDefault()
        val now = LocalDateTime.now(zone)
        val reminderMinute = (minuteOfDay - LEAD_MINUTES).coerceAtLeast(0)
        var candidate = now
            .withHour(reminderMinute / 60)
            .withMinute(reminderMinute % 60)
            .withSecond(0)
            .withNano(0)
        val daysAhead = (day.value - candidate.dayOfWeek.value + 7) % 7
        candidate = candidate.plusDays(daysAhead.toLong())
        if (!candidate.isAfter(now)) candidate = candidate.plusWeeks(1)
        return candidate.atZone(zone).toInstant().toEpochMilli()
    }

    private fun pendingIntent(context: Context, day: DayOfWeek): PendingIntent {
        val intent = Intent(context, WorkoutReminderReceiver::class.java).setAction(ACTION_REMINDER)
        return PendingIntent.getBroadcast(
            context,
            day.value,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
