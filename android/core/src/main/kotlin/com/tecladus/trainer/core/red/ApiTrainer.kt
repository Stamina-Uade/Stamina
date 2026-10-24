package com.tecladus.trainer.core.red

import java.net.URLEncoder
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Los endpoints que la app usa, tipeados.
 *
 * Es la única capa escrita a mano entre las pantallas y el contrato: los MODELOS
 * se generan (`ModelosGenerados.kt`), el transporte es genérico (`ClienteApi`), y
 * acá quedan sólo los nombres de las rutas y la forma de cada pedido.
 *
 * Qué pide sesión y qué no lo dice el contrato: todo lleva token salvo lo que
 * declara `security: []`, y eso acá va con `conSesion = false`. Lo público sale sin
 * token y nunca dispara una renovación.
 *
 * Cuando exista el generador de operaciones —hoy sólo genera esquemas— este
 * archivo se borra.
 */
class ApiTrainer(private val cliente: ClienteApi) {

    private val json = Json { encodeDefaults = true; explicitNulls = false }
    private val jsonConNulls = Json { encodeDefaults = true; explicitNulls = true }

    // ------------------------------------------------------------- servicio --

    /** ¿Está vivo el servidor? Lo primero que hay que poder responder. */
    suspend fun salud(): Resultado<Health> =
        cliente.obtener("/health", Health.serializer(), conSesion = false)

    /** La última respuesta clara de la puerta en este proceso, si hubo. Ver [consultarPuertaDeVersion]. */
    @Volatile
    private var ultimaPuertaClara: DecisionDeVersion? = null

    /**
     * La puerta de versión mínima (AGENTS.md §5.1): `GET /version` con la plataforma
     * y el build de esta app, para que el servidor resuelva `action`.
     *
     * Devuelve la decisión y no la respuesta, porque lo delicado es la regla de qué
     * hacer con cada respuesta: sin red, un 503 o cualquier cosa rara es
     * [DecisionDeVersion.Pasar]. Ver [PuertaDeVersion.decidir].
     *
     * 🛑 **Salvo que el servidor ya haya contestado claro.** La app vuelve a preguntar
     * cada vez que vuelve a primer plano, y una falla ahí no puede deshacer lo que el
     * servidor ya dijo: si no, a una versión bloqueada le alcanzaría con salir, poner
     * modo avión y volver. Una falla devuelve la última respuesta clara de este proceso,
     * y sólo otra respuesta clara la cambia —por ejemplo, si el servidor baja el mínimo—.
     * Sin ninguna todavía, una falla deja pasar como siempre.
     */
    suspend fun consultarPuertaDeVersion(plataforma: Plataforma, build: Long): DecisionDeVersion {
        val nombre = json.encodeToJsonElement(Plataforma.serializer(), plataforma).jsonPrimitive.content
        val respuesta = cliente.obtener(
            "/version?platform=$nombre&build=$build",
            VersionGate.serializer(),
            conSesion = false,
        )
        if (respuesta !is Resultado.Ok) return ultimaPuertaClara ?: DecisionDeVersion.Pasar
        return PuertaDeVersion.decidir(respuesta, build).also { ultimaPuertaClara = it }
    }

    // --------------------------------------------------------------- sesión --

    suspend fun entrar(email: String, contrasena: String): Resultado<Sesion> {
        val cuerpo = json.encodeToString(PedidoLogin.serializer(), PedidoLogin(email, contrasena))
        val r = cliente.enviar("/auth/login", cuerpo, Sesion.serializer(), conSesion = false)
        if (r is Resultado.Ok) cliente.abrirSesion(r.dato)
        return r
    }

    /** Levanta la sesión guardada al arrancar. Ver [ClienteApi.restaurarSesion]. */
    suspend fun restaurarSesion(): Boolean = cliente.restaurarSesion()

    /** Cerrar sesión desde la app: avisa al servidor y la borra. Ver [ClienteApi.cerrarSesion]. */
    suspend fun cerrarSesion(): Resultado<Unit> = cliente.cerrarSesion()

    /** La olvida sin avisarle al servidor: para cuando el servidor ya dijo que no existe. */
    suspend fun olvidarSesion() = cliente.olvidarSesion()

