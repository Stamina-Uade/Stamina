import SwiftUI
import UIKit
import TrainerCore

/// Una hoja que sube desde abajo y mide exactamente lo que mide su contenido, ni más
/// ni menos (decisión de Iván del 2026-10-23: vale para todas las hojas).
///
/// Se mide el alto ideal del contenido —dentro de un `ScrollView`, que no lo aprieta—
/// y ese alto es el único detent. Hasta tener la primera medición se usa `estimado`,
/// para que no aparezca con un tamaño muy distinto y después salte. Si el contenido
/// pasa del 90 % de la pantalla, la hoja va a `.large` y recién ahí se desplaza.
///
/// Es lo que antes hacía sólo `HojaDeExplicacion`, sacado acá para usarlo en todas.
struct HojaAMedida<Contenido: View>: View {
    private let estimado: CGFloat
    private let contenido: Contenido
    @State private var altoMedido: CGFloat?

    init(estimado: CGFloat = 360, @ViewBuilder contenido: () -> Contenido) {
        self.estimado = estimado
        self.contenido = contenido()
    }

    var body: some View {
        ScrollView {
            contenido
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: AltoDeLaHojaAMedida.self, value: geo.size.height)
                    }
                )
        }
        .scrollDisabled(!desborda)
        .onPreferenceChange(AltoDeLaHojaAMedida.self) { alto in
            guard alto > 0 else { return }
            let redondeado = alto.rounded(.up)
            if abs(redondeado - (altoMedido ?? 0)) > 0.5 { altoMedido = redondeado }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .presentationDetents([desborda ? .large : .height(alto)])
        .presentationDragIndicator(.visible)
    }

    private var alto: CGFloat { altoMedido ?? estimado }

    private var desborda: Bool { alto > Self.altoDePantalla * 0.9 }

    private static var altoDePantalla: CGFloat {
        let escena = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return escena?.screen.bounds.height ?? 800
    }
}

/// El alto ideal del contenido de `HojaAMedida`, medido desde adentro.
private struct AltoDeLaHojaAMedida: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// El encabezado de las hojas: título y, si hay, una línea debajo.
struct EncabezadoDeHoja: View {
    let titulo: String
    var bajada: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            Text(titulo)
                .estilo(.tituloSeccion)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let bajada, !bajada.isEmpty {
                Text(bajada)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    /// Los márgenes de adentro de una hoja.
    func margenesDeHoja() -> some View {
        padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e26)
            .padding(.bottom, TokensEspaciado.e20)
    }
}
