import Foundation
import SwiftUI
import TrainerCore

// =============================================================================
// El estado del flujo de entrada: qué pantalla se ve, qué se juntó hasta ahora,
// y qué se le pide al servidor en cada paso.
//
// El orden es el del diseño (`Trainer App.dc.html`, arrays `ORDER` y `REG`) más
// los dos pasos que el diseño no tiene y el contrato exige, y los nombres son los
// slugs estables de `design/ESPECIFICACION.md` §4. Es el equivalente de
// `FlujoDeAcceso.kt` y `FlujoDeClave.kt` de Android: el mismo alta hace los
// mismos pedidos, en el mismo orden, en las dos plataformas.
//
// 🛑 El permiso del alta y el de la recuperación viven SÓLO en memoria, acá, y se
// sueltan apenas se usan (AGENTS.md §8). Los tokens de la sesión ni siquiera
// pasan por este archivo: los guarda `RenovadorDeSesion` en el llavero, y lo
// único que llega hasta acá es que se abrió una.
//
// 2026-10-22 (Iván, "Entrar y registrarse"): lo que sale mal se dice con una
// ALERTA con título y mensaje (`alerta`), no en rojo debajo del campo. El único
// rojo que queda es "Las contraseñas no coinciden", debajo de la confirmación y
// recién al tocar. Los botones se habilitan cuando lo escrito ya sirve (un correo
// válido, la contraseña con sus tres reglas): ya no se juzga el correo al tocar.
// =============================================================================

/// Las pantallas del flujo de entrada. La última —`home`— es el import de
/// `HomeB.dc.html`, que es otra pieza.
enum Pantalla: String, CaseIterable, Equatable {
    case bienvenida
    case login, claveCorreo, claveCodigo, claveNueva
    case regCorreo, regCodigo, regAntesDeEmpezar
    case regNacimiento, regSexo, regCuerpo
    case regDeporte, regNivel, regObjetivo, regDias, regApto
    case home

    /// Los ONCE pasos que cuenta la barra de avance (2026-10-22).
    ///
    /// ```
    ///  1 crea tu cuenta (nombre, apellido, correo, contraseña y su confirmación)
    ///  2 valida tu correo   3 antes de empezar          ← acá NACE la cuenta
    ///  4 nacimiento   5 sexo   6 peso y altura   7 deporte   8 nivel
    ///  9 objetivo  10 días y horarios                    ← un PATCH /me cada uno
    /// 11 tu apto físico (opcional, sólo en el teléfono)
    /// ```
    ///
    /// Con Google o Apple y el correo ya validado por el proveedor no hay código:
    /// son diez.
    ///
    /// 🛑 "Antes de empezar" no se puede saltear: sin las dos casillas no hay
    /// cuenta. Los pasos de perfil van DESPUÉS de crearla (decisión 0008). La
    /// barra NO se reinicia.
    static let pasosDelRegistro: [Pantalla] = [
        .regCorreo, .regCodigo, .regAntesDeEmpezar,
        .regNacimiento, .regSexo, .regCuerpo, .regDeporte, .regNivel,
        .regObjetivo, .regDias, .regApto,
    ]

    /// El primer paso con la cuenta ya creada.
    static let primerPasoDePerfil: Pantalla = .regNacimiento

    /// Los que corren con la cuenta ya creada.
    static let pasosDePerfil: [Pantalla] =
        Array(pasosDelRegistro.drop { $0 != primerPasoDePerfil })

    var esPasoDelRegistro: Bool { Pantalla.pasosDelRegistro.contains(self) }
    var esPasoDePerfil: Bool { Pantalla.pasosDePerfil.contains(self) }

    /// Los pasos del alta ANTES de que exista la cuenta. Salir de acá es
    /// abandonar el alta.
    var esDelAlta: Bool {
        [.regCorreo, .regCodigo, .regAntesDeEmpezar].contains(self)
    }

    var esDeLaRecuperacion: Bool {
        [.claveCorreo, .claveCodigo, .claveNueva].contains(self)
    }

    /// "Completar después" aparece desde Deporte (2026-10-22): nacimiento, sexo
    /// y cuerpo se completan sí o sí. El apto tiene su propio "Lo subo después".
    var ofreceCompletarDespues: Bool {
        esPasoDePerfil && ![.regNacimiento, .regSexo, .regCuerpo, .regApto].contains(self)
    }

    /// Qué lleva la cabecera. Está acá y no repartido por las pantallas porque
    /// la flecha de volver la dibuja **un solo lugar**: `RaizFlujoView`.
    enum Cabecera { case ninguna, soloVolver, volverYAvance, soloAvance }

    var cabecera: Cabecera {
        switch self {
        // Entradas y finales: de acá no se vuelve.
        case .bienvenida, .home:
            return .ninguna
        // El diseño les dibuja la flecha adentro de la pantalla; acá la pone el
        // andamio, que es lo mismo en pantalla y una sola implementación.
        case .login, .claveCorreo, .claveCodigo, .claveNueva:
            return .soloVolver
        // 🛑 El primer paso de perfil lleva la barra y NO la flecha: la cuenta ya
        // existe y atrás sólo hay pasos que mandarían un permiso consumido. Una
        // flecha deshabilitada se ve y no hace nada, que es peor que no tenerla.
        case .regNacimiento:
            return .soloAvance
        default:
            return esPasoDelRegistro ? .volverYAvance : .ninguna
        }
    }

    /// 1-based, para la barra. El diseño decidió **no mostrar el número**; se
    /// usa igual para VoiceOver, donde no hay barra que mirar.
    var numeroDePaso: Int? {
        Pantalla.pasosDelRegistro.firstIndex(of: self).map { $0 + 1 }
    }

    /// El paso que sigue, o `nil` si éste es el último o no es un paso del alta.
    var pasoSiguiente: Pantalla? {
        guard let i = Pantalla.pasosDelRegistro.firstIndex(of: self),
              Pantalla.pasosDelRegistro.indices.contains(i + 1) else { return nil }
        return Pantalla.pasosDelRegistro[i + 1]
    }
}

@MainActor
final class FlujoEntrada: ObservableObject {
    @Published private(set) var objetivosActivos: [ObjetivoDeUsuario] = []
    @Published private(set) var pantalla: Pantalla = .bienvenida {
        // El "no coinciden" es de la pantalla que lo mostró.
        didSet {
            if pantalla != oldValue, !erroresDeCampo.isEmpty { erroresDeCampo = [:] }
        }
    }

    /// Lo que juntan los pasos de perfil.
    ///
    /// 🛑 Cambiar el contenido cierra el intento de guardado en curso: la clave de
    /// idempotencia identifica el INTENTO, no el contenido (docs/API.md §6).
    @Published var datos = DatosRegistro() {
        didSet {
            if datos != oldValue { claveDeGuardado = nil }
        }
    }

    /// Los campos del login, de la recuperación y de la contraseña del alta viven
    /// aparte de `datos`: son otra conversación, y mezclarlos hace que volver
    /// atrás arrastre basura — o que una contraseña quede junto al perfil.
    @Published var loginCorreo = ""
    @Published var loginClave = ""
    @Published var recuperacionCorreo = ""
    @Published var recuperacionCodigo = ""
    @Published var claveNueva = "" {
        didSet {
            guard claveNueva != oldValue else { return }
            if Self.laLlenoElSistema(antes: oldValue, ahora: claveNueva, otra: claveNuevaRepetida) {
                claveNuevaSugeridaPorElSistema = true
            } else if claveNuevaSugeridaPorElSistema, claveNueva.isEmpty || claveNueva != claveNuevaRepetida {
                claveNuevaSugeridaPorElSistema = false
                claveNuevaRepetida = ""
            }
        }
    }
    @Published var claveNuevaRepetida = "" {
        didSet {
            if Self.laLlenoElSistema(antes: oldValue, ahora: claveNuevaRepetida, otra: claveNueva) {
                claveNuevaSugeridaPorElSistema = true
            }
        }
    }
    /// Igual que `claveSugeridaPorElSistema`, para la contraseña nueva.
    @Published private(set) var claveNuevaSugeridaPorElSistema = false

    /// 🪤 La "contraseña segura" del iPhone llena los dos campos de una vez, y el
    /// de confirmación queda con el valor pero se dibuja vacío (SwiftUI no repinta
    /// un SecureField que llenó el sistema). Tipeando, un campo nunca pasa de vacío
    /// a 12 caracteres o más iguales al otro: eso sólo lo hace el autocompletado.
    static func laLlenoElSistema(antes: String, ahora: String, otra: String) -> Bool {
        antes.isEmpty && ahora.count >= 12 && ahora == otra
    }
    @Published var claveDeRegistro = "" {
        didSet {
            guard claveDeRegistro != oldValue else { return }
            // El iPhone a veces llena primero la confirmación y después esta.
            if Self.laLlenoElSistema(antes: oldValue, ahora: claveDeRegistro, otra: claveDeRegistroRepetida) {
                claveSugeridaPorElSistema = true
                return
            }
            // Cambió la contraseña que sugirió el iPhone: hay que volver a confirmarla.
            if claveSugeridaPorElSistema, claveDeRegistro.isEmpty || claveDeRegistro != claveDeRegistroRepetida {
                claveSugeridaPorElSistema = false
                claveDeRegistroRepetida = ""
            }
        }
    }
    @Published var claveDeRegistroRepetida = "" {
        didSet {
            // El autocompletado del iPhone llena la confirmación de una vez, entera
            // e igual a la contraseña. Tipeando, nunca pasa de vacío a 12+ iguales.
            if Self.laLlenoElSistema(antes: oldValue, ahora: claveDeRegistroRepetida, otra: claveDeRegistro) {
                claveSugeridaPorElSistema = true
            }
        }
    }

