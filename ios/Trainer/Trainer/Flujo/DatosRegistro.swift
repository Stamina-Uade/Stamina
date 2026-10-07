import Foundation
import TrainerCore

// =============================================================================
// Lo que juntan los pasos del registro, y qué manda cada uno al contrato.
//
// 🛑 Esto NO valida por seguridad: valida para no hacerle perder el viaje a la
// persona. **Toda validación se hace cumplir en el servidor** (AGENTS.md §10).
// Un botón deshabilitado acá es comodidad, nunca la regla.
//
// La otra mitad del trabajo es la conversión. El diseño pide kg, cm y fechas del
// calendario, que es como la gente se piensa; el contrato guarda **gramos y
// milímetros enteros** y **milisegundos epoch** (AGENTS.md §5). La conversión
// pasa una sola vez, acá, y no en cada pantalla — y es lo mismo que hace
// `BorradorDePerfil` en Android (`pantallas/acceso/DatosDePerfil.kt`).
// =============================================================================

struct DatosRegistro: Equatable {
    var correo = ""
    var codigo = ""

    var nombre = ""
    /// Opcional, como en `reg-nombre` del diseño. Vacío viaja como `null`
    /// explícito: es la única forma de borrar uno que ya estaba (docs/API.md §7).
    var apellido = ""

    /// 🛑 Arranca SIN fecha, y se sigue recién después de mover la rueda. Con una
    /// fecha de fábrica, alguien de quince años que tocaba "Continuar" quedaba
    /// guardado como adulto, con objetivos de calorías de adulto. Es la misma regla
    /// que las elecciones de abajo, y Android también arranca vacío.
    var nacimiento: Date?

    /// 🛑 Las elecciones de una sola opción arrancan SIN nada elegido. El diseño
    /// las dibuja con una marcada, y una opción marcada de fábrica es un dato que
    /// la persona no eligió — que ahora se guarda en el servidor apenas toca
    /// "Continuar". Para el sexo biológico y el nivel no es cosmético: de ahí
    /// salen la sudoración estimada y el volumen inicial del plan. Es la regla de
    /// `BorradorDePerfil.puedeSeguir` en Android.
    var sexo: SexoBiologico?

    /// Tal como se escribe: "72", "72,5" o "72.5".
    var pesoTexto = ""
    var alturaTexto = ""

    var deporte: Deporte?
    var nivel: Nivel?
    var objetivo: Objetivo?
    var objetivosAdicionales: [Objetivo] = []
    var fechaObjetivo: Date?

    var descargoAceptado = false
    var medicion: Medicion?

    /// Día ISO (1 = lunes) → minuto del día. El diseño arranca con tres días, y
    /// se ven en pantalla con su hora antes de que alguien toque "Continuar".
    var dias: [Int: Int] = [2: 18 * 60 + 30, 4: 18 * 60 + 30, 6: 7 * 60]

    /// Qué usa la persona para medir. `reg-medicion`.
    ///
    /// ⚠️ **Este dato no tiene lugar en el contrato v1** (B-006). `PerfilEntrada`
    /// no lo declara, así que el paso se completa, el valor **no se manda**, y la
    /// pantalla lo dice. Es lo mismo que hace Android.
    enum Medicion: String, CaseIterable, Equatable {
        case gps, garmin, apple, manual
    }

    /// Dónde se para la rueda mientras no hay nada elegido: la fecha que dibuja el
    /// diseño. Es SÓLO una posición: no se guarda ni deja seguir.
    static var posicionInicialDeLaRueda: Date {
        var c = DateComponents()
        c.year = 1998; c.month = 6; c.day = 24
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }
}

// MARK: - Lo que cada paso necesita para dejar seguir

extension DatosRegistro {
    /// `PerfilEntrada.weight_g` y `height_mm` del contrato: los mismos topes, para
    /// avisar antes de que el servidor rechace.
    static let pesoValido: ClosedRange<Int64> = 20_000...400_000
    static let alturaValida: ClosedRange<Int64> = 500...2_600

    /// `PerfilEntrada.first_name.maxLength` y `last_name.maxLength`.
    static let largoMaximoDelNombre = 80

    /// `PerfilEntrada.timezone.maxLength`.
    static let largoMaximoDeZona = 64

    var correoValido: Bool { DatosRegistro.pareceCorreo(correo) }

