import SwiftUI
import TrainerCore

/// Las etapas del bloque (base, construcción, pico, afinamiento, carrera) como
/// una barra proporcional a sus semanas y una fila de chips. Tocar una etapa
/// explica para qué sirve, en palabras de todos los días. Arranca mostrando la
/// etapa en curso.
struct PlanTarjetaDeFases: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let fases: [FaseDelPlan]
    /// Por índice y no por `id`: los `id` de las fases son `UUID()` que cambian
    /// cada vez que se traduce el plan.
    @State private var elegida: Int?

    init(fases: [FaseDelPlan]) {
        self.fases = fases
    }

    private var indiceMostrado: Int {
        let indice = elegida ?? fases.firstIndex(where: { $0.enCurso }) ?? 0
        return fases.indices.contains(indice) ? indice : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                EncabezadoDeSeccion(Textos.planPhasesTitle)
                Text(Textos.planPhasesIntro)
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
                    .fixedSize(horizontal: false, vertical: true)
            }

            barra
            chips

            if fases.indices.contains(indiceMostrado) {
                explicacion(de: fases[indiceMostrado])
                    .id(indiceMostrado)
                    .transition(.opacity)
            }
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    private func elegir(_ indice: Int) {
        guard indice != indiceMostrado else { return }
        Haptico.seleccion()
        withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida)) {
            elegida = indice
        }
    }

    // MARK: - Barra proporcional

    /// `layoutPriority` no reparte ancho en proporción —sólo decide quién se
    /// achica primero—, así que el ancho se calcula. Cada tramo se puede tocar;
    /// para VoiceOver están los chips de abajo.
    private var barra: some View {
        GeometryReader { geo in
            let huecos = TokensEspaciado.e4 * CGFloat(max(0, fases.count - 1))
            let util = max(0, geo.size.width - huecos)
            let total = CGFloat(fases.reduce(0) { $0 + $1.peso })
            HStack(spacing: TokensEspaciado.e4) {
                ForEach(Array(fases.enumerated()), id: \.offset) { indice, fase in
                    Button { elegir(indice) } label: {
                        Capsule()
                            .fill(color(de: fase))
                            .shadow(color: fase.enCurso ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e4)
                            .frame(height: indice == indiceMostrado ? TokensEspaciado.e8 : TokensEspaciado.e4)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloPresionado())
                    .frame(width: total > 0 ? util * CGFloat(fase.peso) / total : 0)
                }
            }
        }
        .frame(height: TokensEspaciado.e22)
        .accessibilityHidden(true)
    }

    private func color(de fase: FaseDelPlan) -> Color {
        if fase.hecha { return Paleta.acento }
        if fase.enCurso { return Paleta.acentoApagado }
        return Paleta.superficieControl
    }

    // MARK: - Chips

    private var chips: some View {
        FlujoHorizontal(espaciado: TokensEspaciado.e6, espaciadoDeLinea: 0) {
            ForEach(Array(fases.enumerated()), id: \.offset) { indice, fase in
                chip(fase, indice: indice)
            }
        }
    }

    private func chip(_ fase: FaseDelPlan, indice: Int) -> some View {
        let esLaMostrada = indice == indiceMostrado
        return Button { elegir(indice) } label: {
            HStack(spacing: TokensEspaciado.e4) {
                if let simbolo = simboloDeEstado(fase) {
                    Image(systemName: simbolo)
                        .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                }
                Text(fase.titulo)
                    .estilo(.chip, color: esLaMostrada ? Paleta.textoPrimario : Paleta.textoSecundario)
                    .lineLimit(1)
            }
            .padding(.horizontal, TokensEspaciado.e10)
            .padding(.vertical, TokensEspaciado.e6)
            .background(Capsule().fill(esLaMostrada ? Paleta.acentoChipActivo : Paleta.superficieAlterna))
            .overlay(Capsule().strokeBorder(esLaMostrada ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                                            lineWidth: TokensEspaciado.e1))
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(Text(verbatim: "\(fase.titulo), \(estado(de: fase).texto)"))
        .accessibilityAddTraits(esLaMostrada ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(Textos.planPhaseHint)
    }

    private func simboloDeEstado(_ fase: FaseDelPlan) -> String? {
        if fase.enCurso { return "location.fill" }
        if fase.hecha { return "checkmark" }
        return nil
    }

    private func estado(de fase: FaseDelPlan) -> (texto: String, simbolo: String, tono: TonoDePildora) {
        if fase.enCurso {
            return (Textos.planPhaseYouAreHere, "location.fill", .acento)
        }
        if fase.hecha {
            return (Textos.planPhaseCompleted, "checkmark", .neutro)
        }
        return (Textos.planPhaseUpcoming, "clock", .neutro)
    }

    // MARK: - Explicación

    private func explicacion(de fase: FaseDelPlan) -> some View {
        let tipo = TipoDeFase(titulo: fase.titulo)
        let estadoDeLaFase = estado(de: fase)
        return VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            HStack(alignment: .center, spacing: TokensEspaciado.e10) {
                ZStack {
                    Circle()
                        .fill(fase.enCurso ? Paleta.acento : Paleta.superficieAlterna)
                        .shadow(color: fase.enCurso ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e6)
                    Image(systemName: tipo.simbolo)
                        .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                        .foregroundStyle(fase.enCurso ? Paleta.sobreAcento : Paleta.textoSecundario)
                }
                .frame(width: TokensEspaciado.e34, height: TokensEspaciado.e34)
                .accessibilityHidden(true)

                Text(fase.titulo)
                    .estilo(.tituloCardGrande)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PildoraDeEstado(estadoDeLaFase.texto, simbolo: estadoDeLaFase.simbolo, tono: estadoDeLaFase.tono)
            }

            Text(tipo.paraQueSirve)
                .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                .fixedSize(horizontal: false, vertical: true)

            if let consejo = tipo.consejo {
                HStack(alignment: .top, spacing: TokensEspaciado.e6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                    Text(consejo)
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fase.enCurso ? Paleta.acentoSuaveFondo : Paleta.superficieHundida)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Qué es cada etapa

/// El servidor manda la fase ya traducida en el título ("Base · 1-5"). Se
/// reconoce por el nombre de `Textos` y, si no, por la palabra (la maqueta usa
/// "Carga"). Lo que no se reconoce lleva una explicación general.
private enum TipoDeFase {
    case base, construccion, pico, afinamiento, carrera, otra

    init(titulo: String) {
        let minusculas = titulo.lowercased()
        func empiezaCon(_ nombre: String) -> Bool {
            !nombre.isEmpty && minusculas.hasPrefix(nombre.lowercased())
        }
        if empiezaCon(Textos.planPhaseBase) || minusculas.contains("base") {
            self = .base
        } else if empiezaCon(Textos.planPhaseBuild) || minusculas.contains("constru") || minusculas.contains("carga") {
            self = .construccion
        } else if empiezaCon(Textos.planPhasePeak) || minusculas.contains("pico") {
            self = .pico
        } else if empiezaCon(Textos.planPhaseTaper) || minusculas.contains("afina") {
            self = .afinamiento
        } else if empiezaCon(Textos.planPhaseRace) || minusculas.contains("carrera") {
            self = .carrera
        } else {
            self = .otra
        }
    }

    var simbolo: String {
        switch self {
        case .base: return "square.stack.3d.up"
        case .construccion: return "chart.line.uptrend.xyaxis"
        case .pico: return "mountain.2"
        case .afinamiento: return "dial.low"
        case .carrera: return "flag.checkered"
        case .otra: return "circle.dashed"
        }
    }

    var paraQueSirve: String {
        switch self {
        case .base:
            return Textos.planPhaseBaseBody
        case .construccion:
            return Textos.planPhaseBuildBody
        case .pico:
            return Textos.planPhasePeakBody
        case .afinamiento:
            return Textos.planPhaseTaperBody
        case .carrera:
            return Textos.planPhaseRaceBody
        case .otra:
            return Textos.planPhaseGenericBody
        }
    }

    var consejo: String? {
        switch self {
        case .base:
            return Textos.planPhaseBaseTip
        case .construccion:
            return Textos.planPhaseBuildTip
        case .pico:
            return Textos.planPhasePeakTip
        case .afinamiento:
            return Textos.planPhaseTaperTip
        case .carrera:
            return Textos.planPhaseRaceTip
        case .otra:
            return nil
        }
    }
}
