import XCTest
@testable import TrainerCore

/// El motor de la 1.1.0 contra respuestas DE VERDAD del servidor.
///
/// Las fixturas de `Fixturas/` se capturaron de staging el 2026-09-10, con el
/// contrato 1.1.0. Un JSON escrito a mano prueba que el decodificador lee lo que
/// quien escribió el test cree que manda el servidor; éstas prueban lo que manda.
final class ApiDelPlanTests: XCTestCase {

    private func api(_ servidor: ServidorDePrueba) -> ApiTrainer {
        let cliente = servidor.cliente()
        return ApiTrainer(cliente: cliente,
                          renovador: RenovadorDeSesion(cliente: cliente,
                                                       almacen: AlmacenEnMemoria(Fixtura.sesion(1)),
                                                       reloj: { Fixtura.ahora }))
    }

    /// Un servidor que contesta siempre la misma fixtura.
    private func servidor(_ fixtura: String, http: Int = 200) -> ServidorDePrueba {
        let cuerpo = Fixturas.texto(fixtura)
        return ServidorDePrueba { _, _ in .cruda(cuerpo, http: http) }
    }

    // MARK: - Plan

    func testElPlanSeLeeEnteroDeLaRespuestaDeVerdad() async throws {
        let servidor = servidor("plan")

        let r = await api(servidor).plan()

        let plan = try XCTUnwrap(r.valor)
        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.metodo, "GET")
        XCTAssertEqual(pedido.ruta, "/v1/plan")
        XCTAssertEqual(pedido.encabezado("Authorization"), "Bearer acceso-1")
        XCTAssertEqual(plan.goal, .mediaMaraton)
        XCTAssertEqual(plan.timezone, "America/Argentina/Buenos_Aires")
        XCTAssertEqual(plan.totalWeeks, 11)
        XCTAssertEqual(plan.phases.map(\.phase), [.base, .construccion, .pico, .afinamiento, .carrera])
        XCTAssertEqual(plan.weeks.count, 11)
        XCTAssertEqual(plan.days.count, 71)

        let primero = try XCTUnwrap(plan.days.first)
        XCTAssertEqual(primero.type, .suave)
        XCTAssertEqual(primero.title, "Running suave (51 min)")
        XCTAssertEqual(primero.zone, .z2)
        XCTAssertEqual(primero.fueling?.gels, 1)
        XCTAssertEqual(primero.reasons.count, 2)

