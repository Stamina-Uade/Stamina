package com.tecladus.trainer.core.red

import java.io.IOException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La puerta de versión (AGENTS.md §5.1): lo que bloquea, lo que avisa y, sobre todo,
 * lo que deja pasar.
 *
 * El caso que más importa es el que menos se ve: una puerta que por un error bloquea
 * a todo el mundo. Por eso la mitad de estos tests son fallas que tienen que dejar
 * entrar.
 */
class PuertaDeVersionTest {

    private fun puerta(
        accion: String,
        minimo: Long = 5,
        recomendado: Long = 8,
        codigo: String? = null,
        mensaje: String? = null,
        tienda: String? = null,
    ) = VersionGate(Plataforma.ANDROID, minimo, recomendado, accion, codigo, mensaje, tienda)

    @Test
    fun `update_required bloquea`() {
        val d = PuertaDeVersion.decidir(Resultado.Ok(puerta("update_required")), build = 3)
        assertTrue(d is DecisionDeVersion.Bloquear)
    }

    @Test
    fun `update_recommended avisa sin bloquear`() {
        val d = PuertaDeVersion.decidir(Resultado.Ok(puerta("update_recommended")), build = 6)
        assertTrue(d is DecisionDeVersion.Recomendar)
    }

    @Test
    fun `ok deja pasar`() {
        assertEquals(DecisionDeVersion.Pasar, PuertaDeVersion.decidir(Resultado.Ok(puerta("ok")), build = 9))
    }

    @Test
    fun `sin red, con un 503 o con cualquier otra falla, deja pasar`() {
        val fallas: List<Resultado<VersionGate>> = listOf(
            Resultado.SinRed("UnknownHostException"),
            Resultado.Rechazado("service_unavailable", "Version gate is not readable", 503),
            Resultado.Rechazado("bad_request", "x", 400),
            Resultado.Rechazado("rate_limited", "x", 429),
            Resultado.Rechazado("internal", "x", 500),
            Resultado.RespuestaRara("SerializationException", 200),
        )
        for (falla in fallas) {
            assertEquals("$falla no puede dejar a nadie afuera", DecisionDeVersion.Pasar, PuertaDeVersion.decidir(falla, build = 1))
        }
    }

    @Test
    fun `una accion que esta version no conoce se decide con los numeros`() {
        val nueva = "update_someday"
        assertTrue(PuertaDeVersion.decidir(Resultado.Ok(puerta(nueva)), build = 4) is DecisionDeVersion.Bloquear)
        assertTrue(PuertaDeVersion.decidir(Resultado.Ok(puerta(nueva)), build = 5) is DecisionDeVersion.Recomendar)
        assertEquals(DecisionDeVersion.Pasar, PuertaDeVersion.decidir(Resultado.Ok(puerta(nueva)), build = 8))
    }

    @Test
    fun `el texto del servidor se usa solo para un code que la app no conoce`() {
        val conocido = "update_required_security"
        assertNull(
            "sin code, el texto es el de la app",
            PuertaDeVersion.mensajeDelServidor(puerta("update_required", mensaje = "Update"), emptySet()),
        )
        assertEquals(
            "Actualizá ya",
            PuertaDeVersion.mensajeDelServidor(
                puerta("update_required", codigo = conocido, mensaje = "Actualizá ya"),
                emptySet(),
            ),
        )
        assertNull(
            "un code conocido se traduce del lado de la app",
            PuertaDeVersion.mensajeDelServidor(
                puerta("update_required", codigo = conocido, mensaje = "Actualizá ya"),
                setOf(conocido),
            ),
        )
        assertNull(PuertaDeVersion.mensajeDelServidor(puerta("update_required", codigo = "x", mensaje = "  "), emptySet()))
    }

    @Test
    fun `la tienda sale del servidor solo si es https o market`() {
        val id = "com.tecladus.trainer"
        val play = "https://play.google.com/store/apps/details?id=$id"
        val propia = "https://trainer.invalid/actualizar"

        assertEquals(propia, PuertaDeVersion.direccionDeLaTienda(puerta("update_required", tienda = propia), id))
        assertEquals(
            "market://details?id=$id",
            PuertaDeVersion.direccionDeLaTienda(puerta("update_required", tienda = "market://details?id=$id"), id),
        )
        for (mala in listOf("javascript:alert(1)", "intent:algo", "file:///sdcard/trainer.apk", "https:", "", null)) {
            assertEquals("«$mala»", play, PuertaDeVersion.direccionDeLaTienda(puerta("update_required", tienda = mala), id))
        }
        assertEquals(play, PuertaDeVersion.direccionDeLaTienda(null, id))
    }

    @Test
    fun `la app pregunta con su plataforma y su build, sin token, y sin red deja pasar`() = runBlocking {
        val servidor = ServidorDeMentira {
            respuestaOk("""{"platform":"android","minimum_build":9,"recommended_build":9,"action":"update_required"}""")
        }
        val cliente = ClienteApi(BASE, AlmacenDeSesionEnMemoria(sesionDePrueba(1)), servidor) { AHORA }
        cliente.restaurarSesion()

        val decision = ApiTrainer(cliente).consultarPuertaDeVersion(Plataforma.ANDROID, build = 7)

        assertTrue(decision is DecisionDeVersion.Bloquear)
        val pedido = servidor.pedidos.single()
        assertEquals("/version?platform=android&build=7", pedido.ruta)
        assertNull("la puerta es pública: no lleva token aunque haya sesión", pedido.acceso)

        val sinRed = ServidorDeMentira { throw IOException("sin señal") }
        assertEquals(
            DecisionDeVersion.Pasar,
            ApiTrainer(ClienteApi(BASE, transporte = sinRed)).consultarPuertaDeVersion(Plataforma.ANDROID, build = 7),
        )
    }

    @Test
    fun `volver a preguntar sin red no deshace lo que el servidor ya contesto`() = runBlocking {
        var contesta: () -> RespuestaHttp = {
            respuestaOk("""{"platform":"android","minimum_build":9,"recommended_build":9,"action":"update_required"}""")
        }
        val api = ApiTrainer(ClienteApi(BASE, transporte = ServidorDeMentira { contesta() }))

        assertTrue(api.consultarPuertaDeVersion(Plataforma.ANDROID, build = 7) is DecisionDeVersion.Bloquear)

        // Sale de la app, pone modo avión y vuelve: la puerta se pregunta de nuevo y no llega.
        contesta = { throw IOException("sin señal") }
        assertTrue(
            "una falla dejó pasar a una versión que el servidor ya había bloqueado",
            api.consultarPuertaDeVersion(Plataforma.ANDROID, build = 7) is DecisionDeVersion.Bloquear,
        )

        // Una respuesta clara sí la cambia: el servidor bajó el mínimo.
        contesta = { respuestaOk("""{"platform":"android","minimum_build":1,"recommended_build":1,"action":"ok"}""") }
        assertEquals(DecisionDeVersion.Pasar, api.consultarPuertaDeVersion(Plataforma.ANDROID, build = 7))
    }
}
