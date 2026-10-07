package com.tecladus.trainer.pantallas.acceso

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.BotonSecundario
import com.tecladus.trainer.core.ds.BotonVolver
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.ds.CampoDeTexto
import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.Resultado
import com.tecladus.trainer.core.red.Sesion
import com.tecladus.trainer.core.tema.Tema
import kotlinx.coroutines.launch

/**
 * Entrar con correo y contraseña. Es `is.login` del diseño canónico, y habla con
 * `POST /auth/login` del contrato.
 *
 * 🛑 **Google y Apple no andan y por eso lo dicen.** El diseño los dibuja, pero el
 * contrato (`shared/api/openapi.yaml`) no tiene ningún camino de OAuth: todas las
 * rutas de `/auth` son de correo y contraseña. Los botones quedan a la vista porque el
 * diseño los pide, y al tocarlos aparece una línea que dice que todavía no. Un
 * botón que no hace nada y tampoco lo dice es peor que no tenerlo.
 *
 * **Recuperar la contraseña ya está**: `¿Olvidaste tu contraseña?` abre
 * [FlujoDeClave] con el correo que ya se escribió acá, si se escribió alguno.
 */
@Composable
fun PantallaLogin(
    api: ApiTrainer,
    onEntro: (Sesion) -> Unit,
    onVolver: () -> Unit,
    onRegistrarse: () -> Unit,
    /** Recibe el correo ya escrito, para no pedirlo dos veces. Puede venir vacío. */
    onOlvideLaClave: (String) -> Unit,
    modifier: Modifier = Modifier,
    /**
     * Lo que hay que explicar cuando se llega acá de rebote y no por elección —la
     * sesión se venció en la mitad del perfil, por ejemplo. Sin esto, la pantalla
     * de login aparece sola y parece que la app se reinició.
     */
    avisoInicial: String? = null,
) {
    var email by remember { mutableStateOf("") }
    var contrasena by remember { mutableStateOf("") }
    var enCurso by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var aviso by remember(avisoInicial) { mutableStateOf(avisoInicial) }
    val chequeo = recordarChequeoDeCorreo()
    val alcance = rememberCoroutineScope()
    val traducir = recordarTraductorDeErrores()

    val faltaSocial = stringResource(R.string.login_social_falta)
    val etiquetaVolver = stringResource(R.string.login_volver)

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Tema.aire.e26)
            .padding(bottom = Tema.aire.e26),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e20),
    ) {
        BotonVolver(etiqueta = etiquetaVolver, onClick = onVolver)

        Text(
            text = stringResource(R.string.login_titulo),
            style = Tema.texto.tituloBienvenida,
            color = Tema.color.textoPrimario,
        )

        Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e13)) {
            CampoDeTexto(
                valor = email,
                onCambio = { email = it; error = null; chequeo.alEditar() },
                etiqueta = stringResource(R.string.login_correo),
                marcador = stringResource(R.string.login_correo_pista),
                error = if (chequeo.rechazado) stringResource(R.string.reg_correo_mal) else null,
                esCorreo = true,
                habilitado = !enCurso,
            )
            CampoDeTexto(
                valor = contrasena,
                onCambio = { contrasena = it; error = null },
                etiqueta = stringResource(R.string.login_clave),
                esContrasena = true,
                esUltimo = true,
                habilitado = !enCurso,
            )
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
                BotonDeTexto(
                    texto = stringResource(R.string.login_olvide),
                    onClick = { onOlvideLaClave(email.trim()) },
                    enfasis = false,
                )
            }

            error?.let {
                Nota(
                    texto = it,
                    icono = { c, m -> Iconos.Aviso(c, m) },
                    tono = Tema.color.error,
                    estilo = Tema.texto.cuerpo,
                )
            }
            aviso?.let {
                Nota(texto = it, icono = { c, m -> Iconos.Aviso(c, m) })
            }

            BotonPrimario(
                titulo = stringResource(R.string.login_entrar),
                onClick = {
                    // El formato se mira recién acá, igual que en el registro: si no
                    // pasa, el error queda debajo del campo y no se manda nada.
                    if (!chequeo.alTocar(email)) return@BotonPrimario
                    enCurso = true
                    error = null
                    aviso = null
                    alcance.launch {
                        val r = api.entrar(email.trim(), contrasena)
                        enCurso = false
                        when (r) {
                            is Resultado.Ok -> onEntro(r.dato)
                            else -> error = traducir(r)
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && email.isNotBlank() && contrasena.isNotBlank(),
            )
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Tema.aire.e12),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(Tema.aire.e1)
                    .background(Tema.color.divisor),
            )
            Text(
                text = stringResource(R.string.login_o),
                style = Tema.texto.nota,
                color = Tema.color.textoTerciario,
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(Tema.aire.e1)
                    .background(Tema.color.divisor),
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e10)) {
            BotonSecundario(
                texto = stringResource(R.string.login_google),
                onClick = { aviso = faltaSocial },
                modifier = Modifier.fillMaxWidth(),
            )
            BotonSecundario(
                texto = stringResource(R.string.login_apple),
                onClick = { aviso = faltaSocial },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.login_no_tengo),
                style = Tema.texto.cuerpoSecundario,
                color = Tema.color.textoSecundario,
                textAlign = TextAlign.Center,
            )
            BotonDeTexto(
                texto = stringResource(R.string.login_registrate),
                onClick = onRegistrarse,
            )
        }
    }
}
