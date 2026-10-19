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
        case .running: return Textos.signupSportRunning
        case .ciclismo: return Textos.signupSportCycling
        case .trekking: return Textos.signupSportTrekking
        case .triatlon: return Textos.signupSportTriathlon
        case .natacion: return Textos.sportSwimming
        case .fuerza: return Textos.sportStrength
        case .otro: return Textos.sportOther
        }
    }
}
