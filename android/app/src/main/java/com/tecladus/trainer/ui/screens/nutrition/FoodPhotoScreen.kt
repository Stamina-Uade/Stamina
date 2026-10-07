package com.tecladus.trainer.ui.screens.nutrition

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.tecladus.trainer.core.ServiceLocator
import com.tecladus.trainer.data.food.FoodPhotoAnalyzer
import com.tecladus.trainer.data.food.PhotoResult
import com.tecladus.trainer.domain.model.Food
import com.tecladus.trainer.domain.model.MealType
import com.tecladus.trainer.ui.components.FoodAvatar
import com.tecladus.trainer.ui.components.NumberField
import com.tecladus.trainer.ui.components.Pill
import com.tecladus.trainer.ui.components.RemoteImage
import com.tecladus.trainer.ui.components.ScreenHeader
import com.tecladus.trainer.ui.components.TextField
import com.tecladus.trainer.ui.components.TrainerCard
import com.tecladus.trainer.ui.components.TrainerIcon
import kotlinx.coroutines.launch
import java.io.File

/**
 * Foto del producto -> qué es y qué tiene.
 *
 * La app propone; el usuario corrige. Todos los valores quedan editables antes de
 * guardar, y lo guardado se suma al catálogo propio para la próxima vez.
 */
