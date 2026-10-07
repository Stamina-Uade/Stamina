import SwiftUI

// =============================================================================
// La tipografía del producto, como ROLES y no como tamaños.
//
// AGENTS.md §10.1: ningún tamaño ni peso se escribe a mano en una pantalla.
// Todo lo de acá sale de `TokensGenerados.swift`, que sale de
// `shared/design/tokens.json`. Una pantalla escribe `.estilo(.tituloPantalla)`,
// nunca un número.
//
// 🪤 DIVERGENCIA CONOCIDA — la familia tipográfica.
// El diseño usa **Archivo** (SIL OFL) y la baja de Google Fonts por red. El
// archivo de la fuente no está en el repositorio y `tokens.json` lo declara
// abierto en `pendientes[fuente-empaquetada]`. Hasta que se empaquete, esto usa
// la fuente del sistema: es la única opción honesta —una app offline-primero
// (AGENTS.md §6) no puede pedirle la tipografía a la red en la primera
// pantalla— y queda anotada en el registro de divergencias de §10.4.
// =============================================================================

/// Un rol tipográfico del diseño. Los valores salen de `TokensTipografia`.
public struct EstiloTipografico: Sendable {
    public let tamano: CGFloat
    public let peso: Font.Weight
    /// Multiplicador de interlineado del diseño (`line-height` de CSS).
    public let interlineado: CGFloat?
    /// `letter-spacing` en `em`, tal como lo declara el diseño.
    public let espaciadoLetrasEm: CGFloat?
    public let mayusculas: Bool
    /// `font-variant-numeric: tabular-nums`. Obligatorio en métricas, horas,
    /// peso, distancia y kcal (`tokens.json` → `tipografia.cifras_tabulares`).
    public let cifrasTabulares: Bool
    /// Contra qué estilo del sistema escala con Dynamic Type.
    public let referencia: Font.TextStyle

    public init(
        tamano: CGFloat,
        peso: Font.Weight,
        interlineado: CGFloat? = nil,
        espaciadoLetrasEm: CGFloat? = nil,
        mayusculas: Bool = false,
        cifrasTabulares: Bool = false,
        referencia: Font.TextStyle
    ) {
        self.tamano = tamano
        self.peso = peso
        self.interlineado = interlineado
        self.espaciadoLetrasEm = espaciadoLetrasEm
        self.mayusculas = mayusculas
        self.cifrasTabulares = cifrasTabulares
        self.referencia = referencia
    }
}

extension EstiloTipografico {
    /// El mismo rol, sin forzar mayúsculas.
    ///
    /// Hace falta como propiedad y no como `.textCase(nil)` en la pantalla:
    /// `textCase` es un valor de entorno y gana el más cercano al `Text`, que es
    /// el que aplica `.estilo()`. Ponerlo afuera no anula nada.
    public var enMinusculas: EstiloTipografico {
        EstiloTipografico(tamano: tamano, peso: peso, interlineado: interlineado,
                          espaciadoLetrasEm: espaciadoLetrasEm, mayusculas: false,
                          cifrasTabulares: cifrasTabulares, referencia: referencia)
    }

    public static let tituloBienvenida = EstiloTipografico(
        tamano: TokensTipografia.tituloBienvenidaTamano,
        peso: TokensTipografia.tituloBienvenidaPeso,
        interlineado: 1.1, espaciadoLetrasEm: -0.03, referencia: .largeTitle)

    public static let tituloConfirmacion = EstiloTipografico(
        tamano: TokensTipografia.tituloConfirmacionTamano,
        peso: TokensTipografia.tituloConfirmacionPeso,
        interlineado: 1.15, espaciadoLetrasEm: -0.03, referencia: .largeTitle)

    public static let tituloPantalla = EstiloTipografico(
        tamano: TokensTipografia.tituloPantallaTamano,
        peso: TokensTipografia.tituloPantallaPeso,
        interlineado: 1.2, espaciadoLetrasEm: -0.03, referencia: .title)

    public static let marca = EstiloTipografico(
        tamano: TokensTipografia.marcaTamano,
        peso: TokensTipografia.marcaPeso,
        espaciadoLetrasEm: -0.02, referencia: .title2)

    public static let numeroDato = EstiloTipografico(
        tamano: TokensTipografia.numeroDatoTamano,
        peso: TokensTipografia.numeroDatoPeso,
        interlineado: 1.0, espaciadoLetrasEm: -0.04,
        cifrasTabulares: true, referencia: .largeTitle)

    public static let numeroGrande = EstiloTipografico(
        tamano: TokensTipografia.numeroGrandeTamano,
        peso: TokensTipografia.numeroGrandePeso,
        interlineado: 1.0, espaciadoLetrasEm: -0.03,
        cifrasTabulares: true, referencia: .largeTitle)

