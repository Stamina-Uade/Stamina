package com.tecladus.trainer.core.red

import java.io.IOException
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/**
 * El cliente HTTP de Trainer. Habla el contrato de `shared/api/openapi.yaml`.
 *
 * El cable está en [Transporte] —en el teléfono, [TransporteHttp]—; acá queda lo
 * que va encima: el sobre del contrato, los headers y la sesión.
 *
 * ## La sesión, guardada y cifrada
 *
 * La sesión vive en memoria y en un [AlmacenDeSesion]. En el teléfono es
 * [AlmacenDeSesionCifrado], que la cifra con una llave del Android Keystore antes
 * de que toque el disco: cerrar la app ya no cierra la sesión.
 *
 * 🛑 **Nunca en claro y nunca en un log.** Un refresh de treinta días en un
 * `SharedPreferences` común es una credencial en texto plano, y AGENTS.md §12.1 no
 * lo permite. Por el mismo motivo [PedidoHttp] y [RespuestaHttp] no imprimen lo que
 * llevan.
 *
 * ## El access se renueva solo (docs/BLOQUEOS.md, B-008)
 *
 * El access vive quince minutos. Si el servidor lo rechaza con un 401 y hay refresh
 * a mano, el cliente pide `POST /auth/refresh` **una** vez y reintenta **una** vez
 * con el access nuevo. Y si el access vence en menos de [MARGEN_DE_RENOVACION_MS],
 * ni se lo manda: se renueva antes.
 *
 * El 401 que dispara esto es `unauthorized` —el access venció— **y también
 * `session_revoked`**. Desde la decisión 0013 rotar el refresh no invalida los access
 * ya emitidos, así que `session_revoked` en un pedido común sólo llega con una
 * revocación de verdad. Igual pasa por la renovación, a propósito: si otro pedido ya
 * renovó, se reintenta con ese access; si no, la renovación le pregunta al servidor,
 * que lo confirma, y la sesión se cierra. Cuesta un pedido más que cerrarla de una, y
 * es todo lo que cuesta. Si el pedido que sale con un access recién renovado vuelve
 * igual con `session_revoked`, ahí se cierra sin preguntar más.
 *
 * 🛑 **Una sola renovación en vuelo.** El servidor rota el refresh en cada uso. Si le
 * reenvían uno ya canjeado dentro de los dos minutos, con su sucesor sin usar, devuelve
 * ese mismo sucesor; fuera de eso es un reuso, su señal de robo, y revoca la familia
 * entera. Dos renovaciones a la vez con el mismo refresh quedan a un paso de eso: basta
 * con que una use el sucesor antes de que llegue la otra. Por eso la renovación pasa
 * por [candado]: sale una, y las que llegan mientras tanto esperan y se quedan con SU
 * resultado, bueno o malo.
 *
 * Si la renovación contesta `invalid_refresh_token` o `session_revoked`, la sesión
 * ya no existe del otro lado: se borra acá y se avisa por [sesionCerrada], que la UI
 * escucha para mandar al login con el motivo.
 *
 * 🛑 **Un solo cliente por proceso.** El candado vive adentro de la instancia: dos
 * clientes sobre el mismo almacén son dos candados, y pueden volver a canjear el
 * mismo refresh dos veces. En la app lo garantiza `RedDeLaApp`.
 *
 * **Una respuesta perdida se recupera.** Si una renovación llega al servidor y la
 * respuesta se corta en el camino, el cliente no puede distinguirlo de un pedido que
 * nunca llegó, y no le hace falta: después de un `SinRed` o un 5xx reenvía EL MISMO
 * refresh a los 5, 20 y 60 segundos, dentro de la ventana de dos minutos en la que el
 * servidor devuelve el mismo sucesor (decisión 0013). Ver `reintentarMasTarde`.
 */
