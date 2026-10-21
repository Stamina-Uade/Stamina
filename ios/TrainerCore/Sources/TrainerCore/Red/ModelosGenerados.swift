// =============================================================================
// GENERADO por scripts/generar-modelos-swift.mjs desde shared/api/openapi.yaml
// NO EDITAR A MANO: se reescribe en cada `npm run generar:modelos`, y el CI
// falla si el archivo commiteado no coincide con lo que el generador produce.
//
// Contrato 1.4.0
//
// AGENTS.md §4.2: los modelos de red se generan desde el contrato, no se
// escriben a mano. AGENTS.md §5: a partir de la primera versión en tienda,
// cambiar la forma o el tipo de algo de acá ROMPE apps ya instaladas.
//
// Convenciones del contrato que se ven acá:
//   - Los IDs son String, siempre, aunque hoy sean UUID.
//   - Los tiempos son Int64 de milisegundos epoch. NO son Date: el decoder no
//     inventa zonas horarias, y la conversión es del que presenta.
//   - Las unidades son enteras y base: peso en gramos, altura en milímetros.
//   - Lo que el contrato no marca `required` es opcional en Swift.
// =============================================================================

import Foundation


/// Milisegundos desde epoch, UTC. Entero. Es el ÚNICO formato de tiempo de la API.
public typealias EpochMs = Int64

/// Identificador. **Siempre string**, aunque hoy sea un UUID: es lo único que deja cambiar de tipo sin romper decoders tipados de Swift y Kotlin.
public typealias Id = String

/// Se normaliza a minúsculas en el servidor antes de comparar.
public typealias Email = String

/// Mínimo 10 caracteres, con al menos una mayúscula y al menos un número. Las mayúsculas acentuadas y la Ñ cuentan: el servidor usa `\p{Lu}`, no `[A-Z]`.
/// Esas tres son las reglas que la app MUESTRA mientras alguien escribe (`design/origen/Trainer App.dc.html`, pantalla `fpNew`: tres barras y tres puntitos). El servidor además rechaza, sin anticiparlo, las que están en su lista de contraseñas conocidas y las que tienen menos de cuatro caracteres distintos; las dos devuelven `weak_password`.
/// Se guarda con argon2id, nunca en claro y nunca en un log.
public typealias Password = String

/// 6 alfanuméricos en mayúscula, como el diseño (design/ESPECIFICACION.md §5.1). Vive 15 minutos y se puede reenviar a los 60 segundos.
public typealias CodigoVerificacion = String

/// Los cuatro clientes de AGENTS.md §1.3. Cada uno versiona por separado.
public enum Plataforma: String, Codable, CaseIterable, Sendable {
    case android = "android"
    case ios = "ios"
    case wear = "wear"
    case watchos = "watchos"
}

public struct Health: Codable, Equatable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case ok = "ok"
        case degraded = "degraded"
        case down = "down"
    }

    public let status: Status
    /// Versión desplegada de Trainer. No la de Postgres ni la del sistema.
    public let version: String
    public let dependencies: EstadoDeDependencias

    public init(
        status: Status,
        version: String,
        dependencies: EstadoDeDependencias
    ) {
        self.status = status
        self.version = version
        self.dependencies = dependencies
    }
}

/// Estaba escrito adentro de Health, sin nombre. Se extrajo el 2026-09-08 para que el generador de modelos pueda emitirlo: un objeto anonimo obliga a inventarle un nombre al cliente, y cada cliente inventa el suyo. La forma en el cable NO cambia: es el mismo objeto en el mismo lugar.
public struct EstadoDeDependencias: Codable, Equatable, Sendable {
    public enum Database: String, Codable, CaseIterable, Sendable {
        case ok = "ok"
        case down = "down"
    }

    public enum Redis: String, Codable, CaseIterable, Sendable {
        case ok = "ok"
        case down = "down"
        case disabled = "disabled"
    }

    public let database: Database
    /// `disabled` (1.1.0) no es una falla: el servidor corre con `REDIS_URL=disabled` a propósito y la caché vive en el proceso (decisión 0011). No baja el `status` a `degraded`.
    public let redis: Redis

    public init(
        database: Database,
        redis: Redis
    ) {
        self.database = database
        self.redis = redis
    }
}

public struct VersionGate: Codable, Equatable, Sendable {
    public enum Action: String, Codable, CaseIterable, Sendable {
        case ok = "ok"
        case updateRecommended = "update_recommended"
        case updateRequired = "update_required"
    }

    public let platform: Plataforma
    /// Por debajo de esto la app **no puede seguir**.
    public let minimumBuild: Int64
    public let recommendedBuild: Int64
    /// Resuelto por el servidor cuando el cliente manda su `build`. Si no lo manda, viene `ok` y el cliente compara solo.
    public let action: Action
    /// Clave estable del mensaje. El cliente la mapea a su propio texto traducido; `message` es el respaldo para cuando todavía no la conoce.
    public let code: String?
    /// Texto ya traducido por el servidor según `Accept-Language`.
    public let message: String?
    /// A dónde mandar a la persona a actualizar.
    public let storeUrl: String?

    enum CodingKeys: String, CodingKey {
        case platform
        case minimumBuild = "minimum_build"
        case recommendedBuild = "recommended_build"
        case action
        case code
        case message
        case storeUrl = "store_url"
    }

    public init(
        platform: Plataforma,
        minimumBuild: Int64,
        recommendedBuild: Int64,
        action: Action,
        code: String? = nil,
        message: String? = nil,
        storeUrl: String? = nil
    ) {
        self.platform = platform
        self.minimumBuild = minimumBuild
        self.recommendedBuild = recommendedBuild
        self.action = action
        self.code = code
        self.message = message
        self.storeUrl = storeUrl
    }
}

/// Lo que se puede decir sin filtrar si la cuenta existe: cuánto vive el código y cuándo se puede pedir otro. Nada más.
public struct DesafioCorreo: Codable, Equatable, Sendable {
    public let expiresAtMs: Int64
    public let resendAfterMs: Int64

    enum CodingKeys: String, CodingKey {
        case expiresAtMs = "expires_at_ms"
        case resendAfterMs = "resend_after_ms"
    }

    public init(
        expiresAtMs: Int64,
        resendAfterMs: Int64
    ) {
        self.expiresAtMs = expiresAtMs
        self.resendAfterMs = resendAfterMs
    }
}

/// Lo que devuelve /auth/register/verify: el permiso de un solo uso para completar el registro. Estaba escrito adentro de la respuesta, sin nombre; se extrajo el 2026-09-09 para que el generador de modelos pueda emitirlo. La forma en el cable NO cambia.
public struct TokenDeRegistro: Codable, Equatable, Sendable {
    public let registrationToken: String
    public let expiresAtMs: Int64

    enum CodingKeys: String, CodingKey {
        case registrationToken = "registration_token"
        case expiresAtMs = "expires_at_ms"
    }

    public init(
        registrationToken: String,
        expiresAtMs: Int64
    ) {
        self.registrationToken = registrationToken
        self.expiresAtMs = expiresAtMs
    }
}

/// Lo que devuelve /auth/password/verify: el permiso de un solo uso para poner la contraseña nueva. Estaba escrito adentro de la respuesta, sin nombre; se extrajo el 2026-09-09 por el mismo motivo que TokenDeRegistro —el generador de modelos no emite objetos anónimos— al escribir las pantallas de recuperar contraseña. La forma en el cable NO cambia.
public struct TokenDeReseteo: Codable, Equatable, Sendable {
    public let resetToken: String
    public let expiresAtMs: Int64

    enum CodingKeys: String, CodingKey {
        case resetToken = "reset_token"
        case expiresAtMs = "expires_at_ms"
    }

    public init(
        resetToken: String,
        expiresAtMs: Int64
    ) {
        self.resetToken = resetToken
        self.expiresAtMs = expiresAtMs
    }
}

