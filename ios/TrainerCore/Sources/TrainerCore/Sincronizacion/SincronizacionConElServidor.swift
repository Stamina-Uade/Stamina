import Foundation

// =============================================================================
// Las series del gimnasio contra el servidor: la decisión 0006, donde el ORDEN
// importa.
//
// El reloj y el teléfono se sincronizan entre ellos como siempre
// (`SincronizadorDeSesion`); esto es el otro camino, el del teléfono al servidor.
// Cuatro reglas:
//
// 1. 🛑 PRIMERO se manda lo pendiente, DESPUÉS se trae. Lo que llegó al servidor le
//    gana a lo que todavía no llegó (`SerieRegistrada.fusionar`, regla 1), así que
//    traer la sesión antes de subir lo propio le haría perder al teléfono los
//    cambios que no mandó. Si mandar falla, esa sesión no se trae.
// 2. 🛑 Una clave de idempotencia por INTENTO: la misma si ESE lote se reintenta, y
//    otra si el lote cambió —la misma clave con otro cuerpo es un 409—.
// 3. Sin red, lo pendiente se queda pendiente: ya está en el disco del
//    sincronizador, y sube cuando vuelve la red o cuando se vuelve a abrir la app.
// 4. La respuesta —la sesión ENTERA, con la hora de llegada de cada serie— se fusiona
//    con `SerieRegistrada.fusionar`, salvo en las series que cambiaron MIENTRAS el
//    pedido viajaba: ésas siguen pendientes y van en el próximo intento. Si no, la
//    versión del servidor, que ya llegó, les ganaría.
// =============================================================================

@MainActor
public final class SincronizacionConElServidor {

    /// El tope de un lote (`maxItems` del contrato). Una sesión real no llega, pero
    /// un lote de más sería un 400 que traba todo lo demás.
    public static let seriesPorLote = 200

    private let servicio: any ServicioDelPlan
    private let sincronizador: SincronizadorDeSesion
    private let sesionDeHoy: () -> String
    private let generacion: () -> Int
    private let nuevaClave: () -> String

    /// Los intentos que no terminaron bien, con su clave: si el mismo lote se vuelve a
    /// mandar, es un reintento de ESE intento.
    private var intentos: [(sesion: String, lote: [SerieDeGimnasioEntrada], clave: String)] = []
    private var enCurso: Task<Void, Never>?
    private var otraVuelta = false

    /// - Parameters:
    ///   - sesionDeHoy: el id de la sesión que se trae cuando no hay nada que mandar.
    ///   - generacion: cambia cuando se cierra la sesión (`CacheDelServidor.generacion`).
    ///     Lo que vuelve de un pedido que salió antes del cierre no se escribe.
    ///   - nuevaClave: los tests la cambian para saber qué clave viajó.
    public init(servicio: any ServicioDelPlan, sincronizador: SincronizadorDeSesion,
                sesionDeHoy: @escaping () -> String = { ClaveDeSerie.sesionDeGimnasio() },
                generacion: @escaping () -> Int = { 0 },
                nuevaClave: @escaping () -> String = { UUID().uuidString.lowercased() }) {
        self.servicio = servicio
        self.sincronizador = sincronizador
        self.sesionDeHoy = sesionDeHoy
        self.generacion = generacion
        self.nuevaClave = nuevaClave
    }

    /// Manda lo pendiente y trae lo que haya. Con una vuelta en el aire no sale otro
    /// pedido —dos a la vez con la misma clave serían un 409—: se anota otra vuelta
    /// para cuando termine.
    public func sincronizar() async {
        if let enCurso {
            otraVuelta = true
            await enCurso.value
            return
        }
        let tarea = Task { await self.vueltas() }
        enCurso = tarea
        await tarea.value
    }

    private func vueltas() async {
        while true {
            otraVuelta = false
            await unaVuelta()
            if !otraVuelta {
                enCurso = nil
                return
            }
        }
    }

    private func unaVuelta() async {
        let alSalir = generacion()
        let pendientes = sincronizador.series.filter { $0.recibidaEnServidorMs == nil && Self.cumpleElContrato($0) }
        let porSesion = Dictionary(grouping: pendientes, by: \.clave.sesion)

        // Regla 1: primero lo pendiente, sesión por sesión.
        for (sesion, series) in porSesion.sorted(by: { $0.key < $1.key }) {
            let entradas = series
                .sorted { ($0.clave.ejercicio, $0.clave.numero) < ($1.clave.ejercicio, $1.clave.numero) }
                .map(Self.entrada)
            for inicio in stride(from: 0, to: entradas.count, by: Self.seriesPorLote) {
                let lote = Array(entradas[inicio..<min(inicio + Self.seriesPorLote, entradas.count)])
                guard await mandar(lote, sesion: sesion, generacion: alSalir) else { return }
            }
        }

        // Nada pendiente de hoy: se trae lo que haya del otro lado (otro teléfono).
        // Con algo pendiente no hace falta: la respuesta del POST ya es la sesión entera.
        let hoy = sesionDeHoy()
        guard porSesion[hoy] == nil else { return }
        if case .ok(let sesion) = await servicio.sesionDeGimnasio(hoy) {
            fusionar(sesion, mandadas: [], generacion: alSalir)
        }
        // `not_found` es una sesión que todavía no existe: no hay nada que traer.
    }

