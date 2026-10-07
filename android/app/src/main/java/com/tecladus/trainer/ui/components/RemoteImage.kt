package com.tecladus.trainer.ui.components

import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

private val remoteImageCache = LruCache<String, ImageBitmap>(30)

/** Imagen remota mínima (las fotos de producto de Open Food Facts), sin librerías extra. */
@Composable
fun RemoteImage(
    url: String?,
    modifier: Modifier = Modifier,
    cornerRadius: Int = 16
) {
    var image by remember(url) { mutableStateOf(remoteImageCache.get(url.orEmpty())) }

    LaunchedEffect(url) {
        if (url.isNullOrBlank() || image != null) return@LaunchedEffect
        image = withContext(Dispatchers.IO) {
            try {
                val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 8000
                    readTimeout = 8000
                    setRequestProperty("User-Agent", "Trainer/1.0 (Android)")
                }
                val bytes = try {
                    if (connection.responseCode in 200..299) connection.inputStream.readBytes() else null
                } finally {
                    connection.disconnect()
                }
                bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size)?.asImageBitmap() }
                    ?.also { remoteImageCache.put(url, it) }
            } catch (e: Exception) {
                null
            }
        }
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius.dp))
            .background(MaterialTheme.colorScheme.background)
    ) {
        image?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}
