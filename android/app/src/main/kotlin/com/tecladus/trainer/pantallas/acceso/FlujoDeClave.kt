package com.tecladus.trainer.pantallas.acceso

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.BotonVolver
import com.tecladus.trainer.core.ds.CampoDeTexto
import com.tecladus.trainer.core.ds.Card
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.Resultado
import com.tecladus.trainer.core.red.Sesion
import com.tecladus.trainer.core.tema.Tema
import kotlinx.coroutines.launch
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Recuperar la contraseña: `fpEmail`, `fpCode`, `fpNew` y `fpDone` de
 * `design/origen/Trainer App.dc.html`.
 *
 * Los cuatro pasos son los tres endpoints del contrato más la confirmación:
 * `POST /auth/password/forgot`, `/verify` y `/reset`.
 *
 * 🛑 **La pantalla del correo no puede decir si esa cuenta existe.** El servidor
 * contesta 202 exista o no, con el mismo costo de tiempo, para que nadie use este
 * formulario como un buscador de direcciones registradas. Por eso el texto dice
 * "si esa dirección tiene cuenta" y no "te mandamos el código", y por eso el paso
 * siguiente se muestra igual: si dijéramos la verdad sólo cuando existe, el
 * silencio del otro caso sería la respuesta.
 *
 * 🛑 **`fpNew` no tiene pantalla propia**: usa [CamposDeClave], que es el mismo
 * control del alta. El diseño dibuja los dos iguales a propósito, y las tres
 * reglas que muestra son las de [REGLAS_DE_CLAVE], las mismas que aplica el
 * servidor.
 *
 * 🛑 Cambiar la contraseña devuelve una sesión nueva (desde la 1.6.0 ya NO cierra
 * las demás sesiones). Se usa: `fpDone` entra derecho a la app. El
 * diseño manda al login, y eso sería pedirle a alguien que tipee la contraseña
 * que acaba de elegir treinta segundos antes. Está anotado como desvío.
 */
@Composable
fun FlujoDeClave(
    api: ApiTrainer,
    correoInicial: String,
    onEntro: (Sesion) -> Unit,
    onVolverAlLogin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var paso by remember { mutableStateOf(PasoDeClave.CORREO) }
    var correo by remember { mutableStateOf(correoInicial) }
    var codigo by remember { mutableStateOf("") }
    var clave by remember { mutableStateOf("") }
    var claveRepetida by remember { mutableStateOf("") }
    var tokenDeReseteo by remember { mutableStateOf<String?>(null) }
    var sesion by remember { mutableStateOf<Sesion?>(null) }
    var enCurso by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var pedidosDeCodigo by remember { mutableStateOf(0) }

    val alcance = rememberCoroutineScope()
    val traducir = recordarTraductorDeErrores()
    val segundosParaReenviar = recordarCuentaRegresiva(pedidosDeCodigo)
    val etiquetaVolver = stringResource(R.string.fp_volver)

    fun volverA(destino: PasoDeClave) {
        error = null
        paso = destino
    }

    fun pedirCodigo() {
        enCurso = true
        error = null
        alcance.launch {
            when (val r = api.pedirCodigoDeClave(correo.trim())) {
                is Resultado.Ok -> {
                    pedidosDeCodigo += 1
                    codigo = ""
                    paso = PasoDeClave.CODIGO
                }
                else -> error = traducir(r)
            }
            enCurso = false
        }
    }

    /** Entrar con la sesión que devolvió el cambio de contraseña. */
    fun entrarConLaNueva() {
        val abierta = sesion
        if (abierta != null) onEntro(abierta) else onVolverAlLogin()
    }

    // 🛑 El handler se queda SIEMPRE prendido. Apagarlo no es "el atrás no hace
    // nada": deja pasar el evento al sistema, que cierra la app. En `fpDone` eso
    // tiraría la sesión que el servidor acaba de devolver, con la contraseña ya
    // cambiada, y habría que entrar de nuevo a mano.
    BackHandler {
        if (enCurso) return@BackHandler
        when (paso) {
            PasoDeClave.CORREO -> onVolverAlLogin()
            PasoDeClave.CODIGO -> volverA(PasoDeClave.CORREO)
            PasoDeClave.NUEVA -> volverA(PasoDeClave.CODIGO)
            PasoDeClave.LISTA -> entrarConLaNueva()
        }
    }

    Column(modifier = modifier.fillMaxSize()) {
        if (paso != PasoDeClave.LISTA) {
            Row(modifier = Modifier.padding(horizontal = Tema.aire.e14, vertical = Tema.aire.e6)) {
                BotonVolver(
                    etiqueta = etiquetaVolver,
                    onClick = {
                        when (paso) {
                            PasoDeClave.CORREO -> onVolverAlLogin()
                            PasoDeClave.CODIGO -> volverA(PasoDeClave.CORREO)
                            PasoDeClave.NUEVA -> volverA(PasoDeClave.CODIGO)
                            PasoDeClave.LISTA -> Unit
                        }
                    },
                )
            }
        }

        when (paso) {
            PasoDeClave.CORREO -> PantallaClaveCorreo(
                correo = correo,
                onCorreo = { correo = it; error = null },
                enCurso = enCurso,
                error = error,
                onEnviar = { pedirCodigo() },
                onVolverAlLogin = onVolverAlLogin,
            )

            PasoDeClave.CODIGO -> PantallaClaveCodigo(
                correo = correo.trim(),
                codigo = codigo,
                onCodigo = { codigo = it; error = null },
                enCurso = enCurso,
                error = error,
                segundosParaReenviar = segundosParaReenviar,
                onReenviar = { pedirCodigo() },
                onCambiarCorreo = { volverA(PasoDeClave.CORREO) },
                onValidar = {
                    enCurso = true
                    error = null
                    alcance.launch {
                        when (val r = api.verificarCodigoDeClave(correo.trim(), codigo)) {
                            is Resultado.Ok -> {
                                tokenDeReseteo = r.dato.resetToken
                                clave = ""
                                claveRepetida = ""
                                paso = PasoDeClave.NUEVA
                            }
                            else -> error = traducir(r)
                        }
                        enCurso = false
                    }
                },
            )

            PasoDeClave.NUEVA -> PantallaClaveNueva(
                clave = clave,
                onClave = { clave = it; error = null },
                repetida = claveRepetida,
                onRepetida = { claveRepetida = it; error = null },
                enCurso = enCurso,
                error = error,
                onGuardar = {
                    val token = tokenDeReseteo
                    if (token == null) {
                        // No debería poder pasar: a este paso se llega con el token
                        // del paso 2. Si pasa, se vuelve al principio en vez de
                        // mandar un pedido que no puede andar.
                        volverA(PasoDeClave.CORREO)
                    } else {
                        enCurso = true
                        error = null
                        alcance.launch {
                            when (val r = api.cambiarClave(token, clave)) {
                                is Resultado.Ok -> {
                                    sesion = r.dato
                                    // 🛑 El token se consumió y no sirve para otro
                                    // intento: se suelta acá para que no quede en
                                    // memoria más de lo necesario (§8).
                                    tokenDeReseteo = null
                                    clave = ""
                                    claveRepetida = ""
                                    paso = PasoDeClave.LISTA
                                }
                                else -> error = traducir(r)
                            }
                            enCurso = false
                        }
                    }
                },
            )

            PasoDeClave.LISTA -> PantallaClaveLista(
                correo = correo.trim(),
                onEntrar = { entrarConLaNueva() },
            )
        }
    }
}

