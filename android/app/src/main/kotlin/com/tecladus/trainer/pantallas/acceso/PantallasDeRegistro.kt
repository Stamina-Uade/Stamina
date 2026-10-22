package com.tecladus.trainer.pantallas.acceso

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.CampoDeTexto
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.tema.Tema
import kotlinx.coroutines.delay

/**
 * Los pasos del registro. Son `regEmail`, `regCode` y —el que falta en el diseño—
 * la contraseña.
 *
 * 🛑 **El diseño tiene un hueco acá.** Los trece pasos de `Trainer App.dc.html`
 * nunca piden una contraseña, y `POST /auth/register/complete` del contrato la
 * exige (`password`, mínimo 10 caracteres). Una de las dos cosas está mal y no la
 * decido yo. Mientras tanto hay una pantalla de contraseña escrita a mano, marcada
 * como hueco en la propia pantalla, para que el registro se pueda terminar contra
 * el servidor de verdad. Está anotado en `docs/BLOQUEOS.md`.
 *
 * Los otros diez pasos —nacimiento, sexo, cuerpo, deporte, nivel,
 * objetivo, salud, medición, días, resumen— están en `PantallasDePerfil.kt`, y
 * corren **después** de que este archivo termine de crear la cuenta. Se puede
 * crear la cuenta sin ellos porque `PerfilEntrada` del contrato no tiene ningún
 * campo obligatorio; ver `docs/decisiones/0008`.
 */

/**
 * Contra cuántos pasos mide la barra de progreso.
 *
 * El diseño declara TRECE (`regEmail` … `regDone`). Son quince porque el registro
 * de verdad tiene dos pasos que el diseño no dibuja y que no se pueden saltear:
 * la contraseña, que `POST /auth/register/complete` exige, y el aviso de salud,
 * que pidió Iván. Contarlos como 13 haría que la barra llegue al final con dos
 * pantallas todavía por delante, que es la única forma de que una barra de
 * progreso moleste más que no tenerla.
 *
 * 🛑 Los cinco primeros están acá y los diez restantes en `PantallasDePerfil.kt`,
 * pero la barra es UNA sola y no se reinicia al crear la cuenta: el número del 6 al
 * 15 lo pone [PasoDePerfil.pasoDelRegistro], contra este mismo total.
 */
const val PASOS_DEL_REGISTRO = 15

/**
 * El molde de un paso: el título y el cuerpo scrollean, el botón queda abajo.
 *
 * Lo usan los TRES flujos —el registro, las once de perfil y las cuatro de
 * recuperar la contraseña—, y sigue llamándose así por el primero.
 *
 * Es un molde y no tres copias porque el detalle importa: con el teclado abierto en
 * un teléfono chico, si todo scrollea junto el botón se va de la vista y parece que
 * la pantalla no tiene salida. Y `Modifier.weight` adentro de un `verticalScroll`
 * no es una fealdad sino un crash: el scroll mide con alto infinito.
 */
@Composable
internal fun PasoDeRegistro(
    modifier: Modifier = Modifier,
    arriba: @Composable ColumnScope.() -> Unit,
    abajo: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = Tema.aire.e26)
            .padding(bottom = Tema.aire.e26),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e14),
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(Tema.aire.e14),
            content = arriba,
        )
        abajo()
    }
}

@Composable
internal fun TituloYCuerpo(titulo: String, cuerpo: String) {
    Text(text = titulo, style = Tema.texto.tituloPantalla, color = Tema.color.textoPrimario)
    Text(text = cuerpo, style = Tema.texto.cuerpo, color = Tema.color.textoSecundario)
}

// ------------------------------------------------------------------ paso 1

@Composable
fun PantallaRegistroNombre(
    nombre: String,
    apellido: String,
    onNombre: (String) -> Unit,
    onApellido: (String) -> Unit,
    onSeguir: () -> Unit,
) {
    PasoDeRegistro(
        arriba = {
            TituloYCuerpo(
                titulo = stringResource(R.string.reg_nombre_titulo),
                cuerpo = stringResource(R.string.reg_nombre_cuerpo),
            )
            CampoDeTexto(
                valor = nombre, onCambio = { onNombre(it.take(LARGO_MAXIMO_DEL_NOMBRE)) },
                etiqueta = stringResource(R.string.perf_nombre_campo),
                marcador = stringResource(R.string.perf_nombre_pista),
            )
            CampoDeTexto(
                valor = apellido, onCambio = { onApellido(it.take(LARGO_MAXIMO_DEL_NOMBRE)) },
                etiqueta = stringResource(R.string.perf_apellido_campo),
                marcador = stringResource(R.string.perf_apellido_pista), esUltimo = true,
            )
        },
        abajo = {
            BotonPrimario(
                titulo = stringResource(R.string.reg_nombre_seguir), onClick = onSeguir,
                modifier = Modifier.fillMaxWidth(),
                habilitado = nombre.isNotBlank() && apellido.isNotBlank(),
            )
        },
    )
}