    var codigoCompleto: Bool {
        codigo.count == CampoCodigo.largo
            && codigo.allSatisfy { $0.isLetter || $0.isNumber }
    }

    /// Con el nombre alcanza: el apellido es opcional.
    var nombreListo: Bool {
        !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nombreCompletoListo: Bool {
        nombreListo && !apellido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nombre.count <= Self.largoMaximoDelNombre
            && apellido.count <= Self.largoMaximoDelNombre
    }

    var pesoEnGramos: Int64? {
        guard let kg = DatosRegistro.numero(pesoTexto) else { return nil }
        let g = Int64((kg * 1000).rounded())
        return DatosRegistro.pesoValido.contains(g) ? g : nil
    }

    var alturaEnMilimetros: Int64? {
        guard let cm = DatosRegistro.numero(alturaTexto) else { return nil }
        let mm = Int64((cm * 10).rounded())
        return DatosRegistro.alturaValida.contains(mm) ? mm : nil
    }

    var cuerpoCompleto: Bool { pesoEnGramos != nil && alturaEnMilimetros != nil }

    var diasElegidos: [Int] { dias.keys.sorted() }

    var hayAlgunDia: Bool { !dias.isEmpty }

    /// Acepta coma o punto decimal: el teclado numérico de iOS ofrece el
    /// separador del locale, y quien viene de otro teclado escribe el otro.
    static func numero(_ texto: String) -> Double? {
        let limpio = texto
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !limpio.isEmpty else { return nil }
        return Double(limpio)
    }

    /// El mismo criterio que el diseño: algo, arroba, algo, punto, algo. No es
    /// una validación de RFC y no pretende serlo — la de verdad es que el código
    /// llegue al buzón.
    static func pareceCorreo(_ texto: String) -> Bool {
        let t = texto.trimmingCharacters(in: .whitespaces)
        guard let arroba = t.firstIndex(of: "@"), arroba != t.startIndex else { return false }
        let dominio = t[t.index(after: arroba)...]
        return !dominio.isEmpty
            && !dominio.contains("@")
            && dominio.contains(".")
            && !dominio.hasPrefix(".")
            && !dominio.hasSuffix(".")
            && !t.contains(" ")
    }

    /// Si ese paso de perfil puede seguir. Es lo que habilita "Continuar".
    func puedeSeguir(en paso: Pantalla) -> Bool {
        switch paso {
        case .regNombre: return nombreListo
        case .regNacimiento: return nacimiento != nil
        case .regSexo: return sexo != nil
        case .regCuerpo: return cuerpoCompleto
        case .regDeporte: return deporte != nil
        case .regNivel: return nivel != nil
        case .regObjetivo: return objetivo != nil
        case .regSalud: return descargoAceptado
        // "Ahora no" del diseño: se puede seguir sin elegir nada.
        case .regMedicion: return true
        case .regDias: return hayAlgunDia
        case .regListo: return true
        default: return false
        }
    }
}

// MARK: - Lo que cada paso manda a `PATCH /me`

extension DatosRegistro {
    /// Lo que ESE paso guarda, y nada más. `nil` es "este paso no guarda nada": el
    /// resumen, y la medición, que no tiene campo (B-006).
    ///
    /// Manda sólo lo suyo por dos motivos. Uno: `PerfilEntrada` tiene todo
    /// opcional y los opcionales en `nil` no viajan, así que un pedido chico no
    /// borra lo que guardó otro paso. Dos: si falla el paso 9, lo que falló es el
    /// paso 9, y se ve dónde.
    func loQueGuarda(en paso: Pantalla, zonaHoraria: TimeZone) -> PerfilEntrada? {
        switch paso {
        case .regNombre:
            let apellidoLimpio = DatosRegistro.recortado(apellido)
            // El apellido vacío no viaja como `""` —el contrato pide minLength 1—
            // sino como `null` explícito: ver `camposEnNull(en:)`.
            return PerfilEntrada(firstName: DatosRegistro.recortado(nombre),
                                 lastName: apellidoLimpio.isEmpty ? nil : apellidoLimpio)
        case .regNacimiento:
            // Sin fecha elegida no viaja nada: `puedeSeguir` ya no deja llegar acá.
            return nacimiento.map {
                PerfilEntrada(birthdateMs: DatosRegistro.fechaDelCalendarioEnMs($0, zona: zonaHoraria))
            }
        case .regSexo:
            return sexo.map { PerfilEntrada(biologicalSex: $0) }
        case .regCuerpo:
            guard let gramos = pesoEnGramos, let milimetros = alturaEnMilimetros else { return nil }
            return PerfilEntrada(weightG: gramos, heightMm: milimetros)
        case .regDeporte:
            return deporte.map { PerfilEntrada(sport: $0) }
        case .regNivel:
            return nivel.map { PerfilEntrada(level: $0) }
        case .regObjetivo:
            // 🛑 La fecha viaja SIEMPRE, también sin fecha: el diseño deja seguir
            // sin ella y el contrato modela ese `null` a propósito ("está y vale
            // nada"). Sin el `null`, "sin fecha" no borraría una que ya estaba.
            guard let objetivo else { return nil }
            return PerfilEntrada(goal: objetivo,
                                 goalDateMs: fechaObjetivo.map {
                                     DatosRegistro.fechaDelCalendarioEnMs($0, zona: zonaHoraria)
                                 })
        case .regSalud:
            return descargoAceptado ? PerfilEntrada(medicalDisclaimerAccepted: true) : nil
        case .regMedicion:
            return nil
        case .regDias:
            // La zona va CON los días y no antes: un "18:30" sin zona no es una hora,
            // y el aviso de preparación se dispara con las dos cosas.
            return PerfilEntrada(trainingDays: diasDeEntrenamiento,
                                 timezone: String(zonaHoraria.identifier.prefix(DatosRegistro.largoMaximoDeZona)))
        default:
            return nil
        }
    }

