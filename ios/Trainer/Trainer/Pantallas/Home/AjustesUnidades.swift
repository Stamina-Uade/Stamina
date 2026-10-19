import SwiftUI
import TrainerCore

/// Ajustes → Unidades: un segmentado Kilómetros / Millas. Guardar es de
/// `AjustesView` (`alElegir`); acá se ve el elegido y el que se está guardando.
struct AjustesPaginaUnidades: View {
    let elegido: SistemaDeUnidades
    /// El que se está guardando ahora (lleva la ruedita).
    let enCurso: SistemaDeUnidades?
    let guardando: Bool
    let alElegir: (SistemaDeUnidades) -> Void
    let volver: () -> Void

    var body: some View {
        AjustesPagina(Textos.ajustesUnidades, volver: volver) {
            HStack(spacing: TokensEspaciado.e4) {
                ForEach(SistemaDeUnidades.allCases) { sistema in
                    segmento(sistema)
                }
            }
            .padding(TokensEspaciado.e4)
            .background(Paleta.superficieHundida)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton + TokensEspaciado.e4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.boton + TokensEspaciado.e4, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
        }
    }

    private func segmento(_ sistema: SistemaDeUnidades) -> some View {
        let esElegido = sistema == elegido
        return Button {
            alElegir(sistema)
        } label: {
            VStack(spacing: TokensEspaciado.e2) {
                HStack(spacing: TokensEspaciado.e6) {
                    if enCurso == sistema {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Paleta.acento)
                    }
                    Text(nombre(de: sistema))
                        .estilo(.opcionTitulo, color: esElegido ? Paleta.sobreAcento : Paleta.textoSecundario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(verbatim: sistema == .metrico ? "km · kg" : "mi · lb")
                    .estilo(.notaLegal, color: esElegido ? Paleta.sobreAcento : Paleta.textoTerciario)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.objetivoTactilMinimo + TokensEspaciado.e8)
            .background(
                RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                    .fill(esElegido ? Paleta.acento : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .disabled(guardando)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nombre(de: sistema))
        // AGENTS.md §10: métrico e imperial son preferencia de PRESENTACIÓN.
        .accessibilityHint(Textos.ajustesUnidadesDetalle)
        .accessibilityAddTraits(esElegido ? [.isButton, .isSelected] : .isButton)
    }

    private func nombre(de sistema: SistemaDeUnidades) -> String {
        sistema == .metrico
            ? String(localized: "Kilómetros", comment: "Ajustes: sistema métrico")
            : String(localized: "Millas", comment: "Ajustes: sistema imperial")
    }
}