    fun haySesion() = cliente.haySesion()

    /** Cuándo el cliente cerró la sesión por su cuenta. Ver [ClienteApi.sesionCerrada]. */
    val sesionCerrada: SharedFlow<Resultado.Rechazado>
        get() = cliente.sesionCerrada

    // ------------------------------------------------------------- registro --

    /**
     * Paso 1 de 3 del registro: pide el código al correo.
     *
     * El contrato lo modela en tres pasos —pedir código, verificarlo, completar el
     * perfil— y esto es sólo el primero.
     */
    suspend fun pedirCodigoDeRegistro(email: String, nombre: String, apellido: String): Resultado<DesafioCorreo> {
        val cuerpo = json.encodeToString(PedidoRegistro.serializer(), PedidoRegistro(email, nombre, apellido))
        return cliente.enviar("/auth/register", cuerpo, DesafioCorreo.serializer(), conSesion = false)
    }

    /** Paso 2 de 3: el código que llegó al correo, a cambio de un permiso de un solo uso. */
    suspend fun verificarCodigo(email: String, codigo: String): Resultado<TokenDeRegistro> {
        val cuerpo = json.encodeToString(
            PedidoVerificacion.serializer(),
            PedidoVerificacion(email, codigo),
        )
        return cliente.enviar(
            "/auth/register/verify",
            cuerpo,
            TokenDeRegistro.serializer(),
            conSesion = false,
        )
    }

    /**
     * El aviso de salud y los términos, con la versión que después hay que mandar
     * al completar el registro.
     *
     * 🛑 No están empaquetados en la app a propósito: un aviso legal que hay que
     * corregir esperando la revisión de la tienda se queda mal escrito una semana.
     */
    suspend fun textosLegales(): Resultado<TextosLegales> =
        cliente.obtener("/legal", TextosLegales.serializer(), conSesion = false)

    /**
     * Paso 3 de 3: la contraseña y el perfil. Devuelve la sesión ya iniciada, y la
     * deja guardada.
     *
     * `perfil` va vacío y el contrato lo permite: `PerfilEntrada` no tiene campos
     * obligatorios. **Las once pantallas de perfil corren DESPUÉS de esto** y
     * guardan con [guardarPerfil]; la decisión y su motivo están en
     * `docs/decisiones/0008-el-perfil-va-despues-de-crear-la-cuenta.md`.
     *
     * @param aceptacion la versión que la persona vio, tal como vino de
     *   [textosLegales]. **No es opcional**: sin ella no hay constancia de qué se
     *   le mostró, y una constancia que no dice qué texto no sirve el día que
     *   haga falta. Si el servidor contesta `legal_version_stale`, el texto cambió
     *   mientras tanto y hay que volver a pedirlo y volver a mostrarlo — no
     *   reintentar con la versión vieja.
     */
    suspend fun completarRegistro(
        tokenDeRegistro: String,
        contrasena: String,
        aceptacion: AceptacionLegal,
        perfil: PerfilEntrada = PerfilEntrada(),
    ): Resultado<Sesion> {
        val cuerpo = json.encodeToString(
            PedidoCompletar.serializer(),
            PedidoCompletar(tokenDeRegistro, contrasena, perfil, aceptacion),
        )
        val r = cliente.enviar("/auth/register/complete", cuerpo, Sesion.serializer(), conSesion = false)
        if (r is Resultado.Ok) cliente.abrirSesion(r.dato)
        return r
    }

    // --------------------------------------------------------------- perfil --

    suspend fun miPerfil(): Resultado<Perfil> =
        cliente.obtener("/me", Perfil.serializer())

    suspend fun misObjetivos(): Resultado<List<ObjetivoActivo>> =
        cliente.obtener("/me/goals", kotlinx.serialization.builtins.ListSerializer(ObjetivoActivo.serializer()))

    suspend fun guardarObjetivos(objetivos: List<ObjetivoEntrada>): Resultado<List<ObjetivoActivo>> {
        val cuerpo = jsonConNulls.encodeToString(PedidoObjetivos.serializer(), PedidoObjetivos(objetivos))
        return cliente.reemplazar(
            "/me/goals", cuerpo,
            kotlinx.serialization.builtins.ListSerializer(ObjetivoActivo.serializer()),
        )
    }

