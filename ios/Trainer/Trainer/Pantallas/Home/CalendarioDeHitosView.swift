import SwiftUI
import TrainerCore

/// El año entrenado, como el gráfico de contribuciones de GitHub (decisión de Iván
/// del 2026-10-23):
///
///   arriba, los años que tuvo la cuenta ("2026 · 2025 · 2024"), el elegido resaltado
///   "2026 · 412 km · 86 entrenamientos"
///   el gráfico de ENERO A DICIEMBRE del año elegido (no "los últimos 12 meses"): una
///     columna por semana, una fila por día de lunes a domingo, más intenso cuanto
///     más se entrenó. Los días escritos a la izquierda quedan quietos al deslizar.
///     Los días antes de la cuenta y los que no llegaron, vacíos; los de carrera, en
///     amarillo (también los que vienen)
///   "Carrera ▢ · Menos ▢▢▢▢▢ Más"
///   el día elegido: su título, los pasos y todo lo que se entrenó ese día
///
/// Al entrar, el día elegido es HOY (antes elegía ayer) y el gráfico queda corrido
/// hasta la semana de hoy. La intensidad es la de `AlmacenDeHitos.nivelDeActividad`.
struct CalendarioDeHitosView: View {
    @ObservedObject private var almacen = AlmacenDeHitos.compartido
    /// Si los pasos vienen solos de Salud (y no se editan) o se cargan a mano.
    @ObservedObject private var sincronizadorDePasos = SincronizadorDePasos.compartido
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido

    /// Km o millas, lo que eligió la persona (lo pasa el historial).
    let unidades: SistemaDeUnidades
    /// Cuándo se creó la cuenta (`created_at_ms` de `GET /me`): los años de arriba
    /// arrancan ahí, y los días anteriores van vacíos. Sin dato, sólo el año actual.
    let fechaDeAlta: Date?
    /// Los días de carrera (la fecha de cada objetivo), con el nombre del objetivo,
    /// por clave de `AlmacenDeHitos.clave(para:)`.
    let carreras: [String: String]
    /// Las sesiones de gimnasio, por día: cuántas series se hicieron.
    let gimnasioPorDia: [String: Int]

    init(unidades: SistemaDeUnidades, fechaDeAlta: Date?, carreras: [String: String], gimnasioPorDia: [String: Int]) {
        self.unidades = unidades
        self.fechaDeAlta = fechaDeAlta
        self.carreras = carreras
        self.gimnasioPorDia = gimnasioPorDia
    }

    @State private var anio = Calendar.current.component(.year, from: Date())
    @State private var fechaSeleccionada = Calendar.current.startOfDay(for: Date())
    @State private var actividadElegida: Actividad?
    @State private var mostrandoEditorPasos = false
    @State private var textoPasosInput = ""

    /// El lado de una celda y el hueco entre celdas.
    private let celda = TokensEspaciado.e14
    private let hueco = TokensEspaciado.e3