/** Dónde está parado el flujo de recuperar la contraseña. */
private enum class PasoDeClave { CORREO, CODIGO, NUEVA, LISTA }

// ------------------------------------------------------------------ fpEmail

@Composable
private fun PantallaClaveCorreo(
    correo: String,
    onCorreo: (String) -> Unit,
    enCurso: Boolean,
    error: String?,
    onEnviar: () -> Unit,
    onVolverAlLogin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val chequeo = recordarChequeoDeCorreo()
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            TituloYCuerpo(
                titulo = stringResource(R.string.fp_correo_titulo),
                cuerpo = stringResource(R.string.fp_correo_cuerpo),
            )
            CampoDeTexto(
                valor = correo,
                onCambio = {
                    chequeo.alEditar()
                    onCorreo(it)
                },
                etiqueta = stringResource(R.string.fp_correo_campo),
                marcador = stringResource(R.string.login_correo_pista),
                error = error ?: if (chequeo.rechazado) {
                    stringResource(R.string.reg_correo_mal)
                } else {
                    null
                },
                esCorreo = true,
                esUltimo = true,
                habilitado = !enCurso,
            )
        },
        abajo = {
            // 🛑 Esta línea NO es un detalle de estilo: es lo que hace honesta a la
            // pantalla. El servidor contesta lo mismo exista o no la cuenta, y si
            // acá dijéramos "te lo mandamos" estaríamos afirmando algo que no
            // sabemos. Ver el encabezado del archivo.
            Text(
                text = stringResource(R.string.fp_correo_anti_enumeracion),
                style = Tema.texto.nota,
                color = Tema.color.textoTerciario,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            BotonPrimario(
                titulo = stringResource(R.string.fp_correo_enviar),
                // El formato se mira recién acá, no mientras se escribe: ver
                // [ChequeoDeCorreo]. Por eso alcanza con que haya texto.
                onClick = { if (chequeo.alTocar(correo)) onEnviar() },
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && correo.isNotBlank(),
            )
            BotonDeTexto(
                texto = stringResource(R.string.fp_correo_volver),
                onClick = onVolverAlLogin,
                enfasis = false,
                modifier = Modifier.fillMaxWidth(),
            )
        },
    )
}

