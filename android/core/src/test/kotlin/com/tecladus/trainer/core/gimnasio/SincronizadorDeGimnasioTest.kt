package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.AHORA
import com.tecladus.trainer.core.red.AlmacenDeSesionEnMemoria
import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.BASE
import com.tecladus.trainer.core.red.ClienteApi
import com.tecladus.trainer.core.red.DispositivoDeOrigen
import com.tecladus.trainer.core.red.DispositivoDeOrigen.RELOJ
import com.tecladus.trainer.core.red.DispositivoDeOrigen.TELEFONO
import com.tecladus.trainer.core.red.PedidoHttp
import com.tecladus.trainer.core.red.RespuestaHttp
import com.tecladus.trainer.core.red.RutinaDelDia
import com.tecladus.trainer.core.red.SerieDeGimnasio
import com.tecladus.trainer.core.red.SerieDeGimnasioEntrada
import com.tecladus.trainer.core.red.Sesion
import com.tecladus.trainer.core.red.SesionDeGimnasio
import com.tecladus.trainer.core.red.ServidorDeMentira
import com.tecladus.trainer.core.red.rechazo
import com.tecladus.trainer.core.red.respuestaConSesion
import com.tecladus.trainer.core.red.respuestaOk
import com.tecladus.trainer.core.red.ruta
import com.tecladus.trainer.core.red.sesionDePrueba
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * El gimnasio sin señal y con señal, contra un servidor de mentira que fusiona como el de
 * verdad: offline primero (AGENTS.md §6), la decisión 0006 del lado del teléfono, y el
 * borrado al cerrar sesión.
 *
 * Tres de estos tests cuidan algo que, si se rompe, rompe en silencio:
 * - `lo pendiente sube antes de traer...`: traer antes de subir pisa un cambio sin mandar.
 * - `si la respuesta se perdio...`: otra clave en el reintento escribiría dos veces.
 * - `cerrar sesion borra...` y los que siguen: la cuenta siguiente vería, o subiría, lo de otra.
 */
class SincronizadorDeGimnasioTest {

    // ------------------------------------------------------------- la rutina --

    @Test
    fun `sin nada guardado y sin red, dice que no hay rutina de hoy y no inventa una`() = runBlocking {
        val m = Mundo(alcance = this)
        m.api.restaurarSesion()
        m.servidor.sinRed = true

        m.sincronizador.sincronizar()

        assertEquals(EstadoDelGimnasio.SinRutinaNiConexion, m.sincronizador.estado.first())
    }

    @Test
    fun `la rutina que llego queda guardada y se muestra sin red al volver a abrir la app`() = runBlocking {
        val servidor = ServidorDeGimnasio()
        val disco = AlmacenDeGimnasioEnMemoria()
        val antes = Mundo(servidor, disco, alcance = this)
        antes.api.restaurarSesion()
        antes.sincronizador.sincronizar()
        assertTrue(antes.sincronizador.estado.first() is EstadoDelGimnasio.ConRutina)

        // El sistema mató la app, y se vuelve a abrir en el sótano del gimnasio.
        servidor.sinRed = true
        val despues = Mundo(servidor, disco, alcance = this)
        despues.api.restaurarSesion()
        despues.sincronizador.sincronizar()

        val estado = despues.sincronizador.estado.first()
        assertTrue(estado.javaClass.simpleName, estado is EstadoDelGimnasio.ConRutina)
        estado as EstadoDelGimnasio.ConRutina
        assertEquals("gym-2026-09-10", estado.rutina.sessionId)
        assertEquals(6, estado.rutina.exercises.size)
        assertTrue("y dice que es la guardada", estado.sinConexion)
    }

