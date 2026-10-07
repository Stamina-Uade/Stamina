import Foundation

// =============================================================================
// La puerta de versión mínima. AGENTS.md §5.1: se construye ANTES de publicar,
// porque después es imposible — el día que haya que cortar un formato viejo, sin
// esto la única salida es sostenerlo para siempre.
//
// `GET /version?platform=ios&build=<CFBundleVersion>`. El servidor resuelve
// `action` con el build que se le manda (docs/API.md §4).
//
// 🛑 SIN RED, 503 O RESPUESTA RARA: DEJA PASAR. Una puerta de versión que se
// rompe no puede dejar a todo el mundo afuera de la app, y en un sótano de
// gimnasio "sin red" es el caso normal, no la excepción. Lo único que cierra es un
// `update_required` que llegó entero.
// =============================================================================

public enum DecisionDeVersion: Equatable, Sendable {
    case pasar
    /// Hay una versión mejor. Se avisa y se sigue.
    case recomendarActualizar(AvisoDeVersion)
    /// Esta versión ya no puede seguir.
    case exigirActualizar(AvisoDeVersion)
}

/// Lo que el servidor manda para explicar la decisión.
public struct AvisoDeVersion: Equatable, Sendable {
    /// Clave estable del mensaje. La app la traduce si la conoce.
    public let codigo: String?
    /// El respaldo, ya traducido por el servidor según `Accept-Language`. A
    /// diferencia del `message` de un error, éste SÍ se muestra cuando la app no
    /// conoce el `codigo`: docs/API.md §4.
    public let mensaje: String?
    /// A dónde mandar a actualizar. Sólo `https` o `itms-apps`: un esquema
    /// cualquiera abriría lo que el servidor diga.
    public let tienda: URL?

    public init(codigo: String?, mensaje: String?, tienda: URL?) {
        self.codigo = codigo
        self.mensaje = mensaje
        self.tienda = tienda
    }
}

public struct PuertaDeVersion: Sendable {
    private let cliente: ClienteAPI
    private let build: Int?

    /// - Parameter build: el `CFBundleVersion` como entero. Si no se puede leer, no
    ///   se manda y el servidor contesta `ok`: la puerta no puede decidir sin saber
    ///   qué versión pregunta, y ante la duda deja pasar.
    public init(cliente: ClienteAPI, build: Int? = PuertaDeVersion.buildInstalado()) {
        self.cliente = cliente
        self.build = build
    }

    public func consultar() async -> DecisionDeVersion {
        var consulta = [URLQueryItem(name: "platform", value: Plataforma.ios.rawValue)]
        if let build {
            consulta.append(URLQueryItem(name: "build", value: String(build)))
        }
        let respuesta: Resultado<VersionGate> = await cliente.pedir(.get, "/version", consulta: consulta)
        return Self.decidir(respuesta, build: build)
    }

    /// La decisión, sin red de por medio. Separada para poder probar cada caso.
    public static func decidir(_ respuesta: Resultado<VersionGate>, build: Int?) -> DecisionDeVersion {
        guard case .ok(let puerta) = respuesta else { return .pasar }

        let aviso = AvisoDeVersion(codigo: puerta.code, mensaje: puerta.message,
                                   tienda: puerta.storeUrl.flatMap(tiendaSegura))

        // La acción la resuelve el servidor. Los números se comparan igual acá como
        // piso: si un servidor viejo ignorara el `build`, contestaría `ok` a todo.
        let debajoDelMinimo = build.map { Int64($0) < puerta.minimumBuild } ?? false
        if puerta.action == .updateRequired || debajoDelMinimo {
            return .exigirActualizar(aviso)
        }
        let debajoDeLoRecomendado = build.map { Int64($0) < puerta.recommendedBuild } ?? false
        if puerta.action == .updateRecommended || debajoDeLoRecomendado {
            return .recomendarActualizar(aviso)
        }
        return .pasar
    }

    /// `CFBundleVersion` como entero positivo, o `nil`.
    public static func buildInstalado(_ bundle: Bundle = .main) -> Int? {
        guard let texto = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let numero = Int(texto), numero >= 1 else { return nil }
        return numero
    }

    static func tiendaSegura(_ texto: String) -> URL? {
        guard let url = URL(string: texto),
              let esquema = url.scheme?.lowercased(),
              esquema == "https" || esquema == "itms-apps" else { return nil }
        return url
    }
}
