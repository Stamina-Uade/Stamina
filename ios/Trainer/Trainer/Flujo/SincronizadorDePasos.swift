import Foundation
import TrainerCore

/// Los pasos de cada día: primero Apple Salud, después el servidor, y la carga a
/// mano sólo cuando Salud no da nada.
///
/// - Al volver a primer plano (`alAbrirLaApp`): si el permiso de Salud ya se pidió,
///   lee los últimos 30 días, guarda lo que cambió y lo sube. No muestra el pedido
///   de permiso: eso sólo pasa cuando la persona mira sus pasos.
/// - Al mirar pasos (`alVerPasos`): pide el permiso la primera vez, lee ese rango de
///   Salud y trae del servidor lo que haya (un teléfono nuevo no tiene el historial
///   en Salud, pero sí en la cuenta).
/// - Lo que no subió queda marcado en `AlmacenDeHitos`, en disco, y sale en la
///   próxima vuelta: sin red no se pierde nada ni se muestra ningún error.
///
/// 🛑 "Modo automático". HealthKit no dice si la persona dio permiso de lectura;
/// con el permiso negado las consultas no fallan, devuelven vacío. Entonces el modo
/// automático es: Salud disponible, el permiso ya pedido, la lectura de los últimos
/// 30 días sin error Y con al menos un día con pasos (un iPhone cuenta pasos solo,
/// así que con permiso siempre hay). En modo automático la carga a mano se esconde;
/// si no, queda, y lo cargado también sube.
@MainActor
final class SincronizadorDePasos: ObservableObject {
    static let compartido = SincronizadorDePasos()

    /// Los días que se leen de Salud al abrir la app.
    static let diasAlAbrir = 30
    /// El tope de `PUT /me/steps`.
    static let diasPorLote = 60
    /// El tope de `GET /me/steps`.
    static let diasPorConsulta = 366
    private static let claveModoAutomatico = "stamina_pasos_modo_automatico"

    /// Los pasos salen de Salud y no se cargan a mano. Se recuerda entre arranques
    /// para que el calendario no muestre "Editar" un instante antes de leer.
    @Published private(set) var modoAutomatico: Bool

    private let salud: ServicioDePasosSalud
    private let almacen: AlmacenDeHitos
    private let preferencias: UserDefaults
    /// `nil` con la maqueta, que no tiene servidor.
    private var servicio: (any ServicioDePasos)?

    private var leyendoAlAbrir = false
    private var subiendo = false
    /// Cuándo se trajo cada rango del servidor: mirar el calendario diez veces seguidas
    /// no lo pide diez veces.
    private var rangosTraidos: [String: Date] = [:]

    private init() {
        salud = .compartido
        almacen = .compartido
        preferencias = .standard
        modoAutomatico = UserDefaults.standard.bool(forKey: Self.claveModoAutomatico)
    }

    /// Lo llama el Home con el servidor de verdad (o `nil` con la maqueta).
    func configurar(servicio: (any ServicioDePasos)?) {
        self.servicio = servicio
    }

    // MARK: - Cuándo

    /// Al abrir la app o volver a primer plano.
    func alAbrirLaApp() async {
        guard !leyendoAlAbrir else { return }
        leyendoAlAbrir = true
        defer { leyendoAlAbrir = false }
        if await salud.yaSePidioPermiso() {
            let hoy = Date()
            let desde = Calendar.current.date(byAdding: .day, value: -(Self.diasAlAbrir - 1), to: hoy) ?? hoy
            await leerDeSalud(desde: desde, hasta: hoy, decideElModo: true)
        } else {
            cambiarModo(false)
        }
        await subirPendientes()
    }

    /// Al mirar los pasos de un rango (el calendario del año, una semana del plan).
    func alVerPasos(desde: Date, hasta: Date) async {
        let fin = min(hasta, Date())
        guard desde <= fin else { return }
        if salud.disponible {
            var pedido = await salud.yaSePidioPermiso()
            if !pedido { pedido = await salud.pedirPermiso() }
            if pedido {
                await leerDeSalud(desde: desde, hasta: fin, decideElModo: false)
            } else {
                cambiarModo(false)
            }
        } else {
            cambiarModo(false)
        }
        await traerDelServidor(desde: desde, hasta: fin)
        await subirPendientes()
    }

