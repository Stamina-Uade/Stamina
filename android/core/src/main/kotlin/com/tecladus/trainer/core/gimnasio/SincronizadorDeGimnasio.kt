package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.Resultado
import com.tecladus.trainer.core.red.RutinaDelDia
import java.util.UUID
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Lo que la pantalla del gimnasio puede mostrar. Ninguno de los cuatro es una rutina inventada. */
sealed interface EstadoDelGimnasio {

    /** Todavía no se sabe: se lee el disco o se pide la rutina, y no hay una de hoy guardada. */
    data object Buscando : EstadoDelGimnasio

    /**
     * La rutina de hoy, con lo registrado de su sesión.
     *
     * @param sinSubir cuántas series no llegaron al servidor, sumando todas las sesiones.
     * @param sinConexion la última vez que se preguntó, el servidor no contestó: la rutina es
     *   la guardada.
     */
    data class ConRutina(
        val rutina: RutinaDelDia,
        val series: List<SerieRegistrada>,
        val sinSubir: Int,
        val sinConexion: Boolean,
    ) : EstadoDelGimnasio

    /** 🛑 No hay una rutina de hoy guardada y el servidor no contesta. Se dice así, tal cual. */
    data object SinRutinaNiConexion : EstadoDelGimnasio

    /**
     * El servidor contestó que no —por ejemplo `profile_incomplete`— y no hay una de hoy
     * guardada. [codigo] es el del contrato, para que la pantalla lo traduzca.
     */
    data class SinRutina(val codigo: String) : EstadoDelGimnasio
}

/**
 * El gimnasio con señal y sin señal (AGENTS.md §6): la rutina del día, las series que se
 * registran y la sincronización con el servidor (decisión 0006).
 *
 * - **La rutina** sale de `GET /plan/routine`, y la última buena queda en el [diario]. Sin
 *   red se muestra ésa si es la de hoy; si no hay, se dice que no hay. Nunca una de ejemplo.
 * - **Las series** quedan en el diario en el momento en que se registran ([registrar]): el
 *   sistema puede matar la app con el teléfono en el bolsillo y no se pierde ninguna.
 * - **Sincronizar** es, en este orden: SUBIR lo pendiente —con una clave por intento, la
 *   misma si ese intento se reintenta— y fusionar la sesión que contesta el servidor; y sólo
 *   sin nada pendiente, TRAER la sesión para ver lo del otro dispositivo.
 * - **Sin red**, lo pendiente queda pendiente y sube cuando vuelve la red o se abre la app.
 * - **Cerrar sesión lo borra todo**, por cualquier motivo: ver [AlmacenDeSesionQueBorraElGimnasio].
 *
 * 🛑 Uno por proceso, igual que el cliente de red: dos sobre el mismo diario serían dos
 * candados, y podrían mandar lo mismo pendiente con dos claves distintas.
 */
