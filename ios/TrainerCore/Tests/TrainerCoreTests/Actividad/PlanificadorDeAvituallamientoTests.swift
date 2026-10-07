import XCTest
@testable import TrainerCore

final class PlanificadorDeAvituallamientoTests: XCTestCase {
    func testSinInsumosNuncaAvisa() {
        var plan = PlanificadorDeAvituallamiento()
        for minuto in stride(from: 0, through: 240, by: 5) {
            XCTAssertNil(plan.siguiente(segundos: minuto * 60,
                                         insumos: InsumosDeSalida(geles: 0, sales: 0, aguaMl: 0)))
        }
    }

    func testNoAvisaDeAlgoQueNoLlevaNiRepiteLoConsumido() {
        var plan = PlanificadorDeAvituallamiento()
        let insumos = InsumosDeSalida(geles: 1, sales: 0, aguaMl: 0)
        XCTAssertNil(plan.siguiente(segundos: 2_699, insumos: insumos))
        XCTAssertEqual(plan.siguiente(segundos: 2_700, insumos: insumos), .gel)
        XCTAssertNil(plan.siguiente(segundos: 2_701, insumos: insumos))
        XCTAssertNil(plan.siguiente(segundos: 7_200, insumos: insumos))
    }

    func testAguaSeLimitaALaCantidadDeclarada() {
        var plan = PlanificadorDeAvituallamiento()
        let insumos = InsumosDeSalida(geles: 0, sales: 0, aguaMl: 400)
        XCTAssertEqual(plan.siguiente(segundos: 1_200, insumos: insumos), .agua)
        XCTAssertEqual(plan.siguiente(segundos: 2_400, insumos: insumos), .agua)
        XCTAssertNil(plan.siguiente(segundos: 3_600, insumos: insumos))
    }

    func testNoInterrumpeNatacionYAdaptaElIntervaloAlPasarACiclismo() {
        var plan = PlanificadorDeAvituallamiento()
        let insumos = InsumosDeSalida(geles: 1, sales: 0, aguaMl: 200)
        XCTAssertNil(plan.siguiente(segundos: 2_400, insumos: insumos, deporte: .natacion))
        XCTAssertEqual(plan.siguiente(segundos: 2_400, insumos: insumos, deporte: .ciclismo), .agua)
        XCTAssertEqual(plan.siguiente(segundos: 2_580, insumos: insumos, deporte: .ciclismo), .gel)
    }
}
