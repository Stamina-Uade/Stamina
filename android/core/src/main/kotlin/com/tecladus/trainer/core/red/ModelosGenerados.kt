// =============================================================================
// GENERADO por scripts/generar-modelos.mjs desde shared/api/openapi.yaml
// NO EDITAR A MANO: se reescribe con `npm run generar:modelos` y el CI falla si
// lo commiteado no coincide.
//
// contrato: Trainer API v1.2.1
//
// AGENTS.md §5: el JSON va en snake_case, los tiempos son enteros de milisegundos
// desde epoch y todo viaja en un sobre {"data": …} o {"error": {…}}. Los nombres
// de Kotlin están en camelCase y @SerialName guarda el nombre real del contrato:
// cambiar uno sin cambiar el otro rompe la deserialización y no el compilador.
// =============================================================================

package com.tecladus.trainer.core.red

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Tipos del contrato que son un primitivo con nombre. Se aplanan:
 *  - EpochMs -> Long
 *  - Id -> String
 *  - Email -> String
 *  - Password -> String
 *  - CodigoVerificacion -> String
 */

/** Los cuatro clientes de AGENTS.md §1.3. Cada uno versiona por separado. */
@Serializable
enum class Plataforma {
    @SerialName("android")
    ANDROID,

    @SerialName("ios")
    IOS,

    @SerialName("wear")
    WEAR,

    @SerialName("watchos")
    WATCHOS,

}

/** Health */
@Serializable
data class Health(
    val status: String,
    /** Versión desplegada de Trainer. No la de Postgres ni la del sistema. */
    val version: String,
    val dependencies: EstadoDeDependencias,
)

/** Estaba escrito adentro de Health, sin nombre. Se extrajo el 2026-09-08 para que el generador de modelos pueda emitirlo: un objeto anonimo obliga a inventarle un nombre al cliente, y cada cliente inventa el suyo. La forma en el cable NO cambia: es el mismo objeto en el mismo lugar. */
@Serializable
data class EstadoDeDependencias(
    val database: String,
    /** `disabled` (1.1.0) no es una falla: el servidor corre con `REDIS_URL=disabled` a propósito y la caché vive en el proceso (decisión 0011). No baja el `status` a `degraded`. */
    val redis: String,
)

/** VersionGate */
@Serializable
data class VersionGate(
    val platform: Plataforma,
    /** Por debajo de esto la app **no puede seguir**. */
    @SerialName("minimum_build")
    val minimumBuild: Long,
    @SerialName("recommended_build")
    val recommendedBuild: Long,
    /** Resuelto por el servidor cuando el cliente manda su `build`. Si no lo manda, viene `ok` y el cliente compara solo. */
    val action: String,
    /** Clave estable del mensaje. El cliente la mapea a su propio texto traducido; `message` es el respaldo para cuando todavía no la conoce. */
    val code: String? = null,
    /** Texto ya traducido por el servidor según `Accept-Language`. */
    val message: String? = null,
    /** A dónde mandar a la persona a actualizar. */
    @SerialName("store_url")
    val storeUrl: String? = null,
)

/** Lo que se puede decir sin filtrar si la cuenta existe: cuánto vive el código y cuándo se puede pedir otro. Nada más. */
@Serializable
data class DesafioCorreo(
    @SerialName("expires_at_ms")
    val expiresAtMs: Long,
    @SerialName("resend_after_ms")
    val resendAfterMs: Long,
)

/** Lo que devuelve /auth/register/verify: el permiso de un solo uso para completar el registro. Estaba escrito adentro de la respuesta, sin nombre; se extrajo el 2026-09-09 para que el generador de modelos pueda emitirlo. La forma en el cable NO cambia. */
@Serializable
data class TokenDeRegistro(
    @SerialName("registration_token")
    val registrationToken: String,
    @SerialName("expires_at_ms")
    val expiresAtMs: Long,
)

/** Lo que devuelve /auth/password/verify: el permiso de un solo uso para poner la contraseña nueva. Estaba escrito adentro de la respuesta, sin nombre; se extrajo el 2026-09-09 por el mismo motivo que TokenDeRegistro —el generador de modelos no emite objetos anónimos— al escribir las pantallas de recuperar contraseña. La forma en el cable NO cambia. */
@Serializable
data class TokenDeReseteo(
    @SerialName("reset_token")
    val resetToken: String,
    @SerialName("expires_at_ms")
    val expiresAtMs: Long,
)

