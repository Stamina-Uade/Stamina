import Foundation

/// Buzón durable para las salidas completas que viajan del reloj al teléfono.
///
/// El recorrido puede superar cómodamente el tamaño práctico de un diccionario de
/// `transferUserInfo`. Por eso se escribe primero como archivo y WatchConnectivity
/// transporta ese archivo en segundo plano. El emisor conserva su copia hasta que
/// recibe `didFinish`; el receptor conserva otra hasta que la app la incorpora a
/// su propia cola de subida al servidor.
public final class AlmacenDeTransferenciasDeSalida: @unchecked Sendable {
    private let carpeta: URL?
    private var carpetaDeSalida: URL? { carpeta?.appendingPathComponent("salida", isDirectory: true) }
    private var archivoDeEntrada: URL? { carpeta?.appendingPathComponent("entrada.json") }

    public init(nombre: String = "transferencias-de-salida") {
        let soporte = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: true)
        carpeta = soporte?.appendingPathComponent(nombre, isDirectory: true)
        prepararCarpetas()
    }

    /// Persiste la salida entera antes de entregársela al sistema operativo.
    /// Repetirla con el mismo id devuelve el mismo archivo y no duplica datos.
    @discardableResult
    public func guardarParaEnviar(_ salida: SalidaDelReloj) -> URL? {
        guard let carpetaDeSalida,
              let datos = try? JSONEncoder().encode(salida) else { return nil }
        prepararCarpetas()
        let url = carpetaDeSalida.appendingPathComponent(nombreSeguro(salida.id) + ".json")
        guard FileManager.default.fileExists(atPath: url.path)
                || escribir(datos, en: url) else { return nil }
        return url
    }

    public func archivosParaEnviar() -> [URL] {
        guard let carpetaDeSalida else { return [] }
        prepararCarpetas()
        return ((try? FileManager.default.contentsOfDirectory(
            at: carpetaDeSalida,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles])) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func borrarEnviado(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL == carpetaDeSalida?.standardizedFileURL else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    /// Guarda en el iPhone antes de avisar a la capa de actividad. La deduplicación
    /// por id vuelve seguro recibir el mismo archivo más de una vez.
    public func guardarRecibida(_ salida: SalidaDelReloj) {
        var recibidas = leerRecibidas()
        guard !recibidas.contains(where: { $0.id == salida.id }) else { return }
        recibidas.append(salida)
        guardarRecibidas(recibidas)
    }

    public func leerRecibidas() -> [SalidaDelReloj] {
        guard let archivoDeEntrada,
              let datos = try? Data(contentsOf: archivoDeEntrada) else { return [] }
        guard let recibidas = try? JSONDecoder().decode([SalidaDelReloj].self, from: datos) else {
            // 🛑 Ilegible: se aparta. Devolver [] sin más dejaba que el próximo
            // `guardarRecibidas` pisara salidas del reloj que nunca se incorporaron.
            ArchivoIlegible.apartar(archivoDeEntrada)
            return []
        }
        return recibidas
    }

    public func guardarRecibidas(_ recibidas: [SalidaDelReloj]) {
        guard let archivoDeEntrada,
              let datos = try? JSONEncoder().encode(recibidas) else { return }
        prepararCarpetas()
        _ = escribir(datos, en: archivoDeEntrada)
    }

    public func borrarTodo() {
        guard let carpeta else { return }
        try? FileManager.default.removeItem(at: carpeta)
    }

    private func prepararCarpetas() {
        guard let carpeta, let carpetaDeSalida else { return }
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: carpetaDeSalida, withIntermediateDirectories: true)
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

/// Un archivo propio que existe pero no se puede decodificar (una versión vieja,
/// un corte a mitad de escritura) se mueve a `<nombre>.corrupto-<timestamp>` en la
/// misma carpeta. Así el lector puede seguir con una lista vacía sin que el próximo
/// guardado pise datos de la persona: quedan ahí para recuperarlos a mano.
public enum ArchivoIlegible {
    @discardableResult
    public static func apartar(_ url: URL, ahora: Date = Date()) -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let marca = Int64((ahora.timeIntervalSince1970 * 1000).rounded())
        var destino = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupto-\(marca)")
        var intento = 1
        while FileManager.default.fileExists(atPath: destino.path) {
            destino = url.deletingLastPathComponent()
                .appendingPathComponent(url.lastPathComponent + ".corrupto-\(marca)-\(intento)")
            intento += 1
        }
        do {
            try FileManager.default.moveItem(at: url, to: destino)
            return destino
        } catch {
            // Si no se puede mover, por lo menos queda una copia.
            return (try? FileManager.default.copyItem(at: url, to: destino)) != nil ? destino : nil
        }
    }
}
