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
// 725 claves · idioma de autoría: en
// =============================================================================

import Foundation

/// Los textos. Una propiedad por clave del catálogo: un typo en una
/// clave deja de ser un bug de producción y pasa a ser un error de compilación.
enum Textos {

    /// Your data is still saved. If you reactivate it, everything will be just as you left it.
    static var accountDeactivatedBody: String { String(localized: "account.deactivated.body") }

    /// Whenever you want to come back, sign in.
    static var accountDeactivatedDone: String { String(localized: "account.deactivated.done") }

    /// Your account is deactivated
    static var accountDeactivatedTitle: String { String(localized: "account.deactivated.title") }

    /// You asked to delete it, and in %lld days it'll be gone for good. If you recover it, you lose nothing.
    static func accountPendingDeletionBody(_ arg1: Int) -> String {
        String(format: String(localized: "account.pending_deletion.body"), arg1)
    }

    /// If you change your mind, sign in within 30 days.
    static var accountPendingDeletionDone: String { String(localized: "account.pending_deletion.done") }

    /// Your account is going to be deleted
    static var accountPendingDeletionTitle: String { String(localized: "account.pending_deletion.title") }

    /// Reactivate
    static var accountReactivate: String { String(localized: "account.reactivate") }

    /// Recover
    static var accountRecover: String { String(localized: "account.recover") }

    /// Clear filters
    static var catalogClearFilters: String { String(localized: "catalog.clear_filters") }

    /// Try fewer filters, log a free exercise for this session, or suggest it for the catalog.
    static var catalogEmptyBody: String { String(localized: "catalog.empty.body") }

    /// Use a free exercise
    static var catalogEmptyFreeExercise: String { String(localized: "catalog.empty.free_exercise") }

    /// Suggest it for the catalog
    static var catalogEmptySuggest: String { String(localized: "catalog.empty.suggest") }

    /// I couldn't find what you're looking for
    static var catalogEmptyTitle: String { String(localized: "catalog.empty.title") }

    /// Widen the filters
    static var catalogEmptyWiden: String { String(localized: "catalog.empty.widen") }

    /// Equipment
    static var catalogEquipment: String { String(localized: "catalog.equipment") }

    /// Filters
    static var catalogFilters: String { String(localized: "catalog.filters") }

    /// Muscle
    static var catalogMuscle: String { String(localized: "catalog.muscle") }

    /// No equipment
    static var catalogNoEquipment: String { String(localized: "catalog.no_equipment") }

    /// Search by name or muscle
    static var catalogSearch: String { String(localized: "catalog.search") }

    /// Show %lld exercises
    static func catalogShowCount(_ arg1: Int) -> String {
        String(format: String(localized: "catalog.show_count"), arg1)
    }

    /// Catalog
    static var catalogTitle: String { String(localized: "catalog.title") }

    /// All
    static var commonAllPlural: String { String(localized: "common.all_plural") }

    /// Avg. pace
    static var commonAvgPace: String { String(localized: "common.avg_pace") }

    /// Avg. speed
    static var commonAvgSpeed: String { String(localized: "common.avg_speed") }

    /// Back
    static var commonBack: String { String(localized: "common.back") }

    /// Cancel
    static var commonCancel: String { String(localized: "common.cancel") }

    /// Close
    static var commonClose: String { String(localized: "common.close") }

    /// 6-character code
    static var commonCodeLabel: String { String(localized: "common.code.label") }

    /// Fill in what's missing to continue.
    static var commonCompleteToContinue: String { String(localized: "common.complete_to_continue") }

    /// Confirm
    static var commonConfirm: String { String(localized: "common.confirm") }

    /// Continue
    static var commonContinue: String { String(localized: "common.continue") }

    /// Continue
    static var commonContinueNext: String { String(localized: "common.continue_next") }

    /// Create account
    static var commonCreateAccount: String { String(localized: "common.create_account") }

    /// day
    static var commonDay: String { String(localized: "common.day") }

    /// days
    static var commonDays: String { String(localized: "common.days") }

    /// Discard
    static var commonDiscard: String { String(localized: "common.discard") }

    /// Distance
    static var commonDistance: String { String(localized: "common.distance") }

    /// Done
    static var commonDone: String { String(localized: "common.done") }

    /// Done
    static var commonDoneCheck: String { String(localized: "common.done_check") }

    /// Edit
    static var commonEdit: String { String(localized: "common.edit") }

    /// Elevation gain
    static var commonElevationGain: String { String(localized: "common.elevation_gain") }

    /// Email address
    static var commonEmailLabel: String { String(localized: "common.email_label") }

    /// you@mail.com
    static var commonEmailPlaceholder: String { String(localized: "common.email_placeholder") }

    /// Event date
    static var commonEventDate: String { String(localized: "common.event_date") }

    /// Google or Apple
    static var commonGoogleOrApple: String { String(localized: "common.google_or_apple") }

    /// Got it
    static var commonGotIt: String { String(localized: "common.got_it") }

    /// Keep going
    static var commonKeepGoing: String { String(localized: "common.keep_going") }

    /// Less
    static var commonLess: String { String(localized: "common.less") }

    /// More
    static var commonMore: String { String(localized: "common.more") }

    /// Next
    static var commonNext: String { String(localized: "common.next") }

    /// Not now
    static var commonNotNow: String { String(localized: "common.not_now") }

    /// Not set
    static var commonNotSet: String { String(localized: "common.not_set") }

    /// OK
    static var commonOk: String { String(localized: "common.ok") }

    /// Pace
    static var commonPace: String { String(localized: "common.pace") }

    /// Hide password
    static var commonPasswordHide: String { String(localized: "common.password.hide") }

    /// Show password
    static var commonPasswordShow: String { String(localized: "common.password.show") }

    /// ••••••••
    static var commonPasswordPlaceholder: String { String(localized: "common.password_placeholder") }

    /// Remove
    static var commonRemove: String { String(localized: "common.remove") }

    /// Resend code
    static var commonResendCode: String { String(localized: "common.resend_code") }

    /// Resend in %@
    static func commonResendIn(_ arg1: String) -> String {
        String(format: String(localized: "common.resend_in"), arg1)
    }

    /// Resume
    static var commonResume: String { String(localized: "common.resume") }

    /// Try again
    static var commonRetry: String { String(localized: "common.retry") }

    /// Route
    static var commonRoute: String { String(localized: "common.route") }

    /// Save
    static var commonSave: String { String(localized: "common.save") }

    /// Sign in
    static var commonSignIn: String { String(localized: "common.sign_in") }

    /// Registration progress
    static var commonSignupProgress: String { String(localized: "common.signup_progress") }

    /// Skip
    static var commonSkip: String { String(localized: "common.skip") }

    /// Speed
    static var commonSpeed: String { String(localized: "common.speed") }

    /// Start
    static var commonStart: String { String(localized: "common.start") }

    /// Remaining
    static var commonToGo: String { String(localized: "common.to_go") }

    /// Today
    static var commonToday: String { String(localized: "common.today") }

    /// Try again
    static var commonTryAgain: String { String(localized: "common.try_again") }

    /// Use
    static var commonUse: String { String(localized: "common.use") }

    /// weeks
    static var commonWeeks: String { String(localized: "common.weeks") }

    /// Workout button
    static var commonWorkoutButton: String { String(localized: "common.workout_button") }

    /// That request isn't the shape the server expects. That's a bug, not you.
    static var errorBadRequest: String { String(localized: "error.bad_request") }

    /// For your security, this code no longer works. Start again.
    static var errorCodeAttemptsExceeded: String { String(localized: "error.code_attempts_exceeded") }

    /// Too many attempts
    static var errorCodeAttemptsExceededTitle: String { String(localized: "error.code_attempts_exceeded.title") }

    /// 15 minutes went by. Start again.
    static var errorCodeExpired: String { String(localized: "error.code_expired") }

    /// 15 minutes went by. Ask for a new one from the start.
    static var errorCodeExpiredReset: String { String(localized: "error.code_expired.reset") }

    /// The code expired
    static var errorCodeExpiredTitle: String { String(localized: "error.code_expired.title") }

    /// We already sent you a code. Wait a minute to ask for another one.
    static var errorCodeResendTooSoon: String { String(localized: "error.code_resend_too_soon") }

    /// Wait a moment
    static var errorCodeResendTooSoonTitle: String { String(localized: "error.code_resend_too_soon.title") }

    /// The previous save is still going through. Try again in a moment.
    static var errorConflict: String { String(localized: "error.conflict") }

    /// That email is already registered.
    static var errorEmailAlreadyRegistered: String { String(localized: "error.email_already_registered") }

    /// You already have an account
    static var errorEmailAlreadyRegisteredTitle: String { String(localized: "error.email_already_registered.title") }

    /// Too much time went by
    static var errorExpiredTitle: String { String(localized: "error.expired.title") }

    /// Something broke on the server. Not your fault.
    static var errorInternal: String { String(localized: "error.internal") }

    /// Check it and try again.
    static var errorInvalidCode: String { String(localized: "error.invalid_code") }

    /// The code isn't correct
    static var errorInvalidCodeTitle: String { String(localized: "error.invalid_code.title") }

    /// That email and password don't match.
    static var errorInvalidCredentials: String { String(localized: "error.invalid_credentials") }

    /// We couldn't verify your account
    static var errorInvalidProviderTokenTitle: String { String(localized: "error.invalid_provider_token.title") }

    /// Your session expired. Sign in again.
    static var errorInvalidRefreshToken: String { String(localized: "error.invalid_refresh_token") }

    /// Too much time went by. Start again.
    static var errorInvalidRegistrationToken: String { String(localized: "error.invalid_registration_token") }

    /// Your sign-up expired
    static var errorInvalidRegistrationTokenTitle: String { String(localized: "error.invalid_registration_token.title") }

    /// Start again from the email step.
    static var errorInvalidResetToken: String { String(localized: "error.invalid_reset_token") }

    /// You have to accept the health notice to create an account.
    static var errorLegalNotAccepted: String { String(localized: "error.legal_not_accepted") }

    /// Read them again to continue.
    static var errorLegalVersionStale: String { String(localized: "error.legal_version_stale") }

    /// The texts changed
    static var errorLegalVersionStaleTitle: String { String(localized: "error.legal_version_stale.title") }

    /// That address doesn't exist on the server.
    static var errorNotFound: String { String(localized: "error.not_found") }