    /// La casilla de los términos y la privacidad de "Antes de empezar". Arranca
    /// sin marcar: una aceptación por defecto no es una aceptación.
    @Published var aceptoElAviso = false
    /// La segunda casilla de "Antes de empezar": que Stamina no reemplaza a un
    /// profesional y que ante un síntoma se para y se consulta. Es lo que antes
    /// guardaba "Antes de arrancar" (`medical_disclaimer_accepted`), y viaja con
    /// el perfil inicial de la cuenta.
    @Published var aceptoElDescargo = false

    /// La contraseña que se escribe en la alerta de vincular, cuando el proveedor
    /// no es dueño del correo.
    @Published var claveParaVincular = ""

    @Published private(set) var enCurso = false
    /// Con qué proveedor se está entrando ahora: su botón muestra la ruedita.
    @Published private(set) var conectandoCon: Proveedor?
    /// El alta en curso empezó con Google o Apple: no se pide contraseña, y la
    /// cuenta se crea con el permiso social. Se suelta con el resto de la entrada.
    @Published private(set) var proveedorDelAlta: Proveedor?
    /// El permiso social venció en el último paso del alta: se ofrece volver a
    /// pasar por Google o Apple SIN perder el código ya validado ni las casillas.
    @Published private(set) var ofrecerRenovarSocial = false
    /// Google o Apple ya verificaron el correo: el alta NO pide código (sólo se
    /// valida con código a quien se registra con correo y contraseña). El campo
    /// del correo queda fijo: cambiarlo obligaría a validarlo.
    @Published private(set) var correoValidadoPorProveedor = false

    /// Los campos de los formularios de entrada que pueden mostrar un error debajo.
    enum CampoDelFormulario: Hashable {
        case claveRepetida
    }

    /// 2026-10-22: el único error debajo de un campo es "Las contraseñas no
    /// coinciden", al tocar el botón. Todo lo demás es una alerta.
    @Published private(set) var erroresDeCampo: [CampoDelFormulario: String] = [:]

    func error(de campo: CampoDelFormulario) -> String? { erroresDeCampo[campo] }

    /// Al editar un campo, su error se va: ya se lo está corrigiendo.
    func corrigiendo(_ campo: CampoDelFormulario) {
        if erroresDeCampo[campo] != nil { erroresDeCampo[campo] = nil }
    }

    /// La contraseña la puso el iPhone (contraseña segura sugerida): llena las dos
    /// a la vez, así que la confirmación sobra y se oculta. Si después se cambia la
    /// primera, vuelve a pedirse.
    @Published private(set) var claveSugeridaPorElSistema = false
    /// El texto del último error. Ya no se dibuja en ninguna pantalla —lo dice la
    /// alerta—, pero lo leen Ajustes y los tests.
    @Published var errorVisible: String?
    @Published var alertaSesionExpirada = false
    /// La alerta del flujo, si hay una a la vista (`RaizFlujoView` la presenta con
    /// `alertaApilada`). Una sola a la vez: la nueva reemplaza a la anterior.
    @Published var alerta: ContenidoDeAlerta?

    /// Una alerta con título, mensaje y "Ok".
    func mostrarAlerta(titulo: String, mensaje: String, alAceptar: @escaping () -> Void = {}) {
        alerta = ContenidoDeAlerta(titulo, mensaje: mensaje,
                                   botones: [BotonDeAlerta(Textos.commonOk, rol: .cancelar, accion: alAceptar)])
    }

    /// Lo que el login tiene que explicar cuando se llega de rebote —la sesión se
    /// cerró— y no por elección. Sin esto el login aparece solo y parece que la app
    /// se reinició.
    @Published private(set) var avisoDelLogin: String?

    /// El aviso de salud, los términos y la privacidad, con su versión. Bajan de
    /// `GET /legal` y los muestra la hoja legal; "Antes de empezar" usa la
    /// versión para dejar constancia de lo aceptado.
    @Published private(set) var legales: TextosLegales?
    @Published private(set) var cargandoLegales = false
    @Published private(set) var falloLegales = false

    /// Se prende cuando el alta ya no puede terminar y lo que corresponde es
    /// entrar: el permiso ya se usó, la cuenta ya existe, o el pedido se cortó y la
    /// cuenta pudo haberse creado igual del otro lado.
    @Published private(set) var ofrecerLogin = false

    /// El servidor dijo `conflict`: ya hay una cuenta con ese correo. La salida al
    /// login lleva su propio texto, porque no es "ya tengo cuenta" de quien la acaba
    /// de crear.
    @Published private(set) var laCuentaYaExiste = false

    /// Cambia cada vez que el servidor aceptó un pedido de código.
    @Published private(set) var pedidosDeCodigo = 0
    /// Cuándo el servidor aceptó el último pedido de código. La cuenta regresiva de
    /// "Reenviar" se calcula desde acá y no descontando de a un segundo: así sigue
    /// corriendo con la app en segundo plano.
    @Published private(set) var envioDelCodigo: Date?
    /// El código venció o se agotaron sus intentos: "Reenviar" desaparece y lo que
    /// queda es volver al principio.
    @Published private(set) var codigoAgotado = false

    @Published private(set) var decisionDeVersion: DecisionDeVersion = .pasar
    @Published var recomendacionDescartada = false

    /// El perfil guardado, tal como lo devolvió el servidor. Lo usa el Home.
    @Published private(set) var perfil: Perfil? {
        didSet {
            sincronizador.publicarUsuario(perfil?.id)
        }
    }

    /// Se está retomando desde el Home un perfil a medio hacer: los pasos van de
    /// hueco en hueco en vez de seguir el orden del alta, y al terminar se vuelve
    /// al Home.
    private(set) var retomandoPerfil = false

    /// La clave de idempotencia del guardado de perfil en curso (AGENTS.md §5.2).
    /// Se lee desde los tests para verificar que identifica el intento.
    private(set) var claveDeGuardado: String?

    let sincronizador: SincronizadorDeSesion
    private let servicio: any ServicioDeCuenta
    private let consultarVersion: @Sendable () async -> DecisionDeVersion
    private let zonaHoraria: () -> TimeZone
    private let reloj: () -> Int64

    private var historial: [Pantalla] = []
    /// El permiso del alta. 🛑 Otro permiso es otra alta: la casilla de los
    /// términos que se marcó con el anterior no vale para éste.
    private var tokenDeRegistro: String? {
        didSet { if tokenDeRegistro != oldValue { aceptoElAviso = false } }
    }
    /// Cuándo vence ese permiso (`expires_at_ms`). Es lo que deja leer un
    /// `invalid_registration_token`: vencido es "empezá de nuevo"; vigente es que
    /// el permiso ya se usó y la cuenta existe.
    private var vencimientoDelPermisoMs: Int64?
    /// Un intento de crear la cuenta terminó sin saber cómo —sin red o con una
    /// respuesta rara—: la cuenta pudo haberse creado del otro lado.
    private var altaSinDesenlace = false
    private var tokenDeReseteo: String?
    /// El permiso de `POST /auth/social` para terminar un alta con Google o Apple.
    /// 🛑 Sólo en memoria, como los otros permisos (AGENTS.md §8).
    private var permisoSocial: String?
    /// Cuándo vence `permisoSocial` (30 minutos).
    private var vencimientoSocialMs: Int64?
    /// El correo para el que se validó el código (`tokenDeRegistro`).
    private var correoDelPermiso: String?
    private let iniciarConProveedor: @MainActor (Proveedor) async -> DesenlaceDelProveedor

    /// - Parameters:
    ///   - servicio: el servidor de verdad (`ServiciosDeLaApp.reales()`) o un doble.
    ///   - consultarVersion: la puerta de versión. Por defecto deja pasar, que es
    ///     lo mismo que hace la puerta de verdad cuando no puede preguntar.
    ///   - reloj: la hora en milisegundos epoch, para saber si el permiso del alta
    ///     venció. Los tests la fijan.
    ///   - sincronizador: el puente de sincronización con el reloj.
    init(servicio: any ServicioDeCuenta,
         consultarVersion: @escaping @Sendable () async -> DecisionDeVersion = { .pasar },
         zonaHoraria: @escaping () -> TimeZone = { TimeZone.autoupdatingCurrent },
         reloj: @escaping () -> Int64 = RenovadorDeSesion.ahoraEnMs,
         sincronizador: SincronizadorDeSesion? = nil,
         iniciarConProveedor: @escaping @MainActor (Proveedor) async -> DesenlaceDelProveedor = {
             await InicioConProveedor.iniciar($0)
         }) {
        self.servicio = servicio
        self.iniciarConProveedor = iniciarConProveedor
        self.consultarVersion = consultarVersion
        self.zonaHoraria = zonaHoraria
        self.reloj = reloj
        let sinc = sincronizador ?? SincronizadorDeSesion(dispositivo: .telefono)
        self.sincronizador = sinc

        // Con una sesión guardada se entra derecho. La bienvenida es para quien
        // todavía no tiene cuenta, no para quien abre la app todos los días.
        if servicio.habiaSesionAlArrancar {
            pantalla = .home
        } else if servicio.sesionExpiradaAlArrancar {
            sinc.publicarUsuario(nil)
            pantalla = .login
            alertaSesionExpirada = true
        } else {
            sinc.publicarUsuario(nil)
        }

        // Sólo hace algo en DEBUG y sólo si hay argumentos de lanzamiento.
        if let pedida = ArranqueDePrueba.pantalla { pantalla = pedida }
        if let ejemplo = ArranqueDePrueba.datos { datos = ejemplo }
        if let credenciales = ArranqueDePrueba.credencialesDeEjemplo {
            loginCorreo = credenciales.correo
            loginClave = credenciales.clave
            recuperacionCorreo = credenciales.correo
            claveNueva = credenciales.clave
            claveNuevaRepetida = credenciales.clave
            claveDeRegistro = credenciales.clave
            claveDeRegistroRepetida = credenciales.clave
        }
    }

