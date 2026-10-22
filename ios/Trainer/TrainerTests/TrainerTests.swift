import Combine
import Testing
import Foundation
import Security
@testable import Trainer
@testable import TrainerCore

// =============================================================================
// Lo que se prueba acá es la traducción entre lo que la persona hace y lo que el
// contrato recibe (AGENTS.md §5): las unidades, qué manda cada paso del alta, y
// qué hace el flujo con cada respuesta del servidor.
//
// El servidor es un doble (`ServicioDePrueba`): ninguno de estos tests necesita
// red ni un backend corriendo. Lo que sí toca algo de verdad está marcado —el
// llavero y App Transport Security—, y está acá y no en `swift test` porque sólo
// existen adentro del simulador.
//
// 🛑 Estas validaciones NO son de seguridad. Toda validación se hace cumplir en
// el servidor (AGENTS.md §10). Acá se prueba que el cliente no le haga perder el
// viaje a nadie, y que no mande nada distinto de lo que manda Android.
// =============================================================================

@Suite("Unidades: de lo que se escribe a lo que el contrato guarda")
struct UnidadesTests {

    @Test("El peso pasa de kilos a gramos enteros")
    func pesoEnGramos() {
        var d = DatosRegistro()
        d.pesoTexto = "72"
        #expect(d.pesoEnGramos == 72_000)

        d.pesoTexto = "72,5"      // coma decimal: teclado en español
        #expect(d.pesoEnGramos == 72_500)

        d.pesoTexto = "72.5"      // punto decimal: teclado en inglés
        #expect(d.pesoEnGramos == 72_500)

        d.pesoTexto = "  68,25 "  // con espacios, como sale de pegar
        #expect(d.pesoEnGramos == 68_250)
    }

    @Test("La altura pasa de centímetros a milímetros enteros")
    func alturaEnMilimetros() {
        var d = DatosRegistro()
        d.alturaTexto = "178"
        #expect(d.alturaEnMilimetros == 1_780)

        d.alturaTexto = "178,5"
        #expect(d.alturaEnMilimetros == 1_785)
    }

    @Test("Formato de pasos de Apple Health")
    func formatoPasos() {
        #expect(Formato.pasos(0) == "0")
        #expect(Formato.pasos(100) == "100")
        #expect(Formato.pasos(1_000).contains("1"))
        #expect(Formato.pasos(12_450).contains("12"))
    }

    @Test("Fuera del rango del contrato, no hay valor: el botón no deja seguir")
    func rangosDelContrato() {
        var d = DatosRegistro()

        // El contrato acepta de 20 000 a 400 000 g.
        d.pesoTexto = "19"
        #expect(d.pesoEnGramos == nil)
        d.pesoTexto = "401"
        #expect(d.pesoEnGramos == nil)
        d.pesoTexto = "20"
        #expect(d.pesoEnGramos == 20_000)
        d.pesoTexto = "400"
        #expect(d.pesoEnGramos == 400_000)

        // Y de 500 a 2 600 mm.
        d.alturaTexto = "49"
        #expect(d.alturaEnMilimetros == nil)
        d.alturaTexto = "261"
        #expect(d.alturaEnMilimetros == nil)
        d.alturaTexto = "50"
        #expect(d.alturaEnMilimetros == 500)
    }

    @Test("Lo que no es un número no se manda")
    func textoQueNoEsNumero() {
        var d = DatosRegistro()
        for basura in ["", "   ", "setenta", "72kg", "7,2,5"] {
            d.pesoTexto = basura
            #expect(d.pesoEnGramos == nil, "«\(basura)» no debería dar un peso")
        }
    }

    /// 1998-06-24T00:00:00Z. La cuenta: 10 401 días desde epoch × 86 400 s.
    static let veinticuatroDeJunioUTC: Int64 = 898_646_400_000

    private func fecha(_ anio: Int, _ mes: Int, _ dia: Int, _ hora: Int, _ minuto: Int,
                       en zona: String) -> Date {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: zona)!
        return calendario.date(from: DateComponents(year: anio, month: mes, day: dia,
                                                    hour: hora, minute: minuto))!
    }

    @Test("Una fecha del calendario es la medianoche UTC de ESE día, esté donde esté la persona")
    func fechaDelCalendario() {
        let baires = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let tokio = TimeZone(identifier: "Asia/Tokyo")!

        // 23:30 del 24 en Buenos Aires ya es el 25 en UTC; 00:30 del 24 en Tokio
        // todavía es el 23 en UTC. Las dos son "el 24 de junio" para quien lo eligió.
        let tardeEnBaires = fecha(1998, 6, 24, 23, 30, en: baires.identifier)
        let tempranoEnTokio = fecha(1998, 6, 24, 0, 30, en: tokio.identifier)

        #expect(DatosRegistro.fechaDelCalendarioEnMs(tardeEnBaires, zona: baires) == Self.veinticuatroDeJunioUTC)
        #expect(DatosRegistro.fechaDelCalendarioEnMs(tempranoEnTokio, zona: tokio) == Self.veinticuatroDeJunioUTC)
    }

    @Test("El tiempo va en milisegundos epoch enteros, nunca en ISO")
    func tiempoEnMilisegundos() {
        #expect(DatosRegistro.epochMs(Date(timeIntervalSince1970: 0)) == 0)
        #expect(DatosRegistro.epochMs(Date(timeIntervalSince1970: 1.5)) == 1_500)
    }
}

@Suite("El correo")
struct CorreoTests {

    @Test("Acepta los que pueden recibir un código")
    func valido() {
        for correo in ["ivan@trainer.app", "a@b.co", "nombre.apellido@sub.dominio.com.ar"] {
            #expect(DatosRegistro.pareceCorreo(correo), "«\(correo)» debería valer")
        }
    }

    @Test("Rechaza los que seguro no")
    func invalido() {
        for correo in ["", "ivan", "ivan@", "@trainer.app", "ivan@trainer",
                       "ivan@@trainer.app", "ivan @trainer.app", "ivan@.app", "ivan@trainer."] {
            #expect(!DatosRegistro.pareceCorreo(correo), "«\(correo)» no debería valer")
        }
    }
}

@Suite("Lo que manda cada paso de perfil a PATCH /me (decisión 0008)")
struct LoQueGuardaCadaPasoTests {

    private let baires = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    @Test("Con el nombre alcanza: el apellido es opcional")
    func apellidoOpcional() {
        var d = DatosRegistro()
        d.nombre = "Iván"
        #expect(d.identidadLista)
    }

    @Test("Las elecciones arrancan vacías y no dejan seguir hasta que alguien elija")
    func sinEleccionDeFabrica() {
        let d = DatosRegistro()
        #expect(d.sexo == nil && d.deporte == nil && d.nivel == nil)
        #expect(!d.puedeSeguir(en: .regSexo))
        #expect(!d.puedeSeguir(en: .regDeporte))
        #expect(!d.puedeSeguir(en: .regNivel))
        #expect(d.loQueGuarda(en: .regSexo, zonaHoraria: baires) == nil)
    }

    /// 🛑 Con una fecha de fábrica, alguien de quince años que tocaba "Continuar"
    /// quedaba guardado como adulto, con objetivos de calorías de adulto.
    @Test("El nacimiento arranca vacío y no deja seguir hasta mover la rueda")
    func nacimientoSinFechaDeFabrica() {
        var d = DatosRegistro()
        #expect(d.nacimiento == nil)
        #expect(!d.puedeSeguir(en: .regNacimiento))
        #expect(d.loQueGuarda(en: .regNacimiento, zonaHoraria: baires) == nil)

        d.nacimiento = DatosRegistro.posicionInicialDeLaRueda
        #expect(d.puedeSeguir(en: .regNacimiento), "elegir la fecha que ya mostraba la rueda también vale")
    }

    @Test("Con menos de 18 años no se sigue: es la edad mínima de los términos")
    func nacimientoMayorDeEdad() {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = baires
        let hoy = calendario.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 12))!
        var d = DatosRegistro()
        d.nacimiento = calendario.date(from: DateComponents(year: 2008, month: 10, day: 23, hour: 12))!
        #expect(!d.tieneEdadMinima(hoy: hoy, calendario: calendario), "le falta un día para los 18")
        d.nacimiento = calendario.date(from: DateComponents(year: 2008, month: 10, day: 22, hour: 12))!
        #expect(d.tieneEdadMinima(hoy: hoy, calendario: calendario), "hoy cumple 18")
    }

    @Test("Cada paso manda sólo lo suyo: un campo de más pisaría lo de otro paso")
    func soloLoSuyo() {
        var d = DatosRegistro()
        d.sexo = .femenino
        d.pesoTexto = "72"
        d.alturaTexto = "178"
        d.deporte = .ciclismo
        d.nivel = .avanzado

        #expect(d.loQueGuarda(en: .regSexo, zonaHoraria: baires) == PerfilEntrada(biologicalSex: .femenino))
        #expect(d.loQueGuarda(en: .regCuerpo, zonaHoraria: baires) == PerfilEntrada(weightG: 72_000, heightMm: 1_780))
        #expect(d.loQueGuarda(en: .regDeporte, zonaHoraria: baires) == PerfilEntrada(sport: .ciclismo))
        #expect(d.loQueGuarda(en: .regNivel, zonaHoraria: baires) == PerfilEntrada(level: .avanzado))
    }

    @Test("El nacimiento viaja como la medianoche UTC del día elegido")
    func nacimiento() {
        var d = DatosRegistro()
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = baires
        d.nacimiento = calendario.date(from: DateComponents(year: 1998, month: 6, day: 24, hour: 21))!

        #expect(d.loQueGuarda(en: .regNacimiento, zonaHoraria: baires)
                == PerfilEntrada(birthdateMs: UnidadesTests.veinticuatroDeJunioUTC))
    }

    @Test("Una carrera pide la fecha; con fecha viaja como medianoche UTC")
    func objetivoConCarrera() {
        var d = DatosRegistro()
        d.objetivo = .maraton
        #expect(!d.puedeSeguir(en: .regObjetivo), "sin fecha de carrera no se sigue (2026-10-22)")

        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = baires
        d.fechaObjetivo = calendario.date(from: DateComponents(year: 1998, month: 6, day: 24, hour: 9))!
        #expect(d.puedeSeguir(en: .regObjetivo))
        #expect(d.loQueGuarda(en: .regObjetivo, zonaHoraria: baires)
                == PerfilEntrada(goal: .maraton, goalDateMs: UnidadesTests.veinticuatroDeJunioUTC))
        #expect(d.camposEnNull(en: .regObjetivo).isEmpty)
    }

    @Test("Volver a entrenar sin lesiones no tiene fecha: sigue derecho y manda null")
    func objetivoSinCarrera() {
        var d = DatosRegistro()
        d.objetivo = .volverSinLesiones
        // Aunque haya quedado una fecha de antes, no viaja: no hay calendario.
        d.fechaObjetivo = Date(timeIntervalSince1970: 0)

        #expect(d.puedeSeguir(en: .regObjetivo))
        #expect(d.loQueGuarda(en: .regObjetivo, zonaHoraria: baires) == PerfilEntrada(goal: .volverSinLesiones))
        #expect(d.camposEnNull(en: .regObjetivo) == [.fechaDelObjetivo])
    }

    @Test("Los días salen ordenados, con el día ISO, y viajan con la zona")
    func dias() {
        var d = DatosRegistro()
        d.dias = [6: 7 * 60, 2: 18 * 60 + 30]     // sábado y martes, desordenados

        let p = d.loQueGuarda(en: .regDias, zonaHoraria: baires)
        #expect(p?.trainingDays == [DiaEntrenamiento(weekday: 2, minuteOfDay: 18 * 60 + 30),
                                    DiaEntrenamiento(weekday: 6, minuteOfDay: 7 * 60)])
        #expect(p?.timezone == "America/Argentina/Buenos_Aires",
                "sin la zona, el minuto del día no significa nada")
    }

    @Test("El apto no guarda nada en el servidor: vive en el teléfono")
    func apto() {
        #expect(DatosRegistro().loQueGuarda(en: .regApto, zonaHoraria: baires) == nil)
    }
}

