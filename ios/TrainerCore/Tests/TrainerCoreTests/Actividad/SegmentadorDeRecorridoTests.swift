import XCTest
@testable import TrainerCore

final class SegmentadorDeRecorridoTests: XCTestCase {
    func testRutaContinuaNoSeDivide() {
        let p1 = PuntoDeRecorrido(lat: -34.6037, lon: -58.3816, atMs: 1000)
        let p2 = PuntoDeRecorrido(lat: -34.6038, lon: -58.3817, atMs: 2000)
        let p3 = PuntoDeRecorrido(lat: -34.6039, lon: -58.3818, atMs: 3000)

        let tramos = SegmentadorDeRecorrido.segmentar([p1, p2, p3])
        XCTAssertEqual(tramos.count, 1)
        XCTAssertEqual(tramos[0].count, 3)
    }

    func testPausaMayorAUmbralDivideTramos() {
        let p1 = PuntoDeRecorrido(lat: -34.6037, lon: -58.3816, atMs: 1000)
        let p2 = PuntoDeRecorrido(lat: -34.6038, lon: -58.3817, atMs: 2000)
        // Pausa de 30 segundos (salto en ms)
        let p3 = PuntoDeRecorrido(lat: -34.6100, lon: -58.3900, atMs: 32000)
        let p4 = PuntoDeRecorrido(lat: -34.6101, lon: -58.3901, atMs: 33000)

        let tramos = SegmentadorDeRecorrido.segmentar([p1, p2, p3, p4])
        XCTAssertEqual(tramos.count, 2)
        XCTAssertEqual(tramos[0].count, 2)
        XCTAssertEqual(tramos[1].count, 2)
    }

    func testSaltoGrandeDeDistanciaDivideTramos() {
        let p1 = PuntoDeRecorrido(lat: -34.6037, lon: -58.3816, atMs: 1000)
        // Salto de varios kilómetros con diferencia de 4 segundos
        let p2 = PuntoDeRecorrido(lat: -34.7000, lon: -58.5000, atMs: 5000)

        let tramos = SegmentadorDeRecorrido.segmentar([p1, p2])
        XCTAssertEqual(tramos.count, 2)
    }
}
