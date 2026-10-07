package com.tecladus.trainer.pantallas.acceso

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.CampoDeTexto
import com.tecladus.trainer.core.tema.Tema
import com.tecladus.trainer.core.tema.TokensMovimiento

/**
 * Los dos campos de contraseña, el medidor y la lista de reglas.
 *
 * Es `is.fpNew` de `design/origen/Trainer App.dc.html`, tal cual: la etiqueta
 * arriba, el "Mostrar" adentro del campo a la derecha, las tres barras finas y los
 * tres puntitos. Está en su propio archivo y no adentro de la pantalla de registro
 * porque el diseño lo usa en DOS lugares —el alta y la recuperación— y cuando se
 * escriban las cuatro pantallas de recuperar la contraseña, esto se reusa sin
 * copiarlo.
 *
 * Las tres reglas salen de [REGLAS_DE_CLAVE], que es el mismo archivo que un test
 * compara contra el servidor.
 */
@Composable
fun CamposDeClave(
    clave: String,
    onClave: (String) -> Unit,
    repetida: String,
    onRepetida: (String) -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    // Un solo interruptor para los dos campos, como en el diseño: si uno se ve y
    // el otro no, compararlos a ojo es imposible, que es justo para lo que está el
    // segundo campo.
    var visible by remember { mutableStateOf(false) }

    val cumplidas = fuerzaDeClave(clave)
    val coinciden = repetida.isNotEmpty() && repetida == clave
    val difieren = repetida.isNotEmpty() && repetida != clave

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e13),
    ) {
        CampoDeTexto(
            valor = clave,
            onCambio = onClave,
            etiqueta = stringResource(R.string.reg_clave_campo),
            esContrasena = true,
            enmascarada = !visible,
            habilitado = habilitado,
            accion = {
                BotonDeTexto(
                    texto = stringResource(
                        if (visible) R.string.reg_clave_ocultar else R.string.reg_clave_mostrar,
                    ),
                    onClick = { visible = !visible },
                    enfasis = false,
                )
            },
        )

        CampoDeTexto(
            valor = repetida,
            onCambio = onRepetida,
            etiqueta = stringResource(R.string.reg_clave_repetir),
            esContrasena = true,
            enmascarada = !visible,
            esUltimo = true,
            habilitado = habilitado,
            bordeAcentuado = coinciden,
            error = if (difieren) stringResource(R.string.reg_clave_no_coincide) else null,
            ayuda = if (coinciden) stringResource(R.string.reg_clave_coincide) else null,
        )

        MedidorDeClave(cumplidas = cumplidas)
        ListaDeReglas(clave = clave)
    }
}

/**
 * Las tres barras. Una por regla cumplida.
 *
 * 🛑 El color NO es lo único que informa: la cantidad de barras llenas ya lo dice,
 * y abajo están los tres puntitos con el texto de cada regla. Para un lector de
 * pantalla, las barras son una sola cosa con un `stateDescription` que dice
 * "2 de 3"; las barras sueltas no se anuncian.
 */
@Composable
private fun MedidorDeClave(cumplidas: Int) {
    val total = REGLAS_DE_CLAVE.size
    val descripcion = stringResource(R.string.reg_clave_fuerza, cumplidas, total)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                contentDescription = descripcion
                stateDescription = descripcion
            },
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e5),
    ) {
        repeat(total) { i ->
            val destino = when {
                i >= cumplidas -> Tema.color.superficieHundida
                cumplidas == total -> Tema.color.acento
                else -> Tema.color.acentoRellenoActivo
            }
            val color by animateColorAsState(
                targetValue = destino,
                animationSpec = androidx.compose.animation.core.tween(TokensMovimiento.media),
                label = "barra",
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(Tema.aire.e3)
                    .background(color, Tema.forma.minimo),
            )
        }
    }
}

/** Los tres puntitos con el texto de cada regla. */
@Composable
private fun ListaDeReglas(clave: String) {
    Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e6)) {
        REGLAS_DE_CLAVE.forEach { regla ->
            val ok = regla.cumple(clave)
            val texto = if (regla.argumento != null) {
                stringResource(regla.etiqueta, regla.argumento)
            } else {
                stringResource(regla.etiqueta)
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(Tema.aire.e8),
                verticalAlignment = Alignment.CenterVertically,
                // Una sola cosa para el lector de pantalla: el punto es decoración
                // y el estado va en `stateDescription`, no en un color.
                modifier = Modifier.semantics(mergeDescendants = true) {
                    stateDescription = texto
                },
            ) {
                Box(
                    modifier = Modifier
                        .clearAndSetSemantics { }
                        .size(Tema.aire.e5)
                        .background(
                            if (ok) Tema.color.acento else Tema.color.superficieHundida,
                            Tema.forma.pill,
                        ),
                )
                Text(
                    text = texto,
                    style = Tema.texto.labelCampo,
                    color = if (ok) Tema.color.textoCuerpo else Tema.color.textoTerciario,
                )
            }
        }
    }
}
