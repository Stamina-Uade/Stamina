package com.tecladus.trainer.pantallas.gimnasio

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonSecundario
import com.tecladus.trainer.core.ds.EtiquetaSeccion
import com.tecladus.trainer.core.ds.FuenteDeMedia
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.MediaDeEjercicio
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.ds.Tecla
import com.tecladus.trainer.core.ds.TecladoNumerico
import com.tecladus.trainer.core.ds.objetivoTactil
import com.tecladus.trainer.core.gimnasio.EstadoDelEjercicio
import com.tecladus.trainer.core.gimnasio.UnidadDeCarga
import com.tecladus.trainer.core.tema.Tema
import java.text.NumberFormat
import kotlin.math.roundToInt
import kotlinx.coroutines.delay

/**
 * La pantalla de **mientras entrenás**.
 *
 * Rediseñada el 2026-09-08 sobre la referencia que trajo Iván: en vez de una
 * serie por vez con steppers grandes, **todas las series a la vez en una tabla**
 * —serie, lo que hiciste la vez pasada, kilos, repeticiones y el tilde— más la
 * animación del ejercicio arriba y un carrusel para saltar de ejercicio.
 *
 * 🛑 La diferencia con la referencia, y es a propósito: ahí el tilde mide unos
 * 23 pt y las celdas unos 33. AGENTS.md §10.1 pide **48 dp sin excepciones**, así
 * que acá cada celda de kilos, cada celda de repeticiones y cada tilde miden 48.
 * Eso cuesta alto: la animación es más chica y con muchas series la lista
 * scrollea. Es el precio de que se pueda tocar con la mano sudada.
 *
 * La regla de qué número aparece en cada fila NO está acá: está en
 * `:core/gimnasio/Sesion.kt`, con 19 tests que corren sin emulador.
 */

/** Qué se está editando en el teclado: una celda concreta de una fila concreta. */
private data class Celda(val fila: Int, val esCarga: Boolean)