@MainActor
@Suite("La contraseña y la navegación")
struct FlujoTests {

    private func flujo() -> FlujoEntrada {
        FlujoEntrada(servicio: ServicioDePrueba(Guion()))
    }

    @Test("El mínimo es el del CONTRATO (10), no el del diseño (8)")
    func largoMinimo() {
        let flujo = flujo()
        #expect(FlujoEntrada.largoMinimoDeClave == 10)

        flujo.claveNueva = "Abcdefg1"          // 8, como decía el diseño
        #expect(flujo.reglasDeClaveNuevaCumplidas == 2)

        flujo.claveNueva = "Abcdefgh1j"        // 10
        #expect(flujo.reglasDeClaveNuevaCumplidas == 3)
    }

    @Test("Las tres reglas se cuentan por separado")
    func reglas() {
        let flujo = flujo()
        flujo.claveNueva = "abcdefghij"        // largo, sin mayúscula ni número
        #expect(flujo.reglasDeClaveNuevaCumplidas == 1)
        flujo.claveNueva = "Abcdefghij"        // + mayúscula
        #expect(flujo.reglasDeClaveNuevaCumplidas == 2)
        flujo.claveNueva = "Abcdefghi1"        // + número
        #expect(flujo.reglasDeClaveNuevaCumplidas == 3)
    }

    @Test("No se guarda hasta que las dos coinciden")
    func coincidencia() {
        let flujo = flujo()
        flujo.claveNueva = "Abcdefghi1"
        flujo.claveNuevaRepetida = "Abcdefghi2"
        #expect(!flujo.claveNuevaLista)

        flujo.claveNuevaRepetida = "Abcdefghi1"
        #expect(flujo.claveNuevaLista)
    }

    @Test("La contraseña segura del iPhone llena las dos y la confirmación se oculta")
    func contrasenaSugerida() {
        let flujo = flujo()
        // El autocompletado llena las dos de una vez, en cualquier orden.
        flujo.claveDeRegistroRepetida = "Xk9-pQr2-mW7z"
        flujo.claveDeRegistro = "Xk9-pQr2-mW7z"
        #expect(flujo.claveSugeridaPorElSistema)
        #expect(flujo.claveDeRegistroLista)

        // Si después se cambia la primera, hay que volver a confirmarla.
        flujo.claveDeRegistro = "Xk9-pQr2-mW7zA"
        #expect(!flujo.claveSugeridaPorElSistema)
        #expect(flujo.claveDeRegistroRepetida.isEmpty)
    }

    @Test("Tipear la confirmación letra por letra no cuenta como sugerida")
    func contrasenaTipeada() {
        let flujo = flujo()
        flujo.claveDeRegistro = "Trainer2026x"
        for largo in 1..."Trainer2026x".count {
            flujo.claveDeRegistroRepetida = String("Trainer2026x".prefix(largo))
        }
        #expect(!flujo.claveSugeridaPorElSistema)
        #expect(flujo.claveDeRegistroLista)
    }

    @Test("Volver dentro del registro retrocede UN paso, no deshace la historia")
    func volverEnElRegistro() {
        let flujo = flujo()
        flujo.ir(a: .regSexo)
        flujo.ir(a: .regCuerpo)
        flujo.ir(a: .regDeporte)

        flujo.volver()
        #expect(flujo.pantalla == .regCuerpo)
        flujo.volver()
        #expect(flujo.pantalla == .regSexo)
    }

    @Test("Volver desde el primer paso sale del registro")
    func volverDesdeElPrimerPaso() {
        let flujo = flujo()
        flujo.ir(a: .login)
        flujo.ir(a: .regCorreo)
        flujo.volver()
        #expect(flujo.pantalla == .login)
    }

    /// El bug de antes: cada paso se apilaba en el historial, y al retroceder hasta
    /// el correo la flecha llevaba a un paso intermedio.
    @Test("Retroceder hasta el correo y volver una vez más lleva a donde se empezó")
    func volverHastaElPrincipio() {
        let flujo = flujo()
        flujo.ir(a: .regCorreo)
        flujo.ir(a: .regCodigo)
        flujo.ir(a: .regAntesDeEmpezar)

        flujo.volver()
        flujo.volver()
        flujo.volver()
        #expect(flujo.pantalla == .bienvenida)
    }

    @Test("Del primer paso de perfil no se vuelve: la cuenta ya existe")
    func delPerfilNoSeVuelveAlAlta() {
        let flujo = flujo()
        flujo.ir(a: .regNacimiento)
        #expect(Pantalla.regNacimiento.cabecera == .soloAvance, "barra de avance, sin flecha")
        flujo.volver()
        #expect(flujo.pantalla == .regNacimiento)
    }

    @Test("Son ONCE pasos: crea tu cuenta, código, antes de empezar, siete de perfil y el apto")
    func pasosDelRegistro() {
        #expect(Pantalla.pasosDelRegistro.count == 11)
        #expect(Pantalla.pasosDelRegistro.first == .regCorreo)
        #expect(Pantalla.regAntesDeEmpezar.numeroDePaso == 3)
        #expect(Pantalla.regNacimiento.numeroDePaso == 4, "la barra NO se reinicia al crear la cuenta")
        #expect(Pantalla.regObjetivo.numeroDePaso == 9)
        #expect(Pantalla.regDias.numeroDePaso == 10)
        #expect(Pantalla.pasosDelRegistro.last == .regApto)
        #expect(Pantalla.pasosDePerfil.count == 8)
        // Las de afuera del registro no cuentan para la barra de avance.
        #expect(Pantalla.login.numeroDePaso == nil)
        #expect(Pantalla.bienvenida.esPasoDelRegistro == false)
    }

    @Test("«Completar después» aparece desde Deporte, y no en el apto")
    func completarDespues() {
        #expect(Pantalla.pasosDePerfil.filter(\.ofreceCompletarDespues)
                == [.regDeporte, .regNivel, .regObjetivo, .regDias])
        #expect(!Pantalla.regNacimiento.ofreceCompletarDespues)
        #expect(!Pantalla.regAntesDeEmpezar.ofreceCompletarDespues, "antes de crear la cuenta no hay a dónde entrar")
    }
}

@MainActor
@Suite("El flujo contra el servidor, con un doble")
struct FlujoContraElServidorTests {

    private let baires = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    private func flujo(_ doble: ServicioDePrueba) -> FlujoEntrada {
        let zona = baires
        return FlujoEntrada(servicio: doble, zonaHoraria: { zona }, reloj: { Fijo.ahoraMs })
    }

    /// Correo, código, contraseña y las dos casillas: deja el flujo en "Antes de
    /// empezar", listo para crear la cuenta.
    private func llegarAlAviso(_ flujo: FlujoEntrada) async {
        flujo.ir(a: .regCorreo)
        flujo.datos.nombre = "Persona"
        flujo.datos.apellido = "Ejemplo"
        flujo.datos.correo = " persona@ejemplo.com "
        // La contraseña va en el mismo paso que el correo (2026-10-21).
        flujo.claveDeRegistro = "Trainer2026x"
        flujo.claveDeRegistroRepetida = "Trainer2026x"
        await flujo.pedirCodigoDeRegistro()
        flujo.datos.codigo = "A7K2Q9"
        await flujo.verificarCodigoDeRegistro()
        await flujo.cargarLegalesSiFaltan()
        flujo.aceptoElAviso = true
        flujo.aceptoElDescargo = true
    }

    // MARK: - Arranque

    @Test("Con una sesión guardada se arranca en el Home; sin ella, en la bienvenida")
    func arranque() {
        #expect(flujo(ServicioDePrueba(Guion(habiaSesion: true))).pantalla == .home)
        #expect(flujo(ServicioDePrueba(Guion())).pantalla == .bienvenida)
    }

    // MARK: - Login

