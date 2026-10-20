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
// 833 claves · idioma de autoría: es
// =============================================================================

import Foundation

/// Los textos. Una propiedad por clave del catálogo: un typo en una
/// clave deja de ser un bug de producción y pasa a ser un error de compilación.
enum Textos {

    /// Gimnasio · tren superior y core
    static var agendaGym: String { String(localized: "agenda.gym") }

    /// %lld ejercicios · 45 min · toca para ver la rutina
    static func agendaGymDetail(_ arg1: Int) -> String {
        String(format: String(localized: "agenda.gym.detail"), arg1)
    }

    /// Preparar bidones y geles
    static var agendaPrepare: String { String(localized: "agenda.prepare") }

    /// %1$@ con sales · %2$lld geles · aviso %3$lld min antes
    static func agendaPrepareDetail(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "agenda.prepare.detail"), arg1, arg2, arg3)
    }

    /// Recuperación
    static var agendaRecovery: String { String(localized: "agenda.recovery") }

    /// %1$lld g proteína + %2$lld g carbos en 45 min
    static func agendaRecoveryDetail(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "agenda.recovery.detail"), arg1, arg2)
    }

    /// Snack pre-entreno
    static var agendaSnack: String { String(localized: "agenda.snack") }

    /// %lld g carbos · banana + avena
    static func agendaSnackDetail(_ arg1: Int) -> String {
        String(format: String(localized: "agenda.snack.detail"), arg1)
    }

    /// Limpiar filtros
    static var catalogClearFilters: String { String(localized: "catalog.clear_filters") }

    /// Probá con menos filtros, registrá un ejercicio libre para esta sesión, o sugerilo para el catálogo.
    static var catalogEmptyBody: String { String(localized: "catalog.empty.body") }

    /// Usar un ejercicio libre
    static var catalogEmptyFreeExercise: String { String(localized: "catalog.empty.free_exercise") }

    /// Sugerirlo para el catálogo
    static var catalogEmptySuggest: String { String(localized: "catalog.empty.suggest") }

    /// No encontré lo que buscás
    static var catalogEmptyTitle: String { String(localized: "catalog.empty.title") }

    /// Ampliar los filtros
    static var catalogEmptyWiden: String { String(localized: "catalog.empty.widen") }

    /// Equipamiento
    static var catalogEquipment: String { String(localized: "catalog.equipment") }

    /// Filtros
    static var catalogFilters: String { String(localized: "catalog.filters") }

    /// Músculo
    static var catalogMuscle: String { String(localized: "catalog.muscle") }

    /// Sin equipo
    static var catalogNoEquipment: String { String(localized: "catalog.no_equipment") }

    /// Buscar por nombre o músculo
    static var catalogSearch: String { String(localized: "catalog.search") }

    /// Ver %lld ejercicios
    static func catalogShowCount(_ arg1: Int) -> String {
        String(format: String(localized: "catalog.show_count"), arg1)
    }

    /// Catálogo
    static var catalogTitle: String { String(localized: "catalog.title") }

    /// Todo
    static var commonAll: String { String(localized: "common.all") }

    /// Todos
    static var commonAllPlural: String { String(localized: "common.all_plural") }

    /// Ritmo prom.
    static var commonAvgPace: String { String(localized: "common.avg_pace") }

    /// Velocidad prom.
    static var commonAvgSpeed: String { String(localized: "common.avg_speed") }

    /// Volver
    static var commonBack: String { String(localized: "common.back") }

    /// Cancelar
    static var commonCancel: String { String(localized: "common.cancel") }

    /// Cambiar correo
    static var commonChangeEmail: String { String(localized: "common.change_email") }

    /// Cerrar
    static var commonClose: String { String(localized: "common.close") }

    /// Completá lo que falta para poder seguir.
    static var commonCompleteToContinue: String { String(localized: "common.complete_to_continue") }

    /// Confirmar
    static var commonConfirm: String { String(localized: "common.confirm") }

    /// Continuar
    static var commonContinue: String { String(localized: "common.continue") }

    /// Seguir
    static var commonContinueNext: String { String(localized: "common.continue_next") }

    /// día
    static var commonDay: String { String(localized: "common.day") }

    /// días
    static var commonDays: String { String(localized: "common.days") }

    /// Descartar
    static var commonDiscard: String { String(localized: "common.discard") }

    /// Distancia
    static var commonDistance: String { String(localized: "common.distance") }

    /// Listo
    static var commonDone: String { String(localized: "common.done") }

    /// Hecho
    static var commonDoneCheck: String { String(localized: "common.done_check") }

    /// Editar
    static var commonEdit: String { String(localized: "common.edit") }

    /// Desnivel
    static var commonElevationGain: String { String(localized: "common.elevation_gain") }

    /// Correo electrónico
    static var commonEmailLabel: String { String(localized: "common.email_label") }

    /// tu@mail.com
    static var commonEmailPlaceholder: String { String(localized: "common.email_placeholder") }

    /// Fecha del evento
    static var commonEventDate: String { String(localized: "common.event_date") }

    /// Entendido
    static var commonGotIt: String { String(localized: "common.got_it") }

    /// Seguir
    static var commonKeepGoing: String { String(localized: "common.keep_going") }

    /// Menos
    static var commonLess: String { String(localized: "common.less") }

    /// Mes
    static var commonMonth: String { String(localized: "common.month") }

    /// Más
    static var commonMore: String { String(localized: "common.more") }

    /// Siguiente
    static var commonNext: String { String(localized: "common.next") }

    /// Aceptar
    static var commonOk: String { String(localized: "common.ok") }

    /// Ritmo
    static var commonPace: String { String(localized: "common.pace") }

    /// ••••••••
    static var commonPasswordPlaceholder: String { String(localized: "common.password_placeholder") }

    /// Quitar
    static var commonRemove: String { String(localized: "common.remove") }

    /// Reenviar código
    static var commonResendCode: String { String(localized: "common.resend_code") }

    /// Reenviar en %@
    static func commonResendIn(_ arg1: String) -> String {
        String(format: String(localized: "common.resend_in"), arg1)
    }

    /// Reanudar
    static var commonResume: String { String(localized: "common.resume") }

    /// Reintentar
    static var commonRetry: String { String(localized: "common.retry") }

    /// Recorrido
    static var commonRoute: String { String(localized: "common.route") }

    /// Guardar
    static var commonSave: String { String(localized: "common.save") }

    /// Avance del registro
    static var commonSignupProgress: String { String(localized: "common.signup_progress") }

    /// Saltar
    static var commonSkip: String { String(localized: "common.skip") }

    /// Velocidad
    static var commonSpeed: String { String(localized: "common.speed") }

    /// Empezar
    static var commonStart: String { String(localized: "common.start") }

    /// Pasos
    static var commonSteps: String { String(localized: "common.steps") }

    /// pasos
    static var commonStepsLowercase: String { String(localized: "common.steps_lowercase") }

    /// Tiempo
    static var commonTime: String { String(localized: "common.time") }

    /// Faltan
    static var commonToGo: String { String(localized: "common.to_go") }

    /// faltan
    static var commonToGoLowercase: String { String(localized: "common.to_go_lowercase") }

    /// Hoy
    static var commonToday: String { String(localized: "common.today") }

    /// hoy
    static var commonTodayLowercase: String { String(localized: "common.today_lowercase") }

    /// Usar
    static var commonUse: String { String(localized: "common.use") }

    /// Semana
    static var commonWeek: String { String(localized: "common.week") }

    /// semanas
    static var commonWeeks: String { String(localized: "common.weeks") }

    /// Ayer
    static var commonYesterday: String { String(localized: "common.yesterday") }

    /// Ese pedido no tiene la forma que el servidor espera. Es un bug, no vos.
    static var errorBadRequest: String { String(localized: "error.bad_request") }

    /// El código venció. Pedí uno nuevo.
    static var errorCodeExpired: String { String(localized: "error.code_expired") }

    /// Recién te mandamos uno. Esperá un momento antes de pedir otro.
    static var errorCodeResendTooSoon: String { String(localized: "error.code_resend_too_soon") }

    /// Lo anterior todavía se está guardando. Probá de nuevo en un momento.
    static var errorConflict: String { String(localized: "error.conflict") }

    /// Se rompió algo del lado del servidor. No es culpa tuya.
    static var errorInternal: String { String(localized: "error.internal") }

    /// Ese código no es correcto o ya venció. Pedí uno nuevo.
    static var errorInvalidCode: String { String(localized: "error.invalid_code") }

    /// El correo o la contraseña no coinciden.
    static var errorInvalidCredentials: String { String(localized: "error.invalid_credentials") }

    /// Se venció la sesión. Entrá de nuevo.
    static var errorInvalidRefreshToken: String { String(localized: "error.invalid_refresh_token") }

    /// Se venció el registro. Empezá de nuevo desde el correo.
    static var errorInvalidRegistrationToken: String { String(localized: "error.invalid_registration_token") }

    /// Se venció el pedido de contraseña nueva. Empezá de nuevo desde el correo.
    static var errorInvalidResetToken: String { String(localized: "error.invalid_reset_token") }

    /// Hay que aceptar el aviso de salud para crear la cuenta.
    static var errorLegalNotAccepted: String { String(localized: "error.legal_not_accepted") }

    /// El aviso cambió mientras completabas el registro. Leelo de nuevo, por favor.
    static var errorLegalVersionStale: String { String(localized: "error.legal_version_stale") }

    /// Esa dirección no existe en el servidor.
    static var errorNotFound: String { String(localized: "error.not_found") }

    /// No hay conexión. Lo que escribiste queda guardado; probá de nuevo cuando vuelva.
    static var errorOffline: String { String(localized: "error.offline") }

    /// Falta un dato del perfil para poder armar el plan.
    static var errorProfileIncomplete: String { String(localized: "error.profile_incomplete") }

    /// Demasiados intentos. Esperá un momento antes de volver a probar.
    static var errorRateLimited: String { String(localized: "error.rate_limited") }

    /// El servidor no está respondiendo. Probá de nuevo en un momento.
    static var errorServerUnavailable: String { String(localized: "error.server_unavailable") }

    /// Se cerró la sesión desde otro lado. Entrá de nuevo.
    static var errorSessionRevoked: String { String(localized: "error.session_revoked") }

    /// Se venció la sesión. Entrá de nuevo.
    static var errorUnauthorized: String { String(localized: "error.unauthorized") }

    /// El servidor contestó algo inesperado. Es un bug, no vos.
    static var errorUnexpectedResponse: String { String(localized: "error.unexpected_response") }

    /// No se pudo. El servidor contestó «%@».
    static func errorUnknownCode(_ arg1: String) -> String {
        String(format: String(localized: "error.unknown_code"), arg1)
    }

    /// Esa contraseña es fácil de adivinar. Probá una más larga o menos común.
    static var errorWeakPassword: String { String(localized: "error.weak_password") }

    /// Patrón de movimiento
    static var exerciseMovementPattern: String { String(localized: "exercise.movement_pattern") }

    /// Músculo principal
    static var exercisePrimaryMuscle: String { String(localized: "exercise.primary_muscle") }

    /// Secundarios
    static var exerciseSecondaryMuscles: String { String(localized: "exercise.secondary_muscles") }

    /// Ver sustitutos
    static var exerciseSeeSubstitutes: String { String(localized: "exercise.see_substitutes") }

    /// Mismo patrón de movimiento
    static var exerciseSubstitutesSamePattern: String { String(localized: "exercise.substitutes.same_pattern") }

    /// Sustitutos de %@
    static func exerciseSubstitutesTitle(_ arg1: String) -> String {
        String(format: String(localized: "exercise.substitutes.title"), arg1)
    }

    /// Usar este ejercicio
    static var exerciseUse: String { String(localized: "exercise.use") }

    /// Armar mi plan de %@
    static func goalsBuildMyPlan(_ arg1: String) -> String {
        String(format: String(localized: "goals.build_my_plan"), arg1)
    }

    /// El equilibrio clásico entre fondo aeróbico y ritmo de carrera.
    static var goalsC10kBody: String { String(localized: "goals.c10k.body") }

    /// 10K Progresivo
    static var goalsC10kTitle: String { String(localized: "goals.c10k.title") }

    /// Velocidad y consistencia. Ideal para iniciarse o mejorar marca personal.
    static var goalsC5kBody: String { String(localized: "goals.c5k.body") }

    /// 5K Express
    static var goalsC5kTitle: String { String(localized: "goals.c5k.title") }

    /// Elige esta meta para tu próximo plan
    static var goalsChooseHint: String { String(localized: "goals.choose.hint") }

    /// Elegir fecha
    static var goalsChooseDate: String { String(localized: "goals.choose_date") }

    /// Con fecha, el plan cuenta las semanas hasta ese día.
    static var goalsDateBody: String { String(localized: "goals.date.body") }

    /// ¿Ya tenés fecha de carrera?
    static var goalsDateQuestion: String { String(localized: "goals.date.question") }

    /// Desnivel +
    static var goalsElevationPlus: String { String(localized: "goals.elevation_plus") }

    /// Con tu meta y la fecha, el plan arma tus semanas: etapas, días y kilómetros.
    static var goalsFooter: String { String(localized: "goals.footer") }

    /// Prueba intermedia exigente. Requiere fondos largos progresivos y nutrición en ruta.
    static var goalsHalfMarathonBody: String { String(localized: "goals.half_marathon.body") }

    /// Media Maratón
    static var goalsHalfMarathonTitle: String { String(localized: "goals.half_marathon.title") }

    /// Salud y base
    static var goalsHealthAndBase: String { String(localized: "goals.health_and_base") }

    /// Acondicionamiento físico suave para retomar el hábito con seguridad.
    static var goalsInjuryFreeBody: String { String(localized: "goals.injury_free.body") }

    /// Volver sin lesiones
    static var goalsInjuryFreeTitle: String { String(localized: "goals.injury_free.title") }

    /// Tu plan anterior terminó o todavía no tenés una meta. Contanos qué querés correr y cuándo, y armamos semanas a
    static var goalsIntro: String { String(localized: "goals.intro") }

    /// El desafío supremo de resistencia aeróbica, fuerza mental y fondo.
    static var goalsMarathonBody: String { String(localized: "goals.marathon.body") }

    /// Maratón
    static var goalsMarathonTitle: String { String(localized: "goals.marathon.title") }

    /// Terrenos técnicos, cuestas y adaptación a senderos y montaña.
    static var goalsMountainTrailBody: String { String(localized: "goals.mountain_trail.body") }

    /// Trail Montaña
    static var goalsMountainTrailTitle: String { String(localized: "goals.mountain_trail.title") }

    /// Nueva etapa
    static var goalsNewChapter: String { String(localized: "goals.new_chapter") }

    /// Natación en aguas abiertas, ciclismo y carrera en transiciones.
    static var goalsOlympicTriathlonBody: String { String(localized: "goals.olympic_triathlon.body") }

    /// Triatlón Olímpico
    static var goalsOlympicTriathlonTitle: String { String(localized: "goals.olympic_triathlon.title") }

    /// Se armará un plan continuo sin fecha límite.
    static var goalsOngoingPlan: String { String(localized: "goals.ongoing_plan") }

    /// El plan durará %lld semanas de preparación
    static func goalsPlanDuration(_ arg1: Int) -> String {
        String(format: String(localized: "goals.plan_duration"), arg1)
    }

    /// Revisá tu conexión e intentá de nuevo.
    static var goalsSaveFailedMessage: String { String(localized: "goals.save_failed.message") }

    /// No se pudo guardar el objetivo
    static var goalsSaveFailedTitle: String { String(localized: "goals.save_failed.title") }

    /// Armamos tu plan
    static var goalsStepBuildPlan: String { String(localized: "goals.step.build_plan") }

    /// Elegí la meta
    static var goalsStepChooseGoal: String { String(localized: "goals.step.choose_goal") }

    /// Poné la fecha
    static var goalsStepSetDate: String { String(localized: "goals.step.set_date") }

    /// Preparación sugerida:
    static var goalsSuggestedPrep: String { String(localized: "goals.suggested_prep") }

    /// Elegí tu próxima carrera
    static var goalsTitle: String { String(localized: "goals.title") }

    /// Es menos de lo recomendado para esta meta (al menos %lld semanas). Podés elegir una fecha más lejana o una met
    static func goalsTooShort(_ arg1: Int) -> String {
        String(format: String(localized: "goals.too_short"), arg1)
    }

    /// 10 a 14 semanas
    static var goalsWeeks1014: String { String(localized: "goals.weeks.10_14") }

    /// 12 a 16 semanas
    static var goalsWeeks1216: String { String(localized: "goals.weeks.12_16") }

    /// 14 a 20 semanas
    static var goalsWeeks1420: String { String(localized: "goals.weeks.14_20") }

    /// 16 a 24 semanas
    static var goalsWeeks1624: String { String(localized: "goals.weeks.16_24") }

    /// 6 a 10 semanas
    static var goalsWeeks610: String { String(localized: "goals.weeks.6_10") }

    /// 6 a 8 semanas
    static var goalsWeeks68: String { String(localized: "goals.weeks.6_8") }

    /// 8 a 12 semanas
    static var goalsWeeks812: String { String(localized: "goals.weeks.8_12") }

    /// ¿En qué consiste %@?
    static func goalsWhatIs(_ arg1: String) -> String {
        String(format: String(localized: "goals.what_is"), arg1)
    }

    /// Agregar ejercicio
    static var gymAddExercise: String { String(localized: "gym.add_exercise") }

    /// Terminar sesión de gimnasio
    static var gymFinish: String { String(localized: "gym.finish") }

    /// Hoy corrés a la tarde: la sesión es de fuerza liviana, sin llegar al fallo, para no comprometer el fondo.
    static var gymNote: String { String(localized: "gym.note") }

    /// La vez anterior: %@
    static func gymPrevious(_ arg1: String) -> String {
        String(format: String(localized: "gym.previous"), arg1)
    }

    /// %1$lld/%2$lld series
    static func gymProgress(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "gym.progress"), arg1, arg2)
    }

    /// +30 s
    static var gymRestAddTime: String { String(localized: "gym.rest.add_time") }

    /// ¡A la siguiente!
    static var gymRestDone: String { String(localized: "gym.rest.done") }

    /// Terminó el descanso de %@
    static func gymRestDoneDetail(_ arg1: String) -> String {
        String(format: String(localized: "gym.rest.done.detail"), arg1)
    }

    /// Faltan %lld series
    static func gymRestSetsLeft(_ arg1: Int) -> String {
        String(format: String(localized: "gym.rest.sets_left"), arg1)
    }

    /// Saltar
    static var gymRestSkip: String { String(localized: "gym.rest.skip") }

    /// Descanso
    static var gymRestTitle: String { String(localized: "gym.rest.title") }

    /// %lld s de descanso
    static func gymRestSeconds(_ arg1: Int) -> String {
        String(format: String(localized: "gym.rest_seconds"), arg1)
    }

    /// Serie %1$lld hecha · %2$@
    static func gymSetConfirm(_ arg1: Int, _ arg2: String) -> String {
        String(format: String(localized: "gym.set.confirm"), arg1, arg2)
    }

    /// Corregir la serie %lld
    static func gymSetEdit(_ arg1: Int) -> String {
        String(format: String(localized: "gym.set.edit"), arg1)
    }

    /// Serie extra
    static var gymSetExtra: String { String(localized: "gym.set.extra") }

    /// Ir al ejercicio siguiente
    static var gymSetNextExercise: String { String(localized: "gym.set.next_exercise") }

    /// Repeticiones
    static var gymSetReps: String { String(localized: "gym.set.reps") }

    /// Segundos
    static var gymSetSeconds: String { String(localized: "gym.set.seconds") }

    /// Saltear
    static var gymSetSkip: String { String(localized: "gym.set.skip") }

    /// Salteada
    static var gymSetSkipped: String { String(localized: "gym.set.skipped") }

    /// Peso
    static var gymSetWeight: String { String(localized: "gym.set.weight") }

    /// Serie %lld
    static func gymSetNumber(_ arg1: Int) -> String {
        String(format: String(localized: "gym.set_number"), arg1)
    }

    /// series completadas · 45 min estimados
    static var gymSetsCompleted: String { String(localized: "gym.sets_completed") }

    /// Jue 28 ago · tren superior y core
    static var gymSubtitle: String { String(localized: "gym.subtitle") }

    /// Todas tus salidas
    static var historyAllWorkouts: String { String(localized: "history.all_workouts") }

    /// Cerrar
    static var historyClose: String { String(localized: "history.close") }

    /// Tocá ⚡ para empezar la primera. Cuando la termines, aparece acá con su mapa, sus parciales y sus pausas.
    static var historyEmptyBody: String { String(localized: "history.empty.body") }

    /// Empezar mi primera salida
    static var historyEmptyStartFirst: String { String(localized: "history.empty.start_first") }

    /// Todavía no hay salidas
    static var historyEmptyTitle: String { String(localized: "history.empty.title") }

    /// No se pudo cargar el historial. Probá de nuevo.
    static var historyError: String { String(localized: "history.error") }

    /// Cargar más
    static var historyLoadMore: String { String(localized: "history.load_more") }

    /// Cargando…
    static var historyLoading: String { String(localized: "history.loading") }

    /// Esta actividad no tiene recorrido GPS guardado.
    static var historyNoRoute: String { String(localized: "history.no_route") }

    /// Abre tus salidas anteriores
    static var historyOpensPastWorkouts: String { String(localized: "history.opens_past_workouts") }

    /// Desde el 1 de este mes
    static var historyPeriodMonthDetail: String { String(localized: "history.period.month_detail") }

    /// Desde el lunes hasta hoy
    static var historyPeriodWeekDetail: String { String(localized: "history.period.week_detail") }

    /// Abre el mapa, los parciales y las pausas de esta salida
    static var historyRowHint: String { String(localized: "history.row.hint") }

    /// Reloj
    static var historySourceWatch: String { String(localized: "history.source.watch") }

    /// Todo lo que entrenaste
    static var historySubtitle: String { String(localized: "history.subtitle") }

    /// Historial
    static var historyTab: String { String(localized: "history.tab") }

    /// tocá una para ver el detalle
    static var historyTapOneForDetail: String { String(localized: "history.tap_one_for_detail") }

    /// Mis actividades
    static var historyTitle: String { String(localized: "history.title") }

    /// %@. Suma lo cargado hasta ahora: tocá «Cargar más» abajo para sumar las anteriores.
    static func historyTotalsPartialNote(_ arg1: String) -> String {
        String(format: String(localized: "history.totals.partial_note"), arg1)
    }

    /// Ver detalle
    static var historyViewDetail: String { String(localized: "history.view_detail") }

    /// Salidas
    static var historyWorkouts: String { String(localized: "history.workouts") }

    /// %lld salidas
    static func historyWorkoutsCount(_ arg1: Int) -> String {
        String(format: String(localized: "history.workouts_count"), arg1)
    }

    /// 1 salida
    static var historyWorkoutsOne: String { String(localized: "history.workouts_one") }

    /// Tus números
    static var historyYourNumbers: String { String(localized: "history.your_numbers") }

    /// Tus salidas
    static var historyYourWorkouts: String { String(localized: "history.your_workouts") }

    /// Elegir objetivo
    static var homeChooseGoal: String { String(localized: "home.choose_goal") }

    /// Elegí tu próxima carrera y armamos el plan semana a semana.
    static var homeChooseNextRace: String { String(localized: "home.choose_next_race") }

    /// Todavía no hay nada para mostrar acá.
    static var homeDataEmpty: String { String(localized: "home.data.empty") }

    /// No pudimos traer esto del servidor. Probá de nuevo en un rato.
    static var homeDataError: String { String(localized: "home.data.error") }

    /// Buscando lo último…
    static var homeDataLoading: String { String(localized: "home.data.loading") }

    /// Sin conexión, y en este teléfono todavía no hay nada guardado para mostrar. Se carga solo cuando vuelva la señ
    static var homeDataOffline: String { String(localized: "home.data.offline") }

    /// Esto se calcula con tu perfil, y le faltan datos: completalo desde el inicio.
    static var homeDataProfileIncomplete: String { String(localized: "home.data.profile_incomplete") }

    /// Reintentar
    static var homeDataRetry: String { String(localized: "home.data.retry") }

    /// Sin conexión: esto es lo que se guardó %@.
    static func homeDataSavedOffline(_ arg1: String) -> String {
        String(format: String(localized: "home.data.saved_offline"), arg1)
    }

    /// No se pudo actualizar: esto es lo que se guardó %@.
    static func homeDataSavedWithError(_ arg1: String) -> String {
        String(format: String(localized: "home.data.saved_with_error"), arg1)
    }

    /// Ingresá tu nuevo objetivo
    static var homeEnterNewGoal: String { String(localized: "home.enter_new_goal") }

    /// Al volver
    static var homeExplainerAfter: String { String(localized: "home.explainer.after") }

    /// Antes de salir
    static var homeExplainerBefore: String { String(localized: "home.explainer.before") }

    /// Carbohidratos
    static var homeExplainerCarbs: String { String(localized: "home.explainer.carbs") }

    /// Carbohidratos y proteína para recuperarte.
    static var homeExplainerCarbsAfter: String { String(localized: "home.explainer.carbs_after") }

    /// Carbohidratos en la comida previa, para salir con energía.
    static var homeExplainerCarbsBefore: String { String(localized: "home.explainer.carbs_before") }

    /// La energía que tu cuerpo usa más rápido. Es lo que conviene sumar por cada hora, entre geles, bebida deportiva
    static var homeExplainerCarbsBody: String { String(localized: "home.explainer.carbs_body") }

    /// Lo que conviene tomar en esta salida, calculado con tu peso y la sesión de hoy.
    static var homeExplainerFuelingBody: String { String(localized: "home.explainer.fueling_body") }

    /// Geles
    static var homeExplainerGels: String { String(localized: "home.explainer.gels") }

    /// Sobres de carbohidratos rápidos. Tomalos con agua, repartidos durante la salida.
    static var homeExplainerGelsBody: String { String(localized: "home.explainer.gels_body") }

    /// Hoy no hacen falta: con el agua alcanza.
    static var homeExplainerNotNeededToday: String { String(localized: "home.explainer.not_needed_today") }

    /// Sodio
    static var homeExplainerSodium: String { String(localized: "home.explainer.sodium") }

    /// Las sales que perdés al transpirar. Van en una bebida con electrolitos o en pastillas de sal.
    static var homeExplainerSodiumBody: String { String(localized: "home.explainer.sodium_body") }

    /// Agua
    static var homeExplainerWater: String { String(localized: "home.explainer.water") }

    /// Lo que conviene tomar por cada hora: mejor en sorbos chicos y seguidos que todo de golpe.
    static var homeExplainerWaterBody: String { String(localized: "home.explainer.water_body") }

    /// Qué llevar hoy
    static var homeExplainerWhatToBringToday: String { String(localized: "home.explainer.what_to_bring_today") }

    /// En toda la salida: %@.
    static func homeExplainerWholeWorkout(_ arg1: String) -> String {
        String(format: String(localized: "home.explainer.whole_workout"), arg1)
    }

    /// Salida de %lld min
    static func homeExplainerWorkoutMinutes(_ arg1: Int) -> String {
        String(format: String(localized: "home.explainer.workout_minutes"), arg1)
    }

    /// Muy suave. Podrías charlar sin parar. Sirve para recuperar.
    static var homeExplainerZone1: String { String(localized: "home.explainer.zone1") }

    /// Cómoda. Hablás en frases completas. Es la que arma tu base y la que más vas a usar.
    static var homeExplainerZone2: String { String(localized: "home.explainer.zone2") }

    /// Exigente pero sostenible. Te salen frases cortas. Afina tu ritmo de carrera.
    static var homeExplainerZone3: String { String(localized: "home.explainer.zone3") }

    /// Dura. Sólo palabras sueltas. Va en tramos, para subir tu umbral.
    static var homeExplainerZone4: String { String(localized: "home.explainer.zone4") }

    /// Al máximo. No podés hablar. Tramos muy cortos, para la velocidad.
    static var homeExplainerZone5: String { String(localized: "home.explainer.zone5") }

    /// La zona dice qué tan fuerte ir. La forma más simple de medirla: cuánto podés hablar mientras te movés.
    static var homeExplainerZonesBody: String { String(localized: "home.explainer.zones_body") }

    /// Zonas de intensidad
    static var homeExplainerZonesTitle: String { String(localized: "home.explainer.zones_title") }

    /// %lld gel
    static func homeGelCount(_ arg1: Int) -> String {
        String(format: String(localized: "home.gel_count"), arg1)
    }

    /// Buenas tardes
    static var homeGreetingAfternoon: String { String(localized: "home.greeting.afternoon") }

    /// Buenas noches
    static var homeGreetingEvening: String { String(localized: "home.greeting.evening") }

    /// Buen día
    static var homeGreetingMorning: String { String(localized: "home.greeting.morning") }

    /// %1$lld ml/h y %2$lld g de carbos/h · %3$@ es intensidad %4$@
    static func homeHydrationNote(_ arg1: Int, _ arg2: Int, _ arg3: String, _ arg4: String) -> String {
        String(format: String(localized: "home.hydration_note"), arg1, arg2, arg3, arg4)
    }

    /// Hidratación %lld ml/h
    static func homeHydrationRate(_ arg1: Int) -> String {
        String(format: String(localized: "home.hydration_rate"), arg1)
    }

    /// Sin objetivo activo
    static var homeNoActiveGoal: String { String(localized: "home.no_active_goal") }

    /// Hoy no hay nada planificado
    static var homeNothingPlannedToday: String { String(localized: "home.nothing_planned_today") }

    /// de %@ previstos
    static func homeOfPlanned(_ arg1: String) -> String {
        String(format: String(localized: "home.of_planned"), arg1)
    }

    /// Preparar salida
    static var homePrepareWorkout: String { String(localized: "home.prepare_workout") }

    /// A tu perfil le faltan datos que usa el plan.
    static var homeProfileIncompleteBody: String { String(localized: "home.profile_incomplete.body") }

    /// Completar perfil
    static var homeProfileIncompleteButton: String { String(localized: "home.profile_incomplete.button") }

    /// Volver a la salida
    static var homeShortcutsBackToWorkout: String { String(localized: "home.shortcuts.back_to_workout") }

    /// Abre todo lo que hiciste
    static var homeShortcutsHistoryHint: String { String(localized: "home.shortcuts.history.hint") }

    /// Abre tu apto físico
    static var homeShortcutsMedicalHint: String { String(localized: "home.shortcuts.medical.hint") }

    /// Abre tu plan semana a semana
    static var homeShortcutsPlanHint: String { String(localized: "home.shortcuts.plan.hint") }

    /// Empezar salida
    static var homeShortcutsStartWorkout: String { String(localized: "home.shortcuts.start_workout") }

    /// Accesos rápidos
    static var homeShortcutsTitle: String { String(localized: "home.shortcuts.title") }

    /// Ver mi plan
    static var homeShortcutsViewPlan: String { String(localized: "home.shortcuts.view_plan") }

    /// Abre el entreno con GPS
    static var homeShortcutsWorkoutHint: String { String(localized: "home.shortcuts.workout.hint") }

    /// Sugerido %@
    static func homeSuggested(_ arg1: String) -> String {
        String(format: String(localized: "home.suggested"), arg1)
    }

    /// Gimnasio
    static var homeTabGym: String { String(localized: "home.tab.gym") }

    /// Inicio
    static var homeTabHome: String { String(localized: "home.tab.home") }

    /// Plan
    static var homeTabPlan: String { String(localized: "home.tab.plan") }

    /// Perfil
    static var homeTabProfile: String { String(localized: "home.tab.profile") }

    /// Entreno
    static var homeTabWorkout: String { String(localized: "home.tab.workout") }

    /// Entrenamientos de hoy
    static var homeTodayWorkouts: String { String(localized: "home.today_workouts") }

    /// para tu %@
    static func homeUntilYour(_ arg1: String) -> String {
        String(format: String(localized: "home.until_your"), arg1)
    }

    /// Ver historial
    static var homeViewHistory: String { String(localized: "home.view_history") }

    /// Ver plan
    static var homeViewPlan: String { String(localized: "home.view_plan") }

    /// Ver la rutina
    static var homeViewRoutine: String { String(localized: "home.view_routine") }

    /// Carga semanal
    static var homeWeeklyLoad: String { String(localized: "home.weekly_load") }

    /// Día %lld
    static func homeWeeklyLoadDayNumber(_ arg1: Int) -> String {
        String(format: String(localized: "home.weekly_load.day_number"), arg1)
    }

    /// Los km de esta semana: lo hecho contra lo previsto. Cada barra es un día; tocala para verlo.
    static var homeWeeklyLoadGuide: String { String(localized: "home.weekly_load.guide") }

    /// Sin km
    static var homeWeeklyLoadNoKm: String { String(localized: "home.weekly_load.no_km") }

    /// ¿Qué es?
    static var homeWhatIsIt: String { String(localized: "home.what_is_it") }

    /// Qué llevar
    static var homeWhatToBring: String { String(localized: "home.what_to_bring") }

    /// Explica qué llevar en la salida
    static var homeWhatToBringHint: String { String(localized: "home.what_to_bring.hint") }

    /// Salida en curso
    static var homeWorkoutInProgress: String { String(localized: "home.workout_in_progress") }

    /// Tu día
    static var homeYourDay: String { String(localized: "home.your_day") }

    /// Explica qué son las zonas de intensidad
    static var homeZonesHint: String { String(localized: "home.zones.hint") }

    /// Ya hay una cuenta con este correo.
    static var legalAccountExists: String { String(localized: "legal.account_exists") }

    /// Crear mi cuenta
    static var legalCreateAccount: String { String(localized: "legal.create_account") }

    /// Ya tengo cuenta, iniciar sesión
    static var legalGoToLogin: String { String(localized: "legal.go_to_login") }

    /// Estamos trayendo el aviso de salud del servidor.
    static var legalLoading: String { String(localized: "legal.loading") }

    /// Marcá que leíste el aviso para poder crear la cuenta.
    static var legalMustAccept: String { String(localized: "legal.must_accept") }

    /// No pudimos traer el aviso de salud. Sin leerlo no se puede crear la cuenta. Probá de nuevo cuando tengas señal
    static var legalNoText: String { String(localized: "legal.no_text") }

    /// Este texto todavía no lo revisó nadie con formación legal. Es un borrador y se va a reemplazar.
    static var legalNotReviewed: String { String(localized: "legal.not_reviewed") }

    /// Probar de nuevo
    static var legalRetry: String { String(localized: "legal.retry") }

    /// Entrar con ese correo
    static var legalSignInWithEmail: String { String(localized: "legal.sign_in_with_email") }

    /// Este registro ya se usó: lo más probable es que tu cuenta ya exista. Probá entrar con tu correo y tu contraseñ
    static var legalSignupAlreadyCreated: String { String(localized: "legal.signup_already_created") }

    /// Empezar de nuevo desde el correo
    static var legalStartOver: String { String(localized: "legal.start_over") }

    /// Aviso de salud
    static var legalTitle: String { String(localized: "legal.title") }

    /// Leer los términos y condiciones
    static var legalViewTerms: String { String(localized: "legal.view_terms") }

    /// Continuar con Apple
    static var loginApple: String { String(localized: "login.apple") }

    /// Error al iniciar sesión
    static var loginErrorTitle: String { String(localized: "login.error.title") }

    /// ¿Olvidaste tu contraseña?
    static var loginForgotPassword: String { String(localized: "login.forgot_password") }

    /// Continuar con Google
    static var loginGoogle: String { String(localized: "login.google") }

    /// ¿No tenés cuenta?
    static var loginNoAccount: String { String(localized: "login.no_account") }

    /// o
    static var loginOr: String { String(localized: "login.or") }

    /// Contraseña
    static var loginPasswordLabel: String { String(localized: "login.password_label") }

    /// Ingresar
    static var loginSignIn: String { String(localized: "login.sign_in") }

    /// Registrate
    static var loginSignUp: String { String(localized: "login.sign_up") }

    /// Google y Apple todavía no: el servidor no tiene ese camino.
    static var loginSocialUnavailable: String { String(localized: "login.social_unavailable") }

    /// Iniciar sesión
    static var loginTitle: String { String(localized: "login.title") }

    /// Brújula, orientación %1$@, %2$lld grados
    static func mapCompassAccessibility(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "map.compass.accessibility"), arg1, arg2)
    }

    /// Con un apto vigente, Stamina puede darte sugerencias en carrera.
    static var medicalAddBody: String { String(localized: "medical.add_body") }

    /// Cargá tu apto físico
    static var medicalAddTitle: String { String(localized: "medical.add_title") }

    /// El certificado que te dio tu médico
    static var medicalCertificateDetail: String { String(localized: "medical.certificate_detail") }

    /// Borrar apto guardado
    static var medicalDelete: String { String(localized: "medical.delete") }

    /// Stamina no reemplaza la consulta médica. Tu apto se guarda sólo en este teléfono, protegido, y no se comparte 
    static var medicalDisclaimer: String { String(localized: "medical.disclaimer") }

    /// No pudimos abrir ese archivo. Probá con otro.
    static var medicalErrorOpenFailed: String { String(localized: "medical.error.open_failed") }

    /// No pudimos guardar el apto. Probá de nuevo.
    static var medicalErrorSaveFailed: String { String(localized: "medical.error.save_failed") }

    /// El archivo pesa más de 15 MB. Probá con una foto más liviana.
    static var medicalErrorTooLarge: String { String(localized: "medical.error.too_large") }

    /// Vencimiento
    static var medicalExpiration: String { String(localized: "medical.expiration") }

    /// Fecha de vencimiento
    static var medicalExpirationDate: String { String(localized: "medical.expiration_date") }

    /// Tu apto físico vence en 30 días
    static var medicalExpiresIn30Days: String { String(localized: "medical.expires_in_30_days") }

    /// Tu apto vence en %lld días
    static func medicalExpiresInDays(_ arg1: Int) -> String {
        String(format: String(localized: "medical.expires_in_days"), arg1)
    }

    /// Vence el %@
    static func medicalExpiresOn(_ arg1: String) -> String {
        String(format: String(localized: "medical.expires_on"), arg1)
    }

    /// Tu apto vence hoy
    static var medicalExpiresToday: String { String(localized: "medical.expires_today") }

    /// Archivo del apto: %@. Tocá para cambiarlo.
    static func medicalFileAccessibility(_ arg1: String) -> String {
        String(format: String(localized: "medical.file.accessibility"), arg1)
    }

    /// Elegí el archivo, la fecha y marcá la declaración.
    static var medicalFormIncomplete: String { String(localized: "medical.form_incomplete") }

    /// Listo para guardar
    static var medicalReadyToSave: String { String(localized: "medical.ready_to_save") }

    /// Renovalo para seguir recibiendo sugerencias en carrera.
    static var medicalRenewBody: String { String(localized: "medical.renew_body") }

    /// Apto vencido · renovalo
    static var medicalStatusExpired: String { String(localized: "medical.status.expired") }

    /// Apto vigente · vence en %lld días
    static func medicalStatusValidDaysLeft(_ arg1: Int) -> String {
        String(format: String(localized: "medical.status.valid_days_left"), arg1)
    }

    /// Declaración jurada
    static var medicalSwornStatement: String { String(localized: "medical.sworn_statement") }

    /// Declaro que mis datos de salud son verdaderos
    static var medicalSwornStatementDeclare: String { String(localized: "medical.sworn_statement.declare") }

    /// Apto físico
    static var medicalTitle: String { String(localized: "medical.title") }

    /// Subir foto o PDF
    static var medicalUpload: String { String(localized: "medical.upload") }

    /// Subir el apto, foto o PDF
    static var medicalUploadAccessibility: String { String(localized: "medical.upload_accessibility") }

    /// Vigente · te avisamos 30 días antes
    static var medicalValidReminder: String { String(localized: "medical.valid_reminder") }

    /// Tu apto físico
    static var medicalYourClearance: String { String(localized: "medical.your_clearance") }

    /// Días activos
    static var milestonesActiveDays: String { String(localized: "milestones.active_days") }

    /// actividad alta
    static var milestonesActivityHigh: String { String(localized: "milestones.activity.high") }

    /// actividad suave
    static var milestonesActivityLight: String { String(localized: "milestones.activity.light") }

    /// actividad moderada
    static var milestonesActivityModerate: String { String(localized: "milestones.activity.moderate") }

    /// sin actividad
    static var milestonesActivityNone: String { String(localized: "milestones.activity.none") }

    /// actividad muy alta
    static var milestonesActivityVeryHigh: String { String(localized: "milestones.activity.very_high") }

    /// El borde de color marca hoy; el borde grueso, el día que elegiste.
    static var milestonesCalendarBorderHint: String { String(localized: "milestones.calendar.border_hint") }

    /// Cada cuadrito es un día. Tocalo para ver qué hiciste.
    static var milestonesCalendarHint: String { String(localized: "milestones.calendar.hint") }

    /// Cerrada
    static var milestonesCollapsed: String { String(localized: "milestones.collapsed") }

    /// Entrenamientos realizados
    static var milestonesCompletedWorkouts: String { String(localized: "milestones.completed_workouts") }

    /// Distancia del día
    static var milestonesDayDistance: String { String(localized: "milestones.day_distance") }

    /// Añadir 1 km running a este día
    static var milestonesDebugAddKm: String { String(localized: "milestones.debug.add_km") }

    /// Abierta
    static var milestonesExpanded: String { String(localized: "milestones.expanded") }

    /// Alto: dos salidas, o %@ o más en el día.
    static func milestonesLevelHigh(_ arg1: String) -> String {
        String(format: String(localized: "milestones.level.high"), arg1)
    }

    /// Suave: una salida corta (menos de %@) o %@ pasos o más.
    static func milestonesLevelLight(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "milestones.level.light"), arg1, arg2)
    }

    /// Moderado: %@ o más en el día, o %@ pasos o más.
    static func milestonesLevelModerate(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "milestones.level.moderate"), arg1, arg2)
    }

    /// Sin actividad: ni salidas ni pasos que lleguen a %@.
    static func milestonesLevelNone(_ arg1: String) -> String {
        String(format: String(localized: "milestones.level.none"), arg1)
    }

    /// Muy alto: tres salidas o más, o %@ o más en el día.
    static func milestonesLevelVeryHigh(_ arg1: String) -> String {
        String(format: String(localized: "milestones.level.very_high"), arg1)
    }

    /// sin entrenamientos
    static var milestonesNoWorkouts: String { String(localized: "milestones.no_workouts") }

    /// No se registraron salidas deportivas este día.
    static var milestonesNoWorkoutsDay: String { String(localized: "milestones.no_workouts_day") }

    /// Día de descanso
    static var milestonesRestDay: String { String(localized: "milestones.rest_day") }

    /// Sesiones
    static var milestonesSessions: String { String(localized: "milestones.sessions") }

    /// Cantidad de pasos
    static var milestonesStepsCount: String { String(localized: "milestones.steps.count") }

    /// Registrar pasos
    static var milestonesStepsLog: String { String(localized: "milestones.steps.log") }

    /// Pasos registrados en el día
    static var milestonesStepsLogged: String { String(localized: "milestones.steps.logged") }

    /// Ingresá la cantidad de pasos para el día seleccionado:
    static var milestonesStepsPrompt: String { String(localized: "milestones.steps.prompt") }

    /// Apple Salud
    static var milestonesStepsSourceAppleHealth: String { String(localized: "milestones.steps.source.apple_health") }

    /// Health Connect
    static var milestonesStepsSourceHealthConnect: String { String(localized: "milestones.steps.source.health_connect") }

    /// Manual
    static var milestonesStepsSourceManual: String { String(localized: "milestones.steps.source.manual") }

    /// Distancia total
    static var milestonesTotalDistance: String { String(localized: "milestones.total_distance") }

    /// ¿Qué significa?
    static var milestonesWhatItMeans: String { String(localized: "milestones.what_it_means") }

    /// %lld entrenamientos
    static func milestonesWorkoutsCount(_ arg1: Int) -> String {
        String(format: String(localized: "milestones.workouts_count"), arg1)
    }

    /// 1 entrenamiento
    static var milestonesWorkoutsOne: String { String(localized: "milestones.workouts_one") }

    /// Tu año
    static var milestonesYourYear: String { String(localized: "milestones.your_year") }

    /// %1$lld °C a la hora de entrenar (sensación %2$lld °C). Revisá el horario y llevá agua. Datos:  Weather.
    static func notificationHeatBody(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "notification.heat.body"), arg1, arg2)
    }

    /// Calor previsto para entrenar
    static var notificationHeatTitle: String { String(localized: "notification.heat.title") }

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

    /// Enviamos un código de 6 caracteres, con números y letras, a %@. Puede tardar hasta un minuto; si no aparece, r
    static func passwordResetCodeBody(_ arg1: String) -> String {
        String(format: String(localized: "password.reset.code.body"), arg1)
    }

    /// Revisá tu correo
    static var passwordResetCodeTitle: String { String(localized: "password.reset.code.title") }

    /// Verificar código
    static var passwordResetCodeVerify: String { String(localized: "password.reset.code.verify") }

    /// Cuenta
    static var passwordResetDoneAccount: String { String(localized: "password.reset.done.account") }

    /// Ya podés entrar con tu contraseña nueva. Cerramos la sesión en los otros dispositivos: si no fuiste vos quien 
    static var passwordResetDoneBody: String { String(localized: "password.reset.done.body") }

    /// Cambio hecho
    static var passwordResetDoneChanged: String { String(localized: "password.reset.done.changed") }

    /// Ir a mi inicio
    static var passwordResetDoneGoHome: String { String(localized: "password.reset.done.go_home") }

    /// Contraseña actualizada
    static var passwordResetDoneTitle: String { String(localized: "password.reset.done.title") }

    /// Por seguridad, el mensaje se envía aunque el correo no esté registrado.
    static var passwordResetEmailAntiEnumeration: String { String(localized: "password.reset.email.anti_enumeration") }

    /// Escribí el correo con el que creaste tu cuenta y te enviamos un código para elegir una contraseña nueva. Tu pl
    static var passwordResetEmailBody: String { String(localized: "password.reset.email.body") }

    /// Enviarme el código
    static var passwordResetEmailSend: String { String(localized: "password.reset.email.send") }

    /// Recuperar tu contraseña
    static var passwordResetEmailTitle: String { String(localized: "password.reset.email.title") }

    /// Error al recuperar contraseña
    static var passwordResetErrorTitle: String { String(localized: "password.reset.error.title") }

    /// Al menos 10 caracteres, con una mayúscula y un número. Cuando la guardes vamos a cerrar la sesión en los otros
    static var passwordResetNewBody: String { String(localized: "password.reset.new.body") }

    /// Nueva contraseña
    static var passwordResetNewLabel: String { String(localized: "password.reset.new.label") }

    /// Las dos contraseñas coinciden.
    static var passwordResetNewMatch: String { String(localized: "password.reset.new.match") }

    /// Las dos contraseñas no coinciden.
    static var passwordResetNewNoMatch: String { String(localized: "password.reset.new.no_match") }

    /// Repetir contraseña
    static var passwordResetNewRepeatLabel: String { String(localized: "password.reset.new.repeat_label") }

    /// Al menos 10 caracteres
    static var passwordResetNewRuleLength: String { String(localized: "password.reset.new.rule_length") }

    /// Un número
    static var passwordResetNewRuleNumber: String { String(localized: "password.reset.new.rule_number") }

    /// Una letra mayúscula
    static var passwordResetNewRuleUppercase: String { String(localized: "password.reset.new.rule_uppercase") }

    /// Guardar contraseña
    static var passwordResetNewSave: String { String(localized: "password.reset.new.save") }

    /// Fuerza de la contraseña: %lld de 3 reglas cumplidas
    static func passwordResetNewStrength(_ arg1: Int) -> String {
        String(format: String(localized: "password.reset.new.strength"), arg1)
    }

    /// Elegí una contraseña nueva
    static var passwordResetNewTitle: String { String(localized: "password.reset.new.title") }

    /// Etapa actual: %@
    static func planCurrentPhase(_ arg1: String) -> String {
        String(format: String(localized: "plan.current_phase"), arg1)
    }

    /// Se habilita ese día: la vas a poder empezar desde acá o desde Inicio.
    static var planDayAvailableThatDay: String { String(localized: "plan.day.available_that_day") }

    /// %lld g de carbohidratos por hora
    static func planDayCarbsPerHour(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.carbs_per_hour"), arg1)
    }

    /// Cerrado
    static var planDayCollapsed: String { String(localized: "plan.day.collapsed") }

    /// Abierto
    static var planDayExpanded: String { String(localized: "plan.day.expanded") }

    /// Lo que el plan llama avituallamiento: agua, geles y sales para no quedarte sin energía en la salida.
    static var planDayFuelingBody: String { String(localized: "plan.day.fueling_body") }

    /// 1 gel
    static var planDayGelOne: String { String(localized: "plan.day.gel_one") }

    /// %lld geles
    static func planDayGelsCount(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.gels_count"), arg1)
    }

    /// Este día ya pasó. No pasa nada: el plan sigue con lo que viene.
    static var planDayPast: String { String(localized: "plan.day.past") }

    /// Hoy toca descansar. El cuerpo se hace más fuerte mientras se recupera: caminar o elongar suave está bien.
    static var planDayRest: String { String(localized: "plan.day.rest") }

    /// Alternás tramos de trote con tramos de caminata.
    static var planDayRunWalk: String { String(localized: "plan.day.run_walk") }

    /// 1 toma de sales
    static var planDaySaltDoseOne: String { String(localized: "plan.day.salt_dose_one") }

    /// %lld tomas de sales
    static func planDaySaltDosesCount(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.salt_doses_count"), arg1)
    }

    /// Cómo es la sesión
    static var planDaySessionShape: String { String(localized: "plan.day.session_shape") }

    /// %lld mg de sodio
    static func planDaySodiumMg(_ arg1: Int) -> String {
        String(format: String(localized: "plan.day.sodium_mg"), arg1)
    }

    /// Empezar esta salida
    static var planDayStartWorkout: String { String(localized: "plan.day.start_workout") }

    /// Día de fuerza: ejercicios que protegen tus piernas y te hacen correr con menos esfuerzo.
    static var planDayStrength: String { String(localized: "plan.day.strength") }

    /// Tocá para cerrar el detalle
    static var planDayTapToClose: String { String(localized: "plan.day.tap_to_close") }

    /// Tocá para ver qué hacer y por qué
    static var planDayTapToSee: String { String(localized: "plan.day.tap_to_see") }

    /// Ver en tu historial
    static var planDayViewInHistory: String { String(localized: "plan.day.view_in_history") }

    /// Ver rutina
    static var planDayViewRoutine: String { String(localized: "plan.day.view_routine") }

    /// Qué es %@
    static func planDayWhatIs(_ arg1: String) -> String {
        String(format: String(localized: "plan.day.what_is"), arg1)
    }

    /// Qué llevar para tomar
    static var planDayWhatToBring: String { String(localized: "plan.day.what_to_bring") }

    /// Por qué hoy
    static var planDayWhyToday: String { String(localized: "plan.day.why_today") }

    /// Muy suave: podés charlar sin esfuerzo. Sirve para recuperarte.
    static var planDayZone1: String { String(localized: "plan.day.zone1") }

    /// Suave y cómodo: podés hablar en frases completas. Construye resistencia sin cansarte de más.
    static var planDayZone2: String { String(localized: "plan.day.zone2") }

    /// Moderado: hablás con frases cortas. Mejora el ritmo que podés sostener mucho rato.
    static var planDayZone3: String { String(localized: "plan.day.zone3") }

    /// Fuerte: te salen pocas palabras. Sube el ritmo que aguantás antes de cansarte.
    static var planDayZone4: String { String(localized: "plan.day.zone4") }

    /// Al máximo: no podés hablar. Son esfuerzos cortos para ganar velocidad.
    static var planDayZone5: String { String(localized: "plan.day.zone5") }

    /// Hecho
    static var planDone: String { String(localized: "plan.done") }

    /// Muestra el plan de esta meta
    static var planGoalHint: String { String(localized: "plan.goal.hint") }

    /// %1$@ de %2$@
    static func planKmOf(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "plan.km_of"), arg1, arg2)
    }

    /// Sin fecha de carrera
    static var planNoRaceDate: String { String(localized: "plan.no_race_date") }

    /// Base
    static var planPhaseBase: String { String(localized: "plan.phase.base") }

    /// Es el cimiento: mucho trote suave para que el corazón, las piernas y los tendones se acostumbren a correr segu
    static var planPhaseBaseBody: String { String(localized: "plan.phase.base.body") }

    /// Si sentís que vas lento, está bien: es a propósito.
    static var planPhaseBaseTip: String { String(localized: "plan.phase.base.tip") }

    /// Construcción
    static var planPhaseBuild: String { String(localized: "plan.phase.build") }

    /// Se suma carga de a poco: más kilómetros y algunas sesiones a ritmo para ganar resistencia y velocidad.
    static var planPhaseBuildBody: String { String(localized: "plan.phase.build.body") }

    /// Algunas semanas cuestan más; las más livianas están para que el cuerpo lo absorba.
    static var planPhaseBuildTip: String { String(localized: "plan.phase.build.tip") }

    /// Completada
    static var planPhaseCompleted: String { String(localized: "plan.phase.completed") }

    /// Una etapa con un objetivo propio. Los días de cada semana ya la tienen en cuenta: seguilos y listo.
    static var planPhaseGenericBody: String { String(localized: "plan.phase.generic.body") }

    /// Explica para qué sirve esta etapa
    static var planPhaseHint: String { String(localized: "plan.phase.hint") }

    /// Pico
    static var planPhasePeak: String { String(localized: "plan.phase.peak") }

    /// Las semanas más exigentes: el fondo más largo y los entrenamientos más parecidos a la carrera.
    static var planPhasePeakBody: String { String(localized: "plan.phase.peak.body") }

    /// Dormí y comé bien: acá el cansancio es esperable.
    static var planPhasePeakTip: String { String(localized: "plan.phase.peak.tip") }

    /// Carrera
    static var planPhaseRace: String { String(localized: "plan.phase.race") }

    /// La semana de la carrera: poco y suave, para llegar con las piernas frescas.
    static var planPhaseRaceBody: String { String(localized: "plan.phase.race.body") }

    /// No estrenes nada el día de la carrera: ni zapatillas ni geles.
    static var planPhaseRaceTip: String { String(localized: "plan.phase.race.tip") }

    /// Afinamiento
    static var planPhaseTaper: String { String(localized: "plan.phase.taper") }

    /// Baja el volumen para que llegues descansado sin perder la chispa: menos kilómetros y algo de ritmo.
    static var planPhaseTaperBody: String { String(localized: "plan.phase.taper.body") }

    /// Si te sobra energía, es la idea. No agregues kilómetros de más.
    static var planPhaseTaperTip: String { String(localized: "plan.phase.taper.tip") }

    /// Más adelante
    static var planPhaseUpcoming: String { String(localized: "plan.phase.upcoming") }

    /// Estás acá
    static var planPhaseYouAreHere: String { String(localized: "plan.phase.you_are_here") }

    /// Cada etapa tiene un objetivo distinto. Tocá una para ver para qué sirve.
    static var planPhasesIntro: String { String(localized: "plan.phases.intro") }

    /// Las etapas de tu plan
    static var planPhasesTitle: String { String(localized: "plan.phases.title") }

    /// %1$@ · semana %2$lld de %3$lld
    static func planSubtitle(_ arg1: String, _ arg2: Int, _ arg3: Int) -> String {
        String(format: String(localized: "plan.subtitle"), arg1, arg2, arg3)
    }

    /// Tu plan
    static var planTitle: String { String(localized: "plan.title") }

    /// HOY
    static var planTodayBadge: String { String(localized: "plan.today_badge") }

    /// para tu carrera
    static var planUntilRace: String { String(localized: "plan.until_race") }

    /// Semana %lld
    static func planWeek(_ arg1: Int) -> String {
        String(format: String(localized: "plan.week"), arg1)
    }

    /// S%lld
    static func planWeekChip(_ arg1: Int) -> String {
        String(format: String(localized: "plan.week.chip"), arg1)
    }

    /// ¡Semana cumplida! Todo lo previsto está hecho.
    static var planWeekComplete: String { String(localized: "plan.week.complete") }

    /// Semana %lld · en curso
    static func planWeekInProgress(_ arg1: Int) -> String {
        String(format: String(localized: "plan.week.in_progress"), arg1)
    }

    /// Te faltan %@ para completar la semana.
    static func planWeekLeftToComplete(_ arg1: String) -> String {
        String(format: String(localized: "plan.week.left_to_complete"), arg1)
    }

    /// Semana siguiente
    static var planWeekNext: String { String(localized: "plan.week.next") }

    /// Sin kilómetros registrados en esta semana.
    static var planWeekNoKmLogged: String { String(localized: "plan.week.no_km_logged") }

    /// Esta semana no tiene kilómetros previstos.
    static var planWeekNoKmPlanned: String { String(localized: "plan.week.no_km_planned") }

    /// Todavía no sumaste kilómetros esta semana.
    static var planWeekNoKmYet: String { String(localized: "plan.week.no_km_yet") }

    /// Semana anterior
    static var planWeekPrevious: String { String(localized: "plan.week.previous") }

    /// Deslizá los días de costado para cambiar de semana
    static var planWeekSwipeHint: String { String(localized: "plan.week.swipe_hint") }

    /// Faltan %lld semanas
    static func planWeeksLeft(_ arg1: Int) -> String {
        String(format: String(localized: "plan.weeks_left"), arg1)
    }

    /// Aviso 45 min antes para preparar bidones, geles y el snack pre-entreno.
    static var previewBeforeBody: String { String(localized: "preview.before_body") }

    /// Y antes de salir
    static var previewBeforeLabel: String { String(localized: "preview.before_label") }

    /// 750 ml/h
    static var previewChipFluid: String { String(localized: "preview.chip.fluid") }

    /// 1 gel c/45′
    static var previewChipGel: String { String(localized: "preview.chip.gel") }

    /// 600 mg sodio
    static var previewChipSodium: String { String(localized: "preview.chip.sodium") }

    /// Armemos tu plan en 2 minutos
    static var previewCtaTitle: String { String(localized: "preview.cta_title") }

    /// ¿Ya tenés cuenta?
    static var previewHaveAccount: String { String(localized: "preview.have_account") }

    /// Tu plan en carrera
    static var previewLabel: String { String(localized: "preview.label") }

    /// Fondo largo · 14 km · 26°
    static var previewSession: String { String(localized: "preview.session") }

    /// Iniciar sesión
    static var previewSignIn: String { String(localized: "preview.sign_in") }

    /// Empezar
    static var previewStart: String { String(localized: "preview.start") }

    /// de quienes dejaron de entrenar lo hizo por falta de tiempo
    static var problemFact1: String { String(localized: "problem.fact1") }

    /// de los corredores sufre calambres: pérdidas de 3 a 5 % del peso ya generan debilidad y desorientación
    static var problemFact2: String { String(localized: "problem.fact2") }

    /// de quienes practican deporte compite en carreras organizadas
    static var problemFact3: String { String(localized: "problem.fact3") }

    /// El problema no es el entusiasmo
    static var problemTitle: String { String(localized: "problem.title") }

    /// Edad
    static var profileAge: String { String(localized: "profile.age") }

    /// %lld años
    static func profileAgeYears(_ arg1: Int) -> String {
        String(format: String(localized: "profile.age_years"), arg1)
    }

    /// Completar ahora
    static var profileCompleteNow: String { String(localized: "profile.complete_now") }

    /// Completar perfil
    static var profileCompleteProfile: String { String(localized: "profile.complete_profile") }

    /// Días y horarios
    static var profileDaysAndTimes: String { String(localized: "profile.days_and_times") }

    /// Elegir nueva meta
    static var profileGoalsChooseNew: String { String(localized: "profile.goals.choose_new") }

    /// Faltan %lld días
    static func profileGoalsDaysLeft(_ arg1: Int) -> String {
        String(format: String(localized: "profile.goals.days_left"), arg1)
    }

    /// Tus metas anteriores ya finalizaron. Definí una nueva meta para comenzar tu próximo plan.
    static var profileGoalsFinished: String { String(localized: "profile.goals.finished") }

    /// Buscando tus metas…
    static var profileGoalsLoading: String { String(localized: "profile.goals.loading") }

    /// + Gestionar
    static var profileGoalsManage: String { String(localized: "profile.goals.manage") }

    /// Plan sin fecha fija
    static var profileGoalsNoFixedDate: String { String(localized: "profile.goals.no_fixed_date") }

    /// Sin metas activas
    static var profileGoalsNoneActive: String { String(localized: "profile.goals.none_active") }

    /// Falta 1 día
    static var profileGoalsOneDayLeft: String { String(localized: "profile.goals.one_day_left") }

    /// Metas y objetivos
    static var profileGoalsTitle: String { String(localized: "profile.goals.title") }

    /// ¡Es hoy!
    static var profileGoalsToday: String { String(localized: "profile.goals.today") }

    /// Faltan %lld sem
    static func profileGoalsWeeksLeft(_ arg1: Int) -> String {
        String(format: String(localized: "profile.goals.weeks_left"), arg1)
    }

    /// Altura
    static var profileHeight: String { String(localized: "profile.height") }

    /// Vencido · renovalo
    static var profileMedicalExpired: String { String(localized: "profile.medical.expired") }

    /// Vence el %@ · faltan %lld días
    static func profileMedicalExpiresOnDaysLeft(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "profile.medical.expires_on_days_left"), arg1, arg2)
    }

    /// Sin cargar · subí foto o PDF
    static var profileMedicalNotAdded: String { String(localized: "profile.medical.not_added") }

    /// Sin foto
    static var profileNoPhoto: String { String(localized: "profile.no_photo") }

    /// sin entrenamiento
    static var profileNoWorkout: String { String(localized: "profile.no_workout") }

    /// de %lld
    static func profileOfNumber(_ arg1: Int) -> String {
        String(format: String(localized: "profile.of_number"), arg1)
    }

    /// de %@
    static func profileOfText(_ arg1: String) -> String {
        String(format: String(localized: "profile.of_text"), arg1)
    }

    /// Abre tus datos personales en Ajustes
    static var profileOpensPersonalData: String { String(localized: "profile.opens_personal_data") }

    /// Abre tu plan
    static var profileOpensPlan: String { String(localized: "profile.opens_plan") }

    /// Abre tus días y horarios en Ajustes
    static var profileOpensTraining: String { String(localized: "profile.opens_training") }

    /// %lld por semana
    static func profilePerWeek(_ arg1: Int) -> String {
        String(format: String(localized: "profile.per_week"), arg1)
    }

    /// Semana %lld de %lld del plan
    static func profilePlanWeekOf(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "profile.plan_week_of"), arg1, arg2)
    }

    /// Muestra cómo funciona la racha
    static var profileStreakHint: String { String(localized: "profile.streak.hint") }

    /// Esta semana
    static var profileThisWeek: String { String(localized: "profile.this_week") }

    /// Días de entrenamiento
    static var profileTrainingDays: String { String(localized: "profile.training_days") }

    /// Los días llenos son los que elegiste: tu plan reparte los entrenamientos en ellos, a esa hora.
    static var profileTrainingDaysDetail: String { String(localized: "profile.training_days.detail") }

    /// Todavía no elegiste días. Completá tu perfil para que el plan sepa cuándo entrenás.
    static var profileTrainingDaysNone: String { String(localized: "profile.training_days.none") }

    /// Ajustes
    static var profileViewSettings: String { String(localized: "profile.view_settings") }

    /// Peso
    static var profileWeight: String { String(localized: "profile.weight") }

    /// entrenás a las %@
    static func profileYouTrainAt(_ arg1: String) -> String {
        String(format: String(localized: "profile.you_train_at"), arg1)
    }

    /// Tu actividad
    static var profileYourActivity: String { String(localized: "profile.your_activity") }

    /// Tu cuerpo
    static var profileYourBody: String { String(localized: "profile.your_body") }

    /// Cerrar reproducción
    static var replayClose: String { String(localized: "replay.close") }

    /// KILÓMETRO
    static var replayHeaderKilometer: String { String(localized: "replay.header.kilometer") }

    /// RITMO
    static var replayHeaderPace: String { String(localized: "replay.header.pace") }

    /// VELOCIDAD
    static var replayHeaderSpeed: String { String(localized: "replay.header.speed") }

    /// TIEMPO
    static var replayHeaderTime: String { String(localized: "replay.header.time") }

    /// TIEMPO TOTAL
    static var replayHeaderTotalTime: String { String(localized: "replay.header.total_time") }

    /// Reiniciar reproducción
    static var replayRestart: String { String(localized: "replay.restart") }

    /// Velocidad %@
    static func replaySpeedAccessibility(_ arg1: String) -> String {
        String(format: String(localized: "replay.speed_accessibility"), arg1)
    }

    /// Más opciones
    static var route3dMoreOptions: String { String(localized: "route3d.more_options") }

    /// Tu sesión ha expirado. Por favor, inicia sesión nuevamente para continuar.
    static var sessionExpiredMessage: String { String(localized: "session.expired.message") }

    /// Sesión expirada
    static var sessionExpiredTitle: String { String(localized: "session.expired.title") }

    /// Cuenta
    static var settingsAccount: String { String(localized: "settings.account") }

    /// Avisos
    static var settingsAlerts: String { String(localized: "settings.alerts") }

    /// Automático
    static var settingsAppearanceAutomatic: String { String(localized: "settings.appearance.automatic") }

    /// Cambia solo, igual que tu iPhone
    static var settingsAppearanceAutomaticDetail: String { String(localized: "settings.appearance.automatic.detail") }

    /// Color
    static var settingsAppearanceColor: String { String(localized: "settings.appearance.color") }

    /// Oscuro
    static var settingsAppearanceDark: String { String(localized: "settings.appearance.dark") }

    /// Fondo negro, descansa la vista
    static var settingsAppearanceDarkDetail: String { String(localized: "settings.appearance.dark.detail") }

    /// Claro
    static var settingsAppearanceLight: String { String(localized: "settings.appearance.light") }

    /// Fondo claro, se lee mejor al sol
    static var settingsAppearanceLightDetail: String { String(localized: "settings.appearance.light.detail") }

    /// Aspecto
    static var settingsAppearanceTitle: String { String(localized: "settings.appearance.title") }

    /// Azul
    static var settingsColorBlue: String { String(localized: "settings.color.blue") }

    /// Coral
    static var settingsColorCoral: String { String(localized: "settings.color.coral") }

    /// Personalizado
    static var settingsColorCustom: String { String(localized: "settings.color.custom") }

    /// Elegí cualquier color y después tocá Usar
    static var settingsColorCustomHint: String { String(localized: "settings.color.custom_hint") }

    /// Color personalizado
    static var settingsColorCustomTitle: String { String(localized: "settings.color.custom_title") }

    /// Cian
    static var settingsColorCyan: String { String(localized: "settings.color.cyan") }

    /// Fucsia
    static var settingsColorFuchsia: String { String(localized: "settings.color.fuchsia") }

    /// Lavanda
    static var settingsColorLavender: String { String(localized: "settings.color.lavender") }

    /// Verde lima
    static var settingsColorLime: String { String(localized: "settings.color.lime") }

    /// Poco contraste
    static var settingsColorLowContrast: String { String(localized: "settings.color.low_contrast") }

    /// Menta
    static var settingsColorMint: String { String(localized: "settings.color.mint") }

    /// Naranja
    static var settingsColorOrange: String { String(localized: "settings.color.orange") }

    /// Rosa Stamina
    static var settingsColorPink: String { String(localized: "settings.color.pink") }

    /// En curso
    static var settingsColorPreviewInProgress: String { String(localized: "settings.color.preview.in_progress") }

    /// Tu semana
    static var settingsColorPreviewYourWeek: String { String(localized: "settings.color.preview.your_week") }

    /// Restablecer
    static var settingsColorReset: String { String(localized: "settings.color.reset") }

    /// Violeta
    static var settingsColorViolet: String { String(localized: "settings.color.violet") }

    /// Amarillo
    static var settingsColorYellow: String { String(localized: "settings.color.yellow") }

    /// Agregar objetivo
    static var settingsGoalsAdd: String { String(localized: "settings.goals.add") }

    /// Agregar fecha del evento
    static var settingsGoalsAddEventDate: String { String(localized: "settings.goals.add_event_date") }

    /// %lld activos
    static func settingsGoalsCountActive(_ arg1: Int) -> String {
        String(format: String(localized: "settings.goals.count_active"), arg1)
    }

    /// Fecha
    static var settingsGoalsDate: String { String(localized: "settings.goals.date") }

    /// Plan principal
    static var settingsGoalsMainPlan: String { String(localized: "settings.goals.main_plan") }

    /// Sin objetivos
    static var settingsGoalsNone: String { String(localized: "settings.goals.none") }

    /// Plan %lld
    static func settingsGoalsPlanNumber(_ arg1: Int) -> String {
        String(format: String(localized: "settings.goals.plan_number"), arg1)
    }

    /// Quitar fecha
    static var settingsGoalsRemoveDate: String { String(localized: "settings.goals.remove_date") }

    /// No se guardaron los objetivos
    static var settingsGoalsSaveFailed: String { String(localized: "settings.goals.save_failed") }

    /// Revisá la conexión e intentá de nuevo.
    static var settingsGoalsSaveFailedMessage: String { String(localized: "settings.goals.save_failed.message") }

    /// Objetivos
    static var settingsGoalsTitle: String { String(localized: "settings.goals.title") }

    /// %lld activas
    static func settingsNotificationsCountOn(_ arg1: Int) -> String {
        String(format: String(localized: "settings.notifications.count_on"), arg1)
    }

    /// Plan del día
    static var settingsNotificationsDailyPlan: String { String(localized: "settings.notifications.daily_plan") }

    /// Los días de entreno, a primera hora: qué toca hacer hoy y a qué hora.
    static var settingsNotificationsDailyPlanDetail: String { String(localized: "settings.notifications.daily_plan.detail") }

    /// Calor
    static var settingsNotificationsHeat: String { String(localized: "settings.notifications.heat") }

    /// Si el pronóstico supera los 30 °C antes de entrenar, te avisamos por la mañana.
    static var settingsNotificationsHeatDetail: String { String(localized: "settings.notifications.heat.detail") }

    /// Apagadas
    static var settingsNotificationsOff: String { String(localized: "settings.notifications.off") }

    /// 1 activa
    static var settingsNotificationsOneOn: String { String(localized: "settings.notifications.one_on") }

    /// 30 min antes
    static var settingsNotificationsThirtyMinBefore: String { String(localized: "settings.notifications.thirty_min_before") }

    /// 30 minutos antes de la hora definida para el entrenamiento
    static var settingsNotificationsThirtyMinBeforeDetail: String { String(localized: "settings.notifications.thirty_min_before.detail") }

    /// Notificaciones
    static var settingsNotificationsTitle: String { String(localized: "settings.notifications.title") }

    /// Nacimiento
    static var settingsPersonalBirthdate: String { String(localized: "settings.personal.birthdate") }

    /// Correo
    static var settingsPersonalEmail: String { String(localized: "settings.personal.email") }

    /// Pies
    static var settingsPersonalHeightFeet: String { String(localized: "settings.personal.height_feet") }

    /// Pulgadas
    static var settingsPersonalHeightInches: String { String(localized: "settings.personal.height_inches") }

    /// Poné una altura entre 2′0″ y 8′6″.
    static var settingsPersonalHeightOutOfRangeFt: String { String(localized: "settings.personal.height_out_of_range_ft") }

    /// Escribí tu nombre.
    static var settingsPersonalNameRequired: String { String(localized: "settings.personal.name_required") }

    /// Sexo
    static var settingsPersonalSex: String { String(localized: "settings.personal.sex") }

    /// Datos personales
    static var settingsPersonalTitle: String { String(localized: "settings.personal.title") }

    /// Peso (lb)
    static var settingsPersonalWeightLabelLb: String { String(localized: "settings.personal.weight_label_lb") }

    /// Poné un peso entre 45 y 880 lb.
    static var settingsPersonalWeightOutOfRangeLb: String { String(localized: "settings.personal.weight_out_of_range_lb") }

    /// Lo que cambiaste no se va a guardar.
    static var settingsProfileDiscardMessage: String { String(localized: "settings.profile.discard_message") }

    /// ¿Descartar cambios?
    static var settingsProfileDiscardTitle: String { String(localized: "settings.profile.discard_title") }

    /// Corregí lo marcado para guardar
    static var settingsProfileFixToSave: String { String(localized: "settings.profile.fix_to_save") }

    /// Seguir editando
    static var settingsProfileKeepEditing: String { String(localized: "settings.profile.keep_editing") }

    /// No pudimos traer tus datos.
    static var settingsProfileLoadFailed: String { String(localized: "settings.profile.load_failed") }

    /// Guardado
    static var settingsProfileSaved: String { String(localized: "settings.profile.saved") }

    /// Apariencia
    static var settingsSectionAppearance: String { String(localized: "settings.section.appearance") }

    /// Ayuda
    static var settingsSectionHelp: String { String(localized: "settings.section.help") }

    /// Preferencias
    static var settingsSectionPreferences: String { String(localized: "settings.section.preferences") }

    /// Cerrar sesión
    static var settingsSignOut: String { String(localized: "settings.sign_out") }

    /// ¿Estás seguro de que querés cerrar la sesión?
    static var settingsSignOutAlertMessage: String { String(localized: "settings.sign_out.alert_message") }

    /// ¿Cerrar sesión?
    static var settingsSignOutAlertTitle: String { String(localized: "settings.sign_out.alert_title") }

    /// Ajustes
    static var settingsTitle: String { String(localized: "settings.title") }

    /// Nivel
    static var settingsTrainingLevel: String { String(localized: "settings.training.level") }

    /// Deporte
    static var settingsTrainingSport: String { String(localized: "settings.training.sport") }

    /// Entrenamiento
    static var settingsTrainingTitle: String { String(localized: "settings.training.title") }

    /// Unidades
    static var settingsUnits: String { String(localized: "settings.units") }

    /// Cambia sólo cómo se muestran: lo guardado no cambia.
    static var settingsUnitsDetail: String { String(localized: "settings.units.detail") }

    /// Kilómetros
    static var settingsUnitsKilometers: String { String(localized: "settings.units.kilometers") }

    /// Millas
    static var settingsUnitsMiles: String { String(localized: "settings.units.miles") }

    /// Stamina %@ · beta
    static func settingsVersion(_ arg1: String) -> String {
        String(format: String(localized: "settings.version"), arg1)
    }

    /// Ver tour
    static var settingsViewTour: String { String(localized: "settings.view_tour") }

    /// La edad define tus zonas de frecuencia cardíaca, el ritmo de sudoración estimado y cuántas calorías necesitás 
    static var signupBirthBody: String { String(localized: "signup.birth.body") }

    /// día
    static var signupBirthDay: String { String(localized: "signup.birth.day") }

    /// Orden según tu idioma (%@): %@
    static func signupBirthFormat(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "signup.birth.format"), arg1, arg2)
    }

    /// ¡Hola, %@!
    static func signupBirthGreeting(_ arg1: String) -> String {
        String(format: String(localized: "signup.birth.greeting"), arg1)
    }

    /// mes
    static var signupBirthMonth: String { String(localized: "signup.birth.month") }

    /// Mové la rueda hasta tu fecha de nacimiento para seguir.
    static var signupBirthMustChoose: String { String(localized: "signup.birth.must_choose") }

    /// %@ ¿Cuándo naciste?
    static func signupBirthTitle(_ arg1: String) -> String {
        String(format: String(localized: "signup.birth.title"), arg1)
    }

    /// año
    static var signupBirthYear: String { String(localized: "signup.birth.year") }

    /// El peso es la base del cálculo: litros de líquido por hora, miligramos de sodio y gramos de carbohidrato que t
    static var signupBodyBody: String { String(localized: "signup.body.body") }

    /// Altura (cm)
    static var signupBodyHeightLabel: String { String(localized: "signup.body.height_label") }

    /// Poné una altura entre 50 y 260 cm.
    static var signupBodyHeightOutOfRange: String { String(localized: "signup.body.height_out_of_range") }

    /// 178
    static var signupBodyHeightPlaceholder: String { String(localized: "signup.body.height_placeholder") }

    /// Tu peso y tu altura
    static var signupBodyTitle: String { String(localized: "signup.body.title") }

    /// Peso (kg)
    static var signupBodyWeightLabel: String { String(localized: "signup.body.weight_label") }

    /// Poné un peso entre 20 y 400 kg.
    static var signupBodyWeightOutOfRange: String { String(localized: "signup.body.weight_out_of_range") }

    /// 72
    static var signupBodyWeightPlaceholder: String { String(localized: "signup.body.weight_placeholder") }

    /// Enviamos un código de 6 caracteres, con números y letras, a %@. Puede tardar hasta un minuto en llegar; si no 
    static func signupCodeBody(_ arg1: String) -> String {
        String(format: String(localized: "signup.code.body"), arg1)
    }

    /// Validá tu correo
    static var signupCodeTitle: String { String(localized: "signup.code.title") }

    /// Validar
    static var signupCodeVerify: String { String(localized: "signup.code.verify") }

    /// Completar después
    static var signupCompleteLater: String { String(localized: "signup.complete_later") }

    /// Vas a recibir %lld avisos por semana, 45 min antes de cada sesión.
    static func signupDaysAlert(_ arg1: Int) -> String {
        String(format: String(localized: "signup.days.alert"), arg1)
    }

    /// Esto no es un dato de perfil: es lo que dispara los avisos. Te escribimos 45 minutos antes de cada sesión para
    static var signupDaysBody: String { String(localized: "signup.days.body") }

    /// Elegí al menos un día para activar los avisos.
    static var signupDaysNoDays: String { String(localized: "signup.days.no_days") }

    /// Hora de %@
    static func signupDaysTimeOf(_ arg1: String) -> String {
        String(format: String(localized: "signup.days.time_of"), arg1)
    }

    /// ¿Qué días y a qué hora entrenás?
    static var signupDaysTitle: String { String(localized: "signup.days.title") }

    /// Plan de base
    static var signupDoneBasePlan: String { String(localized: "signup.done.base_plan") }

    /// Nacimiento
    static var signupDoneBirth: String { String(localized: "signup.done.birth") }

    /// Días
    static var signupDoneDays: String { String(localized: "signup.done.days") }

    /// Ir a mi inicio
    static var signupDoneGoHome: String { String(localized: "signup.done.go_home") }

    /// Objetivo
    static var signupDoneGoal: String { String(localized: "signup.done.goal") }

    /// Nivel
    static var signupDoneLevel: String { String(localized: "signup.done.level") }

    /// Tu perfil quedó completo.
    static var signupDoneProfileComplete: String { String(localized: "signup.done.profile_complete") }

    /// Deporte
    static var signupDoneSport: String { String(localized: "signup.done.sport") }

    /// Todo listo, %@
    static func signupDoneTitle(_ arg1: String) -> String {
        String(format: String(localized: "signup.done.title"), arg1)
    }

    /// Lo validamos antes de pedirte cualquier otro dato, así no completás todo el registro para descubrir al final q
    static var signupEmailBody: String { String(localized: "signup.email.body") }

    /// Ese correo no parece válido: revisá que tenga @ y dominio.
    static var signupEmailInvalid: String { String(localized: "signup.email.invalid") }

    /// Al continuar aceptás los términos y la política de privacidad. No mandamos publicidad.
    static var signupEmailLegal: String { String(localized: "signup.email.legal") }

    /// Enviarme el código
    static var signupEmailSend: String { String(localized: "signup.email.send") }

    /// Empecemos por tu correo
    static var signupEmailTitle: String { String(localized: "signup.email.title") }

    /// Error en el registro
    static var signupErrorTitle: String { String(localized: "signup.error.title") }

    /// Con la fecha del evento armamos la cuenta regresiva y repartimos las semanas de carga, descarga y afinamiento.
    static var signupGoalBody: String { String(localized: "signup.goal.body") }

    /// 10 km
    static var signupGoalC10k: String { String(localized: "signup.goal.c10k") }

    /// 10 km
    static var signupGoalC10kDetail: String { String(localized: "signup.goal.c10k.detail") }

    /// 5 km
    static var signupGoalC5k: String { String(localized: "signup.goal.c5k") }

    /// 5 km · plan de 4 semanas
    static var signupGoalC5kDetail: String { String(localized: "signup.goal.c5k.detail") }

    /// Elegí tu objetivo
    static var signupGoalChoose: String { String(localized: "signup.goal.choose") }

    /// Media maratón
    static var signupGoalHalfMarathon: String { String(localized: "signup.goal.half_marathon") }

    /// 21,1 km
    static var signupGoalHalfMarathonDetail: String { String(localized: "signup.goal.half_marathon.detail") }

    /// Volver a entrenar sin lesiones
    static var signupGoalInjuryFree: String { String(localized: "signup.goal.injury_free") }

    /// sin distancia fija
    static var signupGoalInjuryFreeDetail: String { String(localized: "signup.goal.injury_free.detail") }

    /// Maratón
    static var signupGoalMarathon: String { String(localized: "signup.goal.marathon") }

    /// 42,2 km
    static var signupGoalMarathonDetail: String { String(localized: "signup.goal.marathon.detail") }

    /// Trail de montaña
    static var signupGoalMountainTrail: String { String(localized: "signup.goal.mountain_trail") }

    /// 25-50 km
    static var signupGoalMountainTrailDetail: String { String(localized: "signup.goal.mountain_trail.detail") }

    /// Podés elegir varios. El primero será tu plan principal.
    static var signupGoalMultipleHint: String { String(localized: "signup.goal.multiple_hint") }

    /// Mes siguiente
    static var signupGoalNextMonth: String { String(localized: "signup.goal.next_month") }

    /// Todavía sin fecha: vamos a armar un plan de base.
    static var signupGoalNoDate: String { String(localized: "signup.goal.no_date") }

    /// Triatlón olímpico
    static var signupGoalOlympicTriathlon: String { String(localized: "signup.goal.olympic_triathlon") }

    /// 1,5 / 40 / 10 km
    static var signupGoalOlympicTriathlonDetail: String { String(localized: "signup.goal.olympic_triathlon.detail") }

    /// Mes anterior
    static var signupGoalPreviousMonth: String { String(localized: "signup.goal.previous_month") }

    /// ¿Para qué estás entrenando?
    static var signupGoalTitle: String { String(localized: "signup.goal.title") }

    /// %@ · faltan %lld semanas
    static func signupGoalWithDate(_ arg1: String, _ arg2: Int) -> String {
        String(format: String(localized: "signup.goal.with_date"), arg1, arg2)
    }

    /// Entiendo que Stamina da sugerencias generales y que ante cualquier síntoma tengo que parar y consultar.
    static var signupHealthAccept: String { String(localized: "signup.health.accept") }

    /// No somos médicos y esta app no reemplaza una consulta. Si tenés alguna condición previa, tomás medicación o ha
    static var signupHealthBody: String { String(localized: "signup.health.body") }

    /// Marcá que entendiste el descargo para poder seguir.
    static var signupHealthMustAccept: String { String(localized: "signup.health.must_accept") }

    /// Pará y consultá si aparece
    static var signupHealthStopAndConsult: String { String(localized: "signup.health.stop_and_consult") }

    /// Dolor u opresión en el pecho
    static var signupHealthSymptom1: String { String(localized: "signup.health.symptom1") }

    /// Dificultad respiratoria grave o mareos
    static var signupHealthSymptom2: String { String(localized: "signup.health.symptom2") }

    /// Dolor articular que empeora mientras corrés
    static var signupHealthSymptom3: String { String(localized: "signup.health.symptom3") }

    /// Antes de arrancar, una sola cosa
    static var signupHealthTitle: String { String(localized: "signup.health.title") }

    /// Apellido (opcional)
    static var signupLastNameLabel: String { String(localized: "signup.last_name.label") }

    /// Benítez
    static var signupLastNamePlaceholder: String { String(localized: "signup.last_name.placeholder") }

    /// Avanzado
    static var signupLevelAdvanced: String { String(localized: "signup.level.advanced") }

    /// Más de 3 años, con competencias en el calendario
    static var signupLevelAdvancedDetail: String { String(localized: "signup.level.advanced.detail") }

    /// Principiante
    static var signupLevelBeginner: String { String(localized: "signup.level.beginner") }

    /// Menos de un año entrenando o volviendo después de un parate
    static var signupLevelBeginnerDetail: String { String(localized: "signup.level.beginner.detail") }

    /// Define desde qué volumen arranca tu plan y cuánto puede crecer por semana sin exponerte a lesiones. Si volvés 
    static var signupLevelBody: String { String(localized: "signup.level.body") }

    /// Intermedio
    static var signupLevelIntermediate: String { String(localized: "signup.level.intermediate") }

    /// 1 a 3 años entrenando de forma regular
    static var signupLevelIntermediateDetail: String { String(localized: "signup.level.intermediate.detail") }

    /// ¿Hace cuánto entrenás?
    static var signupLevelTitle: String { String(localized: "signup.level.title") }

    /// Usamos tu nombre para hablarte en las notificaciones y en el resumen de cada semana. El apellido solo aparece 
    static var signupNameBody: String { String(localized: "signup.name.body") }

    /// Nombre
    static var signupNameLabel: String { String(localized: "signup.name.label") }

    /// Iván
    static var signupNamePlaceholder: String { String(localized: "signup.name.placeholder") }

    /// Correo validado. ¿Cómo te llamás?
    static var signupNameTitle: String { String(localized: "signup.name.title") }

    /// Al menos %lld caracteres, con una mayúscula y un número. Es la única contraseña que te vamos a pedir: con ella
    static func signupPasswordBody(_ arg1: Int) -> String {
        String(format: String(localized: "signup.password.body"), arg1)
    }

    /// Esta pantalla NO está en el diseño: los 13 pasos nunca piden contraseña y el contrato la exige. Es un hueco de
    static var signupPasswordGapNote: String { String(localized: "signup.password.gap_note") }

    /// Elegí una contraseña
    static var signupPasswordTitle: String { String(localized: "signup.password.title") }

    /// Las tasas de sudoración, la pérdida de sodio y el gasto calórico difieren bastante entre hombres y mujeres con
    static var signupSexBody: String { String(localized: "signup.sex.body") }

    /// Femenino
    static var signupSexFemale: String { String(localized: "signup.sex.female") }

    /// Menor tasa de sudoración media y distinta pérdida de sodio
    static var signupSexFemaleDetail: String { String(localized: "signup.sex.female.detail") }

    /// Masculino
    static var signupSexMale: String { String(localized: "signup.sex.male") }

    /// Mayor tasa de sudoración media para el mismo peso y ritmo
    static var signupSexMaleDetail: String { String(localized: "signup.sex.male.detail") }

    /// ¿Con qué sexo biológico calculamos tu sudoración?
    static var signupSexTitle: String { String(localized: "signup.sex.title") }

    /// Prefiero no decirlo
    static var signupSexUndisclosed: String { String(localized: "signup.sex.undisclosed") }

    /// Sin este dato, algunas partes del plan pueden no estar disponibles
    static var signupSexUndisclosedDetail: String { String(localized: "signup.sex.undisclosed.detail") }

    /// Cada disciplina consume líquido y carbohidrato de forma distinta: en bici podés tomar más y comer sólido, corr
    static var signupSportBody: String { String(localized: "signup.sport.body") }

    /// Ciclismo
    static var signupSportCycling: String { String(localized: "signup.sport.cycling") }

    /// Ruta, gravel o MTB
    static var signupSportCyclingDetail: String { String(localized: "signup.sport.cycling.detail") }

    /// Running
    static var signupSportRunning: String { String(localized: "signup.sport.running") }

    /// Calle, pista o trail
    static var signupSportRunningDetail: String { String(localized: "signup.sport.running.detail") }

    /// Por ahora, Stamina es sólo para correr.
    static var signupSportRunningOnly: String { String(localized: "signup.sport.running_only") }

    /// ¿Cuál es tu deporte principal?
    static var signupSportTitle: String { String(localized: "signup.sport.title") }

    /// Trekking
    static var signupSportTrekking: String { String(localized: "signup.sport.trekking") }

    /// Montaña y travesías
    static var signupSportTrekkingDetail: String { String(localized: "signup.sport.trekking.detail") }

    /// Triatlón
    static var signupSportTriathlon: String { String(localized: "signup.sport.triathlon") }

    /// Nado, bici y carrera
    static var signupSportTriathlonDetail: String { String(localized: "signup.sport.triathlon.detail") }

    /// Apple Watch y Salud
    static var signupTrackingApple: String { String(localized: "signup.tracking.apple") }

    /// Pulso, pasos y entrenamientos
    static var signupTrackingAppleDetail: String { String(localized: "signup.tracking.apple.detail") }

    /// Si conectás tu reloj o el GPS del teléfono, ajustamos hidratación y geles con el ritmo y la frecuencia cardíac
    static var signupTrackingBody: String { String(localized: "signup.tracking.body") }

    /// Reloj Garmin
    static var signupTrackingGarmin: String { String(localized: "signup.tracking.garmin") }

    /// Ritmo, pulso y altimetría
    static var signupTrackingGarminDetail: String { String(localized: "signup.tracking.garmin.detail") }

    /// GPS del teléfono
    static var signupTrackingGps: String { String(localized: "signup.tracking.gps") }

    /// Ritmo y distancia, sin accesorios
    static var signupTrackingGpsDetail: String { String(localized: "signup.tracking.gps.detail") }

    /// Cargo todo a mano
    static var signupTrackingManual: String { String(localized: "signup.tracking.manual") }

    /// Estimamos con peso, clima y ritmo objetivo
    static var signupTrackingManualDetail: String { String(localized: "signup.tracking.manual.detail") }

    /// Ahora no
    static var signupTrackingNotNow: String { String(localized: "signup.tracking.not_now") }

    /// Esta respuesta todavía no se guarda: el contrato no tiene dónde. Está anotado como B-006 y no bloquea nada: po
    static var signupTrackingNotSaved: String { String(localized: "signup.tracking.not_saved") }

    /// ¿Con qué medís tus salidas?
    static var signupTrackingTitle: String { String(localized: "signup.tracking.title") }

    /// Otro
    static var sportOther: String { String(localized: "sport.other") }

    /// Fuerza
    static var sportStrength: String { String(localized: "sport.strength") }

    /// Natación
    static var sportSwimming: String { String(localized: "sport.swimming") }

    /// Triatlón
    static var sportTriathlon: String { String(localized: "sport.triathlon") }

    /// %1$@: %2$lld %3$@
    static func streakAccessibility(_ arg1: String, _ arg2: Int, _ arg3: String) -> String {
        String(format: String(localized: "streak.accessibility"), arg1, arg2, arg3)
    }

    /// días
    static var streakDays: String { String(localized: "streak.days") }

    /// ¡Fueguito encendido! Completaste tu entrenamiento de hoy.
    static var streakDetailActive: String { String(localized: "streak.detail.active") }

    /// No tenés una racha activa. ¡Entrená en tu próximo día para encender el fueguito!
    static var streakDetailLost: String { String(localized: "streak.detail.lost") }

    /// Hoy te toca entrenar. ¡Completá tu sesión para mantener vivo el fueguito!
    static var streakDetailPending: String { String(localized: "streak.detail.pending") }

    /// Hoy es día de descanso en tu plan. Tu racha se mantiene intacta.
    static var streakDetailRest: String { String(localized: "streak.detail.rest") }

    /// Tu racha solo cuenta los días que tu plan dice que tenés que entrenar. Si no entrenás un día programado, el fu
    static var streakExplanation: String { String(localized: "streak.explanation") }

    /// Racha de entrenamientos
    static var streakTitle: String { String(localized: "streak.title") }

    /// ¡Llegaste!
    static var summaryArrived: String { String(localized: "summary.arrived") }

    /// Pulso medio
    static var summaryAvgHeartRate: String { String(localized: "summary.avg_heart_rate") }

    /// Mejor ritmo
    static var summaryBestPace: String { String(localized: "summary.best_pace") }

    /// Calorías
    static var summaryCalories: String { String(localized: "summary.calories") }

    /// Parcial más rápido
    static var summaryFastestSplit: String { String(localized: "summary.fastest_split") }

    /// Pulso máx
    static var summaryMaxHeartRate: String { String(localized: "summary.max_heart_rate") }

    /// Velocidad máx.
    static var summaryMaxSpeed: String { String(localized: "summary.max_speed") }

    /// En movimiento
    static var summaryMovingTime: String { String(localized: "summary.moving_time") }

    /// Pausa %1$lld: %2$@
    static func summaryPauseNumber(_ arg1: Int, _ arg2: String) -> String {
        String(format: String(localized: "summary.pause_number"), arg1, arg2)
    }

    /// Pausa: %1$@ · Reanudación: %2$@
    static func summaryPauseResume(_ arg1: String, _ arg2: String) -> String {
        String(format: String(localized: "summary.pause_resume"), arg1, arg2)
    }

    /// cada km
    static var summaryPerKm: String { String(localized: "summary.per_km") }

    /// Reproducir recorrido
    static var summaryReplayRoute: String { String(localized: "summary.replay_route") }

    /// Listo
    static var summarySaveAndClose: String { String(localized: "summary.save_and_close") }

    /// Tramos, pausas y reanudaciones
    static var summarySegmentsPauses: String { String(localized: "summary.segments_pauses") }

    /// Km %lld
    static func summarySplitKmNumber(_ arg1: Int) -> String {
        String(format: String(localized: "summary.split.km_number"), arg1)
    }

    /// Tramo %lld
    static func summarySplitSegmentNumber(_ arg1: Int) -> String {
        String(format: String(localized: "summary.split.segment_number"), arg1)
    }

    /// Parciales
    static var summarySplits: String { String(localized: "summary.splits") }

    /// ¡Mantuviste tu racha de fueguito!
    static var summaryStreakKept: String { String(localized: "summary.streak_kept") }

    /// Duración total
    static var summaryTotalDuration: String { String(localized: "summary.total_duration") }

    /// Cierra el tour y va al inicio
    static var tourCloseHint: String { String(localized: "tour.close.hint") }

    /// ¡Listo! Tocá ⚡ cuando quieras salir a correr.
    static var tourCoachDoneBubble: String { String(localized: "tour.coach.done.bubble") }

    /// Tu semana de entrenamiento, día por día.
    static var tourCoachPlanBubble: String { String(localized: "tour.coach.plan.bubble") }

    /// Con ⚡ arrancás una salida: GPS, ritmo y pausa.
    static var tourCoachWorkoutBubble: String { String(localized: "tour.coach.workout.bubble") }

    /// Cada salida queda acá, con tus números.
    static var tourPageHistoryBubble: String { String(localized: "tour.page.history.bubble") }

    /// ¡Hola! Acá ves lo que te toca hoy.
    static var tourPageHomeBubble: String { String(localized: "tour.page.home.bubble") }

    /// Tus datos, tus metas y el color de la app.
    static var tourPageProfileBubble: String { String(localized: "tour.page.profile.bubble") }

    /// Página %lld de %lld
    static func tourPageOf(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "tour.page_of"), arg1, arg2)
    }

    /// Ahora no
    static var versionNotNow: String { String(localized: "version.not_now") }

    /// Podés seguir usando esta, pero conviene actualizar.
    static var versionRecommendedBody: String { String(localized: "version.recommended.body") }

    /// Hay una versión nueva de Stamina
    static var versionRecommendedTitle: String { String(localized: "version.recommended.title") }

    /// Esta versión ya no puede hablar con el servidor. Actualizá desde la App Store para seguir.
    static var versionRequiredBody: String { String(localized: "version.required.body") }

    /// Hay que actualizar Stamina
    static var versionRequiredTitle: String { String(localized: "version.required.title") }

    /// Actualizar
    static var versionUpdate: String { String(localized: "version.update") }

    /// Clima: Apple Weather. Fuentes de datos
    static var weatherAttributionAccessibility: String { String(localized: "weather.attribution.accessibility") }

    /// Fuentes de datos
    static var weatherAttributionSources: String { String(localized: "weather.attribution.sources") }

    /// Vie
    static var weekdayShortFri: String { String(localized: "weekday.short.fri") }

    /// Lun
    static var weekdayShortMon: String { String(localized: "weekday.short.mon") }

    /// Sáb
    static var weekdayShortSat: String { String(localized: "weekday.short.sat") }

    /// Dom
    static var weekdayShortSun: String { String(localized: "weekday.short.sun") }

    /// Jue
    static var weekdayShortThu: String { String(localized: "weekday.short.thu") }

    /// Mar
    static var weekdayShortTue: String { String(localized: "weekday.short.tue") }

    /// Mié
    static var weekdayShortWed: String { String(localized: "weekday.short.wed") }

    /// Crear cuenta gratis
    static var welcomeCreateAccount: String { String(localized: "welcome.create_account") }

    /// Ver la foto %lld de %lld
    static func welcomeGoToPhoto(_ arg1: Int, _ arg2: Int) -> String {
        String(format: String(localized: "welcome.go_to_photo"), arg1, arg2)
    }

    /// Ya tengo cuenta
    static var welcomeHaveAccount: String { String(localized: "welcome.have_account") }

    /// Corredores al amanecer
    static var welcomeSlide1Photo: String { String(localized: "welcome.slide1.photo") }

    /// Entrená y comé según la carga del día
    static var welcomeSlide1Title: String { String(localized: "welcome.slide1.title") }

    /// Pelotón en ruta
    static var welcomeSlide2Photo: String { String(localized: "welcome.slide2.photo") }

    /// Hidratate y reponé con una guía clara
    static var welcomeSlide2Title: String { String(localized: "welcome.slide2.title") }

    /// Trail en montaña
    static var welcomeSlide3Photo: String { String(localized: "welcome.slide3.photo") }

    /// Preparate para el día de la carrera
    static var welcomeSlide3Title: String { String(localized: "welcome.slide3.title") }

    /// Cerrar el plan
    static var workoutClosePlan: String { String(localized: "workout.close_plan") }

    /// Duración
    static var workoutDuration: String { String(localized: "workout.duration") }

    /// Terminar
    static var workoutFinish: String { String(localized: "workout.finish") }

    /// ¿Terminar el entreno?
    static var workoutFinishConfirm: String { String(localized: "workout.finish.confirm") }

    /// Avituallamiento
    static var workoutFueling: String { String(localized: "workout.fueling") }

    /// Sin GPS
    static var workoutGpsNone: String { String(localized: "workout.gps.none") }

    /// GPS ok
    static var workoutGpsOk: String { String(localized: "workout.gps.ok") }

    /// Grabando GPS
    static var workoutGpsRecording: String { String(localized: "workout.gps.recording") }

    /// Buscando GPS
    static var workoutGpsSearching: String { String(localized: "workout.gps.searching") }

    /// Entrenamiento en curso
    static var workoutInProgress: String { String(localized: "workout.in_progress") }

    /// en curso
    static var workoutInProgressLowercase: String { String(localized: "workout.in_progress_lowercase") }

    /// Centrar
    static var workoutMapCenter: String { String(localized: "workout.map.center") }

    /// Centrar en mi ubicación
    static var workoutMapCenterOnMe: String { String(localized: "workout.map.center_on_me") }

    /// Vista satelital
    static var workoutMapSatellite: String { String(localized: "workout.map.satellite") }

    /// Vista 3D
    static var workoutMapView3d: String { String(localized: "workout.map.view_3d") }

    /// El entrenamiento no registró desplazamiento suficiente o duró menos de 10 segundos. ¿Deseas descartarlo o rean
    static var workoutNoMovementMessage: String { String(localized: "workout.no_movement.message") }

    /// Sin movimiento
    static var workoutNoMovementTitle: String { String(localized: "workout.no_movement.title") }

    /// Abre el plan de hoy
    static var workoutOpensTodayPlan: String { String(localized: "workout.opens_today_plan") }

    /// Pausar
    static var workoutPause: String { String(localized: "workout.pause") }

    /// En pausa
    static var workoutPaused: String { String(localized: "workout.paused") }

    /// Ahora no
    static var workoutPermissionCancel: String { String(localized: "workout.permission.cancel") }

    /// Continuar
    static var workoutPermissionContinue: String { String(localized: "workout.permission.continue") }

    /// Al iniciar la salida, Stamina usará tu ubicación para dibujar el mapa y medir distancia y ritmo, incluso con l
    static var workoutPermissionDetail: String { String(localized: "workout.permission.detail") }

    /// Registrar tu recorrido
    static var workoutPermissionTitle: String { String(localized: "workout.permission.title") }

    /// Listo para iniciar
    static var workoutReadyToStart: String { String(localized: "workout.ready_to_start") }

    /// Grabando en el reloj
    static var workoutRecordingOnWatch: String { String(localized: "workout.recording_on_watch") }

    /// Rutas
    static var workoutRoutes: String { String(localized: "workout.routes") }

    /// Deporte
    static var workoutSport: String { String(localized: "workout.sport") }

    /// Empezar
    static var workoutStart: String { String(localized: "workout.start") }

    /// Estructura de la sesión
    static var workoutStructure: String { String(localized: "workout.structure") }

    /// Objetivo
    static var workoutTarget: String { String(localized: "workout.target") }

    /// Plan de hoy
    static var workoutTodayPlan: String { String(localized: "workout.today_plan") }

    /// Reloj vinculado
    static var workoutWatchConnected: String { String(localized: "workout.watch_connected") }

    /// Zona %lld
    static func zoneAccessibility(_ arg1: Int) -> String {
        String(format: String(localized: "zone.accessibility"), arg1)
    }

    /// alta
    static var zoneHigh: String { String(localized: "zone.high") }

    /// baja
    static var zoneLow: String { String(localized: "zone.low") }

    /// máxima
    static var zoneMax: String { String(localized: "zone.max") }

    /// moderada
    static var zoneModerate: String { String(localized: "zone.moderate") }

    /// moderada-alta
    static var zoneModerateHigh: String { String(localized: "zone.moderate_high") }
}
