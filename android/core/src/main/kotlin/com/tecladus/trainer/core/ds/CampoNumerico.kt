package com.tecladus.trainer.core.ds

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.core.tema.Tema

/**
 * El control con el que se carga una serie en el gimnasio: repeticiones y peso.
 *
 * Está pensado para la mano equivocada, sudada, con cuarenta segundos de descanso:
 *
 * - Los tres controles —el valor, el − y el +— son de 48 dp o más. Los dos
 *   botones ocupan **la mitad del ancho cada uno**, que es mucho más que 48 y es
 *   lo que hace que no haya que apuntar.
 * - El valor se toca y abre el teclado numérico: subir de 20 a 60 kg con el + son
 *   dieciséis taps.
 * - El paso está escrito debajo ("de a 2,5 kg"), porque si no, el + es una
 *   sorpresa.
 *
 * Las descripciones de los botones entran por parámetro: este módulo no tiene
 * recursos de texto y no puede tener una sola palabra sin traducir.
 */
@Composable
fun CampoNumerico(
    etiqueta: String,
    valorMostrado: String,
    paso: String,
    descripcionMenos: String,
    descripcionMas: String,
    onMenos: () -> Unit,
    onMas: () -> Unit,
    onTocarValor: () -> Unit,
    modifier: Modifier = Modifier,
    enfocado: Boolean = false,
) {
    val borde = if (enfocado) Tema.color.acento else Tema.color.bordeSuperficie
    Column(
        modifier = modifier
            .background(Tema.color.superficie, Tema.forma.card)
            .border(Tema.aire.e1, borde, Tema.forma.card)
            .padding(horizontal = Tema.aire.e11, vertical = Tema.aire.e11),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e7),
    ) {
        Text(text = etiqueta, style = Tema.texto.labelCampo, color = Tema.color.textoSecundario)

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .objetivoTactil()
                .background(Tema.color.superficieHundida, Tema.forma.input)
                .clickable(onClick = onTocarValor),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = valorMostrado,
                style = Tema.texto.numeroGrande,
                color = Tema.color.textoPrimario,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Tema.aire.e7),
        ) {
            BotonDePaso(descripcionMenos, onMenos, Modifier.weight(1f)) { color, m ->
                Iconos.Menos(color, m)
            }
            BotonDePaso(descripcionMas, onMas, Modifier.weight(1f)) { color, m ->
                Iconos.Mas(color, m)
            }
        }

        Text(
            text = paso,
            style = Tema.texto.nota,
            color = Tema.color.textoTerciario,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun BotonDePaso(
    descripcion: String,
    onClick: () -> Unit,
    modifier: Modifier,
    icono: @Composable (Color, Modifier) -> Unit,
) {
    Box(
        modifier = modifier
            .objetivoTactil()
            .background(Tema.color.superficieControl, Tema.forma.boton)
            .border(Tema.aire.e1, Tema.color.bordeBotonSecundario, Tema.forma.boton)
            .clickable(onClick = onClick)
            // El ícono es un trazo: sin esto el botón no tiene nombre para nadie que
            // no lo esté viendo.
            .semantics { contentDescription = descripcion },
        contentAlignment = Alignment.Center,
    ) {
        icono(Tema.color.textoPrimario, Modifier.size(Iconos.tamano))
    }
}

/** Una tecla del teclado numérico. */
sealed interface Tecla {
    data class Digito(val valor: Char) : Tecla

    /** El separador decimal. Sólo existe donde el valor puede tener decimales. */
    data object Coma : Tecla

    /** La flecha de retroceso. */
    data object Borrar : Tecla

    /**
     * El lugar donde iría la coma en un campo que sólo admite enteros.
     *
     * Es un hueco y no un segundo cero: la primera versión ponía otro "0" ahí y
     * quedaban dos ceros idénticos en la misma fila, que es una trampa. Tampoco
     * es una coma deshabilitada: un control que se ve y no hace nada es peor que
     * ninguno. No se dibuja, no se toca y el lector de pantalla no lo ve.
     */
    data object Hueco : Tecla
}

/**
 * El teclado para los saltos grandes. Existe porque el stepper es bueno para
 * corregir de a poco y pésimo para cambiar de 20 a 60.
 *
 * La grilla es de tres columnas y las teclas miden 56 dp de alto: más que el
 * mínimo, porque se tocan de a muchas y seguido.
 */
@Composable
fun TecladoNumerico(
    admiteDecimales: Boolean,
    etiquetaBorrar: String,
    textoDeLaComa: String,
    onTecla: (Tecla) -> Unit,
    modifier: Modifier = Modifier,
) {
    val teclas: List<Tecla> = buildList {
        for (c in '1'..'9') add(Tecla.Digito(c))
        add(if (admiteDecimales) Tecla.Coma else Tecla.Hueco)
        add(Tecla.Digito('0'))
        add(Tecla.Borrar)
    }
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e8),
        userScrollEnabled = false,
    ) {
        items(teclas) { tecla ->
            if (tecla is Tecla.Hueco) {
                Box(modifier = Modifier.fillMaxWidth().heightIn(min = Tema.aire.e56))
                return@items
            }
            val etiqueta = when (tecla) {
                is Tecla.Digito -> tecla.valor.toString()
                Tecla.Coma -> textoDeLaComa
                Tecla.Borrar -> "←"
                Tecla.Hueco -> ""
            }
            val descripcion = if (tecla is Tecla.Borrar) etiquetaBorrar else etiqueta
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = Tema.aire.e56)
                    .objetivoTactil()
                    .background(
                        if (tecla is Tecla.Borrar) Tema.color.superficieHundida else Tema.color.superficieControl,
                        Tema.forma.boton,
                    )
                    .border(Tema.aire.e1, Tema.color.bordeBotonSecundario, Tema.forma.boton)
                    .clickable { onTecla(tecla) }
                    .semantics { contentDescription = descripcion },
                contentAlignment = Alignment.Center,
            ) {
                Text(text = etiqueta, style = Tema.texto.tecla, color = Tema.color.textoPrimario)
            }
        }
    }
}
