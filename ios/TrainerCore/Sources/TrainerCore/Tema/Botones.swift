import SwiftUI

// =============================================================================
// Los tres botones del flujo de entrada.
//
// 🪤 EL ESTADO DESHABILITADO (2026-10-21, pedido de Iván).
//
// Apagado es **el mismo botón, con su color, a menos opacidad** (0,45, la pone
// `EstiloPresionado` para TODOS los botones de la app): ni gris ni invisible. Se
// lee como el botón que va a ser, todavía sin poder tocarse. VoiceOver dice por
// qué con `motivoDeshabilitado`.
//
// `pendientes[estados-de-control]` de `tokens.json` dice que el diseño sólo
// define "deshabilitado": no hay pressed ni foco. El estado presionado de acá
// (una bajada de opacidad corta) es la propuesta mínima para llenar ese hueco.
// =============================================================================

/// El botón que cierra cada paso. Ancho completo, siempre abajo.
public struct BotonPrimario: View {
    private let titulo: String
    private let habilitado: Bool
    private let cargando: Bool
    private let motivoDeshabilitado: String?
    private let grande: Bool
    private let accion: () -> Void

    /// - Parameter motivoDeshabilitado: por qué no se puede tocar. Es
    ///   obligatorio para VoiceOver: un botón apagado sin explicación es un
    ///   callejón sin salida para quien no ve el mensaje de validación.
    /// - Parameter grande: texto más grande (`botonGrande`), para la bienvenida.
    public init(
        _ titulo: String,
        habilitado: Bool = true,
        cargando: Bool = false,
        motivoDeshabilitado: String? = nil,
        grande: Bool = false,
        accion: @escaping () -> Void
    ) {
        self.grande = grande
        self.titulo = titulo
        self.habilitado = habilitado
        self.cargando = cargando
        self.motivoDeshabilitado = motivoDeshabilitado
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            ZStack {
                // 2026-10-22 (Iván): el texto del botón rosa es BLANCO, con el
                // color que sea. Apagado, el blanco también baja de opacidad
                // junto con el rosa (lo hace `EstiloPresionado`): nunca gris.
                // Esperando al servidor, sólo la ruedita, sin texto.
                if cargando {
                    ProgressView()
                        .tint(Color.white)
                } else {
                    Text(titulo)
                        .estilo(grande ? .botonGrande : .botonPrimario, color: Color.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.botonPrimario)
            // 2026-10-21 (Iván): apagado NO es gris: es el MISMO botón, rosa, con
            // menos opacidad (la pone `EstiloPresionado` para todos los botones),
            // así se entiende que es el mismo y que todavía no se puede tocar.
            .background(Paleta.acento)
            // Rediseño 2026-10: la acción principal es una cápsula, como el mockup.
            .clipShape(Capsule())
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .disabled(!habilitado || cargando)
        .accessibilityHint(habilitado ? "" : (motivoDeshabilitado ?? ""))
        // La ruedita sola no dice nada a VoiceOver: el botón conserva su nombre.
        .accessibilityLabel(titulo)
    }
}

/// Botón de borde, para las alternativas de igual peso (Google, Apple).
public struct BotonSecundario<Contenido: View>: View {
    private let accion: () -> Void
    private let contenido: Contenido

    public init(accion: @escaping () -> Void, @ViewBuilder contenido: () -> Contenido) {
        self.accion = accion
        self.contenido = contenido()
    }

    public var body: some View {
        Button(action: accion) {
            contenido
                .frame(maxWidth: .infinity)
                .frame(minHeight: TokensTamano.botonPrimario)
                .overlay(
                    Capsule()
                        .strokeBorder(Paleta.bordeBotonSecundario, lineWidth: TokensEspaciado.e1)
                )
                .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
    }
}

/// Enlace de texto: "Ya tengo cuenta", "Volver al inicio de sesión", "Ahora no".
public struct BotonTexto: View {
    private let titulo: String
    private let color: Color
    private let grande: Bool
    private let accion: () -> Void

    public init(_ titulo: String, color: Color = Paleta.textoAcento, grande: Bool = false,
                accion: @escaping () -> Void) {
        self.grande = grande
        self.titulo = titulo
        self.color = color
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            Text(titulo)
                .estilo(grande ? .botonGrande : .tituloCard, color: color)
                .frame(maxWidth: .infinity)
                .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
    }
}

/// Feedback de presionado. Llena `pendientes[estados-de-control]` con lo mínimo:
/// el diseño no define ninguno y un botón que no responde se siente roto.
public struct EstiloPresionado: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CuerpoPresionado(configuration: configuration)
    }

    /// Un `View` aparte para poder leer `isEnabled`: el `ButtonStyle` no lo ve.
    private struct CuerpoPresionado: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var habilitado

        var body: some View {
            configuration.label
                // Apagado: el mismo color, con menos opacidad (nunca 0, nunca gris).
                .opacity(habilitado ? (configuration.isPressed ? 0.72 : 1) : Self.opacidadApagado)
                .animation(.easeOut(duration: TokensMovimiento.rapida), value: configuration.isPressed)
                .animation(.easeOut(duration: TokensMovimiento.rapida), value: habilitado)
        }

        static let opacidadApagado: Double = 0.45
    }
}
