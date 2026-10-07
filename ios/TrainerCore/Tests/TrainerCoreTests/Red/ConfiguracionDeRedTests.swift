import XCTest
@testable import TrainerCore

final class ConfiguracionDeRedTests: XCTestCase {

    func testProduccionLlevaElPrefijoDelContrato() {
        XCTAssertEqual(ConfiguracionDeRed.baseDeProduccion.absoluteString, "https://stamina.com.ar/v1")
    }

    func testSinArgumentoEsProduccion() {
        XCTAssertEqual(ConfiguracionDeRed.base(argumentos: ["Trainer"]), ConfiguracionDeRed.baseDeProduccion)
    }

    /// `swift test` compila en DEBUG, así que acá el argumento cuenta. En release el
    /// `#if` lo saca entero.
    func testApiBaseApuntaAlBackendLocalEnDebug() {
        let base = ConfiguracionDeRed.base(argumentos: ["Trainer", "-apiBase", "http://localhost:8082/v1/"])

        XCTAssertEqual(base.absoluteString, "http://localhost:8082/v1", "sin la barra final")
    }

    func testUnApiBaseQueNoSeEntiendeSeIgnora() {
        for roto in [["-apiBase"], ["-apiBase", ""], ["-apiBase", "localhost:8082/v1"],
                     ["-apiBase", "ftp://localhost/v1"], ["-apiBase", "http:///v1"]] {
            XCTAssertNil(ConfiguracionDeRed.baseSobreescrita(en: ["Trainer"] + roto), "\(roto)")
        }
    }
}
