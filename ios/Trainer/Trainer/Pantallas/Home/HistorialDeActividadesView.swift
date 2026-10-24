import SwiftUI
import TrainerCore

/// `historial` — "menos cosas a la vista" (decisión de Iván del 2026-10-23):
///
///   la barra fija «Historial» con el fueguito (`PantallaDePestana`)
///   el año entrenado (`CalendarioDeHitosView`): los años de la cuenta, el total, el
///     gráfico de enero a diciembre y el día elegido
///   "Tus salidas", una por fila, agrupadas por mes, como antes
///
/// Se fueron los botones Semana · Mes · Todo y la tarjeta "Tus números": el total del
/// año va en una línea. El listado sale de `GET /activities`; el mapa de cada salida
/// se pide sólo al abrirla.
struct HistorialDeActividadesView: View {
    let servicio: (any ServicioDeActividades)?
    @EnvironmentObject private var estado: EstadoHome
    @State private var actividades: [Actividad] = []
    @State private var cursor: String?
    @State private var hayMas = true
    @State private var cargando = false
    @State private var fallo = false
    @State private var elegida: ActividadElegida?
    @State private var deporteElegido: DeporteDeSesion?
    /// Los días de carrera de los objetivos, con su nombre.
    @State private var carreras: [String: String] = [:]
    /// Las series de gimnasio hechas, por día.
    @State private var gimnasioPorDia: [String: Int] = [:]

    /// Para el total del año hacen falta las salidas del año: se siguen pidiendo
    /// páginas hasta pasar el 1 de enero del año de alta, con este tope.
    private static let paginasComoMucho = 25

    struct ActividadElegida: Identifiable {
        let actividad: Actividad
        var id: String { actividad.id }
    }

    private var unidades: SistemaDeUnidades { estado.sistemaDeUnidades }

    private var fechaDeAlta: Date? {
        estado.perfil.map { Date(timeIntervalSince1970: TimeInterval($0.createdAtMs) / 1000) }
    }

    /// Los deportes que aparecen en lo cargado, en el orden de siempre. Los
    /// chips sólo ofrecen los del MVP (sólo running); las salidas de otros
    /// deportes que ya existan se siguen viendo en "Todos".
    private var deportesPresentes: [DeporteDeSesion] {
        let presentes = Set(actividades.map(\.sport))
        return DeporteDeSesion.allCases.filter { presentes.contains($0) && MVP.permite($0) }
    }

    /// El filtro vigente. Si el deporte elegido ya no está (p. ej. después de
    /// actualizar), vuelve solo a "Todos".
    private var filtro: DeporteDeSesion? {
        guard let deporteElegido, deportesPresentes.contains(deporteElegido) else { return nil }
        return deporteElegido
    }

    private var filtradas: [Actividad] {
        guard let filtro else { return actividades }
        return actividades.filter { $0.sport == filtro }
    }

    var body: some View {
        PantallaDePestana(Textos.historyTab, alRefrescar: { await cargar(desdeElPrincipio: true) }) {
            FueguitoDeLaBarra()
        } contenido: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
                CalendarioDeHitosView(unidades: unidades, fechaDeAlta: fechaDeAlta,
                                      carreras: carreras, gimnasioPorDia: gimnasioPorDia)

                if actividades.isEmpty, !cargando {
                    HistorialEstadoVacio(
                        fallo: fallo,
                        reintentar: { Task { await cargar(desdeElPrincipio: true) } },
                        empezar: { estado.ir(a: .entreno) }
                    )
                }

                salidas
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .task {
            if actividades.isEmpty { await cargar() }
            await cargarDelAnio()
        }
        .task { await cargarCarrerasYGimnasio() }
        .sheet(item: $elegida) { seleccion in
            DetalleDeActividadView(
                actividad: seleccion.actividad,
                puntosIniciales: AlmacenDeRecorridos.compartido.puntos(para: seleccion.actividad.id),
                servicio: servicio,
                unidades: unidades
            )
        }
    }

    // MARK: - Lista de salidas, por mes

