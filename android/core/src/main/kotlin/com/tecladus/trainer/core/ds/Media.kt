package com.tecladus.trainer.core.ds

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import coil3.compose.AsyncImage
import coil3.gif.AnimatedImageDecoder
import coil3.ImageLoader
import coil3.request.ImageRequest
import com.tecladus.trainer.core.tema.Tema

/**
 * De dónde sale la foto o la animación de un ejercicio.
 *
 * 🛑 Son tres casos y **el tercero no es un error**: hoy no hay ni un archivo, y
 * el hueco tiene que poder dibujarse sin que la pantalla parezca rota. Ver
 * `docs/MEDIA-DE-EJERCICIOS.md`.
 *
 * Existe como tipo, y no como un `String?` con una URL, porque la decisión de si
 * la media viaja en el APK o baja de S3 **todavía no está tomada** y cambia por
 * ejercicio. Con esto, cambiarla es cambiar quién construye la fuente; la pantalla
 * que la dibuja no se entera.
 */
sealed interface FuenteDeMedia {

    /** Un archivo de `res/raw/`. Está en el APK: se ve sin señal, y pesa siempre. */
    data class Empaquetada(val recurso: Int) : FuenteDeMedia

    /**
     * Un archivo del bucket. No pesa en el APK y se puede cambiar sin publicar,
     * que es lo que AGENTS.md §9.1 pide del catálogo.
     */
    data class Remota(val url: String) : FuenteDeMedia

    /** No hay archivo. Se dibuja el hueco, con su medida y su cartel. */
    data object NoHay : FuenteDeMedia

    companion object {
        /**
         * El recurso empaquetado que le toca a un id del catálogo, o [NoHay].
         *
         * Android exige que el nombre de un `res/raw` sea minúsculas y guiones
         * bajos, y los ids del catálogo llevan guiones medios
         * (`press-banca-barra`). La traducción se hace **acá y en un solo lugar**:
         * si cada pantalla la hiciera sola, la primera que se olvide de un guión
         * muestra el hueco sin que nadie entienda por qué.
         */
        fun empaquetada(idDelCatalogo: String, buscar: (String) -> Int): FuenteDeMedia {
            val recurso = buscar(idDelCatalogo.replace('-', '_').lowercase())
            return if (recurso == 0) NoHay else Empaquetada(recurso)
        }
    }
}

/**
 * La foto o la animación de un ejercicio, o el hueco si no hay.
 *
 * El alto lo pone quien la usa: en la captura de serie es una tira ancha y baja,
 * en la ficha del ejercicio es un cuadrado. Lo que NO cambia es que **siempre
 * ocupa lugar**, incluso sin archivo: si el hueco no midiera, la pantalla saltaría
 * el día que aparezca el archivo, y eso pasa justo mientras alguien está mirándola.
 *
 * @param descripcion lo que se ve, para quien no lo ve. No es opcional: una
 *   animación sin descripción, para un lector de pantalla, es un rectángulo.
 */
@Composable
fun MediaDeEjercicio(
    fuente: FuenteDeMedia,
    descripcion: String,
    textoDelHueco: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(Tema.color.superficieAlterna, Tema.forma.card)
            .semantics { contentDescription = descripcion },
        contentAlignment = Alignment.Center,
    ) {
        when (fuente) {
            is FuenteDeMedia.NoHay -> Hueco(textoDelHueco)
            is FuenteDeMedia.Empaquetada -> Dibujo(fuente.recurso, descripcion)
            is FuenteDeMedia.Remota -> Dibujo(fuente.url, descripcion)
        }
    }
}

/**
 * El dibujo propiamente dicho.
 *
 * `AnimatedImageDecoder` es lo que hace que un WebP animado se mueva en vez de
 * quedarse en el primer cuadro; sin él, Coil dibuja una foto fija y no hay ningún
 * error que lo diga.
 */
@Composable
private fun Dibujo(dato: Any, descripcion: String) {
    val contexto = LocalContext.current
    val cargador = remember(contexto) {
        ImageLoader.Builder(contexto)
            .components { add(AnimatedImageDecoder.Factory()) }
            .build()
    }
    AsyncImage(
        model = ImageRequest.Builder(contexto).data(dato).build(),
        imageLoader = cargador,
        // La descripción ya está en el Box de arriba: repetirla acá la haría
        // sonar dos veces.
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = Modifier.fillMaxSize(),
    )
}

/** El hueco: dice qué falta, con su ícono. Nunca finge ser el dibujo. */
@Composable
private fun Hueco(texto: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e8),
        modifier = Modifier.padding(Tema.aire.e16),
    ) {
        Iconos.Imagen(Tema.color.textoTerciario, Modifier.size(Tema.aire.e36))
        Text(
            text = texto,
            style = Tema.texto.nota,
            color = Tema.color.textoTerciario,
            textAlign = TextAlign.Center,
        )
    }
}
