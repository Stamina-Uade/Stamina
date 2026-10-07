package com.tecladus.trainer.core.ds

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.Dp
import com.tecladus.trainer.core.tema.TokensEspaciado

/**
 * Los pocos glifos que el design system necesita, dibujados con trazos.
 *
 * No son drawables ni una tipografía de íconos, y eso es a propósito:
 * `tokens.json` declara `pendientes[set-de-iconos]` — el tablero no tiene un set
 * nombrado ni versionado. Inventar uno acá sería tomar una decisión de diseño de
 * contrabando. Están dibujados trazo por trazo con la misma geometría: viewBox
 * cuadrado, grosor 2 dp, puntas redondeadas.
 *
 * 🛑 **Acá no hay emojis, y es una regla.** Un emoji en un botón o en un mensaje
 * de error no está en el diseño, y además: lo dibuja el sistema, así que cambia
 * de forma y de color entre teléfonos, no se puede teñir con el color del tema, y
 * un lector de pantalla lo lee con el nombre que le puso Unicode ("señal de
 * construcción") en el medio de la frase. Todo lo que antes era un emoji en un
 * string ahora es uno de estos.
 *
 * 🛑 Ninguno lleva significado por sí solo: en toda la UI van acompañados de
 * texto. Un ícono sin etiqueta es una adivinanza, y para un lector de pantalla no
 * existe.
 *
 * Cuando exista el set real, este archivo se borra entero.
 */
object Iconos {

    /** El grosor de trazo del diseño (2.2–2.4 sobre un viewBox de 24). */
    private val grosor: Dp = TokensEspaciado.e2

    /** El tamaño al que se dibujan en las pantallas de gimnasio. */
    val tamano: Dp = TokensEspaciado.e16

    @Composable
    fun Menos(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val y = size.height / 2f
        linea(Offset(borde(), y), Offset(size.width - borde(), y), color)
    }

    @Composable
    fun Mas(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        linea(Offset(borde(), cy), Offset(size.width - borde(), cy), color)
        linea(Offset(cx, borde()), Offset(cx, size.height - borde()), color)
    }

    /** ‹ — vuelve al ejercicio anterior. */
    @Composable
    fun ChevronIzquierda(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val x1 = size.width * 0.66f
        val x2 = size.width * 0.34f
        linea(Offset(x1, borde()), Offset(x2, size.height / 2f), color)
        linea(Offset(x2, size.height / 2f), Offset(x1, size.height - borde()), color)
    }

    /** › — pasa al siguiente. */
    @Composable
    fun ChevronDerecha(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val x1 = size.width * 0.34f
        val x2 = size.width * 0.66f
        linea(Offset(x1, borde()), Offset(x2, size.height / 2f), color)
        linea(Offset(x2, size.height / 2f), Offset(x1, size.height - borde()), color)
    }

    /** ▶| — saltear: el triángulo con la barra, como el "siguiente" de un reproductor. */
    @Composable
    fun Saltear(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val alto = size.height - borde() * 2f
        val ancho = size.width * 0.55f
        val camino = Path().apply {
            moveTo(borde(), borde())
            lineTo(borde() + ancho, size.height / 2f)
            lineTo(borde(), size.height - borde())
            close()
        }
        drawPath(camino, color)
        linea(
            Offset(size.width - borde(), borde()),
            Offset(size.width - borde(), borde() + alto),
            color,
        )
    }

    /** ✕ — cerrar o descartar. NO es un "más" rotado: un + que cierra es una trampa. */
    @Composable
    fun Cruz(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        linea(Offset(borde(), borde()), Offset(size.width - borde(), size.height - borde()), color)
        linea(Offset(size.width - borde(), borde()), Offset(borde(), size.height - borde()), color)
    }

    /** ✓ — hecho. Nunca es lo único que dice que algo se hizo: siempre hay texto al lado. */
    @Composable
    fun Tilde(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        linea(Offset(borde(), size.height * 0.55f), Offset(size.width * 0.4f, size.height - borde()), color)
        linea(Offset(size.width * 0.4f, size.height - borde()), Offset(size.width - borde(), borde()), color)
    }


    /** ▶ — empezar, reproducir. */
    @Composable
    fun Reproducir(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val p = Path().apply {
            moveTo(size.width * 0.28f, borde())
            lineTo(size.width - borde(), size.height / 2f)
            lineTo(size.width * 0.28f, size.height - borde())
            close()
        }
        drawPath(p, color)
    }

    /** ⚑ — bandera de llegada: terminar. */
    @Composable
    fun Bandera(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val x = borde()
        linea(Offset(x, borde()), Offset(x, size.height - borde()), color)
        val p = Path().apply {
            moveTo(x, borde())
            lineTo(size.width - borde(), size.height * 0.28f)
            lineTo(x, size.height * 0.55f)
            close()
        }
        drawPath(p, color)
    }

