#if os(watchOS)
import Combine
import CoreLocation
import Foundation
import HealthKit
import TrainerCore
import WatchKit

public struct VueltaRegistrada: Codable, Identifiable, Equatable {
    public var id: Int { numero }
    public let numero: Int
    public let segundos: Int
    public let metros: Int
    public let ritmoSegPorKm: Int?

    public init(numero: Int, segundos: Int, metros: Int, ritmoSegPorKm: Int?) {
        self.numero = numero
        self.segundos = segundos
        self.metros = metros
        self.ritmoSegPorKm = ritmoSegPorKm
    }
}

private struct SalidaActivaDelReloj: Codable {
    var id: String
    var usuarioId: String
    var deporte: DeporteDeSesion
    var inicioMs: Int64
    var segundos: Int
    var metros: Int
    var puntos: [PuntoDeRecorrido]
    var segundosPausa: Int?
    var vueltas: [VueltaRegistrada]?
    var marcas: [MarcaRuta]?
    var tramosDePausa: [[PuntoDeRecorrido]]?
    var esTriatlon: Bool?
    var tramosPorDeporte: [TramoPorDeporte]?
}

private struct SalidasDelRelojEnDisco: Codable {
    var activa: SalidaActivaDelReloj?
    var pendientes: [SalidaDelReloj]
    var usuarioVinculadoId: String?
}

