import Foundation

// =============================================================================
// Los endpoints que la app usa, con nombre.
//
// Es la única capa escrita a mano entre las pantallas y el contrato, igual que
// `android/core/.../red/ApiTrainer.kt`: los MODELOS se generan, el transporte es
// genérico (`ClienteAPI`) y la sesión la maneja `RenovadorDeSesion`. Acá quedan
// los nombres de las rutas y la forma de cada pedido. Cuando exista el generador
// de operaciones —hoy sólo emite esquemas—, este archivo se borra.
//
// Lo que la app usa del contrato 1.1.0: salud, legal, registro en tres pasos,
// login, refresh, logout, recuperación y perfil (`ServicioDeCuenta`), y el motor
// —plan, rutina y nutrición del día, comidas, series de gimnasio y catálogo—
// (`ServicioDelPlan`, docs/API.md §8). Actividades, exportar y borrar la cuenta
// ya existen del otro lado, pero todavía no hay pantalla que los use.
//
// 🛑 Los tokens no salen de acá. Login, alta y recuperación devuelven una
// `SesionAbierta`, que dice quién entró y nada más: la sesión de verdad la guarda
// el renovador en el Keychain, y una pantalla no tiene por qué tener un refresh
// token en la mano.
// =============================================================================

/// Que se abrió una sesión, y de quién.
public struct SesionAbierta: Equatable, Sendable {
    public let usuario: String

    public init(usuario: String) {
        self.usuario = usuario
    }
}

/// Los campos de `PerfilEntrada` que el contrato deja mandar en `null`.
///
/// 🛑 En un `PATCH` parcial omitir es "no lo toques" (docs/API.md §7), así que un
/// campo que se quiere VACIAR tiene que viajar como `null` explícito. Hoy son dos,
/// y son un enum y no un texto libre: un `"first_name": null` es un 400, y así
/// no se puede escribir.
public enum CampoAnulable: String, CaseIterable, Sendable {
    case apellido = "last_name"
    case fechaDelObjetivo = "goal_date_ms"
}

public struct ObjetivoDeUsuario: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let goal: Objetivo
    public let goalDateMs: Int64?
    enum CodingKeys: String, CodingKey { case id, goal, goalDateMs = "goal_date_ms" }

    public init(id: String, goal: Objetivo, goalDateMs: Int64?) {
        self.id = id
        self.goal = goal
        self.goalDateMs = goalDateMs
    }

    /// 🛑 `goal_date_ms` viaja SIEMPRE, también sin fecha, como `null` explícito.
    /// El `Encodable` sintetizado usa `encodeIfPresent` y omite los `nil`: hasta el
    /// contrato 1.2.0 `ObjetivoEntrada` lo exigía, así que cada "sin fecha" —y cada
    /// objetivo adicional del alta, que nunca tiene fecha— volvía con un 400 y el
    /// objetivo no se guardaba. El servidor de la 1.2.1 ya acepta la clave ausente,
    /// pero así funciona también contra uno anterior.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(goal, forKey: .goal)
        try c.encode(goalDateMs, forKey: .goalDateMs)
    }
}

private struct CuerpoDeObjetivos: Encodable {
    let goals: [ObjetivoDeUsuario]
}

/// Lo que la app le pide al servidor. Es un protocolo para que los tests del flujo
/// de entrada usen un doble y no un servidor.
public protocol ServicioDeCuenta: Sendable {
    func salud() async -> Resultado<Health>
    func textosLegales() async -> Resultado<TextosLegales>

    func pedirCodigoDeRegistro(correo: String) async -> Resultado<DesafioCorreo>
    func pedirCodigoDeRegistro(correo: String, nombre: String, apellido: String) async -> Resultado<DesafioCorreo>
    func verificarCodigoDeRegistro(correo: String, codigo: String) async -> Resultado<TokenDeRegistro>
    func completarRegistro(token: String, clave: String, aceptacion: AceptacionLegal,
                           perfil: PerfilEntrada) async -> Resultado<SesionAbierta>