// ------------------------------------------------------------------ paso 2

/**
 * Paso 1: el correo. Dispara `POST /auth/register`, que manda el código.
 *
 * El chequeo del correo es a propósito flojo —que tenga arroba y un punto después—
 * y no una expresión regular de las que se copian de internet. La validación de
 * verdad la hace el servidor, y la de acá sólo existe para no gastar un pedido y
 * un minuto de espera en un `mail@gmial` con un dedo de más. Rechazar de más en el
 * teléfono deja gente afuera con direcciones válidas y raras.
 */
@Composable
fun PantallaRegistroCorreo(
    correo: String,
    onCorreo: (String) -> Unit,
    enCurso: Boolean,
    error: String?,
    onEnviar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val chequeo = recordarChequeoDeCorreo()
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            TituloYCuerpo(
                titulo = stringResource(R.string.reg_correo_titulo),
                cuerpo = stringResource(R.string.reg_correo_cuerpo),
            )
            CampoDeTexto(
                valor = correo,
                onCambio = {
                    chequeo.alEditar()
                    onCorreo(it)
                },
                etiqueta = stringResource(R.string.reg_correo_campo),
                etiquetaVisible = false,
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
            Text(
                text = stringResource(R.string.reg_correo_legal),
                style = Tema.texto.nota,
                color = Tema.color.textoTerciario,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            BotonPrimario(
                titulo = stringResource(R.string.reg_correo_enviar),
                // El formato se mira recién acá, no mientras se escribe: ver
                // [ChequeoDeCorreo]. Por eso alcanza con que haya texto.
                onClick = { if (chequeo.alTocar(correo)) onEnviar() },
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && correo.isNotBlank(),
            )
        },
    )
}

// ------------------------------------------------------------------ paso 2

/**
 * Paso 2: el código. Dispara `POST /auth/register/verify`.
 *
 * El "Reenviar en 0:42" del diseño es un número dibujado; acá cuenta de verdad,
 * porque si no cuenta lo único que hace es mentir. Los segundos salen de
 * [SEGUNDOS_PARA_REENVIAR], que es lo que el servidor tarda en aceptar otro pedido
 * (abajo de eso contesta `code_resend_too_soon`).
 */
@Composable
fun PantallaRegistroCodigo(
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
                titulo = stringResource(R.string.reg_codigo_titulo),
                cuerpo = stringResource(R.string.reg_codigo_cuerpo, correo),
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
                titulo = stringResource(R.string.reg_codigo_validar),
                onClick = onValidar,
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && codigo.length == LARGO_DEL_CODIGO,
            )
        },
    )
}

// ------------------------------------------------------------------ paso 3

/**
 * Paso 3: la contraseña. Dispara `POST /auth/register/complete` y termina con una
 * sesión de verdad.
 *
 * 🛑 Esta pantalla NO está en el diseño; ver la nota del encabezado del archivo. Lo
 * dice también en la pantalla, para que quien la mire no crea que es parte del
 * flujo dibujado.
 *
 * El largo mínimo se chequea acá para no gastar un viaje, pero la decisión es del
 * servidor: si no cumple sus reglas contesta `weak_password` y eso se muestra tal
 * como viene traducido.
 */
@Composable
fun PantallaRegistroClave(
    clave: String,
    onClave: (String) -> Unit,
    repetida: String,
    onRepetida: (String) -> Unit,
    enCurso: Boolean,
    error: String?,
    onCrear: () -> Unit,
    modifier: Modifier = Modifier,
) {
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            TituloYCuerpo(
                titulo = stringResource(R.string.reg_clave_titulo),
                cuerpo = stringResource(R.string.reg_clave_cuerpo, LARGO_MINIMO_DE_CLAVE),
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
                titulo = stringResource(R.string.reg_clave_crear),
                onClick = onCrear,
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && claveCompleta(clave) && repetida == clave,
            )
        },
    )
}

// ------------------------------------------------------------------ utilería

/**
 * Cuenta regresiva para poder pedir otro código. Devuelve los segundos que faltan.
 *
 * Vive acá y no en cada pantalla porque el registro tiene dos lugares que la usan
 * —pedir el código y reenviarlo— y tienen que compartir el mismo reloj.
 *
 * 🛑 Cuenta tiempo de composición, no tiempo del reloj del sistema: si la app se va
 * a segundo plano, la cuenta se congela y al volver marca de más. Es lo mismo que
 * le pasa al descanso del gimnasio y se arregla en el mismo lugar (fase 8). Acá
 * molesta poco porque el peor caso es ofrecer "Reenviar" tarde, no temprano.
 */
