import Foundation
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
// =============================================================================

/// Las pantallas del flujo de entrada. La última —`home`— es el import de
/// `HomeB.dc.html`, que es otra pieza.
enum Pantalla: String, CaseIterable, Equatable {
    case bienvenida, problema, previewPlan
    case login, claveCorreo, claveCodigo, claveNueva, claveLista
    case regCorreo, regCodigo, regClave, regAviso, regTerminos
    case regNombre, regNacimiento, regSexo, regCuerpo
    case regDeporte, regNivel, regObjetivo, regSalud, regMedicion, regDias, regListo
    case home

    /// Los TRECE pasos que cuenta la barra de avance (2026-10-21).
    ///
    /// ```
    ///  1 datos (nombre, apellido, correo, contraseña y su confirmación)
    ///  2 código   3 aviso de salud                   ← acá NACE la cuenta
    ///  4 nacimiento   5 sexo   6 cuerpo   7 deporte   8 nivel
    ///  9 objetivo  10 salud  11 medición  12 días  13 resumen   ← un PATCH /me cada uno
    /// ```
    ///
    /// La contraseña y el nombre se piden JUNTO con el correo (pedido de Iván):
    /// así, después del código no queda nada que no aplique a quien entró con
    /// Google o Apple, que se saltea el código y la contraseña. El nombre viaja en
    /// el `profile` de `register/complete`. `regClave` y `regNombre` siguen
    /// existiendo como pantallas pero ya no son pasos del alta.
    ///
    /// 🛑 El aviso de salud no se puede saltear: sin él no hay cuenta. Los pasos de
    /// perfil van DESPUÉS de crearla (decisión 0008). La barra NO se reinicia.
    static let pasosDelRegistro: [Pantalla] = [
        .regCorreo, .regCodigo, .regAviso,
        .regNacimiento, .regSexo, .regCuerpo, .regDeporte, .regNivel,
        .regObjetivo, .regSalud, .regMedicion, .regDias, .regListo,
    ]

    /// El primer paso con la cuenta ya creada.
    static let primerPasoDePerfil: Pantalla = .regNacimiento

    /// Los que corren con la cuenta ya creada. `regNombre` va aparte: no es paso
    /// del alta, pero si alguien llega (desde una prueba) guarda como cualquiera.
    static let pasosDePerfil: [Pantalla] =
        [.regNombre] + Array(pasosDelRegistro.drop { $0 != primerPasoDePerfil })

    var esPasoDelRegistro: Bool { Pantalla.pasosDelRegistro.contains(self) }
    var esPasoDePerfil: Bool { Pantalla.pasosDePerfil.contains(self) }

    /// Los pasos del alta ANTES de que exista la cuenta, más los términos que se
    /// leen desde el aviso. Salir de acá es abandonar el alta.
    var esDelAlta: Bool {
        [.regCorreo, .regCodigo, .regClave, .regAviso, .regTerminos].contains(self)
    }

    var esDeLaRecuperacion: Bool {
        [.claveCorreo, .claveCodigo, .claveNueva].contains(self)
    }

    /// Los diez primeros pasos de perfil llevan "Completar después" (decisión 0008
    /// §3): con la cuenta ya creada, una pantalla que sólo se pasa guardando
    /// encierra a quien se quedó sin señal. El resumen no la necesita: ya entra.
    var ofreceCompletarDespues: Bool { esPasoDePerfil && self != .regListo }

    /// Qué lleva la cabecera. Está acá y no repartido por las pantallas porque
    /// la flecha de volver la dibuja **un solo lugar**: `RaizFlujoView`.
    enum Cabecera { case ninguna, soloVolver, volverYAvance, soloAvance }

