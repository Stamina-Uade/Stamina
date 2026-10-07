package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.DispositivoDeOrigen
import com.tecladus.trainer.core.red.DispositivoDeOrigen.RELOJ
import com.tecladus.trainer.core.red.DispositivoDeOrigen.TELEFONO
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests de la fusión de series (decisión 0006), del lado del teléfono.
 *
 * 🛑 Son, uno por uno y con los mismos números, los casos de
 * `backend/test/unit.fusion.test.ts` —que a su vez son los de
 * `ios/TrainerCore/Tests/TrainerCoreTests/FusionDeSeriesTests.swift` más los que sólo
 * existen en el servidor—. Es a propósito: teléfono, reloj y servidor corren la misma
 * regla, y si uno fusionara distinto divergirían en silencio. Si cambia un caso allá,
 * cambia acá.
 */
class FusionDeSeriesTest {

    /** El `serie(numero, {...})` del test del servidor, con los mismos valores por defecto. */
    private fun serie(
        numero: Int,
        ejercicio: String = "press-banca",
        hecha: Boolean = true,
        reps: Int = 8,
        kg: Int? = 45,
        servidor: Long? = null,
        local: Long = 1_000,
        de: DispositivoDeOrigen = TELEFONO,
        extra: Boolean = false,
    ) = SerieRegistrada(
        ejercicioId = ejercicio,
        numero = numero,
        hecha = hecha,
        repeticiones = reps,
        pesoG = kg?.let { it * 1000 },
        salteada = false,
        esExtra = extra,
        registradaLocalMs = local,
        recibidaEnServidorMs = servidor,
        dispositivo = de,
    )

    private fun fusionar(a: SerieRegistrada, b: SerieRegistrada) = FusionDeSeries.fusionar(a, b)

    private fun unir(unas: List<SerieRegistrada>, otras: List<SerieRegistrada>) = FusionDeSeries.unir(unas, otras)

    // ------------------------------------------- lo que pidió Iván, al pie de la letra --

    @Test
    fun `la misma serie en los dos dispositivos queda como una sola`() {
        val unidas = unir(listOf(serie(2, local = 2_000, de = RELOJ)), listOf(serie(2, local = 1_000)))
        assertEquals("la misma serie física no puede quedar duplicada", 1, unidas.size)
        assertEquals(true, unidas[0].hecha)
    }

    @Test
    fun `series distintas se unen`() {
        val unidas = unir(listOf(serie(2, de = RELOJ)), listOf(serie(3)))
        assertEquals(listOf(2, 3), unidas.map { it.numero })
    }

    @Test
    fun `lo que registro el reloj aparece en el telefono`() {
        val unidas = unir(emptyList(), listOf(serie(1, de = RELOJ), serie(2, de = RELOJ)))
        assertEquals(2, unidas.size)
        assertTrue(unidas.all { it.hecha })
    }

    // ------------------------------------------------------ las tres reglas del modelo --

    @Test
    fun `regla 2 - ninguna sincronizacion desmarca una serie`() {
        val sinMarcar = serie(2, hecha = false, local = 9_000)
        val marcada = serie(2, hecha = true, local = 1_000, de = RELOJ)
        assertEquals(true, fusionar(sinMarcar, marcada).hecha)
    }

    @Test
    fun `regla 3 - nunca se mezclan los campos de dos versiones`() {
        val delReloj = serie(2, reps = 8, kg = 45, local = 2_000, de = RELOJ)
        val delTelefono = serie(2, reps = 6, kg = 40, local = 1_000)
        val f = fusionar(delReloj, delTelefono)
        // Gana el reloj ENTERO: 8 × 45. Nunca 8 × 40 ni 6 × 45.
        assertEquals(8, f.repeticiones)
        assertEquals(45_000, f.pesoG)
    }

    @Test
    fun `lo que llego al servidor le gana a lo que no llego, aunque el reloj local sea mas nuevo`() {
        val llego = serie(2, reps = 6, servidor = 500, local = 1)
        val soloLocal = serie(2, reps = 9, servidor = null, local = 999_999, de = RELOJ)
        assertEquals(6, fusionar(llego, soloLocal).repeticiones)
    }

