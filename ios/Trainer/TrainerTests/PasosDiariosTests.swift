import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

/// Los pasos diarios: de dónde sale cada número, qué falta subir a `PUT /me/steps` y
/// cómo se fusiona lo que contesta el servidor (gana el más nuevo, igual que allá).
@MainActor
@Suite("Pasos diarios: Salud, carga a mano y servidor")
struct PasosDiariosTests {

    private func almacenAislado(carpeta: String) -> (AlmacenDeHitos, UserDefaults, String) {
        let suite = "tests-pasos-\(UUID().uuidString)"
        let preferencias = UserDefaults(suiteName: suite) ?? .standard
        let almacen = AlmacenDeHitos(carpeta: carpeta, preferencias: preferencias, dueno: "cuenta-a",
                                     conectarConLaApp: false)
        return (almacen, preferencias, suite)
    }

    private func limpiar(_ carpeta: String, _ preferencias: UserDefaults, _ suite: String) {
        preferencias.removePersistentDomain(forName: suite)
        if let url = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true))?
            .appendingPathComponent(carpeta, isDirectory: true) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private var ayer: Date { Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date() }

    @Test("La carga a mano queda pendiente como manual; Salud la reemplaza; leer lo mismo no vuelve a subir")
    func manualYSalud() {
        let carpeta = "tests-pasos-\(UUID().uuidString)"
        let (almacen, preferencias, suite) = almacenAislado(carpeta: carpeta)
        defer { limpiar(carpeta, preferencias, suite) }
        let clave = AlmacenDeHitos.clave(para: ayer)

        almacen.guardarPasos(4_000, para: ayer)
        #expect(almacen.pasosPendientes().map(\.source) == [.manual])

        let inicio = Calendar.current.startOfDay(for: ayer)
        almacen.registrarDeSalud([inicio: 9_876], ahoraMs: 2_000)
        let pendiente = almacen.pasosPendientes()
        #expect(pendiente == [DiaDePasosEntrada(date: clave, steps: 9_876, source: .healthkit, updatedAtMs: 2_000)])
        #expect(almacen.fuenteDePasos(para: ayer) == .healthkit)

        almacen.confirmarSubida(pendiente, respuesta: [DiaDePasos(date: clave, steps: 9_876, source: .healthkit,
                                                                  updatedAtMs: 2_000)])
        #expect(almacen.pasosPendientes().isEmpty)
        almacen.registrarDeSalud([inicio: 9_876], ahoraMs: 3_000)
        #expect(almacen.pasosPendientes().isEmpty, "el mismo número de Salud no se vuelve a subir")
    }

    @Test("Lo que cambió mientras viajaba el lote sigue pendiente")
    func cambioEnVuelo() {
        let carpeta = "tests-pasos-\(UUID().uuidString)"
        let (almacen, preferencias, suite) = almacenAislado(carpeta: carpeta)
        defer { limpiar(carpeta, preferencias, suite) }
        let inicio = Calendar.current.startOfDay(for: ayer)

        almacen.registrarDeSalud([inicio: 5_000], ahoraMs: 1_000)
        let enviado = almacen.pasosPendientes()
        almacen.registrarDeSalud([inicio: 6_000], ahoraMs: 2_000)
        almacen.confirmarSubida(enviado, respuesta: [])
        #expect(almacen.pasosPendientes().map(\.steps) == [6_000])
    }

    @Test("Del servidor: llena lo que falta, gana el más nuevo y no pisa lo local más nuevo")
    func fusionConElServidor() {
        let carpeta = "tests-pasos-\(UUID().uuidString)"
        let (almacen, preferencias, suite) = almacenAislado(carpeta: carpeta)
        defer { limpiar(carpeta, preferencias, suite) }
        let cal = Calendar.current
        let anteayer = cal.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let claveAyer = AlmacenDeHitos.clave(para: ayer)
        let claveAnteayer = AlmacenDeHitos.clave(para: anteayer)

        almacen.registrarDeSalud([cal.startOfDay(for: ayer): 8_000], ahoraMs: 5_000)
        almacen.fusionarDelServidor([
            DiaDePasos(date: claveAyer, steps: 1_000, source: .manual, updatedAtMs: 4_000),
            DiaDePasos(date: claveAnteayer, steps: 12_000, source: .healthkit, updatedAtMs: 4_000),
        ])
        #expect(almacen.pasos(para: ayer) == 8_000, "lo local es más nuevo")
        #expect(almacen.pasosPendientes().map(\.date) == [claveAyer], "y sigue pendiente")
        #expect(almacen.pasos(para: anteayer) == 12_000, "un teléfono nuevo recupera el historial")
        #expect(almacen.fuenteDePasos(para: anteayer) == .healthkit)

        almacen.fusionarDelServidor([DiaDePasos(date: claveAyer, steps: 8_500, source: .healthkit, updatedAtMs: 6_000)])
        #expect(almacen.pasos(para: ayer) == 8_500, "otro teléfono leyó después")
        #expect(almacen.pasosPendientes().isEmpty)
    }

    @Test("Los pasos de antes de esta versión suben una vez, como manual de 'hace mucho'")
    func pasosViejosSinRegistro() {
        let carpeta = "tests-pasos-\(UUID().uuidString)"
        let suite = "tests-pasos-\(UUID().uuidString)"
        let preferencias = UserDefaults(suiteName: suite) ?? .standard
        defer { limpiar(carpeta, preferencias, suite) }
        let clave = AlmacenDeHitos.clave(para: ayer)
        preferencias.set([clave: 3_210], forKey: AlmacenDeHitos.clavePasosLegada)

        let almacen = AlmacenDeHitos(carpeta: carpeta, preferencias: preferencias, dueno: "cuenta-a",
                                     conectarConLaApp: false)
        #expect(almacen.pasosPendientes() == [DiaDePasosEntrada(date: clave, steps: 3_210, source: .manual, updatedAtMs: 1)])
    }

    @Test("Lo pendiente sobrevive a cerrar la app")
    func persisteLoPendiente() {
        let carpeta = "tests-pasos-\(UUID().uuidString)"
        let (almacen, preferencias, suite) = almacenAislado(carpeta: carpeta)
        defer { limpiar(carpeta, preferencias, suite) }
        almacen.guardarPasos(7_500, para: ayer)

        let reabierto = AlmacenDeHitos(carpeta: carpeta, preferencias: preferencias, dueno: "cuenta-a",
                                       conectarConLaApp: false)
        #expect(reabierto.pasosPendientes().map(\.steps) == [7_500])
        #expect(reabierto.fuenteDePasos(para: ayer) == .manual)
    }

    @Test("Un número fuera del contrato no sale: se recorta al tope")
    func topeDelContrato() {
        let carpeta = "tests-pasos-\(UUID().uuidString)"
        let (almacen, preferencias, suite) = almacenAislado(carpeta: carpeta)
        defer { limpiar(carpeta, preferencias, suite) }
        almacen.guardarPasos(1_000_000, para: ayer)
        #expect(almacen.pasosPendientes().map(\.steps) == [Int64(AlmacenDeHitos.maximoDePasos)])
    }
}