    @Test("Un login aceptado entra al Home")
    func loginAceptado() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .login)
        flujo.loginCorreo = " persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.pantalla == .home)
        #expect(flujo.loginClave.isEmpty, "la contraseña no queda en memoria después de usarla")
        #expect(await doble.pedidos == ["entrar:persona@ejemplo.com"])
    }

    @Test("Una contraseña equivocada es una alerta con «Intentar de nuevo» y nada más")
    func loginRechazado() async {
        var guion = Guion()
        guion.login = [.rechazado(codigo: "wrong_password", http: 401)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "mal"

        await flujo.entrar()

        #expect(flujo.pantalla == .login)
        #expect(flujo.alerta?.titulo == Textos.errorWrongPasswordTitle)
        #expect(flujo.alerta?.mensaje == Textos.errorWrongPassword)
        #expect(flujo.alerta?.botones.map(\.titulo) == [Textos.commonTryAgain])
        #expect(flujo.alerta?.botones.first?.rol == .cancelar)
    }

    @Test("Sin cuenta: «El usuario no existe», y «Crear cuenta» abre el alta con el correo escrito")
    func loginSinCuenta() async {
        var guion = Guion()
        guion.login = [.rechazado(codigo: "user_not_found", http: 404)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        let alerta = try? #require(flujo.alerta)
        #expect(alerta?.titulo == Textos.errorUserNotFoundTitle)
        #expect(alerta?.botonesOrdenados.map(\.titulo) == [Textos.commonCreateAccount, Textos.commonTryAgain],
                "cancelar va abajo")
        alerta?.botones.first { $0.titulo == Textos.commonCreateAccount }?.accion()
        #expect(flujo.pantalla == .regCorreo)
        #expect(flujo.datos.correo == "persona@ejemplo.com")
    }

    @Test("Una cuenta de Google sin contraseña lo dice con su proveedor")
    func loginSinContrasena() async {
        var guion = Guion()
        guion.login = [.rechazado(codigo: "password_not_set", http: 409,
                                  detalle: DatosDelError(provider: .google))]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.alerta?.titulo == Textos.errorPasswordNotSetTitle("Google"))
        #expect(flujo.alerta?.mensaje == Textos.errorPasswordNotSet("Google"))
    }

    @Test("Una cuenta desactivada ofrece reactivarla, y reactivar entra al Home")
    func loginDesactivada() async {
        var guion = Guion()
        guion.login = [.rechazado(codigo: "account_deactivated", http: 403,
                                  detalle: DatosDelError(reactivationToken: "permiso-reactivar"))]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.alerta?.titulo == Textos.accountDeactivatedTitle)
        #expect(flujo.alerta?.botonesOrdenados.map(\.titulo) == [Textos.accountReactivate, Textos.commonCancel])
        await flujo.reactivar(permiso: "permiso-reactivar")
        #expect(flujo.pantalla == .home)
        #expect(await doble.pedidos.last == "reactivarCuenta:permiso-reactivar")
    }

    @Test("Una cuenta por borrarse dice cuántos días faltan y ofrece recuperarla")
    func loginPorBorrarse() async {
        var guion = Guion()
        guion.login = [.rechazado(codigo: "account_pending_deletion", http: 403,
                                  detalle: DatosDelError(reactivationToken: "p", daysRemaining: 12))]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.alerta?.titulo == Textos.accountPendingDeletionTitle)
        #expect(flujo.alerta?.mensaje == Textos.accountPendingDeletionBody(12))
        #expect(flujo.alerta?.botonesOrdenados.map(\.titulo) == [Textos.accountRecover, Textos.commonCancel])
    }

    @Test("Demasiados intentos: una alerta con un solo «Ok»")
    func loginDemasiadosIntentos() async {
        var guion = Guion()
        guion.login = [.rechazado(codigo: "too_many_attempts", http: 429)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.alerta?.titulo == Textos.errorTooManyAttemptsTitle)
        #expect(flujo.alerta?.botones.map(\.titulo) == [Textos.commonOk])
    }

    @Test("Sin red es una alerta con el mensaje corto, no un cuelgue ni un crash")
    func loginSinRed() async {
        var guion = Guion()
        guion.login = [.sinRed]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"

        await flujo.entrar()

        #expect(flujo.alerta?.mensaje == Textos.errorOffline)
        #expect(flujo.errorVisible == Textos.errorOffline)
        #expect(!flujo.enCurso)
    }

    // MARK: - Alta

    @Test("El alta hace los pedidos del contrato, en orden, y la cuenta nace en el paso 3")
    func alta() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)

        await llegarAlAviso(flujo)
        #expect(flujo.pantalla == .regAntesDeEmpezar)
        await flujo.crearCuenta()

        #expect(flujo.pantalla == .regNacimiento)
        #expect(await doble.pedidos == ["pedirCodigoDeRegistro:persona@ejemplo.com",
                                        "verificarCodigoDeRegistro", "textosLegales", "completarRegistro"])
        #expect(await doble.altas == [ServicioDePrueba.Alta(token: "permiso-alta", clave: "Trainer2026x",
                                                            version: "1.0.0",
                                                            perfil: PerfilEntrada(firstName: "Persona", lastName: "Ejemplo",
                                                                                  medicalDisclaimerAccepted: true))],
                "el nombre y el descargo viajan con el alta; lo demás lo guardan los pasos de perfil")
        #expect(flujo.claveDeRegistro.isEmpty, "la contraseña se suelta apenas se usa")
    }

    @Test("Sin las dos casillas no se crea la cuenta")
    func casillas() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        await llegarAlAviso(flujo)
        flujo.aceptoElDescargo = false

        await flujo.crearCuenta()

        #expect(flujo.pantalla == .regAntesDeEmpezar)
        #expect(await doble.altas.isEmpty)
    }

    @Test("Una contraseña que el servidor rechaza al crear la cuenta vuelve a su paso, con el motivo")
    func contrasenaDebil() async {
        var guion = Guion()
        guion.altas = [.rechazado(codigo: "weak_password", http: 400)]
        let flujo = flujo(ServicioDePrueba(guion))
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()

        #expect(flujo.pantalla == .regCorreo, "la contraseña se elige con el correo")
        #expect(flujo.alerta?.mensaje == Textos.errorWeakPassword)
    }

    @Test("Si el aviso cambió, se baja el nuevo, se desmarca, y se acepta ESE")
    func avisoViejo() async {
        var guion = Guion()
        guion.legales = [.ok(Fijo.legales(version: "1.0.0")), .ok(Fijo.legales(version: "1.1.0"))]
        guion.altas = [.rechazado(codigo: "legal_version_stale", http: 409), .ok(Fijo.sesion)]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()

        #expect(flujo.pantalla == .regAntesDeEmpezar)
        #expect(flujo.legales?.version == "1.1.0")
        #expect(!flujo.aceptoElAviso, "aceptar un texto no es aceptar el que vino después")
        #expect(flujo.alerta?.titulo == Textos.errorLegalVersionStaleTitle)
        #expect(flujo.alerta?.mensaje == Textos.errorLegalVersionStale)

        flujo.aceptoElAviso = true
        await flujo.crearCuenta()
        #expect(await doble.altas.map(\.version) == ["1.0.0", "1.1.0"])
        #expect(flujo.pantalla == .regNacimiento)
    }

    @Test("Si el pedido de alta se corta, la salida es entrar, no volver al correo")
    func altaSinRed() async {
        var guion = Guion()
        guion.altas = [.sinRed]
        let flujo = flujo(ServicioDePrueba(guion))
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()

        #expect(flujo.ofrecerLogin)
        flujo.irAlLoginDesdeElAlta()
        #expect(flujo.pantalla == .login)
        #expect(flujo.loginCorreo == "persona@ejemplo.com")
    }

    @Test("Con el permiso vencido no se manda nada: «Se venció el registro» y Ok vuelve a «Crea tu cuenta»")
    func permisoDeAltaVencido() async {
        var guion = Guion()
        guion.verificacionDeRegistro = [.ok(TokenDeRegistro(registrationToken: "permiso-alta",
                                                            expiresAtMs: Fijo.ahoraMs - 1))]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()

        #expect(await doble.altas.isEmpty, "con el permiso vencido no se intenta")
        #expect(flujo.alerta?.titulo == Textos.errorInvalidRegistrationTokenTitle)
        #expect(!flujo.ofrecerLogin, "esa cuenta no existe: entrar no es una salida")

        flujo.alerta?.botones.first?.accion()

        #expect(flujo.pantalla == .regCorreo)
        #expect(flujo.datos.correo == " persona@ejemplo.com ", "el correo queda escrito")
        #expect(flujo.datos.nombre == "Persona")
        #expect(flujo.claveDeRegistro == "Trainer2026x", "con los datos escritos, también la contraseña")
        #expect(!flujo.aceptoElAviso)
    }

    /// 🛑 Vigente y rechazado: el permiso ya se usó y la cuenta existe. Volver al
    /// correo sería la trampa: a una dirección con cuenta el código no llega nunca.
    @Test("Con el permiso vigente, invalid_registration_token ofrece entrar, con su propio texto")
    func permisoDeAltaYaUsado() async {
        var guion = Guion()
        guion.altas = [.rechazado(codigo: "invalid_registration_token", http: 400)]
        let flujo = flujo(ServicioDePrueba(guion))
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()

        #expect(flujo.pantalla == .regAntesDeEmpezar)
        #expect(flujo.ofrecerLogin)
        #expect(flujo.alerta?.titulo == Textos.signupAccountExistsTitle)
        #expect(flujo.alerta?.mensaje == Textos.legalSignupAlreadyCreated)
    }

    @Test("Si un intento se cortó y el permiso venció después, «Se venció el registro» y entrar sigue a mano")
    func altaCortadaYDespuesVencida() async {
        var guion = Guion()
        guion.altas = [.sinRed]
        let hora = HoraDePrueba(Fijo.ahoraMs)
        let doble = ServicioDePrueba(guion)
        let flujo = FlujoEntrada(servicio: doble, zonaHoraria: { .gmt }, reloj: { hora.ms })
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()
        #expect(flujo.ofrecerLogin, "el intento cortado pudo haber creado la cuenta")

        hora.ms += 3_600_000
        await flujo.crearCuenta()

        #expect(flujo.alerta?.titulo == Textos.errorInvalidRegistrationTokenTitle,
                "el permiso venció: no se puede seguir")
        #expect(await doble.altas.count == 1, "con el permiso vencido no se manda otro intento")
    }

    @Test("conflict al crear la cuenta ofrece entrar, con un texto que no es el de ya tengo cuenta")
    func altaConCuentaExistente() async {
        var guion = Guion()
        guion.altas = [.rechazado(codigo: "conflict", http: 409)]
        let flujo = flujo(ServicioDePrueba(guion))
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()

        #expect(flujo.pantalla == .regAntesDeEmpezar)
        #expect(flujo.alerta?.titulo == Textos.errorEmailAlreadyRegisteredTitle)
        #expect(flujo.alerta?.mensaje != Textos.errorConflict, "no es el conflict de un guardado en curso")
        #expect(flujo.ofrecerLogin && flujo.laCuentaYaExiste)

        flujo.irAlLoginDesdeElAlta()
        #expect(flujo.pantalla == .login)
        #expect(flujo.loginCorreo == "persona@ejemplo.com")
    }

    @Test("Una respuesta rara al crear la cuenta se dice así, deja reintentar y ofrece entrar")
    func altaConRespuestaRara() async {
        var guion = Guion()
        guion.altas = [.respuestaRara(http: 502), .ok(Fijo.sesion)]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        await llegarAlAviso(flujo)

        await flujo.crearCuenta()

        #expect(flujo.pantalla == .regAntesDeEmpezar)
        #expect(flujo.errorVisible == Textos.errorUnexpectedResponse)
        #expect(flujo.ofrecerLogin, "la cuenta pudo crearse del otro lado")

        await flujo.crearCuenta()
        #expect(flujo.pantalla == .regNacimiento, "reintentar con el mismo permiso sigue valiendo")
        #expect(await doble.altas.map(\.token) == ["permiso-alta", "permiso-alta"])
    }

    // MARK: - Perfil

    @Test("Sin mover la rueda, «Continuar» en el nacimiento no guarda ni avanza")
    func nacimientoSinElegir() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .regNacimiento)

        await flujo.guardarYSeguir()

        #expect(flujo.pantalla == .regNacimiento)
        #expect(await doble.guardados.isEmpty, "una fecha que nadie eligió no llega al servidor")
    }

    @Test("Cada paso de perfil guarda con PATCH /me antes de avanzar")
    func pasoDePerfil() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .regNivel)
        flujo.datos.nivel = .avanzado

        await flujo.guardarYSeguir()

        #expect(flujo.pantalla == .regObjetivo)
        let guardado = await doble.guardados.first
        #expect(guardado?.perfil == PerfilEntrada(level: .avanzado))
        #expect(guardado?.anulando == [])
        #expect(flujo.perfil == Fijo.perfil)
    }

    @Test("Un guardado que falla no avanza, y el reintento lleva la MISMA clave")
    func reintentoMismaClave() async {
        var guion = Guion()
        guion.guardados = [.sinRed, .ok(Fijo.perfil)]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        flujo.ir(a: .regSexo)
        flujo.datos.sexo = .femenino

        await flujo.guardarYSeguir()
        #expect(flujo.pantalla == .regSexo)
        #expect(flujo.alerta?.mensaje == Textos.errorOffline)

        await flujo.guardarYSeguir()
        #expect(flujo.pantalla == .regCuerpo)

        let claves = await doble.guardados.map(\.clave)
        #expect(claves.count == 2)
        #expect(claves[0] == claves[1], "es el mismo intento: el servidor tiene que poder reconocerlo")
    }

    /// docs/API.md §6, el caso entero: femenino, atrás, masculino, atrás, femenino.
    /// El tercer pedido es byte a byte igual al primero. Con una clave derivada
    /// del cuerpo, el servidor contestaría la respuesta guardada sin escribir, y el
    /// perfil quedaría en masculino con la pantalla diciendo femenino.
    @Test("Volver atrás y elegir lo mismo de antes es OTRO intento: otra clave")
    func claveDelIntento() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .regSexo)

        for sexo in [SexoBiologico.femenino, .masculino, .femenino] {
            flujo.datos.sexo = sexo
            await flujo.guardarYSeguir()
            #expect(flujo.pantalla == .regCuerpo)
            flujo.volver()
        }

        let guardados = await doble.guardados
        #expect(guardados.map(\.perfil.biologicalSex) == [.femenino, .masculino, .femenino])
        #expect(Set(guardados.map(\.clave)).count == 3)
    }

    @Test("Cambiar el contenido después de un fallo también es otro intento")
    func cambioDeContenido() async {
        var guion = Guion()
        guion.guardados = [.sinRed, .ok(Fijo.perfil)]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        flujo.ir(a: .regSexo)
        flujo.datos.sexo = .femenino
        await flujo.guardarYSeguir()

        flujo.datos.sexo = .sinDeclarar
        await flujo.guardarYSeguir()

        let claves = await doble.guardados.map(\.clave)
        #expect(claves.count == 2)
        #expect(claves[0] != claves[1], "con otro cuerpo, la misma clave daría 409")
    }

    @Test("Los días viajan con la zona de la persona")
    func dias() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .regDias)
        flujo.datos.dias = [1: 7 * 60]

        await flujo.guardarYSeguir()

        #expect(flujo.pantalla == .regApto, "el apto es el último paso")
        #expect(await doble.guardados.first?.perfil.timezone == "America/Argentina/Buenos_Aires")

        flujo.terminarRegistro()
        #expect(flujo.pantalla == .home, "«Guardar» o «Lo subo después»: derecho al Inicio")
    }

    @Test("«Completar después» entra al Home con lo que ya se guardó")
    func completarDespues() {
        let flujo = flujo(ServicioDePrueba(Guion()))
        flujo.ir(a: .regDeporte)

        flujo.completarDespues()

        #expect(flujo.pantalla == .home)
    }

    @Test("Una sesión muerta en la mitad del perfil manda al login con el motivo, y olvida el perfil")
    func sesionMuertaEnElPerfil() async {
        var guion = Guion()
        guion.guardados = [.rechazado(codigo: "session_revoked", http: 401)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .regCuerpo)
        flujo.datos.pesoTexto = "72"
        flujo.datos.alturaTexto = "178"

        await flujo.guardarYSeguir()

        #expect(flujo.pantalla == .login)
        #expect(flujo.avisoDelLogin == Textos.errorSessionRevoked)
        #expect(flujo.datos == DatosRegistro(), "el peso es dato de salud: no queda en memoria")
    }

    // MARK: - Sesión

    /// 🛑 Antes, "Completar después" seguía prendido con el guardado en el aire: se
    /// entraba al Home y el error de ese guardado no lo veía nadie.
    @Test("Con un guardado en el aire, «Completar después» no sale, y el error se ve")
    func completarDespuesEsperaAlGuardado() async {
        let compuerta = Compuerta()
        var guion = Guion()
        guion.guardados = [.sinRed]
        guion.compuertaDeGuardado = compuerta
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .regCuerpo)
        flujo.datos.pesoTexto = "72"
        flujo.datos.alturaTexto = "178"

        let guardado = Task { await flujo.guardarYSeguir() }
        var intentos = 0
        while !compuerta.hayAlguienEsperando, intentos < 400 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            intentos += 1
        }
        #expect(flujo.enCurso)

        flujo.completarDespues()
        #expect(flujo.pantalla == .regCuerpo, "con el guardado en el aire no se sale")

        compuerta.abrir()
        await guardado.value
        #expect(flujo.pantalla == .regCuerpo)
        #expect(flujo.errorVisible == Textos.errorOffline)
    }

    // MARK: - Perfil a medio hacer

    private func perfil(nacimiento: Int64? = 898_646_400_000, sexo: SexoBiologico? = .masculino,
                        peso: Int64? = 72_000, altura: Int64? = 1_780, deporte: Deporte? = .running,
                        nivel: Nivel? = .intermedio, objetivo: Objetivo? = .mediaMaraton,
                        dias: [DiaEntrenamiento]? = [DiaEntrenamiento(weekday: 2, minuteOfDay: 1_110)],
                        zona: String? = "America/Argentina/Buenos_Aires") -> Perfil {
        Perfil(id: "u-1", email: "persona@ejemplo.com", birthdateMs: nacimiento, biologicalSex: sexo,
               weightG: peso, heightMm: altura, sport: deporte, level: nivel, goal: objetivo,
               trainingDays: dias, timezone: zona, createdAtMs: 1, updatedAtMs: 2)
    }

    @Test("El primer hueco del perfil sigue el orden de los pasos")
    func primerPasoFaltante() {
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil()) == nil)
        #expect(FlujoEntrada.primerPasoFaltante(en: Fijo.perfil) == .regNacimiento)
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil(sexo: nil, deporte: nil)) == .regSexo)
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil(altura: nil)) == .regCuerpo)
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil(deporte: nil)) == .regDeporte)
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil(nivel: nil)) == .regNivel)
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil(objetivo: nil)) == .regObjetivo)
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil(dias: [])) == .regDias)
        #expect(FlujoEntrada.primerPasoFaltante(en: perfil(zona: nil)) == .regDias, "una hora sin zona no es una hora")
    }

    /// 🛑 Antes, quien tocaba "Completar después" —o se quedaba sin señal a mitad del
    /// alta— entraba a un Home sin forma de volver a esos pasos.
    @Test("Un perfil a medio hacer se retoma desde el Home, de hueco en hueco, y vuelve al Home")
    func retomarElPerfil() async {
        var guion = Guion(habiaSesion: true)
        guion.perfiles = [.ok(perfil(sexo: nil, dias: nil))]
        guion.guardados = [.ok(perfil(dias: nil)), .ok(perfil())]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        #expect(flujo.pantalla == .home)

        await flujo.cargarPerfil()
        #expect(flujo.pasoPendienteDelPerfil == .regSexo)

        flujo.retomarPerfil()
        #expect(flujo.pantalla == .regSexo)

        flujo.datos.sexo = .femenino
        await flujo.guardarYSeguir()
        #expect(flujo.pantalla == .regDias, "lo que ya estaba guardado no se vuelve a pedir")

        await flujo.guardarYSeguir()
        #expect(flujo.pantalla == .home)
        #expect(flujo.pasoPendienteDelPerfil == nil)
        #expect(await doble.guardados.count == 2)
        #expect(!flujo.retomandoPerfil)
    }

    @Test("Sin GET /me todavía, el Home no ofrece completar nada")
    func sinPerfilNoSeOfreceNada() async {
        var guion = Guion(habiaSesion: true)
        guion.perfiles = [.sinRed]
        let flujo = flujo(ServicioDePrueba(guion))

        await flujo.cargarPerfil()
        flujo.retomarPerfil()

        #expect(flujo.pasoPendienteDelPerfil == nil, "sin perfil no se sabe qué falta: no se inventa un hueco")
        #expect(flujo.pantalla == .home)
    }

    @Test("Un cierre del renovador lleva al login con el motivo; cerrar a mano, a la bienvenida")
    func cierres() {
        let flujo = flujo(ServicioDePrueba(Guion(habiaSesion: true)))

        flujo.sesionCerrada(.rechazada(codigo: "invalid_refresh_token"))
        #expect(flujo.pantalla == .login)
        #expect(flujo.avisoDelLogin == Textos.errorInvalidRefreshToken)

        flujo.sesionCerrada(.laPersonaCerro)
        #expect(flujo.pantalla == .bienvenida)
        #expect(flujo.avisoDelLogin == nil)
    }

    @Test("El flujo escucha los cierres que publica el renovador")
    func escuchaLosCierres() async {
        let doble = ServicioDePrueba(Guion(habiaSesion: true))
        let flujo = flujo(doble)
        let escucha = Task { await flujo.escucharCierres() }
        defer { escucha.cancel() }

        var intentos = 0
        while await doble.suscriptores == 0, intentos < 200 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            intentos += 1
        }
        await doble.publicar(.rechazada(codigo: "session_revoked"))
        intentos = 0
        while flujo.pantalla != .login, intentos < 200 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            intentos += 1
        }

        #expect(flujo.pantalla == .login)
        #expect(flujo.avisoDelLogin == Textos.errorSessionRevoked)
    }

    /// 🛑 Lo que tipeó una persona no puede quedar en memoria para la siguiente:
    /// antes, la recuperación, las contraseñas del alta y la casilla del aviso
    /// sobrevivían al cierre de sesión. Y la bienvenida aparecía antes de borrar la
    /// sesión guardada.
    @Test("Cerrar sesión borra la sesión antes de cambiar de pantalla, y no deja nada tipeado")
    func cerrarSesion() async {
        let doble = ServicioDePrueba(Guion(habiaSesion: true))
        let flujo = flujo(doble)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.loginClave = "Trainer2026x"
        flujo.recuperacionCorreo = "persona@ejemplo.com"
        flujo.recuperacionCodigo = "A7K2Q9"
        flujo.claveNueva = "Trainer2027x"
        flujo.claveNuevaRepetida = "Trainer2027x"
        flujo.claveDeRegistro = "Trainer2026x"
        flujo.claveDeRegistroRepetida = "Trainer2026x"
        flujo.aceptoElAviso = true
        flujo.datos.pesoTexto = "72"

        var cerradaAlCambiarDePantalla: Bool?
        let observador = flujo.$pantalla.dropFirst().sink { _ in
            if cerradaAlCambiarDePantalla == nil { cerradaAlCambiarDePantalla = doble.sesionCerrada }
        }
        defer { observador.cancel() }

        await flujo.cerrarSesion()

        #expect(flujo.pantalla == .bienvenida)
        #expect(cerradaAlCambiarDePantalla == true, "la bienvenida no puede aparecer con la sesión guardada")
        #expect(await doble.pedidos == ["cerrarSesion"])
        #expect(flujo.loginCorreo.isEmpty && flujo.loginClave.isEmpty)
        #expect(flujo.recuperacionCorreo.isEmpty && flujo.recuperacionCodigo.isEmpty)
        #expect(flujo.claveNueva.isEmpty && flujo.claveNuevaRepetida.isEmpty)
        #expect(flujo.claveDeRegistro.isEmpty && flujo.claveDeRegistroRepetida.isEmpty)
        #expect(!flujo.aceptoElAviso)
        #expect(flujo.datos == DatosRegistro())
    }

    @Test("Salir del alta con la flecha no deja el correo, las contraseñas ni la casilla en memoria")
    func salirDelAltaOlvida() async {
        let flujo = flujo(ServicioDePrueba(Guion()))
        await llegarAlAviso(flujo)
        #expect(flujo.aceptoElAviso)

        flujo.volver()  // aviso → código (la contraseña va con el correo)
        flujo.volver()  // código → correo
        #expect(!flujo.datos.correo.isEmpty, "adentro del alta, volver no borra")
        flujo.volver()  // correo → bienvenida

        #expect(flujo.pantalla == .bienvenida)
        #expect(flujo.datos == DatosRegistro())
        #expect(flujo.claveDeRegistro.isEmpty && flujo.claveDeRegistroRepetida.isEmpty)
        #expect(!flujo.aceptoElAviso)
    }

    @Test("Del alta al login con la flecha: el alta se olvida y el correo del login queda")
    func delAltaAlLoginOlvida() {
        let flujo = flujo(ServicioDePrueba(Guion()))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.ir(a: .regCorreo)
        flujo.datos.correo = "otra@ejemplo.com"
        flujo.claveDeRegistro = "Trainer2026x"

        flujo.volver()

        #expect(flujo.pantalla == .login)
        #expect(flujo.datos == DatosRegistro())
        #expect(flujo.claveDeRegistro.isEmpty)
        #expect(flujo.loginCorreo == "persona@ejemplo.com")
    }

    @Test("Salir de la recuperación con la flecha no deja el código ni la contraseña nueva")
    func salirDeLaRecuperacionOlvida() async {
        let flujo = flujo(ServicioDePrueba(Guion()))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.irARecuperarClave()
        await flujo.pedirCodigoDeClave()
        flujo.recuperacionCodigo = "A7K2Q9"
        await flujo.verificarCodigoDeClave()
        flujo.claveNueva = "Trainer2027x"
        flujo.claveNuevaRepetida = "Trainer2027x"

        flujo.volver()  // contraseña nueva → código
        #expect(flujo.pantalla == .claveCodigo)
        #expect(!flujo.recuperacionCorreo.isEmpty, "adentro de la recuperación, volver no borra")
        flujo.volver()  // código → correo
        flujo.volver()  // correo → login

        #expect(flujo.pantalla == .login)
        #expect(flujo.recuperacionCorreo.isEmpty && flujo.recuperacionCodigo.isEmpty)
        #expect(flujo.claveNueva.isEmpty && flujo.claveNuevaRepetida.isEmpty)
        #expect(flujo.loginCorreo == "persona@ejemplo.com", "el login conserva su correo")
    }

    @Test("Un permiso de alta nuevo desmarca la casilla del aviso")
    func permisoNuevoDesmarcaElAviso() async {
        let flujo = flujo(ServicioDePrueba(Guion()))
        await llegarAlAviso(flujo)
        #expect(flujo.aceptoElAviso)

        flujo.volver()  // aviso → código (la contraseña va con el correo)
        await flujo.pedirCodigoDeRegistro()  // "Reenviar": el permiso de antes deja de valer

        #expect(!flujo.aceptoElAviso, "lo aceptado con otro permiso no vale para éste")
    }

    // MARK: - Recuperación

    @Test("Recuperar la contraseña usa sus tres pedidos y entra con la sesión nueva")
    func recuperacion() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"

        flujo.irARecuperarClave()
        #expect(flujo.recuperacionCorreo == "persona@ejemplo.com", "el correo del login viaja")
        await flujo.pedirCodigoDeClave()
        #expect(flujo.pantalla == .claveCodigo)
        flujo.recuperacionCodigo = "A7K2Q9"
        await flujo.verificarCodigoDeClave()
        #expect(flujo.pantalla == .claveNueva)
        flujo.claveNueva = "Trainer2027x"
        flujo.claveNuevaRepetida = "Trainer2027x"
        await flujo.guardarClaveNueva()

        // Sin pantalla final: una alerta pregunta por las otras sesiones.
        let alerta = try? #require(flujo.alerta)
        #expect(alerta?.titulo == Textos.passwordResetOtherSessionsTitle)
        #expect(alerta?.botonesOrdenados.map(\.titulo)
                == [Textos.passwordResetOtherSessionsClose, Textos.passwordResetOtherSessionsKeep])
        #expect(flujo.pantalla == .claveNueva)
        alerta?.botones.first { $0.titulo == Textos.passwordResetOtherSessionsKeep }?.accion()

        #expect(flujo.pantalla == .home)
        #expect(await doble.pedidos == ["pedirCodigoDeClave:persona@ejemplo.com",
                                        "verificarCodigoDeClave", "cambiarClave:permiso-clave"],
                "«Mantenerlas abiertas» no cierra nada")
    }

    @Test("«Cerrar las otras sesiones» las cierra y entra igual")
    func recuperacionCerrandoLasOtras() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        await llegarAClaveNueva(flujo)
        await flujo.guardarClaveNueva()

        flujo.alerta?.botones.first { $0.titulo == Textos.passwordResetOtherSessionsClose }?.accion()

        #expect(flujo.pantalla == .home)
        var intentos = 0
        while await !doble.pedidos.contains("cerrarOtrasSesiones"), intentos < 200 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            intentos += 1
        }
        #expect(await doble.pedidos.contains("cerrarOtrasSesiones"))
    }

    @Test("Si las dos contraseñas no coinciden, el rojo va debajo de la confirmación y no se manda nada")
    func recuperacionNoCoinciden() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        await llegarAClaveNueva(flujo)
        // Tipeadas a mano (no la sugerida del iPhone, que llena las dos iguales).
        flujo.claveNueva = "Trainer2027z"
        flujo.claveNuevaRepetida = "Trainer2027y"
        #expect(!flujo.claveNuevaSugeridaPorElSistema)
        #expect(flujo.puedeGuardarClaveNueva, "el botón se habilita con las tres reglas")

        await flujo.guardarClaveNueva()

        #expect(flujo.error(de: .claveRepetida) == Textos.fieldPasswordNoMatch)
        #expect(!(await doble.pedidos.contains { $0.hasPrefix("cambiarClave") }))
    }

    /// Deja el flujo en "contraseña nueva", con el permiso del código en la mano.
    private func llegarAClaveNueva(_ flujo: FlujoEntrada) async {
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.irARecuperarClave()
        await flujo.pedirCodigoDeClave()
        flujo.recuperacionCodigo = "A7K2Q9"
        await flujo.verificarCodigoDeClave()
        flujo.claveNueva = "Trainer2027x"
        flujo.claveNuevaRepetida = "Trainer2027x"
    }

    @Test("Con el permiso de la recuperación vencido, el error lo dice y no se entra")
    func recuperacionConPermisoVencido() async {
        var guion = Guion()
        guion.cambiosDeClave = [.rechazado(codigo: "invalid_reset_token", http: 400)]
        let flujo = flujo(ServicioDePrueba(guion))
        await llegarAClaveNueva(flujo)

        await flujo.guardarClaveNueva()

        #expect(flujo.pantalla == .claveNueva)
        #expect(flujo.alerta?.titulo == Textos.errorExpiredTitle)
        #expect(flujo.alerta?.mensaje == Textos.errorInvalidResetToken)
        flujo.alerta?.botones.first?.accion()
        #expect(flujo.pantalla == .claveCorreo, "«Ok» vuelve al principio")
        #expect(flujo.recuperacionCorreo == "persona@ejemplo.com", "con el correo escrito")
    }

    @Test("Una contraseña nueva que el servidor rechaza se queda, con el motivo, para corregirla")
    func recuperacionConClaveDebil() async {
        var guion = Guion()
        guion.cambiosDeClave = [.rechazado(codigo: "weak_password", http: 400), .ok(Fijo.sesion)]
        let doble = ServicioDePrueba(guion)
        let flujo = flujo(doble)
        await llegarAClaveNueva(flujo)

        await flujo.guardarClaveNueva()

        #expect(flujo.pantalla == .claveNueva)
        #expect(flujo.alerta?.mensaje == Textos.errorWeakPassword)
        #expect(flujo.claveNueva == "Trainer2027x", "lo escrito queda para corregirlo, no para tipearlo de nuevo")

        flujo.claveNueva = "Trainer2028x"
        flujo.claveNuevaRepetida = "Trainer2028x"
        await flujo.guardarClaveNueva()

        #expect(flujo.alerta?.titulo == Textos.passwordResetOtherSessionsTitle,
                "el mismo permiso sirve para el reintento")
        #expect(await doble.pedidos.filter { $0.hasPrefix("cambiarClave") }.count == 2)
    }

    @Test("Sin red en cada paso de la recuperación, se dice, no se avanza, y el reintento sigue")
    func recuperacionSinRed() async {
        var guion = Guion()
        guion.codigoDeClave = [.sinRed, .ok(Fijo.desafio)]
        guion.verificacionDeClave = [.sinRed, .ok(TokenDeReseteo(resetToken: "permiso-clave", expiresAtMs: 1))]
        guion.cambiosDeClave = [.sinRed, .ok(Fijo.sesion)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.irARecuperarClave()

        await flujo.pedirCodigoDeClave()
        #expect(flujo.pantalla == .claveCorreo)
        #expect(flujo.errorVisible == Textos.errorOffline)
        await flujo.pedirCodigoDeClave()
        #expect(flujo.pantalla == .claveCodigo)

        flujo.recuperacionCodigo = "A7K2Q9"
        await flujo.verificarCodigoDeClave()
        #expect(flujo.pantalla == .claveCodigo)
        #expect(flujo.errorVisible == Textos.errorOffline)
        await flujo.verificarCodigoDeClave()
        #expect(flujo.pantalla == .claveNueva)

        flujo.claveNueva = "Trainer2027x"
        flujo.claveNuevaRepetida = "Trainer2027x"
        await flujo.guardarClaveNueva()
        #expect(flujo.pantalla == .claveNueva)
        #expect(flujo.errorVisible == Textos.errorOffline)
        await flujo.guardarClaveNueva()
        #expect(flujo.alerta?.titulo == Textos.passwordResetOtherSessionsTitle)
    }

    // MARK: - Códigos

    @Test("Un código equivocado: «El código no es correcto», «Intentar de nuevo» y se sigue en la pantalla")
    func codigoEquivocado() async {
        var guion = Guion()
        guion.verificacionDeClave = [.rechazado(codigo: "invalid_code", http: 400)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .login)
        flujo.loginCorreo = "persona@ejemplo.com"
        flujo.irARecuperarClave()
        await flujo.pedirCodigoDeClave()
        flujo.recuperacionCodigo = "A7K2Q9"

        await flujo.verificarCodigoDeClave()

        #expect(flujo.alerta?.titulo == Textos.errorInvalidCodeTitle)
        #expect(flujo.alerta?.botones.map(\.titulo) == [Textos.commonTryAgain])
        #expect(!flujo.codigoAgotado, "un código equivocado todavía deja reenviar")
        #expect(flujo.pantalla == .claveCodigo)
    }

    @Test("Vencido o agotado: «Reenviar» desaparece y «Ok» vuelve al principio con el correo")
    func codigoVencidoYAgotado() async {
        for (codigo, titulo) in [("code_expired", Textos.errorCodeExpiredTitle),
                                 ("code_attempts_exceeded", Textos.errorCodeAttemptsExceededTitle)] {
            var guion = Guion()
            guion.verificacionDeClave = [.rechazado(codigo: codigo, http: 400)]
            let flujo = flujo(ServicioDePrueba(guion))
            flujo.ir(a: .login)
            flujo.loginCorreo = "persona@ejemplo.com"
            flujo.irARecuperarClave()
            await flujo.pedirCodigoDeClave()
            flujo.recuperacionCodigo = "A7K2Q9"

            await flujo.verificarCodigoDeClave()

            #expect(flujo.alerta?.titulo == titulo)
            #expect(flujo.codigoAgotado, "\(codigo): sin «Reenviar»")
            flujo.alerta?.botones.first?.accion()
            #expect(flujo.pantalla == .claveCorreo)
            #expect(flujo.recuperacionCorreo == "persona@ejemplo.com")
            #expect(!flujo.codigoAgotado)
        }
    }

    @Test("En el alta, el código vencido vuelve a «Crea tu cuenta» con los datos escritos")
    func codigoDelAltaVencido() async {
        var guion = Guion()
        guion.verificacionDeRegistro = [.rechazado(codigo: "code_expired", http: 400)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .regCorreo)
        flujo.datos.nombre = "Persona"
        flujo.datos.correo = "persona@ejemplo.com"
        flujo.claveDeRegistro = "Trainer2026x"
        flujo.claveDeRegistroRepetida = "Trainer2026x"
        await flujo.pedirCodigoDeRegistro()
        flujo.datos.codigo = "A7K2Q9"

        await flujo.verificarCodigoDeRegistro()

        #expect(flujo.alerta?.mensaje == Textos.errorCodeExpired)
        flujo.alerta?.botones.first?.accion()
        #expect(flujo.pantalla == .regCorreo)
        #expect(flujo.datos.nombre == "Persona" && flujo.datos.correo == "persona@ejemplo.com")
        #expect(flujo.claveDeRegistro == "Trainer2026x")
    }

    @Test("«Reenviar» cuenta desde la hora de envío: con la app en segundo plano, el tiempo igual pasa")
    func cuentaRegresivaDelReenvio() {
        let envio = Date(timeIntervalSince1970: 1_000)
        #expect(FilaDeReenvio.restantes(desde: envio, ahora: envio) == 60)
        #expect(FilaDeReenvio.restantes(desde: envio, ahora: envio.addingTimeInterval(45.4)) == 15)
        #expect(FilaDeReenvio.restantes(desde: envio, ahora: envio.addingTimeInterval(300)) == 0,
                "volver después de cinco minutos: ya se puede reenviar")
        #expect(FilaDeReenvio.restantes(desde: nil, ahora: envio) == 0)
    }

    @Test("Crear la cuenta con un correo ya registrado: alerta con «Iniciar sesión» que lleva el correo")
    func correoYaRegistrado() async {
        var guion = Guion()
        guion.codigoDeRegistro = [.rechazado(codigo: "email_already_registered", http: 409)]
        let flujo = flujo(ServicioDePrueba(guion))
        flujo.ir(a: .regCorreo)
        flujo.datos.nombre = "Persona"
        flujo.datos.correo = "persona@ejemplo.com"
        flujo.claveDeRegistro = "Trainer2026x"
        flujo.claveDeRegistroRepetida = "Trainer2026x"

        await flujo.pedirCodigoDeRegistro()

        #expect(flujo.alerta?.titulo == Textos.errorEmailAlreadyRegisteredTitle)
        #expect(flujo.alerta?.botonesOrdenados.map(\.titulo) == [Textos.commonSignIn, Textos.commonCancel])
        flujo.alerta?.botones.first { $0.titulo == Textos.commonSignIn }?.accion()
        #expect(flujo.pantalla == .login)
        #expect(flujo.loginCorreo == "persona@ejemplo.com")
    }

    @Test("Crear la cuenta con contraseñas distintas: el rojo debajo de la confirmación y no se pide el código")
    func altaNoCoinciden() async {
        let doble = ServicioDePrueba(Guion())
        let flujo = flujo(doble)
        flujo.ir(a: .regCorreo)
        flujo.datos.nombre = "Persona"
        flujo.datos.correo = "persona@ejemplo.com"
        flujo.claveDeRegistro = "Trainer2026x"
        flujo.claveDeRegistroRepetida = "Trainer2026y"
        #expect(flujo.puedePedirCodigoDeRegistro)

        await flujo.pedirCodigoDeRegistro()

        #expect(flujo.error(de: .claveRepetida) == Textos.fieldPasswordNoMatch)
        #expect(await doble.pedidos.isEmpty)
    }

    // MARK: - Vincular

    @Test("Google con el correo de una cuenta con contraseña ofrece vincular, y vincular entra")
    func vincular() async {
        var guion = Guion()
        guion.social = [.rechazado(codigo: "account_link_available", http: 409,
                                   detalle: DatosDelError(provider: .google, email: "persona@gmail.com",
                                                          linkToken: "permiso-vincular", requiresPassword: false))]
        let doble = ServicioDePrueba(guion)
        let flujo = FlujoEntrada(servicio: doble, iniciarConProveedor: { _ in
            .ok(CredencialDeProveedor(idToken: "id", nonce: "nonce-de-prueba-1234"))
        })
        flujo.ir(a: .login)

        await flujo.entrarCon(.google)

        let alerta = try? #require(flujo.alerta)
        #expect(alerta?.titulo == Textos.linkTitle("Google"))
        #expect(alerta?.mensaje == Textos.linkBody("persona@gmail.com", "Google"))
        #expect(alerta?.campo == nil, "Google es dueño del correo: no hace falta la contraseña")
        #expect(alerta?.botonesOrdenados.map(\.titulo) == [Textos.linkConfirm, Textos.commonNotNow])

        await flujo.vincular(.google, permiso: "permiso-vincular", correo: "persona@gmail.com", pideClave: false)
        #expect(flujo.pantalla == .home)
        #expect(await doble.pedidos.last == "vincularProveedor:permiso-vincular:-")
    }

    @Test("Si el proveedor no es dueño del correo, vincular pide la contraseña de la cuenta")
    func vincularConContrasena() async {
        var guion = Guion()
        guion.social = [.rechazado(codigo: "account_link_available", http: 409,
                                   detalle: DatosDelError(provider: .google, email: "persona@hotmail.com",
                                                          linkToken: "p", requiresPassword: true))]
        guion.vinculos = [.rechazado(codigo: "wrong_password", http: 401), .ok(Fijo.sesion)]
        let doble = ServicioDePrueba(guion)
        let flujo = FlujoEntrada(servicio: doble, iniciarConProveedor: { _ in
            .ok(CredencialDeProveedor(idToken: "id", nonce: "nonce-de-prueba-1234"))
        })
        flujo.ir(a: .login)

        await flujo.entrarCon(.google)
        #expect(flujo.alerta?.campo != nil)
        #expect(flujo.alerta?.mensaje == Textos.linkBodyPassword("persona@hotmail.com", "Google"))

        flujo.claveParaVincular = "mal"
        await flujo.vincular(.google, permiso: "p", correo: "persona@hotmail.com", pideClave: true)
        #expect(flujo.alerta?.titulo == Textos.errorWrongPasswordTitle)
        flujo.alerta?.botones.first?.accion()
        #expect(flujo.alerta?.titulo == Textos.linkTitle("Google"), "«Intentar de nuevo» vuelve a pedirla")

        flujo.claveParaVincular = "Trainer2026x"
        await flujo.vincular(.google, permiso: "p", correo: "persona@hotmail.com", pideClave: true)
        #expect(flujo.pantalla == .home)
        #expect(await doble.pedidos.suffix(2) == ["vincularProveedor:p:mal", "vincularProveedor:p:Trainer2026x"])
    }

    // MARK: - Desactivar

    @Test("Desactivar cierra la sesión, vuelve a la bienvenida y avisa cómo volver")
    func desactivar() async {
        let doble = ServicioDePrueba(Guion(habiaSesion: true))
        let flujo = flujo(doble)

        let error = await flujo.desactivarCuenta()

        #expect(error == nil)
        #expect(flujo.pantalla == .bienvenida)
        #expect(flujo.alerta?.titulo == Textos.accountDeactivatedTitle)
        #expect(flujo.alerta?.mensaje == Textos.accountDeactivatedDone)
        #expect(await doble.pedidos == ["desactivarCuenta", "cerrarSesion"])
    }

    // MARK: - Puerta de versión

    @Test("update_required cierra; update_recommended avisa una vez; pasar no muestra nada")
    func puertaDeVersion() async {
        let aviso = AvisoDeVersion(codigo: "update_required_security", mensaje: nil,
                                   tienda: URL(string: "https://apps.apple.com/app/id000"))

        let exigida = FlujoEntrada(servicio: ServicioDePrueba(Guion()),
                                   consultarVersion: { .exigirActualizar(aviso) })
        await exigida.consultarPuertaDeVersion()
        #expect(exigida.actualizacionRequerida == aviso)

        let recomendada = FlujoEntrada(servicio: ServicioDePrueba(Guion()),
                                       consultarVersion: { .recomendarActualizar(aviso) })
        await recomendada.consultarPuertaDeVersion()
        #expect(recomendada.actualizacionRequerida == nil)
        #expect(recomendada.actualizacionRecomendada == aviso)
        recomendada.recomendacionDescartada = true
        #expect(recomendada.actualizacionRecomendada == nil)

        let libre = FlujoEntrada(servicio: ServicioDePrueba(Guion()))
        await libre.consultarPuertaDeVersion()
        #expect(libre.actualizacionRequerida == nil && libre.actualizacionRecomendada == nil)
    }

    @Test("El aviso de versión usa el message del servidor si vino, y el texto propio si no")
    func textoDelAviso() {
        #expect(AvisoDeVersion(codigo: "x", mensaje: " Update Trainer ", tienda: nil)
                    .texto(generico: "genérico") == "Update Trainer")
        #expect(AvisoDeVersion(codigo: "x", mensaje: "  ", tienda: nil).texto(generico: "genérico") == "genérico")
        #expect(AvisoDeVersion(codigo: nil, mensaje: nil, tienda: nil).texto(generico: "genérico") == "genérico")
    }

    // MARK: - Errores

    @Test("Un code que la app no conoce se muestra con su nombre, no se traga")
    func codigoDesconocido() {
        #expect(TraductorDeErrores.texto(codigo: "algo_nuevo").contains("algo_nuevo"))
        #expect(TraductorDeErrores.texto(Resultado<Int>.respuestaRara(http: 502)) == Textos.errorUnexpectedResponse)
        #expect(TraductorDeErrores.texto(Resultado<Int>.rechazado(codigo: "session_revoked", http: 401))
                == Textos.errorSessionRevoked)
    }
}

