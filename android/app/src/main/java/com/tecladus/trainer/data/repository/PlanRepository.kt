package com.tecladus.trainer.data.repository

import com.tecladus.trainer.data.local.TrainerDatabase
import com.tecladus.trainer.domain.logic.TrainingPlanGenerator
import com.tecladus.trainer.domain.model.PlanWeek
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.UserProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.time.LocalDate

interface PlanRepository {
    val plan: StateFlow<List<PlannedWorkout>>
    suspend fun refresh()
    suspend fun regenerate(profile: UserProfile, startDate: LocalDate = LocalDate.now())
    suspend fun markCompleted(workoutId: Long, sessionId: Long?)
    fun workoutFor(date: LocalDate): PlannedWorkout?
    fun weeks(): List<PlanWeek>
}

class LocalPlanRepository(private val db: TrainerDatabase) : PlanRepository {

    private val _plan = MutableStateFlow<List<PlannedWorkout>>(emptyList())
    override val plan: StateFlow<List<PlannedWorkout>> = _plan.asStateFlow()

    override suspend fun refresh() {
        _plan.value = withContext(Dispatchers.IO) { db.queryPlan() }
    }

    override suspend fun regenerate(profile: UserProfile, startDate: LocalDate) {
        val generated = TrainingPlanGenerator.generate(profile, startDate)
        withContext(Dispatchers.IO) { db.replacePlan(generated) }
        refresh()
    }

    override suspend fun markCompleted(workoutId: Long, sessionId: Long?) {
        withContext(Dispatchers.IO) { db.markWorkoutCompleted(workoutId, sessionId) }
        refresh()
    }

    override fun workoutFor(date: LocalDate): PlannedWorkout? =
        _plan.value.firstOrNull { it.date == date }

    override fun weeks(): List<PlanWeek> = _plan.value
        .groupBy { it.weekNumber }
        .toSortedMap()
        .map { (week, workouts) ->
            PlanWeek(
                weekNumber = week,
                startDate = workouts.minOf { it.date },
                phase = workouts.first().phase,
                workouts = workouts.sortedBy { it.date }
            )
        }
}
