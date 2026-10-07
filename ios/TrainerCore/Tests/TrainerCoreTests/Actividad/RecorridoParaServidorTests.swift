import XCTest
@testable import TrainerCore

final class RecorridoParaServidorTests: XCTestCase {
    func testUnaRutaCortaViajaCompleta() {
        let ruta = puntos(8)
        XCTAssertEqual(RecorridoParaServidor.preparar(ruta), ruta)
    }

    func testUnaRutaLargaConservaInicioFinalYTodoElIntervalo() {
        let ruta = puntos(25_001)
        let preparada = RecorridoParaServidor.preparar(ruta)
        XCTAssertEqual(preparada.count, 10_000)
        XCTAssertEqual(preparada.first, ruta.first)
        XCTAssertEqual(preparada.last, ruta.last)
        XCTAssertTrue(zip(preparada, preparada.dropFirst()).allSatisfy { $0.atMs < $1.atMs })
        XCTAssertTrue(preparada.contains { $0.atMs > 12_000 && $0.atMs < 13_000 })
    }

    private func puntos(_ cantidad: Int) -> [PuntoDeRecorrido] {
        (0..<cantidad).map {
            PuntoDeRecorrido(lat: -34.6 + Double($0) / 1_000_000,
                             lon: -58.38, atMs: Int64($0))
        }
    }
}
