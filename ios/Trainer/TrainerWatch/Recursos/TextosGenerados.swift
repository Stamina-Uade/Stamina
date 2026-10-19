// =============================================================================
// GENERADO por scripts/generar-textos-swift.mjs desde
// ios/Trainer/Trainer/Recursos/Localizable.xcstrings
//
// NO EDITAR A MANO. Para cambiar un texto se edita el CATÁLOGO —en Xcode, como
// cualquier traducción— y se corre `npm run generar:textos`.
//
// AGENTS.md §10: ningún texto visible al usuario va hardcodeado, y fechas,
// números y unidades se formatean con el locale del sistema. Esto resuelve lo
// primero; lo segundo es de quien presenta el dato.
//
// 209 claves · idioma de autoría: es
// =============================================================================

import Foundation

/// Los textos. Una propiedad por clave del catálogo: un typo en una
/// clave deja de ser un bug de producción y pasa a ser un error de compilación.
enum TextosReloj {

    /// Hecho
    static var alertDone: String { String(localized: "alert.done") }

    /// Gel + 300 ml con sales
    static var alertGel: String { String(localized: "alert.gel") }

    /// Vas 300 mg de sodio. Quedan 40 min de esfuerzo en Z2.
    static var alertGelDetail: String { String(localized: "alert.gel.detail") }

    /// Hidratación
    static var alertHydration: String { String(localized: "alert.hydration") }

    /// Minuto %lld
    static func alertMinute(_ arg1: Int) -> String {
        String(format: String(localized: "alert.minute"), arg1)
    }

    /// Sin agua encima
    static var alertNoWater: String { String(localized: "alert.no_water") }

    /// Listo
    static var alertReady: String { String(localized: "alert.ready") }

    /// Recordar en 5 min
    static var alertRemindLater: String { String(localized: "alert.remind_later") }

    /// Tocá para continuar
    static var alertTapToContinue: String { String(localized: "alert.tap_to_continue") }

    /// Tomá 200 ml
    static var alertWater: String { String(localized: "alert.water") }

