import SwiftUI
import TrainerCore

/// Historial leído de GET /activities. El mapa de detalle se pide sólo al abrir
/// la actividad: el listado del servidor nunca arrastra puntos GPS.
struct HistorialDeActividadesView: View {
    let servicio: (any ServicioDeActividades)?
    @Environment(\.dismiss) private var cerrar
    @State private var actividades: [Actividad] = []
    @State private var cursor: String?
    @State private var hayMas = true
    @State private var cargando = false
    @State private var fallo = false
    @State private var elegida: ActividadElegida?

    struct ActividadElegida: Identifiable {
        let actividad: Actividad
        var id: String { actividad.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TokensEspaciado.e14) {
                    CalendarioDeHitosView()

                    LazyVStack(spacing: TokensEspaciado.e10) {
                    if actividades.isEmpty, !cargando {
                        Text(fallo ? Textos.historialError : Textos.historialVacio)
                            .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(actividades, id: \.id) { actividad in
                        Button { elegida = ActividadElegida(actividad: actividad) } label: {
                            VStack(alignment: .leading, spacing: TokensEspaciado.e5) {
                                Text(actividad.sport == .triatlon ? Textos.regDeporteTriatlon : actividad.sport.rawValue.capitalized)
                                    .estilo(.tituloCardGrande)
                                Text(fecha(actividad.startedAtMs))
                                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                                Text("\(Formato.distancia(Int(actividad.distanceM ?? 0), unidades: .metrico)) · \(Formato.cronometro(segundos: Int(actividad.durationS)))")
                                    .estilo(.labelCampo, color: Paleta.acento)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(TokensEspaciado.e14)
                            .background(Paleta.superficie)
                            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card))
                        }
                        .buttonStyle(EstiloPresionado())
                    }
                    if hayMas {
                        Button(cargando ? Textos.historialCargando : Textos.historialMas) {
                            Task { await cargar() }
                        }
                        .disabled(cargando)
                        .padding(TokensEspaciado.e14)
                    }
                }
                }
                .padding(TokensEspaciado.e16)
            }
            .background(Paleta.fondo)
            .navigationTitle(Textos.historialTitulo)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Textos.historialCerrar) { cerrar() }
                }
            }
        }
        .task { if actividades.isEmpty { await cargar() } }
        .sheet(item: $elegida) { seleccion in
            DetalleDeActividadView(
                actividad: seleccion.actividad,
                puntosIniciales: AlmacenDeRecorridos.compartido.puntos(para: seleccion.actividad.id),
                servicio: servicio
            )
        }
    }

    private func cargar() async {
        guard !cargando, hayMas, let servicio else { return }
        cargando = true
        defer { cargando = false }
        let respuesta = await servicio.actividades(limite: 20, cursor: cursor)
        guard case .ok(let pagina) = respuesta else { fallo = true; return }
        fallo = false
        actividades.append(contentsOf: pagina.elementos.filter { nuevo in
            !actividades.contains { $0.id == nuevo.id }
        })
        cursor = pagina.paginacion.nextCursor
        hayMas = pagina.paginacion.hasMore
    }

    private func fecha(_ ms: Int64) -> String {
        Date(timeIntervalSince1970: Double(ms) / 1000)
            .formatted(date: .abbreviated, time: .shortened)
    }
}

struct DetalleDeActividadView: View {
    let actividad: Actividad
    let puntosIniciales: [PuntoDeRecorrido]?
    let servicio: (any ServicioDeActividades)?
    @Environment(\.dismiss) private var cerrar
    @State private var puntos: [PuntoDeRecorrido]
    @State private var cargando: Bool
    @State private var modoReproduccion = false
    @State private var sistemaDeUnidades: SistemaDeUnidades = .metrico

    init(actividad: Actividad, puntosIniciales: [PuntoDeRecorrido]? = nil, servicio: (any ServicioDeActividades)?) {
        self.actividad = actividad
        self.servicio = servicio
        let puntosLocales = (puntosIniciales != nil && !puntosIniciales!.isEmpty)
            ? puntosIniciales
            : AlmacenDeRecorridos.compartido.puntos(para: actividad.id)
        self.puntosIniciales = puntosLocales
        if let puntosLocales, !puntosLocales.isEmpty {
            _puntos = State(initialValue: puntosLocales)
            _cargando = State(initialValue: false)
        } else {
            _puntos = State(initialValue: [])
            _cargando = State(initialValue: true)
        }
    }

    private var fechaHora: String {
        Date(timeIntervalSince1970: Double(actividad.startedAtMs) / 1000)
            .formatted(date: .abbreviated, time: .shortened)
    }

