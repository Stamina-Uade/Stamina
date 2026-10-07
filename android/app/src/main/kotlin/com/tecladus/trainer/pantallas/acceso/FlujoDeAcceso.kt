package com.tecladus.trainer.pantallas.acceso

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.activity.compose.BackHandler
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.EncabezadoDeRegistro
import com.tecladus.trainer.core.red.AceptacionLegal
import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.ObjetivoEntrada
import com.tecladus.trainer.core.red.Resultado
import com.tecladus.trainer.core.red.Sesion
import com.tecladus.trainer.core.red.TextosLegales
import kotlinx.coroutines.launch

/**
 * El flujo de acceso: bienvenida, login, recuperar la contraseña y los quince
 * pasos del alta.
 *
 * Es el `state.screen` de `design/origen/Trainer App.dc.html` traído a Compose. El
 * diseño lo resuelve con una lista de 22 pantallas y un índice; acá son un enum y
 * un `when`, que es lo mismo pero sin poder equivocarse de nombre.
 *
 * **Los quince pasos, y dónde se crea la cuenta:**
 *
 * ```
 *  1 nombre   2 correo   3 código   4 contraseña   5 aviso de salud   ← acá NACE la cuenta
 *  6 nacimiento   7 sexo   8 cuerpo   9 deporte   10 nivel
 * 11 objetivo   12 salud   13 medición   14 días   15 resumen  ← PATCH /me c/u
 * ```
 *
 * 🛑 **Los diez pasos restantes de perfil van DESPUÉS de crear la cuenta**, al revés que el
 * diseño. `docs/decisiones/0008-el-perfil-va-despues-de-crear-la-cuenta.md` tiene
 * el porqué completo; el resumen es que sin persistencia (fase 8) un alta de
 * quince pasos que se pierde entera en el paso catorce es peor que un perfil que
 * se completa de a pedazos. La barra de progreso **no** se reinicia en el paso 6:
 * para quien lo está usando esto es un solo trámite.
 *
 * 🛑 El estado del flujo vive en memoria. Si Android mata el proceso a mitad del
 * alta, se pierde el token del paso 2 y hay que empezar de nuevo desde el correo.
 * Del paso 5 en adelante ya no: la cuenta existe y la sesión quedó guardada
 * cifrada, así que al volver a abrir la app se entra derecho — con el perfil a
 * medias, porque en qué paso iba no se guarda. Lo que falte se completa después:
 * el contrato no exige ningún campo.
 *
 * 🛑 Ni el token de registro ni el de recuperación se escriben en ningún log
 * (AGENTS.md §8). Están en variables de composición y se van con ellas.
 */