@Composable
fun FoodPhotoScreen(
    mealType: MealType,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val container = ServiceLocator.container
    val date by container.nutritionRepository.selectedDate.collectAsState()
    val customFoods by container.nutritionRepository.customFoods.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var photo by remember { mutableStateOf<Bitmap?>(null) }
    var analyzing by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<PhotoResult?>(null) }
    var imageUrl by remember { mutableStateOf<String?>(null) }

    // Campos editables: la foto los completa, el usuario los corrige.
    var name by remember { mutableStateOf("") }
    var grams by remember { mutableStateOf("100") }
    var kcal by remember { mutableStateOf("") }
    var carbs by remember { mutableStateOf("") }
    var protein by remember { mutableStateOf("") }
    var fat by remember { mutableStateOf("") }
    var sodium by remember { mutableStateOf("") }
    var sourceId by remember { mutableStateOf("") }

    fun fillFrom(food: Food, portion: Double = food.defaultPortionG) {
        name = food.name
        grams = portion.toInt().toString()
        kcal = food.kcalPer100g.toInt().toString()
        carbs = food.carbsPer100g.toInt().toString()
        protein = food.proteinPer100g.toInt().toString()
        fat = food.fatPer100g.toInt().toString()
        sodium = food.sodiumMgPer100g.toInt().toString()
        sourceId = food.id
    }

    val photoFile = remember {
        File(context.cacheDir, "fotos").apply { mkdirs() }.let { File(it, "producto.jpg") }
    }
    val photoUri = remember {
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", photoFile)
    }

    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success ->
        if (!success) return@rememberLauncherForActivityResult
        scope.launch {
            analyzing = true
            result = null
            imageUrl = null
            val bitmap = decodeScaled(photoFile, 1600)
            photo = bitmap
            if (bitmap != null) {
                val analysis = FoodPhotoAnalyzer.analyze(bitmap, customFoods)
                result = analysis
                when (analysis) {
                    is PhotoResult.Product -> {
                        fillFrom(analysis.product.food)
                        imageUrl = analysis.product.imageUrl
                    }
                    is PhotoResult.Suggestions -> analysis.foods.firstOrNull()?.let { fillFrom(it) }
                    PhotoResult.Unknown -> Unit
                }
            }
            analyzing = false
        }
    }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            ScreenHeader(
                title = "Foto del producto",
                subtitle = "Se suma a ${mealType.label.lowercase()}",
                onBack = onBack
            )
        }

        item {
            val bitmap = photo
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .padding(horizontal = 20.dp)
                        .fillMaxWidth()
                        .height(220.dp)
                        .clip(RoundedCornerShape(22.dp))
                )
            } else {
                TrainerCard(
                    modifier = Modifier.padding(horizontal = 20.dp),
                    contentPadding = PaddingValues(24.dp)
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        TrainerIcon("ic_search", tint = MaterialTheme.colorScheme.primary, size = 30)
                        Text("Sacale una foto al producto", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "Si tiene código de barras traemos el nombre, la marca y la tabla nutricional " +
                                "exacta. Si es comida sin envase, te proponemos opciones para elegir.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        item {
            Button(
                onClick = { cameraLauncher.launch(photoUri) },
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .padding(horizontal = 20.dp)
                    .fillMaxWidth()
                    .height(52.dp)
            ) {
                Text(if (photo == null) "Sacar foto" else "Sacar otra foto", fontWeight = FontWeight.Bold)
            }
        }

        if (analyzing) {
            item {
                TrainerCard(modifier = Modifier.padding(horizontal = 20.dp)) {
                    Text("Leyendo la foto...", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Buscamos el código de barras y, si no hay, reconocemos qué comida es.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        when (val current = result) {
            is PhotoResult.Product -> item {
                TrainerCard(
                    modifier = Modifier.padding(horizontal = 20.dp),
                    accent = MaterialTheme.colorScheme.tertiary
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RemoteImage(
                            url = imageUrl,
                            modifier = Modifier.size(56.dp)
                        )
                        Spacer(Modifier.width(14.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Producto reconocido", style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.height(3.dp))
                            Text(current.product.food.name, style = MaterialTheme.typography.titleMedium)
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "Código ${current.product.barcode} · datos de Open Food Facts",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            is PhotoResult.Suggestions -> item {
                TrainerCard(modifier = Modifier.padding(horizontal = 20.dp)) {
                    Text("¿Es alguno de estos?", style = MaterialTheme.typography.titleMedium)
                    if (current.labels.isNotEmpty()) {
                        Spacer(Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            current.labels.take(3).forEach { label ->
                                Pill(label, MaterialTheme.colorScheme.primary)
                            }
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    current.foods.forEach { food ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            FoodAvatar(foodId = food.id, name = food.name, size = 38)
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(food.name, style = MaterialTheme.typography.bodySmall)
                                Text(
                                    "${food.kcalPer100g.toInt()} kcal/100 g",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            OutlinedButton(
                                onClick = { fillFrom(food) },
                                shape = RoundedCornerShape(12.dp)
                            ) { Text("Usar") }
                        }
                    }
                }
            }

            PhotoResult.Unknown -> item {
                TrainerCard(modifier = Modifier.padding(horizontal = 20.dp)) {
                    Text("No lo reconocimos", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Probá enfocando el código de barras, o cargalo a mano acá abajo: " +
                            "queda guardado para la próxima.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            null -> Unit
        }

        item {
            TrainerCard(modifier = Modifier.padding(horizontal = 20.dp)) {
                Text("Qué tiene", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(
                    "Editá cualquier valor: manda lo que dice el envase.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(14.dp))
                TextField(label = "Nombre", value = name, onValueChange = { name = it })
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberField(
                        label = "Cantidad",
                        value = grams,
                        onValueChange = { grams = it },
                        suffix = "g",
                        decimal = true,
                        modifier = Modifier.weight(1f)
                    )
                    NumberField(
                        label = "Calorías",
                        value = kcal,
                        onValueChange = { kcal = it },
                        suffix = "kcal/100 g",
                        decimal = true,
                        modifier = Modifier.weight(1.3f)
                    )
                }
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberField(
                        label = "Hidratos",
                        value = carbs,
                        onValueChange = { carbs = it },
                        suffix = "g",
                        decimal = true,
                        modifier = Modifier.weight(1f)
                    )
                    NumberField(
                        label = "Proteína",
                        value = protein,
                        onValueChange = { protein = it },
                        suffix = "g",
                        decimal = true,
                        modifier = Modifier.weight(1f)
                    )
                    NumberField(
                        label = "Grasas",
                        value = fat,
                        onValueChange = { fat = it },
                        suffix = "g",
                        decimal = true,
                        modifier = Modifier.weight(1f)
                    )
                }
                Spacer(Modifier.height(12.dp))
                NumberField(
                    label = "Sodio",
                    value = sodium,
                    onValueChange = { sodium = it },
                    suffix = "mg/100 g",
                    decimal = true
                )

                val gramsValue = grams.toDoubleOrNull() ?: 0.0
                val kcalValue = kcal.toDoubleOrNull() ?: 0.0
                Spacer(Modifier.height(14.dp))
                Text(
                    "En ${gramsValue.toInt()} g: ${(kcalValue * gramsValue / 100).toInt()} kcal · " +
                        "${((carbs.toDoubleOrNull() ?: 0.0) * gramsValue / 100).toInt()} g de hidratos · " +
                        "${((protein.toDoubleOrNull() ?: 0.0) * gramsValue / 100).toInt()} g de proteína",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }

        item {
            Button(
                enabled = name.isNotBlank() && (kcal.toDoubleOrNull() ?: 0.0) > 0,
                onClick = {
                    val food = Food(
                        id = sourceId.ifBlank { "propio_${System.currentTimeMillis()}" },
                        name = name.trim(),
                        category = "Mis alimentos",
                        kcalPer100g = kcal.toDoubleOrNull() ?: 0.0,
                        proteinPer100g = protein.toDoubleOrNull() ?: 0.0,
                        carbsPer100g = carbs.toDoubleOrNull() ?: 0.0,
                        fatPer100g = fat.toDoubleOrNull() ?: 0.0,
                        sodiumMgPer100g = sodium.toDoubleOrNull() ?: 0.0,
                        defaultPortionG = grams.toDoubleOrNull() ?: 100.0,
                        portionLabel = "${grams.toDoubleOrNull()?.toInt() ?: 100} g"
                    )
                    scope.launch {
                        container.nutritionRepository.addCustomFood(food)
                        container.nutritionRepository.addFood(
                            food = food,
                            grams = grams.toDoubleOrNull() ?: 100.0,
                            mealType = mealType,
                            date = date
                        )
                        onBack()
                    }
                },
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .padding(horizontal = 20.dp)
                    .fillMaxWidth()
                    .height(52.dp)
            ) { Text("Agregar a ${mealType.label.lowercase()}", fontWeight = FontWeight.Bold) }
        }

        item {
            Text(
                "Datos de productos: Open Food Facts (licencia ODbL). Reconocimiento en el " +
                    "teléfono con ML Kit, sin enviar la foto a ningún servidor.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp)
            )
        }
    }
}

/** Decodifica la foto a un tamaño manejable sin perder la nitidez que el código de barras necesita. */
private fun decodeScaled(file: File, maxSize: Int): Bitmap? {
    if (!file.exists()) return null
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.absolutePath, bounds)
    var sample = 1
    var width = bounds.outWidth
    var height = bounds.outHeight
    while (width / sample > maxSize || height / sample > maxSize) sample *= 2
    val options = BitmapFactory.Options().apply { inSampleSize = sample }
    return BitmapFactory.decodeFile(file.absolutePath, options)
}
