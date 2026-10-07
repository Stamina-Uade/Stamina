import Foundation
import TrainerCore

// =============================================================================
// El modelo de lo que la app muestra después del login.
//
// 🛑 ACÁ NO SE CALCULA NADA DEL PLAN, Y ES LA REGLA MÁS IMPORTANTE DE ESTE
//    ARCHIVO.
//
// `design/origen/HomeB.dc.html` deriva en JavaScript los mililitros por hora,
// los geles, los gramos de carbohidrato, los minutos de la sesión y el reparto
// de la semana. Eso es lógica de negocio, y AGENTS.md §10 dice exactamente qué
// pasa si vive en el cliente:
//
//   "La lógica de negocio vive en el servidor. Si el cliente calcula el objetivo
//    calórico, hay dos implementaciones que van a divergir, y la vieja va a
//    seguir instalada por años."
//
// Así que el cliente **presenta valores que le dan**: los del motor de la 1.1.0,
// que `TraduccionDelServidor` pasa a estos tipos sin calcular nada. Las vistas
// previas y `-datosDeEjemplo` usan los de `RepositorioProvisional`, que son la
// maqueta del diseño. Las pantallas no cambian: cambia quién implementa
// `RepositorioDePlan`.
//
// Lo que sí vive acá: las unidades. La API habla en unidad base (§5) —metros,
// gramos, kcal enteras, milisegundos— y la conversión a lo que se muestra es del
// cliente.
// =============================================================================

// MARK: - Sesión de entrenamiento

/// Zona de intensidad. El diseño la escribe "Z2"; el nombre largo es para
/// VoiceOver, donde "zeta dos" no se entiende.
public enum ZonaDeIntensidad: String, CaseIterable, Codable, Sendable {
    case z1, z2, z3, z4, z5

    public var corta: String { rawValue.uppercased() }
    public var numero: Int { Int(rawValue.dropFirst()) ?? 2 }
}

/// Un bloque de la sesión: calentamiento, principal, vuelta a la calma.
public struct BloqueDeSesion: Identifiable, Sendable {
    public let id = UUID()
    public let titulo: String
    public let detalle: String
    /// La etiqueta de la derecha ("10 km", "3 de 6"). Vacía si no lleva.
    public let insignia: String?

    public init(titulo: String, detalle: String, insignia: String? = nil) {
        self.titulo = titulo
        self.detalle = detalle
        self.insignia = insignia
    }
}

/// Lo que se muestra de la sesión del día, ya calculado por el servidor.
public struct SesionDelDia: Sendable {
    /// El título, tal como lo manda el servidor y en su idioma: "Running suave (51 min)".
    public let tipo: String
    /// `nil` en lo que no va por distancia.
    public let distanciaMetros: Int?
    /// `nil` si el plan no pone zona para ese día.
    public let zona: ZonaDeIntensidad?
    /// Minutos desde medianoche, local. `nil` si el día no tiene horario elegido.
    public let minutoDelDia: Int?
    public let duracionMinutos: Int
    public let bloques: [BloqueDeSesion]
    /// 🛑 `nil` cuando el servidor no lo calcula —sin el peso de la persona no sale—.
    /// No se completa con un número de ejemplo.
    public let avituallamiento: AvituallamientoDeSesion?
    /// El aviso del clima. Vacío mientras el servidor no lo mande.
    public let notaDelClima: String
    /// Por qué el plan pone esto hoy, ya traducido (AGENTS.md §9.1: explicable).
    public let motivos: [String]
    public let runWalkRun: Bool

    public init(tipo: String, distanciaMetros: Int?, zona: ZonaDeIntensidad?, minutoDelDia: Int?,
                duracionMinutos: Int, bloques: [BloqueDeSesion], avituallamiento: AvituallamientoDeSesion?,
                notaDelClima: String = "", motivos: [String] = [], runWalkRun: Bool = false) {
        self.tipo = tipo
        self.distanciaMetros = distanciaMetros
        self.zona = zona
        self.minutoDelDia = minutoDelDia
        self.duracionMinutos = duracionMinutos
        self.bloques = bloques
        self.avituallamiento = avituallamiento
        self.notaDelClima = notaDelClima
        self.motivos = motivos
        self.runWalkRun = runWalkRun
    }
}

/// El avituallamiento de una sesión, tal como lo calcula el servidor: durante,
/// antes y después. El cliente no deriva ninguno de estos números.
public struct AvituallamientoDeSesion: Sendable {
    public let geles: Int
    public let mililitrosTotales: Int
    public let mililitrosPorHora: Int
    public let sodioMg: Int
    public let carbohidratosPorHoraG: Int
    public let carbohidratosAntesG: Int
    public let carbohidratosDespuesG: Int
    public let proteinaDespuesG: Int

