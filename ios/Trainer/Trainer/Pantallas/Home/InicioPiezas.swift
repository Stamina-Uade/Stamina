import SwiftUI
import TrainerCore

// El fueguito de la racha y su hoja. Va en la barra fija de las cuatro pestañas
// (`FueguitoDeLaBarra`, en `PantallaDePestana.swift`).

// MARK: - Fueguitos / Racha estilo Duolingo

struct InsigniaDeRacha: View {
    let racha: RachaHome
    @State private var mostrandoDetalle = false

    private var encendida: Bool { racha.dias > 0 && racha.activaHoy }

    var body: some View {
        Button { mostrandoDetalle = true } label: {
            HStack(spacing: TokensEspaciado.e5) {
                Image(systemName: encendida ? "flame.fill" : "flame")
                    .font(.system(size: TokensEspaciado.e16, weight: .bold))
                    .foregroundStyle(racha.dias > 0
                        ? (racha.activaHoy ? Paleta.acento : Paleta.textoSecundario)
                        : Paleta.textoTerciario)
                Text(verbatim: "\(racha.dias)")
                    .estilo(.cuerpoDestacado, color: racha.dias > 0 ? Paleta.textoPrimario : Paleta.textoSecundario)
                    .monospacedDigit()
            }
            .padding(.horizontal, TokensEspaciado.e12)
            .frame(minHeight: TokensEspaciado.e36)
            .background(Capsule().fill(encendida ? Paleta.acentoChipActivo : Paleta.superficie))
            .overlay(
                Capsule()
                    .strokeBorder(encendida ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                                  lineWidth: TokensEspaciado.e1)
            )
            .shadow(color: encendida ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e8)
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Textos.streakAccessibility(Textos.streakTitle, racha.dias, Textos.streakDays))
        .sheet(isPresented: $mostrandoDetalle) {
            DetalleDeRachaView(racha: racha)
        }
    }
}

struct DetalleDeRachaView: View {
    let racha: RachaHome
    @Environment(\.dismiss) private var cerrar

    private var encendida: Bool { racha.dias > 0 && racha.activaHoy }

    var body: some View {
        HojaAMedida(estimado: 520) {
            VStack(spacing: TokensEspaciado.e20) {
                ZStack {
                    Circle()
                        .fill(encendida ? Paleta.acentoChipActivo : Paleta.superficieOverlay)
                        .frame(width: TokensEspaciado.e44 * 2,
                               height: TokensEspaciado.e44 * 2)
                        .shadow(color: encendida ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e20)
                    Image(systemName: encendida ? "flame.fill" : "flame")
                        .font(.system(size: TokensEspaciado.e44, weight: .bold))
                        .foregroundStyle(encendida ? Paleta.acento : Paleta.textoSecundario)
                }
                .padding(.top, TokensEspaciado.e12)
                .accessibilityHidden(true)

                VStack(spacing: TokensEspaciado.e4) {
                    MetricaHeroe("\(racha.dias)", unidad: racha.dias == 1 ? Textos.commonDay : Textos.streakDays,
                                 etiquetaAccesible: Textos.streakTitle)
                    Text(Textos.streakTitle)
                        .estilo(.etiquetaSeccion, color: Paleta.acento)
                }

                VStack(spacing: TokensEspaciado.e10) {
                    Text(mensajeDeEstado)
                        .estilo(.tituloSeccion)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, TokensEspaciado.e16)

                    Text(Textos.streakExplanation)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, TokensEspaciado.e20)
                }

                BotonPrimario(Textos.commonDone) {
                    cerrar()
                }
                .padding(.horizontal, TokensEspaciado.e16)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, TokensEspaciado.e16)
            .padding(.bottom, TokensEspaciado.e20)
        }
    }

    private var mensajeDeEstado: String {
        if racha.dias > 0 {
            if racha.entrenadoHoy {
                return Textos.streakDetailActive
            } else if !racha.tocaHoy {
                return Textos.streakDetailRest
            } else {
                return Textos.streakDetailPending
            }
        } else {
            return Textos.streakDetailLost
        }
    }
}
