import XCTest
@testable import TrainerCore

/// El color que el teléfono le manda al reloj: qué viaja, qué se entiende al
/// llegar y qué se guarda del otro lado.
final class AparienciaCompartidaTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() {
        suite = "tests-apariencia-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testIdaYVuelta_elRelojLeeLoQueMandaElTelefono() {
        let enviada = AparienciaCompartida(acento: "59,130,246", modo: ModoApariencia.claro.rawValue)
        let campos = enviada.campos
        XCTAssertEqual(campos[AparienciaCompartida.claveAcento] as? String, "59,130,246")
        XCTAssertEqual(campos[AparienciaCompartida.claveModo] as? String, "claro")
        XCTAssertEqual(AparienciaCompartida.leer(de: campos), enviada)
    }

    func testElColorDeFabricaViajaVacio() {
        let enviada = AparienciaCompartida(acento: "", modo: "oscuro")
        XCTAssertEqual(AparienciaCompartida.leer(de: enviada.campos)?.acento, "")
    }

    func testUnContextoSinColor_noTocaLoGuardado() {
        // Un snapshot de un build anterior, o un `pong` de antes del cambio.
        XCTAssertNil(AparienciaCompartida.leer(de: ["series": Data(), "usuarioId": "u-1"]))
    }

    func testUnColorMalEscrito_seVuelveElDeFabrica() {
        XCTAssertEqual(AparienciaCompartida(acento: "300,0,0", modo: "").acento, "")
        XCTAssertEqual(AparienciaCompartida.leer(de: [AparienciaCompartida.claveAcento: "rojo"])?.acento, "")
    }

    func testSinModo_seLeeIgualElColor() {
        let leida = AparienciaCompartida.leer(de: [AparienciaCompartida.claveAcento: "34,211,238"])
        XCTAssertEqual(leida?.acento, "34,211,238")
        XCTAssertEqual(leida?.modo, "")
    }

    func testLoGuardado_saleDeLasMismasClavesQueAjustes() {
        XCTAssertEqual(AparienciaCompartida.guardada(en: defaults),
                       AparienciaCompartida(acento: "", modo: ModoApariencia.predeterminado.rawValue))
        defaults.set("249,115,22", forKey: AcentoPersonalizado.clave)
        defaults.set("automatico", forKey: ModoApariencia.clave)
        XCTAssertEqual(AparienciaCompartida.guardada(en: defaults),
                       AparienciaCompartida(acento: "249,115,22", modo: "automatico"))
    }

    @MainActor
    func testElRelojGuardaYPublicaElColorQueLlega() {
        let apariencia = AparienciaDelReloj(defaults: defaults)
        XCTAssertEqual(apariencia.acentoGuardado, "")

        apariencia.aplicar(AparienciaCompartida(acento: "132,204,22", modo: "claro"))

        XCTAssertEqual(apariencia.acentoGuardado, "132,204,22")
        XCTAssertEqual(defaults.string(forKey: AcentoPersonalizado.clave), "132,204,22")
        XCTAssertEqual(apariencia.modoGuardado, "claro")

        // Volver al de fábrica también se guarda: vacío.
        apariencia.aplicar(AparienciaCompartida(acento: "", modo: "claro"))
        XCTAssertEqual(defaults.string(forKey: AcentoPersonalizado.clave), "")
    }
}