    func entrar(correo: String, clave: String) async -> Resultado<SesionAbierta>

    func pedirCodigoDeClave(correo: String) async -> Resultado<DesafioCorreo>
    func verificarCodigoDeClave(correo: String, codigo: String) async -> Resultado<TokenDeReseteo>
    func cambiarClave(token: String, clave: String) async -> Resultado<SesionAbierta>

    func miPerfil() async -> Resultado<Perfil>
    func guardarPerfil(_ perfil: PerfilEntrada, anulando: Set<CampoAnulable>,
                       claveDeIdempotencia: String) async -> Resultado<Perfil>
    func objetivos() async -> Resultado<[ObjetivoDeUsuario]>
    func guardarObjetivos(_ objetivos: [ObjetivoDeUsuario]) async -> Resultado<[ObjetivoDeUsuario]>

    /// Si había una sesión guardada al abrir la app. Sincrónico a propósito: ver
    /// `RenovadorDeSesion.habiaSesionAlArrancar`.
    var habiaSesionAlArrancar: Bool { get }
    var sesionExpiradaAlArrancar: Bool { get }
    func haySesion() async -> Bool
    /// Borra las credenciales y vuelve YA, sin esperar a la red ni a una renovación
    /// en vuelo. El aviso al servidor sigue por detrás.
    func cerrarSesion() async
    func cierres() async -> AsyncStream<MotivoDeCierre>
}

public extension ServicioDeCuenta {
    func pedirCodigoDeRegistro(correo: String, nombre: String, apellido: String) async -> Resultado<DesafioCorreo> {
        await pedirCodigoDeRegistro(correo: correo)
    }
    func objetivos() async -> Resultado<[ObjetivoDeUsuario]> { .sinRed }
    func guardarObjetivos(_ objetivos: [ObjetivoDeUsuario]) async -> Resultado<[ObjetivoDeUsuario]> { .sinRed }
}

extension ServicioDeCuenta {
    public var sesionExpiradaAlArrancar: Bool { false }
}

/// El motor: lo que el servidor calcula y la app muestra, y lo que la persona
/// registra. Aparte de `ServicioDeCuenta` para que el Home pruebe su caché y sus
/// colas con un doble, sin arrastrar el alta entera.
///
/// Todas son rutas autenticadas y pasan por el renovador: un 401 se arregla
/// renovando una vez, no mostrando "se venció la sesión".
public protocol ServicioDelPlan: Sendable {
    func plan() async -> Resultado<Plan>
    func planes() async -> Resultado<[PlanDeObjetivo]>
    func rutina(delDia fechaMs: Int64) async -> Resultado<RutinaDelDia>
    func nutricion(delDia fechaMs: Int64) async -> Resultado<DiaNutricional>

    func guardarComida(id: String, _ comida: ComidaEntrada) async -> Resultado<ComidaRegistrada>
    func borrarComida(id: String) async -> Resultado<SinCuerpo>

    func sincronizarSeries(sesion: String, _ series: [SerieDeGimnasioEntrada],
                           claveDeIdempotencia: String) async -> Resultado<SesionDeGimnasio>
    func sesionDeGimnasio(_ id: String) async -> Resultado<SesionDeGimnasio>
    func sesionesDeGimnasio(limite: Int?, cursor: String?) async -> Resultado<Pagina<ResumenDeSesionDeGimnasio>>

    func ejercicios(limite: Int?, cursor: String?) async -> Resultado<Pagina<EjercicioCatalogado>>
    func diccionarioDeEjercicios() async -> Resultado<DiccionarioDeEjercicios>
}

public extension ServicioDelPlan {
    func diccionarioDeEjercicios() async -> Resultado<DiccionarioDeEjercicios> { .sinRed }
    func planes() async -> Resultado<[PlanDeObjetivo]> { .sinRed }
}

