import Foundation

// =============================================================================
// La sesión: quién la tiene, cuándo renovarla y cuándo darla por muerta.
//
// Es B-008 cerrado del lado de iOS. El access token vive quince minutos
// (`ACCESS_TTL_S`), once pantallas de perfil con un aviso legal para leer se los
// comen sin esfuerzo, y sin renovación cada `PATCH /me` terminaría en "se venció
// la sesión".
//
// Las cuatro reglas:
//
// 1. **Por adelantado.** Si al access le quedan menos de 30 s, se renueva ANTES
//    de pedir. Un pedido que sale con un token a punto de vencer llega vencido.
// 2. **Ante un 401 `unauthorized`, UNA renovación y UN reintento.** Nunca un
//    bucle: si el token recién renovado también da 401, la sesión no sirve y se
//    cierra.
// 3. 🛑 **Una sola renovación en vuelo.** El servidor ROTA el refresh en cada uso
//    y, si ve uno ya usado, revoca la familia entera: es su señal de que alguien
//    lo copió. Dos pedidos que renuevan a la vez con el mismo refresh cierran la
//    sesión de quien los hizo. Por eso esto es un `actor` y la renovación es una
//    sola `Task` que esperan todos.
// 4. **Una respuesta perdida se reintenta sola.** Si `/auth/refresh` no contestó
//    —sin red o un 5xx—, el servidor pudo haber rotado igual, y la sesión nueva
//    quedó del otro lado. Durante dos minutos desde el canje, el MISMO refresh
//    devuelve el MISMO sucesor (decisión 0013), pero eso sólo sirve si alguien lo
//    vuelve a mandar a tiempo. Por eso se reintenta por detrás a los 5, 20 y 60
//    segundos, sin hacer esperar a nadie y siempre como LA renovación en vuelo de
//    la regla 3. Pasados 100 segundos ya no: el mismo refresh sería reuso.
//
// Con `invalid_refresh_token` o `session_revoked` no hay nada que reintentar: se
// borran las credenciales y se avisa por `cierres()`, que es lo que escucha la
// app para volver al login.
// =============================================================================

/// Por qué se cerró la sesión.
public enum MotivoDeCierre: Equatable, Sendable {
    /// La persona tocó "Cerrar sesión".
    case laPersonaCerro
    /// El servidor dijo que la sesión ya no vale: `invalid_refresh_token`,
    /// `session_revoked`, o un `unauthorized` que no se arregló renovando.
    case rechazada(codigo: String)
}

