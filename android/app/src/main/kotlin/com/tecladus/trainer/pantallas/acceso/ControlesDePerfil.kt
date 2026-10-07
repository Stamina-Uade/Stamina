package com.tecladus.trainer.pantallas.acceso

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.objetivoTactil
import com.tecladus.trainer.core.tema.Tema
import kotlinx.coroutines.flow.filter
import kotlin.math.abs

/**
 * Los tres controles que el diseño inventa para el perfil y el design system no
 * tiene: la lista de una sola opción, la rueda de fecha y el calendario.
 *
 * Están acá y no en `:core` a propósito. `:core` es lo que comparten el teléfono y
 * el reloj (AGENTS.md §4.1), y el reloj no tiene registro: subir un calendario de
 * mes a un módulo que también compila para una pantalla de 45 mm sería mudanza sin
 * mudanza. El día que otra pantalla del teléfono los necesite, se suben.
 */

// ------------------------------------------------------- lista de una opción

/**
 * Una fila de [ListaDeOpciones].
 *
 * [id] no se muestra: es el valor, y existe para que la pantalla no tenga que
 * comparar por texto traducido.
 */
data class OpcionDeLista<T>(
    val id: T,
    val titulo: String,
    val detalle: String? = null,
    /** Lo que va a la derecha, en chico. La distancia de cada objetivo. */
    val alFinal: String? = null,
)

/**
 * Elegir uno entre varios. Es `regSex`, `regSport`, `regLevel`, `regGoal` y
 * `regWatch`: cinco pantallas con el mismo control y distinta lista.
 *
 * 🛑 **La opción elegida no se dice sólo con el color.** El diseño la marca con el
 * acento en el punto, el borde y el relleno, y los tres son color. Acá va además
 * un tilde adentro del punto y el estado en `stateDescription`, porque para quien
 * no distingue ese verde las cinco filas son idénticas.
 *
 * Es un `selectableGroup` de radios de verdad: un lector de pantalla anuncia
 * "2 de 4, seleccionado" sin que la pantalla arme la frase.
 */
@Composable
fun <T> ListaDeOpciones(
    opciones: List<OpcionDeLista<T>>,
    elegida: T?,
    onElegir: (T) -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    Column(
        modifier = modifier.fillMaxWidth().selectableGroup(),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e10),
    ) {
        opciones.forEach { opcion ->
            val marcada = opcion.id == elegida
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .objetivoTactil()
                    .background(
                        if (marcada) Tema.color.acentoRellenoSuave else Tema.color.superficie,
                        Tema.forma.card,
                    )
                    .border(
                        Tema.aire.e1,
                        if (marcada) Tema.color.acento else Tema.color.bordeSuperficie,
                        Tema.forma.card,
                    )
                    .selectable(
                        selected = marcada,
                        enabled = habilitado,
                        role = androidx.compose.ui.semantics.Role.RadioButton,
                        onClick = { onElegir(opcion.id) },
                    )
                    .padding(horizontal = Tema.aire.e14, vertical = Tema.aire.e12),
                horizontalArrangement = Arrangement.spacedBy(Tema.aire.e12),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .clearAndSetSemantics { }
                        .size(Tema.aire.e20)
                        .background(
                            if (marcada) Tema.color.acento else Tema.color.superficieHundida,
                            Tema.forma.pill,
                        )
                        .border(Tema.aire.e1, Tema.color.bordeSignificante, Tema.forma.pill),
                    contentAlignment = Alignment.Center,
                ) {
                    if (marcada) Iconos.Tilde(Tema.color.sobreAcento, Modifier.size(Tema.aire.e12))
                }
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(Tema.aire.e2),
                ) {
                    Text(
                        text = opcion.titulo,
                        style = Tema.texto.tituloCard,
                        color = Tema.color.textoPrimario,
                    )
                    if (opcion.detalle != null) {
                        Text(
                            text = opcion.detalle,
                            style = Tema.texto.nota,
                            color = Tema.color.textoSecundario,
                        )
                    }
                }
                if (opcion.alFinal != null) {
                    Text(
                        text = opcion.alFinal,
                        style = Tema.texto.nota,
                        color = Tema.color.textoTerciario,
                    )
                }
            }
        }
    }
}

