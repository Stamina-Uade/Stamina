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

    @Test("El color de la paleta en el móvil es rosa #FF23A7")
    func testColorDeAcentoEsRosa() {
        // En sRGB #FF23A7 corresponde a R: 1.0, G: 0.137, B: 0.655
        let acento = Paleta.acento
        #expect(Paleta.secundario == acento)
        #expect(Paleta.pestanaActiva == acento)
        #expect(Paleta.textoAcento == acento)
    }
}
