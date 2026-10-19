import Foundation
import Combine
import UserNotifications
import TrainerCore

// =============================================================================
// El apto físico (certificado médico) de la persona. Rediseño 2026-10, pantalla
// "Validación de apto" del mockup.
//
// 🛑 Es un dato de salud: vive SÓLO en el teléfono, en Application Support,
// separado por cuenta (`DuenoDeLosDatosLocales`) y con protección de archivo
// `.complete` (cifrado mientras el teléfono está bloqueado). No se sube al
// servidor: el contrato (`shared/api/openapi.yaml`) no tiene dónde guardarlo y
// subir un certificado médico es una decisión de producto y legal, no de UI.
// Por eso el texto de la pantalla dice "se guarda en tu teléfono".
// =============================================================================

/// Lo que se sabe del apto cargado.
struct AptoFisico: Codable, Equatable, Sendable {
    /// El nombre con el que la persona eligió el archivo ("apto_fisico.pdf").
    let nombreOriginal: String
    /// El nombre del archivo copiado adentro de la carpeta de la cuenta.
    let archivoGuardado: String
    let bytes: Int64
    let subidoMs: Int64
    /// Medianoche local del día de vencimiento.
    let venceMs: Int64
    /// La casilla "Declaro que mis datos de salud son verdaderos".
    let declaracionAceptada: Bool

    var vence: Date { Date(timeIntervalSince1970: TimeInterval(venceMs) / 1000) }

    /// Días que faltan para el vencimiento (negativo si ya venció).
    func diasParaVencer(ahora: Date = Date(), calendario: Calendar = .current) -> Int {
        let hoy = calendario.startOfDay(for: ahora)
        let fin = calendario.startOfDay(for: vence)
        return calendario.dateComponents([.day], from: hoy, to: fin).day ?? 0
    }
}

/// El estado que muestran Inicio y Perfil.
enum EstadoDelApto: Equatable {
    case sinCargar
    case vigente(dias: Int)
    case porVencer(dias: Int)
    case vencido

    /// Cuántos días antes se avisa. Es lo que promete la pantalla.
    static let diasDeAviso = 30
}

@MainActor
final class AlmacenDeAptoFisico: ObservableObject {
    static let compartido = AlmacenDeAptoFisico()

    @Published private(set) var apto: AptoFisico?

    private let fm = FileManager.default
    private var observador: AnyCancellable?
    private let raiz: URL

