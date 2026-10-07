import XCTest
@testable import TrainerCore

/// Offline primero (AGENTS.md §6): lo guardado se ve sin red, un pedido que falla no
/// borra lo último bueno, y nada se inventa cuando no hay nada.
final class FuenteDelServidorTests: XCTestCase {

    /// 00:00 del 2026-09-10 en Buenos Aires: el día de las fixturas.
    static let diaDeLasFixturas: Int64 = 1_789_009_200_000
    static let diezDeLaManana: Int64 = diaDeLasFixturas + 10 * 3_600_000
    static let buenosAires = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    private var cache: CacheDelServidor!

    override func setUp() {
        cache = CacheDelServidor(nombre: "tests-cache-\(UUID().uuidString)")
    }

    override func tearDown() {
        cache.borrarTodo()
    }

    private func fuente(_ servicio: PlanDePrueba, ahora: Int64 = diezDeLaManana) -> FuenteDelServidor {
        FuenteDelServidor(servicio: servicio, cache: cache, reloj: { ahora })
    }

    private func servicioConTodo() throws -> PlanDePrueba {
        let servicio = PlanDePrueba()
        servicio.respuestaDelPlan = .ok(try Fixturas.dato("plan"))
        servicio.respuestaDeRutina = .ok(try Fixturas.dato("rutina-del-dia"))
        servicio.respuestaDeNutricion = .ok(try Fixturas.dato("nutricion-del-dia"))
        return servicio
    }

    /// 🛑 El caso que nunca puede terminar en datos de ejemplo: la primera vez, sin red.
    func testSinNadaGuardadoYSinRedNoHayNadaQueMostrar() async {
        let fuente = fuente(PlanDePrueba())

        let alAbrir = fuente.guardado()
        let despues = await fuente.actualizar()

        XCTAssertNil(alAbrir.plan.valor)
        XCTAssertNil(alAbrir.rutina.valor)
        XCTAssertNil(alAbrir.nutricion.valor)
        XCTAssertNil(despues.plan.valor)
        XCTAssertNil(despues.rutina.valor)
        XCTAssertNil(despues.nutricion.valor)
        XCTAssertEqual([despues.plan.problema, despues.rutina.problema, despues.nutricion.problema],
                       [.sinRed, .sinRed, .sinRed])
    }

    func testLoQueLlegoBienSeVeAlVolverAAbrirSinRed() async throws {
        let conRed = await fuente(try servicioConTodo()).actualizar()
        XCTAssertEqual(conRed.plan.valor?.days.count, 71)
        XCTAssertNil(conRed.plan.problema)

        let sinRed = fuente(PlanDePrueba(), ahora: Self.diezDeLaManana + 60_000)
        let alAbrir = sinRed.guardado()
        XCTAssertEqual(alAbrir.plan.valor?.days.count, 71)
        XCTAssertEqual(alAbrir.rutina.valor?.exercises.count, 6)
        XCTAssertEqual(alAbrir.nutricion.valor?.meals.count, 1)
        XCTAssertFalse(alAbrir.plan.desactualizada, "todavía no se le preguntó al servidor")

        let despues = await sinRed.actualizar()
        XCTAssertEqual(despues.plan.valor?.days.count, 71, "un pedido que falla no borra lo último bueno")
        XCTAssertEqual(despues.plan.problema, .sinRed)
        XCTAssertTrue(despues.plan.desactualizada)
        XCTAssertEqual(despues.plan.guardadoEnMs, Self.diezDeLaManana, "se sabe de cuándo es lo que se ve")
    }

    func testLaRutinaYLaNutricionDeAyerNoSeMuestranComoDeHoy() async throws {
        _ = await fuente(try servicioConTodo()).actualizar()

        let manana = fuente(PlanDePrueba(), ahora: Self.diezDeLaManana + 86_400_000).guardado()

        XCTAssertNotNil(manana.plan.valor, "el plan es el bloque entero: sirve igual")
        XCTAssertNil(manana.rutina.valor)
        XCTAssertNil(manana.nutricion.valor)
    }

