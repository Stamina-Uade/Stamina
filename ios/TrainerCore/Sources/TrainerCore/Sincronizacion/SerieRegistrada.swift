import Foundation

// =============================================================================
// La serie registrada, y cómo se fusionan dos versiones de la misma.
//
// Implementa `docs/decisiones/0006`, cerrada el 2026-09-09. Las tres reglas que
// gobiernan este archivo:
//
// 1. **La identidad es determinística**: `(sesión, ejercicio, número)`. No un
//    UUID del cliente. Si cada dispositivo generara su id, tocar la misma serie
//    en los dos lados daría DOS filas para la misma serie física.
// 2. **`hecha` es monotónica**: al fusionar sólo va de `false` a `true`. Ninguna
//    sincronización desmarca una serie.
// 3. **La fusión es por FILA COMPLETA, nunca por campo.** Tomar las repeticiones
//    de un lado y el peso del otro produce un estado que nadie registró.
//
// 🛑 Y una propiedad que no es negociable: `fusionar` tiene que ser
// **conmutativa, asociativa e idempotente**. Los dos dispositivos la corren por
// separado sobre los mismos datos; si el resultado dependiera del orden,
// divergirían en silencio. Los tests lo verifican.
// =============================================================================

/// Qué dispositivo registró algo. Sirve para desempatar y para la UI.
public enum Dispositivo: String, Codable, Sendable, CaseIterable, Comparable {
    case telefono
    case reloj

    public static func < (a: Dispositivo, b: Dispositivo) -> Bool {
        a.rawValue < b.rawValue
    }
}

/// La identidad de una serie. Determinística a propósito: ver la regla 1.
public struct ClaveDeSerie: Hashable, Codable, Sendable {
    public let sesion: String
    public let ejercicio: String
    /// 1-based, como se ve en pantalla. Las extra siguen numerando después de
    /// la última prescrita.
    public let numero: Int

    public init(sesion: String, ejercicio: String, numero: Int) {
        self.sesion = sesion
        self.ejercicio = ejercicio
        self.numero = numero
    }
}

public struct SerieRegistrada: Codable, Sendable, Equatable, Identifiable {
    public var id: ClaveDeSerie { clave }

    public let clave: ClaveDeSerie
    public var hecha: Bool
    public var repeticiones: Int
    /// Gramos, unidad base del contrato (§5). `nil` = peso corporal.
    public var pesoGramos: Int?
    public var salteada: Bool
    public var esExtra: Bool

    /// Cuándo la recibió el SERVIDOR, en ms epoch. `nil` mientras no llegó.
    ///
    /// La regla 3 de la decisión 0006 dice "última escritura **por hora de
    /// llegada al servidor**": el reloj de un cliente no es un orden confiable
    /// entre dos dispositivos que estuvieron sin red.
    ///
    /// 🛑 `Int64`, no `Int`: en los Apple Watch arm64_32 (Series 6 a 8 y SE, con
    /// watchOS 11) `Int` es de 32 bits, y un epoch en milisegundos (~1,8 billones) no
    /// entra: el reloj se cerraba al registrar una serie.
    public var recibidaEnServidorMs: Int64?

    /// El momento local. Sólo ordena lo que **todavía no llegó** al servidor.
    public var registradaLocalMs: Int64

    public let dispositivo: Dispositivo

    public init(clave: ClaveDeSerie, hecha: Bool, repeticiones: Int, pesoGramos: Int? = nil,
                salteada: Bool = false, esExtra: Bool = false,
                recibidaEnServidorMs: Int64? = nil, registradaLocalMs: Int64,
                dispositivo: Dispositivo) {
        self.clave = clave
        self.hecha = hecha
        self.repeticiones = repeticiones
        self.pesoGramos = pesoGramos
        self.salteada = salteada
        self.esExtra = esExtra
        self.recibidaEnServidorMs = recibidaEnServidorMs
        self.registradaLocalMs = registradaLocalMs
        self.dispositivo = dispositivo
    }
}

// MARK: - La fusión

extension SerieRegistrada {

