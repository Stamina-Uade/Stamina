import SwiftUI

// =============================================================================
// Los botones de "entrar con Google" y "entrar con Apple".
//
// 🛑 ESTOS DOS NO SIGUEN EL DESIGN SYSTEM, Y ES A PROPÓSITO.
//
// Google y Apple publican guías de marca para sus botones de inicio de sesión y
// **exigen** un aspecto concreto: fondo, tipo de letra, color de texto y logo.
// Apartarse de eso es motivo de rechazo en la revisión de la App Store. Por eso:
//
// - Los colores salen de `color.proveedor` de tokens.json, que es un grupo
//   declarado como "marca de terceros", separado del producto.
// - **No se derivan del acento.** Si mañana la app es naranja, estos dos siguen
//   siendo blanco y negro. Es la única excepción a "cambiar el acento cambia
//   todo", y está acá escrita para que se vea que es deliberada.
//
// ⚠️ EL LOGO DE GOOGLE ES UN MARCADOR DE POSICIÓN.
// El archivo oficial no está en el repositorio y no se puede dibujar a mano: la
// "G" de cuatro colores es marca registrada y reproducirla incumple la misma
// guía que estos colores respetan. Hoy va una letra sola, neutra. Antes de
// publicar hay que bajar el asset oficial de la guía de Google y ponerlo en
// `Assets.xcassets`. Está anotado en la decisión 0007 §12.
// =============================================================================

/// Con qué proveedor entra la persona.
public enum Proveedor: Sendable {
    case google
    case apple

    var fondo: Color {
        switch self {
        case .google: return TokensColor.proveedorGoogleFondo
        case .apple: return TokensColor.proveedorAppleFondo
        }
    }

    var texto: Color {
        switch self {
        case .google: return TokensColor.proveedorGoogleTexto
        case .apple: return TokensColor.proveedorAppleTexto
        }
    }

    /// Google pide borde; el botón negro de Apple no lleva.
    var borde: Color? {
        switch self {
        case .google: return TokensColor.proveedorGoogleBorde
        case .apple: return nil
        }
    }
}

/// El botón de un proveedor, con su marca y no con la nuestra.
public struct BotonProveedor: View {
    private let proveedor: Proveedor
    private let titulo: String
    private let accion: () -> Void

    public init(_ proveedor: Proveedor, titulo: String, accion: @escaping () -> Void) {
        self.proveedor = proveedor
        self.titulo = titulo
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e10) {
                logo
                Text(titulo)
                    .estilo(.botonPrimario, color: proveedor.texto)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.botonPrimario)
            .background(proveedor.fondo)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
                    .strokeBorder(proveedor.borde ?? .clear, lineWidth: TokensEspaciado.e1)
            )
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(titulo)
    }

    @ViewBuilder
    private var logo: some View {
        switch proveedor {
        case .apple:
            // `apple.logo` es el símbolo que el propio sistema publica para esto.
            Image(systemName: "apple.logo")
                .font(.system(size: TokensTipografia.opcionTituloTamano,
                              weight: TokensTipografia.tituloCardPeso))
                .foregroundStyle(proveedor.texto)
        case .google:
            // Marcador de posición: ver la nota del encabezado.
            Text(verbatim: "G")
                .estilo(.opcionTitulo, color: proveedor.texto)
        }
    }
}