@Composable
fun PantallaEntrenando(
    estado: EstadoDelEjercicio,
    nombreEjercicio: String,
    nombresDeLaRutina: List<String>,
    indiceEjercicio: Int,
    segundosDeSesion: Int,
    onEstado: (EstadoDelEjercicio) -> Unit,
    onIrAEjercicio: (Int) -> Unit,
    onTerminar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val locale = LocalConfiguration.current.locales[0]
    val numero = remember(locale) {
        NumberFormat.getInstance(locale).apply { maximumFractionDigits = 1 }
    }
    val esTiempo = estado.ejercicio.unidad == UnidadDeCarga.TIEMPO

    var editando by remember(indiceEjercicio) { mutableStateOf<Celda?>(null) }
    var buffer by remember { mutableStateOf("") }

    var menuDeFila by remember(indiceEjercicio) { mutableStateOf<Int?>(null) }
    var eligiendoDescanso by remember { mutableStateOf(false) }
    var borrada by remember(indiceEjercicio) { mutableStateOf<Int?>(null) }

    var descansoRestante by remember { mutableIntStateOf(0) }
    LaunchedEffect(descansoRestante) {
        if (descansoRestante > 0) {
            delay(MILISEGUNDOS_POR_SEGUNDO)
            descansoRestante -= 1
        }
    }

    Box(modifier = modifier.fillMaxSize().background(Tema.color.fondo)) {
        Column(modifier = Modifier.fillMaxSize()) {

            BarraDeSesion(
                segundos = segundosDeSesion,
                descansoRestante = descansoRestante,
                onTerminar = onTerminar,
            )

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(Tema.aire.e12),
            ) {
                CarruselDeEjercicios(
                    nombres = nombresDeLaRutina,
                    actual = indiceEjercicio,
                    onIr = onIrAEjercicio,
                )

                HuecoDeAnimacion(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Tema.aire.e16),
                )

                Column(
                    modifier = Modifier.padding(horizontal = Tema.aire.e16),
                    verticalArrangement = Arrangement.spacedBy(Tema.aire.e10),
                ) {
                    Text(
                        text = nombreEjercicio,
                        style = Tema.texto.tituloEjercicio,
                        color = Tema.color.textoPrimario,
                    )
                    AccionesDelEjercicio(
                        descanso = relojDe(estado.descansoSegundos),
                        onDescanso = { eligiendoDescanso = true },
                    )
                }

                Column(
                    modifier = Modifier.padding(horizontal = Tema.aire.e16),
                    verticalArrangement = Arrangement.spacedBy(Tema.aire.e6),
                ) {
                    EncabezadoDeLaTabla(esTiempo = esTiempo)
                    // El numero que se ve es la POSICION, no el indice: si se borra la
                    // serie 2, las que quedan son 1, 2 y 3. Mostrar "1, 3, 4" hace
                    // pensar que falta algo, cuando lo que falta se borro a proposito.
                    estado.strip().forEachIndexed { posicion, chip ->
                        val v = estado.valoresDeLaFila(chip.indice)
                        FilaDeSerie(
                            numero = posicion + 1,
                            esExtra = chip.esExtra,
                            onOpciones = { menuDeFila = chip.indice },
                            onBorrar = {
                                onEstado(estado.borrarSerie(chip.indice))
                                borrada = chip.indice
                            },
                            previa = estado.previas[chip.indice],
                            reps = numero.format(v.reps),
                            carga = numero.format(v.peso),
                            marcada = estado.estaMarcada(chip.indice),
                            esTiempo = esTiempo,
                            formato = numero,
                            onEditarCarga = { editando = Celda(chip.indice, true); buffer = "" },
                            onEditarReps = { editando = Celda(chip.indice, false); buffer = "" },
                            onAlternar = {
                                val siguiente = estado.alternarLaFila(chip.indice)
                                onEstado(siguiente)
                                descansoRestante = if (siguiente.estaMarcada(chip.indice)) {
                                    estado.ejercicio.descansoSegundos
                                } else {
                                    0
                                }
                            },
                        )
                    }
                    Nota(
                        texto = stringResource(R.string.gym_como_se_borra),
                        icono = { color, m -> Iconos.ChevronIzquierda(color, m) },
                    )
                    BotonSecundario(
                        texto = stringResource(R.string.gym_anadir_serie),
                        onClick = { onEstado(estado.agregarSerieExtra()) },
                        modifier = Modifier.fillMaxWidth(),
                        icono = { color, m -> Iconos.Mas(color, m) },
                    )
                }

                Spacer(Modifier.height(Tema.aire.e22))
            }
        }

        val filaBorrada = borrada
        if (filaBorrada != null) {
            BarraDeshacer(
                onDeshacer = {
                    onEstado(estado.restaurarSerie(filaBorrada))
                    borrada = null
                },
                onCerrar = { borrada = null },
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }

        val fila = menuDeFila
        if (fila != null) {
            HojaDeOpcionesDeFila(
                numero = fila + 1,
                onSaltear = {
                    onEstado(estado.copy(corrigiendo = fila).saltear())
                    menuDeFila = null
                },
                onBorrar = {
                    onEstado(estado.borrarSerie(fila))
                    borrada = fila
                    menuDeFila = null
                },
                onCerrar = { menuDeFila = null },
            )
        }

        if (eligiendoDescanso) {
            HojaDeDescanso(
                actual = estado.descansoSegundos,
                onElegir = {
                    onEstado(estado.conDescanso(it))
                    eligiendoDescanso = false
                },
                onCerrar = { eligiendoDescanso = false },
            )
        }

        val celda = editando
        if (celda != null) {
            val v = estado.valoresDeLaFila(celda.fila)
            HojaDeTeclado(
                titulo = stringResource(
                    if (celda.esCarga) R.string.gym_editar_carga else R.string.gym_editar_reps,
                    celda.fila + 1,
                ),
                mostrado = if (buffer.isNotEmpty()) {
                    buffer
                } else if (celda.esCarga) {
                    numero.format(v.peso)
                } else {
                    numero.format(v.reps)
                },
                admiteDecimales = celda.esCarga,
                onTecla = { tecla ->
                    buffer = aplicarTecla(buffer, tecla, soloEnteros = !celda.esCarga)
                    val reps = if (celda.esCarga) {
                        v.reps
                    } else {
                        (buffer.toIntOrNull() ?: 0).coerceIn(0, TOPE_REPETICIONES)
                    }
                    val peso = if (celda.esCarga) {
                        (buffer.replace(',', '.').toDoubleOrNull() ?: 0.0).coerceIn(0.0, TOPE_CARGA)
                    } else {
                        v.peso
                    }
                    onEstado(estado.escribirEnLaFila(celda.fila, reps, peso))
                },
                onCerrar = { editando = null; buffer = "" },
            )
        }
    }
}

