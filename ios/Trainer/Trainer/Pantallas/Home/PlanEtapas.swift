import SwiftUI
import TrainerCore

/// "Las etapas de tu plan": la hoja que abre "Etapa Base ⓘ" en la cabecera de la
/// semana. Reemplaza a la tarjeta fija de las etapas (2026-10-23): las cuatro, una
/// línea cada una, y la actual marcada "Estás acá".
struct HojaDeEtapas: View {
    /// Las del bloque, para saber en cuál estás.
    let fases: [FaseDelPlan]
    @Environment(\.dismiss) private var cerrar

    private static let etapas: [Fase] = [.base, .construccion, .pico, .afinamiento]

    private var actual: Fase? { fases.first(where: { $0.enCurso })?.fase }

    var body: some View {
        HojaAMedida(estimado: 420) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                EncabezadoDeHoja(titulo: Textos.planPhasesTitle)
                VStack(spacing: TokensEspaciado.e8) {
                    ForEach(Self.etapas, id: \.self) { etapa in
                        fila(etapa)
                    }
                }
                BotonPrimario(Textos.commonDone) {
                    Haptico.toque()
                    cerrar()
                }
            }
            .margenesDeHoja()
        }
    }

    private func fila(_ etapa: Fase) -> some View {
        let esLaActual = etapa == actual
        return VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
            HStack(spacing: TokensEspaciado.e8) {
                Text(TraduccionDelServidor.nombre(de: etapa))
                    .estilo(.cuerpoDestacado)
                if esLaActual {
                    PildoraDeEstado(Textos.planPhaseYouAreHere, simbolo: "location.fill", tono: .acento)
                }
                Spacer(minLength: 0)
            }
            Text(Self.enUnaLinea(etapa))
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(esLaActual ? Paleta.acentoSuaveFondo : Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(esLaActual ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
        .accessibilityElement(children: .combine)
    }

    static func enUnaLinea(_ etapa: Fase) -> String {
        switch etapa {
        case .base: return Textos.planStageBaseLine
        case .construccion: return Textos.planStageBuildLine
        case .pico: return Textos.planStagePeakLine
        case .afinamiento: return Textos.planStageTaperLine
        case .carrera: return Textos.planStageRaceLine
        }
    }
}