    /**
     * Guarda los campos del perfil que cambiaron. `PATCH /me` del contrato.
     *
     * Manda **sólo lo que trae [perfil]**: `PerfilEntrada` tiene todo opcional y el
     * `Json` de acá está configurado con `explicitNulls = false`, así que un campo
     * en `null` no viaja y el servidor no lo pisa. Es lo que hace que las once
     * pantallas de perfil puedan guardar de a una sin borrarse entre ellas.
     *
     * 🛑 **Y es también lo que hace falta romper para poder BORRAR algo.** Un campo
     * que se quiere dejar vacío no se puede mandar como ausencia —ausencia es "no
     * lo toques"— sino como un `null` explícito. Para eso está [camposEnNull]: los
     * nombres, tal como los escribe el contrato (`goal_date_ms`, `last_name`), se
     * reinyectan en el JSON después de serializar. Sin esto, "Seguir sin fecha"
     * dejaría la fecha de la carrera puesta y la pantalla diría que no.
     *
     * @param clave la clave de idempotencia (AGENTS.md §5.2). La genera quien
     *   llama: tiene que ser **una por intento y la misma entre reintentos de ese
     *   intento**. 🛑 Deliberadamente NO se deriva del cuerpo: dos guardados con el
     *   mismo contenido —volver atrás y volver a elegir lo de antes— son dos
     *   intentos distintos, y con una clave derivada del cuerpo el segundo se
     *   contestaría con la respuesta guardada del primero sin escribir nada.
     */
    suspend fun guardarPerfil(
        perfil: PerfilEntrada,
        clave: String? = null,
        camposEnNull: Set<String> = emptySet(),
    ): Resultado<Perfil> {
        val cuerpo = if (camposEnNull.isEmpty()) {
            json.encodeToString(PerfilEntrada.serializer(), perfil)
        } else {
            val base = json.encodeToJsonElement(PerfilEntrada.serializer(), perfil).jsonObject
            val conNulls = base.toMutableMap()
            camposEnNull.forEach { conNulls[it] = JsonNull }
            json.encodeToString(JsonObject.serializer(), JsonObject(conNulls))
        }
        return cliente.actualizar("/me", cuerpo, Perfil.serializer(), clave)
    }

    // ------------------------------------------------------- recuperación --

    /**
     * Paso 1 de 3 de recuperar la contraseña: pide el código al correo.
     *
     * 🛑 **Contesta que sí exista o no la cuenta**, con el mismo texto y el mismo
     * costo de tiempo. Es a propósito (`/auth/password/forgot`, "mismo trato
     * anti-enumeración que el registro"): una pantalla que dijera "ese correo no
     * está registrado" sería un buscador gratis de direcciones con cuenta. Por eso
     * la pantalla que la usa **no** puede prometer que el mensaje llegó.
     */
    suspend fun pedirCodigoDeClave(email: String): Resultado<DesafioCorreo> {
        val cuerpo = json.encodeToString(PedidoRegistro.serializer(), PedidoRegistro(email))
        return cliente.enviar("/auth/password/forgot", cuerpo, DesafioCorreo.serializer(), conSesion = false)
    }

    /** Paso 2 de 3: el código, a cambio de un permiso de un solo uso. */
    suspend fun verificarCodigoDeClave(email: String, codigo: String): Resultado<TokenDeReseteo> {
        val cuerpo = json.encodeToString(
            PedidoVerificacion.serializer(),
            PedidoVerificacion(email, codigo),
        )
        return cliente.enviar(
            "/auth/password/verify",
            cuerpo,
            TokenDeReseteo.serializer(),
            conSesion = false,
        )
    }

    /**
     * Paso 3 de 3: la contraseña nueva. Devuelve una sesión abierta.
     *
     * El servidor devuelve una sesión nueva. Desde la 1.6.0 ya NO revoca las demás
     * sesiones (cerrarlas es `POST /auth/logout/others`, que Android no usa).
     * Acá se la guarda, igual que en [entrar] — la pantalla `fpDone` entra derecho con ella en vez de
     * pedirle a alguien que tipee la contraseña que acaba de elegir.
     */
    suspend fun cambiarClave(tokenDeReseteo: String, contrasena: String): Resultado<Sesion> {
        val cuerpo = json.encodeToString(
            PedidoReseteo.serializer(),
            PedidoReseteo(tokenDeReseteo, contrasena),
        )
        val r = cliente.enviar("/auth/password/reset", cuerpo, Sesion.serializer(), conSesion = false)
        if (r is Resultado.Ok) cliente.abrirSesion(r.dato)
        return r
    }

