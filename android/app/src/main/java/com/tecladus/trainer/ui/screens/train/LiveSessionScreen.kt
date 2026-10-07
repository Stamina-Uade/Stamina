package com.tecladus.trainer.ui.screens.train

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.model.IntakeType
import com.tecladus.trainer.domain.model.TrackingState
import com.tecladus.trainer.tracking.TrackingService
import com.tecladus.trainer.ui.components.Pill
import com.tecladus.trainer.ui.components.ProgressBarLine
import com.tecladus.trainer.ui.components.PulsingDot
import com.tecladus.trainer.ui.components.TileMap
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import com.tecladus.trainer.ui.theme.Hydration
import com.tecladus.trainer.ui.theme.MetricNumberStyle

/**
 * Sesión en vivo, con el mapa de fondo y los datos flotando encima.
 *
 * Todo lo que hay que tocar en movimiento (registrar una toma, pausar, finalizar) vive
 * abajo, al alcance del pulgar y siempre visible.
 */
@Composable
fun LiveSessionScreen(
    onFinish: () -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val manager = container.trackingManager
    val state by manager.state.collectAsState()
    val context = LocalContext.current

    // Mientras la sesión está en curso el botón "atrás" no la abandona.
    BackHandler(enabled = true) { }

    val background = MaterialTheme.colorScheme.background
    val floating = MaterialTheme.colorScheme.surface.copy(alpha = 0.93f)
    val plan = state.hydrationPlan
    val alert = state.pendingAlert

    Box(modifier = modifier.fillMaxSize()) {

        TileMap(
            latitude = state.points.lastOrNull()?.latitude,
            longitude = state.points.lastOrNull()?.longitude,
            route = state.points,
            modifier = Modifier.fillMaxSize(),
            cornerRadius = 0,
            placeholder = "Buscando señal de GPS..."
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        0f to background.copy(alpha = 0.85f),
                        0.14f to background.copy(alpha = 0.18f),
                        0.52f to background.copy(alpha = 0.55f),
                        1f to background.copy(alpha = 0.95f)
                    )
                )
        )

        Column(modifier = Modifier.fillMaxSize()) {

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(floating)
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    PulsingDot(
                        color = if (state.hasGpsFix) MaterialTheme.colorScheme.tertiary
                        else MaterialTheme.colorScheme.error,
                        active = state.state == TrackingState.RUNNING,
                        size = 8
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        if (state.hasGpsFix) "GPS ±${state.gpsAccuracyM.toInt()} m" else "Buscando GPS",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Pill(
                    when (state.state) {
                        TrackingState.RUNNING -> "En curso"
                        TrackingState.PAUSED -> "En pausa"
                        TrackingState.FINISHED -> "Finalizada"
                        TrackingState.IDLE -> "Lista"
                    },
                    MaterialTheme.colorScheme.primary
                )
            }

            Spacer(Modifier.weight(1f))

            AnimatedVisibility(
                visible = alert != null,
                enter = fadeIn(tween(220)) + slideInVertically(tween(280)) { it / 2 },
                exit = fadeOut(tween(180)) + slideOutVertically(tween(220)) { it / 2 }
            ) {
                TrainerCard(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.96f),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TrainerIcon(
                            when (alert?.type) {
                                IntakeType.SALT -> "ic_salt"
                                IntakeType.GEL -> "ic_gel"
                                IntakeType.SOLID -> "ic_food"
                                else -> "ic_water"
                            },
                            tint = Hydration,
                            size = 24
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                alert?.title ?: "",
                                style = MaterialTheme.typography.titleMedium
                            )
                            Text(
                                alert?.message ?: "",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = {
                                alert?.let {
                                    manager.registerIntake(
                                        type = it.type,
                                        fluidMl = it.suggestedFluidMl,
                                        sodiumMg = it.suggestedSodiumMg,
                                        carbsG = it.suggestedCarbsG
                                    )
                                }
                            },
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Hydration,
                                contentColor = MaterialTheme.colorScheme.onSecondary
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .height(46.dp)
                        ) { Text("Ya lo tomé", fontWeight = FontWeight.Bold) }
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(46.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(MaterialTheme.colorScheme.background.copy(alpha = 0.6f))
                                .clickable { manager.dismissAlert() },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                "Ahora no",
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            TrainerCard(
                modifier = Modifier.padding(horizontal = 16.dp),
                containerColor = floating,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text(
                            Formatters.duration(state.elapsedSec),
                            style = MetricNumberStyle,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            "Tiempo",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            Formatters.decimal(state.distanceKm, 2),
                            style = MaterialTheme.typography.headlineMedium
                        )
                        Text(
                            "km",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(Modifier.height(18.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    LiveMetric("Ritmo", Formatters.pace(state.currentPaceSecPerKm), "min/km")
                    LiveMetric("Medio", Formatters.pace(state.avgPaceSecPerKm), "min/km")
                    LiveMetric("Desnivel", state.elevationGainM.toInt().toString(), "m")
                    LiveMetric("Calorías", state.kcal.toString(), "kcal")
                }

                if (plan != null) {
                    val expected = (plan.fluidPerHourMl * state.elapsedSec / 3600.0).toInt().coerceAtLeast(1)
                    Spacer(Modifier.height(20.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            "Hidratación",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            "${state.fluidTakenMl} de $expected ml",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    ProgressBarLine(
                        progress = state.fluidTakenMl / expected.toFloat(),
                        color = Hydration,
                        heightDp = 8
                    )
                    Spacer(Modifier.height(14.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        QuickIntake("${plan.fluidBolusMl} ml", "ic_water", Modifier.weight(1f)) {
                            manager.registerIntake(IntakeType.WATER, plan.fluidBolusMl, 0, 0)
                        }
                        QuickIntake("Sales", "ic_salt", Modifier.weight(1f)) {
                            manager.registerIntake(
                                IntakeType.SALT, 0,
                                if (plan.sodiumBolusMg > 0) plan.sodiumBolusMg else 300, 0
                            )
                        }
                        QuickIntake("Gel", "ic_gel", Modifier.weight(1f)) {
                            manager.registerIntake(
                                IntakeType.GEL, 0, 50,
                                if (plan.carbsBolusG > 0) plan.carbsBolusG else 25
                            )
                        }
                    }
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 26.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                val running = state.state == TrackingState.RUNNING
                Button(
                    onClick = {
                        TrackingService.send(
                            context,
                            if (running) TrackingService.ACTION_PAUSE else TrackingService.ACTION_RESUME
                        )
                    },
                    shape = RoundedCornerShape(18.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                        contentColor = MaterialTheme.colorScheme.onSurface
                    ),
                    modifier = Modifier
                        .weight(1f)
                        .height(58.dp)
                ) {
                    TrainerIcon(
                        if (running) "ic_pause" else "ic_play",
                        tint = MaterialTheme.colorScheme.onSurface,
                        size = 16
                    )
                    Spacer(Modifier.width(9.dp))
                    Text(if (running) "Pausar" else "Reanudar", fontWeight = FontWeight.SemiBold)
                }
                Button(
                    onClick = {
                        TrackingService.send(context, TrackingService.ACTION_STOP)
                        onFinish()
                    },
                    shape = RoundedCornerShape(18.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                        contentColor = MaterialTheme.colorScheme.error
                    ),
                    modifier = Modifier
                        .weight(1f)
                        .height(58.dp)
                ) {
                    TrainerIcon("ic_stop", tint = MaterialTheme.colorScheme.error, size = 15)
                    Spacer(Modifier.width(9.dp))
                    Text("Finalizar", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun LiveMetric(label: String, value: String, unit: String) {
    Column(horizontalAlignment = Alignment.Start) {
        Text(value, style = MaterialTheme.typography.titleLarge)
        Text(
            "$label · $unit",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun QuickIntake(
    label: String,
    icon: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Row(
        modifier = modifier
            .height(46.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(MaterialTheme.colorScheme.background.copy(alpha = 0.7f))
            .clickable { onClick() },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        TrainerIcon(icon, tint = Hydration, size = 15)
        Spacer(Modifier.width(7.dp))
        Text(label, style = MaterialTheme.typography.labelMedium)
    }
}
