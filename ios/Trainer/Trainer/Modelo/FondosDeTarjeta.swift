import Foundation
import SwiftUI
import UIKit
import TrainerCore

// =============================================================================
// Qué foto va de fondo en las tarjetas héroe (Inicio, Plan).
//
// Antes la cuenta regresiva de un plan de running mostraba "BienvenidaRuta",
// que en realidad es una foto de ciclismo. Ahora la foto sale de un pool por
// disciplina y rota una por día: con el pool completo (20) la misma foto no
// se repite en 20 días seguidos. Cada tarjeta ("inicio", "plan") arranca en
// otro punto del pool, así el mismo día no ven la misma foto.
//
// Las fotos nuevas se agregan al catálogo con el nombre exacto
// (FondoRunning01…20, FondoCiclismo01…20, FondoNatacion01…20; ver
// docs/PROMPTS-FONDOS.md) y aparecen solas: sólo se eligen las que existen.
//
// 2026-10-23 (decisión de Iván): la persona de la foto se ve ENTERA, nunca con
// la cabeza cortada. Las fotos son verticales (1536 × 2752) y la tarjeta es
// apaisada: entra apenas un tercio del alto. Cada foto que entra tiene su punto
// de encuadre (dónde está la persona), y `TarjetaHeroe` centra el recorte ahí.
// Las que tienen a la persona de cuerpo entero ocupando media foto no entran en
// esa proporción y salen de las candidatas (`noEntranEnLaTarjeta`). Se revisaron
// las 20 una por una; las que salen siguen en el catálogo (la bienvenida usa 01,
// 09 y 20 a pantalla completa).
// =============================================================================

/// La familia de fotos. No es lo mismo que `DeporteDeSesion`: trekking y
/// fuerza usan fotos de running, y el triatlón no tiene foto propia.
enum Disciplina: String, CaseIterable, Sendable {
    case running, ciclismo, natacion
}

enum FondosDeTarjeta {
    /// Cuántas fotos tiene cada pool completo.
    static let tamanoDelPool = 20

    /// Los pools: "FondoRunning01"…"FondoRunning20", etc.
    static func pool(de disciplina: Disciplina) -> [String] {
        let prefijo: String
        switch disciplina {
        case .running: prefijo = "FondoRunning"
        case .ciclismo: prefijo = "FondoCiclismo"
        case .natacion: prefijo = "FondoNatacion"
        }
        return (1...tamanoDelPool).map { prefijo + String(format: "%02d", $0) }
    }

    /// Si el pool está vacío (todavía no se cargaron fotos), las de siempre.
    static func respaldo(de disciplina: Disciplina) -> [String] {
        switch disciplina {
        case .running: return ["BienvenidaAmanecer", "BienvenidaMontana"]
        case .ciclismo: return ["BienvenidaRuta"]
        case .natacion: return []
        }
    }

    /// Fotos que NUNCA van con esa disciplina, aunque alguien las meta en un
    /// pool por error. "BienvenidaRuta" es ciclismo (El Tour de Francia.png).
    static func prohibidas(para disciplina: Disciplina) -> Set<String> {
        switch disciplina {
        case .running: return ["BienvenidaRuta"]
        case .ciclismo, .natacion: return []
        }
    }

    /// Dónde está la persona en cada foto que entra en la tarjeta apaisada, en
    /// fracciones de la foto (0 arriba/izquierda, 1 abajo/derecha).
    static let encuadres: [String: UnitPoint] = [
        "FondoRunning02": UnitPoint(x: 0.50, y: 0.52),
        "FondoRunning06": UnitPoint(x: 0.48, y: 0.51),
        "FondoRunning10": UnitPoint(x: 0.53, y: 0.55),
        "FondoRunning13": UnitPoint(x: 0.50, y: 0.52),
        "FondoRunning14": UnitPoint(x: 0.50, y: 0.50),
        "FondoRunning15": UnitPoint(x: 0.50, y: 0.62),
        "FondoRunning17": UnitPoint(x: 0.50, y: 0.51),
        "FondoRunning19": UnitPoint(x: 0.50, y: 0.50),
    ]

    /// La persona va de cuerpo entero y ocupa casi media foto (o más): en una
    /// tarjeta apaisada se le cortaría la cabeza o las piernas. No se eligen.
    static let noEntranEnLaTarjeta: Set<String> = [
        "FondoRunning01", "FondoRunning03", "FondoRunning04", "FondoRunning05",
        "FondoRunning07", "FondoRunning08", "FondoRunning09", "FondoRunning11",
        "FondoRunning12", "FondoRunning16", "FondoRunning18", "FondoRunning20",
    ]

    /// El punto de encuadre de una foto; sin dato, el centro.
    static func encuadre(de imagen: String?) -> UnitPoint {
        imagen.flatMap { encuadres[$0] } ?? .center
    }

    /// Las tarjetas que piden foto. El orden define el desfase: cada una
    /// arranca en otra parte del pool.
    static let contextosConocidos = ["inicio", "plan"]

