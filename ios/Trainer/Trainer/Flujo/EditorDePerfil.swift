import Foundation
import TrainerCore

// =============================================================================
// Ajustes → Datos personales y Entrenamiento: lo que se edita del perfil y el
// ÚNICO `PATCH /me` que lo guarda.
//
// Se edita en la unidad de la persona (kg y cm, o lb y pies con pulgadas) y
// viaja en la del contrato: gramos y milímetros enteros, fechas a medianoche
// UTC (AGENTS.md §5). Los topes son los del alta (`DatosRegistro`).
//
// 🛑 QUÉ cambió se decide comparando lo EDITABLE con lo que se cargó, no lo
// convertido: 72 kg mostrados como "158,7 lb" y vueltos a gramos dan 71.985 g,
// y ese "cambio" no lo hizo nadie. Por eso un campo que no se tocó no viaja.
// =============================================================================

/// Lo que se puede editar del perfil desde Ajustes.
struct EdicionDePerfil: Equatable {
    var nombre: String
    var apellido: String
    /// La fecha del CALENDARIO, en el huso de la persona. `nil`: no está cargada.
    var nacimiento: Date?
    var sexo: SexoBiologico?
    /// Tal como se escribe, en kg o en lb según `unidades`.
    var pesoTexto: String
    /// En cm. Sólo con el sistema métrico.
    var alturaTexto: String
    /// En pulgadas totales. Sólo con el imperial: se edita con dos ruedas.
    var alturaEnPulgadas: Int?
    var nivel: Nivel?
    /// Día ISO (1 = lunes) → minuto del día, igual que `DatosRegistro.dias`.
    var dias: [Int: Int]
    let unidades: SistemaDeUnidades

    init(perfil: Perfil, unidades: SistemaDeUnidades) {
        self.unidades = unidades
        nombre = perfil.firstName ?? ""
        apellido = perfil.lastName ?? ""
        nacimiento = perfil.birthdateMs.map(EdicionDePerfil.fechaDelCalendario(desdeMs:))
        sexo = perfil.biologicalSex
        pesoTexto = perfil.weightG.map { EdicionDePerfil.textoDePeso($0, unidades: unidades) } ?? ""
        alturaTexto = perfil.heightMm.map { EdicionDePerfil.decimal(Double($0) / 10) } ?? ""
        alturaEnPulgadas = perfil.heightMm.map { Int((Double($0) / EdicionDePerfil.mmPorPulgada).rounded()) }
        nivel = perfil.level
        var dias: [Int: Int] = [:]
        for dia in perfil.trainingDays ?? [] { dias[Int(dia.weekday)] = Int(dia.minuteOfDay) }
        self.dias = dias
    }
}

/// Lo que viaja en el `PATCH /me`: sólo lo que cambió.
struct CambiosDePerfil: Equatable {
    let entrada: PerfilEntrada
    /// Los campos que se VACÍAN (`null` explícito). Hoy, el apellido.
    let anulando: Set<CampoAnulable>
    /// Nivel y días cambian el plan: el Home lo vuelve a pedir.
    let tocaElPlan: Bool
}

// MARK: - Conversiones

extension EdicionDePerfil {
    static let gramosPorLibra = 453.59237
    static let mmPorPulgada = 25.4
    /// Las ruedas de la altura imperial: 2′0″ a 8′11″ (el contrato corta en 8′6″).
    static let piesPosibles = Array(2...8)
    static let pulgadasPosibles = Array(0...11)
    /// Dónde se paran las ruedas mientras no hay altura: 5′7″. Sólo posición.
    static let pulgadasIniciales = 67

    /// "72" o "72,5": hasta un decimal, con el separador del locale y sin miles.
    static func decimal(_ valor: Double) -> String {
        valor.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    static func textoDePeso(_ gramos: Int64, unidades: SistemaDeUnidades) -> String {
        unidades == .metrico
            ? decimal(Double(gramos) / 1000)
            : decimal(Double(gramos) / gramosPorLibra)
    }

    /// El día que guarda el contrato (medianoche UTC) como fecha del calendario
    /// local: el 24 de junio sigue siendo el 24 en cualquier huso.
    static func fechaDelCalendario(desdeMs ms: Int64) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let instante = Date(timeIntervalSince1970: Double(ms) / 1000)
        let dia = utc.dateComponents([.year, .month, .day], from: instante)
        // Gregoriano también del lado local: con el budista, `year` es otro número.
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .autoupdatingCurrent
        return local.date(from: DateComponents(year: dia.year, month: dia.month, day: dia.day)) ?? instante
    }

