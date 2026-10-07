package com.tecladus.trainer

import com.tecladus.trainer.domain.logic.HeatRiskCalculator
import com.tecladus.trainer.domain.model.RiskLevel
import com.tecladus.trainer.domain.model.WeatherSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HeatRiskCalculatorTest {

    private fun weather(
        temp: Double,
        humidity: Double,
        apparent: Double = temp,
        wind: Double = 8.0,
        uv: Double = 3.0,
        code: Int = 0
    ) = WeatherSnapshot(
        tempC = temp,
        humidityPct = humidity,
        apparentC = apparent,
        windKmh = wind,
        uvIndex = uv,
        isDay = true,
        weatherCode = code,
        place = "CABA",
        latitude = -34.6,
        longitude = -58.38,
        fetchedAtMs = 0L
    )

    @Test
    fun `con temperatura templada el indice de calor es la temperatura`() {
        assertEquals(18.0, HeatRiskCalculator.heatIndexC(18.0, 60.0), 0.01)
    }

    @Test
    fun `la humedad dispara la sensacion termica`() {
        val seco = HeatRiskCalculator.heatIndexC(32.0, 25.0)
        val humedo = HeatRiskCalculator.heatIndexC(32.0, 80.0)
        assertTrue("Con 80% de humedad debe sentirse mucho más: $humedo vs $seco", humedo > seco + 8)
        assertTrue("32 °C con 80% supera los 43 de sensación: $humedo", humedo > 43)
    }

    @Test
    fun `un dia templado no genera advertencias`() {
        val assessment = HeatRiskCalculator.assess(weather(20.0, 55.0), 60)
        assertEquals(RiskLevel.GOOD, assessment.level)
        assertTrue(assessment.adjustments.isEmpty())
    }

    @Test
    fun `calor extremo recomienda no salir`() {
        val assessment = HeatRiskCalculator.assess(weather(38.0, 70.0), 90)
        assertEquals(RiskLevel.EXTREME, assessment.level)
        assertTrue(assessment.blocksTraining)
        assertTrue(assessment.advice.contains("no conviene", ignoreCase = true))
    }

    @Test
    fun `la tormenta electrica bloquea la salida`() {
        val assessment = HeatRiskCalculator.assess(weather(24.0, 70.0, code = 95), 60)
        assertEquals(RiskLevel.EXTREME, assessment.level)
        assertTrue(assessment.headline.contains("Tormenta"))
    }

    @Test
    fun `el frio extremo tambien bloquea`() {
        val assessment = HeatRiskCalculator.assess(weather(-6.0, 60.0, apparent = -12.0), 60)
        assertEquals(RiskLevel.EXTREME, assessment.level)
    }

    @Test
    fun `el calor alto sugiere recortar la sesion`() {
        val assessment = HeatRiskCalculator.assess(weather(33.0, 65.0), 120)
        assertEquals(RiskLevel.HIGH, assessment.level)
        assertTrue(assessment.adjustments.any { it.contains("Recortá") })
    }

    @Test
    fun `el uv alto agrega proteccion solar`() {
        val assessment = HeatRiskCalculator.assess(weather(29.0, 60.0, uv = 9.0), 60)
        assertTrue(assessment.adjustments.any { it.contains("protector solar") })
    }

    @Test
    fun `el viento fuerte cambia la recomendacion`() {
        val assessment = HeatRiskCalculator.assess(weather(18.0, 50.0, wind = 60.0), 60)
        assertEquals(RiskLevel.HIGH, assessment.level)
        assertTrue(assessment.headline.contains("Viento"))
    }
}