/** Sesion */
@Serializable
data class Sesion(
    /** Corto. Va en el header `Authorization`, con el esquema Bearer. */
    @SerialName("access_token")
    val accessToken: String,
    @SerialName("access_expires_at_ms")
    val accessExpiresAtMs: Long,
    /** Rota en cada uso. En el cliente va al almacenamiento seguro de la plataforma —Keystore o Keychain—, nunca a preferencias planas ni a un log (AGENTS.md §12.1). */
    @SerialName("refresh_token")
    val refreshToken: String,
    @SerialName("refresh_expires_at_ms")
    val refreshExpiresAtMs: Long,
    @SerialName("user_id")
    val userId: String,
)

/** Para el cálculo de sudoración y de metabolismo basal, no para nada más. Incluye "prefiero no decirlo" como el diseño (`reg-sexo`). */
@Serializable
enum class SexoBiologico {
    @SerialName("femenino")
    FEMENINO,

    @SerialName("masculino")
    MASCULINO,

    @SerialName("sin_declarar")
    SIN_DECLARAR,

}

/** Deporte */
@Serializable
enum class Deporte {
    @SerialName("running")
    RUNNING,

    @SerialName("ciclismo")
    CICLISMO,

    @SerialName("trekking")
    TREKKING,

    @SerialName("triatlon")
    TRIATLON,

}

/** Nivel */
@Serializable
enum class Nivel {
    @SerialName("principiante")
    PRINCIPIANTE,

    @SerialName("intermedio")
    INTERMEDIO,

    @SerialName("avanzado")
    AVANZADO,

}

/** Los 7 objetivos cerrados de `reg-objetivo` (design/ESPECIFICACION.md §5.1). Cerrar la lista es lo que hace que el motor del plan sea determinístico (AGENTS.md §9.1). */
@Serializable
enum class Objetivo {
    @SerialName("c5k")
    C5K,

    @SerialName("c10k")
    C10K,

    @SerialName("media_maraton")
    MEDIA_MARATON,

    @SerialName("maraton")
    MARATON,

    @SerialName("trail_montana")
    TRAIL_MONTANA,

    @SerialName("triatlon_olimpico")
    TRIATLON_OLIMPICO,

    @SerialName("volver_sin_lesiones")
    VOLVER_SIN_LESIONES,

}

/** `goal_date_ms` ausente equivale a `null` (sin fecha) desde la 1.2.1; antes era obligatorio y un cliente que omitía los nulos recibía un 400. */
@Serializable
data class ObjetivoEntrada(
    /** principal para el primero, UUID existente para los demás; omitir al crear. */
    val id: String? = null,
    val goal: Objetivo,
    @SerialName("goal_date_ms")
    val goalDateMs: Long? = null,
)

/** ObjetivoActivo */
@Serializable
data class ObjetivoActivo(
    val id: String,
    val goal: Objetivo,
    @SerialName("goal_date_ms")
    val goalDateMs: Long?,
)

/** PlanDeObjetivo */
@Serializable
data class PlanDeObjetivo(
    @SerialName("goal_id")
    val goalId: String,
    val plan: Plan,
)

/** PronosticoDeCalor */
@Serializable
data class PronosticoDeCalor(
    /** MET Norway */
    val source: String,
    @SerialName("source_url")
    val sourceUrl: String,
    val hours: List<HoraDePronostico>,
)

/** HoraDePronostico */
@Serializable
data class HoraDePronostico(
    @SerialName("at_ms")
    val atMs: Long,
    @SerialName("air_temperature_c")
    val airTemperatureC: Double,
)

/** DiaEntrenamiento */
@Serializable
data class DiaEntrenamiento(
    /** ISO-8601, 1 = lunes. La semana del diseño empieza el lunes. */
    val weekday: Int,
    /** Minutos desde la medianoche **local de la persona**. Sin zona no significa nada, por eso el perfil lleva `timezone`. */
    @SerialName("minute_of_day")
    val minuteOfDay: Int,
)

/** El aviso de salud y los términos, tal como se muestran. La estructura es deliberadamente tonta —título, resumen y una lista de bloques— porque el texto lo edita quien lo revise, no quien programa: cuantos menos campos con significado, menos chances de que un cambio de redacción rompa la pantalla. */
@Serializable
data class TextosLegales(
    val version: String,
    /** `false` mientras el texto sea un borrador que no revisó nadie con formación legal. El servidor **no arranca en producción** con esto en `false`; el campo existe para que se vea en desarrollo. */
    val reviewed: Boolean? = null,
    @SerialName("health_notice")
    val healthNotice: BloqueLegal,
    val terms: BloqueLegal,
)

