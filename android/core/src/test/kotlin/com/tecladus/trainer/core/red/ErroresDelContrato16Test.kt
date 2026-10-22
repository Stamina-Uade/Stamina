package com.tecladus.trainer.core.red

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Los errores que el servidor empezó a contestar con el contrato 1.6.0, leídos por el
 * cliente de verdad.
 *
 * Android no usa las rutas nuevas (vincular, reactivar), pero el login y los códigos de
 * correo SÍ pueden devolver los códigos nuevos, y algunos traen `details`. Lo que se fija
 * acá: llegan como [Resultado.Rechazado] con su código —que la pantalla traduce—, y no
 * como [Resultado.RespuestaRara] por un objeto que el cliente no esperaba.
 */
class ErroresDelContrato16Test {

    private fun sinSesion(contestar: RespuestaHttp): Pair<ApiTrainer, ServidorDeMentira> {
        val servidor = ServidorDeMentira { contestar }
        val cliente = ClienteApi(BASE, AlmacenDeSesionEnMemoria(), servidor, reloj = { AHORA })
        return ApiTrainer(cliente) to servidor
    }

    private fun conDetalles(http: Int, codigo: String, detalles: String) = RespuestaHttp(
        http,
        """{"error":{"code":"$codigo","message":"de mentira","details":$detalles}}""",
    )

    @Test
    fun `too_many_attempts del login llega con su codigo y no abre sesion`() = runBlocking {
        val (api, servidor) = sinSesion(rechazo(429, "too_many_attempts"))

        val r = api.entrar("a@b.c", "Clave-equivocada-1")

        assertEquals(Resultado.Rechazado("too_many_attempts", "de mentira", 429), r)
        assertEquals("un 429 del login no se reintenta solo", 1, servidor.cuantos("/auth/login"))
        assertFalse(api.haySesion())
    }

    @Test
    fun `una cuenta por borrarse llega con su codigo aunque traiga details`() = runBlocking {
        val (api, _) = sinSesion(
            conDetalles(
                403,
                "account_pending_deletion",
                """{"reactivation_token":"rt","days_remaining":29}""",
            ),
        )

        val r = api.entrar("a@b.c", "Clave-correcta-1")

        assertEquals(Resultado.Rechazado("account_pending_deletion", "de mentira", 403), r)
        assertFalse(api.haySesion())
    }

    @Test
    fun `account_link_available con todos sus details se lee`() = runBlocking {
        val (api, _) = sinSesion(
            conDetalles(
                409,
                "account_link_available",
                """{"link_token":"lt","email":"a@b.c","provider":"google","requires_password":true}""",
            ),
        )

        val r = api.entrar("a@b.c", "Clave-correcta-1")

        assertEquals(Resultado.Rechazado("account_link_available", "de mentira", 409), r)
    }

    @Test
    fun `code_attempts_exceeded del codigo de registro llega con su codigo`() = runBlocking {
        val (api, _) = sinSesion(rechazo(400, "code_attempts_exceeded"))

        val r = api.verificarCodigo("a@b.c", "A7K2Q9")

        assertEquals(Resultado.Rechazado("code_attempts_exceeded", "de mentira", 400), r)
    }
}