    /// Vas %1$@ de %2$@. Con 26° perdés más de lo que sentís.
    static func alertWaterDetail(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "alert.water.detail"), arg1, arg2)
    }

    /// Todavía no hay avisos programados para esta salida.
    static var alertsEmpty: String { String(localized: "alerts.empty") }

    /// Lo que pasó
    static var alertsPast: String { String(localized: "alerts.past") }

    /// Avisos
    static var alertsTitle: String { String(localized: "alerts.title") }

    /// Lo que viene
    static var alertsUpcoming: String { String(localized: "alerts.upcoming") }

    /// Volver
    static var commonBack: String { String(localized: "common.back") }

    /// Cancelar
    static var commonCancel: String { String(localized: "common.cancel") }

    /// Completado
    static var commonCompleted: String { String(localized: "common.completed") }

    /// Continuar
    static var commonContinue: String { String(localized: "common.continue") }

    /// %1$lld de %2$lld
    static func commonCountOf(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "common.count_of"), arg1, arg2)
    }

    /// Descartar
    static var commonDiscard: String { String(localized: "common.discard") }

    /// ¿Seguro que quieres descartar estos datos?
    static var commonDiscardConfirmation: String { String(localized: "common.discard_confirmation") }

    /// Finalizar
    static var commonFinish: String { String(localized: "common.finish") }

    /// Regresar
    static var commonGoBack: String { String(localized: "common.go_back") }

    /// No
    static var commonNo: String { String(localized: "common.no") }

    /// Iniciar
    static var commonStart: String { String(localized: "common.start") }

    /// Deshacer
    static var commonUndo: String { String(localized: "common.undo") }

    /// Sí
    static var commonYes: String { String(localized: "common.yes") }

    /// Finalizar
    static var controlsFinish: String { String(localized: "controls.finish") }

    /// Vuelta
    static var controlsLap: String { String(localized: "controls.lap") }

    /// Bloquear
    static var controlsLock: String { String(localized: "controls.lock") }

    /// Pausar
    static var controlsPause: String { String(localized: "controls.pause") }

    /// Reanudar
    static var controlsResume: String { String(localized: "controls.resume") }

    /// Ajustes
    static var controlsSettings: String { String(localized: "controls.settings") }

    /// Controles
    static var controlsTitle: String { String(localized: "controls.title") }

    /// Pasar a Bicicleta
    static var controlsTriathlonToCycling: String { String(localized: "controls.triathlon.to_cycling") }

    /// Pasar a Carrera
    static var controlsTriathlonToRunning: String { String(localized: "controls.triathlon.to_running") }

    /// El entrenamiento está pausado. Guardalo o seguí entrenando.
    static var finishDetail: String { String(localized: "finish.detail") }

    /// Reanudar
    static var finishResume: String { String(localized: "finish.resume") }

    /// Guardar
    static var finishSave: String { String(localized: "finish.save") }

    /// ¿Finalizar?
    static var finishTitle: String { String(localized: "finish.title") }

    /// Tocá para cerrar
    static var fuelAlertDismiss: String { String(localized: "fuel.alert.dismiss") }

    /// Tomá un gel
    static var fuelAlertGel: String { String(localized: "fuel.alert.gel") }

    /// Considerá las sales
    static var fuelAlertSalts: String { String(localized: "fuel.alert.salts") }

    /// Tomá agua
    static var fuelAlertWater: String { String(localized: "fuel.alert.water") }

    /// Avisos de nutrición e hidratación
    static var fuelEnable: String { String(localized: "fuel.enable") }

    /// Energía para continuar
    static var fuelFullscreenGelSubtitle: String { String(localized: "fuel.fullscreen.gel.subtitle") }

    /// ¡Tomá un gel!
    static var fuelFullscreenGelTitle: String { String(localized: "fuel.fullscreen.gel.title") }

    /// Electrolitos para tu ritmo
    static var fuelFullscreenSaltsSubtitle: String { String(localized: "fuel.fullscreen.salts.subtitle") }

    /// ¡Tomá sales!
    static var fuelFullscreenSaltsTitle: String { String(localized: "fuel.fullscreen.salts.title") }

    /// Momento de hidratarte
    static var fuelFullscreenWaterSubtitle: String { String(localized: "fuel.fullscreen.water.subtitle") }

    /// ¡Tomá agua!
    static var fuelFullscreenWaterTitle: String { String(localized: "fuel.fullscreen.water.title") }

    /// Geles
    static var fuelGels: String { String(localized: "fuel.gels") }

    /// Geles
    static var fuelPromptGels: String { String(localized: "fuel.prompt.gels") }

    /// ¿Llevás hidratación o geles?
    static var fuelPromptQuestion: String { String(localized: "fuel.prompt.question") }

    /// Sales
    static var fuelPromptSalts: String { String(localized: "fuel.prompt.salts") }

    /// Tocá para saltear
    static var fuelPromptTapToSkip: String { String(localized: "fuel.prompt.tap_to_skip") }

    /// ¿QUÉ LLEVÁS?
    static var fuelPromptTitle: String { String(localized: "fuel.prompt.title") }

    /// Agua
    static var fuelPromptWater: String { String(localized: "fuel.prompt.water") }

    /// Sales
    static var fuelSalts: String { String(localized: "fuel.salts") }

    /// Lo que llevás
    static var fuelTitle: String { String(localized: "fuel.title") }

    /// Agua (ml)
    static var fuelWater: String { String(localized: "fuel.water") }

    /// Terminaste todas las series de hoy.
    static var goalAllSetsDone: String { String(localized: "goal.all_sets_done") }

    /// ¡Objetivo completado!
    static var goalCompleted: String { String(localized: "goal.completed") }

    /// Continuar entrenamiento
    static var goalContinueWorkout: String { String(localized: "goal.continue_workout") }

    /// Finalizar objetivo de hoy
    static var goalFinishToday: String { String(localized: "goal.finish_today") }

    /// ¡Objetivo alcanzado!
    static var goalReached: String { String(localized: "goal.reached") }

    /// + Serie
    static var gymAddSet: String { String(localized: "gym.add_set") }

    /// ¿Seguro que quieres descartar estos datos?
    static var gymDiscardConfirmation: String { String(localized: "gym.discard.confirmation") }

    /// reps
    static var gymReps: String { String(localized: "gym.reps") }

    /// Serie
    static var gymSet: String { String(localized: "gym.set") }

    /// Serie hecha
    static var gymSetDone: String { String(localized: "gym.set_done") }

    /// Serie %1$lld de %2$lld
    static func gymSetProgress(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "gym.set_progress"), arg1, arg2)
    }

    /// Descartar
    static var gymSummaryDiscard: String { String(localized: "gym.summary.discard") }

    /// Ejercicios
    static var gymSummaryExercises: String { String(localized: "gym.summary.exercises") }

    /// Regresar
    static var gymSummaryGoBack: String { String(localized: "gym.summary.go_back") }

    /// Repeticiones
    static var gymSummaryReps: String { String(localized: "gym.summary.reps") }

    /// Guardar
    static var gymSummarySave: String { String(localized: "gym.summary.save") }

    /// Series registradas
    static var gymSummarySetsLogged: String { String(localized: "gym.summary.sets_logged") }

    /// Entrenamiento finalizado
    static var gymSummaryTitle: String { String(localized: "gym.summary.title") }

    /// Volumen total
    static var gymSummaryTotalVolume: String { String(localized: "gym.summary.total_volume") }

    /// Técnica
    static var gymTechnique: String { String(localized: "gym.technique") }

    /// Técnica y movimiento
    static var gymTechniqueMovement: String { String(localized: "gym.technique_movement") }

    /// Movimiento continuo · Controlá la respiración
    static var gymTimerCue: String { String(localized: "gym.timer.cue") }

    /// Desmarcar serie
    static var gymUnmarkSet: String { String(localized: "gym.unmark_set") }

    /// Unidades de distancia
    static var homeSettingsDistanceUnits: String { String(localized: "home.settings.distance_units") }

    /// Imperial · mi
    static var homeSettingsImperial: String { String(localized: "home.settings.imperial") }

    /// Métrico · km
    static var homeSettingsMetric: String { String(localized: "home.settings.metric") }

    /// Ajustes
    static var homeSettingsTitle: String { String(localized: "home.settings.title") }

    /// Serie %lld
    static func intervalsSetNumber(_ arg1: Int) -> String {
        String(format: String(localized: "intervals.set_number"), arg1)
    }

    /// SERIES
    static var intervalsTitle: String { String(localized: "intervals.title") }

    /// Error al iniciar sesión
    static var loginErrorTitle: String { String(localized: "login.error.title") }

    /// El recorrido llega con el GPS.
    static var mapNoGps: String { String(localized: "map.no_gps") }

    /// Recorrido
    static var mapTitle: String { String(localized: "map.title") }

    /// Tu ubicación
    static var mapYourLocation: String { String(localized: "map.your_location") }

    /// promedio
    static var metricsAverage: String { String(localized: "metrics.average") }

    /// pulso
    static var metricsHeartRate: String { String(localized: "metrics.heart_rate") }

    /// km
    static var metricsKm: String { String(localized: "metrics.km") }

    /// parcial
    static var metricsLap: String { String(localized: "metrics.lap") }

    /// Pantalla bloqueada · apretá dos veces el botón lateral
    static var metricsLocked: String { String(localized: "metrics.locked") }

    /// ritmo
    static var metricsPace: String { String(localized: "metrics.pace") }

    /// En pausa
    static var metricsPaused: String { String(localized: "metrics.paused") }

    /// En curso
    static var metricsRunning: String { String(localized: "metrics.running") }

    /// Música
    static var musicPlaceholder: String { String(localized: "music.placeholder") }

    /// Buen día, hoy es día de entreno. Hoy a las %1$@ toca hacer %2$@.
    static func notificationReminderMorningBody(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "notification.reminder.morning.body"), arg1, arg2)
    }

    /// Entrenamiento de hoy
    static var notificationReminderMorningTitle: String { String(localized: "notification.reminder.morning.title") }

    /// Tu entrenamiento de %1$@ es en este momento. ¡A darlo todo!
    static func notificationReminderTimeBody(_ arg1: String) -> String {
        String(format: String(localized: "notification.reminder.time.body"), arg1)
    }

    /// ¡Hora de entrenar!
    static var notificationReminderTimeTitle: String { String(localized: "notification.reminder.time.title") }

    /// Hiciste %1$@ durante %2$@ y recorriste %3$@. ¡Gran trabajo!
    static func notificationWorkoutBody(_ arg1: String, _ arg2: String, _ arg3: String) -> String {
        String(format: String(localized: "notification.workout.body"), arg1, arg2, arg3)
    }

    /// ciclismo
    static var notificationWorkoutCycling: String { String(localized: "notification.workout.cycling") }

    /// %@ km
    static func notificationWorkoutDistance(_ arg1: String) -> String {
        String(format: String(localized: "notification.workout.distance"), arg1)
    }

    /// trekking
    static var notificationWorkoutHiking: String { String(localized: "notification.workout.hiking") }

    /// un entrenamiento
    static var notificationWorkoutOther: String { String(localized: "notification.workout.other") }

    /// running
    static var notificationWorkoutRunning: String { String(localized: "notification.workout.running") }

    /// fuerza
    static var notificationWorkoutStrength: String { String(localized: "notification.workout.strength") }

    /// natación
    static var notificationWorkoutSwimming: String { String(localized: "notification.workout.swimming") }

    /// ¡Entrenamiento completado!
    static var notificationWorkoutTitle: String { String(localized: "notification.workout.title") }

    /// Continuar sin iPhone
    static var phoneMissingContinueWithout: String { String(localized: "phone.missing.continue_without") }

    /// Asegúrate de que tu teléfono esté cerca y de que hayas iniciado sesión en Stamina.
    static var phoneMissingDetail: String { String(localized: "phone.missing.detail") }

    /// Asegúrate de que tu iPhone esté cerca y con Bluetooth encendido.
    static var phoneMissingDisconnected: String { String(localized: "phone.missing.disconnected") }

    /// Volver a intentar
    static var phoneMissingRetry: String { String(localized: "phone.missing.retry") }

    /// Inicia sesión en Stamina desde tu iPhone para continuar.
    static var phoneMissingSignedOut: String { String(localized: "phone.missing.signed_out") }

    /// Sin teléfono cerca
    static var phoneMissingTitle: String { String(localized: "phone.missing.title") }

    /// Hoy no hay rutina
    static var routineNone: String { String(localized: "routine.none") }

    /// Es un día de descanso. Disfrutalo.
    static var routineNoneDetail: String { String(localized: "routine.none.detail") }

    /// Rutina de hoy
    static var routineTitle: String { String(localized: "routine.title") }

    /// Tu sesión ha expirado. Por favor, inicia sesión nuevamente para continuar.
    static var sessionExpiredMessage: String { String(localized: "session.expired.message") }

    /// Sesión expirada
    static var sessionExpiredTitle: String { String(localized: "session.expired.title") }

    /// Alertas
    static var settingsAlertsSection: String { String(localized: "settings.alerts.section") }

    /// Alertas de entrenamiento
    static var settingsAlertsWorkout: String { String(localized: "settings.alerts.workout") }

    /// Vueltas y parciales
    static var settingsAudioLapsSplits: String { String(localized: "settings.audio.laps_splits") }

    /// Inicio, fin y pausa
    static var settingsAudioStartFinishPause: String { String(localized: "settings.audio.start_finish_pause") }

    /// Avisos de entrenamiento
    static var settingsAudioWorkoutAlerts: String { String(localized: "settings.audio.workout_alerts") }

    /// Pausa automática
    static var settingsAutoPause: String { String(localized: "settings.auto_pause") }

    /// Avisos de sales y geles
    static var settingsFuelAlerts: String { String(localized: "settings.fuel_alerts") }

    /// Guía de la rutina
    static var settingsRoutine: String { String(localized: "settings.routine") }

    /// Sólo para esta salida
    static var settingsThisSessionOnly: String { String(localized: "settings.this_session_only") }

    /// Ajustes
    static var settingsTitle: String { String(localized: "settings.title") }

    /// Sistema imperial
    static var settingsUnitsImperial: String { String(localized: "settings.units.imperial") }

    /// Sistema métrico
    static var settingsUnitsMetric: String { String(localized: "settings.units.metric") }

    /// Unidades
    static var settingsUnitsTitle: String { String(localized: "settings.units.title") }

    /// Error en el registro
    static var signupErrorTitle: String { String(localized: "signup.error.title") }

    /// Sin kilómetros completados aún
    static var splitsEmpty: String { String(localized: "splits.empty") }

    /// KM %lld
    static func splitsKmNumber(_ arg1: Int) -> String {
        String(format: String(localized: "splits.km_number"), arg1)
    }

    /// KILÓMETROS
    static var splitsTitle: String { String(localized: "splits.title") }

    /// Bicicleta
    static var sportCycling: String { String(localized: "sport.cycling") }

    /// Gimnasio
    static var sportGym: String { String(localized: "sport.gym") }

    /// Carrera
    static var sportRunning: String { String(localized: "sport.running") }

    /// Inicio
    static var startBegin: String { String(localized: "start.begin") }

    /// Elegí un deporte
    static var startChooseSport: String { String(localized: "start.choose_sport") }

    /// %lld ejercicios
    static func startExercisesCount(_ arg1: Int) -> String {
        String(format: String(localized: "start.exercises_count"), arg1)
    }

    /// %lld geles
    static func startGelsCount(_ arg1: Int) -> String {
        String(format: String(localized: "start.gels_count"), arg1)
    }

    /// Completado · %@
    static func startGoalCompletedDistance(_ arg1: String) -> String {
        String(format: String(localized: "start.goal.completed_distance"), arg1)
    }

    /// Gimnasio
    static var startGym: String { String(localized: "start.gym") }

    /// %lld series
    static func startGymSetsCount(_ arg1: Int) -> String {
        String(format: String(localized: "start.gym.sets_count"), arg1)
    }

    /// Gimnasio y rutina de hoy
    static var startGymRoutine: String { String(localized: "start.gym_routine") }

    /// No compartir
    static var startLocationOff: String { String(localized: "start.location.off") }

    /// Compartiendo
    static var startLocationOn: String { String(localized: "start.location.on") }

    /// Compartir ubicación
    static var startLocationShare: String { String(localized: "start.location.share") }

    /// %lld min
    static func startMinutes(_ arg1: Int) -> String {
        String(format: String(localized: "start.minutes"), arg1)
    }

    /// No hay una sesión planificada para hoy
    static var startNoPlan: String { String(localized: "start.no_plan") }

    /// Bicicleta interior
    static var startOptionBikeIndoor: String { String(localized: "start.option.bike_indoor") }

    /// Bicicleta exterior
    static var startOptionBikeOutdoor: String { String(localized: "start.option.bike_outdoor") }

    /// Carrera interior
    static var startOptionRunIndoor: String { String(localized: "start.option.run_indoor") }

    /// Carrera exterior
    static var startOptionRunOutdoor: String { String(localized: "start.option.run_outdoor") }

    /// Natación piscina
    static var startOptionSwimPool: String { String(localized: "start.option.swim_pool") }

    /// Triatlón completo
    static var startOptionTriathlon: String { String(localized: "start.option.triathlon") }

    /// Caminata interior
    static var startOptionWalkIndoor: String { String(localized: "start.option.walk_indoor") }

    /// Caminata exterior
    static var startOptionWalkOutdoor: String { String(localized: "start.option.walk_outdoor") }

    /// Registrar
    static var startRecord: String { String(localized: "start.record") }

    /// Guía de la rutina
    static var startRoutine: String { String(localized: "start.routine") }

    /// Bicicleta
    static var startSportBike: String { String(localized: "start.sport.bike") }

    /// Ciclismo (exterior)
    static var startSportBikeOutdoor: String { String(localized: "start.sport.bike_outdoor") }

    /// Carrera
    static var startSportRun: String { String(localized: "start.sport.run") }

    /// Carrera (exterior)
    static var startSportRunOutdoor: String { String(localized: "start.sport.run_outdoor") }

    /// Trekking
    static var startSportTrek: String { String(localized: "start.sport.trek") }

    /// Trekking (exterior)
    static var startSportTrekOutdoor: String { String(localized: "start.sport.trek_outdoor") }

    /// Empezar entrenamiento
    static var startStartWorkout: String { String(localized: "start.start_workout") }

    /// Empezar
    static var startTitle: String { String(localized: "start.title") }

    /// Hoy te toca
    static var startToday: String { String(localized: "start.today") }

    /// Objetivo de hoy
    static var startTodayGoal: String { String(localized: "start.today_goal") }

    /// Cerrar y reanudar
    static var stationaryClose: String { String(localized: "stationary.close") }

    /// No se puede guardar esta actividad porque no se detectan cambios en la ubicación.
    static var stationaryDetail: String { String(localized: "stationary.detail") }

    /// Descartar
    static var stationaryDiscard: String { String(localized: "stationary.discard") }

    /// Reanudar
    static var stationaryResume: String { String(localized: "stationary.resume") }

    /// Sin movimiento
    static var stationaryTitle: String { String(localized: "stationary.title") }

    /// CALORÍAS ACTIVAS
    static var summaryActiveCalories: String { String(localized: "summary.active_calories") }

    /// VELOCIDAD PROMEDIO
    static var summaryAverageSpeed: String { String(localized: "summary.average_speed") }

    /// Distancia
    static var summaryDistance: String { String(localized: "summary.distance") }

    /// Listo
    static var summaryDone: String { String(localized: "summary.done") }

    /// Duración
    static var summaryDuration: String { String(localized: "summary.duration") }

    /// DESNIVEL ACUMULADO
    static var summaryElevationGain: String { String(localized: "summary.elevation_gain") }

    /// Vuelta %lld
    static func summaryLapsItem(_ arg1: Int) -> String {
        String(format: String(localized: "summary.laps.item"), arg1)
    }

    /// VUELTAS
    static var summaryLapsTitle: String { String(localized: "summary.laps.title") }

    /// Ritmo
    static var summaryPace: String { String(localized: "summary.pace") }

    /// TIEMPO EN PAUSA
    static var summaryPausedTime: String { String(localized: "summary.paused_time") }

    /// Guardar
    static var summarySave: String { String(localized: "summary.save") }

    /// Pausa posterior: %@
    static func summarySegmentsPauseAfter(_ arg1: String) -> String {
        String(format: String(localized: "summary.segments.pause_after"), arg1)
    }

    /// TRAMOS Y PAUSAS
    static var summarySegmentsTitle: String { String(localized: "summary.segments.title") }

    /// Zona %lld
    static func summarySegmentsZone(_ arg1: Int) -> String {
        String(format: String(localized: "summary.segments.zone"), arg1)
    }

    /// Terminaste
    static var summaryTitle: String { String(localized: "summary.title") }

    /// Sin sincronizar
    static var syncUnsynced: String { String(localized: "sync.unsynced") }

    /// Abrí Stamina en el iPhone para vincular tu cuenta al reloj.
    static var workoutOpenOnPhone: String { String(localized: "workout.open_on_phone") }

    /// PROMEDIO
    static var workoutPaceAverage: String { String(localized: "workout.pace.average") }

    /// ACTUAL
    static var workoutPaceCurrent: String { String(localized: "workout.pace.current") }

    /// Permití ubicación y Salud para registrar esta salida.
    static var workoutPermissionDenied: String { String(localized: "workout.permission_denied") }

    /// Autopausado
    static var workoutStatusAutoPaused: String { String(localized: "workout.status.auto_paused") }

    /// EN CURSO
    static var workoutStatusInProgress: String { String(localized: "workout.status.in_progress") }

    /// Pausado
    static var workoutStatusPaused: String { String(localized: "workout.status.paused") }
}