    // ----------------------------------------------------------------- plan --

    /**
     * El plan entero: `GET /plan`. Viene el bloque completo a propósito, para que la app
     * lo guarde y el plan del jueves no dependa de tener señal el jueves (AGENTS.md §6).
     *
     * Sin objetivo, nivel, deporte, zona o días de entrenamiento contesta
     * `profile_incomplete`: no es falta de red, es un perfil que falta completar, y la
     * pantalla tiene que poder decir cuál de las dos cosas pasa.
     */
    suspend fun plan(): Resultado<Plan> = cliente.obtener("/plan", Plan.serializer())

    suspend fun planes(): Resultado<List<PlanDeObjetivo>> =
        cliente.obtener("/plans", kotlinx.serialization.builtins.ListSerializer(PlanDeObjetivo.serializer()))

    /**
     * "Lo hice: marcar como hecho" un día que tocaba entrenar y pasó sin una salida
     * registrada: `PUT /plan/days/done` (contrato 1.7.0). No es una actividad: el día
     * sale `done` y cuenta para su semana, sin kilómetros, y la racha no vuelve. Sólo
     * días anteriores a hoy; si no, `bad_request`.
     *
     * @param instanteMs cualquier instante de ese día, como en [rutinaDelDia].
     */
    suspend fun marcarDiaHecho(instanteMs: Long, clave: String? = null): Resultado<Unit> =
        cliente.reemplazarSinRespuesta(
            "/plan/days/done",
            json.encodeToString(PedidoDiaHecho.serializer(), PedidoDiaHecho(instanteMs)),
            clave,
        )

    /**
     * La rutina de gimnasio de un día: `GET /plan/routine`.
     *
     * @param instanteMs cualquier instante del día que se pide. El SERVIDOR lo lleva al
     *   día local de la persona con la zona de su perfil, así que para hoy alcanza con
     *   "ahora". 🛑 El cliente no manda una medianoche: calculada con el huso del teléfono,
     *   a quien viajó le pediría otro día.
     */
    suspend fun rutinaDelDia(instanteMs: Long): Resultado<RutinaDelDia> =
        cliente.obtener("/plan/routine?date_ms=$instanteMs", RutinaDelDia.serializer())

    // ------------------------------------------------------------ nutrición --

    /**
     * Los objetivos y las comidas de un día: `GET /nutrition/day`, con el mismo
     * `instanteMs` que [rutinaDelDia].
     *
     * Sin objetivos viene `unavailable_reason` en lugar de `targets` (AGENTS.md §9.2): la
     * pantalla muestra apoyo y no un número, así que `targets` en `null` no es un error.
     */
    suspend fun nutricionDelDia(instanteMs: Long): Resultado<DiaNutricional> =
        cliente.obtener("/nutrition/day?date_ms=$instanteMs", DiaNutricional.serializer())

    /**
     * Guarda una comida: `PUT /meals/{meal_id}`.
     *
     * @param id lo genera el cliente —un UUID— y es lo que hace seguro reintentar: el
     *   mismo id dos veces es la misma comida, no dos. Uno que ya se borró contesta
     *   `not_found`.
     */
    suspend fun guardarComida(id: String, comida: ComidaEntrada): Resultado<ComidaRegistrada> =
        cliente.reemplazar(
            "/meals/${segmento(id)}",
            json.encodeToString(ComidaEntrada.serializer(), comida),
            ComidaRegistrada.serializer(),
        )

    /** Borra una comida: `DELETE /meals/{meal_id}`. Borrar lo ya borrado también da `Ok`. */
    suspend fun borrarComida(id: String): Resultado<Unit> = cliente.borrar("/meals/${segmento(id)}")

    // ------------------------------------------------------------- gimnasio --

