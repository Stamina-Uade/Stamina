import SwiftUI

// =============================================================================
// Configuración de marca e identidad visual del producto (AGENTS.md §1).
//
// Centraliza el nombre de la aplicación y el recurso del logotipo para que
// cualquier cambio de identidad se aplique desde un solo lugar.
// =============================================================================

/// Constantes centrales de la marca.
public enum MarcaApp {
    /// Nombre visible del producto.
    public static let nombre = "Stamina"

    /// Nombre del recurso de imagen para el logo de la aplicación.
    public static let recursoLogo = "LogoApp"
}

/// Logotipo oficial de la aplicación.
///
/// Muestra el recurso de imagen centralizado con dimensiones y esquinas
/// redondeadas continuas según el design system.
public struct LogoApp: View {
    private let tamano: CGFloat
    private let radio: CGFloat

    public init(tamano: CGFloat = TokensEspaciado.e26, radio: CGFloat = TokensRadio.celda) {
        self.tamano = tamano
        self.radio = radio
    }

    public var body: some View {
        Image(MarcaApp.recursoLogo)
            .resizable()
            .scaledToFill()
            .frame(width: tamano, height: tamano)
            .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
            .accessibilityHidden(true)
    }
}
