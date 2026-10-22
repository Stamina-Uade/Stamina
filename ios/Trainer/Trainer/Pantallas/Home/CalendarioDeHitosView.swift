import SwiftUI
import TrainerCore

/// Calendario de hitos estilo GitHub (el gráfico de contribuciones del año).
/// Muestra los días entrenados de las últimas 52 semanas con niveles de intensidad del acento.
/// Permite tocar cualquier día para inspeccionar los pasos guardados y la lista de entrenamientos
/// realizados en esa jornada (por ejemplo, 1 km corriendo y 2 km corriendo en un mismo día).
struct CalendarioDeHitosView: View {
    @ObservedObject private var almacen = AlmacenDeHitos.compartido
    /// Si los pasos vienen solos de Salud (y no se editan) o se cargan a mano.
    @ObservedObject private var sincronizadorDePasos = SincronizadorDePasos.compartido
    /// Km o millas, lo que eligió la persona (lo pasa el historial).
    private let unidades: SistemaDeUnidades
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var fechaSeleccionada: Date = {
        // Por defecto seleccionar ayer si tiene entrenamientos o hoy
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }()

    @State private var actividadElegidaParaDetalle: Actividad? = nil
    @State private var mostrandoEditorPasos: Bool = false
    @State private var textoPasosInput: String = ""
    /// La explicación de qué significa cada color, plegada al principio.
    @State private var leyendaAbierta = false

