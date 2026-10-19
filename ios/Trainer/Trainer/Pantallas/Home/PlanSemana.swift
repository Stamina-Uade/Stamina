import SwiftUI
import TrainerCore

// MARK: - Selector de semana

/// Las semanas como segmentos del mismo control que el de objetivos. Con
/// pocas, llenan el ancho; con muchas, se desplazan de costado y la elegida
/// queda centrada. La semana en curso lleva un punto.
struct PlanSelectorDeSemana: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let semanas: [SemanaDelPlan]
    let elegida: Int
    let alElegir: (Int) -> Void

    /// Hasta acá entran todas sin apretar el texto.
    private let maximoSinDesplazar = 5

    // Init explícito: con propiedades `private` el memberwise no se ve desde PlanView.
    init(semanas: [SemanaDelPlan], elegida: Int, alElegir: @escaping (Int) -> Void) {
        self.semanas = semanas
        self.elegida = elegida
        self.alElegir = alElegir
    }

    var body: some View {
        if semanas.count <= maximoSinDesplazar {
            fila(llenando: true)
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        } else {
            ScrollViewReader { lector in
                ScrollView(.horizontal, showsIndicators: false) {
                    fila(llenando: false)
                }
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                .onAppear { lector.scrollTo(elegida, anchor: .center) }
                .onChange(of: elegida) { nueva in
                    withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.media)) {
                        lector.scrollTo(nueva, anchor: .center)
                    }
                }
            }
        }
    }

    private func fila(llenando: Bool) -> some View {
        HStack(spacing: TokensEspaciado.e2) {
            ForEach(semanas) { semana in
                chip(semana, llenando: llenando)
                    .id(semana.numero)
            }
        }
        .padding(TokensEspaciado.e4)
        .background(Capsule().fill(Paleta.superficie))
        .overlay(Capsule().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
    }

    private func chip(_ semana: SemanaDelPlan, llenando: Bool) -> some View {
        let esLaElegida = semana.numero == elegida
        return Button { alElegir(semana.numero) } label: {
            Text(Textos.planWeekChip(semana.numero))
                .estilo(.tituloCard, color: esLaElegida ? Paleta.sobreAcento : Paleta.textoTerciario)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, llenando ? 0 : TokensEspaciado.e14)
                .frame(maxWidth: llenando ? .infinity : nil)
                .frame(minWidth: TokensTamano.objetivoTactilMinimo, minHeight: TokensEspaciado.e40)
                .background(Capsule().fill(esLaElegida ? Paleta.acento : Color.clear))
                .overlay(alignment: .top) {
                    if semana.enCurso && !esLaElegida {
                        Circle()
                            .fill(Paleta.acento)
                            .frame(width: TokensEspaciado.e5, height: TokensEspaciado.e5)
                            .padding(.top, TokensEspaciado.e4)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(semana.enCurso ? Textos.planWeekInProgress(semana.numero) : Textos.planWeek(semana.numero))
        .accessibilityAddTraits(esLaElegida ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Cuánto llevás de la semana

/// El anillo de lo hecho contra lo previsto, la frase que lo dice en palabras y
/// las flechas para ir a la semana anterior o siguiente. Los dos números son
/// los del servidor: acá sólo se dibujan.
struct PlanProgresoDeLaSemana: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let semana: SemanaDelPlan
    let unidades: SistemaDeUnidades
    let hayAnterior: Bool
    let haySiguiente: Bool
    /// -1 anterior, +1 siguiente.
    let alMoverse: (Int) -> Void

    @State private var mostrado = false

    init(semana: SemanaDelPlan, unidades: SistemaDeUnidades, hayAnterior: Bool, haySiguiente: Bool,
         alMoverse: @escaping (Int) -> Void) {
        self.semana = semana
        self.unidades = unidades
        self.hayAnterior = hayAnterior
        self.haySiguiente = haySiguiente
        self.alMoverse = alMoverse
    }

    private var fraccion: Double {
        guard semana.metrosPrevistos > 0 else { return 0 }
        return min(1, max(0, Double(semana.metrosHechos) / Double(semana.metrosPrevistos)))
    }

    private var titulo: String {
        semana.enCurso ? Textos.planWeekInProgress(semana.numero) : Textos.planWeek(semana.numero)
    }

    private var kilometros: String {
        Textos.planKmOf(
            Formato.distancia(semana.metrosHechos, unidades: unidades, decimales: 0),
            Formato.distancia(semana.metrosPrevistos, unidades: unidades, decimales: 0))
    }

    private var mensaje: String {
        if semana.metrosPrevistos <= 0 {
            return Textos.planWeekNoKmPlanned
        }
        if semana.metrosHechos >= semana.metrosPrevistos {
            return Textos.planWeekComplete
        }
        if semana.metrosHechos <= 0 {
            return semana.enCurso
                ? Textos.planWeekNoKmYet
                : Textos.planWeekNoKmLogged
        }
        let faltan = Formato.distancia(semana.metrosPrevistos - semana.metrosHechos, unidades: unidades, decimales: 0)
        return Textos.planWeekLeftToComplete(faltan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            HStack(spacing: TokensEspaciado.e14) {
                anillo
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(titulo)
                        .estilo(.tituloSeccion)
                        .accessibilityAddTraits(.isHeader)
                    Text(kilometros)
                        .estilo(.tituloCard, color: Paleta.textoPrimario)
                        .monospacedDigit()
                    Text(mensaje)
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: TokensEspaciado.e8) {
                flecha("chevron.left",
                       etiqueta: Textos.planWeekPrevious,
                       habilitada: hayAnterior) { alMoverse(-1) }
                Text(Textos.planWeekSwipeHint)
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                flecha("chevron.right",
                       etiqueta: Textos.planWeekNext,
                       habilitada: haySiguiente) { alMoverse(1) }
            }
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
        .onAppear { mostrado = true }
    }

    private var anillo: some View {
        ZStack {
            Circle()
                .stroke(Paleta.superficieControl, lineWidth: TokensEspaciado.e6)
            Circle()
                .trim(from: 0, to: mostrado ? fraccion : 0)
                .stroke(Paleta.acento, style: StrokeStyle(lineWidth: TokensEspaciado.e6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: fraccion >= 1 ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e6)
            Text(fraccion.formatted(.percent.precision(.fractionLength(0))))
                .estilo(.tituloCard)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: TokensEspaciado.e56, height: TokensEspaciado.e56)
        .animation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.lenta), value: fraccion)
        .animation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.lenta), value: mostrado)
    }

    private func flecha(_ simbolo: String, etiqueta: String, habilitada: Bool,
                        accion: @escaping () -> Void) -> some View {
        BotonCircular(simbolo, etiqueta: etiqueta, accion: accion)
            .disabled(!habilitada)
            .opacity(habilitada ? 1 : 0.35)
    }
}