    public init(geles: Int, mililitrosTotales: Int, mililitrosPorHora: Int, sodioMg: Int,
                carbohidratosPorHoraG: Int, carbohidratosAntesG: Int, carbohidratosDespuesG: Int,
                proteinaDespuesG: Int) {
        self.geles = geles
        self.mililitrosTotales = mililitrosTotales
        self.mililitrosPorHora = mililitrosPorHora
        self.sodioMg = sodioMg
        self.carbohidratosPorHoraG = carbohidratosPorHoraG
        self.carbohidratosAntesG = carbohidratosAntesG
        self.carbohidratosDespuesG = carbohidratosDespuesG
        self.proteinaDespuesG = proteinaDespuesG
    }
}

/// La sesión en curso, mientras se corre.
public struct SesionEnCurso: Sendable {
    public let segundos: Int
    /// Segundos por kilómetro. `nil` mientras no hay dato.
    public let ritmoSegPorKm: Int?
    public let metros: Int
    public let bloqueActivo: Int
    public let proximoAviso: String
    public let proximoAvisoEn: String
    public let proximoAvisoPorcentaje: Double
    public let estadoDelAvituallamiento: String

    public init(segundos: Int, ritmoSegPorKm: Int?, metros: Int, bloqueActivo: Int,
                proximoAviso: String, proximoAvisoEn: String, proximoAvisoPorcentaje: Double,
                estadoDelAvituallamiento: String) {
        self.segundos = segundos
        self.ritmoSegPorKm = ritmoSegPorKm
        self.metros = metros
        self.bloqueActivo = bloqueActivo
        self.proximoAviso = proximoAviso
        self.proximoAvisoEn = proximoAvisoEn
        self.proximoAvisoPorcentaje = proximoAvisoPorcentaje
        self.estadoDelAvituallamiento = estadoDelAvituallamiento
    }

    public static let detenida = SesionEnCurso(
        segundos: 0, ritmoSegPorKm: nil, metros: 0, bloqueActivo: -1,
        proximoAviso: "", proximoAvisoEn: "", proximoAvisoPorcentaje: 0,
        estadoDelAvituallamiento: "")
}

// MARK: - El bloque de semanas

public struct DiaDelPlan: Identifiable, Sendable {
    public let id = UUID()
    public let diaDeLaSemana: Int      // ISO: 1 = lunes
    public let numeroDeDia: Int
    public let mesCorto: String
    public let titulo: String
    public let detalle: String
    public let hecho: Bool
    public let esHoy: Bool
    /// `true` si tocarlo abre la sesión. Un descanso no se abre.
    public let abrible: Bool
    public let fecha: Date?

    public init(diaDeLaSemana: Int, numeroDeDia: Int, mesCorto: String, titulo: String,
                detalle: String, hecho: Bool, esHoy: Bool, abrible: Bool, fecha: Date? = nil) {
        self.diaDeLaSemana = diaDeLaSemana
        self.numeroDeDia = numeroDeDia
        self.mesCorto = mesCorto
        self.titulo = titulo
        self.detalle = detalle
        self.hecho = hecho
        self.esHoy = esHoy
        self.abrible = abrible
        self.fecha = fecha
    }
}

public struct SemanaDelPlan: Identifiable, Sendable {
    public var id: Int { numero }
    public let numero: Int
    public let metrosHechos: Int
    public let metrosPrevistos: Int
    public let dias: [DiaDelPlan]
    public let enCurso: Bool

    public init(numero: Int, metrosHechos: Int, metrosPrevistos: Int, dias: [DiaDelPlan], enCurso: Bool) {
        self.numero = numero
        self.metrosHechos = metrosHechos
        self.metrosPrevistos = metrosPrevistos
        self.dias = dias
        self.enCurso = enCurso
    }
}

/// Una fase del bloque: base, carga, afinamiento. El diseño la dibuja como una
/// barra proporcional, así que lleva su peso.
public struct FaseDelPlan: Identifiable, Sendable {
    public let id = UUID()
    public let titulo: String
    public let peso: Int
    /// `hecha` → llena; `enCurso` → media; si no, vacía.
    public let hecha: Bool
    public let enCurso: Bool

    public init(titulo: String, peso: Int, hecha: Bool, enCurso: Bool) {
        self.titulo = titulo
        self.peso = peso
        self.hecha = hecha
        self.enCurso = enCurso
    }
}