@Composable
fun recordarCuentaRegresiva(reiniciarCon: Any?): Int {
    var segundos by remember(reiniciarCon) { mutableIntStateOf(SEGUNDOS_PARA_REENVIAR) }
    LaunchedEffect(reiniciarCon, segundos) {
        if (segundos > 0) {
            delay(MILISEGUNDOS_POR_SEGUNDO)
            segundos -= 1
        }
    }
    return segundos
}

/** "0:42". Con dos dígitos en los segundos, siempre. */
fun minutosYSegundos(total: Int): String {
    val m = total / SEGUNDOS_POR_MINUTO
    val s = total % SEGUNDOS_POR_MINUTO
    return "$m:" + s.toString().padStart(2, '0')
}

/**
 * Un chequeo mínimo: hay algo, un arroba, algo, un punto y algo. Nada más.
 * La validación de verdad es del servidor.
 */
fun pareceCorreo(texto: String): Boolean {
    val t = texto.trim()
    if (t.any { it.isWhitespace() }) return false
    val arroba = t.indexOf('@')
    if (arroba <= 0 || arroba != t.lastIndexOf('@')) return false
    val dominio = t.substring(arroba + 1)
    val punto = dominio.indexOf('.')
    return punto > 0 && punto < dominio.length - 1
}

/**
 * Cuándo se mira [pareceCorreo]: al tocar el botón, no mientras se escribe.
 *
 * Un error que aparece con la primera letra reta a la persona por algo que todavía
 * no terminó de escribir, y un botón apagado hasta que el texto "parece" un correo
 * hace sentir lento al teléfono. Así que mientras se escribe no hay mensaje —ni
 * error ni ayuda—, el botón se prende apenas hay texto, y el formato se mira
 * recién al tocarlo. Si no pasa, el error queda debajo del campo, no se manda nada,
 * el foco no se mueve y TalkBack lo anuncia (ver [recordarChequeoDeCorreo]); si
 * pasa, la pantalla sigue como siempre. El error se va con la primera edición,
 * porque ya no es el correo que se rechazó.
 *
 * Lo usan las tres pantallas que piden un correo —el registro, recuperar la
 * contraseña y el login— para que las tres se porten igual. Es una clase y no un
 * `remember` suelto en cada una para que la regla se pruebe en la JVM
 * (`ChequeoDeCorreoTest`).
 */
@Stable
internal class ChequeoDeCorreo {
    /** El formato no pasó al tocar el botón, y el campo no se editó desde entonces. */
    var rechazado by mutableStateOf(false)
        private set

    /** Cada edición borra el error. */
    fun alEditar() {
        rechazado = false
    }

    /** Mira el formato al tocar el botón. Devuelve si se puede seguir. */
    fun alTocar(correo: String): Boolean {
        rechazado = !pareceCorreo(correo)
        return !rechazado
    }
}

/**
 * Un [ChequeoDeCorreo] que dura lo que dura la pantalla, y que le avisa a TalkBack
 * cuando rechaza el correo.
 *
 * El aviso hace falta porque el foco del lector de pantalla se queda en el botón que
 * se acaba de tocar y el error aparece en otro lado: sin anuncio, el toque no dice
 * nada. iOS hace lo mismo con `UIAccessibility.post(notification: .announcement)` y,
 * como iOS, anuncia cuando el error aparece, no en cada toque. Va acá y no en cada
 * pantalla para que ninguna de las tres se lo pueda olvidar.
 *
 * 🪤 `announceForAccessibility` está obsoleto desde la API 36, que recomienda una
 * live region o el error puesto en el nodo. No se usó ninguno de los dos porque en
 * Compose 1.10.4 `AndroidComposeViewAccessibilityDelegateCompat` sólo los copia al
 * `AccessibilityNodeInfo` y no manda ningún evento propio cuando aparecen (se miró
 * el bytecode): que TalkBack los lea depende de cómo interprete un cambio genérico
 * del árbol, y el emulador con el que se probó (API 33 con Play Store) no trae
 * TalkBack. El anuncio sí se prueba: `AnuncioDelCorreoRechazadoTest` espera el evento.
 */
@Suppress("DEPRECATION")
@Composable
internal fun recordarChequeoDeCorreo(): ChequeoDeCorreo {
    val chequeo = remember { ChequeoDeCorreo() }
    val vista = LocalView.current
    val aviso = stringResource(R.string.reg_correo_mal)
    LaunchedEffect(chequeo.rechazado) {
        if (chequeo.rechazado) vista.announceForAccessibility(aviso)
    }
    return chequeo
}

/**
 * Lo que el servidor espera antes de aceptar otro pedido de código. Sale de
 * `backend/src/dominios/auth/servicio.ts` (`REENVIO_MS`): abajo de esto contesta
 * `code_resend_too_soon`. `scripts/test/entorno-local.test.mjs` ata los dos.
 */
const val SEGUNDOS_PARA_REENVIAR = 60

private const val SEGUNDOS_POR_MINUTO = 60
private const val MILISEGUNDOS_POR_SEGUNDO = 1000L
