package com.tecladus.trainer.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.util.LruCache
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.tecladus.trainer.domain.model.TrackPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.tan

private const val TILE_SIZE = 256

/** Proyección Web Mercator: la misma que usan todos los mapas de tiles. */
private object MapProjection {
    fun tileX(lon: Double, zoom: Int): Double = (lon + 180.0) / 360.0 * (1 shl zoom)

    fun tileY(lat: Double, zoom: Int): Double {
        val rad = Math.toRadians(lat.coerceIn(-85.05, 85.05))
        return (1.0 - ln(tan(rad) + 1.0 / cos(rad)) / PI) / 2.0 * (1 shl zoom)
    }
}

/**
 * Descarga y cachea los tiles de OpenStreetMap.
 * Memoria para el scroll y disco para no volver a bajar el mismo barrio cada día.
 */
private object TileLoader {

    private val memory = LruCache<String, ImageBitmap>(120)

    suspend fun load(context: Context, zoom: Int, x: Int, y: Int): ImageBitmap? =
        withContext(Dispatchers.IO) {
            val key = "$zoom/$x/$y"
            memory.get(key)?.let { return@withContext it }
            val dir = File(context.cacheDir, "osm_tiles").apply { mkdirs() }
            val file = File(dir, "${zoom}_${x}_$y.png")
            val bytes = if (file.exists() && file.length() > 0) {
                file.readBytes()
            } else {
                download(zoom, x, y)?.also { data ->
                    runCatching { file.writeBytes(data) }
                }
            } ?: return@withContext null
            val bitmap = runCatching { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }.getOrNull()
                ?: return@withContext null
            val image = toNightStyle(bitmap).asImageBitmap()
            memory.put(key, image)
            image
        }

    /**
     * Convierte el tile claro de OpenStreetMap en uno oscuro, en el teléfono.
     *
     * No existe hoy un proveedor de tiles oscuros gratuito y sin clave (CARTO empezó a
     * exigir API key), así que se hace acá: se invierte la luminancia, se conserva un 25%
     * del color con los canales rojo y azul intercambiados (equivale a girar el tono 180°,
     * así el agua queda azul y no marrón) y se apoya todo sobre un gris azulado.
     * El resultado se cachea ya procesado: se hace una sola vez por tile.
     */
    private fun toNightStyle(source: Bitmap): Bitmap {
        val output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(output)
        val paint = Paint().apply {
            isFilterBitmap = true
            colorFilter = ColorMatrixColorFilter(
                ColorMatrix(
                    floatArrayOf(
                        -0.1615f, -0.3170f, -0.2416f, 0f, 191.6f,
                        -0.1615f, -0.4970f, -0.0616f, 0f, 191.6f,
                        -0.3415f, -0.3170f, -0.0616f, 0f, 191.6f,
                        0f, 0f, 0f, 1f, 0f
                    )
                )
            )
        }
        canvas.drawBitmap(source, 0f, 0f, paint)
        return output
    }

    private fun download(zoom: Int, x: Int, y: Int): ByteArray? = try {
        val connection = (URL("https://tile.openstreetmap.org/$zoom/$x/$y.png")
            .openConnection() as HttpURLConnection).apply {
            connectTimeout = 8000
            readTimeout = 8000
            // La política de uso de OSM exige identificar la aplicación.
            setRequestProperty("User-Agent", "Trainer/1.0 (Android; entrenamiento de resistencia)")
        }
        try {
            if (connection.responseCode in 200..299) connection.inputStream.readBytes() else null
        } finally {
            connection.disconnect()
        }
    } catch (e: Exception) {
        null
    }
}

/**
 * Mapa dibujado a mano sobre tiles de OpenStreetMap: sin SDK de mapas, sin API key
 * y sin dependencias nuevas. Muestra dónde está el usuario antes de salir y el
 * recorrido cuando la sesión ya terminó.
 */