    var pesoEnGramos: Int64? {
        guard let valor = DatosRegistro.numero(pesoTexto) else { return nil }
        let gramos = Int64((unidades == .metrico ? valor * 1000 : valor * Self.gramosPorLibra).rounded())
        return DatosRegistro.pesoValido.contains(gramos) ? gramos : nil
    }

    var alturaEnMilimetros: Int64? {
        let milimetros: Int64
        if unidades == .metrico {
            guard let cm = DatosRegistro.numero(alturaTexto) else { return nil }
            milimetros = Int64((cm * 10).rounded())
        } else {
            guard let pulgadas = alturaEnPulgadas else { return nil }
            milimetros = Int64((Double(pulgadas) * Self.mmPorPulgada).rounded())
        }
        return DatosRegistro.alturaValida.contains(milimetros) ? milimetros : nil
    }

    func nacimientoEnMs(zona: TimeZone) -> Int64? {
        nacimiento.map { DatosRegistro.fechaDelCalendarioEnMs($0, zona: zona) }
    }

    /// Los días de lunes a domingo, como los pide el contrato.
    var diasDeEntrenamiento: [DiaEntrenamiento] {
        dias
            .filter { (1...7).contains($0.key) && (0...1439).contains($0.value) }
            .sorted { $0.key < $1.key }
            .map { DiaEntrenamiento(weekday: Int64($0.key), minuteOfDay: Int64($0.value)) }
    }

    static func recortado(_ texto: String) -> String {
        String(texto.trimmingCharacters(in: .whitespacesAndNewlines).prefix(DatosRegistro.largoMaximoDelNombre))
    }

    private func alturaCambio(desde original: EdicionDePerfil) -> Bool {
        unidades == .metrico
            ? alturaTexto != original.alturaTexto
            : alturaEnPulgadas != original.alturaEnPulgadas
    }
}

// MARK: - Validación (comodidad: la regla la hace cumplir el servidor)

extension EdicionDePerfil {
    /// El nombre es obligatorio (`first_name.minLength` 1); el apellido no.
    func faltaElNombre(desde original: EdicionDePerfil) -> Bool {
        nombre != original.nombre && Self.recortado(nombre).isEmpty
    }

    /// Un peso tocado tiene que leerse y estar en el rango del contrato. No hay
    /// `null` para el peso: borrarlo no es una opción.
    func pesoInvalido(desde original: EdicionDePerfil) -> Bool {
        pesoTexto != original.pesoTexto && pesoEnGramos == nil
    }

    func alturaInvalida(desde original: EdicionDePerfil) -> Bool {
        alturaCambio(desde: original) && alturaEnMilimetros == nil
    }

    /// Sin días no hay plan ni avisos: el alta pide al menos uno, y acá también.
    func faltanDias(desde original: EdicionDePerfil) -> Bool {
        dias != original.dias && dias.isEmpty
    }

    func esValida(desde original: EdicionDePerfil) -> Bool {
        !faltaElNombre(desde: original) && !pesoInvalido(desde: original)
            && !alturaInvalida(desde: original) && !faltanDias(desde: original)
    }
}

// MARK: - Lo que viaja

