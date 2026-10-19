import Foundation
import TrainerCore

// =============================================================================
// Cómo se NOMBRA un deporte en pantalla. Un solo lugar.
//
// Antes había cinco copias de `nombreDeporte(_:)` (Inicio, Entreno, Resumen,
// Historial, Calendario) y no coincidían: una decía "Carrera" y otra "Running",
// y tres caían a `rawValue.capitalized`, que muestra "Natacion" sin tilde. El
// ícono ya estaba unificado en `IconoDeporte` (TrainerCore).
// =============================================================================

extension DeporteDeSesion {
    /// El nombre visible, en el idioma de la app.
    var nombreVisible: String {
        switch self {
        case .running: return Textos.regDeporteRunning
        case .ciclismo: return Textos.regDeporteCiclismo
        case .trekking: return Textos.regDeporteTrekking
        case .triatlon: return Textos.regDeporteTriatlon
        case .natacion: return String(localized: "Natación", comment: "Nombre del deporte")
        case .fuerza: return String(localized: "Fuerza", comment: "Nombre del deporte")
        case .otro: return String(localized: "Otro", comment: "Nombre del deporte")
        }
    }
}
