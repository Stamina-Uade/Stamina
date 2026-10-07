package com.tecladus.trainer.data.local

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.tecladus.trainer.domain.model.ActivitySession
import com.tecladus.trainer.domain.model.Food
import com.tecladus.trainer.domain.model.IntakeEvent
import com.tecladus.trainer.domain.model.IntakeType
import com.tecladus.trainer.domain.model.MealEntry
import com.tecladus.trainer.domain.model.MealType
import com.tecladus.trainer.domain.model.PlannedWorkout
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.TrackPoint
import com.tecladus.trainer.domain.model.TrainingPhase
import com.tecladus.trainer.domain.model.WorkoutType
import java.time.LocalDate

/**
 * Persistencia local en SQLite.
 *
 * Se implementa directamente sobre SQLiteOpenHelper (sin ORM) para que el proyecto
 * compile sin procesadores de anotaciones y para dejar el esquema a la vista.
 * Los repositorios son los únicos que hablan con esta clase, así que migrar a Room
 * o a un backend remoto sólo implica cambiar la implementación del repositorio.
 */
class TrainerDatabase(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    companion object {
        const val DB_NAME = "trainer.db"
        const val DB_VERSION = 2
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sport TEXT NOT NULL,
                start_time INTEGER NOT NULL,
                end_time INTEGER NOT NULL,
                elapsed_sec INTEGER NOT NULL,
                moving_sec INTEGER NOT NULL,
                distance_m REAL NOT NULL,
                elev_gain_m REAL NOT NULL,
                kcal INTEGER NOT NULL,
                avg_hr INTEGER,
                rpe INTEGER NOT NULL,
                temp_c REAL NOT NULL,
                humidity REAL NOT NULL,
                planned_workout_id INTEGER,
                planned_type TEXT,
                fluid_ml INTEGER NOT NULL,
                sodium_mg INTEGER NOT NULL,
                carbs_g INTEGER NOT NULL,
                planned_fluid_ml INTEGER NOT NULL,
                planned_sodium_mg INTEGER NOT NULL,
                planned_carbs_g INTEGER NOT NULL,
                title TEXT NOT NULL,
                notes TEXT NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE track_points (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL,
                ts INTEGER NOT NULL,
                lat REAL NOT NULL,
                lon REAL NOT NULL,
                alt REAL NOT NULL,
                speed REAL NOT NULL,
                accuracy REAL NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_points_session ON track_points(session_id)")
        db.execSQL(
            """
            CREATE TABLE intakes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL,
                ts INTEGER NOT NULL,
                type TEXT NOT NULL,
                fluid_ml INTEGER NOT NULL,
                sodium_mg INTEGER NOT NULL,
                carbs_g INTEGER NOT NULL,
                note TEXT NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_intakes_session ON intakes(session_id)")
        db.execSQL(
            """
            CREATE TABLE meals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                day INTEGER NOT NULL,
                meal_type TEXT NOT NULL,
                food_id TEXT NOT NULL,
                food_name TEXT NOT NULL,
                grams REAL NOT NULL,
                kcal REAL NOT NULL,
                protein REAL NOT NULL,
                carbs REAL NOT NULL,
                fat REAL NOT NULL,
                sodium REAL NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_meals_day ON meals(day)")
        db.execSQL("CREATE TABLE water_log (day INTEGER PRIMARY KEY, ml INTEGER NOT NULL)")
        db.execSQL(
            """
            CREATE TABLE planned_workouts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                day INTEGER NOT NULL,
                sport TEXT NOT NULL,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                duration_min INTEGER NOT NULL,
                distance_km REAL,
                pace_low INTEGER,
                pace_high INTEGER,
                phase TEXT NOT NULL,
                week_number INTEGER NOT NULL,
                kcal INTEGER NOT NULL,
                fueling_tip TEXT NOT NULL,
                time_min INTEGER,
                completed INTEGER NOT NULL,
                session_id INTEGER
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_plan_day ON planned_workouts(day)")
        db.execSQL(
            """
            CREATE TABLE custom_foods (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                kcal REAL NOT NULL,
                protein REAL NOT NULL,
                carbs REAL NOT NULL,
                fat REAL NOT NULL,
                sodium REAL NOT NULL,
                portion_g REAL NOT NULL,
                portion_label TEXT NOT NULL
            )
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // MVP: al cambiar de versión se recrea el esquema local (los datos viven en el dispositivo).
        db.execSQL("DROP TABLE IF EXISTS sessions")
        db.execSQL("DROP TABLE IF EXISTS track_points")
        db.execSQL("DROP TABLE IF EXISTS intakes")
        db.execSQL("DROP TABLE IF EXISTS meals")
        db.execSQL("DROP TABLE IF EXISTS water_log")
        db.execSQL("DROP TABLE IF EXISTS planned_workouts")
        db.execSQL("DROP TABLE IF EXISTS custom_foods")
        onCreate(db)
    }

    // ---------------------------------------------------------------- sesiones

    fun insertSession(session: ActivitySession, points: List<TrackPoint>, intakes: List<IntakeEvent>): Long {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val values = ContentValues().apply {
                put("sport", session.sport.name)
                put("start_time", session.startTimeMs)
                put("end_time", session.endTimeMs)
                put("elapsed_sec", session.elapsedSec)
                put("moving_sec", session.movingSec)
                put("distance_m", session.distanceM)
                put("elev_gain_m", session.elevationGainM)
                put("kcal", session.kcal)
                put("avg_hr", session.avgHr)
                put("rpe", session.perceivedEffort)
                put("temp_c", session.tempC)
                put("humidity", session.humidityPct)
                put("planned_workout_id", session.plannedWorkoutId)
                put("planned_type", session.plannedType?.name)
                put("fluid_ml", session.fluidMl)
                put("sodium_mg", session.sodiumMg)
                put("carbs_g", session.carbsG)
                put("planned_fluid_ml", session.plannedFluidMl)
                put("planned_sodium_mg", session.plannedSodiumMg)
                put("planned_carbs_g", session.plannedCarbsG)
                put("title", session.title)
                put("notes", session.notes)
            }
            val id = db.insert("sessions", null, values)
            points.forEach { p ->
                db.insert("track_points", null, ContentValues().apply {
                    put("session_id", id)
                    put("ts", p.timestampMs)
                    put("lat", p.latitude)
                    put("lon", p.longitude)
                    put("alt", p.altitudeM)
                    put("speed", p.speedMps)
                    put("accuracy", p.accuracyM.toDouble())
                })
            }
            intakes.forEach { i ->
                db.insert("intakes", null, ContentValues().apply {
                    put("session_id", id)
                    put("ts", i.timestampMs)
                    put("type", i.type.name)
                    put("fluid_ml", i.fluidMl)
                    put("sodium_mg", i.sodiumMg)
                    put("carbs_g", i.carbsG)
                    put("note", i.note)
                })
            }
            db.setTransactionSuccessful()
            return id
        } finally {
            db.endTransaction()
        }
    }

    fun querySessions(limit: Int = 500): List<ActivitySession> {
        val list = mutableListOf<ActivitySession>()
        readableDatabase.rawQuery("SELECT * FROM sessions ORDER BY start_time DESC LIMIT ?", arrayOf(limit.toString()))
            .use { c ->
                while (c.moveToNext()) list += c.toSession()
            }
        return list
    }

    fun queryPoints(sessionId: Long): List<TrackPoint> {
        val list = mutableListOf<TrackPoint>()
        readableDatabase.rawQuery(
            "SELECT * FROM track_points WHERE session_id = ? ORDER BY ts ASC",
            arrayOf(sessionId.toString())
        ).use { c ->
            while (c.moveToNext()) {
                list += TrackPoint(
                    timestampMs = c.getLong(c.getColumnIndexOrThrow("ts")),
                    latitude = c.getDouble(c.getColumnIndexOrThrow("lat")),
                    longitude = c.getDouble(c.getColumnIndexOrThrow("lon")),
                    altitudeM = c.getDouble(c.getColumnIndexOrThrow("alt")),
                    speedMps = c.getDouble(c.getColumnIndexOrThrow("speed")),
                    accuracyM = c.getDouble(c.getColumnIndexOrThrow("accuracy")).toFloat()
                )
            }
        }
        return list
    }

    fun queryIntakes(sessionId: Long): List<IntakeEvent> {
        val list = mutableListOf<IntakeEvent>()
        readableDatabase.rawQuery(
            "SELECT * FROM intakes WHERE session_id = ? ORDER BY ts ASC",
            arrayOf(sessionId.toString())
        ).use { c ->
            while (c.moveToNext()) {
                list += IntakeEvent(
                    id = c.getLong(c.getColumnIndexOrThrow("id")),
                    sessionId = sessionId,
                    timestampMs = c.getLong(c.getColumnIndexOrThrow("ts")),
                    type = IntakeType.valueOf(c.getString(c.getColumnIndexOrThrow("type"))),
                    fluidMl = c.getInt(c.getColumnIndexOrThrow("fluid_ml")),
                    sodiumMg = c.getInt(c.getColumnIndexOrThrow("sodium_mg")),
                    carbsG = c.getInt(c.getColumnIndexOrThrow("carbs_g")),
                    note = c.getString(c.getColumnIndexOrThrow("note")) ?: ""
                )
            }
        }
        return list
    }

    fun deleteSession(id: Long) {
        val db = writableDatabase
        db.delete("track_points", "session_id = ?", arrayOf(id.toString()))
        db.delete("intakes", "session_id = ?", arrayOf(id.toString()))
        db.delete("sessions", "id = ?", arrayOf(id.toString()))
    }

    private fun Cursor.toSession(): ActivitySession = ActivitySession(
        id = getLong(getColumnIndexOrThrow("id")),
        sport = Sport.valueOf(getString(getColumnIndexOrThrow("sport"))),
        startTimeMs = getLong(getColumnIndexOrThrow("start_time")),
        endTimeMs = getLong(getColumnIndexOrThrow("end_time")),
        elapsedSec = getInt(getColumnIndexOrThrow("elapsed_sec")),
        movingSec = getInt(getColumnIndexOrThrow("moving_sec")),
        distanceM = getDouble(getColumnIndexOrThrow("distance_m")),
        elevationGainM = getDouble(getColumnIndexOrThrow("elev_gain_m")),
        kcal = getInt(getColumnIndexOrThrow("kcal")),
        avgHr = if (isNull(getColumnIndexOrThrow("avg_hr"))) null else getInt(getColumnIndexOrThrow("avg_hr")),
        perceivedEffort = getInt(getColumnIndexOrThrow("rpe")),
        tempC = getDouble(getColumnIndexOrThrow("temp_c")),
        humidityPct = getDouble(getColumnIndexOrThrow("humidity")),
        plannedWorkoutId = if (isNull(getColumnIndexOrThrow("planned_workout_id"))) null
        else getLong(getColumnIndexOrThrow("planned_workout_id")),
        plannedType = getString(getColumnIndexOrThrow("planned_type"))?.let { WorkoutType.valueOf(it) },
        fluidMl = getInt(getColumnIndexOrThrow("fluid_ml")),
        sodiumMg = getInt(getColumnIndexOrThrow("sodium_mg")),
        carbsG = getInt(getColumnIndexOrThrow("carbs_g")),
        plannedFluidMl = getInt(getColumnIndexOrThrow("planned_fluid_ml")),
        plannedSodiumMg = getInt(getColumnIndexOrThrow("planned_sodium_mg")),
        plannedCarbsG = getInt(getColumnIndexOrThrow("planned_carbs_g")),
        title = getString(getColumnIndexOrThrow("title")) ?: "",
        notes = getString(getColumnIndexOrThrow("notes")) ?: ""
    )

    // ------------------------------------------------------------------ plan

    fun replacePlan(workouts: List<PlannedWorkout>) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.delete("planned_workouts", null, null)
            workouts.forEach { w ->
                db.insert("planned_workouts", null, ContentValues().apply {
                    put("day", w.date.toEpochDay())
                    put("sport", w.sport.name)
                    put("type", w.type.name)
                    put("title", w.title)
                    put("description", w.description)
                    put("duration_min", w.durationMin)
                    put("distance_km", w.distanceKm)
                    put("pace_low", w.targetPaceLowSecPerKm)
                    put("pace_high", w.targetPaceHighSecPerKm)
                    put("phase", w.phase.name)
                    put("week_number", w.weekNumber)
                    put("kcal", w.estimatedKcal)
                    put("fueling_tip", w.fuelingTip)
                    put("time_min", w.scheduledMinuteOfDay)
                    put("completed", if (w.completed) 1 else 0)
                    put("session_id", w.sessionId)
                })
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun queryPlan(): List<PlannedWorkout> {
        val list = mutableListOf<PlannedWorkout>()
        readableDatabase.rawQuery("SELECT * FROM planned_workouts ORDER BY day ASC", null).use { c ->
            while (c.moveToNext()) {
                list += PlannedWorkout(
                    id = c.getLong(c.getColumnIndexOrThrow("id")),
                    date = LocalDate.ofEpochDay(c.getLong(c.getColumnIndexOrThrow("day"))),
                    sport = Sport.valueOf(c.getString(c.getColumnIndexOrThrow("sport"))),
                    type = WorkoutType.valueOf(c.getString(c.getColumnIndexOrThrow("type"))),
                    title = c.getString(c.getColumnIndexOrThrow("title")),
                    description = c.getString(c.getColumnIndexOrThrow("description")),
                    durationMin = c.getInt(c.getColumnIndexOrThrow("duration_min")),
                    distanceKm = if (c.isNull(c.getColumnIndexOrThrow("distance_km"))) null
                    else c.getDouble(c.getColumnIndexOrThrow("distance_km")),
                    targetPaceLowSecPerKm = if (c.isNull(c.getColumnIndexOrThrow("pace_low"))) null
                    else c.getInt(c.getColumnIndexOrThrow("pace_low")),
                    targetPaceHighSecPerKm = if (c.isNull(c.getColumnIndexOrThrow("pace_high"))) null
                    else c.getInt(c.getColumnIndexOrThrow("pace_high")),
                    phase = TrainingPhase.valueOf(c.getString(c.getColumnIndexOrThrow("phase"))),
                    weekNumber = c.getInt(c.getColumnIndexOrThrow("week_number")),
                    estimatedKcal = c.getInt(c.getColumnIndexOrThrow("kcal")),
                    fuelingTip = c.getString(c.getColumnIndexOrThrow("fueling_tip")),
                    scheduledMinuteOfDay = if (c.isNull(c.getColumnIndexOrThrow("time_min"))) null
                    else c.getInt(c.getColumnIndexOrThrow("time_min")),
                    completed = c.getInt(c.getColumnIndexOrThrow("completed")) == 1,
                    sessionId = if (c.isNull(c.getColumnIndexOrThrow("session_id"))) null
                    else c.getLong(c.getColumnIndexOrThrow("session_id"))
                )
            }
        }
        return list
    }

    /** Sesión planificada de un día puntual (la usa el recordatorio, sin cargar todo el plan). */
    fun queryPlanFor(date: LocalDate): PlannedWorkout? =
        queryPlan().firstOrNull { it.date == date }

    fun markWorkoutCompleted(workoutId: Long, sessionId: Long?) {
        writableDatabase.update(
            "planned_workouts",
            ContentValues().apply {
                put("completed", 1)
                put("session_id", sessionId)
            },
            "id = ?",
            arrayOf(workoutId.toString())
        )
    }

    // ------------------------------------------------------------- nutrición

    fun insertMeal(entry: MealEntry): Long = writableDatabase.insert("meals", null, ContentValues().apply {
        put("day", entry.date.toEpochDay())
        put("meal_type", entry.mealType.name)
        put("food_id", entry.foodId)
        put("food_name", entry.foodName)
        put("grams", entry.grams)
        put("kcal", entry.kcal)
        put("protein", entry.proteinG)
        put("carbs", entry.carbsG)
        put("fat", entry.fatG)
        put("sodium", entry.sodiumMg)
    })

    fun deleteMeal(id: Long) {
        writableDatabase.delete("meals", "id = ?", arrayOf(id.toString()))
    }

    fun queryMeals(date: LocalDate): List<MealEntry> {
        val list = mutableListOf<MealEntry>()
        readableDatabase.rawQuery(
            "SELECT * FROM meals WHERE day = ? ORDER BY id ASC",
            arrayOf(date.toEpochDay().toString())
        ).use { c ->
            while (c.moveToNext()) {
                list += MealEntry(
                    id = c.getLong(c.getColumnIndexOrThrow("id")),
                    date = date,
                    mealType = MealType.valueOf(c.getString(c.getColumnIndexOrThrow("meal_type"))),
                    foodId = c.getString(c.getColumnIndexOrThrow("food_id")),
                    foodName = c.getString(c.getColumnIndexOrThrow("food_name")),
                    grams = c.getDouble(c.getColumnIndexOrThrow("grams")),
                    kcal = c.getDouble(c.getColumnIndexOrThrow("kcal")),
                    proteinG = c.getDouble(c.getColumnIndexOrThrow("protein")),
                    carbsG = c.getDouble(c.getColumnIndexOrThrow("carbs")),
                    fatG = c.getDouble(c.getColumnIndexOrThrow("fat")),
                    sodiumMg = c.getDouble(c.getColumnIndexOrThrow("sodium"))
                )
            }
        }
        return list
    }

    fun waterFor(date: LocalDate): Int {
        readableDatabase.rawQuery(
            "SELECT ml FROM water_log WHERE day = ?",
            arrayOf(date.toEpochDay().toString())
        ).use { c -> if (c.moveToFirst()) return c.getInt(0) }
        return 0
    }

    fun setWater(date: LocalDate, ml: Int) {
        writableDatabase.execSQL(
            "INSERT OR REPLACE INTO water_log(day, ml) VALUES(?, ?)",
            arrayOf<Any>(date.toEpochDay(), ml)
        )
    }

    fun insertCustomFood(food: Food) {
        writableDatabase.insertWithOnConflict(
            "custom_foods", null,
            ContentValues().apply {
                put("id", food.id)
                put("name", food.name)
                put("category", food.category)
                put("kcal", food.kcalPer100g)
                put("protein", food.proteinPer100g)
                put("carbs", food.carbsPer100g)
                put("fat", food.fatPer100g)
                put("sodium", food.sodiumMgPer100g)
                put("portion_g", food.defaultPortionG)
                put("portion_label", food.portionLabel)
            },
            SQLiteDatabase.CONFLICT_REPLACE
        )
    }

    fun queryCustomFoods(): List<Food> {
        val list = mutableListOf<Food>()
        readableDatabase.rawQuery("SELECT * FROM custom_foods ORDER BY name ASC", null).use { c ->
            while (c.moveToNext()) {
                list += Food(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    name = c.getString(c.getColumnIndexOrThrow("name")),
                    category = c.getString(c.getColumnIndexOrThrow("category")),
                    kcalPer100g = c.getDouble(c.getColumnIndexOrThrow("kcal")),
                    proteinPer100g = c.getDouble(c.getColumnIndexOrThrow("protein")),
                    carbsPer100g = c.getDouble(c.getColumnIndexOrThrow("carbs")),
                    fatPer100g = c.getDouble(c.getColumnIndexOrThrow("fat")),
                    sodiumMgPer100g = c.getDouble(c.getColumnIndexOrThrow("sodium")),
                    defaultPortionG = c.getDouble(c.getColumnIndexOrThrow("portion_g")),
                    portionLabel = c.getString(c.getColumnIndexOrThrow("portion_label"))
                )
            }
        }
        return list
    }
}
