import Combine
import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

// =============================================================================
// La sesión con las piezas de verdad —`ServiciosDeLaApp.armar`, `ApiTrainer`,
// `RenovadorDeSesion`, `ClienteAPI`— y una red de mentira por debajo.
//
// `FlujoContraElServidorTests` usa un doble del servicio entero, y un doble no
// puede probar lo que pasa ADENTRO del renovador: que un `session_revoked` de
// verdad llegue al login, que el llavero se borre antes de cambiar de pantalla, o
// que las series del gimnasio se vayan con la sesión. Esto sí, sin servidor y con
// el llavero en memoria.
// =============================================================================

/// Una red de mentira por host: cada test arma la suya, así dos tests en paralelo
/// no se pisan.
final class RedDePrueba: @unchecked Sendable {
    struct Respuesta: Sendable {
        var http: Int
        var cuerpo: String
        var demora: TimeInterval = 0

        static func error(_ codigo: String, http: Int) -> Respuesta {
            Respuesta(http: http, cuerpo: #"{"error":{"code":"\#(codigo)","message":"para el log"}}"#)
        }
    }

    typealias Responder = @Sendable (_ metodo: String, _ ruta: String) -> Respuesta

    let host = "red-\(UUID().uuidString.lowercased()).invalid"
    private let responder: Responder
    private let cerrojo = NSLock()
    private var recibidos: [String] = []

    init(_ responder: @escaping Responder) {
        self.responder = responder
        Self.registrar(self)
    }

    /// "MÉTODO /ruta" de cada pedido que llegó, en orden.
    var pedidos: [String] {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return recibidos
    }

    func cliente() -> ClienteAPI {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.protocolClasses = [ProtocoloDeRedDePrueba.self]
        return ClienteAPI(base: URL(string: "https://\(host)/v1")!,
                          sesion: URLSession(configuration: configuracion), idioma: { "es-AR" })
    }

    fileprivate func atender(metodo: String, ruta: String) -> Respuesta {
        cerrojo.lock()
        recibidos.append("\(metodo) \(ruta)")
        cerrojo.unlock()
        return responder(metodo, ruta)
    }

    private static let cerrojoDelRegistro = NSLock()
    private static var registro: [String: RedDePrueba] = [:]

    private static func registrar(_ red: RedDePrueba) {
        cerrojoDelRegistro.lock()
        defer { cerrojoDelRegistro.unlock() }
        registro[red.host] = red
    }

    fileprivate static func buscar(_ host: String?) -> RedDePrueba? {
        guard let host else { return nil }
        cerrojoDelRegistro.lock()
        defer { cerrojoDelRegistro.unlock() }
        return registro[host]
    }
}

final class ProtocoloDeRedDePrueba: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let red = RedDePrueba.buscar(url.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let respuesta = red.atender(metodo: request.httpMethod ?? "GET", ruta: url.path)
        guard respuesta.demora > 0 else { return entregar(respuesta, url: url) }
        // En el run loop que empezó a cargar, como pide `URLProtocol`.
        let temporizador = Timer(timeInterval: respuesta.demora, repeats: false) { [weak self] _ in
            self?.entregar(respuesta, url: url)
        }
        RunLoop.current.add(temporizador, forMode: .common)
    }

    override func stopLoading() {}