class SincronizadorDeGimnasio(
    private val api: ApiTrainer,
    private val diario: DiarioDeGimnasio,
    /** Donde corren las subidas que dispara una serie: siguen aunque la pantalla ya no esté. */
    private val alcance: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    /** Milisegundos epoch. Se inyecta para probar "hoy" y "ayer" sin esperar un día. */
    private val reloj: () -> Long = System::currentTimeMillis,
    /** Una clave de idempotencia nueva. Se inyecta para que los tests sepan cuál esperar. */
    private val nuevaClave: () -> String = { UUID.randomUUID().toString() },
) {

    /** Una sincronización a la vez: dos juntas mandarían lo mismo pendiente con dos claves. */
    private val unaALaVez = Mutex()

    /**
     * Las escrituras de la pantalla, de a una y en el orden en que llegan: una serie marcada
     * y enseguida corregida no puede quedar guardada al revés.
     */
    private val escritor: CoroutineDispatcher = Dispatchers.IO.limitedParallelism(1)

    private val busqueda = MutableStateFlow(Busqueda(TipoDeBusqueda.NINGUNA, generacion = -1))

    /** Lo que la pantalla muestra, cada vez que cambia el diario o termina una búsqueda. */
    val estado: Flow<EstadoDelGimnasio> =
        combine(diario.cambios, busqueda) { instantanea, b -> estadoDe(instantanea, b) }.distinctUntilChanged()

    /**
     * Todo, en el orden que importa: sube lo pendiente, trae la rutina de hoy y, sin nada
     * pendiente, lo que registró el otro dispositivo. Se llama al abrir la pantalla, al
     * volver a primer plano y cuando vuelve la red.
     */
    suspend fun sincronizar() {
        withContext(Dispatchers.IO) {
            unaALaVez.withLock {
                // Sin sesión no hay de quién sincronizar: cada pedido volvería con un "no" que
                // quedaría pintado en la pantalla de la cuenta que entre después.
                if (!api.haySesion()) return@withLock
                val generacion = diario.leer().generacion
                val alDia = subirTodo(generacion)
                val rutina = traerRutina(generacion) ?: return@withLock
                if (rutina.sessionId !in alDia) sincronizarSesion(rutina.sessionId, generacion)
                consultarZona(generacion)
            }
        }
    }

    /** Sólo lo pendiente. Sin red, no hace más que intentarlo; sin sesión, ni eso. */
    suspend fun subirPendientes() {
        withContext(Dispatchers.IO) {
            unaALaVez.withLock {
                if (api.haySesion()) subirTodo(diario.leer().generacion)
            }
        }
    }

    /**
     * Cuando vuelve la red: todo, en segundo plano, sin esperar a que alguien abra la
     * pantalla. Lo pendiente sube primero, como siempre, y una rutina que faltaba aparece sola.
     */
    fun volvioLaRed(): Job = alcance.launch { sincronizar() }

    /**
     * Guarda las series que cambió la pantalla y, si hay red, las sube.
     *
     * No suspende: la pantalla lo llama en cada tilde. Guarda fuera del hilo principal, de a
     * una y en orden, y la subida sigue aunque la pantalla se cierre.
     *
     * Si la rutina guardada ya no es la de [sesionId] —se cerró la sesión, o llegó la de otro
     * día— no guarda nada: esas series no son de ninguna rutina que se esté mostrando, y
     * guardarlas sería dejarle a la cuenta siguiente series de otra.
     *
     * @return el trabajo, para quien necesite esperarlo. La pantalla no lo espera.
     */
    fun registrar(sesionId: String, cambios: List<SerieRegistrada>): Job? {
        if (cambios.isEmpty()) return null
        return alcance.launch(escritor) {
            val generacion = diario.leer().generacion
            diario.cambiar(generacion) { c ->
                if (c.rutina?.sessionId != sesionId) c else c.conCambiosLocales(sesionId, cambios)
            }
            subirPendientes()
        }
    }

    // ------------------------------------------------------------ por dentro --

    /** Sube lo pendiente de cada sesión. Devuelve las sesiones que quedaron al día. */
    private suspend fun subirTodo(generacion: Long): Set<String> {
        val conAlgo = diario.leer().contenido.sesiones.filterValues { it.tieneAlgoSinSubir }.keys
        val alDia = HashSet<String>()
        for (sesionId in conAlgo) {
            when (subir(sesionId, generacion)) {
                Subida.SUBIO -> alDia += sesionId
                // Sin red para una es sin red para todas, y un diario borrado no tiene nada más.
                Subida.SIN_RED, Subida.CANCELADA -> return alDia
                Subida.NADA, Subida.RECHAZADA -> Unit
            }
        }
        return alDia
    }

    /**
     * 🛑 **Primero lo pendiente, y sólo sin nada pendiente se trae** (decisión 0006, y la
     * descripción de `POST .../sets` en el contrato). Lo que llegó al servidor le gana a lo
     * que no llegó: traer con algo sin subir le haría perder al teléfono sus cambios. Subir
     * ya trae, porque la respuesta es la sesión entera.
     */
    private suspend fun sincronizarSesion(sesionId: String, generacion: Long) {
        if (subir(sesionId, generacion) == Subida.NADA) traer(sesionId, generacion)
    }

    private suspend fun subir(sesionId: String, generacion: Long): Subida {
        var resultado = Subida.NADA
        repeat(RONDAS_POR_SESION) {
            var intento: EnvioEnCurso? = null
            val vigente = diario.cambiar(generacion) { c ->
                val sesion = c.sesiones[sesionId]
                val pendiente = sesion?.envio
                when {
                    sesion == null -> c
                    // El intento que ya salió se repite igual: misma clave, mismo cuerpo.
                    pendiente != null -> c.also { intento = pendiente }
                    else -> {
                        val series = sesion.series.filter { it.pendiente }.take(MAXIMO_POR_ENVIO)
                        if (series.isEmpty()) {
                            c
                        } else {
                            val nuevo = EnvioEnCurso(nuevaClave(), series)
                            intento = nuevo
                            // 🛑 La clave queda en el disco ANTES de salir: si la app muere con el
                            // pedido en el aire, el reintento sale con la misma.
                            c.conSesion(sesionId, sesion.copy(envio = nuevo))
                        }
                    }
                }
            }
            if (!vigente) return Subida.CANCELADA
            val envio = intento ?: return resultado

            val r = api.sincronizarSeries(sesionId, envio.series.map(SeriesDeLaRutina::entradaDe), envio.clave)
            when {
                r is Resultado.Ok -> {
                    val delServidor = r.dato.sets.map(SeriesDeLaRutina::registradaDe)
                    val guardado = diario.cambiar(generacion) {
                        it.conRespuesta(sesionId, delServidor, llevadas = envio.series, cierraElEnvio = true)
                    }
                    if (!guardado) return Subida.CANCELADA
                    resultado = Subida.SUBIO
                }
                // Queda el intento, con su clave, para la próxima.
                seReintenta(r) -> return Subida.SIN_RED
                else -> {
                    // Un 400 no se arregla mandando lo mismo: se suelta el intento. Las series
                    // siguen pendientes y salen en otro, con otra clave.
                    diario.cambiar(generacion) { it.sinEnvio(sesionId) }
                    return Subida.RECHAZADA
                }
            }
        }
        return resultado
    }

    /** Trae la sesión. Sólo se llama sin nada pendiente: ver [sincronizarSesion]. */
    private suspend fun traer(sesionId: String, generacion: Long) {
        val instantanea = diario.leer()
        if (instantanea.generacion != generacion) return
        val pendientesAlSalir = instantanea.contenido.sesiones[sesionId]?.series.orEmpty().filter { it.pendiente }
        when (val r = api.sesionDeGimnasio(sesionId)) {
            is Resultado.Ok -> diario.cambiar(generacion) {
                it.conRespuesta(
                    sesionId,
                    r.dato.sets.map(SeriesDeLaRutina::registradaDe),
                    llevadas = pendientesAlSalir,
                    cierraElEnvio = false,
                )
            }
            // `not_found` es una sesión en la que nadie registró nada. Sin red, será la próxima.
            else -> Unit
        }
    }

    private suspend fun traerRutina(generacion: Long): RutinaDelDia? =
        when (val r = api.rutinaDelDia(reloj())) {
            is Resultado.Ok -> {
                if (diario.cambiar(generacion) { it.conRutina(r.dato) }) {
                    busqueda.value = Busqueda(TipoDeBusqueda.LISTA, generacion)
                    r.dato
                } else {
                    null
                }
            }
            is Resultado.SinRed -> null.also { busqueda.value = Busqueda(TipoDeBusqueda.SIN_RED, generacion) }
            is Resultado.Rechazado ->
                null.also { busqueda.value = Busqueda(TipoDeBusqueda.RECHAZADA, generacion, r.codigo) }
            is Resultado.RespuestaRara ->
                null.also { busqueda.value = Busqueda(TipoDeBusqueda.RECHAZADA, generacion, CODIGO_RESPUESTA_RARA) }
        }

    /**
     * La zona del perfil, una sola vez: es lo que dice, sin red, si la rutina guardada es la
     * de hoy (ver [idDeSesionDeGimnasio]). Si falla, se vuelve a preguntar la próxima.
     */
    private suspend fun consultarZona(generacion: Long) {
        if (diario.leer().contenido.zonaConsultada) return
        val perfil = api.miPerfil() as? Resultado.Ok ?: return
        diario.cambiar(generacion) { it.copy(zona = perfil.dato.timezone, zonaConsultada = true) }
    }

    private fun estadoDe(instantanea: DiarioDeGimnasio.Instantanea?, b: Busqueda): EstadoDelGimnasio {
        val contenido = instantanea?.contenido ?: return EstadoDelGimnasio.Buscando
        // Una búsqueda de antes de cerrar sesión no dice nada de este diario.
        val tipo = if (b.generacion == instantanea.generacion) b.tipo else TipoDeBusqueda.NINGUNA
        val rutina = contenido.rutina?.takeIf {
            // Recién llegada es la de hoy por definición: la pidió con "ahora". Guardada, sólo
            // si su sesión es la de hoy en la zona del perfil.
            tipo == TipoDeBusqueda.LISTA || it.sessionId == idDeSesionDeGimnasio(reloj(), contenido.zona)
        }
        return when {
            rutina != null -> EstadoDelGimnasio.ConRutina(
                rutina = rutina,
                series = contenido.sesiones[rutina.sessionId]?.series.orEmpty(),
                sinSubir = contenido.sinSubir,
                sinConexion = tipo == TipoDeBusqueda.SIN_RED,
            )
            tipo == TipoDeBusqueda.SIN_RED -> EstadoDelGimnasio.SinRutinaNiConexion
            tipo == TipoDeBusqueda.RECHAZADA -> EstadoDelGimnasio.SinRutina(b.codigo ?: CODIGO_RESPUESTA_RARA)
            else -> EstadoDelGimnasio.Buscando
        }
    }

    /**
     * Lo que se arregla solo con el tiempo, repitiendo el MISMO intento: sin red, un servidor
     * caído o apurado, el mismo intento todavía en vuelo (409), una sesión que se está
     * renovando. Una respuesta ilegible también: con la misma clave, el servidor contesta lo
     * que ya contestó, sin escribir otra vez.
     */
    private fun seReintenta(r: Resultado<*>): Boolean = when (r) {
        is Resultado.Ok -> false
        is Resultado.SinRed -> true
        is Resultado.RespuestaRara -> true
        is Resultado.Rechazado -> r.http == 401 || r.http == 408 || r.http == 409 || r.http == 429 || r.http >= 500
    }

    private enum class Subida { NADA, SUBIO, SIN_RED, RECHAZADA, CANCELADA }

    private enum class TipoDeBusqueda { NINGUNA, LISTA, SIN_RED, RECHAZADA }

    private data class Busqueda(val tipo: TipoDeBusqueda, val generacion: Long, val codigo: String? = null)

    companion object {
        /** El `maxItems` del cuerpo de `POST .../sets` en el contrato. */
        const val MAXIMO_POR_ENVIO = 200

        /** Cuántos envíos seguidos por sesión: lo que se marca mientras viaja uno sale en el siguiente. */
        private const val RONDAS_POR_SESION = 5

        /** El código que ve la pantalla cuando el servidor contestó algo que no es el contrato. */
        const val CODIGO_RESPUESTA_RARA = "respuesta_rara"
    }
}

