import SwiftUI

// 🛑 SÓLO TELÉFONO — el archivo entero.
//
// `DatePicker` no existe en watchOS antes de la 10, y el reloj no lo necesita:
// AGENTS.md §10.2 dice que la interacción del reloj es **de un dedo y sin
// mirar**, sin formularios, y que "si algo necesita teclado, es del teléfono".
// Una rueda de fecha en la muñeca es exactamente lo que esa regla prohíbe.
//
// El `#if` de acá no está para que compile: es esa regla, escrita en el código.
#if os(iOS)

// =============================================================================
// Los dos selectores de fecha del registro.
//
// 🪤 RUEDA DE NACIMIENTO — se usa el `DatePicker` del sistema, no una rueda
// propia. El diseño la construye a mano con tres columnas que se ordenan con
// `Intl` según el idioma, y su referencia declarada es literalmente una captura
// de "la rueda de fecha estilo iOS" (`design/ESPECIFICACION.md` §1.2). Es decir:
// el diseño está imitando este control. Reimplementarlo daría el mismo dibujo
// con peor accesibilidad, sin rotor de VoiceOver y con los bordes —febreros
// bisiestos, meses de 30— por resolver a mano.
//
// El calendario del objetivo SÍ es propio: es compacto, vive dentro de una card
// y no se parece al `DatePicker` gráfico del sistema.
// =============================================================================

/// La rueda de nacimiento. `reg-nacimiento`.
public struct RuedaDeNacimiento: View {
    @Binding private var fecha: Date
    /// Una línea debajo de la rueda; sin nota no ocupa lugar.
    private let nota: String?

    /// El diseño ofrece de 1945 hasta hace 12 años. El techo no es estético:
    /// abajo de esa edad el producto necesita otro camino entero (AGENTS.md
    /// §9.2, menores), y ese camino no está construido.
    public static let anioMinimo = 1945
    public static let edadMinima = 12

    public init(fecha: Binding<Date>, nota: String? = nil) {
        self._fecha = fecha
        self.nota = nota
    }