// ---------------------------------------------------------------------- piezas

@Composable
private fun BarraDeSesion(segundos: Int, descansoRestante: Int, onTerminar: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Tema.color.superficieBarra)
            .padding(horizontal = Tema.aire.e16, vertical = Tema.aire.e8),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e12),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            EtiquetaSeccion(
                stringResource(
                    if (descansoRestante > 0) R.string.gym_descanso else R.string.gym_sesion_cronometro,
                ),
                color = if (descansoRestante > 0) Tema.color.acento else Tema.color.textoSecundario,
            )
            Text(
                text = relojDe(if (descansoRestante > 0) descansoRestante else segundos),
                style = Tema.texto.cronometro,
                color = if (descansoRestante > 0) Tema.color.acento else Tema.color.textoPrimario,
            )
        }
        BotonSecundario(
            texto = stringResource(R.string.gym_terminar_corto),
            onClick = onTerminar,
            icono = { color, m -> Iconos.Bandera(color, m) },
        )
    }
}

/**
 * El carrusel de ejercicios. Cada burbuja es de 48 dp o más y lleva el número del
 * ejercicio, no una miniatura: las miniaturas son el mismo asset que falta para
 * la animación. El actual lleva un anillo, y además su número va en acento — el
 * anillo solo sería forma, pero el anillo Y el color juntos se leen mejor.
 */
@Composable
private fun CarruselDeEjercicios(nombres: List<String>, actual: Int, onIr: (Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = Tema.aire.e16),
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
    ) {
        nombres.forEachIndexed { i, nombre ->
            val esActual = i == actual
            Box(
                modifier = Modifier
                    .objetivoTactil()
                    .size(Tema.tactilMinimo)
                    .background(
                        if (esActual) Tema.color.acentoRellenoActivo else Tema.color.superficieHundida,
                        CircleShape,
                    )
                    .border(
                        if (esActual) Tema.aire.e2 else Tema.aire.e1,
                        if (esActual) Tema.color.acento else Tema.color.bordeSignificante,
                        CircleShape,
                    )
                    .clickable { onIr(i) }
                    .semantics { contentDescription = nombre },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = (i + 1).toString(),
                    style = Tema.texto.valorDato,
                    color = if (esActual) Tema.color.acento else Tema.color.textoSecundario,
                )
            }
        }
    }
}

/**
 * 🛑 El lugar de la animación, **reservado y medido**, con un cartel que dice qué
 * falta.
 *
 * No es un adorno ni un "ya lo hacemos": las animaciones anatómicas de la app de
 * referencia son una biblioteca licenciada que no tenemos, y AGENTS.md §9.1 dice
 * que el catálogo va de 50 a 500 ejercicios **sin desplegar la app**, así que el
 * archivo no puede viajar en el APK: necesita el bucket propio, que hoy es un
 * hueco marcado. Dejarlo dibujado y vacío es lo más barato de revertir y lo único
 * que no miente.
 */
@Composable
private fun HuecoDeAnimacion(modifier: Modifier = Modifier) {
    // TODO(media): la fuente está cableada en `NoHay` porque no hay ni un archivo
    // y porque la decisión de dónde viven —APK o bucket— no está tomada. Ver
    // `docs/MEDIA-DE-EJERCICIOS.md`. Cuando esté, esta línea pasa a construir la
    // fuente desde el id del ejercicio y NADA MÁS de esta pantalla cambia: por eso
    // ya pasa por `MediaDeEjercicio` en vez de dibujar el hueco a mano.
    MediaDeEjercicio(
        fuente = FuenteDeMedia.NoHay,
        descripcion = stringResource(R.string.gym_animacion_falta),
        textoDelHueco = stringResource(R.string.gym_animacion_detalle),
        modifier = modifier.height(Tema.aire.e56 * ALTO_DE_LA_ANIMACION_EN_UNIDADES_DE_56),
    )
}