public struct Sesion: Codable, Equatable, Sendable {
    /// Corto. Va en el header `Authorization`, con el esquema Bearer.
    public let accessToken: String
    public let accessExpiresAtMs: Int64
    /// Rota en cada uso. En el cliente va al almacenamiento seguro de la plataforma —Keystore o Keychain—, nunca a preferencias planas ni a un log (AGENTS.md §12.1).
    public let refreshToken: String
    public let refreshExpiresAtMs: Int64
    public let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accessExpiresAtMs = "access_expires_at_ms"
        case refreshToken = "refresh_token"
        case refreshExpiresAtMs = "refresh_expires_at_ms"
        case userId = "user_id"
    }

    public init(
        accessToken: String,
        accessExpiresAtMs: Int64,
        refreshToken: String,
        refreshExpiresAtMs: Int64,
        userId: String
    ) {
        self.accessToken = accessToken
        self.accessExpiresAtMs = accessExpiresAtMs
        self.refreshToken = refreshToken
        self.refreshExpiresAtMs = refreshExpiresAtMs
        self.userId = userId
    }
}

/// Lo que contesta `POST /auth/social`. Trae `session` o `signup`, según `status`.
public struct EntradaSocial: Codable, Equatable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case signedIn = "signed_in"
        case signupRequired = "signup_required"
    }

    public let status: Status
    public let session: Sesion?
    public let signup: AltaSocialPendiente?

    public init(
        status: Status,
        session: Sesion? = nil,
        signup: AltaSocialPendiente? = nil
    ) {
        self.status = status
        self.session = session
        self.signup = signup
    }
}

/// El permiso para terminar un alta que empezó con Google o Apple. `email` es el que dio el proveedor (puede ser un relay privado de Apple, o faltar). Si `email_verified` es `true`, ése es el correo de la cuenta y no se pide código; si no, la persona valida un correo con el código como siempre.
public struct AltaSocialPendiente: Codable, Equatable, Sendable {
    public let signupToken: String
    public let expiresAtMs: Int64
    /// Si el proveedor verificó `email`. Con `true` el alta no pide el código al correo y el campo no se puede cambiar.
    public let emailVerified: Bool?
    public let email: String?

    enum CodingKeys: String, CodingKey {
        case signupToken = "signup_token"
        case expiresAtMs = "expires_at_ms"
        case emailVerified = "email_verified"
        case email
    }

    public init(
        signupToken: String,
        expiresAtMs: Int64,
        emailVerified: Bool? = nil,
        email: String? = nil
    ) {
        self.signupToken = signupToken
        self.expiresAtMs = expiresAtMs
        self.emailVerified = emailVerified
        self.email = email
    }
}

/// Para el cálculo de sudoración y de metabolismo basal, no para nada más. Incluye "prefiero no decirlo" como el diseño (`reg-sexo`).
public enum SexoBiologico: String, Codable, CaseIterable, Sendable {
    case femenino = "femenino"
    case masculino = "masculino"
    case sinDeclarar = "sin_declarar"
}

public enum Deporte: String, Codable, CaseIterable, Sendable {
    case running = "running"
    case ciclismo = "ciclismo"
    case trekking = "trekking"
    case triatlon = "triatlon"
}

public enum Nivel: String, Codable, CaseIterable, Sendable {
    case principiante = "principiante"
    case intermedio = "intermedio"
    case avanzado = "avanzado"
}

/// Los 7 objetivos cerrados de `reg-objetivo` (design/ESPECIFICACION.md §5.1). Cerrar la lista es lo que hace que el motor del plan sea determinístico (AGENTS.md §9.1).
public enum Objetivo: String, Codable, CaseIterable, Sendable {
    case c5k = "c5k"
    case c10k = "c10k"
    case mediaMaraton = "media_maraton"
    case maraton = "maraton"
    case trailMontana = "trail_montana"
    case triatlonOlimpico = "triatlon_olimpico"
    case volverSinLesiones = "volver_sin_lesiones"
}

/// `goal_date_ms` ausente equivale a `null` (sin fecha) desde la 1.2.1; antes era obligatorio y un cliente que omitía los nulos recibía un 400.
public struct ObjetivoEntrada: Codable, Equatable, Sendable {
    /// principal para el primero, UUID existente para los demás; omitir al crear.
    public let id: String?
    public let goal: Objetivo
    public let goalDateMs: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case goal
        case goalDateMs = "goal_date_ms"
    }

    public init(
        id: String? = nil,
        goal: Objetivo,
        goalDateMs: Int64? = nil
    ) {
        self.id = id
        self.goal = goal
        self.goalDateMs = goalDateMs
    }
}

public struct ObjetivoActivo: Codable, Equatable, Sendable {
    public let id: String
    public let goal: Objetivo
    public let goalDateMs: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case goal
        case goalDateMs = "goal_date_ms"
    }

    public init(
        id: String,
        goal: Objetivo,
        goalDateMs: Int64? = nil
    ) {
        self.id = id
        self.goal = goal
        self.goalDateMs = goalDateMs
    }
}

public struct PlanDeObjetivo: Codable, Equatable, Sendable {
    public let goalId: String
    public let plan: Plan

    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case plan
    }

    public init(
        goalId: String,
        plan: Plan
    ) {
        self.goalId = goalId
        self.plan = plan
    }
}

public struct PronosticoDeCalor: Codable, Equatable, Sendable {
    /// MET Norway
    public let source: String
    public let sourceUrl: String
    public let hours: [HoraDePronostico]

    enum CodingKeys: String, CodingKey {
        case source
        case sourceUrl = "source_url"
        case hours
    }

    public init(
        source: String,
        sourceUrl: String,
        hours: [HoraDePronostico]
    ) {
        self.source = source
        self.sourceUrl = sourceUrl
        self.hours = hours
    }
}

public struct HoraDePronostico: Codable, Equatable, Sendable {
    public let atMs: Int64
    public let airTemperatureC: Double

    enum CodingKeys: String, CodingKey {
        case atMs = "at_ms"
        case airTemperatureC = "air_temperature_c"
    }

    public init(
        atMs: Int64,
        airTemperatureC: Double
    ) {
        self.atMs = atMs
        self.airTemperatureC = airTemperatureC
    }
}

public struct DiaEntrenamiento: Codable, Equatable, Sendable {
    /// ISO-8601, 1 = lunes. La semana del diseño empieza el lunes.
    public let weekday: Int64
    /// Minutos desde la medianoche **local de la persona**. Sin zona no significa nada, por eso el perfil lleva `timezone`.
    public let minuteOfDay: Int64

    enum CodingKeys: String, CodingKey {
        case weekday
        case minuteOfDay = "minute_of_day"
    }

    public init(
        weekday: Int64,
        minuteOfDay: Int64
    ) {
        self.weekday = weekday
        self.minuteOfDay = minuteOfDay
    }
}

/// El aviso de salud y los términos, tal como se muestran. La estructura es deliberadamente tonta —título, resumen y una lista de bloques— porque el texto lo edita quien lo revise, no quien programa: cuantos menos campos con significado, menos chances de que un cambio de redacción rompa la pantalla.
public struct TextosLegales: Codable, Equatable, Sendable {
    public enum Language: String, Codable, CaseIterable, Sendable {
        case es = "es"
        case en = "en"
        case fr = "fr"
    }

    public let version: String
    /// `false` mientras el texto sea un borrador que no revisó nadie con formación legal. El servidor **no arranca en producción** con esto en `false`; el campo existe para que se vea en desarrollo.
    public let reviewed: Bool?
    public let healthNotice: BloqueLegal
    public let terms: BloqueLegal
    /// (1.4.0) La política de privacidad. Opcional para que un cliente nuevo lea la respuesta de un servidor anterior.
    public let privacy: BloqueLegal?
    /// (1.4.0) En qué idioma vinieron los textos, según `Accept-Language`: es, fr, o en para cualquier otro.
    public let language: Language?

