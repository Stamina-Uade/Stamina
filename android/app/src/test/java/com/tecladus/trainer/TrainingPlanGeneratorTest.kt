package com.tecladus.trainer

import com.tecladus.trainer.domain.logic.TrainingPlanGenerator
import com.tecladus.trainer.domain.model.FitnessLevel
import com.tecladus.trainer.domain.model.GoalType
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.TrainingPhase
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.WorkoutType
import java.time.DayOfWeek
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class TrainingPlanGeneratorTest {

    private val start = LocalDate.of(2026, 3, 2) // lunes

    private val profile = UserProfile(
        weightKg = 72.0,
        level = FitnessLevel.INTERMEDIATE,
        primarySport = Sport.RUNNING,
        goal = GoalType.RACE_21K,
        eventDate = start.plusWeeks(12),
        trainingSchedule = linkedMapOf(
            DayOfWeek.TUESDAY to 19 * 60,
            DayOfWeek.THURSDAY to 19 * 60,
            DayOfWeek.FRIDAY to 7 * 60,
            DayOfWeek.SUNDAY to 8 * 60 + 30
        )
    )

    @Test
    fun `el plan cubre todos los dias hasta el evento`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        val days = plan.map { it.date }.distinct()
        assertEquals(85, days.size) // 12 semanas + el día del evento
        assertEquals(start, days.first())
        assertEquals(profile.eventDate, days.last())
    }

    @Test
    fun `el ultimo dia es la competencia`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        assertEquals(WorkoutType.RACE, plan.last().type)
        assertEquals(TrainingPhase.RACE, plan.last().phase)
    }

    @Test
    fun `respeta la cantidad de dias de entrenamiento por semana`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        val week2 = plan.filter { it.weekNumber == 2 }
        val entrenamientos = week2.count { it.type != WorkoutType.REST }
        assertEquals(profile.trainingDaysPerWeek, entrenamientos)
    }

    @Test
    fun `el taper baja el volumen antes del evento`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        val porSemana = plan.groupBy { it.weekNumber }.mapValues { (_, w) -> w.sumOf { it.durationMin } }
        val pico = porSemana.values.max()
        val ultimaSemanaCompleta = porSemana[porSemana.keys.max() - 1] ?: 0
        assertTrue("El taper debe bajar el volumen", ultimaSemanaCompleta < pico)
    }

    @Test
    fun `las fases van de base a taper`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        val fases = plan.map { it.phase }.distinct()
        assertTrue(fases.contains(TrainingPhase.BASE))
        assertTrue(fases.contains(TrainingPhase.BUILD))
        assertTrue(fases.contains(TrainingPhase.PEAK))
        assertTrue(fases.contains(TrainingPhase.TAPER))
    }

    @Test
    fun `todas las sesiones tienen consejo de combustible`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        assertTrue(plan.all { it.fuelingTip.isNotBlank() })
    }

    @Test
    fun `el fondo largo cae el domingo si esta disponible`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        val largos = plan.filter { it.type == WorkoutType.LONG }
        assertTrue(largos.isNotEmpty())
        assertTrue("Todos los fondos deben caer domingo", largos.all { it.date.dayOfWeek == DayOfWeek.SUNDAY })
    }

    @Test
    fun `las sesiones heredan el horario elegido`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        val martes = plan.first { it.date.dayOfWeek == DayOfWeek.TUESDAY && it.type != WorkoutType.REST }
        val domingo = plan.first { it.date.dayOfWeek == DayOfWeek.SUNDAY && it.type == WorkoutType.LONG }
        assertEquals(19 * 60, martes.scheduledMinuteOfDay)
        assertEquals(8 * 60 + 30, domingo.scheduledMinuteOfDay)
    }

    @Test
    fun `solo se entrena en los dias elegidos`() {
        val plan = TrainingPlanGenerator.generate(profile, start)
        val diasEntrenados = plan.filter { it.type != WorkoutType.REST && it.type != WorkoutType.RACE }
            .map { it.date.dayOfWeek }.distinct().toSet()
        assertEquals(profile.trainingSchedule.keys, diasEntrenados)
    }

    @Test
    fun `una agenda de tres dias no genera dobles sesiones`() {
        val tresDias = profile.copy(
            trainingSchedule = linkedMapOf(
                DayOfWeek.MONDAY to 7 * 60,
                DayOfWeek.WEDNESDAY to 7 * 60,
                DayOfWeek.SATURDAY to 9 * 60
            )
        )
        val plan = TrainingPlanGenerator.generate(tresDias, start)
        val semana = plan.filter { it.weekNumber == 3 }
        assertEquals(3, semana.count { it.type != WorkoutType.REST })
        assertEquals(1, semana.count { it.type == WorkoutType.LONG })
    }

    @Test
    fun `sin fecha de evento genera 8 semanas`() {
        val sinEvento = profile.copy(eventDate = null)
        val plan = TrainingPlanGenerator.generate(sinEvento, start)
        assertTrue(plan.map { it.weekNumber }.max() >= 8)
    }
}