extension EdicionDePerfil {
    /// Lo que cambió respecto de `original`, o `nil` si no hay nada que mandar.
    /// Un campo inválido no viaja (y `esValida` no deja guardar).
    func cambios(desde original: EdicionDePerfil, zona: TimeZone) -> CambiosDePerfil? {
        var anulando: Set<CampoAnulable> = []

        let nombreLimpio = Self.recortado(nombre)
        let nombreNuevo: String? = nombreLimpio != Self.recortado(original.nombre) && !nombreLimpio.isEmpty
            ? nombreLimpio : nil

        // El apellido vacío viaja como `null` explícito: `""` lo rechaza el
        // `minLength` y omitirlo dejaría el viejo (docs/API.md §7).
        var apellidoNuevo: String?
        let apellidoLimpio = Self.recortado(apellido)
        if apellidoLimpio != Self.recortado(original.apellido) {
            if apellidoLimpio.isEmpty { anulando.insert(.apellido) } else { apellidoNuevo = apellidoLimpio }
        }

        let nacimientoMs = nacimientoEnMs(zona: zona)
        let nacimientoNuevo = nacimientoMs != original.nacimientoEnMs(zona: zona) ? nacimientoMs : nil
        let sexoNuevo = sexo != original.sexo ? sexo : nil
        let pesoNuevo = pesoTexto != original.pesoTexto ? pesoEnGramos : nil
        let alturaNueva = alturaCambio(desde: original) ? alturaEnMilimetros : nil
        let nivelNuevo = nivel != original.nivel ? nivel : nil
        // La zona va CON los días, como en el alta: un "18:30" sin zona no es una hora.
        let diasNuevos = dias != original.dias && !dias.isEmpty ? diasDeEntrenamiento : nil
        let zonaNueva = diasNuevos == nil ? nil
            : String(zona.identifier.prefix(DatosRegistro.largoMaximoDeZona))

        let entrada = PerfilEntrada(firstName: nombreNuevo,
                                    lastName: apellidoNuevo,
                                    birthdateMs: nacimientoNuevo,
                                    biologicalSex: sexoNuevo,
                                    weightG: pesoNuevo,
                                    heightMm: alturaNueva,
                                    level: nivelNuevo,
                                    trainingDays: diasNuevos,
                                    timezone: zonaNueva)
        guard entrada != PerfilEntrada() || !anulando.isEmpty else { return nil }
        return CambiosDePerfil(entrada: entrada, anulando: anulando,
                               tocaElPlan: nivelNuevo != nil || diasNuevos != nil)
    }
}

// MARK: - El guardado

/// El estado del "Guardar" de una página de Ajustes, y su clave de idempotencia.
///
/// 🛑 Una clave por INTENTO (docs/API.md §6), como `FlujoEntrada.guardarYSeguir`:
/// se crea al tocar "Guardar", se conserva para "Reintentar" con lo mismo y la
/// sueltan el éxito y cualquier cambio en lo que se edita.
@MainActor
final class GuardadoDePerfil: ObservableObject {
    enum Estado: Equatable {
        case quieto, guardando, guardado
        case fallo(String)
    }

    @Published private(set) var estado: Estado = .quieto
    private var clave: String?

    /// Cambió lo que se edita: el intento anterior se cierra. El tilde de
    /// "Guardado" se va recién cuando hay algo nuevo sin guardar.
    func contenidoCambio(hayCambios: Bool) {
        clave = nil
        if case .fallo = estado { estado = .quieto }
        if hayCambios, estado == .guardado { estado = .quieto }
    }

    /// Manda los cambios. Devuelve el perfil nuevo, o `nil` si falló (el error
    /// queda en `estado` para mostrarlo con "Reintentar").
    func guardar(_ cambios: CambiosDePerfil, en flujo: FlujoEntrada) async -> Perfil? {
        guard estado != .guardando else { return nil }
        let claveDelIntento = clave ?? UUID().uuidString
        clave = claveDelIntento
        estado = .guardando
        let respuesta = await flujo.guardarEdicionDelPerfil(cambios.entrada, anulando: cambios.anulando,
                                                             claveDeIdempotencia: claveDelIntento)
        guard case .ok(let perfil) = respuesta else {
            estado = .fallo(TraductorDeErrores.texto(respuesta))
            return nil
        }
        if clave == claveDelIntento { clave = nil }
        estado = .guardado
        Haptico.exito()
        Task { [weak self] in
            // El tilde es una confirmación breve, no un estado.
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if self?.estado == .guardado { self?.estado = .quieto }
        }
        return perfil
    }
}
