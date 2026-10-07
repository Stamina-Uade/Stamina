package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.DispositivoDeOrigen
import com.tecladus.trainer.core.red.EjercicioDeRutina
import com.tecladus.trainer.core.red.RutinaDelDia
import com.tecladus.trainer.core.red.SeriePrescritaDeRutina
import com.tecladus.trainer.core.red.SesionDeGimnasio
import java.util.TimeZone
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * El puente entre la rutina del servidor, la pantalla y las series que se guardan.
 *
 * Las rutinas son las respuestas REALES de `src/test/resources/respuestas-1.1.0/`: lo que
 * se prueba es que lo que manda el servidor llegue a la tabla con el número que corresponde,
 * y que lo que se toca en la tabla vuelva como la serie que el servidor espera.
 */
class SeriesDeLaRutinaTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun <T> dato(nombre: String, lector: kotlinx.serialization.KSerializer<T>): T {
        val crudo = requireNotNull(javaClass.getResource("/respuestas-1.1.0/$nombre.json")).readText()
        return json.decodeFromJsonElement(lector, json.parseToJsonElement(crudo).jsonObject.getValue("data"))
    }

    private val rutina: RutinaDelDia by lazy { dato("rutina-con-series-previas", RutinaDelDia.serializer()) }

    /** La zancada: con banco, en kilos, 3 × 10, y la vez pasada 10 × 12 kg y 8 con su peso. */
    private fun zancada(): EstadoDelEjercicio = SeriesDeLaRutina.estadosDe(rutina, emptyList()).first()

    // ------------------------------------------------------ del servidor a la tabla --

    @Test
    fun `la rutina del servidor llega a la tabla con su prescripcion, su descanso y la columna PREVIA`() {
        val estados = SeriesDeLaRutina.estadosDe(rutina, emptyList())

        assertEquals(rutina.exercises.map { it.exerciseId }, estados.map { it.ejercicio.id })
        val z = estados.first()
        assertEquals("estocada-deficit", z.ejercicio.id)
        assertEquals(UnidadDeCarga.KILOS, z.ejercicio.unidad)
        assertEquals(75, z.descansoSegundos)
        assertEquals(listOf(10, 10, 10), z.objetivos.map { it.reps })
        assertEquals("el motor no prescribe carga", listOf(0.0, 0.0, 0.0), z.objetivos.map { it.peso })
        assertEquals(SerieHecha(10, 12.0), z.previas[0])
        assertEquals("sin weight_g es peso corporal", SerieHecha(8, 0.0), z.previas[1])
        // Y la PREVIA precarga la primera serie del día, que es para lo que existe.
        assertEquals(Precarga(10, 12.0, OrigenDeLaPrecarga.SESION_ANTERIOR), z.precarga(0))
        assertEquals(UnidadDeCarga.TIEMPO, estados.first { it.ejercicio.id == "plancha-pies-elevados" }.ejercicio.unidad)
    }

    @Test
    fun `sin equipo el peso es lastre, donde cero es solo el cuerpo`() {
        val flexiones = EjercicioDeRutina(
            exerciseId = "flexiones",
            name = "Flexiones",
            pattern = "empuje-horizontal",
            equipment = "ninguno",
            unit = "reps",
            label = "General",
            reason = "",
            restS = 60,
            sets = listOf(SeriePrescritaDeRutina(number = 2, reps = 10), SeriePrescritaDeRutina(number = 1, reps = 12)),
            previousSets = emptyList(),
        )

        val ejercicio = SeriesDeLaRutina.ejercicioDe(flexiones)

        assertEquals(UnidadDeCarga.LASTRE, ejercicio.unidad)
        assertEquals("la prescripción va en el orden de `number`, no en el de la lista", listOf(12, 10), ejercicio.prescripcion.map { it.reps })
    }

    // ------------------------------------------------------ de la tabla a las series --

    @Test
    fun `marcar, corregir, saltear y desmarcar se registran, y escribir un borrador no`() {
        val e0 = zancada()

        val e1 = e0.alternarLaFila(0)
        assertEquals(
            listOf(serie(1, hecha = true, reps = 10, pesoG = 12_000, ms = 1)),
            SeriesDeLaRutina.cambiosEntre(e0, e1, ahoraMs = 1),
        )

        val e2 = e1.escribirEnLaFila(1, reps = 9, peso = 14.0)
        assertTrue("un borrador no es una serie hecha", SeriesDeLaRutina.cambiosEntre(e1, e2, ahoraMs = 2).isEmpty())

        val e3 = e2.escribirEnLaFila(0, reps = 8, peso = 12.5)
        assertEquals(
            listOf(serie(1, hecha = true, reps = 8, pesoG = 12_500, ms = 3)),
            SeriesDeLaRutina.cambiosEntre(e2, e3, ahoraMs = 3),
        )

        val e4 = e3.copy(corrigiendo = 2).saltear()
        assertEquals(
            listOf(serie(3, hecha = false, salteada = true, reps = 0, pesoG = null, ms = 4)),
            SeriesDeLaRutina.cambiosEntre(e3, e4, ahoraMs = 4),
        )

        val e5 = e4.alternarLaFila(0)
        assertEquals(
            "desmarcar viaja con los números que quedan en la fila",
            listOf(serie(1, hecha = false, reps = 8, pesoG = 12_500, ms = 5)),
            SeriesDeLaRutina.cambiosEntre(e4, e5, ahoraMs = 5),
        )
    }

    @Test
    fun `una serie extra sigue numerando y va marcada como extra`() {
        val antes = zancada().agregarSerieExtra()
        val despues = antes.alternarLaFila(3)

        val cambio = SeriesDeLaRutina.cambiosEntre(antes, despues, ahoraMs = 7).single()

        assertEquals(4, cambio.numero)
        assertTrue(cambio.esExtra)
    }

    // ------------------------------------------------------ de las series a la tabla --

    @Test
    fun `lo registrado vuelve a la tabla y lo que es solo de la pantalla se queda`() {
        val enPantalla = zancada().copy(corrigiendo = 0, descansoElegido = 90)
        val series = listOf(
            serie(1, hecha = true, reps = 10, pesoG = 12_000, ms = 1),
            serie(2, hecha = false, salteada = true, reps = 0, pesoG = null, ms = 2),
            serie(3, hecha = false, reps = 7, pesoG = null, ms = 3),
            serie(5, hecha = true, reps = 6, pesoG = 10_000, ms = 4, extra = true),
        )

        val e = SeriesDeLaRutina.conSeries(enPantalla, series)

        assertEquals(mapOf(0 to SerieHecha(10, 12.0), 1 to SerieHecha(0, 0.0, salteada = true), 4 to SerieHecha(6, 10.0)), e.hechas)
        assertEquals("desmarcada vuelve como borrador", SerieHecha(7, 0.0), e.borradores[2])
        assertEquals("la serie 5 necesita dos extra", 2, e.extras)
        assertEquals(0, e.corrigiendo)
        assertEquals(90, e.descansoSegundos)
    }

    @Test
    fun `ida y vuelta - lo que la tabla registra se ve igual al volver del disco`() {
        val antes = zancada()
        val despues = antes.alternarLaFila(0).escribirEnLaFila(0, reps = 9, peso = 13.5).copy(corrigiendo = 1).saltear()

        val guardadas = SeriesDeLaRutina.cambiosEntre(antes, despues, ahoraMs = 10)
        val reabierta = SeriesDeLaRutina.estadosDe(rutina, guardadas).first()

        assertEquals(despues.hechas, reabierta.hechas)
    }

    @Test
    fun `los gramos del contrato - ausente es peso corporal, y con tiempo no hay peso`() {
        assertNull(SeriesDeLaRutina.gramosDe(0.0, UnidadDeCarga.KILOS))
        assertNull(SeriesDeLaRutina.gramosDe(0.0, UnidadDeCarga.LASTRE))
        assertEquals(12_500, SeriesDeLaRutina.gramosDe(12.5, UnidadDeCarga.KILOS))
        assertEquals(2_500, SeriesDeLaRutina.gramosDe(2.5, UnidadDeCarga.LASTRE))
        assertNull(SeriesDeLaRutina.gramosDe(45.0, UnidadDeCarga.TIEMPO))
        assertEquals(0.0, SeriesDeLaRutina.kilosDe(null), 0.0)
    }

    @Test
    fun `lo que vuelve del servidor se guarda con su hora de llegada, y viaja igual que llego`() {
        val sesion = dato("series-sincronizadas", SesionDeGimnasio.serializer())

        val registradas = sesion.sets.map(SeriesDeLaRutina::registradaDe)

        assertEquals(1_789_033_543_346L, registradas[0].recibidaEnServidorMs)
        assertEquals(DispositivoDeOrigen.RELOJ, registradas[1].dispositivo)
        assertNull(registradas[1].pesoG)
        val deVuelta = registradas.map(SeriesDeLaRutina::entradaDe)
        assertEquals(sesion.sets.map { it.exerciseId to it.number }, deVuelta.map { it.exerciseId to it.number })
        assertEquals(sesion.sets.map { it.recordedAtMs }, deVuelta.map { it.recordedAtMs })
        assertEquals(sesion.sets.map { it.weightG }, deVuelta.map { it.weightG })
    }

    // ------------------------------------------------------------ el id de la sesión --

    @Test
    fun `el id de la sesion es la fecha local del perfil, como la arma el servidor`() {
        // El par real de la respuesta: date_ms 1789009200000 es 00:00 del 10 en Buenos Aires.
        val medianoche = 1_789_009_200_000L
        assertEquals("gym-2026-09-10", idDeSesionDeGimnasio(medianoche, "America/Argentina/Buenos_Aires"))
        assertEquals("gym-2026-09-09", idDeSesionDeGimnasio(medianoche - 1, "America/Argentina/Buenos_Aires"))

        // Las 20 h UTC del 10: todavía el 10 en Buenos Aires, ya el 11 en Tokio.
        val veinteUtc = 1_789_070_400_000L
        assertEquals("gym-2026-09-10", idDeSesionDeGimnasio(veinteUtc, "America/Argentina/Buenos_Aires"))
        assertEquals("gym-2026-09-11", idDeSesionDeGimnasio(veinteUtc, "Asia/Tokyo"))
    }

    @Test
    fun `sin zona en el perfil, o con una que no existe, manda la del telefono`() {
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Tokyo"))
            val veinteUtc = 1_789_070_400_000L
            assertEquals("gym-2026-09-11", idDeSesionDeGimnasio(veinteUtc, null))
            assertEquals("gym-2026-09-11", idDeSesionDeGimnasio(veinteUtc, "Marte/Olympus"))
        } finally {
            TimeZone.setDefault(original)
        }
    }

    private fun serie(
        numero: Int,
        hecha: Boolean,
        reps: Int,
        pesoG: Int?,
        ms: Long,
        salteada: Boolean = false,
        extra: Boolean = false,
    ) = SerieRegistrada(
        ejercicioId = "estocada-deficit",
        numero = numero,
        hecha = hecha,
        repeticiones = reps,
        pesoG = pesoG,
        salteada = salteada,
        esExtra = extra,
        registradaLocalMs = ms,
        recibidaEnServidorMs = null,
        dispositivo = DispositivoDeOrigen.TELEFONO,
    )
}
