package com.tecladus.trainer.ui.screens.train

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.logic.EnergyCalculator
import com.tecladus.trainer.domain.logic.HeatRiskCalculator
import com.tecladus.trainer.domain.logic.HydrationCalculator
import com.tecladus.trainer.domain.model.EffortIntensity
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.RiskLevel
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.WeatherConditions
import com.tecladus.trainer.domain.model.WeatherStatus
import com.tecladus.trainer.domain.model.WorkoutType
import com.tecladus.trainer.domain.model.formatMinuteOfDay
import com.tecladus.trainer.tracking.LocationProvider
import com.tecladus.trainer.tracking.SessionConfig
import com.tecladus.trainer.tracking.TrackingService
import com.tecladus.trainer.ui.components.ChipSelector
import com.tecladus.trainer.ui.components.LabeledSlider
import com.tecladus.trainer.ui.components.Pill
import com.tecladus.trainer.ui.components.StatTile
import com.tecladus.trainer.ui.components.TileMap
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import com.tecladus.trainer.ui.theme.Attention
import com.tecladus.trainer.ui.theme.Hydration
import kotlinx.coroutines.launch

/**
 * Antes de salir: el mapa es el fondo de toda la pantalla y la información flota encima.
 *
 * La app no pregunta nada que pueda averiguar sola — la sesión viene del plan y el clima
 * de la ubicación — y el botón de empezar queda fijo abajo, siempre a la vista.
 */