    /// Check your connection and try again.
    static var errorOffline: String { String(localized: "error.offline") }

    /// No connection
    static var errorOfflineTitle: String { String(localized: "error.offline.title") }

    /// You created it with %1$@, so it has no password. Use “Continue with %1$@” or choose a password from “Forgot yo
    static func errorPasswordNotSet(_ arg1: String) -> String {
        String(format: String(localized: "error.password_not_set"), arg1)
    }

    /// This account signs in with %@
    static func errorPasswordNotSetTitle(_ arg1: String) -> String {
        String(format: String(localized: "error.password_not_set.title"), arg1)
    }

    /// A profile detail is missing before we can build the plan.
    static var errorProfileIncomplete: String { String(localized: "error.profile_incomplete") }

    /// Too many attempts. Wait a moment before trying again.
    static var errorRateLimited: String { String(localized: "error.rate_limited") }

    /// Too many attempts
    static var errorRateLimitedTitle: String { String(localized: "error.rate_limited.title") }

    /// The server isn't responding. Try again in a moment.
    static var errorServerUnavailable: String { String(localized: "error.server_unavailable") }

    /// The server isn't responding
    static var errorServerUnavailableTitle: String { String(localized: "error.server_unavailable.title") }

    /// The session was closed elsewhere. Sign in again.
    static var errorSessionRevoked: String { String(localized: "error.session_revoked") }

    /// For your security, we've blocked sign-in with this email for 15 minutes.
    static var errorTooManyAttempts: String { String(localized: "error.too_many_attempts") }

    /// Too many attempts
    static var errorTooManyAttemptsTitle: String { String(localized: "error.too_many_attempts.title") }

    /// Your session expired. Sign in again.
    static var errorUnauthorized: String { String(localized: "error.unauthorized") }

    /// The server replied something unexpected. That's a bug, not you.
    static var errorUnexpectedResponse: String { String(localized: "error.unexpected_response") }

    /// It didn't work. The server replied “%@”.
    static func errorUnknownCode(_ arg1: String) -> String {
        String(format: String(localized: "error.unknown_code"), arg1)
    }

    /// There's no account with that email.
    static var errorUserNotFound: String { String(localized: "error.user_not_found") }

    /// That account doesn't exist
    static var errorUserNotFoundTitle: String { String(localized: "error.user_not_found.title") }

    /// It needs at least 10 characters, an uppercase letter and a number.
    static var errorWeakPassword: String { String(localized: "error.weak_password") }

    /// The password doesn't meet the requirements
    static var errorWeakPasswordTitle: String { String(localized: "error.weak_password.title") }

    /// The password you entered is incorrect.
    static var errorWrongPassword: String { String(localized: "error.wrong_password") }

    /// Incorrect password
    static var errorWrongPasswordTitle: String { String(localized: "error.wrong_password.title") }

    /// Movement pattern
    static var exerciseMovementPattern: String { String(localized: "exercise.movement_pattern") }

    /// Primary muscle
    static var exercisePrimaryMuscle: String { String(localized: "exercise.primary_muscle") }

    /// Secondary
    static var exerciseSecondaryMuscles: String { String(localized: "exercise.secondary_muscles") }

    /// See alternatives
    static var exerciseSeeSubstitutes: String { String(localized: "exercise.see_substitutes") }

    /// Same movement pattern
    static var exerciseSubstitutesSamePattern: String { String(localized: "exercise.substitutes.same_pattern") }

    /// Alternatives to %@
    static func exerciseSubstitutesTitle(_ arg1: String) -> String {
        String(format: String(localized: "exercise.substitutes.title"), arg1)
    }

    /// Use this exercise
    static var exerciseUse: String { String(localized: "exercise.use") }

    /// The passwords don't match.
    static var fieldPasswordNoMatch: String { String(localized: "field.password.no_match") }

    /// Build my %@ plan
    static func goalsBuildMyPlan(_ arg1: String) -> String {
        String(format: String(localized: "goals.build_my_plan"), arg1)
    }

    /// The classic balance between aerobic endurance and race pace.
    static var goalsC10kBody: String { String(localized: "goals.c10k.body") }

    /// Progressive 10K
    static var goalsC10kTitle: String { String(localized: "goals.c10k.title") }

    /// Speed and consistency. Ideal for getting started or setting a personal best.
    static var goalsC5kBody: String { String(localized: "goals.c5k.body") }

    /// 5K Express
    static var goalsC5kTitle: String { String(localized: "goals.c5k.title") }

    /// Chooses this goal for your next plan
    static var goalsChooseHint: String { String(localized: "goals.choose.hint") }

    /// Choose date
    static var goalsChooseDate: String { String(localized: "goals.choose_date") }

    /// With a date, the plan counts the weeks until that day.
    static var goalsDateBody: String { String(localized: "goals.date.body") }

    /// Do you already have a race date?
    static var goalsDateQuestion: String { String(localized: "goals.date.question") }

    /// Elevation +
    static var goalsElevationPlus: String { String(localized: "goals.elevation_plus") }

    /// With your goal and date, the plan builds your weeks: phases, days and kilometers.
    static var goalsFooter: String { String(localized: "goals.footer") }

    /// A demanding mid-distance race. Requires progressive long runs and on-course fueling.
    static var goalsHalfMarathonBody: String { String(localized: "goals.half_marathon.body") }

    /// Half Marathon
    static var goalsHalfMarathonTitle: String { String(localized: "goals.half_marathon.title") }

    /// Health and base
    static var goalsHealthAndBase: String { String(localized: "goals.health_and_base") }

    /// Gentle conditioning to get back into the habit safely.
    static var goalsInjuryFreeBody: String { String(localized: "goals.injury_free.body") }

    /// Injury-free comeback
    static var goalsInjuryFreeTitle: String { String(localized: "goals.injury_free.title") }

    /// Your previous plan is over or you don't have a goal yet. Tell us what you want to run and when, and we'll buil
    static var goalsIntro: String { String(localized: "goals.intro") }

    /// The ultimate challenge of aerobic endurance, mental strength and stamina.
    static var goalsMarathonBody: String { String(localized: "goals.marathon.body") }

    /// Marathon
    static var goalsMarathonTitle: String { String(localized: "goals.marathon.title") }

    /// Technical terrain, hills and adapting to trails and mountains.
    static var goalsMountainTrailBody: String { String(localized: "goals.mountain_trail.body") }

    /// Mountain Trail
    static var goalsMountainTrailTitle: String { String(localized: "goals.mountain_trail.title") }

    /// New chapter
    static var goalsNewChapter: String { String(localized: "goals.new_chapter") }

    /// Open-water swimming, cycling and running, with transitions.
    static var goalsOlympicTriathlonBody: String { String(localized: "goals.olympic_triathlon.body") }

    /// Olympic Triathlon
    static var goalsOlympicTriathlonTitle: String { String(localized: "goals.olympic_triathlon.title") }

    /// We'll build an ongoing plan with no end date.
    static var goalsOngoingPlan: String { String(localized: "goals.ongoing_plan") }

    /// The plan will last %lld weeks of training
    static func goalsPlanDuration(_ arg1: Int) -> String {
        String(format: String(localized: "goals.plan_duration"), arg1)
    }

    /// Check your connection and try again.
    static var goalsSaveFailedMessage: String { String(localized: "goals.save_failed.message") }

    /// Couldn't save the goal
    static var goalsSaveFailedTitle: String { String(localized: "goals.save_failed.title") }

    /// We build your plan
    static var goalsStepBuildPlan: String { String(localized: "goals.step.build_plan") }

    /// Choose the goal
    static var goalsStepChooseGoal: String { String(localized: "goals.step.choose_goal") }

    /// Set the date
    static var goalsStepSetDate: String { String(localized: "goals.step.set_date") }

    /// Suggested training time:
    static var goalsSuggestedPrep: String { String(localized: "goals.suggested_prep") }

    /// Choose your next race
    static var goalsTitle: String { String(localized: "goals.title") }

    /// That's less than recommended for this goal (at least %lld weeks). You can pick a later date or a shorter goal.
    static func goalsTooShort(_ arg1: Int) -> String {
        String(format: String(localized: "goals.too_short"), arg1)
    }

    /// 10 to 14 weeks
    static var goalsWeeks1014: String { String(localized: "goals.weeks.10_14") }

    /// 12 to 16 weeks
    static var goalsWeeks1216: String { String(localized: "goals.weeks.12_16") }

    /// 14 to 20 weeks
    static var goalsWeeks1420: String { String(localized: "goals.weeks.14_20") }

    /// 16 to 24 weeks
    static var goalsWeeks1624: String { String(localized: "goals.weeks.16_24") }

    /// 6 to 10 weeks
    static var goalsWeeks610: String { String(localized: "goals.weeks.6_10") }

    /// 6 to 8 weeks
    static var goalsWeeks68: String { String(localized: "goals.weeks.6_8") }

    /// 8 to 12 weeks
    static var goalsWeeks812: String { String(localized: "goals.weeks.8_12") }

    /// What is %@ about?
    static func goalsWhatIs(_ arg1: String) -> String {
        String(format: String(localized: "goals.what_is"), arg1)
    }

    /// Add exercise
    static var gymAddExercise: String { String(localized: "gym.add_exercise") }

    /// Finish gym session
    static var gymFinish: String { String(localized: "gym.finish") }

    /// You run this afternoon: this is light strength work, not to failure, so the long run isn't compromised.
    static var gymNote: String { String(localized: "gym.note") }

    /// Last time: %@
    static func gymPrevious(_ arg1: String) -> String {
        String(format: String(localized: "gym.previous"), arg1)
    }

