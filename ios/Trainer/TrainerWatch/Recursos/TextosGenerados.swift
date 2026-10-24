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
// 186 claves · idioma de autoría: en
// =============================================================================

import Foundation

/// Los textos. Una propiedad por clave del catálogo: un typo en una
/// clave deja de ser un bug de producción y pasa a ser un error de compilación.
enum TextosReloj {

    /// Tap to continue
    static var alertTapToContinue: String { String(localized: "alert.tap_to_continue") }

    /// There are no scheduled alerts for this workout yet.
    static var alertsEmpty: String { String(localized: "alerts.empty") }

    /// Done
    static var alertsPast: String { String(localized: "alerts.past") }

    /// Alerts
    static var alertsTitle: String { String(localized: "alerts.title") }

    /// Coming up
    static var alertsUpcoming: String { String(localized: "alerts.upcoming") }

    /// Back
    static var commonBack: String { String(localized: "common.back") }

    /// Cancel
    static var commonCancel: String { String(localized: "common.cancel") }

    /// Completed
    static var commonCompleted: String { String(localized: "common.completed") }

    /// Continue
    static var commonContinue: String { String(localized: "common.continue") }

    /// %1$lld of %2$lld
    static func commonCountOf(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "common.count_of"), arg1, arg2)
    }

    /// Discard
    static var commonDiscard: String { String(localized: "common.discard") }

    /// Are you sure you want to discard this data?
    static var commonDiscardConfirmation: String { String(localized: "common.discard_confirmation") }

    /// Finish
    static var commonFinish: String { String(localized: "common.finish") }

    /// Back
    static var commonGoBack: String { String(localized: "common.go_back") }

    /// No
    static var commonNo: String { String(localized: "common.no") }

    /// Start
    static var commonStart: String { String(localized: "common.start") }

    /// Undo
    static var commonUndo: String { String(localized: "common.undo") }

    /// Yes
    static var commonYes: String { String(localized: "common.yes") }

    /// Finish
    static var controlsFinish: String { String(localized: "controls.finish") }

    /// Lap
    static var controlsLap: String { String(localized: "controls.lap") }

    /// Pause
    static var controlsPause: String { String(localized: "controls.pause") }

    /// Resume
    static var controlsResume: String { String(localized: "controls.resume") }

    /// Settings
    static var controlsSettings: String { String(localized: "controls.settings") }

    /// Switch to cycling
    static var controlsTriathlonToCycling: String { String(localized: "controls.triathlon.to_cycling") }

    /// Switch to running
    static var controlsTriathlonToRunning: String { String(localized: "controls.triathlon.to_running") }

    /// The workout is paused. Save it or keep training.
    static var finishDetail: String { String(localized: "finish.detail") }

    /// Resume
    static var finishResume: String { String(localized: "finish.resume") }

    /// Save
    static var finishSave: String { String(localized: "finish.save") }

    /// Finish?
    static var finishTitle: String { String(localized: "finish.title") }

    /// Energy to keep going
    static var fuelFullscreenGelSubtitle: String { String(localized: "fuel.fullscreen.gel.subtitle") }

    /// Take a gel!
    static var fuelFullscreenGelTitle: String { String(localized: "fuel.fullscreen.gel.title") }

    /// Electrolytes for your pace
    static var fuelFullscreenSaltsSubtitle: String { String(localized: "fuel.fullscreen.salts.subtitle") }

    /// Take salts!
    static var fuelFullscreenSaltsTitle: String { String(localized: "fuel.fullscreen.salts.title") }

    /// Time to hydrate
    static var fuelFullscreenWaterSubtitle: String { String(localized: "fuel.fullscreen.water.subtitle") }

    /// Drink water!
    static var fuelFullscreenWaterTitle: String { String(localized: "fuel.fullscreen.water.title") }

    /// Gels
    static var fuelPromptGels: String { String(localized: "fuel.prompt.gels") }

    /// Carrying water or gels?
    static var fuelPromptQuestion: String { String(localized: "fuel.prompt.question") }

    /// Salts
    static var fuelPromptSalts: String { String(localized: "fuel.prompt.salts") }

    /// Tap to skip
    static var fuelPromptTapToSkip: String { String(localized: "fuel.prompt.tap_to_skip") }

    /// WHAT ARE YOU CARRYING?
    static var fuelPromptTitle: String { String(localized: "fuel.prompt.title") }

    /// Water (ml)
    static var fuelPromptWater: String { String(localized: "fuel.prompt.water") }

    /// You completed all sets today.
    static var goalAllSetsDone: String { String(localized: "goal.all_sets_done") }

    /// Goal completed!
    static var goalCompleted: String { String(localized: "goal.completed") }

    /// Continue workout
    static var goalContinueWorkout: String { String(localized: "goal.continue_workout") }

    /// Finish today's goal
    static var goalFinishToday: String { String(localized: "goal.finish_today") }

    /// Goal reached!
    static var goalReached: String { String(localized: "goal.reached") }

    /// + Set
    static var gymAddSet: String { String(localized: "gym.add_set") }

    /// Are you sure you want to discard this data?
    static var gymDiscardConfirmation: String { String(localized: "gym.discard.confirmation") }

    /// reps
    static var gymReps: String { String(localized: "gym.reps") }

    /// Set
    static var gymSet: String { String(localized: "gym.set") }

    /// Set done
    static var gymSetDone: String { String(localized: "gym.set_done") }

    /// Set %1$lld of %2$lld
    static func gymSetProgress(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "gym.set_progress"), arg1, arg2)
    }

    /// Discard
    static var gymSummaryDiscard: String { String(localized: "gym.summary.discard") }

    /// Exercises
    static var gymSummaryExercises: String { String(localized: "gym.summary.exercises") }

    /// Return
    static var gymSummaryGoBack: String { String(localized: "gym.summary.go_back") }

    /// Repetitions
    static var gymSummaryReps: String { String(localized: "gym.summary.reps") }

    /// Save
    static var gymSummarySave: String { String(localized: "gym.summary.save") }

    /// Sets logged
    static var gymSummarySetsLogged: String { String(localized: "gym.summary.sets_logged") }

    /// Workout completed
    static var gymSummaryTitle: String { String(localized: "gym.summary.title") }

    /// Total volume
    static var gymSummaryTotalVolume: String { String(localized: "gym.summary.total_volume") }

    /// Technique
    static var gymTechnique: String { String(localized: "gym.technique") }

    /// Technique & movement
    static var gymTechniqueMovement: String { String(localized: "gym.technique_movement") }

    /// Keep moving · Control your breathing
    static var gymTimerCue: String { String(localized: "gym.timer.cue") }

    /// Unmark set
    static var gymUnmarkSet: String { String(localized: "gym.unmark_set") }

    /// Distance units
    static var homeSettingsDistanceUnits: String { String(localized: "home.settings.distance_units") }

    /// Imperial · mi
    static var homeSettingsImperial: String { String(localized: "home.settings.imperial") }

    /// Metric · km
    static var homeSettingsMetric: String { String(localized: "home.settings.metric") }

    /// Settings
    static var homeSettingsTitle: String { String(localized: "home.settings.title") }

    /// Set %lld
    static func intervalsSetNumber(_ arg1: Int) -> String {
        String(format: String(localized: "intervals.set_number"), arg1)
    }

    /// SETS
    static var intervalsTitle: String { String(localized: "intervals.title") }

    /// Login Error
    static var loginErrorTitle: String { String(localized: "login.error.title") }

    /// The route arrives with GPS.
    static var mapNoGps: String { String(localized: "map.no_gps") }

    /// Route
    static var mapTitle: String { String(localized: "map.title") }

    /// Your location
    static var mapYourLocation: String { String(localized: "map.your_location") }

    /// average
    static var metricsAverage: String { String(localized: "metrics.average") }

    /// heart rate
    static var metricsHeartRate: String { String(localized: "metrics.heart_rate") }

    /// km
    static var metricsKm: String { String(localized: "metrics.km") }

    /// lap
    static var metricsLap: String { String(localized: "metrics.lap") }

    /// Screen locked · press the side button twice
    static var metricsLocked: String { String(localized: "metrics.locked") }

    /// pace
    static var metricsPace: String { String(localized: "metrics.pace") }

    /// Paused
    static var metricsPaused: String { String(localized: "metrics.paused") }

    /// Running
    static var metricsRunning: String { String(localized: "metrics.running") }

    /// Music
    static var musicPlaceholder: String { String(localized: "music.placeholder") }

    /// Good morning, today is a workout day. Today at %1$@: %2$@.
    static func notificationReminderMorningBody(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "notification.reminder.morning.body"), arg1, arg2)
    }

    /// Today's workout
    static var notificationReminderMorningTitle: String { String(localized: "notification.reminder.morning.title") }

    /// Your %1$@ workout is starting now. Let's go!
    static func notificationReminderTimeBody(_ arg1: String) -> String {
        String(format: String(localized: "notification.reminder.time.body"), arg1)
    }

    /// Time to train!
    static var notificationReminderTimeTitle: String { String(localized: "notification.reminder.time.title") }

    /// You completed %1$@ for %2$@ and covered %3$@. Great work!
    static func notificationWorkoutBody(_ arg1: String, _ arg2: String, _ arg3: String) -> String {
        String(format: String(localized: "notification.workout.body"), arg1, arg2, arg3)
    }

    /// a bike ride
    static var notificationWorkoutCycling: String { String(localized: "notification.workout.cycling") }

    /// %@ km
    static func notificationWorkoutDistance(_ arg1: String) -> String {
        String(format: String(localized: "notification.workout.distance"), arg1)
    }

    /// a hike
    static var notificationWorkoutHiking: String { String(localized: "notification.workout.hiking") }

    /// a workout
    static var notificationWorkoutOther: String { String(localized: "notification.workout.other") }

    /// a run
    static var notificationWorkoutRunning: String { String(localized: "notification.workout.running") }

    /// a strength workout
    static var notificationWorkoutStrength: String { String(localized: "notification.workout.strength") }

    /// a swim
    static var notificationWorkoutSwimming: String { String(localized: "notification.workout.swimming") }

    /// Workout complete!
    static var notificationWorkoutTitle: String { String(localized: "notification.workout.title") }

    /// Continue without iPhone
    static var phoneMissingContinueWithout: String { String(localized: "phone.missing.continue_without") }

    /// Make sure your phone is nearby and that you have logged into Stamina.
    static var phoneMissingDetail: String { String(localized: "phone.missing.detail") }

    /// Make sure your iPhone is nearby with Bluetooth turned on.
    static var phoneMissingDisconnected: String { String(localized: "phone.missing.disconnected") }

    /// Try Again
    static var phoneMissingRetry: String { String(localized: "phone.missing.retry") }

    /// Log into Stamina on your iPhone to continue.
    static var phoneMissingSignedOut: String { String(localized: "phone.missing.signed_out") }

    /// Phone not nearby
    static var phoneMissingTitle: String { String(localized: "phone.missing.title") }

    /// No routine today
    static var routineNone: String { String(localized: "routine.none") }

    /// It's a rest day. Enjoy it.
    static var routineNoneDetail: String { String(localized: "routine.none.detail") }

    /// Today's routine
    static var routineTitle: String { String(localized: "routine.title") }

    /// Your session has expired. Please log in again to continue.
    static var sessionExpiredMessage: String { String(localized: "session.expired.message") }

    /// Session Expired
    static var sessionExpiredTitle: String { String(localized: "session.expired.title") }

    /// Alerts
    static var settingsAlertsSection: String { String(localized: "settings.alerts.section") }

    /// Workout alerts
    static var settingsAlertsWorkout: String { String(localized: "settings.alerts.workout") }

    /// Laps and splits
    static var settingsAudioLapsSplits: String { String(localized: "settings.audio.laps_splits") }

    /// Start, finish and pause
    static var settingsAudioStartFinishPause: String { String(localized: "settings.audio.start_finish_pause") }

    /// Workout alerts
    static var settingsAudioWorkoutAlerts: String { String(localized: "settings.audio.workout_alerts") }

    /// Auto pause
    static var settingsAutoPause: String { String(localized: "settings.auto_pause") }

    /// Routine guidance
    static var settingsRoutine: String { String(localized: "settings.routine") }

    /// For this session only
    static var settingsThisSessionOnly: String { String(localized: "settings.this_session_only") }

    /// Settings
    static var settingsTitle: String { String(localized: "settings.title") }

    /// Imperial system
    static var settingsUnitsImperial: String { String(localized: "settings.units.imperial") }

    /// Metric system
    static var settingsUnitsMetric: String { String(localized: "settings.units.metric") }

    /// Units
    static var settingsUnitsTitle: String { String(localized: "settings.units.title") }

    /// Registration Error
    static var signupErrorTitle: String { String(localized: "signup.error.title") }

    /// No kilometers completed yet
    static var splitsEmpty: String { String(localized: "splits.empty") }

    /// KM %lld
    static func splitsKmNumber(_ arg1: Int) -> String {
        String(format: String(localized: "splits.km_number"), arg1)
    }

    /// KILOMETERS
    static var splitsTitle: String { String(localized: "splits.title") }

    /// Cycling
    static var sportCycling: String { String(localized: "sport.cycling") }

    /// Gym
    static var sportGym: String { String(localized: "sport.gym") }

    /// Running
    static var sportRunning: String { String(localized: "sport.running") }

    /// Start
    static var startBegin: String { String(localized: "start.begin") }

    /// Choose a sport
    static var startChooseSport: String { String(localized: "start.choose_sport") }

    /// %lld exercises
    static func startExercisesCount(_ arg1: Int) -> String {
        String(format: String(localized: "start.exercises_count"), arg1)
    }

    /// Completed · %@
    static func startGoalCompletedDistance(_ arg1: String) -> String {
        String(format: String(localized: "start.goal.completed_distance"), arg1)
    }

    /// Gym
    static var startGym: String { String(localized: "start.gym") }

    /// %lld sets
    static func startGymSetsCount(_ arg1: Int) -> String {
        String(format: String(localized: "start.gym.sets_count"), arg1)
    }

    /// Gym & today's routine
    static var startGymRoutine: String { String(localized: "start.gym_routine") }

    /// Not sharing
    static var startLocationOff: String { String(localized: "start.location.off") }

    /// Sharing location
    static var startLocationOn: String { String(localized: "start.location.on") }

    /// Share location
    static var startLocationShare: String { String(localized: "start.location.share") }

    /// %lld min
    static func startMinutes(_ arg1: Int) -> String {
        String(format: String(localized: "start.minutes"), arg1)
    }

    /// No workout planned for today
    static var startNoPlan: String { String(localized: "start.no_plan") }

    /// Indoor cycling
    static var startOptionBikeIndoor: String { String(localized: "start.option.bike_indoor") }

    /// Outdoor cycling
    static var startOptionBikeOutdoor: String { String(localized: "start.option.bike_outdoor") }

    /// Indoor run
    static var startOptionRunIndoor: String { String(localized: "start.option.run_indoor") }

    /// Outdoor run
    static var startOptionRunOutdoor: String { String(localized: "start.option.run_outdoor") }

    /// Pool swim
    static var startOptionSwimPool: String { String(localized: "start.option.swim_pool") }

    /// Full triathlon
    static var startOptionTriathlon: String { String(localized: "start.option.triathlon") }

    /// Indoor walk
    static var startOptionWalkIndoor: String { String(localized: "start.option.walk_indoor") }

    /// Outdoor walk
    static var startOptionWalkOutdoor: String { String(localized: "start.option.walk_outdoor") }

    /// Record
    static var startRecord: String { String(localized: "start.record") }

    /// Routine guidance
    static var startRoutine: String { String(localized: "start.routine") }

    /// Bike
    static var startSportBike: String { String(localized: "start.sport.bike") }

    /// Outdoor Cycling
    static var startSportBikeOutdoor: String { String(localized: "start.sport.bike_outdoor") }

    /// Run
    static var startSportRun: String { String(localized: "start.sport.run") }

    /// Outdoor Run
    static var startSportRunOutdoor: String { String(localized: "start.sport.run_outdoor") }

    /// Hike
    static var startSportTrek: String { String(localized: "start.sport.trek") }

    /// Outdoor Trekking
    static var startSportTrekOutdoor: String { String(localized: "start.sport.trek_outdoor") }

    /// Start workout
    static var startStartWorkout: String { String(localized: "start.start_workout") }

    /// Start
    static var startTitle: String { String(localized: "start.title") }

    /// Today’s workout
    static var startToday: String { String(localized: "start.today") }

    /// Today's Goal
    static var startTodayGoal: String { String(localized: "start.today_goal") }

    /// Close and resume
    static var stationaryClose: String { String(localized: "stationary.close") }

    /// This activity cannot be saved because no location changes were detected.
    static var stationaryDetail: String { String(localized: "stationary.detail") }

    /// Discard
    static var stationaryDiscard: String { String(localized: "stationary.discard") }

    /// Resume
    static var stationaryResume: String { String(localized: "stationary.resume") }

    /// No movement
    static var stationaryTitle: String { String(localized: "stationary.title") }

    /// ACTIVE CALORIES
    static var summaryActiveCalories: String { String(localized: "summary.active_calories") }

    /// AVERAGE SPEED
    static var summaryAverageSpeed: String { String(localized: "summary.average_speed") }

    /// Distance
    static var summaryDistance: String { String(localized: "summary.distance") }

    /// Done
    static var summaryDone: String { String(localized: "summary.done") }

    /// Duration
    static var summaryDuration: String { String(localized: "summary.duration") }

    /// ELEVATION GAIN
    static var summaryElevationGain: String { String(localized: "summary.elevation_gain") }

    /// Lap %lld
    static func summaryLapsItem(_ arg1: Int) -> String {
        String(format: String(localized: "summary.laps.item"), arg1)
    }

    /// LAPS
    static var summaryLapsTitle: String { String(localized: "summary.laps.title") }

    /// Pace
    static var summaryPace: String { String(localized: "summary.pace") }

    /// PAUSED TIME
    static var summaryPausedTime: String { String(localized: "summary.paused_time") }

    /// Save
    static var summarySave: String { String(localized: "summary.save") }

    /// Post pause: %@
    static func summarySegmentsPauseAfter(_ arg1: String) -> String {
        String(format: String(localized: "summary.segments.pause_after"), arg1)
    }

    /// SPLITS AND PAUSES
    static var summarySegmentsTitle: String { String(localized: "summary.segments.title") }

    /// Zone %lld
    static func summarySegmentsZone(_ arg1: Int) -> String {
        String(format: String(localized: "summary.segments.zone"), arg1)
    }

    /// You're done
    static var summaryTitle: String { String(localized: "summary.title") }

    /// Unsynced
    static var syncUnsynced: String { String(localized: "sync.unsynced") }

    /// Open Stamina on your iPhone to link your account to the watch.
    static var workoutOpenOnPhone: String { String(localized: "workout.open_on_phone") }

    /// AVERAGE
    static var workoutPaceAverage: String { String(localized: "workout.pace.average") }

    /// CURRENT
    static var workoutPaceCurrent: String { String(localized: "workout.pace.current") }

    /// Allow location and Health access to record this workout.
    static var workoutPermissionDenied: String { String(localized: "workout.permission_denied") }

    /// Auto-paused
    static var workoutStatusAutoPaused: String { String(localized: "workout.status.auto_paused") }

    /// IN PROGRESS
    static var workoutStatusInProgress: String { String(localized: "workout.status.in_progress") }

    /// Paused
    static var workoutStatusPaused: String { String(localized: "workout.status.paused") }
}
