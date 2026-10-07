package com.tecladus.trainer

import com.tecladus.trainer.domain.logic.HydrationCalculator
import com.tecladus.trainer.domain.model.EffortIntensity
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.SweatSaltiness
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.WeatherConditions
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HydrationCalculatorTest {

    private val profile = UserProfile(weightKg = 70.0, sweatSaltiness = SweatSaltiness.MEDIUM)

    @Test
    fun `el calor aumenta la tasa de sudoracion`() {
        val fresco = HydrationCalculator.sweatRateLh(
            profile, Sport.RUNNING, EffortIntensity.MODERATE, WeatherConditions(12.0, 50.0, false)
        )
        val calor = HydrationCalculator.sweatRateLh(
            profile, Sport.RUNNING, EffortIntensity.MODERATE, WeatherConditions(32.0, 70.0, true)
        )
        assertTrue("Con calor se debe sudar más", calor > fresco * 1.4)
    }

    @Test
    fun `la reposicion nunca supera el limite de vaciado gastrico`() {
        val plan = HydrationCalculator.buildPlan(
            profile.copy(weightKg = 95.0),
            Sport.RUNNING,
            EffortIntensity.RACE,
            WeatherConditions(38.0, 85.0, true),
            180
        )
        assertTrue("Máximo 800 ml/h", plan.fluidPerHourMl <= 800)
        assertTrue("Mínimo 300 ml/h", plan.fluidPerHourMl >= 300)
    }

    @Test
    fun `sesiones cortas no llevan geles ni sales`() {
        val plan = HydrationCalculator.buildPlan(
            profile, Sport.RUNNING, EffortIntensity.MODERATE, WeatherConditions(), 40
        )
        assertEquals(0, plan.carbsPerHourG)
        assertEquals(0, plan.sodiumPerHourMg)
    }

    @Test
    fun `sesiones largas respetan el techo del intestino entrenado`() {
        val sensible = HydrationCalculator.carbsPerHour(300, gutTrainingLevel = 1)
        val entrenado = HydrationCalculator.carbsPerHour(300, gutTrainingLevel = 3)
        assertEquals(45, sensible)
        assertEquals(90, entrenado)
    }

    @Test
    fun `la agenda de avisos se ordena por minuto`() {
        val plan = HydrationCalculator.buildPlan(
            profile, Sport.RUNNING, EffortIntensity.MODERATE, WeatherConditions(28.0, 60.0, true), 180
        )
        val schedule = HydrationCalculator.buildSchedule(plan)
        assertTrue(schedule.isNotEmpty())
        assertEquals(schedule.map { it.atMinute }.sorted(), schedule.map { it.atMinute })
        assertTrue("Ningún aviso después del final", schedule.all { it.atMinute <= 180 })
    }

    @Test
    fun `la tasa medida usa el protocolo de peso`() {
        // 1 kg perdido + 500 ml tomados en 1 hora = 1,5 L/h
        val rate = HydrationCalculator.measuredSweatRate(70.0, 69.0, 500, 60)
        assertEquals(1.5, rate, 0.01)
    }
}