class ClienteApi(
    /** Sin barra final y con el prefijo del contrato: `https://host/v1`. */
    private val baseUrl: String,
    private val almacen: AlmacenDeSesion = AlmacenDeSesionEnMemoria(),
    private val transporte: Transporte = TransporteHttp(),
    /**
     * Donde corren los reintentos de una renovación que se quedó sin respuesta. No es
     * de quien pide: esos reintentos tienen que seguir aunque la pantalla que disparó
     * la renovación ya no exista. En la app vive lo que vive el proceso, igual que el
     * cliente; los tests pasan uno con reloj virtual.
     */
    private val alcance: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
    /** Milisegundos epoch. Se inyecta para probar vencimientos sin esperar quince minutos. */
    private val reloj: () -> Long = System::currentTimeMillis,
) {

    private val json = Json {
        // El servidor puede agregar campos: el contrato dice que los cambios son
        // aditivos (§5). Un cliente que revienta ante un campo nuevo obliga a
        // desplegar la app cada vez que el servidor crece.
        ignoreUnknownKeys = true
        explicitNulls = false
    }

    /**
     * Una sesión y la apertura a la que pertenece.
     *
     * Una apertura es un login —o un alta, o una contraseña nueva—. Renovar el access
     * NO abre otra; cerrar la sesión y volver a entrar, sí. Es lo que deja distinguir
     * "otro pedido ya la renovó mientras éste viajaba", donde se usa la renovada, de
     * "se cerró y entró alguien", donde el pedido era de otra sesión y no se reintenta
     * con nada.
     */
    private class Vigente(val sesion: Sesion, val apertura: Long)

    /** Se LEE sin candado —es un solo campo, `@Volatile`— y se ESCRIBE sólo con [candado]. */
    @Volatile
    private var vigente: Vigente? = null

    /** Serializa todo lo que cambia la sesión: renovar, abrir, olvidar, cerrar, y el almacén. */
    private val candado = Mutex()

    /** Cuántas aperturas hubo. Sólo con [candado]. */
    private var aperturas = 0L

    /**
     * La renovación que está viajando, si hay una, y de QUÉ sesión es. Sólo con [candado].
     *
     * 🛑 La sesión va anotada porque cerrar no corta el viaje: si la renovación de la
     * sesión de antes sigue en el aire cuando esa persona sale y entra otra, la que
     * entró no se puede sumar a ella. Esperaría un refresh que no es el suyo, y lo que
     * vuelva no le sirve a nadie.
     */
    private var renovacionEnVuelo: EnVuelo? = null

    /** Una renovación en el aire: la sesión cuyo refresh salió, y en qué termina. */
    private class EnVuelo(val desde: Vigente) {
        val resultado = CompletableDeferred<Renovacion>()
    }

    /**
     * Si conviene renovar ANTES de mandar un access por vencer.
     *
     * Se apaga cuando una sesión recién emitida por el servidor ya parece por vencer
     * según el reloj del teléfono: la hora está adelantada, o el servidor da access más
     * cortos que el margen. Sin esto, con el reloj corrido quince minutos cada pedido
     * gastaría una renovación. Apagado, queda el camino que no depende del reloj: el
     * 401.
     */
    @Volatile
    private var renovarPorAdelantado = true

    private val cierres = MutableSharedFlow<Resultado.Rechazado>(extraBufferCapacity = 1)

    /**
     * Avisa cuando el cliente cerró la sesión POR SU CUENTA: la renovación contestó
     * `invalid_refresh_token` o `session_revoked`, o un pedido que salió con el access
     * recién renovado volvió igual con `session_revoked`. Trae el rechazo tal cual, para
     * que la pantalla traduzca el `codigo`.
     *
     * No avisa cuando la cierra quien usa la app ([cerrarSesion], [olvidarSesion]): ya
     * lo sabe. Y no repite avisos viejos: quien se suscribe tarde pregunta [haySesion].
     */
    val sesionCerrada: SharedFlow<Resultado.Rechazado> = cierres.asSharedFlow()

    fun haySesion(): Boolean = vigente != null

    /**
     * Levanta la sesión guardada. Se llama al arrancar, antes de decidir si se muestra
     * el acceso o la app.
     *
     * Idempotente: con una sesión en memoria no relee el almacén. Si lo guardado no se
     * puede leer, el almacén lo borra y esto devuelve `false`.
     *
     * No mira si el refresh venció según el reloj del teléfono: esa hora la mueve
     * cualquiera, y el servidor lo va a decir en el primer pedido.
     *
     * @return si quedó una sesión abierta.
     */
    suspend fun restaurarSesion(): Boolean = candado.withLock {
        if (vigente == null) {
            val guardada = withContext(Dispatchers.IO) { almacen.leer() }
            if (guardada != null) vigente = Vigente(guardada, ++aperturas)
        }
        vigente != null
    }

    /** Adopta la sesión que acaba de emitir el servidor —login, alta, contraseña nueva— y la guarda. */
    suspend fun abrirSesion(nueva: Sesion) {
        candado.withLock { adoptar(Vigente(nueva, ++aperturas)) }
    }

    /** La olvida acá y en el almacén, sin avisarle al servidor. */
    suspend fun olvidarSesion() {
        candado.withLock { soltar() }
    }

    /**
     * Cerrar sesión: `POST /auth/logout` con el refresh, y borrarla de este lado.
     *
     * 🛑 **Se borra ANTES de llamar al servidor**, no después. Si la app se cierra con
     * el pedido en el aire, al volver a abrirla no puede aparecer adentro de una cuenta
     * de la que la persona salió. El pedido sale con los tokens que ya estaban en la
     * mano, y corre sin poder cancelarse: salir de la pantalla no lo corta.
     *
     * Con el refresh en el cuerpo el servidor revoca la familia entera, no sólo esta
     * sesión. Si el access ya venció, se renueva con ese refresh sólo para poder
     * revocar: lo que devuelve esa renovación no se guarda.
     *
     * Sin señal, la sesión queda cerrada igual en el teléfono, y del otro lado el
     * refresh vence solo. Reintentar el logout más tarde no está hecho.
     *
     * @return lo que contestó el logout. Es informativo: la sesión local ya no está.
     */
    suspend fun cerrarSesion(): Resultado<Unit> = withContext(NonCancellable) {
        val cerrada = candado.withLock {
            val actual = vigente ?: return@withContext Resultado.Ok(Unit)
            soltar()
            actual.sesion
        }
        val respuesta = pedirCierre(cerrada)
        if (!esAccesoRechazado(respuesta)) return@withContext respuesta
        when (val renovada = pedirRenovacion(cerrada.refreshToken)) {
            is Resultado.Ok -> pedirCierre(renovada.dato)
            else -> respuesta
        }
    }

    suspend fun <T> obtener(
        ruta: String,
        comoLeerlo: DeserializationStrategy<T>,
        /** `false` para lo que el contrato declara `security: []`: sale sin token y no renueva. */
        conSesion: Boolean = true,
    ): Resultado<T> = pedir("GET", ruta, null, conSesion, null) { leerSobre(it, comoLeerlo) }

    /**
     * POST.
     *
     * @param clave la clave de idempotencia, o `null`. Ver [actualizar]: es una por
     *   intento y la misma entre reintentos de ese intento, también el que sale después
     *   de renovar la sesión.
     */
    suspend fun <T> enviar(
        ruta: String,
        cuerpo: String,
        comoLeerlo: DeserializationStrategy<T>,
        /** `false` para lo que el contrato declara `security: []`: sale sin token y no renueva. */
        conSesion: Boolean = true,
        clave: String? = null,
    ): Resultado<T> = pedir("POST", ruta, cuerpo, conSesion, clave) { leerSobre(it, comoLeerlo) }

    /**
     * GET de una lista del contrato: `{data: [...], pagination: {...}}`.
     *
     * No pasa por [obtener] porque la paginación viaja AL LADO de `data`, no adentro
     * (docs/API.md §1): leer sólo `data` perdería el cursor, y con él la página siguiente.
     */
    suspend fun <E> obtenerPagina(
        ruta: String,
        elemento: KSerializer<E>,
    ): Resultado<Pagina<E>> = pedir("GET", ruta, null, true, null) { leerPagina(it, elemento) }

    /**
     * PUT: guardar entero lo que tiene un id que eligió el cliente, como `PUT /meals/{id}`.
     * Mandarlo dos veces deja lo mismo, así que un reintento no duplica nada.
     */
    suspend fun <T> reemplazar(
        ruta: String,
        cuerpo: String,
        comoLeerlo: DeserializationStrategy<T>,
        clave: String? = null,
    ): Resultado<T> = pedir("PUT", ruta, cuerpo, true, clave) { leerSobre(it, comoLeerlo) }

    /** DELETE. Lo que el contrato borra contesta 204 sin cuerpo. */
    suspend fun borrar(ruta: String, clave: String? = null): Resultado<Unit> =
        pedir("DELETE", ruta, null, true, clave) { leerSinCuerpo(it) }

    /**
     * PATCH. Lo usa `PATCH /me`, que es la única escritura parcial del contrato.
     *
     * 🛑 **PATCH sobre `HttpURLConnection` es un caso especial y por eso está
     * escrito.** El `HttpURLConnection` del JDK de escritorio tiene la lista de
     * métodos quemada y `setRequestMethod("PATCH")` le tira `ProtocolException`.
     * En **Android** no: desde KitKat la implementación es la de OkHttp y su lista sí
     * lo incluye. O sea que [TransporteHttp] anda en el teléfono y **no** andaría en
     * un test de JVM que llame de verdad al servidor — por eso los tests de este
     * repositorio usan un [Transporte] de mentira y prueban lo que va encima.
     *
     * @param clave la clave de idempotencia (AGENTS.md §5.2), o `null`. Va como
     *   header `Idempotency-Key`: con ella, reintentar un pedido que ya se aplicó
     *   devuelve la MISMA respuesta en vez de volver a escribir. En una app que se usa
     *   sin señal, reintentar es lo normal, no la excepción. El reintento después de
     *   renovar la sesión lleva la misma clave: es el mismo intento.
     */
    suspend fun <T> actualizar(
        ruta: String,
        cuerpo: String,
        comoLeerlo: DeserializationStrategy<T>,
        clave: String? = null,
    ): Resultado<T> = pedir("PATCH", ruta, cuerpo, true, clave) { leerSobre(it, comoLeerlo) }

    // ------------------------------------------------------------ por dentro --

    /**
     * Un pedido, con la sesión si corresponde. Renueva antes si el access está por
     * vencer, o después de un 401; nunca las dos cosas en el mismo pedido.
     */
    private suspend fun <T> pedir(
        metodo: String,
        ruta: String,
        cuerpo: String?,
        conSesion: Boolean,
        clave: String?,
        leer: (RespuestaHttp) -> Resultado<T>,
    ): Resultado<T> {
        // Lo público sale sin token y nunca renueva: gastar una rotación para
        // preguntar la puerta de versión sería tirarla.
        if (!conSesion) return intentar(metodo, ruta, null, clave, cuerpo, leer)
        // 🛑 Con sesión pedida y sin sesión, no sale. Sin `Authorization` el servidor
        // contestaría 401 igual, pero el pedido ya habría viajado: un `PATCH /me` de
        // alguien que acaba de salir, con su perfil adentro y sin dueño. Se contesta acá
        // lo mismo que contestaría él.
        val enMano = vigente ?: return SIN_SESION

        var conEsta = enMano
        var renovoAntes = false
        if (renovarPorAdelantado && enMano.sesion.accessExpiresAtMs - reloj() < MARGEN_DE_RENOVACION_MS) {
            renovoAntes = true
            when (val renovacion = renovar(enMano)) {
                is Renovacion.Lista -> conEsta = renovacion.vigente
                is Renovacion.Fallida -> return renovacion.motivo ?: SIN_SESION
            }
        }

        val primera = intentar(metodo, ruta, conEsta.sesion.accessToken, clave, cuerpo, leer)
        // Una sola renovación por pedido: si ya se renovó antes de mandarlo y el
        // servidor igual dice que no, otra más no lo arregla.
        if (renovoAntes) return cerrarSiLaRevocaron(conEsta, primera)
        if (!esAccesoRechazado(primera)) return primera

        return when (val renovacion = renovar(conEsta)) {
            is Renovacion.Lista -> cerrarSiLaRevocaron(
                renovacion.vigente,
                intentar(metodo, ruta, renovacion.vigente.sesion.accessToken, clave, cuerpo, leer),
            )
            is Renovacion.Fallida -> renovacion.motivo ?: primera
        }
    }

    /**
     * Lo que volvió con un access recién renovado. Si igual dice `session_revoked`, a la
     * sesión la revocaron de verdad —desde la decisión 0013 rotar no invalida ningún
     * access— y otra renovación no la salva: se borra y se avisa por [sesionCerrada],
     * igual que cuando lo dice la renovación. Devolverlo sin más dejaba guardada una
     * sesión muerta, y la pantalla sin enterarse de que tiene que ir al login.
     *
     * Sólo si sigue siendo la sesión que se usó: si mientras tanto se cerró, entró otra
     * o alguien la volvió a renovar, este rechazo ya no habla de la que está.
     */
    private suspend fun <T> cerrarSiLaRevocaron(usada: Vigente, respuesta: Resultado<T>): Resultado<T> {
        if (respuesta is Resultado.Rechazado && respuesta.http == 401 && respuesta.codigo == "session_revoked") {
            candado.withLock {
                if (vigente === usada) {
                    soltar()
                    cierres.tryEmit(respuesta)
                }
            }
        }
        return respuesta
    }

    /** Lo que sale de pedir una renovación. */
    private sealed interface Renovacion {

        /** Hay un access que sirve: el renovado, o el que otro pedido renovó mientras tanto. */
        class Lista(val vigente: Vigente) : Renovacion

        /** No hay. [motivo] es lo que contestó la renovación, o `null` si la sesión se cerró mientras tanto. */
        class Fallida(val motivo: Resultado<Nothing>?) : Renovacion
    }

    /**
     * Renueva la sesión con la que salió un pedido, o se suma a la renovación que ya
     * está viajando. Nunca salen dos a la vez.
     */
    private suspend fun renovar(vencida: Vigente): Renovacion {
        val (enVuelo, meToca) = candado.withLock {
            val actual = vigente
            // Se cerró, o se cerró y entró otra: el pedido era de una sesión que ya no está.
            if (actual == null || actual.apertura != vencida.apertura) return Renovacion.Fallida(null)
            // Otro pedido ya la renovó mientras éste viajaba: se usa esa, sin gastar el refresh.
            if (actual !== vencida) return Renovacion.Lista(actual)
            val existente = renovacionEnVuelo
            // Se suma sólo a la de ESTA sesión, por identidad. La que quedó en el aire de
            // una sesión que ya se cerró no es de nadie: ésta manda la suya.
            if (existente != null && existente.desde === vencida) {
                existente to false
            } else {
                EnVuelo(vencida).also { renovacionEnVuelo = it } to true
            }
        }
        if (!meToca) return enVuelo.resultado.await()

        // 🛑 NonCancellable: si quien disparó la renovación se cancela —se cerró la
        // pantalla—, el pedido sigue igual y su resultado se guarda. Tirarlo sería
        // perder un refresh que el servidor ya canjeó: el intento siguiente mandaría el
        // viejo, que dentro de los dos minutos de la decisión 0013 recibe el mismo
        // sucesor, pero pasado eso es un reuso que revoca la familia. Guardarlo ahora no
        // depende de esa ventana. Y los que esperan en `enVuelo` no pueden quedarse
        // esperando para siempre.
        return withContext(NonCancellable) {
            try {
                val respuesta = pedirRenovacion(vencida.sesion.refreshToken)
                val renovacion = candado.withLock {
                    // Sólo si sigue siendo ésta: mientras viajaba pudo entrar otra sesión
                    // y mandar su propia renovación, que no se toca.
                    if (renovacionEnVuelo === enVuelo) renovacionEnVuelo = null
                    aplicar(vencida, respuesta).also {
                        // Sin respuesta o con un 5xx, y la sesión intacta: el refresh pudo
                        // haberse canjeado igual del otro lado.
                        if (vigente === vencida && sePuedeReintentar(respuesta)) reintentarMasTarde(vencida)
                    }
                }
                enVuelo.resultado.complete(renovacion)
                renovacion
            } catch (e: Throwable) {
                // Algo que no es la red —la red ya vuelve como SinRed—, o sea un bug.
                // Igual se suelta a los que esperan, con el mismo error.
                candado.withLock { if (renovacionEnVuelo === enVuelo) renovacionEnVuelo = null }
                enVuelo.resultado.completeExceptionally(e)
                throw e
            }
        }
    }

    /**
     * La sesión que tiene reintentos programados, si hay. Por identidad, como
     * [renovacionEnVuelo]: uno por sesión, y nunca los de la de antes para la de ahora.
     * Sólo con [candado].
     */
    private var reintentosDe: Vigente? = null

    /**
     * Vuelve a mandar EL MISMO refresh, un par de veces, cuando la renovación se quedó
     * sin respuesta o volvió con un 5xx. Se llama con [candado] tomado.
     *
     * 🛑 Es lo que salva una respuesta perdida. Si el refresh llegó y el servidor lo
     * canjeó, pero la respuesta se cortó, desde el teléfono no hay forma de saberlo. La
     * decisión 0013 lo cubre del otro lado: ese refresh reenviado dentro de los dos
     * minutos, con el sucesor sin usar, devuelve EL MISMO sucesor. Pero sólo si alguien
     * lo reenvía a tiempo: si nadie pide nada en tres minutos, el próximo intento ya es
     * un reuso, el servidor revoca la familia y la persona termina en el login. Por eso
     * no se espera a que alguien pida.
     *
     * - A los 5, 20 y 60 segundos del primer fallo, si cada intento falla enseguida. Con
     *   los 10 s de espera de cada uno, el último sale antes de los 90 s del primer envío
     *   y vuelve antes de los 100: adentro de la ventana, con margen.
     * - En [alcance] y no en el de quien pidió: esa pantalla ya se llevó su `SinRed` en el
     *   momento, y puede no existir más.
     * - Cada intento pasa por [renovar], así que respeta la regla de una sola en vuelo:
     *   si hay una viajando se suma a ella, si alguien ya renovó se queda con eso, y si
     *   la sesión se cerró no manda nada.
     * - Uno por sesión: un pedido que falla mientras tanto no programa otro.
     */
    private fun reintentarMasTarde(vencida: Vigente) {
        if (reintentosDe === vencida) return
        reintentosDe = vencida
        alcance.launch {
            try {
                for (espera in ESPERAS_ENTRE_REINTENTOS_MS) {
                    delay(espera)
                    val otra = renovar(vencida)
                    if (otra !is Renovacion.Fallida || !sePuedeReintentar(otra.motivo)) break
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Un bug, no la red: la red vuelve como SinRed. No se reintenta más; el
                // próximo pedido que renueve se lo va a encontrar por su cuenta.
            } finally {
                withContext(NonCancellable) {
                    candado.withLock { if (reintentosDe === vencida) reintentosDe = null }
                }
            }
        }
    }

    /** Lo que vale la pena reintentar con el mismo refresh: no volvió nada, o volvió un 5xx. */
    private fun sePuedeReintentar(respuesta: Resultado<*>?): Boolean = when (respuesta) {
        is Resultado.SinRed -> true
        is Resultado.Rechazado -> respuesta.http in 500..599
        is Resultado.RespuestaRara -> respuesta.http in 500..599
        else -> false
    }

    /** Lo que volvió de la renovación. Se llama con [candado] tomado. */
    private suspend fun aplicar(desde: Vigente, respuesta: Resultado<Sesion>): Renovacion {
        // Mientras viajaba se cerró la sesión o entró otra: lo que volvió ya no es de
        // nadie. No se guarda y no se avisa; quien la cerró ya lo sabe.
        if (vigente !== desde) return Renovacion.Fallida(null)
        return when (respuesta) {
            is Resultado.Ok -> {
                val renovada = Vigente(respuesta.dato, desde.apertura)
                adoptar(renovada)
                Renovacion.Lista(renovada)
            }
            is Resultado.Rechazado -> {
                if (respuesta.codigo in CODIGOS_DE_SESION_TERMINADA) {
                    soltar()
                    cierres.tryEmit(respuesta)
                }
                Renovacion.Fallida(respuesta)
            }
            // Sin red o una respuesta rara: la sesión puede seguir sirviendo. Se
            // devuelve el problema y no se toca nada.
            is Resultado.SinRed -> Renovacion.Fallida(respuesta)
            is Resultado.RespuestaRara -> Renovacion.Fallida(respuesta)
        }
    }

    /** Con [candado] tomado. */
    private suspend fun adoptar(nueva: Vigente) {
        vigente = nueva
        // Una sesión recién emitida tiene que durar más que el margen. Si según este
        // reloj ya está por vencer, el reloj está corrido: ver `renovarPorAdelantado`.
        renovarPorAdelantado = nueva.sesion.accessExpiresAtMs - reloj() >= MARGEN_DE_RENOVACION_MS
        withContext(Dispatchers.IO) { almacen.guardar(nueva.sesion) }
    }

    /** Con [candado] tomado. */
    private suspend fun soltar() {
        vigente = null
        renovarPorAdelantado = true
        withContext(Dispatchers.IO) { almacen.borrar() }
    }

    private suspend fun pedirRenovacion(refresh: String): Resultado<Sesion> =
        intentar("POST", "/auth/refresh", null, null, cuerpoConRefresh(refresh)) {
            leerSobre(it, Sesion.serializer())
        }

    private suspend fun pedirCierre(sesion: Sesion): Resultado<Unit> =
        intentar("POST", "/auth/logout", sesion.accessToken, null, cuerpoConRefresh(sesion.refreshToken)) {
            leerSinCuerpo(it)
        }

    private fun cuerpoConRefresh(refresh: String): String =
        json.encodeToString(PedidoConRefresh.serializer(), PedidoConRefresh(refresh))

    /** Un viaje de ida y vuelta, sin reintentos ni renovaciones. */
    private suspend fun <T> intentar(
        metodo: String,
        ruta: String,
        acceso: String?,
        clave: String?,
        cuerpo: String?,
        leer: (RespuestaHttp) -> Resultado<T>,
    ): Resultado<T> {
        val headers = buildMap<String, String> {
            put("Accept", "application/json")
            // Lo que el servidor traduce, lo traduce según esto: el `message` de la
            // puerta de versión, por ejemplo.
            put("Accept-Language", Locale.getDefault().toLanguageTag())
            if (acceso != null) put("Authorization", "Bearer $acceso")
            if (clave != null) put("Idempotency-Key", clave)
            if (cuerpo != null) put("Content-Type", "application/json")
        }
        val respuesta = try {
            transporte.ejecutar(PedidoHttp(metodo, baseUrl + ruta, headers, cuerpo))
        } catch (e: IOException) {
            // 🛑 El mensaje de la excepción puede llevar la URL, y la URL puede
            // llevar un id. §8: nada de identidad en logs ni en telemetría.
            return Resultado.SinRed(e.javaClass.simpleName)
        }
        return leer(respuesta)
    }

    private fun <T> leerSobre(
        respuesta: RespuestaHttp,
        comoLeerlo: DeserializationStrategy<T>,
    ): Resultado<T> = try {
        val raiz: JsonObject = json.parseToJsonElement(respuesta.cuerpo).jsonObject
        val error = raiz["error"]
        if (error != null) {
            val detalle = json.decodeFromJsonElement(DetalleDeError.serializer(), error)
            Resultado.Rechazado(detalle.code, detalle.message, respuesta.codigo)
        } else {
            val dato = raiz["data"]
                ?: return Resultado.RespuestaRara("el sobre no trae ni data ni error", respuesta.codigo)
            Resultado.Ok(json.decodeFromJsonElement(comoLeerlo, dato))
        }
    } catch (e: SerializationException) {
        Resultado.RespuestaRara(e.javaClass.simpleName, respuesta.codigo)
    } catch (e: IllegalArgumentException) {
        Resultado.RespuestaRara(e.javaClass.simpleName, respuesta.codigo)
    }

    /** Lo mismo que [leerSobre], para una lista: `data` es la página y `pagination` va al lado. */
    private fun <E> leerPagina(
        respuesta: RespuestaHttp,
        elemento: KSerializer<E>,
    ): Resultado<Pagina<E>> = try {
        val raiz: JsonObject = json.parseToJsonElement(respuesta.cuerpo).jsonObject
        val error = raiz["error"]
        if (error != null) {
            val detalle = json.decodeFromJsonElement(DetalleDeError.serializer(), error)
            Resultado.Rechazado(detalle.code, detalle.message, respuesta.codigo)
        } else {
            val datos = raiz["data"]
                ?: return Resultado.RespuestaRara("el sobre no trae ni data ni error", respuesta.codigo)
            // Sin `pagination` no se sabe si hay otra página: tomarlo como "no hay" cortaría
            // el catálogo en silencio.
            val paginacion = raiz["pagination"]
                ?: return Resultado.RespuestaRara("la lista no trae pagination", respuesta.codigo)
            Resultado.Ok(
                Pagina(
                    datos = json.decodeFromJsonElement(ListSerializer(elemento), datos),
                    paginacion = json.decodeFromJsonElement(Paginacion.serializer(), paginacion),
                ),
            )
        }
    } catch (e: SerializationException) {
        Resultado.RespuestaRara(e.javaClass.simpleName, respuesta.codigo)
    } catch (e: IllegalArgumentException) {
        Resultado.RespuestaRara(e.javaClass.simpleName, respuesta.codigo)
    }

    /** Para lo que contesta 204 sin cuerpo, como `POST /auth/logout`. */
    private fun leerSinCuerpo(respuesta: RespuestaHttp): Resultado<Unit> =
        if (respuesta.codigo in 200..299) Resultado.Ok(Unit) else leerSobre(respuesta, Unit.serializer())

    /** El 401 que se arregla renovando. El encabezado dice por qué incluye `session_revoked`. */
    private fun esAccesoRechazado(r: Resultado<*>): Boolean =
        r is Resultado.Rechazado && r.http == 401 && r.codigo in CODIGOS_DE_ACCESO_RECHAZADO

    companion object {
        /**
         * Diez segundos. En el gimnasio la señal es mala pero no infinita: esperar
         * más deja a la persona mirando una rueda con el celular en la mano.
         */
        const val ESPERA_POR_DEFECTO_MS = 10_000

        /**
         * El prefijo de versión del contrato.
         *
         * `shared/api/openapi.yaml` declara `servers: https://{host}/v1`, y el
         * backend registra TODAS sus rutas con ese prefijo. Sin él, cada llamada
         * se lleva un 404 con el sobre de error bien formado, que es la peor
         * manera de fallar: parece que el servidor contestó que no.
         */
        const val PREFIJO_DEL_CONTRATO = "/v1"

        /**
         * El host de la máquina de desarrollo, visto desde el emulador de Android.
         * No es una constante caprichosa: `localhost` dentro del emulador es el
         * propio emulador; `10.0.2.2` es el loopback de la máquina que lo hospeda.
         *
         * La app ya no lo usa sola: la base sale de `BuildConfig.API_BASE`, y ésta
         * es la que hay que darle a `trainer.apiBase` para hablar con el backend
         * local (docs/CORRER-LOCAL.md §4).
         */
        const val BASE_EN_EL_EMULADOR = "http://10.0.2.2:8082" + PREFIJO_DEL_CONTRATO

        /**
         * Treinta segundos. Un access que vence antes de eso se renueva sin
         * mandarlo: con mala señal, ir y volver tarda más que eso, y llegaría vencido.
         */
        const val MARGEN_DE_RENOVACION_MS = 30_000L

        /**
         * Cuánto esperar antes de cada reintento de una renovación sin respuesta: 5, 15 y
         * 40 segundos, o sea a los 5, 20 y 60 del primer fallo. Todo tiene que entrar en
         * los dos minutos en los que el servidor todavía devuelve el mismo sucesor
         * (decisión 0013). Ver `reintentarMasTarde`.
         */
        private val ESPERAS_ENTRE_REINTENTOS_MS = listOf(5_000L, 15_000L, 40_000L)

        /**
         * Los 401 que pasan por la renovación: el access venció, o la sesión fue revocada.
         * El segundo no se arregla renovando —desde la decisión 0013 sólo llega con una
         * revocación de verdad—, pero la renovación lo confirma con el servidor por un
         * pedido más, o reintenta con el access que otro pedido ya renovó.
         */
        private val CODIGOS_DE_ACCESO_RECHAZADO = setOf("unauthorized", "session_revoked")

        /** Lo que la RENOVACIÓN contesta cuando la sesión ya no existe del otro lado. */
        private val CODIGOS_DE_SESION_TERMINADA = setOf("invalid_refresh_token", "session_revoked")

        /** Un pedido con sesión cuya sesión se cerró antes de salir: lo mismo que diría el servidor. */
        private val SIN_SESION = Resultado.Rechazado("unauthorized", "sin sesión en este cliente", 401)
    }
}

/** El cuerpo de `POST /auth/refresh` y de `POST /auth/logout`: el refresh y nada más. */
@Serializable
private class PedidoConRefresh(
    @SerialName("refresh_token")
    val refreshToken: String,
)

/**
 * Lo que puede pasar en una llamada. Son cuatro casos y ninguno es una excepción:
 * en una app que vive sin señal, "no hay red" es un resultado normal y la pantalla
 * tiene que poder decir algo distinto para cada uno.
 */
sealed interface Resultado<out T> {

    /** Salió bien. */
    data class Ok<T>(val dato: T) : Resultado<T>

    /**
     * El servidor contestó y dijo que no. `codigo` es el del contrato
     * (`invalid_credentials`, `email_taken`…) y es lo que la pantalla traduce:
     * `mensaje` es para el log del desarrollador y NO se muestra tal cual (§5).
     */
    data class Rechazado(val codigo: String, val mensaje: String, val http: Int) : Resultado<Nothing>

    /** No se pudo llegar al servidor. Sin señal, servidor caído, timeout. */
    data class SinRed(val causa: String) : Resultado<Nothing>

    /** Contestó algo que no es el sobre del contrato. Es un bug, de un lado o del otro. */
    data class RespuestaRara(val causa: String, val http: Int) : Resultado<Nothing>
}
