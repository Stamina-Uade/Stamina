import Foundation
@testable import TrainerCore

// =============================================================================
// Un servidor de mentira para los tests de red, sobre `URLProtocol`.
//
// Cada test arma el suyo con un host propio (`prueba-<uuid>.invalid`) y el
// protocolo lo busca por el host del pedido. Así dos tests no comparten estado
// aunque alguien los corra en paralelo, y ninguno sale a la red: `.invalid` es un
// dominio reservado que no resuelve nunca (RFC 2606).
//
// Lo que se prueba acá es el cliente de verdad —`URLSession`, los encabezados, el
// cuerpo que viaja—, no una imitación del cliente.
// =============================================================================

final class ServidorDePrueba: @unchecked Sendable {

    struct Pedido: Sendable {
        let metodo: String
        /// Con el `/v1`, como llega al servidor.
        let ruta: String
        /// La consulta tal como viaja, sin decodificar.
        let consultaCruda: String?
        let consulta: [String: String]
        let encabezados: [String: String]
        let cuerpo: Data
        let espera: TimeInterval

        func encabezado(_ nombre: String) -> String? {
            encabezados.first { $0.key.caseInsensitiveCompare(nombre) == .orderedSame }?.value
        }

        var json: [String: Any]? {
            (try? JSONSerialization.jsonObject(with: cuerpo)) as? [String: Any]
        }
    }

    struct Respuesta: Sendable {
        var http = 200
        var cuerpo = Data()
        var demora: TimeInterval = 0
        var falla: URLError.Code?

        static func datos(_ json: String, http: Int = 200, demora: TimeInterval = 0) -> Respuesta {
            Respuesta(http: http, cuerpo: Data("{\"data\":\(json)}".utf8), demora: demora)
        }

        static func error(_ codigo: String, http: Int) -> Respuesta {
            let json = "{\"error\":{\"code\":\"\(codigo)\",\"message\":\"para el log, no para la pantalla\"}}"
            return Respuesta(http: http, cuerpo: Data(json.utf8))
        }

        static func cruda(_ texto: String, http: Int) -> Respuesta {
            Respuesta(http: http, cuerpo: Data(texto.utf8))
        }

        static let sinContenido = Respuesta(http: 204)
        static let sinRed = Respuesta(falla: .notConnectedToInternet)
    }

    /// Recibe el pedido y todos los recibidos hasta ahora, incluido éste: con eso
    /// un test puede contestar distinto la segunda vez, como hace el servidor de
    /// verdad con un refresh ya usado.
    typealias Responder = @Sendable (Pedido, [Pedido]) -> Respuesta

    let host = "prueba-\(UUID().uuidString.lowercased()).invalid"
    var base: URL { URL(string: "https://\(host)/v1")! }

    private let cerrojo = NSLock()
    private var recibidos: [Pedido] = []
    private let responder: Responder

    init(_ responder: @escaping Responder) {
        self.responder = responder
        Self.registrar(self)
    }

    var pedidos: [Pedido] {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return recibidos
    }

    func pedidos(a ruta: String) -> [Pedido] {
        pedidos.filter { $0.ruta == ruta }
    }

    func cliente(idioma: String = "es-AR") -> ClienteAPI {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.protocolClasses = [ProtocoloDePrueba.self]
        return ClienteAPI(base: base, sesion: URLSession(configuration: configuracion), idioma: { idioma })
    }

    fileprivate func atender(_ pedido: Pedido) -> Respuesta {
        cerrojo.lock()
        recibidos.append(pedido)
        let hastaAhora = recibidos
        cerrojo.unlock()
        return responder(pedido, hastaAhora)
    }

    // MARK: - Registro por host

    private static let cerrojoDelRegistro = NSLock()
    private static var registro: [String: ServidorDePrueba] = [:]

    private static func registrar(_ servidor: ServidorDePrueba) {
        cerrojoDelRegistro.lock()
        defer { cerrojoDelRegistro.unlock() }
        registro[servidor.host] = servidor
    }

    fileprivate static func buscar(_ host: String?) -> ServidorDePrueba? {
        guard let host else { return nil }
        cerrojoDelRegistro.lock()
        defer { cerrojoDelRegistro.unlock() }
        return registro[host]
    }
}