/// La actividad se guarda por id antes que su recorrido. El recorrido viaja
/// aparte para que el historial no devuelva miles de coordenadas por fila.
public struct PuntoDeRecorrido: Codable, Equatable, Sendable {
    public let lat: Double
    public let lon: Double
    public let atMs: Int64

    enum CodingKeys: String, CodingKey { case lat, lon, atMs = "at_ms" }

    public init(lat: Double, lon: Double, atMs: Int64) {
        self.lat = lat
        self.lon = lon
        self.atMs = atMs
    }
}

public struct RecorridoDeActividad: Codable, Equatable, Sendable {
    public let points: [PuntoDeRecorrido]
    public init(points: [PuntoDeRecorrido]) { self.points = points }
}

public protocol ServicioDeActividades: Sendable {
    func guardarActividad(id: String, _ actividad: ActividadEntrada) async -> Resultado<Actividad>
    func guardarRecorrido(id: String, _ puntos: [PuntoDeRecorrido]) async -> Resultado<RecorridoDeActividad>
    func actividades(limite: Int?, cursor: String?) async -> Resultado<Pagina<Actividad>>
    func recorrido(id: String) async -> Resultado<RecorridoDeActividad>
}

public final class ApiTrainer: ServicioDeCuenta, ServicioDelPlan, ServicioDeActividades {
    private let cliente: ClienteAPI
    private let renovador: RenovadorDeSesion

    public init(cliente: ClienteAPI, renovador: RenovadorDeSesion) {
        self.cliente = cliente
        self.renovador = renovador
    }

    // MARK: - Servicio

    /// ¿Está vivo el servidor? Lo primero que hay que poder responder.
    public func salud() async -> Resultado<Health> {
        await cliente.pedir(.get, "/health")
    }

    /// El aviso de salud y los términos, con la versión que después se acepta.
    ///
    /// 🛑 No están empaquetados en la app a propósito: un aviso legal que hay que
    /// corregir esperando la revisión de la tienda se queda mal escrito una semana.
    public func textosLegales() async -> Resultado<TextosLegales> {
        await cliente.pedir(.get, "/legal")
    }

    // MARK: - Registro

    /// Paso 1 de 3: pide el código al correo. Contesta 202 exista o no la cuenta
    /// (anti-enumeración, AGENTS.md §12).
    public func pedirCodigoDeRegistro(correo: String) async -> Resultado<DesafioCorreo> {
        await cliente.pedir(.post, "/auth/register", cuerpo: PedidoConCorreo(email: correo))
    }

    public func pedirCodigoDeRegistro(correo: String, nombre: String, apellido: String) async -> Resultado<DesafioCorreo> {
        await cliente.pedir(.post, "/auth/register",
                            cuerpo: PedidoRegistroConNombre(email: correo, firstName: nombre, lastName: apellido))
    }

    /// Paso 2 de 3: el código, a cambio de un permiso de un solo uso.
    public func verificarCodigoDeRegistro(correo: String, codigo: String) async -> Resultado<TokenDeRegistro> {
        await cliente.pedir(.post, "/auth/register/verify",
                            cuerpo: PedidoConCodigo(email: correo, code: codigo))
    }

    /// Paso 3 de 3: la contraseña y la aceptación legal. Abre la sesión.
    ///
    /// `perfil` va vacío y el contrato lo permite: los once pasos de perfil corren
    /// DESPUÉS, cada uno con su `PATCH /me` (decisión 0008).
    ///
    /// - Parameter aceptacion: la versión que la persona VIO, tal como vino de
    ///   `textosLegales()`. Si el servidor contesta `legal_version_stale`, el texto
    ///   cambió mientras tanto y hay que volver a pedirlo y a mostrarlo — no
    ///   reintentar con la versión vieja.
    public func completarRegistro(token: String, clave: String, aceptacion: AceptacionLegal,
                                  perfil: PerfilEntrada) async -> Resultado<SesionAbierta> {
        let respuesta: Resultado<Sesion> = await cliente.pedir(
            .post, "/auth/register/complete",
            cuerpo: PedidoCompletar(registrationToken: token, password: clave,
                                    profile: perfil, legal: aceptacion))
        return await abrir(respuesta)
    }