    public static let codigo = EstiloTipografico(
        tamano: TokensTipografia.codigoTamano,
        peso: TokensTipografia.codigoPeso,
        espaciadoLetrasEm: 0.36, mayusculas: true,
        cifrasTabulares: true, referencia: .title)

    public static let campoNumero = EstiloTipografico(
        tamano: TokensTipografia.campoNumeroTamano,
        peso: TokensTipografia.campoNumeroPeso,
        cifrasTabulares: true, referencia: .title3)

    public static let tituloCardGrande = EstiloTipografico(
        tamano: TokensTipografia.tituloCardGrandeTamano,
        peso: TokensTipografia.tituloCardGrandePeso,
        espaciadoLetrasEm: -0.02, referencia: .headline)

    public static let campoTexto = EstiloTipografico(
        tamano: TokensTipografia.campoTextoTamano,
        peso: TokensTipografia.campoTextoPeso, referencia: .body)

    public static let botonPrimario = EstiloTipografico(
        tamano: TokensTipografia.botonPrimarioTamano,
        peso: TokensTipografia.botonPrimarioPeso, referencia: .body)

    public static let opcionTitulo = EstiloTipografico(
        tamano: TokensTipografia.opcionTituloTamano,
        peso: TokensTipografia.opcionTituloPeso, referencia: .body)

    public static let cuerpoDestacado = EstiloTipografico(
        tamano: TokensTipografia.cuerpoDestacadoTamano,
        peso: TokensTipografia.cuerpoDestacadoPeso,
        interlineado: 1.5, referencia: .callout)

    public static let cuerpo = EstiloTipografico(
        tamano: TokensTipografia.cuerpoTamano,
        peso: TokensTipografia.cuerpoPeso,
        interlineado: 1.55, referencia: .callout)

    public static let tituloCard = EstiloTipografico(
        tamano: TokensTipografia.tituloCardTamano,
        peso: TokensTipografia.tituloCardPeso, referencia: .callout)

    public static let cuerpoSecundario = EstiloTipografico(
        tamano: TokensTipografia.cuerpoSecundarioTamano,
        peso: TokensTipografia.cuerpoSecundarioPeso,
        interlineado: 1.5, referencia: .footnote)

    public static let labelCampo = EstiloTipografico(
        tamano: TokensTipografia.labelCampoTamano,
        peso: TokensTipografia.labelCampoPeso, referencia: .caption)

    public static let notaLegal = EstiloTipografico(
        tamano: TokensTipografia.notaLegalTamano,
        peso: TokensTipografia.notaLegalPeso,
        interlineado: 1.5, referencia: .caption)

    public static let etiquetaSeccion = EstiloTipografico(
        tamano: TokensTipografia.etiquetaSeccionTamano,
        peso: TokensTipografia.etiquetaSeccionPeso,
        espaciadoLetrasEm: 0.14, mayusculas: true, referencia: .caption2)
}

// -----------------------------------------------------------------------------

/// Aplica un rol tipográfico. El tamaño escala con Dynamic Type: una app de
/// gimnasio se lee con el brazo estirado y transpirado (AGENTS.md §10.1).
private struct EstiloTipograficoModifier: ViewModifier {
    let estilo: EstiloTipografico
    let color: Color
    @ScaledMetric private var tamano: CGFloat

    init(estilo: EstiloTipografico, color: Color) {
        self.estilo = estilo
        self.color = color
        _tamano = ScaledMetric(wrappedValue: estilo.tamano, relativeTo: estilo.referencia)
    }

    func body(content: Content) -> some View {
        content
            .font(fuente)
            .foregroundStyle(color)
            .tracking(tracking)
            .lineSpacing(lineSpacing)
            .textCase(estilo.mayusculas ? .uppercase : nil)
    }

    private var fuente: Font {
        let base = Font.system(size: tamano, weight: estilo.peso)
        return estilo.cifrasTabulares ? base.monospacedDigit() : base
    }

    /// El diseño declara el tracking en `em`; SwiftUI lo quiere en puntos.
    private var tracking: CGFloat {
        guard let em = estilo.espaciadoLetrasEm else { return 0 }
        return tamano * em
    }

    /// `line-height` de CSS es la altura TOTAL de la línea; `lineSpacing` de
    /// SwiftUI es el hueco EXTRA entre líneas. La conversión es la diferencia.
    private var lineSpacing: CGFloat {
        guard let mult = estilo.interlineado, mult > 1 else { return 0 }
        return tamano * (mult - 1)
    }
}

extension View {
    /// Aplica un rol tipográfico y su color. Es la única forma autorizada de
    /// darle tipografía a un texto en este producto.
    public func estilo(_ estilo: EstiloTipografico, color: Color = Paleta.textoPrimario) -> some View {
        modifier(EstiloTipograficoModifier(estilo: estilo, color: color))
    }
}