    enum CodingKeys: String, CodingKey {
        case version
        case reviewed
        case healthNotice = "health_notice"
        case terms
        case privacy
        case language
    }

    public init(
        version: String,
        reviewed: Bool? = nil,
        healthNotice: BloqueLegal,
        terms: BloqueLegal,
        privacy: BloqueLegal? = nil,
        language: Language? = nil
    ) {
        self.version = version
        self.reviewed = reviewed
        self.healthNotice = healthNotice
        self.terms = terms
        self.privacy = privacy
        self.language = language
    }
}

/// Un bloque del texto. Un título corto y un párrafo.
public struct SeccionLegal: Codable, Equatable, Sendable {
    public let title: String
    public let body: String

    public init(
        title: String,
        body: String
    ) {
        self.title = title
        self.body = body
    }
}

public struct BloqueLegal: Codable, Equatable, Sendable {
    public let title: String
    public let summary: String
    public let sections: [SeccionLegal]
    /// La frase que va al lado de la casilla de aceptar.
    public let acceptance: String

    public init(
        title: String,
        summary: String,
        sections: [SeccionLegal],
        acceptance: String
    ) {
        self.title = title
        self.summary = summary
        self.sections = sections
        self.acceptance = acceptance
    }
}

/// La constancia de que la persona vio y aceptó el aviso de salud y los términos. Se guarda con la versión y con la hora del servidor.
/// `version` es la de `shared/datos/textos-legales.json`. Es el campo que hace que esto valga: sin él queda un "sí" sin referencia a qué se dijo.
/// No hay dos campos separados para el aviso y los términos porque el aviso de salud **es parte** de los términos (sección 2) y se aceptan en la misma pantalla. Si algún día se separan, se agrega un campo; sacarlo sería un cambio incompatible.
public struct AceptacionLegal: Codable, Equatable, Sendable {
    /// La versión del texto que se le mostró, tal cual.
    public let version: String
    /// Tiene que ser `true`. Existe como campo, y no se da por implícito al mandar `version`, para que un cliente no pueda "aceptar" por descuido mandando sólo la versión que tenía cacheada.
    public let accepted: Bool

    public init(
        version: String,
        accepted: Bool
    ) {
        self.version = version
        self.accepted = accepted
    }
}

/// Lo que el cliente puede escribir. Todo opcional para que `PATCH /me` mande sólo lo que cambia; `POST /auth/register/complete` exige el mínimo que el motor necesita, y esa validación es del servidor.
public struct PerfilEntrada: Codable, Equatable, Sendable {
    public enum UnitSystem: String, Codable, CaseIterable, Sendable {
        case metrico = "metrico"
        case imperial = "imperial"
    }

    public let firstName: String?
    /// Puede ser null a propósito, igual que `goal_date_ms`: el apellido es opcional (`reg-nombre` del diseño) y quien lo cargó tiene que poder borrarlo. Sin el null, un apellido escrito una vez no se saca nunca —mandar `""` lo rechaza el `minLength`, y omitir la clave deja el valor viejo—. Aditivo: nada que hoy mande un string deja de andar.
    public let lastName: String?
    public let birthdateMs: Int64?
    public let biologicalSex: SexoBiologico?
    /// Peso corporal en **gramos**. Entero, nunca decimal.
    public let weightG: Int64?
    /// Altura en **milímetros**. La regla de §5 fija la distancia en metros, pero eso es para distancias de entrenamiento: una altura en metros enteros no sirve. Ver la decisión 0005.
    public let heightMm: Int64?
    public let sport: Deporte?
    public let level: Nivel?
    public let goal: Objetivo?
    /// Fecha de la carrera. Puede ser null a propósito: el diseño deja seguir sin fecha (`reg-objetivo`). Es una fecha SIN HORA, igual que `birthdate_ms`: viaja como la medianoche UTC del día elegido, y el servidor lee sólo la fecha en UTC (docs/API.md §1).
    public let goalDateMs: Int64?
    public let trainingDays: [DiaEntrenamiento]?
    /// Zona IANA, p. ej. `America/Argentina/Buenos_Aires`.
    public let timezone: String?
    /// Preferencia de PRESENTACIÓN. No cambia lo que se guarda: la API habla siempre en la unidad base (AGENTS.md §10).
    public let unitSystem: UnitSystem?
    /// El descargo de `reg-salud`. Se guarda con su fecha del lado del servidor.
    public let medicalDisclaimerAccepted: Bool?
    /// (1.1.0) Qué equipamiento tiene la persona, con los ids del diccionario del catálogo (`GET /exercises/dictionary`). Sin declarar, la rutina asume sin equipo. Acepta null para poder vaciarlo (docs/API.md §7).
    public let equipment: [String]?
    /// (1.1.0) 🛑 AGENTS.md §9.2: embarazo y lactancia están FUERA del flujo genérico de nutrición. Sin esta respuesta el servidor no da objetivos calóricos a quien declaró sexo biológico femenino. Es un dato de salud (§8): se pregunta sólo para eso y no se usa para nada más.
    public let pregnantOrBreastfeeding: Bool?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case birthdateMs = "birthdate_ms"
        case biologicalSex = "biological_sex"
        case weightG = "weight_g"
        case heightMm = "height_mm"
        case sport
        case level
        case goal
        case goalDateMs = "goal_date_ms"
        case trainingDays = "training_days"
        case timezone
        case unitSystem = "unit_system"
        case medicalDisclaimerAccepted = "medical_disclaimer_accepted"
        case equipment
        case pregnantOrBreastfeeding = "pregnant_or_breastfeeding"
    }

    public init(
        firstName: String? = nil,
        lastName: String? = nil,
        birthdateMs: Int64? = nil,
        biologicalSex: SexoBiologico? = nil,
        weightG: Int64? = nil,
        heightMm: Int64? = nil,
        sport: Deporte? = nil,
        level: Nivel? = nil,
        goal: Objetivo? = nil,
        goalDateMs: Int64? = nil,
        trainingDays: [DiaEntrenamiento]? = nil,
        timezone: String? = nil,
        unitSystem: UnitSystem? = nil,
        medicalDisclaimerAccepted: Bool? = nil,
        equipment: [String]? = nil,
        pregnantOrBreastfeeding: Bool? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.birthdateMs = birthdateMs
        self.biologicalSex = biologicalSex
        self.weightG = weightG
        self.heightMm = heightMm
        self.sport = sport
        self.level = level
        self.goal = goal
        self.goalDateMs = goalDateMs
        self.trainingDays = trainingDays
        self.timezone = timezone
        self.unitSystem = unitSystem
        self.medicalDisclaimerAccepted = medicalDisclaimerAccepted
        self.equipment = equipment
        self.pregnantOrBreastfeeding = pregnantOrBreastfeeding
    }
}

/// Lo que el servidor devuelve. **Nunca** incluye el hash de la contraseña, ni tokens, ni tokens de terceros (AGENTS.md §7).
public struct Perfil: Codable, Equatable, Sendable {
    public enum UnitSystem: String, Codable, CaseIterable, Sendable {
        case metrico = "metrico"
        case imperial = "imperial"
    }

