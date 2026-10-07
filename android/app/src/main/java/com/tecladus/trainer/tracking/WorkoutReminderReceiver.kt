package com.tecladus.trainer.tracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.model.WorkoutType
import java.time.LocalDate

/**
 * Recibe la alarma semanal y muestra el recordatorio con la sesión del día.
 * También reprograma todo después de un reinicio del teléfono.
 */
class WorkoutReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        ServiceLocator.init(context)
        val container = ServiceLocator.container

        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            ReminderScheduler.reschedule(context, container.profileRepository.profile.value)
            return
        }

        val pending = goAsync()
        Thread {
            try {
                TrainerNotifications.createChannels(context)
                val workout = container.database.queryPlanFor(LocalDate.now())
                if (workout != null && workout.type != WorkoutType.REST && !workout.completed) {
                    TrainerNotifications.showWorkoutReminder(context, workout)
                }
            } catch (e: Exception) {
                // Un recordatorio no debe poder tirar la app abajo.
            } finally {
                pending.finish()
            }
        }.start()
    }
}
