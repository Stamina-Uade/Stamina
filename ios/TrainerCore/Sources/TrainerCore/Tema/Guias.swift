import SwiftUI
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

// =============================================================================
// Las piezas que explican la app mientras se usa (rediseño 2026-10, ronda 3).
//
// Pedido de Ivan: "entro y no entiendo qué hace cada cosa". Cada pestaña lleva
// una TarjetaDeGuia la primera vez —qué es esta pantalla y qué se puede tocar—
// que se cierra con la X y no vuelve. El "?" del encabezado la vuelve a mostrar.
// =============================================================================

/// Un punto de la guía: un ícono y una frase corta.
public struct PuntoDeGuia: Identifiable, Sendable {
    public let id: String
    public let simbolo: String
    public let texto: String

    public init(_ simbolo: String, _ texto: String) {
        self.id = simbolo + texto
        self.simbolo = simbolo
        self.texto = texto
    }
}

/// "Qué hay acá": título, hasta cuatro puntos y una X para no verla más.
///
/// - `clave`: dónde se guarda que ya se cerró (`@AppStorage`). Una por pestaña.
public struct TarjetaDeGuia: View {
    private let titulo: String
    private let puntos: [PuntoDeGuia]
    @AppStorage private var cerrada: Bool

    public init(clave: String, titulo: String, puntos: [PuntoDeGuia]) {
        self.titulo = titulo
        self.puntos = puntos
        self._cerrada = AppStorage(wrappedValue: false, clave)
    }

    public var body: some View {
        if !cerrada {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                HStack(alignment: .top, spacing: TokensEspaciado.e8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                    Text(titulo)
                        .estilo(.tituloCardGrande)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        Haptico.toque()
                        withAnimation(.easeOut(duration: TokensMovimiento.rapida)) { cerrada = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: TokensTipografia.notaTamano, weight: .bold))
                            .foregroundStyle(Paleta.textoSecundario)
                            .frame(width: TokensTamano.objetivoTactilMinimo, height: TokensTamano.objetivoTactilMinimo)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloPresionado())
                    .padding(.top, -TokensEspaciado.e14)
                    .padding(.trailing, -TokensEspaciado.e12)
                    .accessibilityLabel(String(localized: "Entendido, ocultar la guía", bundle: .main, comment: "Cierra la tarjeta de ayuda"))
                }
                ForEach(puntos) { punto in
                    HStack(alignment: .top, spacing: TokensEspaciado.e10) {
                        Image(systemName: punto.simbolo)
                            .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                            .foregroundStyle(Paleta.acento)
                            .frame(width: TokensEspaciado.e16)
                            .padding(.top, TokensEspaciado.e2)
                            .accessibilityHidden(true)
                        Text(punto.texto)
                            .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(TokensEspaciado.e14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.acentoSuaveFondo)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Para el botón "?": vuelve a mostrar la guía de esa clave.
    public static func mostrarDeNuevo(clave: String) {
        UserDefaults.standard.set(false, forKey: clave)
    }
}

/// El "?" chico de un encabezado: vuelve a mostrar la guía de la pantalla.
public struct BotonDeAyuda: View {
    private let clave: String
    @AppStorage private var cerrada: Bool

    public init(clave: String) {
        self.clave = clave
        self._cerrada = AppStorage(wrappedValue: false, clave)
    }

    public var body: some View {
        BotonCircular("questionmark", etiqueta: String(localized: "¿Qué hay en esta pantalla?", bundle: .main, comment: "Botón de ayuda")) {
            Haptico.toque()
            withAnimation(.easeOut(duration: TokensMovimiento.media)) { cerrada = false }
        }
    }
}

// MARK: - Vibraciones

/// Respuesta táctil. iOS 16 no tiene `sensoryFeedback` (es de iOS 17), así que
/// va por UIKit. En el reloj y en macOS no hace nada.
public enum Haptico {
    /// Un toque liviano: abrir, elegir, cerrar.
    public static func toque() {
        #if canImport(UIKit) && !os(watchOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Cambió una selección: un chip, un segmento, un día.
    public static func seleccion() {
        #if canImport(UIKit) && !os(watchOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// Algo salió bien: guardado, completado.
    public static func exito() {
        #if canImport(UIKit) && !os(watchOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
