import Combine
import CoreLocation
import Foundation
import HealthKit
import TrainerCore
import UIKit

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
    /// La cuenta dueña de la salida. `nil` en las guardadas antes de que existiera:
    /// ésas se suben con la sesión que haya, como siempre.
    var usuarioId: String?
}

private struct SalidasEnDisco: Codable {
    var activa: SalidaCapturada?
    var pendientes: [SalidaCapturada]
    /// Las que el servidor rechazó para siempre (un 4xx que no se arregla
    /// reintentando). 🛑 No se borran nunca: son entrenamientos de la persona.
    var cuarentena: [SalidaCapturada]?
}

final class AlmacenDeSalidas {
    private let archivo: URL?

    init(nombre: String = "salidas-capturadas.json") {
        archivo = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))?
            .appendingPathComponent(nombre)
    }

    fileprivate func leer() -> SalidasEnDisco {
        let vacio = SalidasEnDisco(activa: nil, pendientes: [], cuarentena: [])
        guard let archivo, let datos = try? Data(contentsOf: archivo) else { return vacio }
        guard let guardado = try? JSONDecoder().decode(SalidasEnDisco.self, from: datos) else {
            // 🛑 Ilegible: se aparta antes de seguir. Si no, el próximo guardado
            // pisaba con una cola vacía las salidas que todavía no se subieron.
            ArchivoIlegible.apartar(archivo)
            return vacio
        }
        return guardado
    }

    fileprivate func guardar(activa: SalidaCapturada?, pendientes: [SalidaCapturada],
                             cuarentena: [SalidaCapturada]) {
        let contenido = SalidasEnDisco(activa: activa, pendientes: pendientes, cuarentena: cuarentena)
        guard var archivo, let datos = try? JSONEncoder().encode(contenido) else { return }
        try? datos.write(to: archivo, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var recursos = URLResourceValues()
        recursos.isExcludedFromBackup = true
        try? archivo.setResourceValues(recursos)
    }

    func borrar() {
        guard let archivo else { return }
        try? FileManager.default.removeItem(at: archivo)
    }

    /// Al cerrar sesión: las salidas sin dueño quedan a nombre de quien se va. Nada
    /// se borra —puede no haber llegado al servidor— y, con dueño, la próxima cuenta
    /// no las ve ni las sube (`SeguimientoDeSalida.esDeLaCuentaActual`).
    func asignarDueno(_ usuario: String?) {
        guard let usuario, !usuario.isEmpty, let archivo,
              FileManager.default.fileExists(atPath: archivo.path) else { return }
        var contenido = leer()
        contenido.activa = contenido.activa.map { SalidaCapturada.conDueno($0, usuario) }
        contenido.pendientes = contenido.pendientes.map { SalidaCapturada.conDueno($0, usuario) }
        let cuarentena = (contenido.cuarentena ?? []).map { SalidaCapturada.conDueno($0, usuario) }
        guardar(activa: contenido.activa, pendientes: contenido.pendientes, cuarentena: cuarentena)
    }
}

extension SalidaCapturada {
    /// La misma salida, a nombre de `usuario` si todavía no tenía dueño.
    static func conDueno(_ salida: SalidaCapturada, _ usuario: String) -> SalidaCapturada {
        guard salida.usuarioId == nil else { return salida }
        var conDueno = salida
        conDueno.usuarioId = usuario
        return conDueno
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
    private var cuarentena: [SalidaCapturada]
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

    /// Escritura a disco con cada fix: como mucho cada `intervaloDeGuardadoMs` o
    /// cada `puntosPorGuardado` muestras. Pausar, reanudar, terminar y pasar a
    /// segundo plano guardan siempre. Un cierre forzado pierde, a lo sumo, esa ventana.
    static let intervaloDeGuardadoMs: Int64 = 10_000
    static let puntosPorGuardado = 20
    private var ultimoGuardadoMs: Int64 = 0
    private var muestrasSinGuardar = 0
    /// La pantalla previa al entreno pidió el mapa: el GPS y la brújula quedan
    /// prendidos aunque no haya salida. Sin eso, en reposo sólo se pide un fix.
    private var mapaPedido = false
    private var suscripciones = Set<AnyCancellable>()

    init(servicio: (any ServicioDeActividades)?, almacen: AlmacenDeSalidas = AlmacenDeSalidas()) {
        self.servicio = servicio
        self.almacen = almacen
        let guardado = almacen.leer()
        activa = guardado.activa
        cola = guardado.pendientes
        cuarentena = guardado.cuarentena ?? []
        permiso = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = kCLHeadingFilterNone
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
            // La pausa empieza en lo último que se observó, no en el epoch: si no,
            // reanudar o terminar registraba una pausa de 50 años.
            inicioPausaMs = Self.inicioDePausaRecuperada(activa, ahoraMs: Self.ahoraEnMs())
            inicioPausaCoords = ubicacion
        }
        if ubicacion == nil, let loc = manager.location?.coordinate {
            ubicacion = loc
        }
        if permiso == .authorizedWhenInUse || permiso == .authorizedAlways {
            // En reposo alcanza con un fix (el mapa centrado, el aviso de calor). El
            // GPS continuo y la brújula, sólo con una salida o con el mapa pedido.
            if fase != .detenida { encenderSensores() } else { manager.requestLocation() }
        }
        actualizarPendientes()
        for salida in cola where !salida.puntos.isEmpty && esDeLaCuentaActual(salida) {
            AlmacenDeRecorridos.compartido.guardar(id: salida.id, puntos: salida.puntos)
        }
        escucharLaApp()
    }