    init(unidades: SistemaDeUnidades = .metrico) {
        self.unidades = unidades
    }

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
        .task {
            // Lo que se ve: Salud para todo el año (pide el permiso la primera vez)
            // y el servidor para lo que Salud no tenga, como en un teléfono nuevo.
            let inicio = semanasDelAnio.first?.first ?? Date()
            await sincronizadorDePasos.alVerPasos(desde: inicio, hasta: Date())
        }
        .sheet(item: $actividadElegidaParaDetalle) { actividad in
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

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack(alignment: .center, spacing: TokensEspaciado.e8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: TokensEspaciado.e16, weight: .bold))
                .foregroundStyle(Paleta.acento)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e1) {
                Text(Textos.milestonesYourYear)
                    .estilo(.tituloSeccion)
                    .accessibilityAddTraits(.isHeader)
                Text(Textos.milestonesCalendarHint)
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
                    .fixedSize(horizontal: false, vertical: true)
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
            TarjetaMetrica(Textos.milestonesSessions, valor: "\(stats.totalSesiones)", simbolo: "figure.run")
            TarjetaMetrica(Textos.milestonesTotalDistance,
                           valor: Formato.distanciaNumero(Int((stats.totalKm * 1000).rounded()), unidades: unidades),
                           unidad: Formato.unidadDeDistancia(unidades), simbolo: "map")
            TarjetaMetrica(Textos.commonSteps, valor: Formato.pasos(stats.totalPasos), simbolo: "figure.walk")
            TarjetaMetrica(Textos.milestonesActiveDays, valor: "\(stats.diasEntrenados)", simbolo: "flame.fill", destacada: true)
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
            guard !esFuturo, !esSeleccionado else { return }
            Haptico.seleccion()
            HistorialMovimiento.animar(movimientoReducido) {
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
        let cantidad = almacen.actividades(para: dia).count
        let entrenos = cantidad == 0
            ? Textos.milestonesNoWorkouts
            : Textos.milestonesWorkoutsCount(cantidad)
        return "\(df.string(from: dia)): \(entrenos), \(Self.nombreDeNivel(nivel))"
    }

    /// El nivel del mapa de calor dicho en una palabra.
    private static func nombreDeNivel(_ nivel: Int) -> String {
        switch nivel {
        case 1: return Textos.milestonesActivityLight
        case 2: return Textos.milestonesActivityModerate
        case 3: return Textos.milestonesActivityHigh
        case 4: return Textos.milestonesActivityVeryHigh
        default: return Textos.milestonesActivityNone
        }
    }

    // MARK: - Leyenda de Intensidad

    /// "Menos ▢▢▢▢▢ Más" siempre a la vista y, al tocar "¿Qué significa?",
    /// qué hace falta para cada color. Los umbrales son los de
    /// `AlmacenDeHitos.nivelDeActividad`: si cambian allá, cambian acá.
    private var leyendaYAyuda: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            HStack(spacing: TokensEspaciado.e6) {
                Text(Textos.commonLess)
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)

                HStack(spacing: hueco) {
                    ForEach(0..<5) { nivel in
                        cuadritoDeLeyenda(nivel)
                    }
                }
                .accessibilityHidden(true)

                Text(Textos.commonMore)
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)

                Spacer(minLength: TokensEspaciado.e6)

                Button {
                    Haptico.toque()
                    HistorialMovimiento.animar(movimientoReducido) { leyendaAbierta.toggle() }
                } label: {
                    HStack(spacing: TokensEspaciado.e4) {
                        Text(Textos.milestonesWhatItMeans)
                            .estilo(.chip, color: Paleta.textoAcento)
                        Image(systemName: "chevron.down")
                            .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                            .foregroundStyle(Paleta.textoAcento)
                            .rotationEffect(.degrees(leyendaAbierta ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityValue(leyendaAbierta
                                    ? Textos.milestonesExpanded
                                    : Textos.milestonesCollapsed)
            }

            if leyendaAbierta {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    ForEach(0..<5) { nivel in
                        HStack(alignment: .top, spacing: TokensEspaciado.e10) {
                            cuadritoDeLeyenda(nivel)
                                .padding(.top, TokensEspaciado.e3)
                                .accessibilityHidden(true)
                            Text(explicacionDeNivel(nivel))
                                .estilo(.labelCampo, color: Paleta.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text(Textos.milestonesCalendarBorderHint)
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(TokensEspaciado.e12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Paleta.superficieAlterna)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, TokensEspaciado.e2)
    }

    private func cuadritoDeLeyenda(_ nivel: Int) -> some View {
        RoundedRectangle(cornerRadius: TokensRadio.minimo)
            .fill(colorParaNivel(nivel, esFuturo: false))
            .frame(width: TokensEspaciado.e10, height: TokensEspaciado.e10)
    }

    /// Qué pide cada color, con las distancias en km o millas.
    private func explicacionDeNivel(_ nivel: Int) -> String {
        let d3 = Formato.distancia(3_000, unidades: unidades)
        let d6 = Formato.distancia(6_000, unidades: unidades)
        let d12 = Formato.distancia(12_000, unidades: unidades)
        let p5 = Formato.pasos(5_000)
        let p10 = Formato.pasos(10_000)
        switch nivel {
        case 1:
            return Textos.milestonesLevelLight(d3, p5)
        case 2:
            return Textos.milestonesLevelModerate(d3, p10)
        case 3:
            return Textos.milestonesLevelHigh(d6)
        case 4:
            return Textos.milestonesLevelVeryHigh(d12)
        default:
            return Textos.milestonesLevelNone(p5)
        }
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
        let fuente = almacen.fuenteDePasos(para: fechaSeleccionada)

        return VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            encabezadoDelDia(cantidad: entrenamientos.count)
            tarjetaDePasos(pasos, fuente: fuente)

            // Lista de Entrenamientos (Requerimiento explícito: "si fueron distintos entrenamientos el mismo día que se muestre una lista")
            if entrenamientos.isEmpty {
                VStack(spacing: TokensEspaciado.e8) {
                    Text(Textos.milestonesNoWorkoutsDay)
                        .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    #if DEBUG
                    botonDeSimulacion
                    #endif
                }
                .padding(.top, TokensEspaciado.e2)
            } else {
                resumenDelDia(entrenamientos)

                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    Text(Textos.milestonesCompletedWorkouts)
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

    /// Lo que suman los entrenamientos del día elegido.
    private func resumenDelDia(_ entrenamientos: [Actividad]) -> some View {
        let totales = HistorialTotales(entrenamientos)
        let tiempo = HistorialFormato.tiempoAcumulado(segundos: totales.segundos)
        return HStack(spacing: TokensEspaciado.e8) {
            TarjetaMetrica(Textos.milestonesDayDistance,
                           valor: Formato.distanciaNumero(totales.metros, unidades: unidades),
                           unidad: Formato.unidadDeDistancia(unidades), simbolo: "map", destacada: true)
            TarjetaMetrica(Textos.commonTime,
                           valor: tiempo.valor, unidad: tiempo.unidad, simbolo: "clock")
        }
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
                PildoraDeEstado(Textos.milestonesRestDay,
                                simbolo: "moon.zzz.fill")
            } else {
                PildoraDeEstado(cantidad == 1
                                ? Textos.milestonesWorkoutsOne
                                : Textos.milestonesWorkoutsCount(cantidad),
                                tono: .acento)
            }
        }
    }

    /// Tarjeta de Pasos del Día (Requerimiento explícito: "que se guarde la cantidad de pasos").
    /// Con Salud en modo automático no se edita: muestra de dónde salió el número.
    private func tarjetaDePasos(_ pasos: Int, fuente: FuenteDePasos?) -> some View {
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
                    Text(Textos.commonStepsLowercase)
                        .estilo(.labelCampo, color: Paleta.acento)
                }
                Text(Textos.milestonesStepsLogged)
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            if sincronizadorDePasos.modoAutomatico {
                PildoraDeEstado(Self.nombreDeFuente(fuente ?? .healthkit), simbolo: "heart.fill", tono: .acento)
            } else {
                botonEditarPasos(pasos)
            }
        }
        .padding(TokensEspaciado.e10)
        .background(Paleta.superficieAlterna)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
    }

    /// La carga a mano: sólo cuando Salud no da los pasos (sin permiso o sin Salud).
    private func botonEditarPasos(_ pasos: Int) -> some View {
        Button {
            textoPasosInput = pasos > 0 ? "\(pasos)" : "5000"
            mostrandoEditorPasos = true
        } label: {
            Text(Textos.commonEdit)
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

    private static func nombreDeFuente(_ fuente: FuenteDePasos) -> String {
        switch fuente {
        case .healthkit:
            return Textos.milestonesStepsSourceAppleHealth
        case .healthConnect:
            return Textos.milestonesStepsSourceHealthConnect
        case .manual:
            return Textos.milestonesStepsSourceManual
        }
    }

    private func filaEntrenamiento(_ actividad: Actividad, indice: Int) -> some View {
        Button {
            Haptico.toque()
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
                            Text(Formato.distancia(Int(dist), unidades: unidades))
                                .estilo(.tituloCard, color: Paleta.acento)
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: TokensEspaciado.e8) {
                        Text(Formato.cronometro(segundos: Int(actividad.durationS)))
                            .estilo(.labelCampo, color: Paleta.textoSecundario)
                            .monospacedDigit()

                        if let ritmo = HistorialFormato.ritmoOVelocidad(actividad, unidades: unidades) {
                            Text(verbatim: "· \(ritmo)")
                                .estilo(.labelCampo, color: Paleta.textoTerciario)
                                .monospacedDigit()
                        }

                        Text(verbatim: "· \(horaDe(actividad))")
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
            return Textos.commonToday
        } else if cal.isDateInYesterday(fecha) {
            return Textos.commonYesterday
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
                Text(Textos.milestonesDebugAddKm)
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