    /// - Parameter raiz: carpeta base. Los tests pasan una temporal.
    init(raiz: URL? = nil) {
        if let raiz {
            self.raiz = raiz
        } else {
            let soporte = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true))
                ?? FileManager.default.temporaryDirectory
            self.raiz = soporte.appendingPathComponent("apto", isDirectory: true)
        }
        apto = leer()
        // Cambió la cuenta: se muestra el apto de la cuenta nueva (o ninguno).
        observador = NotificationCenter.default.publisher(for: DuenoDeLosDatosLocales.cambio)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.apto = self.leer()
            }
    }

    var estado: EstadoDelApto {
        guard let apto else { return .sinCargar }
        let dias = apto.diasParaVencer()
        if dias < 0 { return .vencido }
        if dias <= EstadoDelApto.diasDeAviso { return .porVencer(dias: dias) }
        return .vigente(dias: dias)
    }

    var urlDelArchivo: URL? {
        guard let apto else { return nil }
        return carpetaDeLaCuenta.appendingPathComponent(apto.archivoGuardado)
    }

    // MARK: - Guardar

    enum FalloAlGuardar: Error, Equatable {
        case noSePudoLeer
        case muyGrande
        case noSePudoEscribir
    }

    /// El límite de tamaño: un PDF o una foto de un certificado entran de sobra.
    static let bytesMaximos: Int64 = 15 * 1024 * 1024

    /// Copia el archivo elegido adentro de la carpeta de la cuenta y guarda los datos.
    ///
    /// - Parameter origen: la URL que devuelve `fileImporter`. Es de alcance de
    ///   seguridad: se abre y se cierra acá.
    func guardar(desde origen: URL, vence: Date, declaracionAceptada: Bool) -> Result<Void, FalloAlGuardar> {
        let accedio = origen.startAccessingSecurityScopedResource()
        defer { if accedio { origen.stopAccessingSecurityScopedResource() } }

        guard let datos = try? Data(contentsOf: origen) else { return .failure(.noSePudoLeer) }
        guard Int64(datos.count) <= Self.bytesMaximos else { return .failure(.muyGrande) }

        let extensionSegura = Self.extensionPermitida(origen.pathExtension)
        let nombreGuardado = "apto-\(Int64(Date().timeIntervalSince1970 * 1000)).\(extensionSegura)"
        let carpeta = carpetaDeLaCuenta
        do {
            try fm.createDirectory(at: carpeta, withIntermediateDirectories: true)
            try datos.write(to: carpeta.appendingPathComponent(nombreGuardado),
                            options: [.atomic, .completeFileProtection])
        } catch {
            return .failure(.noSePudoEscribir)
        }

        let nuevo = AptoFisico(
            nombreOriginal: origen.lastPathComponent,
            archivoGuardado: nombreGuardado,
            bytes: Int64(datos.count),
            subidoMs: Int64(Date().timeIntervalSince1970 * 1000),
            venceMs: Int64(Calendar.current.startOfDay(for: vence).timeIntervalSince1970 * 1000),
            declaracionAceptada: declaracionAceptada)

        guard escribir(nuevo) else { return .failure(.noSePudoEscribir) }
        // El archivo anterior se borra recién cuando el nuevo ya quedó escrito.
        if let anterior = apto, anterior.archivoGuardado != nombreGuardado {
            try? fm.removeItem(at: carpeta.appendingPathComponent(anterior.archivoGuardado))
        }
        apto = nuevo
        programarAviso(para: nuevo)
        return .success(())
    }

    /// Cambia sólo la fecha (renovó el apto con el mismo archivo, o se equivocó).
    func actualizarVencimiento(_ vence: Date, declaracionAceptada: Bool) -> Bool {
        guard let actual = apto else { return false }
        let nuevo = AptoFisico(
            nombreOriginal: actual.nombreOriginal, archivoGuardado: actual.archivoGuardado,
            bytes: actual.bytes, subidoMs: actual.subidoMs,
            venceMs: Int64(Calendar.current.startOfDay(for: vence).timeIntervalSince1970 * 1000),
            declaracionAceptada: declaracionAceptada)
        guard escribir(nuevo) else { return false }
        apto = nuevo
        programarAviso(para: nuevo)
        return true
    }

    func borrar() {
        if let url = urlDelArchivo { try? fm.removeItem(at: url) }
        try? fm.removeItem(at: carpetaDeLaCuenta.appendingPathComponent("apto.json"))
        apto = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.idDelAviso])
    }

    // MARK: - Disco

    private var carpetaDeLaCuenta: URL {
        let dueno = DuenoDeLosDatosLocales.actual.map(Self.nombreSeguro) ?? "sin-dueno"
        return raiz.appendingPathComponent("usuario-\(dueno)", isDirectory: true)
    }

    private func leer() -> AptoFisico? {
        let url = carpetaDeLaCuenta.appendingPathComponent("apto.json")
        guard let datos = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AptoFisico.self, from: datos)
    }

    private func escribir(_ apto: AptoFisico) -> Bool {
        do {
            try fm.createDirectory(at: carpetaDeLaCuenta, withIntermediateDirectories: true)
            let datos = try JSONEncoder().encode(apto)
            try datos.write(to: carpetaDeLaCuenta.appendingPathComponent("apto.json"),
                            options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }

    /// Un id de cuenta nunca se usa crudo como nombre de carpeta: sin barras ni
    /// puntos no hay forma de salirse de `apto/`.
    static func nombreSeguro(_ id: String) -> String {
        let permitidos = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let limpio = String(id.unicodeScalars.filter { permitidos.contains($0) })
        return limpio.isEmpty ? "sin-dueno" : limpio
    }

    static func extensionPermitida(_ ext: String) -> String {
        let minuscula = ext.lowercased()
        return ["pdf", "jpg", "jpeg", "png", "heic"].contains(minuscula) ? minuscula : "dat"
    }

    // MARK: - Aviso 30 días antes

    static let idDelAviso = "apto-fisico-vencimiento"

    private func programarAviso(para apto: AptoFisico) {
        let centro = UNUserNotificationCenter.current()
        centro.removePendingNotificationRequests(withIdentifiers: [Self.idDelAviso])
        guard let dia = Calendar.current.date(byAdding: .day, value: -EstadoDelApto.diasDeAviso, to: apto.vence),
              dia > Date() else { return }
        var cuando = Calendar.current.dateComponents([.year, .month, .day], from: dia)
        cuando.hour = 10

        let contenido = UNMutableNotificationContent()
        contenido.title = String(localized: "Tu apto físico vence en 30 días", comment: "Aviso de vencimiento del apto")
        // Sin datos de salud en la pantalla bloqueada: sólo el recordatorio.
        contenido.body = String(localized: "Renovalo para seguir recibiendo sugerencias en carrera.",
                                comment: "Aviso de vencimiento del apto")
        let pedido = UNNotificationRequest(identifier: Self.idDelAviso, content: contenido,
                                           trigger: UNCalendarNotificationTrigger(dateMatching: cuando, repeats: false))
        centro.requestAuthorization(options: [.alert, .sound]) { concedido, _ in
            guard concedido else { return }
            centro.add(pedido)
        }
    }
}