public struct BloqueDelPlan: Sendable {
    public let subtitulo: String
    public let evento: String
    public let cuando: String
    public let semanasQueFaltan: Int
    /// Las semanas del bloque entero. `semanas` sólo trae las que se pueden
    /// mirar hoy, que son menos.
    public let totalDeSemanas: Int
    public let fases: [FaseDelPlan]
    public let semanas: [SemanaDelPlan]

    public init(subtitulo: String, evento: String, cuando: String, semanasQueFaltan: Int,
                totalDeSemanas: Int, fases: [FaseDelPlan], semanas: [SemanaDelPlan]) {
        self.subtitulo = subtitulo
        self.evento = evento
        self.cuando = cuando
        self.semanasQueFaltan = semanasQueFaltan
        self.totalDeSemanas = totalDeSemanas
        self.fases = fases
        self.semanas = semanas
    }
}

// MARK: - Nutrición

public struct Comida: Identifiable, Sendable {
    /// El id del servidor, que lo genera el CLIENTE antes del primer intento:
    /// `PUT /meals/{id}` es idempotente por id, y con eso borrar la comida de otro
    /// teléfono o reintentar un guardado apuntan a la misma fila.
    public let id: String
    public let minutoDelDia: Int
    public let nombre: String
    public let kcal: Int
    public let carbohidratosG: Int
    public let proteinaG: Int
    public let grasaG: Int

    public init(id: String = UUID().uuidString.lowercased(), minutoDelDia: Int, nombre: String, kcal: Int,
                carbohidratosG: Int, proteinaG: Int, grasaG: Int) {
        self.id = id
        self.minutoDelDia = minutoDelDia
        self.nombre = nombre
        self.kcal = kcal
        self.carbohidratosG = carbohidratosG
        self.proteinaG = proteinaG
        self.grasaG = grasaG
    }
}

/// Los objetivos del día. 🛑 Los calcula el SERVIDOR y hace cumplir los
/// guardarraíles de AGENTS.md §9.2 (piso calórico, techo de déficit). El cliente
/// no los recalcula ni los ajusta: los muestra.
public struct ObjetivoNutricional: Sendable {
    public let kcal: Int
    public let carbohidratosG: Int
    public let proteinaG: Int
    public let grasaG: Int
    /// El agua del día. `nil` en lo consumido, que no la cuenta.
    public let aguaMl: Int?

    public init(kcal: Int, carbohidratosG: Int, proteinaG: Int, grasaG: Int, aguaMl: Int? = nil) {
        self.kcal = kcal
        self.carbohidratosG = carbohidratosG
        self.proteinaG = proteinaG
        self.grasaG = grasaG
        self.aguaMl = aguaMl
    }
}

/// Un plato del catálogo de frecuentes o reconocido por la cámara.
public struct PlatoSugerido: Identifiable, Sendable {
    public let id = UUID()
    public let nombre: String
    public let kcal: Int
    public let carbohidratosG: Int
    public let proteinaG: Int
    public let grasaG: Int
    /// Sólo para lo reconocido por foto. Es el número: el "%" y su formato los
    /// pone el cliente con el locale, no el servidor.
    public let certezaPorcentaje: Int?
    /// Los ingredientes con su cantidad, para poder escalar la porción.
    public let ingredientes: [IngredienteSugerido]

    public init(nombre: String, kcal: Int, carbohidratosG: Int, proteinaG: Int, grasaG: Int,
                certezaPorcentaje: Int? = nil, ingredientes: [IngredienteSugerido] = []) {
        self.nombre = nombre
        self.kcal = kcal
        self.carbohidratosG = carbohidratosG
        self.proteinaG = proteinaG
        self.grasaG = grasaG
        self.certezaPorcentaje = certezaPorcentaje
        self.ingredientes = ingredientes
    }
}

public struct IngredienteSugerido: Identifiable, Sendable {
    public let id = UUID()
    public let nombre: String
    public let cantidad: Double
    public let unidad: String
    /// `true` si la unidad se cuenta (rebanadas, unidades) y admite medios.
    public let contable: Bool

    public init(nombre: String, cantidad: Double, unidad: String, contable: Bool) {
        self.nombre = nombre
        self.cantidad = cantidad
        self.unidad = unidad
        self.contable = contable
    }
}

// MARK: - Gimnasio

