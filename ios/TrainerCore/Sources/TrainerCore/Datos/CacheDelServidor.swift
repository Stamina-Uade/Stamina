import Foundation

// =============================================================================
// Lo último bueno que mandó el servidor, en disco, para abrir sin señal.
//
// AGENTS.md §6: el plan del jueves no puede depender de tener señal el jueves.
// Y lo que se guarda acá es DATO DE SALUD —el plan con pulso y kcal, lo que se
// comió, las comidas que esperan para subir—, así que tres reglas que no se
// negocian:
//
// 1. 🛑 A disco con Data Protection `completeUntilFirstUserAuthentication`: el
//    archivo queda cifrado hasta el primer desbloqueo después de prender el
//    teléfono. No `complete`: la app refresca al volver a primer plano y sube lo
//    pendiente por detrás, y con `complete` no podría leer ni escribir con la
//    pantalla recién bloqueada.
// 2. 🛑 Nunca en `UserDefaults` (AGENTS.md §12.1): es un plist sin cifrar que
//    además viaja en los backups.
// 3. 🛑 Se borra en CADA cierre de sesión, sea cual sea el motivo: lo cuelga
//    `ServiciosDeLaApp` del mismo gancho del renovador que borra el llavero. Y como
//    un pedido puede volver DESPUÉS de ese cierre, quien escribe lo que trajo de la
//    red pasa la `generacion` con la que salió: si en el medio se borró todo, no se
//    escribe nada, y lo de quien se fue no vuelve a aparecer en el disco.
//
// Además queda fuera del backup: es una copia de lo que ya tiene el servidor, y un
// dato de salud en un backup es un dato de salud en otro lado más.
// =============================================================================

/// Un valor guardado, con el momento en que se guardó.
public struct Guardado<Valor> {
    public let valor: Valor
    /// ms epoch. Es lo que la pantalla dice cuando muestra algo desactualizado.
    public let guardadoEnMs: Int64

    public init(valor: Valor, guardadoEnMs: Int64) {
        self.valor = valor
        self.guardadoEnMs = guardadoEnMs
    }
}

extension Guardado: Equatable where Valor: Equatable {}
extension Guardado: Sendable where Valor: Sendable {}

public final class CacheDelServidor: @unchecked Sendable {

    /// Qué se guarda: un archivo por clave. La rutina y la nutrición guardan sólo el
    /// último día que se pidió, así que nada de esto crece sin tope.
    public enum Clave: String, CaseIterable, Sendable {
        case plan
        case rutina
        case nutricion
        /// Las comidas que la persona guardó o borró sin señal, en orden.
        case comidasPendientes = "comidas-pendientes"
    }

    /// Cómo se escribe cada archivo (regla 1). Está a la vista para que un test la
    /// ate: cambiarla tiene que ser una decisión, no un descuido.
    public static let opcionesDeEscritura: Data.WritingOptions = [
        .atomic, .completeFileProtectionUntilFirstUserAuthentication,
    ]

    /// La carpeta de todo esto, adentro de Application Support.
    let carpeta: URL?
    private let cerrojo = NSLock()
    private var generacionActual = 0

    /// - Parameter nombre: la carpeta. Los tests usan una propia cada uno.
    public init(nombre: String = "cache-del-servidor") {
        let soporte = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
        carpeta = soporte?.appendingPathComponent(nombre, isDirectory: true)
    }

    /// Cambia cada vez que se borra todo. Quien sale a la red la anota antes de
    /// salir y la pasa al guardar lo que trajo (regla 3).
    public var generacion: Int {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return generacionActual
    }

    public func leer<Valor: Decodable>(_ clave: Clave, como tipo: Valor.Type = Valor.self) -> Guardado<Valor>? {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        // Un archivo que no se puede leer —de una versión vieja de la app, o a medio
        // escribir— es lo mismo que no tener nada: se vuelve a pedir.
        guard let archivo = archivo(clave), let datos = try? Data(contentsOf: archivo),
              let sobre = try? JSONDecoder().decode(Sobre<Valor>.self, from: datos) else { return nil }
        return Guardado(valor: sobre.valor, guardadoEnMs: sobre.guardadoEnMs)
    }

    /// Guarda `valor`, salvo que desde `generacion` se haya borrado todo.
    ///
    /// - Parameter generacion: la que se anotó antes de salir a la red. `nil` para
    ///   lo que no viene de la red, sino de lo que la persona acaba de hacer.
    /// - Returns: si quedó escrito.
    @discardableResult
    public func guardar<Valor: Encodable>(_ valor: Valor, en clave: Clave, ahoraMs: Int64,
                                          generacion: Int? = nil) -> Bool {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        if let generacion, generacion != generacionActual { return false }
        guard let carpeta = prepararCarpeta(),
              let datos = try? JSONEncoder().encode(Sobre(guardadoEnMs: ahoraMs, valor: valor)) else { return false }
        do {
            try datos.write(to: carpeta.appendingPathComponent("\(clave.rawValue).json"),
                            options: Self.opcionesDeEscritura)
            return true
        } catch {
            // 🛑 Sin detalle: el error de escritura lleva la ruta, y no hay nada que la
            // persona pueda hacer con él. Lo que no se guardó se vuelve a pedir.
            return false
        }
    }

    public func borrar(_ clave: Clave) {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        guard let archivo = archivo(clave) else { return }
        try? FileManager.default.removeItem(at: archivo)
    }

    /// Borra todo lo guardado, y lo que esté volviendo de la red ya no se escribe.
    /// Lo llama el cierre de sesión.
    public func borrarTodo() {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        generacionActual += 1
        guard let carpeta else { return }
        try? FileManager.default.removeItem(at: carpeta)
    }

    // MARK: - Adentro

    private func archivo(_ clave: Clave) -> URL? {
        carpeta?.appendingPathComponent("\(clave.rawValue).json")
    }

    /// La carpeta, creada con la misma protección que los archivos y fuera del backup.
    private func prepararCarpeta() -> URL? {
        guard var carpeta else { return nil }
        if !FileManager.default.fileExists(atPath: carpeta.path) {
            do {
                try FileManager.default.createDirectory(
                    at: carpeta, withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            } catch {
                return nil
            }
        }
        var valores = URLResourceValues()
        valores.isExcludedFromBackup = true
        try? carpeta.setResourceValues(valores)
        return carpeta
    }
}

/// El archivo: el valor y cuándo se guardó.
private struct Sobre<Valor> {
    let guardadoEnMs: Int64
    let valor: Valor
}

extension Sobre: Encodable where Valor: Encodable {}
extension Sobre: Decodable where Valor: Decodable {}