    @Test
    fun `una rutina guardada de otro dia no se muestra como la de hoy`() = runBlocking {
        val servidor = ServidorDeGimnasio()
        val disco = AlmacenDeGimnasioEnMemoria()
        val ayer = Mundo(servidor, disco, alcance = this)
        ayer.api.restaurarSesion()
        ayer.sincronizador.sincronizar()

        servidor.sinRed = true
        val hoy = Mundo(servidor, disco, alcance = this, hoy = HOY + UN_DIA)
        hoy.api.restaurarSesion()
        hoy.sincronizador.sincronizar()

        assertEquals(EstadoDelGimnasio.SinRutinaNiConexion, hoy.sincronizador.estado.first())
    }

    @Test
    fun `un perfil incompleto se dice como tal y no como falta de red`() = runBlocking {
        val m = Mundo(alcance = this)
        m.api.restaurarSesion()
        m.servidor.contestarRutina = { RespuestaHttp(400, respuestaReal("error-profile-incomplete")) }

        m.sincronizador.sincronizar()

        assertEquals(EstadoDelGimnasio.SinRutina("profile_incomplete"), m.sincronizador.estado.first())
    }

    // ------------------------------------------------------------ las series --

    @Test
    fun `una serie registrada queda en el disco al instante, y sin red queda pendiente con su intento`() = runBlocking {
        val m = conRutina()
        m.servidor.sinRed = true

        m.sincronizador.registrar("gym-2026-09-10", listOf(serie()))?.join()

        val guardada = requireNotNull(m.disco.guardado).sesiones.getValue("gym-2026-09-10")
        assertEquals(listOf(serie()), guardada.series)
        assertEquals("el intento quedó con su clave, para repetirlo igual", EnvioEnCurso("clave-1", listOf(serie())), guardada.envio)
        assertEquals(1, (m.sincronizador.estado.first() as EstadoDelGimnasio.ConRutina).sinSubir)
    }

    @Test
    fun `si la respuesta se perdio, el reintento sale con la misma clave y el mismo cuerpo`() = runBlocking {
        val m = conRutina()
        // El servidor lo aplica, y la respuesta no llega: para el teléfono es igual que sin red.
        m.servidor.cortarDespuesDeAplicar = true

        m.sincronizador.registrar("gym-2026-09-10", listOf(serie()))?.join()
        assertEquals("clave-1", requireNotNull(m.disco.guardado).sesiones.getValue("gym-2026-09-10").envio?.clave)

        m.sincronizador.sincronizar()

        val envios = m.servidor.transporte.deLaRuta(SETS)
        assertEquals(listOf("clave-1", "clave-1"), envios.map { it.headers["Idempotency-Key"] })
        assertEquals(envios[0].cuerpo, envios[1].cuerpo)
        assertEquals("el servidor no la escribió dos veces", 1, m.servidor.aplicados)
        val sesion = requireNotNull(m.disco.guardado).sesiones.getValue("gym-2026-09-10")
        assertNull("el intento terminó", sesion.envio)
        assertTrue("y la serie ya llegó", sesion.series.single().recibidaEnServidorMs != null)

        m.sincronizador.registrar("gym-2026-09-10", listOf(serie(numero = 2)))?.join()
        assertEquals("otro intento, otra clave", "clave-2", m.servidor.transporte.deLaRuta(SETS).last().headers["Idempotency-Key"])
    }

    @Test
    fun `un intento sin respuesta se repite igual aunque despues se hayan marcado otras series`() = runBlocking {
        val m = conRutina()
        m.servidor.sinRed = true
        m.sincronizador.registrar("gym-2026-09-10", listOf(serie(numero = 1)))?.join()
        m.sincronizador.registrar("gym-2026-09-10", listOf(serie(numero = 2)))?.join()

        m.servidor.sinRed = false
        m.sincronizador.sincronizar()

        val envios = m.servidor.transporte.deLaRuta(SETS)
        assertEquals(listOf("clave-1", "clave-1", "clave-1", "clave-2"), envios.map { it.headers["Idempotency-Key"] })
        assertEquals("el mismo intento, el mismo cuerpo", 1, envios.take(3).map { it.cuerpo }.distinct().size)
        assertEquals(listOf(1), numerosEn(envios[2]))
        assertEquals("la serie marcada después sale en el siguiente", listOf(2), numerosEn(envios[3]))
        assertEquals(2, m.servidor.sesiones.getValue("gym-2026-09-10").size)
        assertEquals(0, (m.sincronizador.estado.first() as EstadoDelGimnasio.ConRutina).sinSubir)
    }