    // MARK: - Navegación

    func ir(a destino: Pantalla) {
        guard destino != pantalla else { return }
        // Dentro del alta, volver sigue el ORDEN de los pasos y no el historial.
        // Apilar cada paso hacía que, al retroceder hasta el correo, la flecha
        // llevara a un paso intermedio en vez de a donde se había empezado.
        if !(pantalla.esPasoDelRegistro && destino.esPasoDelRegistro) {
            historial.append(pantalla)
        }
        errorVisible = nil
        // Cambiar de paso cierra el intento de guardado del anterior.
        claveDeGuardado = nil
        pantalla = destino
    }

    /// Volver dentro del registro retrocede un paso; fuera de él, deshace la
    /// última navegación. Es lo que hace el diseño en su `go.back`.
    func volver() {
        // 🛑 Con un pedido en el aire no se vuelve. Si no, la respuesta del paso 8
        // llega con la pantalla ya en el 7 y el avance la tira al 9, salteando
        // justo la que se quería corregir. Misma regla que `FlujoDeAcceso.kt`.
        guard !enCurso else { return }
        errorVisible = nil
        claveDeGuardado = nil
        ofrecerLogin = false
        ofrecerRenovarSocial = false
        laCuentaYaExiste = false
        codigoAgotado = false
        if let paso = numeroDelPasoActual, paso > 1 {
            // 🛑 Del perfil no se vuelve al alta: la cuenta ya existe. La cabecera
            // del primer paso de perfil no tiene flecha; esto es la red de abajo.
            guard pantalla != Pantalla.primerPasoDePerfil else { return }
            pantalla = pasosDelAlta[paso - 2]
            return
        }
        let desde = pantalla
        let destino = historial.popLast() ?? .bienvenida
        // 🛑 Salir del alta o de la recuperación es abandonar ese trámite: lo que se
        // tipeó ahí no se queda en memoria esperando a quien use el teléfono después.
        if destino == .bienvenida {
            olvidarLoDeLaSesion()
            loginCorreo = ""
        } else if desde.esDelAlta && !destino.esDelAlta {
            olvidarLaEntrada()
            datos = DatosRegistro()
        } else if desde.esDeLaRecuperacion && !destino.esDeLaRecuperacion {
            olvidarLaEntrada()
        }
        pantalla = destino
    }

    /// Los pasos que cuenta la barra en ESTE alta. Con Google o Apple y el correo
    /// verificado no hay código: la barra cuenta sólo los pasos que de verdad hay.
    var pasosDelAlta: [Pantalla] {
        guard proveedorDelAlta != nil, correoValidadoPorProveedor else { return Pantalla.pasosDelRegistro }
        return Pantalla.pasosDelRegistro.filter { $0 != .regCodigo }
    }

    /// 1-based, para la barra y para VoiceOver.
    var numeroDelPasoActual: Int? {
        pasosDelAlta.firstIndex(of: pantalla).map { $0 + 1 }
    }

    /// Si la pantalla muestra flecha, volver **siempre** tiene a dónde ir: el paso
    /// anterior, lo último del historial, o la bienvenida.
    var puedeVolver: Bool {
        pantalla.cabecera == .soloVolver || pantalla.cabecera == .volverYAvance
    }

    // MARK: - Login

    func entrar() async {
        guard loginListo, !enCurso else { return }
        enCurso = true
        errorVisible = nil
        avisoDelLogin = nil
        let respuesta = await servicio.entrar(correo: Self.limpio(loginCorreo), clave: loginClave)
        enCurso = false
        if case .ok = respuesta {
            // La sesión ya quedó en el llavero: se entra aunque la persona haya
            // tocado otra cosa mientras el pedido viajaba.
            irAlHome()
            return
        }
        guard pantalla == .login else { return }
        errorVisible = TraductorDeErrores.texto(respuesta)
        switch respuesta.codigoDeRechazo {
        case "user_not_found":
            alertaUsuarioInexistente(correo: loginCorreo)
        case "wrong_password", "invalid_credentials":
            alertaClaveIncorrecta()
        case "password_not_set":
            let proveedor = respuesta.detalleDelRechazo?.provider.flatMap { Proveedor(rawValue: $0.rawValue) }
            if let proveedor {
                mostrarAlerta(titulo: Textos.errorPasswordNotSetTitle(proveedor.nombre),
                              mensaje: Textos.errorPasswordNotSet(proveedor.nombre))
            } else {
                mostrarAlertaDeError(respuesta, siNo: Textos.loginErrorTitle)
            }
        default:
            if !alertaDeCuenta(respuesta) {
                mostrarAlertaDeError(respuesta, siNo: Textos.loginErrorTitle)
            }
        }
    }

    /// "El usuario no existe", con la salida a crear la cuenta con ese correo.
    private func alertaUsuarioInexistente(correo: String) {
        alerta = ContenidoDeAlerta(
            Textos.errorUserNotFoundTitle, mensaje: Textos.errorUserNotFound,
            botones: [
                BotonDeAlerta(Textos.commonCreateAccount) { [weak self] in self?.crearCuentaCon(correo: correo) },
                BotonDeAlerta(Textos.commonTryAgain, rol: .cancelar),
            ])
    }

    private func alertaClaveIncorrecta(alReintentar: @escaping () -> Void = {}) {
        alerta = ContenidoDeAlerta(
            Textos.errorWrongPasswordTitle, mensaje: Textos.errorWrongPassword,
            botones: [BotonDeAlerta(Textos.commonTryAgain, rol: .cancelar, accion: alReintentar)])
    }

    /// "Crear cuenta" desde una alerta: el alta arranca con ese correo escrito.
    private func crearCuentaCon(correo: String) {
        let limpio = Self.limpio(correo)
        olvidarLaEntrada()
        datos = DatosRegistro()
        datos.correo = limpio
        ir(a: .regCorreo)
    }

    /// Lo que pasa al entrar —con correo, con Google o Apple, al vincular o al
    /// cambiar la contraseña— y no es de esa pantalla: la cuenta está desactivada
    /// o por borrarse, o se agotaron los intentos. `true` si lo atendió.
    private func alertaDeCuenta<Valor>(_ respuesta: Resultado<Valor>) -> Bool {
        switch respuesta.codigoDeRechazo {
        case "account_deactivated":
            guard let permiso = respuesta.detalleDelRechazo?.reactivationToken else { return false }
            alerta = ContenidoDeAlerta(
                Textos.accountDeactivatedTitle, mensaje: Textos.accountDeactivatedBody,
                botones: [
                    BotonDeAlerta(Textos.accountReactivate) { [weak self] in
                        Task { await self?.reactivar(permiso: permiso) }
                    },
                    BotonDeAlerta(Textos.commonCancel, rol: .cancelar),
                ])
            return true
        case "account_pending_deletion":
            guard let permiso = respuesta.detalleDelRechazo?.reactivationToken else { return false }
            let dias = Int(max(respuesta.detalleDelRechazo?.daysRemaining ?? 1, 1))
            alerta = ContenidoDeAlerta(
                Textos.accountPendingDeletionTitle, mensaje: Textos.accountPendingDeletionBody(dias),
                botones: [
                    BotonDeAlerta(Textos.accountRecover) { [weak self] in
                        Task { await self?.reactivar(permiso: permiso) }
                    },
                    BotonDeAlerta(Textos.commonCancel, rol: .cancelar),
                ])
            return true
        case "too_many_attempts":
            mostrarAlerta(titulo: Textos.errorTooManyAttemptsTitle, mensaje: Textos.errorTooManyAttempts)
            return true
        default:
            return false
        }
    }

    /// "Reactivar" o "Recuperar": `POST /auth/reactivate` y al Inicio.
    func reactivar(permiso: String) async {
        guard !enCurso else { return }
        enCurso = true
        let respuesta = await servicio.reactivarCuenta(permiso: permiso)
        enCurso = false
        if case .ok = respuesta {
            irAlHome()
        } else {
            mostrarAlertaDeError(respuesta, siNo: Textos.loginErrorTitle)
        }
    }

    // MARK: - Google y Apple

    /// "Continuar con Google / Apple". Si la persona ya tiene cuenta, entra. Si no,
    /// empieza el alta de siempre con lo que dio el proveedor ya escrito: nombre,
    /// apellido y correo, que la persona revisa; después el código al correo (si
    /// el proveedor no lo verificó), "Antes de empezar" y los pasos de perfil. Lo
    /// único que no se pide es contraseña.
    func entrarCon(_ proveedor: Proveedor) async {
        guard !enCurso else { return }
        enCurso = true
        conectandoCon = proveedor
        errorVisible = nil
        // `avisoDelLogin` (p. ej. "se venció la sesión") se deja: si la persona
        // cierra la hoja de Apple, la explicación tiene que seguir ahí.
        let desde = pantalla
        let desenlace = await iniciarConProveedor(proveedor)

        let credencial: CredencialDeProveedor
        switch desenlace {
        case .ok(let traida):
            credencial = traida
        case .cancelado:
            enCurso = false
            conectandoCon = nil
            return
        case .sinConfigurar:
            enCurso = false
            conectandoCon = nil
            mostrarAlerta(titulo: Textos.loginErrorTitle, mensaje: Textos.loginSocialNotConfigured)
            return
        case .fallo:
            enCurso = false
            conectandoCon = nil
            mostrarAlerta(titulo: Textos.loginErrorTitle, mensaje: Textos.loginSocialFailed)
            return
        }

        let respuesta = await servicio.entrarConProveedor(proveedor, idToken: credencial.idToken,
                                                          nonce: credencial.nonce)
        enCurso = false
        conectandoCon = nil
        switch respuesta {
        case .ok(.entro):
            irAlHome()
        case .ok(.faltaElAlta(let alta)):
            guard pantalla == desde else { return }
            empezarAltaSocial(proveedor, permiso: alta, credencial: credencial)
        default:
            guard pantalla == desde else { return }
            errorVisible = TraductorDeErrores.texto(respuesta)
            if respuesta.codigoDeRechazo == "account_link_available",
               let detalle = respuesta.detalleDelRechazo, let permiso = detalle.linkToken {
                ofrecerVincular(proveedor, permiso: permiso,
                                correo: detalle.email ?? credencial.correo ?? "",
                                pideClave: detalle.requiresPassword ?? true)
                return
            }
            if alertaDeCuenta(respuesta) { return }
            switch respuesta.codigoDeRechazo {
            case "provider_not_configured":
                mostrarAlerta(titulo: Textos.loginErrorTitle, mensaje: Textos.loginSocialNotConfigured)
            // Ese correo ya tiene cuenta y no se puede vincular.
            case "conflict":
                mostrarAlerta(titulo: Textos.loginErrorTitle, mensaje: Textos.loginSocialAccountExists)
            default:
                mostrarAlertaDeError(respuesta, siNo: Textos.loginErrorTitle)
            }
        }
    }

