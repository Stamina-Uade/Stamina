package com.tecladus.trainer.data.repository

import com.tecladus.trainer.data.catalog.FoodCatalog
import com.tecladus.trainer.data.local.TrainerDatabase
import com.tecladus.trainer.domain.model.Food
import com.tecladus.trainer.domain.model.MealEntry
import com.tecladus.trainer.domain.model.MealType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.time.LocalDate

/**
 * Última acción reversible del diario. Existe para que un toque de más se pueda deshacer
 * sin tener que buscar el registro y borrarlo a mano.
 */
sealed interface UndoableAction {
    val message: String

    data class WaterAdded(val ml: Int) : UndoableAction {
        override val message: String =
            if (ml >= 0) "Sumaste $ml ml de agua" else "Restaste ${-ml} ml de agua"
    }

    data class MealAdded(val entryId: Long, val foodName: String) : UndoableAction {
        override val message: String = "Agregaste $foodName"
    }

    data class MealRemoved(val entry: MealEntry) : UndoableAction {
        override val message: String = "Borraste ${entry.foodName}"
    }
}

interface NutritionRepository {
    val selectedDate: StateFlow<LocalDate>
    val entries: StateFlow<List<MealEntry>>
    val waterMl: StateFlow<Int>
    val customFoods: StateFlow<List<Food>>
    /** Última acción que se puede deshacer (o null si no hay nada pendiente). */
    val lastAction: StateFlow<UndoableAction?>
    suspend fun selectDate(date: LocalDate)
    suspend fun refresh()
    suspend fun addFood(food: Food, grams: Double, mealType: MealType, date: LocalDate)
    suspend fun addQuickEntry(entry: MealEntry)
    suspend fun removeEntry(id: Long)
    suspend fun addWater(ml: Int)
    suspend fun undoLast()
    fun clearUndo()
    suspend fun addCustomFood(food: Food)
    fun search(query: String): List<Food>
    /** Comidas de un día puntual (para las estadísticas del historial). */
    suspend fun entriesFor(date: LocalDate): List<MealEntry>
}

class LocalNutritionRepository(private val db: TrainerDatabase) : NutritionRepository {

    private val _selectedDate = MutableStateFlow(LocalDate.now())
    override val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    private val _entries = MutableStateFlow<List<MealEntry>>(emptyList())
    override val entries: StateFlow<List<MealEntry>> = _entries.asStateFlow()

    private val _waterMl = MutableStateFlow(0)
    override val waterMl: StateFlow<Int> = _waterMl.asStateFlow()

    private val _customFoods = MutableStateFlow<List<Food>>(emptyList())
    override val customFoods: StateFlow<List<Food>> = _customFoods.asStateFlow()

    private val _lastAction = MutableStateFlow<UndoableAction?>(null)
    override val lastAction: StateFlow<UndoableAction?> = _lastAction.asStateFlow()

    override suspend fun selectDate(date: LocalDate) {
        _selectedDate.value = date
        _lastAction.value = null
        refresh()
    }

    override suspend fun refresh() {
        val date = _selectedDate.value
        withContext(Dispatchers.IO) {
            val meals = db.queryMeals(date)
            val water = db.waterFor(date)
            val custom = db.queryCustomFoods()
            _entries.value = meals
            _waterMl.value = water
            _customFoods.value = custom
        }
    }

    override suspend fun addFood(food: Food, grams: Double, mealType: MealType, date: LocalDate) {
        val entry = MealEntry(
            date = date,
            mealType = mealType,
            foodId = food.id,
            foodName = food.name,
            grams = grams,
            kcal = food.kcalFor(grams),
            proteinG = food.proteinFor(grams),
            carbsG = food.carbsFor(grams),
            fatG = food.fatFor(grams),
            sodiumMg = food.sodiumFor(grams)
        )
        addQuickEntry(entry)
    }

    override suspend fun addQuickEntry(entry: MealEntry) {
        val id = withContext(Dispatchers.IO) { db.insertMeal(entry) }
        _lastAction.value = UndoableAction.MealAdded(id, entry.foodName)
        if (entry.date == _selectedDate.value) refresh()
    }

    override suspend fun removeEntry(id: Long) {
        val removed = _entries.value.firstOrNull { it.id == id }
        withContext(Dispatchers.IO) { db.deleteMeal(id) }
        if (removed != null) _lastAction.value = UndoableAction.MealRemoved(removed)
        refresh()
    }

    override suspend fun addWater(ml: Int) {
        applyWater(ml)
        _lastAction.value = UndoableAction.WaterAdded(ml)
    }

    /** Aplica el cambio de agua sin registrarlo como acción reversible. */
    private suspend fun applyWater(ml: Int) {
        val date = _selectedDate.value
        val updated = (_waterMl.value + ml).coerceAtLeast(0)
        withContext(Dispatchers.IO) { db.setWater(date, updated) }
        _waterMl.value = updated
    }

    override suspend fun undoLast() {
        when (val action = _lastAction.value) {
            is UndoableAction.WaterAdded -> applyWater(-action.ml)
            is UndoableAction.MealAdded -> {
                withContext(Dispatchers.IO) { db.deleteMeal(action.entryId) }
                refresh()
            }
            is UndoableAction.MealRemoved -> {
                withContext(Dispatchers.IO) { db.insertMeal(action.entry) }
                refresh()
            }
            null -> Unit
        }
        _lastAction.value = null
    }

    override fun clearUndo() {
        _lastAction.value = null
    }

    override suspend fun addCustomFood(food: Food) {
        withContext(Dispatchers.IO) { db.insertCustomFood(food) }
        refresh()
    }

    override fun search(query: String): List<Food> = FoodCatalog.search(query, _customFoods.value)

    override suspend fun entriesFor(date: LocalDate): List<MealEntry> =
        withContext(Dispatchers.IO) { db.queryMeals(date) }
}