/**
 * Los chips de acción del ejercicio. Están **deshabilitados** y lo dicen: cada uno
 * necesita una pantalla que todavía no existe (tutorial, sustitutos, notas). Un
 * chip que se ve igual que los demás y no hace nada es peor que ninguno, así que
 * llevan el color de deshabilitado y una descripción que lo explica.
 */
/**
 * Los chips de acción del ejercicio.
 *
 * **Descanso funciona**: abre el selector y lo que se elija corre al marcar la
 * serie siguiente. Los otros tres están **deshabilitados y lo dicen**: cada uno
 * necesita una pantalla que todavía no existe (tutorial, sustitutos, notas). Un
 * chip que se ve igual que los demás y no hace nada es peor que ninguno.
 */
@Composable
private fun AccionesDelEjercicio(descanso: String, onDescanso: () -> Unit) {
    val sinHacer = stringResource(R.string.gym_accion_sin_hacer)
    Row(
        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
    ) {
        Box(
            modifier = Modifier
                .heightIn(min = Tema.tactilMinimo)
                .background(Tema.color.acentoRellenoSuave, Tema.forma.pill)
                .border(Tema.aire.e1, Tema.color.acento, Tema.forma.pill)
                .clickable(onClick = onDescanso)
                .padding(horizontal = Tema.aire.e14),
            contentAlignment = Alignment.Center,
        ) {
            Nota(
                texto = stringResource(R.string.gym_descanso_chip, descanso),
                icono = { color, m -> Iconos.Reloj(color, m) },
                tono = Tema.color.acento,
                estilo = Tema.texto.tituloCard,
            )
        }
        val acciones: List<Pair<String, @Composable (Color, Modifier) -> Unit>> = listOf(
            stringResource(R.string.gym_accion_tutorial) to { c, m -> Iconos.Reproducir(c, m) },
            stringResource(R.string.gym_accion_reemplazar) to { c, m -> Iconos.Reemplazar(c, m) },
            stringResource(R.string.gym_accion_notas) to { c, m -> Iconos.Lapiz(c, m) },
        )
        for ((etiqueta, icono) in acciones) {
            Box(
                modifier = Modifier
                    .heightIn(min = Tema.tactilMinimo)
                    .background(Tema.color.superficieHundida, Tema.forma.pill)
                    .border(Tema.aire.e1, Tema.color.bordeSuperficie, Tema.forma.pill)
                    .padding(horizontal = Tema.aire.e14)
                    .semantics { contentDescription = "$etiqueta. $sinHacer" },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = etiqueta,
                    style = Tema.texto.tituloCard,
                    color = Tema.color.textoDeshabilitado,
                )
            }
        }
    }
}

@Composable
private fun EncabezadoDeLaTabla(esTiempo: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = Tema.aire.e4),
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        EtiquetaSeccion(stringResource(R.string.gym_col_serie), Modifier.width(Tema.aire.e34))
        EtiquetaSeccion(stringResource(R.string.gym_col_previa), Modifier.weight(1.1f))
        EtiquetaSeccion(
            stringResource(if (esTiempo) R.string.gym_col_seg else R.string.gym_col_kg),
            Modifier.weight(1f),
        )
        EtiquetaSeccion(stringResource(R.string.gym_col_reps), Modifier.weight(1f))
        Spacer(Modifier.width(Tema.tactilMinimo))
    }
}

/**
 * Una fila de la tabla. **Todo lo tocable mide 48 dp**: las dos celdas y el tilde.
 *
 * El estado "hecha" NO se comunica sólo por color: la fila marcada cambia de
 * fondo, el tilde se llena, y el propio tilde aparece dibujado. Además la
 * descripción accesible dice "marcar" o "desmarcar", que es la diferencia real.
 */