    @ViewBuilder
    private var salidas: some View {
        if !actividades.isEmpty {
            EncabezadoDeSeccion(Textos.historyYourWorkouts,
                                detalle: Textos.historyTapOneForDetail)
            if deportesPresentes.count > 1 {
                HistorialChipsDeDeporte(deportes: deportesPresentes, elegido: $deporteElegido)
            }
        }

        LazyVStack(alignment: .leading, spacing: TokensEspaciado.e10, pinnedViews: [.sectionHeaders]) {
            ForEach(HistorialGrupoDeMes.agrupar(filtradas)) { grupo in
                Section {
                    ForEach(grupo.actividades, id: \.id) { actividad in
                        fila(actividad)
                    }
                } header: {
                    HistorialEncabezadoDeMes(grupo: grupo, unidades: unidades)
                }
            }
            // Vacío y sin cargar ya tiene sus propios botones (reintentar, empezar).
            if hayMas, !actividades.isEmpty || cargando {
                BotonTonal(Textos.historyLoadMore, cargando: cargando) {
                    Task { await cargar() }
                }
                .disabled(cargando)
                .padding(.vertical, TokensEspaciado.e8)
            }
        }
    }

    private func fila(_ actividad: Actividad) -> some View {
        Button { abrir(actividad) } label: {
            HistorialTarjetaDeActividad(actividad: actividad, unidades: unidades)
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityHint(Textos.historyRowHint)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .contextMenu {
            Button { abrir(actividad) } label: {
                Label(Textos.historyViewDetail, systemImage: "map")
            }
        }
    }

    // MARK: - Acciones

    private func abrir(_ actividad: Actividad) {
        Haptico.toque()
        elegida = ActividadElegida(actividad: actividad)
    }

    /// La página siguiente; con `desdeElPrincipio` (tirar hacia abajo, reintentar)
    /// vuelve a la primera y reemplaza la lista sólo cuando la respuesta llegó bien.
    private func cargar(desdeElPrincipio: Bool = false) async {
        guard !cargando, hayMas || desdeElPrincipio, let servicio else { return }
        cargando = true
        defer { cargando = false }
        let respuesta = await servicio.actividades(limite: 20, cursor: desdeElPrincipio ? nil : cursor)
        guard case .ok(let pagina) = respuesta else { fallo = true; return }
        fallo = false
        let base = desdeElPrincipio ? [] : actividades
        actividades = base + pagina.elementos.filter { nuevo in
            !base.contains { $0.id == nuevo.id }
        }
        cursor = pagina.paginacion.nextCursor
        hayMas = pagina.paginacion.hasMore
        // El calendario del año lee de `AlmacenDeHitos`: lo que llega se anota ahí.
        for actividad in pagina.elementos { AlmacenDeHitos.compartido.registrarActividad(actividad) }
    }

    /// Sigue pidiendo páginas mientras la salida más vieja cargada sea de un año que
    /// la cuenta tuvo, para que el gráfico y el total del año estén completos.
    private func cargarDelAnio() async {
        let cal = Calendar.current
        let desde = fechaDeAlta.flatMap { cal.date(from: DateComponents(year: cal.component(.year, from: $0))) }
            ?? cal.date(from: DateComponents(year: cal.component(.year, from: Date())))
        guard let desdeMs = desde.map({ Int64($0.timeIntervalSince1970 * 1000) }) else { return }
        var paginas = 0
        while hayMas, paginas < Self.paginasComoMucho, let masVieja = actividades.last?.startedAtMs, masVieja >= desdeMs {
            paginas += 1
            await cargar()
            if fallo { return }
        }
    }

    /// Las fechas de los objetivos (también las que vienen) y las series de gimnasio
    /// de cada día, para el calendario.
    private func cargarCarrerasYGimnasio() async {
        guard let plan = estado.repositorio.servicioDelCatalogo() else { return }
        var porDia: [String: String] = [:]
        if let perfil = estado.perfil, let ms = perfil.goalDateMs, let goal = perfil.goal {
            porDia[Self.claveDeCarrera(ms)] = TraduccionDelServidor.nombre(de: goal)
        }
        if case .ok(let planes) = await plan.planes() {
            for item in planes {
                if let ms = item.plan.eventDateMs {
                    porDia[Self.claveDeCarrera(ms)] = TraduccionDelServidor.nombre(de: item.plan.goal)
                }
            }
        }
        carreras = porDia
        if case .ok(let pagina) = await plan.sesionesDeGimnasio(limite: 100, cursor: nil) {
            var series: [String: Int] = [:]
            for sesion in pagina.elementos where sesion.setsDone > 0 {
                guard let ms = sesion.dateMs else { continue }
                let clave = AlmacenDeHitos.clave(para: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
                series[clave, default: 0] += Int(sesion.setsDone)
            }
            gimnasioPorDia = series
        }
    }

    /// La fecha de una carrera es un día SIN HORA: el servidor la guarda a las 00:00
    /// UTC (`goal_date_ms`) o a las 00:00 locales (`event_date_ms`); al mediodía UTC
    /// cae en el mismo día de calendario en cualquier zona de América y Europa.
    private static func claveDeCarrera(_ ms: Int64) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        let fecha = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let partes = utc.dateComponents([.year, .month, .day], from: fecha.addingTimeInterval(6 * 3600))
        let dia = Calendar.current.date(from: partes) ?? fecha
        return AlmacenDeHitos.clave(para: dia)
    }
}

/// Una actividad del listado: ícono en círculo, deporte, fecha, la distancia en
/// el acento y abajo el tiempo y el ritmo (o la velocidad). El chevron dice que
/// se abre.
private struct HistorialTarjetaDeActividad: View {
    let actividad: Actividad
    let unidades: SistemaDeUnidades

