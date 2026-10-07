package com.tecladus.trainer.ui.navigation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.tecladus.trainer.domain.model.MealType

/** Destinos de la app. Navegación propia con una pila en memoria: sin dependencias extra. */
sealed interface Screen {
    data object Home : Screen
    data object Plan : Screen
    data object Nutrition : Screen
    data object History : Screen
    data object Profile : Screen
    data class PreSession(val workoutId: Long?) : Screen
    data object Live : Screen
    data object Summary : Screen
    data class SessionDetail(val sessionId: Long) : Screen
    data class FoodSearch(val mealType: MealType) : Screen
    data class FoodPhoto(val mealType: MealType) : Screen
}

class Navigator {
    var stack by mutableStateOf<List<Screen>>(listOf(Screen.Home))
        private set

    val current: Screen get() = stack.last()
    val canGoBack: Boolean get() = stack.size > 1

    fun push(screen: Screen) {
        stack = stack + screen
    }

    fun pop() {
        if (stack.size > 1) stack = stack.dropLast(1)
    }

    fun popTo(screen: Screen) {
        stack = listOf(screen)
    }

    fun replace(screen: Screen) {
        stack = stack.dropLast(1) + screen
    }
}

/** Pestañas de la barra inferior. */
enum class Tab(val screen: Screen, val label: String, val icon: String) {
    HOME(Screen.Home, "Hoy", "ic_home"),
    PLAN(Screen.Plan, "Plan", "ic_calendar"),
    NUTRITION(Screen.Nutrition, "Nutrición", "ic_food"),
    HISTORY(Screen.History, "Historial", "ic_chart"),
    PROFILE(Screen.Profile, "Perfil", "ic_profile")
}