    public let id: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let birthdateMs: Int64?
    public let biologicalSex: SexoBiologico?
    public let weightG: Int64?
    public let heightMm: Int64?
    public let sport: Deporte?
    public let level: Nivel?
    public let goal: Objetivo?
    public let goalDateMs: Int64?
    public let trainingDays: [DiaEntrenamiento]?
    public let timezone: String?
    public let unitSystem: UnitSystem?
    public let medicalDisclaimerAcceptedAtMs: Int64?
    public let equipment: [String]?
    public let pregnantOrBreastfeeding: Bool?
    public let createdAtMs: Int64
    public let updatedAtMs: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case birthdateMs = "birthdate_ms"
        case biologicalSex = "biological_sex"
        case weightG = "weight_g"
        case heightMm = "height_mm"
        case sport
        case level
        case goal
        case goalDateMs = "goal_date_ms"
        case trainingDays = "training_days"
        case timezone
        case unitSystem = "unit_system"
        case medicalDisclaimerAcceptedAtMs = "medical_disclaimer_accepted_at_ms"
        case equipment
        case pregnantOrBreastfeeding = "pregnant_or_breastfeeding"
        case createdAtMs = "created_at_ms"
        case updatedAtMs = "updated_at_ms"
    }

    public init(
        id: String,
        email: String,
        firstName: String? = nil,
        lastName: String? = nil,
        birthdateMs: Int64? = nil,
        biologicalSex: SexoBiologico? = nil,
        weightG: Int64? = nil,
        heightMm: Int64? = nil,
        sport: Deporte? = nil,
        level: Nivel? = nil,
        goal: Objetivo? = nil,
        goalDateMs: Int64? = nil,
        trainingDays: [DiaEntrenamiento]? = nil,
        timezone: String? = nil,
        unitSystem: UnitSystem? = nil,
        medicalDisclaimerAcceptedAtMs: Int64? = nil,
        equipment: [String]? = nil,
        pregnantOrBreastfeeding: Bool? = nil,
        createdAtMs: Int64,
        updatedAtMs: Int64
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.birthdateMs = birthdateMs
        self.biologicalSex = biologicalSex
        self.weightG = weightG
        self.heightMm = heightMm
        self.sport = sport
        self.level = level
        self.goal = goal
        self.goalDateMs = goalDateMs
        self.trainingDays = trainingDays
        self.timezone = timezone
        self.unitSystem = unitSystem
        self.medicalDisclaimerAcceptedAtMs = medicalDisclaimerAcceptedAtMs
        self.equipment = equipment
        self.pregnantOrBreastfeeding = pregnantOrBreastfeeding
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
    }
}

/// La otra mitad de toda lista (docs/API.md §1). `next_cursor` viene sólo si hay otra página, y se devuelve tal cual en el parámetro `cursor`.
public struct Paginacion: Codable, Equatable, Sendable {
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }

    public init(
        nextCursor: String? = nil,
        hasMore: Bool
    ) {
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

/// Un ejercicio del catálogo. `pattern`, `equipment`, `muscles[].id` y `joints` son ids del diccionario y NO son enums: el catálogo es dato y crece sin publicar la app (AGENTS.md §9.1). No trae prescripción: series, repeticiones y descanso los decide la rutina, no el ejercicio.
public struct EjercicioCatalogado: Codable, Equatable, Sendable {
    public let id: String
    /// En el idioma de `Accept-Language`.
    public let name: String
    public let pattern: String
    public let equipment: String
    /// `bilateral` o `unilateral`. String y no enum: es dato del catálogo.
    public let side: String
    /// `reps` o `tiempo`. Con `tiempo`, las repeticiones de la rutina son segundos.
    public let unit: String
    public let muscles: [MusculoDeEjercicio]
    public let substitutes: [SustitutoDeEjercicio]
    /// Qué articulaciones CARGA. Es un dato estructural, no un criterio clínico.
    public let joints: [String]

    public init(
        id: String,
        name: String,
        pattern: String,
        equipment: String,
        side: String,
        unit: String,
        muscles: [MusculoDeEjercicio],
        substitutes: [SustitutoDeEjercicio],
        joints: [String]
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.equipment = equipment
        self.side = side
        self.unit = unit
        self.muscles = muscles
        self.substitutes = substitutes
        self.joints = joints
    }
}

public struct MusculoDeEjercicio: Codable, Equatable, Sendable {
    public let id: String
    public let role: RolDeMusculo

    public init(
        id: String,
        role: RolDeMusculo
    ) {
        self.id = id
        self.role = role
    }
}

public enum RolDeMusculo: String, Codable, CaseIterable, Sendable {
    case principal = "principal"
    case secundario = "secundario"
}

public struct SustitutoDeEjercicio: Codable, Equatable, Sendable {
    public let id: String
    public let kind: TipoDeSustituto

    public init(
        id: String,
        kind: TipoDeSustituto
    ) {
        self.id = id
        self.kind = kind
    }
}

/// `mismo_patron` se intercambia sin cambiar la forma de la sesión; `mismo_musculo` carga lo mismo por otro camino y NO es un reemplazo transparente: se ofrece, no se cambia solo.
public enum TipoDeSustituto: String, Codable, CaseIterable, Sendable {
    case mismoPatron = "mismo_patron"
    case mismoMusculo = "mismo_musculo"
}

public struct DiccionarioDeEjercicios: Codable, Equatable, Sendable {
    public let patterns: [EntradaDeDiccionario]
    public let equipment: [EntradaDeDiccionario]
    public let muscles: [EntradaDeDiccionario]
    public let joints: [EntradaDeDiccionario]

    public init(
        patterns: [EntradaDeDiccionario],
        equipment: [EntradaDeDiccionario],
        muscles: [EntradaDeDiccionario],
        joints: [EntradaDeDiccionario]
    ) {
        self.patterns = patterns
        self.equipment = equipment
        self.muscles = muscles
        self.joints = joints
    }
}

public struct EntradaDeDiccionario: Codable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(
        id: String,
        name: String
    ) {
        self.id = id
        self.name = name
    }
}

public enum Fase: String, Codable, CaseIterable, Sendable {
    case base = "base"
    case construccion = "construccion"
    case pico = "pico"
    case afinamiento = "afinamiento"
    case carrera = "carrera"
}

public enum TipoDeSesion: String, Codable, CaseIterable, Sendable {
    case descanso = "descanso"
    case regenerativo = "regenerativo"
    case suave = "suave"
    case fondo = "fondo"
    case tempo = "tempo"
    case umbral = "umbral"
    case series = "series"
    case cuestas = "cuestas"
    case fartlek = "fartlek"
    case ritmoCarrera = "ritmo_carrera"
    case fuerza = "fuerza"
    case carrera = "carrera"
}

public enum DeporteDeSesion: String, Codable, CaseIterable, Sendable {
    case running = "running"
    case ciclismo = "ciclismo"
    case natacion = "natacion"
    case trekking = "trekking"
    case fuerza = "fuerza"
    case otro = "otro"
    case triatlon = "triatlon"
}

/// Zona de frecuencia cardíaca, como porcentaje de la máxima.
public enum Zona: String, Codable, CaseIterable, Sendable {
    case z1 = "z1"
    case z2 = "z2"
    case z3 = "z3"
    case z4 = "z4"
    case z5 = "z5"
}

public struct Plan: Codable, Equatable, Sendable {
    public struct Streak: Codable, Equatable, Sendable {
        public let current: Int64
        public let activeToday: Bool
        public let trainedToday: Bool
        public let scheduledToday: Bool

        enum CodingKeys: String, CodingKey {
            case current
            case activeToday = "active_today"
            case trainedToday = "trained_today"
            case scheduledToday = "scheduled_today"
        }

        public init(
            current: Int64,
            activeToday: Bool,
            trainedToday: Bool,
            scheduledToday: Bool
        ) {
            self.current = current
            self.activeToday = activeToday
            self.trainedToday = trainedToday
            self.scheduledToday = scheduledToday
        }
    }

    /// La versión del motor que hizo el cálculo.
    public let motorVersion: String
    /// Hash de TODO lo que entró al cálculo, motor incluido. Si no cambia, el plan tampoco: es lo que responde "¿por qué me cambió el plan?" con un dato.
    public let inputHash: String
    public let generatedAtMs: Int64
    /// La zona con la que se armaron los días.
    public let timezone: String
    /// El idioma de los textos: es-AR o en-US.
    public let locale: String
    public let startDateMs: Int64
    /// 00:00 local del día del evento, o null si el bloque es genérico (sin fecha, o con una fecha pasada o a más de un año).
    public let eventDateMs: Int64?
    public let totalWeeks: Int64
    public let goal: Objetivo
    public let phases: [TramoDeFase]
    public let weeks: [SemanaPlanificada]
    public let streak: Streak?
    public let days: [DiaPlanificado]

