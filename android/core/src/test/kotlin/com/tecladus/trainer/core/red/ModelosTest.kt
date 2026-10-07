package com.tecladus.trainer.core.red

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.serialization.json.Json

/**
 * Ata los modelos GENERADOS al JSON que el contrato promete.
 *
 * No prueban kotlinx.serialization: prueban que los `@SerialName` que emitió
 * `scripts/generar-modelos.mjs` coincidan con `shared/api/openapi.yaml`. Ese es el
 * error que no avisa: el campo se llama distinto, el objeto deserializa igual y
 * llega `null` en producción.
 */
class ModelosTest {

    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    @Test
    fun `la sesion se lee con los nombres del contrato, en snake_case`() {
        val crudo = """
            {"access_token":"aaa","access_expires_at_ms":1757308800000,
             "refresh_token":"bbb","refresh_expires_at_ms":1757395200000,
             "user_id":"u_1"}
        """.trimIndent()
        val s = json.decodeFromString(Sesion.serializer(), crudo)
        assertEquals("aaa", s.accessToken)
        assertEquals(1_757_308_800_000L, s.accessExpiresAtMs)
        assertEquals("u_1", s.userId)
    }

    @Test
    fun `un campo nuevo del servidor NO rompe al cliente`() {
        // §5: los cambios del contrato son aditivos. Un cliente que revienta ante
        // un campo que no conoce obliga a desplegar la app cada vez que el
        // servidor crece.
        val conExtra = """
            {"access_token":"a","access_expires_at_ms":1,"refresh_token":"b",
             "refresh_expires_at_ms":2,"user_id":"u","algo_que_no_existia":true}
        """.trimIndent()
        assertEquals("a", json.decodeFromString(Sesion.serializer(), conExtra).accessToken)
    }

    @Test
    fun `los tiempos son enteros de milisegundos, no textos con formato`() {
        val perfil = json.decodeFromString(
            Perfil.serializer(),
            """{"id":"u","email":"a@b.c","created_at_ms":1757308800000,"updated_at_ms":1757308800001}""",
        )
        assertEquals(1_757_308_800_000L, perfil.createdAtMs)
        assertNull("lo no requerido llega en null y no explota", perfil.firstName)
    }

    @Test
    fun `un opcional del contrato acepta null explicito`() {
        // goal_date_ms es oneOf:[EpochMs, null] en OpenAPI 3.1. El generador lo
        // aplana a Long? — si alguna vez lo emite como Long, esto falla.
        val perfil = json.decodeFromString(
            Perfil.serializer(),
            """{"id":"u","email":"a@b.c","created_at_ms":1,"updated_at_ms":2,"goal_date_ms":null}""",
        )
        assertNull(perfil.goalDateMs)
    }

    @Test
    fun `los enums usan el valor del contrato y no el nombre de Kotlin`() {
        assertEquals(
            Plataforma.ANDROID,
            json.decodeFromString(Plataforma.serializer(), "\"android\""),
        )
        assertEquals("\"wear\"", json.encodeToString(Plataforma.serializer(), Plataforma.WEAR))
    }

    @Test
    fun `el sobre de error trae un codigo estable`() {
        val e = json.decodeFromString(
            Error.serializer(),
            """{"error":{"code":"invalid_credentials","message":"no"}}""",
        )
        assertEquals("invalid_credentials", e.error.code)
    }

    @Test
    fun `health trae el estado de sus dependencias`() {
        val h = json.decodeFromString(
            Health.serializer(),
            """{"status":"ok","version":"1.0.0","dependencies":{"database":"ok","redis":"down"}}""",
        )
        assertEquals("ok", h.dependencies.database)
        assertEquals("down", h.dependencies.redis)
        assertTrue("el objeto anonimo del contrato quedo con nombre propio", h.status == "ok")
    }
}
