package com.tecladus.trainer.pantallas.acceso

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.red.Resultado
import com.tecladus.trainer.core.tema.Tema

/**
 * Lo que comparten las pantallas de acceso: la traducción de errores y el campo
 * del código.
 */

/**
 * Convierte un [Resultado] que salió mal en una frase que se le puede mostrar a
 * una persona.
 *
 * 🛑 Traduce el `codigo` del contrato, NUNCA el `mensaje` (AGENTS.md §5). El
 * mensaje del servidor está escrito para el log de quien programa: puede traer la
 * ruta, un id, o el nombre de una tabla, y ninguna de las tres cosas tiene por qué
 * terminar en la pantalla de alguien.
 *
 * Si aparece un código que no está en la lista, lo muestra con su nombre técnico en
 * vez de tragárselo. Un error mudo cuesta más que uno feo: el que traduce el
 * contrato es este archivo, y si el servidor agregó un código, acá se ve.
 */
@Composable
fun recordarTraductorDeErrores(): (Resultado<*>) -> String {
    // Las frases se leen UNA vez por configuración y no en cada recomposición. Quien
    // llama es la pantalla que tiene el texto que se está escribiendo —el login, el
    // registro, recuperar la contraseña—, así que antes esto eran veinticuatro
    // lecturas de recursos, un mapa nuevo y la comparación del mapa entero con el
    // anterior POR TECLA. La configuración va de clave para que un cambio de idioma
    // las vuelva a leer, como las volvería a leer `stringResource`.
    val recursos = LocalResources.current
    val configuracion = LocalConfiguration.current
    return remember(recursos, configuracion) {
        val porCodigo = mapOf(
            "invalid_credentials" to recursos.getString(R.string.error_invalid_credentials),
            "email_taken" to recursos.getString(R.string.error_email_taken),
            "rate_limited" to recursos.getString(R.string.error_rate_limited),
            "validation_failed" to recursos.getString(R.string.error_validation_failed),
            "unauthorized" to recursos.getString(R.string.error_unauthorized),
            "code_resend_too_soon" to recursos.getString(R.string.error_code_resend_too_soon),
            "invalid_code" to recursos.getString(R.string.error_invalid_code),
            "code_expired" to recursos.getString(R.string.error_code_expired),
            "weak_password" to
                recursos.getString(R.string.error_weak_password, LARGO_MINIMO_DE_CLAVE),
            "invalid_registration_token" to
                recursos.getString(R.string.error_invalid_registration_token),
            "invalid_reset_token" to recursos.getString(R.string.error_invalid_reset_token),
            "bad_request" to recursos.getString(R.string.error_bad_request),
            "profile_incomplete" to recursos.getString(R.string.error_profile_incomplete),
            "service_unavailable" to recursos.getString(R.string.error_service_unavailable),
            "session_revoked" to recursos.getString(R.string.error_session_revoked),
            "invalid_refresh_token" to recursos.getString(R.string.error_invalid_refresh_token),
            "conflict" to recursos.getString(R.string.error_conflict),
            "internal" to recursos.getString(R.string.error_internal),
            "not_found" to recursos.getString(R.string.error_not_found),
            "legal_not_accepted" to recursos.getString(R.string.error_legal_not_accepted),
            "legal_version_stale" to recursos.getString(R.string.error_legal_version_stale),
            // 1.6.0. Android no usa las rutas nuevas (vincular, reactivar), así que
            // estos sólo se muestran: no hay paso siguiente desde acá.
            "too_many_attempts" to recursos.getString(R.string.error_too_many_attempts),
            "code_attempts_exceeded" to
                recursos.getString(R.string.error_code_attempts_exceeded),
            "account_link_available" to
                recursos.getString(R.string.error_account_link_available),
            "invalid_link_token" to recursos.getString(R.string.error_invalid_link_token),
            "account_deactivated" to recursos.getString(R.string.error_account_deactivated),
            "account_pending_deletion" to
                recursos.getString(R.string.error_account_pending_deletion),
            "invalid_reactivation_token" to
                recursos.getString(R.string.error_invalid_reactivation_token),
        )
        val sinRed = recursos.getString(R.string.error_sin_red)
        val raro = recursos.getString(R.string.error_respuesta_rara)
        val plantillaDesconocido = recursos.getString(R.string.error_desconocido)

        val traducir: (Resultado<*>) -> String = { r ->
            when (r) {
                is Resultado.Rechazado ->
                    porCodigo[r.codigo] ?: plantillaDesconocido.format(r.codigo)
                is Resultado.SinRed -> sinRed
                is Resultado.RespuestaRara -> raro
                is Resultado.Ok -> ""
            }
        }
        traducir
    }
}

/**
 * El campo del código de 6 caracteres.
 *
 * No es el [com.tecladus.trainer.core.ds.CampoDeTexto] con otro tamaño: el diseño
 * lo dibuja centrado, grande y con las letras separadas, porque un código que se
 * copia de un correo se lee de a caracteres y no como una palabra. Por eso está
 * escrito aparte en vez de agregarle cinco parámetros al campo común.
 *
 * Pasa a MAYÚSCULAS lo que se escriba y corta en [LARGO_DEL_CODIGO], así el código
 * `a7k2q9` que alguien copia en minúscula entra igual.
 */
@Composable
fun CampoDeCodigo(
    valor: String,
    onCambio: (String) -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    val etiqueta = stringResource(R.string.reg_codigo_campo)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = Tema.tactilMinimo)
            .background(Tema.color.superficieInput, Tema.forma.boton)
            .border(Tema.aire.e1, Tema.color.bordeInput, Tema.forma.boton)
            .padding(horizontal = Tema.aire.e10, vertical = Tema.aire.e14),
        contentAlignment = Alignment.Center,
    ) {
        if (valor.isEmpty()) {
            Text(
                text = stringResource(R.string.reg_codigo_pista),
                style = Tema.texto.codigo,
                color = Tema.color.placeholder,
                textAlign = TextAlign.Center,
            )
        }
        BasicTextField(
            value = valor,
            onValueChange = { nuevo ->
                onCambio(nuevo.uppercase().filter { it.isLetterOrDigit() }.take(LARGO_DEL_CODIGO))
            },
            enabled = habilitado,
            singleLine = true,
            textStyle = Tema.texto.codigo.copy(
                color = Tema.color.textoPrimario,
                textAlign = TextAlign.Center,
            ),
            cursorBrush = SolidColor(Tema.color.acento),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Text,
                capitalization = KeyboardCapitalization.Characters,
                imeAction = ImeAction.Done,
            ),
            modifier = Modifier
                .fillMaxWidth()
                .semantics { contentDescription = etiqueta },
        )
    }
}

/** Lo que el contrato dice que mide el código del correo. */
const val LARGO_DEL_CODIGO = 6
