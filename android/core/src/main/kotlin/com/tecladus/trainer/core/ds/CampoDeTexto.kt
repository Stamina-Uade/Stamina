package com.tecladus.trainer.core.ds

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import com.tecladus.trainer.core.tema.Tema

/**
 * Un campo de texto del design system.
 *
 * Está construido sobre `BasicTextField` y no sobre el de Material a propósito: el
 * de Material trae su propia paleta y su propio alto, y los dos son justo lo que
 * §10.1 dice que no se decide en la pantalla. Acá el color sale de los tokens y el
 * alto no puede bajar del mínimo táctil.
 *
 * El error va con TEXTO, no sólo con el borde en rojo: quien no distingue el rojo
 * ve un campo igual a los demás.
 *
 * El [marcador] es el texto de ejemplo que se ve con el campo vacío ("tu@mail.com").
 * NO reemplaza a [etiqueta] y por eso los dos son parámetros distintos: un marcador
 * que hace de etiqueta desaparece justo cuando el campo se llena, y entonces nadie
 * —ni quien mira ni el lector de pantalla— sabe qué se está escribiendo.
 *
 * [etiquetaVisible] en `false` la SACA DE LA VISTA pero la deja para el lector de
 * pantalla. Es para las pantallas donde el título de la pantalla ya dice qué es el
 * campo y repetirlo arriba sobra. No hay forma de que un campo se quede sin
 * etiqueta: el parámetro es obligatorio.
 *
 * [accion] es el slot de la derecha, ADENTRO del campo: el "Mostrar / Ocultar" de
 * la pantalla de contraseña del diseño. Va adentro y no al lado porque así lo
 * dibuja `fpNew`, y porque afuera se lo lleva puesto el ancho en un teléfono
 * chico.
 *
 * [bordeAcentuado] pinta el borde con el acento para decir "esto está bien": las
 * dos contraseñas coinciden. Nunca es lo ÚNICO que lo dice —siempre hay un texto
 * al lado—, porque un borde de color, para quien no distingue ese color, es un
 * campo igual a los demás.
 *
 * [esDecimal] pide el teclado con la coma. Lo usan el peso y la altura, que el
 * diseño dibuja con `inputMode="decimal"`. No valida nada: quien convierte y
 * chequea el rango es la pantalla, contra los topes del contrato.
 *
 * [esContrasena] y [enmascarada] son dos cosas distintas y por eso son dos
 * parámetros. La primera elige el teclado y le dice al gestor de contraseñas que
 * esto es una; la segunda decide si se ven puntitos. El "Mostrar" del diseño
 * cambia sólo la segunda: el campo sigue siendo una contraseña aunque se esté
 * viendo.
 */
@Composable
fun CampoDeTexto(
    valor: String,
    onCambio: (String) -> Unit,
    etiqueta: String,
    modifier: Modifier = Modifier,
    etiquetaVisible: Boolean = true,
    marcador: String? = null,
    ayuda: String? = null,
    error: String? = null,
    accion: (@Composable () -> Unit)? = null,
    bordeAcentuado: Boolean = false,
    esContrasena: Boolean = false,
    enmascarada: Boolean = esContrasena,
    esCorreo: Boolean = false,
    esDecimal: Boolean = false,
    esUltimo: Boolean = false,
    habilitado: Boolean = true,
) {
    val borde = when {
        error != null -> Tema.color.error
        bordeAcentuado -> Tema.color.acento
        else -> Tema.color.bordeInput
    }
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e6),
    ) {
        if (etiquetaVisible) {
            Text(text = etiqueta, style = Tema.texto.labelCampo, color = Tema.color.textoSecundario)
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = Tema.tactilMinimo)
                .background(Tema.color.superficieInput, Tema.forma.input)
                .border(Tema.aire.e1, borde, Tema.forma.input)
                .padding(horizontal = Tema.aire.e13),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                if (valor.isEmpty() && marcador != null) {
                    Text(
                        text = marcador,
                        style = Tema.texto.cuerpo,
                        // El rol `placeholder` de los tokens no llega a AA; ver la nota
                        // de `EsquemaColor.placeholder`. Acá se usa el rol, no el token.
                        color = Tema.color.placeholder,
                    )
                }
                BasicTextField(
                    value = valor,
                    onValueChange = onCambio,
                    enabled = habilitado,
                    singleLine = true,
                    textStyle = Tema.texto.cuerpo.copy(color = Tema.color.textoPrimario),
                    cursorBrush = SolidColor(Tema.color.acento),
                    visualTransformation = if (enmascarada) {
                        PasswordVisualTransformation()
                    } else {
                        VisualTransformation.None
                    },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = when {
                            esContrasena -> KeyboardType.Password
                            esCorreo -> KeyboardType.Email
                            esDecimal -> KeyboardType.Decimal
                            else -> KeyboardType.Text
                        },
                        imeAction = if (esUltimo) ImeAction.Done else ImeAction.Next,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics { contentDescription = etiqueta },
                )
            }
            if (accion != null) {
                Box(modifier = Modifier.padding(start = Tema.aire.e8)) { accion() }
            }
        }
        if (error != null) {
            Text(text = error, style = Tema.texto.nota, color = Tema.color.error)
        } else if (ayuda != null) {
            Text(text = ayuda, style = Tema.texto.nota, color = Tema.color.textoTerciario)
        }
    }
}
