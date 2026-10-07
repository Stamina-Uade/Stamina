package com.tecladus.trainer.ui.screens.history

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.logic.TrainingLoadCalculator
import com.tecladus.trainer.ui.components.BarChart
import com.tecladus.trainer.ui.components.EmptyState
import com.tecladus.trainer.ui.components.Pill
import com.tecladus.trainer.ui.components.SectionTitle
import com.tecladus.trainer.ui.components.StatTile
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import com.tecladus.trainer.ui.screens.plan.sportIcon
import java.time.Instant
import java.time.ZoneId

/** Historial de sesiones y estadísticas acumuladas. */
@Composable
fun HistoryScreen(
    onOpenSession: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val sessions by container.sessionRepository.sessions.collectAsState()
    val load = remember(sessions) { TrainingLoadCalculator.summarize(sessions) }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Historial", style = MaterialTheme.typography.headlineMedium)
        }

        if (sessions.isEmpty()) {
            item {
                EmptyState(
                    title = "Todavía no registraste sesiones",
                    message = "Cuando termines tu primer entrenamiento vas a ver acá tus métricas, " +
                        "el recorrido y el cumplimiento de tu plan de hidratación.",
                    iconRes = "ic_run"
                )
            }
        } else {
            item {
                TrainerCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        StatTile("Sesiones", sessions.size.toString())
                        StatTile("Distancia", Formatters.decimal(sessions.sumOf { it.distanceKm }, 1), "km")
                        StatTile("Tiempo", Formatters.durationShort(sessions.sumOf { it.durationMin }))
                        StatTile("Calorías", sessions.sumOf { it.kcal }.toString(), "kcal")
                    }
                    Spacer(Modifier.height(16.dp))
                    SectionTitle("Carga de las últimas 4 semanas")
                    Spacer(Modifier.height(10.dp))
                    BarChart(
                        values = load.weeklyLoads,
                        labels = listOf("-3", "-2", "-1", "Actual")
                    )
                }
            }

            items(sessions.size) { index ->
                val session = sessions[index]
                val date = Instant.ofEpochMilli(session.startTimeMs)
                    .atZone(ZoneId.systemDefault()).toLocalDate()
                TrainerCard(onClick = { onOpenSession(session.id) }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TrainerIcon(sportIcon(session.sport), tint = MaterialTheme.colorScheme.primary, size = 22)
                        Spacer(Modifier.size(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                session.title.ifBlank { session.sport.label },
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                Formatters.fullDate(date),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        if (session.plannedFluidMl > 0) {
                            Pill(
                                "${(session.hydrationCompliance * 100).toInt()}% hidratación",
                                if (session.hydrationCompliance >= 0.8) MaterialTheme.colorScheme.tertiary
                                else MaterialTheme.colorScheme.error
                            )
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        StatTile("Distancia", Formatters.decimal(session.distanceKm, 2), "km")
                        StatTile("Tiempo", Formatters.duration(session.elapsedSec))
                        StatTile("Ritmo", Formatters.pace(session.avgPaceSecPerKm), "min/km")
                        StatTile("Kcal", session.kcal.toString())
                    }
                }
            }
        }

        item { Spacer(Modifier.height(60.dp)) }
    }
}
