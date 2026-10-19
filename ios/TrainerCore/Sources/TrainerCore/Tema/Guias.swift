import SwiftUI
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

// =============================================================================
// Lo que quedó de las guías (rediseño 2026-10). En la ronda 5 Ivan pidió UI
// limpia, sin el "?" ni las tarjetas "qué hay acá": se borraron TarjetaDeGuia,
// PuntoDeGuia y BotonDeAyuda. Queda la respuesta táctil, que usa toda la app.
// =============================================================================

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
