package com.tecladus.trainer.data.local

import android.content.Context
import com.tecladus.trainer.domain.model.BodyGoal
import com.tecladus.trainer.domain.model.FitnessLevel
import com.tecladus.trainer.domain.model.GoalType
import com.tecladus.trainer.domain.model.Sex
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.SweatSaltiness
import com.tecladus.trainer.domain.model.UserProfile
import com.tecladus.trainer.domain.model.defaultSchedule
import java.time.DayOfWeek
import java.time.LocalDate

/** Guarda el perfil del usuario en SharedPreferences (datos chicos y de acceso frecuente). */
class ProfileStore(context: Context) {

    private val prefs = context.getSharedPreferences("trainer_profile", Context.MODE_PRIVATE)

    fun load(): UserProfile = UserProfile(
        name = prefs.getString("name", "") ?: "",
        sex = Sex.valueOf(prefs.getString("sex", Sex.MALE.name) ?: Sex.MALE.name),
        age = prefs.getInt("age", 30),
        weightKg = prefs.getFloat("weight", 70f).toDouble(),
        heightCm = prefs.getFloat("height", 175f).toDouble(),
        level = FitnessLevel.valueOf(prefs.getString("level", FitnessLevel.BEGINNER.name) ?: FitnessLevel.BEGINNER.name),
        primarySport = Sport.valueOf(prefs.getString("sport", Sport.RUNNING.name) ?: Sport.RUNNING.name),
        goal = GoalType.valueOf(prefs.getString("goal", GoalType.RACE_10K.name) ?: GoalType.RACE_10K.name),
        eventDate = prefs.getLong("event_date", -1L).takeIf { it >= 0 }?.let { LocalDate.ofEpochDay(it) },
        trainingSchedule = decodeSchedule(prefs.getString("schedule", null)),
        sweatSaltiness = SweatSaltiness.valueOf(
            prefs.getString("saltiness", SweatSaltiness.MEDIUM.name) ?: SweatSaltiness.MEDIUM.name
        ),
        measuredSweatRateLh = prefs.getFloat("sweat_rate", -1f).takeIf { it > 0f }?.toDouble(),
        restingHr = prefs.getInt("resting_hr", -1).takeIf { it > 0 },
        maxHrOverride = prefs.getInt("max_hr", -1).takeIf { it > 0 },
        referenceDistanceKm = prefs.getFloat("ref_distance", -1f).takeIf { it > 0f }?.toDouble(),
        referenceTimeMinutes = prefs.getFloat("ref_time", -1f).takeIf { it > 0f }?.toDouble(),
        bodyGoal = BodyGoal.valueOf(prefs.getString("body_goal", BodyGoal.MAINTAIN.name) ?: BodyGoal.MAINTAIN.name),
        gutTrainingLevel = prefs.getInt("gut_level", 2),
        onboardingCompleted = prefs.getBoolean("onboarding_done", false)
    )

    fun save(profile: UserProfile) {
        prefs.edit()
            .putString("name", profile.name)
            .putString("sex", profile.sex.name)
            .putInt("age", profile.age)
            .putFloat("weight", profile.weightKg.toFloat())
            .putFloat("height", profile.heightCm.toFloat())
            .putString("level", profile.level.name)
            .putString("sport", profile.primarySport.name)
            .putString("goal", profile.goal.name)
            .putLong("event_date", profile.eventDate?.toEpochDay() ?: -1L)
            .putString("schedule", encodeSchedule(profile.trainingSchedule))
            .putString("saltiness", profile.sweatSaltiness.name)
            .putFloat("sweat_rate", profile.measuredSweatRateLh?.toFloat() ?: -1f)
            .putInt("resting_hr", profile.restingHr ?: -1)
            .putInt("max_hr", profile.maxHrOverride ?: -1)
            .putFloat("ref_distance", profile.referenceDistanceKm?.toFloat() ?: -1f)
            .putFloat("ref_time", profile.referenceTimeMinutes?.toFloat() ?: -1f)
            .putString("body_goal", profile.bodyGoal.name)
            .putInt("gut_level", profile.gutTrainingLevel)
            .putBoolean("onboarding_done", profile.onboardingCompleted)
            .apply()
    }

    /** La agenda se guarda como "MARTES:1080|JUEVES:1080|DOMINGO:540". */
    private fun encodeSchedule(schedule: Map<DayOfWeek, Int>): String =
        schedule.entries.sortedBy { it.key.value }.joinToString("|") { "${it.key.name}:${it.value}" }

    private fun decodeSchedule(raw: String?): Map<DayOfWeek, Int> {
        if (raw.isNullOrBlank()) return defaultSchedule()
        val parsed = linkedMapOf<DayOfWeek, Int>()
        raw.split("|").forEach { chunk ->
            val parts = chunk.split(":")
            if (parts.size == 2) {
                val day = runCatching { DayOfWeek.valueOf(parts[0]) }.getOrNull()
                val minute = parts[1].toIntOrNull()
                if (day != null && minute != null) parsed[day] = minute.coerceIn(0, 24 * 60 - 1)
            }
        }
        return if (parsed.isEmpty()) defaultSchedule() else parsed
    }
}
