package com.tecladus.trainer.core.red

import java.util.Collections
import kotlinx.serialization.json.Json

/**
 * Lo que comparten los tests de red: un servidor de mentira y sesiones de ejemplo.
 *
 * Ningún test de `:core` llama a un servidor de verdad (ver `ClienteApi.actualizar`):
 * el cable se reemplaza por esto, que anota cada pedido y contesta lo que el test
 * diga.
 */
internal class ServidorDeMentira(
    private val responder: suspend (PedidoHttp) -> RespuestaHttp,
) : Transporte {

    /** Todo lo que llegó, en orden. Sincronizada: hay tests que pegan desde varios hilos. */
    val pedidos: MutableList<PedidoHttp> = Collections.synchronizedList(mutableListOf())

    override suspend fun ejecutar(pedido: PedidoHttp): RespuestaHttp {
        pedidos += pedido
        return responder(pedido)
    }

    fun cuantos(ruta: String): Int = deLaRuta(ruta).size

    fun deLaRuta(ruta: String): List<PedidoHttp> = synchronized(pedidos) { pedidos.filter { it.ruta == ruta } }

    fun rutas(): List<String> = synchronized(pedidos) { pedidos.map { it.ruta } }
}

internal const val BASE = "https://trainer.invalid/v1"

/** Un "ahora" fijo: los vencimientos se prueban moviendo esto, no esperando. */
internal const val AHORA = 1_757_500_000_000L

internal const val QUINCE_MINUTOS_MS = 15 * 60_000L

internal val PedidoHttp.ruta: String
    get() = url.removePrefix(BASE)

/** El access con el que salió el pedido, o `null` si salió sin token. */
internal val PedidoHttp.acceso: String?
    get() = headers["Authorization"]?.removePrefix("Bearer ")

internal fun sesionDePrueba(n: Int, venceElAcceso: Long = AHORA + QUINCE_MINUTOS_MS) = Sesion(
    accessToken = "acceso-$n",
    accessExpiresAtMs = venceElAcceso,
    refreshToken = "refresco-$n",
    refreshExpiresAtMs = AHORA + 30L * 24 * 60 * 60_000,
    userId = "u_1",
)

internal fun respuestaOk(dato: String) = RespuestaHttp(200, """{"data":$dato}""")

internal fun respuestaConSesion(sesion: Sesion) =
    respuestaOk(Json.encodeToString(Sesion.serializer(), sesion))

internal fun rechazo(http: Int, codigo: String) =
    RespuestaHttp(http, """{"error":{"code":"$codigo","message":"de mentira"}}""")

internal const val PERFIL_JSON = """{"id":"u_1","email":"a@b.c","created_at_ms":1,"updated_at_ms":2}"""

internal const val HEALTH_JSON = """{"status":"ok","version":"1.0.0","dependencies":{"database":"ok","redis":"ok"}}"""
