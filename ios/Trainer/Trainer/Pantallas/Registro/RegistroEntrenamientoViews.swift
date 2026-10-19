import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 9 a 11: deporte, nivel y objetivo. Cada uno guarda lo suyo con
// `PATCH /me` al tocar "Continuar" (decisión 0008).
//
// Los 7 objetivos son una **lista cerrada** y eso no es pereza de diseño: es lo
// que permite que el motor del plan sea determinístico y explicable (AGENTS.md
// §9.1). Un objetivo libre no se puede periodizar.
// =============================================================================

/// `reg-deporte` · paso 9 de 15
struct RegDeporteView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private var opciones: [(Deporte, String, String)] {
        [
            (.running, Textos.regDeporteRunning, Textos.regDeporteRunningDetalle),
            (.ciclismo, Textos.regDeporteCiclismo, Textos.regDeporteCiclismoDetalle),
            (.trekking, Textos.regDeporteTrekking, Textos.regDeporteTrekkingDetalle),
            (.triatlon, Textos.regDeporteTriatlon, Textos.regDeporteTriatlonDetalle),
        ]
    }

    var body: some View {
        PantallaPaso(titulo: Textos.regDeporteTitulo, texto: Textos.regDeporteTexto) {
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
    }
}

/// `reg-nivel` · paso 10 de 15
struct RegNivelView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private var opciones: [(Nivel, String, String)] {
        [
            (.principiante, Textos.regNivelPrincipiante, Textos.regNivelPrincipianteDetalle),
            (.intermedio, Textos.regNivelIntermedio, Textos.regNivelIntermedioDetalle),
            (.avanzado, Textos.regNivelAvanzado, Textos.regNivelAvanzadoDetalle),
        ]
    }

    var body: some View {
        PantallaPaso(titulo: Textos.regNivelTitulo, texto: Textos.regNivelTexto) {
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
        [
            (.c5k, Textos.regObjetivoC5k, Textos.regObjetivoC5kDetalle),
            (.c10k, Textos.regObjetivoC10k, Textos.regObjetivoC10kDetalle),
            (.mediaMaraton, Textos.regObjetivoMediaMaraton, Textos.regObjetivoMediaMaratonDetalle),
            (.maraton, Textos.regObjetivoMaraton, Textos.regObjetivoMaratonDetalle),
            (.trailMontana, Textos.regObjetivoTrailMontana, Textos.regObjetivoTrailMontanaDetalle),
            (.triatlonOlimpico, Textos.regObjetivoTriatlonOlimpico,
             Textos.regObjetivoTriatlonOlimpicoDetalle),
            (.volverSinLesiones, Textos.regObjetivoVolverSinLesiones,
             Textos.regObjetivoVolverSinLesionesDetalle),
        ]
    }

    var body: some View {
        PantallaPaso(titulo: Textos.regObjetivoTitulo, texto: Textos.regObjetivoTexto) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    Text(Textos.regObjetivoElegi)
                        .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                    Text("Podés elegir varios. El primero será tu plan principal.")
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
                              etiquetaMesAnterior: Textos.regObjetivoMesAnterior,
                              etiquetaMesSiguiente: Textos.regObjetivoMesSiguiente)

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
        guard let fecha = flujo.datos.fechaObjetivo else { return Textos.regObjetivoSinFecha }
        let dias = Calendar.autoupdatingCurrent
            .dateComponents([.day], from: Date(), to: fecha).day ?? 0
        let semanas = max(0, Int((Double(dias) / 7).rounded()))
        return Textos.regObjetivoConFecha(
            fecha.formatted(.dateTime.day().month(.wide).year()), semanas)
    }
}
