import AuthenticationServices
import CryptoKit
import Foundation
import Security
import TrainerCore
import UIKit

// =============================================================================
// "Continuar con Google" y "Continuar con Apple", del lado del teléfono.
//
// Lo único que hace esto es conseguir un `id_token` firmado por el proveedor y el
// `nonce` con el que se pidió. Quién es la persona y si ya tiene cuenta lo decide
// el servidor (`POST /auth/social`), que verifica la firma: el teléfono no confía
// en lo que dice el token, sólo lo transporta.
//
// - **Apple**: `AuthenticationServices`, nativo. Requiere la capacidad "Sign in
//   with Apple" (está en `Trainer.entitlements`) y activarla en el App ID.
// - **Google**: sin SDK. OAuth 2.0 con PKCE en una `ASWebAuthenticationSession`,
//   que es lo que hace por dentro el SDK de Google. Hace falta un "iOS client ID"
//   de Google Cloud Console en `Trainer-Info.plist` → `GoogleClientID`. Sin eso el
//   botón explica que falta configurarlo, en vez de abrir una página que falla.
//
// 🛑 El nonce: uno nuevo y al azar por intento. A Apple se le pasa su SHA-256 (así
// lo pide Apple) y a Google el claro; al servidor siempre va el claro, y él
// compara con lo que corresponde. Es lo que impide reusar un id_token robado.
// =============================================================================

/// Lo que se trae del proveedor.
struct CredencialDeProveedor: Equatable, Sendable {
    let idToken: String
    let nonce: String
    /// Para PRECARGAR el alta si la cuenta es nueva. Apple da el nombre una sola
    /// vez (la primera); después llega vacío y la persona lo escribe.
    var nombre: String?
    var apellido: String?
    var correo: String?
}

enum DesenlaceDelProveedor: Equatable, Sendable {
    case ok(CredencialDeProveedor)
    /// La persona cerró la hoja. No es un error y no se muestra nada.
    case cancelado
    /// Falta el client id (Google) en esta compilación.
    case sinConfigurar
    case fallo
}

@MainActor
enum InicioConProveedor {
    static func iniciar(_ proveedor: Proveedor) async -> DesenlaceDelProveedor {
        switch proveedor {
        case .apple: return await ConApple().iniciar()
        case .google: return await ConGoogle().iniciar()
        }
    }