@Composable
fun TileMap(
    latitude: Double?,
    longitude: Double?,
    modifier: Modifier = Modifier,
    zoom: Int = 15,
    route: List<TrackPoint> = emptyList(),
    showMarker: Boolean = true,
    routeColor: Color = MaterialTheme.colorScheme.primary,
    cornerRadius: Int = 20,
    placeholder: String = "Buscando tu ubicación..."
) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    // Un tile de 256 px se vería diminuto en pantallas densas: se escala a un tamaño legible.
    val scale = (density / 2f).coerceIn(1f, 2f)
    val tilePx = (TILE_SIZE * scale).roundToInt()

    var sizePx by remember { mutableStateOf(IntSize.Zero) }
    var tiles by remember { mutableStateOf<Map<String, ImageBitmap>>(emptyMap()) }

    val hasRoute = route.size > 1
    val centerLat = if (hasRoute) route.map { it.latitude }.average() else latitude
    val centerLon = if (hasRoute) route.map { it.longitude }.average() else longitude

    val effectiveZoom = remember(route, sizePx, zoom, scale) {
        if (!hasRoute || sizePx.width == 0) zoom else fitZoom(route, sizePx, tilePx)
    }

    LaunchedEffect(centerLat, centerLon, effectiveZoom, sizePx) {
        if (centerLat == null || centerLon == null || sizePx.width == 0) return@LaunchedEffect
        val centerTileX = MapProjection.tileX(centerLon, effectiveZoom)
        val centerTileY = MapProjection.tileY(centerLat, effectiveZoom)
        val cols = (sizePx.width / tilePx) / 2 + 2
        val rows = (sizePx.height / tilePx) / 2 + 2
        val maxIndex = (1 shl effectiveZoom) - 1
        val loaded = mutableMapOf<String, ImageBitmap>()
        for (dx in -cols..cols) {
            for (dy in -rows..rows) {
                val x = (centerTileX.toInt() + dx).coerceIn(0, maxIndex)
                val y = (centerTileY.toInt() + dy).coerceIn(0, maxIndex)
                val key = "$effectiveZoom/$x/$y"
                if (loaded.containsKey(key)) continue
                val image = TileLoader.load(context, effectiveZoom, x, y)
                if (image != null) {
                    loaded[key] = image
                    tiles = loaded.toMap()
                }
            }
        }
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius.dp))
            .background(MaterialTheme.colorScheme.background)
            .onSizeChanged { sizePx = it }
    ) {
        if (centerLat == null || centerLon == null) {
            Text(
                text = placeholder,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.align(Alignment.Center)
            )
        } else {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val centerTileX = MapProjection.tileX(centerLon, effectiveZoom)
                val centerTileY = MapProjection.tileY(centerLat, effectiveZoom)
                val originX = centerTileX * tilePx - size.width / 2f
                val originY = centerTileY * tilePx - size.height / 2f

                tiles.forEach { (key, image) ->
                    val parts = key.split("/")
                    if (parts.size != 3 || parts[0].toIntOrNull() != effectiveZoom) return@forEach
                    val tx = parts[1].toIntOrNull() ?: return@forEach
                    val ty = parts[2].toIntOrNull() ?: return@forEach
                    drawImage(
                        image = image,
                        srcOffset = IntOffset.Zero,
                        srcSize = IntSize(image.width, image.height),
                        dstOffset = IntOffset(
                            (tx * tilePx - originX).roundToInt(),
                            (ty * tilePx - originY).roundToInt()
                        ),
                        dstSize = IntSize(tilePx, tilePx)
                    )
                }

                fun project(lat: Double, lon: Double): Offset = Offset(
                    (MapProjection.tileX(lon, effectiveZoom) * tilePx - originX).toFloat(),
                    (MapProjection.tileY(lat, effectiveZoom) * tilePx - originY).toFloat()
                )

                if (hasRoute) {
                    val path = Path()
                    route.forEachIndexed { index, point ->
                        val offset = project(point.latitude, point.longitude)
                        if (index == 0) path.moveTo(offset.x, offset.y) else path.lineTo(offset.x, offset.y)
                    }
                    drawPath(
                        path = path,
                        color = Color.Black.copy(alpha = 0.55f),
                        style = Stroke(width = 16f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                    )
                    drawPath(
                        path = path,
                        color = routeColor,
                        style = Stroke(width = 10f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                    )
                    val start = route.first()
                    val end = route.last()
                    drawCircle(Color.White, radius = 13f, center = project(start.latitude, start.longitude))
                    drawCircle(Color(0xFF46C98B), radius = 9f, center = project(start.latitude, start.longitude))
                    drawCircle(Color.White, radius = 13f, center = project(end.latitude, end.longitude))
                    drawCircle(Color(0xFFFF6B6B), radius = 9f, center = project(end.latitude, end.longitude))
                } else if (showMarker) {
                    val center = Offset(size.width / 2f, size.height / 2f)
                    drawCircle(routeColor.copy(alpha = 0.14f), radius = 60f, center = center)
                    drawCircle(routeColor.copy(alpha = 0.22f), radius = 38f, center = center)
                    drawCircle(Color.White, radius = 18f, center = center)
                    drawCircle(routeColor, radius = 13f, center = center)
                }
            }

            Text(
                text = "© OpenStreetMap",
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.45f),
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            )
        }
    }
}

/** Elige el zoom más cercano que hace entrar todo el recorrido en el recuadro. */
private fun fitZoom(route: List<TrackPoint>, sizePx: IntSize, tilePx: Int): Int {
    val minLat = route.minOf { it.latitude }
    val maxLat = route.maxOf { it.latitude }
    val minLon = route.minOf { it.longitude }
    val maxLon = route.maxOf { it.longitude }
    for (zoom in 17 downTo 3) {
        val width = (MapProjection.tileX(maxLon, zoom) - MapProjection.tileX(minLon, zoom)) * tilePx
        val height = (MapProjection.tileY(minLat, zoom) - MapProjection.tileY(maxLat, zoom)) * tilePx
        if (width <= sizePx.width * 0.82 && height <= max(1, sizePx.height) * 0.82) return zoom
    }
    return 12
}