/**
 * Una fila de la tabla. **Todo lo tocable mide 48 dp**: el número, las dos celdas
 * y el tilde.
 *
 * 🛑 **Borrar tiene tres caminos, no uno.**
 *
 * 1. **El gesto**: se arrastra la fila hacia la izquierda y aparece «Borrar».
 * 2. **El número de la serie es un botón** y abre las mismas opciones. WCAG 2.5.1
 *    pide una alternativa de un solo punto para todo gesto con trayecto: quien
 *    tiene temblor, artritis o usa un switch **no desliza**. Un borrado que sólo
 *    se puede hacer arrastrando es un borrado que algunas personas no pueden
 *    hacer, y la fila que está debajo lo dice con todas las letras.
 * 3. Y **nada se borra de verdad hasta que se cierra el «Deshacer»**.
 *
 * El estado "hecha" tampoco se comunica sólo por color: cambia el fondo, el tilde
 * se llena y la descripción accesible dice "marcar" o "desmarcar".
 */
@Composable
private fun FilaDeSerie(
    numero: Int,
    esExtra: Boolean,
    previa: com.tecladus.trainer.core.gimnasio.SerieHecha?,
    reps: String,
    carga: String,
    marcada: Boolean,
    esTiempo: Boolean,
    formato: NumberFormat,
    onOpciones: () -> Unit,
    onBorrar: () -> Unit,
    onEditarCarga: () -> Unit,
    onEditarReps: () -> Unit,
    onAlternar: () -> Unit,
) {
    val textoPrevia = if (previa == null) {
        stringResource(R.string.gym_sin_previa)
    } else {
        stringResource(
            R.string.gym_previa_valores,
            formato.format(previa.peso),
            formato.format(previa.reps),
        )
    }
    val anchoBorrar = Tema.aire.e56 * 2
    val anchoPx = with(LocalDensity.current) { anchoBorrar.toPx() }
    var arrastre by remember(numero) { mutableFloatStateOf(0f) }
    val desplazamiento by animateFloatAsState(arrastre, label = "arrastre de la fila")

    Box(modifier = Modifier.fillMaxWidth()) {
        // Lo que aparece detrás al arrastrar. Es un botón de verdad, no un adorno.
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(Tema.color.errorFondo, Tema.forma.celda)
                .border(Tema.aire.e1, Tema.color.errorBorde, Tema.forma.celda),
            contentAlignment = Alignment.CenterEnd,
        ) {
            Box(
                modifier = Modifier
                    .objetivoTactil()
                    .clickable { arrastre = 0f; onBorrar() }
                    .padding(horizontal = Tema.aire.e14),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(R.string.gym_borrar),
                    style = Tema.texto.tituloCard,
                    color = Tema.color.error,
                )
            }
        }

        Row(
            modifier = Modifier
                .offset { IntOffset(desplazamiento.roundToInt(), 0) }
                .fillMaxWidth()
                .background(
                    if (marcada) Tema.color.acentoRellenoSuave else Tema.color.superficie,
                    Tema.forma.celda,
                )
                .pointerInput(numero) {
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            arrastre = if (arrastre < -anchoPx / 2f) -anchoPx else 0f
                        },
                        onDragCancel = { arrastre = 0f },
                    ) { _, delta ->
                        arrastre = (arrastre + delta).coerceIn(-anchoPx, 0f)
                    }
                }
                .padding(horizontal = Tema.aire.e4, vertical = Tema.aire.e2),
            horizontalArrangement = Arrangement.spacedBy(Tema.aire.e6),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .objetivoTactil()
                    .size(Tema.tactilMinimo)
                    .clickable(onClick = onOpciones)
                    .semantics { contentDescription = "" },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = (if (esExtra) "+" else "") + numero,
                    style = Tema.texto.valorFila,
                    color = if (marcada) Tema.color.acento else Tema.color.textoSecundario,
                    textAlign = TextAlign.Center,
                )
            }
            Text(
                text = textoPrevia,
                style = Tema.texto.cuerpoSecundario,
                color = Tema.color.textoTerciario,
                modifier = Modifier.weight(1f),
            )
            CeldaEditable(carga, Modifier.weight(1f), onEditarCarga, stringResource(R.string.gym_editar_carga, numero))
            CeldaEditable(reps, Modifier.weight(1f), onEditarReps, stringResource(R.string.gym_editar_reps, numero))
            Box(
                modifier = Modifier
                    .objetivoTactil()
                    .size(Tema.tactilMinimo)
                    .background(
                        if (marcada) Tema.color.acento else Tema.color.superficieControl,
                        Tema.forma.boton,
                    )
                    .border(
                        Tema.aire.e1,
                        if (marcada) Tema.color.acento else Tema.color.bordeSignificante,
                        Tema.forma.boton,
                    )
                    .clickable(onClick = onAlternar)
                    .semantics { contentDescription = "" },
                contentAlignment = Alignment.Center,
            ) {
                Iconos.Tilde(
                    if (marcada) Tema.color.sobreAcento else Tema.color.textoSecundario,
                    Modifier.size(Iconos.tamano),
                )
            }
        }
    }
    if (esTiempo) {
        Spacer(Modifier.height(Tema.aire.e1))
    }
}