    var cabecera: Cabecera {
        switch self {
        // Entradas y finales: de acá no se vuelve.
        case .bienvenida, .problema, .previewPlan, .claveLista, .regListo, .home:
            return .ninguna
        // El diseño les dibuja la flecha adentro de la pantalla; acá la pone el
        // andamio, que es lo mismo en pantalla y una sola implementación.
        case .login, .claveCorreo, .claveCodigo, .claveNueva, .regTerminos:
            return .soloVolver
        // 🛑 El primer paso de perfil lleva la barra y NO la flecha: la cuenta ya
        // existe y atrás sólo hay pasos que mandarían un permiso consumido. Una
        // flecha deshabilitada se ve y no hace nada, que es peor que no tenerla.
        case .regNombre, .regNacimiento:
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
        // `regNombre` ya no es paso del alta (2026-10-21); si se llega, sigue el
        // primero de perfil.
        if self == .regNombre { return Pantalla.primerPasoDePerfil }
        guard let i = Pantalla.pasosDelRegistro.firstIndex(of: self),
              Pantalla.pasosDelRegistro.indices.contains(i + 1) else { return nil }
        return Pantalla.pasosDelRegistro[i + 1]
    }
}

@MainActor
final class FlujoEntrada: ObservableObject {
    @Published private(set) var objetivosActivos: [ObjetivoDeUsuario] = []
    @Published private(set) var pantalla: Pantalla = .bienvenida {
        // El "no parece un correo" y los errores de campo son de la pantalla que
        // los mostró.
        didSet {
            if correoRechazado, pantalla != oldValue { correoRechazado = false }
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
            if correoRechazado, datos.correo != oldValue.correo { correoRechazado = false }
        }
    }

    /// Los campos del login, de la recuperación y de la contraseña del alta viven
    /// aparte de `datos`: son otra conversación, y mezclarlos hace que volver
    /// atrás arrastre basura — o que una contraseña quede junto al perfil.
    @Published var loginCorreo = "" {
        didSet { if correoRechazado, loginCorreo != oldValue { correoRechazado = false } }
    }
    @Published var loginClave = ""
    @Published var recuperacionCorreo = "" {
        didSet { if correoRechazado, recuperacionCorreo != oldValue { correoRechazado = false } }
    }
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

    /// La casilla del aviso de salud. Arranca sin marcar: una aceptación por
    /// defecto no es una aceptación.
    @Published var aceptoElAviso = false

    @Published private(set) var enCurso = false
    /// Con qué proveedor se está entrando ahora: su botón muestra la ruedita.
    @Published private(set) var conectandoCon: Proveedor?
    /// El alta en curso empezó con Google o Apple: no se pide contraseña, y la
    /// cuenta se crea con el permiso social. Se suelta con el resto de la entrada.
    @Published private(set) var proveedorDelAlta: Proveedor?
    /// El permiso social venció en el último paso del alta: se ofrece volver a
    /// pasar por Google o Apple SIN perder el código ya validado ni la casilla.
    @Published private(set) var ofrecerRenovarSocial = false
    /// Google o Apple ya verificaron el correo: el alta NO pide código (sólo se
    /// valida con código a quien se registra con correo y contraseña). El campo
    /// del correo queda fijo: cambiarlo obligaría a validarlo.
    @Published private(set) var correoValidadoPorProveedor = false

    /// Los campos de los formularios de entrada que pueden mostrar un error debajo.
    enum CampoDelFormulario: Hashable {
        case nombre, correo, clave, claveRepetida
    }

    /// 2026-10-21 (Iván): el error de un dato va DEBAJO del campo que falló, en
    /// rojo, y no en una alerta: "Ese correo ya está registrado" debajo del
    /// correo, "Las contraseñas no coinciden" debajo de la confirmación. Las
    /// alertas quedan para lo que no es de un campo (sin conexión, el servidor).
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
    @Published var errorVisible: String?
    @Published var alertaSesionExpirada = false
    @Published var alertaError: InfoAlerta?

    public struct InfoAlerta: Identifiable, Equatable {
        public let id = UUID()
        public let titulo: String
        public let mensaje: String
        public let boton: String

        public init(titulo: String, mensaje: String, boton: String = Textos.commonDone) {
            self.titulo = titulo
            self.mensaje = mensaje
            self.boton = boton
        }
    }

    func mostrarAlertaError(titulo: String, mensaje: String, boton: String = Textos.commonDone) {
        alertaError = InfoAlerta(titulo: titulo, mensaje: mensaje, boton: boton)
    }

    /// Se tocó el botón con algo que no parece un correo: la pantalla lo dice
    /// debajo del campo, y no se manda nada.
    ///
    /// 🛑 El correo se juzga al TOCAR, no mientras se escribe. El "no parece
    /// válido" que aparecía con la primera letra retaba a quien todavía no había
    /// terminado, y el botón apagado hasta que el correo pareciera uno hacía
    /// sentir lenta la pantalla (Iván, probando en el iPhone, 2026-09-10). Se
    /// apaga al editar ese correo y al cambiar de pantalla; el `if correoRechazado`
    /// de esos `didSet` evita avisarle a SwiftUI en cada tecla. Las reglas de la
    /// contraseña sí siguen en vivo.
    @Published private(set) var correoRechazado = false

