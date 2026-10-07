import Foundation

/// Almacén local persistente y en memoria de los recorridos completos de actividades.
///
/// Guarda los puntos GPS de cada actividad inmediatamente al finalizar o al recibirse del reloj,
/// para que el minimapa y las estadísticas por kilómetro se muestren de forma instantánea (0 ms)
/// sin tener que esperar la sincronización en segundo plano con el servidor.
public final class AlmacenDeRecorridos: @unchecked Sendable {
    public static let compartido = AlmacenDeRecorridos()

    private let lock = NSLock()
    private var memoria: [String: [PuntoDeRecorrido]] = [:]
    private let carpeta: URL?

    public init(nombre: String = "recorridos-locales") {
        let soporte = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        carpeta = soporte?.appendingPathComponent(nombre, isDirectory: true)
        prepararCarpeta()
    }

    /// Guarda los puntos del recorrido asociados al id de la actividad.
    public func guardar(id: String, puntos: [PuntoDeRecorrido]) {
        guard !id.isEmpty, !puntos.isEmpty else { return }
        lock.lock()
        memoria[id] = puntos
        lock.unlock()

        guard let carpeta, let datos = try? JSONEncoder().encode(puntos) else { return }
        prepararCarpeta()
        let url = carpeta.appendingPathComponent(nombreSeguro(id) + ".json")
        _ = escribir(datos, en: url)
    }

    /// Obtiene los puntos del recorrido para una actividad, buscando primero en memoria y luego en disco.
    public func puntos(para id: String) -> [PuntoDeRecorrido]? {
        guard !id.isEmpty else { return nil }
        lock.lock()
        if let enMemoria = memoria[id] {
            lock.unlock()
            return enMemoria
        }
        lock.unlock()

        guard let carpeta else { return nil }
        let url = carpeta.appendingPathComponent(nombreSeguro(id) + ".json")
        guard let datos = try? Data(contentsOf: url),
              let guardados = try? JSONDecoder().decode([PuntoDeRecorrido].self, from: datos) else {
            return nil
        }
        lock.lock()
        memoria[id] = guardados
        lock.unlock()
        return guardados
    }

    /// Elimina el recorrido para una actividad.
    public func borrar(id: String) {
        guard !id.isEmpty else { return }
        lock.lock()
        memoria.removeValue(forKey: id)
        lock.unlock()

        guard let carpeta else { return }
        let url = carpeta.appendingPathComponent(nombreSeguro(id) + ".json")
        try? FileManager.default.removeItem(at: url)
    }

    /// Borra todos los recorridos guardados en memoria y en disco (por ejemplo al cerrar sesión).
    public func borrarTodo() {
        lock.lock()
        memoria.removeAll()
        lock.unlock()

        guard let carpeta else { return }
        try? FileManager.default.removeItem(at: carpeta)
        prepararCarpeta()
    }

    private func prepararCarpeta() {
        guard let carpeta else { return }
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        var recursos = URLResourceValues()
        recursos.isExcludedFromBackup = true
        var mutable = carpeta
        try? mutable.setResourceValues(recursos)
    }

    private func escribir(_ datos: Data, en url: URL) -> Bool {
        do {
            try datos.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var mutable = url
            var recursos = URLResourceValues()
            recursos.isExcludedFromBackup = true
            try? mutable.setResourceValues(recursos)
            return true
        } catch {
            return false
        }
    }

    private func nombreSeguro(_ id: String) -> String {
        Data(id.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}
