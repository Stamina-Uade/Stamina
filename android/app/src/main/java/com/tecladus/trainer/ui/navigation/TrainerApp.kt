package com.tecladus.trainer.ui.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.model.TrackingState
import com.tecladus.trainer.tracking.ReminderScheduler
import com.tecladus.trainer.ui.components.TrainerIcon
import com.tecladus.trainer.ui.theme.NavSurface
import com.tecladus.trainer.ui.screens.history.HistoryScreen
import com.tecladus.trainer.ui.screens.history.SessionDetailScreen
import com.tecladus.trainer.ui.screens.home.HomeScreen
import com.tecladus.trainer.ui.screens.nutrition.FoodPhotoScreen
import com.tecladus.trainer.ui.screens.nutrition.FoodSearchScreen
import com.tecladus.trainer.ui.screens.nutrition.NutritionScreen
import com.tecladus.trainer.ui.screens.onboarding.OnboardingScreen
import com.tecladus.trainer.ui.screens.plan.PlanScreen
import com.tecladus.trainer.ui.screens.profile.ProfileScreen
import com.tecladus.trainer.ui.screens.train.LiveSessionScreen
import com.tecladus.trainer.ui.screens.train.PreSessionScreen
import com.tecladus.trainer.ui.screens.train.SessionSummaryScreen
import kotlinx.coroutines.launch

/** Raíz de la app: onboarding, navegación por pestañas y pantallas de sesión. */
@Composable
fun TrainerApp() {
    val container = ServiceLocator.container
    val profile by container.profileRepository.profile.collectAsState()
    val plan by container.planRepository.plan.collectAsState()
    val liveState by container.trackingManager.state.collectAsState()
    val scope = rememberCoroutineScope()
    val navigator = remember { Navigator() }
    val context = LocalContext.current

    // Los recordatorios se reprograman cada vez que cambia la agenda del usuario.
    LaunchedEffect(profile.trainingSchedule, profile.onboardingCompleted) {
        if (profile.onboardingCompleted) ReminderScheduler.reschedule(context, profile)
    }

    LaunchedEffect(Unit) {
        container.planRepository.refresh()
        container.sessionRepository.refresh()
        container.nutritionRepository.refresh()
    }

    // Si hay una sesión en curso (por ejemplo al volver a abrir la app), se muestra en vivo.
    LaunchedEffect(liveState.state) {
        val running = liveState.state == TrackingState.RUNNING || liveState.state == TrackingState.PAUSED
        if (running && navigator.current != Screen.Live && navigator.current != Screen.Summary) {
            navigator.push(Screen.Live)
        }
    }

    if (!profile.onboardingCompleted) {
        OnboardingScreen(
            initialProfile = profile,
            onFinish = { newProfile ->
                scope.launch {
                    container.profileRepository.save(newProfile)
                    container.planRepository.regenerate(newProfile)
                    ReminderScheduler.reschedule(context, newProfile)
                }
            }
        )
        return
    }

    BackHandler(enabled = navigator.canGoBack) { navigator.pop() }

    val current = navigator.current
    val showBottomBar = Tab.entries.any { it.screen == current }

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar(containerColor = NavSurface, tonalElevation = 0.dp) {
                    Tab.entries.forEach { tab ->
                        val selected = tab.screen == current
                        NavigationBarItem(
                            selected = selected,
                            onClick = { navigator.popTo(tab.screen) },
                            icon = {
                                TrainerIcon(
                                    tab.icon,
                                    size = 21,
                                    tint = if (selected) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            },
                            label = {
                                Text(
                                    tab.label,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = if (selected) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                indicatorColor = androidx.compose.ui.graphics.Color.Transparent
                            )
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            Crossfade(
                targetState = current,
                animationSpec = tween(durationMillis = 260, easing = FastOutSlowInEasing),
                label = "screen"
            ) { destination ->
            when (destination) {
                Screen.Home -> HomeScreen(
                    onStartSession = { workoutId -> navigator.push(Screen.PreSession(workoutId)) },
                    onOpenPlan = { navigator.popTo(Screen.Plan) },
                    onOpenNutrition = { navigator.popTo(Screen.Nutrition) }
                )

                Screen.Plan -> PlanScreen(
                    onOpenWorkout = { workout -> navigator.push(Screen.PreSession(workout.id)) }
                )

                Screen.Nutrition -> NutritionScreen(
                    onAddFood = { meal -> navigator.push(Screen.FoodSearch(meal)) }
                )

                Screen.History -> HistoryScreen(
                    onOpenSession = { id -> navigator.push(Screen.SessionDetail(id)) }
                )

                Screen.Profile -> ProfileScreen()

                is Screen.PreSession -> PreSessionScreen(
                    workout = plan.firstOrNull { it.id == destination.workoutId },
                    onBack = { navigator.pop() },
                    onSessionStarted = { navigator.replace(Screen.Live) }
                )

                Screen.Live -> LiveSessionScreen(
                    onFinish = { navigator.replace(Screen.Summary) }
                )

                Screen.Summary -> SessionSummaryScreen(
                    onDone = { navigator.popTo(Screen.Home) }
                )

                is Screen.SessionDetail -> SessionDetailScreen(
                    sessionId = destination.sessionId,
                    onBack = { navigator.pop() }
                )

                is Screen.FoodSearch -> FoodSearchScreen(
                    mealType = destination.mealType,
                    onBack = { navigator.pop() },
                    onPhoto = { navigator.replace(Screen.FoodPhoto(destination.mealType)) }
                )

                is Screen.FoodPhoto -> FoodPhotoScreen(
                    mealType = destination.mealType,
                    onBack = { navigator.pop() }
                )
            }
            }
        }
    }
}