@Composable
fun FlujoDeAcceso(
    api: ApiTrainer,
    onEntro: (Sesion) -> Unit,
    modifier: Modifier = Modifier,
    /**
     * Por qué se llega acá de rebote, ya traducido: la sesión se cerró sola —el
     * servidor dijo que no existe más— y hay que volver a entrar. Con esto el flujo
     * arranca en el login con el motivo a la vista; sin esto, en la bienvenida.
     */
    avisoInicial: String? = null,
) {
    var paso by remember {
        mutableStateOf(if (avisoInicial != null) PasoDeAcceso.LOGIN else PasoDeAcceso.BIENVENIDA)
    }
    var pasoDePerfil by remember { mutableStateOf(PasoDePerfil.NOMBRE) }
    var borrador by remember { mutableStateOf(BorradorDePerfil()) }
    var correo by remember { mutableStateOf("") }
    var codigo by remember { mutableStateOf("") }
    var clave by remember { mutableStateOf("") }
    var claveRepetida by remember { mutableStateOf("") }
    var tokenDeRegistro by remember { mutableStateOf<String?>(null) }
    var sesion by remember { mutableStateOf<Sesion?>(null) }
    var legales by remember { mutableStateOf<TextosLegales?>(null) }
    var aceptoElAviso by remember { mutableStateOf(false) }
    var enCurso by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    // Cambia cada vez que se pide un código: reinicia la cuenta regresiva.
    var pedidosDeCodigo by remember { mutableStateOf(0) }
    /**
     * La clave de idempotencia del guardado en curso (AGENTS.md §5.2).
     *
     * 🛑 Una por INTENTO, no por contenido. Se genera al arrancar un guardado y se
     * conserva mientras ese guardado se pueda reintentar, así que tocar "Continuar"
     * dos veces con mala señal escribe una sola vez. Se tira cuando sale bien,
     * cuando el borrador cambia y cuando se cambia de paso: si se derivara del
     * cuerpo, volver atrás y volver a elegir lo mismo de antes reusaría la clave
     * del primer intento, el servidor contestaría la respuesta vieja sin escribir
     * nada, y el perfil quedaría en un valor que la pantalla no muestra.
     */
    var claveDeGuardado by remember { mutableStateOf<String?>(null) }
    /** Se prende cuando el alta ya no puede terminar y lo que corresponde es entrar. */
    var ofrecerLogin by remember { mutableStateOf(false) }
    /** Lo que el login tiene que explicar cuando se llega ahí por un rebote. */
    var avisoParaElLogin by remember { mutableStateOf(avisoInicial) }

    val alcance = rememberCoroutineScope()
    val traducir = recordarTraductorDeErrores()
    val segundosParaReenviar = recordarCuentaRegresiva(pedidosDeCodigo)

    // La zona del teléfono, en formato IANA. Va con los días de entrenamiento: un
    // "18:30" sin zona no es una hora, y el aviso de preparación necesita las dos.
    val zonaHoraria = remember { java.util.TimeZone.getDefault().id }

    // El aviso de salud baja del servidor, no está empaquetado. Se pide una vez
    // al abrir el flujo para que ya esté cuando llegue el paso, y se vuelve a
    // pedir si el servidor dice que la versión quedó vieja.
    LaunchedEffect(Unit) {
        if (legales == null) {
            (api.textosLegales() as? Resultado.Ok)?.let { legales = it.dato }
        }
    }

    fun volverA(destino: PasoDeAcceso) {
        error = null
        paso = destino
    }

    /** Pide (o vuelve a pedir) el código del paso 1. */
    fun pedirCodigo(siguiente: PasoDeAcceso) {
        enCurso = true
        error = null
        alcance.launch {
            when (val r = api.pedirCodigoDeRegistro(correo.trim(), borrador.nombre.trim(), borrador.apellido.trim())) {
                is Resultado.Ok -> {
                    pedidosDeCodigo += 1
                    codigo = ""
                    paso = siguiente
                }
                else -> error = traducir(r)
            }
            enCurso = false
        }
    }

    /** Entrar a la app con la sesión que quedó abierta al crear la cuenta. */
    fun entrar() {
        val abierta = sesion
        if (abierta != null) {
            onEntro(abierta)
        } else {
            // No debería poder pasar: al perfil se llega con la sesión del paso 4.
            volverA(PasoDeAcceso.LOGIN)
        }
    }

    // A variables locales: `paso` y `pasoDePerfil` son propiedades delegadas
    // (`by remember`) y sobre esas Kotlin no hace smart cast.
    val enElPerfil = paso == PasoDeAcceso.REG_PERFIL
    val perfilActual = pasoDePerfil

    /**
     * De dónde se puede volver. En el perfil, del primer paso NO se vuelve: la
     * cuenta ya está creada y atrás no hay nada a lo que volver. En recuperar la
     * contraseña tampoco, porque ese flujo tiene su propia flecha y su propio
     * `BackHandler`; dos manejadores del botón físico pisándose es la forma de que
     * un "atrás" salte dos pantallas.
     */
    val puedeVolver = when {
        // 🛑 Con un pedido en el aire no se vuelve. Si no, la respuesta del paso 8
        // llega cuando la pantalla ya es la del 7 y el avance la tira al 9,
        // salteando justo la que se había querido corregir.
        enCurso -> false
        paso == PasoDeAcceso.BIENVENIDA -> false
        paso == PasoDeAcceso.RECUPERAR -> false
        enElPerfil -> perfilActual.anterior() != null
        else -> true
    }

    fun volverAtras() {
        if (enElPerfil) {
            perfilActual.anterior()?.let {
                error = null
                // Cambiar de paso cierra el intento de guardado del anterior.
                claveDeGuardado = null
                pasoDePerfil = it
            }
        } else {
            ofrecerLogin = false
            volverA(paso.anterior())
        }
    }

    /**
     * Guarda lo del paso y avanza. Si el servidor dice que no, **no avanza**: el
     * error queda a la vista y el botón vuelve a estar disponible para reintentar.
     * Quien no pueda pasar de ahí tiene "Completar después", que entra a la app con
     * lo que sí se guardó — el contrato no exige ningún campo del perfil.
     */
    fun guardarYSeguir() {
        val actual = perfilActual
        val siguiente = actual.siguiente()
        val aGuardar = borrador.loQueGuarda(actual, zonaHoraria)
        if (aGuardar == null) {
            error = null
            claveDeGuardado = null
            if (siguiente == null) entrar() else pasoDePerfil = siguiente
            return
        }
        val clave = claveDeGuardado
            ?: java.util.UUID.randomUUID().toString().also { claveDeGuardado = it }
        enCurso = true
        error = null
        alcance.launch {
            val r = api.guardarPerfil(aGuardar, clave, borrador.camposEnNull(actual))
            if (r is Resultado.Ok && actual == PasoDePerfil.OBJETIVO) {
                val elegidos = listOfNotNull(borrador.objetivo) + borrador.objetivosAdicionales
                val guardados = api.guardarObjetivos(elegidos.mapIndexed { indice, objetivo ->
                    ObjetivoEntrada(
                        id = if (indice == 0) "principal" else null,
                        goal = objetivo,
                        goalDateMs = if (indice == 0) borrador.fechaDelObjetivo?.aEpocaMs() else null,
                    )
                })
                if (guardados !is Resultado.Ok) {
                    enCurso = false
                    if (pasoDePerfil == actual) error = traducir(guardados)
                    return@launch
                }
            }
            enCurso = false
            when {
                r is Resultado.Ok -> {
                    claveDeGuardado = null
                    // Si mientras el pedido viajaba alguien se movió de paso, no se
                    // lo arrastra: `siguiente` es el siguiente de ESTE paso y en
                    // otro no significa nada.
                    if (pasoDePerfil == actual) {
                        if (siguiente == null) entrar() else pasoDePerfil = siguiente
                    }
                }
                // 🛑 La sesión murió de verdad. Un access vencido ya no llega hasta
                // acá: `ClienteApi` lo renueva y reintenta solo (B-008, resuelto).
                // Lo que llega es un refresh que el servidor ya no acepta —y en ese
                // caso el cliente la borró y avisó por `sesionCerrada`, así que
                // `RaizDeLaApp` también vuelve al login— o un 401 que siguió después
                // de renovar. Quedarse acá con el cartel colgado no tiene salida: del
                // primer paso no se vuelve y el alta ya terminó. Se manda al login,
                // que es lo único que reabre una sesión.
                r is Resultado.Rechazado && r.codigo in CODIGOS_DE_SESION_MUERTA -> {
                    api.olvidarSesion()
                    sesion = null
                    claveDeGuardado = null
                    avisoParaElLogin = traducir(r)
                    error = null
                    paso = PasoDeAcceso.LOGIN
                }
                // El error se muestra donde se pidió, no donde se esté ahora.
                else -> if (pasoDePerfil == actual) error = traducir(r)
            }
        }
    }

    // El botón físico de atrás tiene que hacer lo mismo que la flecha de la
    // pantalla. Si no, se sale de la app en la mitad del alta.
    //
    // 🛑 `BackHandler(enabled = false)` NO es "no hace nada": deja pasar el atrás
    // al sistema, que termina la Activity. En el primer paso de perfil eso cierra
    // la app en la mitad del alta: la sesión quedó guardada y al volver se entra
    // derecho, pero con el perfil a medias y sin que nadie lo haya elegido. Por eso
    // el handler se queda prendido en todo el flujo y decide adentro.
    BackHandler(enabled = paso != PasoDeAcceso.BIENVENIDA && paso != PasoDeAcceso.RECUPERAR) {
        when {
            puedeVolver -> volverAtras()
            // Primer paso del perfil: no hay a dónde volver, pero sí a dónde ir.
            enElPerfil && !enCurso -> entrar()
            // Con un pedido en vuelo, el atrás no mueve nada.
            else -> Unit
        }
    }

    val numeroDePaso = if (enElPerfil) perfilActual.pasoDelRegistro else paso.pasoDelRegistro
    val alVolver: (() -> Unit)? = if (puedeVolver) {
        { volverAtras() }
    } else {
        null
    }

    Column(modifier = modifier.fillMaxSize()) {
        if (numeroDePaso != null) {
            EncabezadoDeRegistro(
                paso = numeroDePaso,
                total = PASOS_DEL_REGISTRO,
                descripcionDelProgreso = stringResource(
                    R.string.reg_progreso,
                    numeroDePaso,
                    PASOS_DEL_REGISTRO,
                ),
                etiquetaVolver = stringResource(R.string.reg_volver),
                onVolver = alVolver,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        when (paso) {
            PasoDeAcceso.BIENVENIDA -> PantallaBienvenida(
                onCrearCuenta = { volverA(PasoDeAcceso.REG_NOMBRE) },
                onYaTengoCuenta = { volverA(PasoDeAcceso.LOGIN) },
            )

            PasoDeAcceso.LOGIN -> PantallaLogin(
                api = api,
                onEntro = onEntro,
                avisoInicial = avisoParaElLogin,
                onVolver = { volverA(PasoDeAcceso.BIENVENIDA) },
                onRegistrarse = { volverA(PasoDeAcceso.REG_NOMBRE) },
                onOlvideLaClave = { escrito ->
                    // El correo que ya tipeó en el login viaja al flujo de
                    // recuperación: volver a escribirlo es el tipo de trámite que
                    // hace que alguien abandone justo cuando más apurado está.
                    correo = escrito
                    volverA(PasoDeAcceso.RECUPERAR)
                },
            )

            PasoDeAcceso.RECUPERAR -> FlujoDeClave(
                api = api,
                correoInicial = correo,
                onEntro = onEntro,
                onVolverAlLogin = { volverA(PasoDeAcceso.LOGIN) },
            )

            PasoDeAcceso.REG_NOMBRE -> PantallaRegistroNombre(
                nombre = borrador.nombre,
                apellido = borrador.apellido,
                onNombre = { borrador = borrador.copy(nombre = it) },
                onApellido = { borrador = borrador.copy(apellido = it) },
                onSeguir = { volverA(PasoDeAcceso.REG_CORREO) },
            )
            PasoDeAcceso.REG_CORREO -> PantallaRegistroCorreo(
                correo = correo,
                onCorreo = { correo = it; error = null },
                enCurso = enCurso,
                error = error,
                onEnviar = { pedirCodigo(PasoDeAcceso.REG_CODIGO) },
            )

            PasoDeAcceso.REG_CODIGO -> PantallaRegistroCodigo(
                correo = correo.trim(),
                codigo = codigo,
                onCodigo = { codigo = it; error = null },
                enCurso = enCurso,
                error = error,
                segundosParaReenviar = segundosParaReenviar,
                onReenviar = { pedirCodigo(PasoDeAcceso.REG_CODIGO) },
                onCambiarCorreo = { volverA(PasoDeAcceso.REG_CORREO) },
                onValidar = {
                    enCurso = true
                    error = null
                    alcance.launch {
                        when (val r = api.verificarCodigo(correo.trim(), codigo)) {
                            is Resultado.Ok -> {
                                tokenDeRegistro = r.dato.registrationToken
                                paso = PasoDeAcceso.REG_CLAVE
                            }
                            else -> error = traducir(r)
                        }
                        enCurso = false
                    }
                },
            )

            PasoDeAcceso.REG_CLAVE -> PantallaRegistroClave(
                clave = clave,
                onClave = { clave = it; error = null },
                repetida = claveRepetida,
                onRepetida = { claveRepetida = it; error = null },
                enCurso = enCurso,
                error = error,
                onCrear = { volverA(PasoDeAcceso.REG_AVISO) },
            )

            PasoDeAcceso.REG_AVISO -> PantallaAviso(
                bloque = legales?.healthNotice,
                revisado = legales?.reviewed ?: true,
                aceptado = aceptoElAviso,
                onAceptado = { aceptoElAviso = it; error = null },
                enCurso = enCurso,
                error = error,
                onVerTerminos = { volverA(PasoDeAcceso.REG_TERMINOS) },
                onIrAlLogin = if (ofrecerLogin) {
                    {
                        avisoParaElLogin = null
                        ofrecerLogin = false
                        volverA(PasoDeAcceso.LOGIN)
                    }
                } else {
                    null
                },
                onSeguir = {
                    val token = tokenDeRegistro
                    val version = legales?.version
                    if (token == null || version == null) {
                        // No debería poder pasar: a este paso se llega con el token
                        // del paso 2, y sin el texto la pantalla no habilita el
                        // botón. Si pasa, se vuelve en vez de mandar un pedido que
                        // no puede andar.
                        volverA(PasoDeAcceso.REG_CORREO)
                    } else {
                        enCurso = true
                        error = null
                        alcance.launch {
                            val r = api.completarRegistro(
                                tokenDeRegistro = token,
                                contrasena = clave,
                                aceptacion = AceptacionLegal(version = version, accepted = true),
                                perfil = com.tecladus.trainer.core.red.PerfilEntrada(
                                    firstName = borrador.nombre.trim(), lastName = borrador.apellido.trim()),
                            )
                            when {
                                r is Resultado.Ok -> {
                                    // 🛑 La cuenta ya existe. De acá en adelante no
                                    // se vuelve: el token de registro se consumió y
                                    // se suelta para no dejarlo en memoria (§8).
                                    sesion = r.dato
                                    tokenDeRegistro = null
                                    clave = ""
                                    claveRepetida = ""
                                    claveDeGuardado = null
                                    pasoDePerfil = PasoDePerfil.NACIMIENTO
                                    paso = PasoDeAcceso.REG_PERFIL
                                }
                                // El texto cambió mientras completaba el registro.
                                // Se baja el nuevo y se lo muestra: reintentar con
                                // la versión vieja sería dar por aceptado algo que
                                // no leyó.
                                r is Resultado.Rechazado && r.codigo == "legal_version_stale" -> {
                                    legales = (api.textosLegales() as? Resultado.Ok)?.dato
                                    aceptoElAviso = false
                                    error = traducir(r)
                                }
                                // 🛑 La contraseña se escribió DOS pasos antes y el
                                // servidor la rechaza recién ahora: las dos reglas
                                // que no se pueden anticipar mientras alguien tipea
                                // —la lista de conocidas y los caracteres distintos,
                                // ver `ReglasDeClave.kt`— sólo se ven al crear la
                                // cuenta. El error tiene que aparecer donde está el
                                // campo, no abajo del aviso de salud.
                                r is Resultado.Rechazado && r.codigo == "weak_password" -> {
                                    error = traducir(r)
                                    paso = PasoDeAcceso.REG_CLAVE
                                }
                                // El token del paso 2 ya no vale. Puede ser que se
                                // haya vencido, o que la cuenta SÍ se haya creado y
                                // la respuesta no haya llegado. En el segundo caso
                                // volver al correo es una trampa: `POST /auth/register`
                                // contesta 202 igual y el código nunca llega, porque
                                // esa dirección ya tiene cuenta. La salida es entrar.
                                r is Resultado.Rechazado &&
                                    r.codigo == "invalid_registration_token" -> {
                                    error = traducir(r)
                                    ofrecerLogin = true
                                }
                                // Puede haberse creado del otro lado sin que la
                                // respuesta volviera. Misma salida.
                                r is Resultado.SinRed -> {
                                    error = traducir(r)
                                    ofrecerLogin = true
                                }
                                else -> error = traducir(r)
                            }
                            enCurso = false
                        }
                    }
                },
            )

            PasoDeAcceso.REG_TERMINOS -> PantallaTerminos(
                bloque = legales?.terms,
                onVolver = { volverA(PasoDeAcceso.REG_AVISO) },
            )

            PasoDeAcceso.REG_PERFIL -> PantallaDePerfil(
                paso = perfilActual,
                borrador = borrador,
                onBorrador = {
                    borrador = it
                    error = null
                    // Otro contenido es otro intento: la clave del anterior no vale.
                    claveDeGuardado = null
                },
                enCurso = enCurso,
                error = error,
                onSeguir = { guardarYSeguir() },
                onCompletarDespues = { entrar() },
            )
        }
    }
}

/**
 * Los códigos con los que vuelve un pedido cuando la sesión ya no sirve, después de
 * que `ClienteApi` intentó renovarla. Para quien usa la app significan lo mismo —hay
 * que volver a entrar— y ninguno se arregla reintentando: `invalid_refresh_token` y
 * `session_revoked` son la renovación diciendo que no, y `unauthorized` es un 401 que
 * siguió después de renovar.
 */
private val CODIGOS_DE_SESION_MUERTA = setOf("unauthorized", "session_revoked", "invalid_refresh_token")

/**
 * Dónde está parado el flujo.
 *
 * [pasoDelRegistro] es el número que muestra la barra de progreso, empezando en 1,
 * o `null` si esa pantalla no es parte del alta. No es el `ordinal`: la bienvenida,
 * el login y la recuperación no cuentan. Los once pasos de perfil tampoco están
 * acá: son un enum propio ([PasoDePerfil]) y ponen su propio número, del 5 al 15.
 */
enum class PasoDeAcceso(val pasoDelRegistro: Int?) {
    BIENVENIDA(null),
    LOGIN(null),

    /** Las cuatro pantallas de `fpEmail` a `fpDone`. Ver [FlujoDeClave]. */
    RECUPERAR(null),

    REG_NOMBRE(1),
    REG_CORREO(2),
    REG_CODIGO(3),

    /** No está dibujado como paso propio: usa el diseño de `fpNew`. */
    REG_CLAVE(4),

    /** 🛑 No está en el diseño: lo pidió Iván. Ver `PantallaAviso.kt`. */
    REG_AVISO(5),

    /** Los términos completos. No cuenta como paso: es una lectura, no un dato. */
    REG_TERMINOS(null),

    /** Los pasos 5 a 15. El número lo pone [PasoDePerfil]. */
    REG_PERFIL(null),
    ;

    /** A dónde lleva la flecha de volver y el botón físico de atrás. */
    fun anterior(): PasoDeAcceso = when (this) {
        BIENVENIDA -> BIENVENIDA
        LOGIN -> BIENVENIDA
        RECUPERAR -> LOGIN
        REG_NOMBRE -> BIENVENIDA
        REG_CORREO -> REG_NOMBRE
        REG_CODIGO -> REG_CORREO
        REG_CLAVE -> REG_CODIGO
        REG_AVISO -> REG_CLAVE
        REG_TERMINOS -> REG_AVISO
        // 🛑 Del perfil no se vuelve al alta: la cuenta ya está creada y el paso
        // anterior mandaría un pedido con un token consumido. Volver adentro del
        // perfil lo maneja `volverAtras()`, no esto.
        REG_PERFIL -> REG_PERFIL
    }
}
