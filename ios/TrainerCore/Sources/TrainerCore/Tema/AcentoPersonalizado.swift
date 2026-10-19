import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// =============================================================================
// El color de la app, elegido por la persona (Ajustes → Apariencia).
//
// Cómo funciona: `Paleta.acento` es un color DINÁMICO de UIKit que se resuelve
// cada vez que se dibuja, leyendo la elección guardada acá. Todo lo que deriva
// del acento (`acentoChipActivo`, `acentoBrillo`, la barra, los botones) es
// `acento.opacity(…)`, así que también cambia. Para que se redibuje al toque,
// la raíz de la app escucha `AcentoPersonalizado.clave` con `@AppStorage` y
// re-crea su contenido (ver `RaizHomeView` / `RaizFlujoView`).
//
// El texto ENCIMA del acento tampoco se elige: `Paleta.sobreAcento` mide el
// contraste (WCAG) del color elegido contra casi-negro y contra blanco y se
// queda con el que más se lee. Con un azul oscuro el texto pasa a blanco solo.
//
// 🛑 Es sólo del teléfono. El reloj sigue con su acento del catálogo (pedido de
// Ivan: el reloj no se toca) y Android con `colors.xml`.
// =============================================================================

/// Un color de la paleta de elección.
public struct OpcionDeAcento: Identifiable, Equatable, Sendable {
    public let id: String
    public let nombre: String
    public let rojo: Double
    public let verde: Double
    public let azul: Double

    public init(id: String, nombre: String, rojo: Double, verde: Double, azul: Double) {
        self.id = id
        self.nombre = nombre
        self.rojo = rojo
        self.verde = verde
        self.azul = azul
    }

    public var color: Color { Color(.sRGB, red: rojo, green: verde, blue: azul, opacity: 1) }

    /// "255,35,167": así se guarda en UserDefaults, sin hex (el guardián de
    /// tokens no quiere hex en `.swift`, y tampoco hace falta).
    public var guardado: String {
        "\(Int((rojo * 255).rounded())),\(Int((verde * 255).rounded())),\(Int((azul * 255).rounded()))"
    }
}

public enum AcentoPersonalizado {
    /// La clave de `@AppStorage`. Vacía = el color de Stamina (rosa).
    public static let clave = "ajuste_color_acento"

    /// Los colores de la paleta. Elegidos para que se lean sobre negro (≥ 3:1)
    /// y para que no se confundan con el rojo de error.
    public static let opciones: [OpcionDeAcento] = [
        OpcionDeAcento(id: "rosa", nombre: "Rosa Stamina", rojo: 1.0, verde: 0.137, azul: 0.655),
        OpcionDeAcento(id: "fucsia", nombre: "Fucsia", rojo: 0.851, verde: 0.275, azul: 0.937),
        OpcionDeAcento(id: "violeta", nombre: "Violeta", rojo: 0.545, verde: 0.361, azul: 0.965),
        OpcionDeAcento(id: "azul", nombre: "Azul", rojo: 0.231, verde: 0.510, azul: 0.965),
        OpcionDeAcento(id: "cian", nombre: "Cian", rojo: 0.133, verde: 0.827, azul: 0.933),
        OpcionDeAcento(id: "menta", nombre: "Menta", rojo: 0.204, verde: 0.827, azul: 0.600),
        OpcionDeAcento(id: "lima", nombre: "Verde lima", rojo: 0.518, verde: 0.800, azul: 0.086),
        OpcionDeAcento(id: "amarillo", nombre: "Amarillo", rojo: 0.980, verde: 0.800, azul: 0.082),
        OpcionDeAcento(id: "naranja", nombre: "Naranja", rojo: 0.976, verde: 0.451, azul: 0.086),
        OpcionDeAcento(id: "coral", nombre: "Coral", rojo: 1.0, verde: 0.420, azul: 0.420),
    ]

    public static var predeterminado: OpcionDeAcento { opciones[0] }

