import XCTest
@testable import TrainerCore

final class AnalizadorDeRecorridoTests: XCTestCase {
    func testAnalisisDeRecorridoVacio() {
        let resultado = AnalizadorDeRecorrido.analizar(puntos: [], duracionTotalSegundos: 120)
        XCTAssertEqual(resultado.tramos.count, 0)
        XCTAssertEqual(resultado.pausas.count, 0)
        XCTAssertEqual(resultado.splitsKm.count, 0)
        XCTAssertEqual(resultado.tiempoEnMovimientoSegundos, 120)
    }

    func testDeteccionDePausasYSplits() {
        // Crear un recorrido con dos tramos y una pausa de 30 segundos
        var puntos: [PuntoDeRecorrido] = []
        let baseMs: Int64 = 1700000000000

        // Tramo 1: 1000 metros avanzando hacia el norte, puntos cada 2 segundos
        for i in 0...10 {
            let lat = -34.6037 + Double(i) * 0.001 // aprox 111m por 0.001 deg
            let atMs = baseMs + Int64(i * 2 * 1000)
            puntos.append(PuntoDeRecorrido(lat: lat, lon: -58.3816, atMs: atMs))
        }

        // Pausa de 45 segundos (salto en atMs mayor a 20s)
        let finTramo1Ms = puntos.last!.atMs
        let inicioTramo2Ms = finTramo1Ms + 45 * 1000

        // Tramo 2: 500 metros más, puntos cada 2 segundos
        for i in 0...5 {
            let lat = -34.6037 + 0.011 + Double(i) * 0.001
            let atMs = inicioTramo2Ms + Int64(i * 2 * 1000)
            puntos.append(PuntoDeRecorrido(lat: lat, lon: -58.3816, atMs: atMs))
        }

        let analisis = AnalizadorDeRecorrido.analizar(puntos: puntos, deporte: .running)

        XCTAssertEqual(analisis.tramos.count, 2, "Debería haber 2 tramos")
        XCTAssertEqual(analisis.pausas.count, 1, "Debería haber 1 pausa detectada")
        XCTAssertEqual(analisis.pausas.first?.duracionSegundos, 45, "La pausa duró 45 segundos")
        XCTAssertGreaterThanOrEqual(analisis.splitsKm.count, 1, "Debería tener al menos 1 split de km")
        XCTAssertEqual(analisis.splitsKm.first?.numero, 1)
    }
}
