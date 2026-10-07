package com.tecladus.trainer.core.red

import java.io.IOException
import java.util.Collections
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Una renovación cuya respuesta se perdió (decisión 0013).
 *
 * El refresh llega, el servidor lo canjea y la respuesta se corta en el camino. Si le
 * reenvían ese mismo refresh dentro de los dos minutos, con el sucesor sin usar, el
 * servidor devuelve EL MISMO sucesor; pasado eso es un reuso, revoca la familia y la
 * persona termina en el login. Estos tests prueban que el cliente lo reenvía solo y a
 * tiempo, sin dos renovaciones en vuelo, y sin hacer esperar a quien pidió.
 *
 * Con reloj virtual: los minutos pasan con `advanceTimeBy`, no esperando.
 *
 * 🛑 `advanceTimeBy` y no `advanceUntilIdle`: los reintentos corren en el
 * `backgroundScope`, y `advanceUntilIdle` deja de mover el reloj cuando sólo queda
 * trabajo de fondo. Con él, un test de reintentos pasa sin que haya salido ninguno.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReintentoDeRenovacionTest {

    /** El cliente con los reintentos en el `backgroundScope` del test, que corre con el reloj virtual. */
    private fun TestScope.cliente(almacen: AlmacenDeSesion, servidor: Transporte) =
        ClienteApi(BASE, almacen, servidor, alcance = backgroundScope) { AHORA }

    @Test
    fun `una renovacion que perdio la respuesta se reintenta sola con el mismo refresh, dentro de la ventana`() = runTest {
        val vieja = sesionDePrueba(1)
        val nueva = sesionDePrueba(2)
        val almacen = AlmacenDeSesionEnMemoria(vieja)
        // El servidor de la 0013, en chico: un canje por refresh, y el mismo sucesor si se
        // reenvía dentro de los dos minutos sin haberlo usado.
        var canjeadoEn: Long? = null
        var sucesorUsado = false
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> if (pedido.acceso == nueva.accessToken) {
                    sucesorUsado = true
                    respuestaOk(PERFIL_JSON)
                } else {
                    rechazo(401, "unauthorized")
                }
                "/auth/refresh" -> {
                    val canje = canjeadoEn
                    when {
                        canje == null -> {
                            // Llega y se canjea, pero la respuesta se corta a los 10 segundos.
                            canjeadoEn = currentTime
                            delay(10_000)
                            throw IOException("se cortó la respuesta")
                        }
                        currentTime - canje <= DOS_MINUTOS_MS && !sucesorUsado -> respuestaConSesion(nueva)
                        else -> rechazo(401, "invalid_refresh_token")
                    }
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()

        val r = api.obtener("/me", Perfil.serializer())
        assertTrue("quien pidió se lleva su SinRed: $r", r is Resultado.SinRed)
        assertEquals("y no espera a los reintentos", 10_000L, currentTime)

        // Tres minutos sin que nadie pida nada: el teléfono en el bolsillo.
        advanceTimeBy(170_000)
        val despues = api.obtener("/me", Perfil.serializer())

        assertTrue("a los tres minutos la sesión terminó en el login: $despues", despues is Resultado.Ok)
        val renovaciones = servidor.deLaRuta("/auth/refresh")
        assertEquals(2, renovaciones.size)
        assertEquals("el reintento tiene que llevar EL MISMO refresh", renovaciones[0].cuerpo, renovaciones[1].cuerpo)
        // Pasa por el candado: espera a que el reintento termine de guardar en el almacén.
        api.restaurarSesion()
        assertEquals(nueva, almacen.leer())
    }

    @Test
    fun `mientras un reintento esta en el aire, el pedido que necesita renovar se suma a el`() = runTest {
        val nueva = sesionDePrueba(2)
        val renovaciones = AtomicInteger()
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> if (pedido.acceso == nueva.accessToken) respuestaOk(PERFIL_JSON) else rechazo(401, "unauthorized")
                "/auth/refresh" -> if (renovaciones.incrementAndGet() == 1) {
                    throw IOException("se cortó")
                } else {
                    // El reintento tarda tres segundos en volver.
                    delay(3_000)
                    respuestaConSesion(nueva)
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor)
        api.restaurarSesion()

        assertTrue(api.obtener("/me", Perfil.serializer()) is Resultado.SinRed)
        // A los 6 segundos: el reintento salió a los 5 y todavía no volvió.
        advanceTimeBy(6_000)
        assertEquals(2, servidor.cuantos("/auth/refresh"))

        val pedido = async { api.obtener("/me", Perfil.serializer()) }
        // Hasta los 11 segundos: el reintento volvió a los 8.
        advanceTimeBy(5_000)
        val r = pedido.await()

        assertTrue("el pedido tenía que quedarse con el reintento: $r", r is Resultado.Ok)
        assertEquals("salieron dos renovaciones a la vez", 2, servidor.cuantos("/auth/refresh"))
        assertEquals(nueva.accessToken, servidor.deLaRuta("/me").last().acceso)
    }

    @Test
    fun `un 5xx tambien se reintenta, a los 5, 20 y 60 segundos, y despues no se insiste mas`() = runTest {
        val vieja = sesionDePrueba(1)
        val almacen = AlmacenDeSesionEnMemoria(vieja)
        val cuando = Collections.synchronizedList(mutableListOf<Long>())
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> rechazo(401, "unauthorized")
                "/auth/refresh" -> {
                    cuando += currentTime
                    if (cuando.size == 1) rechazo(503, "service_unavailable") else throw IOException("sin señal")
                }
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(almacen, servidor)
        api.restaurarSesion()

        val r = api.obtener("/me", Perfil.serializer())
        assertEquals("quien pidió se lleva el 503 enseguida", 503, (r as Resultado.Rechazado).http)
        advanceTimeBy(DOS_MINUTOS_MS)
        assertEquals("cuándo salió cada refresh", listOf(0L, 5_000L, 20_000L, 60_000L), cuando.toList())

        advanceTimeBy(10 * 60_000L)
        assertEquals("pasados los tres reintentos no se insiste más", 4, cuando.size)
        val cuerpos = servidor.deLaRuta("/auth/refresh").map { it.cuerpo }
        assertTrue("todos llevan el mismo refresh", cuerpos.all { it == cuerpos.first() })
        assertTrue("sin respuesta no se cierra nada", api.haySesion())
        assertEquals(vieja, almacen.leer())
    }

    @Test
    fun `si la sesion se cierra mientras espera el reintento, no sale ningun refresh mas`() = runTest {
        val servidor = ServidorDeMentira { pedido ->
            when (pedido.ruta) {
                "/me" -> rechazo(401, "unauthorized")
                "/auth/refresh" -> throw IOException("sin señal")
                else -> error("ruta inesperada: ${pedido.ruta}")
            }
        }
        val api = cliente(AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor)
        api.restaurarSesion()

        assertTrue(api.obtener("/me", Perfil.serializer()) is Resultado.SinRed)
        api.olvidarSesion()
        advanceTimeBy(DOS_MINUTOS_MS)

        assertEquals("un reintento mandó el refresh de una sesión cerrada", 1, servidor.cuantos("/auth/refresh"))
        assertFalse(api.haySesion())
    }
}

private const val DOS_MINUTOS_MS = 120_000L
