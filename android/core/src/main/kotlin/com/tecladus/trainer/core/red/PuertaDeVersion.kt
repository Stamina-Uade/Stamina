package com.tecladus.trainer.core.red

/**
 * Qué hacer con la respuesta de `GET /version`. AGENTS.md §5.1 y docs/API.md §4.
 */
sealed interface DecisionDeVersion {

    /** Seguir. Incluye "no se pudo preguntar": una puerta rota no deja a nadie afuera. */
    data object Pasar : DecisionDeVersion

    /** Hay una versión mejor. Se avisa, y el aviso se puede descartar. */
    data class Recomendar(val puerta: VersionGate) : DecisionDeVersion

    /** Esta versión ya no puede seguir. Pantalla bloqueante, sin salida a la app. */
    data class Bloquear(val puerta: VersionGate) : DecisionDeVersion
}

/**
 * La puerta de versión mínima, del lado del cliente.
 *
 * Es lógica pura y vive en `:core` para poder probarla sin un teléfono. Qué hacer
 * con cada respuesta posible es justo lo que se rompe en silencio: una puerta que
 * por un error deja a todos afuera no se ve en el emulador de quien la escribió,
 * que siempre tiene la última versión.
 */
object PuertaDeVersion {

    const val ACCION_OK = "ok"
    const val ACCION_RECOMENDADA = "update_recommended"
    const val ACCION_OBLIGATORIA = "update_required"

    /**
     * 🛑 **Todo lo que no es una respuesta clara deja pasar**: sin red, un 503, un 400,
     * un sobre raro. docs/API.md §4 lo decide así y es a propósito: una puerta de
     * versión que se rompe no puede dejar a todo el mundo afuera de la app. Lo único
     * que bloquea es el servidor diciendo `update_required` con todas las letras.
     *
     * @param build el `versionCode` de esta app. Sólo se usa si llega una `action`
     *   que esta versión no conoce —el contrato puede sumar valores—: ahí se compara
     *   con los números, que sí conoce.
     */
    fun decidir(respuesta: Resultado<VersionGate>, build: Long): DecisionDeVersion {
        val puerta = (respuesta as? Resultado.Ok)?.dato ?: return DecisionDeVersion.Pasar
        return when (puerta.action) {
            ACCION_OBLIGATORIA -> DecisionDeVersion.Bloquear(puerta)
            ACCION_RECOMENDADA -> DecisionDeVersion.Recomendar(puerta)
            ACCION_OK -> DecisionDeVersion.Pasar
            else -> when {
                build < puerta.minimumBuild -> DecisionDeVersion.Bloquear(puerta)
                build < puerta.recommendedBuild -> DecisionDeVersion.Recomendar(puerta)
                else -> DecisionDeVersion.Pasar
            }
        }
    }

    /**
     * El texto del servidor, cuando corresponde mostrarlo.
     *
     * docs/API.md §4: el cliente prefiere su propia traducción del `code`, y `message`
     * es el respaldo para un `code` que esta versión todavía no conoce. Sin `code`, o
     * con uno conocido, devuelve `null` y la pantalla usa su propio texto.
     */
    fun mensajeDelServidor(puerta: VersionGate, codigosConocidos: Set<String>): String? {
        val codigo = puerta.code ?: return null
        if (codigo in codigosConocidos) return null
        return puerta.message?.takeIf { it.isNotBlank() }
    }

    /**
     * A dónde mandar a actualizar: la `store_url` del servidor si es `https:` o
     * `market:`, y si no, la ficha de Play de [idDeLaApp].
     *
     * El esquema se revisa porque es un texto que llega por la red y termina en un
     * `Intent`: un `intent:` o un `file:` ahí no tiene nada que hacer.
     */
    fun direccionDeLaTienda(puerta: VersionGate?, idDeLaApp: String): String {
        val delServidor = puerta?.storeUrl?.trim().orEmpty()
        val esquema = delServidor.substringBefore(':', missingDelimiterValue = "").lowercase()
        val sirve = esquema in ESQUEMAS_DE_TIENDA && delServidor.length > esquema.length + 1
        return if (sirve) delServidor else "https://play.google.com/store/apps/details?id=$idDeLaApp"
    }

    private val ESQUEMAS_DE_TIENDA = setOf("https", "market")
}