    // MARK: - Login

    public func entrar(correo: String, clave: String) async -> Resultado<SesionAbierta> {
        let respuesta: Resultado<Sesion> = await cliente.pedir(
            .post, "/auth/login", cuerpo: PedidoLogin(email: correo, password: clave))
        return await abrir(respuesta)
    }

    // MARK: - Recuperación

    /// Contesta que sí exista o no la cuenta, con el mismo costo de tiempo: la
    /// pantalla que lo usa NO puede prometer que el mensaje llegó.
    public func pedirCodigoDeClave(correo: String) async -> Resultado<DesafioCorreo> {
        await cliente.pedir(.post, "/auth/password/forgot", cuerpo: PedidoConCorreo(email: correo))
    }

    public func verificarCodigoDeClave(correo: String, codigo: String) async -> Resultado<TokenDeReseteo> {
        await cliente.pedir(.post, "/auth/password/verify",
                            cuerpo: PedidoConCodigo(email: correo, code: codigo))
    }

    /// 🛑 Cambiar la contraseña revoca las demás sesiones (AGENTS.md §12) y el
    /// servidor devuelve una nueva. Se usa: la app entra derecho, en vez de pedirle
    /// a alguien que tipee la contraseña que acaba de elegir.
    public func cambiarClave(token: String, clave: String) async -> Resultado<SesionAbierta> {
        let respuesta: Resultado<Sesion> = await cliente.pedir(
            .post, "/auth/password/reset", cuerpo: PedidoReseteo(resetToken: token, password: clave))
        return await abrir(respuesta)
    }

    // MARK: - Perfil

    public func miPerfil() async -> Resultado<Perfil> {
        await renovador.pedir(.get, "/me")
    }

    /// `PATCH /me` con lo que cambió y nada más.
    ///
    /// - Parameters:
    ///   - anulando: los campos que se quieren VACIAR. Viajan como `null` explícito;
    ///     si `perfil` trae un valor para ese campo, gana el valor.
    ///   - claveDeIdempotencia: 🛑 una por INTENTO, la misma entre reintentos de ese
    ///     intento. NO se deriva del cuerpo: volver atrás y volver a elegir lo de
    ///     antes es otro intento con el mismo contenido, y con una clave derivada el
    ///     servidor contestaría la respuesta guardada sin escribir nada
    ///     (docs/API.md §6).
    public func guardarPerfil(_ perfil: PerfilEntrada, anulando: Set<CampoAnulable>,
                              claveDeIdempotencia: String) async -> Resultado<Perfil> {
        await renovador.pedir(.patch, "/me", cuerpo: CuerpoDePerfil(perfil: perfil, anulando: anulando),
                              claveDeIdempotencia: claveDeIdempotencia)
    }

    // MARK: - El motor (1.1.0)

    /// El bloque entero. Viene completo a propósito: el plan del jueves no puede
    /// depender de tener señal el jueves (AGENTS.md §6). Sin objetivo, nivel,
    /// deporte, zona o días de entrenamiento, `profile_incomplete`.
    public func plan() async -> Resultado<Plan> {
        await renovador.pedir(.get, "/plan")
    }

    public func planes() async -> Resultado<[PlanDeObjetivo]> {
        await renovador.pedir(.get, "/plans")
    }

    public func objetivos() async -> Resultado<[ObjetivoDeUsuario]> {
        await renovador.pedir(.get, "/me/goals")
    }

    public func guardarObjetivos(_ objetivos: [ObjetivoDeUsuario]) async -> Resultado<[ObjetivoDeUsuario]> {
        await renovador.pedir(.put, "/me/goals", cuerpo: CuerpoDeObjetivos(goals: objetivos))
    }

