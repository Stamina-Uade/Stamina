import XCTest
@testable import TrainerCore

final class FormatoDeDistanciaTests: XCTestCase {
    func testLaDistanciaUsaLaUnidadElegidaSinCambiarLosMetrosGuardados() {
        XCTAssertEqual(Formato.distancia(1_000, unidades: .metrico), "1 km")
        XCTAssertEqual(Formato.distancia(1_609, unidades: .imperial, decimales: 0), "1 mi")
        XCTAssertEqual(Formato.unidadDeDistancia(.metrico), "km")
        XCTAssertEqual(Formato.unidadDeDistancia(.imperial), "mi")
    }

    func testElRitmoImperialConvierteDeMinutosPorKilometroAMinutosPorMilla() {
        XCTAssertEqual(Formato.ritmo(segundosPorKm: 300, unidades: .metrico), "5:00")
        XCTAssertEqual(Formato.ritmo(segundosPorKm: 300, unidades: .imperial), "8:03")
    }

    func testLaVelocidadUsaLaUnidadElegida() {
        // 10 000 metros en 1800 segundos (30 min) = 20.0 km/h o ~12.4 mph
        XCTAssertEqual(Formato.unidadDeVelocidad(.metrico), "km/h")
        XCTAssertEqual(Formato.unidadDeVelocidad(.imperial), "mph")
        XCTAssertEqual(Formato.velocidadNumero(metros: 10_000, segundos: 1800, unidades: .metrico), "20,0")
        XCTAssertEqual(Formato.velocidad(metros: 10_000, segundos: 1800, unidades: .metrico), "20,0 km/h")
        XCTAssertEqual(Formato.velocidad(metros: 10_000, segundos: 1800, unidades: .imperial), "12,4 mph")
    }

    func testElDesnivelUsaLaUnidadElegida() {
        XCTAssertEqual(Formato.desnivel(metros: 100, unidades: .metrico), "100 m")
        XCTAssertEqual(Formato.desnivel(metros: 100, unidades: .imperial), "328 ft")
    }

    func testLimpiarTituloEventoEliminaExclamacionesPuntosSuspensivosYTextosAgregados() {
        XCTAssertEqual(Formato.limpiarTituloEvento("¡Media maratón (21K)! Día del evento"), "Media maratón")
        XCTAssertEqual(Formato.limpiarTituloEvento("¡Media maratón! Día del evento..."), "Media maratón")
        XCTAssertEqual(Formato.limpiarTituloEvento("Media maratón (21K)..."), "Media maratón")
        XCTAssertEqual(Formato.limpiarTituloEvento("Tu objetivo: media maratón (21K)."), "Media maratón")
        XCTAssertEqual(Formato.limpiarTituloEvento("Media maratón · 21K"), "Media maratón")
        XCTAssertEqual(Formato.limpiarTituloEvento("¡Maratón (42K)! Día del evento"), "Maratón")
        XCTAssertEqual(Formato.limpiarTituloEvento("5K (5.0 km)"), "5K")
        XCTAssertEqual(Formato.limpiarTituloEvento("10K"), "10K")
    }

    func testLimpiarTituloEventoEnTriatlonDevuelveNombresLegalesProtegidos() {
        XCTAssertEqual(Formato.limpiarTituloEvento("¡Media maratón (21K)! Día del evento", enTriatlon: true), "Triatlón media distancia")
        XCTAssertEqual(Formato.limpiarTituloEvento("Medio Ironman", enTriatlon: true), "Triatlón media distancia")
        XCTAssertEqual(Formato.limpiarTituloEvento("Half Ironman 70.3", enTriatlon: true), "Middle distance triathlon")
        XCTAssertEqual(Formato.limpiarTituloEvento("Maratón (42K)", enTriatlon: true), "Triatlón larga distancia")
    }
}