    @Test
    fun `lo que no subio ayer sube igual aunque hoy la rutina sea otra`() = runBlocking {
        val m = conRutina()
        m.servidor.sinRed = true
        m.sincronizador.registrar("gym-2026-09-10", listOf(serie()))?.join()

        // Al día siguiente, con señal: la rutina ya es la del 11.
        m.servidor.sinRed = false
        m.hoy = HOY + UN_DIA
        m.servidor.contestarRutina = { RespuestaHttp(200, respuestaReal("rutina-con-series-previas")) }
        m.sincronizador.sincronizar()

        assertEquals(1, m.servidor.sesiones.getValue("gym-2026-09-10").size)
        val guardado = requireNotNull(m.disco.guardado)
        assertEquals("gym-2026-09-11", guardado.rutina?.sessionId)
        assertFalse("la de ayer ya está en el servidor: no se guarda de más", "gym-2026-09-10" in guardado.sesiones)
    }

    @Test
    fun `registrar para una rutina que ya no esta no guarda nada`() = runBlocking {
        val m = conRutina()

        m.sincronizador.registrar("gym-2026-09-09", listOf(serie()))?.join()

        assertFalse("gym-2026-09-09" in requireNotNull(m.disco.guardado).sesiones)
    }

    // ------------------------------------------------ subir antes de traer --

    @Test
    fun `lo pendiente sube antes de traer, y una copia vieja del servidor no pisa un cambio sin subir`() = runBlocking {
        // En el servidor, el reloj anotó 8 repeticiones en la zancada, y además la extensión.
        val servidor = ServidorDeGimnasio().apply {
            sesiones["gym-2026-09-10"] = listOf(
                serie(reps = 8, servidor = 100, de = RELOJ),
                serie(ejercicio = "extension-lumbar", pesoG = null, servidor = 100, de = RELOJ),
            )
        }
        // En el teléfono, sin subir, la corrigió a 10: con un reloj local más viejo que esa llegada.
        val disco = discoConPendiente(serie(reps = 10, local = 50))
        val m = Mundo(servidor, disco, alcance = this)
        m.api.restaurarSesion()

        m.sincronizador.sincronizar()

        val delGimnasio = m.servidor.transporte.rutas().filter { it.startsWith("/gym/") }
        assertEquals("lo primero que sale es la subida", SETS, delGimnasio.first())
        val enElTelefono = requireNotNull(m.disco.guardado).sesiones.getValue("gym-2026-09-10").series
        val zancada = enElTelefono.single { it.ejercicioId == "estocada-deficit" }
        assertEquals("la copia vieja del servidor no pisó el cambio sin subir", 10, zancada.repeticiones)
        assertTrue("y ahora ya llegó", zancada.recibidaEnServidorMs != null)
        assertEquals(10, m.servidor.sesiones.getValue("gym-2026-09-10").single { it.ejercicioId == "estocada-deficit" }.repeticiones)
        assertTrue("lo del reloj también está", enElTelefono.any { it.ejercicioId == "extension-lumbar" })
    }

    @Test
    fun `si lo pendiente no pudo subir, no se trae la sesion`() = runBlocking {
        val servidor = ServidorDeGimnasio().apply {
            sesiones["gym-2026-09-10"] = listOf(serie(reps = 8, servidor = 100, de = RELOJ))
            contestarSets = { rechazo(503, "unavailable") }
        }
        val disco = discoConPendiente(serie(reps = 10, local = 50))
        val m = Mundo(servidor, disco, alcance = this)
        m.api.restaurarSesion()

        m.sincronizador.sincronizar()

        assertEquals("con algo sin subir no se trae", 0, m.servidor.transporte.cuantos("/gym/sessions/gym-2026-09-10"))
        val sesion = requireNotNull(m.disco.guardado).sesiones.getValue("gym-2026-09-10")
        assertEquals(listOf(serie(reps = 10, local = 50)), sesion.series)
        assertEquals("y el intento sigue, para repetirlo igual", "clave-1", sesion.envio?.clave)
    }

