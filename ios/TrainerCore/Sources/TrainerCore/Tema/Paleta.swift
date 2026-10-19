import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// =============================================================================
// La paleta del TELÉFONO, por rol.
//
// `TokensColor` trae los 40 colores del producto entero, con prefijo de
// plataforma (`telefono…`, `reloj…`). Esto es la vista del teléfono: nombres
// cortos para que una pantalla se lea, y un solo lugar donde arreglar un rol.
//
// 🛑 Tres roles NO apuntan al token que usa el diseño, y cada uno dice por qué.
// No son licencias creativas: son fallas de contraste MEDIDAS en
// `design/ESPECIFICACION.md` §9.1, y §10.1 pide accesibilidad desde el primer
// componente, no retrofiteada. Están en el registro de divergencias de §10.4.
// =============================================================================

public enum Paleta {

    /// Resuelve un color adaptativo para modo día (claro) y modo noche (oscuro).
    public static func dinamico(claro: Color, oscuro: Color) -> Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(oscuro) : UIColor(claro)
        })
        #else
        return oscuro
        #endif
    }

    // ---- fondo y superficies ----

    public static let fondo = dinamico(claro: Color.white, oscuro: TokensColor.telefonoFondo)
    public static let superficie = dinamico(claro: Color(red: 0.96, green: 0.96, blue: 0.97), oscuro: TokensColor.telefonoSuperficie)
    public static let superficieAlterna = dinamico(claro: Color(red: 0.91, green: 0.92, blue: 0.94), oscuro: TokensColor.telefonoSuperficieAlterna)
    public static let superficieInput = dinamico(claro: Color.white, oscuro: TokensColor.telefonoSuperficieInput)
    /// Relleno de un control apoyado sobre una card, y del botón deshabilitado.
    public static let superficieHundida = dinamico(claro: Color(red: 0.92, green: 0.93, blue: 0.95), oscuro: TokensColor.telefonoSuperficieHundida)
    public static let superficieControl = dinamico(claro: Color(red: 0.88, green: 0.89, blue: 0.91), oscuro: TokensColor.telefonoSuperficieControl)
    /// Hoja inferior y tarjetas apoyadas sobre el mapa: superficie al 94 %.
    public static let superficieOverlay = dinamico(claro: Color.white.opacity(0.96), oscuro: TokensColor.telefonoSuperficieOverlay)
    /// El fondo oscurecido de un control circular sobre el mapa.
    public static let superficieOverlayFondo = dinamico(claro: Color(red: 0.92, green: 0.93, blue: 0.95, opacity: 0.92), oscuro: TokensColor.telefonoVelo)
    /// Extremo claro del degradado de la card de sesión.
    public static let superficieDestacada = dinamico(claro: Color(red: 0.88, green: 0.90, blue: 0.93), oscuro: TokensColor.telefonoSuperficieDestacada)
    public static let superficieBarra = dinamico(claro: Color.white, oscuro: TokensColor.telefonoSuperficieBarra)

    // ---- texto ----

    public static let textoPrimario = dinamico(claro: Color(red: 0.08, green: 0.08, blue: 0.08), oscuro: TokensColor.telefonoTextoPrimario)
    public static let textoCuerpo = dinamico(claro: Color(red: 0.15, green: 0.15, blue: 0.16), oscuro: TokensColor.telefonoTextoCuerpo)
    public static let textoSecundario = dinamico(claro: Color(red: 0.38, green: 0.40, blue: 0.44), oscuro: TokensColor.telefonoTextoSecundario)
    public static let textoTerciario = dinamico(claro: Color(red: 0.52, green: 0.55, blue: 0.60), oscuro: TokensColor.telefonoTextoTerciario)

    /// ⚠️ DIVERGENCIA 1 — el placeholder del diseño es blanco al 32 %, que sobre
    /// el input da **2.74:1** y no llega ni a AA grande (ESPECIFICACION §9.1).
    /// Se sirve con el terciario (.5), que mide **4.89:1** y cumple AA. Es
    /// exactamente lo que ya hizo el diseño nuevo del gimnasio (fase 2B).
    public static let textoPlaceholder = dinamico(claro: Color(red: 0.58, green: 0.61, blue: 0.66), oscuro: TokensColor.telefonoTextoTerciario)

    /// ⚠️ DIVERGENCIA 2 — el texto deshabilitado del diseño (blanco al 34 %) da
    /// **2.87:1**. Un control apagado igual tiene que ser legible: si no, no se
    /// puede saber qué dice el botón que no anda. Se sirve con el secundario
    /// (.6), **6.54:1** sobre superficie.
    public static let textoDeshabilitado = dinamico(claro: Color(red: 0.64, green: 0.67, blue: 0.72), oscuro: TokensColor.telefonoTextoSecundario)

    // ---- marca: la única perilla de color de la app ----

    /// El acento. **Se cambia desde Xcode**, en
    /// `Trainer/Assets.xcassets/Acento.colorset`, con el selector de color.
    ///
    /// Todo lo que lleva acento en el producto —botón primario, links, borde en
    /// foco, chip elegido, botón apagado— se deriva de acá, así que tocar ese
    /// único color cambia la app entera. Es la regla que `ESPECIFICACION.md` §3
    /// pide: *"es UN token; cambiarlo tiene que cambiar el producto entero desde
    /// un solo lugar"*.
    ///
    /// 🔁 **Si lo cambiás en Xcode, corré `npm run acento:desde-xcode`.** Eso
    /// copia el valor a `shared/design/tokens.json` y regenera el tema, para que
    /// Android quede del mismo color (AGENTS.md §4.2: `shared/` es la fuente de
    /// verdad de los cuatro clientes). Sin ese paso, iOS y Android divergen.
    ///
    /// Si el catálogo no está disponible —previews del paquete, `swift test`
    /// fuera de la app— cae al valor generado desde `tokens.json`, que es el
    /// mismo número.
    public static let acento: Color = acentoDelCatalogo ?? Color(red: 1.0, green: 35.0 / 255.0, blue: 167.0 / 255.0)

    private static var acentoDelCatalogo: Color? {
        #if canImport(UIKit)
        guard let color = UIColor(named: TokensAcento.nombreEnAssets) else { return nil }
        return Color(color)
        #else
        return nil
        #endif
    }

    /// El texto sobre el acento. **No** se deriva: es el casi-negro del diseño y
    /// no cambia con el acento. Si algún día el acento pasa a ser oscuro, este
    /// rol hay que revisarlo — está anotado en la decisión 0007 §12.
    public static let sobreAcento = TokensColor.marcaSobreAcento

    public static let acentoSuaveFondo = acento.opacity(TokensAcento.alfaSuaveFondo)
    public static let acentoSuaveBorde = acento.opacity(TokensAcento.alfaSuaveBorde)
    public static let acentoChipActivo = acento.opacity(TokensAcento.alfaChipActivo)

    /// Relleno del botón primario deshabilitado: el color de la app, apagado.
    /// Ver la nota de `Botones.swift` sobre por qué el texto encima va claro.
    public static let acentoApagado = acento.opacity(TokensAcento.alfaApagado)

    // ---- secundario (Rosa Stamina #FF23A7) ----
    public static let secundario = acento
    public static let secundarioSuaveFondo = acento.opacity(TokensAcento.alfaChipActivo)
    public static let secundarioSuaveBorde = acento.opacity(TokensAcento.alfaSuaveBorde)

    // ---- barra de pestañas ----
    public static let fondoBarra = dinamico(claro: Color.white, oscuro: Color.black)
    public static let pestanaActiva = acento
    public static let pestanaInactiva = dinamico(claro: Color(red: 0.38, green: 0.40, blue: 0.44), oscuro: Color(red: 0.70, green: 0.72, blue: 0.75))

    // ---- acento semántico (#FF23A7) ----
    public static let textoAcento = acento
    public static let iconoAcento = acento
    public static let seleccionadoFondo = acento.opacity(0.15)
    public static let seleccionadoBorde = acento
    public static let bordeEnfocado = acento
    public static let interruptorActivo = acento
    public static let interruptorThumb = dinamico(claro: Color.white, oscuro: sobreAcento)

    // ---- bordes ----

    public static let bordeInput = dinamico(claro: Color.black.opacity(0.14), oscuro: TokensColor.telefonoBordeInput)
    public static let bordeSuperficie = dinamico(claro: Color.black.opacity(0.08), oscuro: TokensColor.telefonoBordeSuperficie)
    public static let bordeBotonSecundario = dinamico(claro: Color.black.opacity(0.12), oscuro: TokensColor.telefonoBordeBotonSecundario)
    public static let divisor = dinamico(claro: Color.black.opacity(0.08), oscuro: TokensColor.telefonoDivisor)
    /// El único borde que puede LLEVAR SIGNIFICADO: blanco al 38 %, **3.58:1**,
    /// por encima del 3.0 que pide WCAG 1.4.11. Los del 9–12 % son decorativos
    /// (1.16–1.44:1) y no pueden ser la única señal de un estado.
    public static let bordeSignificante = dinamico(claro: Color.black.opacity(0.35), oscuro: TokensColor.telefonoBordeSignificante)

    // ---- estado ----

    public static let error = TokensColor.estadoError
    public static let errorFondo = TokensColor.estadoErrorFondo
    public static let errorBorde = TokensColor.estadoErrorBorde

    /// ⚠️ DIVERGENCIA 3 — no hay color de éxito propio: `tokens.json` lo declara
    /// abierto en `pendientes[color-exito]` y el diseño usa el acento, que
    /// además significa "tocable". Mientras siga así, **el éxito nunca se
    /// comunica sólo con este color**: siempre lleva ícono o texto (§10.1).
    public static let exito = acento

    // ---- controles de sesión de entrenamiento ----
    /// Naranja atlético clásico (#FF9500 / systemOrange) para Pausa y Reanudar,
    /// preservando la visibilidad del botón de acción sin invadir la paleta de marca.
    public static let controlPausa = Color(red: 1.0, green: 0.584, blue: 0.0)
    public static let controlReanudar = Color(red: 1.0, green: 0.584, blue: 0.0)
    public static let sobreControlPausa = Color.white
}
