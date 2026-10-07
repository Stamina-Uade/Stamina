package com.tecladus.trainer.core.gimnasio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La regla de precarga y los tres casos de toda sesión, verificados.
 *
 * Estos tests son la razón por la que `Sesion.kt` está en `:core` y no dentro de
 * la pantalla: corren en la JVM, sin emulador, en dos segundos. La regla de
 * precarga se cerró el 2026-09-08 (`ESPECIFICACION.md` §6.2) y es determinística
 * a propósito — si alguien la "mejora" con una heurística de progresión, estos
 * tests lo dicen.
 */
class SesionTest {

    private fun press(pesos: List<Double>, reps: Int = 8) = Ejercicio(
        id = "press-banca",
        unidad = UnidadDeCarga.KILOS,
        descansoSegundos = 90,
        prescripcion = pesos.map { SerieObjetivo(reps = reps, peso = it) },
    )

    /** Cuatro series iguales: el caso normal. */
    private fun parejo() = EstadoDelEjercicio(press(listOf(45.0, 45.0, 45.0, 45.0)))

    /** Rampa de aproximación: el peso sube serie a serie. Con un string era inexpresable. */
    private fun rampa() = EstadoDelEjercicio(
        Ejercicio(
            id = "press-banca",
            unidad = UnidadDeCarga.KILOS,
            descansoSegundos = 90,
            prescripcion = listOf(
                SerieObjetivo(10, 40.0),
                SerieObjetivo(8, 45.0),
                SerieObjetivo(8, 45.0),
                SerieObjetivo(6, 47.5),
            ),
        ),
    )

    // --------------------------------------------------------- regla de precarga

    @Test
    fun `con peso parejo, la primera serie se precarga con el objetivo`() {
        val e = parejo()
        assertEquals(Precarga(8, 45.0, OrigenDeLaPrecarga.OBJETIVO), e.precarga(0))
    }

    @Test
    fun `con peso parejo, precarga lo ULTIMO que se hizo y no lo que pedia el plan`() {
        // Levantó 42.5 en vez de 45: la serie siguiente arranca en 42.5, no en 45.
        val e = parejo().confirmar(reps = 8, peso = 42.5)
        assertEquals(Precarga(8, 42.5, OrigenDeLaPrecarga.ULTIMA_HECHA), e.precarga(1))
    }

    @Test
    fun `con peso en rampa, precarga el objetivo de ESA serie y no la anterior`() {
        val e = rampa().confirmar(reps = 10, peso = 40.0)
        // La serie 2 pide 45 aunque la persona venga de levantar 40: lo dice el plan.
        assertEquals(Precarga(8, 45.0, OrigenDeLaPrecarga.OBJETIVO), e.precarga(1))
        assertEquals(Precarga(6, 47.5, OrigenDeLaPrecarga.OBJETIVO), e.precarga(3))
    }

    @Test
    fun `una serie salteada NO cuenta para la precarga de la siguiente`() {
        val e = parejo()
            .confirmar(reps = 8, peso = 42.5) // serie 1
            .saltear() // serie 2, salteada
        // La 3 se precarga con la 1, que es la última que se hizo de verdad.
        assertEquals(Precarga(8, 42.5, OrigenDeLaPrecarga.ULTIMA_HECHA), e.precarga(2))
    }

    // ------------------------------------------------- los tres casos de la sesión

    @Test
    fun `serie fallida se guarda como HECHA con el numero real, nunca como error`() {
        val e = parejo().confirmar(reps = 6, peso = 45.0) // pedía 8, hizo 6
        val chip = e.strip()[0]
        assertEquals(EstadoDeChip.HECHA, chip.estado)
        assertEquals("el chip muestra el dato real, que son 6", 6, chip.reps)
        assertEquals(1, e.hechasDeVerdad)
    }

    @Test
    fun `serie salteada cambia de FORMA, no solo de color`() {
        val e = parejo().saltear()
        assertEquals(EstadoDeChip.SALTEADA, e.strip()[0].estado)
        assertEquals("una salteada no suma al progreso", 0, e.hechasDeVerdad)
        assertEquals("el foco pasa solo a la siguiente", 1, e.serieEnFoco)
    }

    @Test
    fun `serie extra agrega un chip y el progreso pasa a 4 de 3 sin romperse`() {
        val tres = EstadoDelEjercicio(press(listOf(35.0, 35.0, 35.0), reps = 10))
        val e = tres
            .confirmar(10, 35.0)
            .confirmar(10, 35.0)
            .confirmar(10, 35.0)
            .agregarSerieExtra()
            .confirmar(10, 35.0)
        assertEquals("cuatro chips", 4, e.strip().size)
        assertEquals("cuatro hechas sobre tres prescriptas", 4, e.hechasDeVerdad)
        assertTrue("el cuarto esta marcado como fuera del plan", e.strip()[3].esExtra)
        assertFalse(e.strip()[0].esExtra)
    }

