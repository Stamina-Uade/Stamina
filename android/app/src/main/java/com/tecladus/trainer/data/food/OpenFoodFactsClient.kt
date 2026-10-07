package com.tecladus.trainer.data.food

import com.tecladus.trainer.domain.model.Food
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Producto reconocido a partir del código de barras, con su foto real. */
data class ScannedProduct(
    val food: Food,
    val barcode: String,
    val brand: String?,
    val imageUrl: String?
)

/**
 * Cliente de Open Food Facts.
 *
 * Se eligió porque es la única base de productos que cumple las tres condiciones: es
 * **gratuita**, **no pide clave** (sólo un User-Agent que identifique la app) y su
 * licencia (ODbL) permite usarla en una app propia citando la fuente. Tiene millones
 * de productos con código de barras, incluidos los de góndola argentina.
 *
 * Límite de la API: 15 consultas por minuto y por IP para lectura, 10 para búsquedas.
 */
object OpenFoodFactsClient {

    // La política de Open Food Facts pide identificar la app y un contacto.
    private const val USER_AGENT = "Trainer/1.0 (Android; contacto: cambiar-por-tu-email)"
    private const val HOST = "https://world.openfoodfacts.org"
    private const val FIELDS =
        "code,product_name,product_name_es,brands,quantity,serving_size,image_front_small_url,nutriments"

    suspend fun byBarcode(barcode: String): ScannedProduct? = withContext(Dispatchers.IO) {
        val json = get("$HOST/api/v2/product/$barcode.json?fields=$FIELDS") ?: return@withContext null
        if (json.optInt("status", 0) != 1) return@withContext null
        val product = json.optJSONObject("product") ?: return@withContext null
        toProduct(product, barcode)
    }

    /** Búsqueda por texto: usa el endpoint clásico, que es el que soporta texto libre. */
    suspend fun search(query: String, limit: Int = 12): List<ScannedProduct> = withContext(Dispatchers.IO) {
        if (query.isBlank()) return@withContext emptyList()
        val encoded = URLEncoder.encode(query, "UTF-8")
        val json = get(
            "$HOST/cgi/search.pl?search_terms=$encoded&search_simple=1&action=process&json=1" +
                "&page_size=$limit&fields=$FIELDS"
        ) ?: return@withContext emptyList()
        val products = json.optJSONArray("products") ?: return@withContext emptyList()
        val result = mutableListOf<ScannedProduct>()
        for (index in 0 until products.length()) {
            val item = products.optJSONObject(index) ?: continue
            val code = item.optString("code", "")
            toProduct(item, code)?.let { result += it }
        }
        result
    }

    private fun toProduct(product: JSONObject, barcode: String): ScannedProduct? {
        val name = listOf("product_name_es", "product_name")
            .firstNotNullOfOrNull { key -> product.optString(key, "").takeIf { it.isNotBlank() } }
            ?: return null
        val brand = product.optString("brands", "").split(",").firstOrNull()?.trim()?.takeIf { it.isNotBlank() }
        val nutriments = product.optJSONObject("nutriments") ?: JSONObject()

        val kcal = nutriments.optDouble("energy-kcal_100g").takeIf { !it.isNaN() }
            ?: nutriments.optDouble("energy_100g").takeIf { !it.isNaN() }?.div(4.184)
            ?: return null
        // El sodio viene en gramos; si sólo hay sal, se convierte (1 g de sal = 400 mg de sodio).
        val sodiumMg = nutriments.optDouble("sodium_100g").takeIf { !it.isNaN() }?.times(1000)
            ?: nutriments.optDouble("salt_100g").takeIf { !it.isNaN() }?.times(400)
            ?: 0.0

        val servingText = product.optString("serving_size", "")
        val servingGrams = Regex("([0-9]+([.,][0-9]+)?)\\s*(g|ml)", RegexOption.IGNORE_CASE)
            .find(servingText)?.groupValues?.get(1)?.replace(',', '.')?.toDoubleOrNull()

        val food = Food(
            id = "off_$barcode",
            name = if (brand.isNullOrBlank()) name else "$name · $brand",
            category = "Productos escaneados",
            kcalPer100g = kcal,
            proteinPer100g = nutriments.optDouble("proteins_100g").orZero(),
            carbsPer100g = nutriments.optDouble("carbohydrates_100g").orZero(),
            fatPer100g = nutriments.optDouble("fat_100g").orZero(),
            sodiumMgPer100g = sodiumMg,
            defaultPortionG = servingGrams ?: 100.0,
            portionLabel = servingText.ifBlank { product.optString("quantity", "").ifBlank { "100 g" } }
        )
        return ScannedProduct(
            food = food,
            barcode = barcode,
            brand = brand,
            imageUrl = product.optString("image_front_small_url", "").takeIf { it.isNotBlank() }
        )
    }

    private fun Double.orZero(): Double = if (isNaN()) 0.0 else this

    private fun get(url: String): JSONObject? = try {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 9000
            readTimeout = 9000
            setRequestProperty("User-Agent", USER_AGENT)
        }
        try {
            if (connection.responseCode in 200..299) {
                JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
            } else null
        } finally {
            connection.disconnect()
        }
    } catch (e: Exception) {
        null
    }
}
