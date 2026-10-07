package com.tecladus.trainer.pantallas.gimnasio

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonSecundario
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.tema.Tema

/**
 * Lo que se ve cuando no hay una rutina que mostrar: buscándola, sin rutina guardada y sin
 * señal, con un perfil al que le falta algo, o con una respuesta que la app no entendió.
 *
 * Dice qué pasa con palabras, y cuando reintentar sirve de algo, ofrece reintentar. Un
 * cuadro vacío se lee como un error de la app; una rutina de ejemplo, como un plan que
 * nadie hizo.
 */
@Composable
internal fun EstadoSinRutina(
    @StringRes titulo: Int,
    @StringRes detalle: Int?,
    onReintentar: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().background(Tema.color.fondo).padding(Tema.aire.e20),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e12, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Iconos.Mancuerna(Tema.color.textoSecundario, Modifier.size(Tema.aire.e36))
        Text(
            text = stringResource(titulo),
            style = Tema.texto.tituloPantalla,
            color = Tema.color.textoPrimario,
            textAlign = TextAlign.Center,
        )
        if (detalle != null) {
            Text(
                text = stringResource(detalle),
                style = Tema.texto.cuerpo,
                color = Tema.color.textoSecundario,
                textAlign = TextAlign.Center,
            )
        }
        if (onReintentar != null) {
            BotonSecundario(
                texto = stringResource(R.string.gym_reintentar),
                onClick = onReintentar,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
