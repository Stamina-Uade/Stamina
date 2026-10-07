package com.tecladus.trainer.ui.screens.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.logic.NutritionCalculator
import com.tecladus.trainer.domain.logic.PaceCalculator
import com.tecladus.trainer.domain.logic.TrainingLoadCalculator
import com.tecladus.trainer.domain.model.LoadStatus
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.WorkoutType
import com.tecladus.trainer.domain.model.formatMinuteOfDay
import com.tecladus.trainer.ui.components.AnimatedNumber
import com.tecladus.trainer.ui.components.Pill
import com.tecladus.trainer.ui.components.ProgressRing
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import com.tecladus.trainer.ui.theme.Hydration
import com.tecladus.trainer.ui.theme.Surface3
import java.time.LocalDate

/**
 * Pantalla "Hoy": cuatro bloques y un solo botón lleno.
 *
 * 1) qué toca ahora, 2) cómo viene la comida, 3) cuánta agua llevo,
 * 4) cómo viene la carga. Todo lo demás vive en su propia pestaña.
 */
@Composable
fun HomeScreen(
    onStartSession: (Long?) -> Unit,
    onOpenPlan: () -> Unit,
    onOpenNutrition: () -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val profile by container.profileRepository.profile.collectAsState()
    val plan by container.planRepository.plan.collectAsState()
    val sessions by container.sessionRepository.sessions.collectAsState()
    val entries by container.nutritionRepository.entries.collectAsState()
    val waterMl by container.nutritionRepository.waterMl.collectAsState()
    val selectedDate by container.nutritionRepository.selectedDate.collectAsState()

    val today = LocalDate.now()

    LaunchedEffect(today) {
        if (selectedDate != today) container.nutritionRepository.selectDate(today)
    }

    val todayWorkout = plan.firstOrNull { it.date == today }
    val eventMinutes = remember(profile) { PaceCalculator.estimatedGoalTimeMinutes(profile) }
    val targets = remember(profile, todayWorkout) {
        NutritionCalculator.targetsFor(profile, todayWorkout, today, eventMinutes)
    }
    val loadSummary = remember(sessions) { TrainingLoadCalculator.summarize(sessions) }
    val weekVolume = remember(sessions) { TrainingLoadCalculator.weeklyVolume(sessions) }
    val kcalConsumed = entries.sumOf { it.kcal }
    val daysToEvent = profile.daysToEvent(today)

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        Formatters.fullDate(today),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        if (profile.name.isBlank()) "Hola" else "Hola, ${profile.name}",
                        style = MaterialTheme.typography.headlineMedium
                    )
                }
                if (daysToEvent != null && daysToEvent >= 0) {
                    Row(
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surface)
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(7.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primary)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            "$daysToEvent días",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }
        }

        item {
            TodayCard(
                workout = todayWorkout,
                onStart = { onStartSession(todayWorkout?.id) },
                onOpenPlan = onOpenPlan
            )
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TrainerCard(
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(16.dp),
                    onClick = onOpenNutrition
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ProgressRing(
                            progress = if (targets.kcal > 0) (kcalConsumed / targets.kcal).toFloat() else 0f,
                            modifier = Modifier.size(52.dp),
                            color = MaterialTheme.colorScheme.tertiary,
                            strokeWidth = 14f
                        )
                        Spacer(Modifier.width(12.dp))
                        Column {
                            AnimatedNumber(
                                value = kcalConsumed.toInt(),
                                style = MaterialTheme.typography.titleMedium
                            )
                            Text(
                                "de ${targets.kcal} kcal",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                TrainerCard(
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(16.dp),
                    onClick = onOpenNutrition
                ) {
                    WaterSegments(consumed = waterMl, target = targets.waterMl)
                    Spacer(Modifier.height(10.dp))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            Formatters.decimal(waterMl / 1000.0, 1),
                            style = MaterialTheme.typography.titleMedium
                        )
                        Spacer(Modifier.width(5.dp))
                        Text(
                            "de ${Formatters.decimal(targets.waterMl / 1000.0, 1)} L",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 2.dp)
                        )
                    }
                }
            }
        }

        item {
            TrainerCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "Carga de las últimas 4 semanas",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Pill(
                        text = loadSummary.status.label,
                        color = when (loadSummary.status) {
                            LoadStatus.RISK -> MaterialTheme.colorScheme.error
                            LoadStatus.CAUTION -> MaterialTheme.colorScheme.primary
                            else -> MaterialTheme.colorScheme.tertiary
                        }
                    )
                }
                Spacer(Modifier.height(14.dp))
                LoadBars(values = loadSummary.weeklyLoads)
                Spacer(Modifier.height(12.dp))
                Text(
                    "${Formatters.decimal(weekVolume.first, 1)} km · " +
                        "${Formatters.durationShort(weekVolume.second)} · " +
                        "${sessions.count {
                            val d = java.time.Instant.ofEpochMilli(it.startTimeMs)
                                .atZone(java.time.ZoneId.systemDefault()).toLocalDate()
                            !d.isBefore(today.minusDays(6))
                        }} sesiones",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item { Spacer(Modifier.height(40.dp)) }
    }
}

