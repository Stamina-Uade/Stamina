import SwiftUI

/// Modo de apariencia visual de la aplicación (Automático, Modo día, Modo noche).
public enum ModoApariencia: String, CaseIterable, Identifiable {
    case automatico = "automatico"
    case claro = "claro"
    case oscuro = "oscuro"

    public var id: String { rawValue }

    public static let clave = "ajuste_modo_apariencia"

    public var titulo: String {
        switch self {
        case .automatico: return "Automático"
        case .claro: return "Modo día"
        case .oscuro: return "Modo noche"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .automatico: return nil
        case .claro: return .light
        case .oscuro: return .dark
        }
    }
}
