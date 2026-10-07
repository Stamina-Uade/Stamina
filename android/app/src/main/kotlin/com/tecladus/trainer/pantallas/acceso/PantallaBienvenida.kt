package com.tecladus.trainer.pantallas.acceso

import android.view.ViewConfiguration
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.ds.objetivoTactil
import com.tecladus.trainer.core.tema.Tema
import kotlinx.coroutines.delay
import kotlin.math.abs
import kotlin.math.sign

/**
 * La primera pantalla: el carrusel de bienvenida.
 * Es `is.welcome` de `design/origen/Trainer App.dc.html`.
 *
 * 🛑 **Falta la foto.** El diseño pone una foto a sangre detrás de cada uno de los
 * tres textos, y las tres son URLs de Unsplash que se bajan por red. Eso no se
 * puede hacer en la app: la primera pantalla no puede depender de que haya señal,
 * y las fotos no están licenciadas para empaquetarlas. Hasta que haya una decisión
 * sobre el arte (misma decisión pendiente que las animaciones del gimnasio, ver
 * `docs/ANIMACIONES-DE-EJERCICIOS.md`), va un lugar reservado del tamaño exacto.
 * Es un hueco a la vista y no un dibujo que finge ser la foto.
 *
 * El carrusel avanza solo cada [MILISEGUNDOS_POR_SLIDE]. Los puntos de abajo
 * son tocables —el diseño los hace `cursor:pointer`— y llevan el estado también en
 * `stateDescription`, porque un rectángulo de 3 dp no lo lee ningún lector de
 * pantalla.
 *
 * Y se pasa deslizando el dedo en cualquier parte de la pantalla, con la regla de
 * [slideTrasDeslizar]. Mientras el dedo arrastra, el carrusel no pasa solo.
 */
