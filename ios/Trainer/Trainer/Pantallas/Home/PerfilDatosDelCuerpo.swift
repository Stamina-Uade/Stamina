import SwiftUI
import TrainerCore

// =============================================================================
// Peso, altura y edad: los tres datos del cuerpo que muestra el perfil.
//
// Ronda 5 (pedido de Ivan: UI limpia, sin explicaciones): ya no hay hoja que
// explique cada dato. Editar uno ya cargado no existe todavía en la app; si
// falta alguno, el perfil ofrece completarlo con los mismos pasos del alta
// (`FlujoEntrada.retomarPerfil()`).
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