/// Registra una salida en la muñeca aun sin teléfono. HealthKit mantiene vivo el
/// entrenamiento en segundo plano y provee el pulso; Core Location da la ruta.
/// Al terminar, un archivo durable la encola para el iPhone.
@MainActor
final class SeguimientoDelReloj: NSObject, ObservableObject,
                                  CLLocationManagerDelegate, HKWorkoutSessionDelegate,
                                  HKLiveWorkoutBuilderDelegate {
    enum Fase { case detenida, corriendo, pausada }

    @Published private(set) var fase: Fase = .detenida
    @Published private(set) var segundos = 0
    @Published private(set) var metros = 0
    @Published private(set) var puntos: [PuntoDeRecorrido] = []
    @Published private(set) var ubicacion: CLLocationCoordinate2D?
    @Published private(set) var pulso: Int?
    @Published private(set) var errorDePermiso = false
    @Published private(set) var ritmoActualSegPorKm: Int?
    @Published private(set) var ritmoPromedioSegPorKm: Int?
    @Published private(set) var segundosEnPausa = 0
    @Published private(set) var pausaCongelada = false
    @Published private(set) var vueltas: [VueltaRegistrada] = []
    @Published private(set) var rumbo: Double = 0.0
    @Published private(set) var esInterior: Bool = false
    @Published var objetivoMetros: Int? = nil
    @Published var objetivoCumplido: Bool = false
    @Published var mostrarAvisoObjetivoCumplido = false
    @Published private(set) var autoPausada = false
    @Published private(set) var marcas: [MarcaRuta] = []
    @Published private(set) var tramosDePausa: [[PuntoDeRecorrido]] = []
    @Published private(set) var puntosPausaActual: [PuntoDeRecorrido] = []
    @Published private(set) var esTriatlon: Bool = false
    @Published private(set) var disciplinaTriatlonActual: DeporteDeSesion = .natacion
    @Published private(set) var tramosPorDeporte: [TramoPorDeporte] = []
    private var tareaGuardado: Task<Void, Never>?
    var pendientesCount: Int { pendientes.count }
    private var objetivoNotificado = false
    private var segundosDetenido = 0
    private var ultimoMetrosParaAutoPausa = 0

    var alCambiar: ((EstadoDeSalidaCompartido) -> Void)?

    private let manager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private let sincronizador: SincronizadorDeSesion
    private let archivo: URL?
    private var activa: SalidaActivaDelReloj?
    private var pendientes: [SalidaDelReloj] = []
    private(set) var usuarioVinculadoId: String?
    private var esperandoPermiso: DeporteDeSesion?
    private var medidorDeDistancia = MedidorDeDistanciaExterior()
    private var inicioDelTramo: Date?
    private var segundosAcumulados = 0
    private var inicioDePausaActual: Date?
    private var segundosPausaAcumulados = 0
    private var ultimoSegundoVuelta = 0
    private var ultimosMetrosVuelta = 0
    private var timer: Timer?
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var pulsos: [Int] = []
    private var suscripciones = Set<AnyCancellable>()
    private var ultimoEnvioMs: Int64 = 0

    init(sincronizador: SincronizadorDeSesion) {
        self.sincronizador = sincronizador
        archivo = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))?
            .appendingPathComponent("salidas-del-reloj.json")
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.headingFilter = kCLHeadingFilterNone
        manager.activityType = .fitness
        if let archivo, let data = try? Data(contentsOf: archivo),
           let guardado = try? JSONDecoder().decode(SalidasDelRelojEnDisco.self, from: data) {
            pendientes = guardado.pendientes
            usuarioVinculadoId = guardado.usuarioVinculadoId
            if let activaGuardada = guardado.activa, activaGuardada.segundos > 0 || activaGuardada.metros > 0 {
                let salidaRecuperada = SalidaDelReloj(
                    id: activaGuardada.id,
                    usuarioId: usuarioVinculadoId ?? "",
                    deporte: activaGuardada.esTriatlon == true ? .triatlon : activaGuardada.deporte,
                    inicioMs: activaGuardada.inicioMs,
                    segundos: max(1, activaGuardada.segundos),
                    metros: activaGuardada.metros,
                    puntos: activaGuardada.puntos,
                    pulsoMedio: nil,
                    pulsoMaximo: nil
                )
                if !pendientes.contains(where: { $0.id == salidaRecuperada.id }) {
                    pendientes.append(salidaRecuperada)
                }
            }
            activa = nil
            fase = .detenida
            guardar()
        }
        if usuarioVinculadoId == nil { usuarioVinculadoId = sincronizador.usuarioRemotoId }
        sincronizador.alActivar = { [weak self] in self?.enviarPendientes() }
        sincronizador.$usuarioRemotoId
            .dropFirst()
            .sink { [weak self] usuario in
                guard let self else { return }
                if let usuario, !usuario.isEmpty {
                    self.usuarioVinculadoId = usuario
                    self.guardar()
                    self.enviarPendientes()
                } else {
                    self.desconectarUsuarioPorCierreDeSesion()
                }
            }
            .store(in: &suscripciones)
        enviarPendientes()
    }

    func desconectarUsuarioPorCierreDeSesion() {
        usuarioVinculadoId = nil
        if let activaActual = activa, (segundos > 0 || metros > 0) {
            if fase == .corriendo, let inicioDelTramo {
                segundos = segundosAcumulados + max(0, Int(Date().timeIntervalSince(inicioDelTramo)))
                self.activa?.segundos = segundos
            }
            if let inicio = inicioDePausaActual {
                let transcurrido = max(0, Int(Date().timeIntervalSince(inicio)))
                segundosPausaAcumulados += transcurrido
                segundosEnPausa = segundosPausaAcumulados
                inicioDePausaActual = nil
            }
            let salidaGuardada = SalidaDelReloj(
                id: activaActual.id,
                usuarioId: "",
                deporte: activaActual.esTriatlon == true ? .triatlon : activaActual.deporte,
                inicioMs: activaActual.inicioMs,
                segundos: max(1, segundos),
                metros: metros,
                puntos: puntos,
                pulsoMedio: pulsos.isEmpty ? nil : pulsos.reduce(0, +) / pulsos.count,
                pulsoMaximo: pulsos.max()
            )
            if !pendientes.contains(where: { $0.id == salidaGuardada.id }) {
                pendientes.append(salidaGuardada)
            }
        }
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
        manager.allowsBackgroundLocationUpdates = false
        timer?.invalidate()
        timer = nil
        inicioDelTramo = nil
        workoutSession?.end()
        let builderActual = builder
        builderActual?.endCollection(withEnd: Date()) { _, _ in
            builderActual?.finishWorkout { _, _ in }
        }
        workoutSession = nil
        builder = nil
        fase = .detenida
        self.activa = nil
        segundos = 0
        metros = 0
        puntos = []
        marcas = []
        tramosDePausa = []
        puntosPausaActual = []
        esTriatlon = false
        tramosPorDeporte = []
        ubicacion = nil
        pulso = nil
        pulsos = []
        segundosAcumulados = 0
        segundosPausaAcumulados = 0
        segundosEnPausa = 0
        pausaCongelada = false
        inicioDePausaActual = nil
        vueltas = []
        ultimoSegundoVuelta = 0
        ultimosMetrosVuelta = 0
        medidorDeDistancia.reiniciar()
        guardar()
    }

    func limpiarSesion() {
        desconectarUsuarioPorCierreDeSesion()
    }

    var ritmoSegPorKm: Int? {
        ritmoActualSegPorKm ?? ritmoPromedioSegPorKm
    }

    var deporteActivo: DeporteDeSesion? { activa?.deporte }

    func empezar(deporte: DeporteDeSesion, esInterior: Bool = false, objetivoMetros: Int? = nil, esTriatlon: Bool = false) {
        guard fase == .detenida else { return }
        self.esInterior = esInterior
        self.objetivoMetros = objetivoMetros
        self.objetivoCumplido = false
        self.objetivoNotificado = false
        self.mostrarAvisoObjetivoCumplido = false
        self.esTriatlon = esTriatlon
        self.disciplinaTriatlonActual = esTriatlon ? .natacion : deporte
        errorDePermiso = false
        let depParaPermiso = esTriatlon ? .natacion : deporte
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: pedirSaludYEmpezar(depParaPermiso)
        case .notDetermined:
            esperandoPermiso = depParaPermiso
            manager.requestWhenInUseAuthorization()
        default: errorDePermiso = true
        }
    }

    private func pedirSaludYEmpezar(_ deporte: DeporteDeSesion) {
        guard HKHealthStore.isHealthDataAvailable(),
              let hr = HKObjectType.quantityType(forIdentifier: .heartRate),
              let distanciaAPie = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
              let distanciaBici = HKObjectType.quantityType(forIdentifier: .distanceCycling) else {
            empezarGPS(deporte: deporte, conSalud: false)
            return
        }
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                         read: [hr, distanciaAPie, distanciaBici]) { [weak self] autorizado, _ in
            Task { @MainActor in self?.empezarGPS(deporte: deporte, conSalud: autorizado) }
        }
    }

    private func empezarGPS(deporte: DeporteDeSesion, conSalud: Bool) {
        let ahora = Date()
        let depReal = esTriatlon ? .natacion : deporte
        activa = SalidaActivaDelReloj(id: UUID().uuidString,
                                     usuarioId: sincronizador.usuarioRemotoId ?? usuarioVinculadoId ?? "",
                                     deporte: depReal,
                                     inicioMs: Int64((ahora.timeIntervalSince1970 * 1000).rounded()),
                                     segundos: 0, metros: 0, puntos: [], segundosPausa: 0, vueltas: [])
        segundos = 0
        metros = 0
        puntos = []
        marcas = []
        tramosDePausa = []
        puntosPausaActual = []
        if esTriatlon {
            tramosPorDeporte = [TramoPorDeporte(deporte: .natacion, puntos: [])]
        } else {
            tramosPorDeporte = []
        }
        ubicacion = nil
        pulso = nil
        pulsos = []
        rumbo = 0.0
        medidorDeDistancia.reiniciar()
        segundosAcumulados = 0
        inicioDePausaActual = nil
        segundosPausaAcumulados = 0
        segundosEnPausa = 0
        vueltas = []
        ultimoSegundoVuelta = 0
        ultimosMetrosVuelta = 0
        fase = .corriendo
        ultimoMetrosParaAutoPausa = 0
        segundosDetenido = 0
        autoPausada = false
        if conSalud { iniciarWorkout(deporte: depReal, fecha: ahora) }
        if esInterior {
            continuarInterior(desde: ahora)
        } else {
            continuarGPS(desde: ahora)
        }
        guardar()
        publicar(forzar: true)
    }

    private func iniciarWorkout(deporte: DeporteDeSesion, fecha: Date) {
        let config = HKWorkoutConfiguration()
        switch deporte {
        case .ciclismo: config.activityType = .cycling
        case .natacion: config.activityType = .swimming
        case .trekking: config.activityType = .hiking
        default: config.activityType = .running
        }
        config.locationType = esInterior ? .indoor : .outdoor
        guard let session = try? HKWorkoutSession(healthStore: healthStore, configuration: config) else { return }
        workoutSession = session
        session.delegate = self
        let builder = session.associatedWorkoutBuilder()
        self.builder = builder
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        builder.delegate = self
        session.startActivity(with: fecha)
        builder.beginCollection(withStart: fecha) { _, _ in }
    }

    private func continuarGPS(desde fecha: Date) {
        inicioDelTramo = fecha
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.actualizarTiempo() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        actualizarTiempo()
    }

    private func continuarInterior(desde fecha: Date) {
        inicioDelTramo = fecha
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.actualizarTiempo() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        actualizarTiempo()
    }

    private func actualizarTiempo() {
        if pausaCongelada {
            segundosEnPausa = segundosPausaAcumulados
            activa?.segundosPausa = segundosEnPausa
            publicar()
            return
        }
        if fase == .corriendo, let inicioDelTramo {
            segundos = segundosAcumulados + max(0, Int(Date().timeIntervalSince(inicioDelTramo)))
            activa?.segundos = segundos
            if metros >= 20, segundos > 0 {
                ritmoPromedioSegPorKm = Int((Double(segundos) * 1000 / Double(metros)).rounded())
            }
            chequearObjetivo()
            if fase == .corriendo && !autoPausada {
                chequearAutoPausa()
            }
        }
        if let inicioPausa = inicioDePausaActual {
            segundosEnPausa = segundosPausaAcumulados + max(0, Int(Date().timeIntervalSince(inicioPausa)))
        } else {
            segundosEnPausa = segundosPausaAcumulados
        }
        activa?.segundosPausa = segundosEnPausa
        if (segundos + segundosEnPausa) % 5 == 0 { guardar() }
        publicar()
    }

    private var pausaAutoHabilitada: Bool {
        guard !esInterior else { return false }
        guard let dep = activa?.deporte else { return false }
        switch dep {
        case .ciclismo:
            return UserDefaults.standard.object(forKey: "pausa_auto_bici") as? Bool ?? true
        case .running:
            return UserDefaults.standard.object(forKey: "pausa_auto_carrera") as? Bool ?? false
        default:
            return false
        }
    }

    private func chequearAutoPausa() {
        guard pausaAutoHabilitada, fase == .corriendo, !autoPausada, segundos >= 5 else { return }
        if metros == ultimoMetrosParaAutoPausa {
            segundosDetenido += 1
            if segundosDetenido >= 3 {
                segundosDetenido = 0
                autoPausada = true
                pausarOReanudar()
            }
        } else {
            ultimoMetrosParaAutoPausa = metros
            segundosDetenido = 0
        }
    }

    private func chequearObjetivo() {
        guard let objetivo = objetivoMetros, objetivo > 0, !objetivoNotificado else { return }
        if metros >= objetivo {
            objetivoNotificado = true
            objetivoCumplido = true
            mostrarAvisoObjetivoCumplido = true
        }
    }

    var tiempoTotalPausaSegundos: Int {
        if pausaCongelada { return segundosPausaAcumulados }
        var total = segundosPausaAcumulados
        if let inicio = inicioDePausaActual {
            total += max(0, Int(Date().timeIntervalSince(inicio)))
        }
        return total
    }

    func congelarPausaParaFinalizacion() {
        if fase == .corriendo {
            fase = .pausada
            if let inicioDelTramo {
                segundos = segundosAcumulados + max(0, Int(Date().timeIntervalSince(inicioDelTramo)))
                activa?.segundos = segundos
                if metros >= 20, segundos > 0 {
                    ritmoPromedioSegPorKm = Int((Double(segundos) * 1000 / Double(metros)).rounded())
                }
            }
            segundosAcumulados = segundos
            inicioDelTramo = nil
            if let loc = ubicacion {
                let ms = Int64((Date().timeIntervalSince1970 * 1000).rounded())
                marcas.append(MarcaRuta(tipo: .pausa, latitud: loc.latitude, longitud: loc.longitude, instanteMs: ms))
                puntosPausaActual.append(PuntoDeRecorrido(lat: loc.latitude, lon: loc.longitude, atMs: ms))
            }
            workoutSession?.pause()
            medidorDeDistancia.reiniciarAnclaGPS()
        }
        if let inicio = inicioDePausaActual {
            let transcurrido = max(0, Int(Date().timeIntervalSince(inicio)))
            segundosPausaAcumulados += transcurrido
            inicioDePausaActual = nil
        }
        segundosEnPausa = segundosPausaAcumulados
        activa?.segundosPausa = segundosEnPausa
        pausaCongelada = true
        guardar()
        publicar(forzar: true)
    }

    func descongelarYReanudar() {
        pausaCongelada = false
        inicioDePausaActual = nil
        fase = .corriendo
        autoPausada = false
        segundosDetenido = 0
        inicioDelTramo = Date()
        if let loc = ubicacion {
            let ms = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            marcas.append(MarcaRuta(tipo: .reanudacion, latitud: loc.latitude, longitud: loc.longitude, instanteMs: ms))
            puntosPausaActual.append(PuntoDeRecorrido(lat: loc.latitude, lon: loc.longitude, atMs: ms))
        }
        if puntosPausaActual.count >= 2 {
            let p0 = puntosPausaActual[0]
            let pFin = puntosPausaActual[puntosPausaActual.count - 1]
            let dPausa = Self.distanciaEnMetros(lat1: p0.lat, lon1: p0.lon, lat2: pFin.lat, lon2: pFin.lon)
            if dPausa >= 3.0 || puntosPausaActual.count >= 3 {
                tramosDePausa.append(puntosPausaActual)
            }
        }
        puntosPausaActual = []
        medidorDeDistancia.reiniciarAnclaGPS()
        let ahora = Date()
        if workoutSession == nil {
            iniciarWorkout(deporte: activa?.deporte ?? .running, fecha: ahora)
        } else {
            workoutSession?.resume()
        }
        if esInterior {
            continuarInterior(desde: ahora)
        } else {
            continuarGPS(desde: ahora)
        }
        guardar()
        publicar(forzar: true)
    }

    func pausarOReanudar() {
        pausaCongelada = false
        switch fase {
        case .detenida: break
        case .corriendo:
            fase = .pausada
            if let inicioDelTramo {
                segundos = segundosAcumulados + max(0, Int(Date().timeIntervalSince(inicioDelTramo)))
                activa?.segundos = segundos
                if metros >= 20, segundos > 0 {
                    ritmoPromedioSegPorKm = Int((Double(segundos) * 1000 / Double(metros)).rounded())
                }
            }
            segundosAcumulados = segundos
            inicioDelTramo = nil
            inicioDePausaActual = Date()
            puntosPausaActual = []
            if let loc = ubicacion {
                let ms = Int64((Date().timeIntervalSince1970 * 1000).rounded())
                marcas.append(MarcaRuta(tipo: .pausa, latitud: loc.latitude, longitud: loc.longitude, instanteMs: ms))
                puntosPausaActual.append(PuntoDeRecorrido(lat: loc.latitude, lon: loc.longitude, atMs: ms))
            }
            workoutSession?.pause()
            // No detenemos location updates: mantener Core Location activo
            // permite a watchOS no suspender la aplicación durante la pausa,
            // mantiene la posición actualizada en el mapa y permite que la
            // pausa automática detecte cuando el usuario vuelve a moverse.
            medidorDeDistancia.reiniciarAnclaGPS()
            guardar()
            publicar(forzar: true)
        case .pausada:
            fase = .corriendo
            autoPausada = false
            segundosDetenido = 0
            if let inicio = inicioDePausaActual {
                let transcurrido = max(0, Int(Date().timeIntervalSince(inicio)))
                segundosPausaAcumulados += transcurrido
                segundosEnPausa = segundosPausaAcumulados
                inicioDePausaActual = nil
            }
            if let loc = ubicacion {
                let ms = Int64((Date().timeIntervalSince1970 * 1000).rounded())
                marcas.append(MarcaRuta(tipo: .reanudacion, latitud: loc.latitude, longitud: loc.longitude, instanteMs: ms))
                puntosPausaActual.append(PuntoDeRecorrido(lat: loc.latitude, lon: loc.longitude, atMs: ms))
            }
            if puntosPausaActual.count >= 2 {
                let p0 = puntosPausaActual[0]
                let pFin = puntosPausaActual[puntosPausaActual.count - 1]
                let dPausa = Self.distanciaEnMetros(lat1: p0.lat, lon1: p0.lon, lat2: pFin.lat, lon2: pFin.lon)
                if dPausa >= 3.0 || puntosPausaActual.count >= 3 {
                    tramosDePausa.append(puntosPausaActual)
                }
            }
            puntosPausaActual = []
            // Al reanudar se reinicia el ancla de GPS para no sumar el salto
            // ocurrido durante la pausa. La distancia ya confirmada se conserva.
            medidorDeDistancia.reiniciarAnclaGPS()
            let ahora = Date()
            if workoutSession == nil { iniciarWorkout(deporte: activa?.deporte ?? .running, fecha: ahora) }
            else { workoutSession?.resume() }
            if esInterior {
                continuarInterior(desde: ahora)
            } else {
                continuarGPS(desde: ahora)
            }
            guardar()
            publicar(forzar: true)
        }
    }

    func terminar() {
        guard let activa else { return }
        if fase == .corriendo, let inicioDelTramo {
            segundos = segundosAcumulados + max(0, Int(Date().timeIntervalSince(inicioDelTramo)))
            self.activa?.segundos = segundos
        }
        if !pausaCongelada, let inicio = inicioDePausaActual {
            let transcurrido = max(0, Int(Date().timeIntervalSince(inicio)))
            segundosPausaAcumulados += transcurrido
            segundosEnPausa = segundosPausaAcumulados
            inicioDePausaActual = nil
        }
        pausaCongelada = false
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
        manager.allowsBackgroundLocationUpdates = false
        timer?.invalidate()
        timer = nil
        inicioDelTramo = nil
        workoutSession?.end()
        let builderActual = builder
        builderActual?.endCollection(withEnd: Date()) { _, _ in
            builderActual?.finishWorkout { _, _ in }
        }
        workoutSession = nil
        builder = nil
        fase = .detenida
        let salida = SalidaDelReloj(id: activa.id, usuarioId: activa.usuarioId,
                                   deporte: activa.esTriatlon == true ? .triatlon : activa.deporte,
                                   inicioMs: activa.inicioMs,
                                   segundos: max(1, segundos), metros: metros, puntos: puntos,
                                   pulsoMedio: pulsos.isEmpty ? nil : pulsos.reduce(0, +) / pulsos.count,
                                   pulsoMaximo: pulsos.max())
        pendientes.append(salida)
        publicar(forzar: true, activa: activa)
        self.activa = nil
        guardar()
        enviarPendientes()
    }

    /// Descarta una salida inválida. HealthKit tampoco conserva un workout que
    /// la app decidió no guardar.
    func descartar() {
        guard activa != nil else { return }
        fase = .detenida
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
        manager.allowsBackgroundLocationUpdates = false
        timer?.invalidate()
        timer = nil
        inicioDelTramo = nil
        workoutSession?.end()
        let builderActual = builder
        builderActual?.endCollection(withEnd: Date()) { _, _ in
            builderActual?.discardWorkout()
        }
        workoutSession = nil
        builder = nil
        fase = .detenida
        if let activa { publicar(forzar: true, activa: activa) }
        self.activa = nil
        segundos = 0
        metros = 0
        puntos = []
        marcas = []
        tramosDePausa = []
        puntosPausaActual = []
        esTriatlon = false
        tramosPorDeporte = []
        ubicacion = nil
        pulso = nil
        pulsos = []
        segundosAcumulados = 0
        segundosPausaAcumulados = 0
        segundosEnPausa = 0
        pausaCongelada = false
        inicioDePausaActual = nil
        vueltas = []
        ultimoSegundoVuelta = 0
        ultimosMetrosVuelta = 0
        medidorDeDistancia.reiniciar()
        guardar()
    }

    @discardableResult
    func registrarVuelta() -> Int {
        if fase == .corriendo { actualizarTiempo() }
        let segsVuelta = max(1, segundos - ultimoSegundoVuelta)
        let metrosVuelta = max(0, metros - ultimosMetrosVuelta)
        ultimoSegundoVuelta = segundos
        ultimosMetrosVuelta = metros
        let ritmo: Int? = metrosVuelta >= 20 ? Int((Double(segsVuelta) * 1000.0 / Double(metrosVuelta)).rounded()) : nil
        let numero = vueltas.count + 1
        let nueva = VueltaRegistrada(numero: numero, segundos: segsVuelta, metros: metrosVuelta, ritmoSegPorKm: ritmo)
        vueltas.append(nueva)
        activa?.vueltas = vueltas
        if let loc = ubicacion {
            let ms = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            marcas.append(MarcaRuta(tipo: .vuelta(numero), latitud: loc.latitude, longitud: loc.longitude, instanteMs: ms))
        }
        guardar()
        return numero
    }

    func siguienteDisciplinaTriatlon() -> DeporteDeSesion? {
        guard esTriatlon else { return nil }
        switch disciplinaTriatlonActual {
        case .natacion: return .ciclismo
        case .ciclismo: return .running
        case .running, .fuerza, .trekking, .otro, .triatlon: return nil
        }
    }

    func transicionarSiguienteDeporteTriatlon() {
        guard esTriatlon, let siguiente = siguienteDisciplinaTriatlon() else { return }
        disciplinaTriatlonActual = siguiente
        activa?.deporte = siguiente
        medidorDeDistancia.reiniciarAnclaGPS()
        tramosPorDeporte.append(TramoPorDeporte(deporte: siguiente, puntos: []))
        if let loc = ubicacion {
            let ms = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            let numero = vueltas.count + 1
            let segsTramo = max(1, segundos - ultimoSegundoVuelta)
            let metrosTramo = max(0, metros - ultimosMetrosVuelta)
            let nueva = VueltaRegistrada(numero: numero, segundos: segsTramo, metros: metrosTramo, ritmoSegPorKm: nil)
            vueltas.append(nueva)
            activa?.vueltas = vueltas
            ultimoSegundoVuelta = segundos
            ultimosMetrosVuelta = metros
            marcas.append(MarcaRuta(tipo: .vuelta(numero), latitud: loc.latitude, longitud: loc.longitude, instanteMs: ms))
        }
        guardar()
        publicar(forzar: true)
    }

    private func enviarPendientes() {
        guard let usuario = sincronizador.usuarioRemotoId ?? usuarioVinculadoId,
              !usuario.isEmpty else { return }
        while let indice = pendientes.firstIndex(where: { $0.usuarioId.isEmpty || $0.usuarioId == usuario }) {
            let guardada = pendientes[indice]
            let salida = guardada.usuarioId.isEmpty ? SalidaDelReloj(
                id: guardada.id, usuarioId: usuario, deporte: guardada.deporte,
                inicioMs: guardada.inicioMs, segundos: guardada.segundos,
                metros: guardada.metros, puntos: guardada.puntos,
                pulsoMedio: guardada.pulsoMedio, pulsoMaximo: guardada.pulsoMaximo) : guardada
            guard sincronizador.enviarSalidaDelReloj(salida) else { return }
            pendientes.remove(at: indice)
            guardar()
        }
    }

    private func guardar() {
        activa?.segundos = segundos
        activa?.metros = metros
        activa?.puntos = puntos
        activa?.segundosPausa = tiempoTotalPausaSegundos
        activa?.vueltas = vueltas
        activa?.marcas = marcas
        activa?.tramosDePausa = tramosDePausa
        activa?.esTriatlon = esTriatlon
        activa?.tramosPorDeporte = tramosPorDeporte
        guard let archivo else { return }
        let snapshot = SalidasDelRelojEnDisco(activa: activa, pendientes: pendientes,
                                               usuarioVinculadoId: usuarioVinculadoId)
        tareaGuardado?.cancel()
        tareaGuardado = Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: archivo, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var recursos = URLResourceValues()
            recursos.isExcludedFromBackup = true
            var mutableArchivo = archivo
            try? mutableArchivo.setResourceValues(recursos)
        }
    }

    private func publicar(forzar: Bool = false, activa salida: SalidaActivaDelReloj? = nil) {
        guard let activa = salida ?? self.activa, let alCambiar else { return }
        let ahora = Int64((Date().timeIntervalSince1970 * 1_000).rounded())
        guard forzar || ahora - ultimoEnvioMs >= 2_000 else { return }
        ultimoEnvioMs = ahora
        alCambiar(EstadoDeSalidaCompartido(
            id: activa.id,
            deporte: activa.deporte,
            corriendo: fase == .corriendo,
            pausada: fase == .pausada,
            segundos: segundos,
            metros: metros,
            ritmoSegPorKm: ritmoSegPorKm,
            puntos: puntos,
            actualizadoMs: ahora))
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let deporte = esperandoPermiso else { return }
            esperandoPermiso = nil
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                pedirSaludYEmpezar(deporte)
            } else if manager.authorizationStatus != .notDetermined { errorDePermiso = true }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.errorDePermiso = true }
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
            if fase == .pausada {
                for lugar in locations {
                    guard lugar.horizontalAccuracy >= 0, lugar.horizontalAccuracy <= 25 else { continue }
                    ubicacion = lugar.coordinate
                    if autoPausada, lugar.speed > 0.8 {
                        autoPausada = false
                        pausarOReanudar()
                        return
                    }
                    let puntoMs = Int64((lugar.timestamp.timeIntervalSince1970 * 1000).rounded())
                    let nuevoPunto = PuntoDeRecorrido(lat: lugar.coordinate.latitude, lon: lugar.coordinate.longitude, atMs: puntoMs)
                    if let ultimo = puntosPausaActual.last {
                        let dist = Self.distanciaEnMetros(lat1: ultimo.lat, lon1: ultimo.lon, lat2: nuevoPunto.lat, lon2: nuevoPunto.lon)
                        if dist >= 2.0 {
                            puntosPausaActual.append(nuevoPunto)
                        }
                    } else {
                        puntosPausaActual.append(nuevoPunto)
                    }
                }
                publicar()
                return
            }
            guard fase == .corriendo else { return }
            for lugar in locations {
                guard lugar.horizontalAccuracy >= 0, lugar.horizontalAccuracy <= 25,
                      abs(lugar.timestamp.timeIntervalSinceNow) <= 15 else { continue }
                
                // Actualizar la ubicación en cada fix de buena calidad para evitar teletransportes del personaje
                ubicacion = lugar.coordinate
                if lugar.course >= 0 {
                    rumbo = lugar.course
                } else if let ultimo = puntos.last {
                    let dLat = lugar.coordinate.latitude - ultimo.lat
                    let dLon = lugar.coordinate.longitude - ultimo.lon
                    if abs(dLat) > 0.00001 || abs(dLon) > 0.00001 {
                        let rad = atan2(dLon, dLat)
                        let deg = rad * 180.0 / .pi
                        rumbo = (deg >= 0 ? deg : deg + 360.0)
                    }
                }

                guard let deporte = activa?.deporte else { continue }
                metros = medidorDeDistancia.agregarGPS(
                    MuestraGPS(latitud: lugar.coordinate.latitude,
                               longitud: lugar.coordinate.longitude,
                               instanteMs: Int64((lugar.timestamp.timeIntervalSince1970 * 1_000).rounded()),
                               precisionMetros: lugar.horizontalAccuracy,
                               velocidadMetrosPorSegundo: lugar.speed),
                    deporte: deporte)

                // Ritmo instantáneo suavizado cuando la velocidad GPS es real
                if lugar.speed >= 0.5, lugar.horizontalAccuracy <= 20 {
                    let instantaneo = Int((1000.0 / lugar.speed).rounded())
                    if (120...1800).contains(instantaneo) {
                        if let previo = self.ritmoActualSegPorKm {
                            self.ritmoActualSegPorKm = Int((Double(previo) * 0.65 + Double(instantaneo) * 0.35).rounded())
                        } else {
                            self.ritmoActualSegPorKm = instantaneo
                        }
                    }
                } else if lugar.speed >= 0 && lugar.speed < 0.35 {
                    self.ritmoActualSegPorKm = nil
                }

                // Filtrar saltos y ruido estático antes de añadir a puntos del recorrido
                var puntoMs = Int64((lugar.timestamp.timeIntervalSince1970 * 1000).rounded())
                if let ultimo = puntos.last, puntoMs <= ultimo.atMs {
                    puntoMs = ultimo.atMs + 1
                }
                let nuevoPunto = PuntoDeRecorrido(lat: lugar.coordinate.latitude, lon: lugar.coordinate.longitude,
                                                  atMs: puntoMs)
                if let ultimo = puntos.last {
                    let dist = Self.distanciaEnMetros(lat1: ultimo.lat, lon1: ultimo.lon,
                                                      lat2: nuevoPunto.lat, lon2: nuevoPunto.lon)
                    let dt = Double(nuevoPunto.atMs - ultimo.atMs) / 1000.0
                    let velMaxPermitida: Double = deporte == .ciclismo ? 28.0 : 14.0
                    // Descartar saltos que superen la velocidad máxima posible del deporte
                    if dt > 0 && (dist / dt) > velMaxPermitida { continue }
                    // Si el sistema midió velocidad, descartar saltos incompatibles que generen pinchazos
                    if lugar.speed >= 0, dt > 0 {
                        let distMaxPlausible = max(lugar.speed * 2.2, 5.0) * dt + max(8.0, lugar.horizontalAccuracy)
                        if dist > distMaxPlausible { continue }
                    }
                    // Agregar si hubo desplazamiento de al menos 2 metros o avance tras varios segundos
                    if dist >= 2.0 || (dt >= 3.0 && dist >= 0.8) {
                        puntos.append(nuevoPunto)
                        if esTriatlon {
                            if tramosPorDeporte.isEmpty {
                                tramosPorDeporte.append(TramoPorDeporte(deporte: deporte, puntos: [nuevoPunto]))
                            } else {
                                tramosPorDeporte[tramosPorDeporte.count - 1].puntos.append(nuevoPunto)
                            }
                        }
                    }
                } else {
                    puntos.append(nuevoPunto)
                    if esTriatlon {
                        if tramosPorDeporte.isEmpty {
                            tramosPorDeporte.append(TramoPorDeporte(deporte: deporte, puntos: [nuevoPunto]))
                        } else {
                            tramosPorDeporte[tramosPorDeporte.count - 1].puntos.append(nuevoPunto)
                        }
                    }
                }
                publicar()
            }
        }
    }

    private static func distanciaEnMetros(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            if let tipoPulso = HKObjectType.quantityType(forIdentifier: .heartRate),
               collectedTypes.contains(tipoPulso),
               let cantidad = workoutBuilder.statistics(for: tipoPulso)?.mostRecentQuantity() {
                let valor = Int(cantidad.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
                if (30...250).contains(valor) {
                    pulso = valor
                    pulsos.append(valor)
                }
            }
            let identificador: HKQuantityTypeIdentifier = activa?.deporte == .ciclismo
                ? .distanceCycling : .distanceWalkingRunning
            if let tipoDistancia = HKObjectType.quantityType(forIdentifier: identificador),
               collectedTypes.contains(tipoDistancia),
               let suma = workoutBuilder.statistics(for: tipoDistancia)?.sumQuantity() {
                let m = Int(suma.doubleValue(for: .meter()).rounded())
                if self.esInterior {
                    self.metros = max(0, m)
                    self.activa?.metros = self.metros
                } else {
                    self.metros = self.medidorDeDistancia.actualizarSalud(metros: m)
                    self.activa?.metros = self.metros
                }
                self.chequearObjetivo()
            }
            publicar()
        }
    }
}
#endif
