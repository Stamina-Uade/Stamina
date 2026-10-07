import SwiftUI

/// Una fila que se va a la línea siguiente cuando no entra: los chips del plan
/// de avituallamiento, las etiquetas de un ejercicio, los filtros del catálogo.
///
/// Existe porque SwiftUI no trae nada equivalente en iOS 16 —`Grid` no envuelve
/// y `LazyVGrid` reparte en columnas fijas—, y porque los chips tienen ancho
/// variable: con columnas fijas, "20′ agua" y "600 mg de sodio" ocupan lo mismo
/// y quedan huecos enormes.
///
/// Escala con Dynamic Type sin tocar nada: al crecer el texto, entran menos por
/// línea y aparecen más líneas.
public struct FlujoHorizontal: Layout {
    private let espaciado: CGFloat
    private let espaciadoDeLinea: CGFloat

    public init(espaciado: CGFloat, espaciadoDeLinea: CGFloat? = nil) {
        self.espaciado = espaciado
        self.espaciadoDeLinea = espaciadoDeLinea ?? espaciado
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? .infinity
        let filas = repartir(subviews: subviews, anchoDisponible: ancho)
        let alto = filas.reduce(CGFloat.zero) { $0 + $1.alto } +
                   espaciadoDeLinea * CGFloat(max(0, filas.count - 1))
        let anchoUsado = filas.map(\.ancho).max() ?? 0
        return CGSize(width: proposal.width ?? anchoUsado, height: alto)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                              subviews: Subviews, cache: inout ()) {
        let filas = repartir(subviews: subviews, anchoDisponible: bounds.width)
        var y = bounds.minY
        for fila in filas {
            var x = bounds.minX
            for indice in fila.indices {
                let medida = subviews[indice].sizeThatFits(.unspecified)
                subviews[indice].place(
                    at: CGPoint(x: x, y: y + (fila.alto - medida.height) / 2),
                    proposal: ProposedViewSize(medida))
                x += medida.width + espaciado
            }
            y += fila.alto + espaciadoDeLinea
        }
    }

    private struct Fila {
        var indices: [Int] = []
        var ancho: CGFloat = 0
        var alto: CGFloat = 0
    }

    private func repartir(subviews: Subviews, anchoDisponible: CGFloat) -> [Fila] {
        var filas: [Fila] = []
        var actual = Fila()

        for indice in subviews.indices {
            let medida = subviews[indice].sizeThatFits(.unspecified)
            let anchoConSeparacion = actual.indices.isEmpty ? medida.width : medida.width + espaciado

            if !actual.indices.isEmpty, actual.ancho + anchoConSeparacion > anchoDisponible {
                filas.append(actual)
                actual = Fila()
                actual.indices = [indice]
                actual.ancho = medida.width
                actual.alto = medida.height
            } else {
                actual.indices.append(indice)
                actual.ancho += anchoConSeparacion
                actual.alto = max(actual.alto, medida.height)
            }
        }
        if !actual.indices.isEmpty { filas.append(actual) }
        return filas
    }
}