    // --------------------------------------------------- cerrar sesión --

    @Test
    fun `cerrar sesion borra la rutina, lo pendiente y el intento en curso`() = runBlocking {
        val m = conRutina()
        m.servidor.sinRed = true
        m.sincronizador.registrar("gym-2026-09-10", listOf(serie()))?.join()
        assertEquals(1, requireNotNull(m.disco.guardado).sinSubir)

        m.api.cerrarSesion()

        assertNull("el disco quedó vacío", m.disco.guardado)
        assertEquals(ContenidoDelDiario(), m.diario.leer().contenido)
        assertEquals(EstadoDelGimnasio.Buscando, m.sincronizador.estado.first())
    }

    @Test
    fun `una sesion que el servidor da por terminada tambien borra el gimnasio`() = runBlocking {
        val m = conRutina()
        m.servidor.sinRed = true
        m.sincronizador.registrar("gym-2026-09-10", listOf(serie()))?.join()
        // El access venció y el refresh ya no sirve: el cliente cierra la sesión solo y avisa
        // por `sesionCerrada`, sin que ninguna pantalla llame a nada.
        m.servidor.sinRed = false
        m.servidor.contestarSets = { rechazo(401, "unauthorized") }
        m.servidor.contestarRefresh = { rechazo(401, "invalid_refresh_token") }

        m.sincronizador.sincronizar()

        assertFalse(m.api.haySesion())
        assertNull(m.disco.guardado)
        assertEquals(ContenidoDelDiario(), m.diario.leer().contenido)
    }

    @Test
    fun `olvidar la sesion tambien borra el gimnasio`() = runBlocking {
        val m = conRutina()

        m.api.olvidarSesion()

        assertNull(m.disco.guardado)
    }

    @Test
    fun `sin sesion guardada al arrancar no queda el gimnasio de nadie`() = runBlocking {
        val disco = discoConPendiente(serie())
        val m = Mundo(disco = disco, sesionGuardada = null, alcance = this)

        assertFalse(m.api.restaurarSesion())

        assertNull(disco.guardado)
    }

    @Test
    fun `lo que vuelve de la red despues de cerrar sesion no escribe nada`() = runBlocking {
        val m = Mundo(alcance = this)
        m.api.restaurarSesion()
        val pidioLaRutina = CompletableDeferred<Unit>()
        val contestar = CompletableDeferred<Unit>()
        m.servidor.contestarRutina = {
            pidioLaRutina.complete(Unit)
            contestar.await()
            RespuestaHttp(200, respuestaReal("rutina-del-dia"))
        }
        val sincronizacion = launch { m.sincronizador.sincronizar() }
        pidioLaRutina.await()

        m.api.olvidarSesion()
        contestar.complete(Unit)
        sincronizacion.join()

        assertNull("la rutina de la cuenta que se fue no volvió al disco", m.disco.guardado)
        assertEquals(ContenidoDelDiario(), m.diario.leer().contenido)
    }

    @Test
    fun `sin sesion no sale ningun pedido, ni cuando vuelve la red`() = runBlocking {
        val m = Mundo(sesionGuardada = null, alcance = this)
        m.api.restaurarSesion()

        m.sincronizador.volvioLaRed().join()
        m.sincronizador.subirPendientes()

        assertTrue(m.servidor.transporte.pedidos.isEmpty())
        assertEquals(EstadoDelGimnasio.Buscando, m.sincronizador.estado.first())
    }

    // ------------------------------------------------------------ andamiaje --