final class ProtocoloDePrueba: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        ServidorDePrueba.buscar(request.url?.host) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let servidor = ServidorDePrueba.buscar(url.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let partes = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var consulta: [String: String] = [:]
        for item in partes?.queryItems ?? [] {
            consulta[item.name] = item.value ?? ""
        }
        let pedido = ServidorDePrueba.Pedido(
            metodo: request.httpMethod ?? "GET",
            ruta: url.path,
            consultaCruda: partes?.percentEncodedQuery,
            consulta: consulta,
            encabezados: request.allHTTPHeaderFields ?? [:],
            cuerpo: Self.cuerpo(de: request),
            espera: request.timeoutInterval
        )
        let respuesta = servidor.atender(pedido)

        guard respuesta.demora > 0 else {
            entregar(respuesta, url: url)
            return
        }
        // La demora es un temporizador en el hilo del protocolo, no un `sleep`: un
        // `sleep` frenaría ese hilo y los pedidos concurrentes dejarían de serlo,
        // que es justo lo que el test de la renovación necesita que sean.
        let temporizador = Timer(timeInterval: respuesta.demora, repeats: false) { [weak self] _ in
            self?.entregar(respuesta, url: url)
        }
        RunLoop.current.add(temporizador, forMode: .common)
    }

    override func stopLoading() {}

    private func entregar(_ respuesta: ServidorDePrueba.Respuesta, url: URL) {
        if let falla = respuesta.falla {
            client?.urlProtocol(self, didFailWithError: URLError(falla))
            return
        }
        let http = HTTPURLResponse(url: url, statusCode: respuesta.http, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        if !respuesta.cuerpo.isEmpty {
            client?.urlProtocol(self, didLoad: respuesta.cuerpo)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    /// `URLSession` le pasa el cuerpo al protocolo como flujo, no como `httpBody`.
    private static func cuerpo(de pedido: URLRequest) -> Data {
        if let datos = pedido.httpBody { return datos }
        guard let flujo = pedido.httpBodyStream else { return Data() }
        flujo.open()
        defer { flujo.close() }
        var datos = Data()
        var bloque = [UInt8](repeating: 0, count: 4096)
        while flujo.hasBytesAvailable {
            let leidos = flujo.read(&bloque, maxLength: bloque.count)
            if leidos <= 0 { break }
            datos.append(bloque, count: leidos)
        }
        return datos
    }
}

/// Datos de ejemplo compartidos por los tests de red.
enum Fixtura {
    static let ahora: Int64 = 1_757_300_000_000
    static let quinceMinutos: Int64 = 900_000

    static func sesion(_ numero: Int, venceEn: Int64 = quinceMinutos, usuario: String = "u-1") -> Sesion {
        Sesion(accessToken: "acceso-\(numero)", accessExpiresAtMs: ahora + venceEn,
               refreshToken: "refresco-\(numero)", refreshExpiresAtMs: ahora + 30 * 86_400_000,
               userId: usuario)
    }

    static func json(_ sesion: Sesion) -> String {
        String(decoding: try! JSONEncoder().encode(sesion), as: UTF8.self)
    }

    static let perfil = #"{"id":"u-1","email":"persona@ejemplo.com","created_at_ms":1,"updated_at_ms":2}"#

    /// El primer cierre de sesión que llegue, o `nil` si no llega en `espera`
    /// segundos. Con techo, para que un test roto falle en vez de colgarse.
    static func primerCierre(de flujo: AsyncStream<MotivoDeCierre>,
                             espera: TimeInterval = 1) async -> MotivoDeCierre? {
        await withTaskGroup(of: MotivoDeCierre?.self) { grupo in
            grupo.addTask {
                for await motivo in flujo { return motivo }
                return nil
            }
            grupo.addTask {
                try? await Task.sleep(nanoseconds: UInt64(espera * 1_000_000_000))
                return nil
            }
            let primero = await grupo.next() ?? nil
            grupo.cancelAll()
            return primero
        }
    }
}

/// El tiempo de los reintentos, sin tiempo real: esperar avanza el reloj al toque y
/// queda anotado cuánto se pidió esperar.
final class TiempoDePrueba: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var ms: Int64
    private var pedidas: [Int64] = []

    init(_ ms: Int64 = Fixtura.ahora) {
        self.ms = ms
    }

    var ahora: Int64 {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return ms
    }

    /// Lo que se pidió esperar, en orden.
    var esperas: [Int64] {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return pedidas
    }

    /// Lo que tarda algo que no es una espera: un pedido que se quedó colgado.
    func avanzar(_ delta: Int64) {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        ms += delta
    }

    func esperar(_ delta: Int64) {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        pedidas.append(delta)
        ms += delta
    }
}

/// Una espera que termina recién cuando el test la abre.
final class CompuertaDePrueba: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var abierta = false
    private var esperando: [CheckedContinuation<Void, Never>] = []

    var hayAlguienEsperando: Bool {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return !esperando.isEmpty
    }

    func pasar() async {
        await withCheckedContinuation { (continuacion: CheckedContinuation<Void, Never>) in
            cerrojo.lock()
            if abierta {
                cerrojo.unlock()
                continuacion.resume()
            } else {
                esperando.append(continuacion)
                cerrojo.unlock()
            }
        }
    }

    func abrir() {
        cerrojo.lock()
        abierta = true
        let despertar = esperando
        esperando = []
        cerrojo.unlock()
        despertar.forEach { $0.resume() }
    }
}

/// Cuántas veces pasó algo, desde cualquier hilo.
final class ContadorDePrueba: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var cuenta = 0

    var valor: Int {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return cuenta
    }

    func sumar() {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        cuenta += 1
    }
}