    /**
     * Sube series: `POST /gym/sessions/{session_id}/sets` (decisión 0006).
     *
     * No es "crear": es "esto es lo que tengo". El servidor fusiona serie por serie y
     * devuelve la sesión ENTERA con `received_at_ms`, que el teléfono fusiona a su vez
     * con lo suyo.
     *
     * @param clave 🛑 **obligatoria acá**, aunque el contrato la declare opcional: una por
     *   intento, y la misma —con el MISMO cuerpo— en los reintentos de ese intento. La
     *   misma clave con otro cuerpo es un 409. La elige quien sabe qué es un intento: el
     *   `SincronizadorDeGimnasio`, que la guarda en el disco antes de mandarla.
     */
    suspend fun sincronizarSeries(
        sesionId: String,
        series: List<SerieDeGimnasioEntrada>,
        clave: String,
    ): Resultado<SesionDeGimnasio> =
        cliente.enviar(
            "/gym/sessions/${segmento(sesionId)}/sets",
            json.encodeToString(PedidoSeries.serializer(), PedidoSeries(series)),
            SesionDeGimnasio.serializer(),
            clave = clave,
        )

    /**
     * Una sesión con sus series: `GET /gym/sessions/{session_id}`.
     *
     * Una sesión en la que nadie registró nada todavía contesta `not_found`: para quien
     * sincroniza eso es una sesión vacía, no un error.
     */
    suspend fun sesionDeGimnasio(sesionId: String): Resultado<SesionDeGimnasio> =
        cliente.obtener("/gym/sessions/${segmento(sesionId)}", SesionDeGimnasio.serializer())

    // ------------------------------------------------------------- catálogo --

    /**
     * Una página del catálogo: `GET /exercises`.
     *
     * @param cursor el `next_cursor` de la página anterior, tal cual vino. Es opaco y
     *   puede traer `=`, `+` o `/`: viaja codificado, o el servidor recibe otro cursor.
     */
    suspend fun ejercicios(
        limite: Int? = null,
        cursor: String? = null,
    ): Resultado<Pagina<EjercicioCatalogado>> {
        val parametros = buildList {
            if (limite != null) add("limit=$limite")
            if (cursor != null) add("cursor=${URLEncoder.encode(cursor, UTF_8)}")
        }
        val consulta = if (parametros.isEmpty()) "" else parametros.joinToString("&", prefix = "?")
        return cliente.obtenerPagina("/exercises$consulta", EjercicioCatalogado.serializer())
    }

    /**
     * Un id que va adentro de la ruta. Los del contrato son letras, números y guiones, y
     * con uno bueno esto no cambia nada; con uno malo evita que una `/` o un `?` manden
     * el pedido a OTRA ruta.
     */
    private fun segmento(id: String): String = URLEncoder.encode(id, UTF_8)

    private companion object {
        /** Por nombre y no `Charsets.UTF_8`: la sobrecarga con `Charset` es de la API 33. */
        const val UTF_8 = "UTF-8"
    }
}

/** El cuerpo de `POST /gym/sessions/{id}/sets`. El contrato no admite nada más que `sets`. */
@Serializable
private data class PedidoSeries(val sets: List<SerieDeGimnasioEntrada>)

/** El cuerpo de `PUT /plan/days/done` (1.7.0). */
@Serializable
private data class PedidoDiaHecho(@kotlinx.serialization.SerialName("date_ms") val dateMs: Long)

@Serializable
private data class PedidoLogin(val email: String, val password: String)

@Serializable
private data class PedidoObjetivos(val goals: List<ObjetivoEntrada>)

@Serializable
private data class PedidoRegistro(
    val email: String,
    @kotlinx.serialization.SerialName("first_name") val firstName: String? = null,
    @kotlinx.serialization.SerialName("last_name") val lastName: String? = null,
)

@Serializable
private data class PedidoVerificacion(val email: String, val code: String)

@Serializable
private data class PedidoReseteo(
    @kotlinx.serialization.SerialName("reset_token")
    val resetToken: String,
    val password: String,
)

@Serializable
private data class PedidoCompletar(
    @kotlinx.serialization.SerialName("registration_token")
    val registrationToken: String,
    val password: String,
    val profile: PerfilEntrada,
    val legal: AceptacionLegal,
)