/** Un bloque del texto. Un título corto y un párrafo. */
@Serializable
data class SeccionLegal(
    val title: String,
    val body: String,
)

/** BloqueLegal */
@Serializable
data class BloqueLegal(
    val title: String,
    val summary: String,
    val sections: List<SeccionLegal>,
    /** La frase que va al lado de la casilla de aceptar. */
    val acceptance: String,
)

/** La constancia de que la persona vio y aceptó el aviso de salud y los términos. Se guarda con la versión y con la hora del servidor. */
@Serializable
data class AceptacionLegal(
    /** La versión del texto que se le mostró, tal cual. */
    val version: String,
    /** Tiene que ser `true`. Existe como campo, y no se da por implícito al mandar `version`, para que un cliente no pueda "aceptar" por descuido mandando sólo la versión que tenía cacheada. */
    val accepted: Boolean,
)

/** Lo que el cliente puede escribir. Todo opcional para que `PATCH /me` mande sólo lo que cambia; `POST /auth/register/complete` exige el mínimo que el motor necesita, y esa validación es del servidor. */
@Serializable
data class PerfilEntrada(
    @SerialName("first_name")
    val firstName: String? = null,
    /** Puede ser null a propósito, igual que `goal_date_ms`: el apellido es opcional (`reg-nombre` del diseño) y quien lo cargó tiene que poder borrarlo. Sin el null, un apellido escrito una vez no se saca nunca —mandar `""` lo rechaza el `minLength`, y omitir la clave deja el valor viejo—. Aditivo: nada que hoy mande un string deja de andar. */
    @SerialName("last_name")
    val lastName: String? = null,
    @SerialName("birthdate_ms")
    val birthdateMs: Long? = null,
    @SerialName("biological_sex")
    val biologicalSex: SexoBiologico? = null,
    /** Peso corporal en **gramos**. Entero, nunca decimal. */
    @SerialName("weight_g")
    val weightG: Int? = null,
    /** Altura en **milímetros**. La regla de §5 fija la distancia en metros, pero eso es para distancias de entrenamiento: una altura en metros enteros no sirve. Ver la decisión 0005. */
    @SerialName("height_mm")
    val heightMm: Int? = null,
    val sport: Deporte? = null,
    val level: Nivel? = null,
    val goal: Objetivo? = null,
    /** Fecha de la carrera. Puede ser null a propósito: el diseño deja seguir sin fecha (`reg-objetivo`). Es una fecha SIN HORA, igual que `birthdate_ms`: viaja como la medianoche UTC del día elegido, y el servidor lee sólo la fecha en UTC (docs/API.md §1). */
    @SerialName("goal_date_ms")
    val goalDateMs: Long? = null,
    @SerialName("training_days")
    val trainingDays: List<DiaEntrenamiento>? = null,
    /** Zona IANA, p. ej. `America/Argentina/Buenos_Aires`. */
    val timezone: String? = null,
    /** Preferencia de PRESENTACIÓN. No cambia lo que se guarda: la API habla siempre en la unidad base (AGENTS.md §10). */
    @SerialName("unit_system")
    val unitSystem: String? = null,
    /** El descargo de `reg-salud`. Se guarda con su fecha del lado del servidor. */
    @SerialName("medical_disclaimer_accepted")
    val medicalDisclaimerAccepted: Boolean? = null,
    /** (1.1.0) Qué equipamiento tiene la persona, con los ids del diccionario del catálogo (`GET /exercises/dictionary`). Sin declarar, la rutina asume sin equipo. Acepta null para poder vaciarlo (docs/API.md §7). */
    val equipment: List<String>? = null,
    /** (1.1.0) 🛑 AGENTS.md §9.2: embarazo y lactancia están FUERA del flujo genérico de nutrición. Sin esta respuesta el servidor no da objetivos calóricos a quien declaró sexo biológico femenino. Es un dato de salud (§8): se pregunta sólo para eso y no se usa para nada más. */
    @SerialName("pregnant_or_breastfeeding")
    val pregnantOrBreastfeeding: Boolean? = null,
)