@Suite("Lo que sólo existe adentro del simulador")
struct PlataformaTests {

    /// Cómo quedó guardado el ítem, leído del Keychain y no del código que lo guardó.
    private func accesibilidad(servicio: String) -> String? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(consulta as CFDictionary, &item) == errSecSuccess,
              let atributos = item as? [String: Any] else { return nil }
        return atributos[kSecAttrAccessible as String] as? String
    }

    /// El llavero de verdad, con un servicio propio para no pisar la sesión de la
    /// app que hospeda los tests. `swift test` no puede probar esto: en macOS, sin
    /// firmar, el llavero es otro.
    @Test("El llavero guarda, lee, pisa y borra la sesión")
    func llavero() throws {
        let almacen = AlmacenEnLlavero(servicio: "com.tecladus.Trainer.sesion.tests")
        almacen.borrar()
        #expect(almacen.leer() == nil)

        let una = Sesion(accessToken: "acceso-1", accessExpiresAtMs: 1, refreshToken: "refresco-1",
                         refreshExpiresAtMs: 2, userId: "u-1")
        let otra = Sesion(accessToken: "acceso-2", accessExpiresAtMs: 3, refreshToken: "refresco-2",
                          refreshExpiresAtMs: 4, userId: "u-1")

        let servicio = "com.tecladus.Trainer.sesion.tests"
        let esperada = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String

        try almacen.guardar(una)
        #expect(almacen.leer() == una)
        // 🛑 Después del primer desbloqueo —para renovar con el teléfono bloqueado en
        // el bolsillo— y SÓLO en este teléfono: no viaja en backups ni se restaura en
        // otro (AGENTS.md §12.1).
        #expect(accesibilidad(servicio: servicio) == esperada, "al crear el ítem")
        try almacen.guardar(otra)
        #expect(almacen.leer() == otra, "guardar de nuevo pisa: el refresh rota en cada uso")
        #expect(accesibilidad(servicio: servicio) == esperada, "al pisarlo, que es otro camino del Keychain")

        almacen.borrar()
        #expect(almacen.leer() == nil)
    }

    /// 🛑 Con `sin_declarar` no hay objetivos de nutrición y la hidratación usa el
    /// factor 1.0: no existe ningún "promedio de ambos". La pantalla no puede
    /// prometerlo, en ningún idioma. Se lee del catálogo compilado en la app.
    @Test("La pantalla del sexo no promete un promedio que el plan no calcula")
    func sexoSinPromesas() throws {
        for idioma in ["es", "en"] {
            let ruta = try #require(Bundle.main.path(forResource: idioma, ofType: "lproj"))
            let paquete = try #require(Bundle(path: ruta))
            // Desde 2026-10-22 las opciones no llevan texto debajo: queda el cuerpo.
            for clave in ["signup.sex.body"] {
                let texto = paquete.localizedString(forKey: clave, value: "∅", table: nil)
                #expect(texto != "∅", "falta \(clave) en \(idioma)")
                #expect(!texto.localizedCaseInsensitiveContains("promedio")
                        && !texto.localizedCaseInsensitiveContains("average"),
                        "\(clave) en \(idioma) promete un promedio")
            }
        }
    }

    /// `-apiBase http://127.0.0.1:8082/v1` (sólo en DEBUG) sirve para apuntar el
    /// simulador al backend local. Esto verifica que App Transport Security no lo
    /// frene sin una excepción en el `Info.plist` —que tocaría el `.pbxproj`—. El
    /// puerto 9 no tiene a nadie: lo que se espera es "no se pudo conectar", no
    /// "ATS lo bloqueó".
    @Test("App Transport Security deja hablarle por http al backend local del simulador")
    func atsDejaElBackendLocal() async {
        for host in ["127.0.0.1", "localhost"] {
            let pedido = URLRequest(url: URL(string: "http://\(host):9/v1/health")!, timeoutInterval: 5)
            do {
                _ = try await URLSession(configuration: .ephemeral).data(for: pedido)
            } catch let error as URLError {
                #expect(error.code != .appTransportSecurityRequiresSecureConnection,
                        "ATS bloquea http://\(host): -apiBase necesitaría https o una excepción")
            } catch {
                // Cualquier otro error no es de ATS.
            }
        }
    }
}

