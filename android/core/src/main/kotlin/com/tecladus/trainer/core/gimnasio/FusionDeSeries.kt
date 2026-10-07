package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.DispositivoDeOrigen
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Una versión de una serie registrada, tal como la fusiona la decisión 0006.
 *
 * Es la fila que se guarda en el teléfono y la que viaja: lo que la pantalla muestra se
 * arma desde acá (ver `SeriesDeLaRutina`), y no al revés.
 *
 * La sesión no está adentro: una serie se fusiona siempre dentro de SU sesión, y quien
 * las guarda las agrupa por sesión.
 *
 * Los nombres de `@SerialName` son los del archivo del teléfono, no los del contrato: lo
 * que viaja se arma con `SerieDeGimnasioEntrada`.
 */
@Serializable
data class SerieRegistrada(
    @SerialName("ejercicio")
    val ejercicioId: String,
    /** 1-based, igual que en el contrato. Las extra siguen numerando. */
    @SerialName("numero")
    val numero: Int,
    @SerialName("hecha")
    val hecha: Boolean,
    @SerialName("repeticiones")
    val repeticiones: Int,
    /** Gramos. `null` = peso corporal. */
    @SerialName("peso_g")
    val pesoG: Int?,
    @SerialName("salteada")
    val salteada: Boolean,
    @SerialName("extra")
    val esExtra: Boolean,
    @SerialName("registrada_ms")
    val registradaLocalMs: Long,
    /** `null` mientras no llegó al servidor: eso es lo que la hace PENDIENTE. */
    @SerialName("recibida_ms")
    val recibidaEnServidorMs: Long?,
    @SerialName("dispositivo")
    val dispositivo: DispositivoDeOrigen,
) {
    val clave: ClaveDeSerie
        get() = ClaveDeSerie(ejercicioId, numero)

    val pendiente: Boolean
        get() = recibidaEnServidorMs == null
}

/** La identidad de una serie dentro de su sesión: (ejercicio, número). Nunca un id al azar. */
data class ClaveDeSerie(val ejercicioId: String, val numero: Int)

/**
 * Cómo se fusionan dos versiones de la misma serie: la decisión 0006, del lado del teléfono.
 *
 * 🛑 Es a propósito LA MISMA FUNCIÓN que `backend/src/dominios/gimnasio/fusion.ts` y que
 * `SerieRegistrada.fusionar` en TrainerCore (iOS), caso por caso, y `FusionDeSeriesTest`
 * corre los mismos casos que `backend/test/unit.fusion.test.ts`. Si el teléfono, el reloj
 * y el servidor fusionaran distinto, divergirían en silencio: cada uno creería tener la
 * sesión bien.
 *
 *   1. La identidad es determinística: (sesión, ejercicio, número).
 *   2. `hecha` es monotónica: al fusionar sólo va de false a true.
 *   3. La fusión es por FILA COMPLETA, nunca por campo. Gana, en este orden: lo que llegó al
 *      servidor sobre lo que no llegó; entre dos que llegaron, la que llegó después; si no,
 *      el momento local; y en empate exacto, el dispositivo —no porque uno sea mejor, sino
 *      para que el orden sea TOTAL—.
 *
 * Tiene que ser conmutativa, asociativa e idempotente, y los tests lo verifican.
 */
object FusionDeSeries {

    /** ¿Gana `a` sobre `b`? El orden es total y determinístico. */
    private fun gana(a: SerieRegistrada, b: SerieRegistrada): Boolean {
        val ta = a.recibidaEnServidorMs
        val tb = b.recibidaEnServidorMs
        if (ta != null && tb != null && ta != tb) return ta > tb
        if (ta != null && tb == null) return true
        if (ta == null && tb != null) return false

        if (a.registradaLocalMs != b.registradaLocalMs) return a.registradaLocalMs > b.registradaLocalMs

        // Por el nombre crudo del contrato, como el `>` de strings del servidor y
        // `Dispositivo: Comparable` en Swift: "telefono" > "reloj". El ordinal del enum de
        // Kotlin daría el orden al revés, y el empate se resolvería distinto en cada lado.
        return crudo(a.dispositivo) > crudo(b.dispositivo)
    }

    /** Fusiona dos versiones de LA MISMA serie. Dos series distintas es un error de programación. */
    fun fusionar(a: SerieRegistrada, b: SerieRegistrada): SerieRegistrada {
        require(a.clave == b.clave) { "fusion: sólo se fusionan versiones de la misma serie" }
        val ganadora = if (gana(a, b)) a else b
        // La fila entera viene de quien ganó (regla 3); `hecha` es la excepción (regla 2).
        return ganadora.copy(hecha = a.hecha || b.hecha)
    }

    /** Une dos conjuntos: misma clave se fusiona, clave distinta se agrega. */
    fun unir(unas: List<SerieRegistrada>, otras: List<SerieRegistrada>): List<SerieRegistrada> {
        val porClave = HashMap<ClaveDeSerie, SerieRegistrada>()
        for (s in unas + otras) {
            val previa = porClave[s.clave]
            porClave[s.clave] = if (previa == null) s else fusionar(previa, s)
        }
        // El orden de pantalla: por ejercicio y número, igual que en el servidor y en Swift.
        return porClave.values.sortedWith(compareBy<SerieRegistrada> { it.ejercicioId }.thenBy { it.numero })
    }

    /** El valor del contrato (`telefono`, `reloj`), leído del serializador generado y no escrito a mano. */
    private fun crudo(d: DispositivoDeOrigen): String =
        DispositivoDeOrigen.serializer().descriptor.getElementName(d.ordinal)
}