/** Lo que el servidor devuelve. **Nunca** incluye el hash de la contraseña, ni tokens, ni tokens de terceros (AGENTS.md §7). */
@Serializable
data class Perfil(
    val id: String,
    val email: String,
    @SerialName("first_name")
    val firstName: String? = null,
    @SerialName("last_name")
    val lastName: String? = null,
    @SerialName("birthdate_ms")
    val birthdateMs: Long? = null,
    @SerialName("biological_sex")
    val biologicalSex: SexoBiologico? = null,
    @SerialName("weight_g")
    val weightG: Int? = null,
    @SerialName("height_mm")
    val heightMm: Int? = null,
    val sport: Deporte? = null,
    val level: Nivel? = null,
    val goal: Objetivo? = null,
    @SerialName("goal_date_ms")
    val goalDateMs: Long? = null,
    @SerialName("training_days")
    val trainingDays: List<DiaEntrenamiento>? = null,
    val timezone: String? = null,
    @SerialName("unit_system")
    val unitSystem: String? = null,
    @SerialName("medical_disclaimer_accepted_at_ms")
    val medicalDisclaimerAcceptedAtMs: Long? = null,
    val equipment: List<String>? = null,
    @SerialName("pregnant_or_breastfeeding")
    val pregnantOrBreastfeeding: Boolean? = null,
    @SerialName("created_at_ms")
    val createdAtMs: Long,
    @SerialName("updated_at_ms")
    val updatedAtMs: Long,
)

/** La otra mitad de toda lista (docs/API.md §1). `next_cursor` viene sólo si hay otra página, y se devuelve tal cual en el parámetro `cursor`. */
@Serializable
data class Paginacion(
    @SerialName("next_cursor")
    val nextCursor: String? = null,
    @SerialName("has_more")
    val hasMore: Boolean,
)

/** Un ejercicio del catálogo. `pattern`, `equipment`, `muscles[].id` y `joints` son ids del diccionario y NO son enums: el catálogo es dato y crece sin publicar la app (AGENTS.md §9.1). No trae prescripción: series, repeticiones y descanso los decide la rutina, no el ejercicio. */
@Serializable
data class EjercicioCatalogado(
    val id: String,
    /** En el idioma de `Accept-Language`. */
    val name: String,
    val pattern: String,
    val equipment: String,
    /** `bilateral` o `unilateral`. String y no enum: es dato del catálogo. */
    val side: String,
    /** `reps` o `tiempo`. Con `tiempo`, las repeticiones de la rutina son segundos. */
    val unit: String,
    val muscles: List<MusculoDeEjercicio>,
    val substitutes: List<SustitutoDeEjercicio>,
    /** Qué articulaciones CARGA. Es un dato estructural, no un criterio clínico. */
    val joints: List<String>,
)

/** MusculoDeEjercicio */
@Serializable
data class MusculoDeEjercicio(
    val id: String,
    val role: RolDeMusculo,
)

/** RolDeMusculo */
@Serializable
enum class RolDeMusculo {
    @SerialName("principal")
    PRINCIPAL,

    @SerialName("secundario")
    SECUNDARIO,

}

/** SustitutoDeEjercicio */
@Serializable
data class SustitutoDeEjercicio(
    val id: String,
    val kind: TipoDeSustituto,
)

/** `mismo_patron` se intercambia sin cambiar la forma de la sesión; `mismo_musculo` carga lo mismo por otro camino y NO es un reemplazo transparente: se ofrece, no se cambia solo. */
@Serializable
enum class TipoDeSustituto {
    @SerialName("mismo_patron")
    MISMO_PATRON,

    @SerialName("mismo_musculo")
    MISMO_MUSCULO,

}

/** DiccionarioDeEjercicios */
@Serializable
data class DiccionarioDeEjercicios(
    val patterns: List<EntradaDeDiccionario>,
    val equipment: List<EntradaDeDiccionario>,
    val muscles: List<EntradaDeDiccionario>,
    val joints: List<EntradaDeDiccionario>,
)

/** EntradaDeDiccionario */
@Serializable
data class EntradaDeDiccionario(
    val id: String,
    val name: String,
)

/** Fase */
@Serializable
enum class Fase {
    @SerialName("base")
    BASE,

    @SerialName("construccion")
    CONSTRUCCION,

    @SerialName("pico")
    PICO,

    @SerialName("afinamiento")
    AFINAMIENTO,

    @SerialName("carrera")
    CARRERA,

}

/** TipoDeSesion */
@Serializable
enum class TipoDeSesion {
    @SerialName("descanso")
    DESCANSO,

    @SerialName("regenerativo")
    REGENERATIVO,

    @SerialName("suave")
    SUAVE,

    @SerialName("fondo")
    FONDO,

    @SerialName("tempo")
    TEMPO,