    /// La opción de la paleta que coincide con lo guardado, si hay una.
    public static func opcion(paraGuardado guardado: String) -> OpcionDeAcento? {
        opciones.first { $0.guardado == guardado }
    }

    /// Lee "r,g,b" (0–255). `nil` si está vacío o mal escrito.
    public static func componentes(de guardado: String) -> (Double, Double, Double)? {
        let partes = guardado.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard partes.count == 3, partes.allSatisfy({ (0...255).contains($0) }) else { return nil }
        return (Double(partes[0]) / 255, Double(partes[1]) / 255, Double(partes[2]) / 255)
    }

    /// Lo elegido ahora, o `nil` si es el color de fábrica.
    public static var componentesActuales: (Double, Double, Double)? {
        guard let guardado = UserDefaults.standard.string(forKey: clave), !guardado.isEmpty else { return nil }
        return componentes(de: guardado)
    }

    /// Guarda un color cualquiera (el selector libre de Ajustes).
    public static func guardado(de color: Color) -> String? {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let limitar = { (x: CGFloat) -> Int in Int((min(1, max(0, x)) * 255).rounded()) }
        return "\(limitar(r)),\(limitar(g)),\(limitar(b))"
        #else
        return nil
        #endif
    }

    // MARK: - Contraste (WCAG 2.x)

    /// Luminancia relativa de un sRGB 0–1.
    public static func luminancia(_ r: Double, _ g: Double, _ b: Double) -> Double {
        func lineal(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lineal(r) + 0.7152 * lineal(g) + 0.0722 * lineal(b)
    }

    public static func contraste(_ l1: Double, _ l2: Double) -> Double {
        (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// `true` si sobre ese color se lee mejor el texto oscuro que el blanco.
    public static func textoOscuroEncima(_ r: Double, _ g: Double, _ b: Double) -> Bool {
        let l = luminancia(r, g, b)
        let casiNegro = luminancia(0.0431, 0.0471, 0.0392)
        return contraste(l, casiNegro) >= contraste(l, 1.0)
    }

    /// Contraste del color contra el fondo negro de la app. Ajustes avisa si da
    /// menos de 3:1 (WCAG 1.4.11: lo que no es texto necesita 3:1).
    public static func contrasteSobreNegro(_ r: Double, _ g: Double, _ b: Double) -> Double {
        contraste(luminancia(r, g, b), 0)
    }
}

// MARK: - Ayudas para Ajustes (puras: no leen ni escriben UserDefaults)

extension AcentoPersonalizado {
    /// `true` si lo guardado es el color de fábrica: vacío, o escrito igual que
    /// la primera opción.
    public static func esPredeterminado(_ guardado: String) -> Bool {
        guardado.isEmpty || guardado == predeterminado.guardado
    }

    /// Lo que se guarda al elegir una opción: vacío para la de fábrica, así
    /// sigue mandando el color del catálogo de Xcode.
    public static func valorAGuardar(para opcion: OpcionDeAcento) -> String {
        opcion == predeterminado ? "" : opcion.guardado
    }

    /// `true` si lo guardado es un color libre (del selector), no de la paleta.
    public static func esLibre(_ guardado: String) -> Bool {
        !esPredeterminado(guardado) && opcion(paraGuardado: guardado) == nil && componentes(de: guardado) != nil
    }

    /// Los componentes de lo guardado o, si está vacío o mal escrito, los del
    /// color de fábrica.
    public static func componentesOPredeterminado(de guardado: String) -> (Double, Double, Double) {
        componentes(de: guardado) ?? (predeterminado.rojo, predeterminado.verde, predeterminado.azul)
    }

    /// El color FIJO de lo guardado (no el dinámico de `Paleta.acento`): para
    /// mostrar un candidato antes de aplicarlo.
    public static func color(paraGuardado guardado: String) -> Color {
        let c = componentesOPredeterminado(de: guardado)
        return Color(.sRGB, red: c.0, green: c.1, blue: c.2, opacity: 1)
    }
}
