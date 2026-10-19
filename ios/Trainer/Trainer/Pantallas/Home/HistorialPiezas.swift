import SwiftUI
import TrainerCore

// =============================================================================
// Piezas del historial (rediseño 2026-10, ronda 3): el resumen con su selector
// Semana | Mes | Todo, los chips de deporte, el encabezado de cada mes y el
// estado vacío que enseña qué hacer. Todo se calcula sobre lo que ya se cargó
// del servidor: nada pide red de más.
// =============================================================================

// MARK: - Cálculos

enum HistorialFormato {
    /// El idioma de la app, no el del sistema (igual que el calendario).
    static var idioma: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
    }

    /// Semanas de lunes a domingo, como el mapa de calor.
    static var calendario: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    static func fecha(_ actividad: Actividad) -> Date {
        Date(timeIntervalSince1970: Double(actividad.startedAtMs) / 1000)
    }

    /// Ritmo (o velocidad, en bici) promedio con su unidad. `nil` si no hay
    /// distancia suficiente para que el número sea honesto.
    static func ritmoOVelocidad(_ actividad: Actividad, unidades: SistemaDeUnidades) -> String? {
        let metros = Int(actividad.distanceM ?? 0)
        let segundos = Int(actividad.durationS)
        if actividad.sport == .ciclismo {
            guard metros >= 50, segundos > 0 else { return nil }
            return Formato.velocidad(metros: metros, segundos: segundos, unidades: unidades)
        }
        guard let ritmo = ResumenFormato.ritmoMedio(metros: metros, segundos: segundos) else { return nil }
        return "\(Formato.ritmo(segundosPorKm: ritmo, unidades: unidades)) \(ResumenFormato.unidadDeRitmo(unidades))"
    }

    /// Un tiempo acumulado partido en número y unidad: ("5:20", "h") o ("45", "min").
    static func tiempoAcumulado(segundos: Int) -> (valor: String, unidad: String) {
        let horas = segundos / 3600
        let minutos = (segundos % 3600) / 60
        if horas > 0 {
            return ("\(horas):\(String(format: "%02d", minutos))", "h")
        }
        return ("\(minutos)", "min")
    }

    /// "Octubre 2026": el mes suelto, sin el "de" del formato largo.
    static func mesYAnio(_ fecha: Date) -> String {
        let df = DateFormatter()
        df.locale = idioma
        df.dateFormat = "LLLL yyyy"
        let texto = df.string(from: fecha)
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    static func cantidadDeSalidas(_ cantidad: Int) -> String {
        cantidad == 1
            ? String(localized: "1 salida", comment: "Historial: cantidad de salidas")
            : String(localized: "\(cantidad) salidas", comment: "Historial: cantidad de salidas")
    }
}

/// Animar sólo si la persona no pidió reducir el movimiento.
enum HistorialMovimiento {
    static func animar(_ reducido: Bool, _ cambio: () -> Void) {
        if reducido {
            cambio()
        } else {
            withAnimation(.easeInOut(duration: TokensMovimiento.rapida), cambio)
        }
    }
}

/// Distancia, cantidad y tiempo de un grupo de actividades.
struct HistorialTotales {
    let metros: Int
    let sesiones: Int
    let segundos: Int

    init(_ actividades: [Actividad]) {
        metros = actividades.reduce(0) { $0 + Int($1.distanceM ?? 0) }
        sesiones = actividades.count
        segundos = actividades.reduce(0) { $0 + Int($1.durationS) }
    }
}

// MARK: - Período del resumen

enum HistorialPeriodo: String, CaseIterable, Identifiable {
    case semana, mes, todo

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .semana: return String(localized: "Semana", comment: "Historial: período del resumen")
        case .mes: return String(localized: "Mes", comment: "Historial: período del resumen")
        case .todo: return String(localized: "Todo", comment: "Historial: período del resumen")
        }
    }

    /// Qué cuenta, dicho en palabras, para debajo de las tarjetas.
    var explicacion: String {
        switch self {
        case .semana: return String(localized: "Desde el lunes hasta hoy", comment: "Historial: qué abarca el resumen semanal")
        case .mes: return String(localized: "Desde el 1 de este mes", comment: "Historial: qué abarca el resumen mensual")
        case .todo: return String(localized: "Todas tus salidas", comment: "Historial: qué abarca el resumen total")
        }
    }

    /// Desde cuándo cuenta. `nil`: sin límite.
    func inicio(hoy: Date = Date()) -> Date? {
        let cal = HistorialFormato.calendario
        switch self {
        case .semana: return cal.dateInterval(of: .weekOfYear, for: hoy)?.start
        case .mes: return cal.dateInterval(of: .month, for: hoy)?.start
        case .todo: return nil
        }
    }
}