    // MARK: - Disciplina

    /// Gancho para planes multideporte: qué fotos corresponden a un deporte.
    /// Con `MVP.soloRunning` siempre es running. Un plan de triatlón no tiene
    /// foto propia: quien llama tiene que pasar el deporte de la sesión del día
    /// (natación, ciclismo o running); si pasa `.triatlon`, cae a running.
    static func disciplina(de deporte: DeporteDeSesion,
                           soloRunning: Bool = MVP.soloRunning) -> Disciplina {
        if soloRunning { return .running }
        switch deporte {
        case .ciclismo: return .ciclismo
        case .natacion: return .natacion
        case .running, .trekking, .fuerza, .otro, .triatlon: return .running
        }
    }

    // MARK: - Elegir la foto

    /// La foto del día para una tarjeta, mirando el catálogo de assets.
    /// `nil` = no hay ninguna: `TarjetaHeroe` muestra el degradado de la marca.
    static func imagen(para disciplina: Disciplina, fecha: Date = Date(), contexto: String) -> String? {
        imagen(para: disciplina, fecha: fecha, contexto: contexto, disponibles: assetsExistentes)
    }

    /// Lo mismo, desde el deporte de la sesión (gancho multideporte).
    static func imagen(paraDeporte deporte: DeporteDeSesion, fecha: Date = Date(),
                       contexto: String) -> String? {
        imagen(para: disciplina(de: deporte), fecha: fecha, contexto: contexto)
    }

    /// El núcleo, sin UIKit: los tests le pasan qué assets "existen".
    /// - Parameters:
    ///   - disponibles: nombres de assets que existen en el catálogo.
    ///   - soloRunning: con `true` la disciplina siempre es running.
    ///   - calendario: el día se cuenta en el calendario local.
    static func imagen(para disciplina: Disciplina,
                       fecha: Date = Date(),
                       contexto: String,
                       disponibles: Set<String>,
                       soloRunning: Bool = MVP.soloRunning,
                       calendario: Calendar = .autoupdatingCurrent) -> String? {
        let efectiva: Disciplina = soloRunning ? .running : disciplina
        let lista = candidatas(para: efectiva, disponibles: disponibles)
        guard !lista.isEmpty else { return nil }
        let n = lista.count
        let indice = modulo(indiceDelDia(fecha, calendario: calendario) + desfase(contexto: contexto, cantidad: n), n)
        return lista[indice]
    }

    /// Las fotos que se pueden usar, en el orden del pool. Si del pool no
    /// existe ninguna, las de respaldo. Nunca una prohibida ni una que no entra
    /// en la tarjeta.
    static func candidatas(para disciplina: Disciplina, disponibles: Set<String>) -> [String] {
        let fuera = prohibidas(para: disciplina).union(noEntranEnLaTarjeta)
        let usables: (String) -> Bool = { disponibles.contains($0) && !fuera.contains($0) }
        let delPool = pool(de: disciplina).filter(usables)
        if !delPool.isEmpty { return delPool }
        return respaldo(de: disciplina).filter(usables)
    }

    // MARK: - Aritmética del día

    /// Días desde una fecha fija (1/1/2024), contados en el calendario local:
    /// cambia a medianoche y no se corre con el horario de verano.
    static func indiceDelDia(_ fecha: Date, calendario: Calendar = .autoupdatingCurrent) -> Int {
        guard let epoca = calendario.date(from: DateComponents(year: 2024, month: 1, day: 1)) else { return 0 }
        let dias = calendario.dateComponents([.day],
                                             from: calendario.startOfDay(for: epoca),
                                             to: calendario.startOfDay(for: fecha)).day
        return dias ?? 0
    }

    /// Dónde arranca cada tarjeta en el pool. Las conocidas se reparten
    /// parejo (con 20 fotos: 0 y 10; con 2: 0 y 1), así dos tarjetas del
    /// mismo día no coinciden mientras haya al menos 2 fotos. Las demás usan
    /// un hash estable (no `hashValue`, que cambia en cada arranque).
    static func desfase(contexto: String, cantidad: Int) -> Int {
        guard cantidad > 0 else { return 0 }
        if let posicion = contextosConocidos.firstIndex(of: contexto) {
            return posicion * cantidad / contextosConocidos.count
        }
        var hash: UInt64 = 5381
        for byte in contexto.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return Int(hash % UInt64(cantidad))
    }

    private static func modulo(_ a: Int, _ n: Int) -> Int {
        let r = a % n
        return r < 0 ? r + n : r
    }

    // MARK: - Catálogo

    /// Qué assets de fondo existen. El catálogo no cambia mientras corre la
    /// app: se mira una sola vez.
    static let assetsExistentes: Set<String> = {
        var nombres: [String] = []
        for disciplina in Disciplina.allCases {
            nombres += pool(de: disciplina) + respaldo(de: disciplina)
        }
        return Set(nombres.filter { UIImage(named: $0) != nil })
    }()
}