    /// Fusiona dos versiones de **la misma** serie.
    ///
    /// - Precondition: las dos tienen la misma `clave`.
    public static func fusionar(_ a: SerieRegistrada, _ b: SerieRegistrada) -> SerieRegistrada {
        precondition(a.clave == b.clave, "sólo se fusionan versiones de la misma serie")

        // La fila entera viene de quien ganó. Nunca se mezclan campos (regla 3).
        var resultado = gana(a, b) ? a : b

        // `hecha` es la excepción, y es monotónica (regla 2): si alguno la marcó,
        // queda marcada. Desmarcar es una acción explícita de la persona, que
        // viaja como una escritura nueva y gana por su propio momento.
        resultado.hecha = a.hecha || b.hecha

        return resultado
    }

    /// ¿Gana `a` sobre `b`?
    ///
    /// El orden tiene que ser **total y determinístico**: los dos dispositivos
    /// corren esto por separado y tienen que llegar al mismo resultado.
    private static func gana(_ a: SerieRegistrada, _ b: SerieRegistrada) -> Bool {
        // 1. Lo que llegó al servidor le gana a lo que todavía no llegó, y entre
        //    dos que llegaron gana el que llegó después.
        switch (a.recibidaEnServidorMs, b.recibidaEnServidorMs) {
        case let (ta?, tb?) where ta != tb: return ta > tb
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }

        // 2. Entre dos que no llegaron —o que llegaron en el mismo milisegundo—
        //    ordena el momento local.
        if a.registradaLocalMs != b.registradaLocalMs {
            return a.registradaLocalMs > b.registradaLocalMs
        }

        // 3. Empate exacto: desempata el dispositivo. No es "mejor", es
        //    **estable**: sin esto los dos lados podrían elegir distinto y
        //    divergir para siempre.
        return a.dispositivo > b.dispositivo
    }
}

// MARK: - La unión de dos conjuntos de series

public enum FusionDeSeries {

    /// Une lo de los dos dispositivos.
    ///
    /// Series con la misma clave se fusionan en una; con claves distintas, se
    /// unen. Es exactamente lo que pidió Iván al cerrar la decisión 0006.
    public static func unir(_ unas: [SerieRegistrada], _ otras: [SerieRegistrada]) -> [SerieRegistrada] {
        var porClave: [ClaveDeSerie: SerieRegistrada] = [:]
        for serie in unas + otras {
            if let previa = porClave[serie.clave] {
                porClave[serie.clave] = SerieRegistrada.fusionar(previa, serie)
            } else {
                porClave[serie.clave] = serie
            }
        }
        // Orden estable: por ejercicio y número, que es como se ven en pantalla.
        return porClave.values.sorted {
            ($0.clave.ejercicio, $0.clave.numero) < ($1.clave.ejercicio, $1.clave.numero)
        }
    }

    /// ¿La unión dejó más series de las que se esperaban?
    ///
    /// La decisión 0006 dice "unión, **y avisa**": si al reencontrarse los dos
    /// dispositivos quedan más series que las prescritas más las extra que la
    /// persona agregó a propósito, la sesión se marca para revisar. No se pierde
    /// nada, pero tampoco se disimula.
    public static func hayQueRevisar(_ series: [SerieRegistrada], prescritasPorEjercicio: [String: Int]) -> Bool {
        let porEjercicio = Dictionary(grouping: series, by: { $0.clave.ejercicio })
        return porEjercicio.contains { ejercicio, suyas in
            let prescritas = prescritasPorEjercicio[ejercicio] ?? 0
            let extraDeliberadas = suyas.filter(\.esExtra).count
            return suyas.count > prescritas + extraDeliberadas
        }
    }
}

// MARK: - El id de la sesión

extension ClaveDeSerie {
    /// El id de la sesión de gimnasio de un día.
    ///
    /// 🛑 Los dos dispositivos tienen que derivar **el mismo** id, o las claves
    /// no coinciden y la unión duplica todo. Por eso vive acá y no en cada app:
    /// dos implementaciones de "cómo se llama la sesión de hoy" es la clase de
    /// divergencia que no se ve hasta que ya pasó.
    ///
    /// Se usa la fecha **local**, que es la que comparten un reloj y un teléfono
    /// que están en la misma muñeca y el mismo bolsillo.
    public static func sesionDeGimnasio(_ fecha: Date = Date(),
                                        calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: fecha)
        return String(format: "gym-%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
