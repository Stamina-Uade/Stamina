import CoreGraphics
import XCTest
import TrainerCore
@testable import Trainer

/// La regla de a qué foto lleva un deslizamiento en la bienvenida. Que el gesto
/// de verdad llegue a esta regla lo mira
/// `FlujoDeEntradaUITests.testLaBienvenidaSePasaDeslizando`.
final class DeslizarLaBienvenidaTests: XCTestCase {

    private let umbral = TokensTamano.objetivoTactilMinimo

    private func destino(desde actual: Int, ancho: CGFloat, alto: CGFloat = 0, de total: Int = 3) -> Int {
        BienvenidaView.fotoTrasDeslizar(desde: actual, de: total,
                                        prediccion: CGSize(width: ancho, height: alto))
    }

    func testHaciaLaIzquierdaVaLaSiguienteYDesdeLaUltimaDaLaVuelta() {
        XCTAssertEqual(destino(desde: 0, ancho: -umbral * 3), 1)
        XCTAssertEqual(destino(desde: 1, ancho: -umbral * 3), 2)
        XCTAssertEqual(destino(desde: 2, ancho: -umbral * 3), 0)
    }

    func testHaciaLaDerechaVaLaAnteriorYDesdeLaPrimeraDaLaVuelta() {
        XCTAssertEqual(destino(desde: 2, ancho: umbral * 3), 1)
        XCTAssertEqual(destino(desde: 1, ancho: umbral * 3), 0)
        XCTAssertEqual(destino(desde: 0, ancho: umbral * 3), 2)
    }

    func testTieneQueRecorrerAlMenosUnObjetivoTactil() {
        XCTAssertEqual(destino(desde: 1, ancho: -(umbral - 1)), 1)
        XCTAssertEqual(destino(desde: 1, ancho: umbral - 1), 1)
        XCTAssertEqual(destino(desde: 1, ancho: -umbral), 2, "el objetivo táctil justo ya cuenta")
    }

    func testUnGestoMasVerticalQueHorizontalNoPasaDeFoto() {
        XCTAssertEqual(destino(desde: 1, ancho: -umbral * 3, alto: umbral * 4), 1)
        XCTAssertEqual(destino(desde: 1, ancho: umbral * 3, alto: -umbral * 4), 1)
        // En diagonal justa tampoco: tiene que ganar el horizontal.
        XCTAssertEqual(destino(desde: 1, ancho: -umbral * 3, alto: umbral * 3), 1)
    }

    func testConUnaSolaFotoNoHayAdondeIr() {
        XCTAssertEqual(destino(desde: 0, ancho: -umbral * 3, de: 1), 0)
    }
}
