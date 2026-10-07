import CoreLocation
import Foundation
import HealthKit
import TrainerCore

/// Una salida real se guarda en disco desde el primer punto. El archivo es una
/// cola local de datos capturados, nunca una fuente de datos de ejemplo.
struct SalidaCapturada: Codable {
    var id: String
    var deporte: DeporteDeSesion
    var inicioMs: Int64
    var segundos: Int
    var metros: Int
    var puntos: [PuntoDeRecorrido]
    var segmentos: [SegmentoActividad]?
    var pausas: [PausaActividad]?
    var dispositivo: DispositivoDeOrigen?
    var pulsoMedio: Int?
    var pulsoMaximo: Int?
}

private struct SalidasEnDisco: Codable {
    var activa: SalidaCapturada?
    var pendientes: [SalidaCapturada]
}

final class AlmacenDeSalidas {
    private let archivo: URL?

    init(nombre: String = "salidas-capturadas.json") {
        archivo = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))?
            .appendingPathComponent(nombre)
    }

    fileprivate func leer() -> (SalidaCapturada?, [SalidaCapturada]) {
        guard let archivo, let datos = try? Data(contentsOf: archivo),
              let guardado = try? JSONDecoder().decode(SalidasEnDisco.self, from: datos) else { return (nil, []) }
        return (guardado.activa, guardado.pendientes)
    }

    fileprivate func guardar(activa: SalidaCapturada?, pendientes: [SalidaCapturada]) {
        guard var archivo, let datos = try? JSONEncoder().encode(SalidasEnDisco(activa: activa, pendientes: pendientes)) else { return }
        try? datos.write(to: archivo, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var recursos = URLResourceValues()
        recursos.isExcludedFromBackup = true
        try? archivo.setResourceValues(recursos)
    }

    func borrar() {
        guard let archivo else { return }
        try? FileManager.default.removeItem(at: archivo)
    }
}