    /// - Returns: si salió bien. Si no, la vuelta termina ahí y no se trae nada.
    private func mandar(_ lote: [SerieDeGimnasioEntrada], sesion: String, generacion alSalir: Int) async -> Bool {
        let clave = claveDelIntento(lote, sesion: sesion)
        let respuesta = await servicio.sincronizarSeries(sesion: sesion, lote, claveDeIdempotencia: clave)
        switch respuesta {
        case .ok(let sesionDelServidor):
            olvidarIntento(clave)
            fusionar(sesionDelServidor, mandadas: lote, generacion: alSalir)
            return true
        case .rechazado(_, let http) where http == 409 || (400..<500).contains(http) && http != 429:
            // 409: la clave chocó con otro cuerpo o con el mismo pedido en vuelo. Un 4xx
            // no se arregla reintentando lo mismo. En los dos casos el próximo intento
            // lleva otra clave, y las series siguen pendientes en el disco.
            olvidarIntento(clave)
            return false
        case .rechazado, .sinRed, .respuestaRara:
            // Pudo haber llegado sin que volviera la respuesta: se conserva la clave, y
            // el reintento de ESTE lote es el mismo intento (regla 2).
            return false
        }
    }

    private func claveDelIntento(_ lote: [SerieDeGimnasioEntrada], sesion: String) -> String {
        if let previo = intentos.first(where: { $0.sesion == sesion && $0.lote == lote }) { return previo.clave }
        let clave = nuevaClave()
        intentos.append((sesion, lote, clave))
        // Un lote que cambió ya no se va a reintentar igual: su clave no sirve más.
        intentos.removeAll { $0.sesion == sesion && $0.lote != lote }
        return clave
    }

    private func olvidarIntento(_ clave: String) {
        intentos.removeAll { $0.clave == clave }
    }

    /// Regla 4.
    private func fusionar(_ sesion: SesionDeGimnasio, mandadas: [SerieDeGimnasioEntrada], generacion alSalir: Int) {
        // La sesión se cerró mientras el pedido viajaba: lo que volvió es de quien se fue.
        guard generacion() == alSalir else { return }
        let actuales = Dictionary(sincronizador.series.map { ($0.clave, $0) }, uniquingKeysWith: { a, _ in a })
        let mandadasPorClave = Dictionary(
            mandadas.map { (ClaveDeSerie(sesion: sesion.sessionId, ejercicio: $0.exerciseId, numero: Int($0.number)), $0) },
            uniquingKeysWith: { a, _ in a })
        let entrantes = sesion.sets
            .map { Self.registrada($0, sesion: sesion.sessionId) }
            .filter { entrante in
                guard let local = actuales[entrante.clave], local.recibidaEnServidorMs == nil else { return true }
                // Pendiente, y no es lo que viajó en este pedido: cambió en el medio, o
                // nunca se mandó. Sigue pendiente.
                return mandadasPorClave[entrante.clave] == Self.entrada(local)
            }
        guard !entrantes.isEmpty else { return }
        sincronizador.fusionar(entrantes)
    }

    // MARK: - Del disco al contrato, y de vuelta

    /// Lo que el contrato acepta (`SerieDeGimnasioEntrada`). Una serie fuera de eso no
    /// viaja: el servidor rechazaría el lote entero, y trabaría también las buenas.
    /// Se queda en el teléfono, a la vista.
    public static func cumpleElContrato(_ serie: SerieRegistrada) -> Bool {
        let id = serie.clave.ejercicio.unicodeScalars
        let permitidos = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        return (1...64).contains(id.count)
            && id.first.map { $0 != "-" } == true
            && id.allSatisfy(permitidos.contains)
            && (1...50).contains(serie.clave.numero)
            && (0...1_000).contains(serie.repeticiones)
            && (serie.pesoGramos.map { (0...1_000_000).contains($0) } ?? true)
    }

    static func entrada(_ serie: SerieRegistrada) -> SerieDeGimnasioEntrada {
        SerieDeGimnasioEntrada(
            exerciseId: serie.clave.ejercicio,
            number: Int64(serie.clave.numero),
            done: serie.hecha,
            reps: Int64(serie.repeticiones),
            weightG: serie.pesoGramos.map { Int64($0) },
            skipped: serie.salteada,
            isExtra: serie.esExtra,
            recordedAtMs: serie.registradaLocalMs,
            device: serie.dispositivo == .reloj ? .reloj : .telefono)
    }

    static func registrada(_ serie: SerieDeGimnasio, sesion: String) -> SerieRegistrada {
        SerieRegistrada(
            clave: ClaveDeSerie(sesion: sesion, ejercicio: serie.exerciseId, numero: Int(serie.number)),
            hecha: serie.done,
            repeticiones: Int(serie.reps),
            pesoGramos: serie.weightG.map { Int($0) },
            salteada: serie.skipped,
            esExtra: serie.isExtra,
            recibidaEnServidorMs: serie.receivedAtMs,
            registradaLocalMs: serie.recordedAtMs,
            dispositivo: serie.device == .reloj ? .reloj : .telefono)
    }
}