// ------------------------------------------------------------------- fpCode

@Composable
private fun PantallaClaveCodigo(
    correo: String,
    codigo: String,
    onCodigo: (String) -> Unit,
    enCurso: Boolean,
    error: String?,
    segundosParaReenviar: Int,
    onReenviar: () -> Unit,
    onCambiarCorreo: () -> Unit,
    onValidar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            TituloYCuerpo(
                titulo = stringResource(R.string.fp_codigo_titulo),
                cuerpo = stringResource(R.string.fp_codigo_cuerpo, correo),
            )
            CampoDeCodigo(valor = codigo, onCambio = onCodigo, habilitado = !enCurso)
            if (error != null) {
                Nota(texto = error, icono = { c, m -> Iconos.Aviso(c, m) }, tono = Tema.color.error)
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                BotonDeTexto(
                    texto = stringResource(R.string.reg_codigo_cambiar),
                    onClick = onCambiarCorreo,
                    enfasis = false,
                )
                if (segundosParaReenviar > 0) {
                    Text(
                        text = stringResource(
                            R.string.reg_codigo_reenviar,
                            minutosYSegundos(segundosParaReenviar),
                        ),
                        style = Tema.texto.cuerpoSecundario,
                        color = Tema.color.textoTerciario,
                        modifier = Modifier.padding(horizontal = Tema.aire.e8),
                    )
                } else {
                    BotonDeTexto(
                        texto = stringResource(R.string.reg_codigo_reenviar_ya),
                        onClick = onReenviar,
                    )
                }
            }
        },
        abajo = {
            BotonPrimario(
                titulo = stringResource(R.string.fp_codigo_validar),
                onClick = onValidar,
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && codigo.length == LARGO_DEL_CODIGO,
            )
        },
    )
}

// -------------------------------------------------------------------- fpNew

@Composable
private fun PantallaClaveNueva(
    clave: String,
    onClave: (String) -> Unit,
    repetida: String,
    onRepetida: (String) -> Unit,
    enCurso: Boolean,
    error: String?,
    onGuardar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            TituloYCuerpo(
                titulo = stringResource(R.string.fp_clave_titulo),
                cuerpo = stringResource(R.string.fp_clave_cuerpo, LARGO_MINIMO_DE_CLAVE),
            )
            CamposDeClave(
                clave = clave,
                onClave = onClave,
                repetida = repetida,
                onRepetida = onRepetida,
                habilitado = !enCurso,
            )
            if (error != null) {
                Nota(
                    texto = error,
                    icono = { c, m -> Iconos.Aviso(c, m) },
                    tono = Tema.color.error,
                    estilo = Tema.texto.cuerpo,
                )
            }
        },
        abajo = {
            BotonPrimario(
                titulo = stringResource(R.string.fp_clave_guardar),
                onClick = onGuardar,
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && claveCompleta(clave) && repetida == clave,
            )
        },
    )
}

// ------------------------------------------------------------------- fpDone

/**
 * La confirmación.
 *
 * La hora que muestra es la del teléfono en el momento de dibujarla. El diseño
 * pone "Hoy, 8:24" fijo; acá es la de verdad, porque una constancia con una hora
 * inventada es peor que no tener constancia.
 */
@Composable
private fun PantallaClaveLista(
    correo: String,
    onEntrar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val idioma = LocalContext.current.resources.configuration.locales[0]
    val hora = remember(idioma) {
        LocalTime.now().format(
            DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(idioma),
        )
    }
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            // El cuadrado de acento del diseño. Es decoración y no dice nada que el
            // título no diga, así que no lleva semántica.
            Box(
                modifier = Modifier
                    .size(Tema.aire.e52)
                    .background(Tema.color.acento, Tema.forma.cardDestacada),
            )
            TituloYCuerpo(
                titulo = stringResource(R.string.fp_listo_titulo),
                cuerpo = stringResource(R.string.fp_listo_cuerpo),
            )
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e9)) {
                    FilaDeConstancia(stringResource(R.string.fp_listo_cuenta), correo)
                    FilaDeConstancia(
                        stringResource(R.string.fp_listo_cuando),
                        stringResource(R.string.fp_listo_hoy, hora),
                    )
                }
            }
        },
        abajo = {
            BotonPrimario(
                titulo = stringResource(R.string.fp_listo_entrar),
                onClick = onEntrar,
                modifier = Modifier.fillMaxWidth(),
            )
        },
    )
}

@Composable
private fun FilaDeConstancia(rotulo: String, valor: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Tema.aire.e10),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = rotulo,
            style = Tema.texto.cuerpoSecundario,
            color = Tema.color.textoSecundario,
        )
        Box(modifier = Modifier.weight(1f))
        Text(
            text = valor,
            style = Tema.texto.valorFila,
            color = Tema.color.textoPrimario,
            textAlign = TextAlign.End,
        )
    }
}
