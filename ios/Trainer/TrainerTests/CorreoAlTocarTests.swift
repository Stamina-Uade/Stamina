import Testing
import Foundation
@testable import Trainer
@testable import TrainerCore

// =============================================================================
// El botón que manda un correo no se habilita hasta que el correo es válido.
//
// 2026-10-22 (Iván): se va el "Ese correo no parece válido…" que aparecía debajo
// del campo al tocar. Antes (2026-09-10) se había decidido juzgar al tocar para
// no retar a quien todavía escribía; ahora no se reta nunca: el botón espera.
// Vale igual en las tres pantallas con correo: `login`, `reg-correo` y
// `clave-correo`. Un correo inválido no viaja aunque se llame a la función.
// =============================================================================

@MainActor
@Suite("El correo tiene que ser válido para poder mandarlo")
struct CorreoAlTocarTests {

    private func flujo(_ doble: ServicioDePrueba) -> FlujoEntrada {
        FlujoEntrada(servicio: doble)
    }

    @Test("Login: \"Ingresar\" se habilita con un correo válido y la contraseña escrita")
    func loginSePrendeConCorreoValido() {
        let flujo = flujo(ServicioDePrueba(Guion()))
        flujo.ir(a: .login)
        #expect(!flujo.loginListo)

        flujo.loginCorreo = "ivan"
        flujo.loginClave = "x"
        #expect(!flujo.loginListo, "con un correo que no es uno, no")

        flujo.loginCorreo = "ivan@ejemplo.com"
        #expect(flujo.loginListo)

        flujo.loginClave = ""
        #expect(!flujo.loginListo, "falta la contraseña")
    }

    @Test("Login: un correo que no parece uno no viaja")
    func loginNoMandaUnCorreoInvalido() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .login)
        flujo.loginCorreo = "ivan"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.pantalla == .login)
        #expect(!flujo.enCurso)
        #expect(flujo.alerta == nil, "no hay cartel: el botón ni siquiera estaba habilitado")
        #expect(await doble.pedidos.isEmpty, "no se manda nada")
    }

    @Test("Alta: sin un correo válido no se pide el código; con uno, sigue como siempre")
    func altaNoMandaUnCorreoInvalido() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .regCorreo)
        flujo.datos.nombre = "Iván"
        flujo.claveDeRegistro = "Trainer2026x"
        flujo.claveDeRegistroRepetida = "Trainer2026x"
        flujo.datos.correo = "persona@ejemplo"
        #expect(!flujo.puedePedirCodigoDeRegistro)

        await flujo.pedirCodigoDeRegistro()

        #expect(flujo.pantalla == .regCorreo)
        #expect(await doble.pedidos.isEmpty, "no se manda nada")

        flujo.datos.correo = "persona@ejemplo.com"
        #expect(flujo.puedePedirCodigoDeRegistro)
        await flujo.pedirCodigoDeRegistro()

        #expect(flujo.pantalla == .regCodigo)
        #expect(await doble.pedidos == ["pedirCodigoDeRegistro:persona@ejemplo.com"])
    }

    @Test("Recuperación: sin un correo válido no se pide el código; con uno, sigue como siempre")
    func recuperacionNoMandaUnCorreoInvalido() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .login)
        flujo.irARecuperarClave()
        flujo.recuperacionCorreo = "@ejemplo.com"

        await flujo.pedirCodigoDeClave()

        #expect(flujo.pantalla == .claveCorreo)
        #expect(await doble.pedidos.isEmpty, "no se manda nada")

        flujo.recuperacionCorreo = "persona@ejemplo.com"
        await flujo.pedirCodigoDeClave()

        #expect(flujo.pantalla == .claveCodigo)
        #expect(await doble.pedidos == ["pedirCodigoDeClave:persona@ejemplo.com"])
    }
}
