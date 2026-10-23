import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 7 a 9: deporte, nivel y objetivo. Cada uno guarda lo suyo con
// `PATCH /me` al tocar "Continuar" (decisión 0008).
//
// Los 7 objetivos son una **lista cerrada** y eso no es pereza de diseño: es lo
// que permite que el motor del plan sea determinístico y explicable (AGENTS.md
// §9.1). Un objetivo libre no se puede periodizar.
//
// MVP sólo running: deporte y objetivos se filtran con `MVP` (TrainerCore).
// =============================================================================

/// `reg-deporte` · paso 7 de 11
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

/// `reg-nivel` · paso 8 de 11
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

/// `reg-objetivo` · paso 9 de 11
///
/// 2026-10-22: si el objetivo principal es una carrera, "Continuar" pide la
/// fecha. Si es "Volver a entrenar sin lesiones", no hay calendario y se sigue
/// derecho (viaja `goal_date_ms: null`, que borra una fecha que ya estuviera).
struct RegObjetivoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private var objetivos: [(Objetivo, String, String)] {
        let todos: [(Objetivo, String, String)] = [
            (.c5k, Textos.signupGoalC5k, ""),
            (.c10k, Textos.signupGoalC10k, ""),
            (.mediaMaraton, Textos.signupGoalHalfMarathon, Textos.signupGoalHalfMarathonDetail),
            (.maraton, Textos.signupGoalMarathon, Textos.signupGoalMarathonDetail),
            (.trailMontana, Textos.signupGoalMountainTrail, Textos.signupGoalMountainTrailDetail),
            (.triatlonOlimpico, Textos.signupGoalOlympicTriathlon,
             Textos.signupGoalOlympicTriathlonDetail),
            // Sin nada a la derecha: no tiene distancia.
            (.volverSinLesiones, Textos.signupGoalInjuryFree, ""),
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

                // Sin carrera (volver a entrenar sin lesiones) no hay fecha que elegir.
                if flujo.datos.objetivo != .volverSinLesiones {
                    CalendarioMes(seleccionada: $flujo.datos.fechaObjetivo,
                                  etiquetaMesAnterior: Textos.signupGoalPreviousMonth,
                                  etiquetaMesSiguiente: Textos.signupGoalNextMonth)

                    lineaDeFechaVista
                }
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.puedeSeguir(en: .regObjetivo),
                        motivoDeshabilitado: flujo.datos.objetivo == nil
                            ? Textos.commonCompleteToContinue : Textos.signupGoalMustChooseDate)
        }
    }

    /// Con fecha elegida, la píldora rosa con tilde del mockup; sin fecha, nada.
    @ViewBuilder
    private var lineaDeFechaVista: some View {
        if let fecha = flujo.datos.fechaObjetivo {
            HStack(alignment: .top, spacing: TokensEspaciado.e6) {
                Image(systemName: "checkmark")
                    .font(.system(size: TokensTipografia.chipTamano, weight: .heavy))
                    .foregroundStyle(Paleta.acento)
                    .padding(.top, TokensEspaciado.e2)
                    .accessibilityHidden(true)
                Text(lineaDeFecha(fecha))
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

    private func lineaDeFecha(_ fecha: Date) -> String {
        let dias = Calendar.autoupdatingCurrent
            .dateComponents([.day], from: Date(), to: fecha).day ?? 0
        let semanas = max(0, Int((Double(dias) / 7).rounded()))
        return Textos.signupGoalWithDate(
            fecha.formatted(.dateTime.day().month(.wide).year()), semanas)
    }
}