    static func ahoraEnMs() -> Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded()) }

    /// Lo último observado de una salida que quedó a medias: el último punto, el
    /// cierre del último tramo (si murió en pausa) o de la última pausa.
    static func inicioDePausaRecuperada(_ salida: SalidaCapturada, ahoraMs: Int64) -> Int64 {
        let candidatos: [Int64] = [salida.puntos.last?.atMs, salida.segmentos?.last?.finMs,
                                   salida.pausas?.last?.finMs].compactMap { $0 }.filter { $0 > 0 }
        guard let ultimo = candidatos.max() else { return ahoraMs }
        return min(ultimo, ahoraMs)
    }

    private func encenderSensores() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    private func apagarSensores() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = false
        mapaPedido = false
    }

    private func escucharLaApp() {
        // Al irse a segundo plano (o cerrarse) se guarda lo que la ventana de
        // `guardarSiToca` todavía no escribió.
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.activa != nil else { return }
                self.guardar()
            }
            .store(in: &suscripciones)
        NotificationCenter.default.publisher(for: DuenoDeLosDatosLocales.cambio)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] aviso in
                let usuario = aviso.userInfo?[DuenoDeLosDatosLocales.claveUsuario] as? String
                let anterior = aviso.userInfo?[DuenoDeLosDatosLocales.claveAnterior] as? String
                self?.cambioDeCuenta(usuario: usuario, anterior: anterior)
            }
            .store(in: &suscripciones)
    }

    // MARK: - Cuenta

    /// Una salida con dueño sólo se sube (y se cuenta como pendiente) con la sesión
    /// de ese dueño. Sin dueño —guardadas antes de esta versión— con la que haya.
    func esDeLaCuentaActual(_ salida: SalidaCapturada) -> Bool {
        guard let dueno = salida.usuarioId else { return true }
        return dueno == DuenoDeLosDatosLocales.actual
    }

    /// Las que el servidor rechazó para siempre y esperan en disco.
    var cantidadEnCuarentena: Int { cuarentena.count }

    private func actualizarPendientes() {
        pendientes = cola.filter { esDeLaCuentaActual($0) }.count
    }

    /// 🛑 Cerrar sesión no borra la cola: lo que no llegó al servidor se perdería.
    /// Lo que no tenía dueño queda a nombre de quien sale; la próxima cuenta no lo
    /// sube ni lo cuenta, y vuelve a salir cuando esa persona entra de nuevo.
    private func cambioDeCuenta(usuario: String?, anterior: String?) {
        if usuario == nil, let anterior {
            activa = activa.map { SalidaCapturada.conDueno($0, anterior) }
            cola = cola.map { SalidaCapturada.conDueno($0, anterior) }
            cuarentena = cuarentena.map { SalidaCapturada.conDueno($0, anterior) }
            guardar()
        }
        actualizarPendientes()
        if usuario != nil { Task { await subirPendientes() } }
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
        mapaPedido = true
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            encenderSensores()
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
                                pulsoMedio: nil, pulsoMaximo: nil,
                                usuarioId: DuenoDeLosDatosLocales.actual)
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
        encenderSensores()
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

        apagarSensores()
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
        actualizarPendientes()
        guardar()
        Task { await subirPendientes() }
        return guardada
    }

    /// Cierra una captura inválida sin crear actividad, ruta ni notificación.
    func descartar() {
        guard activa != nil else { return }
        if fase == .corriendo { actualizarReloj() }
        apagarSensores()
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

    enum DesenlaceDeSubida: Equatable {
        case aceptada
        /// Sin red, 5xx, sesión por renovar, demasiados pedidos: se reintenta después,
        /// en orden, sin saltear.
        case reintentar
        /// Un 4xx que no cambia reintentando: va a la cuarentena y sigue la próxima.
        case rechazada
    }

    static func desenlace<Valor>(_ resultado: Resultado<Valor>) -> DesenlaceDeSubida {
        switch resultado {
        case .ok: return .aceptada
        case .sinRed, .respuestaRara: return .reintentar
        case .rechazado(_, let http):
            if [401, 403, 408, 425, 429].contains(http) { return .reintentar }
            return (400..<500).contains(http) ? .rechazada : .reintentar
        }
    }

    func subirPendientes() async {
        guard !subiendo, let servicio else { return }
        subiendo = true
        defer { subiendo = false }
        while let salida = cola.first(where: { esDeLaCuentaActual($0) }) {
            let cuerpo = ActividadEntrada(sport: salida.deporte, startedAtMs: salida.inicioMs,
                                          durationS: Int64(salida.segundos), distanceM: Int64(salida.metros),
                                          avgHrBpm: salida.pulsoMedio.map(Int64.init),
                                          maxHrBpm: salida.pulsoMaximo.map(Int64.init),
                                          device: salida.dispositivo ?? .telefono)
            let respuesta = await servicio.guardarActividad(id: salida.id, cuerpo)
            var veredicto = Self.desenlace(respuesta)
            if veredicto == .aceptada, !salida.puntos.isEmpty {
                let recorrido = RecorridoParaServidor.preparar(salida.puntos)
                let respuestaDelRecorrido = await servicio.guardarRecorrido(id: salida.id, recorrido)
                veredicto = Self.desenlace(respuestaDelRecorrido)
            }
            if veredicto == .reintentar { return }
            // Mientras se esperaba al servidor la cola pudo cambiar: se busca por id.
            guard let indice = cola.firstIndex(where: { $0.id == salida.id }) else { return }
            let sacada = cola.remove(at: indice)
            if veredicto == .rechazada, !cuarentena.contains(where: { $0.id == sacada.id }) {
                // 🛑 Un rechazo permanente ya no frena a las que vienen detrás, pero
                // tampoco se borra: queda en disco para revisarla.
                cuarentena.append(sacada)
            }
            actualizarPendientes()
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
                                        pulsoMaximo: salida.pulsoMaximo,
                                        usuarioId: salida.usuarioId.isEmpty ? nil : salida.usuarioId)
        AlmacenDeRecorridos.compartido.guardar(id: salida.id, puntos: salida.puntos)
        cola.append(capturada)
        actualizarPendientes()
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
        almacen.guardar(activa: activa, pendientes: cola, cuarentena: cuarentena)
        ultimoGuardadoMs = Self.ahoraEnMs()
        muestrasSinGuardar = 0
        publicarSiCorresponde()
    }

    /// Para cada fix del GPS: guarda si pasó la ventana; si no, sólo publica.
    private func guardarSiToca() {
        muestrasSinGuardar += 1
        if muestrasSinGuardar >= Self.puntosPorGuardado
            || Self.ahoraEnMs() - ultimoGuardadoMs >= Self.intervaloDeGuardadoMs {
            guardar()
        } else {
            publicarSiCorresponde()
        }
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
                if mapaPedido || fase != .detenida { encenderSensores() } else { manager.requestLocation() }
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
                    guardarSiToca()
                    continue
                }

                guard fase == .corriendo else { continue }
                guard lugar.horizontalAccuracy <= 35 else { continue }
                guard let deporte = activa?.deporte else { continue }
                let instanteMs = Int64((lugar.timestamp.timeIntervalSince1970 * 1000).rounded())
                let punto = PuntoDeRecorrido(lat: lugar.coordinate.latitude, lon: lugar.coordinate.longitude,
                                             atMs: instanteMs)
                var agregarPunto = true
                if let ultimo = puntos.last {
                    let dist = SegmentadorDeRecorrido.distanciaMetros(lat1: ultimo.lat, lon1: ultimo.lon,
                                                                     lat2: punto.lat, lon2: punto.lon)
                    let dt = Double(punto.atMs - ultimo.atMs) / 1000.0
                    let velMax: Double = deporte == .ciclismo ? 28.0 : 14.0
                    // 🛑 Un salto imposible se descarta ANTES de medir: antes la
                    // distancia ya se había sumado y sólo se salteaba el punto.
                    // Tampoco entra al filtro, que sigue anclado en la última buena.
                    if dt > 0 && (dist / dt) > velMax { continue }
                    if lugar.speed >= 0, dt > 0 {
                        let distMax = max(lugar.speed * 2.2, 5.0) * dt + max(8.0, lugar.horizontalAccuracy)
                        if dist > distMax { continue }
                    }
                    agregarPunto = dist >= 2.0 || (dt >= 3.0 && dist >= 0.8)
                }
                metros += filtroDeDistancia.agregar(
                    MuestraGPS(latitud: lugar.coordinate.latitude,
                               longitud: lugar.coordinate.longitude,
                               instanteMs: instanteMs,
                               precisionMetros: lugar.horizontalAccuracy,
                               velocidadMetrosPorSegundo: lugar.speed),
                    deporte: deporte)
                if agregarPunto {
                    puntos.append(punto)
                    puntosSegmentoActual.append(punto)
                }
                guardarSiToca()
            }
        }
    }
}