/// GPS del iPhone. Los puntos con precisión mala, viejos o que implican un salto
/// imposible no cuentan distancia. La duración descuenta las pausas.
@MainActor
final class SeguimientoDeSalida: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Fase { case detenida, corriendo, pausada }

    @Published private(set) var fase: Fase = .detenida
    @Published private(set) var segundos = 0
    @Published private(set) var metros = 0
    @Published private(set) var puntos: [PuntoDeRecorrido] = []
    @Published private(set) var segmentos: [SegmentoActividad] = []
    @Published private(set) var pausas: [PausaActividad] = []
    @Published private(set) var puntosPausaActual: [PuntoDeRecorrido] = []
    @Published private(set) var ubicacion: CLLocationCoordinate2D?
    @Published private(set) var permiso: CLAuthorizationStatus
    @Published private(set) var errorDeUbicacion = false
    @Published private(set) var pendientes = 0
    @Published private(set) var rumbo: Double = 0.0

    private let manager = CLLocationManager()
    private let almacen: AlmacenDeSalidas
    private let servicio: (any ServicioDeActividades)?
    private var activa: SalidaCapturada?
    private var cola: [SalidaCapturada]
    private var inicioDelTramo: Date?
    private var segundosAcumulados = 0
    private var filtroDeDistancia = FiltroDeDistanciaGPS()
    private var reloj: Timer?
    private var subiendo = false
    private var inicioSolicitado: DeporteDeSesion?
    var alCambiar: ((EstadoDeSalidaCompartido) -> Void)?
    private var ultimoEnvioMs: Int64 = 0

    // Seguimiento interno de segmentos y pausas
    private var puntosSegmentoActual: [PuntoDeRecorrido] = []
    private var inicioSegmentoActualMs: Int64 = 0
    private var metrosInicioSegmento = 0
    private var segundosInicioSegmento = 0
    private var inicioPausaMs: Int64 = 0
    private var inicioPausaCoords: CLLocationCoordinate2D?

    init(servicio: (any ServicioDeActividades)?, almacen: AlmacenDeSalidas = AlmacenDeSalidas()) {
        self.servicio = servicio
        self.almacen = almacen
        (activa, cola) = almacen.leer()
        permiso = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = kCLHeadingFilterNone
            manager.startUpdatingHeading()
        }
        // Si el proceso murió en plena salida, se recupera PAUSADA: nunca se
        // suma tiempo ni distancia sin observación del sensor.
        if let activa {
            fase = .pausada
            segundos = activa.segundos
            segundosAcumulados = activa.segundos
            metros = activa.metros
            puntos = activa.puntos
            segmentos = activa.segmentos ?? []
            pausas = activa.pausas ?? []
            ubicacion = activa.puntos.last.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        }
        if ubicacion == nil, let loc = manager.location?.coordinate {
            ubicacion = loc
        }
        if permiso == .authorizedWhenInUse || permiso == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        pendientes = cola.count
        for salida in cola where !salida.puntos.isEmpty {
            AlmacenDeRecorridos.compartido.guardar(id: salida.id, puntos: salida.puntos)
        }
    }

    var ritmoSegPorKm: Int? {
        guard metros >= 100, segundos > 0 else { return nil }
        return Int((Double(segundos) * 1000 / Double(metros)).rounded())
    }

    /// Obtiene la ubicación para abrir el mapa centrado aunque todavía no haya
    /// empezado una salida. Nunca agrega ese punto al recorrido.
    func prepararMapa() {
        errorDeUbicacion = false
        if let loc = manager.location?.coordinate {
            ubicacion = loc
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            errorDeUbicacion = true
        }
    }

    func pedirPermisoYEmpezar(deporte: DeporteDeSesion) {
        guard fase == .detenida else { return }
        errorDeUbicacion = false
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            empezar(deporte: deporte)
        case .notDetermined:
            inicioSolicitado = deporte
            manager.requestWhenInUseAuthorization()
        default:
            errorDeUbicacion = true
        }
    }

    private func empezar(deporte: DeporteDeSesion) {
        NotificadorDeEntrenamiento.preparar()
        let ahora = Date()
        let ahoraMs = Int64((ahora.timeIntervalSince1970 * 1000).rounded())
        activa = SalidaCapturada(id: UUID().uuidString, deporte: deporte,
                                inicioMs: ahoraMs,
                                segundos: 0, metros: 0, puntos: [],
                                segmentos: [], pausas: [],
                                dispositivo: .telefono,
                                pulsoMedio: nil, pulsoMaximo: nil)
        segundos = 0
        metros = 0
        puntos = []
        segmentos = []
        pausas = []
        puntosSegmentoActual = []
        puntosPausaActual = []
        inicioSegmentoActualMs = ahoraMs
        metrosInicioSegmento = 0
        segundosInicioSegmento = 0
        filtroDeDistancia.reiniciar()
        segundosAcumulados = 0
        fase = .corriendo
        continuarGPS(desde: ahora)
        if HKHealthStore.isHealthDataAvailable() {
            let healthStore = HKHealthStore()
            let config = HKWorkoutConfiguration()
            switch deporte {
            case .ciclismo: config.activityType = .cycling
            case .trekking: config.activityType = .hiking
            case .natacion: config.activityType = .swimming
            default: config.activityType = .running
            }
            config.locationType = .outdoor
            healthStore.startWatchApp(with: config) { _, _ in }
        }
        guardar()
        publicarSiCorresponde(forzar: true)
    }

    func pausarOReanudar() {
        let ahora = Date()
        let ahoraMs = Int64((ahora.timeIntervalSince1970 * 1000).rounded())
        switch fase {
        case .detenida: break
        case .corriendo:
            actualizarReloj()
            segundosAcumulados = segundos
            inicioDelTramo = nil
            fase = .pausada
            reloj?.invalidate()
            reloj = nil
            filtroDeDistancia.reiniciar()

            // Cerrar el tramo activo
            let distSeg = max(0, metros - metrosInicioSegmento)
            let durSeg = max(1, segundos - segundosInicioSegmento)
            let primerPunto = puntosSegmentoActual.first ?? puntos.first
            let ultimoPunto = puntosSegmentoActual.last ?? puntos.last
            let cInicio = primerPunto.map { CoordenadaGPS(latitud: $0.lat, longitud: $0.lon) }
                ?? CoordenadaGPS(latitud: ubicacion?.latitude ?? 0, longitud: ubicacion?.longitude ?? 0)
            let cFin = ultimoPunto.map { CoordenadaGPS(latitud: $0.lat, longitud: $0.lon) }
                ?? CoordenadaGPS(latitud: ubicacion?.latitude ?? 0, longitud: ubicacion?.longitude ?? 0)

            let seg = SegmentoActividad(
                numero: segmentos.count + 1,
                inicioMs: inicioSegmentoActualMs > 0 ? inicioSegmentoActualMs : ahoraMs,
                finMs: ahoraMs,
                distanciaMetros: distSeg,
                duracionSegundos: durSeg,
                inicioCoords: cInicio,
                finCoords: cFin,
                puntos: puntosSegmentoActual
            )
            segmentos.append(seg)
            puntosSegmentoActual = []

            // Iniciar período de pausa
            inicioPausaMs = ahoraMs
            inicioPausaCoords = ubicacion
            puntosPausaActual = []
            if let loc = ubicacion {
                puntosPausaActual.append(PuntoDeRecorrido(lat: loc.latitude, lon: loc.longitude, atMs: ahoraMs))
            }

            guardar()
            publicarSiCorresponde(forzar: true)

        case .pausada:
            fase = .corriendo
            filtroDeDistancia.reiniciar()

            // Cerrar período de pausa
            let durPausa = max(1, Int((ahoraMs - inicioPausaMs) / 1000))
            let cInicio = CoordenadaGPS(latitud: inicioPausaCoords?.latitude ?? ubicacion?.latitude ?? 0,
                                       longitud: inicioPausaCoords?.longitude ?? ubicacion?.longitude ?? 0)
            let cFin = CoordenadaGPS(latitud: ubicacion?.latitude ?? cInicio.latitud,
                                    longitud: ubicacion?.longitude ?? cInicio.longitud)
            if let loc = ubicacion, (puntosPausaActual.last?.lat != loc.latitude || puntosPausaActual.last?.lon != loc.longitude) {
                puntosPausaActual.append(PuntoDeRecorrido(lat: loc.latitude, lon: loc.longitude, atMs: ahoraMs))
            }

            let p = PausaActividad(
                numero: pausas.count + 1,
                inicioMs: inicioPausaMs,
                finMs: ahoraMs,
                duracionSegundos: durPausa,
                inicioCoords: cInicio,
                finCoords: cFin,
                puntosPausa: puntosPausaActual
            )
            pausas.append(p)
            puntosPausaActual = []

            // Abrir nuevo tramo
            inicioSegmentoActualMs = ahoraMs
            metrosInicioSegmento = metros
            segundosInicioSegmento = segundos
            puntosSegmentoActual = []

            continuarGPS(desde: ahora)
            guardar()
            publicarSiCorresponde(forzar: true)
        }
    }

    private func continuarGPS(desde fecha: Date) {
        inicioDelTramo = fecha
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        reloj?.invalidate()
        reloj = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.actualizarReloj() }
        }
    }

    private func actualizarReloj() {
        guard let inicioDelTramo else { return }
        segundos = segundosAcumulados + max(0, Int(Date().timeIntervalSince(inicioDelTramo)))
        activa?.segundos = segundos
        publicarSiCorresponde()
    }

    @discardableResult
    func terminar() -> SalidaCapturada? {
        guard activa != nil else { return nil }
        let ahora = Date()
        let ahoraMs = Int64((ahora.timeIntervalSince1970 * 1000).rounded())

        if fase == .corriendo {
            actualizarReloj()
            let distSeg = max(0, metros - metrosInicioSegmento)
            let durSeg = max(1, segundos - segundosInicioSegmento)
            let primerPunto = puntosSegmentoActual.first ?? puntos.first
            let ultimoPunto = puntosSegmentoActual.last ?? puntos.last
            let cInicio = primerPunto.map { CoordenadaGPS(latitud: $0.lat, longitud: $0.lon) }
                ?? CoordenadaGPS(latitud: ubicacion?.latitude ?? 0, longitud: ubicacion?.longitude ?? 0)
            let cFin = ultimoPunto.map { CoordenadaGPS(latitud: $0.lat, longitud: $0.lon) }
                ?? CoordenadaGPS(latitud: ubicacion?.latitude ?? 0, longitud: ubicacion?.longitude ?? 0)

            let seg = SegmentoActividad(
                numero: segmentos.count + 1,
                inicioMs: inicioSegmentoActualMs > 0 ? inicioSegmentoActualMs : ahoraMs,
                finMs: ahoraMs,
                distanciaMetros: distSeg,
                duracionSegundos: durSeg,
                inicioCoords: cInicio,
                finCoords: cFin,
                puntos: puntosSegmentoActual
            )
            segmentos.append(seg)
        } else if fase == .pausada {
            let durPausa = max(1, Int((ahoraMs - inicioPausaMs) / 1000))
            let cInicio = CoordenadaGPS(latitud: inicioPausaCoords?.latitude ?? ubicacion?.latitude ?? 0,
                                       longitud: inicioPausaCoords?.longitude ?? ubicacion?.longitude ?? 0)
            let cFin = CoordenadaGPS(latitud: ubicacion?.latitude ?? cInicio.latitud,
                                    longitud: ubicacion?.longitude ?? cInicio.longitud)
            let p = PausaActividad(
                numero: pausas.count + 1,
                inicioMs: inicioPausaMs,
                finMs: ahoraMs,
                duracionSegundos: durPausa,
                inicioCoords: cInicio,
                finCoords: cFin,
                puntosPausa: puntosPausaActual
            )
            pausas.append(p)
        }

        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        reloj?.invalidate()
        reloj = nil
        inicioDelTramo = nil
        fase = .detenida

        var guardada: SalidaCapturada?
        if var terminada = activa {
            terminada.segundos = max(1, segundos)
            terminada.metros = metros
            terminada.puntos = puntos
            terminada.segmentos = segmentos
            terminada.pausas = pausas
            AlmacenDeRecorridos.compartido.guardar(id: terminada.id, puntos: terminada.puntos)
            cola.append(terminada)
            notificar(terminada)
            guardada = terminada
        }
        publicarSiCorresponde(forzar: true)
        activa = nil
        pendientes = cola.count
        guardar()
        Task { await subirPendientes() }
        return guardada
    }

    /// Cierra una captura inválida sin crear actividad, ruta ni notificación.
    func descartar() {
        guard activa != nil else { return }
        if fase == .corriendo { actualizarReloj() }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        reloj?.invalidate()
        reloj = nil
        inicioDelTramo = nil
        fase = .detenida
        publicarSiCorresponde(forzar: true)
        activa = nil
        segundos = 0
        metros = 0
        puntos = []
        segmentos = []
        pausas = []
        puntosSegmentoActual = []
        puntosPausaActual = []
        metrosInicioSegmento = 0
        segundosInicioSegmento = 0
        filtroDeDistancia.reiniciar()
        segundosAcumulados = 0
        guardar()
    }

    func subirPendientes() async {
        guard !subiendo, let servicio else { return }
        subiendo = true
        defer { subiendo = false }
        while let salida = cola.first {
            let cuerpo = ActividadEntrada(sport: salida.deporte, startedAtMs: salida.inicioMs,
                                          durationS: Int64(salida.segundos), distanceM: Int64(salida.metros),
                                          avgHrBpm: salida.pulsoMedio.map(Int64.init),
                                          maxHrBpm: salida.pulsoMaximo.map(Int64.init),
                                          device: salida.dispositivo ?? .telefono)
            guard case .ok = await servicio.guardarActividad(id: salida.id, cuerpo) else { break }
            if !salida.puntos.isEmpty {
                let recorrido = RecorridoParaServidor.preparar(salida.puntos)
                guard case .ok = await servicio.guardarRecorrido(id: salida.id, recorrido) else { break }
            }
            cola.removeFirst()
            pendientes = cola.count
            guardar()
        }
    }

    @discardableResult
    func recibirDelReloj(_ salida: SalidaDelReloj) -> Bool {
        guard !cola.contains(where: { $0.id == salida.id }) else { return true }
        let capturada = SalidaCapturada(id: salida.id, deporte: salida.deporte,
                                        inicioMs: salida.inicioMs, segundos: salida.segundos,
                                        metros: salida.metros, puntos: salida.puntos,
                                        dispositivo: .reloj, pulsoMedio: salida.pulsoMedio,
                                        pulsoMaximo: salida.pulsoMaximo)
        AlmacenDeRecorridos.compartido.guardar(id: salida.id, puntos: salida.puntos)
        cola.append(capturada)
        pendientes = cola.count
        guardar()
        // La felicitación pertenece al iPhone incluso cuando toda la medición se
        // hizo en el reloj. Se programa después de incorporar la ruta a la cola.
        notificar(capturada)
        Task { await subirPendientes() }
        return true
    }

    private func notificar(_ salida: SalidaCapturada) {
        guard salida.metros > 0 && salida.segundos >= 10 else { return }
        let deporte: String = switch salida.deporte {
        case .running: Textos.notificacionEntrenamientoRunning
        case .ciclismo: Textos.notificacionEntrenamientoCiclismo
        case .trekking: Textos.notificacionEntrenamientoTrekking
        case .natacion: Textos.notificacionEntrenamientoNatacion
        case .fuerza: Textos.notificacionEntrenamientoFuerza
        case .otro: Textos.notificacionEntrenamientoOtro
        case .triatlon: Textos.regDeporteTriatlon
        }
        let distancia = Textos.notificacionEntrenamientoDistancia(
            Formato.kilometros(salida.metros, decimales: 2))
        let duracion = Formato.cronometroCompleto(segundos: salida.segundos)
        NotificadorDeEntrenamiento.enviar(
            id: salida.id,
            titulo: Textos.notificacionEntrenamientoTitulo,
            cuerpo: Textos.notificacionEntrenamientoCuerpo(deporte, duracion, distancia))
    }

    private func guardar() {
        activa?.segundos = segundos
        activa?.metros = metros
        activa?.puntos = puntos
        activa?.segmentos = segmentos
        activa?.pausas = pausas
        almacen.guardar(activa: activa, pendientes: cola)
        publicarSiCorresponde()
    }

    private func publicarSiCorresponde(forzar: Bool = false) {
        guard let activa, let alCambiar else { return }
        let ahora = Int64((Date().timeIntervalSince1970 * 1000).rounded())
        guard forzar || ahora - ultimoEnvioMs >= 1000 else { return }
        ultimoEnvioMs = ahora
        alCambiar(EstadoDeSalidaCompartido(id: activa.id, deporte: activa.deporte,
                                           corriendo: fase == .corriendo,
                                           pausada: fase == .pausada, segundos: segundos,
                                           metros: metros, ritmoSegPorKm: ritmoSegPorKm,
                                           puntos: puntos, actualizadoMs: ahora))
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            permiso = manager.authorizationStatus
            if inicioSolicitado == nil,
               permiso == .authorizedWhenInUse || permiso == .authorizedAlways {
                manager.startUpdatingLocation()
            }
            if let deporte = inicioSolicitado {
                inicioSolicitado = nil
                if permiso == .authorizedWhenInUse || permiso == .authorizedAlways {
                    empezar(deporte: deporte)
                } else if permiso != .notDetermined { errorDeUbicacion = true }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in errorDeUbicacion = true }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let grados = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        if grados >= 0 {
            Task { @MainActor in
                self.rumbo = grados
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for lugar in locations {
                guard lugar.horizontalAccuracy >= 0, lugar.horizontalAccuracy <= 150,
                      abs(lugar.timestamp.timeIntervalSinceNow) <= 60 else { continue }
                ubicacion = lugar.coordinate
                if lugar.course >= 0 {
                    rumbo = lugar.course
                }

                if fase == .pausada {
                    // El usuario se mueve mientras el entrenamiento está en pausa:
                    // 1. NO se suma a la distancia del entrenamiento.
                    // 2. Se registran puntos para trazar la línea discontinua / punteada.
                    let ahoraMs = Int64((lugar.timestamp.timeIntervalSince1970 * 1000).rounded())
                    let puntoPausa = PuntoDeRecorrido(lat: lugar.coordinate.latitude, lon: lugar.coordinate.longitude, atMs: ahoraMs)
                    if let ultimo = puntosPausaActual.last {
                        let d = SegmentadorDeRecorrido.distanciaMetros(lat1: ultimo.lat, lon1: ultimo.lon,
                                                                      lat2: puntoPausa.lat, lon2: puntoPausa.lon)
                        if d >= 2.0 {
                            puntosPausaActual.append(puntoPausa)
                        }
                    } else {
                        puntosPausaActual.append(puntoPausa)
                    }
                    guardar()
                    continue
                }

                guard fase == .corriendo else { continue }
                guard lugar.horizontalAccuracy <= 35 else { continue }
                guard let deporte = activa?.deporte else { continue }
                let deltaMetros = filtroDeDistancia.agregar(
                    MuestraGPS(latitud: lugar.coordinate.latitude,
                               longitud: lugar.coordinate.longitude,
                               instanteMs: Int64((lugar.timestamp.timeIntervalSince1970 * 1_000).rounded()),
                               precisionMetros: lugar.horizontalAccuracy,
                               velocidadMetrosPorSegundo: lugar.speed),
                    deporte: deporte)
                metros += deltaMetros
                let punto = PuntoDeRecorrido(lat: lugar.coordinate.latitude, lon: lugar.coordinate.longitude,
                                             atMs: Int64((lugar.timestamp.timeIntervalSince1970 * 1000).rounded()))
                if let ultimo = puntos.last {
                    let dist = SegmentadorDeRecorrido.distanciaMetros(lat1: ultimo.lat, lon1: ultimo.lon,
                                                                     lat2: punto.lat, lon2: punto.lon)
                    let dt = Double(punto.atMs - ultimo.atMs) / 1000.0
                    let velMax: Double = deporte == .ciclismo ? 28.0 : 14.0
                    if dt > 0 && (dist / dt) > velMax { continue }
                    if lugar.speed >= 0, dt > 0 {
                        let distMax = max(lugar.speed * 2.2, 5.0) * dt + max(8.0, lugar.horizontalAccuracy)
                        if dist > distMax { continue }
                    }
                    if dist >= 2.0 || (dt >= 3.0 && dist >= 0.8) {
                        puntos.append(punto)
                        puntosSegmentoActual.append(punto)
                    }
                } else {
                    puntos.append(punto)
                    puntosSegmentoActual.append(punto)
                }
                guardar()
            }
        }
    }
}
