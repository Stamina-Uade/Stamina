import XCTest
@testable import TrainerCore

final class AlmacenDeTransferenciasDeSalidaTests: XCTestCase {
    func testElArchivoDeSalidaConservaTodosLosPuntosHastaConfirmarLaEntrega() throws {
        let almacen = nuevoAlmacen()
        defer { almacen.borrarTodo() }
        let salida = salida(cantidadDePuntos: 12_345)

        let archivo = try XCTUnwrap(almacen.guardarParaEnviar(salida))
        let guardada = try JSONDecoder().decode(SalidaDelReloj.self, from: Data(contentsOf: archivo))

        XCTAssertEqual(guardada.id, salida.id)
        XCTAssertEqual(guardada.puntos.count, 12_345)
        XCTAssertEqual(guardada.puntos.first, salida.puntos.first)
        XCTAssertEqual(guardada.puntos.last, salida.puntos.last)
        XCTAssertEqual(almacen.archivosParaEnviar(), [archivo])

        almacen.borrarEnviado(archivo)
        XCTAssertTrue(almacen.archivosParaEnviar().isEmpty)
    }

    func testLaEntradaPersisteYSeDeduplicaHastaQueLaCapaSiguienteLaConsume() {
        let nombre = "transferencias-test-\(UUID().uuidString)"
        let primero = AlmacenDeTransferenciasDeSalida(nombre: nombre)
        defer { primero.borrarTodo() }
        let salida = salida(cantidadDePuntos: 3)

        primero.guardarRecibida(salida)
        primero.guardarRecibida(salida)

        let despuesDeReabrir = AlmacenDeTransferenciasDeSalida(nombre: nombre)
        XCTAssertEqual(despuesDeReabrir.leerRecibidas().map(\.id), [salida.id])
        XCTAssertEqual(despuesDeReabrir.leerRecibidas().first?.puntos, salida.puntos)
    }

    func testUnaEntradaIlegibleSeAparta_yNoLaPisaElProximoGuardado() throws {
        let nombre = "transferencias-test-\(UUID().uuidString)"
        let almacen = AlmacenDeTransferenciasDeSalida(nombre: nombre)
        defer { almacen.borrarTodo() }
        let carpeta = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            .appendingPathComponent(nombre, isDirectory: true)
        let entrada = carpeta.appendingPathComponent("entrada.json")
        let basura = Data("{ esto no es una lista".utf8)
        try basura.write(to: entrada)

        XCTAssertTrue(almacen.leerRecibidas().isEmpty)
        almacen.guardarRecibida(salida(cantidadDePuntos: 2))

        let apartados = try FileManager.default.contentsOfDirectory(atPath: carpeta.path)
            .filter { $0.hasPrefix("entrada.json.corrupto-") }
        XCTAssertEqual(apartados.count, 1, "el archivo ilegible se conserva aparte")
        let apartado = try XCTUnwrap(apartados.first)
        let conservado = try Data(contentsOf: carpeta.appendingPathComponent(apartado))
        XCTAssertEqual(conservado, basura)
        XCTAssertEqual(almacen.leerRecibidas().count, 1)
    }

    func testApartarUnArchivoQueNoExisteNoHaceNada() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("no-existe-\(UUID().uuidString)")
        XCTAssertNil(ArchivoIlegible.apartar(url))
    }

    private func nuevoAlmacen() -> AlmacenDeTransferenciasDeSalida {
        AlmacenDeTransferenciasDeSalida(nombre: "transferencias-test-\(UUID().uuidString)")
    }

    private func salida(cantidadDePuntos: Int) -> SalidaDelReloj {
        SalidaDelReloj(
            id: UUID().uuidString,
            usuarioId: "usuario-prueba",
            deporte: .running,
            inicioMs: 1_790_000_000_000,
            segundos: 3_600,
            metros: 10_000,
            puntos: (0..<cantidadDePuntos).map {
                PuntoDeRecorrido(lat: -34.6 + Double($0) / 1_000_000,
                                 lon: -58.38,
                                 atMs: 1_790_000_000_000 + Int64($0))
            },
            pulsoMedio: 150,
            pulsoMaximo: 178)
    }
}
