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
        PantallaPaso(titulo: Textos.signupHealthTitle, texto: Textos.signupHealthBody) {
            VStack(spacing: TokensEspaciado.e14) {
                AvisoAtencion(titulo: Textos.signupHealthStopAndConsult) {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                        ItemAtencion(Textos.signupHealthSymptom1)
                        ItemAtencion(Textos.signupHealthSymptom2)
                        ItemAtencion(Textos.signupHealthSymptom3)
                    }
                }

                Casilla(texto: Textos.signupHealthAccept, marcada: $flujo.datos.descargoAceptado)
                    .disabled(flujo.enCurso)
            }
        } pie: {
            PieDePerfil(habilitado: flujo.datos.descargoAceptado,
                        motivoDeshabilitado: Textos.signupHealthMustAccept)
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
            (.gps, Textos.signupTrackingGps, Textos.signupTrackingGpsDetail),
            (.garmin, Textos.signupTrackingGarmin, Textos.signupTrackingGarminDetail),
            (.apple, Textos.signupTrackingApple, Textos.signupTrackingAppleDetail),
            (.manual, Textos.signupTrackingManual, Textos.signupTrackingManualDetail),
        ]
    }

    var body: some View {
        PantallaPaso(titulo: Textos.signupTrackingTitle, texto: Textos.signupTrackingBody) {
            VStack(spacing: TokensEspaciado.e10) {
                ForEach(opciones, id: \.0) { valor, titulo, detalle in
                    FilaOpcion(titulo: titulo, detalle: detalle,
                               elegida: flujo.datos.medicion == valor) {
                        flujo.datos.medicion = valor
                    }
                }
                AvisoSuave(Textos.signupTrackingNotSaved)
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
        PantallaPaso(titulo: Textos.signupDaysTitle, texto: Textos.signupDaysBody) {
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
                           ? Textos.signupDaysAlert(flujo.datos.dias.count)
                           : Textos.signupDaysNoDays)
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.hayAlgunDia,
                        motivoDeshabilitado: Textos.signupDaysNoDays)
        }
    }

    private func filaDeHora(_ iso: Int) -> some View {
        HStack {
            Text(Self.nombre(iso)).estilo(.tituloCard)
            Spacer()
            DatePicker(
                Textos.signupDaysTimeOf(Self.nombre(iso)),
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
///
/// Rediseño 2026-10 (ronda 4): en vez del sello con tilde, festeja la mascota
/// con la medalla y dice el título en un globito. El párrafo largo
/// (`regListoTexto`) se cambió por una línea. Arma su propio andamio —el de
/// `PantallaCierre` dibuja el sello— con el mismo pie fijo de los pasos.
struct RegListoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: TokensEspaciado.e16) {
                    MascotaConBocadillo(pose: .medalla,
                                        texto: Textos.signupDoneTitle(nombre),
                                        altoMaximo: TokensEspaciado.e56 * 4)

                    Text(Textos.signupDoneProfileComplete)
                        .estilo(.cuerpoDestacado, color: Paleta.textoSecundario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    resumen
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, TokensEspaciado.e22)
                .padding(.top, TokensEspaciado.e26)
                .padding(.bottom, TokensEspaciado.e20)
            }

            pie
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(fondo)
        .onAppear { Haptico.exito() }
    }

    private var resumen: some View {
        Tarjeta {
            VStack(spacing: TokensEspaciado.e9) {
                FilaResumen(Textos.signupDoneBirth,
                            flujo.datos.nacimiento.map { $0.formatted(.dateTime.day().month().year()) } ?? "—")
                FilaResumen(Textos.signupDoneSport, deporte)
                FilaResumen(Textos.signupDoneLevel, nivel)
                FilaResumen(Textos.signupDoneDays, dias)
                FilaResumen(Textos.signupDoneGoal, objetivo)
            }
        }
    }

    /// El mismo pie fijo de `PantallaCierre`: la cápsula, con un fundido arriba
    /// para que el resumen que scrollea se pierda debajo.
    private var pie: some View {
        VStack(spacing: TokensEspaciado.e10) {
            BotonPrimario(Textos.signupDoneGoHome) { flujo.terminarRegistro() }
        }
        .padding(.horizontal, TokensEspaciado.e22)
        .padding(.bottom, TokensEspaciado.e34)
        .padding(.top, TokensEspaciado.e12)
        .background(alignment: .top) {
            LinearGradient(colors: [Paleta.fondo.opacity(0), Paleta.fondo],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: TokensEspaciado.e20)
                .offset(y: -TokensEspaciado.e20)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// El halo del acento arriba, como los otros cierres: es un final, no un paso.
    private var fondo: some View {
        ZStack {
            Paleta.fondo
            RadialGradient(colors: [Paleta.acentoProfundo, Color.clear],
                           center: .top, startRadius: 0,
                           endRadius: TokensEspaciado.e56 * 5)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var nombre: String {
        let n = flujo.datos.nombre.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? Textos.signupNamePlaceholder : n
    }

    private var deporte: String {
        switch flujo.datos.deporte {
        case .running: return Textos.signupSportRunning
        case .ciclismo: return Textos.signupSportCycling
        case .trekking: return Textos.signupSportTrekking
        case .triatlon: return Textos.signupSportTriathlon
        case .none: return "—"
        }
    }

    private var nivel: String {
        switch flujo.datos.nivel {
        case .principiante: return Textos.signupLevelBeginner
        case .intermedio: return Textos.signupLevelIntermediate
        case .avanzado: return Textos.signupLevelAdvanced
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
        case .c5k: return Textos.signupGoalC5k
        case .c10k: return Textos.signupGoalC10k
        case .mediaMaraton: return Textos.signupGoalHalfMarathon
        case .maraton: return Textos.signupGoalMarathon
        case .trailMontana: return Textos.signupGoalMountainTrail
        case .triatlonOlimpico: return Textos.signupGoalOlympicTriathlon
        case .volverSinLesiones: return Textos.signupGoalInjuryFree
        case .none: return Textos.signupDoneBasePlan
        }
    }
}
