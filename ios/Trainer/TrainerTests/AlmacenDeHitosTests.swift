import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

@MainActor
@Suite("Almacén de hitos, calendario de actividad y registro de pasos")
struct AlmacenDeHitosTests {

    @Test("Guarda y recupera la cantidad de pasos para una fecha específica")
    func testGuardaYRecuperaPasos() {
        let almacen = AlmacenDeHitos.compartido
        let cal = Calendar.current
        let ayer = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        almacen.guardarPasos(5000, para: ayer)
        let pasosAyer = almacen.pasos(para: ayer)

        #expect(pasosAyer == 5000, "Debe registrar y persistir los 5000 pasos de ayer correctamente")
    }

    @Test("Agrupa múltiples entrenamientos del mismo día en una lista ordenada")
    func testMultiplesEntrenamientosMismoDia() {
        let almacen = AlmacenDeHitos.compartido
        let cal = Calendar.current
        let hoy = Date()
        let baseMs = Int64(cal.startOfDay(for: hoy).timeIntervalSince1970 * 1000)

        let entreno1 = Actividad(
            id: "test-run-1km",
            sport: .running,
            startedAtMs: baseMs + 8 * 3600 * 1000,
            durationS: 300,
            distanceM: 1000,
            elevationGainM: 5,
            avgHrBpm: 140,
            maxHrBpm: 155,
            kcal: 65,
            device: .telefono,
            createdAtMs: baseMs,
            updatedAtMs: baseMs
        )

        let entreno2 = Actividad(
            id: "test-run-2km",
            sport: .running,
            startedAtMs: baseMs + 18 * 3600 * 1000,
            durationS: 600,
            distanceM: 2000,
            elevationGainM: 10,
            avgHrBpm: 150,
            maxHrBpm: 165,
            kcal: 135,
            device: .telefono,
            createdAtMs: baseMs,
            updatedAtMs: baseMs
        )

        almacen.registrarActividad(entreno1)
        almacen.registrarActividad(entreno2)

        let listaHoy = almacen.actividades(para: hoy)
        #expect(listaHoy.count >= 2, "El día debe contener ambos entrenamientos en una lista")
        #expect(listaHoy.contains { $0.id == "test-run-1km" })
        #expect(listaHoy.contains { $0.id == "test-run-2km" })
    }

    @Test("Calcula niveles de intensidad del mapa de calor estilo GitHub")
    func testNivelesDeActividadHeatmap() {
        let almacen = AlmacenDeHitos.compartido
        let cal = Calendar.current
        guard let diaFuturo = cal.date(byAdding: .day, value: 45, to: Date()) else { return }

        // Asegurar día sin nada
        almacen.guardarPasos(0, para: diaFuturo)
        let nivelVacio = almacen.nivelDeActividad(para: diaFuturo)
        #expect(nivelVacio == 0, "Un día sin actividad debe dar nivel 0")

        // Con pasos elevados
        almacen.guardarPasos(6000, para: diaFuturo)
        #expect(almacen.nivelDeActividad(para: diaFuturo) == 1)

        almacen.guardarPasos(12000, para: diaFuturo)
        #expect(almacen.nivelDeActividad(para: diaFuturo) == 2)
    }

    // MARK: - Separación por cuenta y migración

    /// Un almacén con su propia carpeta y sus propias preferencias, sin Salud.
    private func almacenAislado(dueno: String? = nil, carpeta: String = "tests-hitos-\(UUID().uuidString)",
                                preferencias: UserDefaults) -> AlmacenDeHitos {
        AlmacenDeHitos(carpeta: carpeta, preferencias: preferencias, dueno: dueno, conectarConLaApp: false)
    }

    private func preferenciasAisladas() -> (UserDefaults, String) {
        let nombre = "tests-hitos-\(UUID().uuidString)"
        return (UserDefaults(suiteName: nombre) ?? .standard, nombre)
    }