    // ------------------------------------------------------------------ corregir

    @Test
    fun `corregir apunta el foco a una serie ya hecha y la reescribe sin tocar las otras`() {
        val e = parejo()
            .confirmar(8, 45.0)
            .confirmar(6, 45.0)
            .corregir(0)

        assertEquals(0, e.serieEnFoco)
        assertEquals(EstadoDeChip.CORRIGIENDO, e.strip()[0].estado)
        assertEquals(
            "los campos muestran lo registrado, no la precarga",
            Precarga(8, 45.0, OrigenDeLaPrecarga.ULTIMA_HECHA),
            e.valoresDelFoco(),
        )

        val corregido = e.confirmar(7, 45.0)
        assertEquals(7, corregido.strip()[0].reps)
        assertEquals("la serie 2 quedo intacta", 6, corregido.strip()[1].reps)
        assertNull("se sale del modo corregir solo", corregido.corrigiendo)
        assertEquals("y el foco vuelve a la que toca", 2, corregido.serieEnFoco)
    }

    // -------------------------------------------------------------------- estados

    @Test
    fun `el strip distingue los cinco estados`() {
        val e = parejo()
            .confirmar(8, 45.0) // 0: hecha
            .saltear() // 1: salteada
        val strip = e.strip()
        assertEquals(EstadoDeChip.HECHA, strip[0].estado)
        assertEquals(EstadoDeChip.SALTEADA, strip[1].estado)
        assertEquals(EstadoDeChip.AHORA, strip[2].estado)
        assertEquals(EstadoDeChip.PENDIENTE, strip[3].estado)
        assertEquals(EstadoDeChip.CORRIGIENDO, e.corregir(0).strip()[0].estado)
    }

    @Test
    fun `con el ejercicio terminado no hay serie actual y el foco queda en la ultima`() {
        var e = parejo()
        repeat(4) { e = e.confirmar(8, 45.0) }
        assertNull(e.serieActual)
        assertEquals(3, e.serieEnFoco)
        assertEquals(4, e.hechasDeVerdad)
    }

    @Test
    fun `un ejercicio por tiempo no pretende ser un peso`() {
        val plancha = Ejercicio(
            id = "plancha",
            unidad = UnidadDeCarga.TIEMPO,
            descansoSegundos = 45,
            prescripcion = List(3) { SerieObjetivo(reps = 45, peso = 45.0) },
        )
        val e = EstadoDelEjercicio(plancha)
        assertEquals(UnidadDeCarga.TIEMPO, e.ejercicio.unidad)
        // 45 y 45: segundos de plancha y segundos de pausa. La pantalla los rotula
        // distinto; el modelo no los confunde porque la unidad lo dice.
        assertEquals(Precarga(45, 45.0, OrigenDeLaPrecarga.OBJETIVO), e.precarga(0))
    }

    // ------------------------------------------- la tabla: previa, borradores y tilde

    @Test
    fun `sin nada hecho hoy, precarga lo de la sesion anterior y no el objetivo`() {
        val e = parejo().copy(
            previas = mapOf(0 to SerieHecha(8, 50.0), 1 to SerieHecha(8, 50.0)),
        )
        // El plan dice 45 en todas; la vez pasada levanto 50. Manda lo que levanto.
        assertEquals(Precarga(8, 50.0, OrigenDeLaPrecarga.SESION_ANTERIOR), e.precarga(0))
    }

    @Test
    fun `lo de esta sesion le gana a lo de la anterior`() {
        val e = parejo()
            .copy(previas = mapOf(0 to SerieHecha(8, 50.0), 1 to SerieHecha(8, 50.0)))
            .confirmar(8, 47.5)
        assertEquals(Precarga(8, 47.5, OrigenDeLaPrecarga.ULTIMA_HECHA), e.precarga(1))
    }

    @Test
    fun `el plan en rampa le gana a todo, incluida la sesion anterior`() {
        val e = rampa().copy(previas = mapOf(1 to SerieHecha(8, 60.0)))
        assertEquals(Precarga(8, 45.0, OrigenDeLaPrecarga.OBJETIVO), e.precarga(1))
    }