    /** Todo lo de un proceso: servidor, disco, sesión, diario y sincronizador. */
    private class Mundo(
        val servidor: ServidorDeGimnasio = ServidorDeGimnasio(),
        val disco: AlmacenDeGimnasioEnMemoria = AlmacenDeGimnasioEnMemoria(),
        sesionGuardada: Sesion? = sesionDePrueba(1),
        alcance: CoroutineScope,
        @Volatile var hoy: Long = HOY,
    ) {
        val diario = DiarioDeGimnasio(disco)
        val api = ApiTrainer(
            ClienteApi(
                BASE,
                AlmacenDeSesionQueBorraElGimnasio(AlmacenDeSesionEnMemoria(sesionGuardada), diario),
                servidor.transporte,
                reloj = { AHORA },
            ),
        )
        private var claves = 0
        val sincronizador = SincronizadorDeGimnasio(
            api = api,
            diario = diario,
            alcance = alcance,
            reloj = { hoy },
            nuevaClave = { "clave-${++claves}" },
        )
    }

    private suspend fun CoroutineScope.conRutina(): Mundo {
        val m = Mundo(alcance = this)
        m.api.restaurarSesion()
        m.sincronizador.sincronizar()
        return m
    }

    private fun discoConPendiente(pendiente: SerieRegistrada) = AlmacenDeGimnasioEnMemoria(
        ContenidoDelDiario(
            rutina = rutinaReal(),
            zona = "America/Argentina/Buenos_Aires",
            zonaConsultada = true,
            sesiones = mapOf("gym-2026-09-10" to SeriesDeSesion(listOf(pendiente))),
        ),
    )

    private fun numerosEn(pedido: PedidoHttp): List<Int> =
        JSON.decodeFromString(CuerpoDeSeries.serializer(), requireNotNull(pedido.cuerpo)).sets.map { it.number }

    private companion object {
        /** Las 9:45 del 10 de septiembre de 2026 en Buenos Aires: el día de la rutina real. */
        const val HOY = 1_789_033_542_979L
        const val UN_DIA = 24 * 60 * 60 * 1000L
        const val SETS = "/gym/sessions/gym-2026-09-10/sets"
        val JSON = Json { ignoreUnknownKeys = true; explicitNulls = false }

        fun respuestaReal(nombre: String): String =
            requireNotNull(SincronizadorDeGimnasioTest::class.java.getResource("/respuestas-1.1.0/$nombre.json")).readText()

        fun rutinaReal(): RutinaDelDia = JSON.decodeFromJsonElement(
            RutinaDelDia.serializer(),
            JSON.parseToJsonElement(respuestaReal("rutina-del-dia")).jsonObject.getValue("data"),
        )

        fun serie(
            ejercicio: String = "estocada-deficit",
            numero: Int = 1,
            reps: Int = 10,
            pesoG: Int? = 12_000,
            local: Long = HOY,
            servidor: Long? = null,
            de: DispositivoDeOrigen = TELEFONO,
        ) = SerieRegistrada(
            ejercicioId = ejercicio,
            numero = numero,
            hecha = true,
            repeticiones = reps,
            pesoG = pesoG,
            salteada = false,
            esExtra = false,
            registradaLocalMs = local,
            recibidaEnServidorMs = servidor,
            dispositivo = de,
        )
    }
}

@Serializable
private data class CuerpoDeSeries(val sets: List<SerieDeGimnasioEntrada>)

/**
 * Un servidor de gimnasio que se porta como el de verdad en lo que importa acá: fusiona lo
 * que le mandan con la MISMA fusión, le pone la hora de llegada, devuelve la sesión entera,
 * y respeta la `Idempotency-Key` —la misma clave con el mismo cuerpo devuelve la misma
 * respuesta sin volver a escribir; con otro cuerpo, 409—.
 */
private class ServidorDeGimnasio {

    val sesiones = HashMap<String, List<SerieRegistrada>>()

    /** Cuántos lotes escribió de verdad. Un reintento con la misma clave no suma. */
    var aplicados = 0
        private set

    @Volatile
    var sinRed = false

