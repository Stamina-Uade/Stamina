import XCTest
@testable import TrainerCore

/// Las comidas sin señal: quedan en disco, suben en orden y con el mismo id, y lo
/// que se borró no se vuelve a crear.
@MainActor
final class ColaDeComidasTests: XCTestCase {

    static let id = "063349d2-0a4b-45c5-9cf6-c54d692ea7ad"
    static let avena = ComidaEntrada(eatenAtMs: 1_789_033_542_979, name: "Avena con banana",
                                     kcal: 420, carbsG: 72, proteinG: 12, fatG: 9)

    private var cache: CacheDelServidor!

    override func setUp() async throws {
        cache = CacheDelServidor(nombre: "tests-comidas-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        cache.borrarTodo()
    }

    /// Lo que contesta el servidor de verdad a un PUT que salió bien.
    static func registrada(_ id: String, _ comida: ComidaEntrada) -> ComidaRegistrada {
        ComidaRegistrada(id: id, eatenAtMs: comida.eatenAtMs, name: comida.name, kcal: comida.kcal,
                         carbsG: comida.carbsG, proteinG: comida.proteinG, fatG: comida.fatG,
                         createdAtMs: 1, updatedAtMs: 1)
    }

    func testSinRedLaComidaQuedaEnDiscoYSubeConElMismoIdCuandoVuelve() async {
        let servicio = PlanDePrueba()
        let cola = ColaDeComidas(servicio: servicio, cache: cache)

        cola.guardar(id: Self.id, Self.avena)
        await cola.subir()

        XCTAssertEqual(cola.pendientes, [.guardar(id: Self.id, comida: Self.avena)], "sin red, sigue en la cola")

        // Se cerró la app: otra cola, sobre el mismo disco, con la red de vuelta.
        servicio.alGuardarComida = { id, comida in .ok(Self.registrada(id, comida)) }
        let reabierta = ColaDeComidas(servicio: servicio, cache: cache)
        XCTAssertEqual(reabierta.pendientes.count, 1)
        await reabierta.subir()

        XCTAssertEqual(servicio.llamadas, ["PUT \(Self.id)", "PUT \(Self.id)"],
                       "reintentar es el mismo PUT: idempotente por id, nunca dos comidas")
        XCTAssertTrue(reabierta.pendientes.isEmpty)
        XCTAssertNil(cache.leer(.comidasPendientes, como: [OperacionDeComida].self))
    }

    func testBorrarSinRedSeEncolaYElGuardadoQueNoSubioSeDescarta() async {
        let servicio = PlanDePrueba()
        let cola = ColaDeComidas(servicio: servicio, cache: cache)

        cola.guardar(id: Self.id, Self.avena)
        cola.borrar(id: Self.id)
        XCTAssertEqual(cola.pendientes, [.borrar(id: Self.id)])

        servicio.alGuardarComida = { id, comida in .ok(Self.registrada(id, comida)) }
        servicio.alBorrarComida = { _ in .ok(SinCuerpo()) }
        await cola.subir()

        XCTAssertEqual(servicio.llamadas, ["DELETE \(Self.id)"], "lo que se borró no se crea antes de borrarlo")
        XCTAssertTrue(cola.pendientes.isEmpty)
    }

    func testSubeEnOrdenYSeDetieneEnLaPrimeraQueNoSale() async {
        let servicio = PlanDePrueba()
        servicio.alGuardarComida = { id, comida in id == "comida-0001" ? .sinRed : .ok(Self.registrada(id, comida)) }
        let cola = ColaDeComidas(servicio: servicio, cache: cache)
        cola.guardar(id: "comida-0001", Self.avena)
        cola.borrar(id: "comida-0002")

        await cola.subir()

        XCTAssertEqual(servicio.llamadas, ["PUT comida-0001"], "nada se adelanta a lo que no salió")
        XCTAssertEqual(cola.pendientes.map(\.id), ["comida-0001", "comida-0002"])
    }

    /// `PUT` sobre una comida borrada en otro teléfono: borrar gana, y no traba la cola.
    func testUnaComidaBorradaEnOtroLadoNoTrabaLaCola() async {
        let servicio = PlanDePrueba()
        servicio.alGuardarComida = { id, comida in
            id == "comida-0001" ? .rechazado(codigo: "not_found", http: 404) : .ok(Self.registrada(id, comida))
        }
        let cola = ColaDeComidas(servicio: servicio, cache: cache)
        cola.guardar(id: "comida-0001", Self.avena)
        cola.guardar(id: "comida-0002", Self.avena)

        await cola.subir()

        XCTAssertEqual(servicio.llamadas, ["PUT comida-0001", "PUT comida-0002"])
        XCTAssertTrue(cola.pendientes.isEmpty)
    }

    /// 🛑 La sesión se cierra con la cola subiendo: lo que queda era de quien se fue.
    func testDespuesDeUnCierreDeSesionNoSigueNiEscribe() async {
        let servicio = PlanDePrueba()
        let compuerta = CompuertaDePrueba()
        servicio.compuerta = compuerta
        servicio.alGuardarComida = { id, comida in .ok(Self.registrada(id, comida)) }
        let cola = ColaDeComidas(servicio: servicio, cache: cache)
        cola.guardar(id: "comida-0001", Self.avena)
        cola.guardar(id: "comida-0002", Self.avena)

        let viaje = Task { await cola.subir() }
        await esperar { servicio.llamadas.count == 1 }
        cache.borrarTodo()
        compuerta.abrir()
        await viaje.value

        XCTAssertEqual(servicio.llamadas.count, 1, "no sube lo de quien se fue")
        XCTAssertNil(cache.leer(.comidasPendientes, como: [OperacionDeComida].self), "ni lo vuelve a escribir")
    }
}