    /// Lo que el login tiene que explicar cuando se llega de rebote —la sesión se
    /// cerró— y no por elección. Sin esto el login aparece solo y parece que la app
    /// se reinició.
    @Published private(set) var avisoDelLogin: String?

    /// El aviso de salud y los términos, con su versión. Bajan de `GET /legal` y
    /// no vienen en la app, a propósito (contrato, `/legal`).
    @Published private(set) var legales: TextosLegales?
    @Published private(set) var cargandoLegales = false
    @Published private(set) var falloLegales = false

    /// Se prende cuando el alta ya no puede terminar y lo que corresponde es
    /// entrar: el permiso ya se usó, la cuenta ya existe, o el pedido se cortó y la
    /// cuenta pudo haberse creado igual del otro lado.
    @Published private(set) var ofrecerLogin = false

    /// Se prende cuando el permiso del alta VENCIÓ sin usarse: hace falta otro
    /// código, y ofrecer sólo "Ya tengo cuenta" mandaba a entrar a una cuenta que
    /// no existe.
    @Published private(set) var ofrecerEmpezarDeNuevo = false

    /// El servidor dijo `conflict`: ya hay una cuenta con ese correo. La salida al
    /// login lleva su propio texto, porque no es "ya tengo cuenta" de quien la acaba
    /// de crear.
    @Published private(set) var laCuentaYaExiste = false

    /// Cambia cada vez que el servidor aceptó un pedido de código: reinicia la
    /// cuenta regresiva de "Reenviar".
    @Published private(set) var pedidosDeCodigo = 0

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
    /// El permiso del alta. 🛑 Otro permiso es otra alta: la casilla del aviso que
    /// se marcó con el anterior no vale para éste.
    private var tokenDeRegistro: String? {
        didSet { if tokenDeRegistro != oldValue { aceptoElAviso = false } }
    }
    /// Cuándo vence ese permiso (`expires_at_ms`). Es lo que deja leer un
    /// `invalid_registration_token`: vencido es "pedí otro código"; vigente es que
    /// el permiso ya se usó y la cuenta existe.
    private var vencimientoDelPermisoMs: Int64?
    /// Un intento de crear la cuenta terminó sin saber cómo —sin red o con una
    /// respuesta rara—: la cuenta pudo haberse creado del otro lado.
    private var altaSinDesenlace = false
    private var tokenDeReseteo: String?
    /// El permiso de `POST /auth/social` para terminar un alta con Google o Apple.
    /// 🛑 Sólo en memoria, como los otros permisos (AGENTS.md §8).
    private var permisoSocial: String?
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
        let adentro: (Pantalla) -> Bool = { $0.esPasoDelRegistro || $0 == .regTerminos }
        if !(adentro(pantalla) && adentro(destino)) {
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
        ofrecerEmpezarDeNuevo = false
        ofrecerRenovarSocial = false
        laCuentaYaExiste = false
        if pantalla == .regTerminos {
            pantalla = .regAviso
            return
        }
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

    /// Los pasos que cuenta la barra en ESTE alta. Con Google o Apple no hay
    /// contraseña ni (si el proveedor verificó el correo) código: la barra cuenta
    /// sólo los pasos que de verdad hay.
    var pasosDelAlta: [Pantalla] {
        guard proveedorDelAlta != nil else { return Pantalla.pasosDelRegistro }
        let sinPedir: Set<Pantalla> = correoValidadoPorProveedor ? [.regCodigo] : []
        return Pantalla.pasosDelRegistro.filter { !sinPedir.contains($0) }
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
        guard DatosRegistro.pareceCorreo(loginCorreo) else { rechazarCorreo(); return }
        enCurso = true
        errorVisible = nil
        erroresDeCampo = [:]
        avisoDelLogin = nil
        let respuesta = await servicio.entrar(correo: Self.limpio(loginCorreo), clave: loginClave)
        enCurso = false
        switch respuesta {
        case .ok:
            // La sesión ya quedó en el llavero: se entra aunque la persona haya
            // tocado otra cosa mientras el pedido viajaba.
            irAlHome()
        case .rechazado(let codigo, _) where codigo == "user_not_found":
            if pantalla == .login { erroresDeCampo[.correo] = Textos.fieldEmailNotFound }
        case .rechazado(let codigo, _) where ["wrong_password", "invalid_credentials"].contains(codigo):
            if pantalla == .login { erroresDeCampo[.clave] = Textos.fieldPasswordWrong }
        case .rechazado(let codigo, _) where codigo == "password_not_set":
            if pantalla == .login { erroresDeCampo[.clave] = Textos.fieldPasswordNotSet }
        default:
            if pantalla == .login {
                let texto = TraductorDeErrores.texto(respuesta)
                errorVisible = texto
                mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.loginErrorTitle), mensaje: texto)
            }
        }
    }

