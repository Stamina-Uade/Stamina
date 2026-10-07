package com.tecladus.trainer.core.red

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * El cable, separado del cliente.
 *
 * [ClienteApi] decide QUÉ se pide —el sobre del contrato, los headers, cuándo
 * renovar la sesión— y esto sólo lo lleva y lo trae. Están separados para poder
 * probar lo primero sin red: los tests de `:core` le pasan un transporte de
 * mentira y ejercitan la renovación, los reintentos y las carreras sin depender de
 * un servidor corriendo.
 */
fun interface Transporte {

    /**
     * Manda el pedido y devuelve lo que contestó el servidor, sea el status que sea.
     *
     * @throws IOException si no se pudo llegar: sin señal, timeout, servidor caído.
     *   Es la única excepción esperable, y el cliente la convierte en
     *   [Resultado.SinRed].
     */
    suspend fun ejecutar(pedido: PedidoHttp): RespuestaHttp
}

/**
 * Un pedido listo para salir: método, URL completa, headers y cuerpo.
 *
 * 🛑 **No es `data class`, a propósito.** El `toString()` de una data class imprime
 * todos los campos, y acá adentro viajan el `Authorization` con el access y el
 * cuerpo de `/auth/refresh` con el refresh. Un `println(pedido)` escrito en un
 * apuro dejaría una credencial en el logcat (AGENTS.md §12.1). Éste imprime el
 * método y nada más: tampoco la URL, que puede llevar un id (§8).
 */
class PedidoHttp(
    val metodo: String,
    val url: String,
    val headers: Map<String, String>,
    val cuerpo: String?,
) {
    override fun toString(): String = "PedidoHttp($metodo)"
}

/**
 * Lo que volvió: el status HTTP y el cuerpo crudo, vacío si no hubo (un 204).
 *
 * Tampoco imprime el cuerpo: la respuesta de un login o de una renovación ES la
 * sesión, con los dos tokens adentro.
 */
class RespuestaHttp(val codigo: Int, val cuerpo: String) {
    override fun toString(): String = "RespuestaHttp($codigo)"
}

/**
 * El transporte del teléfono, sobre `HttpURLConnection`.
 *
 * Está escrito así a propósito: es lo que Android trae, y una app que existe para
 * funcionar en el sótano de un gimnasio no gana nada cargando otra librería de red.
 * Si algún día hace falta HTTP/2 o interceptores, se cambia acá adentro y ninguna
 * pantalla se entera.
 *
 * El certificado se valida contra las autoridades del sistema y desde acá no hay
 * forma de apagarlo (AGENTS.md §12.1). Si se permite tráfico en claro, y con quién,
 * lo decide la configuración de red de la app, no este código.
 */
class TransporteHttp(
    private val esperaMs: Int = ClienteApi.ESPERA_POR_DEFECTO_MS,
) : Transporte {

    override suspend fun ejecutar(pedido: PedidoHttp): RespuestaHttp = withContext(Dispatchers.IO) {
        var conexion: HttpURLConnection? = null
        try {
            conexion = (URL(pedido.url).openConnection() as HttpURLConnection).apply {
                requestMethod = pedido.metodo
                connectTimeout = esperaMs
                readTimeout = esperaMs
                pedido.headers.forEach { (nombre, valor) -> setRequestProperty(nombre, valor) }
                if (pedido.cuerpo != null) doOutput = true
            }
            if (pedido.cuerpo != null) {
                conexion.outputStream.use { it.write(pedido.cuerpo.toByteArray(Charsets.UTF_8)) }
            }
            val codigo = conexion.responseCode
            val flujo = if (codigo in 200..299) conexion.inputStream else conexion.errorStream
            val texto = flujo?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            RespuestaHttp(codigo, texto)
        } finally {
            conexion?.disconnect()
        }
    }
}
