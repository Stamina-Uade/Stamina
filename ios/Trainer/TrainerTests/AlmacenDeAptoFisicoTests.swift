import Foundation
import Testing
@testable import Trainer

@MainActor
@Suite("Apto físico: se guarda en el teléfono, por cuenta, y sabe cuándo vence")
struct AlmacenDeAptoFisicoTests {

    private func carpetaTemporal() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("apto-test-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("Guardar copia el archivo y el apto queda vigente")
    func guardaYQuedaVigente() throws {
        let raiz = carpetaTemporal()
        let almacen = AlmacenDeAptoFisico(raiz: raiz)
        let origen = FileManager.default.temporaryDirectory.appendingPathComponent("apto_fisico.pdf")
        try Data("%PDF-1.4 prueba".utf8).write(to: origen)
        let vence = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()

        let resultado = almacen.guardar(desde: origen, vence: vence, declaracionAceptada: true)

        #expect((try? resultado.get()) != nil)
        #expect(almacen.apto?.nombreOriginal == "apto_fisico.pdf")
        #expect(almacen.estado == .vigente(dias: 90))
        if let url = almacen.urlDelArchivo {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
        // Otra instancia sobre la misma carpeta lo lee de disco.
        #expect(AlmacenDeAptoFisico(raiz: raiz).apto == almacen.apto)
        almacen.borrar()
        #expect(almacen.estado == .sinCargar)
    }

    @Test("A 30 días o menos está por vencer, y pasado el día, vencido")
    func estadosDeVencimiento() {
        let apto = AptoFisico(nombreOriginal: "a.pdf", archivoGuardado: "a.pdf", bytes: 1, subidoMs: 0,
                              venceMs: Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000),
                              declaracionAceptada: true)
        #expect(apto.diasParaVencer() == 0)
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        #expect(apto.diasParaVencer(ahora: manana) == -1)
    }

    @Test("Un id de cuenta no puede salirse de la carpeta del apto")
    func nombreSeguro() {
        #expect(AlmacenDeAptoFisico.nombreSeguro("../../etc") == "etc")
        #expect(AlmacenDeAptoFisico.nombreSeguro("") == "sin-dueno")
        #expect(AlmacenDeAptoFisico.extensionPermitida("EXE") == "dat")
        #expect(AlmacenDeAptoFisico.extensionPermitida("PDF") == "pdf")
    }
}