    /// 2026-10-22: quien ya tenía cuenta con correo y contraseña y toca "Continuar
    /// con Google/Apple" con el mismo correo puede vincular las dos. Si el
    /// proveedor no es dueño del correo, primero se pide la contraseña de la
    /// cuenta: si no, cualquiera con un Google armado con un correo ajeno entraría.
    private func ofrecerVincular(_ proveedor: Proveedor, permiso: String, correo: String, pideClave: Bool) {
        claveParaVincular = ""
        let campo = pideClave
            ? CampoDeAlerta(Textos.loginPasswordLabel,
                            texto: Binding(get: { [weak self] in self?.claveParaVincular ?? "" },
                                           set: { [weak self] in self?.claveParaVincular = $0 }),
                            seguro: true, teclado: .clave, contenido: .claveActual)
            : nil
        alerta = ContenidoDeAlerta(
            Textos.linkTitle(proveedor.nombre),
            mensaje: pideClave ? Textos.linkBodyPassword(correo, proveedor.nombre)
                               : Textos.linkBody(correo, proveedor.nombre),
            campo: campo,
            botones: [
                BotonDeAlerta(Textos.linkConfirm) { [weak self] in
                    Task { await self?.vincular(proveedor, permiso: permiso, correo: correo, pideClave: pideClave) }
                },
                BotonDeAlerta(Textos.commonNotNow, rol: .cancelar) { [weak self] in
                    self?.claveParaVincular = ""
                },
            ])
    }

    /// "Vincular": `POST /auth/social/link`, y al Inicio. Desde ahí la cuenta entra
    /// con la contraseña o con el proveedor.
    func vincular(_ proveedor: Proveedor, permiso: String, correo: String, pideClave: Bool) async {
        guard !enCurso else { return }
        let clave = pideClave ? claveParaVincular : nil
        claveParaVincular = ""
        enCurso = true
        conectandoCon = proveedor
        let respuesta = await servicio.vincularProveedor(permiso: permiso, clave: clave)
        enCurso = false
        conectandoCon = nil
        if case .ok = respuesta {
            irAlHome()
            return
        }
        errorVisible = TraductorDeErrores.texto(respuesta)
        switch respuesta.codigoDeRechazo {
        case "wrong_password", "invalid_credentials":
            // "Intentar de nuevo" vuelve a pedir la contraseña con el mismo permiso.
            alertaClaveIncorrecta { [weak self] in
                self?.ofrecerVincular(proveedor, permiso: permiso, correo: correo, pideClave: pideClave)
            }
        case "invalid_link_token":
            mostrarAlerta(titulo: Textos.errorExpiredTitle, mensaje: Textos.signupSocialExpired(proveedor.nombre))
        default:
            if !alertaDeCuenta(respuesta) {
                mostrarAlertaDeError(respuesta, siNo: Textos.loginErrorTitle)
            }
        }
    }

    /// El permiso social venció (más de 30 minutos en el alta). Se vuelve a pasar
    /// por el proveedor y, si sigue sin cuenta, se sigue con el permiso nuevo: el
    /// código del correo ya validado y las casillas siguen valiendo, así que no se
    /// vuelve a pedir nada. En "Antes de empezar" la cuenta se crea en el acto.
    func renovarPermisoSocial() async {
        guard let proveedor = proveedorDelAlta, !enCurso else { return }
        enCurso = true
        conectandoCon = proveedor
        errorVisible = nil
        let desenlace = await iniciarConProveedor(proveedor)
        guard case .ok(let credencial) = desenlace else {
            enCurso = false
            conectandoCon = nil
            switch desenlace {
            case .sinConfigurar:
                mostrarAlerta(titulo: Textos.signupErrorTitle, mensaje: Textos.loginSocialNotConfigured)
            case .fallo:
                mostrarAlerta(titulo: Textos.signupErrorTitle, mensaje: Textos.loginSocialFailed)
            case .cancelado, .ok:
                break
            }
            return
        }
        let respuesta = await servicio.entrarConProveedor(proveedor, idToken: credencial.idToken,
                                                          nonce: credencial.nonce)
        enCurso = false
        conectandoCon = nil
        switch respuesta {
        case .ok(.entro):
            // Mientras tanto la cuenta apareció (otro teléfono): se entra a ésa.
            irAlHome()
        case .ok(.faltaElAlta(let alta)):
            permisoSocial = alta.signupToken
            vencimientoSocialMs = alta.expiresAtMs
            ofrecerRenovarSocial = false
            // Si el proveedor ahora no verifica el correo, el alta sin código no
            // sirve: tiene que haber un código validado (`tokenDeRegistro`).
            if alta.emailVerified != true && tokenDeRegistro == nil {
                correoValidadoPorProveedor = false
                pantalla = .regCorreo
                return
            }
            ofrecerLogin = false
            if pantalla == .regAntesDeEmpezar { await crearCuenta() }
        default:
            errorVisible = TraductorDeErrores.texto(respuesta)
            if !alertaDeCuenta(respuesta) {
                mostrarAlertaDeError(respuesta, siNo: Textos.signupErrorTitle)
            }
        }
    }

    private func empezarAltaSocial(_ proveedor: Proveedor, permiso: AltaSocialPendiente,
                                   credencial: CredencialDeProveedor) {
        olvidarLaEntrada()
        var nuevos = DatosRegistro()
        nuevos.nombre = Self.limpio(credencial.nombre ?? "")
        nuevos.apellido = Self.limpio(credencial.apellido ?? "")
        nuevos.correo = Self.limpio(permiso.email ?? credencial.correo ?? "")
        datos = nuevos
        permisoSocial = permiso.signupToken
        vencimientoSocialMs = permiso.expiresAtMs
        proveedorDelAlta = proveedor
        correoValidadoPorProveedor = permiso.emailVerified == true && !(permiso.email ?? "").isEmpty
        ir(a: .regCorreo)
    }

    /// El primer paso de un alta con Google o Apple cuyo correo ya verificó el
    /// proveedor: con el nombre, derecho a "Antes de empezar". Sin código.
    func seguirConDatosDelProveedor() {
        guard correoValidadoPorProveedor, datos.identidadLista, !enCurso else { return }
        guard !permisoSocialVencido else { alertaSocialVencida(); return }
        ir(a: .regAntesDeEmpezar)
    }

    /// Si el permiso de Google/Apple ya venció, según el reloj del teléfono.
    private var permisoSocialVencido: Bool {
        guard permisoSocial != nil, let vence = vencimientoSocialMs else { return false }
        return reloj() >= vence
    }

    /// "Pasó demasiado tiempo · Vuelve a continuar con Google", con el botón para
    /// hacerlo. Con el permiso vencido no se puede validar, reenviar ni seguir.
    private func alertaSocialVencida() {
        guard let proveedor = proveedorDelAlta else { return }
        ofrecerRenovarSocial = true
        ofrecerLogin = false
        alerta = ContenidoDeAlerta(
            Textos.errorExpiredTitle, mensaje: Textos.signupSocialExpired(proveedor.nombre),
            botones: [
                BotonDeAlerta(Textos.signupSocialRetry(proveedor.nombre)) { [weak self] in
                    Task { await self?.renovarPermisoSocial() }
                },
                BotonDeAlerta(Textos.commonCancel, rol: .cancelar),
            ])
    }

    /// "Se venció el registro · Pasó demasiado tiempo. Empieza de nuevo." Con el
    /// permiso del alta vencido no se puede hacer nada más que volver a "Crea tu
    /// cuenta", con lo escrito.
    private func alertaRegistroVencido() {
        mostrarAlerta(titulo: Textos.errorInvalidRegistrationTokenTitle,
                      mensaje: Textos.errorInvalidRegistrationToken) { [weak self] in
            self?.volverAlPrincipioDelAlta()
        }
    }

    // MARK: - Alta: crea tu cuenta, valida tu correo, antes de empezar (pasos 1 a 3)

