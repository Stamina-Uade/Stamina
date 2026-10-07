import XCTest
@testable import TrainerCore

final class AlmacenDeRecorridosTests: XCTestCase {
    private var nombreTemporal: String!
    private var almacen: AlmacenDeRecorridos!

    override func setUp() {
        super.setUp()
        nombreTemporal = "test-recorridos-\(UUID().uuidString)"
        almacen = AlmacenDeRecorridos(nombre: nombreTemporal)
    }

    override func tearDown() {
        almacen.borrarTodo()
        super.tearDown()
    }

    func testGuardarYRecuperarPuntos() {
        let id = "actividad-123"
        let puntos = [
            PuntoDeRecorrido(lat: -34.6037, lon: -58.3816, atMs: 1000),
            PuntoDeRecorrido(lat: -34.6040, lon: -58.3820, atMs: 2000)
        ]

        almacen.guardar(id: id, puntos: puntos)

        let recuperados = almacen.puntos(para: id)
        XCTAssertNotNil(recuperados)
        XCTAssertEqual(recuperados?.count, 2)
        XCTAssertEqual(recuperados?.first?.lat, -34.6037)
        XCTAssertEqual(recuperados?.last?.atMs, 2000)
    }

    func testRecuperarDesdeDisco() {
        let id = "actividad-disco"
        let puntos = [
            PuntoDeRecorrido(lat: -34.6000, lon: -58.3800, atMs: 5000)
        ]

        almacen.guardar(id: id, puntos: puntos)

        // Nuevo almacén apuntando a la misma carpeta (sin memoria previa)
        let segundoAlmacen = AlmacenDeRecorridos(nombre: nombreTemporal)
        let recuperados = segundoAlmacen.puntos(para: id)
        XCTAssertNotNil(recuperados)
        XCTAssertEqual(recuperados?.count, 1)
        XCTAssertEqual(recuperados?.first?.lat, -34.6000)
    }

    func testBorrarId() {
        let id = "actividad-a-borrar"
        let puntos = [PuntoDeRecorrido(lat: -34.6000, lon: -58.3800, atMs: 5000)]
        almacen.guardar(id: id, puntos: puntos)
        XCTAssertNotNil(almacen.puntos(para: id))

        almacen.borrar(id: id)
        XCTAssertNil(almacen.puntos(para: id))
    }

    func testBorrarTodo() {
        almacen.guardar(id: "act-1", puntos: [PuntoDeRecorrido(lat: -34.1, lon: -58.1, atMs: 100)])
        almacen.guardar(id: "act-2", puntos: [PuntoDeRecorrido(lat: -34.2, lon: -58.2, atMs: 200)])

        almacen.borrarTodo()

        XCTAssertNil(almacen.puntos(para: "act-1"))
        XCTAssertNil(almacen.puntos(para: "act-2"))
    }
}
