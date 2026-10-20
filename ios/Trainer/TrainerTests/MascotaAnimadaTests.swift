import CoreGraphics
import ImageIO
import SwiftUI
import XCTest
@testable import Trainer

/// La demora de cada cuadro de la mascota animada (lo que ImageIO dice de cada
/// cuadro de un WebP) y dónde pone el tour el globito.
final class MascotaAnimadaTests: XCTestCase {

    private let webp = kCGImagePropertyWebPDictionary as String
    private let sinRecortar = kCGImagePropertyWebPUnclampedDelayTime as String
    private let recortada = kCGImagePropertyWebPDelayTime as String
    private let porDefecto = DecodificadorDeMascota.demoraPorDefecto

    // MARK: - Demora de un cuadro

    func testSinPropiedadesEsUnDoceavoDeSegundo() {
        XCTAssertEqual(DecodificadorDeMascota.demora(de: nil), 1.0 / 12.0, accuracy: 1e-9)
        XCTAssertEqual(DecodificadorDeMascota.demora(de: [:]), porDefecto, accuracy: 1e-9)
        XCTAssertEqual(DecodificadorDeMascota.demora(de: [webp: [String: Any]()]), porDefecto, accuracy: 1e-9)
    }

    func testPrefiereLaDemoraSinRecortar() {
        let propiedades: [String: Any] = [webp: [sinRecortar: 0.083, recortada: 0.1]]
        XCTAssertEqual(DecodificadorDeMascota.demora(de: propiedades), 0.083, accuracy: 1e-9)
    }

    func testSiLaSinRecortarEsCeroUsaLaRecortada() {
        let propiedades: [String: Any] = [webp: [sinRecortar: 0.0, recortada: 0.1]]
        XCTAssertEqual(DecodificadorDeMascota.demora(de: propiedades), 0.1, accuracy: 1e-9)
    }

    func testLeeNumerosComoLosDaImageIO() {
        let propiedades: [String: Any] = [webp: [recortada: NSNumber(value: 0.25)]]
        XCTAssertEqual(DecodificadorDeMascota.demora(de: propiedades), 0.25, accuracy: 1e-9)
    }

    func testUnaDemoraCasiCeroNoSirveYQuedaLaDePorDefecto() {
        let propiedades: [String: Any] = [webp: [sinRecortar: 0.005, recortada: 0.0]]
        XCTAssertEqual(DecodificadorDeMascota.demora(de: propiedades), porDefecto, accuracy: 1e-9)
    }

    func testUnValorQueNoEsNumeroSeIgnora() {
        let propiedades: [String: Any] = [webp: [sinRecortar: "rápido"]]
        XCTAssertEqual(DecodificadorDeMascota.demora(de: propiedades), porDefecto, accuracy: 1e-9)
    }

    func testElLadoEnPixelesRedondeaHaciaArriba() {
        XCTAssertEqual(DecodificadorDeMascota.ladoEnPixeles(alto: 100, escala: 3), 300)
        XCTAssertEqual(DecodificadorDeMascota.ladoEnPixeles(alto: 100.2, escala: 2), 201)
        XCTAssertEqual(DecodificadorDeMascota.ladoEnPixeles(alto: 0, escala: 2), 1)
    }

    func testElSiguienteCuadroDaLaVueltaSoloConLoop() {
        XCTAssertEqual(DecodificadorDeMascota.siguiente(a: 0, de: 96, loop: true), 1)
        XCTAssertEqual(DecodificadorDeMascota.siguiente(a: 95, de: 96, loop: true), 0)
        XCTAssertEqual(DecodificadorDeMascota.siguiente(a: 94, de: 96, loop: false), 95)
        XCTAssertNil(DecodificadorDeMascota.siguiente(a: 95, de: 96, loop: false))
        XCTAssertNil(DecodificadorDeMascota.siguiente(a: 0, de: 0, loop: true))
    }

    // MARK: - El globito del tour

    /// En los teléfonos de 375, 393 y 430 pt, con la barra medida donde la
    /// pone la app: el globito queda en pantalla y no pisa el dibujo.
    func testElGlobitoNoPisaLaMascotaNiSeSaleDeLaPantalla() {
        let margenes = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        for ancho in [CGFloat(375), 393, 430] {
            let tamano = CGSize(width: ancho, height: 852)
            let barra = CGRect(x: 0, y: tamano.height - margenes.bottom - 74, width: ancho, height: 74)
            for paso in PasoDelTour.todos {
                let g = paso.animacion.geometria
                let d = DisposicionDelTour(lugar: paso.lugar, geometria: g, tamano: tamano,
                                           margenes: margenes, barra: barra)
                let alto = d.mascota.height
                let bordeIzquierdo = d.mascota.minX + alto * g.izquierda
                let bordeDerecho = d.mascota.minX + alto * g.derecha

                XCTAssertGreaterThanOrEqual(d.globo.minX, 0)
                XCTAssertLessThanOrEqual(d.globo.maxX, ancho)
                XCTAssertLessThan(d.mascota.maxY, barra.minY, "la mascota se para sobre la barra")
                if d.globoAlCostado {
                    let pisa = d.globo.maxX > bordeIzquierdo - DisposicionDelTour.separacion + 0.5
                        && d.globo.minX < bordeDerecho + DisposicionDelTour.separacion - 0.5
                    XCTAssertFalse(pisa, "\(paso.animacion) a \(ancho) pt")
                    XCTAssertLessThan(d.globo.maxY, d.mascota.minY + alto * g.boca.y)
                } else {
                    XCTAssertLessThan(d.globo.maxY, d.mascota.minY + alto * g.tope, "\(paso.animacion)")
                }
                // El piquito baja desde el globito.
                XCTAssertGreaterThan(d.puntaEnElGlobo.y, 0)
            }
        }
    }
}