// MARK: - El doble

/// Lo que el doble contesta. Cada cola se consume en orden y la última respuesta
/// se repite: así un test puede fallar la primera vez y salir bien la segunda.
struct Guion: Sendable {
    var habiaSesion = false
    var login: [Resultado<SesionAbierta>] = [.ok(Fijo.sesion)]
    var codigoDeRegistro: [Resultado<DesafioCorreo>] = [.ok(Fijo.desafio)]
    var verificacionDeRegistro: [Resultado<TokenDeRegistro>] =
        [.ok(TokenDeRegistro(registrationToken: "permiso-alta", expiresAtMs: Fijo.ahoraMs + 600_000))]
    var altas: [Resultado<SesionAbierta>] = [.ok(Fijo.sesion)]
    var legales: [Resultado<TextosLegales>] = [.ok(Fijo.legales())]
    var guardados: [Resultado<Perfil>] = [.ok(Fijo.perfil)]
    var codigoDeClave: [Resultado<DesafioCorreo>] = [.ok(Fijo.desafio)]
    var verificacionDeClave: [Resultado<TokenDeReseteo>] =
        [.ok(TokenDeReseteo(resetToken: "permiso-clave", expiresAtMs: 1))]
    var cambiosDeClave: [Resultado<SesionAbierta>] = [.ok(Fijo.sesion)]
    var perfiles: [Resultado<Perfil>] = [.ok(Fijo.perfil)]
    var social: [Resultado<DesenlaceSocial>] = [.sinRed]
    var vinculos: [Resultado<SesionAbierta>] = [.ok(Fijo.sesion)]
    var reactivaciones: [Resultado<SesionAbierta>] = [.ok(Fijo.sesion)]
    var desactivaciones: [Resultado<SinCuerpo>] = [.ok(SinCuerpo())]
    /// Si está, cada guardado de perfil espera a que el test la abra.
    var compuertaDeGuardado: Compuerta?
}