// --------------------------------------------------------------- rueda de fecha

/** Una columna de [RuedaDeFecha]. */
data class ColumnaDeRueda(
    /** Lo que anuncia el lector de pantalla: "Año". No se dibuja. */
    val etiqueta: String,
    val elementos: List<String>,
    val elegido: Int,
    val onElegir: (Int) -> Unit,
)

/** Cuántas filas se ven a la vez. Impar, para que haya una en el centro. */
private const val FILAS_VISIBLES = 5

/**
 * La rueda de tres columnas de `regBirth`.
 *
 * 🛑 **El orden de las columnas lo decide el `locale`, no este archivo.** En
 * es-AR es día-mes-año y en en-US es mes-día-año; quien arma las columnas es la
 * pantalla, con `Intl` del lado del diseño y `DateTimeFormatter` del lado de acá.
 * Una rueda con el orden quemado hace que la mitad del mundo cargue mal la fecha
 * de nacimiento sin darse cuenta, porque 03/04 es una fecha válida en los dos.
 *
 * Está escrita sin `SnapFlingBehavior`: al soltar, mira qué fila quedó más cerca
 * del centro y se acomoda ahí. Es menos elegante que un fling con snap y tiene la
 * ventaja de que se entiende leyéndola.
 */
@Composable
fun RuedaDeFecha(
    columnas: List<ColumnaDeRueda>,
    modifier: Modifier = Modifier,
    habilitada: Boolean = true,
) {
    val altoDeFila = Tema.aire.e44
    val altoDeRueda = altoDeFila * FILAS_VISIBLES
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(altoDeRueda)
            .background(Tema.color.superficie, Tema.forma.cardDestacada)
            .border(Tema.aire.e1, Tema.color.bordeSuperficie, Tema.forma.cardDestacada),
    ) {
        // La banda del centro: dice dónde está lo elegido. Es decoración pura y no
        // se toca, así que no lleva semántica ni intercepta el gesto.
        Box(
            modifier = Modifier
                .align(Alignment.Center)
                .fillMaxWidth()
                .height(altoDeFila)
                .background(Tema.color.acentoRellenoSuave),
        )
        Row(modifier = Modifier.fillMaxSize()) {
            columnas.forEach { columna ->
                ColumnaDeLaRueda(
                    columna = columna,
                    altoDeFila = altoDeFila,
                    altoDeRueda = altoDeRueda,
                    habilitada = habilitada,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun ColumnaDeLaRueda(
    columna: ColumnaDeRueda,
    altoDeFila: Dp,
    altoDeRueda: Dp,
    habilitada: Boolean,
    modifier: Modifier = Modifier,
) {
    val estado = rememberLazyListState(initialFirstVisibleItemIndex = columna.elegido)

    // Cuál quedó más cerca del centro del viewport. `derivedStateOf` para que esto
    // se recalcule con el scroll y no recomponga la pantalla entera en cada píxel.
    val centrada by remember(columna.elementos.size) {
        derivedStateOf {
            val info = estado.layoutInfo
            val centro = (info.viewportStartOffset + info.viewportEndOffset) / 2
            info.visibleItemsInfo.minByOrNull { abs(it.offset + it.size / 2 - centro) }?.index
        }
    }

    /** `true` si la fila [i] ya está exactamente en el centro. */
    fun yaEstaCentrada(i: Int) =
        estado.firstVisibleItemIndex == i && estado.firstVisibleItemScrollOffset == 0

    // Al soltar: acomodarse a la fila más cercana y avisar. Mientras el dedo o el
    // fling siguen, no se avisa nada — si no, elegir sería todo lo que pasa por el
    // centro mientras uno pasa de largo.
    //
    // 🛑 El efecto se keyea con `estado`, NO con `isScrollInProgress`. Parece más
    // directo keyearlo con la bandera, y es un lazo: `animateScrollToItem` pone la
    // bandera en `true`, eso cambia la key, Compose cancela la corrutina que está
    // corriendo —o sea, la animación— y al terminar el scroll cortado la bandera
    // vuelve a `false` y arranca todo de nuevo desde una posición intermedia. Se
    // ve como un temblor y, en el peor caso, elige la fila de al lado. Con
    // `snapshotFlow` la bandera se OBSERVA en vez de ser la key, y la animación
    // corre entera.
    LaunchedEffect(estado, columna.elementos.size, habilitada) {
        snapshotFlow { estado.isScrollInProgress }
            .filter { enMovimiento -> !enMovimiento }
            .collect {
                val i = centrada
                if (habilitada && i != null && i in columna.elementos.indices) {
                    if (i != columna.elegido) columna.onElegir(i)
                    if (!yaEstaCentrada(i)) estado.animateScrollToItem(i)
                }
            }
    }

    // Un cambio de afuera —de 31 días a 28 al cambiar el mes— también mueve la
    // rueda. Si la fila ya está centrada no se toca: si no, este efecto pelearía
    // con el de arriba por el mismo `LazyListState` cada vez que alguien elige.
    LaunchedEffect(columna.elegido, columna.elementos.size) {
        if (!estado.isScrollInProgress &&
            columna.elegido in columna.elementos.indices &&
            !yaEstaCentrada(columna.elegido)
        ) {
            estado.animateScrollToItem(columna.elegido)
        }
    }

    val etiqueta = columna.etiqueta
    LazyColumn(
        state = estado,
        modifier = modifier
            .fillMaxSize()
            .selectableGroup()
            .semantics { contentDescription = etiqueta },
        // El relleno pone la primera fila en el centro: con esto, "la fila i está
        // arriba de todo" y "la fila i está en el centro" son la misma posición, y
        // `animateScrollToItem(i)` centra sin cuentas.
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            vertical = (altoDeRueda - altoDeFila) / 2,
        ),
        userScrollEnabled = habilitada,
    ) {
        items(count = columna.elementos.size) { i ->
            val elegida = i == columna.elegido
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(altoDeFila)
                    .selectable(
                        selected = elegida,
                        enabled = habilitada,
                        role = androidx.compose.ui.semantics.Role.RadioButton,
                        onClick = { columna.onElegir(i) },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = columna.elementos[i],
                    style = if (elegida) Tema.texto.valorDato else Tema.texto.cuerpo,
                    color = if (elegida) Tema.color.textoPrimario else Tema.color.textoTerciario,
                )
            }
        }
    }
}

// -------------------------------------------------------------- calendario

/** Una celda del calendario. `null` en [dia] es un hueco antes del día 1. */
data class DiaDelCalendario(
    val dia: Int?,
    val fecha: FechaSimple?,
    val elegido: Boolean,
    val pasado: Boolean,
)

/**
 * El calendario de un mes de `regGoal`. La semana empieza el LUNES, como el diseño.
 *
 * Se dibuja con `Row`s y no con `LazyVerticalGrid` porque vive adentro de una
 * pantalla que ya scrollea: una grilla con scroll propio adentro de otra con
 * scroll es la forma más rápida de que la pantalla deje de poder scrollearse.
 */
@Composable
fun CalendarioMensual(
    titulo: String,
    nombresDeDias: List<String>,
    celdas: List<DiaDelCalendario>,
    etiquetaMesAnterior: String,
    etiquetaMesSiguiente: String,
    onMesAnterior: () -> Unit,
    onMesSiguiente: () -> Unit,
    onElegir: (FechaSimple) -> Unit,
    modifier: Modifier = Modifier,
    /**
     * `false` en el mes de hoy: para atrás no hay nada que elegir, sólo meses
     * enteros de días apagados. Una flecha que se puede tocar y no cambia nada se
     * lee como un cuelgue.
     */
    hayMesAnterior: Boolean = true,
    habilitado: Boolean = true,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(Tema.color.superficie, Tema.forma.cardDestacada)
            .border(Tema.aire.e1, Tema.color.bordeSuperficie, Tema.forma.cardDestacada)
            .padding(Tema.aire.e12),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e11),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FlechaDeMes(etiquetaMesAnterior, onMesAnterior, hayMesAnterior) { c, m ->
                Iconos.ChevronIzquierda(c, m)
            }
            Text(
                text = titulo,
                style = Tema.texto.tituloCard,
                color = Tema.color.textoPrimario,
            )
            FlechaDeMes(etiquetaMesSiguiente, onMesSiguiente, true) { c, m ->
                Iconos.ChevronDerecha(c, m)
            }
        }

        Row(modifier = Modifier.fillMaxWidth()) {
            nombresDeDias.forEach { nombre ->
                Text(
                    text = nombre,
                    style = Tema.texto.nota,
                    color = Tema.color.textoTerciario,
                    textAlign = TextAlign.Center,
                    // El encabezado de la columna no se lee: cada celda ya dice su
                    // fecha completa, y una "L" suelta no significa nada.
                    modifier = Modifier.weight(1f).clearAndSetSemantics { },
                )
            }
        }

        celdas.chunked(DIAS_DE_LA_SEMANA).forEach { semana ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Tema.aire.e2),
            ) {
                semana.forEach { celda ->
                    CeldaDelCalendario(celda, Modifier.weight(1f), habilitado, onElegir)
                }
                // La última semana puede venir corta: se rellena para que los días
                // queden bajo su columna en vez de estirarse.
                repeat(DIAS_DE_LA_SEMANA - semana.size) {
                    Box(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun CeldaDelCalendario(
    celda: DiaDelCalendario,
    modifier: Modifier,
    habilitado: Boolean,
    onElegir: (FechaSimple) -> Unit,
) {
    if (celda.dia == null || celda.fecha == null) {
        Box(modifier = modifier.heightIn(min = Tema.aire.e34))
        return
    }
    val tocable = habilitado && !celda.pasado
    Box(
        modifier = modifier
            .heightIn(min = Tema.aire.e34)
            .background(
                if (celda.elegido) Tema.color.acento else Tema.color.superficie,
                Tema.forma.chip,
            )
            .selectable(
                selected = celda.elegido,
                enabled = tocable,
                role = androidx.compose.ui.semantics.Role.RadioButton,
                onClick = { onElegir(celda.fecha) },
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = celda.dia.toString(),
            style = Tema.texto.valorFila,
            color = when {
                celda.elegido -> Tema.color.sobreAcento
                celda.pasado -> Tema.color.textoDeshabilitado
                else -> Tema.color.textoCuerpo
            },
        )
    }
}

@Composable
private fun FlechaDeMes(
    etiqueta: String,
    onClick: () -> Unit,
    habilitada: Boolean,
    icono: @Composable (androidx.compose.ui.graphics.Color, Modifier) -> Unit,
) {
    Box(
        modifier = Modifier
            .objetivoTactil()
            .background(Tema.color.superficieHundida, Tema.forma.chip)
            .clickable(enabled = habilitada, onClick = onClick)
            .semantics { contentDescription = etiqueta },
        contentAlignment = Alignment.Center,
    ) {
        icono(
            if (habilitada) Tema.color.textoSecundario else Tema.color.textoDeshabilitado,
            Modifier.size(Iconos.tamano),
        )
    }
}

// ------------------------------------------------------------- días y horas

/**
 * Los siete chips de día. Cada uno es un interruptor propio, no un radio: se
 * entrena más de un día.
 */
@Composable
fun ChipsDeDias(
    nombresCortos: List<String>,
    nombresLargos: List<String>,
    elegidos: Set<Int>,
    onAlternar: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e5),
    ) {
        (1..DIAS_DE_LA_SEMANA).toList().chunked(CHIPS_POR_FILA).forEach { fila ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Tema.aire.e5),
            ) {
                fila.forEach { dia ->
                    ChipDeDia(
                        corto = nombresCortos.getOrElse(dia - 1) { "" },
                        largo = nombresLargos.getOrElse(dia - 1) { "" },
                        marcado = dia in elegidos,
                        onAlternar = { onAlternar(dia) },
                        modifier = Modifier.weight(1f),
                    )
                }
                // La última fila viene corta: se rellena para que los chips queden
                // del mismo ancho que los de arriba y no estirados.
                repeat(CHIPS_POR_FILA - fila.size) { Box(modifier = Modifier.weight(1f)) }
            }
        }
    }
}

