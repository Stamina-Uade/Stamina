import XCTest
@testable import TrainerCore

final class GestorDeportesFrecuentesTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "test_deportes_frecuentes"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testOrdenInicialPorDefectoParaUsuarioNuevo() {
        let gestor = GestorDeportesFrecuentes(defaults: defaults)
        let lista = gestor.deportesOrdenados(userId: "usuario_nuevo")

        XCTAssertEqual(lista, [.running, .ciclismo, .natacion, .trekking, .triatlon])
    }

    func testReordenamientoAdaptativoSegunFrecuencia() {
        let gestor = GestorDeportesFrecuentes(defaults: defaults)
        let userId = "atleta_1"

        // Registrar ciclismo 3 veces
        gestor.registrarUso(deporte: .ciclismo, userId: userId)
        gestor.registrarUso(deporte: .ciclismo, userId: userId)
        gestor.registrarUso(deporte: .ciclismo, userId: userId)

        // Registrar carrera 1 vez
        gestor.registrarUso(deporte: .running, userId: userId)

        let orden = gestor.deportesOrdenados(userId: userId)
        XCTAssertEqual(orden.first, .ciclismo)
        XCTAssertEqual(orden[1], .running)
    }

    func testFrecuenciasSonIndividualesPorUsuario() {
        let gestor = GestorDeportesFrecuentes(defaults: defaults)
        let userA = "atleta_nadador"
        let userB = "atleta_ciclista"

        gestor.registrarUso(deporte: .natacion, userId: userA)
        gestor.registrarUso(deporte: .natacion, userId: userA)

        gestor.registrarUso(deporte: .ciclismo, userId: userB)

        let ordenA = gestor.deportesOrdenados(userId: userA)
        let ordenB = gestor.deportesOrdenados(userId: userB)

        XCTAssertEqual(ordenA.first, .natacion)
        XCTAssertEqual(ordenB.first, .ciclismo)
    }
}