    /// 32 bytes al azar en base64url: entra en los 16…128 que pide el contrato.
    nonisolated static func nonceNuevo() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return String((UUID().uuidString + UUID().uuidString).prefix(64))
        }
        return Data(bytes).base64URL
    }

    nonisolated static func sha256Hex(_ texto: String) -> String {
        SHA256.hash(data: Data(texto.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Lo que dice el payload de un JWT, SIN verificar: sólo para precargar campos.
    nonisolated static func payload(de jwt: String) -> [String: Any] {
        let partes = jwt.split(separator: ".")
        guard partes.count >= 2 else { return [:] }
        var b64 = String(partes[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let datos = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else { return [:] }
        return json
    }

    static var ventana: ASPresentationAnchor {
        let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return escenas.flatMap(\.windows).first { $0.isKeyWindow } ?? escenas.first?.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Apple

@MainActor
private final class ConApple: NSObject, ASAuthorizationControllerDelegate,
                              ASAuthorizationControllerPresentationContextProviding {
    private var continuacion: CheckedContinuation<DesenlaceDelProveedor, Never>?
    private let nonce = InicioConProveedor.nonceNuevo()
    /// Se retiene a sí mismo mientras la hoja está abierta: el controlador de Apple
    /// guarda al delegado con referencia débil.
    private var yoMismo: ConApple?

    func iniciar() async -> DesenlaceDelProveedor {
        await withCheckedContinuation { continuacion in
            self.continuacion = continuacion
            self.yoMismo = self
            let pedido = ASAuthorizationAppleIDProvider().createRequest()
            pedido.requestedScopes = [.fullName, .email]
            pedido.nonce = InicioConProveedor.sha256Hex(nonce)
            let controlador = ASAuthorizationController(authorizationRequests: [pedido])
            controlador.delegate = self
            controlador.presentationContextProvider = self
            controlador.performRequests()
        }
    }

    private func terminar(_ desenlace: DesenlaceDelProveedor) {
        continuacion?.resume(returning: desenlace)
        continuacion = nil
        yoMismo = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        InicioConProveedor.ventana
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credencial = authorization.credential as? ASAuthorizationAppleIDCredential,
              let datos = credencial.identityToken,
              let token = String(data: datos, encoding: .utf8) else {
            terminar(.fallo)
            return
        }
        let correo = credencial.email ?? (InicioConProveedor.payload(de: token)["email"] as? String)
        terminar(.ok(CredencialDeProveedor(
            idToken: token, nonce: nonce,
            nombre: credencial.fullName?.givenName,
            apellido: credencial.fullName?.familyName,
            correo: correo)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let codigo = (error as? ASAuthorizationError)?.code
        terminar(codigo == .canceled ? .cancelado : .fallo)
    }
}

// MARK: - Google

@MainActor
private final class ConGoogle: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var sesion: ASWebAuthenticationSession?

    /// El "iOS client ID" de Google Cloud Console (`…apps.googleusercontent.com`).
    static var clientId: String? {
        let valor = (Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return valor.hasSuffix(".apps.googleusercontent.com") ? valor : nil
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        InicioConProveedor.ventana
    }

    func iniciar() async -> DesenlaceDelProveedor {
        guard let clientId = Self.clientId else { return .sinConfigurar }
        // El esquema de vuelta que Google le asigna a un client id de iOS: el id al revés.
        let prefijo = clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        let esquema = "com.googleusercontent.apps.\(prefijo)"
        let vuelta = "\(esquema):/oauth2redirect"
        let verificador = InicioConProveedor.nonceNuevo() + InicioConProveedor.nonceNuevo()
        let desafio = Data(SHA256.hash(data: Data(verificador.utf8))).base64URL
        let estado = InicioConProveedor.nonceNuevo()
        let nonce = InicioConProveedor.nonceNuevo()

        var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        url.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: vuelta),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: desafio),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: estado),
            .init(name: "nonce", value: nonce),
            .init(name: "prompt", value: "select_account"),
        ]
        guard let direccion = url.url else { return .fallo }

        let respuesta: URL
        switch await abrir(direccion, esquema: esquema) {
        case .success(let url): respuesta = url
        case .failure(let error):
            let cancelo = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            return cancelo ? .cancelado : .fallo
        }

        let items = URLComponents(url: respuesta, resolvingAgainstBaseURL: false)?.queryItems ?? []
        // 🛑 Un `state` que no es el nuestro es una vuelta que no pedimos.
        guard items.first(where: { $0.name == "state" })?.value == estado,
              let codigo = items.first(where: { $0.name == "code" })?.value else {
            return items.contains { $0.name == "error" && $0.value == "access_denied" } ? .cancelado : .fallo
        }

        guard let idToken = await canjear(codigo: codigo, clientId: clientId, vuelta: vuelta,
                                          verificador: verificador) else { return .fallo }
        let datos = InicioConProveedor.payload(de: idToken)
        return .ok(CredencialDeProveedor(
            idToken: idToken, nonce: nonce,
            nombre: datos["given_name"] as? String,
            apellido: datos["family_name"] as? String,
            correo: datos["email"] as? String))
    }

    private func abrir(_ url: URL, esquema: String) async -> Result<URL, Error> {
        await withCheckedContinuation { continuacion in
            let sesion = ASWebAuthenticationSession(url: url, callbackURLScheme: esquema) { url, error in
                if let url { continuacion.resume(returning: .success(url)) }
                else { continuacion.resume(returning: .failure(error ?? URLError(.unknown))) }
            }
            sesion.presentationContextProvider = self
            // Con la sesión de Safari: si ya entró a Google en el teléfono, elige la
            // cuenta con un toque en vez de escribir la contraseña.
            sesion.prefersEphemeralWebBrowserSession = false
            self.sesion = sesion
            if !sesion.start() { continuacion.resume(returning: .failure(URLError(.cannotOpenFile))) }
        }
    }

    /// Cambia el código por los tokens. Un client id de iOS no tiene secreto: lo
    /// reemplaza el verificador de PKCE.
    private func canjear(codigo: String, clientId: String, vuelta: String, verificador: String) async -> String? {
        var pedido = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        pedido.httpMethod = "POST"
        pedido.timeoutInterval = 15
        pedido.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var cuerpo = URLComponents()
        cuerpo.queryItems = [
            .init(name: "code", value: codigo),
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: vuelta),
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code_verifier", value: verificador),
        ]
        pedido.httpBody = cuerpo.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)
        guard let (datos, respuesta) = try? await URLSession.shared.data(for: pedido),
              (respuesta as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else { return nil }
        return json["id_token"] as? String
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
