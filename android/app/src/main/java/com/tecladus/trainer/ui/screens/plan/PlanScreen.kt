package com.tecladus.trainer.ui.screens.plan

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.model.PlanWeek
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.WorkoutType
import com.tecladus.trainer.domain.model.formatMinuteOfDay
import com.tecladus.trainer.ui.components.HairLine
import com.tecladus.trainer.ui.components.SelectableChip
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import kotlinx.coroutines.launch
import java.time.LocalDate

/**
 * El plan es una lista, no siete tarjetas: filas separadas por hairlines, los días de
 * descanso apagados y el día de hoy marcado con el acento. Se recorre de un vistazo.
 */
@Composable
fun PlanScreen(
    onOpenWorkout: (PlannedWorkout) -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val profile by container.profileRepository.profile.collectAsState()
    val plan by container.planRepository.plan.collectAsState()
    val scope = rememberCoroutineScope()
    val today = LocalDate.now()

    val weeks: List<PlanWeek> = remember(plan) { container.planRepository.weeks() }
    val currentWeek = weeks.firstOrNull { week -> week.workouts.any { it.date == today } }?.weekNumber
        ?: weeks.firstOrNull()?.weekNumber ?: 1
    var selectedWeek by remember(weeks.size) { mutableStateOf(currentWeek) }
    val week = weeks.firstOrNull { it.weekNumber == selectedWeek }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column {
                Text("Tu plan", style = MaterialTheme.typography.headlineMedium)
                Text(
                    "${profile.goal.label} · ${profile.trainingDaysPerWeek} días por semana",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        if (weeks.isEmpty()) {
            item {
                TrainerCard {
                    Text("Todavía no hay plan", style = MaterialTheme.typography.headlineSmall)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Generá tu calendario a partir de tu objetivo, tu nivel y tus días disponibles.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.height(16.dp))
                    Button(
                        onClick = { scope.launch { container.planRepository.regenerate(profile) } },
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                    ) { Text("Generar plan") }
                }
            }
        } else {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    weeks.forEach { w ->
                        SelectableChip(
                            text = "Sem ${w.weekNumber}",
                            selected = w.weekNumber == selectedWeek,
                            onClick = { selectedWeek = w.weekNumber },
                            modifier = Modifier.height(44.dp)
                        )
                    }
                }
            }

            if (week != null) {
                item {
                    TrainerCard {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    "Semana ${week.weekNumber} · ${week.phase.label}",
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Spacer(Modifier.height(3.dp))
                                Text(
                                    week.phase.focus,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Spacer(Modifier.width(12.dp))
                            Column(horizontalAlignment = Alignment.End) {
                                Text(
                                    if (week.totalKm > 0) "${week.totalKm.toInt()} km"
                                    else Formatters.durationShort(week.totalMinutes),
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Text(
                                    Formatters.durationShort(week.totalMinutes),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                items(week.workouts.size) { index ->
                    val workout = week.workouts[index]
                    Column {
                        WorkoutRow(
                            workout = workout,
                            isToday = workout.date == today,
                            onClick = { onOpenWorkout(workout) }
                        )
                        if (index < week.workouts.lastIndex) HairLine()
                    }
                }
            }

            item {
                Spacer(Modifier.height(4.dp))
                OutlinedButton(
                    onClick = { scope.launch { container.planRepository.regenerate(profile) } },
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp)
                ) { Text("Regenerar plan") }
            }
        }
    }
}

@Composable
private fun WorkoutRow(workout: PlannedWorkout, isToday: Boolean, onClick: () -> Unit) {
    val isRest = workout.type == WorkoutType.REST
    val rowModifier = if (isRest) Modifier else Modifier.clickable { onClick() }
    Row(
        modifier = rowModifier
            .fillMaxWidth()
            .height(64.dp)
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.width(38.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                Formatters.dayName(workout.date).uppercase(),
                style = MaterialTheme.typography.labelSmall,
                color = if (isToday) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                workout.date.dayOfMonth.toString(),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = when {
                    isToday -> MaterialTheme.colorScheme.primary
                    isRest -> MaterialTheme.colorScheme.onSurfaceVariant
                    else -> MaterialTheme.colorScheme.onSurface
                }
            )
        }
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                if (isRest) "Descanso" else workout.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isRest) FontWeight.Normal else FontWeight.SemiBold,
                color = if (isRest) MaterialTheme.colorScheme.onSurfaceVariant
                else MaterialTheme.colorScheme.onSurface
            )
            if (!isRest) {
                Spacer(Modifier.height(3.dp))
                Text(
                    buildString {
                        workout.scheduledMinuteOfDay?.let { append("${formatMinuteOfDay(it)} · ") }
                        append("${workout.durationMin} min")
                        workout.distanceKm?.let { append(" · ${Formatters.distanceShort(it)}") }
                    },
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        when {
            workout.completed -> TrainerIcon("ic_check", tint = MaterialTheme.colorScheme.tertiary, size = 18)
            isToday -> Box(
                modifier = Modifier
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    "HOY",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onPrimary,
                    fontWeight = FontWeight.Bold
                )
            }
            !isRest -> TrainerIcon(
                "ic_chevron_right",
                tint = MaterialTheme.colorScheme.outline,
                size = 16
            )
        }
    }
}

fun sportIcon(sport: Sport): String = when (sport) {
    Sport.RUNNING -> "ic_run"
    Sport.CYCLING -> "ic_bike"
    Sport.TREKKING -> "ic_mountain"
    Sport.SWIMMING, Sport.TRIATHLON -> "ic_swim"
    Sport.STRENGTH -> "ic_heart"
    Sport.OTHER -> "ic_timer"
}
