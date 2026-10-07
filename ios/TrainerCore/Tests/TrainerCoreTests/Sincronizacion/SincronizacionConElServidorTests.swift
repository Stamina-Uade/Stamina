import XCTest
@testable import TrainerCore

/// Las series del gimnasio contra el servidor (decisión 0006): primero se manda lo
/// pendiente, después se trae, y sin red nada se pierde.
@MainActor
final class SincronizacionConElServidorTests: XCTestCase {

    static let hoy = "gym-2026-09-10"
    static let llegada = 1_789_033_543_346

    private var almacen: AlmacenDeSeries!
    private var claves = 0

    override func setUp() async throws {
        almacen = AlmacenDeSeries(nombre: "tests-servidor-\(UUID().uuidString).json")
        claves = 0
    }

    override func tearDown() async throws {
        almacen.borrar()
    }

    private func sincronizador() -> SincronizadorDeSesion {
        SincronizadorDeSesion(dispositivo: .telefono, almacen: almacen)
    }

    private func sincronizacion(_ servicio: PlanDePrueba, _ sincronizador: SincronizadorDeSesion,
                                generacion: @escaping () -> Int = { 0 }) -> SincronizacionConElServidor {
        SincronizacionConElServidor(servicio: servicio, sincronizador: sincronizador,
                                    sesionDeHoy: { Self.hoy }, generacion: generacion,
                                    nuevaClave: { [unowned self] in
                                        self.claves += 1
                                        return "intento-\(self.claves)"
                                    })
    }

    private func clave(_ ejercicio: String = "sentadilla", _ numero: Int = 1) -> ClaveDeSerie {
        ClaveDeSerie(sesion: Self.hoy, ejercicio: ejercicio, numero: numero)
    }

    /// Lo que devuelve el servidor de verdad: fusiona lo que llega —gana lo último en
    /// llegar— y contesta la sesión entera, cada serie con su hora de llegada.
    private final class ServidorQueFusiona: @unchecked Sendable {
        var guardadas: [String: SerieDeGimnasio] = [:]
        var llegada = SincronizacionConElServidorTests.llegada

        func recibir(_ lote: [SerieDeGimnasioEntrada], sesion: String) -> SesionDeGimnasio {
            llegada += 1
            for serie in lote {
                let previa = guardadas["\(serie.exerciseId)#\(serie.number)"]
                guardadas["\(serie.exerciseId)#\(serie.number)"] = SerieDeGimnasio(
                    exerciseId: serie.exerciseId, number: serie.number, done: serie.done || (previa?.done ?? false),
                    reps: serie.reps, weightG: serie.weightG, skipped: serie.skipped, isExtra: serie.isExtra,
                    recordedAtMs: serie.recordedAtMs, receivedAtMs: Int64(llegada), device: serie.device)
            }
            return sesionEntera(sesion)
        }

        func sesionEntera(_ sesion: String) -> SesionDeGimnasio {
            SesionDeGimnasio(sessionId: sesion, updatedAtMs: Int64(llegada),
                             sets: guardadas.values.sorted { ($0.exerciseId, $0.number) < ($1.exerciseId, $1.number) })
        }
    }

    // MARK: - El orden

    /// 🛑 El test de la regla 1. El servidor tiene la serie 1 con 10 repeticiones, ya
    /// recibida; en el teléfono, sin mandar, la persona la corrigió a 8. Traer primero
    /// le daría la victoria a lo recibido, y la corrección se perdería sin avisar.
    func testPrimeroMandaLoPendienteYDespuesTrae() async throws {
        let servidor = ServidorQueFusiona()
        _ = servidor.recibir([SerieDeGimnasioEntrada(exerciseId: "sentadilla", number: 1, done: true, reps: 10,
                                                     weightG: 60_000, skipped: false, isExtra: false,
                                                     recordedAtMs: 1, device: .reloj)], sesion: Self.hoy)
        let servicio = PlanDePrueba()
        servicio.alSincronizar = { sesion, lote, _ in .ok(servidor.recibir(lote, sesion: sesion)) }
        servicio.alPedirSesion = { sesion in .ok(servidor.sesionEntera(sesion)) }
        let sincronizador = sincronizador()
        sincronizador.registrar(clave: clave(), hecha: true, repeticiones: 8, pesoGramos: 60_000)

        await sincronizacion(servicio, sincronizador).sincronizar()

        XCTAssertEqual(servicio.llamadas.first, "POST \(Self.hoy) intento-1", "lo pendiente sale antes que nada")
        let serie = try XCTUnwrap(sincronizador.series.first { $0.clave == clave() })
        XCTAssertEqual(serie.repeticiones, 8, "la corrección que no se había mandado no se pierde")
        XCTAssertNotNil(serie.recibidaEnServidorMs, "y ahora ya llegó")
        XCTAssertEqual(servidor.guardadas["sentadilla#1"]?.reps, 8)
    }

