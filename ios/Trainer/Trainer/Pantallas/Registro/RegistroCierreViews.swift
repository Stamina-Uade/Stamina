import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 12 a 15: salud, medición, días y resumen.
//
// 🛑 `reg-salud` es el descargo médico y no es un trámite. AGENTS.md §8 y §9.2
// tratan los datos de salud como la categoría más sensible del producto, y esta
// pantalla es donde la app dice, con todas las letras, que no reemplaza una
// consulta. El tono nunca es punitivo (§9.2). Se pisa con el aviso del paso 4
// (B-007), y eso sigue abierto.
// =============================================================================

/// `reg-salud` · paso 12 de 15 · guarda `medical_disclaimer_accepted`
struct RegSaludView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.regSaludTitulo, texto: Textos.regSaludTexto) {
            VStack(spacing: TokensEspaciado.e14) {
                AvisoAtencion(titulo: Textos.regSaludParaYConsulta) {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                        ItemAtencion(Textos.regSaludSintoma1)
                        ItemAtencion(Textos.regSaludSintoma2)
                        ItemAtencion(Textos.regSaludSintoma3)
                    }
                }

                Casilla(texto: Textos.regSaludAcepto, marcada: $flujo.datos.descargoAceptado)
                    .disabled(flujo.enCurso)
            }
        } pie: {
            PieDePerfil(habilitado: flujo.datos.descargoAceptado,
                        motivoDeshabilitado: Textos.regSaludFaltaAceptar)
        }
    }
}

/// `reg-medicion` · paso 13 de 15 · 🛑 no guarda nada (B-006)
///
/// `PerfilEntrada` del contrato v1 no tiene dónde guardar esto: el paso se
/// completa, el valor no se manda, y **la pantalla lo dice**. Un paso que pregunta
/// y tira la respuesta sin avisar es peor que no preguntarla: quien elige "Garmin"
/// y después no ve su reloj conectado merece saber por qué. Es lo mismo que hace
/// Android (`perf_medicion_hueco`).
struct RegMedicionView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private var opciones: [(DatosRegistro.Medicion, String, String)] {
        [
            (.gps, Textos.regMedicionGps, Textos.regMedicionGpsDetalle),
            (.garmin, Textos.regMedicionGarmin, Textos.regMedicionGarminDetalle),
            (.apple, Textos.regMedicionApple, Textos.regMedicionAppleDetalle),
            (.manual, Textos.regMedicionManual, Textos.regMedicionManualDetalle),
        ]
    }

    var body: some View {
        PantallaPaso(titulo: Textos.regMedicionTitulo, texto: Textos.regMedicionTexto) {
            VStack(spacing: TokensEspaciado.e10) {
                ForEach(opciones, id: \.0) { valor, titulo, detalle in
                    FilaOpcion(titulo: titulo, detalle: detalle,
                               elegida: flujo.datos.medicion == valor) {
                        flujo.datos.medicion = valor
                    }
                }
                AvisoSuave(Textos.regMedicionNoSeGuarda)
            }
        } pie: {
            PieDePerfil(ahoraNo: {
                flujo.datos.medicion = nil
                Task { await flujo.guardarYSeguir() }
            })
        }
    }
}