// ---------------------------------------------------- cambios del contenido --

internal fun ContenidoDelDiario.conSesion(sesionId: String, sesion: SeriesDeSesion): ContenidoDelDiario =
    copy(sesiones = sesiones + (sesionId to sesion))

/**
 * La rutina nueva, y el diario podado: queda la sesión de esta rutina y las que tienen algo
 * sin subir. Lo demás ya está en el servidor, y guardar de más datos de salud no sirve para
 * nada (AGENTS.md §8, mínimo dato posible).
 */
internal fun ContenidoDelDiario.conRutina(rutina: RutinaDelDia): ContenidoDelDiario = copy(
    rutina = rutina,
    sesiones = sesiones.filter { (id, sesion) -> id == rutina.sessionId || sesion.tieneAlgoSinSubir },
)

/**
 * Lo que cambió en la pantalla. Un cambio local REEMPLAZA a la fila, no se fusiona: es lo
 * último que quiso la persona en este teléfono y todavía no llegó a ningún lado. Se fusiona
 * cuando vuelve del servidor.
 */
internal fun ContenidoDelDiario.conCambiosLocales(sesionId: String, cambios: List<SerieRegistrada>): ContenidoDelDiario {
    val sesion = sesiones[sesionId] ?: SeriesDeSesion()
    val porClave = sesion.series.associateByTo(LinkedHashMap()) { it.clave }
    for (cambio in cambios) porClave[cambio.clave] = cambio
    return conSesion(sesionId, sesion.copy(series = ordenadas(porClave.values)))
}

