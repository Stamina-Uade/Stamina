package com.tecladus.trainer.pantallas.acceso

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.state.ToggleableState
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.Card
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.ds.objetivoTactil
import com.tecladus.trainer.core.red.BloqueLegal
import com.tecladus.trainer.core.tema.Tema

/**
 * El aviso de salud, con la casilla que hay que tildar para seguir.
 *
 * 🛑 **Este paso no está en el diseño canónico**: lo pidió Iván el 2026-09-09
 * ("un aviso para que consulte con profesional siempre"). Está en el registro y no
 * sólo dentro de los términos porque un aviso enterrado en la sección 4 de un
 * texto largo no lo lee nadie, y lo que no se leyó no protege a nadie — ni a la
 * persona, ni a Trainer.
 *
 * 🛑 **El texto NO está en `strings.xml`**: baja de `GET /legal`, y lo que se
 * manda al crear la cuenta es la VERSIÓN de ese texto. Un registro que dice
 * "aceptó" sin decir qué aceptó no sirve el día que haga falta, porque para
 * entonces el texto cambió tres veces. Por el mismo motivo la casilla no viene
 * tildada y el botón no se habilita hasta que alguien la toque: una aceptación por
 * defecto no es una aceptación.
 *
 * Lo que sí es un string local es el rótulo de "todavía no lo revisó un abogado",
 * porque eso no es parte del texto legal: es una advertencia nuestra sobre él.
 */
@Composable
fun PantallaAviso(
    bloque: BloqueLegal?,
    revisado: Boolean,
    aceptado: Boolean,
    onAceptado: (Boolean) -> Unit,
    enCurso: Boolean,
    error: String?,
    onVerTerminos: () -> Unit,
    onSeguir: () -> Unit,
    modifier: Modifier = Modifier,
    /**
     * La salida cuando el alta ya no puede terminar: el permiso del paso 2 se
     * venció, o el pedido se cortó y la cuenta puede haberse creado igual del otro
     * lado. `null` mientras no sea el caso.
     *
     * 🛑 Existe porque volver al correo sería una trampa: si la cuenta se creó,
     * `POST /auth/register` contesta 202 lo mismo —es la regla anti-enumeración— y
     * el código no llega nunca. Sin este botón, la única salida es cerrar la app.
     */
    onIrAlLogin: (() -> Unit)? = null,
) {
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            if (bloque == null) {
                // Sin el texto no se puede aceptar nada. Se dice, no se deja una
                // pantalla vacía con un botón que igual funciona.
                Nota(
                    texto = stringResource(R.string.legal_sin_texto),
                    icono = { c, m -> Iconos.SinConexion(c, m) },
                    tono = Tema.color.error,
                    estilo = Tema.texto.cuerpo,
                )
                return@PasoDeRegistro
            }

            TituloYCuerpo(titulo = bloque.title, cuerpo = bloque.summary)

            if (!revisado) {
                Nota(
                    texto = stringResource(R.string.legal_sin_revisar),
                    icono = { c, m -> Iconos.Aviso(c, m) },
                )
            }

            bloque.sections.forEach { seccion ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e6)) {
                        Text(
                            text = seccion.title,
                            style = Tema.texto.tituloCard,
                            color = Tema.color.textoPrimario,
                        )
                        Text(
                            text = seccion.body,
                            style = Tema.texto.cuerpo,
                            color = Tema.color.textoSecundario,
                        )
                    }
                }
            }

            BotonDeTexto(
                texto = stringResource(R.string.legal_ver_terminos),
                onClick = onVerTerminos,
                modifier = Modifier.fillMaxWidth(),
            )

            if (error != null) {
                Nota(
                    texto = error,
                    icono = { c, m -> Iconos.Aviso(c, m) },
                    tono = Tema.color.error,
                    estilo = Tema.texto.cuerpo,
                )
            }

            if (onIrAlLogin != null) {
                BotonDeTexto(
                    texto = stringResource(R.string.legal_ir_al_login),
                    onClick = onIrAlLogin,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        abajo = {
            if (bloque != null) {
                Casilla(
                    texto = bloque.acceptance,
                    marcada = aceptado,
                    onMarcar = onAceptado,
                    habilitada = !enCurso,
                )
                BotonPrimario(
                    titulo = stringResource(R.string.legal_seguir),
                    onClick = onSeguir,
                    modifier = Modifier.fillMaxWidth(),
                    habilitado = !enCurso && aceptado,
                )
            }
        },
    )
}

/**
 * La casilla de aceptar.
 *
 * El cuadrado y el texto son **un solo control**: tocar la frase la marca. Una
 * casilla de 18 dp al lado de tres renglones de texto es un blanco imposible con
 * el pulgar, y el error acá se paga caro — alguien que quiso aceptar y no pudo se
 * va, y alguien que aceptó sin querer no aceptó nada.
 */
@Composable
internal fun Casilla(
    texto: String,
    marcada: Boolean,
    onMarcar: (Boolean) -> Unit,
    habilitada: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .objetivoTactil()
            .clickable(enabled = habilitada) { onMarcar(!marcada) }
            .padding(vertical = Tema.aire.e6)
            .semantics(mergeDescendants = true) {
                toggleableState = if (marcada) ToggleableState.On else ToggleableState.Off
            },
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e12),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(Tema.aire.e22)
                .background(
                    if (marcada) Tema.color.acento else Tema.color.superficieHundida,
                    Tema.forma.celda,
                )
                .border(Tema.aire.e1, Tema.color.bordeSignificante, Tema.forma.celda),
            contentAlignment = Alignment.Center,
        ) {
            if (marcada) {
                Iconos.Tilde(Tema.color.sobreAcento, Modifier.size(Tema.aire.e12))
            }
        }
        Text(
            text = texto,
            style = Tema.texto.cuerpoSecundario,
            color = Tema.color.textoCuerpo,
            modifier = Modifier.weight(1f),
        )
    }
}

/** Los términos completos, en una hoja aparte. Mismo formato que el aviso. */
@Composable
fun PantallaTerminos(bloque: BloqueLegal?, onVolver: () -> Unit, modifier: Modifier = Modifier) {
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            if (bloque == null) {
                Nota(
                    texto = stringResource(R.string.legal_sin_texto),
                    icono = { c, m -> Iconos.SinConexion(c, m) },
                    tono = Tema.color.error,
                    estilo = Tema.texto.cuerpo,
                )
                return@PasoDeRegistro
            }
            TituloYCuerpo(titulo = bloque.title, cuerpo = bloque.summary)
            bloque.sections.forEach { seccion ->
                Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e6)) {
                    Text(
                        text = seccion.title,
                        style = Tema.texto.tituloCard,
                        color = Tema.color.textoPrimario,
                    )
                    Text(
                        text = seccion.body,
                        style = Tema.texto.cuerpo,
                        color = Tema.color.textoSecundario,
                    )
                }
            }
        },
        abajo = {
            BotonPrimario(
                titulo = stringResource(R.string.legal_volver),
                onClick = onVolver,
                modifier = Modifier.fillMaxWidth(),
            )
        },
    )
}