    private func entregar(_ respuesta: RedDePrueba.Respuesta, url: URL) {
        let http = HTTPURLResponse(url: url, statusCode: respuesta.http, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(respuesta.cuerpo.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@MainActor
@Suite("La sesión con las piezas de verdad, sobre una red de mentira")
struct SesionDeVerdadTests {

    private let ahora = RenovadorDeSesion.ahoraEnMs()

    private func sesion(_ numero: Int) -> Sesion {
        Sesion(accessToken: "acceso-\(numero)", accessExpiresAtMs: ahora + 900_000,
               refreshToken: "refresco-\(numero)", refreshExpiresAtMs: ahora + 86_400_000, userId: "u-1")
    }

    /// Un archivo de series propio de cada test, con una serie registrada adentro.
    private func seriesDeUnEntrenamiento() -> AlmacenDeSeries {
        let almacen = AlmacenDeSeries(nombre: "tests-sesion-\(UUID().uuidString).json")
        let clave = ClaveDeSerie(sesion: ClaveDeSerie.sesionDeGimnasio(), ejercicio: "sentadilla", numero: 1)
        almacen.guardar([SerieRegistrada(clave: clave, hecha: true, repeticiones: 8, pesoGramos: 60_000,
                                         registradaLocalMs: 1, dispositivo: .telefono)])
        return almacen
    }

    /// Espera a que algo pase, con techo: un test roto falla en vez de colgarse.
    private func esperar(hasta condicion: () -> Bool) async {
        var intentos = 0
        while !condicion(), intentos < 600 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            intentos += 1
        }
    }

    @Test("Un session_revoked de verdad llega al login y se lleva el llavero y las series del gimnasio")
    func sesionRevocada() async {
        let red = RedDePrueba { _, ruta in
            ruta == "/v1/me" ? .error("session_revoked", http: 401) : .error("not_found", http: 404)
        }
        let almacen = AlmacenEnMemoria(sesion(1))
        let series = seriesDeUnEntrenamiento()
        defer { series.borrar() }
        let servicios = ServiciosDeLaApp.armar(cliente: red.cliente(), almacen: almacen, series: series,
                                               cache: CacheDelServidor(nombre: "tests-cache-\(UUID().uuidString)"))
        let flujo = FlujoEntrada(servicio: servicios.cuenta, consultarVersion: servicios.consultarVersion)
        #expect(flujo.pantalla == .home)
        #expect(!series.leer().isEmpty)

        // Lo mismo que hace `RaizFlujoView`: escuchar los cierres desde el arranque.
        // Se le da un momento para suscribirse antes de que el Home pida el perfil.
        let escucha = Task { await flujo.escucharCierres() }
        defer { escucha.cancel() }
        try? await Task.sleep(nanoseconds: 100_000_000)

        await flujo.cargarPerfil()
        await esperar { flujo.pantalla == .login }

        #expect(flujo.pantalla == .login)
        #expect(flujo.avisoDelLogin == Textos.errorSessionRevoked)
        #expect(almacen.leer() == nil)
        #expect(series.leer().isEmpty, "el entrenamiento de quien se fue no queda para el siguiente")
        #expect(red.pedidos == ["GET /v1/me"], "un session_revoked no se reintenta ni se renueva")
    }

    /// 🛑 Con una renovación en vuelo, "Cerrar sesión" esperaba hasta diez segundos
    /// para borrar el llavero, y la pantalla ya mostraba la bienvenida.
    @Test("Cerrar sesión borra el llavero y las series antes de cambiar de pantalla, sin esperar a la red")
    func cerrarSesionConUnaRenovacionEnVuelo() async throws {
        let nueva = String(decoding: try JSONEncoder().encode(sesion(2)), as: UTF8.self)
        let red = RedDePrueba { _, ruta in
            switch ruta {
            case "/v1/auth/refresh": return .init(http: 200, cuerpo: #"{"data":\#(nueva)}"#, demora: 2)
            case "/v1/auth/logout": return .init(http: 204, cuerpo: "")
            default: return .error("unauthorized", http: 401)
            }
        }
        let almacen = AlmacenEnMemoria(sesion(1))
        let series = seriesDeUnEntrenamiento()
        defer { series.borrar() }
        let servicios = ServiciosDeLaApp.armar(cliente: red.cliente(), almacen: almacen, series: series,
                                               cache: CacheDelServidor(nombre: "tests-cache-\(UUID().uuidString)"))
        let flujo = FlujoEntrada(servicio: servicios.cuenta)

        // `GET /me` da 401 y deja la renovación en el aire por dos segundos.
        let perfil = Task { await flujo.cargarPerfil() }
        await esperar { red.pedidos.contains("POST /v1/auth/refresh") }

        var llaveroVacio: Bool?
        var seriesVacias: Bool?
        let observador = flujo.$pantalla.dropFirst().sink { _ in
            guard llaveroVacio == nil else { return }
            llaveroVacio = almacen.leer() == nil
            seriesVacias = series.leer().isEmpty
        }
        defer { observador.cancel() }

        let inicio = Date()
        await flujo.cerrarSesion()
        let demora = Date().timeIntervalSince(inicio)

        #expect(flujo.pantalla == .bienvenida)
        #expect(demora < 1, "no espera a la renovación que está en vuelo")
        #expect(llaveroVacio == true, "la bienvenida no aparece con la sesión todavía guardada")
        #expect(seriesVacias == true)

        await perfil.value
        #expect(almacen.leer() == nil, "la renovación que llega tarde no revive la sesión")
    }

    /// 🛑 Esta misma corrida: la app que hospeda los tests no puede estar armando
    /// los servicios de verdad, que le hablan al servidor de producción.
    @Test("Adentro de los tests la app arma los dobles, no los servicios de verdad")
    func losTestsNoUsanElServidorDeVerdad() {
        let proceso = ProcessInfo.processInfo
        #expect(proceso.arguments.contains(ServiciosDeLaApp.argumentoDeDobles),
                "la acción de test del esquema le pasa el argumento a la app que hospeda los tests")
        #expect(ServiciosDeLaApp.usaDobles(argumentos: proceso.arguments, entorno: proceso.environment))
        #expect(ServiciosDeLaApp.usaDobles(argumentos: ["Trainer"], entorno: ["XCTestSessionIdentifier": "x"]),
                "sin el argumento, el entorno de XCTest alcanza")
        #expect(!ServiciosDeLaApp.usaDobles(argumentos: ["Trainer"], entorno: [:]),
                "fuera de los tests, la app es la de verdad")
    }
}