    func testLaRespuestaEsLaSesionEnteraYSeFusionaConLoDelOtroDispositivo() async throws {
        let servidor = ServidorQueFusiona()
        _ = servidor.recibir([SerieDeGimnasioEntrada(exerciseId: "remo", number: 1, done: true, reps: 12,
                                                     skipped: false, isExtra: false, recordedAtMs: 1,
                                                     device: .reloj)], sesion: Self.hoy)
        let servicio = PlanDePrueba()
        servicio.alSincronizar = { sesion, lote, _ in .ok(servidor.recibir(lote, sesion: sesion)) }
        let sincronizador = sincronizador()
        sincronizador.registrar(clave: clave(), hecha: true, repeticiones: 8, pesoGramos: 60_000)

        await sincronizacion(servicio, sincronizador).sincronizar()

        XCTAssertEqual(sincronizador.series.map(\.clave.ejercicio), ["remo", "sentadilla"])
        XCTAssertTrue(sincronizador.series.allSatisfy { $0.recibidaEnServidorMs != nil })
        XCTAssertEqual(almacen.leer().count, 2, "lo fusionado queda en disco")
        let enviadas = servicio.llamadas.filter { $0.hasPrefix("POST") }
        XCTAssertEqual(enviadas.count, 1)
        XCTAssertFalse(servicio.llamadas.contains { $0.hasPrefix("GET") },
                       "con algo pendiente, la respuesta del POST ya es la sesión entera")
    }

    // MARK: - Sin red

    func testSinRedLoPendienteSeQuedaYSubeConLaMismaClaveCuandoVuelve() async throws {
        let servidor = ServidorQueFusiona()
        let servicio = PlanDePrueba()
        let sincronizador = sincronizador()
        sincronizador.registrar(clave: clave(), hecha: true, repeticiones: 8, pesoGramos: 60_000)
        let sincronizacion = sincronizacion(servicio, sincronizador)

        await sincronizacion.sincronizar()

        XCTAssertEqual(servicio.llamadas, ["POST \(Self.hoy) intento-1"], "si mandar falla, no se trae nada")
        XCTAssertNil(sincronizador.series.first?.recibidaEnServidorMs, "sigue pendiente")
        XCTAssertEqual(almacen.leer().first?.repeticiones, 8, "y en disco: sobrevive a cerrar la app")

        servicio.alSincronizar = { sesion, lote, _ in .ok(servidor.recibir(lote, sesion: sesion)) }
        await sincronizacion.sincronizar()

        XCTAssertEqual(servicio.llamadas.last, "POST \(Self.hoy) intento-1",
                       "el reintento del mismo lote es el mismo intento: la misma clave")
        XCTAssertNotNil(sincronizador.series.first?.recibidaEnServidorMs)
    }

    func testAlVolverAAbrirLaAppLoPendienteTambienSube() async throws {
        let servidor = ServidorQueFusiona()
        let servicio = PlanDePrueba()
        sincronizador().registrar(clave: clave(), hecha: true, repeticiones: 8, pesoGramos: 60_000)

        // Otro proceso: el sincronizador arranca de lo que quedó en disco.
        servicio.alSincronizar = { sesion, lote, _ in .ok(servidor.recibir(lote, sesion: sesion)) }
        let reabierto = sincronizador()
        await sincronizacion(servicio, reabierto).sincronizar()

        XCTAssertEqual(servidor.guardadas["sentadilla#1"]?.reps, 8)
        XCTAssertNotNil(reabierto.series.first?.recibidaEnServidorMs)
    }