    /// La rutina de fuerza del día, con la columna PREVIA.
    ///
    /// - Parameter fechaMs: cualquier instante del día. El servidor lo lleva al día
    ///   local con la zona del PERFIL, así que para hoy alcanza con "ahora".
    public func rutina(delDia fechaMs: Int64) async -> Resultado<RutinaDelDia> {
        await renovador.pedir(.get, "/plan/routine", consulta: Self.delDia(fechaMs))
    }

    /// Los objetivos del día y lo comido. 🛑 A veces NO hay objetivos y viene el
    /// motivo (AGENTS.md §9.2): quien lo muestre no puede suponer que están.
    public func nutricion(delDia fechaMs: Int64) async -> Resultado<DiaNutricional> {
        await renovador.pedir(.get, "/nutrition/day", consulta: Self.delDia(fechaMs))
    }

    /// `PUT /meals/{id}`. Idempotente POR ID: reintentarlo con el mismo id no crea
    /// dos, y por eso no lleva `Idempotency-Key` —el contrato no la declara acá—.
    /// El id lo genera el cliente ANTES del primer intento, y no cambia entre
    /// reintentos. Sobre un id ya borrado contesta `not_found`: borrar gana.
    public func guardarComida(id: String, _ comida: ComidaEntrada) async -> Resultado<ComidaRegistrada> {
        guard let ruta = Self.ruta("/meals/", id) else { return .respuestaRara(http: 0) }
        return await renovador.pedir(.put, ruta, cuerpo: comida)
    }

    /// `DELETE /meals/{id}`. Idempotente: borrar lo ya borrado también da 204.
    public func borrarComida(id: String) async -> Resultado<SinCuerpo> {
        guard let ruta = Self.ruta("/meals/", id) else { return .respuestaRara(http: 0) }
        return await renovador.pedir(.delete, ruta)
    }

    /// `POST /gym/sessions/{id}/sets`: no es "crear", es "esto es lo que tengo".
    /// Devuelve la sesión ENTERA ya fusionada, con `received_at_ms` en cada serie.
    ///
    /// - Parameter claveDeIdempotencia: 🛑 una por INTENTO —este lote—, y la misma
    ///   si ESE intento se reintenta. Con otro lote, otra clave: la misma clave con
    ///   otro cuerpo es un 409.
    public func sincronizarSeries(sesion: String, _ series: [SerieDeGimnasioEntrada],
                                  claveDeIdempotencia: String) async -> Resultado<SesionDeGimnasio> {
        guard let ruta = Self.ruta("/gym/sessions/", sesion, "/sets") else { return .respuestaRara(http: 0) }
        return await renovador.pedir(.post, ruta, cuerpo: PedidoDeSeries(sets: series),
                                     claveDeIdempotencia: claveDeIdempotencia)
    }

    /// Una sesión con sus series; `not_found` si todavía no existe.
    ///
    /// 🛑 Se pide DESPUÉS de mandar lo pendiente, nunca antes: lo que llegó al
    /// servidor le gana a lo que todavía no llegó (decisión 0006), y traer la
    /// sesión primero le haría perder al teléfono los cambios que no mandó.
    public func sesionDeGimnasio(_ id: String) async -> Resultado<SesionDeGimnasio> {
        guard let ruta = Self.ruta("/gym/sessions/", id) else { return .respuestaRara(http: 0) }
        return await renovador.pedir(.get, ruta)
    }

    /// El historial de sesiones, de la más nueva a la más vieja.
    public func sesionesDeGimnasio(limite: Int? = nil, cursor: String? = nil)
        async -> Resultado<Pagina<ResumenDeSesionDeGimnasio>> {
        await renovador.pedirPagina("/gym/sessions", consulta: Self.pagina(limite: limite, cursor: cursor))
    }

