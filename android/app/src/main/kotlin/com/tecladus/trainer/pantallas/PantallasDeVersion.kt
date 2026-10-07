package com.tecladus.trainer.pantallas

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.BotonSecundario
import com.tecladus.trainer.core.ds.Card
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.red.PuertaDeVersion
import com.tecladus.trainer.core.red.VersionGate
import com.tecladus.trainer.core.tema.Tema

/**
 * La pantalla que no deja seguir: esta app está por debajo de `minimum_build`.
 *
 * 🛑 No tiene salida a la app, a propósito. AGENTS.md §5.1: "muestra una pantalla de
 * actualización obligatoria y no sigue". No hay flecha de volver, y el botón físico
 * de atrás hace lo de siempre, que es cerrar la app: volver adentro sería seguir
 * usando un formato que el servidor ya decidió cortar.
 *
 * No está en el diseño canónico; se arma con los componentes del design system y el
 * mismo aire que las pantallas de acceso.
 */
@Composable
fun PantallaActualizacionObligatoria(
    puerta: VersionGate,
    noSeAbrioLaTienda: Boolean,
    onActualizar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Tema.color.fondo),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(Tema.aire.e26),
            verticalArrangement = Arrangement.spacedBy(Tema.aire.e20),
        ) {
            // Decoración: lo que pasa lo dice el título.
            Box(modifier = Modifier.clearAndSetSemantics { }) {
                Iconos.Aviso(Tema.color.acento, Modifier.size(Tema.aire.e36))
            }
            Text(
                text = stringResource(R.string.version_obligatoria_titulo),
                style = Tema.texto.tituloPantalla,
                color = Tema.color.textoPrimario,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = textoDeLaPuerta(puerta, R.string.version_obligatoria_cuerpo),
                style = Tema.texto.cuerpo,
                color = Tema.color.textoSecundario,
            )
            if (noSeAbrioLaTienda) {
                Nota(
                    texto = stringResource(R.string.version_sin_tienda),
                    icono = { c, m -> Iconos.Aviso(c, m) },
                    tono = Tema.color.error,
                    estilo = Tema.texto.cuerpo,
                )
            }
            BotonPrimario(
                titulo = stringResource(R.string.version_actualizar),
                onClick = onActualizar,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

/**
 * El aviso de que hay una versión mejor. Se puede descartar, y descartado no vuelve
 * hasta el próximo arranque.
 *
 * Va arriba de lo que se esté mostrando —el acceso o la app— y no lo tapa: es una
 * recomendación, no una puerta.
 */
@Composable
fun AvisoDeActualizacion(
    puerta: VersionGate,
    noSeAbrioLaTienda: Boolean,
    onActualizar: () -> Unit,
    onDescartar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Tema.aire.e14, vertical = Tema.aire.e8),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e8)) {
            Text(
                text = stringResource(R.string.version_recomendada_titulo),
                style = Tema.texto.tituloCard,
                color = Tema.color.textoPrimario,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = textoDeLaPuerta(puerta, R.string.version_recomendada_cuerpo),
                style = Tema.texto.cuerpoSecundario,
                color = Tema.color.textoSecundario,
            )
            if (noSeAbrioLaTienda) {
                Nota(
                    texto = stringResource(R.string.version_sin_tienda),
                    icono = { c, m -> Iconos.Aviso(c, m) },
                    tono = Tema.color.error,
                )
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                BotonSecundario(
                    texto = stringResource(R.string.version_actualizar),
                    onClick = onActualizar,
                    modifier = Modifier.weight(1f),
                )
                BotonDeTexto(
                    texto = stringResource(R.string.version_ahora_no),
                    onClick = onDescartar,
                    enfasis = false,
                )
            }
        }
    }
}

/**
 * El cuerpo del mensaje: el texto de la app, salvo que el servidor mande un `code` que
 * esta versión no conoce junto con su `message` ([PuertaDeVersion.mensajeDelServidor]).
 *
 * Hoy la app no conoce ningún `code`: la migración que siembra la puerta los deja en
 * `null`. El día que el servidor empiece a mandar uno, su traducción se agrega a
 * [TEXTOS_POR_CODIGO] y a los dos `strings_version.xml`.
 */
@Composable
private fun textoDeLaPuerta(puerta: VersionGate, @StringRes propio: Int): String {
    val traducido = puerta.code?.let { TEXTOS_POR_CODIGO[it] }
    return when {
        traducido != null -> stringResource(traducido)
        else -> PuertaDeVersion.mensajeDelServidor(puerta, TEXTOS_POR_CODIGO.keys) ?: stringResource(propio)
    }
}

private val TEXTOS_POR_CODIGO: Map<String, Int> = emptyMap()
