package com.tecladus.trainer.pantallas.gimnasio

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.EtiquetaSeccion
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.gimnasio.EstadoDelEjercicio
import com.tecladus.trainer.core.gimnasio.UnidadDeCarga
import com.tecladus.trainer.core.tema.Tema

/**
 * La pantalla de **antes de entrenar**: qué vas a hacer hoy, y el botón para
 * empezar.
 *
 * Es la pantalla `gimnasio` que `design/origen/HomeB.dc.html` ya tenía —la fuente
 * canónica del teléfono— más dos cosas que trajo la referencia de Iván y que el
 * diseño no tenía: el **resumen** (cuántos ejercicios y cuánto dura) y la
 * **distribución muscular**.
 *
 * 🛑 La distribución muscular sale del catálogo y la duración del plan, que son datos del
 * servidor (AGENTS.md §9.1). Mientras no lleguen, no se muestran: con `distribucion` vacía
 * no aparece la sección, y con `minutosEstimados` en `null` el resumen no dice minutos. Un
 * número inventado en esta pantalla se lee como un dato.
 *
 * @param aviso lo que conviene saber de la sincronización —sin conexión, series sin subir—,
 *   o `null` si no hay nada que decir.
 */
@Composable
fun PantallaRutina(
    ejercicios: List<EstadoDelEjercicio>,
    nombres: List<String>,
    distribucion: List<Pair<String, Int>>,
    minutosEstimados: Int?,
    onEmpezar: () -> Unit,
    onIrAEjercicio: (Int) -> Unit,
    modifier: Modifier = Modifier,
    aviso: String? = null,
) {
    Column(modifier = modifier.fillMaxSize().background(Tema.color.fondo)) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Tema.aire.e16),
            verticalArrangement = Arrangement.spacedBy(Tema.aire.e16),
        ) {
            Spacer(Modifier.height(Tema.aire.e8))

            Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e4)) {
                Text(
                    text = stringResource(R.string.gym_rutina_titulo),
                    style = Tema.texto.tituloPantalla,
                    color = Tema.color.textoPrimario,
                )
                Text(
                    text = if (minutosEstimados != null) {
                        stringResource(R.string.gym_rutina_resumen, ejercicios.size, minutosEstimados)
                    } else {
                        stringResource(R.string.gym_rutina_resumen_sin_minutos, ejercicios.size)
                    },
                    style = Tema.texto.cuerpo,
                    color = Tema.color.textoSecundario,
                )
                if (aviso != null) {
                    Nota(
                        texto = aviso,
                        icono = { c, m -> Iconos.Aviso(c, m) },
                        tono = Tema.color.textoSecundario,
                        estilo = Tema.texto.cuerpoSecundario,
                    )
                }
            }

            if (distribucion.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e8)) {
                    Text(
                        text = stringResource(R.string.gym_distribucion),
                        style = Tema.texto.tituloCard,
                        color = Tema.color.textoSecundario,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
                    ) {
                        for ((musculo, porcentaje) in distribucion) {
                            BarraDeMusculo(musculo, porcentaje)
                        }
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e8)) {
                EtiquetaSeccion(stringResource(R.string.gym_lista_ejercicios))
                ejercicios.forEachIndexed { i, e ->
                    FilaDeEjercicio(
                        numero = i + 1,
                        nombre = nombres[i],
                        prescripcion = prescripcionDe(e),
                        onClick = { onIrAEjercicio(i) },
                    )
                }
            }

            Spacer(Modifier.height(Tema.aire.e8))
        }

        Column(modifier = Modifier.padding(horizontal = Tema.aire.e16).padding(bottom = Tema.aire.e22)) {
            BotonPrimario(
                titulo = stringResource(R.string.gym_empezar),
                onClick = onEmpezar,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

/**
 * "4 series × 8 reps", o "4 series × 6–10 reps" cuando el plan pide una rampa.
 *
 * La primera versión mostraba siempre las repeticiones de la PRIMERA serie, así
 * que un press de 10/8/8/6 decía "4 series × 10 reps": un número que no era el de
 * ninguna de las otras tres. Es el mismo error que motivó pasar la prescripción de
 * cadena a lista (`ESPECIFICACION.md` §6.2), reaparecido en la presentación.
 */
@Composable
private fun prescripcionDe(estado: EstadoDelEjercicio): String {
    val series = estado.objetivos.size
    if (estado.objetivos.isEmpty()) return ""
    val minimo = estado.objetivos.minOf { it.reps }
    val maximo = estado.objetivos.maxOf { it.reps }
    return when {
        estado.ejercicio.unidad == UnidadDeCarga.TIEMPO ->
            stringResource(R.string.gym_prescripcion_tiempo, series, maximo)
        minimo == maximo -> stringResource(R.string.gym_prescripcion_reps, series, maximo)
        else -> stringResource(R.string.gym_prescripcion_rango, series, minimo, maximo)
    }
}

/**
 * El porcentaje va en NÚMERO además de en barra. La referencia lo dibuja con un
 * músculo pintado de azul y el número al lado; la barra sola sería significado por
 * color y por tamaño, que no se lee igual en todas las pantallas ni con todas las
 * vistas.
 */
@Composable
private fun BarraDeMusculo(musculo: String, porcentaje: Int) {
    Column(
        modifier = Modifier
            .background(Tema.color.superficie, Tema.forma.card)
            .border(Tema.aire.e1, Tema.color.bordeSuperficie, Tema.forma.card)
            .padding(horizontal = Tema.aire.e12, vertical = Tema.aire.e10),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e4),
    ) {
        Text(
            text = stringResource(R.string.gym_porcentaje, porcentaje),
            style = Tema.texto.valorDato,
            color = Tema.color.acento,
        )
        Text(text = musculo, style = Tema.texto.nota, color = Tema.color.textoSecundario)
    }
}

@Composable
private fun FilaDeEjercicio(
    numero: Int,
    nombre: String,
    prescripcion: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = Tema.tactilMinimo)
            .background(Tema.color.superficie, Tema.forma.card)
            .border(Tema.aire.e1, Tema.color.bordeSuperficie, Tema.forma.card)
            .clickable(onClick = onClick)
            .semantics { contentDescription = "$nombre. $prescripcion" }
            .padding(horizontal = Tema.aire.e12, vertical = Tema.aire.e10),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e12),
    ) {
        // La burbuja lleva el número, no una miniatura: la miniatura es el mismo
        // asset que falta para la animación.
        Box(
            modifier = Modifier
                .size(Tema.tactilMinimo)
                .background(Tema.color.superficieHundida, CircleShape)
                .border(Tema.aire.e1, Tema.color.bordeSuperficie, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = numero.toString(),
                style = Tema.texto.valorDato,
                color = Tema.color.textoSecundario,
                textAlign = TextAlign.Center,
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Tema.aire.e2)) {
            Text(text = prescripcion, style = Tema.texto.cuerpoSecundario, color = Tema.color.textoSecundario)
            Text(text = nombre, style = Tema.texto.valorFila, color = Tema.color.textoPrimario)
        }
    }
}