    @SerialName("umbral")
    UMBRAL,

    @SerialName("series")
    SERIES,

    @SerialName("cuestas")
    CUESTAS,

    @SerialName("fartlek")
    FARTLEK,

    @SerialName("ritmo_carrera")
    RITMO_CARRERA,

    @SerialName("fuerza")
    FUERZA,

    @SerialName("carrera")
    CARRERA,

}

/** DeporteDeSesion */
@Serializable
enum class DeporteDeSesion {
    @SerialName("running")
    RUNNING,

    @SerialName("ciclismo")
    CICLISMO,

    @SerialName("natacion")
    NATACION,

    @SerialName("trekking")
    TREKKING,

    @SerialName("fuerza")
    FUERZA,

    @SerialName("otro")
    OTRO,

    @SerialName("triatlon")
    TRIATLON,

}

/** Zona de frecuencia cardíaca, como porcentaje de la máxima. */
@Serializable
enum class Zona {
    @SerialName("z1")
    Z1,

    @SerialName("z2")
    Z2,

    @SerialName("z3")
    Z3,

    @SerialName("z4")
    Z4,

    @SerialName("z5")
    Z5,

}

/** Plan */
@Serializable
data class Plan(
    /** La versión del motor que hizo el cálculo. */
    @SerialName("motor_version")
    val motorVersion: String,
    /** Hash de TODO lo que entró al cálculo, motor incluido. Si no cambia, el plan tampoco: es lo que responde "¿por qué me cambió el plan?" con un dato. */
    @SerialName("input_hash")
    val inputHash: String,
    @SerialName("generated_at_ms")
    val generatedAtMs: Long,
    /** La zona con la que se armaron los días. */
    val timezone: String,
    /** El idioma de los textos: es-AR o en-US. */
    val locale: String,
    @SerialName("start_date_ms")
    val startDateMs: Long,
    /** 00:00 local del día del evento, o null si el bloque es genérico (sin fecha, o con una fecha pasada o a más de un año). */
    @SerialName("event_date_ms")
    val eventDateMs: Long?,
    @SerialName("total_weeks")
    val totalWeeks: Int,
    val goal: Objetivo,
    val phases: List<TramoDeFase>,
    val weeks: List<SemanaPlanificada>,
    val streak: PlanStreak? = null,
    val days: List<DiaPlanificado>,
)

/** TramoDeFase */
@Serializable
data class TramoDeFase(
    val phase: Fase,
    @SerialName("first_week")
    val firstWeek: Int,
    @SerialName("last_week")
    val lastWeek: Int,
)

/** SemanaPlanificada */
@Serializable
data class SemanaPlanificada(
    val number: Int,
    val phase: Fase,
    @SerialName("start_date_ms")
    val startDateMs: Long,
    /** Semana de descarga. No son opcionales (AGENTS.md §9.1). */
    @SerialName("is_deload")
    val isDeload: Boolean,
    @SerialName("planned_duration_min")
    val plannedDurationMin: Int,
    @SerialName("planned_distance_m")
    val plannedDistanceM: Int,
    /** Días de esa semana con una actividad o series de gimnasio registradas. */
    @SerialName("done_sessions")
    val doneSessions: Int,
    @SerialName("done_distance_m")
    val doneDistanceM: Int,
)

/** DiaPlanificado */
@Serializable
data class DiaPlanificado(
    @SerialName("date_ms")
    val dateMs: Long,
    /** 0 es el primer día del bloque. */
    @SerialName("day_index")
    val dayIndex: Int,
    /** ISO-8601, 1 = lunes. */
    val weekday: Int,
    @SerialName("week_number")
    val weekNumber: Int,
    val phase: Fase,
    val type: TipoDeSesion,
    val sport: DeporteDeSesion,
    /** La hora que eligió la persona para ese día de la semana. Ausente en descanso. */
    @SerialName("scheduled_minute_of_day")
    val scheduledMinuteOfDay: Int? = null,
    @SerialName("duration_min")
    val durationMin: Int,
    @SerialName("distance_m")
    val distanceM: Int? = null,
    val zone: Zona? = null,
    /** Ausente sin fecha de nacimiento. */
    @SerialName("hr_low_bpm")
    val hrLowBpm: Int? = null,
    @SerialName("hr_high_bpm")
    val hrHighBpm: Int? = null,
    @SerialName("pace_low_s_per_km")
    val paceLowSPerKm: Int? = null,
    @SerialName("pace_high_s_per_km")
    val paceHighSPerKm: Int? = null,
    /** Ausente sin peso. */
    @SerialName("estimated_kcal")
    val estimatedKcal: Int? = null,
    val fueling: Avituallamiento? = null,
    @SerialName("is_deload_week")
    val isDeloadWeek: Boolean,
    val title: String,
    val detail: String,
    val reasons: List<MotivoDelPlan>,
    /** Hay una actividad o series de gimnasio registradas ese día. */
    val done: Boolean,
)

