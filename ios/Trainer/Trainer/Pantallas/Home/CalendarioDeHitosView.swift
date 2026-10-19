import SwiftUI
import TrainerCore

/// Calendario de hitos estilo GitHub ("Yearly" activity contribution graph).
/// Muestra los días entrenados a lo largo del año con diferentes niveles de intensidad rosa (#FF23A7).
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
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: 1)
        )
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
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Paleta.acento)

            VStack(alignment: .leading, spacing: 1) {
                Text("Yearly")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                Text("Hitos y entrenamientos estilo GitHub")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Paleta.textoTerciario)
            }

            Spacer()

            Text("2026")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(Paleta.acento)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Paleta.acentoChipActivo)
                .clipShape(Capsule())
        }
    }

    // MARK: - Resumen de Estadísticas Anuales

    private var resumenEstadisticas: some View {
        let stats = almacen.resumenAnual()
        return HStack(spacing: TokensEspaciado.e8) {
            itemEstadistica(valor: "\(stats.totalSesiones)", etiqueta: "Sesiones", icono: "figure.run")
            divisorVertical
            itemEstadistica(valor: String(format: "%.1f", stats.totalKm).replacingOccurrences(of: ".", with: ","), etiqueta: "km totales", icono: "map")
            divisorVertical
            itemEstadistica(valor: Formato.pasos(stats.totalPasos), etiqueta: "Pasos", icono: "figure.walk")
            divisorVertical
            itemEstadistica(valor: "\(stats.diasEntrenados)", etiqueta: "Días activos", icono: "flame.fill")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Paleta.superficieAlterna.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func itemEstadistica(valor: String, etiqueta: String, icono: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icono)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Paleta.acento)
                Text(valor)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(etiqueta)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Paleta.textoTerciario)
        }
        .frame(maxWidth: .infinity)
    }

    private var divisorVertical: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(width: 1, height: 20)
    }

    // MARK: - Matriz GitHub Heatmap

    private var graficoMatrizGitHub: some View {
        let semanas = semanasDelAnio

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    // Columna con los días de la semana a la izquierda
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("").frame(height: 14) // espacio para la fila de meses
                        Text("Mon").font(.system(size: 9, weight: .semibold)).foregroundStyle(Paleta.textoTerciario).frame(height: 12)
                        Text("Tue").font(.system(size: 9, weight: .semibold)).foregroundStyle(Paleta.textoTerciario).frame(height: 12)
                        Text("Wed").font(.system(size: 9, weight: .semibold)).foregroundStyle(Paleta.textoTerciario).frame(height: 12)
                        Text("Thu").font(.system(size: 9, weight: .semibold)).foregroundStyle(Paleta.textoTerciario).frame(height: 12)
                        Text("Fri").font(.system(size: 9, weight: .semibold)).foregroundStyle(Paleta.textoTerciario).frame(height: 12)
                        Text("Sat").font(.system(size: 9, weight: .semibold)).foregroundStyle(Paleta.textoTerciario).frame(height: 12)
                        Text("Sun").font(.system(size: 9, weight: .semibold)).foregroundStyle(Paleta.textoTerciario).frame(height: 12)
                    }

                    // Cuadrícula de 52 semanas
                    HStack(spacing: 3) {
                        ForEach(Array(semanas.enumerated()), id: \.offset) { semanaIdx, diasDeSemana in
                            VStack(spacing: 3) {
                                // Etiqueta del mes sobre la primera semana del mes
                                if let primerDia = diasDeSemana.first, esInicioDeMes(primerDia) {
                                    Text(nombreMes(primerDia))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Paleta.textoSecundario)
                                        .frame(height: 14, alignment: .leading)
                                } else {
                                    Text("")
                                        .frame(height: 14)
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
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
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
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(colorParaNivel(nivel, esFuturo: esFuturo))
                .frame(width: 12, height: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(
                            esSeleccionado ? Color.white : (esHoy ? Paleta.acento : Color.clear),
                            lineWidth: esSeleccionado ? 1.8 : 1.0
                        )
                )
                .shadow(color: esSeleccionado ? Paleta.acento.opacity(0.8) : Color.clear, radius: 2)
        }
        .buttonStyle(.plain)
        .disabled(esFuturo)
        .accessibilityLabel(descripcionAccesibilidad(dia: dia, nivel: nivel))
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
            return Paleta.acento // #FF23A7 vivo
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
        df.locale = Locale(identifier: "es_AR")
        df.dateFormat = "MMM"
        return df.string(from: fecha).capitalized
    }

    private func descripcionAccesibilidad(dia: Date, nivel: Int) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "\(df.string(from: dia)): nivel de actividad \(nivel)"
    }

    // MARK: - Leyenda de Intensidad

    private var leyendaYAyuda: some View {
        HStack {
            Text("Menos")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Paleta.textoTerciario)

            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2).fill(colorParaNivel(0, esFuturo: false)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(colorParaNivel(1, esFuturo: false)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(colorParaNivel(2, esFuturo: false)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(colorParaNivel(3, esFuturo: false)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(colorParaNivel(4, esFuturo: false)).frame(width: 10, height: 10)
            }

            Text("Más")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Paleta.textoTerciario)

            Spacer()

            Text("Tocá un día para ver detalle")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Paleta.textoTerciario)
        }
        .padding(.horizontal, 2)
    }

    private var divisor: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(height: 1)
    }

    // MARK: - Inspector del Día Seleccionado

    private var inspectorDelDiaSeleccionado: some View {
        let entrenamientos = almacen.actividades(para: fechaSeleccionada)
        let pasos = almacen.pasos(para: fechaSeleccionada)

        return VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            // Título de la fecha
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tituloFecha(fechaSeleccionada))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.textoPrimario)
                    Text(subtituloFecha(fechaSeleccionada))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                }

                Spacer()

                if entrenamientos.isEmpty {
                    Text("Día de descanso")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Paleta.textoSecundario)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Paleta.superficieAlterna)
                        .clipShape(Capsule())
                } else {
                    Text("\(entrenamientos.count) \(entrenamientos.count == 1 ? "entrenamiento" : "entrenamientos")")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.acento)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Paleta.acentoChipActivo)
                        .clipShape(Capsule())
                }
            }

            // Tarjeta de Pasos del Día (Requerimiento explícito: "que se guarde la cantidad de pasos")
            HStack(spacing: TokensEspaciado.e12) {
                ZStack {
                    Circle()
                        .fill(Paleta.acento.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Formato.pasos(pasos)) pasos")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.textoPrimario)
                        .monospacedDigit()
                    Text("Pasos registrados en el día")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                }

                Spacer()

                Button {
                    textoPasosInput = pasos > 0 ? "\(pasos)" : "5000"
                    mostrandoEditorPasos = true
                } label: {
                    Text("Editar")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.acento)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Paleta.acentoChipActivo)
                        .clipShape(Capsule())
                }
                .buttonStyle(EstiloPresionado())
            }
            .padding(TokensEspaciado.e10)
            .background(Paleta.superficieAlterna)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Lista de Entrenamientos (Requerimiento explícito: "si fueron distintos entrenamientos el mismo día que se muestre una lista")
            if entrenamientos.isEmpty {
                VStack(spacing: 8) {
                    Text("No se registraron salidas deportivas este día.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        simularEntrenamientoParaFecha(fechaSeleccionada)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Añadir 1 km running a este día")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Paleta.acento)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Paleta.acentoChipActivo)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(EstiloPresionado())
                }
                .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    Text("ENTRENAMIENTOS REALIZADOS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Paleta.textoTerciario)

                    ForEach(Array(entrenamientos.enumerated()), id: \.element.id) { indice, act in
                        filaEntrenamiento(act, indice: indice)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func filaEntrenamiento(_ actividad: Actividad, indice: Int) -> some View {
        Button {
            actividadElegidaParaDetalle = actividad
        } label: {
            HStack(spacing: TokensEspaciado.e12) {
                ZStack {
                    Circle()
                        .fill(Paleta.acentoChipActivo)
                        .frame(width: 40, height: 40)
                    IconoDeporte(deporte: actividad.sport, color: Paleta.acento, tamano: 18)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(nombreDeporte(actividad.sport))
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Paleta.textoPrimario)

                        if let dist = actividad.distanceM {
                            Text(Formato.distancia(Int(dist), unidades: .metrico))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Paleta.acento)
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: 8) {
                        Text(Formato.cronometro(segundos: Int(actividad.durationS)))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Paleta.textoSecundario)
                            .monospacedDigit()

                        if let dist = actividad.distanceM, dist > 0 {
                            let km = Double(dist) / 1000.0
                            let segPorKm = Int(Double(actividad.durationS) / km)
                            Text("· \(Formato.ritmo(segundosPorKm: segPorKm, unidades: .metrico)) /km")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Paleta.textoTerciario)
                        }

                        let hora = Date(timeIntervalSince1970: Double(actividad.startedAtMs) / 1000)
                            .formatted(date: .omitted, time: .shortened)
                        Text("· \(hora)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Paleta.textoTerciario)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paleta.textoTerciario)
            }
            .padding(TokensEspaciado.e10)
            .background(Paleta.superficieAlterna)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(EstiloPresionado())
    }

    // MARK: - Auxiliares de Formato de Fechas

    private func tituloFecha(_ fecha: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(fecha) {
            return "Hoy"
        } else if cal.isDateInYesterday(fecha) {
            return "Ayer"
        } else {
            let df = DateFormatter()
            df.locale = Locale(identifier: "es_AR")
            df.dateFormat = "EEEE d 'de' MMMM"
            return df.string(from: fecha).capitalized
        }
    }

    private func subtituloFecha(_ fecha: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_AR")
        df.dateStyle = .long
        return df.string(from: fecha)
    }

    private func nombreDeporte(_ sport: DeporteDeSesion) -> String {
        switch sport {
        case .running: return Textos.regDeporteRunning
        case .ciclismo: return Textos.regDeporteCiclismo
        case .trekking: return Textos.regDeporteTrekking
        case .triatlon: return Textos.regDeporteTriatlon
        default: return sport.rawValue.capitalized
        }
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
}