public actor RenovadorDeSesion {

    /// Treinta segundos: lo que tarda, en el peor caso razonable, un pedido en
    /// salir, esperar y volver. Menos que eso y el token vence en el viaje.
    public static let margenDeRenovacionMs: Int64 = 30_000

    /// A qué altura se vuelve a mandar una renovación que se quedó sin respuesta,
    /// contada desde que salió. Con la señal que va y viene en el sótano de un
    /// gimnasio, un solo reintento casi nunca alcanza.
    public static let reintentosDeRenovacionMs: [Int64] = [5_000, 20_000, 60_000]

    /// 🛑 El techo de los reintentos, contado desde que salió el primer pedido sin
    /// respuesta. El servidor devuelve el mismo sucesor durante dos minutos desde el
    /// canje (decisión 0013); después, el mismo refresh es reuso y revoca la familia
    /// entera. Cien segundos dejan veinte de margen para el viaje y los relojes.
    public static let ventanaDeReintentoMs: Int64 = 100_000

    static let noAutorizada = "unauthorized"
    static let revocada = "session_revoked"
    static let renovacionInvalida = "invalid_refresh_token"

    /// La hora del teléfono en milisegundos epoch, como los `*_at_ms` del contrato.
    public static let ahoraEnMs: @Sendable () -> Int64 = {
        Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }

    /// Esperar de verdad. Si la tarea se cancela —se cerró la sesión— se despierta
    /// antes, y quien esperaba mira si todavía tiene algo que hacer.
    public static let dormir: @Sendable (Int64) async -> Void = { ms in
        try? await Task.sleep(nanoseconds: UInt64(max(0, ms)) * 1_000_000)
    }

    private let cliente: ClienteAPI
    private let almacen: any AlmacenDeCredenciales
    private let reloj: @Sendable () -> Int64
    private let esperar: @Sendable (Int64) async -> Void
    private let alCerrar: @Sendable () -> Void

    private var sesion: Sesion?

    /// Si al crear el renovador había una sesión guardada en el llavero.
    ///
    /// Es `nonisolated` y se fija una sola vez a propósito: la app lo lee ANTES
    /// del primer cuadro para decidir entre el Home y la bienvenida. Preguntarle al
    /// actor sería asíncrono, y mientras llega la respuesta quien ya entró vería la
    /// bienvenida medio segundo — que se lee como "me sacó la sesión".
    public nonisolated let habiaSesionAlArrancar: Bool
    public nonisolated let sesionExpiradaAlArrancar: Bool

    /// 🪤 Si el reloj del teléfono está adelantado, un token recién emitido ya
    /// "vence" según él, y la regla 1 renovaría antes de CADA pedido: el doble de
    /// viajes y una rotación por pedido. Se detecta al recibir la sesión —un token
    /// nuevo tiene quince minutos, no treinta segundos— y, si pasa, se deja de
    /// renovar por adelantado para esa sesión y se confía en el 401.
    private var confiarEnElVencimiento = true

    private var renovacionEnCurso: Task<Renovacion, Never>?
    private var suscriptores: [UUID: AsyncStream<MotivoDeCierre>.Continuation] = [:]

    /// El refresh que salió y no tuvo respuesta, y cuándo salió POR PRIMERA VEZ: es
    /// lo más temprano en que el servidor pudo haberlo canjeado, y la ventana de la
    /// regla 4 se cuenta desde ahí.
    private var sinRespuesta: (refresco: String, desdeMs: Int64)?
    /// Los reintentos que valen ahora. Uno solo por vez.
    private var reintentoVigente: UUID?
    /// Las tareas de reintento que todavía no terminaron, también las canceladas.
    /// Guardarlas por `id` hace que una vieja, al terminar, no suelte a la nueva.
    private var tareasDeReintento: [UUID: Task<Void, Never>] = [:]
    /// El `POST /auth/logout` que sigue andando después de cerrar la sesión.
    private var avisoDeCierre: Task<Void, Never>?

    private enum Renovacion: Sendable {
        case renovada(Sesion)
        /// Se cerró, o ya estaba cerrada. `codigo` es el que se le devuelve a quien
        /// pidió.
        case cerrada(codigo: String)
        /// El servidor renovó, pero mientras el pedido viajaba la sesión se cerró o
        /// cambió, y no se adopta. Viaja igual: es el refresh más nuevo que existe, y
        /// el cierre de sesión tiene que revocar ÉSE y no el que ya rotó.
        case descartada(Sesion)
        /// No se pudo renovar, pero la sesión sigue: sin red, un 429, una respuesta
        /// rara. No hay motivo para tirar las credenciales por algo transitorio, y a
        /// quien pidió se le devuelve ESTO y no el 401 original: si no, la pantalla
        /// diría "se venció la sesión" de una sesión que sigue viva.
        case fallida(Resultado<Sesion>)
    }

    /// - Parameters:
    ///   - reloj: la hora en milisegundos epoch. Mide el vencimiento del access y
    ///     la ventana de los reintentos.
    ///   - esperar: cómo se esperan los reintentos de la regla 4. Los tests no
    ///     duermen: cambian esto.
    ///   - alCerrar: lo que, además de las credenciales, se va con la sesión —en la
    ///     app, las series del gimnasio que quedaron en disco—. Corre en el mismo
    ///     momento en que se borra el llavero, sea cual sea el motivo del cierre.
    public init(
        cliente: ClienteAPI,
        almacen: any AlmacenDeCredenciales,
        reloj: @escaping @Sendable () -> Int64 = RenovadorDeSesion.ahoraEnMs,
        esperar: @escaping @Sendable (Int64) async -> Void = RenovadorDeSesion.dormir,
        alCerrar: @escaping @Sendable () -> Void = {}
    ) {
        self.cliente = cliente
        self.almacen = almacen
        self.reloj = reloj
        self.esperar = esperar
        self.alCerrar = alCerrar
        let guardada = almacen.leer()
        if let guardada, guardada.refreshExpiresAtMs > reloj() {
            self.sesion = guardada
            self.habiaSesionAlArrancar = true
            self.sesionExpiradaAlArrancar = false
        } else {
            if guardada != nil {
                almacen.borrar()
                alCerrar()
                self.sesionExpiradaAlArrancar = true
            } else {
                self.sesionExpiradaAlArrancar = false
            }
            self.sesion = nil
            self.habiaSesionAlArrancar = false
        }
    }

    // MARK: - Lo que usa el resto de la app

    public var haySesion: Bool { sesion != nil }

    /// Guarda la sesión que devolvió login, alta o recuperación de contraseña.
    public func establecer(_ nueva: Sesion) {
        adoptar(nueva)
    }

    /// Los cierres de sesión, a medida que pasan. Cada llamada es un suscriptor
    /// propio: dos lugares que escuchan no se reparten los avisos.
    public func cierres() -> AsyncStream<MotivoDeCierre> {
        var continuacion: AsyncStream<MotivoDeCierre>.Continuation?
        let flujo = AsyncStream<MotivoDeCierre> { continuacion = $0 }
        guard let continuacion else { return flujo }

        let id = UUID()
        suscriptores[id] = continuacion
        continuacion.onTermination = { [weak self] _ in
            Task { await self?.quitarSuscriptor(id) }
        }
        return flujo
    }

    /// Un pedido autenticado, con las reglas del encabezado.
    public func pedir<Respuesta: Decodable & Sendable>(
        _ metodo: MetodoHTTP,
        _ ruta: String,
        consulta: [URLQueryItem] = [],
        cuerpo: (any Encodable & Sendable)? = nil,
        claveDeIdempotencia: String? = nil,
        como tipo: Respuesta.Type = Respuesta.self
    ) async -> Resultado<Respuesta> {
        let cliente = self.cliente
        // 🛑 La MISMA clave de idempotencia en el reintento: es el mismo intento de
        // escritura, que no llegó a aplicarse porque el token no pasó.
        return await conToken { token in
            await cliente.pedir(metodo, ruta, consulta: consulta, cuerpo: cuerpo, token: token,
                                claveDeIdempotencia: claveDeIdempotencia, como: tipo)
        }
    }

    /// Una página de una lista autenticada. Mismas reglas que `pedir`.
    public func pedirPagina<Elemento: Decodable & Sendable>(
        _ ruta: String,
        consulta: [URLQueryItem] = [],
        como tipo: Elemento.Type = Elemento.self
    ) async -> Resultado<Pagina<Elemento>> {
        let cliente = self.cliente
        return await conToken { token in
            await cliente.pedirPagina(ruta, consulta: consulta, token: token, como: tipo)
        }
    }

    /// Cierra la sesión: credenciales borradas YA, y `POST /auth/logout` por detrás.
    ///
    /// 🛑 Se borra PRIMERO y sin esperar nada —ni la red ni una renovación en
    /// vuelo—, y recién entonces vuelve. Quien toca "Cerrar sesión" puede cerrar la
    /// app al segundo siguiente: si el llavero se borrara después de esperar, el
    /// próximo arranque entraría con la sesión que la persona cerró. Y sin señal las
    /// credenciales tienen que irse igual: la revocación del servidor es una defensa
    /// de más, no la condición para salir.
    public func cerrarSesion() {
        guard let par = sesion else { return }
        let enCurso = renovacionEnCurso
        let confiaba = confiarEnElVencimiento
        cerrarLocalmente(.laPersonaCerro)
        avisoDeCierre = Task { await self.revocar(par, confiaba: confiaba, despuesDe: enCurso) }
    }

    // MARK: - Las reglas

    private func conToken<T>(_ hacer: (String) async -> Resultado<T>) async -> Resultado<T> {
        // Sin sesión no hay a quién preguntarle: es lo mismo que contestaría el
        // servidor, sin gastar el viaje.
        guard var vigente = sesion else { return .rechazado(codigo: Self.noAutorizada, http: 401) }

        if vigente.refreshExpiresAtMs <= reloj() {
            cerrarLocalmente(.rechazada(codigo: Self.renovacionInvalida))
            return .rechazado(codigo: Self.renovacionInvalida, http: 401)
        }

        // Regla 1: por adelantado.
        if confiarEnElVencimiento, vigente.accessExpiresAtMs - reloj() < Self.margenDeRenovacionMs {
            switch await renovar(despuesDe: vigente) {
            case .renovada(let nueva): vigente = nueva
            case .cerrada(let codigo): return .rechazado(codigo: codigo, http: 401)
            case .descartada: return .rechazado(codigo: Self.noAutorizada, http: 401)
            // Si la renovación no llegó, el pedido tampoco va a llegar: no se hace
            // esperar a la persona otros diez segundos para enterarse. La regla 4 ya
            // quedó reintentando por detrás.
            case .fallida(.sinRed): return .sinRed
            // Todavía le quedan unos segundos: se intenta igual.
            case .fallida: break
            }
        }

        let primero = await hacer(vigente.accessToken)
        if let codigo = primero.codigoDeRechazo {
            if codigo == Self.revocada {
                cerrar(siSigue: vigente, motivo: .rechazada(codigo: codigo))
                return primero
            }
            guard codigo == Self.noAutorizada else { return primero }
        } else {
            return primero
        }

        // Regla 2: una renovación y un reintento.
        switch await renovar(despuesDe: vigente) {
        case .renovada(let nueva):
            let segundo = await hacer(nueva.accessToken)
            if let codigo = segundo.codigoDeRechazo, codigo == Self.noAutorizada || codigo == Self.revocada {
                // Un 401 con un token recién emitido no se arregla reintentando.
                cerrar(siSigue: nueva, motivo: .rechazada(codigo: codigo))
            }
            return segundo
        case .cerrada(let codigo):
            return .rechazado(codigo: codigo, http: 401)
        case .descartada:
            return .rechazado(codigo: Self.noAutorizada, http: 401)
        case .fallida(let motivo):
            return Self.sinValor(motivo)
        }
    }

    /// El desenlace de una renovación que no salió bien, con el tipo de quien pidió.
    private static func sinValor<T>(_ motivo: Resultado<Sesion>) -> Resultado<T> {
        switch motivo {
        case .rechazado(let codigo, let http, let detalle): return .rechazado(codigo: codigo, http: http, detalle: detalle)
        case .sinRed: return .sinRed
        case .respuestaRara(let http): return .respuestaRara(http: http)
        // No pasa: una renovación que salió bien es `.renovada`, no `.fallida`.
        case .ok: return .respuestaRara(http: 0)
        }
    }

    /// Regla 3: una sola renovación en vuelo, la esperan todos.
    private func renovar(despuesDe usada: Sesion) async -> Renovacion {
        guard let actual = sesion, actual.userId == usada.userId else {
            // Se cerró mientras el pedido viajaba, o ahora hay otra persona adentro:
            // el reintento no puede salir con un token que no es de quien pidió.
            return .cerrada(codigo: Self.noAutorizada)
        }
        if actual.refreshExpiresAtMs <= reloj() {
            cerrarLocalmente(.rechazada(codigo: Self.renovacionInvalida))
            return .cerrada(codigo: Self.renovacionInvalida)
        }
        // Otro pedido ya la renovó mientras éste viajaba: no se gasta el refresh de
        // nuevo, que es justo lo que revoca la familia.
        if actual.accessToken != usada.accessToken { return .renovada(actual) }
        return await intentarRenovar(con: actual.refreshToken)
    }

    /// El único lugar que manda `/auth/refresh` para la sesión vigente. Lo usan los
    /// pedidos y los reintentos de la regla 4: así nunca salen dos a la vez.
    private func intentarRenovar(con refresco: String) async -> Renovacion {
        if let enCurso = renovacionEnCurso { return await enCurso.value }

        let salioEn = reloj()
        let tarea = Task { () -> Renovacion in
            let resultado = await self.pedirRenovacion(con: refresco)
            // Se suelta acá, en el actor y antes de que la esperen: así nadie llega a
            // ver una tarea terminada como si estuviera en vuelo.
            self.renovacionEnCurso = nil
            if case .fallida(let motivo) = resultado, Self.pudoPerderseLaRespuesta(motivo) {
                self.programarReintentos(de: refresco, salioEn: salioEn)
            }
            return resultado
        }
        renovacionEnCurso = tarea
        return await tarea.value
    }

    private func pedirRenovacion(con refresco: String) async -> Renovacion {
        let respuesta: Resultado<Sesion> = await cliente.pedir(
            .post, "/auth/refresh", cuerpo: PedidoConRefresco(refreshToken: refresco))

        // Mientras el pedido viajaba la sesión pudo cerrarse o cambiar por otra.
        let sigueSiendoLaMisma = sesion?.refreshToken == refresco

        switch respuesta {
        case .ok(let nueva):
            guard sigueSiendoLaMisma else { return .descartada(nueva) }
            adoptar(nueva)
            return .renovada(nueva)
        case .rechazado(let codigo, _, _) where codigo == Self.renovacionInvalida || codigo == Self.revocada:
            if sigueSiendoLaMisma { cerrarLocalmente(.rechazada(codigo: codigo)) }
            return .cerrada(codigo: codigo)
        case .rechazado, .sinRed, .respuestaRara:
            return .fallida(respuesta)
        }
    }

    // MARK: - Regla 4: la respuesta que se perdió

    /// Sin red o un 5xx: el pedido pudo haber llegado y el servidor pudo haber
    /// rotado sin que la respuesta volviera. Un 4xx, en cambio, es una respuesta que
    /// SÍ llegó, y reintentarla no cambia nada.
    private static func pudoPerderseLaRespuesta(_ motivo: Resultado<Sesion>) -> Bool {
        switch motivo {
        case .sinRed: return true
        case .rechazado(_, let http, _), .respuestaRara(let http): return http >= 500
        case .ok: return false
        }
    }

    private func programarReintentos(de refresco: String, salioEn: Int64) {
        // La sesión se cerró o cambió mientras el pedido viajaba: no hay qué recuperar.
        guard sesion?.refreshToken == refresco else { return }
        if sinRespuesta?.refresco != refresco { sinRespuesta = (refresco, salioEn) }
        guard reintentoVigente == nil else { return }
        let id = UUID()
        reintentoVigente = id
        tareasDeReintento[id] = Task { await self.reintentar(id: id) }
    }

    private func reintentar(id: UUID) async {
        defer {
            tareasDeReintento[id] = nil
            if reintentoVigente == id { reintentoVigente = nil }
        }
        for alturaMs in Self.reintentosDeRenovacionMs {
            guard let pendiente = sinRespuesta else { return }
            let falta = pendiente.desdeMs + alturaMs - reloj()
            if falta > 0 { await esperar(falta) }

            // Mientras se esperaba pudo cerrarse la sesión, entrar otra persona, o un
            // pedido pudo haber renovado. En los tres casos no queda nada que hacer.
            guard reintentoVigente == id,
                  let vigente = sinRespuesta, vigente.refresco == pendiente.refresco,
                  sesion?.refreshToken == vigente.refresco else { return }
            // 🛑 Fuera de la ventana, mandar el mismo refresh ya no es reintentar: es
            // reusarlo, y el servidor cerraría todas las sesiones de la familia.
            guard reloj() - vigente.desdeMs <= Self.ventanaDeReintentoMs else { return }

            guard case .fallida(let motivo) = await intentarRenovar(con: vigente.refresco),
                  Self.pudoPerderseLaRespuesta(motivo) else { return }
        }
    }

    private func olvidarLosReintentos() {
        sinRespuesta = nil
        if let id = reintentoVigente { tareasDeReintento[id]?.cancel() }
        reintentoVigente = nil
    }

    // MARK: - Cierre

    /// Le avisa al servidor de un cierre que en el teléfono ya pasó.
    private func revocar(_ guardada: Sesion, confiaba: Bool,
                         despuesDe enCurso: Task<Renovacion, Never>?) async {
        var par = guardada
        // Una renovación que estaba en vuelo termina DESPUÉS del cierre, con un
        // refresh nuevo que no se adopta. Si no se revoca ése, del otro lado queda
        // una sesión viva que no tiene nadie.
        if let enCurso, case .descartada(let nueva) = await enCurso.value {
            par = nueva
        }
        // Con el access vencido el servidor contestaría 401 y la sesión quedaría viva
        // del otro lado. Se renueva una vez, sólo para poder revocar lo último.
        if confiaba, par.accessExpiresAtMs - reloj() < Self.margenDeRenovacionMs {
            let renovada: Resultado<Sesion> = await cliente.pedir(
                .post, "/auth/refresh", cuerpo: PedidoConRefresco(refreshToken: par.refreshToken))
            if case .ok(let nueva) = renovada { par = nueva }
        }
        let _: Resultado<SinCuerpo> = await cliente.pedir(
            .post, "/auth/logout", cuerpo: PedidoConRefresco(refreshToken: par.refreshToken),
            token: par.accessToken)
    }

    // MARK: - Estado

    private func adoptar(_ nueva: Sesion) {
        sesion = nueva
        confiarEnElVencimiento = nueva.accessExpiresAtMs - reloj() >= Self.margenDeRenovacionMs
        // Con una sesión nueva, lo que se estaba por reintentar ya no existe.
        olvidarLosReintentos()
        // ⚠️ Si el Keychain no la acepta, la sesión sigue en memoria y la app anda.
        // Lo que se pierde es el próximo arranque: ahí se leería el refresh viejo,
        // que el servidor ya rotó, y habría que entrar de nuevo. No hay nada mejor
        // que hacer con el error que eso, y no se muestra: no es de la persona.
        try? almacen.guardar(nueva)
    }

    private func cerrar(siSigue usada: Sesion, motivo: MotivoDeCierre) {
        guard sesion?.accessToken == usada.accessToken else { return }
        cerrarLocalmente(motivo)
    }

    private func cerrarLocalmente(_ motivo: MotivoDeCierre) {
        sesion = nil
        confiarEnElVencimiento = true
        olvidarLosReintentos()
        almacen.borrar()
        alCerrar()
        for continuacion in suscriptores.values {
            continuacion.yield(motivo)
        }
    }

    private func quitarSuscriptor(_ id: UUID) {
        suscriptores[id] = nil
    }

    // MARK: - Para los tests

    /// Espera el `POST /auth/logout` que quedó andando. La app no lo espera nunca.
    func esperarElAvisoDeCierre() async {
        await avisoDeCierre?.value
    }

    /// Espera a que terminen los reintentos en segundo plano, también los cancelados.
    func esperarLosReintentos() async {
        while let tarea = tareasDeReintento.values.first {
            await tarea.value
        }
    }
}

/// `POST /auth/refresh` y `POST /auth/logout` llevan el mismo cuerpo. Los cuerpos
/// de pedido del contrato están escritos adentro de cada operación, sin nombre, y
/// el generador sólo emite esquemas con nombre: por eso se escriben a mano, como
/// en `ApiTrainer.kt`.
struct PedidoConRefresco: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
