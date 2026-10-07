package com.tecladus.trainer.domain.model

import java.time.LocalDate

data class Food(
    val id: String,
    val name: String,
    val category: String,
    val kcalPer100g: Double,
    val proteinPer100g: Double,
    val carbsPer100g: Double,
    val fatPer100g: Double,
    val sodiumMgPer100g: Double,
    val defaultPortionG: Double,
    val portionLabel: String
) {
    fun kcalFor(grams: Double) = kcalPer100g * grams / 100.0
    fun proteinFor(grams: Double) = proteinPer100g * grams / 100.0
    fun carbsFor(grams: Double) = carbsPer100g * grams / 100.0
    fun fatFor(grams: Double) = fatPer100g * grams / 100.0
    fun sodiumFor(grams: Double) = sodiumMgPer100g * grams / 100.0
}

enum class MealType(val label: String, val order: Int) {
    BREAKFAST("Desayuno", 0),
    PRE_WORKOUT("Pre-entreno", 1),
    LUNCH("Almuerzo", 2),
    DURING("Durante el esfuerzo", 3),
    POST_WORKOUT("Post-entreno", 4),
    SNACK("Merienda / snack", 5),
    DINNER("Cena", 6)
}

data class MealEntry(
    val id: Long = 0L,
    val date: LocalDate,
    val mealType: MealType,
    val foodId: String,
    val foodName: String,
    val grams: Double,
    val kcal: Double,
    val proteinG: Double,
    val carbsG: Double,
    val fatG: Double,
    val sodiumMg: Double
)

/** Cómo de exigente fue (o será) el día de entrenamiento: define los gramos de CHO por kg. */
enum class DayLoad(val label: String, val carbsPerKg: Double, val description: String) {
    REST("Descanso", 3.5, "Día sin entrenamiento o solo movilidad"),
    LOW("Carga baja", 5.0, "Menos de 60 min suaves"),
    MODERATE("Carga moderada", 6.5, "60-90 min o sesión de calidad corta"),
    HIGH("Carga alta", 8.5, "Más de 90 min o doble sesión"),
    RACE_WEEK("Carga de competencia", 9.5, "Carga de hidratos previa al evento")
}

data class NutritionTargets(
    val dayLoad: DayLoad,
    val kcal: Int,
    val carbsG: Int,
    val proteinG: Int,
    val fatG: Int,
    val waterMl: Int,
    val sodiumMg: Int,
    val bmr: Int,
    val trainingKcal: Int,
    val rationale: String
)

data class DailyNutrition(
    val date: LocalDate,
    val targets: NutritionTargets,
    val entries: List<MealEntry>,
    val waterLoggedMl: Int
) {
    val kcalConsumed: Double get() = entries.sumOf { it.kcal }
    val carbsConsumed: Double get() = entries.sumOf { it.carbsG }
    val proteinConsumed: Double get() = entries.sumOf { it.proteinG }
    val fatConsumed: Double get() = entries.sumOf { it.fatG }
    val sodiumConsumed: Double get() = entries.sumOf { it.sodiumMg }
    val kcalRemaining: Double get() = targets.kcal - kcalConsumed
    fun entriesFor(meal: MealType) = entries.filter { it.mealType == meal }
}