/// `reg-dias` · paso 14 de 15 · guarda `training_days` y `timezone`
///
/// 🪤 DIVERGENCIA — el diseño ofrece **7 horarios fijos** en un `<select>`.
/// Acá va el selector de hora del sistema: el contrato guarda `minute_of_day`
/// de 0 a 1439, así que quien entrena 6:45 puede decirlo, y el formato de 12 o
/// 24 horas sale del locale en vez de estar escrito (AGENTS.md §10).
struct RegDiasView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    /// Días ISO: 1 = lunes. El orden de la fila arranca donde el locale diga.
    private var diasEnOrden: [Int] {
        let primero = Calendar.autoupdatingCurrent.firstWeekday  // 1 = domingo
        let isoDelPrimero = primero == 1 ? 7 : primero - 1
        return (0..<7).map { ((isoDelPrimero - 1 + $0) % 7) + 1 }
    }

    var body: some View {
        PantallaPaso(titulo: Textos.regDiasTitulo, texto: Textos.regDiasTexto) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                HStack(spacing: TokensEspaciado.e5) {
                    ForEach(diasEnOrden, id: \.self) { iso in
                        ChipDia(abreviatura: Self.abreviatura(iso),
                                nombreCompleto: Self.nombre(iso),
                                elegido: flujo.datos.dias[iso] != nil) {
                            alternar(iso)
                        }
                    }
                }

                VStack(spacing: TokensEspaciado.e9) {
                    ForEach(flujo.datos.diasElegidos, id: \.self) { iso in
                        filaDeHora(iso)
                    }
                }

                AvisoSuave(flujo.datos.hayAlgunDia
                           ? Textos.regDiasAviso(flujo.datos.dias.count)
                           : Textos.regDiasSinDias)
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.hayAlgunDia,
                        motivoDeshabilitado: Textos.regDiasSinDias)
        }
    }

    private func filaDeHora(_ iso: Int) -> some View {
        HStack {
            Text(Self.nombre(iso)).estilo(.tituloCard)
            Spacer()
            DatePicker(
                Textos.regDiasHoraDe(Self.nombre(iso)),
                selection: enlaceDeHora(iso),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
        .padding(.vertical, TokensEspaciado.e8)
        .padding(.horizontal, TokensEspaciado.e16)
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
    }

    /// El contrato guarda minutos desde la medianoche **local**; el `DatePicker`
    /// trabaja con `Date`. La traducción vive acá y no se filtra al modelo.
    private func enlaceDeHora(_ iso: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutos = flujo.datos.dias[iso] ?? 0
                let inicio = Calendar.autoupdatingCurrent.startOfDay(for: Date())
                return Calendar.autoupdatingCurrent
                    .date(byAdding: .minute, value: minutos, to: inicio) ?? inicio
            },
            set: { nueva in
                let c = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: nueva)
                flujo.datos.dias[iso] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func alternar(_ iso: Int) {
        if flujo.datos.dias[iso] != nil {
            flujo.datos.dias.removeValue(forKey: iso)
        } else {
            flujo.datos.dias[iso] = 18 * 60 + 30
        }
    }

    // Los nombres de los días salen del sistema, no de una tabla propia: son
    // parte del locale, como las fechas y los números (AGENTS.md §10).
    private static func simbolos(_ cortos: Bool) -> [String] {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        let s = cortos ? f.shortWeekdaySymbols : f.standaloneWeekdaySymbols
        return s ?? []
    }

    /// `iso` 1 = lunes; `weekdaySymbols` arranca en domingo.
    private static func indice(_ iso: Int) -> Int { iso % 7 }

    static func abreviatura(_ iso: Int) -> String {
        let s = simbolos(true)
        guard s.count == 7 else { return "" }
        return s[indice(iso)].prefix(3).capitalized
    }

    static func nombre(_ iso: Int) -> String {
        let s = simbolos(false)
        guard s.count == 7 else { return "" }
        return s[indice(iso)].capitalized
    }
}

/// `reg-listo` · paso 15 de 15
///
/// No guarda nada: cada paso anterior ya guardó lo suyo. Lo que se ve acá es un
/// espejo de eso, no un último pedido que pueda fallar.
struct RegListoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaCierre(titulo: Textos.regListoTitulo(nombre), texto: Textos.regListoTexto) {
            Tarjeta {
                VStack(spacing: TokensEspaciado.e9) {
                    FilaResumen(Textos.regListoNacimiento,
                                flujo.datos.nacimiento.map { $0.formatted(.dateTime.day().month().year()) } ?? "—")
                    FilaResumen(Textos.regListoDeporte, deporte)
                    FilaResumen(Textos.regListoNivel, nivel)
                    FilaResumen(Textos.regListoDias, dias)
                    FilaResumen(Textos.regListoObjetivo, objetivo)
                }
            }
        } pie: {
            BotonPrimario(Textos.regListoIrAInicio) { flujo.terminarRegistro() }
        }
    }

    private var nombre: String {
        let n = flujo.datos.nombre.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? Textos.regNombreMarcador : n
    }

    private var deporte: String {
        switch flujo.datos.deporte {
        case .running: return Textos.regDeporteRunning
        case .ciclismo: return Textos.regDeporteCiclismo
        case .trekking: return Textos.regDeporteTrekking
        case .triatlon: return Textos.regDeporteTriatlon
        case .none: return "—"
        }
    }

    private var nivel: String {
        switch flujo.datos.nivel {
        case .principiante: return Textos.regNivelPrincipiante
        case .intermedio: return Textos.regNivelIntermedio
        case .avanzado: return Textos.regNivelAvanzado
        case .none: return "—"
        }
    }

    private var dias: String {
        let elegidos = flujo.datos.diasElegidos
        guard !elegidos.isEmpty else { return "—" }
        return elegidos.map(RegDiasView.abreviatura).joined(separator: ", ")
    }

    private var objetivo: String {
        switch flujo.datos.objetivo {
        case .c5k: return Textos.regObjetivoC5k
        case .c10k: return Textos.regObjetivoC10k
        case .mediaMaraton: return Textos.regObjetivoMediaMaraton
        case .maraton: return Textos.regObjetivoMaraton
        case .trailMontana: return Textos.regObjetivoTrailMontana
        case .triatlonOlimpico: return Textos.regObjetivoTriatlonOlimpico
        case .volverSinLesiones: return Textos.regObjetivoVolverSinLesiones
        case .none: return Textos.regListoPlanDeBase
        }
    }
}