        // Un descanso no trae zona, ni distancia, ni avituallamiento: son opcionales
        // de verdad, y un decodificador que los exigiera tiraría el plan entero.
        let descanso = try XCTUnwrap(plan.days.first { $0.type == .descanso })
        XCTAssertNil(descanso.zone)
        XCTAssertNil(descanso.distanceM)
        XCTAssertNil(descanso.fueling)
        XCTAssertNil(descanso.scheduledMinuteOfDay)
    }

    /// docs/API.md §2: 400 `profile_incomplete`. El Home lo convierte en el aviso de
    /// completar el perfil, así que el código tiene que llegar tal cual.
    func testUnPerfilIncompletoLlegaConSuCodigo() async {
        let r = await api(servidor("error-profile-incomplete", http: 400)).plan()

        XCTAssertEqual(r, .rechazado(codigo: "profile_incomplete", http: 400))
    }

    // MARK: - Rutina

    func testLaRutinaPideElDiaYTraeLaPrescripcionSeriePorSerie() async throws {
        let servidor = servidor("rutina-del-dia")

        let r = await api(servidor).rutina(delDia: 1_789_033_541_989)

        let rutina = try XCTUnwrap(r.valor)
        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.ruta, "/v1/plan/routine")
        XCTAssertEqual(pedido.consulta["date_ms"], "1789033541989")
        XCTAssertEqual(rutina.sessionId, "gym-2026-09-10")
        XCTAssertEqual(rutina.exercises.count, 6)

        let primero = try XCTUnwrap(rutina.exercises.first)
        XCTAssertEqual(primero.exerciseId, "estocada-deficit")
        XCTAssertEqual(primero.name, "Zancada con déficit")
        XCTAssertEqual(primero.sets.map(\.reps), [10, 10, 10])
        XCTAssertTrue(primero.sets.allSatisfy { $0.weightG == nil }, "el motor no prescribe carga")
        XCTAssertEqual(primero.restS, 75)
        XCTAssertTrue(primero.previousSets.isEmpty)

        let plancha = try XCTUnwrap(rutina.exercises.first { $0.unit == "tiempo" })
        XCTAssertEqual(plancha.sets.first?.reps, 40, "con `tiempo`, las repeticiones son segundos")
    }

    func testLaColumnaPreviaTraeLoQueSeHizoLaVezAnterior() async throws {
        let r = await api(servidor("rutina-con-series-previas")).rutina(delDia: 1_789_033_541_989)

        let previas = try XCTUnwrap(r.valor?.exercises.first?.previousSets)
        XCTAssertEqual(previas.map(\.number), [1, 2])
        XCTAssertEqual(previas.map(\.reps), [10, 8])
        XCTAssertEqual(previas.map(\.weightG), [12_000, nil], "sin peso es peso corporal")
        XCTAssertEqual(previas.map(\.skipped), [false, false])
    }

    // MARK: - Nutrición

    func testLaNutricionDelDiaTraeLosObjetivosYLoComido() async throws {
        let servidor = servidor("nutricion-del-dia")

        let r = await api(servidor).nutricion(delDia: 1_789_033_541_989)

        let dia = try XCTUnwrap(r.valor)
        XCTAssertEqual(servidor.pedidos.first?.ruta, "/v1/nutrition/day")
        XCTAssertEqual(servidor.pedidos.first?.consulta["date_ms"], "1789033541989")
        let objetivos = try XCTUnwrap(dia.targets)
        XCTAssertEqual(objetivos.kcal, 2750)
        XCTAssertEqual(objetivos.waterMl, 3132)
        XCTAssertEqual(objetivos.dayLoad, .baja)
        XCTAssertTrue(objetivos.provisional)
        XCTAssertNil(dia.unavailableReason)
        XCTAssertEqual(dia.consumed.kcal, 420)
        XCTAssertEqual(dia.meals.map(\.name), ["Avena con banana"])
    }

    /// 🛑 AGENTS.md §9.2: sin objetivos viene el MOTIVO, y ningún número.
    func testSinObjetivosVieneElMotivoYNingunNumero() async throws {
        let r = await api(servidor("nutricion-sin-objetivos")).nutricion(delDia: 1_789_033_541_989)

        let dia = try XCTUnwrap(r.valor)
        XCTAssertNil(dia.targets)
        XCTAssertEqual(dia.unavailableReason, .faltaEmbarazoOLactancia)
        XCTAssertEqual(dia.meals.count, 1, "lo comido se muestra igual")
    }

    func testLosObjetivosDeUnaMujerSeLeenIgual() async throws {
        let r = await api(servidor("nutricion-con-objetivos-mujer")).nutricion(delDia: 1_789_033_541_989)

        let objetivos = try XCTUnwrap(r.valor?.targets)
        XCTAssertEqual(objetivos.kcal, 2526)
        XCTAssertEqual(objetivos.fatG, 70)
    }

    // MARK: - Comidas

    func testGuardarUnaComidaEsUnPutPorSuIdConElCuerpoDelContrato() async throws {
        let servidor = servidor("comida")
        let id = "063349d2-0a4b-45c5-9cf6-c54d692ea7ad"
        let entrada = ComidaEntrada(eatenAtMs: 1_789_033_542_979, name: "Avena con banana",
                                    kcal: 420, carbsG: 72, proteinG: 12, fatG: 9)

        let r = await api(servidor).guardarComida(id: id, entrada)

        let comida = try XCTUnwrap(r.valor)
        XCTAssertEqual(comida.id, id)
        XCTAssertEqual(comida.eatenAtMs, 1_789_033_542_979)
        XCTAssertEqual(comida.updatedAtMs, 1_789_033_544_452)
        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.metodo, "PUT")
        XCTAssertEqual(pedido.ruta, "/v1/meals/\(id)")
        XCTAssertNil(pedido.encabezado("Idempotency-Key"), "el PUT es idempotente por id")
        let cuerpo = try XCTUnwrap(pedido.json)
        XCTAssertEqual(Set(cuerpo.keys), ["eaten_at_ms", "name", "kcal", "carbs_g", "protein_g", "fat_g"])
        XCTAssertEqual(cuerpo["name"] as? String, "Avena con banana")
    }

    func testBorrarUnaComidaEsUnDeleteQueContestaSinCuerpo() async throws {
        let servidor = ServidorDePrueba { _, _ in .sinContenido }

        let r = await api(servidor).borrarComida(id: "063349d2-0a4b-45c5-9cf6-c54d692ea7ad")

        XCTAssertEqual(r, .ok(SinCuerpo()))
        XCTAssertEqual(servidor.pedidos.first?.metodo, "DELETE")
        XCTAssertEqual(servidor.pedidos.first?.ruta, "/v1/meals/063349d2-0a4b-45c5-9cf6-c54d692ea7ad")
    }

    /// 🛑 Un id que cambiaría la ruta no sale del teléfono.
    func testUnIdQueCambiariaLaRutaNoSeManda() async {
        let servidor = ServidorDePrueba { _, _ in .sinContenido }
        let api = api(servidor)

        let borrar = await api.borrarComida(id: "../me")
        let sesion = await api.sesionDeGimnasio("gym/2026")

        XCTAssertEqual(borrar, .respuestaRara(http: 0))
        XCTAssertEqual(sesion, .respuestaRara(http: 0))
        XCTAssertTrue(servidor.pedidos.isEmpty)
    }

    // MARK: - Gimnasio

    func testSincronizarMandaElLoteConSuClaveYDevuelveLaSesionEntera() async throws {
        let servidor = servidor("series-sincronizadas")
        let lote = [
            SerieDeGimnasioEntrada(exerciseId: "estocada-deficit", number: 1, done: true, reps: 10,
                                   weightG: 12_000, skipped: false, isExtra: false,
                                   recordedAtMs: 1_789_033_482_979, device: .telefono),
            SerieDeGimnasioEntrada(exerciseId: "estocada-deficit", number: 2, done: false, reps: 8,
                                   skipped: false, isExtra: false,
                                   recordedAtMs: 1_789_033_542_979, device: .reloj),
        ]

        let r = await api(servidor).sincronizarSeries(sesion: "gym-2026-09-10", lote,
                                                      claveDeIdempotencia: "intento-3")

        let sesion = try XCTUnwrap(r.valor)
        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.metodo, "POST")
        XCTAssertEqual(pedido.ruta, "/v1/gym/sessions/gym-2026-09-10/sets")
        XCTAssertEqual(pedido.encabezado("Idempotency-Key"), "intento-3")
        let enviadas = try XCTUnwrap(pedido.json?["sets"] as? [[String: Any]])
        XCTAssertEqual(pedido.json?.count, 1, "el cuerpo es `{sets: [...]}` y nada más")
        XCTAssertEqual(enviadas.count, 2)
        XCTAssertEqual(Set(enviadas[0].keys), ["exercise_id", "number", "done", "reps", "weight_g", "skipped",
                                               "is_extra", "recorded_at_ms", "device"])
        XCTAssertNil(enviadas[1]["weight_g"], "sin el campo es peso corporal: no viaja un null")
        XCTAssertEqual(enviadas[1]["device"] as? String, "reloj")

        XCTAssertEqual(sesion.sessionId, "gym-2026-09-10")
        XCTAssertEqual(sesion.dateMs, 1_789_009_200_000)
        XCTAssertEqual(sesion.sets.map(\.receivedAtMs), [1_789_033_543_346, 1_789_033_543_346])
        XCTAssertEqual(sesion.sets.map(\.device), [.telefono, .reloj])
        XCTAssertEqual(sesion.sets.map(\.weightG), [12_000, nil])
    }

    func testLaSesionDeGimnasioSeLeeConSusSeries() async throws {
        let servidor = servidor("sesion-de-gimnasio")

        let r = await api(servidor).sesionDeGimnasio("gym-2026-09-10")

        let sesion = try XCTUnwrap(r.valor)
        XCTAssertEqual(servidor.pedidos.first?.metodo, "GET")
        XCTAssertEqual(servidor.pedidos.first?.ruta, "/v1/gym/sessions/gym-2026-09-10")
        XCTAssertEqual(sesion.sets.count, 2)
        XCTAssertEqual(sesion.updatedAtMs, 1_789_033_543_346)
    }

    /// Una sesión que todavía no tiene series no existe del otro lado.
    func testUnaSesionQueNoExisteEsNotFound() async {
        let r = await api(servidor("error-not-found", http: 404)).sesionDeGimnasio("gym-2026-09-11")

        XCTAssertEqual(r, .rechazado(codigo: "not_found", http: 404))
    }

    func testElHistorialDeSesionesEsUnaPagina() async throws {
        let servidor = servidor("sesiones-de-gimnasio")

        let r = await api(servidor).sesionesDeGimnasio(limite: 20, cursor: nil)

        let pagina = try XCTUnwrap(r.valor)
        XCTAssertEqual(servidor.pedidos.first?.ruta, "/v1/gym/sessions")
        XCTAssertEqual(servidor.pedidos.first?.consulta, ["limit": "20"])
        XCTAssertEqual(pagina.elementos.map(\.sessionId), ["gym-2026-09-10"])
        XCTAssertEqual(pagina.elementos.first?.setsDone, 1)
        XCTAssertFalse(pagina.paginacion.hasMore)
        XCTAssertNil(pagina.paginacion.nextCursor)
    }

    // MARK: - Catálogo

    /// El cursor es opaco (docs/API.md §1): vuelve tal cual vino, sin interpretarlo.
    func testElCatalogoSePaginaDevolviendoElCursorTalCual() async throws {
        let paginas = [Fixturas.texto("ejercicios-pagina-1"), Fixturas.texto("ejercicios-pagina-2")]
        let servidor = ServidorDePrueba { _, recibidos in .cruda(paginas[min(recibidos.count, 2) - 1], http: 200) }
        let api = api(servidor)

        let r1 = await api.ejercicios(limite: 3, cursor: nil)
        let primera = try XCTUnwrap(r1.valor)
        let cursor = try XCTUnwrap(primera.paginacion.nextCursor)
        let r2 = await api.ejercicios(limite: 3, cursor: cursor)
        let segunda = try XCTUnwrap(r2.valor)

        XCTAssertEqual(primera.elementos.map(\.id),
                       ["abduccion-cadera-maquina", "aduccion-cadera-maquina", "aperturas-mancuernas"])
        XCTAssertEqual(primera.elementos.first?.muscles.first?.role, .principal)
        XCTAssertTrue(primera.paginacion.hasMore)
        XCTAssertEqual(segunda.elementos.count, 3)
        XCTAssertEqual(servidor.pedidos.map(\.ruta), ["/v1/exercises", "/v1/exercises"])
        XCTAssertEqual(servidor.pedidos[0].consulta, ["limit": "3"])
        XCTAssertEqual(servidor.pedidos[1].consulta, ["limit": "3", "cursor": "WyJhcGVydHVyYXMtbWFuY3Vlcm5hcyJd"])
    }

    func testElDiccionarioDelCatalogoSaleDelServidor() async throws {
        let servidor = ServidorDePrueba { _, _ in
            .datos(#"{"patterns":[{"id":"sentadilla","name":"Sentadilla"}],"equipment":[],"muscles":[{"id":"cuadriceps","name":"Cuádriceps"}],"joints":[]}"#)
        }

        let resultado = await api(servidor).diccionarioDeEjercicios()

        let diccionario = try XCTUnwrap(resultado.valor)
        XCTAssertEqual(servidor.pedidos.first?.ruta, "/v1/exercises/dictionary")
        XCTAssertEqual(diccionario.patterns.first?.name, "Sentadilla")
        XCTAssertEqual(diccionario.muscles.first?.id, "cuadriceps")
    }
}

/// Las respuestas capturadas del servidor de verdad (ver el encabezado de
/// `ApiDelPlanTests`).
enum Fixturas {
    static func texto(_ nombre: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        guard let url = Bundle.module.url(forResource: nombre, withExtension: "json", subdirectory: "Fixturas"),
              let texto = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("falta la fixtura \(nombre).json", file: file, line: line)
            return ""
        }
        return texto
    }

    /// La fixtura decodificada con el mismo sobre que usa el cliente.
    static func dato<T: Decodable>(_ nombre: String, como tipo: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(SobreDeFixtura<T>.self, from: Data(texto(nombre).utf8)).data
    }
}

private struct SobreDeFixtura<Dato: Decodable>: Decodable {
    let data: Dato
}