    /// Los campos que ese paso manda como `null` EXPLÍCITO.
    ///
    /// 🛑 Es la diferencia entre "no lo toques" y "borralo": en un PATCH parcial
    /// una clave ausente deja el valor viejo. Hoy son dos, el apellido y la fecha
    /// de la carrera — los mismos que `BorradorDePerfil.camposEnNull` de Android.
    func camposEnNull(en paso: Pantalla) -> Set<CampoAnulable> {
        switch paso {
        case .regNombre:
            return DatosRegistro.recortado(apellido).isEmpty ? [.apellido] : []
        case .regObjetivo:
            return fechaObjetivo == nil ? [.fechaDelObjetivo] : []
        default:
            return []
        }
    }

    /// Los días elegidos, de lunes a domingo, como los pide el contrato.
    var diasDeEntrenamiento: [DiaEntrenamiento] {
        dias
            .filter { (1...7).contains($0.key) && (0...1439).contains($0.value) }
            .sorted { $0.key < $1.key }
            .map { DiaEntrenamiento(weekday: Int64($0.key), minuteOfDay: Int64($0.value)) }
    }

    /// Los milisegundos que el contrato guarda para una FECHA del calendario: el
    /// nacimiento y el día de la carrera.
    ///
    /// 🛑 **Medianoche UTC del día elegido, no medianoche local.** Un nacimiento
    /// es una fecha, no un instante: el 24 de junio es el 24 de junio en Ushuaia y
    /// en Tokio. Con la medianoche local, la misma persona guardaría un número
    /// distinto según dónde esté parada, y al mostrarlo en otro huso aparecería el
    /// día anterior. Es lo mismo que hace `FechaSimple.aEpocaMs` en Android, y
    /// tiene que serlo: si no, las dos apps guardan números distintos para la
    /// misma fecha.
    ///
    /// El día se lee con el calendario GREGORIANO del huso de la persona, no con el
    /// calendario del teléfono: con el budista o el japonés, `year` es otro número.
    static func fechaDelCalendarioEnMs(_ fecha: Date, zona: TimeZone) -> Int64 {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = zona
        let partes = local.dateComponents([.year, .month, .day], from: fecha)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        guard let medianoche = utc.date(from: DateComponents(year: partes.year,
                                                             month: partes.month,
                                                             day: partes.day)) else {
            return epochMs(fecha)
        }
        return epochMs(medianoche)
    }

    static func epochMs(_ fecha: Date) -> Int64 {
        Int64((fecha.timeIntervalSince1970 * 1000).rounded())
    }

    /// Sin espacios de sobra y dentro del largo del contrato.
    private static func recortado(_ texto: String) -> String {
        String(texto.trimmingCharacters(in: .whitespacesAndNewlines).prefix(largoMaximoDelNombre))
    }
}