@Composable
private fun CeldaEditable(
    valor: String,
    modifier: Modifier,
    onClick: () -> Unit,
    descripcion: String,
) {
    Box(
        modifier = modifier
            .heightIn(min = Tema.tactilMinimo)
            .background(Tema.color.superficieHundida, Tema.forma.input)
            .border(Tema.aire.e1, Tema.color.bordeInput, Tema.forma.input)
            .clickable(onClick = onClick)
            .semantics { contentDescription = "$descripcion: $valor" },
        contentAlignment = Alignment.Center,
    ) {
        Text(text = valor, style = Tema.texto.valorDato, color = Tema.color.textoPrimario)
    }
}

@Composable
private fun HojaDeTeclado(
    titulo: String,
    mostrado: String,
    admiteDecimales: Boolean,
    onTecla: (Tecla) -> Unit,
    onCerrar: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Tema.color.velo)
            .clickable(onClick = onCerrar)
            .clearAndSetSemantics { },
        contentAlignment = Alignment.BottomCenter,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Tema.color.superficieOverlay, Tema.forma.cardDestacada)
                .padding(horizontal = Tema.aire.e16)
                .padding(top = Tema.aire.e16, bottom = Tema.aire.e26),
            verticalArrangement = Arrangement.spacedBy(Tema.aire.e13),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = titulo,
                    style = Tema.texto.cuerpoSecundario,
                    color = Tema.color.textoSecundario,
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier.objetivoTactil().clickable(onClick = onCerrar),
                    contentAlignment = Alignment.CenterEnd,
                ) {
                    Text(
                        text = stringResource(R.string.gym_teclado_listo),
                        style = Tema.texto.tituloCard,
                        color = Tema.color.acento,
                    )
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = Tema.tactilMinimo)
                    .background(Tema.color.superficieInput, Tema.forma.boton)
                    .border(Tema.aire.e1, Tema.color.acento, Tema.forma.boton)
                    .padding(Tema.aire.e10),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = mostrado,
                    style = Tema.texto.numeroGrande,
                    color = Tema.color.textoPrimario,
                    textAlign = TextAlign.Center,
                )
            }
            TecladoNumerico(
                admiteDecimales = admiteDecimales,
                etiquetaBorrar = stringResource(R.string.gym_teclado_borrar),
                textoDeLaComa = stringResource(R.string.gym_teclado_coma),
                onTecla = onTecla,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

/** El alto del hueco de la animación, en múltiplos del token de 56. */
private const val ALTO_DE_LA_ANIMACION_EN_UNIDADES_DE_56 = 3

/**
 * Las opciones de una serie: el camino sin gesto.
 *
 * Vive acá y no en un menú de tres puntos porque el ancho de la fila ya está
 * ocupado por lo que importa —el número, la previa, los dos valores y el tilde— y
 * meter un control más obligaría a bajar alguno de 48 dp.
 */
@Composable
private fun HojaDeOpcionesDeFila(
    numero: Int,
    onSaltear: () -> Unit,
    onBorrar: () -> Unit,
    onCerrar: () -> Unit,
) {
    HojaInferior(titulo = stringResource(R.string.gym_menu_serie, numero), onCerrar = onCerrar) {
        BotonSecundario(
            texto = stringResource(R.string.gym_saltear_serie),
            onClick = onSaltear,
            modifier = Modifier.fillMaxWidth(),
            icono = { color, m -> Iconos.Saltear(color, m) },
        )
        BotonSecundario(
            texto = stringResource(R.string.gym_borrar_serie),
            onClick = onBorrar,
            modifier = Modifier.fillMaxWidth(),
            icono = { color, m -> Iconos.Tacho(color, m) },
        )
    }
}

/**
 * El descanso de este ejercicio, para hoy.
 *
 * No toca el plan: el plan lo decide el motor de la fase 7. Esto es lo que la
 * persona quiere hoy, que puede no ser lo mismo. El cero está a propósito: en una
 * superserie no hay descanso, y sin esa opción habría que saltearlo a mano cada vez.
 */
@Composable
private fun HojaDeDescanso(actual: Int, onElegir: (Int) -> Unit, onCerrar: () -> Unit) {
    HojaInferior(titulo = stringResource(R.string.gym_descanso_titulo), onCerrar = onCerrar) {
        for (segundos in DESCANSOS_OFRECIDOS) {
            val elegido = segundos == actual
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = Tema.tactilMinimo)
                    .background(
                        if (elegido) Tema.color.acentoRellenoSuave else Tema.color.superficieHundida,
                        Tema.forma.boton,
                    )
                    .border(
                        if (elegido) Tema.aire.e2 else Tema.aire.e1,
                        if (elegido) Tema.color.acento else Tema.color.bordeSignificante,
                        Tema.forma.boton,
                    )
                    .clickable { onElegir(segundos) },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (segundos == 0) {
                        stringResource(R.string.gym_descanso_sin)
                    } else {
                        stringResource(R.string.gym_descanso_opcion, relojDe(segundos))
                    },
                    style = Tema.texto.valorDato,
                    color = if (elegido) Tema.color.acento else Tema.color.textoPrimario,
                )
            }
        }
    }
}