internal fun ContenidoDelDiario.sinEnvio(sesionId: String): ContenidoDelDiario {
    val sesion = sesiones[sesionId] ?: return this
    return conSesion(sesionId, sesion.copy(envio = null))
}

/**
 * La sesión que contestó el servidor, fusionada con lo que hay.
 *
 * @param llevadas lo pendiente de lo que la respuesta ya sabe: en un POST, lo que se mandó;
 *   en un GET, lo que estaba pendiente cuando salió. Para eso manda la fusión de siempre.
 *   Lo pendiente que el pedido NO llevaba —una serie marcada mientras viajaba— se conserva
 *   tal cual y sale en el próximo envío: fusionado, la copia del servidor le ganaría por
 *   haber llegado, y se perdería un cambio que nunca se mandó.
 */
internal fun ContenidoDelDiario.conRespuesta(
    sesionId: String,
    delServidor: List<SerieRegistrada>,
    llevadas: List<SerieRegistrada>,
    cierraElEnvio: Boolean,
): ContenidoDelDiario {
    val sesion = sesiones[sesionId] ?: SeriesDeSesion()
    val sabidas = llevadas.toHashSet()
    val sinLlevar = sesion.series.filter { it.pendiente && it !in sabidas }.toHashSet()
    val clavesSinLlevar = sinLlevar.mapTo(HashSet()) { it.clave }
    val fusionadas = FusionDeSeries.unir(sesion.series.filter { it !in sinLlevar }, delServidor)
        .filter { it.clave !in clavesSinLlevar }
    return conSesion(
        sesionId,
        SeriesDeSesion(
            series = ordenadas(fusionadas + sinLlevar),
            envio = if (cierraElEnvio) null else sesion.envio,
        ),
    )
}

/** El orden de la pantalla y del servidor: por ejercicio y número. */
private fun ordenadas(series: Collection<SerieRegistrada>): List<SerieRegistrada> =
    series.sortedWith(compareBy<SerieRegistrada> { it.ejercicioId }.thenBy { it.numero })
