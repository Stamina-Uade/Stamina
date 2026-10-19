import SwiftUI
import TrainerCore

/// "Carga semanal": los km de la semana de hoy, lo hecho contra lo previsto, y
/// una barra por día. Tocar una barra dice qué toca ese día; tocar el total
/// lleva al plan. El día elegido es estado de esta vista: no viaja a ningún lado.
struct InicioTarjetaDeCarga: View {
    @EnvironmentObject private var estado: EstadoHome
    let plan: PlanDelHome
    /// `nil` hasta que se toca una barra: mientras tanto se muestra hoy.
    @State private var diaElegido: Int? = nil

    private var semana: SemanaDelPlan? {
        plan.bloque.semanas.first(where: { $0.numero == plan.semanaDeHoy })
    }

    /// Los días de la semana, alineados con las barras. Salen de la misma lista
    /// del servidor y en el mismo orden; si por algo no coinciden en cantidad,
    /// no se adivina cuál es cuál.
    private var dias: [DiaDelPlan]? {
        guard let semana, semana.dias.count == plan.cargaSemanal.count else { return nil }
        return semana.dias
    }

    private var indiceMostrado: Int? {
        guard let indice = diaElegido ?? plan.indiceDeHoy,
              plan.cargaSemanal.indices.contains(indice) else { return nil }
        return indice
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                EncabezadoDeSeccion(Textos.homeWeeklyLoad)
                Text(Textos.homeWeeklyLoadGuide)
                    .estilo(.notaLegal, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
                filaDelTotal
                GraficoDeCarga(metrosPorDia: plan.cargaSemanal,
                               diaDestacado: plan.indiceDeHoy ?? -1,
                               seleccionado: indiceMostrado,
                               etiquetas: letrasDeLosDias,
                               etiquetasAccesibles: plan.cargaSemanal.indices.map { etiquetaAccesible($0) },
                               alElegir: { elegir($0) })
                    .frame(height: TokensEspaciado.e56 + TokensEspaciado.e20)
                if let indice = indiceMostrado {
                    detalleDelDia(indice)
                }
            }
            .padding(TokensEspaciado.e16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjeta()
        }
    }

    // MARK: - El total, que lleva al plan

    private var filaDelTotal: some View {
        Button {
            Haptico.toque()
            estado.ir(a: .plan)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e6) {
                if let semana {
                    Text(Formato.distancia(semana.metrosHechos, unidades: estado.sistemaDeUnidades, decimales: 0))
                        .estilo(.metricaMedia)
                    Text(Textos.homeOfPlanned(
                        Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades, decimales: 0)))
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                }
                Spacer(minLength: 0)
                HStack(spacing: TokensEspaciado.e4) {
                    Text(Textos.homeViewPlan).estilo(.chip, color: Paleta.textoAcento)
                    Image(systemName: "chevron.right")
                        .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                        .foregroundStyle(Paleta.textoAcento)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Textos.homeViewPlan)
    }

    // MARK: - El día elegido

    private func detalleDelDia(_ indice: Int) -> some View {
        let metros = plan.cargaSemanal[indice]
        let dia = dias?[indice]
        return HStack(alignment: .center, spacing: TokensEspaciado.e10) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(nombreDelDia(indice))
                    .estilo(.cuerpoDestacado)
                if let titulo = dia?.titulo, !titulo.isEmpty {
                    Text(titulo)
                        .estilo(.notaLegal, color: Paleta.textoSecundario)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if dia?.hecho == true {
                PildoraDeEstado(Textos.commonDoneCheck,
                                simbolo: "checkmark", tono: .acento)
            }
            Text(metros > 0
                 ? Formato.distancia(metros, unidades: estado.sistemaDeUnidades)
                 : Textos.homeWeeklyLoadNoKm)
                .estilo(.tituloCard, color: metros > 0 ? Paleta.acento : Paleta.textoTerciario)
                .monospacedDigit()
        }
        .padding(.horizontal, TokensEspaciado.e12)
        .padding(.vertical, TokensEspaciado.e10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficieAlterna)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func elegir(_ indice: Int) {
        Haptico.seleccion()
        diaElegido = indice
    }

    // MARK: - Nombres de los días

    private var calendario: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        return calendario
    }

    /// ISO 1 = lunes … 7 = domingo; los símbolos del calendario arrancan en domingo.
    private func simbolo(iso: Int, corto: Bool) -> String {
        let simbolos = corto ? calendario.veryShortStandaloneWeekdaySymbols : calendario.standaloneWeekdaySymbols
        let indice = iso % 7
        guard simbolos.indices.contains(indice) else { return "" }
        return simbolos[indice]
    }

    /// "L M M J V S D" debajo de las barras; sin días alineados, nada.
    private var letrasDeLosDias: [String] {
        guard let dias else { return [] }
        return dias.map { simbolo(iso: $0.diaDeLaSemana, corto: true).uppercased() }
    }

    /// "Hoy · miércoles 21", "Jueves 22" o, sin días alineados, "Día 4".
    private func nombreDelDia(_ indice: Int) -> String {
        let hoy = Textos.commonToday
        guard let dia = dias?[indice] else {
            if indice == plan.indiceDeHoy { return hoy }
            return Textos.homeWeeklyLoadDayNumber(indice + 1)
        }
        let nombre = "\(simbolo(iso: dia.diaDeLaSemana, corto: false)) \(dia.numeroDeDia)"
        if indice == plan.indiceDeHoy { return "\(hoy) · \(nombre)" }
        return InicioTextos.primeraMayuscula(nombre)
    }

    private func etiquetaAccesible(_ indice: Int) -> String {
        let metros = plan.cargaSemanal[indice]
        let distancia = metros > 0
            ? Formato.distancia(metros, unidades: estado.sistemaDeUnidades)
            : Textos.homeWeeklyLoadNoKm
        return "\(nombreDelDia(indice)), \(distancia)"
    }
}