    /** Dos flechas en círculo: reemplazar, cambiar por otro. */
    @Composable
    fun Reemplazar(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val y1 = size.height * 0.33f
        val y2 = size.height * 0.67f
        linea(Offset(borde(), y1), Offset(size.width - borde(), y1), color)
        linea(Offset(size.width - borde() * 2.4f, y1 - borde() * 1.2f), Offset(size.width - borde(), y1), color)
        linea(Offset(size.width - borde() * 2.4f, y1 + borde() * 1.2f), Offset(size.width - borde(), y1), color)
        linea(Offset(size.width - borde(), y2), Offset(borde(), y2), color)
        linea(Offset(borde() * 2.4f, y2 - borde() * 1.2f), Offset(borde(), y2), color)
        linea(Offset(borde() * 2.4f, y2 + borde() * 1.2f), Offset(borde(), y2), color)
    }

    /** Un lápiz: notas. */
    @Composable
    fun Lapiz(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        linea(Offset(borde(), size.height - borde()), Offset(size.width * 0.32f, size.height - borde() * 1.6f), color)
        linea(Offset(borde(), size.height - borde()), Offset(borde() * 1.6f, size.height * 0.68f), color)
        linea(Offset(borde() * 1.6f, size.height * 0.68f), Offset(size.width * 0.72f, borde()), color)
        linea(Offset(size.width * 0.72f, borde()), Offset(size.width - borde(), size.height * 0.28f), color)
        linea(Offset(size.width - borde(), size.height * 0.28f), Offset(size.width * 0.32f, size.height - borde() * 1.6f), color)
    }

    /** Un tacho: borrar. */
    @Composable
    fun Tacho(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val tapa = size.height * 0.26f
        linea(Offset(borde(), tapa), Offset(size.width - borde(), tapa), color)
        linea(Offset(size.width * 0.36f, tapa), Offset(size.width * 0.36f, borde()), color)
        linea(Offset(size.width * 0.36f, borde()), Offset(size.width * 0.64f, borde()), color)
        linea(Offset(size.width * 0.64f, borde()), Offset(size.width * 0.64f, tapa), color)
        linea(Offset(size.width * 0.2f, tapa), Offset(size.width * 0.26f, size.height - borde()), color)
        linea(Offset(size.width * 0.8f, tapa), Offset(size.width * 0.74f, size.height - borde()), color)
        linea(Offset(size.width * 0.26f, size.height - borde()), Offset(size.width * 0.74f, size.height - borde()), color)
    }

    /** Un reloj: descanso, tiempo. */
    @Composable
    fun Reloj(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val r = size.minDimension / 2f - borde()
        val c = Offset(size.width / 2f, size.height / 2f)
        drawCircle(color = color, radius = r, center = c, style = Stroke(width = grosor.toPx()))
        linea(c, Offset(c.x, c.y - r * 0.55f), color)
        linea(c, Offset(c.x + r * 0.42f, c.y), color)
    }

    /**
     * Un triángulo con un signo: algo no está terminado.
     *
     * Reemplaza al 🚧 que había en los mensajes de "todavía no". No es un error:
     * es un aviso, y por eso es un triángulo y no una cruz.
     */
    @Composable
    fun Aviso(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val p = Path().apply {
            moveTo(size.width / 2f, borde())
            lineTo(size.width - borde(), size.height - borde())
            lineTo(borde(), size.height - borde())
            close()
        }
        drawPath(p, color, style = Stroke(width = grosor.toPx()))
        linea(Offset(size.width / 2f, size.height * 0.42f), Offset(size.width / 2f, size.height * 0.66f), color)
        drawCircle(color = color, radius = grosor.toPx() * 0.5f, center = Offset(size.width / 2f, size.height * 0.79f))
    }

    /** Un marco con una montaña: falta una imagen o una animación. */
    @Composable
    fun Imagen(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val b = borde()
        drawPath(
            Path().apply {
                moveTo(b, b); lineTo(size.width - b, b)
                lineTo(size.width - b, size.height - b); lineTo(b, size.height - b); close()
            },
            color,
            style = Stroke(width = grosor.toPx()),
        )
        linea(Offset(b, size.height * 0.72f), Offset(size.width * 0.4f, size.height * 0.44f), color)
        linea(Offset(size.width * 0.4f, size.height * 0.44f), Offset(size.width - b, size.height * 0.72f), color)
        drawCircle(color = color, radius = grosor.toPx() * 0.8f, center = Offset(size.width * 0.68f, size.height * 0.32f))
    }

    /** Un sobre: te mandamos un correo. */
    @Composable
    fun Sobre(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val b = borde()
        val alto = size.height * 0.66f
        val y0 = (size.height - alto) / 2f
        drawPath(
            Path().apply {
                moveTo(b, y0); lineTo(size.width - b, y0)
                lineTo(size.width - b, y0 + alto); lineTo(b, y0 + alto); close()
            },
            color,
            style = Stroke(width = grosor.toPx()),
        )
        linea(Offset(b, y0), Offset(size.width / 2f, y0 + alto * 0.55f), color)
        linea(Offset(size.width / 2f, y0 + alto * 0.55f), Offset(size.width - b, y0), color)
    }

