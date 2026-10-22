import Foundation

// =============================================================================
// El cliente HTTP de Trainer. Habla el sobre de `shared/api/openapi.yaml` y nada
// más: las rutas con nombre están en `ApiTrainer.swift`, los modelos se GENERAN
// (`ModelosGenerados.swift`) y la sesión la maneja `RenovadorDeSesion`.
//
// Está escrito sobre `URLSession` a propósito, igual que Android lo escribió sobre
// `HttpURLConnection`: una app que tiene que andar en el sótano de un gimnasio no
// gana nada con otra librería de red, y AGENTS.md §12.1 cuenta cada dependencia
// del cliente como superficie. Si algún día hace falta otra cosa, se cambia acá
// adentro y ninguna pantalla se entera.
//
// 🛑 NO LOGUEA NADA: ni cuerpos, ni tokens, ni correos, ni datos de salud
// (AGENTS.md §8 y §12.1). El cuerpo de `PATCH /me` ES un dato de salud —peso,
// nacimiento, sexo biológico— y las rutas de mañana van a llevar ids. La forma
// más segura de no filtrar nada en un log es no tener log.
//
// 🛑 NI CACHEA. `GET /me` devuelve el perfil y `/auth/*` devuelve tokens: el
// `URLCache` por defecto los escribiría en el disco, afuera del Keychain, que es
// exactamente lo que §12.1 prohíbe.
// =============================================================================

/// Lo que puede pasar en un pedido. Son cuatro casos y ninguno es una excepción:
/// en una app que vive sin señal, "no hay red" es un resultado normal, y cada
/// pantalla tiene que poder decir algo distinto para cada uno.
///
/// Es el `Resultado` de `android/core/.../red/ClienteApi.kt` con una diferencia a
/// propósito: acá `rechazado` no trae el `message` del servidor. docs/API.md §1
/// dice que no se le muestra a nadie, y lo que no viaja no se muestra por descuido.
public enum Resultado<Valor> {
    /// Salió bien.
    case ok(Valor)
    /// El servidor contestó con el sobre de error. `codigo` es contrato
    /// (docs/API.md §2) y es lo que la pantalla traduce. `detalle` (contrato
    /// 1.6.0) es lo que algunos códigos traen para poder seguir —el proveedor de
    /// `password_not_set`, el permiso para reactivar o vincular, los días que
    /// faltan para un borrado— y casi siempre es `nil`.
    case rechazado(codigo: String, http: Int, detalle: DatosDelError? = nil)
    /// No se llegó al servidor: sin señal, servidor caído, o diez segundos sin
    /// respuesta.
    case sinRed
    /// Contestó algo que no es el sobre del contrato. Es un bug de un lado o del
    /// otro —o un proxy en el medio—, no algo que la persona pueda arreglar.
    case respuestaRara(http: Int)
}

extension Resultado: Sendable where Valor: Sendable {}
extension Resultado: Equatable where Valor: Equatable {}

extension Resultado {
    /// El valor, si salió bien.
    public var valor: Valor? {
        if case .ok(let valor) = self { return valor }
        return nil
    }

    /// El código del contrato, si el servidor dijo que no.
    public var codigoDeRechazo: String? {
        if case .rechazado(let codigo, _, _) = self { return codigo }
        return nil
    }

    /// Lo que trajo el rechazo además del código (contrato 1.6.0), si trajo algo.
    public var detalleDelRechazo: DatosDelError? {
        if case .rechazado(_, _, let detalle) = self { return detalle }
        return nil
    }

    /// Transforma sólo el `.ok`: los otros tres casos pasan tal cual.
    public func map<Otro>(_ transformar: (Valor) -> Otro) -> Resultado<Otro> {
        switch self {
        case .ok(let valor): return .ok(transformar(valor))
        case .rechazado(let codigo, let http, let detalle): return .rechazado(codigo: codigo, http: http, detalle: detalle)
        case .sinRed: return .sinRed
        case .respuestaRara(let http): return .respuestaRara(http: http)
        }
    }
}

public enum MetodoHTTP: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

/// Lo que devuelve un pedido que contesta sin cuerpo. `POST /auth/logout` da 204,
/// y un 204 no trae sobre que leer.
public struct SinCuerpo: Decodable, Equatable, Sendable {
    public init() {}
}

/// Una página de una lista: `{"data": [...], "pagination": {...}}`.
///
/// `pagination` va AL LADO de `data`, no adentro, y por eso una lista no se puede
/// leer con el sobre común. El cursor es `Paginacion`, que desde la 1.1.0 SE GENERA
/// del contrato (`ModelosGenerados.swift`): keyset, nunca OFFSET, y **opaco**, así
/// que el cliente lo devuelve tal cual y no lo interpreta. Las listas de la 1.1.0
/// son `/exercises`, `/gym/sessions` y `/activities`.
public struct Pagina<Elemento> {
    public let elementos: [Elemento]
    public let paginacion: Paginacion

