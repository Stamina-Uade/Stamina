package com.tecladus.trainer

import com.tecladus.trainer.domain.logic.GeoUtils
import com.tecladus.trainer.domain.model.TrackPoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GeoUtilsTest {

    private fun point(index: Int, lat: Double, lon: Double, alt: Double = 10.0) = TrackPoint(
        timestampMs = 1_700_000_000_000L + index * 1000L,
        latitude = lat,
        longitude = lon,
        altitudeM = alt,
        speedMps = 3.0,
        accuracyM = 5f
    )

    @Test
    fun `haversine mide bien una distancia conocida`() {
        // Obelisco -> Congreso (Buenos Aires), aproximadamente 1,5 km
        val d = GeoUtils.distanceMeters(-34.6037, -58.3816, -34.6097, -58.3925)
        assertTrue("Distancia esperada entre 1100 y 1300 m: $d", d in 1100.0..1300.0)
    }

    @Test
    fun `el desnivel ignora el ruido del gps`() {
        val ruido = listOf(
            point(0, -34.60, -58.38, 100.0),
            point(1, -34.601, -58.38, 101.5),
            point(2, -34.602, -58.38, 100.2),
            point(3, -34.603, -58.38, 101.0)
        )
        assertEquals(0.0, GeoUtils.elevationGain(ruido), 0.01)

        val subida = listOf(
            point(0, -34.60, -58.38, 100.0),
            point(1, -34.601, -58.38, 110.0),
            point(2, -34.602, -58.38, 125.0)
        )
        assertEquals(25.0, GeoUtils.elevationGain(subida), 0.01)
    }

    @Test
    fun `descarta puntos con salto imposible`() {
        val a = point(0, -34.60, -58.38)
        val b = point(1, -34.70, -58.38) // 11 km en 1 segundo
        assertFalse(GeoUtils.isPlausible(a, b))
    }

    @Test
    fun `descarta puntos con mala precision`() {
        val a = point(0, -34.60, -58.38)
        val b = point(1, -34.6001, -58.38).copy(accuracyM = 80f)
        assertFalse(GeoUtils.isPlausible(a, b))
    }

    @Test
    fun `normaliza el recorrido dentro del rango 0 a 1`() {
        val puntos = (0..10).map { point(it, -34.60 + it * 0.001, -58.38 + it * 0.001) }
        val normalizados = GeoUtils.normalizeForCanvas(puntos)
        assertEquals(puntos.size, normalizados.size)
        assertTrue(normalizados.all { it.first in 0f..1f && it.second in 0f..1f })
    }
}
