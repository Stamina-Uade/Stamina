import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 9 a 11: deporte, nivel y objetivo. Cada uno guarda lo suyo con
// `PATCH /me` al tocar "Continuar" (decisión 0008).
//
// Los 7 objetivos son una **lista cerrada** y eso no es pereza de diseño: es lo
// que permite que el motor del plan sea determinístico y explicable (AGENTS.md
// §9.1). Un objetivo libre no se puede periodizar.
//
// MVP sólo running: deporte y objetivos se filtran con `MVP` (TrainerCore).
// =============================================================================

/// `reg-deporte` · paso 9 de 15
struct RegDeporteView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    /// Todas las opciones; el MVP (sólo running) filtra cuáles se muestran.
    private var opciones: [(Deporte, String, String)] {
        let todas: [(Deporte, String, String)] = [
            (.running, Textos.signupSportRunning, Textos.signupSportRunningDetail),
            (.ciclismo, Textos.signupSportCycling, Textos.signupSportCyclingDetail),
            (.trekking, Textos.signupSportTrekking, Textos.signupSportTrekkingDetail),
            (.triatlon, Textos.signupSportTriathlon, Textos.signupSportTriathlonDetail),
        ]
        return todas.filter { MVP.deportesDePerfil.contains($0.0) }
    }

    var body: some View {
        PantallaPaso(titulo: Textos.signupSportTitle, texto: texto) {
            VStack(spacing: TokensEspaciado.e10) {
                ForEach(opciones, id: \.0) { valor, titulo, detalle in
                    FilaOpcion(titulo: titulo, detalle: detalle,
                               elegida: flujo.datos.deporte == valor) {
                        flujo.datos.deporte = valor
                    }
                }
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.deporte != nil)
        }
        .onAppear(perform: preseleccionar)
    }

    /// El texto de siempre habla de bici; con una sola opción (MVP sólo
    /// running) va una línea que dice por qué no hay más.
    private var texto: String {
        opciones.count == 1
            ? Textos.signupSportRunningOnly
            : Textos.signupSportBody
    }

    /// Con una sola opción (MVP sólo running) queda elegida de entrada; y si
    /// venía un deporte escondido, se reemplaza para que al servidor vaya running.
    private func preseleccionar() {
        let permitidos = MVP.deportesDePerfil
        if let actual = flujo.datos.deporte, permitidos.contains(actual) { return }
        if permitidos.count == 1 || flujo.datos.deporte != nil {
            flujo.datos.deporte = permitidos.first
        }
    }
}

/// `reg-nivel` · paso 10 de 15
struct RegNivelView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private var opciones: [(Nivel, String, String)] {
        [
            (.principiante, Textos.signupLevelBeginner, Textos.signupLevelBeginnerDetail),
            (.intermedio, Textos.signupLevelIntermediate, Textos.signupLevelIntermediateDetail),
            (.avanzado, Textos.signupLevelAdvanced, Textos.signupLevelAdvancedDetail),
        ]
    }

    var body: some View {
        PantallaPaso(titulo: Textos.signupLevelTitle, texto: Textos.signupLevelBody) {
            VStack(spacing: TokensEspaciado.e10) {
                ForEach(opciones, id: \.0) { valor, titulo, detalle in
                    FilaOpcion(titulo: titulo, detalle: detalle,
                               elegida: flujo.datos.nivel == valor,
                               conMarca: false) {
                        flujo.datos.nivel = valor
                    }
                }
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.nivel != nil)
        }
    }
}

