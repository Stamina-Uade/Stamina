import SwiftUI
import TrainerCore

// =============================================================================
// Peso, altura y edad: los tres datos del cuerpo que muestra el perfil.
//
// Ronda 5 (pedido de Ivan: UI limpia, sin explicaciones): ya no hay hoja que
// explique cada dato. Ronda 6: se editan en Ajustes → Datos personales; tocar
// una tarjeta (o "Completar ahora") abre Ajustes ya en esa página.
// =============================================================================

/// Uno de los tres datos del cuerpo que muestra el perfil.
enum DatoDelCuerpo: String, Identifiable, CaseIterable {
    case peso, altura, edad

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .peso: return Textos.profileWeight
        case .altura: return Textos.profileHeight
        case .edad: return Textos.profileAge
        }
    }

    var simbolo: String {
        switch self {
        case .peso: return "scalemass"
        case .altura: return "ruler"
        case .edad: return "calendar"
        }
    }
}
