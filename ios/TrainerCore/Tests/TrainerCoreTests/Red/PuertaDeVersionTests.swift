import XCTest
@testable import TrainerCore

/// AGENTS.md §5.1 y docs/API.md §4. La regla que más importa está en los tests de
/// abajo de todo: una puerta rota DEJA PASAR.
final class PuertaDeVersionTests: XCTestCase {

    private static func gate(_ accion: String, minimo: Int = 40, recomendado: Int = 50,
                             tienda: String = "https://apps.apple.com/app/id000") -> String {
        """
        {"platform":"ios","minimum_build":\(minimo),"recommended_build":\(recomendado),\
        "action":"\(accion)","code":"update_required_security","message":"Update Trainer",\
        "store_url":"\(tienda)"}
        """
    }

    private func consultar(_ respuesta: ServidorDePrueba.Respuesta,
                           build: Int? = 42) async -> (DecisionDeVersion, ServidorDePrueba) {
        let servidor = ServidorDePrueba { _, _ in respuesta }
        let decision = await PuertaDeVersion(cliente: servidor.cliente(), build: build).consultar()
        return (decision, servidor)
    }

    func testPreguntaComoIOSYConSuBuild() async {
        let (_, servidor) = await consultar(.datos(Self.gate("ok")))

        let pedido = try! XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.metodo, "GET")
        XCTAssertEqual(pedido.ruta, "/v1/version")
        XCTAssertEqual(pedido.consulta, ["platform": "ios", "build": "42"])
        XCTAssertNil(pedido.encabezado("Authorization"), "es pública: se consulta antes de entrar")
    }

    func testSinBuildNoMandaElParametro() async {
        let (_, servidor) = await consultar(.datos(Self.gate("ok")), build: nil)

        XCTAssertEqual(servidor.pedidos.first?.consulta, ["platform": "ios"])
    }

    func testUpdateRequiredCierra() async {
        let (decision, _) = await consultar(.datos(Self.gate("update_required")))

        XCTAssertEqual(decision, .exigirActualizar(AvisoDeVersion(
            codigo: "update_required_security", mensaje: "Update Trainer",
            tienda: URL(string: "https://apps.apple.com/app/id000"))))
    }

    func testUpdateRecommendedAvisaYDejaSeguir() async {
        let (decision, _) = await consultar(.datos(Self.gate("update_recommended", minimo: 1)))

        guard case .recomendarActualizar = decision else {
            return XCTFail("tendría que recomendar, dio \(decision)")
        }
    }

    func testOkDejaPasar() async {
        let (decision, _) = await consultar(.datos(Self.gate("ok", minimo: 1, recomendado: 1)))

        XCTAssertEqual(decision, .pasar)
    }

    // MARK: - 🛑 Una puerta rota deja pasar

    func testConUn503DejaPasar() async {
        let (decision, _) = await consultar(.error("service_unavailable", http: 503))

        XCTAssertEqual(decision, .pasar)
    }

    func testSinRedDejaPasar() async {
        let (decision, _) = await consultar(.sinRed)

        XCTAssertEqual(decision, .pasar)
    }

    func testConBasuraDejaPasar() async {
        for respuesta in [ServidorDePrueba.Respuesta.cruda("<html>502</html>", http: 502),
                          .cruda(#"{"data":{"action":"update_required"}}"#, http: 200),
                          .error("bad_request", http: 400)] {
            let (decision, _) = await consultar(respuesta)
            XCTAssertEqual(decision, .pasar)
        }
    }

    // MARK: - La decisión, sin red

    /// El servidor resuelve la acción; el mínimo se compara igual como piso, por si un
    /// servidor viejo ignorara el `build` y contestara `ok` a todo.
    func testElMinimoSeRespetaAunqueElServidorDigaOk() {
        let puerta = VersionGate(platform: .ios, minimumBuild: 40, recommendedBuild: 50, action: .ok)

        XCTAssertEqual(PuertaDeVersion.decidir(.ok(puerta), build: 39),
                       .exigirActualizar(AvisoDeVersion(codigo: nil, mensaje: nil, tienda: nil)))
        XCTAssertEqual(PuertaDeVersion.decidir(.ok(puerta), build: 45),
                       .recomendarActualizar(AvisoDeVersion(codigo: nil, mensaje: nil, tienda: nil)))
        XCTAssertEqual(PuertaDeVersion.decidir(.ok(puerta), build: 50), .pasar)
        XCTAssertEqual(PuertaDeVersion.decidir(.ok(puerta), build: nil), .pasar,
                       "sin saber qué versión pregunta, no puede cerrar")
    }

    func testSoloSeAbreUnaTiendaHttpsOItmsApps() {
        XCTAssertNotNil(PuertaDeVersion.tiendaSegura("https://apps.apple.com/app/id000"))
        XCTAssertNotNil(PuertaDeVersion.tiendaSegura("itms-apps://apps.apple.com/app/id000"))
        XCTAssertNil(PuertaDeVersion.tiendaSegura("http://apps.apple.com/app/id000"))
        XCTAssertNil(PuertaDeVersion.tiendaSegura("tel:1234"))
        XCTAssertNil(PuertaDeVersion.tiendaSegura("no es una url"))
    }
}
