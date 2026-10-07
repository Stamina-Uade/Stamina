package com.tecladus.trainer.domain.logic

import com.tecladus.trainer.domain.model.ActivitySession
import com.tecladus.trainer.domain.model.LoadStatus
import com.tecladus.trainer.domain.model.TrainingLoadSummary
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Carga de entrenamiento y riesgo de lesión.
 *
 * Se usa el ratio carga aguda / carga crónica (ACWR): la carga de los últimos 7 días
 * dividida por el promedio semanal de las últimas 4 semanas. La evidencia en deportes
 * de resistencia ubica la "zona dulce" entre 0,8 y 1,3; por encima de 1,5 el riesgo
 * de lesión por sobrecarga crece de forma marcada.
 */
object TrainingLoadCalculator {

    private fun dateOf(session: ActivitySession): LocalDate =
        Instant.ofEpochMilli(session.startTimeMs).atZone(ZoneId.systemDefault()).toLocalDate()

    fun summarize(sessions: List<ActivitySession>, today: LocalDate = LocalDate.now()): TrainingLoadSummary {
        val acute = sessions.filter {
            val d = dateOf(it)
            !d.isBefore(today.minusDays(6)) && !d.isAfter(today)
        }.sumOf { it.load }

        val chronicTotal = sessions.filter {
            val d = dateOf(it)
            !d.isBefore(today.minusDays(27)) && !d.isAfter(today)
        }.sumOf { it.load }
        val chronic = chronicTotal / 4.0

        val ratio = if (chronic > 1.0) acute / chronic else if (acute > 0) 1.0 else 0.0
        val status = when {
            chronic < 1.0 -> LoadStatus.OPTIMAL
            ratio < 0.8 -> LoadStatus.DETRAINING
            ratio <= 1.3 -> LoadStatus.OPTIMAL
            ratio <= 1.5 -> LoadStatus.CAUTION
            else -> LoadStatus.RISK
        }

        val weekly = (3 downTo 0).map { weeksAgo ->
            val start = today.minusDays((weeksAgo * 7 + 6).toLong())
            val end = today.minusDays((weeksAgo * 7).toLong())
            sessions.filter {
                val d = dateOf(it)
                !d.isBefore(start) && !d.isAfter(end)
            }.sumOf { it.load }
        }

        return TrainingLoadSummary(
            acuteLoad = acute,
            chronicLoad = chronic,
            ratio = ratio,
            status = status,
            weeklyLoads = weekly
        )
    }

    /** Kilómetros y minutos de los últimos 7 días. */
    fun weeklyVolume(sessions: List<ActivitySession>, today: LocalDate = LocalDate.now()): Pair<Double, Int> {
        val week = sessions.filter {
            val d = dateOf(it)
            !d.isBefore(today.minusDays(6)) && !d.isAfter(today)
        }
        return week.sumOf { it.distanceKm } to week.sumOf { it.durationMin }
    }
}
