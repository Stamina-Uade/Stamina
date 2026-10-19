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
                            HistorialAvisoVacio(fallo: fallo)
                        }
                        ForEach(actividades, id: \.id) { actividad in
                            Button { elegida = ActividadElegida(actividad: actividad) } label: {
                                HistorialTarjetaDeActividad(actividad: actividad)
                            }
                            .buttonStyle(EstiloPresionado())
                        }
                        if hayMas {
                            BotonTonal(cargando ? Textos.historialCargando : Textos.historialMas) {
                                Task { await cargar() }
                            }
                            .disabled(cargando)
                            .padding(.vertical, TokensEspaciado.e8)
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
}

/// Una actividad del listado: ícono en círculo rosado, deporte, fecha, la
/// distancia en rosa y abajo el tiempo y el ritmo (o la velocidad).
private struct HistorialTarjetaDeActividad: View {
    let actividad: Actividad

    private var metros: Int { Int(actividad.distanceM ?? 0) }
    private var segundos: Int { Int(actividad.durationS) }

    /// Ritmo o velocidad promedio, sólo si hay distancia para calcularlo.
    private var ritmoOVelocidad: String? {
        if actividad.sport == .ciclismo {
            guard metros >= 50, segundos > 0 else { return nil }
            return Formato.velocidad(metros: metros, segundos: segundos, unidades: .metrico)
        }
        guard let ritmo = ResumenFormato.ritmoMedio(metros: metros, segundos: segundos) else { return nil }
        return "\(Formato.ritmo(segundosPorKm: ritmo, unidades: .metrico)) \(ResumenFormato.unidadDeRitmo(.metrico))"
    }

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
                    Text(Formato.distanciaNumero(metros, unidades: .metrico))
                        .estilo(.metricaMedia, color: Paleta.acento)
                    Text(Formato.unidadDeDistancia(.metrico))
                        .estilo(.labelCampo, color: Paleta.acento)
                }
                Text(Formato.cronometro(segundos: segundos))
                    .estilo(.resumenCifraChica, color: Paleta.textoSecundario)
                if let ritmoOVelocidad {
                    Text(ritmoOVelocidad)
                        .estilo(.resumenCifraChica, color: Paleta.textoTerciario)
                }
            }
            .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: TokensTipografia.notaTamano, weight: .bold))
                .foregroundStyle(Paleta.textoTerciario)
                .accessibilityHidden(true)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .resumenTarjeta()
        .accessibilityElement(children: .combine)
    }
}

/// Lista vacía o error de carga, en una tarjeta en vez de texto suelto.
private struct HistorialAvisoVacio: View {
    let fallo: Bool

    var body: some View {
        HStack(spacing: TokensEspaciado.e12) {
            Image(systemName: fallo ? "exclamationmark.triangle.fill" : "figure.run")
                .font(.system(size: TokensEspaciado.e20, weight: .semibold))
                .foregroundStyle(fallo ? Paleta.error : Paleta.acento)
                .accessibilityHidden(true)
            Text(fallo ? Textos.historialError : Textos.historialVacio)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(TokensEspaciado.e14)
        .resumenTarjeta()
    }
}

struct DetalleDeActividadView: View {
    let actividad: Actividad
    let puntosIniciales: [PuntoDeRecorrido]?
    let servicio: (any ServicioDeActividades)?
    @Environment(\.dismiss) private var cerrar
    @State private var puntos: [PuntoDeRecorrido]
    @State private var cargando: Bool
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
            PildoraDeEstado(actividad.device == .reloj ? String(localized: "Reloj", comment: "Dispositivo de origen") : "iPhone",
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
            HStack(spacing: TokensEspaciado.e8) {
                ProgressView().tint(Paleta.acento)
                Text(Textos.historialCargando)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
            }
            .frame(maxWidth: .infinity)
            .frame(height: TokensEspaciado.e40 * 3)
            .resumenTarjeta()
        } else {
            HStack(spacing: TokensEspaciado.e8) {
                Image(systemName: "map")
                    .font(.system(size: TokensTipografia.valorFilaTamano))
                    .foregroundStyle(Paleta.textoTerciario)
                    .accessibilityHidden(true)
                Text(Textos.historialSinRecorrido)
                    .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
            }
            .frame(maxWidth: .infinity)
            .frame(height: TokensEspaciado.e34 * 2)
            .resumenTarjeta()
        }
    }
}