    /** Aplica el próximo lote y corta antes de contestar: la respuesta se pierde en el camino. */
    @Volatile
    var cortarDespuesDeAplicar = false

    var contestarRutina: suspend () -> RespuestaHttp = {
        RespuestaHttp(200, requireNotNull(javaClass.getResource("/respuestas-1.1.0/rutina-del-dia.json")).readText())
    }
    var contestarSets: ((PedidoHttp) -> RespuestaHttp)? = null
    var contestarRefresh: () -> RespuestaHttp = { respuestaConSesion(sesionDePrueba(2)) }

    private var llegada = 1_000L
    private val porClave = HashMap<String, Pair<String, String>>()
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    val transporte = ServidorDeMentira { pedido -> atender(pedido) }

    private suspend fun atender(pedido: PedidoHttp): RespuestaHttp {
        if (sinRed) throw IOException("sin red")
        val ruta = pedido.ruta
        return when {
            ruta.startsWith("/plan/routine") -> contestarRutina()
            ruta == "/me" -> respuestaOk(
                """{"id":"u_1","email":"a@b.c","created_at_ms":1,"updated_at_ms":2,"timezone":"America/Argentina/Buenos_Aires"}""",
            )
            ruta == "/auth/refresh" -> contestarRefresh()
            ruta == "/auth/logout" -> RespuestaHttp(204, "")
            ruta.startsWith("/gym/sessions/") && ruta.endsWith("/sets") -> contestarSets?.invoke(pedido) ?: subir(pedido)
            ruta.startsWith("/gym/sessions/") -> traer(ruta.removePrefix("/gym/sessions/"))
            else -> error("ruta inesperada: $ruta")
        }
    }

    private fun subir(pedido: PedidoHttp): RespuestaHttp = synchronized(this) {
        val id = pedido.ruta.removePrefix("/gym/sessions/").removeSuffix("/sets")
        val clave = requireNotNull(pedido.headers["Idempotency-Key"]) { "un POST de series sin clave" }
        val cuerpo = requireNotNull(pedido.cuerpo)
        porClave[clave]?.let { (cuerpoDeAntes, respuesta) ->
            return if (cuerpoDeAntes == cuerpo) RespuestaHttp(200, respuesta) else rechazo(409, "idempotency_conflict")
        }
        llegada += 1
        val entrantes = json.decodeFromString(CuerpoDeSeries.serializer(), cuerpo).sets.map {
            SerieRegistrada(it.exerciseId, it.number, it.done, it.reps, it.weightG, it.skipped, it.isExtra, it.recordedAtMs, llegada, it.device)
        }
        val unidas = FusionDeSeries.unir(sesiones[id].orEmpty(), entrantes)
        sesiones[id] = unidas
        aplicados += 1
        val respuesta = sobre(id, unidas)
        porClave[clave] = cuerpo to respuesta
        if (cortarDespuesDeAplicar) {
            cortarDespuesDeAplicar = false
            throw IOException("la respuesta se perdió en el camino")
        }
        RespuestaHttp(200, respuesta)
    }

    private fun traer(id: String): RespuestaHttp = synchronized(this) {
        val series = sesiones[id] ?: return rechazo(404, "not_found")
        RespuestaHttp(200, sobre(id, series))
    }

    private fun sobre(id: String, series: List<SerieRegistrada>): String {
        val sesion = SesionDeGimnasio(
            sessionId = id,
            updatedAtMs = llegada,
            sets = series.map {
                SerieDeGimnasio(
                    exerciseId = it.ejercicioId,
                    number = it.numero,
                    done = it.hecha,
                    reps = it.repeticiones,
                    weightG = it.pesoG,
                    skipped = it.salteada,
                    isExtra = it.esExtra,
                    recordedAtMs = it.registradaLocalMs,
                    receivedAtMs = requireNotNull(it.recibidaEnServidorMs),
                    device = it.dispositivo,
                )
            },
        )
        return """{"data":${json.encodeToString(SesionDeGimnasio.serializer(), sesion)}}"""
    }
}