    enum CodingKeys: String, CodingKey {
        case motorVersion = "motor_version"
        case inputHash = "input_hash"
        case generatedAtMs = "generated_at_ms"
        case timezone
        case locale
        case startDateMs = "start_date_ms"
        case eventDateMs = "event_date_ms"
        case totalWeeks = "total_weeks"
        case goal
        case phases
        case weeks
        case streak
        case days
    }

    public init(
        motorVersion: String,
        inputHash: String,
        generatedAtMs: Int64,
        timezone: String,
        locale: String,
        startDateMs: Int64,
        eventDateMs: Int64? = nil,
        totalWeeks: Int64,
        goal: Objetivo,
        phases: [TramoDeFase],
        weeks: [SemanaPlanificada],
        streak: Streak? = nil,
        days: [DiaPlanificado]
    ) {
        self.motorVersion = motorVersion
        self.inputHash = inputHash
        self.generatedAtMs = generatedAtMs
        self.timezone = timezone
        self.locale = locale
        self.startDateMs = startDateMs
        self.eventDateMs = eventDateMs
        self.totalWeeks = totalWeeks
        self.goal = goal
        self.phases = phases
        self.weeks = weeks
        self.streak = streak
        self.days = days
    }
}

public struct TramoDeFase: Codable, Equatable, Sendable {
    public let phase: Fase
    public let firstWeek: Int64
    public let lastWeek: Int64

    enum CodingKeys: String, CodingKey {
        case phase
        case firstWeek = "first_week"
        case lastWeek = "last_week"
    }

    public init(
        phase: Fase,
        firstWeek: Int64,
        lastWeek: Int64
    ) {
        self.phase = phase
        self.firstWeek = firstWeek
        self.lastWeek = lastWeek
    }
}

public struct SemanaPlanificada: Codable, Equatable, Sendable {
    public let number: Int64
    public let phase: Fase
    public let startDateMs: Int64
    /// Semana de descarga. No son opcionales (AGENTS.md §9.1).
    public let isDeload: Bool
    public let plannedDurationMin: Int64
    public let plannedDistanceM: Int64
    /// Días de esa semana con una actividad o series de gimnasio registradas.
    public let doneSessions: Int64
    public let doneDistanceM: Int64

    enum CodingKeys: String, CodingKey {
        case number
        case phase
        case startDateMs = "start_date_ms"
        case isDeload = "is_deload"
        case plannedDurationMin = "planned_duration_min"
        case plannedDistanceM = "planned_distance_m"
        case doneSessions = "done_sessions"
        case doneDistanceM = "done_distance_m"
    }

    public init(
        number: Int64,
        phase: Fase,
        startDateMs: Int64,
        isDeload: Bool,
        plannedDurationMin: Int64,
        plannedDistanceM: Int64,
        doneSessions: Int64,
        doneDistanceM: Int64
    ) {
        self.number = number
        self.phase = phase
        self.startDateMs = startDateMs
        self.isDeload = isDeload
        self.plannedDurationMin = plannedDurationMin
        self.plannedDistanceM = plannedDistanceM
        self.doneSessions = doneSessions
        self.doneDistanceM = doneDistanceM
    }
}

public struct DiaPlanificado: Codable, Equatable, Sendable {
    public let dateMs: Int64
    /// 0 es el primer día del bloque.
    public let dayIndex: Int64
    /// ISO-8601, 1 = lunes.
    public let weekday: Int64
    public let weekNumber: Int64
    public let phase: Fase
    public let type: TipoDeSesion
    public let sport: DeporteDeSesion
    /// La hora que eligió la persona para ese día de la semana. Ausente en descanso.
    public let scheduledMinuteOfDay: Int64?
    public let durationMin: Int64
    public let distanceM: Int64?
    public let zone: Zona?
    /// Ausente sin fecha de nacimiento.
    public let hrLowBpm: Int64?
    public let hrHighBpm: Int64?
    public let paceLowSPerKm: Int64?
    public let paceHighSPerKm: Int64?
    /// Ausente sin peso.
    public let estimatedKcal: Int64?
    public let fueling: Avituallamiento?
    public let isDeloadWeek: Bool
    public let title: String
    public let detail: String
    public let reasons: [MotivoDelPlan]
    /// Hay una actividad o series de gimnasio registradas ese día.
    public let done: Bool

    enum CodingKeys: String, CodingKey {
        case dateMs = "date_ms"
        case dayIndex = "day_index"
        case weekday
        case weekNumber = "week_number"
        case phase
        case type
        case sport
        case scheduledMinuteOfDay = "scheduled_minute_of_day"
        case durationMin = "duration_min"
        case distanceM = "distance_m"
        case zone
        case hrLowBpm = "hr_low_bpm"
        case hrHighBpm = "hr_high_bpm"
        case paceLowSPerKm = "pace_low_s_per_km"
        case paceHighSPerKm = "pace_high_s_per_km"
        case estimatedKcal = "estimated_kcal"
        case fueling
        case isDeloadWeek = "is_deload_week"
        case title
        case detail
        case reasons
        case done
    }

    public init(
        dateMs: Int64,
        dayIndex: Int64,
        weekday: Int64,
        weekNumber: Int64,
        phase: Fase,
        type: TipoDeSesion,
        sport: DeporteDeSesion,
        scheduledMinuteOfDay: Int64? = nil,
        durationMin: Int64,
        distanceM: Int64? = nil,
        zone: Zona? = nil,
        hrLowBpm: Int64? = nil,
        hrHighBpm: Int64? = nil,
        paceLowSPerKm: Int64? = nil,
        paceHighSPerKm: Int64? = nil,
        estimatedKcal: Int64? = nil,
        fueling: Avituallamiento? = nil,
        isDeloadWeek: Bool,
        title: String,
        detail: String,
        reasons: [MotivoDelPlan],
        done: Bool
    ) {
        self.dateMs = dateMs
        self.dayIndex = dayIndex
        self.weekday = weekday
        self.weekNumber = weekNumber
        self.phase = phase
        self.type = type
        self.sport = sport
        self.scheduledMinuteOfDay = scheduledMinuteOfDay
        self.durationMin = durationMin
        self.distanceM = distanceM
        self.zone = zone
        self.hrLowBpm = hrLowBpm
        self.hrHighBpm = hrHighBpm
        self.paceLowSPerKm = paceLowSPerKm
        self.paceHighSPerKm = paceHighSPerKm
        self.estimatedKcal = estimatedKcal
        self.fueling = fueling
        self.isDeloadWeek = isDeloadWeek
        self.title = title
        self.detail = detail
        self.reasons = reasons
        self.done = done
    }
}

/// El "por qué" de un día (AGENTS.md §9.1: explicable). `code` es estable; `text` viene traducido.
public struct MotivoDelPlan: Codable, Equatable, Sendable {
    public let code: String
    public let text: String

    public init(
        code: String,
        text: String
    ) {
        self.code = code
        self.text = text
    }
}

/// Líquido, sodio e hidratos de la sesión, calculados por el servidor. Ausente en descanso y sin peso. Los números son de un port SIN VERIFICAR (docs/PROPUESTA-MOTOR.md §2).
public struct Avituallamiento: Codable, Equatable, Sendable {
    public let fluidMlPerHour: Int64
    public let fluidTotalMl: Int64
    public let sodiumMgPerHour: Int64
    public let sodiumTotalMg: Int64
    public let carbsGPerHour: Int64
    public let carbsTotalG: Int64
    public let gels: Int64
    public let preFluidMl: Int64
    public let preCarbsG: Int64
    public let postFluidMl: Int64
    public let postCarbsG: Int64
    public let postProteinG: Int64

