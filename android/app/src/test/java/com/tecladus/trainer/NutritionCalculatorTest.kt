package com.tecladus.trainer

import com.tecladus.trainer.domain.logic.NutritionCalculator
import com.tecladus.trainer.domain.model.DayLoad
import com.tecladus.trainer.domain.model.Sex
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.TrainingPhase
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.WorkoutType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class NutritionCalculatorTest {

    private val profile = UserProfile(sex = Sex.MALE, age = 30, weightKg = 70.0, heightCm = 175.0)

    private fun workout(type: WorkoutType, minutes: Int, kcal: Int) = PlannedWorkout(
        date = LocalDate.now(),
        sport = Sport.RUNNING,
        type = type,
        title = "test",
        description = "",
        durationMin = minutes,
        distanceKm = null,
        targetPaceLowSecPerKm = null,
        targetPaceHighSecPerKm = null,
        phase = TrainingPhase.BASE,
        weekNumber = 1,
        estimatedKcal = kcal,
        fuelingTip = ""
    )

    @Test
    fun `mifflin st jeor para hombre de 70 kg`() {
        // 10*70 + 6.25*175 - 5*30 + 5 = 1648,75
        assertEquals(1648.75, NutritionCalculator.bmr(profile), 0.01)
    }

    @Test
    fun `los hidratos se periodizan segun la carga del dia`() {
        val descanso = NutritionCalculator.targetsFor(profile, workout(WorkoutType.REST, 0, 0), LocalDate.now())
        val fondo = NutritionCalculator.targetsFor(profile, workout(WorkoutType.LONG, 120, 900), LocalDate.now())
        assertEquals(DayLoad.REST, descanso.dayLoad)
        assertEquals(DayLoad.HIGH, fondo.dayLoad)
        assertTrue("Más carga, más hidratos", fondo.carbsG > descanso.carbsG)
        assertTrue("Más carga, más calorías", fondo.kcal > descanso.kcal)
    }

    @Test
    fun `las calorias nunca caen por debajo del basal`() {
        val agresivo = profile.copy(bodyGoal = com.tecladus.trainer.domain.model.BodyGoal.LOSE_FAT)
        val targets = NutritionCalculator.targetsFor(agresivo, workout(WorkoutType.REST, 0, 0), LocalDate.now())
        assertTrue(targets.kcal >= NutritionCalculator.bmr(agresivo) * 1.1)
    }

    @Test
    fun `la grasa nunca baja del minimo saludable`() {
        val targets = NutritionCalculator.targetsFor(
            profile.copy(weightKg = 60.0),
            workout(WorkoutType.LONG, 180, 1500),
            LocalDate.now()
        )
        assertTrue("Mínimo 0,8 g/kg de grasa", targets.fatG >= (0.8 * 60).toInt())
    }

    @Test
    fun `los macros cierran contra las calorias objetivo`() {
        val targets = NutritionCalculator.targetsFor(profile, workout(WorkoutType.EASY, 50, 450), LocalDate.now())
        val kcalFromMacros = targets.carbsG * 4 + targets.proteinG * 4 + targets.fatG * 9
        assertTrue(
            "Los macros deben aproximar las kcal objetivo",
            kotlin.math.abs(kcalFromMacros - targets.kcal) < targets.kcal * 0.06
        )
    }
}