@Composable
fun PreSessionScreen(
    workout: PlannedWorkout?,
    onBack: () -> Unit,
    onSessionStarted: () -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val profile by container.profileRepository.profile.collectAsState()
    val weather by container.weatherRepository.weather.collectAsState()
    val weatherStatus by container.weatherRepository.status.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val recommendedSport = workout?.sport?.takeIf { it != Sport.OTHER && it != Sport.STRENGTH }
        ?: profile.primarySport
    val recommendedDuration = workout?.durationMin ?: 45
    val recommendedIntensity = workout?.let { EnergyCalculator.intensityFor(it.type) } ?: EffortIntensity.MODERATE

    var sport by remember(recommendedSport) { mutableStateOf(recommendedSport) }
    var durationMin by remember(recommendedDuration) { mutableStateOf(recommendedDuration.toFloat()) }
    var intensity by remember(recommendedIntensity) { mutableStateOf(recommendedIntensity) }
    var showAdjust by remember { mutableStateOf(false) }
    var permissionAsked by remember { mutableStateOf(false) }

    val locationLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { scope.launch { container.weatherRepository.refresh(force = true) } }

    LaunchedEffect(Unit) {
        if (!LocationProvider.hasPermission(context) && !permissionAsked) {
            permissionAsked = true
            locationLauncher.launch(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            )
        } else {
            container.weatherRepository.refresh()
        }
    }

    val conditions = weather?.toConditions() ?: WeatherConditions()
    val safety = remember(weather, durationMin) {
        weather?.let { HeatRiskCalculator.assess(it, durationMin.toInt()) }
    }
    val plan = remember(profile, sport, intensity, conditions, durationMin) {
        HydrationCalculator.buildPlan(profile, sport, intensity, conditions, durationMin.toInt())
    }

    fun startSession() {
        container.trackingManager.prepare(
            SessionConfig(
                sport = sport,
                weightKg = profile.weightKg,
                hydrationPlan = plan,
                intensity = intensity,
                weather = conditions,
                plannedWorkoutId = workout?.id,
                plannedType = workout?.type,
                title = workout?.title ?: "${sport.label} libre"
            )
        )
        TrackingService.send(context, TrackingService.ACTION_START)
        onSessionStarted()
    }

    val background = MaterialTheme.colorScheme.background
    val floating = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f)

    Box(modifier = modifier.fillMaxSize()) {

        TileMap(
            latitude = weather?.latitude,
            longitude = weather?.longitude,
            modifier = Modifier.fillMaxSize(),
            zoom = 15,
            cornerRadius = 0,
            placeholder = when (weatherStatus) {
                WeatherStatus.NO_PERMISSION -> "Activá la ubicación para ver el mapa y el clima"
                WeatherStatus.NO_LOCATION -> "No pudimos ubicarte: el GPS engancha al empezar"
                WeatherStatus.LOADING, WeatherStatus.IDLE -> "Buscando tu ubicación..."
                else -> "Mapa no disponible"
            }
        )

        // Velo para que el texto se lea sobre el mapa sin taparlo del todo.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        0f to background.copy(alpha = 0.88f),
                        0.13f to background.copy(alpha = 0.30f),
                        0.30f to background.copy(alpha = 0.72f),
                        1f to background.copy(alpha = 0.94f)
                    )
                )
        )

        Column(modifier = Modifier.fillMaxSize()) {

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(floating)
                        .clickable { onBack() },
                    contentAlignment = Alignment.Center
                ) {
                    TrainerIcon("ic_back", size = 17)
                }
                Spacer(Modifier.width(14.dp))
                Column {
                    Text("Hoy te recomendamos", style = MaterialTheme.typography.titleLarge)
                    Text(
                        weather?.place ?: "Tu ubicación actual",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Aire para que se vea el mapa antes de que empiecen las tarjetas.
                item { Spacer(Modifier.height(150.dp)) }

                item {
                    TrainerCard(containerColor = floating, contentPadding = PaddingValues(20.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                "Tu sesión de hoy",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            workout?.scheduledMinuteOfDay?.let {
                                Text(
                                    formatMinuteOfDay(it),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                        Spacer(Modifier.height(12.dp))
                        Text(
                            workout?.title ?: "${sport.label} libre",
                            style = MaterialTheme.typography.headlineSmall
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            buildString {
                                append("${durationMin.toInt()} min")
                                workout?.distanceKm?.let { append(" · ${Formatters.distanceShort(it)}") }
                                append(" · ${intensity.label.lowercase()}")
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (workout != null && workout.type != WorkoutType.REST) {
                            Spacer(Modifier.height(14.dp))
                            Text(
                                workout.description,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(Modifier.height(12.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Pill(workout.phase.label, MaterialTheme.colorScheme.primary)
                                Pill(workout.type.zone.label, MaterialTheme.colorScheme.tertiary)
                            }
                        }
                    }
                }

                if (weather != null) {
                    item {
                        TrainerCard(
                            containerColor = floating,
                            accent = MaterialTheme.colorScheme.secondary
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    "Condiciones ahora",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    weather?.description ?: "",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Hydration
                                )
                            }
                            Spacer(Modifier.height(14.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                StatTile("Temperatura", "${weather?.tempC?.toInt()}", "°C")
                                StatTile("Sensación", "${weather?.apparentC?.toInt()}", "°C")
                                StatTile("Humedad", "${weather?.humidityPct?.toInt()}", "%")
                                StatTile("Viento", "${weather?.windKmh?.toInt()}", "km/h")
                            }
                        }
                    }
                } else if (weatherStatus == WeatherStatus.NO_PERMISSION || weatherStatus == WeatherStatus.ERROR) {
                    item {
                        TrainerCard(containerColor = floating) {
                            Text(
                                if (weatherStatus == WeatherStatus.NO_PERMISSION)
                                    "Sin permiso de ubicación no podemos leer el clima: calculamos la " +
                                        "hidratación con condiciones templadas (22 °C y 55%)."
                                else
                                    "No pudimos leer el clima. Calculamos con condiciones templadas.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(Modifier.height(12.dp))
                            OutlinedButton(
                                onClick = {
                                    locationLauncher.launch(
                                        arrayOf(
                                            Manifest.permission.ACCESS_FINE_LOCATION,
                                            Manifest.permission.ACCESS_COARSE_LOCATION
                                        )
                                    )
                                },
                                shape = RoundedCornerShape(14.dp),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(46.dp)
                            ) { Text("Reintentar") }
                        }
                    }
                }

                if (safety != null && safety.level != RiskLevel.GOOD) {
                    item {
                        val color = when (safety.level) {
                            RiskLevel.EXTREME -> MaterialTheme.colorScheme.error
                            RiskLevel.HIGH -> Attention
                            else -> MaterialTheme.colorScheme.primary
                        }
                        TrainerCard(
                            containerColor = floating,
                            accent = color,
                            contentPadding = PaddingValues(20.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                TrainerIcon("ic_heart", tint = color, size = 20)
                                Spacer(Modifier.width(10.dp))
                                Text(safety.headline, style = MaterialTheme.typography.titleMedium, color = color)
                            }
                            Spacer(Modifier.height(10.dp))
                            Text(
                                safety.advice,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            if (safety.adjustments.isNotEmpty()) {
                                Spacer(Modifier.height(12.dp))
                                safety.adjustments.forEach { adjustment ->
                                    Row(modifier = Modifier.padding(vertical = 3.dp)) {
                                        Text(
                                            "· ",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                        Text(
                                            adjustment,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                            if (safety.level >= RiskLevel.HIGH && durationMin > 30) {
                                Spacer(Modifier.height(12.dp))
                                OutlinedButton(
                                    onClick = { durationMin = (durationMin * 0.75f).coerceAtLeast(20f) },
                                    shape = RoundedCornerShape(14.dp),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(46.dp)
                                ) { Text("Recortar a ${(durationMin * 0.75f).toInt()} min") }
                            }
                        }
                    }
                }

                item {
                    TrainerCard(
                        containerColor = floating,
                        accent = MaterialTheme.colorScheme.secondary,
                        contentPadding = PaddingValues(20.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            TrainerIcon("ic_water", tint = Hydration, size = 19)
                            Spacer(Modifier.width(10.dp))
                            Text("Tu plan de hidratación", style = MaterialTheme.typography.titleMedium)
                        }
                        Spacer(Modifier.height(16.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            StatTile("Sudor", Formatters.decimal(plan.sweatRateLh, 2), "L/h", color = Hydration)
                            StatTile("Agua", plan.fluidPerHourMl.toString(), "ml/h")
                            StatTile("Sodio", plan.sodiumPerHourMg.toString(), "mg/h")
                            StatTile("Hidratos", plan.carbsPerHourG.toString(), "g/h")
                        }
                        Spacer(Modifier.height(16.dp))
                        Text(
                            "Llevá ${plan.totalFluidMl} ml, ${plan.totalCarbsG} g de hidratos y " +
                                "${plan.totalSodiumMg} mg de sodio.",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                        Spacer(Modifier.height(12.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Pill("Agua c/${plan.fluidIntervalMin} min", Hydration)
                            if (plan.sodiumIntervalMin > 0) {
                                Pill("Sales c/${plan.sodiumIntervalMin} min", MaterialTheme.colorScheme.primary)
                            }
                            if (plan.carbsIntervalMin > 0) {
                                Pill("Gel c/${plan.carbsIntervalMin} min", MaterialTheme.colorScheme.tertiary)
                            }
                        }
                    }
                }

                item {
                    Text(
                        text = if (showAdjust) "Ocultar ajustes" else "Ajustar la sesión",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .clickable { showAdjust = !showAdjust }
                            .padding(vertical = 12.dp)
                    )
                }

                item {
                    AnimatedVisibility(
                        visible = showAdjust,
                        enter = fadeIn(tween(200)) + expandVertically(tween(260)),
                        exit = fadeOut(tween(160)) + shrinkVertically(tween(220))
                    ) {
                        TrainerCard(containerColor = floating) {
                            Text(
                                "Deporte",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(Modifier.height(10.dp))
                            ChipSelector(
                                options = listOf(Sport.RUNNING, Sport.CYCLING, Sport.TREKKING, Sport.SWIMMING),
                                selected = sport,
                                labelOf = { it.label },
                                onSelect = { sport = it }
                            )
                            Spacer(Modifier.height(18.dp))
                            LabeledSlider(
                                label = "Duración",
                                value = durationMin,
                                range = 20f..300f,
                                valueLabel = Formatters.durationShort(durationMin.toInt()),
                                onValueChange = { durationMin = it }
                            )
                            Spacer(Modifier.height(10.dp))
                            Text(
                                "Intensidad",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(Modifier.height(10.dp))
                            ChipSelector(
                                options = EffortIntensity.entries.toList(),
                                selected = intensity,
                                labelOf = { it.label },
                                onSelect = { intensity = it }
                            )
                        }
                    }
                }
            }

            // El botón vive fuera del scroll: siempre a la vista.
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            0f to Color.Transparent,
                            0.35f to background.copy(alpha = 0.92f),
                            1f to background
                        )
                    )
                    .padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 26.dp)
            ) {
                if (safety?.blocksTraining == true) {
                    Button(
                        onClick = onBack,
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(54.dp)
                    ) { Text("Entrenar más tarde", fontWeight = FontWeight.Bold) }
                    Spacer(Modifier.height(10.dp))
                    OutlinedButton(
                        onClick = { startSession() },
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                    ) { Text("Salir igual, bajo mi responsabilidad") }
                } else {
                    Button(
                        onClick = { startSession() },
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp)
                    ) {
                        TrainerIcon("ic_play", tint = MaterialTheme.colorScheme.onPrimary, size = 15)
                        Spacer(Modifier.width(10.dp))
                        Text("Empezar sesión", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
