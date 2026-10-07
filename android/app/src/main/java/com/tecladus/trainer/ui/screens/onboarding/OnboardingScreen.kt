package com.tecladus.trainer.ui.screens.onboarding

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.domain.logic.PaceCalculator
import com.tecladus.trainer.domain.model.BodyGoal
import com.tecladus.trainer.domain.model.FitnessLevel
import com.tecladus.trainer.domain.model.GoalType
import com.tecladus.trainer.domain.model.Sex
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.esLabel
import com.tecladus.trainer.domain.model.formatMinuteOfDay
import com.tecladus.trainer.ui.components.ChipSelector
import com.tecladus.trainer.ui.components.DateInputRow
import com.tecladus.trainer.ui.components.DayPicker
import com.tecladus.trainer.ui.components.NumberField
import com.tecladus.trainer.ui.components.ProgressBarLine
import com.tecladus.trainer.ui.components.TextField
import com.tecladus.trainer.ui.components.TimeStepperRow
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit

private const val LAST_STEP = 13

/**
 * Alta del usuario como conversación: una pregunta por pantalla, en el orden en que
 * alguien las contaría, y avance automático en las que se responden con un toque.
 * Cada dato que se pide alimenta un cálculo concreto: no hay campos decorativos.
 */
@Composable
fun OnboardingScreen(
    initialProfile: UserProfile,
    onFinish: (UserProfile) -> Unit
) {
    var step by remember { mutableStateOf(0) }
    var draft by remember { mutableStateOf(initialProfile) }
    var name by remember { mutableStateOf(initialProfile.name) }
    var age by remember { mutableStateOf(initialProfile.age.toString()) }
    var weight by remember { mutableStateOf(initialProfile.weightKg.toInt().toString()) }
    var height by remember { mutableStateOf(initialProfile.heightCm.toInt().toString()) }
    var refDistance by remember { mutableStateOf("") }
    var refTime by remember { mutableStateOf("") }
    var days by remember { mutableStateOf(initialProfile.trainingSchedule.keys.toSet()) }
    var times by remember { mutableStateOf(initialProfile.trainingSchedule) }

    fun buildProfile(): UserProfile = draft.copy(
        name = name.trim(),
        age = age.toIntOrNull() ?: draft.age,
        weightKg = weight.toDoubleOrNull() ?: draft.weightKg,
        heightCm = height.toDoubleOrNull() ?: draft.heightCm,
        trainingSchedule = days.sortedBy { it.value }.associateWith { times[it] ?: 18 * 60 },
        referenceDistanceKm = refDistance.toDoubleOrNull(),
        referenceTimeMinutes = refTime.toDoubleOrNull(),
        onboardingCompleted = true
    )

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { onFinish(buildProfile()) }

    fun finish() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            onFinish(buildProfile())
        }
    }

    fun next() {
        if (step < LAST_STEP) step++ else finish()
    }

    val firstName = name.trim().split(" ").firstOrNull().orEmpty()
    val canContinue = when (step) {
        10 -> days.isNotEmpty()
        else -> true
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp)
    ) {
        Spacer(Modifier.height(28.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (step > 0) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .clickable { step-- },
                    contentAlignment = Alignment.Center
                ) {
                    TrainerIcon("ic_back", size = 16)
                }
                Spacer(Modifier.size(12.dp))
            }
            Text(
                text = "Paso ${step + 1} de ${LAST_STEP + 1}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Spacer(Modifier.height(10.dp))
        ProgressBarLine(progress = (step + 1) / (LAST_STEP + 1f), heightDp = 6)

        Box(modifier = Modifier.weight(1f)) {
            Crossfade(
                targetState = step,
                animationSpec = tween(durationMillis = 320, easing = FastOutSlowInEasing),
                label = "onboardingStep"
            ) { current ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                ) {
                    Spacer(Modifier.height(28.dp))
                    when (current) {
                        0 -> StepBlock(
                            title = "Bienvenido a Trainer",
                            hint = "Vamos a armar tu plan, tu nutrición y tu estrategia de hidratación. " +
                                "Te hago unas preguntas cortas, de a una por vez."
                        ) {
                            TextField(label = "¿Cómo te llamás?", value = name, onValueChange = { name = it })
                        }

                        1 -> StepBlock(
                            title = if (firstName.isBlank()) "Contame de vos" else "Hola, $firstName",
                            hint = "El sexo cambia el cálculo del metabolismo basal y de la sudoración."
                        ) {
                            ChipSelector(
                                options = Sex.entries.toList(),
                                selected = draft.sex,
                                labelOf = { it.label },
                                onSelect = { draft = draft.copy(sex = it); next() }
                            )
                        }

                        2 -> StepBlock(
                            title = "¿Qué edad tenés?",
                            hint = "Define tu frecuencia cardíaca máxima estimada y tus zonas de entrenamiento."
                        ) {
                            NumberField(label = "Edad", value = age, onValueChange = { age = it }, suffix = "años")
                        }

                        3 -> StepBlock(
                            title = "¿Cuánto pesás?",
                            hint = "Es la variable más importante: calorías, gramos de hidratos por kilo, " +
                                "litros de sudor y sales salen de acá."
                        ) {
                            NumberField(
                                label = "Peso",
                                value = weight,
                                onValueChange = { weight = it },
                                suffix = "kg",
                                decimal = true
                            )
                        }

                        4 -> StepBlock(
                            title = "¿Y tu altura?",
                            hint = "Completa la ecuación de Mifflin-St Jeor para tu metabolismo basal."
                        ) {
                            NumberField(label = "Altura", value = height, onValueChange = { height = it }, suffix = "cm")
                        }

                        5 -> StepBlock(
                            title = "¿Qué buscás con el peso?",
                            hint = "Ajusta el déficit o superávit sin comprometer el rendimiento."
                        ) {
                            ChipSelector(
                                options = BodyGoal.entries.toList(),
                                selected = draft.bodyGoal,
                                labelOf = { it.label },
                                onSelect = { draft = draft.copy(bodyGoal = it); next() }
                            )
                        }

                        6 -> StepBlock(
                            title = "¿Qué deporte hacés?",
                            hint = "Podés cambiarlo cuando quieras desde tu perfil."
                        ) {
                            ChipSelector(
                                options = listOf(Sport.RUNNING, Sport.CYCLING, Sport.TREKKING, Sport.TRIATHLON),
                                selected = draft.primarySport,
                                labelOf = { it.label },
                                onSelect = { sport ->
                                    draft = draft.copy(
                                        primarySport = sport,
                                        goal = PaceCalculator.goalTypeFor(sport.name)
                                    )
                                    next()
                                }
                            )
                        }

                        7 -> StepBlock(
                            title = "¿Para qué estás entrenando?",
                            hint = "El plan se arma hacia atrás desde tu meta."
                        ) {
                            ChipSelector(
                                options = GoalType.entries.filter {
                                    it.sport == draft.primarySport || it == GoalType.GENERAL_FITNESS
                                },
                                selected = draft.goal,
                                labelOf = { it.label },
                                onSelect = { draft = draft.copy(goal = it); next() },
                                perRow = 1
                            )
                        }

                        8 -> StepBlock(
                            title = "¿Cómo venís entrenando?",
                            hint = "Con esto dimensionamos el volumen inicial para que no te pases de rosca."
                        ) {
                            Column {
                                ChipSelector(
                                    options = FitnessLevel.entries.toList(),
                                    selected = draft.level,
                                    labelOf = { it.label },
                                    onSelect = { draft = draft.copy(level = it); next() },
                                    perRow = 1
                                )
                                Spacer(Modifier.height(10.dp))
                                Text(
                                    draft.level.description,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        9 -> StepBlock(
                            title = "¿Tenés fecha para tu evento?",
                            hint = "Si ya sabés cuándo es, armamos la periodización completa con su afinamiento final."
                        ) {
                            Column {
                                DateInputRow(
                                    label = "Fecha del evento",
                                    date = draft.eventDate,
                                    onDateChange = { draft = draft.copy(eventDate = it) }
                                )
                                val event = draft.eventDate
                                if (event != null) {
                                    Spacer(Modifier.height(12.dp))
                                    val weeks = ChronoUnit.WEEKS.between(LocalDate.now(), event)
                                    Text(
                                        if (weeks >= 1) "Tenemos $weeks semanas para prepararte. Alcanza."
                                        else "Es muy pronto: vamos a priorizar llegar entero, sin sobrecargas.",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                            }
                        }

                        10 -> StepBlock(
                            title = "¿Qué días podés entrenar?",
                            hint = "Elegí sólo los días que realmente vas a poder. Es mejor un plan de 3 días " +
                                "que cumplís que uno de 6 que abandonás."
                        ) {
                            Column {
                                DayPicker(
                                    selected = days,
                                    onToggle = { day ->
                                        days = if (day in days) days - day else days + day
                                        if (day !in times) times = times + (day to 18 * 60)
                                    }
                                )
                                Spacer(Modifier.height(14.dp))
                                Text(
                                    text = when (days.size) {
                                        0 -> "Marcá al menos un día para seguir."
                                        1, 2 -> "${days.size} día(s): vamos a priorizar calidad sobre volumen."
                                        3, 4 -> "${days.size} días: la distribución ideal para la mayoría."
                                        else -> "${days.size} días: sumamos regenerativos y trabajo de fuerza."
                                    },
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        11 -> StepBlock(
                            title = "¿A qué hora entrenás?",
                            hint = "Te avisamos una hora antes con la sesión y lo que tenés que llevar. " +
                                "También usamos el horario para ubicar el fondo largo y los descansos."
                        ) {
                            Column {
                                days.sortedBy { it.value }.forEach { day ->
                                    TimeStepperRow(
                                        day = day,
                                        minuteOfDay = times[day] ?: 18 * 60,
                                        onChange = { minutes -> times = times + (day to minutes) }
                                    )
                                    Spacer(Modifier.height(18.dp))
                                }
                                if (days.isEmpty()) {
                                    Text(
                                        "Volvé un paso y elegí tus días.",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }

                        12 -> StepBlock(
                            title = "¿Tenés alguna marca reciente?",
                            hint = "Con una referencia calculamos tus ritmos exactos. Si no tenés, la estimamos " +
                                "por tu nivel y la vamos ajustando con tus sesiones."
                        ) {
                            Column {
                                NumberField(
                                    label = "Distancia",
                                    value = refDistance,
                                    onValueChange = { refDistance = it },
                                    suffix = "km",
                                    decimal = true
                                )
                                Spacer(Modifier.height(12.dp))
                                NumberField(
                                    label = "Tiempo",
                                    value = refTime,
                                    onValueChange = { refTime = it },
                                    suffix = "minutos",
                                    decimal = true
                                )
                                val km = refDistance.toDoubleOrNull()
                                val minutes = refTime.toDoubleOrNull()
                                if (km != null && minutes != null && km > 0.5 && minutes > 1) {
                                    val preview = draft.copy(
                                        referenceDistanceKm = km,
                                        referenceTimeMinutes = minutes
                                    )
                                    Spacer(Modifier.height(16.dp))
                                    TrainerCard {
                                        Text("Tus ritmos", style = MaterialTheme.typography.titleMedium)
                                        Spacer(Modifier.height(10.dp))
                                        listOf(
                                            "Rodaje suave" to PaceCalculator.predictedPaceSecPerKm(preview, 42.195) + 70,
                                            "Tempo" to PaceCalculator.predictedPaceSecPerKm(preview, 10.0) + 25,
                                            "Series" to PaceCalculator.predictedPaceSecPerKm(preview, 5.0),
                                            "Ritmo objetivo" to PaceCalculator.predictedPaceSecPerKm(
                                                preview, draft.goal.distanceKm
                                            )
                                        ).forEach { (label, pace) ->
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween
                                            ) {
                                                Text(label, style = MaterialTheme.typography.bodySmall)
                                                Text(
                                                    "${Formatters.pace(pace)} min/km",
                                                    style = MaterialTheme.typography.bodySmall,
                                                    fontWeight = FontWeight.SemiBold
                                                )
                                            }
                                            Spacer(Modifier.height(4.dp))
                                        }
                                    }
                                }
                            }
                        }

                        else -> SummaryStep(
                            profile = buildProfile(),
                            days = days.sortedBy { it.value },
                            times = times
                        )
                    }
                    Spacer(Modifier.height(24.dp))
                }
            }
        }

        if (step == 9 || step == 12) {
            TextButton(
                onClick = {
                    if (step == 9) draft = draft.copy(eventDate = null)
                    if (step == 12) {
                        refDistance = ""
                        refTime = ""
                    }
                    next()
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text("No tengo, seguir") }
        }

        Button(
            onClick = { next() },
            enabled = canContinue,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
        ) {
            Text(if (step == LAST_STEP) "Crear mi plan" else "Continuar")
        }
        Spacer(Modifier.height(24.dp))
    }
}

/** Encabezado consistente de cada pregunta: título grande, contexto corto y el control. */
@Composable
private fun StepBlock(
    title: String,
    hint: String,
    content: @Composable () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(title, style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(10.dp))
        Text(
            hint,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(26.dp))
        content()
    }
}

@Composable
private fun SummaryStep(
    profile: UserProfile,
    days: List<DayOfWeek>,
    times: Map<DayOfWeek, Int>
) {
    val name = profile.name.trim().split(" ").firstOrNull().orEmpty()
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            if (name.isBlank()) "Todo listo" else "Listo, $name",
            style = MaterialTheme.typography.headlineMedium
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Con esto armamos tu calendario, tus objetivos de nutrición para cada día y tu plan de " +
                "hidratación para cada sesión.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(22.dp))
        TrainerCard(accent = MaterialTheme.colorScheme.primary) {
            SummaryRow("Objetivo", profile.goal.label)
            SummaryRow(
                "Evento",
                profile.eventDate?.let { Formatters.fullDate(it) } ?: "Sin fecha: plan de 8 semanas"
            )
            SummaryRow("Nivel", profile.level.label)
            SummaryRow("Días", "${days.size} por semana")
            Spacer(Modifier.height(10.dp))
            days.forEach { day ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(day.esLabel(), style = MaterialTheme.typography.bodySmall)
                    Text(
                        formatMinuteOfDay(times[day] ?: 18 * 60),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Spacer(Modifier.height(4.dp))
            }
        }
        Spacer(Modifier.height(14.dp))
        TrainerCard(accent = MaterialTheme.colorScheme.secondary) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TrainerIcon("ic_notification", tint = MaterialTheme.colorScheme.secondary, size = 20)
                Spacer(Modifier.size(10.dp))
                Text("Recordatorios", style = MaterialTheme.typography.titleMedium)
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "Te vamos a avisar una hora antes de cada sesión, con lo que tenés que llevar de agua, " +
                    "sales e hidratos. Podés desactivarlos cuando quieras.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun SummaryRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
    }
    Spacer(Modifier.height(6.dp))
}
