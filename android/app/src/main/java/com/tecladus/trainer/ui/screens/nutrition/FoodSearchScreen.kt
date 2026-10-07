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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.data.food.OpenFoodFactsClient
import com.tecladus.trainer.domain.model.Food
import com.tecladus.trainer.domain.model.MealType
import com.tecladus.trainer.ui.components.FoodAvatar
import com.tecladus.trainer.ui.components.HairLine
import com.tecladus.trainer.ui.components.NumberField
import com.tecladus.trainer.ui.components.ScreenHeader
import com.tecladus.trainer.ui.components.TrainerIcon
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Buscador de alimentos. Primero el catálogo local (instantáneo, offline) y, si el
 * texto no alcanza, productos de Open Food Facts. Arriba, el atajo a la cámara.
 */
@Composable
fun FoodSearchScreen(
    mealType: MealType,
    onBack: () -> Unit,
    onPhoto: () -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val date by container.nutritionRepository.selectedDate.collectAsState()
    val customFoods by container.nutritionRepository.customFoods.collectAsState()
    val scope = rememberCoroutineScope()

    var query by remember { mutableStateOf("") }
    var selectedFood by remember { mutableStateOf<Food?>(null) }
    var remoteFoods by remember { mutableStateOf<List<Food>>(emptyList()) }
    var searchingRemote by remember { mutableStateOf(false) }

    val localResults = remember(query, customFoods) { container.nutritionRepository.search(query) }

    // Si el catálogo local se queda corto, se buscan productos de góndola.
    LaunchedEffect(query) {
        remoteFoods = emptyList()
        if (query.trim().length < 3) return@LaunchedEffect
        delay(500)
        searchingRemote = true
        remoteFoods = OpenFoodFactsClient.search(query.trim()).map { it.food }
        searchingRemote = false
    }

    Column(modifier = modifier.fillMaxWidth()) {
        ScreenHeader(
            title = mealType.label,
            subtitle = "Buscá, escaneá o cargá lo tuyo",
            onBack = onBack,
            trailing = {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary)
                        .clickable { onPhoto() },
                    contentAlignment = Alignment.Center
                ) {
                    TrainerIcon("ic_search", tint = MaterialTheme.colorScheme.onPrimary, size = 20)
                }
            }
        )
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text("Buscar alimento o producto") },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
        )
        Spacer(Modifier.height(8.dp))

        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp)
        ) {
            items(localResults.size) { index ->
                val food = localResults[index]
                FoodRow(food = food) { selectedFood = food }
                if (index < localResults.lastIndex) HairLine()
            }

            if (query.trim().length >= 3) {
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 20.dp, bottom = 6.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            "Productos de góndola",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (searchingRemote) {
                            Text(
                                "buscando...",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                items(remoteFoods.size) { index ->
                    val food = remoteFoods[index]
                    FoodRow(food = food) { selectedFood = food }
                    if (index < remoteFoods.lastIndex) HairLine()
                }
            }

            item { Spacer(Modifier.height(80.dp)) }
        }
    }

    val food = selectedFood
    if (food != null) {
        var grams by remember(food.id) { mutableStateOf(food.defaultPortionG.toInt().toString()) }
        val gramsValue = grams.toDoubleOrNull() ?: 0.0
        AlertDialog(
            onDismissRequest = { selectedFood = null },
            title = { Text(food.name) },
            text = {
                Column {
                    Text(
                        "Porción sugerida: ${food.portionLabel}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.height(12.dp))
                    NumberField(
                        label = "Cantidad",
                        value = grams,
                        onValueChange = { grams = it },
                        suffix = "g",
                        decimal = true
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        "${food.kcalFor(gramsValue).toInt()} kcal · " +
                            "${food.carbsFor(gramsValue).toInt()} g hidratos · " +
                            "${food.proteinFor(gramsValue).toInt()} g proteína · " +
                            "${food.fatFor(gramsValue).toInt()} g grasa",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        "${food.sodiumFor(gramsValue).toInt()} mg de sodio",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        if (food.id.startsWith("off_")) container.nutritionRepository.addCustomFood(food)
                        container.nutritionRepository.addFood(food, gramsValue, mealType, date)
                    }
                    selectedFood = null
                    onBack()
                }) { Text("Agregar") }
            },
            dismissButton = {
                TextButton(onClick = { selectedFood = null }) { Text("Cancelar") }
            }
        )
    }
}

@Composable
private fun FoodRow(food: Food, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .clip(RoundedCornerShape(14.dp))
            .clickable { onClick() },
        verticalAlignment = Alignment.CenterVertically
    ) {
        FoodAvatar(foodId = food.id, name = food.name, size = 42)
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                food.name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.height(2.dp))
            Text(
                "${food.kcalPer100g.toInt()} kcal/100 g · ${food.portionLabel}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        TrainerIcon("ic_add", tint = MaterialTheme.colorScheme.primary, size = 20)
    }
}