    // MARK: - Google y Apple

    /// "Continuar con Google / Apple". Si la persona ya tiene cuenta, entra. Si no,
    /// empieza el alta de siempre con lo que dio el proveedor ya escrito: nombre,
    /// apellido y correo, que la persona revisa; después el código al correo, el
    /// aviso de salud y los pasos de perfil. Lo único que no se pide es contraseña.
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
            mostrarAlertaError(titulo: Textos.loginErrorTitle, mensaje: Textos.loginSocialNotConfigured)
            return
        case .fallo:
            enCurso = false
            conectandoCon = nil
            mostrarAlertaError(titulo: Textos.loginErrorTitle, mensaje: Textos.loginSocialFailed)
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
            let texto: String
            switch respuesta.codigoDeRechazo {
            case "provider_not_configured": texto = Textos.loginSocialNotConfigured
            // Ese correo ya tiene cuenta con contraseña y no se vincula solo.
            case "conflict": texto = Textos.loginSocialAccountExists
            default: texto = TraductorDeErrores.texto(respuesta)
            }
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.loginErrorTitle),
                               mensaje: texto)
        }
    }

    /// El permiso social venció antes de crear la cuenta (más de 30 minutos en el
    /// alta). Se vuelve a pasar por el proveedor y, si sigue sin cuenta, se crea con
    /// el permiso nuevo: el código del correo ya validado y la casilla del aviso
    /// siguen valiendo, así que no se vuelve a pedir nada.
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
                mostrarAlertaError(titulo: Textos.signupErrorTitle, mensaje: Textos.loginSocialNotConfigured)
            case .fallo:
                mostrarAlertaError(titulo: Textos.signupErrorTitle, mensaje: Textos.loginSocialFailed)
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
            // Si el proveedor ahora no verifica el correo, el alta sin código no
            // sirve: tiene que haber un código validado (`tokenDeRegistro`).
            if alta.emailVerified != true && tokenDeRegistro == nil {
                correoValidadoPorProveedor = false
                ofrecerRenovarSocial = false
                pantalla = .regCorreo
                return
            }
            ofrecerRenovarSocial = false
            ofrecerLogin = false
            await crearCuenta()
        default:
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
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
        proveedorDelAlta = proveedor
        correoValidadoPorProveedor = permiso.emailVerified == true && !(permiso.email ?? "").isEmpty
        ir(a: .regCorreo)
    }

    /// El primer paso de un alta con Google o Apple cuyo correo ya verificó el
    /// proveedor: con nombre y apellido, derecho al aviso de salud. Sin código.
    func seguirConDatosDelProveedor() {
        guard correoValidadoPorProveedor, datos.identidadLista, !enCurso else { return }
        ir(a: .regAviso)
    }

    // MARK: - Alta: correo, código, contraseña y aviso (pasos 1 a 4)

    /// Paso 1, y también "Reenviar" del paso 2: `POST /auth/register`.
    func pedirCodigoDeRegistro() async {
        guard !enCurso else { return }
        // Al tocar se juzga todo, y cada error va debajo de su campo.
        if pantalla == .regCorreo {
            var errores: [CampoDelFormulario: String] = [:]
            if !datos.identidadLista { errores[.nombre] = Textos.fieldNameRequired }
            if proveedorDelAlta == nil {
                if reglasDeClaveDeRegistroCumplidas < 3 {
                    errores[.clave] = Textos.fieldPasswordRulesUnmet
                } else if !claveSugeridaPorElSistema && !claveDeRegistroCoincide {
                    errores[.claveRepetida] = Textos.fieldPasswordNoMatch
                }
            }
            erroresDeCampo = errores
            if !datos.correoValido { rechazarCorreo() }
            guard errores.isEmpty, datos.correoValido else { return }
        }
        // La contraseña se elige en el mismo paso: sin una válida no se pide código.
        guard proveedorDelAlta != nil || claveDeRegistroLista else { return }
        // Volvió acá a corregir la contraseña (el servidor la rechazó al crear la
        // cuenta): el código de ESTE correo ya se validó y el permiso sigue vivo.
        // Pedir otro tiraría `code_resend_too_soon` y desmarcaría el aviso.
        if pantalla == .regCorreo, tokenDeRegistro != nil, !permisoVencido,
           correoDelPermiso == Self.limpio(datos.correo).lowercased() {
            ir(a: .regAviso)
            return
        }
        guard datos.correoValido else { rechazarCorreo(); return }
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
            pedidosDeCodigo += 1
            if pantalla == .regCorreo { ir(a: .regCodigo) }
        case .rechazado(let codigo, _) where codigo == "email_already_registered" && pantalla == .regCorreo:
            erroresDeCampo[.correo] = Textos.fieldEmailInUse
        default:
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
        }
    }

    /// Paso 2: `POST /auth/register/verify`, a cambio de un permiso de un solo uso.
    func verificarCodigoDeRegistro() async {
        guard datos.codigoCompleto, !enCurso else { return }
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
            // La contraseña ya se eligió con el correo: derecho al aviso.
            ir(a: .regAviso)
        default:
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
        }
    }

    /// Paso 3. No sale ningún pedido: la contraseña viaja con el paso 4, que es
    /// el que crea la cuenta.
    func seguirConLaClave() {
        guard claveDeRegistroLista else { return }
        ir(a: .regAviso)
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
        if textos.version != legales?.version { aceptoElAviso = false }
        legales = textos
    }

    /// Paso 4: `POST /auth/register/complete`. Acá nace la cuenta.
    ///
    /// `perfil` va vacío y el contrato lo permite: los once pasos de perfil lo
    /// guardan después, de a uno (decisión 0008).
    func crearCuenta() async {
        guard !enCurso, aceptoElAviso, let legales else { return }
        // Con Google/Apple y el correo ya verificado no hay permiso de código.
        let sinCodigo = permisoSocial != nil && correoValidadoPorProveedor
        guard sinCodigo || tokenDeRegistro != nil else {
            // No debería pasar: a este paso se llega con el permiso del código. Si
            // pasa, se vuelve al correo en vez de mandar un pedido que no puede andar.
            errorVisible = nil
            pantalla = .regCorreo
            return
        }
        let token = tokenDeRegistro
        enCurso = true
        errorVisible = nil
        let aceptacion = AceptacionLegal(version: legales.version, accepted: true)
        // El nombre y el apellido ya se pidieron con el correo: viajan acá y no
        // en un paso de perfil aparte.
        let apellido = DatosRegistro.recortado(datos.apellido)
        let nombre = DatosRegistro.recortado(datos.nombre)
        let perfilInicial = PerfilEntrada(firstName: nombre.isEmpty ? nil : nombre,
                                          lastName: apellido.isEmpty ? nil : apellido)
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
            ofrecerRenovarSocial = false
            vencimientoDelPermisoMs = nil
            altaSinDesenlace = false
            claveDeRegistro = ""
            claveDeRegistroRepetida = ""
            ofrecerLogin = false
            ofrecerEmpezarDeNuevo = false
            laCuentaYaExiste = false
            errorVisible = nil
            claveDeGuardado = nil
            historial.removeAll()
            pantalla = Pantalla.primerPasoDePerfil
        case .rechazado(let codigo, _) where codigo == "legal_version_stale":
            // El texto cambió mientras tanto. Se baja el nuevo y se lo muestra:
            // reintentar con la versión vieja sería dar por aceptado algo que la
            // persona no leyó.
            aceptoElAviso = false
            await cargarLegales()
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
        case .rechazado(let codigo, _) where codigo == "weak_password":
            // 🛑 La contraseña se escribió un paso antes y el servidor la rechaza
            // recién ahora: la lista de conocidas no se puede anticipar mientras
            // alguien tipea. El error va donde está el campo.
            pantalla = .regCorreo
            erroresDeCampo[.clave] = Textos.fieldPasswordWeak
        case .rechazado(let codigo, _) where codigo == "invalid_signup_token":
            // Pasaron más de 30 minutos desde "Continuar con Google / Apple". El
            // código del correo NO se gastó (el servidor mira esto antes), pero hay
            // que volver a entrar con el proveedor para tener un permiso nuevo.
            errorVisible = Textos.signupSocialExpired
            mostrarAlertaError(titulo: Textos.signupErrorTitle, mensaje: Textos.signupSocialExpired)
            ofrecerRenovarSocial = true
            ofrecerLogin = false
            ofrecerEmpezarDeNuevo = false
        case .rechazado(let codigo, _) where codigo == "invalid_registration_token":
            if permisoVencido {
                // Venció sin usarse: hace falta otro código. Si un intento anterior
                // se cortó, la cuenta pudo crearse igual, y entrar queda como la otra
                // salida.
                let texto = TraductorDeErrores.texto(respuesta)
                errorVisible = texto
                mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
                ofrecerEmpezarDeNuevo = true
                ofrecerLogin = altaSinDesenlace
            } else {
                // 🛑 Vigente y rechazado: el permiso ya se usó, así que la cuenta SÍ
                // se creó y la respuesta no llegó. Volver al correo sería una trampa
                // —`POST /auth/register` contesta 202 igual y el código no llega
                // nunca—. La salida es entrar.
                errorVisible = Textos.legalSignupAlreadyCreated
                mostrarAlertaError(titulo: Textos.signupErrorTitle, mensaje: Textos.legalSignupAlreadyCreated)
                ofrecerLogin = true
                ofrecerEmpezarDeNuevo = false
            }
        case .rechazado(let codigo, _) where codigo == "conflict":
            // Ya hay una cuenta con ese correo, y pedir otro código no la cambia.
            // No es el `conflict` de un guardado en curso: el texto es otro.
            errorVisible = Textos.legalAccountExists
            mostrarAlertaError(titulo: Textos.errorEmailAlreadyRegisteredTitle, mensaje: Textos.errorEmailAlreadyRegistered)
            laCuentaYaExiste = true
            ofrecerLogin = true
            ofrecerEmpezarDeNuevo = false
        case .sinRed, .respuestaRara:
            // No se sabe cómo terminó: la cuenta pudo crearse del otro lado sin que
            // la respuesta volviera. Reintentar con el mismo permiso sigue valiendo,
            // y entrar es la otra salida.
            altaSinDesenlace = true
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
            ofrecerLogin = true
        default:
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
        }
    }

    /// Si el permiso del alta ya venció, según el reloj del teléfono. Sin fecha se lo
    /// da por vencido: pedir otro código siempre es una salida posible.
    private var permisoVencido: Bool {
        guard let vence = vencimientoDelPermisoMs else { return true }
        return reloj() >= vence
    }

    /// "Empezar de nuevo desde el correo": el permiso venció y hace falta otro
    /// código. El correo queda escrito; la contraseña y la casilla, no.
    func empezarElAltaDeNuevo() {
        guard !enCurso else { return }
        let anteriores = datos
        // El permiso social sigue valiendo aunque haya vencido el del correo.
        let social = (permisoSocial, proveedorDelAlta, correoValidadoPorProveedor)
        olvidarLaEntrada()
        datos = DatosRegistro()
        datos.correo = anteriores.correo
        if social.1 != nil {
            datos.nombre = anteriores.nombre
            datos.apellido = anteriores.apellido
            (permisoSocial, proveedorDelAlta, correoValidadoPorProveedor) = social
        }
        pantalla = .regCorreo
    }

    func irAlLoginDesdeElAlta() {
        loginCorreo = Self.limpio(datos.correo)
        irAlLogin(aviso: nil)
    }

    // MARK: - Perfil (pasos 5 a 15)

    /// Guarda lo de ESTE paso con `PATCH /me` y avanza.
    ///
    /// Si el servidor dice que no, **no avanza**: el error queda a la vista y el
    /// botón vuelve a estar disponible para reintentar con la misma clave. Quien no
    /// pueda pasar de ahí tiene "Completar después".
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
                        let texto = TraductorDeErrores.texto(guardadoDeObjetivos)
                        errorVisible = texto
                        mostrarAlertaError(titulo: TraductorDeErrores.titulo(guardadoDeObjetivos, siNo: Textos.signupErrorTitle), mensaje: texto)
                    }
                    return
                }
                objetivosActivos = recibidos
            }
            if claveDeGuardado == clave { claveDeGuardado = nil }
            // Si mientras viajaba la persona se fue a otro lado, no se la arrastra.
            if pantalla == actual { avanzar(desde: actual) }
        case .rechazado(let codigo, _) where Self.codigosDeSesionMuerta.contains(codigo):
            // El renovador ya intentó renovar y no pudo. Quedarse acá con el cartel
            // no tiene salida: se manda al login, que es lo único que reabre una
            // sesión. Se pierde lo que no se guardó, no lo anterior.
            irAlLogin(aviso: TraductorDeErrores.texto(respuesta))
        default:
            if pantalla == actual {
                let texto = TraductorDeErrores.texto(respuesta)
                errorVisible = texto
                mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.signupErrorTitle), mensaje: texto)
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

    func terminarRegistro() {
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

    /// `POST /auth/password/forgot`. Contesta 202 exista o no la cuenta: la
    /// pantalla no puede prometer que el mensaje llegó.
    func pedirCodigoDeClave() async {
        guard !enCurso else { return }
        guard DatosRegistro.pareceCorreo(recuperacionCorreo) else { rechazarCorreo(); return }
        let desde = pantalla
        enCurso = true
        errorVisible = nil
        erroresDeCampo = [:]
        let respuesta = await servicio.pedirCodigoDeClave(correo: Self.limpio(recuperacionCorreo))
        enCurso = false
        guard pantalla == desde else { return }
        switch respuesta {
        case .ok:
            tokenDeReseteo = nil
            recuperacionCodigo = ""
            pedidosDeCodigo += 1
            if pantalla == .claveCorreo { ir(a: .claveCodigo) }
        case .rechazado(let codigo, _) where codigo == "user_not_found":
            erroresDeCampo[.correo] = Textos.fieldEmailNotFound
        default:
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.passwordResetErrorTitle), mensaje: texto)
        }
    }

    func verificarCodigoDeClave() async {
        guard recuperacionCodigo.count == CampoCodigo.largo, !enCurso else { return }
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
            let texto = TraductorDeErrores.texto(respuesta)
            errorVisible = texto
            mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.passwordResetErrorTitle), mensaje: texto)
        }
    }

    /// `POST /auth/password/reset`. 🛑 Cambiar la contraseña revoca las demás
    /// sesiones y el servidor devuelve una nueva: se usa para entrar derecho, en
    /// vez de pedirle a alguien que tipee la contraseña que acaba de elegir.
    func guardarClaveNueva() async {
        guard !enCurso else { return }
        // Se juzga al tocar, y el error va debajo del campo que falló.
        if reglasDeClaveNuevaCumplidas < 3 {
            erroresDeCampo = [.clave: Textos.fieldPasswordRulesUnmet]; return
        }
        if !claveNuevaCoincide {
            erroresDeCampo = [.claveRepetida: Textos.fieldPasswordNoMatch]; return
        }
        erroresDeCampo = [:]
        guard claveNuevaLista else { return }
        guard let token = tokenDeReseteo else {
            // Sin permiso no hay pedido posible: se vuelve a pedir el código.
            errorVisible = nil
            pantalla = .claveCorreo
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
            historial.removeAll()
            pantalla = .claveLista
        case .rechazado(let codigo, _) where codigo == "weak_password":
            if pantalla == .claveNueva { erroresDeCampo[.clave] = Textos.fieldPasswordWeak }
        default:
            if pantalla == .claveNueva {
                let texto = TraductorDeErrores.texto(respuesta)
                errorVisible = texto
                mostrarAlertaError(titulo: TraductorDeErrores.titulo(respuesta, siNo: Textos.passwordResetErrorTitle), mensaje: texto)
            }
        }
    }

    func entrarConLaClaveNueva() {
        irAlHome()
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
        irALaBienvenida()
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
        case .rechazado(let codigo, _) where Self.codigosDeSesionMuerta.contains(codigo):
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
    /// correo de la recuperación, los permisos, la casilla del aviso— y las salidas
    /// que ofrecía la pantalla. Es UNA sola función a propósito: con una lista por
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
        aceptoElAviso = false
        errorVisible = nil
        ofrecerLogin = false
        ofrecerEmpezarDeNuevo = false
        laCuentaYaExiste = false
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

    /// Con algo escrito en los dos campos se puede tocar "Ingresar". Si el correo
    /// no parece uno, lo dice el toque (`correoRechazado`), no un botón apagado.
    var loginListo: Bool {
        !loginCorreo.isEmpty && !loginClave.isEmpty
    }

    /// El toque con algo que no parece un correo: no viaja nada, y el error de un
    /// intento anterior no queda pegado al de ahora.
    private func rechazarCorreo() {
        errorVisible = nil
        correoRechazado = true
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
