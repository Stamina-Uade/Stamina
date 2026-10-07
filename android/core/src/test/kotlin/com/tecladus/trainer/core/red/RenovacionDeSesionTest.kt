package com.tecladus.trainer.core.red

import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * B-008, hecho fallar (docs/BLOQUEOS.md).
 *
 * El servidor rota el refresh en cada uso. Un refresh ya canjeado que vuelve dentro de
 * los dos minutos, con el sucesor sin usar, recibe ese mismo sucesor; fuera de eso es
 * un reuso y revoca la familia entera (decisión 0013). Casi todo lo de acá prueba
 * alguna forma de que el cliente NO mande el mismo refresh dos veces a la vez; el
 * resto, que cuando la sesión muere de verdad lo diga y no la deje guardada, y que
 * cuando no muere no la mate. Los reintentos de una renovación que se quedó sin
 * respuesta están en [ReintentoDeRenovacionTest].
 *
 * Corre en la JVM contra [ServidorDeMentira]: nada de esto necesita un servidor.
 */
class RenovacionDeSesionTest {

    private fun cliente(
        almacen: AlmacenDeSesion,
        servidor: Transporte,
        reloj: () -> Long = { AHORA },
    ) = ClienteApi(BASE, almacen, servidor, reloj = reloj)

    // --------------------------------------------------- una sola renovación --