    func testUnLoteQueCambioEsOtroIntentoConOtraClave() async {
        let servicio = PlanDePrueba()
        let sincronizador = sincronizador()
        let sincronizacion = sincronizacion(servicio, sincronizador)
        sincronizador.registrar(clave: clave("sentadilla", 1), hecha: true, repeticiones: 8, pesoGramos: 60_000)
        await sincronizacion.sincronizar()

        sincronizador.registrar(clave: clave("sentadilla", 2), hecha: true, repeticiones: 8, pesoGramos: 60_000)
        await sincronizacion.sincronizar()

        XCTAssertEqual(servicio.llamadas, ["POST \(Self.hoy) intento-1", "POST \(Self.hoy) intento-2"],
                       "la misma clave con otro cuerpo sería un 409")
    }

    func testUn409TiraLaClave() async {
        let servicio = PlanDePrueba()
        servicio.alSincronizar = { _, _, _ in .rechazado(codigo: "conflict", http: 409) }
        let sincronizador = sincronizador()
        sincronizador.registrar(clave: clave(), hecha: true, repeticiones: 8, pesoGramos: 60_000)
        let sincronizacion = sincronizacion(servicio, sincronizador)

        await sincronizacion.sincronizar()
        await sincronizacion.sincronizar()

        XCTAssertEqual(servicio.llamadas, ["POST \(Self.hoy) intento-1", "POST \(Self.hoy) intento-2"])
        XCTAssertNil(sincronizador.series.first?.recibidaEnServidorMs)
    }

    // MARK: - Traer

    func testSinNadaPendienteTraeLaSesionDeHoy() async throws {
        let servidor = ServidorQueFusiona()
        _ = servidor.recibir([SerieDeGimnasioEntrada(exerciseId: "remo", number: 1, done: true, reps: 12,
                                                     skipped: false, isExtra: false, recordedAtMs: 1,
                                                     device: .telefono)], sesion: Self.hoy)
        let servicio = PlanDePrueba()
        servicio.alPedirSesion = { sesion in .ok(servidor.sesionEntera(sesion)) }
        let sincronizador = sincronizador()

        await sincronizacion(servicio, sincronizador).sincronizar()

        XCTAssertEqual(servicio.llamadas, ["GET \(Self.hoy)"])
        XCTAssertEqual(sincronizador.series.first?.repeticiones, 12, "lo registrado en otro teléfono llega")
    }

    func testUnaSesionQueTodaviaNoExisteNoEsUnError() async {
        let servicio = PlanDePrueba()
        servicio.alPedirSesion = { _ in .rechazado(codigo: "not_found", http: 404) }
        let sincronizador = sincronizador()

        await sincronizacion(servicio, sincronizador).sincronizar()

        XCTAssertTrue(sincronizador.series.isEmpty)
    }

    // MARK: - Lo que cambia en el medio

    /// Regla 4: la persona corrige la serie mientras el pedido viaja. La respuesta trae
    /// la versión vieja, ya recibida, que le ganaría a la corrección.
    func testLoQueCambiaMientrasViajaElPedidoSigueParaElProximo() async throws {
        let servidor = ServidorQueFusiona()
        let servicio = PlanDePrueba()
        let compuerta = CompuertaDePrueba()
        servicio.alSincronizar = { sesion, lote, _ in .ok(servidor.recibir(lote, sesion: sesion)) }
        servicio.compuerta = compuerta
        let sincronizador = sincronizador()
        sincronizador.registrar(clave: clave(), hecha: true, repeticiones: 8, pesoGramos: 60_000)
        let sincronizacion = sincronizacion(servicio, sincronizador)

        let viaje = Task { await sincronizacion.sincronizar() }
        await esperar { servicio.llamadas.count == 1 }
        sincronizador.registrar(clave: clave(), hecha: true, repeticiones: 6, pesoGramos: 60_000)
        compuerta.abrir()
        await viaje.value

        let serie = try XCTUnwrap(sincronizador.series.first)
        XCTAssertEqual(serie.repeticiones, 6, "la corrección hecha durante el viaje no se pisa")
        XCTAssertNil(serie.recibidaEnServidorMs, "y sigue pendiente")

        await sincronizacion.sincronizar()
        XCTAssertEqual(servidor.guardadas["sentadilla#1"]?.reps, 6)
    }