    /// El catálogo, de a una página. El cursor es opaco: vuelve tal cual vino.
    public func ejercicios(limite: Int? = nil, cursor: String? = nil)
        async -> Resultado<Pagina<EjercicioCatalogado>> {
        await renovador.pedirPagina("/exercises", consulta: Self.pagina(limite: limite, cursor: cursor))
    }

    public func diccionarioDeEjercicios() async -> Resultado<DiccionarioDeEjercicios> {
        await renovador.pedir(.get, "/exercises/dictionary")
    }

    public func guardarActividad(id: String, _ actividad: ActividadEntrada) async -> Resultado<Actividad> {
        guard let ruta = Self.ruta("/activities/", id) else { return .respuestaRara(http: 0) }
        return await renovador.pedir(.put, ruta, cuerpo: actividad)
    }

    public func guardarRecorrido(id: String, _ puntos: [PuntoDeRecorrido]) async -> Resultado<RecorridoDeActividad> {
        guard let ruta = Self.ruta("/activities/", id, "/route") else { return .respuestaRara(http: 0) }
        return await renovador.pedir(.put, ruta, cuerpo: RecorridoDeActividad(points: puntos))
    }

    public func actividades(limite: Int? = nil, cursor: String? = nil) async -> Resultado<Pagina<Actividad>> {
        await renovador.pedirPagina("/activities", consulta: Self.pagina(limite: limite, cursor: cursor))
    }

    public func recorrido(id: String) async -> Resultado<RecorridoDeActividad> {
        guard let ruta = Self.ruta("/activities/", id, "/route") else { return .respuestaRara(http: 0) }
        return await renovador.pedir(.get, ruta)
    }

    private static func delDia(_ fechaMs: Int64) -> [URLQueryItem] {
        [URLQueryItem(name: "date_ms", value: String(fechaMs))]
    }

    private static func pagina(limite: Int?, cursor: String?) -> [URLQueryItem] {
        var consulta: [URLQueryItem] = []
        if let limite { consulta.append(URLQueryItem(name: "limit", value: String(limite))) }
        if let cursor { consulta.append(URLQueryItem(name: "cursor", value: cursor)) }
        return consulta
    }

    /// La ruta con un id adentro, o `nil` si el id no es de los que acepta el
    /// contrato (letras, números y guiones, hasta 64).
    ///
    /// 🛑 Un id con `/`, `.` o `?` cambiaría la RUTA que se pide —`../me`—. Lo que no
    /// es un id válido no sale: el servidor lo rechazaría igual.
    static func ruta(_ prefijo: String, _ id: String, _ sufijo: String = "") -> String? {
        let permitidos = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        guard (1...64).contains(id.unicodeScalars.count),
              id.unicodeScalars.allSatisfy(permitidos.contains) else { return nil }
        return prefijo + id + sufijo
    }

    // MARK: - Sesión

    public var habiaSesionAlArrancar: Bool {
        renovador.habiaSesionAlArrancar
    }

    public var sesionExpiradaAlArrancar: Bool {
        renovador.sesionExpiradaAlArrancar
    }

    public func haySesion() async -> Bool {
        await renovador.haySesion
    }

    public func cerrarSesion() async {
        await renovador.cerrarSesion()
    }

    public func cierres() async -> AsyncStream<MotivoDeCierre> {
        await renovador.cierres()
    }

    private func abrir(_ respuesta: Resultado<Sesion>) async -> Resultado<SesionAbierta> {
        if case .ok(let sesion) = respuesta {
            await renovador.establecer(sesion)
        }
        return respuesta.map { SesionAbierta(usuario: $0.userId) }
    }
}

// MARK: - Los cuerpos de los pedidos

// Escritos a mano porque en el contrato están adentro de cada operación, sin
// nombre, y el generador sólo emite esquemas con nombre. Son los mismos que
// `ApiTrainer.kt`.

