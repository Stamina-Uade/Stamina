import SwiftUI
import TrainerCore

/// Historial leído de GET /activities. El mapa de detalle se pide sólo al abrir
/// la actividad: el listado del servidor nunca arrastra puntos GPS.
///
/// Ronda 3: resumen Semana | Mes | Todo, filtro por
/// deporte, lista agrupada por mes y un estado vacío que lleva al entreno.
/// El resumen y el filtro se calculan sobre lo ya cargado (sin pedir más red).
struct HistorialDeActividadesView: View {
    let servicio: (any ServicioDeActividades)?
    /// `true` cuando es una pestaña de la barra (rediseño 2026-10): lleva el
    /// encabezado grande y no tiene botón de cerrar. `false` cuando se abre como
    /// hoja desde otra pantalla.
    var esPestana: Bool = false
    /// 🪤 Como hoja (desde Plan) llega igual: desde iOS 14 una `.sheet` hereda
    /// los `environmentObject` de la vista que la presenta.
    @EnvironmentObject private var estado: EstadoHome
    @Environment(\.dismiss) private var cerrar
    @State private var actividades: [Actividad] = []
    @State private var cursor: String?
    @State private var hayMas = true
    @State private var cargando = false
    @State private var fallo = false
    @State private var elegida: ActividadElegida?
    @State private var periodo: HistorialPeriodo = .semana
    @State private var deporteElegido: DeporteDeSesion?

    struct ActividadElegida: Identifiable {
        let actividad: Actividad
        var id: String { actividad.id }
    }

    private var unidades: SistemaDeUnidades { estado.sistemaDeUnidades }

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
        Group {
            if esPestana {
                lista(conEncabezado: true)
            } else {
                NavigationStack {
                    lista(conEncabezado: false)
                        .navigationTitle(Textos.historyTitle)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(Textos.historyClose) { cerrar() }
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { if actividades.isEmpty { await cargar() } }
        .sheet(item: $elegida) { seleccion in
            DetalleDeActividadView(
                actividad: seleccion.actividad,
                puntosIniciales: AlmacenDeRecorridos.compartido.puntos(para: seleccion.actividad.id),
                servicio: servicio,
                unidades: unidades
            )
        }
    }

    private func lista(conEncabezado: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
                if conEncabezado {
                    encabezado
                }

                if actividades.isEmpty, !cargando {
                    HistorialEstadoVacio(
                        fallo: fallo,
                        reintentar: { Task { await cargar(desdeElPrincipio: true) } },
                        empezar: empezarPrimeraSalida
                    )
                } else if !actividades.isEmpty {
                    HistorialFranjaDeResumen(
                        actividades: filtradas,
                        deporte: filtro,
                        unidades: unidades,
                        hayMasPorCargar: hayMas,
                        periodo: $periodo
                    )
                }

                CalendarioDeHitosView(unidades: unidades)

                salidas
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, conEncabezado ? TokensEspaciado.e8 : TokensEspaciado.e16)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .background(Paleta.fondo)
        .refreshable { await cargar(desdeElPrincipio: true) }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        EncabezadoDePestana(
            Textos.historyTab,
            sobretitulo: Textos.historySubtitle
        )
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

    /// Del estado vacío al entreno. Como hoja, primero se cierra.
    private func empezarPrimeraSalida() {
        if !esPestana { cerrar() }
        estado.ir(a: .entreno)
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
