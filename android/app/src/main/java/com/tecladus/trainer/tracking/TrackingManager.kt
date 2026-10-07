package com.tecladus.trainer.tracking

import android.location.Location
import com.tecladus.trainer.domain.logic.EnergyCalculator
import com.tecladus.trainer.domain.logic.GeoUtils
import com.tecladus.trainer.domain.logic.HydrationCalculator
import com.tecladus.trainer.domain.model.ActivitySession
import com.tecladus.trainer.domain.model.EffortIntensity
import com.tecladus.trainer.domain.model.FuelAlert
import com.tecladus.trainer.domain.model.FuelScheduleItem
import com.tecladus.trainer.domain.model.HydrationPlan
import com.tecladus.trainer.domain.model.IntakeEvent
import com.tecladus.trainer.domain.model.IntakeType
import com.tecladus.trainer.domain.model.LiveSessionState
import com.tecladus.trainer.domain.model.Sport
import com.tecladus.trainer.domain.model.TrackPoint
import com.tecladus.trainer.domain.model.TrackingState
import com.tecladus.trainer.domain.model.WeatherConditions
import com.tecladus.trainer.domain.model.WorkoutType
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/** Configuración con la que arranca una sesión (la arma la pantalla de pre-sesión). */
data class SessionConfig(
    val sport: Sport,
    val weightKg: Double,
    val hydrationPlan: HydrationPlan?,
    val intensity: EffortIntensity = EffortIntensity.MODERATE,
    val weather: WeatherConditions = WeatherConditions(),
    val plannedWorkoutId: Long? = null,
    val plannedType: WorkoutType? = null,
    val title: String = ""
)

/** Resultado de una sesión terminada, listo para persistir. */
data class SessionResult(
    val session: ActivitySession,
    val points: List<TrackPoint>,
    val intakes: List<IntakeEvent>
)

/**
 * Cerebro de la sesión en vivo: acumula el recorrido, calcula las métricas y dispara
 * las alertas de hidratación, sales y geles según la agenda calculada para esa sesión.
 *
 * Es independiente de Android salvo por [Location], así que se puede testear con
 * datos sintéticos.
 */
class TrackingManager {

    private val _state = MutableStateFlow(LiveSessionState())
    val state: StateFlow<LiveSessionState> = _state.asStateFlow()

    private val _alerts = MutableSharedFlow<FuelAlert>(replay = 0, extraBufferCapacity = 8)
    val alerts: SharedFlow<FuelAlert> = _alerts.asSharedFlow()

    private var config: SessionConfig? = null
    private var schedule: List<FuelScheduleItem> = emptyList()
    private var firedIndex = 0
    private val points = mutableListOf<TrackPoint>()
    private val intakes = mutableListOf<IntakeEvent>()
    private var distanceM = 0.0

    val currentConfig: SessionConfig? get() = config

    fun prepare(config: SessionConfig) {
        this.config = config
        points.clear()
        intakes.clear()
        distanceM = 0.0
        firedIndex = 0
        schedule = config.hydrationPlan?.let { HydrationCalculator.buildSchedule(it) } ?: defaultSchedule()
        _state.value = LiveSessionState(
            state = TrackingState.IDLE,
            sport = config.sport,
            hydrationPlan = config.hydrationPlan,
            plannedWorkoutId = config.plannedWorkoutId,
            plannedType = config.plannedType
        )
    }

    /** Agenda mínima cuando no hay plan calculado: agua cada 20 minutos. */
    private fun defaultSchedule(): List<FuelScheduleItem> = (1..12).map {
        FuelScheduleItem(
            atMinute = it * 20,
            type = IntakeType.WATER,
            fluidMl = 200,
            sodiumMg = 0,
            carbsG = 0,
            message = "Tomá unos 200 ml"
        )
    }

    fun start() {
        _state.value = _state.value.copy(
            state = TrackingState.RUNNING,
            startTimeMs = System.currentTimeMillis()
        )
    }