/**
 * La barra de deshacer.
 *
 * Es lo que hace que borrar no sea destructivo. El dato no se pierde nunca: la
 * serie sigue guardada y esto la devuelve tal cual estaba.
 */
@Composable
private fun BarraDeshacer(onDeshacer: () -> Unit, onCerrar: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(Tema.aire.e16)
            .background(Tema.color.superficieAlterna, Tema.forma.card)
            .border(Tema.aire.e1, Tema.color.bordeSignificante, Tema.forma.card)
            .padding(start = Tema.aire.e14),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Nota(
            texto = stringResource(R.string.gym_serie_borrada),
            icono = { color, m -> Iconos.Tacho(color, m) },
            tono = Tema.color.textoPrimario,
            estilo = Tema.texto.cuerpo,
            modifier = Modifier.weight(1f),
        )
        Box(
            modifier = Modifier.objetivoTactil().clickable(onClick = onDeshacer).padding(horizontal = Tema.aire.e12),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = stringResource(R.string.gym_deshacer),
                style = Tema.texto.tituloCard,
                color = Tema.color.acento,
            )
        }
        Box(
            modifier = Modifier
                .objetivoTactil()
                .clickable(onClick = onCerrar)
                .semantics { contentDescription = "" },
            contentAlignment = Alignment.Center,
        ) {
            Iconos.Cruz(Tema.color.textoSecundario, Modifier.size(Iconos.tamano))
        }
    }
}

/** La hoja inferior, con su velo y su botón de cerrar. */
@Composable
private fun HojaInferior(
    titulo: String,
    onCerrar: () -> Unit,
    contenido: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Tema.color.velo)
            .clickable(onClick = onCerrar)
            .clearAndSetSemantics { },
        contentAlignment = Alignment.BottomCenter,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Tema.color.superficieOverlay, Tema.forma.cardDestacada)
                .padding(horizontal = Tema.aire.e16)
                .padding(top = Tema.aire.e16, bottom = Tema.aire.e26),
            verticalArrangement = Arrangement.spacedBy(Tema.aire.e10),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = titulo,
                    style = Tema.texto.cuerpoSecundario,
                    color = Tema.color.textoSecundario,
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier.objetivoTactil().clickable(onClick = onCerrar),
                    contentAlignment = Alignment.CenterEnd,
                ) {
                    Text(
                        text = stringResource(R.string.gym_cerrar),
                        style = Tema.texto.tituloCard,
                        color = Tema.color.acento,
                    )
                }
            }
            contenido()
        }
    }
}

/** Los descansos que se ofrecen. El 0 es "sin descanso": existen las superseries. */
private val DESCANSOS_OFRECIDOS = listOf(0, 30, 45, 60, 90, 120, 180)
