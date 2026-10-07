package com.tecladus.trainer

import android.app.Application
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.tracking.TrainerNotifications

class TrainerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ServiceLocator.init(this)
        TrainerNotifications.createChannels(this)
    }
}