    @Test
    fun `se puede escribir en una fila sin marcarla`() {
        val e = parejo().escribirEnLaFila(2, reps = 12, peso = 40.0)
        assertEquals(12, e.valoresDeLaFila(2).reps)
        assertEquals(40.0, e.valoresDeLaFila(2).peso, 0.001)
        assertFalse("escribir no la marca", e.estaMarcada(2))
        assertEquals("y no suma al progreso", 0, e.hechasDeVerdad)
    }

    @Test
    fun `el tilde marca lo que la fila muestra`() {
        val e = parejo().escribirEnLaFila(0, 6, 42.5).alternarLaFila(0)
        assertTrue(e.estaMarcada(0))
        assertEquals(1, e.hechasDeVerdad)
        assertEquals(SerieHecha(6, 42.5), e.hechas[0])
    }

    @Test
    fun `destildar NO borra el numero, lo deja como borrador`() {
        val e = parejo().escribirEnLaFila(0, 6, 42.5).alternarLaFila(0).alternarLaFila(0)
        assertFalse(e.estaMarcada(0))
        assertEquals("el 6 sigue ahi", 6, e.valoresDeLaFila(0).reps)
        assertEquals(42.5, e.valoresDeLaFila(0).peso, 0.001)
        assertEquals(0, e.hechasDeVerdad)
    }

    @Test
    fun `editar una fila ya marcada la corrige sin desmarcarla`() {
        val e = parejo().alternarLaFila(0).escribirEnLaFila(0, 7, 45.0)
        assertTrue("sigue marcada", e.estaMarcada(0))
        assertEquals(7, e.hechas.getValue(0).reps)
        assertEquals("y sigue contando una sola vez", 1, e.hechasDeVerdad)
    }

    @Test
    fun `las filas se pueden marcar fuera de orden`() {
        val e = parejo().alternarLaFila(2).alternarLaFila(0)
        assertTrue(e.estaMarcada(0))
        assertFalse(e.estaMarcada(1))
        assertTrue(e.estaMarcada(2))
        assertEquals(2, e.hechasDeVerdad)
        assertEquals("la que toca es la primera sin marcar", 1, e.serieActual)
    }

    // ------------------------------------------------- borrar una serie y deshacer

    @Test
    fun `borrar una serie la saca de la tabla y del progreso`() {
        val e = parejo().alternarLaFila(0).alternarLaFila(1).borrarSerie(1)
        assertEquals("quedan tres filas", 3, e.strip().size)
        assertEquals("y una sola cuenta", 1, e.hechasDeVerdad)
        assertEquals(listOf(0, 2, 3), e.filasVisibles)
    }

    @Test
    fun `deshacer devuelve la serie CON lo que tenia adentro`() {
        val e = parejo().escribirEnLaFila(1, 7, 42.5).alternarLaFila(1)
        val borrada = e.borrarSerie(1)
        assertEquals(0, borrada.hechasDeVerdad)

        val vuelta = borrada.restaurarSerie(1)
        assertTrue("vuelve marcada", vuelta.estaMarcada(1))
        assertEquals("y con el 7 que tenia", 7, vuelta.valoresDeLaFila(1).reps)
        assertEquals(42.5, vuelta.valoresDeLaFila(1).peso, 0.001)
        assertEquals(1, vuelta.hechasDeVerdad)
    }

    @Test
    fun `una serie borrada no cuenta para la precarga de las que siguen`() {
        val e = parejo()
            .escribirEnLaFila(0, 8, 50.0).alternarLaFila(0)
            .borrarSerie(0)
        // Sin nada hecho que valga, cae al objetivo del plan.
        assertEquals(Precarga(8, 45.0, OrigenDeLaPrecarga.OBJETIVO), e.precarga(1))
    }

    @Test
    fun `la que toca saltea las borradas`() {
        val e = parejo().borrarSerie(0)
        assertEquals(1, e.serieActual)
        assertEquals(1, e.serieEnFoco)
    }

    // -------------------------------------------------------- descanso del ejercicio

    @Test
    fun `el descanso sale del plan salvo que la persona lo cambie`() {
        val e = parejo()
        assertEquals(90, e.descansoSegundos)
        assertEquals(120, e.conDescanso(120).descansoSegundos)
    }

    @Test
    fun `un descanso de cero es valido porque existen las superseries`() {
        assertEquals(0, parejo().conDescanso(0).descansoSegundos)
    }

    @Test
    fun `el descanso tiene tope, porque diez minutos ya es otra sesion`() {
        assertEquals(
            EstadoDelEjercicio.DESCANSO_MAXIMO,
            parejo().conDescanso(99999).descansoSegundos,
        )
        assertEquals(
            EstadoDelEjercicio.DESCANSO_MINIMO,
            parejo().conDescanso(-30).descansoSegundos,
        )
    }
}