    /// %1$lld/%2$lld sets
    static func gymProgress(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "gym.progress"), arg1, arg2)
    }

    /// +30 s
    static var gymRestAddTime: String { String(localized: "gym.rest.add_time") }

    /// Next one!
    static var gymRestDone: String { String(localized: "gym.rest.done") }

    /// Rest is over for %@
    static func gymRestDoneDetail(_ arg1: String) -> String {
        String(format: String(localized: "gym.rest.done.detail"), arg1)
    }

    /// %lld sets to go
    static func gymRestSetsLeft(_ arg1: Int) -> String {
        String(format: String(localized: "gym.rest.sets_left"), arg1)
    }

    /// Skip
    static var gymRestSkip: String { String(localized: "gym.rest.skip") }

    /// Rest
    static var gymRestTitle: String { String(localized: "gym.rest.title") }

    /// %lld s rest
    static func gymRestSeconds(_ arg1: Int) -> String {
        String(format: String(localized: "gym.rest_seconds"), arg1)
    }

    /// Set %1$lld done · %2$@
    static func gymSetConfirm(_ arg1: Int, _ arg2: String) -> String {
        String(format: String(localized: "gym.set.confirm"), arg1, arg2)
    }

    /// Correct set %lld
    static func gymSetEdit(_ arg1: Int) -> String {
        String(format: String(localized: "gym.set.edit"), arg1)
    }

    /// Extra set
    static var gymSetExtra: String { String(localized: "gym.set.extra") }

    /// Go to next exercise
    static var gymSetNextExercise: String { String(localized: "gym.set.next_exercise") }

    /// Reps
    static var gymSetReps: String { String(localized: "gym.set.reps") }

    /// Seconds
    static var gymSetSeconds: String { String(localized: "gym.set.seconds") }

    /// Skip
    static var gymSetSkip: String { String(localized: "gym.set.skip") }

    /// Skipped
    static var gymSetSkipped: String { String(localized: "gym.set.skipped") }

    /// Weight
    static var gymSetWeight: String { String(localized: "gym.set.weight") }

    /// Set %lld
    static func gymSetNumber(_ arg1: Int) -> String {
        String(format: String(localized: "gym.set_number"), arg1)
    }

    /// sets completed · 45 min estimated
    static var gymSetsCompleted: String { String(localized: "gym.sets_completed") }

    /// %@ · upper body and core
    static func gymSubtitle(_ arg1: String) -> String {
        String(format: String(localized: "gym.subtitle"), arg1)
    }

    /// Close
    static var historyClose: String { String(localized: "history.close") }

    /// Tap %@ to start your first one. When you finish, it shows up here with its map, splits and pauses.
    static func historyEmptyBody(_ arg1: String) -> String {
        String(format: String(localized: "history.empty.body"), arg1)
    }

    /// Start my first workout
    static var historyEmptyStartFirst: String { String(localized: "history.empty.start_first") }

    /// No workouts yet
    static var historyEmptyTitle: String { String(localized: "history.empty.title") }

    /// Could not load your activities. Try again.
    static var historyError: String { String(localized: "history.error") }

    /// %lld sets
    static func historyGymSets(_ arg1: Int) -> String {
        String(format: String(localized: "history.gym_sets"), arg1)
    }

    /// 1 set
    static var historyGymSetsOne: String { String(localized: "history.gym_sets_one") }

    /// Load more
    static var historyLoadMore: String { String(localized: "history.load_more") }

    /// This activity has no saved GPS route.
    static var historyNoRoute: String { String(localized: "history.no_route") }

    /// Race
    static var historyRaceDay: String { String(localized: "history.race_day") }

    /// Race day: %@
    static func historyRaceOfTheDay(_ arg1: String) -> String {
        String(format: String(localized: "history.race_of_the_day"), arg1)
    }

    /// Opens this workout's map, splits and pauses
    static var historyRowHint: String { String(localized: "history.row.hint") }

    /// Watch
    static var historySourceWatch: String { String(localized: "history.source.watch") }

    /// %@ steps
    static func historySteps(_ arg1: String) -> String {
        String(format: String(localized: "history.steps"), arg1)
    }

    /// History
    static var historyTab: String { String(localized: "history.tab") }

    /// tap one to see the details
    static var historyTapOneForDetail: String { String(localized: "history.tap_one_for_detail") }

    /// %lld workouts
    static func historyTrainingsCount(_ arg1: Int) -> String {
        String(format: String(localized: "history.trainings_count"), arg1)
    }

    /// 1 workout
    static var historyTrainingsOne: String { String(localized: "history.trainings_one") }

    /// View details
    static var historyViewDetail: String { String(localized: "history.view_detail") }

    /// %lld workouts
    static func historyWorkoutsCount(_ arg1: Int) -> String {
        String(format: String(localized: "history.workouts_count"), arg1)
    }

    /// 1 workout
    static var historyWorkoutsOne: String { String(localized: "history.workouts_one") }

    /// %1$lld · %2$@ · %3$@
    static func historyYearTotal(_ arg1: Int, _ arg2: String, _ arg3: String) -> String {
        String(format: String(localized: "history.year_total"), arg1, arg2, arg3)
    }

    /// Your workouts
    static var historyYourWorkouts: String { String(localized: "history.your_workouts") }

    /// Back to workout
    static var homeBackToWorkout: String { String(localized: "home.back_to_workout") }

    /// For today's workout: %@.
    static func homeBringFor(_ arg1: String) -> String {
        String(format: String(localized: "home.bring.for"), arg1)
    }

    /// %lld g per hour
    static func homeBringGramsPerHour(_ arg1: Int) -> String {
        String(format: String(localized: "home.bring.grams_per_hour"), arg1)
    }

    /// %lld ml per hour
    static func homeBringMlPerHour(_ arg1: Int) -> String {
        String(format: String(localized: "home.bring.ml_per_hour"), arg1)
    }

    /// Recovery
    static var homeBringRecovery: String { String(localized: "home.bring.recovery") }

    /// %1$lld g protein + %2$lld g carbs
    static func homeBringRecoveryValue(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "home.bring.recovery_value"), arg1, arg2)
    }

    /// %lld g of carbs
    static func homeBringSnack(_ arg1: Int) -> String {
        String(format: String(localized: "home.bring.snack"), arg1)
    }

    /// %1$@ · %2$lld g of carbs
    static func homeBringSnackAt(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "home.bring.snack_at"), arg1, arg2)
    }

    /// Snack before
    static var homeBringSnackBefore: String { String(localized: "home.bring.snack_before") }

    /// Water with salts
    static var homeBringWaterWithSalts: String { String(localized: "home.bring.water_with_salts") }

    /// Choose goal
    static var homeChooseGoal: String { String(localized: "home.choose_goal") }

    /// Choose your next race and we'll build your plan week by week.
    static var homeChooseNextRace: String { String(localized: "home.choose_next_race") }

    /// A few details are missing to build your plan.
    static var homeCompleteProfileBody: String { String(localized: "home.complete_profile.body") }

    /// Complete profile
    static var homeCompleteProfileButton: String { String(localized: "home.complete_profile.button") }

    /// Complete your profile
    static var homeCompleteProfileTitle: String { String(localized: "home.complete_profile.title") }

    /// Nothing to show here yet.
    static var homeDataEmpty: String { String(localized: "home.data.empty") }

    /// We couldn't get this from the server. Try again in a while.
    static var homeDataError: String { String(localized: "home.data.error") }

    /// You're offline, and there's nothing saved on this phone to show yet. It loads by itself once you're back onlin
    static var homeDataOffline: String { String(localized: "home.data.offline") }

    /// This is calculated from your profile, which is missing some details. Complete it from Home.
    static var homeDataProfileIncomplete: String { String(localized: "home.data.profile_incomplete") }

    /// Try again
    static var homeDataRetry: String { String(localized: "home.data.retry") }

    /// Offline: this is what was saved %@.
    static func homeDataSavedOffline(_ arg1: String) -> String {
        String(format: String(localized: "home.data.saved_offline"), arg1)
    }

    /// Couldn't update: this is what was saved %@.
    static func homeDataSavedWithError(_ arg1: String) -> String {
        String(format: String(localized: "home.data.saved_with_error"), arg1)
    }

    /// Enter your new goal
    static var homeEnterNewGoal: String { String(localized: "home.enter_new_goal") }

    /// Carbs
    static var homeExplainerCarbs: String { String(localized: "home.explainer.carbs") }

    /// Gels
    static var homeExplainerGels: String { String(localized: "home.explainer.gels") }

    /// What to bring today
    static var homeExplainerWhatToBringToday: String { String(localized: "home.explainer.what_to_bring_today") }

    /// %lld gel
    static func homeGelCount(_ arg1: Int) -> String {
        String(format: String(localized: "home.gel_count"), arg1)
    }

    /// Good afternoon
    static var homeGreetingAfternoon: String { String(localized: "home.greeting.afternoon") }

    /// Good evening
    static var homeGreetingEvening: String { String(localized: "home.greeting.evening") }

    /// Good morning
    static var homeGreetingMorning: String { String(localized: "home.greeting.morning") }

    /// %lld ml/h
    static func homeMlPerHour(_ arg1: Int) -> String {
        String(format: String(localized: "home.ml_per_hour"), arg1)
    }

    /// No active goal
    static var homeNoActiveGoal: String { String(localized: "home.no_active_goal") }

    /// Nothing planned for today
    static var homeNothingPlannedToday: String { String(localized: "home.nothing_planned_today") }

    /// Start workout
    static var homeStartWorkout: String { String(localized: "home.start_workout") }

    /// Gym
    static var homeTabGym: String { String(localized: "home.tab.gym") }

    /// Home
    static var homeTabHome: String { String(localized: "home.tab.home") }

    /// Plan
    static var homeTabPlan: String { String(localized: "home.tab.plan") }

    /// Profile
    static var homeTabProfile: String { String(localized: "home.tab.profile") }

    /// Workout
    static var homeTabWorkout: String { String(localized: "home.tab.workout") }

    /// This week
    static var homeThisWeek: String { String(localized: "home.this_week") }

    /// Today · %@
    static func homeTodayAt(_ arg1: String) -> String {
        String(format: String(localized: "home.today_at"), arg1)
    }

    /// Today · Done
    static var homeTodayDone: String { String(localized: "home.today_done") }

    /// Tomorrow: %@
    static func homeTomorrow(_ arg1: String) -> String {
        String(format: String(localized: "home.tomorrow"), arg1)
    }

    /// View plan
    static var homeViewPlan: String { String(localized: "home.view_plan") }

    /// See the routine
    static var homeViewRoutine: String { String(localized: "home.view_routine") }

    /// Explains what to bring on the workout
    static var homeWhatToBringHint: String { String(localized: "home.what_to_bring.hint") }

    /// What to bring: %@
    static func homeWhatToBringLine(_ arg1: String) -> String {
        String(format: String(localized: "home.what_to_bring_line"), arg1)
    }

    /// Create my account
    static var legalCreateAccount: String { String(localized: "legal.create_account") }

    /// I already have an account, sign in
    static var legalGoToLogin: String { String(localized: "legal.go_to_login") }

    /// Health notice
    static var legalHealthTitle: String { String(localized: "legal.health.title") }

    /// We couldn't load the texts. Check your connection.
    static var legalNoText: String { String(localized: "legal.no_text") }

    /// Privacy Policy
    static var legalPrivacyTitle: String { String(localized: "legal.privacy.title") }

    /// Try again
    static var legalRetry: String { String(localized: "legal.retry") }

    /// Sign in with that email
    static var legalSignInWithEmail: String { String(localized: "legal.sign_in_with_email") }

    /// Sign in with your email and password.
    static var legalSignupAlreadyCreated: String { String(localized: "legal.signup_already_created") }

    /// Health
    static var legalTabHealth: String { String(localized: "legal.tab.health") }

    /// Privacy
    static var legalTabPrivacy: String { String(localized: "legal.tab.privacy") }

    /// Terms
    static var legalTabTerms: String { String(localized: "legal.tab.terms") }

    /// Terms and Conditions
    static var legalTermsTitle: String { String(localized: "legal.terms.title") }

    /// You already have an account with %1$@. If you link it, you'll be able to sign in with your password or with %2
    static func linkBody(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "link.body"), arg1, arg2)
    }

    /// You already have an account with %1$@. Enter its password to link it; then you'll be able to sign in with your
    static func linkBodyPassword(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "link.body_password"), arg1, arg2)
    }

    /// Link
    static var linkConfirm: String { String(localized: "link.confirm") }

    /// Link your %@ account?
    static func linkTitle(_ arg1: String) -> String {
        String(format: String(localized: "link.title"), arg1)
    }

    /// Continue with Apple
    static var loginApple: String { String(localized: "login.apple") }

    /// We couldn't sign you in
    static var loginErrorTitle: String { String(localized: "login.error.title") }

    /// Forgot your password?
    static var loginForgotPassword: String { String(localized: "login.forgot_password") }

    /// Continue with Google
    static var loginGoogle: String { String(localized: "login.google") }

    /// Don't have an account?
    static var loginNoAccount: String { String(localized: "login.no_account") }

    /// or
    static var loginOr: String { String(localized: "login.or") }

    /// Password
    static var loginPasswordLabel: String { String(localized: "login.password_label") }

    /// Sign in
    static var loginSignIn: String { String(localized: "login.sign_in") }

    /// Sign up
    static var loginSignUp: String { String(localized: "login.sign_up") }

    /// There's already an account with that email. Sign in with your email and password.
    static var loginSocialAccountExists: String { String(localized: "login.social_account_exists") }

    /// We couldn't finish signing you in. Try again in a moment.
    static var loginSocialFailed: String { String(localized: "login.social_failed") }

    /// Signing in this way isn't set up in this version of the app yet. Use your email for now.
    static var loginSocialNotConfigured: String { String(localized: "login.social_not_configured") }

    /// Sign in
    static var loginTitle: String { String(localized: "login.title") }

    /// Compass, heading %@, %lld degrees
    static func mapCompassAccessibility(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "map.compass.accessibility"), arg1, arg2)
    }

    /// With a valid medical clearance, Stamina can give you in-run suggestions.
    static var medicalAddBody: String { String(localized: "medical.add_body") }

    /// The certificate your doctor gave you
    static var medicalCertificateDetail: String { String(localized: "medical.certificate_detail") }

    /// Delete saved clearance
    static var medicalDelete: String { String(localized: "medical.delete") }

    /// Stamina doesn't replace seeing a doctor. Your clearance is stored only on this phone, protected, and is never 
    static var medicalDisclaimer: String { String(localized: "medical.disclaimer") }

    /// We couldn't open that file. Try another one.
    static var medicalErrorOpenFailed: String { String(localized: "medical.error.open_failed") }

    /// We couldn't save the clearance. Try again.
    static var medicalErrorSaveFailed: String { String(localized: "medical.error.save_failed") }

    /// The file is larger than 15 MB. Try a smaller photo.
    static var medicalErrorTooLarge: String { String(localized: "medical.error.too_large") }

    /// Expiration
    static var medicalExpiration: String { String(localized: "medical.expiration") }

    /// Expiration date
    static var medicalExpirationDate: String { String(localized: "medical.expiration_date") }

    /// Your medical clearance expires in 30 days
    static var medicalExpiresIn30Days: String { String(localized: "medical.expires_in_30_days") }

    /// Expires on %@
    static func medicalExpiresOn(_ arg1: String) -> String {
        String(format: String(localized: "medical.expires_on"), arg1)
    }

    /// Clearance file: %@. Tap to change it.
    static func medicalFileAccessibility(_ arg1: String) -> String {
        String(format: String(localized: "medical.file.accessibility"), arg1)
    }

    /// Choose the file and the date, and check the statement.
    static var medicalFormIncomplete: String { String(localized: "medical.form_incomplete") }

    /// Ready to save
    static var medicalReadyToSave: String { String(localized: "medical.ready_to_save") }

    /// Renew it to keep getting in-run suggestions.
    static var medicalRenewBody: String { String(localized: "medical.renew_body") }

    /// Sworn statement
    static var medicalSwornStatement: String { String(localized: "medical.sworn_statement") }

    /// I declare that my health information is true
    static var medicalSwornStatementDeclare: String { String(localized: "medical.sworn_statement.declare") }

    /// Medical clearance
    static var medicalTitle: String { String(localized: "medical.title") }

    /// Upload photo or PDF
    static var medicalUpload: String { String(localized: "medical.upload") }

    /// Upload the clearance, photo or PDF
    static var medicalUploadAccessibility: String { String(localized: "medical.upload_accessibility") }

    /// Valid · we'll remind you 30 days before
    static var medicalValidReminder: String { String(localized: "medical.valid_reminder") }

    /// Your medical clearance
    static var medicalYourClearance: String { String(localized: "medical.your_clearance") }

    /// high activity
    static var milestonesActivityHigh: String { String(localized: "milestones.activity.high") }

    /// light activity
    static var milestonesActivityLight: String { String(localized: "milestones.activity.light") }

    /// moderate activity
    static var milestonesActivityModerate: String { String(localized: "milestones.activity.moderate") }

    /// no activity
    static var milestonesActivityNone: String { String(localized: "milestones.activity.none") }

    /// very high activity
    static var milestonesActivityVeryHigh: String { String(localized: "milestones.activity.very_high") }

    /// no workouts
    static var milestonesNoWorkouts: String { String(localized: "milestones.no_workouts") }

    /// No workouts were recorded on this day.
    static var milestonesNoWorkoutsDay: String { String(localized: "milestones.no_workouts_day") }

    /// Number of steps
    static var milestonesStepsCount: String { String(localized: "milestones.steps.count") }

    /// Log steps
    static var milestonesStepsLog: String { String(localized: "milestones.steps.log") }

    /// Enter the number of steps for the selected day:
    static var milestonesStepsPrompt: String { String(localized: "milestones.steps.prompt") }

    /// Apple Health
    static var milestonesStepsSourceAppleHealth: String { String(localized: "milestones.steps.source.apple_health") }

    /// %lld workouts
    static func milestonesWorkoutsCount(_ arg1: Int) -> String {
        String(format: String(localized: "milestones.workouts_count"), arg1)
    }

    /// %1$lld °C at workout time (feels like %2$lld °C). Check the time and bring water.
    static func notificationHeatBody(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "notification.heat.body"), arg1, arg2)
    }

    /// Heat expected for your workout
    static var notificationHeatTitle: String { String(localized: "notification.heat.title") }

    /// Today is your %1$@. You trained %2$lld weeks for this: trust what you did and enjoy the race. Let's go!
    static func notificationRaceDayBody(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "notification.race_day.body"), arg1, arg2)
    }

    /// Today is your %1$@. You trained %2$lld weeks for this: trust what you did and enjoy the race. Let's go, %3$@!
    static func notificationRaceDayBodyName(_ arg1: String, _ arg2: Int, _ arg3: String) -> String {
        String(format: String(localized: "notification.race_day.body_name"), arg1, arg2, arg3)
    }

    /// The day is here!
    static var notificationRaceDayTitle: String { String(localized: "notification.race_day.title") }

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

    /// Before each session
    static var notificationsPrepBefore: String { String(localized: "notifications.prep.before") }

    /// Reminder to get ready
    static var notificationsPrepTitle: String { String(localized: "notifications.prep.title") }

    /// We sent a 6-character code to %@. It expires in 15 minutes.
    static func passwordResetCodeBody(_ arg1: String) -> String {
        String(format: String(localized: "password.reset.code.body"), arg1)
    }

    /// Check your email
    static var passwordResetCodeTitle: String { String(localized: "password.reset.code.title") }

    /// Verify code
    static var passwordResetCodeVerify: String { String(localized: "password.reset.code.verify") }

    /// We'll send you a code to choose a new password.
    static var passwordResetEmailBody: String { String(localized: "password.reset.email.body") }

    /// Send me the code
    static var passwordResetEmailSend: String { String(localized: "password.reset.email.send") }

    /// Recover your password
    static var passwordResetEmailTitle: String { String(localized: "password.reset.email.title") }

    /// We couldn't change your password
    static var passwordResetErrorTitle: String { String(localized: "password.reset.error.title") }

    /// New password
    static var passwordResetNewLabel: String { String(localized: "password.reset.new.label") }

    /// Repeat password
    static var passwordResetNewRepeatLabel: String { String(localized: "password.reset.new.repeat_label") }

    /// At least 10 characters
    static var passwordResetNewRuleLength: String { String(localized: "password.reset.new.rule_length") }

    /// One number
    static var passwordResetNewRuleNumber: String { String(localized: "password.reset.new.rule_number") }

    /// One capital letter
    static var passwordResetNewRuleUppercase: String { String(localized: "password.reset.new.rule_uppercase") }

    /// Save password
    static var passwordResetNewSave: String { String(localized: "password.reset.new.save") }

    /// Password strength: %lld of 3 rules met
    static func passwordResetNewStrength(_ arg1: Int) -> String {
        String(format: String(localized: "password.reset.new.strength"), arg1)
    }

    /// Choose a new password
    static var passwordResetNewTitle: String { String(localized: "password.reset.new.title") }

    /// If you don't recognize one, close them all to protect your account.
    static var passwordResetOtherSessionsBody: String { String(localized: "password.reset.other_sessions.body") }

    /// Close the other sessions
    static var passwordResetOtherSessionsClose: String { String(localized: "password.reset.other_sessions.close") }

    /// Keep them open
    static var passwordResetOtherSessionsKeep: String { String(localized: "password.reset.other_sessions.keep") }

    /// Sign out of your other devices?
    static var passwordResetOtherSessionsTitle: String { String(localized: "password.reset.other_sessions.title") }

    /// 1 gel
    static var planDayGelOne: String { String(localized: "plan.day.gel_one") }

    /// %lld gels
    static func planDayGelsCount(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.gels_count"), arg1)
    }

    /// I did it: mark as done
    static var planDayMarkDone: String { String(localized: "plan.day.mark_done") }

    /// We couldn't mark it. Check your connection and try again.
    static var planDayMarkFailed: String { String(localized: "plan.day.mark_failed") }

    /// We didn't record this workout. If you did it without recording it, mark it as done: it counts toward your week
    static var planDayMissed: String { String(localized: "plan.day.missed") }

    /// Start this workout
    static var planDayStartWorkout: String { String(localized: "plan.day.start_workout") }

    /// Strength day: exercises that protect your legs and make running feel easier.
    static var planDayStrength: String { String(localized: "plan.day.strength") }

    /// Tap to see what to do and why
    static var planDayTapToSee: String { String(localized: "plan.day.tap_to_see") }

    /// View routine
    static var planDayViewRoutine: String { String(localized: "plan.day.view_routine") }

    /// %lld ml of water with salts
    static func planDayWaterWithSalts(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.water_with_salts"), arg1)
    }

    /// What to bring to drink and eat
    static var planDayWhatToBring: String { String(localized: "plan.day.what_to_bring") }

    /// Very easy: you can chat effortlessly. Good for recovering.
    static var planDayZone1: String { String(localized: "plan.day.zone1") }

    /// Easy and comfortable: you can speak in full sentences. Builds endurance without overtiring you.
    static var planDayZone2: String { String(localized: "plan.day.zone2") }

    /// Moderate: you speak in short sentences. Improves the pace you can hold for a long time.
    static var planDayZone3: String { String(localized: "plan.day.zone3") }

    /// Hard: only a few words come out. Raises the pace you can hold before tiring.
    static var planDayZone4: String { String(localized: "plan.day.zone4") }

    /// All out: you can't talk. Short efforts to build speed.
    static var planDayZone5: String { String(localized: "plan.day.zone5") }

    /// Done
    static var planDone: String { String(localized: "plan.done") }

    /// Shows the plan for this goal
    static var planGoalHint: String { String(localized: "plan.goal.hint") }

    /// %1$@ of %2$@
    static func planKmOf(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "plan.km_of"), arg1, arg2)
    }

    /// No race date
    static var planNoRaceDate: String { String(localized: "plan.no_race_date") }

    /// Base
    static var planPhaseBase: String { String(localized: "plan.phase.base") }

    /// Build
    static var planPhaseBuild: String { String(localized: "plan.phase.build") }

    /// Peak
    static var planPhasePeak: String { String(localized: "plan.phase.peak") }

    /// Race
    static var planPhaseRace: String { String(localized: "plan.phase.race") }

    /// Taper
    static var planPhaseTaper: String { String(localized: "plan.phase.taper") }

    /// You are here
    static var planPhaseYouAreHere: String { String(localized: "plan.phase.you_are_here") }

    /// Your plan's phases
    static var planPhasesTitle: String { String(localized: "plan.phases.title") }

    /// %@ stage
    static func planStage(_ arg1: String) -> String {
        String(format: String(localized: "plan.stage"), arg1)
    }

    /// Lots of easy running so your body gets used to it.
    static var planStageBaseLine: String { String(localized: "plan.stage.base.line") }

    /// More kilometers and some pace work.
    static var planStageBuildLine: String { String(localized: "plan.stage.build.line") }

    /// The toughest weeks.
    static var planStagePeakLine: String { String(localized: "plan.stage.peak.line") }

    /// Race week: little and easy, to arrive with fresh legs.
    static var planStageRaceLine: String { String(localized: "plan.stage.race.line") }

    /// Less volume so you arrive rested.
    static var planStageTaperLine: String { String(localized: "plan.stage.taper.line") }

    /// %1$@ · week %2$lld of %3$lld
    static func planSubtitle(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "plan.subtitle"), arg1, arg2, arg3)
    }

    /// Your plan
    static var planTitle: String { String(localized: "plan.title") }

    /// TODAY
    static var planTodayBadge: String { String(localized: "plan.today_badge") }

    /// completed
    static var planWeekDone: String { String(localized: "plan.week.done") }

    /// %@ to go
    static func planWeekKmLeft(_ arg1: String) -> String {
        String(format: String(localized: "plan.week.km_left"), arg1)
    }

    /// Next week
    static var planWeekNext: String { String(localized: "plan.week.next") }

    /// Previous week
    static var planWeekPrevious: String { String(localized: "plan.week.previous") }

    /// Week %1$lld of %2$lld
    static func planWeekOf(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "plan.week_of"), arg1, arg2)
    }

    /// %lld years
    static func profileAgeYears(_ arg1: Int) -> String {
        String(format: String(localized: "profile.age_years"), arg1)
    }

    /// %lld days to go
    static func profileCountdownDays(_ arg1: Int) -> String {
        String(format: String(localized: "profile.countdown.days"), arg1)
    }

    /// 1 day to go
    static var profileCountdownOneDay: String { String(localized: "profile.countdown.one_day") }

    /// it's today
    static var profileCountdownToday: String { String(localized: "profile.countdown.today") }

    /// %lld weeks to go
    static func profileCountdownWeeks(_ arg1: Int) -> String {
        String(format: String(localized: "profile.countdown.weeks"), arg1)
    }

    /// Days and time
    static var profileDaysAndTime: String { String(localized: "profile.days_and_time") }

    /// Days and times
    static var profileDaysAndTimes: String { String(localized: "profile.days_and_times") }

    /// Goals
    static var profileGoals: String { String(localized: "profile.goals") }

    /// No active goals
    static var profileGoalsNoneActive: String { String(localized: "profile.goals.none_active") }

    /// Height
    static var profileHeight: String { String(localized: "profile.height") }

    /// Expired
    static var profileMedicalExpiredShort: String { String(localized: "profile.medical.expired_short") }

    /// Expires in %lld days
    static func profileMedicalExpiresIn(_ arg1: Int) -> String {
        String(format: String(localized: "profile.medical.expires_in"), arg1)
    }

    /// Expires today
    static var profileMedicalExpiresToday: String { String(localized: "profile.medical.expires_today") }

    /// Not uploaded
    static var profileMedicalNone: String { String(localized: "profile.medical.none") }

    /// Valid
    static var profileMedicalValid: String { String(localized: "profile.medical.valid") }

    /// No photo
    static var profileNoPhoto: String { String(localized: "profile.no_photo") }

    /// Settings
    static var profileViewSettings: String { String(localized: "profile.view_settings") }

    /// Weight
    static var profileWeight: String { String(localized: "profile.weight") }

    /// Your body
    static var profileYourBody: String { String(localized: "profile.your_body") }

    /// Close playback
    static var replayClose: String { String(localized: "replay.close") }

    /// KILOMETER
    static var replayHeaderKilometer: String { String(localized: "replay.header.kilometer") }

    /// PACE
    static var replayHeaderPace: String { String(localized: "replay.header.pace") }

    /// SPEED
    static var replayHeaderSpeed: String { String(localized: "replay.header.speed") }

    /// TIME
    static var replayHeaderTime: String { String(localized: "replay.header.time") }

    /// TOTAL TIME
    static var replayHeaderTotalTime: String { String(localized: "replay.header.total_time") }

    /// Restart playback
    static var replayRestart: String { String(localized: "replay.restart") }

    /// Speed %@
    static func replaySpeedAccessibility(_ arg1: String) -> String {
        String(format: String(localized: "replay.speed_accessibility"), arg1)
    }

    /// More options
    static var route3dMoreOptions: String { String(localized: "route3d.more_options") }

    /// Your session has expired. Please log in again to continue.
    static var sessionExpiredMessage: String { String(localized: "session.expired.message") }

    /// Session Expired
    static var sessionExpiredTitle: String { String(localized: "session.expired.title") }

    /// Account
    static var settingsAccount: String { String(localized: "settings.account") }

    /// Alerts
    static var settingsAlerts: String { String(localized: "settings.alerts") }

    /// Automatic
    static var settingsAppearanceAutomatic: String { String(localized: "settings.appearance.automatic") }

    /// Switches on its own, like your iPhone
    static var settingsAppearanceAutomaticDetail: String { String(localized: "settings.appearance.automatic.detail") }

    /// Color
    static var settingsAppearanceColor: String { String(localized: "settings.appearance.color") }

    /// Dark
    static var settingsAppearanceDark: String { String(localized: "settings.appearance.dark") }

    /// Black background, easier on the eyes
    static var settingsAppearanceDarkDetail: String { String(localized: "settings.appearance.dark.detail") }

    /// Light
    static var settingsAppearanceLight: String { String(localized: "settings.appearance.light") }

    /// Light background, easier to read in the sun
    static var settingsAppearanceLightDetail: String { String(localized: "settings.appearance.light.detail") }

    /// Appearance
    static var settingsAppearanceTitle: String { String(localized: "settings.appearance.title") }

    /// Blue
    static var settingsColorBlue: String { String(localized: "settings.color.blue") }

    /// Coral
    static var settingsColorCoral: String { String(localized: "settings.color.coral") }

    /// Custom
    static var settingsColorCustom: String { String(localized: "settings.color.custom") }

    /// Pick any color, then tap Use
    static var settingsColorCustomHint: String { String(localized: "settings.color.custom_hint") }

    /// Custom color
    static var settingsColorCustomTitle: String { String(localized: "settings.color.custom_title") }

    /// Cyan
    static var settingsColorCyan: String { String(localized: "settings.color.cyan") }

    /// Fuchsia
    static var settingsColorFuchsia: String { String(localized: "settings.color.fuchsia") }

    /// Lavender
    static var settingsColorLavender: String { String(localized: "settings.color.lavender") }

    /// Lime green
    static var settingsColorLime: String { String(localized: "settings.color.lime") }

    /// Low contrast
    static var settingsColorLowContrast: String { String(localized: "settings.color.low_contrast") }

    /// Mint
    static var settingsColorMint: String { String(localized: "settings.color.mint") }

    /// Orange
    static var settingsColorOrange: String { String(localized: "settings.color.orange") }

    /// Stamina Pink
    static var settingsColorPink: String { String(localized: "settings.color.pink") }

    /// In progress
    static var settingsColorPreviewInProgress: String { String(localized: "settings.color.preview.in_progress") }

    /// Your week
    static var settingsColorPreviewYourWeek: String { String(localized: "settings.color.preview.your_week") }

    /// Reset
    static var settingsColorReset: String { String(localized: "settings.color.reset") }

    /// Violet
    static var settingsColorViolet: String { String(localized: "settings.color.violet") }

    /// Yellow
    static var settingsColorYellow: String { String(localized: "settings.color.yellow") }

    /// Deactivate account
    static var settingsDeactivateAccount: String { String(localized: "settings.deactivate_account") }

    /// Deactivate
    static var settingsDeactivateAccountAlertConfirm: String { String(localized: "settings.deactivate_account.alert_confirm") }

    /// Your data stays saved. To come back, sign in.
    static var settingsDeactivateAccountAlertMessage: String { String(localized: "settings.deactivate_account.alert_message") }

    /// Deactivate your account?
    static var settingsDeactivateAccountAlertTitle: String { String(localized: "settings.deactivate_account.alert_title") }

    /// Delete account
    static var settingsDeleteAccount: String { String(localized: "settings.delete_account") }

    /// Delete
    static var settingsDeleteAccountAlertConfirm: String { String(localized: "settings.delete_account.alert_confirm") }

    /// You have 30 days to change your mind.
    static var settingsDeleteAccountAlertMessage: String { String(localized: "settings.delete_account.alert_message") }

    /// Delete your account?
    static var settingsDeleteAccountAlertTitle: String { String(localized: "settings.delete_account.alert_title") }

    /// Your account and all your data are deleted after 30 days. Until then you can recover it by signing in.
    static var settingsDeleteAccountBody: String { String(localized: "settings.delete_account.body") }

    /// Delete my account
    static var settingsDeleteAccountConfirmButton: String { String(localized: "settings.delete_account.confirm_button") }

    /// To confirm it's you, enter your password.
    static var settingsDeleteAccountPasswordHint: String { String(localized: "settings.delete_account.password_hint") }

    /// Your account signs in with Google or Apple, so no password is needed.
    static var settingsDeleteAccountSocialHint: String { String(localized: "settings.delete_account.social_hint") }

    /// Add goal
    static var settingsGoalsAdd: String { String(localized: "settings.goals.add") }

    /// Add event date
    static var settingsGoalsAddEventDate: String { String(localized: "settings.goals.add_event_date") }

    /// %lld active
    static func settingsGoalsCountActive(_ arg1: Int) -> String {
        String(format: String(localized: "settings.goals.count_active"), arg1)
    }

    /// Date
    static var settingsGoalsDate: String { String(localized: "settings.goals.date") }

    /// Main plan
    static var settingsGoalsMainPlan: String { String(localized: "settings.goals.main_plan") }

    /// No goals
    static var settingsGoalsNone: String { String(localized: "settings.goals.none") }

    /// Plan %lld
    static func settingsGoalsPlanNumber(_ arg1: Int) -> String {
        String(format: String(localized: "settings.goals.plan_number"), arg1)
    }

    /// Remove date
    static var settingsGoalsRemoveDate: String { String(localized: "settings.goals.remove_date") }

    /// The goals weren't saved
    static var settingsGoalsSaveFailed: String { String(localized: "settings.goals.save_failed") }

    /// Check your connection and try again.
    static var settingsGoalsSaveFailedMessage: String { String(localized: "settings.goals.save_failed.message") }

    /// Goals
    static var settingsGoalsTitle: String { String(localized: "settings.goals.title") }

    /// %lld on
    static func settingsNotificationsCountOn(_ arg1: Int) -> String {
        String(format: String(localized: "settings.notifications.count_on"), arg1)
    }

    /// Today's plan
    static var settingsNotificationsDailyPlan: String { String(localized: "settings.notifications.daily_plan") }

    /// On training days, first thing in the morning: what's on today and at what time.
    static var settingsNotificationsDailyPlanDetail: String { String(localized: "settings.notifications.daily_plan.detail") }

    /// Heat
    static var settingsNotificationsHeat: String { String(localized: "settings.notifications.heat") }

    /// If the forecast goes above 30 °C before your workout, we'll let you know in the morning.
    static var settingsNotificationsHeatDetail: String { String(localized: "settings.notifications.heat.detail") }

    /// Off
    static var settingsNotificationsOff: String { String(localized: "settings.notifications.off") }

    /// 1 on
    static var settingsNotificationsOneOn: String { String(localized: "settings.notifications.one_on") }

    /// Before each session, so you can get ready.
    static var settingsNotificationsPrepDetail: String { String(localized: "settings.notifications.prep.detail") }

    /// Notifications
    static var settingsNotificationsTitle: String { String(localized: "settings.notifications.title") }

    /// Date of birth
    static var settingsPersonalBirthdate: String { String(localized: "settings.personal.birthdate") }

    /// Email
    static var settingsPersonalEmail: String { String(localized: "settings.personal.email") }

    /// Feet
    static var settingsPersonalHeightFeet: String { String(localized: "settings.personal.height_feet") }

    /// Inches
    static var settingsPersonalHeightInches: String { String(localized: "settings.personal.height_inches") }

    /// Enter a height between 2′0″ and 8′6″.
    static var settingsPersonalHeightOutOfRangeFt: String { String(localized: "settings.personal.height_out_of_range_ft") }

    /// Enter your name.
    static var settingsPersonalNameRequired: String { String(localized: "settings.personal.name_required") }

    /// Sex
    static var settingsPersonalSex: String { String(localized: "settings.personal.sex") }

    /// Personal details
    static var settingsPersonalTitle: String { String(localized: "settings.personal.title") }

    /// Weight (lb)
    static var settingsPersonalWeightLabelLb: String { String(localized: "settings.personal.weight_label_lb") }

    /// Enter a weight between 45 and 880 lb.
    static var settingsPersonalWeightOutOfRangeLb: String { String(localized: "settings.personal.weight_out_of_range_lb") }

    /// Your changes won't be saved.
    static var settingsProfileDiscardMessage: String { String(localized: "settings.profile.discard_message") }

    /// Discard changes?
    static var settingsProfileDiscardTitle: String { String(localized: "settings.profile.discard_title") }

    /// Fix the highlighted fields to save
    static var settingsProfileFixToSave: String { String(localized: "settings.profile.fix_to_save") }

    /// Keep editing
    static var settingsProfileKeepEditing: String { String(localized: "settings.profile.keep_editing") }

    /// We couldn't load your details.
    static var settingsProfileLoadFailed: String { String(localized: "settings.profile.load_failed") }

    /// Saved
    static var settingsProfileSaved: String { String(localized: "settings.profile.saved") }

    /// Appearance
    static var settingsSectionAppearance: String { String(localized: "settings.section.appearance") }

    /// Help
    static var settingsSectionHelp: String { String(localized: "settings.section.help") }

    /// Preferences
    static var settingsSectionPreferences: String { String(localized: "settings.section.preferences") }

    /// Sign out
    static var settingsSignOut: String { String(localized: "settings.sign_out") }

    /// Are you sure you want to sign out?
    static var settingsSignOutAlertMessage: String { String(localized: "settings.sign_out.alert_message") }

    /// Sign out?
    static var settingsSignOutAlertTitle: String { String(localized: "settings.sign_out.alert_title") }

    /// Settings
    static var settingsTitle: String { String(localized: "settings.title") }

    /// Level
    static var settingsTrainingLevel: String { String(localized: "settings.training.level") }

    /// Sport
    static var settingsTrainingSport: String { String(localized: "settings.training.sport") }

    /// Training
    static var settingsTrainingTitle: String { String(localized: "settings.training.title") }

    /// Units
    static var settingsUnits: String { String(localized: "settings.units") }

    /// Changes only how things are shown: what's stored doesn't change.
    static var settingsUnitsDetail: String { String(localized: "settings.units.detail") }

    /// Kilometers
    static var settingsUnitsKilometers: String { String(localized: "settings.units.kilometers") }

    /// Miles
    static var settingsUnitsMiles: String { String(localized: "settings.units.miles") }

    /// Stamina %@ · beta
    static func settingsVersion(_ arg1: String) -> String {
        String(format: String(localized: "settings.version"), arg1)
    }

    /// View tour
    static var settingsViewTour: String { String(localized: "settings.view_tour") }

    /// Your account already exists
    static var signupAccountExistsTitle: String { String(localized: "signup.account_exists.title") }

    /// I understand that Stamina doesn't replace a professional and that, if something happens to me while I train, I
    static var signupBeforeAcceptHealth: String { String(localized: "signup.before.accept_health") }

    /// I accept the terms and conditions and the privacy policy.
    static var signupBeforeAcceptTerms: String { String(localized: "signup.before.accept_terms") }

    /// We're not doctors and the app doesn't replace a medical visit. If you have a condition or take medication, tal
    static var signupBeforeBody: String { String(localized: "signup.before.body") }

    /// Check both boxes to create your account.
    static var signupBeforeMustAccept: String { String(localized: "signup.before.must_accept") }

    /// Read terms, privacy and health
    static var signupBeforeReadLegal: String { String(localized: "signup.before.read_legal") }

    /// Before you start
    static var signupBeforeTitle: String { String(localized: "signup.before.title") }

    /// We use your age to work out your heart-rate zones and your hydration.
    static var signupBirthBody: String { String(localized: "signup.birth.body") }

    /// Hi %@!
    static func signupBirthGreeting(_ arg1: String) -> String {
        String(format: String(localized: "signup.birth.greeting"), arg1)
    }

    /// Choose your date of birth. You need to be 18 or older.
    static var signupBirthMustChoose: String { String(localized: "signup.birth.must_choose") }

    /// %@ When were you born?
    static func signupBirthTitle(_ arg1: String) -> String {
        String(format: String(localized: "signup.birth.title"), arg1)
    }

    /// We use your weight to work out fluids, sodium and carbs. You can change it anytime.
    static var signupBodyBody: String { String(localized: "signup.body.body") }

    /// Height (cm)
    static var signupBodyHeightLabel: String { String(localized: "signup.body.height_label") }

    /// Enter a height between 50 and 260 cm.
    static var signupBodyHeightOutOfRange: String { String(localized: "signup.body.height_out_of_range") }

    /// 178
    static var signupBodyHeightPlaceholder: String { String(localized: "signup.body.height_placeholder") }

    /// Your weight and height
    static var signupBodyTitle: String { String(localized: "signup.body.title") }

    /// Weight (kg)
    static var signupBodyWeightLabel: String { String(localized: "signup.body.weight_label") }

    /// Enter a weight between 20 and 400 kg.
    static var signupBodyWeightOutOfRange: String { String(localized: "signup.body.weight_out_of_range") }

    /// 72
    static var signupBodyWeightPlaceholder: String { String(localized: "signup.body.weight_placeholder") }

    /// We sent a 6-character code to %@. It expires in 15 minutes.
    static func signupCodeBody(_ arg1: String) -> String {
        String(format: String(localized: "signup.code.body"), arg1)
    }

    /// Verify your email
    static var signupCodeTitle: String { String(localized: "signup.code.title") }

    /// Verify
    static var signupCodeVerify: String { String(localized: "signup.code.verify") }

    /// Finish later
    static var signupCompleteLater: String { String(localized: "signup.complete_later") }

    /// We'll remind you before each session so you can get ready.
    static var signupDaysBody: String { String(localized: "signup.days.body") }

    /// Pick at least one day to switch the alerts on.
    static var signupDaysNoDays: String { String(localized: "signup.days.no_days") }

    /// Time on %@
    static func signupDaysTimeOf(_ arg1: String) -> String {
        String(format: String(localized: "signup.days.time_of"), arg1)
    }

    /// Which days and at what time do you train?
    static var signupDaysTitle: String { String(localized: "signup.days.title") }

    /// Fill in your details and choose a password.
    static var signupEmailBody: String { String(localized: "signup.email.body") }

    /// Send me the code
    static var signupEmailSend: String { String(localized: "signup.email.send") }

    /// Create your account
    static var signupEmailTitle: String { String(localized: "signup.email.title") }

    /// We couldn't continue your sign-up
    static var signupErrorTitle: String { String(localized: "signup.error.title") }

    /// With the race date we build your plan and the countdown.
    static var signupGoalBody: String { String(localized: "signup.goal.body") }

    /// 10 km
    static var signupGoalC10k: String { String(localized: "signup.goal.c10k") }

    /// 5 km
    static var signupGoalC5k: String { String(localized: "signup.goal.c5k") }

    /// Choose your goal
    static var signupGoalChoose: String { String(localized: "signup.goal.choose") }

    /// Half marathon
    static var signupGoalHalfMarathon: String { String(localized: "signup.goal.half_marathon") }

    /// 21.1 km
    static var signupGoalHalfMarathonDetail: String { String(localized: "signup.goal.half_marathon.detail") }

    /// Get back to training without injuries
    static var signupGoalInjuryFree: String { String(localized: "signup.goal.injury_free") }

    /// Marathon
    static var signupGoalMarathon: String { String(localized: "signup.goal.marathon") }

    /// 42.2 km
    static var signupGoalMarathonDetail: String { String(localized: "signup.goal.marathon.detail") }

    /// Mountain trail
    static var signupGoalMountainTrail: String { String(localized: "signup.goal.mountain_trail") }

    /// 25-50 km
    static var signupGoalMountainTrailDetail: String { String(localized: "signup.goal.mountain_trail.detail") }

    /// You can choose several. The first one will be your main plan.
    static var signupGoalMultipleHint: String { String(localized: "signup.goal.multiple_hint") }

    /// Choose the race date to continue.
    static var signupGoalMustChooseDate: String { String(localized: "signup.goal.must_choose_date") }

    /// Next month
    static var signupGoalNextMonth: String { String(localized: "signup.goal.next_month") }

    /// Olympic triathlon
    static var signupGoalOlympicTriathlon: String { String(localized: "signup.goal.olympic_triathlon") }

    /// 1.5 / 40 / 10 km
    static var signupGoalOlympicTriathlonDetail: String { String(localized: "signup.goal.olympic_triathlon.detail") }

    /// Previous month
    static var signupGoalPreviousMonth: String { String(localized: "signup.goal.previous_month") }

    /// What are you training for?
    static var signupGoalTitle: String { String(localized: "signup.goal.title") }

    /// %@ · %lld weeks to go
    static func signupGoalWithDate(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "signup.goal.with_date"), arg1, arg2)
    }

    /// Stop and get checked if you feel
    static var signupHealthStopAndConsult: String { String(localized: "signup.health.stop_and_consult") }

    /// Chest pain or tightness
    static var signupHealthSymptom1: String { String(localized: "signup.health.symptom1") }

    /// Severe breathlessness or dizziness
    static var signupHealthSymptom2: String { String(localized: "signup.health.symptom2") }

    /// Joint pain that gets worse as you run
    static var signupHealthSymptom3: String { String(localized: "signup.health.symptom3") }

    /// Surname (optional)
    static var signupLastNameLabel: String { String(localized: "signup.last_name.label") }

    /// Morgan
    static var signupLastNamePlaceholder: String { String(localized: "signup.last_name.placeholder") }

    /// Advanced
    static var signupLevelAdvanced: String { String(localized: "signup.level.advanced") }

    /// More than 3 years, with races on the calendar
    static var signupLevelAdvancedDetail: String { String(localized: "signup.level.advanced.detail") }

    /// Beginner
    static var signupLevelBeginner: String { String(localized: "signup.level.beginner") }

    /// Less than a year training, or coming back after a break
    static var signupLevelBeginnerDetail: String { String(localized: "signup.level.beginner.detail") }

    /// It sets where your plan starts. If you're coming back after a break, choose beginner.
    static var signupLevelBody: String { String(localized: "signup.level.body") }

    /// Intermediate
    static var signupLevelIntermediate: String { String(localized: "signup.level.intermediate") }

    /// 1 to 3 years training regularly
    static var signupLevelIntermediateDetail: String { String(localized: "signup.level.intermediate.detail") }

    /// How long have you been training?
    static var signupLevelTitle: String { String(localized: "signup.level.title") }

    /// Upload it now or later from your profile. With a valid one we give you tips during races.
    static var signupMedicalBody: String { String(localized: "signup.medical.body") }

    /// I'll upload it later
    static var signupMedicalLater: String { String(localized: "signup.medical.later") }

    /// First name
    static var signupNameLabel: String { String(localized: "signup.name.label") }

    /// Alex
    static var signupNamePlaceholder: String { String(localized: "signup.name.placeholder") }

    /// We only use it to calculate your plan. It isn't shown or shared.
    static var signupSexBody: String { String(localized: "signup.sex.body") }

    /// Female
    static var signupSexFemale: String { String(localized: "signup.sex.female") }

    /// Male
    static var signupSexMale: String { String(localized: "signup.sex.male") }

    /// What's your biological sex?
    static var signupSexTitle: String { String(localized: "signup.sex.title") }

    /// I'd rather not say
    static var signupSexUndisclosed: String { String(localized: "signup.sex.undisclosed") }

    /// Continue with %@ again.
    static func signupSocialExpired(_ arg1: String) -> String {
        String(format: String(localized: "signup.social_expired"), arg1)
    }

    /// Continue with %@ again
    static func signupSocialRetry(_ arg1: String) -> String {
        String(format: String(localized: "signup.social_retry"), arg1)
    }

    /// Check that your name and email are right: we brought them from your %@ account.
    static func signupSocialReview(_ arg1: String) -> String {
        String(format: String(localized: "signup.social_review"), arg1)
    }

    /// Each discipline burns fluid and carbohydrate differently: on a bike you can drink more and eat solid food; run
    static var signupSportBody: String { String(localized: "signup.sport.body") }

    /// Cycling
    static var signupSportCycling: String { String(localized: "signup.sport.cycling") }

    /// Road, gravel or MTB
    static var signupSportCyclingDetail: String { String(localized: "signup.sport.cycling.detail") }

    /// Running
    static var signupSportRunning: String { String(localized: "signup.sport.running") }

    /// Road, track or trail
    static var signupSportRunningDetail: String { String(localized: "signup.sport.running.detail") }

    /// For now, Stamina is just for running.
    static var signupSportRunningOnly: String { String(localized: "signup.sport.running_only") }

    /// What's your main sport?
    static var signupSportTitle: String { String(localized: "signup.sport.title") }

    /// Hiking
    static var signupSportTrekking: String { String(localized: "signup.sport.trekking") }

    /// Mountains and long crossings
    static var signupSportTrekkingDetail: String { String(localized: "signup.sport.trekking.detail") }

    /// Triathlon
    static var signupSportTriathlon: String { String(localized: "signup.sport.triathlon") }

    /// Swim, bike and run
    static var signupSportTriathlonDetail: String { String(localized: "signup.sport.triathlon.detail") }

    /// Other
    static var sportOther: String { String(localized: "sport.other") }

    /// Strength
    static var sportStrength: String { String(localized: "sport.strength") }

    /// Swimming
    static var sportSwimming: String { String(localized: "sport.swimming") }

    /// Triathlon
    static var sportTriathlon: String { String(localized: "sport.triathlon") }

    /// %1$@: %2$lld %3$@
    static func streakAccessibility(_ arg1: String, _ arg2: Int, _ arg3: String) -> String {
        String(format: String(localized: "streak.accessibility"), arg1, arg2, arg3)
    }

    /// days
    static var streakDays: String { String(localized: "streak.days") }

    /// Streak flame is active! You completed today's workout.
    static var streakDetailActive: String { String(localized: "streak.detail.active") }

    /// No active streak. Complete your next scheduled workout to ignite the flame!
    static var streakDetailLost: String { String(localized: "streak.detail.lost") }

    /// You have a workout scheduled today. Complete it to keep the flame!
    static var streakDetailPending: String { String(localized: "streak.detail.pending") }

    /// Today is a rest day. Your streak is safe without working out.
    static var streakDetailRest: String { String(localized: "streak.detail.rest") }

    /// Your streak only counts days you are scheduled to train. If you miss a scheduled training day, the little flam
    static var streakExplanation: String { String(localized: "streak.explanation") }

    /// Workout streak
    static var streakTitle: String { String(localized: "streak.title") }

    /// You made it!
    static var summaryArrived: String { String(localized: "summary.arrived") }

    /// Avg HR
    static var summaryAvgHeartRate: String { String(localized: "summary.avg_heart_rate") }

    /// Best pace
    static var summaryBestPace: String { String(localized: "summary.best_pace") }

    /// Calories
    static var summaryCalories: String { String(localized: "summary.calories") }

    /// Fastest split
    static var summaryFastestSplit: String { String(localized: "summary.fastest_split") }

    /// Max HR
    static var summaryMaxHeartRate: String { String(localized: "summary.max_heart_rate") }

    /// Max speed
    static var summaryMaxSpeed: String { String(localized: "summary.max_speed") }

    /// Moving time
    static var summaryMovingTime: String { String(localized: "summary.moving_time") }

    /// Pause %1$lld: %2$@
    static func summaryPauseNumber(_ arg1: Int, _ arg2: String) -> String {
        String(format: String(localized: "summary.pause_number"), arg1, arg2)
    }

    /// Pause: %1$@ · Resumed: %2$@
    static func summaryPauseResume(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "summary.pause_resume"), arg1, arg2)
    }

    /// per km
    static var summaryPerKm: String { String(localized: "summary.per_km") }

    /// Replay route
    static var summaryReplayRoute: String { String(localized: "summary.replay_route") }

    /// Done
    static var summarySaveAndClose: String { String(localized: "summary.save_and_close") }

    /// Segments, pauses and resumes
    static var summarySegmentsPauses: String { String(localized: "summary.segments_pauses") }

    /// Km %lld
    static func summarySplitKmNumber(_ arg1: Int) -> String {
        String(format: String(localized: "summary.split.km_number"), arg1)
    }

    /// Split %lld
    static func summarySplitSegmentNumber(_ arg1: Int) -> String {
        String(format: String(localized: "summary.split.segment_number"), arg1)
    }

    /// Splits
    static var summarySplits: String { String(localized: "summary.splits") }

    /// You kept your flame streak burning!
    static var summaryStreakKept: String { String(localized: "summary.streak_kept") }

    /// Total time
    static var summaryTotalDuration: String { String(localized: "summary.total_duration") }

    /// Closes the tour and goes to Home
    static var tourCloseHint: String { String(localized: "tour.close.hint") }

    /// All set! Tap %@ whenever you want to go for a run.
    static func tourCoachDoneBubble(_ arg1: String) -> String {
        String(format: String(localized: "tour.coach.done.bubble"), arg1)
    }

    /// Your training week, day by day.
    static var tourCoachPlanBubble: String { String(localized: "tour.coach.plan.bubble") }

    /// Start a workout with %@: GPS, pace and pause.
    static func tourCoachWorkoutBubble(_ arg1: String) -> String {
        String(format: String(localized: "tour.coach.workout.bubble"), arg1)
    }

    /// Every workout stays here, with your numbers.
    static var tourPageHistoryBubble: String { String(localized: "tour.page.history.bubble") }

    /// Hi! Here you'll see what's on for today.
    static var tourPageHomeBubble: String { String(localized: "tour.page.home.bubble") }

    /// Your info, your goals and the app color.
    static var tourPageProfileBubble: String { String(localized: "tour.page.profile.bubble") }

    /// Page %lld of %lld
    static func tourPageOf(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "tour.page_of"), arg1, arg2)
    }

    /// Not now
    static var versionNotNow: String { String(localized: "version.not_now") }

    /// You can keep using this one, but it's worth updating.
    static var versionRecommendedBody: String { String(localized: "version.recommended.body") }

    /// There's a new version of Stamina
    static var versionRecommendedTitle: String { String(localized: "version.recommended.title") }

    /// This version can no longer talk to the server. Update from the App Store to carry on.
    static var versionRequiredBody: String { String(localized: "version.required.body") }

    /// Stamina needs an update
    static var versionRequiredTitle: String { String(localized: "version.required.title") }

    /// Update
    static var versionUpdate: String { String(localized: "version.update") }

    /// Weather: Apple Weather. Data sources
    static var weatherAttributionAccessibility: String { String(localized: "weather.attribution.accessibility") }

    /// Data sources
    static var weatherAttributionSources: String { String(localized: "weather.attribution.sources") }

    /// Fri
    static var weekdayShortFri: String { String(localized: "weekday.short.fri") }

    /// Mon
    static var weekdayShortMon: String { String(localized: "weekday.short.mon") }

    /// Sat
    static var weekdayShortSat: String { String(localized: "weekday.short.sat") }

    /// Sun
    static var weekdayShortSun: String { String(localized: "weekday.short.sun") }

    /// Thu
    static var weekdayShortThu: String { String(localized: "weekday.short.thu") }

    /// Tue
    static var weekdayShortTue: String { String(localized: "weekday.short.tue") }

    /// Wed
    static var weekdayShortWed: String { String(localized: "weekday.short.wed") }

    /// Create a free account
    static var welcomeCreateAccount: String { String(localized: "welcome.create_account") }

    /// Show photo %lld of %lld
    static func welcomeGoToPhoto(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "welcome.go_to_photo"), arg1, arg2)
    }

    /// I already have an account
    static var welcomeHaveAccount: String { String(localized: "welcome.have_account") }

    /// Runners at sunrise
    static var welcomeSlide1Photo: String { String(localized: "welcome.slide1.photo") }

    /// Built around your free days and your goal, and adjusted week by week.
    static var welcomeSlide1Text: String { String(localized: "welcome.slide1.text") }

    /// Your running plan, at your pace
    static var welcomeSlide1Title: String { String(localized: "welcome.slide1.title") }

    /// Peloton on the road
    static var welcomeSlide2Photo: String { String(localized: "welcome.slide2.photo") }

    /// Pace, distance and route from your iPhone or Apple Watch.
    static var welcomeSlide2Text: String { String(localized: "welcome.slide2.text") }

    /// Run with everything tracked
    static var welcomeSlide2Title: String { String(localized: "welcome.slide2.title") }

    /// Mountain trail
    static var welcomeSlide3Photo: String { String(localized: "welcome.slide3.photo") }

    /// Hydration, heat alerts and a countdown to your 10K, half or marathon.
    static var welcomeSlide3Text: String { String(localized: "welcome.slide3.text") }

    /// Show up strong on race day
    static var welcomeSlide3Title: String { String(localized: "welcome.slide3.title") }

    /// Close the plan
    static var workoutClosePlan: String { String(localized: "workout.close_plan") }

    /// Duration
    static var workoutDuration: String { String(localized: "workout.duration") }

    /// Finish
    static var workoutFinish: String { String(localized: "workout.finish") }

    /// End the workout?
    static var workoutFinishConfirm: String { String(localized: "workout.finish.confirm") }

    /// Fueling
    static var workoutFueling: String { String(localized: "workout.fueling") }

    /// No GPS
    static var workoutGpsNone: String { String(localized: "workout.gps.none") }

    /// GPS OK
    static var workoutGpsOk: String { String(localized: "workout.gps.ok") }

    /// Recording GPS
    static var workoutGpsRecording: String { String(localized: "workout.gps.recording") }

    /// Finding GPS
    static var workoutGpsSearching: String { String(localized: "workout.gps.searching") }

    /// Workout in progress
    static var workoutInProgress: String { String(localized: "workout.in_progress") }

    /// in progress
    static var workoutInProgressLowercase: String { String(localized: "workout.in_progress_lowercase") }

    /// Center
    static var workoutMapCenter: String { String(localized: "workout.map.center") }

    /// Center on my location
    static var workoutMapCenterOnMe: String { String(localized: "workout.map.center_on_me") }

    /// Satellite view
    static var workoutMapSatellite: String { String(localized: "workout.map.satellite") }

    /// 3D view
    static var workoutMapView3d: String { String(localized: "workout.map.view_3d") }

    /// The workout did not record enough movement or lasted less than 10 seconds. Do you want to discard or resume it
    static var workoutNoMovementMessage: String { String(localized: "workout.no_movement.message") }

    /// No movement
    static var workoutNoMovementTitle: String { String(localized: "workout.no_movement.title") }

    /// Opens today's plan
    static var workoutOpensTodayPlan: String { String(localized: "workout.opens_today_plan") }

    /// Pause
    static var workoutPause: String { String(localized: "workout.pause") }

    /// Paused
    static var workoutPaused: String { String(localized: "workout.paused") }

    /// Not now
    static var workoutPermissionCancel: String { String(localized: "workout.permission.cancel") }

    /// Continue
    static var workoutPermissionContinue: String { String(localized: "workout.permission.continue") }

    /// When you start a workout, Stamina uses your location to draw the route and measure distance and pace, includin
    static var workoutPermissionDetail: String { String(localized: "workout.permission.detail") }

    /// Record your route
    static var workoutPermissionTitle: String { String(localized: "workout.permission.title") }

    /// Ready to start
    static var workoutReadyToStart: String { String(localized: "workout.ready_to_start") }

    /// Recording on the watch
    static var workoutRecordingOnWatch: String { String(localized: "workout.recording_on_watch") }

    /// Routes
    static var workoutRoutes: String { String(localized: "workout.routes") }

    /// Sport
    static var workoutSport: String { String(localized: "workout.sport") }

    /// Start
    static var workoutStart: String { String(localized: "workout.start") }

    /// Session structure
    static var workoutStructure: String { String(localized: "workout.structure") }

    /// Target
    static var workoutTarget: String { String(localized: "workout.target") }

    /// Today's plan
    static var workoutTodayPlan: String { String(localized: "workout.today_plan") }

    /// Watch connected
    static var workoutWatchConnected: String { String(localized: "workout.watch_connected") }

    /// Zone %lld
    static func zoneAccessibility(_ arg1: Int) -> String {
        String(format: String(localized: "zone.accessibility"), arg1)
    }

    /// very easy
    static var zoneFeel1: String { String(localized: "zone.feel.1") }

    /// easy
    static var zoneFeel2: String { String(localized: "zone.feel.2") }

    /// moderate
    static var zoneFeel3: String { String(localized: "zone.feel.3") }

    /// hard
    static var zoneFeel4: String { String(localized: "zone.feel.4") }

    /// all out
    static var zoneFeel5: String { String(localized: "zone.feel.5") }

    /// Zone %1$lld · %2$@
    static func zonePill(_ arg1: Int, _ arg2: String) -> String {
        String(format: String(localized: "zone.pill"), arg1, arg2)
    }

    /// zone %1$lld, %2$@
    static func zoneWords(_ arg1: Int, _ arg2: String) -> String {
        String(format: String(localized: "zone.words"), arg1, arg2)
    }
}
