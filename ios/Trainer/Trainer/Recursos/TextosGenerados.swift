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
// 886 claves · idioma de autoría: en
// =============================================================================

import Foundation

/// Los textos. Una propiedad por clave del catálogo: un typo en una
/// clave deja de ser un bug de producción y pasa a ser un error de compilación.
enum Textos {

    /// Gym · upper body and core
    static var agendaGym: String { String(localized: "agenda.gym") }

    /// %lld exercises · 45 min · tap to see the routine
    static func agendaGymDetail(_ arg1: Int) -> String {
        String(format: String(localized: "agenda.gym.detail"), arg1)
    }

    /// Prepare bottles and gels
    static var agendaPrepare: String { String(localized: "agenda.prepare") }

    /// %1$@ with electrolytes · %2$lld gels · alert %3$lld min before
    static func agendaPrepareDetail(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "agenda.prepare.detail"), arg1, arg2, arg3)
    }

    /// Recovery
    static var agendaRecovery: String { String(localized: "agenda.recovery") }

    /// %1$lld g protein + %2$lld g carbs within 45 min
    static func agendaRecoveryDetail(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "agenda.recovery.detail"), arg1, arg2)
    }

    /// Pre-workout snack
    static var agendaSnack: String { String(localized: "agenda.snack") }

    /// %lld g carbs · banana + oats
    static func agendaSnackDetail(_ arg1: Int) -> String {
        String(format: String(localized: "agenda.snack.detail"), arg1)
    }

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
    static var commonAll: String { String(localized: "common.all") }

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

    /// Change email
    static var commonChangeEmail: String { String(localized: "common.change_email") }

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

    /// Got it
    static var commonGotIt: String { String(localized: "common.got_it") }

    /// Keep going
    static var commonKeepGoing: String { String(localized: "common.keep_going") }

    /// Less
    static var commonLess: String { String(localized: "common.less") }

    /// Month
    static var commonMonth: String { String(localized: "common.month") }

    /// More
    static var commonMore: String { String(localized: "common.more") }

    /// Next
    static var commonNext: String { String(localized: "common.next") }

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

    /// Registration progress
    static var commonSignupProgress: String { String(localized: "common.signup_progress") }

    /// Skip
    static var commonSkip: String { String(localized: "common.skip") }

    /// Speed
    static var commonSpeed: String { String(localized: "common.speed") }

    /// Start
    static var commonStart: String { String(localized: "common.start") }

    /// Steps
    static var commonSteps: String { String(localized: "common.steps") }

    /// steps
    static var commonStepsLowercase: String { String(localized: "common.steps_lowercase") }

    /// Time
    static var commonTime: String { String(localized: "common.time") }

    /// Remaining
    static var commonToGo: String { String(localized: "common.to_go") }

    /// to go
    static var commonToGoLowercase: String { String(localized: "common.to_go_lowercase") }

    /// Today
    static var commonToday: String { String(localized: "common.today") }

    /// today
    static var commonTodayLowercase: String { String(localized: "common.today_lowercase") }

    /// Use
    static var commonUse: String { String(localized: "common.use") }

    /// Week
    static var commonWeek: String { String(localized: "common.week") }

    /// weeks
    static var commonWeeks: String { String(localized: "common.weeks") }

    /// Yesterday
    static var commonYesterday: String { String(localized: "common.yesterday") }

    /// That request isn't the shape the server expects. That's a bug, not you.
    static var errorBadRequest: String { String(localized: "error.bad_request") }

    /// More than 15 minutes went by or there were too many attempts. Ask for a new one with “Resend”.
    static var errorCodeExpired: String { String(localized: "error.code_expired") }

    /// The code expired
    static var errorCodeExpiredTitle: String { String(localized: "error.code_expired.title") }

    /// We just sent one. Wait a moment before asking for another.
    static var errorCodeResendTooSoon: String { String(localized: "error.code_resend_too_soon") }

    /// Wait a moment
    static var errorCodeResendTooSoonTitle: String { String(localized: "error.code_resend_too_soon.title") }

    /// The previous save is still going through. Try again in a moment.
    static var errorConflict: String { String(localized: "error.conflict") }

    /// That email is already registered. Sign in with your password, or reset it if you forgot it.
    static var errorEmailAlreadyRegistered: String { String(localized: "error.email_already_registered") }

    /// You already have an account
    static var errorEmailAlreadyRegisteredTitle: String { String(localized: "error.email_already_registered.title") }

    /// Something broke on the server. Not your fault.
    static var errorInternal: String { String(localized: "error.internal") }

    /// Check the code we emailed you: it has 6 letters and numbers.
    static var errorInvalidCode: String { String(localized: "error.invalid_code") }

    /// The code isn't correct
    static var errorInvalidCodeTitle: String { String(localized: "error.invalid_code.title") }

    /// That email and password don't match.
    static var errorInvalidCredentials: String { String(localized: "error.invalid_credentials") }

    /// We couldn't verify your account
    static var errorInvalidProviderTokenTitle: String { String(localized: "error.invalid_provider_token.title") }

    /// Your session expired. Sign in again.
    static var errorInvalidRefreshToken: String { String(localized: "error.invalid_refresh_token") }

    /// The sign-up expired. Start again from the email.
    static var errorInvalidRegistrationToken: String { String(localized: "error.invalid_registration_token") }

    /// The password reset expired. Start again from your email.
    static var errorInvalidResetToken: String { String(localized: "error.invalid_reset_token") }

    /// You have to accept the health notice to create an account.
    static var errorLegalNotAccepted: String { String(localized: "error.legal_not_accepted") }

    /// The notice changed while you were signing up. Please read it again.
    static var errorLegalVersionStale: String { String(localized: "error.legal_version_stale") }

    /// That address doesn't exist on the server.
    static var errorNotFound: String { String(localized: "error.not_found") }

    /// No connection. What you typed is saved — try again when it's back.
    static var errorOffline: String { String(localized: "error.offline") }

    /// No connection
    static var errorOfflineTitle: String { String(localized: "error.offline.title") }

    /// You created it with Google or Apple, so it has no password. Use that button, or set a password from “Forgot yo
    static var errorPasswordNotSet: String { String(localized: "error.password_not_set") }

    /// This account signs in with Google or Apple
    static var errorPasswordNotSetTitle: String { String(localized: "error.password_not_set.title") }

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

    /// Your session expired. Sign in again.
    static var errorUnauthorized: String { String(localized: "error.unauthorized") }

    /// The server replied something unexpected. That's a bug, not you.
    static var errorUnexpectedResponse: String { String(localized: "error.unexpected_response") }

    /// It didn't work. The server replied “%@”.
    static func errorUnknownCode(_ arg1: String) -> String {
        String(format: String(localized: "error.unknown_code"), arg1)
    }

    /// There is no account with that email. Check the spelling or create a new account.
    static var errorUserNotFound: String { String(localized: "error.user_not_found") }

    /// That account doesn't exist
    static var errorUserNotFoundTitle: String { String(localized: "error.user_not_found.title") }

    /// That password is easy to guess. Try a longer or less common one.
    static var errorWeakPassword: String { String(localized: "error.weak_password") }

    /// That password is too easy
    static var errorWeakPasswordTitle: String { String(localized: "error.weak_password.title") }

    /// That's not the password for this account. Try again or tap “Forgot your password?”.
    static var errorWrongPassword: String { String(localized: "error.wrong_password") }

    /// The password doesn't match
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

    /// That email is already in use. Sign in with it or reset the password.
    static var fieldEmailInUse: String { String(localized: "field.email.in_use") }

    /// There's no account with that email.
    static var fieldEmailNotFound: String { String(localized: "field.email.not_found") }

    /// Enter your first name.
    static var fieldNameRequired: String { String(localized: "field.name.required") }

    /// The passwords don't match.
    static var fieldPasswordNoMatch: String { String(localized: "field.password.no_match") }

    /// This account signs in with Google or Apple. Use that button or set a password from “Forgot your password?”.
    static var fieldPasswordNotSet: String { String(localized: "field.password.not_set") }

    /// The password doesn't meet the requirements above.
    static var fieldPasswordRulesUnmet: String { String(localized: "field.password.rules_unmet") }

    /// It's easy to guess. Try a longer or less common one.
    static var fieldPasswordWeak: String { String(localized: "field.password.weak") }

    /// The password is incorrect.
    static var fieldPasswordWrong: String { String(localized: "field.password.wrong") }

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

    /// Thu Aug 28 · upper body and core
    static var gymSubtitle: String { String(localized: "gym.subtitle") }

    /// All your workouts
    static var historyAllWorkouts: String { String(localized: "history.all_workouts") }

    /// Close
    static var historyClose: String { String(localized: "history.close") }

    /// Tap ⚡ to start your first one. When you finish, it shows up here with its map, splits and pauses.
    static var historyEmptyBody: String { String(localized: "history.empty.body") }

    /// Start my first workout
    static var historyEmptyStartFirst: String { String(localized: "history.empty.start_first") }

    /// No workouts yet
    static var historyEmptyTitle: String { String(localized: "history.empty.title") }

    /// Could not load your activities. Try again.
    static var historyError: String { String(localized: "history.error") }

    /// Load more
    static var historyLoadMore: String { String(localized: "history.load_more") }

    /// Loading…
    static var historyLoading: String { String(localized: "history.loading") }

    /// This activity has no saved GPS route.
    static var historyNoRoute: String { String(localized: "history.no_route") }

    /// Opens your past workouts
    static var historyOpensPastWorkouts: String { String(localized: "history.opens_past_workouts") }

    /// Since the 1st of this month
    static var historyPeriodMonthDetail: String { String(localized: "history.period.month_detail") }

    /// From Monday to today
    static var historyPeriodWeekDetail: String { String(localized: "history.period.week_detail") }

    /// Opens this workout's map, splits and pauses
    static var historyRowHint: String { String(localized: "history.row.hint") }

    /// Watch
    static var historySourceWatch: String { String(localized: "history.source.watch") }

    /// Everything you've trained
    static var historySubtitle: String { String(localized: "history.subtitle") }

    /// History
    static var historyTab: String { String(localized: "history.tab") }

    /// tap one to see the details
    static var historyTapOneForDetail: String { String(localized: "history.tap_one_for_detail") }

    /// My activities
    static var historyTitle: String { String(localized: "history.title") }

    /// %@. Includes what's loaded so far: tap “Load more” below to add earlier ones.
    static func historyTotalsPartialNote(_ arg1: String) -> String {
        String(format: String(localized: "history.totals.partial_note"), arg1)
    }

    /// View details
    static var historyViewDetail: String { String(localized: "history.view_detail") }

    /// Workouts
    static var historyWorkouts: String { String(localized: "history.workouts") }

    /// %lld workouts
    static func historyWorkoutsCount(_ arg1: Int) -> String {
        String(format: String(localized: "history.workouts_count"), arg1)
    }

    /// 1 workout
    static var historyWorkoutsOne: String { String(localized: "history.workouts_one") }

    /// Your numbers
    static var historyYourNumbers: String { String(localized: "history.your_numbers") }

    /// Your workouts
    static var historyYourWorkouts: String { String(localized: "history.your_workouts") }

    /// Choose goal
    static var homeChooseGoal: String { String(localized: "home.choose_goal") }

    /// Choose your next race and we'll build your plan week by week.
    static var homeChooseNextRace: String { String(localized: "home.choose_next_race") }

    /// Nothing to show here yet.
    static var homeDataEmpty: String { String(localized: "home.data.empty") }

    /// We couldn't get this from the server. Try again in a while.
    static var homeDataError: String { String(localized: "home.data.error") }

    /// Getting the latest…
    static var homeDataLoading: String { String(localized: "home.data.loading") }

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

    /// When you're back
    static var homeExplainerAfter: String { String(localized: "home.explainer.after") }

    /// Before you go
    static var homeExplainerBefore: String { String(localized: "home.explainer.before") }

    /// Carbs
    static var homeExplainerCarbs: String { String(localized: "home.explainer.carbs") }

    /// Carbs and protein to recover.
    static var homeExplainerCarbsAfter: String { String(localized: "home.explainer.carbs_after") }

    /// Carbs in your pre-workout meal, so you head out with energy.
    static var homeExplainerCarbsBefore: String { String(localized: "home.explainer.carbs_before") }

    /// The energy your body uses fastest. It's what to add every hour, from gels, a sports drink or something solid.
    static var homeExplainerCarbsBody: String { String(localized: "home.explainer.carbs_body") }

    /// What to drink and eat on this workout, based on your weight and today's session.
    static var homeExplainerFuelingBody: String { String(localized: "home.explainer.fueling_body") }

    /// Gels
    static var homeExplainerGels: String { String(localized: "home.explainer.gels") }

    /// Packets of fast carbs. Take them with water, spread out over the workout.
    static var homeExplainerGelsBody: String { String(localized: "home.explainer.gels_body") }

    /// Not needed today: water is enough.
    static var homeExplainerNotNeededToday: String { String(localized: "home.explainer.not_needed_today") }

    /// Sodium
    static var homeExplainerSodium: String { String(localized: "home.explainer.sodium") }

    /// The salts you lose when you sweat. Get them from an electrolyte drink or salt tablets.
    static var homeExplainerSodiumBody: String { String(localized: "home.explainer.sodium_body") }

    /// Water
    static var homeExplainerWater: String { String(localized: "home.explainer.water") }

    /// How much to drink each hour: small, frequent sips are better than all at once.
    static var homeExplainerWaterBody: String { String(localized: "home.explainer.water_body") }

    /// What to bring today
    static var homeExplainerWhatToBringToday: String { String(localized: "home.explainer.what_to_bring_today") }

    /// For the whole workout: %@.
    static func homeExplainerWholeWorkout(_ arg1: String) -> String {
        String(format: String(localized: "home.explainer.whole_workout"), arg1)
    }

    /// %lld-min workout
    static func homeExplainerWorkoutMinutes(_ arg1: Int) -> String {
        String(format: String(localized: "home.explainer.workout_minutes"), arg1)
    }

    /// Very easy. You could chat nonstop. Good for recovery.
    static var homeExplainerZone1: String { String(localized: "home.explainer.zone1") }

    /// Comfortable. You can speak in full sentences. It builds your base and it's the one you'll use most.
    static var homeExplainerZone2: String { String(localized: "home.explainer.zone2") }

    /// Hard but sustainable. Only short sentences come out. Sharpens your race pace.
    static var homeExplainerZone3: String { String(localized: "home.explainer.zone3") }

    /// Hard. Just a few words at a time. Done in intervals, to raise your threshold.
    static var homeExplainerZone4: String { String(localized: "home.explainer.zone4") }

    /// All out. You can't talk. Very short intervals, for speed.
    static var homeExplainerZone5: String { String(localized: "home.explainer.zone5") }

    /// The zone tells you how hard to go. The simplest way to measure it: how much you can talk while you move.
    static var homeExplainerZonesBody: String { String(localized: "home.explainer.zones_body") }

    /// Intensity zones
    static var homeExplainerZonesTitle: String { String(localized: "home.explainer.zones_title") }

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

    /// %1$lld ml/h and %2$lld g carbs/h · %3$@ is %4$@ intensity
    static func homeHydrationNote(_ arg1: Int, _ arg2: Int, _ arg3: String, _ arg4: String) -> String {
        String(format: String(localized: "home.hydration_note"), arg1, arg2, arg3, arg4)
    }

    /// Hydration %lld ml/h
    static func homeHydrationRate(_ arg1: Int) -> String {
        String(format: String(localized: "home.hydration_rate"), arg1)
    }

    /// No active goal
    static var homeNoActiveGoal: String { String(localized: "home.no_active_goal") }

    /// Nothing planned for today
    static var homeNothingPlannedToday: String { String(localized: "home.nothing_planned_today") }

    /// of %@ planned
    static func homeOfPlanned(_ arg1: String) -> String {
        String(format: String(localized: "home.of_planned"), arg1)
    }

    /// Get ready
    static var homePrepareWorkout: String { String(localized: "home.prepare_workout") }

    /// Your profile is missing details your plan uses.
    static var homeProfileIncompleteBody: String { String(localized: "home.profile_incomplete.body") }

    /// Complete profile
    static var homeProfileIncompleteButton: String { String(localized: "home.profile_incomplete.button") }

    /// Back to workout
    static var homeShortcutsBackToWorkout: String { String(localized: "home.shortcuts.back_to_workout") }

    /// Opens everything you've done
    static var homeShortcutsHistoryHint: String { String(localized: "home.shortcuts.history.hint") }

    /// Opens your medical clearance
    static var homeShortcutsMedicalHint: String { String(localized: "home.shortcuts.medical.hint") }

    /// Opens your week-by-week plan
    static var homeShortcutsPlanHint: String { String(localized: "home.shortcuts.plan.hint") }

    /// Start workout
    static var homeShortcutsStartWorkout: String { String(localized: "home.shortcuts.start_workout") }

    /// Shortcuts
    static var homeShortcutsTitle: String { String(localized: "home.shortcuts.title") }

    /// View my plan
    static var homeShortcutsViewPlan: String { String(localized: "home.shortcuts.view_plan") }

    /// Opens the GPS workout
    static var homeShortcutsWorkoutHint: String { String(localized: "home.shortcuts.workout.hint") }

    /// Suggested %@
    static func homeSuggested(_ arg1: String) -> String {
        String(format: String(localized: "home.suggested"), arg1)
    }

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

    /// Today's workouts
    static var homeTodayWorkouts: String { String(localized: "home.today_workouts") }

    /// until your %@
    static func homeUntilYour(_ arg1: String) -> String {
        String(format: String(localized: "home.until_your"), arg1)
    }

    /// View history
    static var homeViewHistory: String { String(localized: "home.view_history") }

    /// View plan
    static var homeViewPlan: String { String(localized: "home.view_plan") }

    /// See the routine
    static var homeViewRoutine: String { String(localized: "home.view_routine") }

    /// Weekly load
    static var homeWeeklyLoad: String { String(localized: "home.weekly_load") }

    /// Day %lld
    static func homeWeeklyLoadDayNumber(_ arg1: Int) -> String {
        String(format: String(localized: "home.weekly_load.day_number"), arg1)
    }

    /// This week's km: done vs. planned. Each bar is a day; tap it to see that day.
    static var homeWeeklyLoadGuide: String { String(localized: "home.weekly_load.guide") }

    /// No km
    static var homeWeeklyLoadNoKm: String { String(localized: "home.weekly_load.no_km") }

    /// What is it?
    static var homeWhatIsIt: String { String(localized: "home.what_is_it") }

    /// What to bring
    static var homeWhatToBring: String { String(localized: "home.what_to_bring") }

    /// Explains what to bring on the workout
    static var homeWhatToBringHint: String { String(localized: "home.what_to_bring.hint") }

    /// Workout in progress
    static var homeWorkoutInProgress: String { String(localized: "home.workout_in_progress") }

    /// Your day
    static var homeYourDay: String { String(localized: "home.your_day") }

    /// Explains what intensity zones are
    static var homeZonesHint: String { String(localized: "home.zones.hint") }

    /// There's already an account with this email.
    static var legalAccountExists: String { String(localized: "legal.account_exists") }

    /// Create my account
    static var legalCreateAccount: String { String(localized: "legal.create_account") }

    /// I already have an account, sign in
    static var legalGoToLogin: String { String(localized: "legal.go_to_login") }

    /// Health notice
    static var legalHealthTitle: String { String(localized: "legal.health.title") }

    /// We're fetching the health notice from the server.
    static var legalLoading: String { String(localized: "legal.loading") }

    /// Tick that you read the notice to create your account.
    static var legalMustAccept: String { String(localized: "legal.must_accept") }

    /// We couldn't fetch the health notice. You can't create an account without reading it. Try again when you have s
    static var legalNoText: String { String(localized: "legal.no_text") }

    /// No one with legal training has reviewed this text yet. It's a draft and it will be replaced.
    static var legalNotReviewed: String { String(localized: "legal.not_reviewed") }

    /// Privacy Policy
    static var legalPrivacyTitle: String { String(localized: "legal.privacy.title") }

    /// Try again
    static var legalRetry: String { String(localized: "legal.retry") }

    /// Sign in with that email
    static var legalSignInWithEmail: String { String(localized: "legal.sign_in_with_email") }

    /// This sign-up was already used, so your account most likely exists. Try signing in with your email and password
    static var legalSignupAlreadyCreated: String { String(localized: "legal.signup_already_created") }

    /// Start again from the email
    static var legalStartOver: String { String(localized: "legal.start_over") }

    /// Health
    static var legalTabHealth: String { String(localized: "legal.tab.health") }

    /// Privacy
    static var legalTabPrivacy: String { String(localized: "legal.tab.privacy") }

    /// Terms
    static var legalTabTerms: String { String(localized: "legal.tab.terms") }

    /// Terms and Conditions
    static var legalTermsTitle: String { String(localized: "legal.terms.title") }

    /// Health notice
    static var legalTitle: String { String(localized: "legal.title") }

    /// Read the terms and conditions
    static var legalViewTerms: String { String(localized: "legal.view_terms") }

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

    /// Add your medical clearance
    static var medicalAddTitle: String { String(localized: "medical.add_title") }

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

    /// Your clearance expires in %lld days
    static func medicalExpiresInDays(_ arg1: Int) -> String {
        String(format: String(localized: "medical.expires_in_days"), arg1)
    }

    /// Expires on %@
    static func medicalExpiresOn(_ arg1: String) -> String {
        String(format: String(localized: "medical.expires_on"), arg1)
    }

    /// Your clearance expires today
    static var medicalExpiresToday: String { String(localized: "medical.expires_today") }

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

    /// Clearance expired · renew it
    static var medicalStatusExpired: String { String(localized: "medical.status.expired") }

    /// Clearance valid · expires in %lld days
    static func medicalStatusValidDaysLeft(_ arg1: Int) -> String {
        String(format: String(localized: "medical.status.valid_days_left"), arg1)
    }

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

    /// Active days
    static var milestonesActiveDays: String { String(localized: "milestones.active_days") }

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

    /// The colored border marks today; the thick border, the day you picked.
    static var milestonesCalendarBorderHint: String { String(localized: "milestones.calendar.border_hint") }

    /// Each square is a day. Tap it to see what you did.
    static var milestonesCalendarHint: String { String(localized: "milestones.calendar.hint") }

    /// Collapsed
    static var milestonesCollapsed: String { String(localized: "milestones.collapsed") }

    /// Completed workouts
    static var milestonesCompletedWorkouts: String { String(localized: "milestones.completed_workouts") }

    /// Distance for the day
    static var milestonesDayDistance: String { String(localized: "milestones.day_distance") }

    /// Add 1 km of running to this day
    static var milestonesDebugAddKm: String { String(localized: "milestones.debug.add_km") }

    /// Expanded
    static var milestonesExpanded: String { String(localized: "milestones.expanded") }

    /// High: two workouts, or %@ or more in the day.
    static func milestonesLevelHigh(_ arg1: String) -> String {
        String(format: String(localized: "milestones.level.high"), arg1)
    }

    /// Light: a short workout (under %@) or %@ steps or more.
    static func milestonesLevelLight(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "milestones.level.light"), arg1, arg2)
    }

    /// Moderate: %@ or more in the day, or %@ steps or more.
    static func milestonesLevelModerate(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "milestones.level.moderate"), arg1, arg2)
    }

    /// No activity: no workouts, and fewer than %@ steps.
    static func milestonesLevelNone(_ arg1: String) -> String {
        String(format: String(localized: "milestones.level.none"), arg1)
    }

    /// Very high: three or more workouts, or %@ or more in the day.
    static func milestonesLevelVeryHigh(_ arg1: String) -> String {
        String(format: String(localized: "milestones.level.very_high"), arg1)
    }

    /// no workouts
    static var milestonesNoWorkouts: String { String(localized: "milestones.no_workouts") }

    /// No workouts were recorded on this day.
    static var milestonesNoWorkoutsDay: String { String(localized: "milestones.no_workouts_day") }

    /// Rest day
    static var milestonesRestDay: String { String(localized: "milestones.rest_day") }

    /// Sessions
    static var milestonesSessions: String { String(localized: "milestones.sessions") }

    /// Number of steps
    static var milestonesStepsCount: String { String(localized: "milestones.steps.count") }

    /// Log steps
    static var milestonesStepsLog: String { String(localized: "milestones.steps.log") }

    /// Steps recorded for the day
    static var milestonesStepsLogged: String { String(localized: "milestones.steps.logged") }

    /// Enter the number of steps for the selected day:
    static var milestonesStepsPrompt: String { String(localized: "milestones.steps.prompt") }

    /// Apple Health
    static var milestonesStepsSourceAppleHealth: String { String(localized: "milestones.steps.source.apple_health") }

    /// Health Connect
    static var milestonesStepsSourceHealthConnect: String { String(localized: "milestones.steps.source.health_connect") }

    /// Manual
    static var milestonesStepsSourceManual: String { String(localized: "milestones.steps.source.manual") }

    /// Total distance
    static var milestonesTotalDistance: String { String(localized: "milestones.total_distance") }

    /// What does it mean?
    static var milestonesWhatItMeans: String { String(localized: "milestones.what_it_means") }

    /// %lld workouts
    static func milestonesWorkoutsCount(_ arg1: Int) -> String {
        String(format: String(localized: "milestones.workouts_count"), arg1)
    }

    /// 1 workout
    static var milestonesWorkoutsOne: String { String(localized: "milestones.workouts_one") }

    /// Your year
    static var milestonesYourYear: String { String(localized: "milestones.your_year") }

    /// %1$lld °C at workout time (feels like %2$lld °C). Check the time and bring water. Data:  Weather.
    static func notificationHeatBody(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "notification.heat.body"), arg1, arg2)
    }

    /// Heat expected for your workout
    static var notificationHeatTitle: String { String(localized: "notification.heat.title") }

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

    /// We sent a 6-character code, with numbers and letters, to %@. It can take up to a minute; if it doesn't turn up
    static func passwordResetCodeBody(_ arg1: String) -> String {
        String(format: String(localized: "password.reset.code.body"), arg1)
    }

    /// Check your email
    static var passwordResetCodeTitle: String { String(localized: "password.reset.code.title") }

    /// Verify code
    static var passwordResetCodeVerify: String { String(localized: "password.reset.code.verify") }

    /// Account
    static var passwordResetDoneAccount: String { String(localized: "password.reset.done.account") }

    /// You can sign in with your new password now. We signed you out everywhere else — if you didn't ask for this cha
    static var passwordResetDoneBody: String { String(localized: "password.reset.done.body") }

    /// Changed
    static var passwordResetDoneChanged: String { String(localized: "password.reset.done.changed") }

    /// Go to my home
    static var passwordResetDoneGoHome: String { String(localized: "password.reset.done.go_home") }

    /// Password updated
    static var passwordResetDoneTitle: String { String(localized: "password.reset.done.title") }

    /// For security, the message is sent whether or not the address has an account.
    static var passwordResetEmailAntiEnumeration: String { String(localized: "password.reset.email.anti_enumeration") }

    /// Enter the email you signed up with and we'll send you a code to choose a new password. Your training plan, you
    static var passwordResetEmailBody: String { String(localized: "password.reset.email.body") }

    /// Send me the code
    static var passwordResetEmailSend: String { String(localized: "password.reset.email.send") }

    /// Recover your password
    static var passwordResetEmailTitle: String { String(localized: "password.reset.email.title") }

    /// We couldn't change your password
    static var passwordResetErrorTitle: String { String(localized: "password.reset.error.title") }

    /// At least 10 characters, with one capital letter and one number. When you save it we'll sign you out on every o
    static var passwordResetNewBody: String { String(localized: "password.reset.new.body") }

    /// New password
    static var passwordResetNewLabel: String { String(localized: "password.reset.new.label") }

    /// The two passwords match.
    static var passwordResetNewMatch: String { String(localized: "password.reset.new.match") }

    /// The two passwords don't match.
    static var passwordResetNewNoMatch: String { String(localized: "password.reset.new.no_match") }

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

    /// Current phase: %@
    static func planCurrentPhase(_ arg1: String) -> String {
        String(format: String(localized: "plan.current_phase"), arg1)
    }

    /// Available on that day: you'll be able to start it from here or from Home.
    static var planDayAvailableThatDay: String { String(localized: "plan.day.available_that_day") }

    /// %lld g of carbs per hour
    static func planDayCarbsPerHour(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.carbs_per_hour"), arg1)
    }

    /// Collapsed
    static var planDayCollapsed: String { String(localized: "plan.day.collapsed") }

    /// Expanded
    static var planDayExpanded: String { String(localized: "plan.day.expanded") }

    /// What the plan calls fueling: water, gels and salts so you don't run out of energy on the workout.
    static var planDayFuelingBody: String { String(localized: "plan.day.fueling_body") }

    /// 1 gel
    static var planDayGelOne: String { String(localized: "plan.day.gel_one") }

    /// %lld gels
    static func planDayGelsCount(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.gels_count"), arg1)
    }

    /// This day has passed. No problem: the plan moves on to what's next.
    static var planDayPast: String { String(localized: "plan.day.past") }

    /// Today is a rest day. Your body gets stronger while it recovers: an easy walk or gentle stretching is fine.
    static var planDayRest: String { String(localized: "plan.day.rest") }

    /// You alternate jogging intervals with walking intervals.
    static var planDayRunWalk: String { String(localized: "plan.day.run_walk") }

    /// 1 salt dose
    static var planDaySaltDoseOne: String { String(localized: "plan.day.salt_dose_one") }

    /// %lld salt doses
    static func planDaySaltDosesCount(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.salt_doses_count"), arg1)
    }

    /// What the session looks like
    static var planDaySessionShape: String { String(localized: "plan.day.session_shape") }

    /// %lld mg of sodium
    static func planDaySodiumMg(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.sodium_mg"), arg1)
    }

    /// Start this workout
    static var planDayStartWorkout: String { String(localized: "plan.day.start_workout") }

    /// Strength day: exercises that protect your legs and make running feel easier.
    static var planDayStrength: String { String(localized: "plan.day.strength") }

    /// Tap to close the details
    static var planDayTapToClose: String { String(localized: "plan.day.tap_to_close") }

    /// Tap to see what to do and why
    static var planDayTapToSee: String { String(localized: "plan.day.tap_to_see") }

    /// View in your history
    static var planDayViewInHistory: String { String(localized: "plan.day.view_in_history") }

    /// View routine
    static var planDayViewRoutine: String { String(localized: "plan.day.view_routine") }

    /// What %@ is
    static func planDayWhatIs(_ arg1: String) -> String {
        String(format: String(localized: "plan.day.what_is"), arg1)
    }

    /// What to bring to drink and eat
    static var planDayWhatToBring: String { String(localized: "plan.day.what_to_bring") }

    /// Why today
    static var planDayWhyToday: String { String(localized: "plan.day.why_today") }

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

    /// It's the foundation: lots of easy running so your heart, legs and tendons get used to running often without ge
    static var planPhaseBaseBody: String { String(localized: "plan.phase.base.body") }

    /// If you feel slow, that's fine: it's on purpose.
    static var planPhaseBaseTip: String { String(localized: "plan.phase.base.tip") }

    /// Build
    static var planPhaseBuild: String { String(localized: "plan.phase.build") }

    /// Load builds up gradually: more kilometers and some pace sessions to gain endurance and speed.
    static var planPhaseBuildBody: String { String(localized: "plan.phase.build.body") }

    /// Some weeks are harder; the lighter ones are there so your body can absorb it.
    static var planPhaseBuildTip: String { String(localized: "plan.phase.build.tip") }

    /// Completed
    static var planPhaseCompleted: String { String(localized: "plan.phase.completed") }

    /// A phase with its own goal. Each week's days already account for it: just follow them.
    static var planPhaseGenericBody: String { String(localized: "plan.phase.generic.body") }

    /// Explains what this phase is for
    static var planPhaseHint: String { String(localized: "plan.phase.hint") }

    /// Peak
    static var planPhasePeak: String { String(localized: "plan.phase.peak") }

    /// The toughest weeks: the longest long run and the workouts closest to race day.
    static var planPhasePeakBody: String { String(localized: "plan.phase.peak.body") }

    /// Sleep and eat well: feeling tired is expected here.
    static var planPhasePeakTip: String { String(localized: "plan.phase.peak.tip") }

    /// Race
    static var planPhaseRace: String { String(localized: "plan.phase.race") }

    /// Race week: short and easy, so you arrive with fresh legs.
    static var planPhaseRaceBody: String { String(localized: "plan.phase.race.body") }

    /// Don't try anything new on race day: no new shoes, no new gels.
    static var planPhaseRaceTip: String { String(localized: "plan.phase.race.tip") }

    /// Taper
    static var planPhaseTaper: String { String(localized: "plan.phase.taper") }

    /// Volume drops so you arrive rested without losing your edge: fewer kilometers and a bit of pace.
    static var planPhaseTaperBody: String { String(localized: "plan.phase.taper.body") }

    /// If you have energy to spare, that's the idea. Don't add extra kilometers.
    static var planPhaseTaperTip: String { String(localized: "plan.phase.taper.tip") }

    /// Coming up
    static var planPhaseUpcoming: String { String(localized: "plan.phase.upcoming") }

    /// You are here
    static var planPhaseYouAreHere: String { String(localized: "plan.phase.you_are_here") }

    /// Each phase has a different goal. Tap one to see what it's for.
    static var planPhasesIntro: String { String(localized: "plan.phases.intro") }

    /// Your plan's phases
    static var planPhasesTitle: String { String(localized: "plan.phases.title") }

    /// %1$@ · week %2$lld of %3$lld
    static func planSubtitle(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "plan.subtitle"), arg1, arg2, arg3)
    }

    /// Your plan
    static var planTitle: String { String(localized: "plan.title") }

    /// TODAY
    static var planTodayBadge: String { String(localized: "plan.today_badge") }

    /// until your race
    static var planUntilRace: String { String(localized: "plan.until_race") }

    /// Week %lld
    static func planWeek(_ arg1: Int) -> String {
        String(format: String(localized: "plan.week"), arg1)
    }

    /// W%lld
    static func planWeekChip(_ arg1: Int) -> String {
        String(format: String(localized: "plan.week.chip"), arg1)
    }

    /// Week complete! Everything planned is done.
    static var planWeekComplete: String { String(localized: "plan.week.complete") }

    /// Week %lld · in progress
    static func planWeekInProgress(_ arg1: Int) -> String {
        String(format: String(localized: "plan.week.in_progress"), arg1)
    }

    /// %@ to go to complete the week.
    static func planWeekLeftToComplete(_ arg1: String) -> String {
        String(format: String(localized: "plan.week.left_to_complete"), arg1)
    }

    /// Next week
    static var planWeekNext: String { String(localized: "plan.week.next") }

    /// No kilometers recorded this week.
    static var planWeekNoKmLogged: String { String(localized: "plan.week.no_km_logged") }

    /// No kilometers planned this week.
    static var planWeekNoKmPlanned: String { String(localized: "plan.week.no_km_planned") }

    /// You haven't logged any kilometers this week yet.
    static var planWeekNoKmYet: String { String(localized: "plan.week.no_km_yet") }

    /// Previous week
    static var planWeekPrevious: String { String(localized: "plan.week.previous") }

    /// Swipe the days sideways to change weeks
    static var planWeekSwipeHint: String { String(localized: "plan.week.swipe_hint") }

    /// %lld weeks to go
    static func planWeeksLeft(_ arg1: Int) -> String {
        String(format: String(localized: "plan.weeks_left"), arg1)
    }

    /// A heads-up 45 min ahead so you can get bottles, gels and your pre-workout snack ready.
    static var previewBeforeBody: String { String(localized: "preview.before_body") }

    /// And before you head out
    static var previewBeforeLabel: String { String(localized: "preview.before_label") }

    /// 750 ml/h
    static var previewChipFluid: String { String(localized: "preview.chip.fluid") }

    /// 1 gel every 45′
    static var previewChipGel: String { String(localized: "preview.chip.gel") }

    /// 600 mg sodium
    static var previewChipSodium: String { String(localized: "preview.chip.sodium") }

    /// Let's build your plan in 2 minutes
    static var previewCtaTitle: String { String(localized: "preview.cta_title") }

    /// Already have an account?
    static var previewHaveAccount: String { String(localized: "preview.have_account") }

    /// Your plan on race day
    static var previewLabel: String { String(localized: "preview.label") }

    /// Long run · 14 km · 26°
    static var previewSession: String { String(localized: "preview.session") }

    /// Sign in
    static var previewSignIn: String { String(localized: "preview.sign_in") }

    /// Get started
    static var previewStart: String { String(localized: "preview.start") }

    /// of those who stopped training did so for lack of time
    static var problemFact1: String { String(localized: "problem.fact1") }

    /// of runners get cramps: losing 3 to 5 % of body weight already causes weakness and disorientation
    static var problemFact2: String { String(localized: "problem.fact2") }

    /// of people who play sport compete in organised races
    static var problemFact3: String { String(localized: "problem.fact3") }

    /// Enthusiasm isn't the problem
    static var problemTitle: String { String(localized: "problem.title") }

    /// Age
    static var profileAge: String { String(localized: "profile.age") }

    /// %lld years
    static func profileAgeYears(_ arg1: Int) -> String {
        String(format: String(localized: "profile.age_years"), arg1)
    }

    /// Complete now
    static var profileCompleteNow: String { String(localized: "profile.complete_now") }

    /// Complete profile
    static var profileCompleteProfile: String { String(localized: "profile.complete_profile") }

    /// Days and times
    static var profileDaysAndTimes: String { String(localized: "profile.days_and_times") }

    /// Choose a new goal
    static var profileGoalsChooseNew: String { String(localized: "profile.goals.choose_new") }

    /// %lld days to go
    static func profileGoalsDaysLeft(_ arg1: Int) -> String {
        String(format: String(localized: "profile.goals.days_left"), arg1)
    }

    /// Your previous goals have ended. Set a new goal to start your next plan.
    static var profileGoalsFinished: String { String(localized: "profile.goals.finished") }

    /// Looking for your goals…
    static var profileGoalsLoading: String { String(localized: "profile.goals.loading") }

    /// + Manage
    static var profileGoalsManage: String { String(localized: "profile.goals.manage") }

    /// Plan with no fixed date
    static var profileGoalsNoFixedDate: String { String(localized: "profile.goals.no_fixed_date") }

    /// No active goals
    static var profileGoalsNoneActive: String { String(localized: "profile.goals.none_active") }

    /// 1 day to go
    static var profileGoalsOneDayLeft: String { String(localized: "profile.goals.one_day_left") }

    /// Goals
    static var profileGoalsTitle: String { String(localized: "profile.goals.title") }

    /// It's today!
    static var profileGoalsToday: String { String(localized: "profile.goals.today") }

    /// %lld wk to go
    static func profileGoalsWeeksLeft(_ arg1: Int) -> String {
        String(format: String(localized: "profile.goals.weeks_left"), arg1)
    }

    /// Height
    static var profileHeight: String { String(localized: "profile.height") }

    /// Expired · renew it
    static var profileMedicalExpired: String { String(localized: "profile.medical.expired") }

    /// Expires on %@ · %lld days left
    static func profileMedicalExpiresOnDaysLeft(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "profile.medical.expires_on_days_left"), arg1, arg2)
    }

    /// Not added · upload a photo or PDF
    static var profileMedicalNotAdded: String { String(localized: "profile.medical.not_added") }

    /// No photo
    static var profileNoPhoto: String { String(localized: "profile.no_photo") }

    /// no workout
    static var profileNoWorkout: String { String(localized: "profile.no_workout") }

    /// of %lld
    static func profileOfNumber(_ arg1: Int) -> String {
        String(format: String(localized: "profile.of_number"), arg1)
    }

    /// of %@
    static func profileOfText(_ arg1: String) -> String {
        String(format: String(localized: "profile.of_text"), arg1)
    }

    /// Opens your personal details in Settings
    static var profileOpensPersonalData: String { String(localized: "profile.opens_personal_data") }

    /// Opens your plan
    static var profileOpensPlan: String { String(localized: "profile.opens_plan") }

    /// Opens your days and times in Settings
    static var profileOpensTraining: String { String(localized: "profile.opens_training") }

    /// %lld per week
    static func profilePerWeek(_ arg1: Int) -> String {
        String(format: String(localized: "profile.per_week"), arg1)
    }

    /// Week %lld of %lld of the plan
    static func profilePlanWeekOf(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "profile.plan_week_of"), arg1, arg2)
    }

    /// Shows how the streak works
    static var profileStreakHint: String { String(localized: "profile.streak.hint") }

    /// This week
    static var profileThisWeek: String { String(localized: "profile.this_week") }

    /// Training days
    static var profileTrainingDays: String { String(localized: "profile.training_days") }

    /// The filled days are the ones you chose: your plan spreads your workouts across them, at that time.
    static var profileTrainingDaysDetail: String { String(localized: "profile.training_days.detail") }

    /// You haven't chosen any days yet. Complete your profile so the plan knows when you train.
    static var profileTrainingDaysNone: String { String(localized: "profile.training_days.none") }

    /// Settings
    static var profileViewSettings: String { String(localized: "profile.view_settings") }

    /// Weight
    static var profileWeight: String { String(localized: "profile.weight") }

    /// you train at %@
    static func profileYouTrainAt(_ arg1: String) -> String {
        String(format: String(localized: "profile.you_train_at"), arg1)
    }

    /// Your activity
    static var profileYourActivity: String { String(localized: "profile.your_activity") }

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

    /// Delete account
    static var settingsDeleteAccount: String { String(localized: "settings.delete_account") }

    /// Delete for good
    static var settingsDeleteAccountAlertConfirm: String { String(localized: "settings.delete_account.alert_confirm") }

    /// Everything is deleted right away and can't be recovered.
    static var settingsDeleteAccountAlertMessage: String { String(localized: "settings.delete_account.alert_message") }

    /// Delete your account for good?
    static var settingsDeleteAccountAlertTitle: String { String(localized: "settings.delete_account.alert_title") }

    /// Your account and everything we keep about you are deleted for good: profile, plan, workouts, runs, gym sets an
    static var settingsDeleteAccountBody: String { String(localized: "settings.delete_account.body") }

    /// Delete my account
    static var settingsDeleteAccountConfirmButton: String { String(localized: "settings.delete_account.confirm_button") }

    /// We no longer keep anything of yours. If you signed in with Apple, you can remove Stamina in iPhone Settings › 
    static var settingsDeleteAccountDoneBody: String { String(localized: "settings.delete_account.done_body") }

    /// Your account was deleted
    static var settingsDeleteAccountDoneTitle: String { String(localized: "settings.delete_account.done_title") }

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

    /// 30 min before
    static var settingsNotificationsThirtyMinBefore: String { String(localized: "settings.notifications.thirty_min_before") }

    /// 30 minutes before the scheduled workout time
    static var settingsNotificationsThirtyMinBeforeDetail: String { String(localized: "settings.notifications.thirty_min_before.detail") }

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

    /// Your age sets your heart-rate zones, your estimated sweat rate and how many calories you need in high-load wee
    static var signupBirthBody: String { String(localized: "signup.birth.body") }

    /// day
    static var signupBirthDay: String { String(localized: "signup.birth.day") }

    /// Order follows your language (%@): %@
    static func signupBirthFormat(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "signup.birth.format"), arg1, arg2)
    }

    /// Hi %@!
    static func signupBirthGreeting(_ arg1: String) -> String {
        String(format: String(localized: "signup.birth.greeting"), arg1)
    }

    /// month
    static var signupBirthMonth: String { String(localized: "signup.birth.month") }

    /// Scroll the wheel to your date of birth to continue.
    static var signupBirthMustChoose: String { String(localized: "signup.birth.must_choose") }

    /// %@ When were you born?
    static func signupBirthTitle(_ arg1: String) -> String {
        String(format: String(localized: "signup.birth.title"), arg1)
    }

    /// year
    static var signupBirthYear: String { String(localized: "signup.birth.year") }

    /// Weight is the basis of the whole calculation: litres of fluid per hour, milligrams of sodium and grams of carb
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

    /// We sent a 6-character code, with numbers and letters, to %@. It can take up to a minute; if it doesn't turn up
    static func signupCodeBody(_ arg1: String) -> String {
        String(format: String(localized: "signup.code.body"), arg1)
    }

    /// Verify your email
    static var signupCodeTitle: String { String(localized: "signup.code.title") }

    /// Verify
    static var signupCodeVerify: String { String(localized: "signup.code.verify") }

    /// Finish later
    static var signupCompleteLater: String { String(localized: "signup.complete_later") }

    /// You'll get %lld alerts a week, 45 min before each session.
    static func signupDaysAlert(_ arg1: Int) -> String {
        String(format: String(localized: "signup.days.alert"), arg1)
    }

    /// This isn't a profile field: it's what triggers your alerts. We message you 45 minutes before each session so y
    static var signupDaysBody: String { String(localized: "signup.days.body") }

    /// Pick at least one day to switch the alerts on.
    static var signupDaysNoDays: String { String(localized: "signup.days.no_days") }

    /// Time on %@
    static func signupDaysTimeOf(_ arg1: String) -> String {
        String(format: String(localized: "signup.days.time_of"), arg1)
    }

    /// Which days and at what time do you train?
    static var signupDaysTitle: String { String(localized: "signup.days.title") }

    /// Base plan
    static var signupDoneBasePlan: String { String(localized: "signup.done.base_plan") }

    /// Date of birth
    static var signupDoneBirth: String { String(localized: "signup.done.birth") }

    /// Days
    static var signupDoneDays: String { String(localized: "signup.done.days") }

    /// Go to my home
    static var signupDoneGoHome: String { String(localized: "signup.done.go_home") }

    /// Goal
    static var signupDoneGoal: String { String(localized: "signup.done.goal") }

    /// Level
    static var signupDoneLevel: String { String(localized: "signup.done.level") }

    /// Your profile is complete.
    static var signupDoneProfileComplete: String { String(localized: "signup.done.profile_complete") }

    /// Sport
    static var signupDoneSport: String { String(localized: "signup.done.sport") }

    /// You're all set, %@
    static func signupDoneTitle(_ arg1: String) -> String {
        String(format: String(localized: "signup.done.title"), arg1)
    }

    /// Fill in your details and choose a password. Then we will send you a code to verify your email.
    static var signupEmailBody: String { String(localized: "signup.email.body") }

    /// That email doesn't look valid — check it has an @ and a domain.
    static var signupEmailInvalid: String { String(localized: "signup.email.invalid") }

    /// By continuing you accept the terms and the privacy policy.
    static var signupEmailLegal: String { String(localized: "signup.email.legal") }

    /// By continuing you accept the [Terms and Conditions](stamina-legal://terminos) and the [Privacy Policy](stamina
    static var signupEmailLegalLinks: String { String(localized: "signup.email.legal_links") }

    /// Send me the code
    static var signupEmailSend: String { String(localized: "signup.email.send") }

    /// Create your account
    static var signupEmailTitle: String { String(localized: "signup.email.title") }

    /// We couldn't continue your sign-up
    static var signupErrorTitle: String { String(localized: "signup.error.title") }

    /// With the date of your event we build the countdown and lay out the loading, recovery and taper weeks. If you h
    static var signupGoalBody: String { String(localized: "signup.goal.body") }

    /// 10 km
    static var signupGoalC10k: String { String(localized: "signup.goal.c10k") }

    /// 10 km
    static var signupGoalC10kDetail: String { String(localized: "signup.goal.c10k.detail") }

    /// 5 km
    static var signupGoalC5k: String { String(localized: "signup.goal.c5k") }

    /// 5 km · 4-week plan
    static var signupGoalC5kDetail: String { String(localized: "signup.goal.c5k.detail") }

    /// Choose your goal
    static var signupGoalChoose: String { String(localized: "signup.goal.choose") }

    /// Half marathon
    static var signupGoalHalfMarathon: String { String(localized: "signup.goal.half_marathon") }

    /// 21.1 km
    static var signupGoalHalfMarathonDetail: String { String(localized: "signup.goal.half_marathon.detail") }

    /// Get back to training without injuries
    static var signupGoalInjuryFree: String { String(localized: "signup.goal.injury_free") }

    /// no fixed distance
    static var signupGoalInjuryFreeDetail: String { String(localized: "signup.goal.injury_free.detail") }

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

    /// Next month
    static var signupGoalNextMonth: String { String(localized: "signup.goal.next_month") }

    /// No date yet: we'll build you a base plan.
    static var signupGoalNoDate: String { String(localized: "signup.goal.no_date") }

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

    /// I understand that Stamina gives general suggestions and that if any symptom appears I have to stop and seek ad
    static var signupHealthAccept: String { String(localized: "signup.health.accept") }

    /// We're not doctors and this app is not a substitute for seeing one. If you have a pre-existing condition, take 
    static var signupHealthBody: String { String(localized: "signup.health.body") }

    /// Tick the disclaimer to continue.
    static var signupHealthMustAccept: String { String(localized: "signup.health.must_accept") }

    /// Stop and get checked if you feel
    static var signupHealthStopAndConsult: String { String(localized: "signup.health.stop_and_consult") }

    /// Chest pain or tightness
    static var signupHealthSymptom1: String { String(localized: "signup.health.symptom1") }

    /// Severe breathlessness or dizziness
    static var signupHealthSymptom2: String { String(localized: "signup.health.symptom2") }

    /// Joint pain that gets worse as you run
    static var signupHealthSymptom3: String { String(localized: "signup.health.symptom3") }

    /// One thing before you start
    static var signupHealthTitle: String { String(localized: "signup.health.title") }

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

    /// This sets the volume your plan starts at and how much it can grow each week without exposing you to injury. If
    static var signupLevelBody: String { String(localized: "signup.level.body") }

    /// Intermediate
    static var signupLevelIntermediate: String { String(localized: "signup.level.intermediate") }

    /// 1 to 3 years training regularly
    static var signupLevelIntermediateDetail: String { String(localized: "signup.level.intermediate.detail") }

    /// How long have you been training?
    static var signupLevelTitle: String { String(localized: "signup.level.title") }

    /// We use your first name to talk to you in notifications and in the weekly summary. Your surname only shows up i
    static var signupNameBody: String { String(localized: "signup.name.body") }

    /// First name
    static var signupNameLabel: String { String(localized: "signup.name.label") }

    /// Alex
    static var signupNamePlaceholder: String { String(localized: "signup.name.placeholder") }

    /// Email verified. What's your name?
    static var signupNameTitle: String { String(localized: "signup.name.title") }

    /// At least %lld characters, with one capital letter and one number. It's the only password we'll ask you for: it
    static func signupPasswordBody(_ arg1: Int) -> String {
        String(format: String(localized: "signup.password.body"), arg1)
    }

    /// This screen is NOT in the design: the 13 steps never ask for a password and the contract requires one. It's a 
    static var signupPasswordGapNote: String { String(localized: "signup.password.gap_note") }

    /// Choose a password
    static var signupPasswordTitle: String { String(localized: "signup.password.title") }

    /// Sweat rates, sodium loss and calorie burn differ quite a bit between men and women at the same weight and pace
    static var signupSexBody: String { String(localized: "signup.sex.body") }

    /// Female
    static var signupSexFemale: String { String(localized: "signup.sex.female") }

    /// Lower average sweat rate and a different sodium loss
    static var signupSexFemaleDetail: String { String(localized: "signup.sex.female.detail") }

    /// Male
    static var signupSexMale: String { String(localized: "signup.sex.male") }

    /// Higher average sweat rate at the same weight and pace
    static var signupSexMaleDetail: String { String(localized: "signup.sex.male.detail") }

    /// Which biological sex should we use for your sweat rate?
    static var signupSexTitle: String { String(localized: "signup.sex.title") }

    /// I'd rather not say
    static var signupSexUndisclosed: String { String(localized: "signup.sex.undisclosed") }

    /// Without it, some parts of your plan may not be available
    static var signupSexUndisclosedDetail: String { String(localized: "signup.sex.undisclosed.detail") }

    /// Continuing with %@. Check your details: we'll send a code to verify your email, and you won't need a password.
    static func signupSocialBanner(_ arg1: String) -> String {
        String(format: String(localized: "signup.social_banner"), arg1)
    }

    /// Continuing with %@. Check your name: %@ already verified your email, so there's no code and no password.
    static func signupSocialBannerVerified(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "signup.social_banner_verified"), arg1, arg2)
    }

    /// Too much time has passed since you chose Google or Apple. Continue with your account again to finish signing u
    static var signupSocialExpired: String { String(localized: "signup.social_expired") }

    /// Continue with %@ again
    static func signupSocialRetry(_ arg1: String) -> String {
        String(format: String(localized: "signup.social_retry"), arg1)
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

    /// Apple Watch and Health
    static var signupTrackingApple: String { String(localized: "signup.tracking.apple") }

    /// Heart rate, steps and workouts
    static var signupTrackingAppleDetail: String { String(localized: "signup.tracking.apple.detail") }

    /// If you connect your watch or your phone's GPS, we tune hydration and gels to your real pace and heart rate ins
    static var signupTrackingBody: String { String(localized: "signup.tracking.body") }

    /// Garmin watch
    static var signupTrackingGarmin: String { String(localized: "signup.tracking.garmin") }

    /// Pace, heart rate and elevation
    static var signupTrackingGarminDetail: String { String(localized: "signup.tracking.garmin.detail") }

    /// Phone GPS
    static var signupTrackingGps: String { String(localized: "signup.tracking.gps") }

    /// Pace and distance, no extra kit
    static var signupTrackingGpsDetail: String { String(localized: "signup.tracking.gps.detail") }

    /// I log everything by hand
    static var signupTrackingManual: String { String(localized: "signup.tracking.manual") }

    /// We estimate from weight, weather and target pace
    static var signupTrackingManualDetail: String { String(localized: "signup.tracking.manual.detail") }

    /// Not now
    static var signupTrackingNotNow: String { String(localized: "signup.tracking.not_now") }

    /// This answer isn't saved yet: the contract has nowhere to put it. It's logged as B-006 and blocks nothing — con
    static var signupTrackingNotSaved: String { String(localized: "signup.tracking.not_saved") }

    /// How do you track your sessions?
    static var signupTrackingTitle: String { String(localized: "signup.tracking.title") }

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

    /// Your streak only counts days you are scheduled to train. If you miss a scheduled training day, the streak is l
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

    /// All set! Tap ⚡ whenever you want to go for a run.
    static var tourCoachDoneBubble: String { String(localized: "tour.coach.done.bubble") }

    /// Your training week, day by day.
    static var tourCoachPlanBubble: String { String(localized: "tour.coach.plan.bubble") }

    /// Start a workout with ⚡: GPS, pace and pause.
    static var tourCoachWorkoutBubble: String { String(localized: "tour.coach.workout.bubble") }

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

    /// high
    static var zoneHigh: String { String(localized: "zone.high") }

    /// low
    static var zoneLow: String { String(localized: "zone.low") }

    /// maximum
    static var zoneMax: String { String(localized: "zone.max") }

    /// moderate
    static var zoneModerate: String { String(localized: "zone.moderate") }

    /// moderate-high
    static var zoneModerateHigh: String { String(localized: "zone.moderate_high") }
}
