import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 10 y 11: días y horarios, y el apto físico.
//
// 2026-10-22: se sacaron "¿Con qué mides tus salidas?" (no se guardaba: B-006,
// ver `DatosRegistro`), "Antes de arrancar" (el descargo pasó a la segunda
// casilla de "Antes de empezar") y "Todo listo" (el último paso entra derecho
// al Inicio).
// =============================================================================

/// `reg-dias` · paso 10 de 11 · guarda `training_days` y `timezone`
///
/// Debajo de los días, la "Notificación para prepararte" (prendida, 30 minutos
/// antes, de entrada). Se guarda en el teléfono (`AvisoDePreparacion`), el mismo
/// lugar que usa Ajustes.
///
/// 🪤 DIVERGENCIA — el diseño ofrece **7 horarios fijos** en un `<select>`.
/// Acá va el selector de hora del sistema: el contrato guarda `minute_of_day`
/// de 0 a 1439, así que quien entrena 6:45 puede decirlo, y el formato de 12 o
/// 24 horas sale del locale en vez de estar escrito (AGENTS.md §10).
struct RegDiasView: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    @AppStorage(AvisoDePreparacion.claveEncendido) private var avisoEncendido = true
    @AppStorage(AvisoDePreparacion.claveMinutos) private var minutosDeAviso = AvisoDePreparacion.minutosPorDefecto

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

                avisoDePreparacion
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.hayAlgunDia,
                        motivoDeshabilitado: Textos.signupDaysNoDays)
        }
    }

    /// "Notificación para prepararte" con su interruptor y, prendida, cuánto antes.
    private var avisoDePreparacion: some View {
        VStack(spacing: TokensEspaciado.e8) {
            Toggle(isOn: $avisoEncendido.animation(.easeInOut(duration: TokensMovimiento.rapida))) {
                Text(Textos.notificationsPrepTitle)
                    .estilo(.tituloCard)
            }
            .tint(Paleta.interruptorActivo)
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)

            if avisoEncendido {
                Divider().background(Paleta.divisor)
                FilaDeMinutosDeAviso(minutos: $minutosDeAviso)
            }
        }
        .padding(.vertical, TokensEspaciado.e8)
        .padding(.horizontal, TokensEspaciado.e16)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
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

/// `reg-apto` · paso 11 de 11 · opcional, sólo en el teléfono
///
/// La misma pantalla del apto de Perfil (`AptoFisicoView`): archivo, vencimiento
/// y declaración. "Guardar" y "Lo subo después" entran derecho al Inicio, sin
/// pantalla final; la primera vez aparece el tour, como siempre.
struct RegAptoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        AptoFisicoView(enElAlta: true) { flujo.terminarRegistro() }
    }
}