    fun pause() {
        if (_state.value.state == TrackingState.RUNNING) {
            _state.value = _state.value.copy(state = TrackingState.PAUSED)
        }
    }

    fun resume() {
        if (_state.value.state == TrackingState.PAUSED) {
            _state.value = _state.value.copy(state = TrackingState.RUNNING)
        }
    }

    /** Se llama una vez por segundo desde el servicio. */
    fun tick() {
        val current = _state.value
        if (current.state != TrackingState.RUNNING) return
        val moving = current.currentSpeedKmh > 2.0
        val elapsed = current.elapsedSec + 1
        val kcal = EnergyCalculator.sessionKcal(
            sport = current.sport,
            weightKg = config?.weightKg ?: 70.0,
            distanceM = current.distanceM,
            durationSec = elapsed,
            elevationGainM = current.elevationGainM,
            intensity = config?.intensity ?: EffortIntensity.MODERATE
        )
        _state.value = current.copy(
            elapsedSec = elapsed,
            movingSec = if (moving) current.movingSec + 1 else current.movingSec,
            kcal = kcal
        )
        checkAlerts(elapsed)
    }

    private fun checkAlerts(elapsedSec: Int) {
        val minute = elapsedSec / 60
        while (firedIndex < schedule.size && schedule[firedIndex].atMinute <= minute) {
            val item = schedule[firedIndex]
            firedIndex++
            val alert = buildAlert(item, elapsedSec)
            _state.value = _state.value.copy(pendingAlert = alert)
            _alerts.tryEmit(alert)
        }
    }

    private fun buildAlert(item: FuelScheduleItem, elapsedSec: Int): FuelAlert {
        val plan = _state.value.hydrationPlan
        val deficit = _state.value.fluidDeficitMl()
        val title = when (item.type) {
            IntakeType.WATER, IntakeType.ISOTONIC -> "Momento de hidratarte"
            IntakeType.SALT -> "Reponé sales"
            IntakeType.GEL -> "Cargá hidratos"
            IntakeType.SOLID -> "Comé algo sólido"
        }
        val extra = when {
            item.type == IntakeType.WATER && deficit > 300 ->
                " Vas ${deficit} ml por debajo del plan: no dejes que se agrande la deuda."
            item.type == IntakeType.SALT && plan != null ->
                " Perdés ~${plan.sweatRateLh.let { String.format("%.1f", it) }} L/h de sudor."
            else -> ""
        }
        return FuelAlert(
            type = item.type,
            title = title,
            message = item.message + extra,
            suggestedFluidMl = item.fluidMl,
            suggestedSodiumMg = item.sodiumMg,
            suggestedCarbsG = item.carbsG,
            triggeredAtSec = elapsedSec
        )
    }

    fun dismissAlert() {
        _state.value = _state.value.copy(pendingAlert = null)
    }

    /** Registra lo que el usuario efectivamente tomó/comió. */
    fun registerIntake(type: IntakeType, fluidMl: Int, sodiumMg: Int, carbsG: Int, note: String = "") {
        val event = IntakeEvent(
            sessionId = 0L,
            timestampMs = System.currentTimeMillis(),
            type = type,
            fluidMl = fluidMl,
            sodiumMg = sodiumMg,
            carbsG = carbsG,
            note = note
        )
        intakes += event
        _state.value = _state.value.copy(intakes = intakes.toList(), pendingAlert = null)
    }

