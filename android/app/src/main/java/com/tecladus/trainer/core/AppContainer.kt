package com.tecladus.trainer.core

import android.content.Context
import com.tecladus.trainer.data.local.ProfileStore
import com.tecladus.trainer.data.local.TrainerDatabase
import com.tecladus.trainer.data.repository.LocalNutritionRepository
import com.tecladus.trainer.data.repository.LocalPlanRepository
import com.tecladus.trainer.data.repository.LocalProfileRepository
import com.tecladus.trainer.data.repository.LocalSessionRepository
import com.tecladus.trainer.data.repository.LocalWeatherRepository
import com.tecladus.trainer.data.repository.NutritionRepository
import com.tecladus.trainer.data.repository.PlanRepository
import com.tecladus.trainer.data.repository.ProfileRepository
import com.tecladus.trainer.data.repository.SessionRepository
import com.tecladus.trainer.data.repository.WeatherRepository
import com.tecladus.trainer.tracking.TrackingManager

/**
 * Contenedor de dependencias hecho a mano (equivalente liviano a Hilt).
 *
 * La UI depende únicamente de las interfaces de repositorio, así que cambiar la
 * implementación local por una remota (Firebase o API propia) no toca las pantallas.
 */
class AppContainer(context: Context) {

    private val appContext = context.applicationContext
    val database: TrainerDatabase by lazy { TrainerDatabase(appContext) }
    private val profileStore by lazy { ProfileStore(appContext) }

    val profileRepository: ProfileRepository by lazy { LocalProfileRepository(profileStore) }
    val planRepository: PlanRepository by lazy { LocalPlanRepository(database) }
    val sessionRepository: SessionRepository by lazy { LocalSessionRepository(database) }
    val nutritionRepository: NutritionRepository by lazy { LocalNutritionRepository(database) }
    val weatherRepository: WeatherRepository by lazy { LocalWeatherRepository(appContext) }
    val trackingManager: TrackingManager by lazy { TrackingManager() }
}

/** Punto de acceso único al contenedor, inicializado en [com.tecladus.trainer.TrainerApplication]. */
object ServiceLocator {

    @Volatile
    private var instance: AppContainer? = null

    fun init(context: Context) {
        if (instance == null) {
            synchronized(this) {
                if (instance == null) instance = AppContainer(context.applicationContext)
            }
        }
    }

    val container: AppContainer
        get() = instance ?: error("ServiceLocator no inicializado: llamá a init() en Application.onCreate()")
}