    enum CodingKeys: String, CodingKey {
        case fluidMlPerHour = "fluid_ml_per_hour"
        case fluidTotalMl = "fluid_total_ml"
        case sodiumMgPerHour = "sodium_mg_per_hour"
        case sodiumTotalMg = "sodium_total_mg"
        case carbsGPerHour = "carbs_g_per_hour"
        case carbsTotalG = "carbs_total_g"
        case gels
        case preFluidMl = "pre_fluid_ml"
        case preCarbsG = "pre_carbs_g"
        case postFluidMl = "post_fluid_ml"
        case postCarbsG = "post_carbs_g"
        case postProteinG = "post_protein_g"
    }

    public init(
        fluidMlPerHour: Int64,
        fluidTotalMl: Int64,
        sodiumMgPerHour: Int64,
        sodiumTotalMg: Int64,
        carbsGPerHour: Int64,
        carbsTotalG: Int64,
        gels: Int64,
        preFluidMl: Int64,
        preCarbsG: Int64,
        postFluidMl: Int64,
        postCarbsG: Int64,
        postProteinG: Int64
    ) {
        self.fluidMlPerHour = fluidMlPerHour
        self.fluidTotalMl = fluidTotalMl
        self.sodiumMgPerHour = sodiumMgPerHour
        self.sodiumTotalMg = sodiumTotalMg
        self.carbsGPerHour = carbsGPerHour
        self.carbsTotalG = carbsTotalG
        self.gels = gels
        self.preFluidMl = preFluidMl
        self.preCarbsG = preCarbsG
        self.postFluidMl = postFluidMl
        self.postCarbsG = postCarbsG
        self.postProteinG = postProteinG
    }
}

public struct RutinaDelDia: Codable, Equatable, Sendable {
    public let dateMs: Int64
    /// El id con el que se sincronizan las series de esta rutina, `gym-YYYY-MM-DD`.
    public let sessionId: String
    /// El plan pone fuerza ese día.
    public let planned: Bool
    /// Con qué equipamiento se eligió. `ninguno` si la persona no declaró.
    public let equipmentAssumed: [String]
    public let exercises: [EjercicioDeRutina]

    enum CodingKeys: String, CodingKey {
        case dateMs = "date_ms"
        case sessionId = "session_id"
        case planned
        case equipmentAssumed = "equipment_assumed"
        case exercises
    }

    public init(
        dateMs: Int64,
        sessionId: String,
        planned: Bool,
        equipmentAssumed: [String],
        exercises: [EjercicioDeRutina]
    ) {
        self.dateMs = dateMs
        self.sessionId = sessionId
        self.planned = planned
        self.equipmentAssumed = equipmentAssumed
        self.exercises = exercises
    }
}

public struct EjercicioDeRutina: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let name: String
    public let pattern: String
    public let equipment: String
    /// `reps` o `tiempo`.
    public let unit: String
    /// Traducido: "Para correr" o "General".
    public let label: String
    /// El "por qué" de este ejercicio, traducido.
    public let reason: String
    public let restS: Int64
    public let sets: [SeriePrescritaDeRutina]
    /// La columna PREVIA. Vacía si nunca lo hizo.
    public let previousSets: [SerieAnterior]

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case name
        case pattern
        case equipment
        case unit
        case label
        case reason
        case restS = "rest_s"
        case sets
        case previousSets = "previous_sets"
    }

    public init(
        exerciseId: String,
        name: String,
        pattern: String,
        equipment: String,
        unit: String,
        label: String,
        reason: String,
        restS: Int64,
        sets: [SeriePrescritaDeRutina],
        previousSets: [SerieAnterior]
    ) {
        self.exerciseId = exerciseId
        self.name = name
        self.pattern = pattern
        self.equipment = equipment
        self.unit = unit
        self.label = label
        self.reason = reason
        self.restS = restS
        self.sets = sets
        self.previousSets = previousSets
    }
}

public struct SeriePrescritaDeRutina: Codable, Equatable, Sendable {
    public let number: Int64
    /// Repeticiones, o segundos si `unit` es `tiempo`.
    public let reps: Int64
    /// Gramos. Hoy no viene nunca: el motor no prescribe carga.
    public let weightG: Int64?

    enum CodingKeys: String, CodingKey {
        case number
        case reps
        case weightG = "weight_g"
    }

    public init(
        number: Int64,
        reps: Int64,
        weightG: Int64? = nil
    ) {
        self.number = number
        self.reps = reps
        self.weightG = weightG
    }
}

public struct SerieAnterior: Codable, Equatable, Sendable {
    public let number: Int64
    public let reps: Int64
    public let weightG: Int64?
    public let skipped: Bool

    enum CodingKeys: String, CodingKey {
        case number
        case reps
        case weightG = "weight_g"
        case skipped
    }

    public init(
        number: Int64,
        reps: Int64,
        weightG: Int64? = nil,
        skipped: Bool
    ) {
        self.number = number
        self.reps = reps
        self.weightG = weightG
        self.skipped = skipped
    }
}

public enum DispositivoDeOrigen: String, Codable, CaseIterable, Sendable {
    case telefono = "telefono"
    case reloj = "reloj"
}

public struct SerieDeGimnasioEntrada: Codable, Equatable, Sendable {
    public let exerciseId: String
    /// 1-based. Las extra siguen numerando.
    public let number: Int64
    public let done: Bool
    public let reps: Int64
    /// Gramos. Sin el campo, peso corporal.
    public let weightG: Int64?
    public let skipped: Bool
    public let isExtra: Bool
    public let recordedAtMs: Int64
    public let device: DispositivoDeOrigen

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case number
        case done
        case reps
        case weightG = "weight_g"
        case skipped
        case isExtra = "is_extra"
        case recordedAtMs = "recorded_at_ms"
        case device
    }

    public init(
        exerciseId: String,
        number: Int64,
        done: Bool,
        reps: Int64,
        weightG: Int64? = nil,
        skipped: Bool,
        isExtra: Bool,
        recordedAtMs: Int64,
        device: DispositivoDeOrigen
    ) {
        self.exerciseId = exerciseId
        self.number = number
        self.done = done
        self.reps = reps
        self.weightG = weightG
        self.skipped = skipped
        self.isExtra = isExtra
        self.recordedAtMs = recordedAtMs
        self.device = device
    }
}

public struct SerieDeGimnasio: Codable, Equatable, Sendable {
    public let exerciseId: String
    public let number: Int64
    public let done: Bool
    public let reps: Int64
    public let weightG: Int64?
    public let skipped: Bool
    public let isExtra: Bool
    public let recordedAtMs: Int64
    public let receivedAtMs: Int64
    public let device: DispositivoDeOrigen

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case number
        case done
        case reps
        case weightG = "weight_g"
        case skipped
        case isExtra = "is_extra"
        case recordedAtMs = "recorded_at_ms"
        case receivedAtMs = "received_at_ms"
        case device
    }

    public init(
        exerciseId: String,
        number: Int64,
        done: Bool,
        reps: Int64,
        weightG: Int64? = nil,
        skipped: Bool,
        isExtra: Bool,
        recordedAtMs: Int64,
        receivedAtMs: Int64,
        device: DispositivoDeOrigen
    ) {
        self.exerciseId = exerciseId
        self.number = number
        self.done = done
        self.reps = reps
        self.weightG = weightG
        self.skipped = skipped
        self.isExtra = isExtra
        self.recordedAtMs = recordedAtMs
        self.receivedAtMs = receivedAtMs
        self.device = device
    }
}