    private func carpetaDeSoporte(_ nombre: String) -> URL? {
        (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                      appropriateFor: nil, create: true))?
            .appendingPathComponent(nombre, isDirectory: true)
    }

    private func actividad(_ id: String, en fecha: Date) -> Actividad {
        let ms = Int64(fecha.timeIntervalSince1970 * 1000)
        return Actividad(id: id, sport: .running, startedAtMs: ms, durationS: 600, distanceM: 2000,
                         elevationGainM: 0, avgHrBpm: nil, maxHrBpm: nil, kcal: nil, device: .telefono,
                         createdAtMs: ms, updatedAtMs: ms)
    }

    @Test("Lo de una cuenta no lo ve la siguiente, y vuelve entero cuando entra la misma persona")
    func separaPorCuenta() {
        let (preferencias, suite) = preferenciasAisladas()
        let carpeta = "tests-hitos-\(UUID().uuidString)"
        defer {
            preferencias.removePersistentDomain(forName: suite)
            if let url = carpetaDeSoporte(carpeta) { try? FileManager.default.removeItem(at: url) }
        }
        let hoy = Date()
        let almacen = almacenAislado(dueno: "cuenta-a", carpeta: carpeta, preferencias: preferencias)
        almacen.guardarPasos(7_000, para: hoy)
        almacen.registrarActividad(actividad("salida-a", en: hoy))

        almacen.cambiarDeDueno(a: nil)
        #expect(almacen.pasos(para: hoy) == 0)
        #expect(almacen.todasLasActividades.isEmpty)

        almacen.cambiarDeDueno(a: "cuenta-b")
        #expect(almacen.pasos(para: hoy) == 0, "la cuenta B no ve los pasos de A")
        #expect(almacen.actividades(para: hoy).isEmpty)

        almacen.cambiarDeDueno(a: "cuenta-a")
        #expect(almacen.pasos(para: hoy) == 7_000, "A recupera lo suyo")
        #expect(almacen.actividades(para: hoy).map(\.id) == ["salida-a"])

        let reabierto = almacenAislado(dueno: "cuenta-a", carpeta: carpeta, preferencias: preferencias)
        #expect(reabierto.pasos(para: hoy) == 7_000, "persiste en disco")
    }

    @Test("Migra lo de UserDefaults a un archivo y recién después borra las claves viejas")
    func migraDesdePreferencias() throws {
        let (preferencias, suite) = preferenciasAisladas()
        let carpeta = "tests-hitos-\(UUID().uuidString)"
        defer {
            preferencias.removePersistentDomain(forName: suite)
            if let url = carpetaDeSoporte(carpeta) { try? FileManager.default.removeItem(at: url) }
        }
        let hoy = Date()
        let clave = AlmacenDeHitos.clave(para: hoy)
        preferencias.set([clave: 4_321], forKey: AlmacenDeHitos.clavePasosLegada)
        let viejas = try JSONEncoder().encode([clave: [actividad("vieja", en: hoy)]])
        preferencias.set(viejas, forKey: AlmacenDeHitos.claveActividadesLegada)

        // El arranque justo después de actualizar: sesión abierta, perfil sin cargar.
        let almacen = almacenAislado(carpeta: carpeta, preferencias: preferencias)
        #expect(almacen.pasos(para: hoy) == 4_321)
        #expect(preferencias.object(forKey: AlmacenDeHitos.clavePasosLegada) == nil)
        #expect(preferencias.object(forKey: AlmacenDeHitos.claveActividadesLegada) == nil)

        // La primera cuenta que se identifica lo adopta.
        almacen.cambiarDeDueno(a: "cuenta-a")
        #expect(almacen.actividades(para: hoy).map(\.id) == ["vieja"])
        let reabierto = almacenAislado(dueno: "cuenta-a", carpeta: carpeta, preferencias: preferencias)
        #expect(reabierto.pasos(para: hoy) == 4_321)
    }

    @Test("Después de un cierre de sesión, lo migrado sin dueño no se le da a otra cuenta, pero no se borra")
    func noAdoptaDespuesDeUnCierre() throws {
        let (preferencias, suite) = preferenciasAisladas()
        let carpeta = "tests-hitos-\(UUID().uuidString)"
        defer {
            preferencias.removePersistentDomain(forName: suite)
            if let url = carpetaDeSoporte(carpeta) { try? FileManager.default.removeItem(at: url) }
        }
        let hoy = Date()
        preferencias.set([AlmacenDeHitos.clave(para: hoy): 999], forKey: AlmacenDeHitos.clavePasosLegada)

        let almacen = almacenAislado(carpeta: carpeta, preferencias: preferencias)
        almacen.cambiarDeDueno(a: nil)
        almacen.cambiarDeDueno(a: "cuenta-b")
        #expect(almacen.pasos(para: hoy) == 0)
        let sinDueno = try #require(carpetaDeSoporte(carpeta)).appendingPathComponent("sin-dueno.json")
        #expect(FileManager.default.fileExists(atPath: sinDueno.path), "queda guardado aparte")
    }

    @Test("El color de la paleta en el móvil es rosa Stamina")
    func testColorDeAcentoEsRosa() {
        // En sRGB el rosa Stamina corresponde a R: 1.0, G: 0.137, B: 0.655
        let acento = Paleta.acento
        #expect(Paleta.secundario == acento)
        #expect(Paleta.pestanaActiva == acento)
        #expect(Paleta.textoAcento == acento)
    }
}
