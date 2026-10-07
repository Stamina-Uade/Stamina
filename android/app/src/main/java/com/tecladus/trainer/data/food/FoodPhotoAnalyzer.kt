package com.tecladus.trainer.data.food

import android.graphics.Bitmap
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.tecladus.trainer.data.catalog.FoodCatalog
import com.tecladus.trainer.domain.model.Food
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/** Qué pudo sacar la app de la foto. */
sealed interface PhotoResult {
    /** Producto envasado identificado por su código de barras: los datos son exactos. */
    data class Product(val product: ScannedProduct) : PhotoResult

    /** Comida sin envase: la app propone candidatos y el usuario confirma. */
    data class Suggestions(val labels: List<String>, val foods: List<Food>) : PhotoResult

    data object Unknown : PhotoResult
}

/**
 * Analiza la foto de un alimento en dos pasadas, ambas sin costo y sin conexión salvo
 * la consulta final a Open Food Facts:
 *
 *  1. **Código de barras** (ML Kit, modelo embebido en el APK). Si el producto está
 *     envasado, es el camino exacto: devuelve marca, nombre y tabla nutricional real.
 *  2. **Etiquetado de imagen** (ML Kit) para comida sin envase. Da categorías generales
 *     ("pan", "pizza", "fruta") que se cruzan con el catálogo local y con Open Food Facts.
 *
 * En los dos casos el usuario revisa y corrige antes de guardar: la foto propone, no decide.
 */
object FoodPhotoAnalyzer {

    private val barcodeScanner by lazy {
        BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(
                    Barcode.FORMAT_EAN_13,
                    Barcode.FORMAT_EAN_8,
                    Barcode.FORMAT_UPC_A,
                    Barcode.FORMAT_UPC_E,
                    Barcode.FORMAT_CODE_128
                )
                .build()
        )
    }

    private val labeler by lazy { ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS) }

    /** Etiquetas del modelo base de ML Kit traducidas a lo que buscamos en el catálogo. */
    private val labelToFood = mapOf(
        "bread" to "pan",
        "baked goods" to "pan",
        "pastry" to "medialuna",
        "cookie" to "galleta",
        "cake" to "torta",
        "pizza" to "pizza",
        "hamburger" to "carne",
        "cheeseburger" to "carne",
        "hot dog" to "pan",
        "sandwich" to "pan",
        "sushi" to "arroz",
        "rice" to "arroz",
        "pasta" to "fideos",
        "noodle" to "fideos",
        "salad" to "ensalada",
        "vegetable" to "verdura",
        "fruit" to "fruta",
        "banana" to "banana",
        "apple" to "manzana",
        "orange" to "naranja",
        "strawberry" to "frutilla",
        "egg" to "huevo",
        "meat" to "carne",
        "steak" to "carne",
        "chicken" to "pollo",
        "fish" to "pescado",
        "seafood" to "pescado",
        "cheese" to "queso",
        "milk" to "leche",
        "yogurt" to "yogur",
        "coffee" to "café",
        "cappuccino" to "café",
        "tea" to "mate",
        "juice" to "jugo",
        "cola" to "gaseosa",
        "soft drink" to "gaseosa",
        "beer" to "cerveza",
        "wine" to "cerveza",
        "water" to "agua",
        "chocolate" to "chocolate",
        "ice cream" to "helado",
        "french fries" to "papa",
        "potato" to "papa",
        "soup" to "sopa",
        "nut" to "almendras",
        "popcorn" to "cereal",
        "breakfast" to "avena",
        "salt" to "sal"
    )

    suspend fun analyze(bitmap: Bitmap, customFoods: List<Food> = emptyList()): PhotoResult {
        val image = InputImage.fromBitmap(bitmap, 0)

        val barcodes = barcodeScanner.process(image).awaitOrNull()
        val code = barcodes?.firstNotNullOfOrNull { it.rawValue?.takeIf { value -> value.length >= 8 } }
        if (code != null) {
            val product = OpenFoodFactsClient.byBarcode(code)
            if (product != null) return PhotoResult.Product(product)
        }

        val labels = labeler.process(image).awaitOrNull().orEmpty()
            .filter { it.confidence >= 0.5f }
            .map { it.text }

        val searchTerms = labels.mapNotNull { labelToFood[it.lowercase()] }.distinct()
        val matches = searchTerms.flatMap { term -> FoodCatalog.search(term, customFoods) }.distinctBy { it.id }
        if (labels.isEmpty() && matches.isEmpty()) return PhotoResult.Unknown
        return PhotoResult.Suggestions(labels = labels, foods = matches.take(8))
    }

    /** Puente entre las Task de ML Kit y las corrutinas, sin sumar dependencias. */
    private suspend fun <T> Task<T>.awaitOrNull(): T? = suspendCancellableCoroutine { continuation ->
        addOnSuccessListener { result -> if (continuation.isActive) continuation.resume(result) }
        addOnFailureListener { if (continuation.isActive) continuation.resume(null) }
        addOnCanceledListener { if (continuation.isActive) continuation.resume(null) }
    }
}