    public var body: some View {
        VStack(spacing: TokensEspaciado.e8) {
            // Rediseño 2026-10: la rueda vive dentro de una tarjeta oscura, como
            // el selector de fecha del mockup.
            DatePicker("", selection: $fecha, in: Self.rango, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyleRueda()
                .padding(.horizontal, TokensEspaciado.e8)
                .padding(.vertical, TokensEspaciado.e4)
                .frame(maxWidth: .infinity)
                .tarjetaDeFecha()

            if let nota {
                Text(nota)
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    static var rango: ClosedRange<Date> {
        let cal = Calendar(identifier: .gregorian)
        let desde = cal.date(from: DateComponents(year: anioMinimo, month: 1, day: 1)) ?? .distantPast
        let hasta = cal.date(byAdding: .year, value: -edadMinima, to: Date()) ?? Date()
        return desde...max(desde, hasta)
    }
}

extension View {
    /// La tarjeta oscura de los dos selectores: mismo radio y borde que las
    /// opciones del registro.
    fileprivate func tarjetaDeFecha() -> some View {
        background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
    }

    @ViewBuilder
    func datePickerStyleRueda() -> some View {
        #if os(iOS)
        self.datePickerStyle(.wheel)
        #else
        self.datePickerStyle(.field)
        #endif
    }
}

// -----------------------------------------------------------------------------

/// El calendario mensual compacto del objetivo. `reg-objetivo`.
///
/// La semana empieza el lunes, como el diseño, **y como el locale mande**: en
/// es-AR y en-GB el lunes es el primer día; en en-US es el domingo. Se toma del
/// calendario del sistema en vez de fijarlo (AGENTS.md §10).
public struct CalendarioMes: View {
    @Binding private var seleccionada: Date?
    @State private var mesVisible: Date
    private let etiquetaMesAnterior: String
    private let etiquetaMesSiguiente: String

    private let calendario: Calendar

    public init(
        seleccionada: Binding<Date?>,
        etiquetaMesAnterior: String,
        etiquetaMesSiguiente: String,
        calendario: Calendar = .autoupdatingCurrent
    ) {
        self._seleccionada = seleccionada
        self.etiquetaMesAnterior = etiquetaMesAnterior
        self.etiquetaMesSiguiente = etiquetaMesSiguiente
        self.calendario = calendario
        _mesVisible = State(initialValue: seleccionada.wrappedValue ?? Date())
    }

    public var body: some View {
        VStack(spacing: TokensEspaciado.e11) {
            encabezado
            grilla
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity)
        .tarjetaDeFecha()
    }

    private var encabezado: some View {
        HStack {
            botonDeMes(-1, sistema: "chevron.left", etiqueta: etiquetaMesAnterior)
            Spacer()
            Text(tituloDelMes).estilo(.tituloSeccion)
            Spacer()
            botonDeMes(1, sistema: "chevron.right", etiqueta: etiquetaMesSiguiente)
        }
    }

    private func botonDeMes(_ delta: Int, sistema: String, etiqueta: String) -> some View {
        Button {
            if let nuevo = calendario.date(byAdding: .month, value: delta, to: mesVisible) {
                mesVisible = nuevo
            }
        } label: {
            Image(systemName: sistema)
                .font(.system(size: TokensTipografia.tituloCardTamano,
                              weight: TokensTipografia.tituloCardPeso))
                .foregroundStyle(Paleta.textoSecundario)
                .frame(width: TokensTamano.botonCircularCalendario,
                       height: TokensTamano.botonCircularCalendario)
                .background(Paleta.superficieAlterna)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
                // Las flechas del diseño miden 30 pt (ESPECIFICACION §9.2). Se
                // dibujan igual y responden en 48.
                .objetivoTactil()
        }
        .accessibilityLabel(etiqueta)
    }

    private var grilla: some View {
        VStack(spacing: TokensEspaciado.e2) {
            HStack(spacing: TokensEspaciado.e2) {
                ForEach(Array(nombresDeDias.enumerated()), id: \.offset) { _, nombre in
                    Text(nombre)
                        .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            ForEach(Array(semanas.enumerated()), id: \.offset) { _, semana in
                HStack(spacing: TokensEspaciado.e2) {
                    ForEach(Array(semana.enumerated()), id: \.offset) { _, dia in
                        celda(dia)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func celda(_ dia: Date?) -> some View {
        if let dia {
            let pasada = calendario.startOfDay(for: dia) < calendario.startOfDay(for: Date())
            let elegida = seleccionada.map { calendario.isDate($0, inSameDayAs: dia) } ?? false
            Button {
                seleccionada = elegida ? nil : dia
            } label: {
                Text(dia.formatted(.dateTime.day()))
                    .estilo(.cuerpoSecundario,
                            color: elegida ? Paleta.sobreAcento
                                : (pasada ? Paleta.textoTerciario : Paleta.textoCuerpo))
                    .frame(maxWidth: .infinity)
                    // El diseño dibuja celdas de 34 pt. Crecen en alto hasta el
                    // mínimo táctil: a lo ancho no se puede sin desbordar siete
                    // columnas, y es el caso que ESPECIFICACION §9.2 describe
                    // como "crece la fila".
                    .frame(height: TokensTamano.objetivoTactilMinimo)
                    .background(elegida ? Paleta.acento : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
                    .shadow(color: elegida ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e8)
                    // Sin esto, un día NO elegido es relleno transparente y no
                    // se puede tocar: sólo respondería el número.
                    .contentShape(Rectangle())
            }
            .disabled(pasada)
            .accessibilityLabel(dia.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
        } else {
            Color.clear.frame(height: TokensTamano.objetivoTactilMinimo)
        }
    }

    // MARK: - Cuentas del mes

    private var tituloDelMes: String {
        let t = mesVisible.formatted(.dateTime.month(.wide).year())
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    /// Los nombres cortos de los días, empezando por el primer día de la semana
    /// del locale.
    private var nombresDeDias: [String] {
        let formateador = DateFormatter()
        formateador.locale = calendario.locale ?? .autoupdatingCurrent
        let cortos: [String] = formateador.veryShortWeekdaySymbols ?? []
        guard cortos.count == 7 else { return cortos }
        let primero = calendario.firstWeekday - 1
        return Array(cortos[primero...] + cortos[..<primero])
    }

    /// Las semanas del mes visible, con `nil` en los huecos de los extremos.
    private var semanas: [[Date?]] {
        guard
            let rango = calendario.range(of: .day, in: .month, for: mesVisible),
            let primero = calendario.date(
                from: calendario.dateComponents([.year, .month], from: mesVisible))
        else { return [] }

        let desplazamiento =
            (calendario.component(.weekday, from: primero) - calendario.firstWeekday + 7) % 7

        var celdas: [Date?] = Array(repeating: nil, count: desplazamiento)
        for offset in 0..<rango.count {
            celdas.append(calendario.date(byAdding: .day, value: offset, to: primero))
        }
        while celdas.count % 7 != 0 { celdas.append(nil) }

        return stride(from: 0, to: celdas.count, by: 7).map { Array(celdas[$0..<$0 + 7]) }
    }
}

#endif
