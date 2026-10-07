package com.tecladus.trainer.ui.screens.profile

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
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
import com.tecladus.trainer.domain.logic.PaceCalculator
import com.tecladus.trainer.domain.model.BodyGoal
import com.tecladus.trainer.domain.model.FitnessLevel
import com.tecladus.trainer.domain.model.GoalType
import com.tecladus.trainer.domain.model.HrZone
import com.tecladus.trainer.domain.model.Sex
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.ui.components.ChipSelector
import com.tecladus.trainer.ui.components.DateInputRow
import com.tecladus.trainer.ui.components.DayPicker
import com.tecladus.trainer.ui.components.TimeStepperRow
import com.tecladus.trainer.ui.components.FieldSpacer
import com.tecladus.trainer.ui.components.NumberField
import com.tecladus.trainer.ui.components.SectionTitle
import com.tecladus.trainer.ui.components.TextField
import com.tecladus.trainer.ui.components.TrainerCard
import kotlinx.coroutines.launch

/** Perfil, objetivos y calculadora de tasa de sudoración. */
@Composable
fun ProfileScreen(modifier: Modifier = Modifier) {
    val container = ServiceLocator.container
    val profile by container.profileRepository.profile.collectAsState()
    val plan by container.planRepository.plan.collectAsState()
    val scope = rememberCoroutineScope()

    // Si el plan quedó armado con otros días u otros horarios, se ofrece rearmarlo.
    val planOutdated = plan.isNotEmpty() && run {
        val planDays = plan.filter { it.type != com.tecladus.trainer.domain.model.WorkoutType.REST &&
            it.type != com.tecladus.trainer.domain.model.WorkoutType.RACE }
            .associate { it.date.dayOfWeek to it.scheduledMinuteOfDay }
        planDays.keys != profile.trainingSchedule.keys ||
            profile.trainingSchedule.any { (day, minute) -> planDays[day] != minute }
    }

    var weight by remember(profile.weightKg) { mutableStateOf(profile.weightKg.toInt().toString()) }
    var height by remember(profile.heightCm) { mutableStateOf(profile.heightCm.toInt().toString()) }
    var age by remember(profile.age) { mutableStateOf(profile.age.toString()) }
    var refDistance by remember(profile.referenceDistanceKm) {
        mutableStateOf(profile.referenceDistanceKm?.toString() ?: "")
    }
    var refTime by remember(profile.referenceTimeMinutes) {
        mutableStateOf(profile.referenceTimeMinutes?.toString() ?: "")
    }
    var saved by remember { mutableStateOf(false) }

    fun persist(update: (com.tecladus.trainer.domain.model.UserProfile) -> com.tecladus.trainer.domain.model.UserProfile) {
        scope.launch {
            container.profileRepository.save(update(container.profileRepository.profile.value))
            saved = true
        }
    }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item { Text("Perfil", style = MaterialTheme.typography.headlineMedium) }

        item {
            TrainerCard {
                SectionTitle("Datos personales")
                FieldSpacer()
                TextField(
                    label = "Nombre",
                    value = profile.name,
                    onValueChange = { name -> persist { it.copy(name = name) } }
                )
                FieldSpacer()
                ChipSelector(
                    options = Sex.entries.toList(),
                    selected = profile.sex,
                    labelOf = { it.label },
                    onSelect = { sex -> persist { it.copy(sex = sex) } }
                )
                FieldSpacer()
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberField(
                        label = "Peso",
                        value = weight,
                        suffix = "kg",
                        decimal = true,
                        onValueChange = { value ->
                            weight = value
                            value.toDoubleOrNull()?.let { w -> persist { it.copy(weightKg = w) } }
                        },
                        modifier = Modifier.weight(1f)
                    )
                    NumberField(
                        label = "Altura",
                        value = height,
                        suffix = "cm",
                        onValueChange = { value ->
                            height = value
                            value.toDoubleOrNull()?.let { h -> persist { it.copy(heightCm = h) } }
                        },
                        modifier = Modifier.weight(1f)
                    )
                    NumberField(
                        label = "Edad",
                        value = age,
                        onValueChange = { value ->
                            age = value
                            value.toIntOrNull()?.let { a -> persist { it.copy(age = a) } }
                        },
                        modifier = Modifier.weight(0.8f)
                    )
                }
                FieldSpacer()
                ChipSelector(
                    options = BodyGoal.entries.toList(),
                    selected = profile.bodyGoal,
                    labelOf = { it.label },
                    onSelect = { goal -> persist { it.copy(bodyGoal = goal) } }
                )
                FieldSpacer()
                Text(
                    "IMC ${Formatters.decimal(profile.bmi, 1)} · Metabolismo basal " +
                        "${NutritionCalculator.bmr(profile).toInt()} kcal · FC máx estimada ${profile.maxHr} ppm",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            TrainerCard(accent = MaterialTheme.colorScheme.primary) {
                SectionTitle("Objetivo")
                FieldSpacer()
                ChipSelector(
                    options = listOf(Sport.RUNNING, Sport.CYCLING, Sport.TREKKING, Sport.TRIATHLON),
                    selected = profile.primarySport,
                    labelOf = { it.label },
                    onSelect = { sport ->
                        persist { it.copy(primarySport = sport, goal = PaceCalculator.goalTypeFor(sport.name)) }
                    }
                )
                FieldSpacer()
                ChipSelector(
                    options = GoalType.entries.filter {
                        it.sport == profile.primarySport || it == GoalType.GENERAL_FITNESS
                    },
                    selected = profile.goal,
                    labelOf = { it.label },
                    onSelect = { goal -> persist { it.copy(goal = goal) } }
                )
                FieldSpacer()
                ChipSelector(
                    options = FitnessLevel.entries.toList(),
                    selected = profile.level,
                    labelOf = { it.label },
                    onSelect = { level -> persist { it.copy(level = level) } }
                )
                FieldSpacer()
                Text(
                    "Días que podés entrenar",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.height(10.dp))
                DayPicker(
                    selected = profile.trainingSchedule.keys,
                    onToggle = { day ->
                        persist { current ->
                            val schedule = current.trainingSchedule.toMutableMap()
                            if (schedule.containsKey(day)) {
                                if (schedule.size > 1) schedule.remove(day)
                            } else {
                                schedule[day] = 18 * 60
                            }
                            current.copy(trainingSchedule = schedule.toSortedMap())
                        }
                    }
                )
                Spacer(Modifier.height(16.dp))
                profile.trainingDays.forEach { day ->
                    TimeStepperRow(
                        day = day,
                        minuteOfDay = profile.trainingSchedule[day] ?: 18 * 60,
                        onChange = { minutes ->
                            persist { current ->
                                current.copy(trainingSchedule = current.trainingSchedule + (day to minutes))
                            }
                        }
                    )
                    Spacer(Modifier.height(16.dp))
                }
                Text(
                    "Te avisamos una hora antes de cada sesión con lo que tenés que llevar.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                FieldSpacer()
                DateInputRow(
                    label = "Fecha del evento",
                    date = profile.eventDate,
                    onDateChange = { date -> persist { it.copy(eventDate = date) } }
                )
                FieldSpacer()
                AnimatedVisibility(
                    visible = planOutdated,
                    enter = fadeIn(tween(220)) + expandVertically(tween(260)),
                    exit = fadeOut(tween(180)) + shrinkVertically(tween(220))
                ) {
                    Column {
                        Text(
                            "Cambiaste tu agenda: regenerá el plan para que las sesiones caigan en tus " +
                                "nuevos días y horarios.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.SemiBold
                        )
                        Spacer(Modifier.height(10.dp))
                    }
                }
                Button(
                    onClick = { scope.launch { container.planRepository.regenerate(profile) } },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Regenerar plan de entrenamiento") }
            }
        }

        item {
            TrainerCard {
                SectionTitle("Rendimiento")
                FieldSpacer()
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberField(
                        label = "Marca: distancia",
                        value = refDistance,
                        suffix = "km",
                        decimal = true,
                        onValueChange = { value ->
                            refDistance = value
                            persist { it.copy(referenceDistanceKm = value.toDoubleOrNull()) }
                        },
                        modifier = Modifier.weight(1f)
                    )
                    NumberField(
                        label = "Tiempo",
                        value = refTime,
                        suffix = "min",
                        decimal = true,
                        onValueChange = { value ->
                            refTime = value
                            persist { it.copy(referenceTimeMinutes = value.toDoubleOrNull()) }
                        },
                        modifier = Modifier.weight(1f)
                    )
                }
                FieldSpacer()
                Text("Ritmos de entrenamiento", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                listOf(
                    "Suave" to PaceCalculator.predictedPaceSecPerKm(profile, 42.195) + 70,
                    "Fondo" to PaceCalculator.predictedPaceSecPerKm(profile, 42.195) + 45,
                    "Tempo" to PaceCalculator.predictedPaceSecPerKm(profile, 10.0) + 25,
                    "Series" to PaceCalculator.predictedPaceSecPerKm(profile, 5.0),
                    "Objetivo ${profile.goal.label}" to PaceCalculator.goalRacePace(profile)
                ).forEach { (label, pace) ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(label, style = MaterialTheme.typography.bodySmall)
                        Text(
                            "${Formatters.pace(pace)} min/km",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
                FieldSpacer()
                Text("Zonas de frecuencia cardíaca", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                HrZone.entries.forEach { zone ->
                    val range = zone.bpmRange(profile.maxHr)
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(zone.label, style = MaterialTheme.typography.bodySmall)
                        Text(
                            "${range.first} - ${range.last} ppm",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        item {
            TrainerCard {
                SectionTitle("Sobre los cálculos")
                Spacer(Modifier.height(8.dp))
                Text(
                    "La app asume valores estándar de sudor (700 mg de sodio por litro) y de tolerancia " +
                        "intestinal (hasta 70 g de hidratos por hora), y ajusta el resto con tus datos. " +
                        "Metabolismo basal: Mifflin-St Jeor. Ritmos: fórmula de Riegel. " +
                        "Hidratación: reposición del 70-80% del sudor con un techo de 800 ml/h. " +
                        "Sodio: según la concentración de tu sudor. Hidratos: 30-90 g/h según duración y " +
                        "tolerancia. Carga: ratio agudo:crónico (ACWR) de 7 vs. 28 días.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item { Spacer(Modifier.height(60.dp)) }
    }
}
