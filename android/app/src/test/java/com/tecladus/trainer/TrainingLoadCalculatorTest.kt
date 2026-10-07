package com.tecladus.trainer

import com.tecladus.trainer.domain.logic.TrainingLoadCalculator
import com.tecladus.trainer.domain.model.ActivitySession
import com.tecladus.trainer.domain.model.LoadStatus
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.WorkoutType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/** Carga de entrenamiento y riesgo de lesión (ratio agudo:crónico). */
class TrainingLoadCalculatorTest {

    private val today = LocalDate.of(2026, 5, 20)

    private fun session(daysAgo: Long, minutes: Int, type: WorkoutType = WorkoutType.EASY): ActivitySession {
        val date = today.minusDays(daysAgo)
        val millis = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        return ActivitySession(
            sport = Sport.RUNNING,
            startTimeMs = millis,
            endTimeMs = millis + minutes * 60_000L,
            elapsedSec = minutes * 60,
            movingSec = minutes * 60,
            distanceM = minutes * 180.0,
            elevationGainM = 0.0,
            kcal = minutes * 10,
            plannedType = type
        )
    }

    @Test
    fun `carga estable cae en zona optima`() {
        val sessions = (0..27L).filter { it % 2 == 0L }.map { session(it, 60) }
        val summary = TrainingLoadCalculator.summarize(sessions, today)
        assertEquals(LoadStatus.OPTIMAL, summary.status)
        assertTrue(summary.ratio in 0.8..1.3)
    }

    @Test
    fun `un salto brusco de volumen marca riesgo`() {
        val historia = (7..27L).filter { it % 3 == 0L }.map { session(it, 40) }
        val semanaActual = (0..6L).map { session(it, 150) }
        val summary = TrainingLoadCalculator.summarize(historia + semanaActual, today)
        assertTrue("El ratio debe dispararse: ${summary.ratio}", summary.ratio > 1.5)
        assertEquals(LoadStatus.RISK, summary.status)
    }

    @Test
    fun `el volumen semanal suma solo los ultimos 7 dias`() {
        val sessions = listOf(session(1, 60), session(3, 60), session(10, 60))
        val (km, minutes) = TrainingLoadCalculator.weeklyVolume(sessions, today)
        assertEquals(120, minutes)
        assertTrue(km > 0)
    }
}