    /// Paso 1, y también "Reenviar" del paso 2: `POST /auth/register`.
    func pedirCodigoDeRegistro() async {
        guard !enCurso else { return }
        if pantalla == .regCorreo {
            // El botón ya exige nombre, correo válido y las tres reglas: lo único
            // que se juzga al tocar es que las dos contraseñas coincidan.
            guard puedePedirCodigoDeRegistro else { return }
            if proveedorDelAlta == nil, !claveSugeridaPorElSistema, !claveDeRegistroCoincide {
                erroresDeCampo[.claveRepetida] = Textos.fieldPasswordNoMatch
                return
            }
            erroresDeCampo = [:]
        }
        if permisoSocialVencido { alertaSocialVencida(); return }
        if pantalla == .regCodigo, tokenDeRegistro != nil, permisoVencido { alertaRegistroVencido(); return }
        // Volvió acá a corregir algo y el código de ESTE correo ya se validó con un
        // permiso vivo: pedir otro tiraría `code_resend_too_soon` y desmarcaría
        // las casillas.
        if pantalla == .regCorreo, tokenDeRegistro != nil, !permisoVencido,
           correoDelPermiso == Self.limpio(datos.correo).lowercased() {
            ir(a: .regAntesDeEmpezar)
            return
        }
        guard datos.correoValido else { return }
        let desde = pantalla
        enCurso = true
        errorVisible = nil
        let respuesta: Resultado<DesafioCorreo>
        if datos.nombreCompletoListo {
            respuesta = await servicio.pedirCodigoDeRegistro(
                correo: Self.limpio(datos.correo),
                nombre: Self.limpio(datos.nombre),
                apellido: Self.limpio(datos.apellido))
        } else {
            respuesta = await servicio.pedirCodigoDeRegistro(correo: Self.limpio(datos.correo))
        }
        enCurso = false
        guard pantalla == desde else { return }
        switch respuesta {
        case .ok:
            // Un código nuevo deja sin valor el permiso de uno anterior: si la
            // persona cambió el correo, ese permiso era de otra dirección.
            tokenDeRegistro = nil
            datos.codigo = ""
            codigoRecibido()
            if pantalla == .regCorreo { ir(a: .regCodigo) }
        case .rechazado(let codigo, _, _) where codigo == "email_already_registered":
            let correo = datos.correo
            alerta = ContenidoDeAlerta(
                Textos.errorEmailAlreadyRegisteredTitle, mensaje: Textos.errorEmailAlreadyRegistered,
                botones: [
                    BotonDeAlerta(Textos.commonSignIn) { [weak self] in self?.irAlLogin(conCorreo: correo) },
                    BotonDeAlerta(Textos.commonCancel, rol: .cancelar),
                ])
        default:
            errorVisible = TraductorDeErrores.texto(respuesta)
            if !alertaDeCodigo(respuesta, vencido: Textos.errorCodeExpired, alVolver: {}) {
                mostrarAlertaDeError(respuesta, siNo: Textos.signupErrorTitle)
            }
        }
    }

    /// Lo que habilita "Enviarme el código" (o "Continuar" con Google/Apple): el
    /// nombre, un correo válido y, sin proveedor, la contraseña con sus tres
    /// reglas. El apellido es opcional.
    var puedePedirCodigoDeRegistro: Bool {
        datos.identidadLista && datos.correoValido
            && (proveedorDelAlta != nil || reglasDeClaveDeRegistroCumplidas == 3)
    }

    private func codigoRecibido() {
        codigoAgotado = false
        envioDelCodigo = Date()
        pedidosDeCodigo += 1
    }

    /// Paso 2: `POST /auth/register/verify`, a cambio de un permiso de un solo uso.
    func verificarCodigoDeRegistro() async {
        guard datos.codigoCompleto, !enCurso, !codigoAgotado else { return }
        if permisoSocialVencido { alertaSocialVencida(); return }
        if tokenDeRegistro != nil, permisoVencido { alertaRegistroVencido(); return }
        enCurso = true
        errorVisible = nil
        let respuesta = await servicio.verificarCodigoDeRegistro(
            correo: Self.limpio(datos.correo), codigo: datos.codigo)
        enCurso = false
        guard pantalla == .regCodigo else { return }
        switch respuesta {
        case .ok(let permiso):
            tokenDeRegistro = permiso.registrationToken
            correoDelPermiso = Self.limpio(datos.correo).lowercased()
            vencimientoDelPermisoMs = permiso.expiresAtMs
            // Un código que llega y se verifica es de una dirección SIN cuenta: lo
            // que dejó un intento cortado ya no aplica.
            altaSinDesenlace = false
            ir(a: .regAntesDeEmpezar)
        default:
            errorVisible = TraductorDeErrores.texto(respuesta)
            if !alertaDeCodigo(respuesta, vencido: Textos.errorCodeExpired,
                               alVolver: { [weak self] in self?.volverAlPrincipioDelAlta() }) {
                mostrarAlertaDeError(respuesta, siNo: Textos.signupErrorTitle)
            }
        }
    }

    /// Las alertas de un código equivocado, vencido o agotado, iguales en el alta
    /// y en la recuperación. Con el código vencido o agotado "Reenviar" desaparece
    /// y "Ok" vuelve al principio: ese código ya no sirve. `true` si la atendió.
    private func alertaDeCodigo<Valor>(_ respuesta: Resultado<Valor>, vencido: String,
                                       alVolver: @escaping () -> Void) -> Bool {
        switch respuesta.codigoDeRechazo {
        case "invalid_code":
            alerta = ContenidoDeAlerta(Textos.errorInvalidCodeTitle, mensaje: Textos.errorInvalidCode,
                                       botones: [BotonDeAlerta(Textos.commonTryAgain, rol: .cancelar)])
            return true
        case "code_expired":
            codigoAgotado = true
            mostrarAlerta(titulo: Textos.errorCodeExpiredTitle, mensaje: vencido, alAceptar: alVolver)
            return true
        case "code_attempts_exceeded":
            codigoAgotado = true
            mostrarAlerta(titulo: Textos.errorCodeAttemptsExceededTitle,
                          mensaje: Textos.errorCodeAttemptsExceeded, alAceptar: alVolver)
            return true
        case "code_resend_too_soon":
            mostrarAlerta(titulo: Textos.errorCodeResendTooSoonTitle, mensaje: Textos.errorCodeResendTooSoon)
            return true
        default:
            return false
        }
    }

    /// "Ok" de un código o un permiso que ya no sirve: de vuelta a "Crea tu
    /// cuenta" con lo que se escribió —nombre, apellido, correo y contraseña—. Con
    /// Google o Apple, el permiso social y el proveedor siguen.
    func volverAlPrincipioDelAlta() {
        guard !enCurso else { return }
        tokenDeRegistro = nil
        correoDelPermiso = nil
        vencimientoDelPermisoMs = nil
        datos.codigo = ""
        codigoAgotado = false
        ofrecerLogin = false
        laCuentaYaExiste = false
        errorVisible = nil
        pantalla = .regCorreo
    }

    func cargarLegalesSiFaltan() async {
        guard legales == nil else { return }
        await cargarLegales()
    }

    func cargarLegales() async {
        guard !cargandoLegales else { return }
        cargandoLegales = true
        falloLegales = false
        let respuesta = await servicio.textosLegales()
        cargandoLegales = false
        guard case .ok(let textos) = respuesta else {
            falloLegales = legales == nil
            return
        }
        // Otra versión es otro texto: lo aceptado antes no vale para éste.
        if let anterior = legales?.version, textos.version != anterior { aceptoElAviso = false }
        legales = textos
    }

    /// Lo que habilita "Crear mi cuenta": las dos casillas.
    var puedeCrearCuenta: Bool { aceptoElAviso && aceptoElDescargo }