@Composable
fun PantallaBienvenida(
    onCrearCuenta: () -> Unit,
    onYaTengoCuenta: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var slide by remember { mutableIntStateOf(0) }

    // Si hay un dedo arrastrando. Mientras tanto el carrusel no pasa solo: el texto
    // cambiaría debajo del dedo y, al soltar, se saltearía un slide.
    var deslizando by remember { mutableStateOf(false) }
    // Dónde se apoyó el dedo y dónde está ahora, en px. Ver el `pointerInput` de abajo.
    var apoyo by remember { mutableFloatStateOf(0f) }
    var dedo by remember { mutableFloatStateOf(0f) }

    val umbral = with(LocalDensity.current) { Tema.tactilMinimo.toPx() }
    val contexto = LocalContext.current
    val velocidadDeGestoRapido = remember(contexto) {
        ViewConfiguration.get(contexto).scaledMinimumFlingVelocity.toFloat()
    }

    // Cambiar cualquiera de las dos claves vuelve a contar desde cero: tocar un punto,
    // pasar de slide deslizando, o soltar el dedo sin llegar a pasar.
    LaunchedEffect(slide, deslizando) {
        if (deslizando) return@LaunchedEffect
        delay(MILISEGUNDOS_POR_SLIDE)
        slide = (slide + 1) % SLIDES.size
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            // Se desliza en toda la pantalla y no sólo sobre la foto: el texto y los
            // botones están abajo, que es donde está el pulgar.
            //
            // Esto sólo MIRA el dedo: en la pasada `Initial` y sin consumir nada, así
            // que no le quita el toque a nadie. Existe porque la regla cuenta lo que el
            // dedo recorrió desde que se apoyó, y los deltas de `draggable` recién
            // empiezan a contar cuando el dedo pasó la tolerancia de arrastre del
            // sistema: con ellos, pasar de slide pedía recorrer esa tolerancia además
            // del objetivo táctil.
            .pointerInput(Unit) {
                awaitEachGesture {
                    val primero = awaitFirstDown(
                        requireUnconsumed = false,
                        pass = PointerEventPass.Initial,
                    )
                    apoyo = primero.position.x
                    dedo = apoyo
                    do {
                        val cambio = awaitPointerEvent(PointerEventPass.Initial).changes
                            .firstOrNull { it.id == primero.id } ?: break
                        dedo = cambio.position.x
                    } while (cambio.pressed)
                }
            }
            // `draggable` decide cuándo el toque se volvió un arrastre horizontal. Hasta
            // ahí, los puntos y los botones reciben el toque; desde ahí, el arrastre es
            // suyo y el botón que quedó debajo no se aprieta. Un arrastre vertical no
            // llega a empezar.
            .draggable(
                // Los deltas no se usan: el recorrido sale de `apoyo` y `dedo`.
                state = rememberDraggableState {},
                orientation = Orientation.Horizontal,
                onDragStarted = { deslizando = true },
                // Llega acá también cuando el sistema cancela el gesto, con velocidad
                // cero: el carrusel no se queda en pausa.
                onDragStopped = { velocidad ->
                    slide = slideTrasDeslizar(
                        actual = slide,
                        total = SLIDES.size,
                        recorrido = dedo - apoyo,
                        velocidad = velocidad,
                        umbral = umbral,
                        velocidadDeGestoRapido = velocidadDeGestoRapido,
                    )
                    deslizando = false
                },
            ),
    ) {
        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            LugarDeLaFoto(modifier = Modifier.fillMaxSize())
            // El degradado del diseño: la foto se funde con el fondo para que el
            // texto de abajo se lea sin una barra que lo corte.
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            0f to Color.Transparent,
                            1f to Tema.color.fondo,
                        ),
                    ),
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Tema.color.fondo)
                .padding(horizontal = Tema.aire.e26)
                .padding(bottom = Tema.aire.e26),
            verticalArrangement = Arrangement.spacedBy(Tema.aire.e16),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Tema.aire.e9),
            ) {
                Box(
                    modifier = Modifier
                        .size(Tema.aire.e26)
                        .background(Tema.color.acento, Tema.forma.celda),
                )
                Text(
                    text = stringResource(R.string.bien_titulo),
                    style = Tema.texto.marca,
                    color = Tema.color.textoPrimario,
                )
            }

            // Alto fijo, y es el del slide MÁS ALTO con la letra que tenga puesta la
            // persona: si el bloque crece y encoge con cada texto, la marca y el
            // título saltan cada vez que pasa el carrusel. Los tres slides se miden
            // con copias invisibles —sin semántica, para que TalkBack no los lea
            // además del que se ve— y el visible va encima. El alto sale de medir y
            // no de un número, así que nada se corta: ni en inglés, ni con la letra
            // agrandada.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    // El diseño le reserva 132 px: e56 + e56 + e20. Es el piso.
                    .heightIn(min = Tema.aire.e56 + Tema.aire.e56 + Tema.aire.e20),
            ) {
                SLIDES.forEach { copia ->
                    TextoDelSlide(
                        contenido = copia,
                        modifier = Modifier.alpha(0f).clearAndSetSemantics {},
                    )
                }
                TextoDelSlide(contenido = SLIDES[slide])
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SLIDES.forEachIndexed { i, _ ->
                    val etiqueta = stringResource(R.string.bien_ir_a_slide, i + 1, SLIDES.size)
                    val esteEs = i == slide
                    Box(
                        modifier = Modifier
                            .objetivoTactil()
                            .clickable { slide = i }
                            // `selected` y no un texto de estado a mano: es la
                            // propiedad que TalkBack ya sabe leer, y así el estado
                            // no depende de una traducción.
                            .semantics {
                                contentDescription = etiqueta
                                selected = esteEs
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(
                            modifier = Modifier
                                .width(Tema.aire.e26)
                                .height(Tema.aire.e3)
                                .background(
                                    if (esteEs) Tema.color.acento else Tema.color.superficieHundida,
                                    Tema.forma.minimo,
                                ),
                        )
                    }
                }
            }

            BotonPrimario(
                titulo = stringResource(R.string.bien_crear),
                onClick = onCrearCuenta,
                modifier = Modifier.fillMaxWidth(),
            )
            BotonDeTexto(
                texto = stringResource(R.string.bien_ya_tengo),
                onClick = onYaTengoCuenta,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

/**
 * A qué slide lleva un deslizamiento que terminó.
 *
 * Hacia la izquierda va el siguiente y hacia la derecha el anterior, como quien pasa
 * una página, y en las puntas da la vuelta igual que el carrusel cuando pasa solo.
 *
 * Pasa si el dedo recorrió al menos [umbral] —el objetivo táctil mínimo: menos que eso
 * es un toque que tembló, no una decisión— o si soltó rápido, a
 * [velocidadDeGestoRapido] o más, para el mismo lado que venía: un gesto corto y
 * decidido también es pasar de página. La velocidad sólo suma para el lado del
 * recorrido; un gesto corto que suelta rápido para el otro lado no mueve nada.
 *
 * Es la regla acordada con iOS (AGENTS.md §10): si cambia, cambia en las dos.
 *
 * @param recorrido lo que se movió el dedo en horizontal desde que se apoyó, en px;
 *   negativo hacia la izquierda.
 * @param velocidad la del dedo al soltar, en px/s, con el mismo signo.
 */
internal fun slideTrasDeslizar(
    actual: Int,
    total: Int,
    recorrido: Float,
    velocidad: Float,
    umbral: Float,
    velocidadDeGestoRapido: Float,
): Int {
    if (total <= 1 || recorrido == 0f) return actual
    val alcanzo = abs(recorrido) >= umbral
    val rapidoParaEseLado = velocidad.sign == recorrido.sign && abs(velocidad) >= velocidadDeGestoRapido
    if (!alcanzo && !rapidoParaEseLado) return actual
    val paso = if (recorrido < 0f) 1 else -1
    return (actual + paso + total) % total
}

/** El título y el cuerpo de un slide: el que se ve, y las copias que miden el alto. */
@Composable
private fun TextoDelSlide(contenido: Slide, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e12),
    ) {
        Text(
            text = stringResource(contenido.titulo),
            style = Tema.texto.tituloBienvenida,
            color = Tema.color.textoPrimario,
        )
        Text(
            text = stringResource(contenido.cuerpo),
            style = Tema.texto.cuerpo,
            color = Tema.color.textoSecundario,
        )
    }
}