    // MARK: - Salud

    /// - Parameter decideElModo: sólo la lectura de los últimos días decide el modo.
    ///   Un rango viejo vacío (un teléfono nuevo) no dice nada del permiso.
    private func leerDeSalud(desde: Date, hasta: Date, decideElModo: Bool) async {
        guard let porDia = await salud.pasosDiarios(desde: desde, hasta: hasta) else {
            if decideElModo { cambiarModo(false) }
            return
        }
        almacen.registrarDeSalud(porDia, ahoraMs: RenovadorDeSesion.ahoraEnMs())
        if !porDia.isEmpty {
            cambiarModo(true)
        } else if decideElModo {
            cambiarModo(false)
        }
    }

    private func cambiarModo(_ automatico: Bool) {
        guard modoAutomatico != automatico else { return }
        modoAutomatico = automatico
        preferencias.set(automatico, forKey: Self.claveModoAutomatico)
    }

    // MARK: - Servidor

    /// `GET /me/steps` del rango, de a 366 días, y fusión con lo local (gana el más nuevo).
    func traerDelServidor(desde: Date, hasta: Date) async {
        guard let servicio, let dueno = almacen.dueno else { return }
        let calendario = Calendar.current
        var inicio = calendario.startOfDay(for: desde)
        let fin = calendario.startOfDay(for: hasta)
        while inicio <= fin {
            let tramoFin = min(fin, calendario.date(byAdding: .day, value: Self.diasPorConsulta - 1, to: inicio) ?? fin)
            let desdeClave = AlmacenDeHitos.clave(para: inicio)
            let hastaClave = AlmacenDeHitos.clave(para: tramoFin)
            let claveDelRango = "\(dueno)|\(desdeClave)|\(hastaClave)"
            let recienTraido = rangosTraidos[claveDelRango].map { Date().timeIntervalSince($0) < 5 * 60 } ?? false
            if !recienTraido {
                guard case .ok(let dias) = await servicio.pasos(desde: desdeClave, hasta: hastaClave) else { return }
                // 🛑 Si cambió la cuenta mientras viajaba, esto era de la otra.
                guard almacen.dueno == dueno else { return }
                almacen.fusionarDelServidor(dias)
                rangosTraidos[claveDelRango] = Date()
            }
            guard let siguiente = calendario.date(byAdding: .day, value: 1, to: tramoFin) else { return }
            inicio = siguiente
        }
    }

    /// `PUT /me/steps` con lo pendiente, de a 60 días. Sin red, o con el servidor
    /// caído, se corta y queda para la próxima.
    func subirPendientes() async {
        // Con una vuelta en el aire no sale otra: esa vuelve a mirar lo pendiente
        // después de cada lote, así que también sube lo que se agregó mientras tanto.
        guard let servicio, let dueno = almacen.dueno, !subiendo else { return }
        subiendo = true
        defer { subiendo = false }
        // Un tope de vueltas: si algo se reescribe sin parar, no se queda subiendo.
        for _ in 0..<20 {
            let lote = Array(almacen.pasosPendientes().prefix(Self.diasPorLote))
            guard !lote.isEmpty else { return }
            let resultado = await servicio.guardarPasos(lote, claveDeIdempotencia: UUID().uuidString)
            guard almacen.dueno == dueno else { return }
            switch resultado {
            case .ok(let respuesta):
                almacen.confirmarSubida(lote, respuesta: respuesta)
            case .rechazado(_, let http) where http == 400:
                // El lote no cumple el contrato: reintentarlo daría lo mismo.
                almacen.descartarPendientes(lote)
            default:
                // Sin red, 5xx, sesión vencida, 409 en vuelo: queda en disco.
                return
            }
        }
    }
}