    /// Paso 3: `POST /auth/register/complete`. Acá nace la cuenta.
    ///
    /// `perfil` lleva el nombre y la constancia del descargo médico; el resto lo
    /// guardan los pasos de perfil después, de a uno (decisión 0008).
    func crearCuenta() async {
        guard !enCurso, puedeCrearCuenta else { return }
        if permisoSocialVencido { alertaSocialVencida(); return }
        // Con Google/Apple y el correo ya verificado no hay permiso de código.
        let sinCodigo = permisoSocial != nil && correoValidadoPorProveedor
        guard sinCodigo || tokenDeRegistro != nil else {
            // No debería pasar: a este paso se llega con el permiso del código. Si
            // pasa, se vuelve al correo en vez de mandar un pedido que no puede andar.
            volverAlPrincipioDelAlta()
            return
        }
        if !sinCodigo, permisoVencido { alertaRegistroVencido(); return }
        // La versión de los textos es lo que queda como constancia: sin ella no
        // se puede aceptar nada. La pantalla se ve sin señal; la cuenta, no.
        if legales == nil {
            enCurso = true
            await cargarLegales()
            enCurso = false
        }
        guard let legales else {
            mostrarAlerta(titulo: Textos.errorOfflineTitle, mensaje: Textos.errorOffline)
            return
        }
        let token = tokenDeRegistro
        enCurso = true
        errorVisible = nil
        let aceptacion = AceptacionLegal(version: legales.version, accepted: true)
        // El nombre y el apellido ya se pidieron con el correo: viajan acá y no
        // en un paso de perfil aparte. El descargo es la segunda casilla.
        let apellido = DatosRegistro.recortado(datos.apellido)
        let nombre = DatosRegistro.recortado(datos.nombre)
        let perfilInicial = PerfilEntrada(firstName: nombre.isEmpty ? nil : nombre,
                                          lastName: apellido.isEmpty ? nil : apellido,
                                          medicalDisclaimerAccepted: true)
        let respuesta: Resultado<SesionAbierta>
        if let permisoSocial {
            respuesta = await servicio.completarRegistroSocial(
                token: token, permisoSocial: permisoSocial, aceptacion: aceptacion, perfil: perfilInicial)
        } else {
            respuesta = await servicio.completarRegistro(
                token: token ?? "", clave: claveDeRegistro, aceptacion: aceptacion, perfil: perfilInicial)
        }
        enCurso = false

        switch respuesta {
        case .ok:
            // 🛑 La cuenta ya existe. El permiso se consumió y la contraseña ya no
            // hace falta en memoria (§8). De acá no se vuelve al alta.
            tokenDeRegistro = nil
            permisoSocial = nil
            vencimientoSocialMs = nil
            ofrecerRenovarSocial = false
            vencimientoDelPermisoMs = nil
            altaSinDesenlace = false
            claveDeRegistro = ""
            claveDeRegistroRepetida = ""
            ofrecerLogin = false
            laCuentaYaExiste = false
            errorVisible = nil
            claveDeGuardado = nil
            historial.removeAll()
            pantalla = Pantalla.primerPasoDePerfil
        case .rechazado(let codigo, _, _) where codigo == "legal_version_stale":
            // El texto cambió mientras tanto. Se baja el nuevo y se desmarca la
            // casilla: reintentar con la versión vieja sería dar por aceptado algo
            // que la persona no leyó.
            aceptoElAviso = false
            await cargarLegales()
            aceptoElAviso = false
            mostrarAlerta(titulo: Textos.errorLegalVersionStaleTitle, mensaje: Textos.errorLegalVersionStale)
        case .rechazado(let codigo, _, _) where codigo == "weak_password":
            // Con la 1.6.0 no debería pasar: el botón ya exige las tres reglas.
            pantalla = .regCorreo
            mostrarAlertaDeError(respuesta, siNo: Textos.signupErrorTitle)
        case .rechazado(let codigo, _, _) where codigo == "invalid_signup_token":
            // Pasaron más de 30 minutos desde "Continuar con Google / Apple". El
            // código del correo NO se gastó (el servidor mira esto antes).
            alertaSocialVencida()
        case .rechazado(let codigo, _, _) where codigo == "invalid_registration_token":
            if permisoVencido {
                alertaRegistroVencido()
            } else {
                // 🛑 Vigente y rechazado: el permiso ya se usó, así que la cuenta SÍ
                // se creó y la respuesta no llegó. Volver al correo sería una trampa
                // —`POST /auth/register` contesta "ya registrado"—. La salida es entrar.
                errorVisible = Textos.legalSignupAlreadyCreated
                mostrarAlerta(titulo: Textos.signupAccountExistsTitle, mensaje: Textos.legalSignupAlreadyCreated)
                ofrecerLogin = true
            }
        case .rechazado(let codigo, _, _) where codigo == "conflict":
            // Ya hay una cuenta con ese correo, y pedir otro código no la cambia.
            // No es el `conflict` de un guardado en curso: el texto es otro.
            mostrarAlerta(titulo: Textos.errorEmailAlreadyRegisteredTitle,
                          mensaje: Textos.errorEmailAlreadyRegistered)
            laCuentaYaExiste = true
            ofrecerLogin = true
        case .sinRed, .respuestaRara:
            // No se sabe cómo terminó: la cuenta pudo crearse del otro lado sin que
            // la respuesta volviera. Reintentar con el mismo permiso sigue valiendo,
            // y entrar es la otra salida.
            altaSinDesenlace = true
            errorVisible = TraductorDeErrores.texto(respuesta)
            mostrarAlertaDeError(respuesta, siNo: Textos.signupErrorTitle)
            ofrecerLogin = true
        default:
            errorVisible = TraductorDeErrores.texto(respuesta)
            mostrarAlertaDeError(respuesta, siNo: Textos.signupErrorTitle)
        }
    }

    /// Si el permiso del alta ya venció, según el reloj del teléfono. Sin fecha se lo
    /// da por vencido: pedir otro código siempre es una salida posible.
    private var permisoVencido: Bool {
        guard let vence = vencimientoDelPermisoMs else { return true }
        return reloj() >= vence
    }

    func irAlLoginDesdeElAlta() {
        irAlLogin(conCorreo: datos.correo)
    }

    /// "Iniciar sesión" desde una alerta: el login con ese correo escrito.
    private func irAlLogin(conCorreo correo: String) {
        let limpio = Self.limpio(correo)
        irAlLogin(aviso: nil)
        loginCorreo = limpio
    }

    // MARK: - Perfil (pasos 4 a 11)

    /// Guarda lo de ESTE paso con `PATCH /me` y avanza.
    ///
    /// Si el servidor dice que no, **no avanza**: la alerta lo dice y el botón
    /// vuelve a estar disponible para reintentar con la misma clave. Quien no
    /// pueda pasar de ahí tiene "Completar después" (desde Deporte).
    func guardarYSeguir() async {
        let actual = pantalla
        guard actual.esPasoDePerfil, !enCurso, datos.puedeSeguir(en: actual) else { return }
        guard let cambios = datos.loQueGuarda(en: actual, zonaHoraria: zonaHoraria()) else {
            avanzar(desde: actual)
            return
        }

        // 🛑 Una clave por INTENTO (docs/API.md §6). Se crea al arrancar un
        // guardado y se conserva mientras ESE guardado se pueda reintentar, así
        // que tocar "Continuar" dos veces con mala señal escribe una sola vez. La
        // sueltan el éxito, un cambio de contenido y un cambio de paso. Derivarla
        // del cuerpo haría que volver atrás y elegir lo mismo de antes reusara la
        // clave del primer intento: el servidor contestaría la respuesta guardada
        // sin escribir, y el perfil quedaría en un valor que la pantalla no muestra.
        let clave = claveDeGuardado ?? UUID().uuidString
        claveDeGuardado = clave
        enCurso = true
        errorVisible = nil
        let respuesta = await servicio.guardarPerfil(
            cambios, anulando: datos.camposEnNull(en: actual), claveDeIdempotencia: clave)
        enCurso = false

        switch respuesta {
        case .ok(let guardado):
            perfil = guardado
            if actual == .regObjetivo, let principal = datos.objetivo {
                let fechaMs = datos.fechaObjetivo.map {
                    DatosRegistro.fechaDelCalendarioEnMs($0, zona: zonaHoraria())
                }
                let lista = [ObjetivoDeUsuario(id: "principal", goal: principal, goalDateMs: fechaMs)] +
                    datos.objetivosAdicionales.map { ObjetivoDeUsuario(id: "", goal: $0, goalDateMs: nil) }
                enCurso = true
                let guardadoDeObjetivos = await servicio.guardarObjetivos(lista)
                enCurso = false
                guard case .ok(let recibidos) = guardadoDeObjetivos else {
                    if pantalla == actual {
                        errorVisible = TraductorDeErrores.texto(guardadoDeObjetivos)
                        mostrarAlertaDeError(guardadoDeObjetivos, siNo: Textos.signupErrorTitle)
                    }
                    return
                }
                objetivosActivos = recibidos
            }
            if claveDeGuardado == clave { claveDeGuardado = nil }
            // Si mientras viajaba la persona se fue a otro lado, no se la arrastra.
            if pantalla == actual { avanzar(desde: actual) }
        case .rechazado(let codigo, _, _) where Self.codigosDeSesionMuerta.contains(codigo):
            // El renovador ya intentó renovar y no pudo. Quedarse acá con el cartel
            // no tiene salida: se manda al login, que es lo único que reabre una
            // sesión. Se pierde lo que no se guardó, no lo anterior.
            irAlLogin(aviso: TraductorDeErrores.texto(respuesta))
        default:
            if pantalla == actual {
                errorVisible = TraductorDeErrores.texto(respuesta)
                mostrarAlertaDeError(respuesta, siNo: Textos.signupErrorTitle)
            }
        }
    }

    /// Entra a la app con lo que sí se guardó. El contrato no exige ningún campo
    /// del perfil, y el motor sabe pedir lo que le falte (`profile_incomplete`).
    ///
    /// 🛑 Con un guardado en el aire no se sale: la respuesta llegaría con el Home ya
    /// a la vista, y si era un error no lo leería nadie.
    func completarDespues() {
        guard !enCurso else { return }
        irAlHome()
    }

    /// El último paso —"Tu apto físico"— terminó, con el apto guardado o con "Lo
    /// subo después". Derecho al Inicio, sin pantalla final.
    func terminarRegistro() {
        guard !enCurso else { return }
        irAlHome()
    }

    private func avanzar(desde actual: Pantalla) {
        errorVisible = nil
        claveDeGuardado = nil
        if retomandoPerfil {
            // De hueco en hueco: lo que ya estaba guardado no se vuelve a pedir. Si el
            // guardado no llenó el hueco de este paso, se vuelve al Home en vez de
            // quedarse dando vueltas en la misma pantalla.
            if let hueco = pasoPendienteDelPerfil, hueco != actual {
                ir(a: hueco)
            } else {
                irAlHome()
            }
            return
        }
        if let siguiente = actual.pasoSiguiente {
            ir(a: siguiente)
        } else {
            irAlHome()
        }
    }

    // MARK: - Recuperar la contraseña

    func irARecuperarClave() {
        // El correo que ya se tipeó en el login viaja: volver a escribirlo es el
        // trámite que hace abandonar justo a quien está más apurado.
        if recuperacionCorreo.isEmpty { recuperacionCorreo = Self.limpio(loginCorreo) }
        ir(a: .claveCorreo)
    }

    /// `POST /auth/password/forgot`. Desde la 1.4.0 dice si el correo no tiene
    /// cuenta (`user_not_found`).
    func pedirCodigoDeClave() async {
        guard !enCurso, DatosRegistro.pareceCorreo(recuperacionCorreo) else { return }
        let desde = pantalla
        enCurso = true
        errorVisible = nil
        let respuesta = await servicio.pedirCodigoDeClave(correo: Self.limpio(recuperacionCorreo))
        enCurso = false
        guard pantalla == desde else { return }
        switch respuesta {
        case .ok:
            tokenDeReseteo = nil
            recuperacionCodigo = ""
            codigoRecibido()
            if pantalla == .claveCorreo { ir(a: .claveCodigo) }
        case .rechazado(let codigo, _, _) where codigo == "user_not_found":
            alertaUsuarioInexistente(correo: recuperacionCorreo)
        default:
            errorVisible = TraductorDeErrores.texto(respuesta)
            if !alertaDeCodigo(respuesta, vencido: Textos.errorCodeExpiredReset, alVolver: {}) {
                mostrarAlertaDeError(respuesta, siNo: Textos.passwordResetErrorTitle)
            }
        }
    }

