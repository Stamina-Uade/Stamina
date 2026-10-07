package com.tecladus.trainer

import com.tecladus.trainer.pantallas.acceso.slideTrasDeslizar
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * A qué slide lleva deslizar el dedo en la bienvenida.
 *
 * Corre en la JVM, sin emulador. Es la regla sola: que el dedo de verdad llegue hasta
 * ella —en cualquier parte de la pantalla, contando desde donde se apoyó y sin quitarle
 * el toque a los botones— lo mira `DeslizarLaBienvenidaEnPantallaTest`, en el emulador.
 */
class DeslizarLaBienvenidaTest {

    // Los números de un teléfono de densidad 2,625, como el emulador: el objetivo táctil
    // son 126 px y la velocidad mínima de un fling, 131 px/s. La regla no depende de ellos.
    private val umbral = 126f
    private val rapido = 131f

    private fun destino(desde: Int, recorrido: Float, velocidad: Float = 0f, total: Int = 3): Int =
        slideTrasDeslizar(desde, total, recorrido, velocidad, umbral, rapido)

    @Test
    fun `hacia la izquierda va el siguiente y desde el ultimo da la vuelta`() {
        assertEquals(1, destino(desde = 0, recorrido = -umbral * 3))
        assertEquals(2, destino(desde = 1, recorrido = -umbral * 3))
        assertEquals(0, destino(desde = 2, recorrido = -umbral * 3))
    }

    @Test
    fun `hacia la derecha va el anterior y desde el primero da la vuelta`() {
        assertEquals(1, destino(desde = 2, recorrido = umbral * 3))
        assertEquals(0, destino(desde = 1, recorrido = umbral * 3))
        assertEquals(2, destino(desde = 0, recorrido = umbral * 3))
    }

    @Test
    fun `un recorrido corto sin velocidad no pasa`() {
        assertEquals(1, destino(desde = 1, recorrido = -(umbral - 1)))
        assertEquals(1, destino(desde = 1, recorrido = umbral - 1))
        // Con algo de velocidad, pero menos que un fling, tampoco.
        assertEquals(1, destino(desde = 1, recorrido = -umbral / 4, velocidad = -(rapido - 1)))
        // El objetivo táctil justo ya cuenta.
        assertEquals(2, destino(desde = 1, recorrido = -umbral))
        assertEquals(0, destino(desde = 1, recorrido = umbral))
    }

    @Test
    fun `un gesto rapido y corto si pasa`() {
        assertEquals(2, destino(desde = 1, recorrido = -umbral / 4, velocidad = -rapido))
        assertEquals(0, destino(desde = 1, recorrido = umbral / 4, velocidad = rapido * 10))
    }

    @Test
    fun `un gesto rapido en contra del recorrido no pasa`() {
        assertEquals(1, destino(desde = 1, recorrido = -umbral / 4, velocidad = rapido * 10))
        assertEquals(1, destino(desde = 1, recorrido = umbral / 4, velocidad = -rapido * 10))
        // Sin recorrido no hay lado: la velocidad sola no decide.
        assertEquals(1, destino(desde = 1, recorrido = 0f, velocidad = -rapido * 10))
        // Y la velocidad no le resta a un recorrido que ya alcanzó.
        assertEquals(2, destino(desde = 1, recorrido = -umbral * 2, velocidad = rapido * 10))
    }

    @Test
    fun `con un solo slide no hay adonde ir`() {
        assertEquals(0, destino(desde = 0, recorrido = -umbral * 3, velocidad = -rapido * 10, total = 1))
        assertEquals(0, destino(desde = 0, recorrido = umbral * 3, velocidad = rapido * 10, total = 1))
    }
}