public struct SesionDeGimnasio: Codable, Equatable, Sendable {
    public let sessionId: String
    public let dateMs: Int64?
    public let updatedAtMs: Int64
    public let sets: [SerieDeGimnasio]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case dateMs = "date_ms"
        case updatedAtMs = "updated_at_ms"
        case sets
    }

    public init(
        sessionId: String,
        dateMs: Int64? = nil,
        updatedAtMs: Int64,
        sets: [SerieDeGimnasio]
    ) {
        self.sessionId = sessionId
        self.dateMs = dateMs
        self.updatedAtMs = updatedAtMs
        self.sets = sets
    }
}

public struct ResumenDeSesionDeGimnasio: Codable, Equatable, Sendable {
    public let sessionId: String
    public let dateMs: Int64?
    public let updatedAtMs: Int64
    public let setsDone: Int64
    public let exercises: Int64

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case dateMs = "date_ms"
        case updatedAtMs = "updated_at_ms"
        case setsDone = "sets_done"
        case exercises
    }

    public init(
        sessionId: String,
        dateMs: Int64? = nil,
        updatedAtMs: Int64,
        setsDone: Int64,
        exercises: Int64
    ) {
        self.sessionId = sessionId
        self.dateMs = dateMs
        self.updatedAtMs = updatedAtMs
        self.setsDone = setsDone
        self.exercises = exercises
    }
}

public struct ActividadEntrada: Codable, Equatable, Sendable {
    public let sport: DeporteDeSesion
    public let startedAtMs: Int64
    public let durationS: Int64
    public let distanceM: Int64?
    public let elevationGainM: Int64?
    public let avgHrBpm: Int64?
    public let maxHrBpm: Int64?
    public let kcal: Int64?
    public let device: DispositivoDeOrigen

    enum CodingKeys: String, CodingKey {
        case sport
        case startedAtMs = "started_at_ms"
        case durationS = "duration_s"
        case distanceM = "distance_m"
        case elevationGainM = "elevation_gain_m"
        case avgHrBpm = "avg_hr_bpm"
        case maxHrBpm = "max_hr_bpm"
        case kcal
        case device
    }

    public init(
        sport: DeporteDeSesion,
        startedAtMs: Int64,
        durationS: Int64,
        distanceM: Int64? = nil,
        elevationGainM: Int64? = nil,
        avgHrBpm: Int64? = nil,
        maxHrBpm: Int64? = nil,
        kcal: Int64? = nil,
        device: DispositivoDeOrigen
    ) {
        self.sport = sport
        self.startedAtMs = startedAtMs
        self.durationS = durationS
        self.distanceM = distanceM
        self.elevationGainM = elevationGainM
        self.avgHrBpm = avgHrBpm
        self.maxHrBpm = maxHrBpm
        self.kcal = kcal
        self.device = device
    }
}

public struct Actividad: Codable, Equatable, Sendable {
    public let id: String
    public let sport: DeporteDeSesion
    public let startedAtMs: Int64
    public let durationS: Int64
    public let distanceM: Int64?
    public let elevationGainM: Int64?
    public let avgHrBpm: Int64?
    public let maxHrBpm: Int64?
    public let kcal: Int64?
    public let device: DispositivoDeOrigen
    public let createdAtMs: Int64
    public let updatedAtMs: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case sport
        case startedAtMs = "started_at_ms"
        case durationS = "duration_s"
        case distanceM = "distance_m"
        case elevationGainM = "elevation_gain_m"
        case avgHrBpm = "avg_hr_bpm"
        case maxHrBpm = "max_hr_bpm"
        case kcal
        case device
        case createdAtMs = "created_at_ms"
        case updatedAtMs = "updated_at_ms"
    }

    public init(
        id: String,
        sport: DeporteDeSesion,
        startedAtMs: Int64,
        durationS: Int64,
        distanceM: Int64? = nil,
        elevationGainM: Int64? = nil,
        avgHrBpm: Int64? = nil,
        maxHrBpm: Int64? = nil,
        kcal: Int64? = nil,
        device: DispositivoDeOrigen,
        createdAtMs: Int64,
        updatedAtMs: Int64
    ) {
        self.id = id
        self.sport = sport
        self.startedAtMs = startedAtMs
        self.durationS = durationS
        self.distanceM = distanceM
        self.elevationGainM = elevationGainM
        self.avgHrBpm = avgHrBpm
        self.maxHrBpm = maxHrBpm
        self.kcal = kcal
        self.device = device
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
    }
}

public enum CargaDelDia: String, Codable, CaseIterable, Sendable {
    case descanso = "descanso"
    case baja = "baja"
    case moderada = "moderada"
    case alta = "alta"
    case competencia = "competencia"
}

/// Por qué NO hay objetivos (AGENTS.md §9.2). La app muestra apoyo y, si corresponde, la pregunta que falta; nunca un número inventado.
public enum MotivoSinObjetivos: String, Codable, CaseIterable, Sendable {
    case perfilIncompleto = "perfil_incompleto"
    case menorDeEdad = "menor_de_edad"
    case sexoSinDeclarar = "sexo_sin_declarar"
    case faltaEmbarazoOLactancia = "falta_embarazo_o_lactancia"
    case embarazoOLactancia = "embarazo_o_lactancia"
}

public struct ObjetivosDelDia: Codable, Equatable, Sendable {
    public let kcal: Int64
    public let carbsG: Int64
    public let proteinG: Int64
    public let fatG: Int64
    public let waterMl: Int64
    public let sodiumMg: Int64
    public let dayLoad: CargaDelDia
    /// Los guardarraíles subieron el número.
    public let adjusted: Bool
    /// `piso_calorico` o `techo_de_deficit`.
    public let adjustmentReason: String?
    /// Los números no los revisó nadie con formación. En producción el servidor no arranca así.
    public let provisional: Bool

    enum CodingKeys: String, CodingKey {
        case kcal
        case carbsG = "carbs_g"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case waterMl = "water_ml"
        case sodiumMg = "sodium_mg"
        case dayLoad = "day_load"
        case adjusted
        case adjustmentReason = "adjustment_reason"
        case provisional
    }

    public init(
        kcal: Int64,
        carbsG: Int64,
        proteinG: Int64,
        fatG: Int64,
        waterMl: Int64,
        sodiumMg: Int64,
        dayLoad: CargaDelDia,
        adjusted: Bool,
        adjustmentReason: String? = nil,
        provisional: Bool
    ) {
        self.kcal = kcal
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.waterMl = waterMl
        self.sodiumMg = sodiumMg
        self.dayLoad = dayLoad
        self.adjusted = adjusted
        self.adjustmentReason = adjustmentReason
        self.provisional = provisional
    }
}

public struct TotalesNutricionales: Codable, Equatable, Sendable {
    public let kcal: Int64
    public let carbsG: Int64
    public let proteinG: Int64
    public let fatG: Int64

    enum CodingKeys: String, CodingKey {
        case kcal
        case carbsG = "carbs_g"
        case proteinG = "protein_g"
        case fatG = "fat_g"
    }

    public init(
        kcal: Int64,
        carbsG: Int64,
        proteinG: Int64,
        fatG: Int64
    ) {
        self.kcal = kcal
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
    }
}

public struct DiaNutricional: Codable, Equatable, Sendable {
    public let dateMs: Int64
    public let targets: ObjetivosDelDia?
    public let unavailableReason: MotivoSinObjetivos?
    public let consumed: TotalesNutricionales
    public let meals: [ComidaRegistrada]

    enum CodingKeys: String, CodingKey {
        case dateMs = "date_ms"
        case targets
        case unavailableReason = "unavailable_reason"
        case consumed
        case meals
    }

    public init(
        dateMs: Int64,
        targets: ObjetivosDelDia? = nil,
        unavailableReason: MotivoSinObjetivos? = nil,
        consumed: TotalesNutricionales,
        meals: [ComidaRegistrada]
    ) {
        self.dateMs = dateMs
        self.targets = targets
        self.unavailableReason = unavailableReason
        self.consumed = consumed
        self.meals = meals
    }
}