/// "Semana | Mes | Todo": una cápsula con el segmento elegido en el acento.
struct HistorialSelectorDePeriodo: View {
    @Binding var periodo: HistorialPeriodo
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @Namespace private var espacio

    var body: some View {
        HStack(spacing: TokensEspaciado.e4) {
            ForEach(HistorialPeriodo.allCases) { opcion in
                segmento(opcion)
            }
        }
        .padding(TokensEspaciado.e4)
        .background(Paleta.superficieAlterna)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
    }

    private func segmento(_ opcion: HistorialPeriodo) -> some View {
        let elegida = opcion == periodo
        return Button {
            guard opcion != periodo else { return }
            Haptico.seleccion()
            HistorialMovimiento.animar(movimientoReducido) { periodo = opcion }
        } label: {
            Text(opcion.titulo)
                .estilo(.chip, color: elegida ? Paleta.sobreAcento : Paleta.textoSecundario)
                .frame(maxWidth: .infinity)
                .frame(minHeight: TokensEspaciado.e40)
                .background {
                    if elegida {
                        Capsule()
                            .fill(Paleta.acento)
                            .matchedGeometryEffect(id: "segmento", in: espacio)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Franja de resumen

/// Lo de arriba del historial: el selector y tres tarjetas (distancia, salidas,
/// tiempo) del período elegido.
struct HistorialFranjaDeResumen: View {
    /// Ya filtradas por deporte.
    let actividades: [Actividad]
    let deporte: DeporteDeSesion?
    let unidades: SistemaDeUnidades
    /// Si el servidor tiene más páginas: el total puede quedarse corto.
    let hayMasPorCargar: Bool
    @Binding var periodo: HistorialPeriodo

    private var desdeMs: Int64? {
        periodo.inicio().map { Int64($0.timeIntervalSince1970 * 1000) }
    }

    private var delPeriodo: [Actividad] {
        guard let desdeMs else { return actividades }
        return actividades.filter { $0.startedAtMs >= desdeMs }
    }

    /// Lo cargado no llega hasta el principio del período: la suma es parcial.
    private var esParcial: Bool {
        guard hayMasPorCargar else { return false }
        guard let desdeMs else { return true }
        let masVieja = actividades.map(\.startedAtMs).min() ?? Int64.max
        return masVieja >= desdeMs
    }

    var body: some View {
        let totales = HistorialTotales(delPeriodo)
        let tiempo = HistorialFormato.tiempoAcumulado(segundos: totales.segundos)
        return VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(String(localized: "Tus números", comment: "Historial: título del resumen"),
                                detalle: deporte?.nombreVisible)

            HistorialSelectorDePeriodo(periodo: $periodo)

            HStack(spacing: TokensEspaciado.e8) {
                TarjetaMetrica(String(localized: "Distancia", comment: "Historial: resumen"),
                               valor: Formato.distanciaNumero(totales.metros, unidades: unidades),
                               unidad: Formato.unidadDeDistancia(unidades),
                               simbolo: "map", destacada: true)
                TarjetaMetrica(String(localized: "Salidas", comment: "Historial: resumen, cantidad de actividades"),
                               valor: "\(totales.sesiones)", simbolo: "figure.run")
                TarjetaMetrica(String(localized: "Tiempo", comment: "Historial: resumen, tiempo acumulado"),
                               valor: tiempo.valor, unidad: tiempo.unidad, simbolo: "clock")
            }

            Text(esParcial
                 ? String(localized: "\(periodo.explicacion). Suma lo cargado hasta ahora: tocá «Cargar más» abajo para sumar las anteriores.",
                          comment: "Historial: aviso de que el total es parcial")
                 : periodo.explicacion)
                .estilo(.labelCampo, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Chips de deporte

/// "Todos" y un chip por cada deporte que aparece en lo cargado.
struct HistorialChipsDeDeporte: View {
    let deportes: [DeporteDeSesion]
    @Binding var elegido: DeporteDeSesion?
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TokensEspaciado.e8) {
                chip(String(localized: "Todos", comment: "Historial: filtro sin deporte"), deporte: nil)
                ForEach(deportes, id: \.self) { deporte in
                    chip(deporte.nombreVisible, deporte: deporte)
                }
            }
            .padding(.vertical, TokensEspaciado.e2)
        }
    }

    private func chip(_ titulo: String, deporte: DeporteDeSesion?) -> some View {
        let activo = elegido == deporte
        return Button {
            guard !activo else { return }
            Haptico.seleccion()
            HistorialMovimiento.animar(movimientoReducido) { elegido = deporte }
        } label: {
            HStack(spacing: TokensEspaciado.e6) {
                if let deporte {
                    IconoDeporte(deporte: deporte, color: activo ? Paleta.sobreAcento : Paleta.acento,
                                 tamano: TokensEspaciado.e14)
                        .accessibilityHidden(true)
                }
                Text(titulo)
                    .estilo(.chip, color: activo ? Paleta.sobreAcento : Paleta.textoPrimario)
                    .lineLimit(1)
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .frame(minHeight: TokensEspaciado.e36)
            .background(activo ? Paleta.acento : Paleta.superficie)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(activo ? Color.clear : Paleta.bordeSuperficie,
                                            lineWidth: TokensEspaciado.e1))
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(titulo)
        .accessibilityAddTraits(activo ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Agrupado por mes

struct HistorialGrupoDeMes: Identifiable {
    /// "2026-10".
    let id: String
    let inicio: Date
    let actividades: [Actividad]

    var metros: Int { actividades.reduce(0) { $0 + Int($1.distanceM ?? 0) } }

    /// De la más nueva a la más vieja, un grupo por mes.
    static func agrupar(_ actividades: [Actividad]) -> [HistorialGrupoDeMes] {
        let cal = HistorialFormato.calendario
        var orden: [String] = []
        var inicios: [String: Date] = [:]
        var porMes: [String: [Actividad]] = [:]
        for actividad in actividades.sorted(by: { $0.startedAtMs > $1.startedAtMs }) {
            let fecha = HistorialFormato.fecha(actividad)
            let partes = cal.dateComponents([.year, .month], from: fecha)
            let clave = "\(partes.year ?? 0)-\(partes.month ?? 0)"
            if porMes[clave] == nil {
                orden.append(clave)
                inicios[clave] = cal.date(from: partes) ?? fecha
                porMes[clave] = []
            }
            porMes[clave, default: []].append(actividad)
        }
        return orden.map { clave in
            HistorialGrupoDeMes(id: clave, inicio: inicios[clave] ?? Date(), actividades: porMes[clave] ?? [])
        }
    }
}

/// "Octubre 2026 · 42 km" y a la derecha cuántas salidas. Queda pegado arriba
/// mientras se recorre el mes (fondo opaco para que la lista pase por debajo).
struct HistorialEncabezadoDeMes: View {
    let grupo: HistorialGrupoDeMes
    let unidades: SistemaDeUnidades

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e6) {
            Text(HistorialFormato.mesYAnio(grupo.inicio))
                .estilo(.tituloSeccion)
            Text("· \(Formato.distancia(grupo.metros, unidades: unidades))")
                .estilo(.labelCampo, color: Paleta.textoAcento)
            Spacer(minLength: TokensEspaciado.e8)
            Text(HistorialFormato.cantidadDeSalidas(grupo.actividades.count))
                .estilo(.labelCampo, color: Paleta.textoTerciario)
        }
        .lineLimit(1)
        .padding(.vertical, TokensEspaciado.e8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.fondo)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Vacío y error

/// Sin salidas: qué hacer para tener la primera. Con error: reintentar.
struct HistorialEstadoVacio: View {
    let fallo: Bool
    let reintentar: () -> Void
    /// `nil` si desde acá no se puede ir al entreno.
    let empezar: (() -> Void)?

    var body: some View {
        if fallo {
            error
        } else {
            vacio
        }
    }

    private var error: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            HStack(spacing: TokensEspaciado.e12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: TokensEspaciado.e20, weight: .semibold))
                    .foregroundStyle(Paleta.error)
                    .accessibilityHidden(true)
                Text(Textos.historialError)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BotonTonal(String(localized: "Reintentar", comment: "Historial: volver a pedir la lista")) {
                Haptico.toque()
                reintentar()
            }
        }
        .padding(TokensEspaciado.e14)
        .resumenTarjeta()
    }

    private var vacio: some View {
        VStack(spacing: TokensEspaciado.e12) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                Circle().strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1)
                Image(systemName: "bolt.fill")
                    .font(.system(size: TokensEspaciado.e26, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(width: TokensEspaciado.e56, height: TokensEspaciado.e56)
            .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e12)
            .accessibilityHidden(true)

            Text(String(localized: "Todavía no hay salidas", comment: "Historial vacío: título"))
                .estilo(.tituloCardGrande)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Tocá ⚡ para empezar la primera. Cuando la termines, aparece acá con su mapa, sus parciales y sus pausas.",
                        comment: "Historial vacío: qué hacer"))
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let empezar {
                BotonPrimario(String(localized: "Empezar mi primera salida", comment: "Historial vacío: botón al entreno")) {
                    Haptico.toque()
                    empezar()
                }
                .padding(.top, TokensEspaciado.e4)
            }
        }
        .padding(TokensEspaciado.e20)
        .frame(maxWidth: .infinity)
        .resumenTarjeta()
    }
}
