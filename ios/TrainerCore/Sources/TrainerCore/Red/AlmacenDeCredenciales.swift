import Foundation
import Security

// =============================================================================
// Dónde vive la sesión mientras la app está cerrada.
//
// AGENTS.md §12.1: los tokens van al almacenamiento seguro de la plataforma —en
// iOS, el Keychain—, nunca a `UserDefaults`, a un archivo ni a un log. El
// contrato lo repite en `Sesion.refresh_token`.
//
// Está detrás de un protocolo por los tests: el Keychain de verdad no se puede
// usar desde `swift test` sin firmar el binario, y un test que depende de eso no
// prueba la lógica, prueba la máquina donde corre. `AlmacenEnMemoria` es el doble;
// el llavero real se prueba en `TrainerTests`, adentro del simulador.
// =============================================================================

public protocol AlmacenDeCredenciales: Sendable {
    /// La sesión guardada, o `nil` si no hay ninguna que se pueda leer.
    func leer() -> Sesion?
    func guardar(_ sesion: Sesion) throws
    func borrar()
}

/// El `OSStatus` que devolvió el Keychain. Sin mensaje: el número alcanza para
/// buscarlo, y un mensaje armado acá sería una tentación de loguearlo junto con
/// lo que se estaba guardando.
public struct ErrorDelLlavero: Error, Equatable, Sendable {
    public let estado: OSStatus
}

/// La sesión en el Keychain, como el JSON de `Sesion` del contrato.
public final class AlmacenEnLlavero: AlmacenDeCredenciales {

    /// El `kSecAttrService` de la app. Los tests usan otro para no pisarla.
    public static let servicioDeLaApp = "com.tecladus.Trainer.sesion"

    /// Una sola cuenta: la app tiene una sola sesión por vez.
    private static let cuenta = "sesion"

    private let servicio: String

    public init(servicio: String = AlmacenEnLlavero.servicioDeLaApp) {
        self.servicio = servicio
    }

    private var consulta: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: Self.cuenta,
        ]
    }

    public func leer() -> Sesion? {
        var pedido = consulta
        pedido[kSecReturnData as String] = true
        pedido[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(pedido as CFDictionary, &item) == errSecSuccess,
              let datos = item as? Data else { return nil }

        guard let sesion = try? JSONDecoder().decode(Sesion.self, from: datos) else {
            // Algo que no se puede leer no sirve para entrar, y dejarlo ahí haría que
            // cada arranque lo intente de nuevo. Se borra y se vuelve a entrar.
            borrar()
            return nil
        }
        return sesion
    }

    public func guardar(_ sesion: Sesion) throws {
        let datos = try JSONEncoder().encode(sesion)
        let cambios: [String: Any] = [
            kSecValueData as String: datos,
            // 🛑 Después del PRIMER desbloqueo y sólo en ESTE teléfono.
            //
            // "Después del primer desbloqueo" y no "mientras está desbloqueado":
            // el teléfono pasa la sesión de gimnasio bloqueado en un bolsillo, y
            // renovar el token en ese momento tiene que poder leerlo.
            // "Sólo en este teléfono": no viaja en los backups ni se restaura en
            // otro. Un refresh token copiado a otro dispositivo es una sesión
            // abierta en un lugar que la persona no eligió.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Actualizar primero y agregar sólo si no existía. Borrar y volver a
        // agregar deja un instante sin sesión guardada, y el refresh rota en cada
        // uso: si la app muere justo ahí, la sesión nueva se pierde y la vieja ya
        // no vale.
        var estado = SecItemUpdate(consulta as CFDictionary, cambios as CFDictionary)
        if estado == errSecItemNotFound {
            let alta = consulta.merging(cambios) { _, nuevo in nuevo }
            estado = SecItemAdd(alta as CFDictionary, nil)
        }
        guard estado == errSecSuccess else { throw ErrorDelLlavero(estado: estado) }
    }

    public func borrar() {
        SecItemDelete(consulta as CFDictionary)
    }
}

/// El doble de los tests, y de las vistas previas. Nunca toca el disco.
public final class AlmacenEnMemoria: AlmacenDeCredenciales, @unchecked Sendable {
    private let cerrojo = NSLock()
    private var sesion: Sesion?

    public init(_ sesion: Sesion? = nil) {
        self.sesion = sesion
    }

    public func leer() -> Sesion? {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return sesion
    }

    public func guardar(_ sesion: Sesion) throws {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        self.sesion = sesion
    }

    public func borrar() {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        sesion = nil
    }
}