    private var analisis: AnalisisDeRecorrido {
        AnalizadorDeRecorrido.analizar(
            puntos: puntos,
            deporte: actividad.sport,
            duracionTotalSegundos: Int(actividad.durationS)
        )
    }

    private var ritmoPromedio: Int? {
        guard let dist = actividad.distanceM, dist > 50, actividad.durationS > 0 else { return nil }
        let segPorMetro = Double(actividad.durationS) / Double(dist)
        return Int((segPorMetro * 1000.0).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                    // 1. Cabecera con deporte, fecha y dispositivo
                    HStack(spacing: TokensEspaciado.e10) {
                        ZStack {
                            Circle()
                                .fill(Paleta.acento.opacity(0.18))
                                .frame(width: 44, height: 44)
                            IconoDeporte(deporte: actividad.sport, color: Paleta.acento, tamano: 20)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(nombreDeporte(actividad.sport))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Paleta.textoPrimario)
                            Text(fechaHora)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Paleta.textoSecundario)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: actividad.device == .reloj ? "applewatch" : "iphone")
                                .font(.system(size: 12))
                            Text(actividad.device == .reloj ? "Reloj" : "iPhone")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Paleta.textoTerciario)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Paleta.superficie)
                        .clipShape(Capsule())
                    }
                    .padding(.top, TokensEspaciado.e8)

                    // 2. Mapa grande con recorrido en 3D (estilo Strava) y reproducción a pantalla completa
                    if !puntos.isEmpty {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                            HStack {
                                Text("RECORRIDO")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Paleta.textoSecundario)
                                Spacer()
                                Button {
                                    modoReproduccion = true
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("Reproducir recorrido")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Paleta.sobreAcento)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Paleta.acento)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(EstiloPresionado())
                            }

                            VistaRecorrido3D(
                                puntos: puntos,
                                deporte: actividad.sport,
                                duracionTotalSegundos: Int(actividad.durationS),
                                distanciaMetros: Int(actividad.distanceM ?? 0),
                                desnivelMetros: actividad.elevationGainM != nil ? Int(actividad.elevationGainM!) : nil,
                                ritmoSegundosPorKm: ritmoPromedio,
                                sistemaDeUnidades: sistemaDeUnidades,
                                inicioMs: actividad.startedAtMs
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 420)
                            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                                    .strokeBorder(Paleta.bordeInput, lineWidth: 1)
                            )
                        }
                        .fullScreenCover(isPresented: $modoReproduccion) {
                            ReproductorDeRecorridoView(
                                puntos: puntos,
                                deporte: actividad.sport,
                                duracionTotalSegundos: Int(actividad.durationS),
                                sistemaDeUnidades: sistemaDeUnidades,
                                alCerrar: { modoReproduccion = false }
                            )
                        }
                    } else if cargando {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(Textos.historialCargando)
                                .font(.system(size: 14))
                                .foregroundStyle(Paleta.textoSecundario)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(Paleta.superficie)
                        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card))
                    } else {
                        Text(Textos.historialSinRecorrido)
                            .font(.system(size: 14))
                            .foregroundStyle(Paleta.textoTerciario)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(Paleta.superficie)
                            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card))
                    }

                    // 3. Métricas principales en fondo OLED puro sin tarjetas grises
                    VStack(alignment: .leading, spacing: 12) {
                        filaMetrica(
                            etiqueta: Textos.entrenoDistancia,
                            valor: Formato.distancia(Int(actividad.distanceM ?? 0), unidades: sistemaDeUnidades, decimales: 2),
                            destacado: true
                        )

                        filaMetrica(
                            etiqueta: "DURACIÓN TOTAL",
                            valor: Formato.cronometroCompleto(segundos: Int(actividad.durationS))
                        )

                        if analisis.tiempoEnMovimientoSegundos < Int(actividad.durationS) {
                            filaMetrica(
                                etiqueta: "TIEMPO EN MOVIMIENTO",
                                valor: Formato.cronometroCompleto(segundos: analisis.tiempoEnMovimientoSegundos)
                            )
                        }

                        if actividad.sport == .ciclismo {
                            let velPromedio: String = {
                                guard let dist = actividad.distanceM, dist >= 50, actividad.durationS > 0 else {
                                    return "0,0 \(Formato.unidadDeVelocidad(sistemaDeUnidades))"
                                }
                                return Formato.velocidad(metros: Int(dist), segundos: Int(actividad.durationS), unidades: sistemaDeUnidades)
                            }()
                            filaMetrica(
                                etiqueta: "VELOCIDAD PROMEDIO",
                                valor: velPromedio
                            )

                            if let maxKmh = analisis.velocidadMaximaKmh {
                                let maxVel = sistemaDeUnidades == .imperial ? maxKmh * 0.621371 : maxKmh
                                let unidad = Formato.unidadDeVelocidad(sistemaDeUnidades)
                                filaMetrica(
                                    etiqueta: "VELOCIDAD MÁXIMA",
                                    valor: String(format: "%.1f %@", maxVel, unidad).replacingOccurrences(of: ".", with: ",")
                                )
                            }
                        } else {
                            let ritmoMedio: Int? = {
                                guard let dist = actividad.distanceM, dist >= 100, actividad.durationS > 0 else { return nil }
                                let segundos = Double(actividad.durationS)
                                let metros = Double(dist)
                                return Int((segundos * 1000.0 / metros).rounded())
                            }()
                            filaMetrica(
                                etiqueta: "RITMO PROMEDIO",
                                valor: Formato.ritmo(segundosPorKm: ritmoMedio, unidades: sistemaDeUnidades) + (sistemaDeUnidades == .imperial ? " /mi" : " /km")
                            )

                            if let ritmoMax = analisis.ritmoMaximoSegPorKm {
                                filaMetrica(
                                    etiqueta: "MEJOR RITMO",
                                    valor: Formato.ritmo(segundosPorKm: ritmoMax, unidades: sistemaDeUnidades) + (sistemaDeUnidades == .imperial ? " /mi" : " /km")
                                )
                            }
                        }

                        if let medio = actividad.avgHrBpm {
                            filaMetrica(
                                etiqueta: Textos.resumenPulsoMedio,
                                valor: "\(medio) ppm",
                                colorIcono: .red,
                                icono: "heart.fill"
                            )
                        }

                        if let maximo = actividad.maxHrBpm {
                            filaMetrica(
                                etiqueta: Textos.resumenPulsoMax,
                                valor: "\(maximo) ppm",
                                colorIcono: .red,
                                icono: "heart.fill"
                            )
                        }

                        filaMetrica(
                            etiqueta: "DESNIVEL ACUMULADO",
                            valor: Formato.desnivel(metros: Int(actividad.elevationGainM ?? 0), unidades: sistemaDeUnidades)
                        )

                        let kcal = actividad.kcal.map(Int.init) ?? caloriasEstimadas(deporte: actividad.sport, segundos: Int(actividad.durationS))
                        filaMetrica(
                            etiqueta: "CALORÍAS ACTIVAS",
                            valor: "\(kcal) kcal"
                        )
                    }

                    // 4. Estadística por kilómetro (Splits con barras relativas)
                    if !analisis.splitsKm.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ESTADÍSTICA POR KILÓMETRO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Paleta.textoSecundario)
                                .padding(.top, 4)

                            let ritmos = analisis.splitsKm.map(\.ritmoSegPorKm).filter { $0 > 0 }
                            let mejorRitmo = ritmos.min() ?? 1
                            let peorRitmo = max(mejorRitmo + 1, ritmos.max() ?? 1)

                            ForEach(analisis.splitsKm) { split in
                                VStack(spacing: 6) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Paleta.acento).frame(width: 24, height: 24)
                                            Text("\(split.numero)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Paleta.fondo)
                                        }

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Km \(split.numero)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Paleta.textoPrimario)
                                            Text(Formato.distancia(split.metros, unidades: sistemaDeUnidades, decimales: 2))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Paleta.textoTerciario)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text(actividad.sport == .ciclismo
                                                ? String(format: "%.1f %@", sistemaDeUnidades == .imperial ? split.velocidadKmh * 0.621371 : split.velocidadKmh, Formato.unidadDeVelocidad(sistemaDeUnidades)).replacingOccurrences(of: ".", with: ",")
                                                : Formato.ritmo(segundosPorKm: split.ritmoSegPorKm, unidades: sistemaDeUnidades) + (sistemaDeUnidades == .imperial ? " /mi" : " /km"))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(Paleta.textoPrimario)
                                                .monospacedDigit()
                                            Text(Formato.cronometro(segundos: split.segundos))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Paleta.textoSecundario)
                                                .monospacedDigit()
                                        }
                                    }

                                    // Barra visual de ritmo relativo
                                    GeometryReader { geo in
                                        let ancho = geo.size.width
                                        let ratio: CGFloat = {
                                            guard peorRitmo > mejorRitmo else { return 1.0 }
                                            let r = 1.0 - (Double(split.ritmoSegPorKm - mejorRitmo) / Double(peorRitmo - mejorRitmo))
                                            return CGFloat(max(0.2, min(1.0, 0.3 + 0.7 * r)))
                                        }()
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Paleta.superficie)
                                                .frame(height: 5)
                                            Capsule()
                                                .fill(Paleta.acento)
                                                .frame(width: ancho * ratio, height: 5)
                                        }
                                    }
                                    .frame(height: 5)
                                }
                                .padding(.vertical, 3)
                                Divider().background(Paleta.divisor)
                            }
                        }
                    }

                    // 5. Tramos, pausas y reanudaciones
                    if !analisis.pausas.isEmpty || analisis.tramos.count > 1 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TRAMOS, PAUSAS Y REANUDACIONES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Paleta.textoSecundario)
                                .padding(.top, 4)

                            ForEach(analisis.tramos) { tramo in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Paleta.superficieOverlay).frame(width: 24, height: 24)
                                            Circle().stroke(Paleta.acento, lineWidth: 1.5).frame(width: 24, height: 24)
                                            Text("\(tramo.numero)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Paleta.acento)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Tramo \(tramo.numero)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Paleta.textoPrimario)
                                            Text(Formato.distancia(tramo.metros, unidades: sistemaDeUnidades, decimales: 2))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Paleta.textoSecundario)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text(Formato.cronometro(segundos: tramo.segundos))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(Paleta.textoPrimario)
                                                .monospacedDigit()
                                            if let ritmo = tramo.ritmoSegPorKm {
                                                Text(Formato.ritmo(segundosPorKm: ritmo, unidades: sistemaDeUnidades) + " /km")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(Paleta.textoTerciario)
                                            }
                                        }
                                    }

                                    // Si hubo pausa después de este tramo
                                    if let pausa = analisis.pausas.first(where: { $0.numero == tramo.numero }) {
                                        let horaPausa = Date(timeIntervalSince1970: Double(pausa.inicioMs) / 1000).formatted(date: .omitted, time: .standard)
                                        let horaReanuda = Date(timeIntervalSince1970: Double(pausa.finMs) / 1000).formatted(date: .omitted, time: .standard)

                                        HStack(spacing: 8) {
                                            Image(systemName: "pause.circle.fill")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Paleta.acento)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Pausa \(pausa.numero): \(Formato.cronometro(segundos: pausa.duracionSegundos))")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Paleta.acento)
                                                Text("Pausa: \(horaPausa) · Reanudación: \(horaReanuda)")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundStyle(Paleta.textoTerciario)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Paleta.acento.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(.vertical, 3)
                                Divider().background(Paleta.divisor)
                            }
                        }
                    }

                    Spacer(minLength: TokensEspaciado.e16)
                }
                .padding(.horizontal, TokensEspaciado.e16)
            }
            .background(Paleta.fondo)
            .navigationTitle(nombreDeporte(actividad.sport))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Textos.historialCerrar) { cerrar() }
                }
            }
        }
        .task {
            if puntos.isEmpty {
                if let cacheados = AlmacenDeRecorridos.compartido.puntos(para: actividad.id), !cacheados.isEmpty {
                    puntos = cacheados
                    cargando = false
                } else if case .ok(let recorrido) = await servicio?.recorrido(id: actividad.id) {
                    puntos = recorrido.points
                    AlmacenDeRecorridos.compartido.guardar(id: actividad.id, puntos: recorrido.points)
                }
                cargando = false
            }
        }
    }

    private func filaMetrica(etiqueta: String, valor: String, destacado: Bool = false,
                             colorIcono: Color? = nil, icono: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(etiqueta)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Paleta.textoSecundario)
            HStack(spacing: 5) {
                Text(valor)
                    .font(.system(size: destacado ? 26 : 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                    .monospacedDigit()
                if let icono, let colorIcono {
                    Image(systemName: icono)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(colorIcono)
                }
            }
            Divider()
                .background(Paleta.divisor)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iconoDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return "figure.run"
        case .ciclismo: return "bicycle"
        case .trekking: return "figure.hiking"
        case .natacion: return "figure.pool.swim"
        case .fuerza: return "dumbbell.fill"
        case .otro, .triatlon: return "figure.mixed.cardio"
        }
    }

    private func nombreDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return Textos.regDeporteRunning
        case .ciclismo: return Textos.regDeporteCiclismo
        case .trekking: return Textos.regDeporteTrekking
        case .triatlon: return Textos.regDeporteTriatlon
        default: return deporte.rawValue.capitalized
        }
    }

    private func caloriasEstimadas(deporte: DeporteDeSesion, segundos: Int) -> Int {
        let minutos = max(1, segundos / 60)
        let factor: Double = switch deporte {
        case .ciclismo: 9.0
        case .running: 11.5
        case .trekking: 7.0
        default: 8.0
        }
        return Int((Double(minutos) * factor).rounded())
    }
}
