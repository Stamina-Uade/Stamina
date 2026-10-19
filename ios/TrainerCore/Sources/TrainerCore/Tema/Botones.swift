import SwiftUI

// =============================================================================
// Los tres botones del flujo de entrada.
//
// 🪤 EL ESTADO DESHABILITADO — el acento, apagado, y el texto al revés.
//
// El botón apagado es **el color de la app, bajo** (`Paleta.acentoApagado`, el
// acento al 35 %): se lee como el mismo botón, sin encender. Eso es lo que pidió
// Iván y es lo que hace el diseño.
//
// Lo que NO se copia del diseño es el texto. El diseño baja el botón entero con
// `opacity: .35`, así que el texto oscuro queda sobre verde oscuro: **2.51:1**,
// que no llega ni a AA grande (`design/ESPECIFICACION.md` §9.1, y §9.3 lo marca
// como defecto). Acá el relleno se apaga y el texto **se da vuelta a claro**:
// #F2F4F0 sobre el acento al 35 % da **7.06:1**. Se ve apagado, y se lee.
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
    private let accion: () -> Void

    /// - Parameter motivoDeshabilitado: por qué no se puede tocar. Es
    ///   obligatorio para VoiceOver: un botón apagado sin explicación es un
    ///   callejón sin salida para quien no ve el mensaje de validación.
    public init(
        _ titulo: String,
        habilitado: Bool = true,
        cargando: Bool = false,
        motivoDeshabilitado: String? = nil,
        accion: @escaping () -> Void
    ) {
        self.titulo = titulo
        self.habilitado = habilitado
        self.cargando = cargando
        self.motivoDeshabilitado = motivoDeshabilitado
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            ZStack {
                if cargando {
                    ProgressView()
                        .tint(habilitado ? Paleta.sobreAcento : Paleta.textoTerciario)
                } else {
                    Text(titulo)
                        .estilo(.botonPrimario, color: habilitado ? Paleta.sobreAcento : Paleta.textoTerciario)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.botonPrimario)
            .background(habilitado ? Paleta.acento : Paleta.superficieInput)
            // Rediseño 2026-10: la acción principal es una cápsula, como el mockup.
            .clipShape(Capsule())
            .opacity(habilitado ? 1.0 : 0.5)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .disabled(!habilitado || cargando)
        .accessibilityHint(habilitado ? "" : (motivoDeshabilitado ?? ""))
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
    private let accion: () -> Void

    public init(_ titulo: String, color: Color = Paleta.textoAcento, accion: @escaping () -> Void) {
        self.titulo = titulo
        self.color = color
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            Text(titulo)
                .estilo(.tituloCard, color: color)
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
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: TokensMovimiento.rapida), value: configuration.isPressed)
    }
}