/** El "por qué" de un día (AGENTS.md §9.1: explicable). `code` es estable; `text` viene traducido. */
@Serializable
data class MotivoDelPlan(
    val code: String,
    val text: String,
)

/** Líquido, sodio e hidratos de la sesión, calculados por el servidor. Ausente en descanso y sin peso. Los números son de un port SIN VERIFICAR (docs/PROPUESTA-MOTOR.md §2). */
@Serializable
data class Avituallamiento(
    @SerialName("fluid_ml_per_hour")
    val fluidMlPerHour: Int,
    @SerialName("fluid_total_ml")
    val fluidTotalMl: Int,
    @SerialName("sodium_mg_per_hour")
    val sodiumMgPerHour: Int,
    @SerialName("sodium_total_mg")
    val sodiumTotalMg: Int,
    @SerialName("carbs_g_per_hour")
    val carbsGPerHour: Int,
    @SerialName("carbs_total_g")
    val carbsTotalG: Int,
    val gels: Int,
    @SerialName("pre_fluid_ml")
    val preFluidMl: Int,
    @SerialName("pre_carbs_g")
    val preCarbsG: Int,
    @SerialName("post_fluid_ml")
    val postFluidMl: Int,
    @SerialName("post_carbs_g")
    val postCarbsG: Int,
    @SerialName("post_protein_g")
    val postProteinG: Int,
)

/** RutinaDelDia */
@Serializable
data class RutinaDelDia(
    @SerialName("date_ms")
    val dateMs: Long,
    /** El id con el que se sincronizan las series de esta rutina, `gym-YYYY-MM-DD`. */
    @SerialName("session_id")
    val sessionId: String,
    /** El plan pone fuerza ese día. */
    val planned: Boolean,
    /** Con qué equipamiento se eligió. `ninguno` si la persona no declaró. */
    @SerialName("equipment_assumed")
    val equipmentAssumed: List<String>,
    val exercises: List<EjercicioDeRutina>,
)

/** EjercicioDeRutina */
@Serializable
data class EjercicioDeRutina(
    @SerialName("exercise_id")
    val exerciseId: String,
    val name: String,
    val pattern: String,
    val equipment: String,
    /** `reps` o `tiempo`. */
    val unit: String,
    /** Traducido: "Para correr" o "General". */
    val label: String,
    /** El "por qué" de este ejercicio, traducido. */
    val reason: String,
    @SerialName("rest_s")
    val restS: Int,
    val sets: List<SeriePrescritaDeRutina>,
    /** La columna PREVIA. Vacía si nunca lo hizo. */
    @SerialName("previous_sets")
    val previousSets: List<SerieAnterior>,
)

/** SeriePrescritaDeRutina */
@Serializable
data class SeriePrescritaDeRutina(
    val number: Int,
    /** Repeticiones, o segundos si `unit` es `tiempo`. */
    val reps: Int,
    /** Gramos. Hoy no viene nunca: el motor no prescribe carga. */
    @SerialName("weight_g")
    val weightG: Int? = null,
)

/** SerieAnterior */
@Serializable
data class SerieAnterior(
    val number: Int,
    val reps: Int,
    @SerialName("weight_g")
    val weightG: Int? = null,
    val skipped: Boolean,
)

/** DispositivoDeOrigen */
@Serializable
enum class DispositivoDeOrigen {
    @SerialName("telefono")
    TELEFONO,

    @SerialName("reloj")
    RELOJ,

}

/** SerieDeGimnasioEntrada */
@Serializable
data class SerieDeGimnasioEntrada(
    @SerialName("exercise_id")
    val exerciseId: String,
    /** 1-based. Las extra siguen numerando. */
    val number: Int,
    val done: Boolean,
    val reps: Int,
    /** Gramos. Sin el campo, peso corporal. */
    @SerialName("weight_g")
    val weightG: Int? = null,
    val skipped: Boolean,
    @SerialName("is_extra")
    val isExtra: Boolean,
    @SerialName("recorded_at_ms")
    val recordedAtMs: Long,
    val device: DispositivoDeOrigen,
)