/// Una espera que termina recién cuando el test la abre.
final class Compuerta: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var abierta = false
    private var esperando: [CheckedContinuation<Void, Never>] = []

    var hayAlguienEsperando: Bool {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return !esperando.isEmpty
    }

    func pasar() async {
        await withCheckedContinuation { (continuacion: CheckedContinuation<Void, Never>) in
            cerrojo.lock()
            if abierta {
                cerrojo.unlock()
                continuacion.resume()
            } else {
                esperando.append(continuacion)
                cerrojo.unlock()
            }
        }
    }

    func abrir() {
        cerrojo.lock()
        abierta = true
        let despertar = esperando
        esperando = []
        cerrojo.unlock()
        despertar.forEach { $0.resume() }
    }
}

/// Una marca que se lee desde cualquier hilo.
final class Marca: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var marcada = false

    var valor: Bool {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return marcada
    }

    func marcar() {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        marcada = true
    }
}

/// Una hora que el test mueve a mano.
final class HoraDePrueba {
    var ms: Int64

    init(_ ms: Int64) {
        self.ms = ms
    }
}

enum Fijo {
    /// "Ahora" para el flujo de los tests. El permiso del alta de `Guion` vence diez
    /// minutos después.
    static let ahoraMs: Int64 = 1_757_300_000_000
    static let sesion = SesionAbierta(usuario: "u-1")
    static let desafio = DesafioCorreo(expiresAtMs: 1, resendAfterMs: 2)
    static let perfil = Perfil(id: "u-1", email: "persona@ejemplo.com", createdAtMs: 1, updatedAtMs: 2)

