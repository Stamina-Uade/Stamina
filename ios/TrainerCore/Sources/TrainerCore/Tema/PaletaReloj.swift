import SwiftUI
#if os(watchOS)
import WatchKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// =============================================================================
// La paleta del RELOJ.
//
// No es la del teléfono con otro nombre: son tokens distintos, extraídos de
// `Trainer Watch.dc.html`, y la diferencia tiene un motivo físico.
//
// - El fondo es **negro puro**, no el `#0B0C0A` del teléfono: en una pantalla
//   OLED el píxel apagado no consume, y AGENTS.md §10.2 dice que **la batería es
//   un requisito funcional**.
// - La superficie del reloj es `#15170F`, distinta del `#131511` del teléfono.
//   Son 27 usos en el diseño del reloj; no es un descuido del diseñador.
//
// 🪤 PENDIENTE ABIERTO — el objetivo táctil del reloj.
// `tokens.json` → `pendientes[objetivo-tactil-reloj]`: AGENTS.md §10.1 dice
// "48dp / 44pt" sin separar plataformas, y el diseño del reloj usa 44. Acá se usa
// **44**, que es el mínimo de Apple para watchOS, y queda anotado que la regla
// para el reloj todavía no está fijada.
// =============================================================================

public enum PaletaReloj {

    /// El archivo de diseño usa el tamaño físico del panel en píxeles. SwiftUI
    /// trabaja en puntos; en watchOS la escala del dispositivo hace esa
    /// conversión. Los objetivos táctiles siguen expresados directamente en
    /// puntos y no pasan por esta función.
    public static func puntosDeDiseno(_ pixeles: CGFloat) -> CGFloat {
        #if os(watchOS)
        return pixeles / WKInterfaceDevice.current().screenScale
        #else
        return pixeles
        #endif
    }

    // ---- fondo y superficies ----

    /// Negro puro: el píxel apagado no consume (AGENTS.md §10.2).
    public static let fondo = TokensColor.relojFondo
    public static let superficie = TokensColor.relojSuperficie
    public static let superficieAlterna = TokensColor.relojSuperficieAlterna
    public static let superficieOverlay = TokensColor.relojSuperficieOverlay

    // ---- texto ----

    public static let textoPrimario = TokensColor.relojTextoPrimario
    public static let textoSecundario = TokensColor.relojTextoSecundario

    // ---- marca ----

    /// El acento, del catálogo de assets del reloj para que la perilla de color
    /// funcione también en la muñeca (decisión 0007 §12.1).
    public static let acento: Color = acentoDelCatalogo ?? TokensAcento.respaldo

    private static var acentoDelCatalogo: Color? {
        #if canImport(UIKit)
        guard let color = UIColor(named: TokensAcento.nombreEnAssets) else { return nil }
        return Color(color)
        #else
        return nil
        #endif
    }

    public static let sobreAcento = TokensColor.marcaSobreAcento
    public static let acentoSuave = acento.opacity(TokensAcento.alfaChipActivo)

    // ---- secundario (Pantone 802 C verde lima) ----
    public static let secundario = acento
    public static let secundarioSuaveFondo = acento.opacity(TokensAcento.alfaChipActivo)
    public static let secundarioSuaveBorde = acento.opacity(0.35)

    // ---- bordes y estado ----

    public static let bordeSuperficie = TokensColor.relojBordeSuperficie
    public static let error = TokensColor.estadoError
    public static let errorFondo = TokensColor.estadoErrorFondo

    // ---- series de datos ----
    // Tres colores propios del reloj, para distinguir métricas de un vistazo.

    public static let dato1 = TokensColor.datosSerie1
    public static let dato2 = acento
    public static let dato3 = acento

    // Acción de vuelta en los controles (verde lima)
    public static let vuelta = acento
    public static let vueltaFondo = acento.opacity(0.18)

    // Controles de sesión (Pausa y Reanudar en naranja atlético)
    public static let controlPausa = Color(red: 1.0, green: 0.584, blue: 0.0)
    public static let controlReanudar = Color(red: 1.0, green: 0.584, blue: 0.0)
    public static let sobreControlPausa = Color.white

    // ---- medidas ----

    /// 44 pt, el mínimo de Apple para watchOS. Ver el pendiente del encabezado.
    public static let objetivoTactilMinimo: CGFloat = 44
}

extension View {
    /// El objetivo táctil del reloj. Igual que en el teléfono, **va adentro del
    /// `label:` del botón**: afuera agranda el layout y no el área sensible.
    public func objetivoTactilReloj() -> some View {
        frame(minWidth: PaletaReloj.objetivoTactilMinimo,
              minHeight: PaletaReloj.objetivoTactilMinimo)
            .contentShape(Rectangle())
    }
}