@Composable
private fun TodayCard(
    workout: PlannedWorkout?,
    onStart: () -> Unit,
    onOpenPlan: () -> Unit
) {
    TrainerCard(contentPadding = PaddingValues(20.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Hoy te recomendamos",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            when {
                workout?.completed == true -> Pill("Completada", MaterialTheme.colorScheme.tertiary)
                workout?.scheduledMinuteOfDay != null -> Text(
                    formatMinuteOfDay(workout.scheduledMinuteOfDay),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        if (workout == null) {
            Text("Todavía no hay plan", style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.height(8.dp))
            Text(
                "Definí tu objetivo y armamos el calendario completo.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = onOpenPlan,
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
            ) { Text("Ver plan") }
            return@TrainerCard
        }

        if (workout.type == WorkoutType.REST) {
            Text("Descanso", style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.height(8.dp))
            Text(
                "La adaptación ocurre cuando descansás. Movilidad suave y buen sueño.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(16.dp))
            OutlinedButton(
                onClick = onStart,
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
            ) { Text("Igual quiero entrenar") }
            return@TrainerCard
        }

        Text(workout.title, style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(6.dp))
        Text(
            buildString {
                append("${workout.durationMin} min")
                workout.distanceKm?.let { append(" · ${Formatters.distanceShort(it)}") }
                append(" · ${workout.type.zone.label}")
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(Modifier.height(16.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(MaterialTheme.colorScheme.background)
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TrainerIcon("ic_water", tint = Hydration, size = 17)
            Spacer(Modifier.width(10.dp))
            Text(
                workout.fuelingTip,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onStart,
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
        ) {
            TrainerIcon("ic_play", tint = MaterialTheme.colorScheme.onPrimary, size = 15)
            Spacer(Modifier.width(10.dp))
            Text("Empezar sesión", fontWeight = FontWeight.Bold)
        }
    }
}

/** Vaso a vaso: seis segmentos de 500 ml se leen más rápido que un porcentaje. */
@Composable
private fun WaterSegments(consumed: Int, target: Int) {
    val segments = 6
    val filled = if (target > 0) (consumed.toFloat() / target * segments).toInt().coerceIn(0, segments) else 0
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
        repeat(segments) { index ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(22.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(if (index < filled) Hydration else Surface3)
            )
        }
    }
}

@Composable
private fun LoadBars(values: List<Double>) {
    val max = (values.maxOrNull() ?: 0.0).coerceAtLeast(1.0)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(46.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        values.forEachIndexed { index, value ->
            val fraction = (value / max).toFloat().coerceIn(0.08f, 1f)
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height((46 * fraction).dp)
                    .clip(RoundedCornerShape(topStart = 6.dp, topEnd = 6.dp, bottomStart = 2.dp, bottomEnd = 2.dp))
                    .background(
                        if (index == values.lastIndex) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.surfaceVariant
                    )
            )
        }
    }
}