    /** Nueva posición del GPS. */
    fun onLocation(location: Location) {
        val current = _state.value
        val candidate = TrackPoint(
            timestampMs = System.currentTimeMillis(),
            latitude = location.latitude,
            longitude = location.longitude,
            altitudeM = if (location.hasAltitude()) location.altitude else 0.0,
            speedMps = if (location.hasSpeed()) location.speed.toDouble() else 0.0,
            accuracyM = location.accuracy
        )
        val hasFix = location.accuracy <= 30f
        if (current.state != TrackingState.RUNNING) {
            _state.value = current.copy(gpsAccuracyM = location.accuracy, hasGpsFix = hasFix)
            return
        }
        val maxSpeed = when (current.sport) {
            Sport.CYCLING -> 25.0
            Sport.TREKKING -> 5.0
            else -> 12.0
        }
        val last = points.lastOrNull()
        if (!GeoUtils.isPlausible(last, candidate, maxSpeed)) {
            _state.value = current.copy(gpsAccuracyM = location.accuracy, hasGpsFix = hasFix)
            return
        }
        if (last != null) distanceM += GeoUtils.distanceMeters(last, candidate)
        points += candidate

        val elevation = GeoUtils.elevationGain(points)
        val splits = GeoUtils.computeSplits(points)
        val currentSpeedKmh = smoothedSpeedKmh()
        val avgPace = if (distanceM > 100 && current.movingSec > 0) {
            (current.movingSec / (distanceM / 1000.0)).toInt()
        } else 0
        val currentPace = if (currentSpeedKmh > 0.5) (3600.0 / currentSpeedKmh).toInt() else 0

        _state.value = current.copy(
            distanceM = distanceM,
            elevationGainM = elevation,
            points = points.toList(),
            splits = splits,
            currentSpeedKmh = currentSpeedKmh,
            currentPaceSecPerKm = currentPace,
            avgPaceSecPerKm = avgPace,
            gpsAccuracyM = location.accuracy,
            hasGpsFix = hasFix
        )
    }

    /** Velocidad suavizada con los últimos 20 segundos de recorrido. */
    private fun smoothedSpeedKmh(): Double {
        if (points.size < 2) return 0.0
        val last = points.last()
        val reference = points.lastOrNull { last.timestampMs - it.timestampMs >= 20_000 } ?: points.first()
        val dt = (last.timestampMs - reference.timestampMs) / 1000.0
        if (dt < 3) return points.takeLast(3).map { it.speedMps }.average() * 3.6
        var d = 0.0
        val startIndex = points.indexOf(reference)
        for (i in (startIndex + 1) until points.size) d += GeoUtils.distanceMeters(points[i - 1], points[i])
        return d / dt * 3.6
    }

    /** Cierra la sesión y devuelve el resultado para persistirlo. */
    fun finish(perceivedEffort: Int = 5): SessionResult {
        val current = _state.value
        val cfg = config
        val session = ActivitySession(
            sport = current.sport,
            startTimeMs = if (current.startTimeMs > 0) current.startTimeMs else System.currentTimeMillis(),
            endTimeMs = System.currentTimeMillis(),
            elapsedSec = current.elapsedSec,
            movingSec = if (current.movingSec > 0) current.movingSec else current.elapsedSec,
            distanceM = current.distanceM,
            elevationGainM = current.elevationGainM,
            kcal = current.kcal,
            perceivedEffort = perceivedEffort,
            tempC = cfg?.weather?.tempC ?: 20.0,
            humidityPct = cfg?.weather?.humidityPct ?: 50.0,
            plannedWorkoutId = current.plannedWorkoutId,
            plannedType = current.plannedType,
            fluidMl = current.fluidTakenMl,
            sodiumMg = current.sodiumTakenMg,
            carbsG = current.carbsTakenG,
            plannedFluidMl = current.hydrationPlan?.let {
                (it.fluidPerHourMl * current.elapsedSec / 3600.0).toInt()
            } ?: 0,
            plannedSodiumMg = current.hydrationPlan?.let {
                (it.sodiumPerHourMg * current.elapsedSec / 3600.0).toInt()
            } ?: 0,
            plannedCarbsG = current.hydrationPlan?.let {
                (it.carbsPerHourG * current.elapsedSec / 3600.0).toInt()
            } ?: 0,
            title = cfg?.title ?: ""
        )
        _state.value = current.copy(state = TrackingState.FINISHED)
        return SessionResult(session, points.toList(), intakes.toList())
    }

    fun reset() {
        points.clear()
        intakes.clear()
        distanceM = 0.0
        firedIndex = 0
        schedule = emptyList()
        config = null
        _state.value = LiveSessionState()
    }
}