struct PedidoConCorreo: Encodable, Sendable {
    let email: String
}

struct PedidoRegistroConNombre: Encodable, Sendable {
    let email: String
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case email
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct PedidoConCodigo: Encodable, Sendable {
    let email: String
    let code: String
}

struct PedidoLogin: Encodable, Sendable {
    let email: String
    let password: String
}

struct PedidoReseteo: Encodable, Sendable {
    let resetToken: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case resetToken = "reset_token"
        case password
    }
}

struct PedidoCompletar: Encodable, Sendable {
    let registrationToken: String
    let password: String
    let profile: PerfilEntrada
    let legal: AceptacionLegal

    enum CodingKeys: String, CodingKey {
        case registrationToken = "registration_token"
        case password
        case profile
        case legal
    }
}

/// `POST /gym/sessions/{id}/sets`: el lote, adentro de `sets`.
struct PedidoDeSeries: Encodable, Sendable {
    let sets: [SerieDeGimnasioEntrada]
}

/// `PerfilEntrada` más los `null` explícitos.
///
/// El `Encodable` generado omite los opcionales en `nil` —que es lo que hace que
/// cada paso del perfil pueda guardar de a uno sin borrar lo de los otros—, y por
/// eso los `null` se agregan después, sobre el mismo objeto.
struct CuerpoDePerfil: Encodable, Sendable {
    let perfil: PerfilEntrada
    let anulando: Set<CampoAnulable>

    func encode(to encoder: Encoder) throws {
        try perfil.encode(to: encoder)
        var contenedor = encoder.container(keyedBy: ClaveDelContrato.self)
        for campo in anulando.sorted(by: { $0.rawValue < $1.rawValue }) where !tieneValor(campo) {
            try contenedor.encodeNil(forKey: ClaveDelContrato(campo.rawValue))
        }
    }

    private func tieneValor(_ campo: CampoAnulable) -> Bool {
        switch campo {
        case .apellido: return perfil.lastName != nil
        case .fechaDelObjetivo: return perfil.goalDateMs != nil
        }
    }
}

private struct ClaveDelContrato: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ nombre: String) { stringValue = nombre }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

// MARK: - Pasos diarios (contrato 1.3.0)

/// Los pasos de cada día en el servidor. Aparte de los otros servicios para que la
/// app lo pida con un `as?` y la maqueta, que no lo tiene, siga igual.
public protocol ServicioDePasos: Sendable {
    /// `GET /me/steps`: los días con pasos entre `desde` y `hasta` ("yyyy-MM-dd",
    /// las dos puntas incluidas, 366 días como mucho).
    func pasos(desde: String, hasta: String) async -> Resultado<[DiaDePasos]>
    /// `PUT /me/steps`: hasta 60 días. Devuelve cómo quedó cada uno (gana el más nuevo).
    ///
    /// - Parameter claveDeIdempotencia: una por intento —este lote—, la misma si ESE
    ///   intento se reintenta.
    func guardarPasos(_ dias: [DiaDePasosEntrada], claveDeIdempotencia: String) async -> Resultado<[DiaDePasos]>
}

extension ApiTrainer: ServicioDePasos {
    public func pasos(desde: String, hasta: String) async -> Resultado<[DiaDePasos]> {
        await renovador.pedir(.get, "/me/steps", consulta: [
            URLQueryItem(name: "from", value: desde),
            URLQueryItem(name: "to", value: hasta),
        ])
    }

    public func guardarPasos(_ dias: [DiaDePasosEntrada], claveDeIdempotencia: String) async -> Resultado<[DiaDePasos]> {
        await renovador.pedir(.put, "/me/steps", cuerpo: PedidoDePasos(days: dias),
                              claveDeIdempotencia: claveDeIdempotencia)
    }
}

/// `PUT /me/steps`: el lote, adentro de `days`.
struct PedidoDePasos: Encodable, Sendable {
    let days: [DiaDePasosEntrada]
}
