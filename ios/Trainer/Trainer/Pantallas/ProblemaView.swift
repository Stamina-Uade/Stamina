import SwiftUI
import TrainerCore

/// `problema` — las tres estadísticas que justifican el producto.
///
/// El diseño la deja **fuera del arranque** y accesible desde los chips del
/// lienzo (`ESPECIFICACION.md` §5.1). Acá se llega desde `preview-plan`, que es
/// lo mismo: existe, no está en el camino principal.
///
/// Los porcentajes se formatean con el locale, no se escriben: en es-AR es
/// "79,4 %" y en en-US "79.4%" (AGENTS.md §10).
struct ProblemaView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private struct Dato {
        let valor: String
        let texto: String
        let enAcento: Bool
    }

    private var datos: [Dato] {
        [
            Dato(valor: porcentaje(0.794), texto: Textos.problemaDato1, enAcento: true),
            Dato(valor: "\(numero(30))–\(porcentaje(0.67))", texto: Textos.problemaDato2, enAcento: false),
            Dato(valor: porcentaje(0.377), texto: Textos.problemaDato3, enAcento: false),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e26) {
                    Text(Textos.problemaTitulo)
                        .estilo(.tituloPantalla)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                        ForEach(Array(datos.enumerated()), id: \.offset) { indice, dato in
                            if indice > 0 {
                                Rectangle()
                                    .fill(Paleta.divisor)
                                    .frame(height: TokensEspaciado.e1)
                            }
                            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                                Text(dato.valor)
                                    .estilo(.numeroDato,
                                            color: dato.enAcento ? Paleta.acento : Paleta.textoPrimario)
                                Text(dato.texto)
                                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, TokensEspaciado.e26)
                .padding(.vertical, TokensEspaciado.e26)
            }

            BotonPrimario(Textos.problemaSeguir) { flujo.ir(a: .previewPlan) }
                .padding(.horizontal, TokensEspaciado.e26)
                .padding(.bottom, TokensEspaciado.e34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }

    private func porcentaje(_ v: Double) -> String {
        v.formatted(.percent.precision(.fractionLength(0...1)))
    }

    private func numero(_ v: Int) -> String {
        v.formatted(.number)
    }
}