/**
 * 🛑 Cuatro por fila, y no los siete que dibuja el diseño.
 *
 * No es una preferencia: con siete en una fila, en un teléfono de 360 dp cada chip
 * mide unos 40 dp de ancho —(360 − 52 de márgenes − 30 de separaciones) / 7— y el
 * mínimo táctil de AGENTS.md §10.1 son 48. `objetivoTactil()` no lo salva, porque
 * `weight` manda sobre el `minWidth`. Con cuatro dan 73 dp y entran cómodos.
 */
private const val CHIPS_POR_FILA = 4

@Composable
private fun ChipDeDia(
    corto: String,
    largo: String,
    marcado: Boolean,
    onAlternar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .objetivoTactil()
            .background(
                if (marcado) Tema.color.acentoRellenoActivo else Tema.color.superficie,
                Tema.forma.chip,
            )
            .border(
                Tema.aire.e1,
                if (marcado) Tema.color.acento else Tema.color.bordeSuperficie,
                Tema.forma.chip,
            )
            .clickable(onClick = onAlternar)
            .semantics {
                // El chip dice "Lun"; el lector de pantalla dice "Lunes".
                contentDescription = largo
                toggleableState = if (marcado) {
                    androidx.compose.ui.state.ToggleableState.On
                } else {
                    androidx.compose.ui.state.ToggleableState.Off
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = corto,
            style = Tema.texto.chip,
            color = if (marcado) Tema.color.acento else Tema.color.textoSecundario,
            textAlign = TextAlign.Center,
        )
    }
}