    public init(elementos: [Elemento], paginacion: Paginacion) {
        self.elementos = elementos
        self.paginacion = paginacion
    }
}

extension Pagina: Sendable where Elemento: Sendable {}
extension Pagina: Equatable where Elemento: Equatable {}

/// El transporte. No sabe de sesiones: el token lo pone quien llama, y el que
/// sabe cuándo renovarlo es `RenovadorDeSesion`.
public final class ClienteAPI: Sendable {

    /// Diez segundos, de punta a punta. En el gimnasio la señal es mala pero no
    /// infinita: más que eso deja a la persona mirando una rueda con el teléfono
    /// en la mano. Es el mismo número que usa Android.
    public static let espera: TimeInterval = 10

    /// Con el prefijo del contrato (`…/v1`) y sin barra final. Ver
    /// `ConfiguracionDeRed`.
    public let base: URL

    private let sesion: URLSession
    private let idioma: @Sendable () -> String

    /// - Parameters:
    ///   - sesion: los tests le pasan una con un `URLProtocol` de mentira; la app
    ///     usa la de `sesionSinCache()`.
    ///   - idioma: el `Accept-Language`. Es una función y no un valor porque la
    ///     persona puede cambiar el idioma de la app con la app abierta.
    public init(
        base: URL,
        sesion: URLSession = ClienteAPI.sesionSinCache(),
        idioma: @escaping @Sendable () -> String = { ClienteAPI.idiomaParaElServidor() }
    ) {
        self.base = base
        self.sesion = sesion
        self.idioma = idioma
    }

