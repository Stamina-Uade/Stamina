import SwiftUI
import TrainerCore

// MARK: - La cabecera de la semana

/// "‹  Semana 2 de 20  ›" con "Etapa Base ⓘ" debajo, y "12 de 26 km · faltan 14 km"
/// con su barra. Reemplaza a los chips S1…S20 y al anillo (2026-10-23). Tocar la
/// etapa abre "Las etapas de tu plan". Los números son los del servidor: un día
/// marcado a mano cuenta como sesión, pero no suma kilómetros.
struct PlanCabeceraDeSemana: View {
    let semana: SemanaDelPlan
    let totalDeSemanas: Int
    let unidades: SistemaDeUnidades
    let hayAnterior: Bool
    let haySiguiente: Bool
    /// -1 anterior, +1 siguiente.
    let alMoverse: (Int) -> Void
    let abrirEtapas: () -> Void

    private var fraccion: Double {
        guard semana.metrosPrevistos > 0 else { return 0 }
        return min(1, max(0, Double(semana.metrosHechos) / Double(semana.metrosPrevistos)))
    }

    /// "faltan 14 km", "cumplida" o nada si la semana no tiene kilómetros previstos.
    private var loQueFalta: String? {
        guard semana.metrosPrevistos > 0 else { return nil }
        guard semana.metrosHechos < semana.metrosPrevistos else { return Textos.planWeekDone }
        return Textos.planWeekKmLeft(
            Formato.distancia(semana.metrosPrevistos - semana.metrosHechos, unidades: unidades, decimales: 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            HStack(spacing: TokensEspaciado.e8) {
                BotonCircular("chevron.left", etiqueta: Textos.planWeekPrevious) { alMoverse(-1) }
                    .disabled(!hayAnterior)
                VStack(spacing: TokensEspaciado.e2) {
                    Text(Textos.planWeekOf(semana.numero, totalDeSemanas))
                        .estilo(.tituloSeccion)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                    if let etapa = semana.etapa {
                        Button(action: abrirEtapas) {
                            HStack(spacing: TokensEspaciado.e4) {
                                Text(Textos.planStage(etapa))
                                    .estilo(.labelCampo, color: Paleta.textoSecundario)
                                Image(systemName: "info.circle")
                                    .font(.system(size: TokensTipografia.chipTamano, weight: .semibold))
                                    .foregroundStyle(Paleta.textoAcento)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(EstiloPresionado())
                        .accessibilityHint(Textos.planPhasesTitle)
                    }
                }
                .frame(maxWidth: .infinity)
                BotonCircular("chevron.right", etiqueta: Textos.planWeekNext) { alMoverse(1) }
                    .disabled(!haySiguiente)
            }

            VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                HStack(spacing: TokensEspaciado.e8) {
                    Text(Textos.planKmOf(
                        Formato.distanciaNumero(semana.metrosHechos, unidades: unidades, decimales: 0),
                        Formato.distancia(semana.metrosPrevistos, unidades: unidades, decimales: 0)))
                        .estilo(.tituloCard)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    if let loQueFalta {
                        Text(loQueFalta)
                            .estilo(.labelCampo, color: Paleta.textoSecundario)
                    }
                }
                .accessibilityElement(children: .combine)
                BarraDeProgreso(fraccion: fraccion, descripcion: Textos.planWeekOf(semana.numero, totalDeSemanas))
            }
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }
}
