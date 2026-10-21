import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
// Rediseño 2026-10-20 (pedido de Iván, con una captura de referencia): los dos
// botones son un PAR — mismo fondo, mismo borde fino, mismo alto — y cambia sólo
// el logo y el texto. En modo noche es el "dark theme" de Google (#131314 con
// borde #8E918F); en modo día, el claro de Google y el negro de Apple.
//
// ⚠️ EL LOGO DE GOOGLE: la "G" de cuatro colores es marca registrada y no se
// dibuja a mano. Va el oficial, que está en `Assets.xcassets` de la app como
// `GoogleIcon`. Si faltara, va una "G" neutra. Está anotado en la decisión 0007 §12.
// =============================================================================

/// Con qué proveedor entra la persona.
public enum Proveedor: String, Sendable, Equatable, CaseIterable {
    case google
    case apple

    /// Cómo se llama en el contrato (`POST /auth/social`, campo `provider`).
    public var claveDelContrato: String { rawValue }

    func fondo(_ esquema: ColorScheme) -> Color {
        switch (self, esquema) {
        case (.google, .dark): return TokensColor.proveedorGoogleFondoOscuro
        case (.apple, .dark): return TokensColor.proveedorAppleFondoOscuro
        case (.google, _): return TokensColor.proveedorGoogleFondo
        case (.apple, _): return TokensColor.proveedorAppleFondo
        }
    }

    func texto(_ esquema: ColorScheme) -> Color {
        switch (self, esquema) {
        case (.google, .dark): return TokensColor.proveedorGoogleTextoOscuro
        case (.apple, .dark): return TokensColor.proveedorAppleTextoOscuro
        case (.google, _): return TokensColor.proveedorGoogleTexto
        case (.apple, _): return TokensColor.proveedorAppleTexto
        }
    }

    /// Google lleva borde en los dos modos; el negro de Apple sobre fondo claro, no.
    func borde(_ esquema: ColorScheme) -> Color? {
        switch (self, esquema) {
        case (.google, .dark): return TokensColor.proveedorGoogleBordeOscuro
        case (.apple, .dark): return TokensColor.proveedorAppleBordeOscuro
        case (.google, _): return TokensColor.proveedorGoogleBorde
        case (.apple, _): return nil
        }
    }
}

/// El botón de un proveedor, con su marca y no con la nuestra.
public struct BotonProveedor: View {
    private let proveedor: Proveedor
    private let titulo: String
    private let cargando: Bool
    private let accion: () -> Void
    @Environment(\.colorScheme) private var esquema
    /// El ancho del contenido (logo + texto) más ancho del grupo: lo pone
    /// `GrupoDeProveedores`. Con él, los dos textos arrancan en el mismo pixel.
    @Environment(\.anchoDeContenidoDeProveedor) private var anchoComun

    public init(_ proveedor: Proveedor, titulo: String, cargando: Bool = false, accion: @escaping () -> Void) {
        self.proveedor = proveedor
        self.titulo = titulo
        self.cargando = cargando
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e10) {
                // El logo y el texto van centrados JUNTOS, como en la referencia;
                // mientras se espera al proveedor, la ruedita ocupa el lugar del logo
                // para que el texto no se mueva.
                ZStack {
                    logo.opacity(cargando ? 0 : 1)
                    if cargando {
                        ProgressView().tint(proveedor.texto(esquema))
                    }
                }
                .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e20)
                Text(titulo)
                    .estilo(.botonPrimario, color: proveedor.texto(esquema))
                    .lineLimit(1)
            }
            // Se mide el ancho natural (logo + texto) y se publica; el grupo se
            // queda con el mayor y todos los botones usan ESE ancho, alineado a la
            // izquierda: el bloque sigue centrado y los textos empiezan parejos.
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: AnchoDeContenidoDeProveedorKey.self, value: geo.size.width)
                }
            )
            .frame(width: anchoComun > 0 ? anchoComun : nil, alignment: .leading)
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.botonPrimario)
            .background(proveedor.fondo(esquema))
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
                    .strokeBorder(proveedor.borde(esquema) ?? .clear, lineWidth: TokensEspaciado.e1)
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
                .resizable()
                .scaledToFit()
                // Mismo alto que la "G" de Google (los 20 pt de la caja): como
                // símbolo de texto quedaba más chico.
                .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e20)
                .foregroundStyle(proveedor.texto(esquema))
                .offset(y: -1)
        case .google:
            if Self.hayLogoDeGoogle {
                Image("GoogleIcon", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e20)
            } else {
                Text(verbatim: "G")
                    .estilo(.opcionTitulo, color: proveedor.texto(esquema))
            }
        }
    }

    /// Si la app trae el logo oficial. Se mira una vez: no cambia mientras corre.
    private static let hayLogoDeGoogle: Bool = {
        #if canImport(UIKit)
        return UIImage(named: "GoogleIcon", in: .main, with: nil) != nil
        #else
        return false
        #endif
    }()
}

// MARK: - Los botones en grupo, con los textos alineados

struct AnchoDeContenidoDeProveedorKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct AnchoDeContenidoDeProveedorEntorno: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var anchoDeContenidoDeProveedor: CGFloat {
        get { self[AnchoDeContenidoDeProveedorEntorno.self] }
        set { self[AnchoDeContenidoDeProveedorEntorno.self] = newValue }
    }
}

/// Apila los botones de Google y Apple de modo que el logo y el texto de todos
/// arranquen en el MISMO pixel (2026-10-21, pedido de Iván): cada uno mide su
/// contenido, el grupo se queda con el más ancho y se lo da a todos.
public struct GrupoDeProveedores<Contenido: View>: View {
    private let contenido: Contenido
    @State private var ancho: CGFloat = 0

    public init(@ViewBuilder contenido: () -> Contenido) {
        self.contenido = contenido()
    }

    public var body: some View {
        VStack(spacing: TokensEspaciado.e10) {
            contenido
        }
        .environment(\.anchoDeContenidoDeProveedor, ancho)
        .onPreferenceChange(AnchoDeContenidoDeProveedorKey.self) { nuevo in
            if abs(nuevo - ancho) > 0.5 { ancho = nuevo }
        }
    }
}