    @Test
    fun `dos 401 a la vez piden UNA sola renovacion y los dos reintentan con el access nuevo`() = runBlocking {
        val vieja = sesionDePrueba(1)
        val nueva = sesionDePrueba(2)
        val almacen = AlmacenDeSesionEnMemoria(vieja)
        val rechazos = AtomicInteger()
        val llegaronLosDos = CompletableDeferred<Unit>()
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> if (pedido.acceso == nueva.accessToken) {
                    respuestaOk(PERFIL_JSON)
                } else {
                    if (rechazos.incrementAndGet() == 2) llegaronLosDos.complete(Unit)
                    rechazo(401, "unauthorized")
                }
                // La renovación no contesta hasta que los dos pedidos tienen su 401 en la
                // mano: así la carrera pasa siempre, y no cuando el planificador quiere.
                "/auth/refresh" -> {
                    llegaronLosDos.await()
                    respuestaConSesion(nueva)
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        assertTrue(api.restaurarSesion())

        val resultados = listOf(
            async { api.obtener("/me", Perfil.serializer()) },
            async { api.obtener("/me", Perfil.serializer()) },
        ).awaitAll()

        assertTrue("los dos tienen que salir bien: $resultados", resultados.all { it is Resultado.Ok })
        assertEquals("el refresh se canjeó más de una vez", 1, servidor.cuantos("/auth/refresh"))
        val renovacion = servidor.deLaRuta("/auth/refresh").single()
        assertTrue("salió sin el refresh de la sesión", renovacion.cuerpo.orEmpty().contains(vieja.refreshToken))
        assertNull("la renovación es pública: no lleva access", renovacion.acceso)
        assertEquals(
            "los dos reintentos tienen que ir con el access nuevo",
            2,
            servidor.deLaRuta("/me").count { it.acceso == nueva.accessToken },
        )
        assertEquals("la renovada tiene que quedar guardada", nueva, almacen.leer())
    }

    @Test
    fun `veinte pedidos desde hilos distintos siguen siendo UNA renovacion`() = runBlocking {
        val nueva = sesionDePrueba(2)
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> if (pedido.acceso == nueva.accessToken) {
                    respuestaOk(PERFIL_JSON)
                } else {
                    rechazo(401, "unauthorized")
                }
                "/auth/refresh" -> {
                    // Lenta a propósito, para que la mayoría la agarre en el aire.
                    delay(50)
                    respuestaConSesion(nueva)
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor)
        api.restaurarSesion()

        val resultados = (1..20)
            .map { async(Dispatchers.Default) { api.obtener("/me", Perfil.serializer()) } }
            .awaitAll()

        assertTrue("todos tienen que salir bien", resultados.all { it is Resultado.Ok })
        assertEquals("el refresh se canjeó más de una vez", 1, servidor.cuantos("/auth/refresh"))
    }

    @Test
    fun `los que esperaban una renovacion que se quedo sin red se quedan con ese resultado`() = runBlocking {
        val rechazos = AtomicInteger()
        val llegaronLosDos = CompletableDeferred<Unit>()
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> {
                    if (rechazos.incrementAndGet() == 2) llegaronLosDos.complete(Unit)
                    rechazo(401, "unauthorized")
                }
                "/auth/refresh" -> {
                    llegaronLosDos.await()
                    throw IOException("sin señal")
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor)
        api.restaurarSesion()

        val resultados = listOf(
            async { api.obtener("/me", Perfil.serializer()) },
            async { api.obtener("/me", Perfil.serializer()) },
        ).awaitAll()

        assertTrue(resultados.all { it is Resultado.SinRed })
        assertEquals(
            "con la red caída, cada pedido que esperaba no tiene que probar su propia renovación",
            1,
            servidor.cuantos("/auth/refresh"),
        )
        assertTrue("sin red, la sesión sigue", api.haySesion())
    }

    @Test
    fun `un session_revoked en un pedido comun pasa por la renovacion y, si otro ya renovo, reintenta con esa`() = runBlocking {
        val nueva = sesionDePrueba(2)
        val rotada = CompletableDeferred<Unit>()
        val primeroEnLlegar = AtomicBoolean(true)
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> when {
                    pedido.acceso == nueva.accessToken -> respuestaOk(PERFIL_JSON)
                    // Salió con el access viejo y vuelve con session_revoked DESPUÉS de que
                    // otro pedido renovó. Desde la decisión 0013 rotar no revoca los access
                    // ya emitidos, así que un servidor de verdad sólo lo manda con una
                    // revocación. Lo que se fija acá es el camino del cliente: pasa por la
                    // renovación y, como otro ya renovó, reintenta con esa sin gastar el
                    // refresh.
                    primeroEnLlegar.compareAndSet(true, false) -> {
                        rotada.await()
                        rechazo(401, "session_revoked")
                    }
                    else -> rechazo(401, "unauthorized")
                }
                "/auth/refresh" -> {
                    rotada.complete(Unit)
                    respuestaConSesion(nueva)
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val almacen = AlmacenDeSesionEnMemoria(sesionDePrueba(1))
        val api = cliente(almacen, servidor)
        api.restaurarSesion()
        val avisos = mutableListOf<Resultado.Rechazado>()
        val escucha = launch(start = CoroutineStart.UNDISPATCHED) { api.sesionCerrada.collect { avisos += it } }

        val resultados = listOf(
            async { api.obtener("/me", Perfil.serializer()) },
            async { api.obtener("/me", Perfil.serializer()) },
        ).awaitAll()
        yield()

        assertTrue("una sesión perfecta no puede mandar al login: $resultados", resultados.all { it is Resultado.Ok })
        assertEquals(1, servidor.cuantos("/auth/refresh"))
        assertTrue(api.haySesion())
        assertEquals(nueva, almacen.leer())
        assertTrue("no se cerró nada: no hay nada que avisar", avisos.isEmpty())
        escucha.cancel()
    }

    // ------------------------------------------------ cuándo renovar, y cuánto --

    @Test
    fun `un access que vence en menos de 30 segundos se renueva antes de mandarlo`() = runBlocking {
        val nueva = sesionDePrueba(2)
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/auth/refresh" -> respuestaConSesion(nueva)
                "/me" -> respuestaOk(PERFIL_JSON)
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val porVencer = sesionDePrueba(1, venceElAcceso = AHORA + 10_000)
        val api = cliente(AlmacenDeSesionEnMemoria(porVencer), servidor)
        api.restaurarSesion()

        assertTrue(api.obtener("/me", Perfil.serializer()) is Resultado.Ok)

        assertEquals(listOf("/auth/refresh", "/me"), servidor.rutas())
        assertEquals(
            "el access por vencer no tenía que salir",
            nueva.accessToken,
            servidor.deLaRuta("/me").single().acceso,
        )
    }

    @Test
    fun `un access al que le quedan mas de 30 segundos sale tal cual`() = runBlocking {
        val servidor = ServidorDeMentira { respuestaOk(PERFIL_JSON) }
        val sesion = sesionDePrueba(1, venceElAcceso = AHORA + ClienteApi.MARGEN_DE_RENOVACION_MS + 1_000)
        val api = cliente(AlmacenDeSesionEnMemoria(sesion), servidor)
        api.restaurarSesion()

        assertTrue(api.obtener("/me", Perfil.serializer()) is Resultado.Ok)

        assertEquals(listOf("/me"), servidor.rutas())
        assertEquals(sesion.accessToken, servidor.pedidos.single().acceso)
    }

    @Test
    fun `si despues de renovar el servidor sigue diciendo 401, no se renueva otra vez`() = runBlocking {
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> rechazo(401, "unauthorized")
                "/auth/refresh" -> respuestaConSesion(sesionDePrueba(2))
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor)
        api.restaurarSesion()

        val r = api.obtener("/me", Perfil.serializer())

        assertEquals("unauthorized", (r as Resultado.Rechazado).codigo)
        assertEquals("UNA renovación", 1, servidor.cuantos("/auth/refresh"))
        assertEquals("un pedido y UN reintento", 2, servidor.cuantos("/me"))
    }

    @Test
    fun `con el reloj adelantado no se gasta una renovacion por pedido`() = runBlocking {
        val nueva = sesionDePrueba(2)
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/auth/refresh" -> respuestaConSesion(nueva)
                "/me" -> respuestaOk(PERFIL_JSON)
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        // El teléfono cree que es una hora más tarde: todo access le parece vencido.
        val api = cliente(AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor) { AHORA + 60 * 60_000L }
        api.restaurarSesion()

        repeat(3) { assertTrue(api.obtener("/me", Perfil.serializer()) is Resultado.Ok) }

        assertEquals(
            "la primera renueva por adelantado; después de eso el reloj ya no se cree",
            1,
            servidor.cuantos("/auth/refresh"),
        )
    }

    @Test
    fun `lo publico sale sin token y nunca renueva, aunque el access este por vencer`() = runBlocking {
        val servidor = ServidorDeMentira { respuestaOk(HEALTH_JSON) }
        val porVencer = sesionDePrueba(1, venceElAcceso = AHORA + 5_000)
        val api = cliente(AlmacenDeSesionEnMemoria(porVencer), servidor)
        api.restaurarSesion()

        assertTrue(api.obtener("/health", Health.serializer(), conSesion = false) is Resultado.Ok)

        assertNull("un pedido público no lleva el access", servidor.pedidos.single().acceso)
        assertEquals(0, servidor.cuantos("/auth/refresh"))
    }

    @Test
    fun `un pedido con sesion y sin sesion abierta no sale, se contesta aca`() = runBlocking {
        val servidor = ServidorDeMentira { rechazo(401, "unauthorized") }
        val api = cliente(AlmacenDeSesionEnMemoria(), servidor)
        api.restaurarSesion()

        val r = api.actualizar("/me", """{"display_name":"Ana"}""", Perfil.serializer(), clave = "clave-1")

        assertEquals("unauthorized", (r as Resultado.Rechazado).codigo)
        assertEquals(401, r.http)
        assertTrue("salió sin Authorization: ${servidor.rutas()}", servidor.pedidos.isEmpty())
    }

    // ------------------------------------------------- cuando la sesión muere --

    @Test
    fun `si la renovacion dice que la sesion no existe, se borra y se avisa`() = runBlocking {
        for (codigo in listOf("session_revoked", "invalid_refresh_token")) {
            val almacen = AlmacenDeSesionEnMemoria(sesionDePrueba(1))
            val servidor = ServidorDeMentira { pedido ->
                when (pedido.ruta) {
                    "/me" -> rechazo(401, "unauthorized")
                    "/auth/refresh" -> rechazo(401, codigo)
                    else -> error("ruta inesperada: ${pedido.ruta}")
                }
            }
            val api = cliente(almacen, servidor)
            api.restaurarSesion()
            val aviso = async(start = CoroutineStart.UNDISPATCHED) { api.sesionCerrada.first() }

            val r = api.obtener("/me", Perfil.serializer())

            assertEquals("[$codigo] el pedido tiene que devolver el motivo", codigo, (r as Resultado.Rechazado).codigo)
            assertFalse("[$codigo] la sesión quedó en memoria", api.haySesion())
            assertNull("[$codigo] la sesión quedó guardada", almacen.leer())
            assertEquals("[$codigo] no llegó el aviso", codigo, withTimeout(1_000) { aviso.await() }.codigo)
            assertEquals("[$codigo] se renovó más de una vez", 1, servidor.cuantos("/auth/refresh"))
        }
    }

    @Test
    fun `sin red al renovar la sesion queda como estaba y no se avisa nada`() = runBlocking {
        val vieja = sesionDePrueba(1)
        val almacen = AlmacenDeSesionEnMemoria(vieja)
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> rechazo(401, "unauthorized")
                "/auth/refresh" -> throw IOException("sin señal")
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()
        val avisos = mutableListOf<Resultado.Rechazado>()
        val escucha = launch(start = CoroutineStart.UNDISPATCHED) { api.sesionCerrada.collect { avisos += it } }

        val r = api.obtener("/me", Perfil.serializer())
        yield()

        assertTrue(r is Resultado.SinRed)
        assertTrue(api.haySesion())
        assertEquals(vieja, almacen.leer())
        assertTrue("no se cerró nada: no hay nada que avisar", avisos.isEmpty())
        escucha.cancel()
    }

    @Test
    fun `un session_revoked con el access recien renovado cierra la sesion y avisa`() = runBlocking {
        // Las dos formas de renovar: después de un 401, y antes de mandar un access por vencer.
        for (porAdelantado in listOf(false, true)) {
            val caso = if (porAdelantado) "[por adelantado]" else "[después del 401]"
            val vence = if (porAdelantado) AHORA + 5_000 else AHORA + QUINCE_MINUTOS_MS
            val nueva = sesionDePrueba(2)
            val almacen = AlmacenDeSesionEnMemoria(sesionDePrueba(1, venceElAcceso = vence))
            val servidor = ServidorDeMentira { pedido ->
                when (pedido.ruta) {
                    // Con el access recién renovado también dice que no: la revocaron de verdad.
                    "/me" -> if (pedido.acceso == nueva.accessToken) {
                        rechazo(401, "session_revoked")
                    } else {
                        rechazo(401, "unauthorized")
                    }
                    "/auth/refresh" -> respuestaConSesion(nueva)
                    else -> error("ruta inesperada: ${pedido.ruta}")
                }
            }
            val api = cliente(almacen, servidor)
            api.restaurarSesion()
            val aviso = async(start = CoroutineStart.UNDISPATCHED) { api.sesionCerrada.first() }

            val r = api.obtener("/me", Perfil.serializer())

            assertEquals(caso, "session_revoked", (r as Resultado.Rechazado).codigo)
            assertFalse("$caso la sesión quedó en memoria", api.haySesion())
            assertNull("$caso la sesión quedó guardada", almacen.leer())
            assertEquals("$caso no llegó el aviso", "session_revoked", withTimeout(1_000) { aviso.await() }.codigo)
            assertEquals("$caso se renovó más de una vez", 1, servidor.cuantos("/auth/refresh"))
        }
    }

    @Test
    fun `una renovacion que vuelve despues de cerrar la sesion no la resucita`() = runBlocking {
        val almacen = AlmacenDeSesionEnMemoria(sesionDePrueba(1))
        val renovacionEnCamino = CompletableDeferred<Unit>()
        val soltarRenovacion = CompletableDeferred<Unit>()
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> rechazo(401, "unauthorized")
                "/auth/refresh" -> {
                    renovacionEnCamino.complete(Unit)
                    soltarRenovacion.await()
                    respuestaConSesion(sesionDePrueba(2))
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()

        val pedido = async { api.obtener("/me", Perfil.serializer()) }
        renovacionEnCamino.await()
        api.olvidarSesion()
        soltarRenovacion.complete(Unit)

        assertTrue(pedido.await() is Resultado.Rechazado)
        assertFalse("la renovación que llegó tarde volvió a abrir la sesión", api.haySesion())
        assertNull("la renovación que llegó tarde quedó guardada", almacen.leer())
    }

    @Test
    fun `la sesion que entra despues no se suma a la renovacion de la que salio`() = runBlocking {
        val deAntes = sesionDePrueba(1)
        val deAhora = sesionDePrueba(5)
        val deAhoraRenovada = sesionDePrueba(6)
        val almacen = AlmacenDeSesionEnMemoria(deAntes)
        val renovacionDeAntesEnCamino = CompletableDeferred<Unit>()
        val soltarRenovacionDeAntes = CompletableDeferred<Unit>()
        val servidor = ServidorDeMentira { pedido ->
            val cuerpo = pedido.cuerpo.orEmpty()
            when {
                pedido.ruta == "/me" && pedido.acceso == deAhoraRenovada.accessToken -> respuestaOk(PERFIL_JSON)
                pedido.ruta == "/me" -> rechazo(401, "unauthorized")
                pedido.ruta == "/auth/refresh" && cuerpo.contains(deAntes.refreshToken) -> {
                    renovacionDeAntesEnCamino.complete(Unit)
                    soltarRenovacionDeAntes.await()
                    respuestaConSesion(sesionDePrueba(2))
                }
                pedido.ruta == "/auth/refresh" && cuerpo.contains(deAhora.refreshToken) ->
                    respuestaConSesion(deAhoraRenovada)
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()

        // La renovación de la sesión de antes sale y se queda en el aire. Mientras tanto
        // esa persona sale, y entra otra en el mismo teléfono.
        val deLaDeAntes = async { api.obtener("/me", Perfil.serializer()) }
        renovacionDeAntesEnCamino.await()
        api.olvidarSesion()
        api.abrirSesion(deAhora)

        // Con tiempo límite y soltando en el `finally`: sin el arreglo, el pedido de la
        // nueva se queda esperando la renovación de la otra, y el test tiene que fallar
        // en vez de colgarse.
        val deLaDeAhora = try {
            withTimeoutOrNull(2_000) { api.obtener("/me", Perfil.serializer()) }
        } finally {
            soltarRenovacionDeAntes.complete(Unit)
        }
        deLaDeAntes.await()

        assertTrue("la sesión nueva esperó la renovación de la anterior: $deLaDeAhora", deLaDeAhora is Resultado.Ok)
        assertEquals(
            "la sesión nueva tiene que renovar con SU refresh",
            1,
            servidor.deLaRuta("/auth/refresh").count { it.cuerpo.orEmpty().contains(deAhora.refreshToken) },
        )
        assertEquals("la renovación de la anterior pisó a la nueva", deAhoraRenovada, almacen.leer())
        assertTrue(api.haySesion())
    }

    // ------------------------------------------- las guardas, hechas fallar --

    @Test
    fun `cancelar a quien disparo la renovacion no la corta, y la sesion nueva queda guardada`() = runBlocking {
        val vieja = sesionDePrueba(1)
        val nueva = sesionDePrueba(2)
        val almacen = AlmacenDeSesionEnMemoria(vieja)
        val renovacionEnCamino = CompletableDeferred<Unit>()
        val soltarRenovacion = CompletableDeferred<Unit>()
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> rechazo(401, "unauthorized")
                "/auth/refresh" -> {
                    renovacionEnCamino.complete(Unit)
                    soltarRenovacion.await()
                    respuestaConSesion(nueva)
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()

        // El refresh ya llegó al servidor, que lo canjeó, y la pantalla que lo pidió se
        // cierra antes de que vuelva la respuesta.
        val pedido = launch { api.obtener("/me", Perfil.serializer()) }
        renovacionEnCamino.await()
        pedido.cancel()
        soltarRenovacion.complete(Unit)
        pedido.join()

        assertEquals("se tiró la respuesta de un refresh que el servidor ya canjeó", nueva, almacen.leer())
        assertTrue(api.haySesion())
    }

    @Test
    fun `un pedido de la sesion de antes no se reintenta con la que entro despues`() = runBlocking {
        val deA = sesionDePrueba(1)
        val deB = sesionDePrueba(7).copy(userId = "u_2")
        val patchEnCamino = CompletableDeferred<Unit>()
        val soltarPatch = CompletableDeferred<Unit>()
        val servidor = ServidorDeMentira { pedido ->
            when {
                pedido.ruta == "/me" && pedido.acceso == deA.accessToken -> {
                    patchEnCamino.complete(Unit)
                    soltarPatch.await()
                    rechazo(401, "unauthorized")
                }
                pedido.ruta == "/me" -> respuestaOk(PERFIL_JSON)
                pedido.ruta == "/auth/refresh" -> respuestaConSesion(sesionDePrueba(8))
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(AlmacenDeSesionEnMemoria(deA), servidor)
        api.restaurarSesion()

        // Sale el PATCH de A y, antes de que vuelva su 401, entra B en el mismo teléfono.
        val pedidoDeA = async {
            api.actualizar("/me", """{"display_name":"A"}""", Perfil.serializer(), clave = "clave-a")
        }
        patchEnCamino.await()
        api.abrirSesion(deB)
        soltarPatch.complete(Unit)
        val r = pedidoDeA.await()

        assertTrue(
            "el PATCH de A se reintentó con la sesión de B: escribió en otra cuenta",
            servidor.pedidos.none { it.acceso == deB.accessToken },
        )
        assertEquals("unauthorized", (r as Resultado.Rechazado).codigo)
        assertEquals("tampoco se gasta el refresh de nadie", 0, servidor.cuantos("/auth/refresh"))
    }

    // ------------------------------------------------ guardar, levantar, cerrar --

    @Test
    fun `abrir sesion la guarda, y al volver a arrancar se levanta del almacen`() = runBlocking {
        val almacen = AlmacenDeSesionEnMemoria()
        val servidor = ServidorDeMentira { respuestaOk(PERFIL_JSON) }
        val antes = cliente(almacen, servidor)
        assertFalse(antes.restaurarSesion())

        antes.abrirSesion(sesionDePrueba(1))
        assertEquals(sesionDePrueba(1), almacen.leer())

        // "Cerrar la app y volver a abrirla": otro cliente sobre el mismo almacén.
        val despues = cliente(almacen, servidor)
        assertTrue(despues.restaurarSesion())
        assertTrue(despues.obtener("/me", Perfil.serializer()) is Resultado.Ok)
        assertEquals(sesionDePrueba(1).accessToken, servidor.pedidos.single().acceso)

        despues.olvidarSesion()
        assertNull(almacen.leer())
        assertFalse(despues.haySesion())
    }

    @Test
    fun `cerrar sesion manda el refresh al logout y la borra aunque no haya red`() = runBlocking {
        val sesion = sesionDePrueba(1)
        val almacen = AlmacenDeSesionEnMemoria(sesion)
        val servidor = ServidorDeMentira { throw IOException("sin señal") }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()

        val r = api.cerrarSesion()

        assertTrue(r is Resultado.SinRed)
        assertFalse(api.haySesion())
        assertNull("sin red, la sesión igual se borra del teléfono", almacen.leer())
        val logout = servidor.pedidos.single()
        assertEquals("/auth/logout", logout.ruta)
        assertEquals(sesion.accessToken, logout.acceso)
        assertTrue("sin el refresh, el servidor no revoca la familia", logout.cuerpo.orEmpty().contains(sesion.refreshToken))
    }

    @Test
    fun `cerrar sesion con el access vencido lo renueva solo para poder revocar`() = runBlocking {
        val vieja = sesionDePrueba(1)
        val paraRevocar = sesionDePrueba(2)
        val almacen = AlmacenDeSesionEnMemoria(vieja)
        val servidor = ServidorDeMentira { pedido ->
            when {
                pedido.ruta == "/auth/logout" && pedido.acceso == vieja.accessToken -> rechazo(401, "unauthorized")
                pedido.ruta == "/auth/logout" -> RespuestaHttp(204, "")
                pedido.ruta == "/auth/refresh" -> respuestaConSesion(paraRevocar)
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()

        assertEquals(Resultado.Ok(Unit), api.cerrarSesion())

        assertEquals(listOf("/auth/logout", "/auth/refresh", "/auth/logout"), servidor.rutas())
        assertTrue(servidor.pedidos.last().cuerpo.orEmpty().contains(paraRevocar.refreshToken))
        assertNull("lo que devolvió esa renovación no se guarda", almacen.leer())
        assertFalse(api.haySesion())
    }
}
