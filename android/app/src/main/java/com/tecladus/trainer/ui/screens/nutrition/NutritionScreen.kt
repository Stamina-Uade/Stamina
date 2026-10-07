package com.tecladus.trainer.ui.screens.nutrition

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.Formatters
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.domain.logic.NutritionCalculator
import com.tecladus.trainer.domain.logic.PaceCalculator
import com.tecladus.trainer.domain.model.MealEntry
import com.tecladus.trainer.domain.model.MealType
import com.tecladus.trainer.ui.components.AnimatedNumber
import com.tecladus.trainer.ui.components.FoodAvatar
import com.tecladus.trainer.ui.components.HairLine
import com.tecladus.trainer.ui.components.MacroRow
import com.tecladus.trainer.ui.components.Pill
import com.tecladus.trainer.ui.components.ProgressBarLine
import com.tecladus.trainer.ui.components.ProgressRing
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import com.tecladus.trainer.ui.components.UndoBar
import com.tecladus.trainer.ui.theme.Hydration
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Diario del día: un bloque de objetivos, uno de agua y la lista de comidas.
 * Las comidas son filas, no tarjetas: siete cajas apiladas cansan la vista.
 */
@Composable
fun NutritionScreen(
    onAddFood: (MealType) -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val profile by container.profileRepository.profile.collectAsState()
    val plan by container.planRepository.plan.collectAsState()
    val entries by container.nutritionRepository.entries.collectAsState()
    val waterMl by container.nutritionRepository.waterMl.collectAsState()
    val date by container.nutritionRepository.selectedDate.collectAsState()
    val undoAction by container.nutritionRepository.lastAction.collectAsState()
    val scope = rememberCoroutineScope()

    LaunchedEffect(undoAction) {
        if (undoAction != null) {
            delay(6000)
            container.nutritionRepository.clearUndo()
        }
    }

    val workout = plan.firstOrNull { it.date == date }
    val eventMinutes = remember(profile) { PaceCalculator.estimatedGoalTimeMinutes(profile) }
    val targets = remember(profile, workout, date) {
        NutritionCalculator.targetsFor(profile, workout, date, eventMinutes)
    }
    val kcal = entries.sumOf { it.kcal }

    Box(modifier = modifier.fillMaxWidth()) {
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ArrowButton("ic_back") {
                        scope.launch { container.nutritionRepository.selectDate(date.minusDays(1)) }
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            Formatters.relativeDay(date).let { if (it.length > 12) "Nutrición" else it },
                            style = MaterialTheme.typography.titleLarge
                        )
                        Text(
                            Formatters.fullDate(date),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    ArrowButton("ic_chevron_right") {
                        scope.launch { container.nutritionRepository.selectDate(date.plusDays(1)) }
                    }
                }
            }

            item {
                TrainerCard(contentPadding = PaddingValues(20.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ProgressRing(
                            progress = if (targets.kcal > 0) (kcal / targets.kcal).toFloat() else 0f,
                            modifier = Modifier.size(96.dp),
                            color = MaterialTheme.colorScheme.tertiary,
                            strokeWidth = 20f
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                AnimatedNumber(
                                    value = kcal.toInt(),
                                    style = MaterialTheme.typography.titleLarge
                                )
                                Text(
                                    "de ${targets.kcal}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        Spacer(Modifier.width(18.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            MacroRow(
                                "Hidratos", entries.sumOf { it.carbsG }, targets.carbsG, "g",
                                MaterialTheme.colorScheme.primary
                            )
                            Spacer(Modifier.height(10.dp))
                            MacroRow(
                                "Proteína", entries.sumOf { it.proteinG }, targets.proteinG, "g",
                                Hydration
                            )
                            Spacer(Modifier.height(10.dp))
                            MacroRow(
                                "Grasas", entries.sumOf { it.fatG }, targets.fatG, "g",
                                MaterialTheme.colorScheme.tertiary
                            )
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Pill(targets.dayLoad.label, MaterialTheme.colorScheme.primary)
                        if (targets.trainingKcal > 0) {
                            Pill("+${targets.trainingKcal} kcal del entreno", MaterialTheme.colorScheme.tertiary)
                        }
                    }
                }
            }

            item {
                TrainerCard(accent = MaterialTheme.colorScheme.secondary, contentPadding = PaddingValues(20.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            TrainerIcon("ic_water", tint = Hydration, size = 17)
                            Spacer(Modifier.width(9.dp))
                            Text("Agua", style = MaterialTheme.typography.titleMedium)
                        }
                        AnimatedNumber(
                            value = waterMl,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            suffix = " / ${targets.waterMl} ml"
                        )
                    }
                    Spacer(Modifier.height(14.dp))
                    ProgressBarLine(
                        progress = if (targets.waterMl > 0) waterMl / targets.waterMl.toFloat() else 0f,
                        color = Hydration,
                        heightDp = 8
                    )
                    Spacer(Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(250, 500, 750).forEach { ml ->
                            WaterButton(
                                label = "+$ml",
                                modifier = Modifier.weight(1f)
                            ) { scope.launch { container.nutritionRepository.addWater(ml) } }
                        }
                    }
                }
            }

            item {
                Text(
                    "Comidas",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }

            val meals = MealType.entries.sortedBy { it.order }
            items(meals.size) { index ->
                val meal = meals[index]
                val mealEntries = entries.filter { it.mealType == meal }
                Column {
                    MealRow(
                        title = meal.label,
                        kcal = mealEntries.sumOf { it.kcal }.toInt(),
                        empty = mealEntries.isEmpty(),
                        onAdd = { onAddFood(meal) }
                    )
                    mealEntries.forEach { entry ->
                        FoodRow(entry = entry) {
                            scope.launch { container.nutritionRepository.removeEntry(entry.id) }
                        }
                    }
                    if (index < meals.lastIndex) HairLine()
                }
            }

            item { Spacer(Modifier.height(40.dp)) }
        }

        UndoBar(
            visible = undoAction != null,
            message = undoAction?.message ?: "",
            modifier = Modifier.align(Alignment.BottomCenter),
            onUndo = { scope.launch { container.nutritionRepository.undoLast() } }
        )
    }
}

@Composable
private fun ArrowButton(icon: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        TrainerIcon(icon, tint = MaterialTheme.colorScheme.onSurfaceVariant, size = 18)
    }
}

@Composable
private fun WaterButton(label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .height(46.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(MaterialTheme.colorScheme.background)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun MealRow(title: String, kcal: Int, empty: Boolean, onAdd: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (empty) MaterialTheme.colorScheme.onSurfaceVariant
                else MaterialTheme.colorScheme.onSurface
            )
            if (!empty) {
                Spacer(Modifier.height(2.dp))
                Text(
                    "$kcal kcal",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surface)
                .clickable { onAdd() },
            contentAlignment = Alignment.Center
        ) {
            TrainerIcon("ic_add", tint = MaterialTheme.colorScheme.primary, size = 20)
        }
    }
}

@Composable
private fun FoodRow(entry: MealEntry, onRemove: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        FoodAvatar(foodId = entry.foodId, name = entry.foodName, size = 34)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(entry.foodName, style = MaterialTheme.typography.bodySmall)
            Text(
                "${entry.grams.toInt()} g · ${entry.carbsG.toInt()}C ${entry.proteinG.toInt()}P ${entry.fatG.toInt()}G",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            "${entry.kcal.toInt()} kcal",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .clickable { onRemove() },
            contentAlignment = Alignment.Center
        ) {
            TrainerIcon("ic_close", tint = MaterialTheme.colorScheme.outline, size = 14)
        }
    }
}