    /// A las 23:30 de Buenos Aires ya es el día siguiente en UTC: el día es el del perfil.
    func testElDiaSeCuentaEnLaZonaDelPlan() async throws {
        let dia = Self.diaDeLasFixturas
        let casiMedianoche = dia + 23 * 3_600_000 + 30 * 60_000
        XCTAssertEqual(FuenteDelServidor.inicioDelDia(Self.diezDeLaManana, zona: Self.buenosAires), dia)
        XCTAssertEqual(FuenteDelServidor.inicioDelDia(casiMedianoche, zona: Self.buenosAires), dia)

        _ = await fuente(try servicioConTodo()).actualizar()

        XCTAssertNotNil(fuente(PlanDePrueba(), ahora: casiMedianoche).guardado().nutricion.valor)
        XCTAssertNil(fuente(PlanDePrueba(), ahora: dia + 24 * 3_600_000 + 60_000).guardado().nutricion.valor)
    }

    func testCadaProblemaSeDiceComoTal() async {
        let servicio = PlanDePrueba()
        servicio.respuestaDelPlan = .rechazado(codigo: "profile_incomplete", http: 400)
        servicio.respuestaDeRutina = .respuestaRara(http: 502)

        let datos = await fuente(servicio).actualizar()

        XCTAssertEqual(datos.plan.problema, .perfilIncompleto)
        XCTAssertEqual(datos.rutina.problema, .servidor)
        XCTAssertEqual(datos.nutricion.problema, .sinRed)
    }

    /// 🛑 La sesión se cierra con los pedidos en el aire: lo que vuelve es de quien se
    /// fue, y no se escribe ni se muestra.
    func testLoQueVuelveDespuesDeUnCierreDeSesionNoSeEscribe() async throws {
        let servicio = try servicioConTodo()
        let compuerta = CompuertaDePrueba()
        servicio.compuerta = compuerta
        let fuente = fuente(servicio)

        let pedido = Task { await fuente.actualizar() }
        await esperar { servicio.llamadas.count == 3 }
        cache.borrarTodo()
        compuerta.abrir()
        let datos = await pedido.value

        XCTAssertNil(datos.plan.valor)
        XCTAssertNil(cache.leer(.plan, como: Plan.self))
        XCTAssertNil(cache.leer(.rutina, como: RutinaDelDia.self))
        XCTAssertNil(cache.leer(.nutricion, como: DiaNutricional.self))
    }
}

/// Dónde y cómo queda en disco lo que mandó el servidor.
final class CacheDelServidorTests: XCTestCase {

    private var cache: CacheDelServidor!

    override func setUp() {
        cache = CacheDelServidor(nombre: "tests-cache-\(UUID().uuidString)")
    }

    override func tearDown() {
        cache.borrarTodo()
    }

    /// 🛑 AGENTS.md §8 y §12.1: dato de salud, cifrado en disco y fuera del backup.
    func testEscribeConDataProtectionYFueraDelBackup() throws {
        XCTAssertTrue(CacheDelServidor.opcionesDeEscritura.contains(.completeFileProtectionUntilFirstUserAuthentication))

        XCTAssertTrue(cache.guardar(["kcal": 2750], en: .nutricion, ahoraMs: 5))

        let carpeta = try XCTUnwrap(cache.carpeta)
        XCTAssertEqual(try carpeta.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertEqual(cache.leer(.nutricion, como: [String: Int].self),
                       Guardado(valor: ["kcal": 2750], guardadoEnMs: 5))
    }

    func testBorrarTodoSeLlevaCadaArchivo() throws {
        for clave in CacheDelServidor.Clave.allCases {
            XCTAssertTrue(cache.guardar("algo", en: clave, ahoraMs: 1))
        }

        cache.borrarTodo()

        for clave in CacheDelServidor.Clave.allCases {
            XCTAssertNil(cache.leer(clave, como: String.self), "\(clave) quedó en disco")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(cache.carpeta).path))
    }

    func testLoQueSalioAntesDeBorrarTodoNoSeEscribe() {
        let generacion = cache.generacion

        cache.borrarTodo()

        XCTAssertFalse(cache.guardar("de quien se fue", en: .plan, ahoraMs: 1, generacion: generacion))
        XCTAssertNil(cache.leer(.plan, como: String.self))
        XCTAssertTrue(cache.guardar("de quien entró", en: .plan, ahoraMs: 2, generacion: cache.generacion))
    }
}
