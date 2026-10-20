import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    /// Nombre del ícono de la app en el catálogo. El logo de adentro de la app
    /// es este mismo ícono (ver `LogoApp`).
    public static let recursoLogo = "AppIcon"
}

/// Logotipo oficial de la aplicación: el MISMO ícono de la app.
///
/// Antes había un `LogoApp.imageset` que era una copia de `AppIcon`: dos
/// archivos para una sola imagen, y el día que se cambiara el ícono el logo
/// quedaba viejo. Ahora se lee el ícono que iOS ya instaló con la app
/// (`CFBundleIcons` → `CFBundlePrimaryIcon` → `CFBundleIconFiles`). Si no se
/// encuentra (previews del paquete, tests), se dibuja la inicial de la marca.
public struct LogoApp: View {
    private let tamano: CGFloat
    private let radio: CGFloat

    public init(tamano: CGFloat = TokensEspaciado.e26, radio: CGFloat = TokensRadio.celda) {
        self.tamano = tamano
        self.radio = radio
    }

    public var body: some View {
        Group {
            #if canImport(UIKit)
            if let icono = MarcaApp.iconoDeLaApp {
                Image(uiImage: icono)
                    .resizable()
                    .scaledToFill()
            } else {
                inicial
            }
            #else
            inicial
            #endif
        }
        .frame(width: tamano, height: tamano)
        .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
        .accessibilityHidden(true)
    }

    private var inicial: some View {
        ZStack {
            Paleta.acento
            Text(String(MarcaApp.nombre.prefix(1)))
                .font(.system(size: tamano * 0.6, weight: .heavy))
                .foregroundStyle(Paleta.sobreAcento)
        }
    }
}

#if canImport(UIKit)
extension MarcaApp {
    /// El ícono principal de la app, tal como quedó en el bundle.
    public static var iconoDeLaApp: UIImage? {
        guard let iconos = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let principal = iconos["CFBundlePrimaryIcon"] as? [String: Any],
              let archivos = principal["CFBundleIconFiles"] as? [String],
              let ultimo = archivos.last else { return nil }
        return UIImage(named: ultimo)
    }
}
#endif
