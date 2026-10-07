package com.tecladus.trainer.ui.screens.history

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.logic.GeoUtils
import com.tecladus.trainer.domain.model.ActivitySession
import com.tecladus.trainer.domain.model.IntakeEvent
import com.tecladus.trainer.domain.model.TrackPoint
import com.tecladus.trainer.ui.components.MacroRow
import com.tecladus.trainer.ui.components.TileMap
import com.tecladus.trainer.ui.components.ScreenHeader
import com.tecladus.trainer.ui.components.SectionTitle
import com.tecladus.trainer.ui.components.SplitsList
import com.tecladus.trainer.ui.components.StatTile
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

@Composable
fun SessionDetailScreen(
    sessionId: Long,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val sessions by container.sessionRepository.sessions.collectAsState()
    val scope = rememberCoroutineScope()
    val session: ActivitySession? = sessions.firstOrNull { it.id == sessionId }

    var points by remember(sessionId) { mutableStateOf<List<TrackPoint>>(emptyList()) }
    var intakes by remember(sessionId) { mutableStateOf<List<IntakeEvent>>(emptyList()) }

    LaunchedEffect(sessionId) {
        points = container.sessionRepository.pointsOf(sessionId)
        intakes = container.sessionRepository.intakesOf(sessionId)
    }

    if (session == null) {
        Column(modifier = modifier.fillMaxWidth()) {
            ScreenHeader(title = "Sesión", onBack = onBack)
            Text("No encontramos esta sesión.", modifier = Modifier.padding(16.dp))
        }
        return
    }

    val date = Instant.ofEpochMilli(session.startTimeMs).atZone(ZoneId.systemDefault()).toLocalDate()

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            ScreenHeader(
                title = session.title.ifBlank { session.sport.label },
                subtitle = Formatters.fullDate(date),
                onBack = onBack
            )
        }

        if (points.size > 2) {
            item {
                TrainerCard(modifier = Modifier.padding(horizontal = 16.dp)) {
                    TileMap(
                        latitude = null,
                        longitude = null,
                        route = points,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(240.dp)
                    )
                }
            }
        }

        item {
            TrainerCard(modifier = Modifier.padding(horizontal = 16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    StatTile("Distancia", Formatters.decimal(session.distanceKm, 2), "km")
                    StatTile("Tiempo", Formatters.duration(session.elapsedSec))
                    StatTile("Ritmo", Formatters.pace(session.avgPaceSecPerKm), "min/km")
                }
                Spacer(Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    StatTile("Calorías", session.kcal.toString(), "kcal")
                    StatTile("Desnivel", session.elevationGainM.toInt().toString(), "m")
                    StatTile("RPE", "${session.perceivedEffort}/10")
                }
            }
        }

        if (session.plannedFluidMl > 0) {
            item {
                TrainerCard(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    accent = MaterialTheme.colorScheme.secondary
                ) {
                    Text("Hidratación y combustible", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(12.dp))
                    MacroRow(
                        "Líquido", session.fluidMl.toDouble(), session.plannedFluidMl, "ml",
                        MaterialTheme.colorScheme.secondary
                    )
                    Spacer(Modifier.height(10.dp))
                    MacroRow(
                        "Sodio", session.sodiumMg.toDouble(), session.plannedSodiumMg, "mg",
                        MaterialTheme.colorScheme.primary
                    )
                    Spacer(Modifier.height(10.dp))
                    MacroRow(
                        "Hidratos", session.carbsG.toDouble(), session.plannedCarbsG, "g",
                        MaterialTheme.colorScheme.tertiary
                    )
                }
            }
        }

        if (intakes.isNotEmpty()) {
            item {
                TrainerCard(modifier = Modifier.padding(horizontal = 16.dp)) {
                    SectionTitle("Ingestas registradas")
                    Spacer(Modifier.height(10.dp))
                    intakes.forEach { intake ->
                        val minute = ((intake.timestampMs - session.startTimeMs) / 60000L).toInt()
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 5.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            TrainerIcon(
                                intake.type.iconRes,
                                tint = MaterialTheme.colorScheme.secondary,
                                size = 16
                            )
                            Spacer(Modifier.size(10.dp))
                            Text(
                                "min $minute · ${intake.type.label}",
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.weight(1f)
                            )
                            Text(
                                buildString {
                                    if (intake.fluidMl > 0) append("${intake.fluidMl} ml ")
                                    if (intake.sodiumMg > 0) append("${intake.sodiumMg} mg Na ")
                                    if (intake.carbsG > 0) append("${intake.carbsG} g CHO")
                                },
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }

        if (points.size > 2 && session.distanceM > 1000) {
            item {
                TrainerCard(modifier = Modifier.padding(horizontal = 16.dp)) {
                    SectionTitle("Parciales por km")
                    Spacer(Modifier.height(8.dp))
                    SplitsList(GeoUtils.computeSplits(points))
                }
            }
        }

        item {
            OutlinedButton(
                onClick = {
                    scope.launch {
                        container.sessionRepository.delete(sessionId)
                        onBack()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) { Text("Eliminar sesión") }
        }
    }
}
