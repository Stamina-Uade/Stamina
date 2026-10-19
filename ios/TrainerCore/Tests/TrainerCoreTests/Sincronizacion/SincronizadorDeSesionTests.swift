import XCTest
@testable import TrainerCore

/// La cuenta que el teléfono le informa al reloj y el guardado local de series.
final class SincronizadorDeSesionTests: XCTestCase {

    func testElRelojEntiendeElCierreDeSesion_aunqueVengaSoloElIdVacio() {
        XCTAssertEqual(SincronizadorDeSesion.cuentaInformada(en: ["cerrarSesion": true]), .some(nil))
        XCTAssertEqual(SincronizadorDeSesion.cuentaInformada(en: ["usuarioId": ""]), .some(nil))
        XCTAssertEqual(SincronizadorDeSesion.cuentaInformada(en: ["usuarioId": "", "cerrarSesion": true]),
                       .some(nil))
    }

    func testUnIdEsUnaCuentaVinculada() {
        XCTAssertEqual(SincronizadorDeSesion.cuentaInformada(en: ["usuarioId": "u-1"]), .some("u-1"))
    }

    func testSinDatoDeCuenta_elRelojSeQuedaComoEsta() {
        // El arranque del teléfono con la sesión guardada y el perfil sin cargar.
        let respuesta = SincronizadorDeSesion.cuentaInformada(en: ["pong": true])
        XCTAssertNil(respuesta)
    }

    func testUnaSesionEnCursoIlegibleSeApartaEnVezDePisarse() throws {
        let nombre = "tests-ilegible-\(UUID().uuidString).json"
        let almacen = AlmacenDeSeries(nombre: nombre)
        defer { almacen.borrar() }
        let carpeta = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let archivo = carpeta.appendingPathComponent(nombre)
        try Data("no es json".utf8).write(to: archivo)

        XCTAssertTrue(almacen.leer().isEmpty)
        almacen.guardar([])

        let apartados = try FileManager.default.contentsOfDirectory(atPath: carpeta.path)
            .filter { $0.hasPrefix(nombre + ".corrupto-") }
        XCTAssertEqual(apartados.count, 1)
        for apartado in apartados {
            try? FileManager.default.removeItem(at: carpeta.appendingPathComponent(apartado))
        }
    }
}
