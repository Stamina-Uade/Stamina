package com.tecladus.trainer.ui.screens.train

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.logic.NutritionCalculator
import com.tecladus.trainer.tracking.SessionResult
import com.tecladus.trainer.ui.components.LabeledSlider
import com.tecladus.trainer.ui.components.MacroRow
import com.tecladus.trainer.ui.components.TileMap
import com.tecladus.trainer.ui.components.SectionTitle
import com.tecladus.trainer.ui.components.SplitsList
import com.tecladus.trainer.ui.components.StatTile
import com.tecladus.trainer.ui.components.TrainerCard
import kotlinx.coroutines.launch

/** Resumen post-sesión: métricas, cumplimiento del plan de hidratación y recuperación. */
@Composable
fun SessionSummaryScreen(
    onDone: () -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val manager = container.trackingManager
    val profile by container.profileRepository.profile.collectAsState()
    val scope = rememberCoroutineScope()

    var result by remember { mutableStateOf<SessionResult?>(null) }
    var rpe by remember { mutableStateOf(5f) }
    var saving by remember { mutableStateOf(false) }

    // El resumen se cierra guardando o descartando, no con el gesto de retroceso.
    BackHandler(enabled = true) { }

    LaunchedEffect(Unit) {
        if (result == null) result = manager.finish()
    }

    val data = result
    if (data == null) {
        Column(modifier = modifier.fillMaxWidth().padding(24.dp)) {
            Text("Cerrando la sesión...", style = MaterialTheme.typography.titleMedium)
        }
        return
    }

    val session = data.session
    val fluidDeficit = (session.plannedFluidMl - session.fluidMl).coerceAtLeast(0)

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Column {
                Text("¡Sesión completa!", style = MaterialTheme.typography.headlineMedium)
                Text(
                    session.title.ifBlank { session.sport.label },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            TrainerCard {
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
                    StatTile("Carga", session.load.toInt().toString())
                }
            }
        }

        if (data.points.size > 2) {
            item {
                TrainerCard {
                    TileMap(
                        latitude = null,
                        longitude = null,
                        route = data.points,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(240.dp)
                    )
                }
            }
        }

        item {
            TrainerCard(accent = MaterialTheme.colorScheme.secondary) {
                Text("Cumplimiento del plan", style = MaterialTheme.typography.titleMedium)
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
                Spacer(Modifier.height(12.dp))
                val message = when {
                    session.plannedFluidMl == 0 -> "Sesión corta: con agua a demanda alcanzaba."
                    session.hydrationCompliance >= 0.85 -> "Muy bien: cumpliste el plan de hidratación."
                    session.hydrationCompliance >= 0.6 ->
                        "Te quedaste corto por ${fluidDeficit} ml. Probá tomar de a sorbos más seguido."
                    else ->
                        "Tomaste bastante menos de lo previsto (déficit de ${fluidDeficit} ml). " +
                            "Por encima del 2% del peso corporal ya cae el rendimiento y aparecen los calambres."
                }
                Text(
                    message,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        if (data.points.size > 2 && session.distanceM > 1000) {
            item {
                TrainerCard {
                    SectionTitle("Parciales")
                    Spacer(Modifier.height(8.dp))
                    SplitsList(
                        com.tecladus.trainer.domain.logic.GeoUtils.computeSplits(data.points)
                    )
                }
            }
        }

        item {
            TrainerCard(accent = MaterialTheme.colorScheme.tertiary) {
                Text("Recuperación", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                Text(
                    NutritionCalculator.recoveryAdvice(profile, session.kcal, fluidDeficit),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "Reponer el 150% del líquido perdido en las próximas 4 horas evita arrastrar " +
                        "deshidratación al día siguiente.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.tertiary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        item {
            TrainerCard {
                LabeledSlider(
                    label = "¿Qué tan duro se sintió? (RPE)",
                    value = rpe,
                    range = 1f..10f,
                    steps = 8,
                    valueLabel = "${rpe.toInt()}/10",
                    onValueChange = { rpe = it }
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "El RPE ajusta el cálculo de carga y el riesgo de sobreentrenamiento.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = {
                        manager.reset()
                        onDone()
                    },
                    modifier = Modifier.weight(1f)
                ) { Text("Descartar") }
                Button(
                    enabled = !saving,
                    onClick = {
                        saving = true
                        scope.launch {
                            val id = container.sessionRepository.save(
                                session.copy(perceivedEffort = rpe.toInt()),
                                data.points,
                                data.intakes
                            )
                            session.plannedWorkoutId?.let { workoutId ->
                                container.planRepository.markCompleted(workoutId, id)
                            }
                            manager.reset()
                            onDone()
                        }
                    },
                    modifier = Modifier.weight(1f)
                ) { Text(if (saving) "Guardando..." else "Guardar sesión") }
            }
        }

        item { Spacer(Modifier.height(40.dp)) }
    }
}