    @Test
    fun `entre dos que llegaron al servidor gana la mas nueva`() {
        val vieja = serie(2, reps = 6, servidor = 100)
        val nueva = serie(2, reps = 9, servidor = 200, de = RELOJ)
        assertEquals(9, fusionar(vieja, nueva).repeticiones)
    }

    // ------------------------------------------- las propiedades que hacen que no diverjan --

    @Test
    fun `es conmutativa, incluso con el mismo momento exacto`() {
        val a = serie(2, reps = 8, local = 1_000, de = RELOJ)
        val b = serie(2, reps = 6, local = 1_000, de = TELEFONO)
        assertEquals(fusionar(a, b), fusionar(b, a))
    }

    @Test
    fun `es idempotente`() {
        val a = serie(2, reps = 8, de = RELOJ)
        assertEquals(a, fusionar(a, a))
        val unaVez = unir(listOf(a), emptyList())
        assertEquals(unaVez, unir(unaVez, unaVez))
    }

    @Test
    fun `es asociativa`() {
        val a = serie(2, reps = 8, local = 3_000, de = RELOJ)
        val b = serie(2, reps = 6, local = 2_000)
        val c = serie(2, reps = 7, servidor = 50, local = 1_000)
        assertEquals(fusionar(fusionar(a, b), c), fusionar(a, fusionar(b, c)))
    }

    @Test
    fun `los dos dispositivos llegan al mismo resultado`() {
        val enElReloj = listOf(serie(1, de = RELOJ), serie(2, reps = 8, local = 5_000, de = RELOJ))
        val enElTelefono = listOf(serie(2, reps = 6, local = 4_000), serie(3))
        val comoLoVeElReloj = unir(enElReloj, enElTelefono)
        assertEquals(comoLoVeElReloj, unir(enElTelefono, enElReloj))
        assertEquals(3, comoLoVeElReloj.size)
    }

    // --------------------------------------------------- lo que sólo pasa en el servidor --

    @Test
    fun `una escritura nueva llega con hora de servidor y reemplaza la fila entera, sin desmarcar`() {
        val guardada = serie(2, reps = 8, kg = 45, servidor = 100, de = RELOJ)
        val entrante = serie(2, reps = 6, kg = 40, hecha = false, servidor = 200, local = 1)
        val f = fusionar(guardada, entrante)
        assertEquals("gana la última en llegar, aunque su reloj local sea viejo", 6, f.repeticiones)
        assertEquals(40_000, f.pesoG)
        assertEquals("y aun así no se desmarca", true, f.hecha)
    }

    @Test
    fun `la misma serie dos veces en un lote - con la misma llegada, ordena el momento local`() {
        val antes = serie(4, reps = 5, servidor = 300, local = 10)
        val despues = serie(4, reps = 7, servidor = 300, local = 20)
        assertEquals(7, unir(emptyList(), listOf(despues, antes))[0].repeticiones)
        assertEquals(7, unir(emptyList(), listOf(antes, despues))[0].repeticiones)
    }

    @Test
    fun `una sincronizacion de un ejercicio no toca las series de otro`() {
        val guardadas = listOf(serie(1, ejercicio = "dominadas", servidor = 10), serie(1, servidor = 10))
        val unidas = unir(guardadas, listOf(serie(1, reps = 3, servidor = 20)))
        assertEquals(2, unidas.size)
        assertEquals(8, unidas.first { it.ejercicioId == "dominadas" }.repeticiones)
    }

    @Test
    fun `fusionar dos series distintas es un error de programacion, no un dato`() {
        assertThrows(IllegalArgumentException::class.java) { fusionar(serie(1), serie(2)) }
    }

    // ------------------------------------------------------- lo que agrega Kotlin --

    @Test
    fun `el empate exacto lo decide el nombre del contrato y no el orden del enum`() {
        // Mismo momento, ninguna llegó: decide el dispositivo, por su nombre crudo como en
        // el servidor ("telefono" > "reloj"). Con el ordinal del enum ganaría el reloj, y el
        // teléfono y el servidor elegirían filas distintas para la misma serie.
        val delReloj = serie(2, reps = 8, local = 1_000, de = RELOJ)
        val delTelefono = serie(2, reps = 6, local = 1_000, de = TELEFONO)
        assertEquals(6, fusionar(delReloj, delTelefono).repeticiones)
    }
}