public struct EjercicioDeGimnasio: Identifiable, Sendable {
    /// 🛑 El id del CATÁLOGO (`shared/datos/ejercicios.json`), no un `UUID()`.
    ///
    /// La clave de una serie sincronizada es `(sesión, ejercicio, número)` y
    /// tiene que ser **determinística** en los dos dispositivos (decisión 0006).
    /// Con un UUID generado al vuelo, el teléfono y el reloj usarían claves
    /// distintas para el mismo ejercicio y la unión daría filas duplicadas.
    public let id: String
    public let nombre: String
    public let prescripcion: PrescripcionDeEjercicio
    public let etiqueta: String
    /// El "por qué" que el diseño muestra en cada tarjeta.
    public let porQue: String
    /// Lo que se hizo la vez anterior, serie por serie: la columna PREVIA. Vacía si
    /// nunca se hizo.
    public let seriesPrevias: [SeriePrevia]

    public init(id: String, nombre: String, prescripcion: PrescripcionDeEjercicio,
                etiqueta: String, porQue: String, seriesPrevias: [SeriePrevia] = []) {
        self.id = id
        self.nombre = nombre
        self.prescripcion = prescripcion
        self.etiqueta = etiqueta
        self.porQue = porQue
        self.seriesPrevias = seriesPrevias
    }
}

/// Una serie de la vez anterior.
public struct SeriePrevia: Equatable, Sendable {
    public let numero: Int
    public let repeticiones: Int
    /// Gramos. `nil` = peso corporal.
    public let pesoGramos: Int?
    public let salteada: Bool

    public init(numero: Int, repeticiones: Int, pesoGramos: Int?, salteada: Bool) {
        self.numero = numero
        self.repeticiones = repeticiones
        self.pesoGramos = pesoGramos
        self.salteada = salteada
    }
}

/// 🛑 La prescripción es una LISTA DE SERIES, no una cadena.
///
/// `design/ESPECIFICACION.md` §6.2 resolvió esta discrepancia el 2026-09-08:
/// HomeB la guardaba como texto (`"4 series × 8 · 45 kg · 90 s"`) y el reloj
/// estructurada. **Gana la estructura**, y el texto se compone para mostrar.
/// Con una cadena era imposible expresar una rampa de aproximación o comparar
/// lo hecho con lo prescrito serie por serie.
public struct PrescripcionDeEjercicio: Sendable {
    public let series: [SeriePrescrita]
    public let descansoSegundos: Int
    /// `nil` en los ejercicios de peso corporal y en los que van por tiempo.
    public let unidadDePeso: UnidadDePeso?

    public init(series: [SeriePrescrita], descansoSegundos: Int, unidadDePeso: UnidadDePeso?) {
        self.series = series
        self.descansoSegundos = descansoSegundos
        self.unidadDePeso = unidadDePeso
    }
}

public struct SeriePrescrita: Identifiable, Sendable {
    public let id = UUID()
    /// Repeticiones, o segundos si el ejercicio va por tiempo.
    public let repeticiones: Int
    /// Gramos, unidad base del contrato (§5). `nil` = peso corporal.
    public let pesoGramos: Int?
    public let porTiempo: Bool

    public init(repeticiones: Int, pesoGramos: Int?, porTiempo: Bool = false) {
        self.repeticiones = repeticiones
        self.pesoGramos = pesoGramos
        self.porTiempo = porTiempo
    }
}

public enum UnidadDePeso: String, Sendable {
    case kilogramos, libras
}

// MARK: - La agenda del día

public struct FilaDeAgenda: Identifiable, Sendable {
    public enum Clase: Sendable {
        case simple
        /// La fila de la sesión, que es la única con chips y botón de editar.
        case sesion
        /// La del gimnasio, que lleva a la rutina.
        case gimnasio
    }

    public let id = UUID()
    public let minutoDelDia: Int
    public let titulo: String
    public let detalle: String
    public let clase: Clase
    public let destino: PestanaHome?

    public init(minutoDelDia: Int, titulo: String, detalle: String, clase: Clase, destino: PestanaHome?) {
        self.minutoDelDia = minutoDelDia
        self.titulo = titulo
        self.detalle = detalle
        self.clase = clase
        self.destino = destino
    }
}

// MARK: - Las pestañas

/// Las siete pestañas de `HomeB.dc.html`. Sólo cinco están en la barra: gimnasio
/// se abre desde la agenda y ajustes desde el perfil.
public enum PestanaHome: String, CaseIterable, Sendable {
    case inicio, plan, entreno, nutricion, perfil, ajustes, gimnasio

    public static let enLaBarra: [PestanaHome] = [.inicio, .plan, .nutricion, .perfil]
}

// MARK: - Lo que el Home muestra, con su estado

/// Hoy, tal como lo planificó el servidor.
public struct DiaDeHoy: Sendable {
    /// "Running suave (51 min)", "Descanso"… ya traducido por el servidor.
    public let titulo: String
    public let detalle: String
    /// La salida de hoy. `nil` en un descanso y en un día de fuerza, que se hace en
    /// `gimnasio` y no en `entreno`.
    public let sesion: SesionDelDia?
    public let esFuerza: Bool