    /// Una `URLSession` que no guarda nada: ni respuestas, ni cookies.
    ///
    /// `waitsForConnectivity` queda en `false` a propósito: sin señal, el pedido
    /// tiene que fallar YA y decir "sin red", no quedarse esperando a que vuelva
    /// mientras la pantalla muestra una rueda.
    public static func sesionSinCache() -> URLSession {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.timeoutIntervalForRequest = espera
        configuracion.timeoutIntervalForResource = espera
        configuracion.waitsForConnectivity = false
        configuracion.urlCache = nil
        configuracion.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuracion.httpCookieStorage = nil
        configuracion.httpShouldSetCookies = false
        configuracion.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuracion)
    }

    /// `es-AR` o `en-US`: los dos idiomas que publica iOS (AGENTS.md §10).
    ///
    /// Sale del idioma en el que la app está MOSTRANDO sus textos, que no siempre
    /// es el primero del teléfono: con el teléfono en portugués, la app se ve en
    /// castellano (es el idioma de desarrollo) y el `message` de respaldo del
    /// servidor tiene que venir en el mismo idioma que el resto de la pantalla.
    public static func idiomaParaElServidor(
        localizacion: String? = Bundle.main.preferredLocalizations.first
    ) -> String {
        guard let localizacion, localizacion.lowercased().hasPrefix("en") else { return "es-AR" }
        return "en-US"
    }

    // MARK: - Pedidos

    /// Un pedido con el sobre común: `{"data": …}` o `{"error": {…}}`.
    ///
    /// - Parameters:
    ///   - ruta: con la barra inicial y sin el `/v1`, que ya está en `base`.
    ///   - token: el access token, si la ruta lo pide. Lo pone
    ///     `RenovadorDeSesion`, no las pantallas.
    ///   - claveDeIdempotencia: `Idempotency-Key` (AGENTS.md §5.2). La genera
    ///     quien llama y tiene que identificar el INTENTO, no el contenido: ver
    ///     docs/API.md §6.
    public func pedir<Respuesta: Decodable>(
        _ metodo: MetodoHTTP,
        _ ruta: String,
        consulta: [URLQueryItem] = [],
        cuerpo: (any Encodable)? = nil,
        token: String? = nil,
        claveDeIdempotencia: String? = nil,
        como tipo: Respuesta.Type = Respuesta.self
    ) async -> Resultado<Respuesta> {
        let transporte = await transportar(metodo, ruta, consulta: consulta, cuerpo: cuerpo,
                                           token: token, claveDeIdempotencia: claveDeIdempotencia)
        switch transporte {
        case .respuesta(let datos, let http): return Self.interpretar(datos, http: http, como: tipo)
        case .sinRed: return .sinRed
        case .malArmado: return .respuestaRara(http: 0)
        }
    }

    /// Una página de una lista. Siempre `GET`: docs/API.md §1.
    ///
    /// Los parámetros de la página —`cursor` y `limit` en la 1.1.0— los arma quien
    /// llama en `consulta`, con el nombre que declara cada operación del contrato.
    public func pedirPagina<Elemento: Decodable>(
        _ ruta: String,
        consulta: [URLQueryItem] = [],
        token: String? = nil,
        como tipo: Elemento.Type = Elemento.self
    ) async -> Resultado<Pagina<Elemento>> {
        let transporte = await transportar(.get, ruta, consulta: consulta, cuerpo: nil,
                                           token: token, claveDeIdempotencia: nil)
        switch transporte {
        case .respuesta(let datos, let http): return Self.interpretarPagina(datos, http: http, como: tipo)
        case .sinRed: return .sinRed
        case .malArmado: return .respuestaRara(http: 0)
        }
    }

    // MARK: - Adentro

    private enum Transporte {
        case respuesta(Data, http: Int)
        case sinRed
        /// La ruta o el cuerpo no se pudieron armar. Es un bug del cliente, no
        /// algo que haya pasado en la red.
        case malArmado
    }

    private func transportar(
        _ metodo: MetodoHTTP,
        _ ruta: String,
        consulta: [URLQueryItem],
        cuerpo: (any Encodable)?,
        token: String?,
        claveDeIdempotencia: String?
    ) async -> Transporte {
        guard let url = armarURL(ruta, consulta: consulta) else { return .malArmado }

        var pedido = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                timeoutInterval: Self.espera)
        pedido.httpMethod = metodo.rawValue
        pedido.setValue("application/json", forHTTPHeaderField: "Accept")
        pedido.setValue(idioma(), forHTTPHeaderField: "Accept-Language")
        if let token {
            pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let claveDeIdempotencia {
            pedido.setValue(claveDeIdempotencia, forHTTPHeaderField: "Idempotency-Key")
        }
        if let cuerpo {
            guard let datos = try? JSONEncoder().encode(cuerpo) else { return .malArmado }
            pedido.httpBody = datos
            pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (datos, respuesta) = try await sesion.data(for: pedido)
            guard let http = respuesta as? HTTPURLResponse else { return .malArmado }
            return .respuesta(datos, http: http.statusCode)
        } catch {
            // 🛑 El error no se guarda ni se describe: su texto puede llevar la URL,
            // y la URL de mañana lleva ids (§8).
            return .sinRed
        }
    }

    /// `base` + `ruta` + la consulta.
    func armarURL(_ ruta: String, consulta: [URLQueryItem]) -> URL? {
        guard ruta.hasPrefix("/") else { return nil }
        var texto = base.absoluteString
        while texto.hasSuffix("/") { texto.removeLast() }
        guard var partes = URLComponents(string: texto + ruta) else { return nil }
        if !consulta.isEmpty {
            partes.queryItems = consulta
            // 🪤 `URLComponents` deja el `+` sin escapar en la consulta, y del otro
            // lado se lee como un espacio. Un cursor opaco en base64 lo puede traer.
            partes.percentEncodedQuery = partes.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        return partes.url
    }

    /// El sobre, según el status. Un 2xx trae `data`; lo demás trae `error`.
    /// Cualquier otra combinación es una respuesta rara y se dice así, en vez de
    /// adivinar qué quiso decir el servidor.
    static func interpretar<Respuesta: Decodable>(
        _ datos: Data, http: Int, como tipo: Respuesta.Type
    ) -> Resultado<Respuesta> {
        guard (200..<300).contains(http) else { return rechazo(datos, http: http) }
        if let vacio = SinCuerpo() as? Respuesta { return .ok(vacio) }
        guard let sobre = try? JSONDecoder().decode(SobreDeDatos<Respuesta>.self, from: datos) else {
            return .respuestaRara(http: http)
        }
        return .ok(sobre.data)
    }

    static func interpretarPagina<Elemento: Decodable>(
        _ datos: Data, http: Int, como tipo: Elemento.Type
    ) -> Resultado<Pagina<Elemento>> {
        guard (200..<300).contains(http) else { return rechazo(datos, http: http) }
        guard let sobre = try? JSONDecoder().decode(SobreDeLista<Elemento>.self, from: datos) else {
            return .respuestaRara(http: http)
        }
        return .ok(Pagina(elementos: sobre.data, paginacion: sobre.pagination))
    }

    private static func rechazo<Valor>(_ datos: Data, http: Int) -> Resultado<Valor> {
        guard let sobre = try? JSONDecoder().decode(ErrorAPI.self, from: datos) else {
            // Un 502 de un proxy con HTML adentro, por ejemplo.
            return .respuestaRara(http: http)
        }
        return .rechazado(codigo: sobre.error.code, http: http, detalle: sobre.error.details)
    }
}

/// `{"data": …}`. El servidor puede agregar claves al lado: los cambios del
/// contrato son aditivos (AGENTS.md §5), y un cliente que revienta ante una clave
/// nueva obliga a publicar la app cada vez que el servidor crece.
private struct SobreDeDatos<Dato: Decodable>: Decodable {
    let data: Dato
}

private struct SobreDeLista<Elemento: Decodable>: Decodable {
    let data: [Elemento]
    let pagination: Paginacion
}