    private var metros: Int { Int(actividad.distanceM ?? 0) }
    private var segundos: Int { Int(actividad.durationS) }

    var body: some View {
        HStack(spacing: TokensEspaciado.e12) {
            ResumenIconoDeDeporte(deporte: actividad.sport)

            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                Text(actividad.sport.nombreVisible)
                    .estilo(.tituloCardGrande)
                    .lineLimit(1)
                Text(ResumenFormato.fechaHora(actividad.startedAtMs))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .lineLimit(1)
            }

            Spacer(minLength: TokensEspaciado.e8)

            VStack(alignment: .trailing, spacing: TokensEspaciado.e3) {
                HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e2) {
                    Text(Formato.distanciaNumero(metros, unidades: unidades))
                        .estilo(.metricaMedia, color: Paleta.acento)
                    Text(Formato.unidadDeDistancia(unidades))
                        .estilo(.labelCampo, color: Paleta.acento)
                }
                Text(Formato.cronometro(segundos: segundos))
                    .estilo(.resumenCifraChica, color: Paleta.textoSecundario)
                if let ritmo = HistorialFormato.ritmoOVelocidad(actividad, unidades: unidades) {
                    Text(ritmo)
                        .estilo(.resumenCifraChica, color: Paleta.textoTerciario)
                }
            }
            .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: TokensTipografia.tituloCardTamano, weight: .semibold))
                .foregroundStyle(Paleta.textoSecundario)
                .accessibilityHidden(true)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .resumenTarjeta()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct DetalleDeActividadView: View {
    let actividad: Actividad
    let puntosIniciales: [PuntoDeRecorrido]?
    let servicio: (any ServicioDeActividades)?
    @Environment(\.dismiss) private var cerrar
    @State private var puntos: [PuntoDeRecorrido]
    @State private var cargando: Bool
    /// Km o millas, lo que eligió la persona. Quien abre el detalle lo pasa.
    private let sistemaDeUnidades: SistemaDeUnidades

    init(actividad: Actividad, puntosIniciales: [PuntoDeRecorrido]? = nil, servicio: (any ServicioDeActividades)?,
         unidades: SistemaDeUnidades = .metrico) {
        self.actividad = actividad
        self.servicio = servicio
        self.sistemaDeUnidades = unidades
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

    private var metros: Int { Int(actividad.distanceM ?? 0) }
    private var segundos: Int { Int(actividad.durationS) }

    private var analisis: AnalisisDeRecorrido {
        AnalizadorDeRecorrido.analizar(
            puntos: puntos,
            deporte: actividad.sport,
            duracionTotalSegundos: segundos
        )
    }

    /// El ritmo que lleva el mapa 3D (desde 50 m, como siempre).
    private var ritmoPromedio: Int? {
        guard let dist = actividad.distanceM, dist > 50, actividad.durationS > 0 else { return nil }
        let segPorMetro = Double(actividad.durationS) / Double(dist)
        return Int((segPorMetro * 1000.0).rounded())
    }

    var body: some View {
        let analisis = self.analisis
        return NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e22) {
                    cabecera

                    ResumenMetricasPrincipales(datos: ResumenDatosDeMetricas(
                        deporte: actividad.sport,
                        metros: metros,
                        segundos: segundos,
                        analisis: analisis,
                        pulsoMedio: actividad.avgHrBpm.map(Int.init),
                        pulsoMaximo: actividad.maxHrBpm.map(Int.init),
                        desnivelMetros: Int(actividad.elevationGainM ?? 0),
                        calorias: actividad.kcal.map(Int.init)
                            ?? ResumenFormato.caloriasEstimadas(deporte: actividad.sport, segundos: segundos),
                        unidades: sistemaDeUnidades
                    ))

                    recorrido

                    if !analisis.splitsKm.isEmpty {
                        ResumenParciales(splits: analisis.splitsKm, deporte: actividad.sport,
                                         unidades: sistemaDeUnidades)
                    }

                    if !analisis.pausas.isEmpty || analisis.tramos.count > 1 {
                        ResumenTramos(filas: ResumenFilaDeTramo.desde(analisis: analisis),
                                      colorPausa: Paleta.acento,
                                      unidades: sistemaDeUnidades)
                    }

                    Spacer(minLength: TokensEspaciado.e16)
                }
                .padding(.horizontal, TokensEspaciado.e16)
            }
            .background(Paleta.fondo)
            .navigationTitle(actividad.sport.nombreVisible)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Textos.historyClose) { cerrar() }
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

    // MARK: - Cabecera: deporte, fecha y dispositivo

    private var cabecera: some View {
        HStack(spacing: TokensEspaciado.e12) {
            ResumenIconoDeDeporte(deporte: actividad.sport)
            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(actividad.sport.nombreVisible)
                    .estilo(.tituloPantalla)
                    .accessibilityAddTraits(.isHeader)
                Text(ResumenFormato.fechaHora(actividad.startedAtMs))
                    .estilo(.labelCampo, color: Paleta.textoSecundario)
            }
            Spacer(minLength: TokensEspaciado.e8)
            PildoraDeEstado(actividad.device == .reloj ? Textos.historySourceWatch : "iPhone",
                            simbolo: actividad.device == .reloj ? "applewatch" : "iphone")
        }
        .padding(.top, TokensEspaciado.e8)
    }

    // MARK: - Mapa, o su estado de carga / sin recorrido

    @ViewBuilder
    private var recorrido: some View {
        if !puntos.isEmpty {
            ResumenMapaDelRecorrido(
                puntos: puntos,
                deporte: actividad.sport,
                segundos: segundos,
                metros: metros,
                desnivelMetros: actividad.elevationGainM.map(Int.init),
                ritmoSegundosPorKm: ritmoPromedio,
                unidades: sistemaDeUnidades,
                inicioMs: actividad.startedAtMs
            )
        } else if cargando {
            ProgressView().tint(Paleta.acento)
            .frame(maxWidth: .infinity)
            .frame(height: TokensEspaciado.e40 * 3)
            .resumenTarjeta()
        } else {
            HStack(spacing: TokensEspaciado.e8) {
                Image(systemName: "map")
                    .font(.system(size: TokensTipografia.valorFilaTamano))
                    .foregroundStyle(Paleta.textoTerciario)
                    .accessibilityHidden(true)
                Text(Textos.historyNoRoute)
                    .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
            }
            .frame(maxWidth: .infinity)
            .frame(height: TokensEspaciado.e34 * 2)
            .resumenTarjeta()
        }
    }
}