    public init(titulo: String, detalle: String, sesion: SesionDelDia?, esFuerza: Bool) {
        self.titulo = titulo
        self.detalle = detalle
        self.sesion = sesion
        self.esFuerza = esFuerza
    }
}

public struct RachaHome: Sendable {
    public let dias: Int
    public let activaHoy: Bool
    public let entrenadoHoy: Bool
    public let tocaHoy: Bool

    public init(dias: Int = 0, activaHoy: Bool = false, entrenadoHoy: Bool = false, tocaHoy: Bool = false) {
        self.dias = dias
        self.activaHoy = activaHoy
        self.entrenadoHoy = entrenadoHoy
        self.tocaHoy = tocaHoy
    }
}

public struct PlanDelHome: Sendable {
    public let bloque: BloqueDelPlan
    /// `nil` si hoy no cae adentro del bloque: todavía no empezó, o ya terminó.
    public let hoy: DiaDeHoy?
    /// La semana que contiene a hoy.
    public let semanaDeHoy: Int?
    /// Los metros de cada día de la semana de hoy, en el orden del bloque.
    public let cargaSemanal: [Int]
    /// Cuál de `cargaSemanal` es hoy.
    public let indiceDeHoy: Int?
    /// Racha de entrenamientos (fueguitos estilo Duolingo).
    public let racha: RachaHome
    /// El cronograma completo de días planificados para sincronizar con el reloj y recordatorios.
    public let cronograma: [DiaPlanificadoCompartido]

    public init(bloque: BloqueDelPlan, hoy: DiaDeHoy?, semanaDeHoy: Int?, cargaSemanal: [Int],
                indiceDeHoy: Int?, racha: RachaHome = RachaHome(), cronograma: [DiaPlanificadoCompartido] = []) {
        self.bloque = bloque
        self.hoy = hoy
        self.semanaDeHoy = semanaDeHoy
        self.cargaSemanal = cargaSemanal
        self.indiceDeHoy = indiceDeHoy
        self.racha = racha
        self.cronograma = cronograma
    }
}

public struct RutinaDelHome: Sendable {
    public let ejercicios: [EjercicioDeGimnasio]
    /// Si el plan pone gimnasio HOY. Si no, es la rutina para cuando toque, y la
    /// agenda del día no la anota.
    public let planificada: Bool

    public init(ejercicios: [EjercicioDeGimnasio], planificada: Bool) {
        self.ejercicios = ejercicios
        self.planificada = planificada
    }
}

public struct NutricionDelHome: Sendable {
    /// 🛑 `nil` cuando el servidor no da objetivos (AGENTS.md §9.2). Entonces
    /// `motivoSinObjetivo` dice por qué, y la pantalla muestra apoyo, no un número.
    public let objetivo: ObjetivoNutricional?
    public let motivoSinObjetivo: MotivoSinObjetivos?
    /// Los números no los revisó todavía nadie con formación.
    public let provisional: Bool
    public let comidas: [Comida]
    /// El agua que se tomó. `nil` en la app de verdad: la API no la registra.
    public let aguaTomadaMl: Int?
    /// El día (`date_ms`) y la zona con que se cuenta: una comida que espera para
    /// subir se muestra sólo en el día en que se comió.
    public let diaMs: Int64?
    public let zona: TimeZone

    public init(objetivo: ObjetivoNutricional?, motivoSinObjetivo: MotivoSinObjetivos?, provisional: Bool,
                comidas: [Comida], aguaTomadaMl: Int? = nil, diaMs: Int64? = nil, zona: TimeZone = .current) {
        self.objetivo = objetivo
        self.motivoSinObjetivo = motivoSinObjetivo
        self.provisional = provisional
        self.comidas = comidas
        self.aguaTomadaMl = aguaTomadaMl
        self.diaMs = diaMs
        self.zona = zona
    }
}

/// Todo lo que el Home muestra del motor, cada parte con su estado: lo último que
/// llegó, cuándo, y si la última vez no se pudo actualizar.
public struct ContenidoDelHome: Sendable {
    public var plan: Seccion<PlanDelHome>
    public var rutina: Seccion<RutinaDelHome>
    public var nutricion: Seccion<NutricionDelHome>

    public init(plan: Seccion<PlanDelHome>, rutina: Seccion<RutinaDelHome>, nutricion: Seccion<NutricionDelHome>) {
        self.plan = plan
        self.rutina = rutina
        self.nutricion = nutricion
    }
}
