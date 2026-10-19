import SwiftUI
import TrainerCore

/// La atribución que Apple exige donde se usen datos de WeatherKit: la marca de
/// Apple Weather y el link a sus fuentes. Mientras no llega la marca oficial (o si
/// WeatherKit no contesta) se ve la marca en texto con el link fijo.
struct AtribucionDeAppleWeather: View {
    @Environment(\.colorScheme) private var esquema
    @State private var atribucion: AtribucionDelClima?

    private var paginaLegal: URL { atribucion?.paginaLegal ?? ClimaNativo.paginaLegalPorDefecto }

    var body: some View {
        Link(destination: paginaLegal) {
            HStack(spacing: TokensEspaciado.e6) {
                marca
                Text(Textos.weatherAttributionSources)
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
                    .underline()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Textos.weatherAttributionAccessibility)
        .accessibilityAddTraits(.isLink)
        .task {
            if atribucion == nil { atribucion = await ClimaNativo.atribucion() }
        }
    }

    /// La marca oficial según el modo (oscura para fondo oscuro), o la de texto.
    @ViewBuilder
    private var marca: some View {
        if let atribucion {
            AsyncImage(url: esquema == .dark ? atribucion.marcaOscura : atribucion.marcaClara) { fase in
                if let imagen = fase.image {
                    imagen
                        .resizable()
                        .scaledToFit()
                        .frame(height: TokensEspaciado.e14)
                } else {
                    marcaEnTexto
                }
            }
        } else {
            marcaEnTexto
        }
    }

    /// "\u{F8FF} Weather": el logo de Apple es un carácter de la fuente del sistema.
    private var marcaEnTexto: some View {
        Text(verbatim: "\u{F8FF} Weather")
            .estilo(.notaLegal, color: Paleta.textoSecundario)
    }
}