    private static var idioma: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
    }

    private var anioActual: Int { Calendar.current.component(.year, from: Date()) }

    /// Del actual hacia atrás, hasta el de la cuenta: "2026 · 2025 · 2024".
    private var anios: [Int] {
        let deAlta = fechaDeAlta.map { Calendar.current.component(.year, from: $0) } ?? anioActual
        return Array((min(deAlta, anioActual)...anioActual).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            selectorDeAnio
            Text(totalDelAnio)
                .estilo(.labelCampo, color: Paleta.textoSecundario)
                .monospacedDigit()
            grafico
            leyenda
            Rectangle().fill(Paleta.divisor).frame(height: TokensEspaciado.e1).accessibilityHidden(true)
            detalleDelDia
        }
        .padding(TokensEspaciado.e16)
        .tarjeta()
        .task(id: anio) {
            // Salud para el año que se mira (pide el permiso la primera vez) y el
            // servidor para lo que Salud no tenga, como en un teléfono nuevo.
            let semanas = semanas(de: anio)
            let inicio = semanas.first?.compactMap { $0 }.first ?? Date()
            await sincronizadorDePasos.alVerPasos(desde: inicio, hasta: min(Date(), semanas.last?.compactMap { $0 }.last ?? Date()))
        }
        .sheet(item: $actividadElegida) { actividad in
            DetalleDeActividadView(
                actividad: actividad,
                puntosIniciales: AlmacenDeRecorridos.compartido.puntos(para: actividad.id),
                servicio: nil,
                unidades: unidades
            )
        }
        .alertaApilada(Textos.milestonesStepsLog, isPresented: $mostrandoEditorPasos,
                       mensaje: Textos.milestonesStepsPrompt,
                       campo: CampoDeAlerta(Textos.milestonesStepsCount, texto: $textoPasosInput,
                                            teclado: .numero),
                       botones: [
                           BotonDeAlerta(Textos.commonSave) {
                               if let cant = Int(textoPasosInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                   almacen.guardarPasos(cant, para: fechaSeleccionada)
                                   Task { await sincronizadorDePasos.subirPendientes() }
                               }
                           },
                           BotonDeAlerta(Textos.commonCancel, rol: .cancelar),
                       ])
    }

    // MARK: - Los años

    private var selectorDeAnio: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TokensEspaciado.e6) {
                ForEach(anios, id: \.self) { valor in
                    let elegido = valor == anio
                    Button {
                        guard !elegido else { return }
                        Haptico.seleccion()
                        HistorialMovimiento.animar(movimientoReducido) { elegirAnio(valor) }
                    } label: {
                        Text(verbatim: "\(valor)")
                            .estilo(.tituloCard, color: elegido ? Paleta.sobreAcento : Paleta.textoSecundario)
                            .monospacedDigit()
                            .padding(.horizontal, TokensEspaciado.e14)
                            .frame(minHeight: TokensEspaciado.e36)
                            .background(Capsule().fill(elegido ? Paleta.acento : Paleta.superficieAlterna))
                            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloPresionado())
                    .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    /// Cambiar de año elige hoy (si es el actual) o el último día de ese año.
    private func elegirAnio(_ nuevo: Int) {
        anio = nuevo
        let cal = Calendar.current
        if nuevo == anioActual {
            fechaSeleccionada = cal.startOfDay(for: Date())
        } else if let fin = cal.date(from: DateComponents(year: nuevo, month: 12, day: 31)) {
            fechaSeleccionada = fin
        }
    }

    /// "2026 · 412 km · 86 entrenamientos", con lo registrado ese año.
    private var totalDelAnio: String {
        let cal = Calendar.current
        let delAnio = almacen.todasLasActividades.filter {
            cal.component(.year, from: HistorialFormato.fecha($0)) == anio
        }
        let metros = delAnio.reduce(0) { $0 + Int($1.distanceM ?? 0) }
        let cantidad = delAnio.count == 1 ? Textos.historyTrainingsOne : Textos.historyTrainingsCount(delAnio.count)
        return Textos.historyYearTotal(anio, Formato.distancia(metros, unidades: unidades, decimales: 0), cantidad)
    }

    // MARK: - El gráfico

    /// Las semanas del año, de lunes a domingo. `nil` es un día de otro año (la
    /// primera y la última semana quedan incompletas).
    private func semanas(de anio: Int) -> [[Date?]] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        guard let primero = cal.date(from: DateComponents(year: anio, month: 1, day: 1)),
              let ultimo = cal.date(from: DateComponents(year: anio, month: 12, day: 31)) else { return [] }
        // El lunes de la semana del 1 de enero (weekday: 1 = domingo, 2 = lunes…).
        let atras = (cal.component(.weekday, from: primero) + 5) % 7
        guard var lunes = cal.date(byAdding: .day, value: -atras, to: primero) else { return [] }
        var resultado: [[Date?]] = []
        while lunes <= ultimo {
            var semana: [Date?] = []
            for i in 0..<7 {
                let dia = cal.date(byAdding: .day, value: i, to: lunes)
                semana.append(dia.flatMap { cal.component(.year, from: $0) == anio ? $0 : nil })
            }
            resultado.append(semana)
            guard let siguiente = cal.date(byAdding: .day, value: 7, to: lunes) else { break }
            lunes = siguiente
        }
        return resultado
    }

    private var grafico: some View {
        let semanas = semanas(de: anio)
        let indiceDeHoy = semanas.firstIndex { $0.contains { $0.map(Calendar.current.isDateInToday) ?? false } }
        return HStack(alignment: .top, spacing: TokensEspaciado.e6) {
            // Fijos: no se van con el gráfico.
            columnaDeDias
            ScrollViewReader { lector in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: hueco) {
                        ForEach(Array(semanas.enumerated()), id: \.offset) { indice, semana in
                            VStack(spacing: hueco) {
                                etiquetaDeMes(semana)
                                ForEach(0..<7, id: \.self) { fila in
                                    celdaDia(semana[fila])
                                }
                            }
                            .id(indice)
                        }
                    }
                    .padding(.vertical, TokensEspaciado.e2)
                }
                .onAppear { correr(lector, a: indiceDeHoy ?? (anio == anioActual ? semanas.count - 1 : 0)) }
                .onChange(of: anio) { _ in
                    correr(lector, a: anio == anioActual ? (indiceDeHoy ?? semanas.count - 1) : semanas.count - 1)
                }
            }
        }
    }

    private func correr(_ lector: ScrollViewProxy, a indice: Int) {
        DispatchQueue.main.async { lector.scrollTo(indice, anchor: .center) }
    }

    /// "Lun" a "Dom", del calendario en el idioma de la app.
    private var columnaDeDias: some View {
        VStack(alignment: .leading, spacing: hueco) {
            Color.clear.frame(height: TokensEspaciado.e14)
            ForEach(1...7, id: \.self) { dia in
                Text(PlanFechas.diaCorto(dia))
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                    .lineLimit(1)
                    .frame(height: celda)
            }
        }
        .accessibilityHidden(true)
    }

    /// El mes, arriba de la semana en la que empieza.
    @ViewBuilder
    private func etiquetaDeMes(_ semana: [Date?]) -> some View {
        if let primero = semana.compactMap({ $0 }).first(where: { Calendar.current.component(.day, from: $0) == 1 }) {
            Text(nombreMes(primero))
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoSecundario)
                .fixedSize()
                .frame(width: celda, height: TokensEspaciado.e14, alignment: .leading)
        } else {
            Color.clear.frame(width: celda, height: TokensEspaciado.e14)
        }
    }

    @ViewBuilder
    private func celdaDia(_ dia: Date?) -> some View {
        if let dia {
            let cal = Calendar.current
            let clave = AlmacenDeHitos.clave(para: dia)
            let esCarrera = carreras[clave] != nil
            let vacio = dia > Date() || (fechaDeAlta.map { dia < cal.startOfDay(for: $0) } ?? false)
            let nivel = vacio ? 0 : almacen.nivelDeActividad(para: dia)
            let elegido = cal.isDate(dia, inSameDayAs: fechaSeleccionada)
            Button {
                guard !elegido else { return }
                Haptico.seleccion()
                HistorialMovimiento.animar(movimientoReducido) { fechaSeleccionada = cal.startOfDay(for: dia) }
            } label: {
                RoundedRectangle(cornerRadius: hueco, style: .continuous)
                    .fill(esCarrera ? Paleta.amarilloMedidor : color(nivel: nivel, vacio: vacio))
                    .frame(width: celda, height: celda)
                    .overlay(
                        RoundedRectangle(cornerRadius: hueco, style: .continuous)
                            .strokeBorder(elegido ? Paleta.textoPrimario : (cal.isDateInToday(dia) ? Paleta.acento : Color.clear),
                                          lineWidth: elegido ? TokensEspaciado.e2 : TokensEspaciado.e1)
                    )
            }
            .buttonStyle(.plain)
            // Lo que no llegó (o es de antes de la cuenta) no se elige, salvo una carrera.
            .disabled(vacio && !esCarrera)
            .accessibilityLabel(descripcion(dia: dia, nivel: nivel, esCarrera: esCarrera))
            .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
        } else {
            Color.clear.frame(width: celda, height: celda)
        }
    }

    private func color(nivel: Int, vacio: Bool) -> Color {
        if vacio { return Paleta.superficieAlterna.opacity(0.25) }
        switch nivel {
        case 1: return Paleta.acento.opacity(0.30)
        case 2: return Paleta.acento.opacity(0.55)
        case 3: return Paleta.acento.opacity(0.80)
        case 4: return Paleta.acento
        default: return Paleta.superficieAlterna.opacity(0.6)
        }
    }

    private func nombreMes(_ fecha: Date) -> String {
        let df = DateFormatter()
        df.locale = Self.idioma
        df.setLocalizedDateFormatFromTemplate("MMM")
        return df.string(from: fecha).replacingOccurrences(of: ".", with: "").capitalizedPrimeraLetra
    }

    private func descripcion(dia: Date, nivel: Int, esCarrera: Bool) -> String {
        let cantidad = almacen.actividades(para: dia).count
        var partes = [titulo(de: dia)]
        if esCarrera { partes.append(Textos.historyRaceDay) }
        partes.append(cantidad == 0 ? Textos.milestonesNoWorkouts : Textos.milestonesWorkoutsCount(cantidad))
        partes.append(Self.nombreDeNivel(nivel))
        return partes.joined(separator: ", ")
    }

    private static func nombreDeNivel(_ nivel: Int) -> String {
        switch nivel {
        case 1: return Textos.milestonesActivityLight
        case 2: return Textos.milestonesActivityModerate
        case 3: return Textos.milestonesActivityHigh
        case 4: return Textos.milestonesActivityVeryHigh
        default: return Textos.milestonesActivityNone
        }
    }

    // MARK: - La leyenda

    /// "▢ Carrera   Menos ▢▢▢▢▢ Más".
    private var leyenda: some View {
        HStack(spacing: TokensEspaciado.e6) {
            cuadrito(Paleta.amarilloMedidor)
            Text(Textos.historyRaceDay)
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
            Spacer(minLength: TokensEspaciado.e8)
            Text(Textos.commonLess)
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
            HStack(spacing: hueco) {
                ForEach(0..<5) { nivel in cuadrito(color(nivel: nivel, vacio: false)) }
            }
            Text(Textos.commonMore)
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
        }
        .accessibilityElement(children: .combine)
    }

    private func cuadrito(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: TokensRadio.minimo)
            .fill(color)
            .frame(width: TokensEspaciado.e10, height: TokensEspaciado.e10)
            .accessibilityHidden(true)
    }

    // MARK: - El día elegido

    private var detalleDelDia: some View {
        let clave = AlmacenDeHitos.clave(para: fechaSeleccionada)
        let entrenamientos = almacen.actividades(para: fechaSeleccionada)
        let series = gimnasioPorDia[clave] ?? 0
        let carrera = carreras[clave]
        return VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e8) {
                Text(carrera == nil ? titulo(de: fechaSeleccionada)
                                    : "\(titulo(de: fechaSeleccionada)) · \(Textos.historyRaceDay)")
                    .estilo(.tituloCard)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: TokensEspaciado.e8)
                pasos
            }

            if let carrera {
                HStack(spacing: TokensEspaciado.e8) {
                    cuadrito(Paleta.amarilloMedidor)
                    Text(Textos.historyRaceOfTheDay(carrera))
                        .estilo(.cuerpoDestacado)
                }
            }

            ForEach(entrenamientos, id: \.id) { actividad in
                filaEntrenamiento(actividad)
            }
            if series > 0 {
                filaSimple(simbolo: "dumbbell.fill", titulo: Textos.homeTabGym,
                           valor: series == 1 ? Textos.historyGymSetsOne : Textos.historyGymSets(series))
            }
            if entrenamientos.isEmpty, series == 0, carrera == nil {
                Text(Textos.milestonesNoWorkoutsDay)
                    .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
            }
        }
    }

    /// "9.412 pasos" y, si se cargan a mano, "Editar"; si vienen de Salud, de dónde.
    private var pasos: some View {
        let cantidad = almacen.pasos(para: fechaSeleccionada)
        return HStack(spacing: TokensEspaciado.e6) {
            if cantidad > 0 {
                Text(Textos.historySteps(Formato.pasos(cantidad)))
                    .estilo(.labelCampo, color: Paleta.textoSecundario)
                    .monospacedDigit()
            }
            if sincronizadorDePasos.modoAutomatico {
                if cantidad > 0 {
                    Image(systemName: "heart.fill")
                        .font(.system(size: TokensTipografia.chipTamano))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityLabel(Textos.milestonesStepsSourceAppleHealth)
                }
            } else if fechaSeleccionada <= Date() {
                Button {
                    textoPasosInput = cantidad > 0 ? "\(cantidad)" : ""
                    mostrandoEditorPasos = true
                } label: {
                    Text(cantidad > 0 ? Textos.commonEdit : Textos.milestonesStepsLog)
                        .estilo(.chip, color: Paleta.textoAcento)
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
            }
        }
    }

    /// "Running · 8,02 km · 46:21": cada entrenamiento con su dato principal.
    private func filaEntrenamiento(_ actividad: Actividad) -> some View {
        var partes: [String] = []
        if let metros = actividad.distanceM, metros > 0 {
            partes.append(Formato.distancia(Int(metros), unidades: unidades, decimales: 2))
        }
        partes.append(Formato.cronometro(segundos: Int(actividad.durationS)))
        return Button {
            Haptico.toque()
            actividadElegida = actividad
        } label: {
            filaSimple(icono: actividad.sport, titulo: actividad.sport.nombreVisible,
                       valor: partes.joined(separator: " · "), conFlecha: true)
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityHint(Textos.historyRowHint)
    }

    private func filaSimple(simbolo: String? = nil, icono: DeporteDeSesion? = nil, titulo: String, valor: String,
                            conFlecha: Bool = false) -> some View {
        HStack(spacing: TokensEspaciado.e10) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                if let icono {
                    IconoDeporte(deporte: icono, color: Paleta.acento, tamano: TokensEspaciado.e14)
                } else if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                }
            }
            .frame(width: TokensEspaciado.e34, height: TokensEspaciado.e34)
            .accessibilityHidden(true)
            Text(titulo).estilo(.cuerpoDestacado)
            Spacer(minLength: TokensEspaciado.e8)
            Text(valor)
                .estilo(.labelCampo, color: Paleta.textoSecundario)
                .monospacedDigit()
            if conFlecha {
                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                    .foregroundStyle(Paleta.textoTerciario)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "Hoy · jueves 22 de octubre" o "Sábado 17 de octubre".
    private func titulo(de fecha: Date) -> String {
        let df = DateFormatter()
        df.locale = Self.idioma
        df.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        let texto = df.string(from: fecha)
        if Calendar.current.isDateInToday(fecha) { return "\(Textos.commonToday) · \(texto)" }
        return texto.capitalizedPrimeraLetra
    }
}