    func verificarCodigoDeClave() async {
        guard recuperacionCodigo.count == CampoCodigo.largo, !enCurso, !codigoAgotado else { return }
        enCurso = true
        errorVisible = nil
        let respuesta = await servicio.verificarCodigoDeClave(
            correo: Self.limpio(recuperacionCorreo), codigo: recuperacionCodigo)
        enCurso = false
        guard pantalla == .claveCodigo else { return }
        switch respuesta {
        case .ok(let permiso):
            tokenDeReseteo = permiso.resetToken
            claveNueva = ""
            claveNuevaRepetida = ""
            ir(a: .claveNueva)
        default:
            errorVisible = TraductorDeErrores.texto(respuesta)
            if !alertaDeCodigo(respuesta, vencido: Textos.errorCodeExpiredReset,
                               alVolver: { [weak self] in self?.volverAlPrincipioDeLaRecuperacion() }) {
                mostrarAlertaDeError(respuesta, siNo: Textos.passwordResetErrorTitle)
            }
        }
    }

    /// De vuelta a "Recuperar tu contraseña", con el correo escrito.
    func volverAlPrincipioDeLaRecuperacion() {
        guard !enCurso else { return }
        tokenDeReseteo = nil
        recuperacionCodigo = ""
        claveNueva = ""
        claveNuevaRepetida = ""
        codigoAgotado = false
        errorVisible = nil
        historial = [.bienvenida, .login]
        pantalla = .claveCorreo
    }

    /// Lo que habilita "Guardar contraseña": las tres reglas.
    var puedeGuardarClaveNueva: Bool { reglasDeClaveNuevaCumplidas == 3 }

    /// `POST /auth/password/reset`. El servidor devuelve una sesión nueva, que se
    /// usa para entrar derecho. 🛑 Desde la 1.6.0 NO cierra las otras sesiones: se
    /// le pregunta a la persona, y las dos respuestas llevan al Inicio.
    func guardarClaveNueva() async {
        guard !enCurso, puedeGuardarClaveNueva else { return }
        if !claveNuevaSugeridaPorElSistema && !claveNuevaCoincide {
            erroresDeCampo = [.claveRepetida: Textos.fieldPasswordNoMatch]
            return
        }
        erroresDeCampo = [:]
        guard let token = tokenDeReseteo else {
            // Sin permiso no hay pedido posible.
            alertaReseteoVencido()
            return
        }
        enCurso = true
        errorVisible = nil
        let respuesta = await servicio.cambiarClave(token: token, clave: claveNueva)
        enCurso = false
        switch respuesta {
        case .ok:
            tokenDeReseteo = nil
            claveNueva = ""
            claveNuevaRepetida = ""
            preguntarPorLasOtrasSesiones()
        case .rechazado(let codigo, _, _) where codigo == "invalid_reset_token":
            alertaReseteoVencido()
        default:
            errorVisible = TraductorDeErrores.texto(respuesta)
            // La contraseña ya cambió, pero la cuenta está desactivada o por
            // borrarse: se ofrece volver a ella como en el login.
            if !alertaDeCuenta(respuesta), pantalla == .claveNueva {
                mostrarAlertaDeError(respuesta, siNo: Textos.passwordResetErrorTitle)
            }
        }
    }

    private func alertaReseteoVencido() {
        mostrarAlerta(titulo: Textos.errorExpiredTitle, mensaje: Textos.errorInvalidResetToken) { [weak self] in
            self?.volverAlPrincipioDeLaRecuperacion()
        }
    }

    private func preguntarPorLasOtrasSesiones() {
        alerta = ContenidoDeAlerta(
            Textos.passwordResetOtherSessionsTitle, mensaje: Textos.passwordResetOtherSessionsBody,
            botones: [
                BotonDeAlerta(Textos.passwordResetOtherSessionsClose) { [weak self] in
                    guard let self else { return }
                    // Se entra igual: si el pedido falla, la contraseña ya cambió y
                    // las otras sesiones se pueden cerrar desde otro teléfono.
                    let servicio = self.servicio
                    Task { _ = await servicio.cerrarOtrasSesiones() }
                    self.irAlHome()
                },
                BotonDeAlerta(Textos.passwordResetOtherSessionsKeep, rol: .cancelar) { [weak self] in
                    self?.irAlHome()
                },
            ])
    }

    // MARK: - Sesión

    /// Los códigos con los que el servidor dice que esta sesión ya no existe.
    /// Ninguno se arregla reintentando.
    static let codigosDeSesionMuerta: Set<String> = [
        "unauthorized", "session_revoked", "invalid_refresh_token",
    ]

    /// Escucha los cierres que publica el renovador. Dura lo que dure la app.
    func escucharCierres() async {
        for await motivo in await servicio.cierres() {
            sesionCerrada(motivo)
        }
    }

    func sesionCerrada(_ motivo: MotivoDeCierre) {
        perfil = nil
        sincronizador.cerrarSesion()
        switch motivo {
        case .laPersonaCerro:
            irALaBienvenida()
        case .rechazada(let codigo):
            irAlLogin(aviso: TraductorDeErrores.texto(codigo: codigo))
            alertaSesionExpirada = true
        }
    }

    func notificarSesionExpirada() {
        irAlLogin(aviso: Textos.errorSessionRevoked)
        alertaSesionExpirada = true
    }

    func irAlLoginDesdeSesionExpirada() {
        alertaSesionExpirada = false
    }

    /// "Cerrar sesión" de Ajustes.
    ///
    /// 🛑 PRIMERO el llavero y DESPUÉS la pantalla. `servicio.cerrarSesion()` vuelve
    /// apenas borró las credenciales —sin esperar a la red ni a una renovación en
    /// vuelo— y el servidor se entera por detrás (`RenovadorDeSesion.cerrarSesion`).
    /// Al revés, la bienvenida aparecía con la sesión todavía guardada, y si la app
    /// se cerraba en ese rato el próximo arranque entraba de nuevo al Home.
    func cerrarSesion() async {
        await servicio.cerrarSesion()
        perfil = nil
        sincronizador.cerrarSesion()
        // Los avisos programados son de esta cuenta: con la sesión cerrada (o la
        // cuenta desactivada o por borrarse) no tiene que llegar ninguno.
        NotificadorDeEntrenamiento.limpiarRecordatorios()
        irALaBienvenida()
    }

    /// Si borrar la cuenta pide la contraseña. Sin perfil cargado se pide: el
    /// servidor la exige a toda cuenta que la tenga.
    var cuentaConContrasena: Bool { perfil?.hasPassword ?? true }

    /// `POST /me/delete` (App Store 5.1.1(v): borrar la cuenta desde la app).
    /// Desde la 1.6.0 la cuenta se borra a los 30 días: hasta entonces se recupera
    /// iniciando sesión. Si sale bien se cierra la sesión, se vuelve a la
    /// bienvenida y se avisa.
    func borrarCuenta(clave: String?) async -> ResultadoDeBorrarCuenta {
        let respuesta = await servicio.borrarCuenta(clave: cuentaConContrasena ? clave : nil)
        switch respuesta {
        case .ok:
            await cerrarSesion()
            mostrarAlerta(titulo: Textos.accountPendingDeletionTitle, mensaje: Textos.accountPendingDeletionDone)
            return .borrada
        case .rechazado(let codigo, _, _) where codigo == "invalid_credentials" || codigo == "wrong_password":
            return .claveIncorrecta
        default:
            return .fallo(TraductorDeErrores.texto(respuesta))
        }
    }

    enum ResultadoDeBorrarCuenta: Equatable {
        case borrada, claveIncorrecta, fallo(String)
    }

    /// `POST /me/deactivate`. Los datos quedan; se cierra la sesión, se vuelve a
    /// la bienvenida y se avisa cómo volver. `nil` si salió bien; si no, el texto
    /// del error.
    func desactivarCuenta() async -> String? {
        let respuesta = await servicio.desactivarCuenta()
        guard case .ok = respuesta else { return TraductorDeErrores.texto(respuesta) }
        await cerrarSesion()
        mostrarAlerta(titulo: Textos.accountDeactivatedTitle, mensaje: Textos.accountDeactivatedDone)
        return nil
    }

    /// `GET /me`. Si no hay sesión o no hay red, el Home sigue con lo que tiene: un
    /// cierre de sesión de verdad llega por `escucharCierres()`, no por acá.
    func cargarPerfil() async {
        if case .ok(let guardado) = await servicio.miPerfil() {
            perfil = guardado
        }
    }

    /// La preferencia vive en `PATCH /me`: al abrir en otro iPhone se ve la misma.
    func guardarUnidades(_ unidades: SistemaDeUnidades) async -> Bool {
        let valor: PerfilEntrada.UnitSystem = unidades == .metrico ? .metrico : .imperial
        let respuesta = await servicio.guardarPerfil(PerfilEntrada(unitSystem: valor), anulando: [],
                                                      claveDeIdempotencia: UUID().uuidString)
        if case .ok(let guardado) = respuesta {
            perfil = guardado
            return true
        }
        errorVisible = TraductorDeErrores.texto(respuesta)
        return false
    }

