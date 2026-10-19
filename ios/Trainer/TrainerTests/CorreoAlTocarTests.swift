import Testing
import Foundation
@testable import Trainer
@testable import TrainerCore

// =============================================================================
// El correo se juzga al TOCAR el botón, no mientras se escribe.
//
// Iván, probando en el iPhone (2026-09-10): con la primera letra ya aparecía "ese
// correo no parece válido", y el botón quedaba apagado hasta que el correo
// pareciera uno. Molestaba, y hacía sentir lenta la pantalla. Las reglas de la
// contraseña siguen en vivo: ahí el medidor ayuda mientras se escribe.
//
// Vale igual en las tres pantallas con correo: `login`, `reg-correo` y
// `clave-correo`.
// =============================================================================

@MainActor
@Suite("El correo se valida al tocar el botón")
struct CorreoAlTocarTests {

    private func flujo(_ doble: ServicioDePrueba) -> FlujoEntrada {
        FlujoEntrada(servicio: doble)
    }

    @Test("Login: con algo escrito en los dos campos se puede tocar, aunque el correo todavía no parezca uno")
    func loginSePrendeConAlgoEscrito() {
        let flujo = flujo(ServicioDePrueba(Guion()))
        flujo.ir(a: .login)
        #expect(!flujo.loginListo)

        flujo.loginCorreo = "i"
        #expect(!flujo.loginListo, "falta la contraseña")

        flujo.loginClave = "x"
        #expect(flujo.loginListo)
        #expect(!flujo.correoRechazado, "mientras se escribe, el correo no se juzga")
    }

    @Test("Login: un correo que no parece uno no viaja, deja el error, y el error se va al editar el correo")
    func loginRechazaAlTocar() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .login)
        flujo.loginCorreo = "ivan"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.correoRechazado)
        #expect(flujo.pantalla == .login)
        #expect(!flujo.enCurso)
        #expect(await doble.pedidos.isEmpty, "no se manda nada")

        flujo.loginClave = "Trainer2026y"
        #expect(flujo.correoRechazado, "cambiar la contraseña no es corregir el correo")

        flujo.loginCorreo = "ivan@"
        #expect(!flujo.correoRechazado, "editar el correo borra el error")
    }

    @Test("Alta: un correo que no parece uno no pide el código; corregido, sigue como siempre")
    func altaRechazaAlTocar() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .regCorreo)
        flujo.datos.correo = "persona@ejemplo"

        await flujo.pedirCodigoDeRegistro()

        #expect(flujo.correoRechazado)
        #expect(flujo.pantalla == .regCorreo)
        #expect(await doble.pedidos.isEmpty, "no se manda nada")

        flujo.datos.correo = "persona@ejemplo.com"
        #expect(!flujo.correoRechazado, "editar el correo borra el error")

        await flujo.pedirCodigoDeRegistro()

        #expect(flujo.pantalla == .regCodigo)
        #expect(await doble.pedidos == ["pedirCodigoDeRegistro:persona@ejemplo.com"])
    }

    @Test("Recuperación: un correo que no parece uno no pide el código; corregido, sigue como siempre")
    func recuperacionRechazaAlTocar() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .login)
        flujo.irARecuperarClave()
        flujo.recuperacionCorreo = "@ejemplo.com"

        await flujo.pedirCodigoDeClave()

        #expect(flujo.correoRechazado)
        #expect(flujo.pantalla == .claveCorreo)
        #expect(await doble.pedidos.isEmpty, "no se manda nada")

        flujo.recuperacionCorreo = "persona@ejemplo.com"
        #expect(!flujo.correoRechazado, "editar el correo borra el error")

        await flujo.pedirCodigoDeClave()

        #expect(flujo.pantalla == .claveCodigo)
        #expect(await doble.pedidos == ["pedirCodigoDeClave:persona@ejemplo.com"])
    }

    @Test("El error es de la pantalla que lo mostró: ir a otra no se lo lleva")
    func elErrorNoViajaAOtraPantalla() async {
        let flujo = flujo(ServicioDePrueba(Guion()))
        flujo.ir(a: .login)
        flujo.loginCorreo = "ivan"
        flujo.loginClave = "Trainer2026x"
        await flujo.entrar()
        #expect(flujo.correoRechazado)

        flujo.ir(a: .regCorreo)   // "Registrate", sin tocar el correo del login

        #expect(!flujo.correoRechazado, "el alta no arranca con un error que no es suyo")
    }

    @Test("El error del intento anterior no queda pegado al del correo")
    func rechazarBorraElErrorAnterior() async {
        var guion = Guion()
        guion.login = [.sinRed]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"
        await flujo.entrar()
        #expect(flujo.errorVisible == Textos.errorOffline)

        flujo.loginCorreo = "persona"
        await flujo.entrar()

        #expect(flujo.correoRechazado)
        #expect(flujo.errorVisible == nil, "el «sin conexión» era del intento anterior")
    }
}
