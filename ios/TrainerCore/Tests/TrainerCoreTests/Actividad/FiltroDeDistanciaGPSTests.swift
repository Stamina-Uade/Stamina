import XCTest
@testable import TrainerCore

final class FiltroDeDistanciaGPSTests: XCTestCase {
    func testNoSumaDerivaEstandoQuieto() {
        var filtro = FiltroDeDistanciaGPS()
        let muestras = [
            muestra(lat: -34.60370, lon: -58.38160, segundo: 0, precision: 7, velocidad: 0.05),
            muestra(lat: -34.60355, lon: -58.38140, segundo: 5, precision: 8, velocidad: 0.12),
            muestra(lat: -34.60382, lon: -58.38175, segundo: 10, precision: 9, velocidad: 0.08),
            muestra(lat: -34.60348, lon: -58.38120, segundo: 15, precision: 10, velocidad: 0.15),
        ]
        XCTAssertEqual(muestras.reduce(0) { total, punto in
            total + filtro.agregar(punto, deporte: .running)
        }, 0)
    }

    func testSumaDesplazamientoCompatibleConUnaCarrera() {
        var filtro = FiltroDeDistanciaGPS()
        let muestras = [
            muestra(lat: -34.60370, lon: -58.38160, segundo: 0, precision: 4, velocidad: 2.8),
            muestra(lat: -34.60357, lon: -58.38160, segundo: 5, precision: 4, velocidad: 2.9),
            muestra(lat: -34.60344, lon: -58.38160, segundo: 10, precision: 4, velocidad: 2.9),
        ]
        let total = muestras.reduce(0) { acumulado, punto in
            acumulado + filtro.agregar(punto, deporte: .running)
        }
        XCTAssertGreaterThan(total, 25)
        XCTAssertLessThan(total, 35)
    }

    func testSumaUnaCaminataLentaAunqueLaActividadSeaRunning() {
        var filtro = FiltroDeDistanciaGPS()
        let muestras = [
            muestra(lat: -34.60370, lon: -58.38160, segundo: 0, precision: 5, velocidad: 0.8),
            muestra(lat: -34.60368, lon: -58.38160, segundo: 3, precision: 5, velocidad: 0.8),
            muestra(lat: -34.60366, lon: -58.38160, segundo: 6, precision: 5, velocidad: 0.8),
            muestra(lat: -34.60364, lon: -58.38160, segundo: 9, precision: 5, velocidad: 0.8),
            muestra(lat: -34.60362, lon: -58.38160, segundo: 12, precision: 5, velocidad: 0.8),
            muestra(lat: -34.60360, lon: -58.38160, segundo: 15, precision: 5, velocidad: 0.8),
        ]
        let total = muestras.reduce(0) { $0 + filtro.agregar($1, deporte: .running) }
        XCTAssertGreaterThanOrEqual(total, 8)
    }

    func testSumaMovimientoRealCuandoCoreLocationNoDaVelocidad() {
        var filtro = FiltroDeDistanciaGPS()
        _ = filtro.agregar(muestra(lat: -34.60370, lon: -58.38160, segundo: 0,
                                   precision: 6, velocidad: -1), deporte: .running)
        let total = filtro.agregar(muestra(lat: -34.60355, lon: -58.38160, segundo: 20,
                                           precision: 6, velocidad: -1), deporte: .running)
        XCTAssertGreaterThan(total, 10)
    }

    func testNoPierdeUnTramoCuandoLasMuestrasLleganEspaciadas() {
        var filtro = FiltroDeDistanciaGPS()
        _ = filtro.agregar(muestra(lat: -34.60370, lon: -58.38160, segundo: 0,
                                   precision: 8, velocidad: 0.9), deporte: .running)
        let total = filtro.agregar(muestra(lat: -34.60338, lon: -58.38160, segundo: 40,
                                           precision: 8, velocidad: 0.9), deporte: .running)
        XCTAssertGreaterThan(total, 30)
    }

    func testDescartaSaltoIncompatibleConLaVelocidad() {
        var filtro = FiltroDeDistanciaGPS()
        _ = filtro.agregar(muestra(lat: -34.60370, lon: -58.38160, segundo: 0,
                                   precision: 5, velocidad: 2.5), deporte: .running)
        let salto = filtro.agregar(muestra(lat: -34.60070, lon: -58.38160, segundo: 5,
                                           precision: 5, velocidad: 2.5), deporte: .running)
        XCTAssertEqual(salto, 0)
    }

    func testAgitarElBrazoSinDesplazarseNoUsaLaDistanciaDeSalud() {
        var medidor = MedidorDeDistanciaExterior()
        XCTAssertEqual(medidor.actualizarSalud(metros: 300), 0)
        _ = medidor.agregarGPS(muestra(lat: -34.60370, lon: -58.38160, segundo: 0,
                                       precision: 6, velocidad: 0.08), deporte: .running)
        XCTAssertEqual(medidor.agregarGPS(muestra(lat: -34.60355, lon: -58.38140, segundo: 5,
                                                  precision: 8, velocidad: 0.12), deporte: .running), 0)
    }

    func testUsaSaludCuandoGPSConfirmaUnaDistanciaCompatible() {
        var medidor = MedidorDeDistanciaExterior()
        _ = medidor.agregarGPS(muestra(lat: -34.60370, lon: -58.38160, segundo: 0,
                                       precision: 4, velocidad: 2.8), deporte: .running)
        let gps = medidor.agregarGPS(muestra(lat: -34.60343, lon: -58.38160, segundo: 10,
                                             precision: 4, velocidad: 3.0), deporte: .running)
        XCTAssertGreaterThan(gps, 20)
        XCTAssertEqual(medidor.actualizarSalud(metros: gps + 4), gps + 4)
    }

    func testDescartaDistanciaDeSaludIncompatibleConGPS() {
        var medidor = MedidorDeDistanciaExterior()
        _ = medidor.agregarGPS(muestra(lat: -34.60370, lon: -58.38160, segundo: 0,
                                       precision: 4, velocidad: 2.8), deporte: .running)
        let gps = medidor.agregarGPS(muestra(lat: -34.60343, lon: -58.38160, segundo: 10,
                                             precision: 4, velocidad: 3.0), deporte: .running)
        XCTAssertEqual(medidor.actualizarSalud(metros: 300), gps)
    }

    func testUnaSalidaDebeDurarYConfirmarDesplazamiento() {
        XCTAssertFalse(ValidadorDeSalida.sePuedeGuardar(segundos: 3, metros: 20))
        XCTAssertFalse(ValidadorDeSalida.sePuedeGuardar(segundos: 180, metros: 0))
        XCTAssertTrue(ValidadorDeSalida.sePuedeGuardar(segundos: 180, metros: 12))
    }

    private func muestra(lat: Double, lon: Double, segundo: Int,
                         precision: Double, velocidad: Double) -> MuestraGPS {
        MuestraGPS(latitud: lat, longitud: lon, instanteMs: Int64(segundo * 1_000),
                   precisionMetros: precision, velocidadMetrosPorSegundo: velocidad)
    }
}