    /// Ajustes → Datos personales / Entrenamiento: UN `PATCH /me` con lo que
    /// cambió (`EditorDePerfil.swift`). La clave la trae quien llama: una por
    /// INTENTO, la misma en el reintento de ese intento (docs/API.md §6). Con
    /// éxito el perfil nuevo queda acá y el Home lo toma (`RaizHomeView.aplicar`).
    func guardarEdicionDelPerfil(_ cambios: PerfilEntrada, anulando: Set<CampoAnulable>,
                                 claveDeIdempotencia: String) async -> Resultado<Perfil> {
        let respuesta = await servicio.guardarPerfil(cambios, anulando: anulando,
                                                      claveDeIdempotencia: claveDeIdempotencia)
        switch respuesta {
        case .ok(let guardado):
            perfil = guardado
        case .rechazado(let codigo, _, _) where Self.codigosDeSesionMuerta.contains(codigo):
            // Igual que en el alta: sin sesión, reintentar no tiene salida.
            irAlLogin(aviso: TraductorDeErrores.texto(respuesta))
        default:
            break
        }
        return respuesta
    }

    func cargarObjetivos() async {
        if case .ok(let recibidos) = await servicio.objetivos() {
            let inicioDeHoyMs = Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
            objetivosActivos = recibidos.filter { objetivo in
                guard let fechaMs = objetivo.goalDateMs else { return true }
                return fechaMs >= inicioDeHoyMs
            }
        }
    }

    func guardarObjetivos(_ objetivos: [ObjetivoDeUsuario]) async -> Bool {
        let respuesta = await servicio.guardarObjetivos(objetivos)
        if case .ok(let recibidos) = respuesta {
            let inicioDeHoyMs = Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
            objetivosActivos = recibidos.filter { objetivo in
                guard let fechaMs = objetivo.goalDateMs else { return true }
                return fechaMs >= inicioDeHoyMs
            }
            await cargarPerfil()
            return true
        }
        errorVisible = TraductorDeErrores.texto(respuesta)
        return false
    }

    // MARK: - Perfil a medio hacer

    /// El primer paso del alta que le falta al perfil guardado, o `nil` si no falta
    /// nada o si todavía no se sabe —sin `GET /me` no se inventa un hueco—. Con esto
    /// el Home ofrece terminarlo: quien tocó "Completar después", o se quedó sin
    /// señal a mitad del alta, no tenía cómo volver a esos pasos.
    var pasoPendienteDelPerfil: Pantalla? {
        perfil.flatMap(Self.primerPasoFaltante(en:))
    }

    /// Los datos del alta que usa el plan, en el orden de los pasos: se retoma en
    /// el hueco más temprano. La zona va con los días porque se guardan juntos.
    static func primerPasoFaltante(en perfil: Perfil) -> Pantalla? {
        if perfil.birthdateMs == nil { return .regNacimiento }
        if perfil.biologicalSex == nil { return .regSexo }
        if perfil.weightG == nil || perfil.heightMm == nil { return .regCuerpo }
        if perfil.sport == nil { return .regDeporte }
        if perfil.level == nil { return .regNivel }
        if perfil.goal == nil { return .regObjetivo }
        if perfil.trainingDays?.isEmpty ?? true { return .regDias }
        if perfil.timezone?.isEmpty ?? true { return .regDias }
        return nil
    }

    /// "Completar perfil" del Home: al primer hueco, con las mismas pantallas del alta.
    func retomarPerfil() {
        guard pantalla == .home, let hueco = pasoPendienteDelPerfil else { return }
        retomandoPerfil = true
        errorVisible = nil
        claveDeGuardado = nil
        historial.removeAll()
        pantalla = hueco
    }

    // MARK: - Puerta de versión

    func consultarPuertaDeVersion() async {
        decisionDeVersion = await consultarVersion()
    }

    var actualizacionRequerida: AvisoDeVersion? {
        if case .exigirActualizar(let aviso) = decisionDeVersion { return aviso }
        return nil
    }

    var actualizacionRecomendada: AvisoDeVersion? {
        guard !recomendacionDescartada,
              case .recomendarActualizar(let aviso) = decisionDeVersion else { return nil }
        return aviso
    }

    // MARK: - Destinos que limpian

    private func irAlHome() {
        olvidarLaEntrada()
        avisoDelLogin = nil
        historial.removeAll()
        pantalla = .home
    }

    /// 🛑 Todo lo que alguien tipeó o recibió para ENTRAR —contraseñas, códigos, el
    /// correo de la recuperación, los permisos, las casillas— y las salidas que
    /// ofrecía la pantalla. Es UNA sola función a propósito: con una lista por
    /// destino, cada destino se olvidaba de un campo distinto, y lo que tipeó una
    /// persona quedaba en memoria para la siguiente.
    ///
    /// No toca `datos` ni `perfil`, que son de la sesión (`olvidarLoDeLaSesion`), ni
    /// `loginCorreo`, que el login conserva para no hacer tipear dos veces.
    private func olvidarLaEntrada() {
        tokenDeRegistro = nil
        correoDelPermiso = nil
        tokenDeReseteo = nil
        permisoSocial = nil
        vencimientoSocialMs = nil
        proveedorDelAlta = nil
        ofrecerRenovarSocial = false
        correoValidadoPorProveedor = false
        claveSugeridaPorElSistema = false
        erroresDeCampo = [:]
        claveDeGuardado = nil
        loginClave = ""
        recuperacionCorreo = ""
        recuperacionCodigo = ""
        claveNueva = ""
        claveNuevaRepetida = ""
        claveDeRegistro = ""
        claveDeRegistroRepetida = ""
        claveParaVincular = ""
        aceptoElAviso = false
        aceptoElDescargo = false
        errorVisible = nil
        ofrecerLogin = false
        laCuentaYaExiste = false
        codigoAgotado = false
        envioDelCodigo = nil
        vencimientoDelPermisoMs = nil
        altaSinDesenlace = false
        retomandoPerfil = false
    }

    /// 🛑 Lo que se juntó del perfil es dato de salud (peso, nacimiento): no se
    /// deja en memoria para quien entre después en este teléfono.
    private func olvidarLoDeLaSesion() {
        olvidarLaEntrada()
        perfil = nil
        objetivosActivos = []
        datos = DatosRegistro()
    }

    private func irAlLogin(aviso: String?) {
        olvidarLoDeLaSesion()
        avisoDelLogin = aviso
        historial = [.bienvenida]
        pantalla = .login
    }

    private func irALaBienvenida() {
        olvidarLoDeLaSesion()
        loginCorreo = ""
        avisoDelLogin = nil
        historial.removeAll()
        pantalla = .bienvenida
    }

    /// La alerta de un error que no tiene una propia: el título de su código (o
    /// `siNo`) y su texto. Sin conexión es "Revisa tu conexión y prueba de nuevo."
    private func mostrarAlertaDeError<Valor>(_ respuesta: Resultado<Valor>, siNo titulo: String) {
        mostrarAlerta(titulo: TraductorDeErrores.titulo(respuesta, siNo: titulo),
                      mensaje: TraductorDeErrores.texto(respuesta))
    }

    // MARK: - Reglas de la contraseña

    /// ⚠️ El diseño dice "al menos 8 caracteres". El contrato
    /// (`shared/api/openapi.yaml` → `Password.minLength`) exige **10**. Gana el
    /// contrato: con 8, la persona escribiría una contraseña que el cliente
    /// acepta y el servidor rechaza, que es la peor forma de enterarse.
    static let largoMinimoDeClave = 10

    struct ReglaDeClave: Identifiable {
        let id: String
        let texto: String
        let cumple: Bool
    }

    func reglasDeClave(_ clave: String) -> [ReglaDeClave] {
        [
            ReglaDeClave(id: "largo", texto: Textos.passwordResetNewRuleLength,
                         cumple: clave.count >= Self.largoMinimoDeClave),
            ReglaDeClave(id: "mayuscula", texto: Textos.passwordResetNewRuleUppercase,
                         cumple: clave.contains { $0.isUppercase }),
            ReglaDeClave(id: "numero", texto: Textos.passwordResetNewRuleNumber,
                         cumple: clave.contains { $0.isNumber }),
        ]
    }

    var reglasDeClaveNuevaCumplidas: Int {
        reglasDeClave(claveNueva).filter(\.cumple).count
    }

    var claveNuevaCoincide: Bool {
        !claveNueva.isEmpty && claveNueva == claveNuevaRepetida
    }

    var claveNuevaLista: Bool {
        reglasDeClaveNuevaCumplidas == 3 && claveNuevaCoincide
    }

    var reglasDeClaveDeRegistroCumplidas: Int {
        reglasDeClave(claveDeRegistro).filter(\.cumple).count
    }

    var claveDeRegistroCoincide: Bool {
        !claveDeRegistro.isEmpty && claveDeRegistro == claveDeRegistroRepetida
    }

    var claveDeRegistroLista: Bool {
        reglasDeClaveDeRegistroCumplidas == 3 && claveDeRegistroCoincide
    }

    /// "Ingresar" se habilita con un correo válido y una contraseña escrita
    /// (2026-10-22: el "no parece un correo" debajo del campo ya no existe).
    var loginListo: Bool {
        DatosRegistro.pareceCorreo(loginCorreo) && !loginClave.isEmpty
    }

    // MARK: - El correo que se muestra en las pantallas de código

    var correoDelDesafio: String {
        let candidatos = [recuperacionCorreo, loginCorreo]
        return candidatos.first { !$0.isEmpty } ?? Textos.commonEmailPlaceholder
    }

    /// El correo tal como viaja: sin los espacios que deja un pegado. Las
    /// minúsculas las normaliza el servidor (contrato, `Email`).
    static func limpio(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Proveedor {
    /// El nombre de la marca, igual en todos los idiomas.
    var nombre: String { self == .google ? "Google" : "Apple" }
}