    /** Un enchufe desconectado: no hay servidor. */
    @Composable
    fun SinConexion(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val c = Offset(size.width / 2f, size.height / 2f)
        val r = size.minDimension / 2f - borde()
        drawCircle(color = color, radius = r, center = c, style = Stroke(width = grosor.toPx()))
        linea(Offset(c.x - r * 0.7f, c.y + r * 0.7f), Offset(c.x + r * 0.7f, c.y - r * 0.7f), color)
    }

    /** Un punto lleno: estado. Va siempre con texto que dice cuál. */
    @Composable
    fun Punto(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        drawCircle(color = color, radius = size.minDimension * 0.22f, center = Offset(size.width / 2f, size.height / 2f))
    }

    // ---------------------------------------------------- la barra de navegación

    /** Casa: Inicio. */
    @Composable
    fun Casa(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val b = borde()
        linea(Offset(b, size.height * 0.46f), Offset(size.width / 2f, b), color)
        linea(Offset(size.width / 2f, b), Offset(size.width - b, size.height * 0.46f), color)
        linea(Offset(size.width * 0.18f, size.height * 0.42f), Offset(size.width * 0.18f, size.height - b), color)
        linea(Offset(size.width * 0.82f, size.height * 0.42f), Offset(size.width * 0.82f, size.height - b), color)
        linea(Offset(size.width * 0.18f, size.height - b), Offset(size.width * 0.82f, size.height - b), color)
    }

    /** Un almanaque: Plan. */
    @Composable
    fun Almanaque(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val b = borde()
        val y0 = size.height * 0.2f
        drawPath(
            Path().apply {
                moveTo(b, y0); lineTo(size.width - b, y0)
                lineTo(size.width - b, size.height - b); lineTo(b, size.height - b); close()
            },
            color,
            style = Stroke(width = grosor.toPx()),
        )
        linea(Offset(b, size.height * 0.42f), Offset(size.width - b, size.height * 0.42f), color)
        linea(Offset(size.width * 0.3f, y0), Offset(size.width * 0.3f, b), color)
        linea(Offset(size.width * 0.7f, y0), Offset(size.width * 0.7f, b), color)
    }

    /** Una mancuerna: Gimnasio. */
    @Composable
    fun Mancuerna(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val y = size.height / 2f
        val b = borde()
        linea(Offset(size.width * 0.3f, y), Offset(size.width * 0.7f, y), color)
        linea(Offset(size.width * 0.2f, size.height * 0.26f), Offset(size.width * 0.2f, size.height * 0.74f), color)
        linea(Offset(size.width * 0.8f, size.height * 0.26f), Offset(size.width * 0.8f, size.height * 0.74f), color)
        linea(Offset(b, size.height * 0.36f), Offset(b, size.height * 0.64f), color)
        linea(Offset(size.width - b, size.height * 0.36f), Offset(size.width - b, size.height * 0.64f), color)
    }

    /** Una manzana: Nutrición. */
    @Composable
    fun Manzana(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val b = borde()
        val c = Offset(size.width / 2f, size.height * 0.6f)
        drawCircle(color = color, radius = size.minDimension * 0.35f, center = c, style = Stroke(width = grosor.toPx()))
        linea(Offset(size.width / 2f, size.height * 0.25f), Offset(size.width / 2f, b), color)
        linea(Offset(size.width / 2f, size.height * 0.18f), Offset(size.width * 0.78f, b), color)
    }

    /** Una persona: Perfil. */
    @Composable
    fun Persona(color: Color, modifier: Modifier = Modifier) = Trazo(modifier) {
        val b = borde()
        drawCircle(
            color = color,
            radius = size.minDimension * 0.2f,
            center = Offset(size.width / 2f, size.height * 0.3f),
            style = Stroke(width = grosor.toPx()),
        )
        linea(Offset(size.width * 0.18f, size.height - b), Offset(size.width * 0.22f, size.height * 0.68f), color)
        linea(Offset(size.width * 0.22f, size.height * 0.68f), Offset(size.width * 0.78f, size.height * 0.68f), color)
        linea(Offset(size.width * 0.78f, size.height * 0.68f), Offset(size.width * 0.82f, size.height - b), color)
    }

    // ------------------------------------------------------------------ interno

    @Composable
    private fun Trazo(modifier: Modifier, dibujo: DrawScope.() -> Unit) {
        Canvas(modifier = modifier, onDraw = dibujo)
    }

    private fun DrawScope.borde(): Float = grosor.toPx()

    private fun DrawScope.linea(desde: Offset, hasta: Offset, color: Color) {
        drawLine(
            color = color,
            start = desde,
            end = hasta,
            strokeWidth = grosor.toPx(),
            cap = StrokeCap.Round,
        )
    }

    /** Se usa para el borde punteado de una serie salteada: la FORMA cambia, no sólo el color. */
    fun trazoPunteado(anchoPx: Float): Stroke = Stroke(width = anchoPx)
}