/** SerieDeGimnasio */
@Serializable
data class SerieDeGimnasio(
    @SerialName("exercise_id")
    val exerciseId: String,
    val number: Int,
    val done: Boolean,
    val reps: Int,
    @SerialName("weight_g")
    val weightG: Int? = null,
    val skipped: Boolean,
    @SerialName("is_extra")
    val isExtra: Boolean,
    @SerialName("recorded_at_ms")
    val recordedAtMs: Long,
    @SerialName("received_at_ms")
    val receivedAtMs: Long,
    val device: DispositivoDeOrigen,
)

/** SesionDeGimnasio */
@Serializable
data class SesionDeGimnasio(
    @SerialName("session_id")
    val sessionId: String,
    @SerialName("date_ms")
    val dateMs: Long? = null,
    @SerialName("updated_at_ms")
    val updatedAtMs: Long,
    val sets: List<SerieDeGimnasio>,
)

/** ResumenDeSesionDeGimnasio */
@Serializable
data class ResumenDeSesionDeGimnasio(
    @SerialName("session_id")
    val sessionId: String,
    @SerialName("date_ms")
    val dateMs: Long? = null,
    @SerialName("updated_at_ms")
    val updatedAtMs: Long,
    @SerialName("sets_done")
    val setsDone: Int,
    val exercises: Int,
)

/** ActividadEntrada */
@Serializable
data class ActividadEntrada(
    val sport: DeporteDeSesion,
    @SerialName("started_at_ms")
    val startedAtMs: Long,
    @SerialName("duration_s")
    val durationS: Int,
    @SerialName("distance_m")
    val distanceM: Int? = null,
    @SerialName("elevation_gain_m")
    val elevationGainM: Int? = null,
    @SerialName("avg_hr_bpm")
    val avgHrBpm: Int? = null,
    @SerialName("max_hr_bpm")
    val maxHrBpm: Int? = null,
    val kcal: Int? = null,
    val device: DispositivoDeOrigen,
)

/** Actividad */
@Serializable
data class Actividad(
    val id: String,
    val sport: DeporteDeSesion,
    @SerialName("started_at_ms")
    val startedAtMs: Long,
    @SerialName("duration_s")
    val durationS: Int,
    @SerialName("distance_m")
    val distanceM: Int? = null,
    @SerialName("elevation_gain_m")
    val elevationGainM: Int? = null,
    @SerialName("avg_hr_bpm")
    val avgHrBpm: Int? = null,
    @SerialName("max_hr_bpm")
    val maxHrBpm: Int? = null,
    val kcal: Int? = null,
    val device: DispositivoDeOrigen,
    @SerialName("created_at_ms")
    val createdAtMs: Long,
    @SerialName("updated_at_ms")
    val updatedAtMs: Long,
)

/** CargaDelDia */
@Serializable
enum class CargaDelDia {
    @SerialName("descanso")
    DESCANSO,

    @SerialName("baja")
    BAJA,

    @SerialName("moderada")
    MODERADA,

    @SerialName("alta")
    ALTA,

    @SerialName("competencia")
    COMPETENCIA,

}

/** Por qué NO hay objetivos (AGENTS.md §9.2). La app muestra apoyo y, si corresponde, la pregunta que falta; nunca un número inventado. */
@Serializable
enum class MotivoSinObjetivos {
    @SerialName("perfil_incompleto")
    PERFIL_INCOMPLETO,

    @SerialName("menor_de_edad")
    MENOR_DE_EDAD,

    @SerialName("sexo_sin_declarar")
    SEXO_SIN_DECLARAR,

    @SerialName("falta_embarazo_o_lactancia")
    FALTA_EMBARAZO_O_LACTANCIA,

    @SerialName("embarazo_o_lactancia")
    EMBARAZO_O_LACTANCIA,

}

/** ObjetivosDelDia */
@Serializable
data class ObjetivosDelDia(
    val kcal: Int,
    @SerialName("carbs_g")
    val carbsG: Int,
    @SerialName("protein_g")
    val proteinG: Int,
    @SerialName("fat_g")
    val fatG: Int,
    @SerialName("water_ml")
    val waterMl: Int,
    @SerialName("sodium_mg")
    val sodiumMg: Int,
    @SerialName("day_load")
    val dayLoad: CargaDelDia,
    /** Los guardarraíles subieron el número. */
    val adjusted: Boolean,
    /** `piso_calorico` o `techo_de_deficit`. */
    @SerialName("adjustment_reason")
    val adjustmentReason: String? = null,
    /** Los números no los revisó nadie con formación. En producción el servidor no arranca así. */
    val provisional: Boolean,
)

