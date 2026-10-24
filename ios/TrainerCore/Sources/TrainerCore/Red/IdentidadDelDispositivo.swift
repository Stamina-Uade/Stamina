import Foundation
import Security
#if canImport(UIKit)
import UIKit
#endif

/// Desde qué dispositivo se entra (contrato 1.7.0, `DispositivoDeEntrada`): lo que la app
/// manda al entrar y al registrarse para que el servidor avise por correo de un
/// inicio de sesión desde un dispositivo que la cuenta nunca vio.
///
/// - `id` es de la INSTALACIÓN, no del teléfono: un UUID al azar que se genera la
///   primera vez y queda en el llavero, sólo en este teléfono
///   (`AfterFirstUnlockThisDeviceOnly`: no viaja en un backup a otro). No es el
///   `identifierForVendor`, que cambia al borrar y volver a instalar todas las apps
///   del mismo desarrollador. El servidor guarda sólo su hash.
/// - `model` y `os` son para leer en el correo: "iPhone 16 · iOS 26.5".
public enum IdentidadDelDispositivo {

    /// El de este teléfono. `nil` fuera de iOS (el reloj no entra a la cuenta) o si el
    /// llavero no deja guardar el id: sin id no se puede decir si es nuevo, y el
    /// servidor no avisa nada.
    public static func actual() -> DispositivoDeEntrada? {
        #if os(iOS)
        guard let id = idDeLaInstalacion() else { return nil }
        let sistema = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        return DispositivoDeEntrada(id: id, model: nombreDelModelo(identificadorDelModelo(), generico: UIDevice.current.model),
                           os: sistema)
        #else
        return nil
        #endif
    }

    // MARK: - El id de la instalación

    static let servicio = "com.tecladus.Trainer.dispositivo"
    private static let cuenta = "instalacion"

    /// Lo lee del llavero o, la primera vez, lo crea y lo guarda.
    static func idDeLaInstalacion(servicio: String = servicio) -> String? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        var pedido = consulta
        pedido[kSecReturnData as String] = true
        pedido[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        if SecItemCopyMatching(pedido as CFDictionary, &item) == errSecSuccess,
           let datos = item as? Data, let id = String(data: datos, encoding: .utf8), !id.isEmpty {
            return id
        }
        let nuevo = UUID().uuidString
        var alta = consulta
        alta[kSecValueData as String] = Data(nuevo.utf8)
        alta[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(alta as CFDictionary, nil) == errSecSuccess ? nuevo : nil
    }

    // MARK: - El modelo

    /// "iPhone17,3", o el del simulador.
    static func identificadorDelModelo() -> String {
        if let simulado = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulado }
        var datos = utsname()
        uname(&datos)
        return withUnsafeBytes(of: &datos.machine) { crudo in
            String(decoding: crudo.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    /// El nombre comercial de los iPhone conocidos; los demás, el genérico ("iPhone").
    /// Un modelo que falta en la tabla no es un error: el correo dice "iPhone".
    static func nombreDelModelo(_ identificador: String, generico: String) -> String {
        modelos[identificador] ?? generico
    }

    private static let modelos: [String: String] = [
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,6": "iPhone SE",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,5": "iPhone 16e",
    ]
}