    /// Una serie que el contrato no acepta haría rechazar el lote entero.
    func testUnaSerieFueraDelContratoNoTrabaALasDemas() async throws {
        let servidor = ServidorQueFusiona()
        let servicio = PlanDePrueba()
        var enviadas: [SerieDeGimnasioEntrada] = []
        servicio.alSincronizar = { sesion, lote, _ in
            enviadas = lote
            return .ok(servidor.recibir(lote, sesion: sesion))
        }
        let sincronizador = sincronizador()
        sincronizador.registrar(clave: clave("sentadilla", 51), hecha: true, repeticiones: 8, pesoGramos: nil)
        sincronizador.registrar(clave: clave("sentadilla", 1), hecha: true, repeticiones: 8, pesoGramos: nil)

        await sincronizacion(servicio, sincronizador).sincronizar()

        XCTAssertEqual(enviadas.map(\.number), [1])
        XCTAssertNil(sincronizador.series.first { $0.clave.numero == 51 }?.recibidaEnServidorMs,
                     "la que no cumple se queda en el teléfono, sin perderse")
    }

    /// 🛑 La sesión se cierra con el pedido en el aire: lo que vuelve es de quien se fue.
    func testLoQueVuelveDespuesDeUnCierreDeSesionNoSeEscribe() async {
        let servidor = ServidorQueFusiona()
        let servicio = PlanDePrueba()
        let compuerta = CompuertaDePrueba()
        servicio.alSincronizar = { sesion, lote, _ in .ok(servidor.recibir(lote, sesion: sesion)) }
        servicio.compuerta = compuerta
        var generacion = 0
        let sincronizador = sincronizador()
        sincronizador.registrar(clave: clave(), hecha: true, repeticiones: 8, pesoGramos: nil)

        let viaje = Task { await sincronizacion(servicio, sincronizador, generacion: { generacion }).sincronizar() }
        await esperar { servicio.llamadas.count == 1 }
        generacion += 1
        almacen.borrar()
        compuerta.abrir()
        await viaje.value

        XCTAssertTrue(almacen.leer().isEmpty, "no se vuelve a escribir en disco")
    }
}

/// Una escritura de este dispositivo sobre una serie que ya había llegado al servidor.
@MainActor
final class CorreccionDeUnaSerieRecibidaTests: XCTestCase {

    func testCorregirUnaSerieQueYaLlegoLaDejaPendienteConLoNuevo() {
        let almacen = AlmacenDeSeries(nombre: "tests-correccion-\(UUID().uuidString).json")
        defer { almacen.borrar() }
        let sincronizador = SincronizadorDeSesion(dispositivo: .telefono, almacen: almacen)
        let clave = ClaveDeSerie(sesion: "gym-2026-09-10", ejercicio: "sentadilla", numero: 1)
        sincronizador.fusionar([SerieRegistrada(clave: clave, hecha: true, repeticiones: 10, pesoGramos: 60_000,
                                                recibidaEnServidorMs: 1_000, registradaLocalMs: 1,
                                                dispositivo: .reloj)])

        sincronizador.registrar(clave: clave, hecha: false, repeticiones: 8, pesoGramos: 62_500)

        let serie = sincronizador.series.first
        XCTAssertEqual(serie?.repeticiones, 8, "la corrección se ve, no la pisa lo que ya había llegado")
        XCTAssertEqual(serie?.pesoGramos, 62_500)
        XCTAssertNil(serie?.recibidaEnServidorMs, "queda pendiente, para que el servidor la reciba")
        XCTAssertEqual(serie?.hecha, true, "hecha sigue siendo monotónica")
        XCTAssertEqual(serie?.dispositivo, .telefono)
        XCTAssertEqual(sincronizador.series.count, 1)
    }
}