/** TotalesNutricionales */
@Serializable
data class TotalesNutricionales(
    val kcal: Int,
    @SerialName("carbs_g")
    val carbsG: Int,
    @SerialName("protein_g")
    val proteinG: Int,
    @SerialName("fat_g")
    val fatG: Int,
)

/** DiaNutricional */
@Serializable
data class DiaNutricional(
    @SerialName("date_ms")
    val dateMs: Long,
    val targets: ObjetivosDelDia? = null,
    @SerialName("unavailable_reason")
    val unavailableReason: MotivoSinObjetivos? = null,
    val consumed: TotalesNutricionales,
    val meals: List<ComidaRegistrada>,
)

/** ComidaEntrada */
@Serializable
data class ComidaEntrada(
    @SerialName("eaten_at_ms")
    val eatenAtMs: Long,
    val name: String,
    val kcal: Int,
    @SerialName("carbs_g")
    val carbsG: Int,
    @SerialName("protein_g")
    val proteinG: Int,
    @SerialName("fat_g")
    val fatG: Int,
)

/** ComidaRegistrada */
@Serializable
data class ComidaRegistrada(
    val id: String,
    @SerialName("eaten_at_ms")
    val eatenAtMs: Long,
    val name: String,
    val kcal: Int,
    @SerialName("carbs_g")
    val carbsG: Int,
    @SerialName("protein_g")
    val proteinG: Int,
    @SerialName("fat_g")
    val fatG: Int,
    @SerialName("created_at_ms")
    val createdAtMs: Long,
    @SerialName("updated_at_ms")
    val updatedAtMs: Long,
)

/** AceptacionRegistrada */
@Serializable
data class AceptacionRegistrada(
    val version: String,
    @SerialName("accepted_at_ms")
    val acceptedAtMs: Long,
    val reason: String,
)

/** AnclaDePlan */
@Serializable
data class AnclaDePlan(
    /** ID del objetivo adicional; omitido para el principal. */
    @SerialName("goal_id")
    val goalId: String? = null,
    @SerialName("motor_version")
    val motorVersion: String,
    @SerialName("start_date_ms")
    val startDateMs: Long,
    val timezone: String,
    @SerialName("created_at_ms")
    val createdAtMs: Long,
    @SerialName("replaced_at_ms")
    val replacedAtMs: Long? = null,
)

/** ExportacionDeDatos */
@Serializable
data class ExportacionDeDatos(
    @SerialName("exported_at_ms")
    val exportedAtMs: Long,
    val profile: Perfil,
    val goals: List<ObjetivoExportado>,
    @SerialName("legal_acceptances")
    val legalAcceptances: List<AceptacionRegistrada>,
    val plans: List<AnclaDePlan>,
    @SerialName("gym_sessions")
    val gymSessions: List<SesionDeGimnasio>,
    val activities: List<Actividad>,
    val meals: List<ComidaRegistrada>,
)

/** ObjetivoExportado */
@Serializable
data class ObjetivoExportado(
    val id: String,
    val goal: Objetivo,
    @SerialName("goal_date_ms")
    val goalDateMs: Long?,
    val order: Int,
    @SerialName("created_at_ms")
    val createdAtMs: Long,
    @SerialName("completed_at_ms")
    val completedAtMs: Long?,
)

/** Error */
@Serializable
data class Error(
    val error: DetalleDeError,
)

/** El cuerpo del sobre de error. Estaba escrito adentro de Error, sin nombre; se extrajo el 2026-09-08 por el mismo motivo que EstadoDeDependencias. La forma en el cable NO cambia. */
@Serializable
data class DetalleDeError(
    /** **Estable y parte del contrato.** El cliente lo mapea a su texto traducido. La lista completa está en docs/API.md. */
    val code: String,
    /** Para el log del desarrollador y como respaldo. **El cliente no lo muestra tal cual**: muestra su propia traducción del `code`. Nunca lleva datos de salud ni de identidad (AGENTS.md §8). */
    val message: String,
)

/** Parte de Plan. No tiene nombre en el contrato. */
@Serializable
data class PlanStreak(
    val current: Int,
    @SerialName("active_today")
    val activeToday: Boolean,
    @SerialName("trained_today")
    val trainedToday: Boolean,
    @SerialName("scheduled_today")
    val scheduledToday: Boolean,
)