/**
 * La hora de un día. El diseño usa un `<select>` con siete horas fijas; acá es un
 * menú con las mismas siete.
 *
 * 🛑 Son siete horas y no un reloj completo porque así lo dibuja el diseño, y
 * porque el dato existe para disparar el aviso de preparación, no para agendar. Si
 * alguna vez hace falta cualquier hora, va un `TimePicker` y esta lista se borra.
 */
@Composable
fun SelectorDeHora(
    minutoDelDia: Int,
    opciones: List<Int>,
    etiqueta: String,
    onElegir: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var abierto by remember { mutableStateOf(false) }
    val descripcion = "$etiqueta ${horaDelDia(minutoDelDia)}"
    Box(modifier = modifier) {
        Row(
            modifier = Modifier
                .objetivoTactil()
                .background(Tema.color.superficieHundida, Tema.forma.boton)
                .border(Tema.aire.e1, Tema.color.bordeSignificante, Tema.forma.boton)
                .clickable { abierto = true }
                .padding(horizontal = Tema.aire.e12)
                .semantics { contentDescription = descripcion },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Tema.aire.e7),
        ) {
            Text(
                text = horaDelDia(minutoDelDia),
                style = Tema.texto.valorFila,
                color = Tema.color.textoPrimario,
            )
            Box(modifier = Modifier.clearAndSetSemantics { }) {
                Iconos.Reloj(Tema.color.textoSecundario, Modifier.size(Iconos.tamano))
            }
        }
        DropdownMenu(expanded = abierto, onDismissRequest = { abierto = false }) {
            opciones.forEach { minuto ->
                DropdownMenuItem(
                    text = {
                        Text(
                            text = horaDelDia(minuto),
                            style = Tema.texto.valorFila,
                            color = Tema.color.textoPrimario,
                        )
                    },
                    onClick = {
                        onElegir(minuto)
                        abierto = false
                    },
                    modifier = Modifier.semantics {
                        stateDescription = if (minuto == minutoDelDia) etiqueta else ""
                    },
                )
            }
        }
    }
}