/**
 * El lugar reservado de la foto. Dice que falta en vez de disimularlo: si mañana
 * alguien mira esta pantalla y ve un degradado prolijo, va a suponer que está
 * terminada.
 */
@Composable
private fun LugarDeLaFoto(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.background(Tema.color.superficieAlterna),
        contentAlignment = Alignment.Center,
    ) {
        Nota(
            texto = stringResource(R.string.bien_foto_falta),
            icono = { c, m -> Iconos.Imagen(c, m) },
            estilo = Tema.texto.cuerpoSecundario,
            modifier = Modifier.padding(Tema.aire.e20),
        )
    }
}

/** Un slide del carrusel: sólo texto, porque la foto todavía no existe. */
private class Slide(@param:StringRes val titulo: Int, @param:StringRes val cuerpo: Int)

private val SLIDES = listOf(
    Slide(R.string.bien_slide1_t, R.string.bien_slide1_c),
    Slide(R.string.bien_slide2_t, R.string.bien_slide2_c),
    Slide(R.string.bien_slide3_t, R.string.bien_slide3_c),
)

/**
 * Lo que tarda el carrusel en pasar solo. Sale del diseño (`setInterval`, 4200 ms).
 * Es `internal` para que el test de la pantalla mida el autoplay con este mismo número.
 */
internal const val MILISEGUNDOS_POR_SLIDE = 4200L