    static func legales(version: String = "1.0.0") -> TextosLegales {
        let bloque = BloqueLegal(title: "Aviso", summary: "Resumen",
                                 sections: [SeccionLegal(title: "1", body: "Texto")],
                                 acceptance: "Leí el aviso")
        return TextosLegales(version: version, reviewed: false, healthNotice: bloque, terms: bloque)
    }
}

/// Un servidor de mentira para el flujo de entrada: contesta lo que diga el guion
/// y anota lo que le llegó. No hay red, ni llavero, ni `URLSession`.
actor ServicioDePrueba: ServicioDeCuenta {
    struct Guardado: Equatable, Sendable {
        let perfil: PerfilEntrada
        let anulando: Set<CampoAnulable>
        let clave: String
    }

    struct Alta: Equatable, Sendable {
        let token: String
        let clave: String
        let version: String
        let perfil: PerfilEntrada
    }

    nonisolated let habiaSesionAlArrancar: Bool
    private var guion: Guion

    private(set) var pedidos: [String] = []
    private(set) var guardados: [Guardado] = []
    private(set) var altas: [Alta] = []
    private var continuaciones: [UUID: AsyncStream<MotivoDeCierre>.Continuation] = [:]

    var suscriptores: Int { continuaciones.count }

    init(_ guion: Guion) {
        self.guion = guion
        self.habiaSesionAlArrancar = guion.habiaSesion
    }

    func publicar(_ motivo: MotivoDeCierre) {
        for continuacion in continuaciones.values { continuacion.yield(motivo) }
    }

    private static func siguiente<T>(_ cola: inout [T]) -> T {
        cola.count > 1 ? cola.removeFirst() : cola[0]
    }

    func salud() async -> Resultado<Health> { .sinRed }

    func textosLegales() async -> Resultado<TextosLegales> {
        pedidos.append("textosLegales")
        return Self.siguiente(&guion.legales)
    }

    func pedirCodigoDeRegistro(correo: String) async -> Resultado<DesafioCorreo> {
        pedidos.append("pedirCodigoDeRegistro:\(correo)")
        return Self.siguiente(&guion.codigoDeRegistro)
    }

    func verificarCodigoDeRegistro(correo: String, codigo: String) async -> Resultado<TokenDeRegistro> {
        pedidos.append("verificarCodigoDeRegistro")
        return Self.siguiente(&guion.verificacionDeRegistro)
    }

    func completarRegistro(token: String, clave: String, aceptacion: AceptacionLegal,
                           perfil: PerfilEntrada) async -> Resultado<SesionAbierta> {
        pedidos.append("completarRegistro")
        altas.append(Alta(token: token, clave: clave, version: aceptacion.version, perfil: perfil))
        return Self.siguiente(&guion.altas)
    }

    func entrar(correo: String, clave: String) async -> Resultado<SesionAbierta> {
        pedidos.append("entrar:\(correo)")
        return Self.siguiente(&guion.login)
    }

    func pedirCodigoDeClave(correo: String) async -> Resultado<DesafioCorreo> {
        pedidos.append("pedirCodigoDeClave:\(correo)")
        return Self.siguiente(&guion.codigoDeClave)
    }

    func verificarCodigoDeClave(correo: String, codigo: String) async -> Resultado<TokenDeReseteo> {
        pedidos.append("verificarCodigoDeClave")
        return Self.siguiente(&guion.verificacionDeClave)
    }

    func cambiarClave(token: String, clave: String) async -> Resultado<SesionAbierta> {
        pedidos.append("cambiarClave:\(token)")
        return Self.siguiente(&guion.cambiosDeClave)
    }

    func miPerfil() async -> Resultado<Perfil> {
        Self.siguiente(&guion.perfiles)
    }

    func guardarPerfil(_ perfil: PerfilEntrada, anulando: Set<CampoAnulable>,
                       claveDeIdempotencia: String) async -> Resultado<Perfil> {
        guardados.append(Guardado(perfil: perfil, anulando: anulando, clave: claveDeIdempotencia))
        if let compuerta = guion.compuertaDeGuardado { await compuerta.pasar() }
        return Self.siguiente(&guion.guardados)
    }

    func entrarConProveedor(_ proveedor: Proveedor, idToken: String, nonce: String) async -> Resultado<DesenlaceSocial> {
        pedidos.append("entrarConProveedor:\(proveedor.rawValue)")
        return Self.siguiente(&guion.social)
    }

    func vincularProveedor(permiso: String, clave: String?) async -> Resultado<SesionAbierta> {
        pedidos.append("vincularProveedor:\(permiso):\(clave ?? "-")")
        return Self.siguiente(&guion.vinculos)
    }

    func reactivarCuenta(permiso: String) async -> Resultado<SesionAbierta> {
        pedidos.append("reactivarCuenta:\(permiso)")
        return Self.siguiente(&guion.reactivaciones)
    }

    func cerrarOtrasSesiones() async -> Resultado<SinCuerpo> {
        pedidos.append("cerrarOtrasSesiones")
        return .ok(SinCuerpo())
    }

    func desactivarCuenta() async -> Resultado<SinCuerpo> {
        pedidos.append("desactivarCuenta")
        return Self.siguiente(&guion.desactivaciones)
    }

    func haySesion() async -> Bool { habiaSesionAlArrancar }

    /// Si ya se llamó a `cerrarSesion()`. Se lee sin `await`, en el instante exacto
    /// en que cambia la pantalla.
    nonisolated var sesionCerrada: Bool { marcaDeCierre.valor }
    private nonisolated let marcaDeCierre = Marca()

    func cerrarSesion() async {
        marcaDeCierre.marcar()
        pedidos.append("cerrarSesion")
    }

    func cierres() async -> AsyncStream<MotivoDeCierre> {
        let id = UUID()
        return AsyncStream { continuacion in
            continuaciones[id] = continuacion
        }
    }
}

@Suite("La maqueta del Home")
struct MaquetaDelHomeTests {

    @Test("El plan de ejemplo tiene días de hoy en adelante: no se da por vencido con el calendario")
    func cronogramaDesdeHoy() {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let hoy = calendario.date(from: DateComponents(year: 2027, month: 3, day: 10, hour: 9))!
        let dias = RepositorioProvisional.cronograma(de: RepositorioProvisional.bloqueMediaMaraton,
                                                     hoy: hoy, calendario: calendario)

        #expect(dias.count == 35, "cinco semanas de siete días")
        #expect(dias.contains { $0.fechaIso == "2027-03-10" }, "el día marcado como hoy cae hoy")
        #expect(dias.contains { $0.fechaIso > "2027-03-10" }, "hay días por delante")
        #expect(dias.first { $0.fechaIso == "2027-03-10" }?.tipo == "Fondo largo · 14 km")
    }
}
