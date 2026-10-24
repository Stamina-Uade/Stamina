import Foundation
import TrainerCore

// =============================================================================
// Los textos de la actividad en vivo. Salen del catálogo de ESTA extensión
// (`StaminaEnVivo/Localizable.xcstrings`): la extensión es otro bundle y no ve el
// de la app. Inglés es el idioma fuente; español (de "tú") y francés al lado.
//
// 🛑 "Carrera" y no el nombre del deporte que usa la app (`nombreVisible` dice
// "Running"): es lo que pidió Iván para esta tarjeta, como la de Strava.
// =============================================================================

enum TextosEnVivo {
    static var pausada: String { String(localized: "live.paused") }
    static var duracion: String { String(localized: "live.duration") }
    static var ritmo: String { String(localized: "live.pace") }
    static var distancia: String { String(localized: "live.distance") }

    static func deporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return String(localized: "live.sport.run")
        case .ciclismo: return String(localized: "live.sport.cycling")
        case .natacion: return String(localized: "live.sport.swimming")
        case .trekking: return String(localized: "live.sport.hiking")
        case .fuerza: return String(localized: "live.sport.strength")
        case .triatlon: return String(localized: "live.sport.triathlon")
        case .otro: return String(localized: "live.sport.other")
        }
    }
}
