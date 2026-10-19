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
//
// EL ACENTO SIGUE AL TELÉFONO, EN VIVO. El iPhone manda su color elegido por
// WatchConnectivity (`AparienciaCompartida`, ver `SincronizadorDeSesion`); el
// reloj lo guarda en su propio UserDefaults bajo `AcentoPersonalizado.clave` y lo
// anuncia en `AparienciaDelReloj.compartida`, que la raíz del reloj escucha para
// redibujar. Del MODO (día/noche/automático) sólo se guarda el valor: watchOS es
// siempre oscuro y el fondo negro puro es un requisito de batería, así que en la
// muñeca no se aplica.
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

    /// El acento. Es el que eligió la persona en el teléfono (Ajustes →
    /// Apariencia), que llega por `SincronizadorDeSesion` y queda guardado en
    /// `AcentoPersonalizado.clave` de ESTE dispositivo; sin elección, el del
    /// catálogo de assets del reloj (decisión 0007 §12.1).
    ///
    /// 🪤 Es `var` calculada y no `let`: un `let` estático se evalúa una sola vez
    /// y el color nuevo no llegaría nunca. watchOS no garantiza el `UIColor`
    /// dinámico que usa `Paleta.acento` en el teléfono, así que se lee lo guardado
    /// en cada dibujo (UserDefaults lo tiene en memoria) y el redibujo lo fuerza
    /// `AparienciaDelReloj`.
    public static var acento: Color {
        guard let c = AcentoPersonalizado.componentesActuales else { return acentoDeFabrica }
        return Color(.sRGB, red: c.0, green: c.1, blue: c.2, opacity: 1)
    }

    private static let acentoDeFabrica: Color =
        acentoDelCatalogo ?? Color(red: 1.0, green: 35.0 / 255.0, blue: 167.0 / 255.0)

    private static var acentoDelCatalogo: Color? {
        #if canImport(UIKit)
        guard let color = UIColor(named: TokensAcento.nombreEnAssets) else { return nil }
        return Color(color)
        #else
        return nil
        #endif
    }

    /// El texto encima del acento: casi-negro o blanco, el que más contraste dé
    /// (WCAG) contra el color elegido. Igual que `Paleta.sobreAcento`.
    public static var sobreAcento: Color {
        guard let c = AcentoPersonalizado.componentesActuales else { return TokensColor.marcaSobreAcento }
        return AcentoPersonalizado.textoOscuroEncima(c.0, c.1, c.2) ? TokensColor.marcaSobreAcento : Color.white
    }

    public static var acentoSuave: Color { acento.opacity(TokensAcento.alfaChipActivo) }

    // ---- secundario (Pantone 802 C verde lima) ----
    public static var secundario: Color { acento }
    public static var secundarioSuaveFondo: Color { acento.opacity(TokensAcento.alfaChipActivo) }
    public static var secundarioSuaveBorde: Color { acento.opacity(0.35) }

    // ---- bordes y estado ----

    public static let bordeSuperficie = TokensColor.relojBordeSuperficie
    public static let error = TokensColor.estadoError
    public static let errorFondo = TokensColor.estadoErrorFondo

    // ---- series de datos ----
    // Tres colores propios del reloj, para distinguir métricas de un vistazo.

    public static let dato1 = TokensColor.datosSerie1
    public static var dato2: Color { acento }
    public static var dato3: Color { acento }

    // Acción de vuelta en los controles (verde lima)
    public static var vuelta: Color { acento }
    public static var vueltaFondo: Color { acento.opacity(0.18) }

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

// MARK: - Lo que llega del teléfono

/// La apariencia que el teléfono le mandó al reloj, publicada para que la raíz
/// del reloj se redibuje en cuanto cambia el color.
///
/// La fuente de verdad es el UserDefaults del dispositivo (la misma clave que el
/// teléfono, `AcentoPersonalizado.clave`), así `PaletaReloj.acento` se resuelve
/// sin pasar por este objeto y el último color sobrevive al reinicio del reloj.
/// Esto sólo avisa del cambio.
public final class AparienciaDelReloj: ObservableObject {
    public static let compartida = AparienciaDelReloj()

    /// "r,g,b" (0–255) o vacío = el color del catálogo.
    @Published public private(set) var acentoGuardado: String
    /// `ModoApariencia.rawValue` del teléfono. Se guarda para el futuro; el reloj
    /// no lo aplica (watchOS es siempre oscuro).
    @Published public private(set) var modoGuardado: String

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.acentoGuardado = defaults.string(forKey: AcentoPersonalizado.clave) ?? ""
        self.modoGuardado = defaults.string(forKey: ModoApariencia.clave) ?? ""
    }

    /// Guarda y publica. Primero se escribe UserDefaults y después se publica, así
    /// el redibujo que dispara `@Published` ya lee el color nuevo.
    @MainActor
    public func aplicar(_ apariencia: AparienciaCompartida) {
        if apariencia.acento != acentoGuardado {
            defaults.set(apariencia.acento, forKey: AcentoPersonalizado.clave)
            acentoGuardado = apariencia.acento
        }
        if apariencia.modo != modoGuardado {
            defaults.set(apariencia.modo, forKey: ModoApariencia.clave)
            modoGuardado = apariencia.modo
        }
    }
}
