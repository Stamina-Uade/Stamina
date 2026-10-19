import SwiftUI
import TrainerCore

/// Calendario de hitos estilo GitHub (el gráfico de contribuciones del año).
/// Muestra los días entrenados de las últimas 52 semanas con niveles de intensidad del acento.
/// Permite tocar cualquier día para inspeccionar los pasos guardados y la lista de entrenamientos
/// realizados en esa jornada (por ejemplo, 1 km corriendo y 2 km corriendo en un mismo día).
struct CalendarioDeHitosView: View {
    @ObservedObject private var almacen = AlmacenDeHitos.compartido
    @State private var fechaSeleccionada: Date = {
        // Por defecto seleccionar ayer si tiene entrenamientos o hoy
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }()

    @State private var actividadElegidaParaDetalle: Actividad? = nil
    @State private var mostrandoEditorPasos: Bool = false
    @State private var textoPasosInput: String = ""

    /// El lado de una celda del mapa de calor y el hueco entre celdas.
    private let celda = TokensEspaciado.e12
    private let hueco = TokensEspaciado.e3

    /// El idioma de la app, no el del sistema: los nombres de días y meses tienen
    /// que coincidir con el resto de los textos.
    private static var idioma: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
    }

    private static var calendarioLocal: Calendar {
        var cal = Calendar.current
        cal.locale = idioma
        return cal
    }

    // Estructura de semanas calculada para los últimos 364 días (52 semanas)
    private var semanasDelAnio: [[Date]] {
        let cal = Calendar.current
        let hoy = cal.startOfDay(for: Date())

        // Encontrar el inicio de la semana actual (Lunes)
        let diaSemanaHoy = cal.component(.weekday, from: hoy) // 1=Dom, 2=Lun, ... 7=Sáb
        let offsetLunes = (diaSemanaHoy == 1) ? -6 : (2 - diaSemanaHoy)
        guard let lunesEstaSemana = cal.date(byAdding: .day, value: offsetLunes, to: hoy) else {
            return []
        }

        // Retroceder 51 semanas para tener un total de 52 semanas
        guard let primerLunes = cal.date(byAdding: .weekOfYear, value: -51, to: lunesEstaSemana) else {
            return []
        }

        var semanas: [[Date]] = []
        for semanaIdx in 0..<52 {
            guard let inicioSemana = cal.date(byAdding: .weekOfYear, value: semanaIdx, to: primerLunes) else { continue }
            var diasSemana: [Date] = []
            for diaIdx in 0..<7 {
                if let dia = cal.date(byAdding: .day, value: diaIdx, to: inicioSemana) {
                    diasSemana.append(dia)
                }
            }
            semanas.append(diasSemana)
        }
        return semanas
    }

    /// Los nombres cortos de lunes a domingo, del calendario en el idioma de la app.
    private var nombresDeDias: [String] {
        let simbolos = Self.calendarioLocal.shortWeekdaySymbols // arranca en domingo
        guard simbolos.count == 7 else { return [] }
        return Array(simbolos[1...]) + [simbolos[0]]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
            encabezado
            resumenEstadisticas
            graficoMatrizGitHub
            leyendaYAyuda
            divisor
            inspectorDelDiaSeleccionado
        }
        .padding(TokensEspaciado.e16)
        .tarjeta()
        .sheet(item: $actividadElegidaParaDetalle) { actividad in
            DetalleDeActividadView(
                actividad: actividad,
                puntosIniciales: AlmacenDeRecorridos.compartido.puntos(para: actividad.id),
                servicio: nil
            )
        }
        .alert("Registrar pasos", isPresented: $mostrandoEditorPasos) {
            TextField("Cantidad de pasos", text: $textoPasosInput)
                .keyboardType(.numberPad)
            Button("Guardar") {
                if let cant = Int(textoPasosInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    almacen.guardarPasos(cant, para: fechaSeleccionada)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Ingresá la cantidad de pasos para el día seleccionado:")
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack(alignment: .center, spacing: TokensEspaciado.e8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: TokensEspaciado.e16, weight: .bold))
                .foregroundStyle(Paleta.acento)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e1) {
                Text(String(localized: "Tu año", comment: "Título del calendario de hitos"))
                    .estilo(.tituloSeccion)
                    .accessibilityAddTraits(.isHeader)
                Text("Hitos y entrenamientos estilo GitHub")
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
            }

            Spacer()

            PildoraDeEstado(Date().formatted(.dateTime.year().locale(Self.idioma)), tono: .acento)
        }
    }

    // MARK: - Resumen de Estadísticas Anuales

    private var resumenEstadisticas: some View {
        let stats = almacen.resumenAnual()
        let columnas = [GridItem(.flexible(), spacing: TokensEspaciado.e8),
                        GridItem(.flexible(), spacing: TokensEspaciado.e8)]
        return LazyVGrid(columns: columnas, spacing: TokensEspaciado.e8) {
            TarjetaMetrica(String(localized: "Sesiones", comment: "Calendario de hitos"), valor: "\(stats.totalSesiones)", simbolo: "figure.run")
            TarjetaMetrica(String(localized: "km totales", comment: "Calendario de hitos"),
                           valor: Formato.kilometros(Int((stats.totalKm * 1000).rounded())),
                           unidad: "km", simbolo: "map")
            TarjetaMetrica(String(localized: "Pasos", comment: "Calendario de hitos"), valor: Formato.pasos(stats.totalPasos), simbolo: "figure.walk")
            TarjetaMetrica(String(localized: "Días activos", comment: "Calendario de hitos"), valor: "\(stats.diasEntrenados)", simbolo: "flame.fill", destacada: true)
        }
    }

    // MARK: - Matriz GitHub Heatmap

    private var graficoMatrizGitHub: some View {
        let semanas = semanasDelAnio

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: TokensEspaciado.e6) {
                    columnaDeDias

                    // Cuadrícula de 52 semanas
                    HStack(spacing: hueco) {
                        ForEach(Array(semanas.enumerated()), id: \.offset) { semanaIdx, diasDeSemana in
                            VStack(spacing: hueco) {
                                // Etiqueta del mes sobre la primera semana del mes
                                if let primerDia = diasDeSemana.first, esInicioDeMes(primerDia) {
                                    Text(nombreMes(primerDia))
                                        .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoSecundario)
                                        .fixedSize()
                                        .frame(width: celda, height: TokensEspaciado.e14, alignment: .leading)
                                } else {
                                    Color.clear
                                        .frame(width: celda, height: TokensEspaciado.e14)
                                }

                                // 7 celdas (Lunes a Domingo)
                                ForEach(diasDeSemana, id: \.self) { dia in
                                    celdaDia(dia)
                                }
                            }
                            .id(semanaIdx)
                        }
                    }
                }
                .padding(.vertical, TokensEspaciado.e4)
                .padding(.horizontal, TokensEspaciado.e2)
            }
            .onAppear {
                // Hacer scroll automático a la derecha (semana actual de hoy)
                if !semanas.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(semanas.count - 1, anchor: .trailing)
                    }
                }
            }
        }
    }

    /// Lunes a domingo, a la izquierda de la cuadrícula.
    private var columnaDeDias: some View {
        VStack(alignment: .trailing, spacing: hueco) {
            Color.clear.frame(height: TokensEspaciado.e14) // espacio para la fila de meses
            ForEach(Array(nombresDeDias.enumerated()), id: \.offset) { _, nombre in
                Text(nombre)
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: celda)
            }
        }
        .accessibilityHidden(true)
    }

    private func celdaDia(_ dia: Date) -> some View {
        let cal = Calendar.current
        let nivel = almacen.nivelDeActividad(para: dia)
        let esSeleccionado = cal.isDate(dia, inSameDayAs: fechaSeleccionada)
        let esHoy = cal.isDateInToday(dia)
        let esFuturo = dia > Date()

        return Button {
            guard !esFuturo else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                fechaSeleccionada = dia
            }
        } label: {
            RoundedRectangle(cornerRadius: hueco, style: .continuous)
                .fill(colorParaNivel(nivel, esFuturo: esFuturo))
                .frame(width: celda, height: celda)
                .overlay(
                    RoundedRectangle(cornerRadius: hueco, style: .continuous)
                        .strokeBorder(
                            esSeleccionado ? Paleta.textoPrimario : (esHoy ? Paleta.acento : Color.clear),
                            lineWidth: esSeleccionado ? TokensEspaciado.e2 : TokensEspaciado.e1
                        )
                )
                .shadow(color: esSeleccionado ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e2)
        }
        .buttonStyle(.plain)
        .disabled(esFuturo)
        .accessibilityLabel(descripcionAccesibilidad(dia: dia, nivel: nivel))
        .accessibilityAddTraits(esSeleccionado ? [.isButton, .isSelected] : .isButton)
    }

    private func colorParaNivel(_ nivel: Int, esFuturo: Bool) -> Color {
        if esFuturo {
            return Paleta.superficieAlterna.opacity(0.2)
        }
        switch nivel {
        case 1:
            return Paleta.acento.opacity(0.30)
        case 2:
            return Paleta.acento.opacity(0.55)
        case 3:
            return Paleta.acento.opacity(0.80)
        case 4:
            return Paleta.acento // el acento vivo
        default:
            return Paleta.superficieAlterna.opacity(0.45)
        }
    }

    private func esInicioDeMes(_ fecha: Date) -> Bool {
        let diaDelMes = Calendar.current.component(.day, from: fecha)
        return diaDelMes <= 7
    }

    private func nombreMes(_ fecha: Date) -> String {
        let df = DateFormatter()
        df.locale = Self.idioma
        df.setLocalizedDateFormatFromTemplate("MMM")
        return df.string(from: fecha).capitalized
    }

    private func descripcionAccesibilidad(dia: Date, nivel: Int) -> String {
        let df = DateFormatter()
        df.locale = Self.idioma
        df.dateStyle = .medium
        return "\(df.string(from: dia)): nivel de actividad \(nivel)"
    }

    // MARK: - Leyenda de Intensidad

    private var leyendaYAyuda: some View {
        HStack(spacing: TokensEspaciado.e6) {
            Text("Menos")
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)

            HStack(spacing: hueco) {
                ForEach(0..<5) { nivel in
                    RoundedRectangle(cornerRadius: TokensRadio.minimo)
                        .fill(colorParaNivel(nivel, esFuturo: false))
                        .frame(width: TokensEspaciado.e10, height: TokensEspaciado.e10)
                }
            }
            .accessibilityHidden(true)

            Text("Más")
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)

            Spacer(minLength: TokensEspaciado.e6)

            Text("Tocá un día para ver detalle")
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, TokensEspaciado.e2)
    }

    private var divisor: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(height: TokensEspaciado.e1)
    }

    // MARK: - Inspector del Día Seleccionado

    private var inspectorDelDiaSeleccionado: some View {
        let entrenamientos = almacen.actividades(para: fechaSeleccionada)
        let pasos = almacen.pasos(para: fechaSeleccionada)

        return VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            encabezadoDelDia(cantidad: entrenamientos.count)
            tarjetaDePasos(pasos)

            // Lista de Entrenamientos (Requerimiento explícito: "si fueron distintos entrenamientos el mismo día que se muestre una lista")
            if entrenamientos.isEmpty {
                VStack(spacing: TokensEspaciado.e8) {
                    Text("No se registraron salidas deportivas este día.")
                        .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    #if DEBUG
                    botonDeSimulacion
                    #endif
                }
                .padding(.top, TokensEspaciado.e2)
            } else {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    Text("Entrenamientos realizados")
                        .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(Array(entrenamientos.enumerated()), id: \.element.id) { indice, act in
                        filaEntrenamiento(act, indice: indice)
                    }
                }
            }
        }
        .padding(.top, TokensEspaciado.e4)
    }

    private func encabezadoDelDia(cantidad: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(tituloFecha(fechaSeleccionada))
                    .estilo(.opcionTitulo)
                Text(subtituloFecha(fechaSeleccionada))
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
            }

            Spacer()

            if cantidad == 0 {
                PildoraDeEstado(String(localized: "Día de descanso", comment: "Calendario de hitos: día sin entrenamientos"),
                                simbolo: "moon.zzz.fill")
            } else {
                PildoraDeEstado(cantidad == 1
                                ? String(localized: "1 entrenamiento", comment: "Calendario de hitos")
                                : String(localized: "\(cantidad) entrenamientos", comment: "Calendario de hitos"),
                                tono: .acento)
            }
        }
    }

    /// Tarjeta de Pasos del Día (Requerimiento explícito: "que se guarde la cantidad de pasos")
    private func tarjetaDePasos(_ pasos: Int) -> some View {
        HStack(spacing: TokensEspaciado.e12) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                Image(systemName: "figure.walk")
                    .font(.system(size: TokensTipografia.tituloCardGrandeTamano, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e4) {
                    Text(Formato.pasos(pasos))
                        .estilo(.metricaMedia)
                    Text("pasos")
                        .estilo(.labelCampo, color: Paleta.acento)
                }
                Text("Pasos registrados en el día")
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                textoPasosInput = pasos > 0 ? "\(pasos)" : "5000"
                mostrandoEditorPasos = true
            } label: {
                Text("Editar")
                    .estilo(.tituloCard, color: Paleta.acento)
                    .padding(.horizontal, TokensEspaciado.e14)
                    .frame(minHeight: TokensEspaciado.e36)
                    .background(Paleta.acentoChipActivo)
                    .clipShape(Capsule())
                    .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionado())
        }
        .padding(TokensEspaciado.e10)
        .background(Paleta.superficieAlterna)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
    }

    private func filaEntrenamiento(_ actividad: Actividad, indice: Int) -> some View {
        Button {
            actividadElegidaParaDetalle = actividad
        } label: {
            HStack(spacing: TokensEspaciado.e12) {
                ZStack {
                    Circle().fill(Paleta.acentoChipActivo)
                    IconoDeporte(deporte: actividad.sport, color: Paleta.acento, tamano: TokensEspaciado.e16)
                }
                .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                    HStack(spacing: TokensEspaciado.e6) {
                        Text(actividad.sport.nombreVisible)
                            .estilo(.cuerpoDestacado)

                        if let dist = actividad.distanceM {
                            Text(Formato.distancia(Int(dist), unidades: .metrico))
                                .estilo(.tituloCard, color: Paleta.acento)
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: TokensEspaciado.e8) {
                        Text(Formato.cronometro(segundos: Int(actividad.durationS)))
                            .estilo(.labelCampo, color: Paleta.textoSecundario)
                            .monospacedDigit()

                        if let dist = actividad.distanceM, dist > 0 {
                            let km = Double(dist) / 1000.0
                            let segPorKm = Int(Double(actividad.durationS) / km)
                            Text("· \(Formato.ritmo(segundosPorKm: segPorKm, unidades: .metrico)) /km")
                                .estilo(.labelCampo, color: Paleta.textoTerciario)
                                .monospacedDigit()
                        }

                        Text("· \(horaDe(actividad))")
                            .estilo(.labelCampo, color: Paleta.textoTerciario)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                    .foregroundStyle(Paleta.textoTerciario)
                    .accessibilityHidden(true)
            }
            .padding(TokensEspaciado.e10)
            .background(Paleta.superficieAlterna)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
    }

    // MARK: - Auxiliares de Formato de Fechas

    private func horaDe(_ actividad: Actividad) -> String {
        Date(timeIntervalSince1970: Double(actividad.startedAtMs) / 1000)
            .formatted(date: .omitted, time: .shortened)
    }

    private func tituloFecha(_ fecha: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(fecha) {
            return String(localized: "Hoy", comment: "Día elegido en el calendario de hitos")
        } else if cal.isDateInYesterday(fecha) {
            return String(localized: "Ayer", comment: "Día elegido en el calendario de hitos")
        } else {
            let df = DateFormatter()
            df.locale = Self.idioma
            // "lunes 13 de octubre" en castellano, "Monday, October 13" en inglés.
            df.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
            return df.string(from: fecha).capitalized
        }
    }

    private func subtituloFecha(_ fecha: Date) -> String {
        let df = DateFormatter()
        df.locale = Self.idioma
        df.dateStyle = .long
        return df.string(from: fecha)
    }

    // MARK: - Sólo en desarrollo

    #if DEBUG
    /// Crea una salida de 1 km de mentira en el día elegido. Sirve para probar
    /// el mapa de calor; en una build de la tienda no existe, para que nadie
    /// pueda inventarse actividades.
    private var botonDeSimulacion: some View {
        Button {
            simularEntrenamientoParaFecha(fechaSeleccionada)
        } label: {
            HStack(spacing: TokensEspaciado.e6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                Text("Añadir 1 km running a este día")
                    .estilo(.tituloCard, color: Paleta.acento)
            }
            .foregroundStyle(Paleta.acento)
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .background(Paleta.acentoChipActivo)
            .clipShape(Capsule())
        }
        .buttonStyle(EstiloPresionado())
    }

    private func simularEntrenamientoParaFecha(_ fecha: Date) {
        let cal = Calendar.current
        let baseMs = Int64(cal.startOfDay(for: fecha).timeIntervalSince1970 * 1000) + 10 * 3600 * 1000
        let nuevo = Actividad(
            id: "simulado-\(UUID().uuidString.prefix(6))",
            sport: .running,
            startedAtMs: baseMs,
            durationS: 320,
            distanceM: 1000,
            elevationGainM: 10,
            avgHrBpm: 145,
            maxHrBpm: 160,
            kcal: 70,
            device: .telefono,
            createdAtMs: baseMs,
            updatedAtMs: baseMs
        )
        almacen.registrarActividad(nuevo)
    }
    #endif
}
