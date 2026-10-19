import XCTest
import SwiftUI
@testable import TrainerCore

/// Lo que se prueba acá no es "que compile": son las reglas de AGENTS.md §10.1
/// y los hallazgos medidos de design/ESPECIFICACION.md §9. Un lint puede
/// verificar que nadie escriba un color a mano; estos tests verifican que los
/// valores que SÍ usamos son los correctos.
final class TemaTests: XCTestCase {

    func testElObjetivoTactilMinimoEsElQueFijaAgentsMd() {
        XCTAssertEqual(TokensTamano.objetivoTactilMinimo, 48,
                       "AGENTS.md §10.1 fija 48 pt para el teléfono, sin excepciones.")
    }

    /// ESPECIFICACION §9.1: el placeholder del diseño (blanco al 32 %) mide
    /// 2.74:1 y no cumple. La paleta lo sirve con el terciario (.5, 4.89:1).
    func testElPlaceholderNoUsaElTokenQueFallaContraste() {
        XCTAssertEqual(Paleta.textoPlaceholder, TokensColor.telefonoTextoTerciario)
        XCTAssertNotEqual(Paleta.textoPlaceholder, TokensColor.telefonoTextoPlaceholder)
    }

    /// Mismo caso para el texto deshabilitado (.34 → 2.87:1).
    func testElTextoDeshabilitadoNoUsaElTokenQueFallaContraste() {
        XCTAssertEqual(Paleta.textoDeshabilitado, TokensColor.telefonoTextoSecundario)
        XCTAssertNotEqual(Paleta.textoDeshabilitado, TokensColor.telefonoTextoDeshabilitado)
    }

    /// El tracking del diseño viene en `em` y SwiftUI lo quiere en puntos.
    /// Si esta conversión se rompe, los títulos se ven bien igual y nadie se
    /// entera hasta comparar capturas con Android.
    func testElEspaciadoDeLetrasSeGuardaEnEmComoLoDeclaraElDiseno() {
        XCTAssertEqual(EstiloTipografico.tituloPantalla.espaciadoLetrasEm, -0.03)
        XCTAssertEqual(EstiloTipografico.codigo.espaciadoLetrasEm, 0.36)
    }

    /// `tokens.json` → `tipografia.cifras_tabulares`: obligatorio donde hay
    /// números que cambian. Un código de verificación que baila al tipear es
    /// exactamente el caso.
    func testLosRolesNumericosPidenCifrasTabulares() {
        XCTAssertTrue(EstiloTipografico.codigo.cifrasTabulares)
        XCTAssertTrue(EstiloTipografico.campoNumero.cifrasTabulares)
        XCTAssertTrue(EstiloTipografico.numeroDato.cifrasTabulares)
        XCTAssertFalse(EstiloTipografico.cuerpo.cifrasTabulares)
        XCTAssertTrue(EstiloTipografico.metricaHeroe.cifrasTabulares)
        XCTAssertTrue(EstiloTipografico.metricaMedia.cifrasTabulares)
    }

    /// Rediseño 2026-10: los roles pesados salen de tokens.json, no de la pantalla.
    func testLosRolesDelRedisenoSalenDeLosTokens() {
        XCTAssertEqual(EstiloTipografico.display.tamano, TokensTipografia.displayTamano)
        XCTAssertEqual(EstiloTipografico.metricaHeroe.tamano, TokensTipografia.metricaHeroeTamano)
        XCTAssertEqual(EstiloTipografico.metricaHeroe.peso, .heavy)
    }

    /// AGENTS.md §1: la marca del producto está centralizada y el nombre comercial
    /// es Stamina.
    func testMarcaAppCentralizada() {
        XCTAssertEqual(MarcaApp.nombre, "Stamina")
        XCTAssertEqual(MarcaApp.recursoLogo, "LogoApp")
    }
}