public struct ComidaEntrada: Codable, Equatable, Sendable {
    public let eatenAtMs: Int64
    public let name: String
    public let kcal: Int64
    public let carbsG: Int64
    public let proteinG: Int64
    public let fatG: Int64

    enum CodingKeys: String, CodingKey {
        case eatenAtMs = "eaten_at_ms"
        case name
        case kcal
        case carbsG = "carbs_g"
        case proteinG = "protein_g"
        case fatG = "fat_g"
    }

    public init(
        eatenAtMs: Int64,
        name: String,
        kcal: Int64,
        carbsG: Int64,
        proteinG: Int64,
        fatG: Int64
    ) {
        self.eatenAtMs = eatenAtMs
        self.name = name
        self.kcal = kcal
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
    }
}

public struct ComidaRegistrada: Codable, Equatable, Sendable {
    public let id: String
    public let eatenAtMs: Int64
    public let name: String
    public let kcal: Int64
    public let carbsG: Int64
    public let proteinG: Int64
    public let fatG: Int64
    public let createdAtMs: Int64
    public let updatedAtMs: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case eatenAtMs = "eaten_at_ms"
        case name
        case kcal
        case carbsG = "carbs_g"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case createdAtMs = "created_at_ms"
        case updatedAtMs = "updated_at_ms"
    }

    public init(
        id: String,
        eatenAtMs: Int64,
        name: String,
        kcal: Int64,
        carbsG: Int64,
        proteinG: Int64,
        fatG: Int64,
        createdAtMs: Int64,
        updatedAtMs: Int64
    ) {
        self.id = id
        self.eatenAtMs = eatenAtMs
        self.name = name
        self.kcal = kcal
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
    }
}

/// De dónde salió el número. Sólo informativo; no decide quién gana.
public enum FuenteDePasos: String, Codable, CaseIterable, Sendable {
    case healthkit = "healthkit"
    case manual = "manual"
    case healthConnect = "health_connect"
}

public struct DiaDePasosEntrada: Codable, Equatable, Sendable {
    /// Día de calendario "YYYY-MM-DD", sin hora ni zona: el día local de quien contó los pasos. El servidor rechaza los días que no existen.
    public let date: String
    public let steps: Int64
    public let source: FuenteDePasos
    /// Cuándo el cliente leyó o editó el valor. Ausente vale "ahora".
    public let updatedAtMs: Int64?

    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case source
        case updatedAtMs = "updated_at_ms"
    }

    public init(
        date: String,
        steps: Int64,
        source: FuenteDePasos,
        updatedAtMs: Int64? = nil
    ) {
        self.date = date
        self.steps = steps
        self.source = source
        self.updatedAtMs = updatedAtMs
    }
}

public struct DiaDePasos: Codable, Equatable, Sendable {
    /// Día de calendario "YYYY-MM-DD", sin hora ni zona: el día local de quien contó los pasos. El servidor rechaza los días que no existen.
    public let date: String
    public let steps: Int64
    public let source: FuenteDePasos
    public let updatedAtMs: Int64

    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case source
        case updatedAtMs = "updated_at_ms"
    }

    public init(
        date: String,
        steps: Int64,
        source: FuenteDePasos,
        updatedAtMs: Int64
    ) {
        self.date = date
        self.steps = steps
        self.source = source
        self.updatedAtMs = updatedAtMs
    }
}

public struct AceptacionRegistrada: Codable, Equatable, Sendable {
    public let version: String
    public let acceptedAtMs: Int64
    public let reason: String

    enum CodingKeys: String, CodingKey {
        case version
        case acceptedAtMs = "accepted_at_ms"
        case reason
    }

    public init(
        version: String,
        acceptedAtMs: Int64,
        reason: String
    ) {
        self.version = version
        self.acceptedAtMs = acceptedAtMs
        self.reason = reason
    }
}

public struct AnclaDePlan: Codable, Equatable, Sendable {
    /// ID del objetivo adicional; omitido para el principal.
    public let goalId: String?
    public let motorVersion: String
    public let startDateMs: Int64
    public let timezone: String
    public let createdAtMs: Int64
    public let replacedAtMs: Int64?

    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case motorVersion = "motor_version"
        case startDateMs = "start_date_ms"
        case timezone
        case createdAtMs = "created_at_ms"
        case replacedAtMs = "replaced_at_ms"
    }

    public init(
        goalId: String? = nil,
        motorVersion: String,
        startDateMs: Int64,
        timezone: String,
        createdAtMs: Int64,
        replacedAtMs: Int64? = nil
    ) {
        self.goalId = goalId
        self.motorVersion = motorVersion
        self.startDateMs = startDateMs
        self.timezone = timezone
        self.createdAtMs = createdAtMs
        self.replacedAtMs = replacedAtMs
    }
}

public struct ExportacionDeDatos: Codable, Equatable, Sendable {
    public let exportedAtMs: Int64
    public let profile: Perfil
    public let goals: [ObjetivoExportado]
    public let legalAcceptances: [AceptacionRegistrada]
    public let plans: [AnclaDePlan]
    public let gymSessions: [SesionDeGimnasio]
    public let activities: [Actividad]
    public let meals: [ComidaRegistrada]
    /// Desde la 1.3.0. Opcional para que un cliente nuevo lea la exportación de un servidor anterior.
    public let steps: [DiaDePasos]?

    enum CodingKeys: String, CodingKey {
        case exportedAtMs = "exported_at_ms"
        case profile
        case goals
        case legalAcceptances = "legal_acceptances"
        case plans
        case gymSessions = "gym_sessions"
        case activities
        case meals
        case steps
    }

    public init(
        exportedAtMs: Int64,
        profile: Perfil,
        goals: [ObjetivoExportado],
        legalAcceptances: [AceptacionRegistrada],
        plans: [AnclaDePlan],
        gymSessions: [SesionDeGimnasio],
        activities: [Actividad],
        meals: [ComidaRegistrada],
        steps: [DiaDePasos]? = nil
    ) {
        self.exportedAtMs = exportedAtMs
        self.profile = profile
        self.goals = goals
        self.legalAcceptances = legalAcceptances
        self.plans = plans
        self.gymSessions = gymSessions
        self.activities = activities
        self.meals = meals
        self.steps = steps
    }
}

public struct ObjetivoExportado: Codable, Equatable, Sendable {
    public let id: String
    public let goal: Objetivo
    public let goalDateMs: Int64?
    public let order: Int64
    public let createdAtMs: Int64
    public let completedAtMs: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case goal
        case goalDateMs = "goal_date_ms"
        case order
        case createdAtMs = "created_at_ms"
        case completedAtMs = "completed_at_ms"
    }

    public init(
        id: String,
        goal: Objetivo,
        goalDateMs: Int64? = nil,
        order: Int64,
        createdAtMs: Int64,
        completedAtMs: Int64? = nil
    ) {
        self.id = id
        self.goal = goal
        self.goalDateMs = goalDateMs
        self.order = order
        self.createdAtMs = createdAtMs
        self.completedAtMs = completedAtMs
    }
}

public struct ErrorAPI: Codable, Equatable, Sendable {
    public let error: DetalleDeError

    public init(
        error: DetalleDeError
    ) {
        self.error = error
    }
}

/// El cuerpo del sobre de error. Estaba escrito adentro de Error, sin nombre; se extrajo el 2026-09-08 por el mismo motivo que EstadoDeDependencias. La forma en el cable NO cambia.
public struct DetalleDeError: Codable, Equatable, Sendable {
    /// **Estable y parte del contrato.** El cliente lo mapea a su texto traducido. La lista completa está en docs/API.md.
    public let code: String
    /// Para el log del desarrollador y como respaldo. **El cliente no lo muestra tal cual**: muestra su propia traducción del `code`. Nunca lleva datos de salud ni de identidad (AGENTS.md §8).
    public let message: String

    public init(
        code: String,
        message: String
    ) {
        self.code = code
        self.message = message
    }
}