/// `reg-objetivo` · paso 11 de 15
///
/// La fecha es **opcional a propósito**: el diseño deja seguir sin carrera
/// elegida y el contrato lo permite (`goal_date_ms` acepta `null`, y sin fecha se
/// manda ese `null` para borrar una que ya estuviera).
struct RegObjetivoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private var objetivos: [(Objetivo, String, String)] {
        let todos: [(Objetivo, String, String)] = [
            (.c5k, Textos.signupGoalC5k, Textos.signupGoalC5kDetail),
            (.c10k, Textos.signupGoalC10k, Textos.signupGoalC10kDetail),
            (.mediaMaraton, Textos.signupGoalHalfMarathon, Textos.signupGoalHalfMarathonDetail),
            (.maraton, Textos.signupGoalMarathon, Textos.signupGoalMarathonDetail),
            (.trailMontana, Textos.signupGoalMountainTrail, Textos.signupGoalMountainTrailDetail),
            (.triatlonOlimpico, Textos.signupGoalOlympicTriathlon,
             Textos.signupGoalOlympicTriathlonDetail),
            (.volverSinLesiones, Textos.signupGoalInjuryFree,
             Textos.signupGoalInjuryFreeDetail),
        ]
        // MVP sólo running: el triatlón queda escondido (ver `MVP`).
        return todos.filter { MVP.permite($0.0) }
    }

    var body: some View {
        PantallaPaso(titulo: Textos.signupGoalTitle, texto: Textos.signupGoalBody) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    Text(Textos.signupGoalChoose)
                        .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                    Text(Textos.signupGoalMultipleHint)
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                    ForEach(objetivos, id: \.0) { valor, titulo, distancia in
                        FilaObjetivo(titulo: titulo, distancia: distancia,
                                     elegido: flujo.datos.objetivo == valor ||
                                         flujo.datos.objetivosAdicionales.contains(valor)) {
                            if flujo.datos.objetivo == nil {
                                flujo.datos.objetivo = valor
                            } else if flujo.datos.objetivo == valor {
                                if let siguiente = flujo.datos.objetivosAdicionales.first {
                                    flujo.datos.objetivo = siguiente
                                    flujo.datos.objetivosAdicionales.removeFirst()
                                }
                            } else if flujo.datos.objetivosAdicionales.contains(valor) {
                                flujo.datos.objetivosAdicionales.removeAll { $0 == valor }
                            } else {
                                flujo.datos.objetivosAdicionales.append(valor)
                            }
                        }
                    }
                }

                CalendarioMes(seleccionada: $flujo.datos.fechaObjetivo,
                              etiquetaMesAnterior: Textos.signupGoalPreviousMonth,
                              etiquetaMesSiguiente: Textos.signupGoalNextMonth)

                lineaDeFechaVista
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.objetivo != nil)
        }
    }

    /// Con fecha elegida, la píldora rosa con tilde del mockup; sin fecha, la
    /// línea apagada que dice que se puede seguir igual.
    @ViewBuilder
    private var lineaDeFechaVista: some View {
        if flujo.datos.fechaObjetivo == nil {
            Text(lineaDeFecha)
                .estilo(.labelCampo, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(alignment: .top, spacing: TokensEspaciado.e6) {
                Image(systemName: "checkmark")
                    .font(.system(size: TokensTipografia.chipTamano, weight: .heavy))
                    .foregroundStyle(Paleta.acento)
                    .padding(.top, TokensEspaciado.e2)
                    .accessibilityHidden(true)
                Text(lineaDeFecha)
                    .estilo(.chip, color: Paleta.textoPrimario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TokensEspaciado.e12)
            .padding(.vertical, TokensEspaciado.e7)
            .background(Paleta.acentoChipActivo)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1)
            )
            .accessibilityElement(children: .combine)
        }
    }

    private var lineaDeFecha: String {
        guard let fecha = flujo.datos.fechaObjetivo else { return Textos.signupGoalNoDate }
        let dias = Calendar.autoupdatingCurrent
            .dateComponents([.day], from: Date(), to: fecha).day ?? 0
        let semanas = max(0, Int((Double(dias) / 7).rounded()))
        return Textos.signupGoalWithDate(
            fecha.formatted(.dateTime.day().month(.wide).year()), semanas)
    }
}
