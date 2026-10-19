import Foundation
import SwiftUI
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// =============================================================================
// La sincronización teléfono↔reloj de la sesión en curso.
//
// Implementa `docs/decisiones/0006`. La lógica de qué gana está en
// `SerieRegistrada.fusionar`, con sus 14 tests; esto es el **transporte**.
//
// 🪤 POR QUÉ `updateApplicationContext` Y NO `sendMessage`.
//
// `sendMessage` exige que el otro lado esté **alcanzable en ese instante**, y el
// caso de uso de esta app es justo el contrario: AGENTS.md §10.2 dice que el
// reloj funciona "con el teléfono lejos o apagado", y §6 que el peor lugar de
// señal es donde se entrena. Además, entre simuladores `isReachable` se cae
// seguido, así que ni siquiera se puede probar bien.
//
// `updateApplicationContext` manda **el último estado conocido** y el sistema lo
// entrega cuando puede. Encaja exactamente con este modelo: como la fusión es
// idempotente y conmutativa, mandar el conjunto entero de series es
// auto-reparable — si se pierde un envío, el siguiente lo trae todo igual.
//
// Y por eso tampoco hace falta una cola de reintentos propia: el snapshot ES la
// cola. La clave de idempotencia de §5.2 sigue haciendo falta para el servidor,
// que es otro camino.
// =============================================================================

public enum EstadoDeSincronizacion: Equatable, Sendable {
    /// No hay reloj emparejado, o esta plataforma no soporta la sesión.
    case sinPar
    /// Hay par, pero la app del otro lado no está instalada.
    case sinAppEnElOtroLado
    /// Todo al día.
    case alDia
    /// Se fusionó algo y quedaron más series de las esperadas: la decisión 0006
    /// dice "unión, **y avisa**".
    case hayQueRevisar
}

/// Última foto de la salida del iPhone para la pantalla del reloj. La ruta se
/// acota para no saturar WatchConnectivity; la actividad completa va al servidor.
public struct EstadoDeSalidaCompartido: Codable, Equatable, Sendable {
    public let id: String
    /// Opcional para seguir decodificando snapshots de builds anteriores.
    public let deporte: DeporteDeSesion?
    public let corriendo: Bool
    public let pausada: Bool
    public let segundos: Int
    public let metros: Int
    public let ritmoSegPorKm: Int?
    public let puntos: [PuntoDeRecorrido]
    public let actualizadoMs: Int64

    public init(id: String, deporte: DeporteDeSesion? = nil,
                corriendo: Bool, pausada: Bool, segundos: Int, metros: Int,
                ritmoSegPorKm: Int?, puntos: [PuntoDeRecorrido], actualizadoMs: Int64) {
        self.id = id
        self.deporte = deporte
        self.corriendo = corriendo
        self.pausada = pausada
        self.segundos = segundos
        self.metros = metros
        self.ritmoSegPorKm = ritmoSegPorKm
        self.puntos = puntos
        self.actualizadoMs = actualizadoMs
    }
}

public struct EjercicioCompartido: Codable, Equatable, Sendable {
    public let id: String
    public let nombre: String
    public let repeticiones: Int
    public let pesoGramos: Int?
    public let series: Int
    public let etiqueta: String
    public let unidad: String

    public init(id: String, nombre: String, repeticiones: Int, pesoGramos: Int?,
                series: Int, etiqueta: String, unidad: String) {
        self.id = id
        self.nombre = nombre
        self.repeticiones = repeticiones
        self.pesoGramos = pesoGramos
        self.series = series
        self.etiqueta = etiqueta
        self.unidad = unidad
    }
}

/// Resumen de la sesión calculada por el servidor que el iPhone deja disponible
/// en el reloj. El reloj sólo la presenta; no deriva el plan.
public struct SesionCompartida: Codable, Equatable, Sendable {
    public let tipo: String
    public let distanciaMetros: Int?
    public let duracionMinutos: Int
    public let minutoDelDia: Int?
    public let geles: Int?
    public let aguaMl: Int?
    public let sales: Int?
    public let esDescanso: Bool?
    public let esFuerza: Bool?

    public init(tipo: String, distanciaMetros: Int?, duracionMinutos: Int,
                minutoDelDia: Int?, geles: Int?, aguaMl: Int? = nil, sales: Int? = nil,
                esDescanso: Bool? = false, esFuerza: Bool? = false) {
        self.tipo = tipo
        self.distanciaMetros = distanciaMetros
        self.duracionMinutos = duracionMinutos
        self.minutoDelDia = minutoDelDia
        self.geles = geles
        self.aguaMl = aguaMl
        self.sales = sales
        self.esDescanso = esDescanso
        self.esFuerza = esFuerza
    }
}

public struct DiaPlanificadoCompartido: Codable, Equatable, Sendable {
    public let fechaIso: String
    public let diaDeLaSemana: Int
    public let tipo: String
    public let distanciaMetros: Int?
    public let duracionMinutos: Int
    public let minutoDelDia: Int?
    public let geles: Int?
    public let aguaMl: Int?
    public let sales: Int?
    public let esDescanso: Bool?
    public let esFuerza: Bool?

    public init(fechaIso: String, diaDeLaSemana: Int, tipo: String, distanciaMetros: Int?,
                duracionMinutos: Int, minutoDelDia: Int?, geles: Int?, aguaMl: Int? = nil, sales: Int? = nil,
                esDescanso: Bool? = false, esFuerza: Bool? = false) {
        self.fechaIso = fechaIso
        self.diaDeLaSemana = diaDeLaSemana
        self.tipo = tipo
        self.distanciaMetros = distanciaMetros
        self.duracionMinutos = duracionMinutos
        self.minutoDelDia = minutoDelDia
        self.geles = geles
        self.aguaMl = aguaMl
        self.sales = sales
        self.esDescanso = esDescanso
        self.esFuerza = esFuerza
    }
}

/// El color (y el modo) que eligió la persona en el teléfono, para que el reloj
/// pinte con el mismo acento. Viaja en el application context —un reloj dormido
/// lo recibe al despertar— y, si el reloj está alcanzable, también como mensaje
/// para que el cambio se vea al instante.
///
/// El reloj sólo aplica el acento: watchOS es siempre oscuro (fondo negro puro,
/// AGENTS.md §10.2), así que el modo viaja pero se ignora.
public struct AparienciaCompartida: Equatable, Sendable {
    public static let claveAcento = "aparienciaAcento"
    public static let claveModo = "aparienciaModo"

    /// "r,g,b" (0–255) como `AcentoPersonalizado.clave`, o vacío = el color de
    /// fábrica. Un valor mal escrito se normaliza a vacío.
    public let acento: String
    /// `ModoApariencia.rawValue`, o vacío si no se sabe.
    public let modo: String

    public init(acento: String, modo: String) {
        let limpio = acento.trimmingCharacters(in: .whitespaces)
        self.acento = AcentoPersonalizado.componentes(de: limpio) == nil ? "" : limpio
        self.modo = modo
    }

    /// Lo que se suma al contexto, al mensaje inmediato y al `pong`.
    public var campos: [String: Any] {
        [Self.claveAcento: acento, Self.claveModo: modo]
    }

    /// `nil` si el diccionario no dice nada del color (un contexto de un build
    /// anterior, o uno que mandó el reloj): en ese caso no se toca lo guardado.
    public static func leer(de diccionario: [String: Any]) -> AparienciaCompartida? {
        guard let acento = diccionario[claveAcento] as? String else { return nil }
        return AparienciaCompartida(acento: acento, modo: diccionario[claveModo] as? String ?? "")
    }

    /// Lo que este dispositivo tiene guardado en sus ajustes.
    public static func guardada(en defaults: UserDefaults = .standard) -> AparienciaCompartida {
        AparienciaCompartida(
            acento: defaults.string(forKey: AcentoPersonalizado.clave) ?? "",
            modo: defaults.string(forKey: ModoApariencia.clave) ?? ModoApariencia.predeterminado.rawValue)
    }
}

public enum ComandoDeSalida: String, Sendable {
    case pausar, reanudar, terminar, descartar
    case musicaAlternar, musicaSiguiente, musicaAnterior, musicaRebobinar
}

/// Una salida terminada en el reloj viaja completa al teléfono como archivo
/// durable. El recorrido no se reduce en este paso.
public struct SalidaDelReloj: Codable, Sendable {
    public let id: String
    public let usuarioId: String
    public let deporte: DeporteDeSesion
    public let inicioMs: Int64
    public let segundos: Int
    public let metros: Int
    public let puntos: [PuntoDeRecorrido]
    public let pulsoMedio: Int?
    public let pulsoMaximo: Int?

    public init(id: String, usuarioId: String, deporte: DeporteDeSesion, inicioMs: Int64, segundos: Int,
                metros: Int, puntos: [PuntoDeRecorrido], pulsoMedio: Int?, pulsoMaximo: Int?) {
        self.id = id
        self.usuarioId = usuarioId
        self.deporte = deporte
        self.inicioMs = inicioMs
        self.segundos = segundos
        self.metros = metros
        self.puntos = puntos
        self.pulsoMedio = pulsoMedio
        self.pulsoMaximo = pulsoMaximo
    }
}

/// De qué cuenta son los datos que este teléfono guarda en disco (hitos, salidas
/// por subir). Lo actualiza `SincronizadorDeSesion` —por donde pasa cada cambio de
/// cuenta— y lo escuchan los almacenes, que separan lo guardado por cuenta en vez
/// de borrarlo: lo que todavía no llegó al servidor no se puede perder.
///
/// Es un id opaco del servidor, no un dato personal: va en `UserDefaults` para que
/// se pueda leer sin actor desde el cierre de sesión del renovador.
public enum DuenoDeLosDatosLocales {
    /// `userInfo`: `claveUsuario` (ausente al cerrar sesión) y `claveAnterior`.
    public static let cambio = Notification.Name("DuenoDeLosDatosLocales.cambio")
    public static let claveUsuario = "usuarioId"
    public static let claveAnterior = "anteriorId"
    static let claveGuardada = "stamina_dueno_de_los_datos_locales"

    public static var actual: String? {
        guard let id = UserDefaults.standard.string(forKey: claveGuardada), !id.isEmpty else { return nil }
        return id
    }

    static func identificar(_ id: String) {
        let anterior = actual
        UserDefaults.standard.set(id, forKey: claveGuardada)
        avisar(usuario: id, anterior: anterior)
    }

    static func olvidar() {
        let anterior = actual
        UserDefaults.standard.removeObject(forKey: claveGuardada)
        avisar(usuario: nil, anterior: anterior)
    }

    private static func avisar(usuario: String?, anterior: String?) {
        var info: [String: String] = [:]
        if let usuario { info[claveUsuario] = usuario }
        if let anterior { info[claveAnterior] = anterior }
        NotificationCenter.default.post(name: cambio, object: nil, userInfo: info)
    }
}

@MainActor
public final class SincronizadorDeSesion: NSObject, ObservableObject {

    /// Las series de la sesión en curso, ya fusionadas.
    @Published public private(set) var series: [SerieRegistrada] = []
    @Published public private(set) var estado: EstadoDeSincronizacion = .sinPar
    /// Cuándo se recibió algo del otro dispositivo por última vez.
    @Published public private(set) var ultimaSincronizacionMs: Int64?
    @Published public private(set) var salidaRemota: EstadoDeSalidaCompartido?
    @Published public private(set) var rutinaRemota: [EjercicioCompartido] = []
    @Published public private(set) var usuarioRemotoId: String?
    @Published public private(set) var sesionRemota: SesionCompartida?
    @Published public private(set) var cronogramaRemoto: [DiaPlanificadoCompartido] = []
    @Published public private(set) var telefonoAlcanzable: Bool = false
    /// En el reloj: la última apariencia que mandó el teléfono. Al cambiar,
    /// `EstadoReloj` reenvía el aviso y las pantallas se redibujan.
    @Published public private(set) var aparienciaRemota: AparienciaCompartida?

    private var salidaPublicada: EstadoDeSalidaCompartido?
    private var rutinaPublicada: [EjercicioCompartido]?
    private var sesionPublicada: SesionCompartida?
    private var cronogramaPublicado: [DiaPlanificadoCompartido] = []
    private var usuarioPublicadoId: String?
    /// En el teléfono: el color y el modo que van en cada snapshot.
    private var aparienciaPublicada: AparienciaCompartida?
    private var observadorDeAjustes: NSObjectProtocol?
    /// Se cerró la sesión (o se arrancó sin ninguna). Distinto de "todavía no se
    /// sabe quién es", que es el arranque con sesión guardada y el perfil sin cargar:
    /// ahí el reloj NO se tiene que desvincular.
    private var sinSesion = false
    public var alComandoDeSalida: ((ComandoDeSalida) -> Void)?
    /// Devuelve `true` cuando el teléfono ya incorporó la salida a su propia cola
    /// durable. Hasta entonces queda en el buzón de entrada y se vuelve a entregar.
    public var alRecibirSalidaDelReloj: ((SalidaDelReloj) -> Bool)? {
        didSet { reintentarSalidasRecibidas() }
    }
    public var alActivar: (() -> Void)?

    private let dispositivo: Dispositivo
    /// Cuántas series prescribe cada ejercicio. Sirve para el aviso de revisión.
    private var prescritasPorEjercicio: [String: Int] = [:]

    private let almacen: AlmacenDeSeries
    private let transferencias: AlmacenDeTransferenciasDeSalida

    public init(dispositivo: Dispositivo,
                almacen: AlmacenDeSeries = AlmacenDeSeries(),
                transferencias: AlmacenDeTransferenciasDeSalida = AlmacenDeTransferenciasDeSalida()) {
        self.dispositivo = dispositivo
        self.almacen = almacen
        self.transferencias = transferencias
        super.init()
        // Offline primero (§6): lo guardado localmente es lo primero que se ve,
        // antes de que llegue nada del otro lado ni del servidor.
        self.series = almacen.leer()
        #if os(watchOS)
        if let cache = UserDefaults.standard.data(forKey: "cache_cronograma_reloj"),
           let cached = try? JSONDecoder().decode([DiaPlanificadoCompartido].self, from: cache) {
            self.cronogramaRemoto = cached
        }
        #endif
        #if os(iOS)
        // Desde el arranque: así el primer snapshot ya lleva el color, aunque
        // todavía no se haya abierto el Home.
        self.aparienciaPublicada = AparienciaCompartida.guardada()
        observarAjustesDeApariencia()
        #endif
        activar()
    }

    deinit {
        if let observadorDeAjustes { NotificationCenter.default.removeObserver(observadorDeAjustes) }
    }

    public func configurar(prescritasPorEjercicio: [String: Int]) {
        self.prescritasPorEjercicio = prescritasPorEjercicio
        recalcularEstado()
    }

    // MARK: - Escribir

    /// Registra o corrige una serie **de este dispositivo**, y la propaga.
    public func registrar(clave: ClaveDeSerie, hecha: Bool, repeticiones: Int,
                          pesoGramos: Int?, salteada: Bool = false, esExtra: Bool = false) {
        let serie = SerieRegistrada(
            clave: clave, hecha: hecha, repeticiones: repeticiones, pesoGramos: pesoGramos,
            salteada: salteada, esExtra: esExtra,
            recibidaEnServidorMs: nil,
            registradaLocalMs: Int64((Date().timeIntervalSince1970 * 1000).rounded()),
            dispositivo: dispositivo)

        // 🛑 Una escritura de ESTE dispositivo no se fusiona con lo que había: lo
        // reemplaza, y queda pendiente hasta que la reciba el servidor. Fusionarla
        // perdería la corrección de una serie que ya llegó al servidor —la regla 1 de
        // `fusionar` le da la victoria a lo recibido— antes de haberla mandado.
        // `hecha` sigue siendo monotónica (regla 2).
        var escrita = serie
        escrita.hecha = hecha || (series.first { $0.clave == clave }?.hecha ?? false)
        aplicar(FusionDeSeries.unir(series.filter { $0.clave != clave }, [escrita]))
        propagar()
    }

    /// Elimina o desmarca una serie de este dispositivo y propaga el cambio.
    public func desmarcar(clave: ClaveDeSerie) {
        series.removeAll { $0.clave == clave }
        almacen.guardar(series)
        recalcularEstado()
        propagar()
    }

    /// Descarta todas las series registradas de la sesión actual.
    public func descartarSeries() {
        series.removeAll()
        almacen.borrar()
        recalcularEstado()
        propagar()
    }

    /// Fusiona lo que venga de afuera —el otro dispositivo o el servidor—.
    public func fusionar(_ entrantes: [SerieRegistrada]) {
        aplicar(FusionDeSeries.unir(series, entrantes))
        ultimaSincronizacionMs = Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }

    public func publicarSalida(_ salida: EstadoDeSalidaCompartido?) {
        salidaPublicada = salida
        propagar()
    }

    public func publicarRutina(_ rutina: [EjercicioCompartido]) {
        rutinaPublicada = rutina
        propagar()
    }

    public func publicarSesion(_ sesion: SesionCompartida?) {
        sesionPublicada = sesion
        propagar()
    }

    public func publicarCronograma(_ dias: [DiaPlanificadoCompartido]) {
        cronogramaPublicado = dias
        propagar()
    }

    public func publicarUsuario(_ id: String?) {
        if let id, !id.isEmpty {
            usuarioPublicadoId = id
            sinSesion = false
            DuenoDeLosDatosLocales.identificar(id)
        } else {
            // Quienes llaman con `nil` lo hacen porque no hay sesión: el arranque
            // sin cuenta, la sesión vencida o el perfil que se va al cerrar.
            usuarioPublicadoId = nil
            sinSesion = true
            DuenoDeLosDatosLocales.olvidar()
        }
        propagar()
    }

    /// Manda al reloj el color y el modo elegidos en el teléfono: en el
    /// application context (llega aunque el reloj esté dormido) y, si está
    /// alcanzable, también como mensaje inmediato. Repetir el mismo valor no
    /// manda nada.
    public func publicarApariencia(acento: String, modo: String) {
        let nueva = AparienciaCompartida(acento: acento, modo: modo)
        guard nueva != aparienciaPublicada else { return }
        aparienciaPublicada = nueva
        propagar()
        enviarAparienciaAlInstante(nueva)
    }

    /// `publicarApariencia` con lo guardado en los ajustes de este dispositivo.
    public func publicarAparienciaGuardada() {
        let guardada = AparienciaCompartida.guardada()
        publicarApariencia(acento: guardada.acento, modo: guardada.modo)
    }

    /// Ajustes escribe con `@AppStorage`; esto se entera de cualquier cambio
    /// —color o modo— sin depender de qué pantalla esté abierta.
    private func observarAjustesDeApariencia() {
        observadorDeAjustes = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.publicarAparienciaGuardada() }
        }
    }

    private func enviarAparienciaAlInstante(_ apariencia: AparienciaCompartida) {
        #if canImport(WatchConnectivity) && os(iOS)
        guard WCSession.isSupported() else { return }
        let sesion = WCSession.default
        guard sesion.activationState == .activated, sesion.isReachable else { return }
        // Sin respuesta y sin reintento: si se pierde, el contexto ya lo lleva.
        sesion.sendMessage(apariencia.campos, replyHandler: nil, errorHandler: nil)
        #endif
    }

    /// En el reloj: guarda el color que llegó y avisa para redibujar.
    private func recibirApariencia(_ apariencia: AparienciaCompartida) {
        #if os(watchOS)
        AparienciaDelReloj.compartida.aplicar(apariencia)
        if aparienciaRemota != apariencia { aparienciaRemota = apariencia }
        #endif
    }

    /// Simula la recepción de un usuario desde el otro dispositivo (útil para tests y previsualizaciones).
    public func simularUsuarioRemoto(_ id: String?) {
        usuarioRemotoId = id
    }

    /// Simula la recepción de una rutina desde el otro dispositivo (útil para tests).
    public func simularRutinaRemota(_ rutina: [EjercicioCompartido]) {
        rutinaRemota = rutina
    }

    /// Simula la recepción de una sesión desde el otro dispositivo (útil para tests).
    public func simularSesionRemota(_ sesion: SesionCompartida?) {
        sesionRemota = sesion
    }

    /// Limpia el usuario y el contenido publicado y notifica al reloj que la sesión se cerró.
    public func cerrarSesion() {
        usuarioPublicadoId = nil
        sinSesion = true
        DuenoDeLosDatosLocales.olvidar()
        salidaPublicada = nil
        rutinaPublicada = nil
        sesionPublicada = nil
        cronogramaPublicado = []
        cronogramaRemoto = []
        #if os(watchOS)
        UserDefaults.standard.removeObject(forKey: "cache_cronograma_reloj")
        #endif
        series = []
        almacen.borrar()
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let sesion = WCSession.default
            if sesion.activationState == .activated, sesion.isReachable {
                sesion.sendMessage(["cerrarSesion": true, "usuarioId": ""], replyHandler: nil, errorHandler: nil)
            }
        }
        #endif
        // 🪤 El aviso durable va DENTRO del snapshot: el application context guarda
        // sólo el último, así que un contexto aparte con `cerrarSesion` lo pisaba el
        // siguiente `propagar()` y un reloj lejos se quedaba vinculado.
        propagar()
    }

    /// Lo que el teléfono dice sobre la cuenta, en el contexto y en el `pong`.
    /// Sin dato (perfil todavía cargando) no dice nada: el reloj se queda como está.
    private func campoDeCuenta() -> [String: Any] {
        if let usuarioPublicadoId, !usuarioPublicadoId.isEmpty { return ["usuarioId": usuarioPublicadoId] }
        if sinSesion { return ["usuarioId": "", "cerrarSesion": true] }
        return [:]
    }

    /// Lo que el reloj entiende de un contexto o un `pong`: `nil` es "no dice
    /// nada"; `.some(nil)`, sesión cerrada (un id vacío también lo es).
    nonisolated static func cuentaInformada(en diccionario: [String: Any]) -> String?? {
        if let cerrar = diccionario["cerrarSesion"] as? Bool, cerrar { return .some(nil) }
        guard let usuario = diccionario["usuarioId"] as? String else { return nil }
        return usuario.isEmpty ? .some(nil) : .some(usuario)
    }

    public func verificarConexion() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            telefonoAlcanzable = false
            return
        }
        let sesion = WCSession.default
        if sesion.activationState != .activated {
            sesion.activate()
        }
        #if os(watchOS)
        let alcanzable = sesion.isReachable
        self.telefonoAlcanzable = alcanzable
        if alcanzable {
            sesion.sendMessage(["ping": true], replyHandler: { [weak self] respuesta in
                Task { @MainActor in
                    self?.telefonoAlcanzable = true
                    if let cuenta = SincronizadorDeSesion.cuentaInformada(en: respuesta) {
                        self?.usuarioRemotoId = cuenta
                    }
                    if let apariencia = AparienciaCompartida.leer(de: respuesta) {
                        self?.recibirApariencia(apariencia)
                    }
                }
            }, errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.telefonoAlcanzable = false
                }
            })
        }
        #endif
        #endif
    }

    public func solicitarComando(_ comando: ComandoDeSalida) -> Bool {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return false }
        let sesion = WCSession.default
        if sesion.isReachable {
            sesion.sendMessage(["comandoSalida": comando.rawValue], replyHandler: nil, errorHandler: nil)
        } else {
            sesion.transferUserInfo(["comandoSalida": comando.rawValue])
        }
        return true
        #else
        return false
        #endif
    }

    /// Devuelve `true` una vez que la copia íntegra quedó en el buzón durable del
    /// reloj. Desde ahí WatchConnectivity puede entregarla aun si el iPhone no está
    /// alcanzable en ese momento.
    public func enviarSalidaDelReloj(_ salida: SalidaDelReloj) -> Bool {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported(), transferencias.guardarParaEnviar(salida) != nil else { return false }
        programarTransferenciasPendientes()
        return true
        #else
        return false
        #endif
    }

    /// Reintenta lo recibido cuando ya existe perfil/sesión en el iPhone. Una
    /// salida sólo desaparece de este buzón cuando la capa siguiente confirma que
    /// la guardó en su propia cola.
    public func reintentarSalidasRecibidas() {
        guard let alRecibirSalidaDelReloj else { return }
        var restantes: [SalidaDelReloj] = []
        for salida in transferencias.leerRecibidas() {
            if !alRecibirSalidaDelReloj(salida) { restantes.append(salida) }
        }
        transferencias.guardarRecibidas(restantes)
    }

    private func aplicar(_ nuevas: [SerieRegistrada]) {
        series = nuevas
        almacen.guardar(nuevas)
        recalcularEstado()
    }

    private func recalcularEstado() {
        if FusionDeSeries.hayQueRevisar(series, prescritasPorEjercicio: prescritasPorEjercicio) {
            estado = .hayQueRevisar
            return
        }
        estado = estadoDelEnlace()
    }

    // MARK: - WatchConnectivity

    private func activar() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { estado = .sinPar; return }
        let sesion = WCSession.default
        sesion.delegate = self
        sesion.activate()
        #endif
    }

    private func recibirSalidaTerminada(_ salida: SalidaDelReloj) {
        transferencias.guardarRecibida(salida)
        reintentarSalidasRecibidas()
    }

    private func programarTransferenciasPendientes() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let sesion = WCSession.default
        guard sesion.activationState == .activated else { return }
        let yaProgramadas = Set(sesion.outstandingFileTransfers.map {
            $0.file.fileURL.standardizedFileURL
        })
        for archivo in transferencias.archivosParaEnviar()
            where !yaProgramadas.contains(archivo.standardizedFileURL) {
            sesion.transferFile(archivo, metadata: ["tipo": "salidaTerminada"])
        }
        #endif
    }

    private func estadoDelEnlace() -> EstadoDeSincronizacion {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return .sinPar }
        let sesion = WCSession.default
        #if os(iOS)
        guard sesion.isPaired else { return .sinPar }
        guard sesion.isWatchAppInstalled else { return .sinAppEnElOtroLado }
        #endif
        return .alDia
        #else
        return .sinPar
        #endif
    }

    /// Manda el conjunto entero. Es el snapshot, no un delta: ver el encabezado.
    private func propagar() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let sesion = WCSession.default
        guard sesion.activationState == .activated else { return }
        guard let datos = try? JSONEncoder().encode(series) else { return }
        var contexto: [String: Any] = ["series": datos]
        let salidaCodificada = salidaPublicada.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        contexto["salida"] = salidaCodificada
        if let rutinaPublicada, let rutina = try? JSONEncoder().encode(rutinaPublicada) {
            contexto["rutina"] = rutina
        }
        #if !os(watchOS)
        contexto.merge(campoDeCuenta()) { _, nuevo in nuevo }
        if let aparienciaPublicada {
            contexto.merge(aparienciaPublicada.campos) { _, nuevo in nuevo }
        }
        #endif
        contexto["sesionPlanificada"] = sesionPublicada.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        if let cronogramaData = try? JSONEncoder().encode(cronogramaPublicado), !cronogramaPublicado.isEmpty {
            contexto["cronograma"] = cronogramaData
        }
        do {
            try sesion.updateApplicationContext(contexto)
        } catch {
            // Que falle un envío no es un error de la persona ni pierde datos:
            // lo local ya está guardado y el próximo snapshot lleva todo igual.
            // 🛑 Y no se loguea el contenido: son datos de entrenamiento (§8).
            #if DEBUG
            print("[sincronizacion] no se pudo propagar el contexto: \(error)")
            #endif
        }
        // Mientras ambos procesos están abiertos, la foto de la salida viaja
        // también por el canal inmediato. El application context queda como
        // respaldo durable cuando el otro dispositivo no está alcanzable.
        if sesion.isReachable {
            if !salidaCodificada.isEmpty {
                sesion.sendMessage(["salidaEnCurso": salidaCodificada], replyHandler: nil, errorHandler: nil)
            } else {
                sesion.sendMessage(["salidaEnCursoTerminada": true], replyHandler: nil, errorHandler: nil)
            }
        } else {
            if !salidaCodificada.isEmpty {
                sesion.transferUserInfo(["salidaEnCurso": salidaCodificada])
            }
        }
        #endif
    }
}

#if canImport(WatchConnectivity)
extension SincronizadorDeSesion: WCSessionDelegate {

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            #if os(watchOS)
            self.telefonoAlcanzable = session.isReachable
            #endif
            self.recalcularEstado()
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                                    replyHandler: @escaping ([String: Any]) -> Void) {
        if message["ping"] as? Bool == true {
            Task { @MainActor in
                var respuesta: [String: Any] = ["pong": true]
                respuesta.merge(self.campoDeCuenta()) { _, nuevo in nuevo }
                if let apariencia = self.aparienciaPublicada {
                    respuesta.merge(apariencia.campos) { _, nuevo in nuevo }
                }
                replyHandler(respuesta)
            }
            return
        }
        self.session(session, didReceiveMessage: message)
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["ping"] as? Bool == true {
            Task { @MainActor in
                #if os(watchOS)
                self.telefonoAlcanzable = true
                #endif
            }
        }
        if let cerrar = message["cerrarSesion"] as? Bool, cerrar {
            Task { @MainActor in
                self.usuarioRemotoId = nil
                self.salidaRemota = nil
                self.rutinaRemota = []
                self.sesionRemota = nil
            }
        }
        if let raw = message["comandoSalida"] as? String,
           let comando = ComandoDeSalida(rawValue: raw) {
            Task { @MainActor in self.alComandoDeSalida?(comando) }
        }
        if let apariencia = AparienciaCompartida.leer(de: message) {
            Task { @MainActor in self.recibirApariencia(apariencia) }
        }
        if let datos = message["salidaEnCurso"] as? Data,
           let salida = try? JSONDecoder().decode(EstadoDeSalidaCompartido.self, from: datos) {
            Task { @MainActor in
                self.salidaRemota = salida
                self.ultimaSincronizacionMs = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            }
        } else if message["salidaEnCursoTerminada"] as? Bool == true {
            Task { @MainActor in
                self.salidaRemota = nil
                self.ultimaSincronizacionMs = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            }
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let datos = userInfo["salidaTerminada"] as? Data,
           let salida = try? JSONDecoder().decode(SalidaDelReloj.self, from: datos) {
            Task { @MainActor in self.recibirSalidaTerminada(salida) }
        }
        if let raw = userInfo["comandoSalida"] as? String,
           let comando = ComandoDeSalida(rawValue: raw) {
            Task { @MainActor in self.alComandoDeSalida?(comando) }
        }
        if let datos = userInfo["salidaEnCurso"] as? Data,
           let salida = try? JSONDecoder().decode(EstadoDeSalidaCompartido.self, from: datos) {
            Task { @MainActor in
                self.salidaRemota = salida
                self.ultimaSincronizacionMs = Int64((Date().timeIntervalSince1970 * 1000).rounded())
            }
        }
    }

    nonisolated public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["tipo"] as? String == "salidaTerminada",
              let datos = try? Data(contentsOf: file.fileURL),
              let salida = try? JSONDecoder().decode(SalidaDelReloj.self, from: datos) else { return }
        Task { @MainActor in self.recibirSalidaTerminada(salida) }
    }

    nonisolated public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer,
                                    error: Error?) {
        guard error == nil else { return }
        Task { @MainActor in
            self.transferencias.borrarEnviado(fileTransfer.file.fileURL)
        }
    }

    nonisolated public func session(_ session: WCSession,
                                    activationDidCompleteWith state: WCSessionActivationState,
                                    error: Error?) {
        Task { @MainActor in
            #if os(watchOS)
            self.telefonoAlcanzable = session.isReachable
            let contexto = session.receivedApplicationContext
            if let cuenta = SincronizadorDeSesion.cuentaInformada(en: contexto) {
                self.usuarioRemotoId = cuenta
            }
            if let apariencia = AparienciaCompartida.leer(de: contexto) {
                self.recibirApariencia(apariencia)
            }
            if let salidaData = contexto["salida"] as? Data,
               let salida = try? JSONDecoder().decode(EstadoDeSalidaCompartido.self, from: salidaData) {
                self.salidaRemota = salida
            }
            if let rutinaData = contexto["rutina"] as? Data,
               let rutina = try? JSONDecoder().decode([EjercicioCompartido].self, from: rutinaData) {
                self.rutinaRemota = rutina
            }
            if let sesionData = contexto["sesionPlanificada"] as? Data,
               let sesion = try? JSONDecoder().decode(SesionCompartida.self, from: sesionData) {
                self.sesionRemota = sesion
            }
            if let cronoData = contexto["cronograma"] as? Data,
               let crono = try? JSONDecoder().decode([DiaPlanificadoCompartido].self, from: cronoData) {
                self.cronogramaRemoto = crono
                UserDefaults.standard.set(cronoData, forKey: "cache_cronograma_reloj")
            }
            #endif
            self.recalcularEstado()
            // Al activarse, mandar lo propio: si el otro lado estuvo sin la app
            // abierta, esto es lo que lo pone al día.
            self.propagar()
            self.programarTransferenciasPendientes()
            self.reintentarSalidasRecibidas()
            self.alActivar?()
        }
    }

    nonisolated public func session(_ session: WCSession,
                                    didReceiveApplicationContext contexto: [String: Any]) {
        let entrantes = (contexto["series"] as? Data).flatMap {
            try? JSONDecoder().decode([SerieRegistrada].self, from: $0)
        }
        let salida = (contexto["salida"] as? Data).flatMap {
            try? JSONDecoder().decode(EstadoDeSalidaCompartido.self, from: $0)
        }
        let rutina = (contexto["rutina"] as? Data).flatMap {
            try? JSONDecoder().decode([EjercicioCompartido].self, from: $0)
        }
        let sesionPlanificada = (contexto["sesionPlanificada"] as? Data).flatMap {
            try? JSONDecoder().decode(SesionCompartida.self, from: $0)
        }
        let cronograma = (contexto["cronograma"] as? Data).flatMap { data -> [DiaPlanificadoCompartido]? in
            guard let decoded = try? JSONDecoder().decode([DiaPlanificadoCompartido].self, from: data) else { return nil }
            #if os(watchOS)
            UserDefaults.standard.set(data, forKey: "cache_cronograma_reloj")
            #endif
            return decoded
        }
        let apariencia = AparienciaCompartida.leer(de: contexto)
        Task { @MainActor in
            if let apariencia { self.recibirApariencia(apariencia) }
            if let entrantes { self.fusionar(entrantes) }
            self.salidaRemota = salida
            if let rutina { self.rutinaRemota = rutina }
            self.sesionRemota = sesionPlanificada
            if let cronograma { self.cronogramaRemoto = cronograma }
            if let cuenta = SincronizadorDeSesion.cuentaInformada(en: contexto) {
                self.usuarioRemotoId = cuenta
            }
        }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // Al cambiar de reloj hay que reactivar, o la sincronización se apaga
        // sin avisar.
        WCSession.default.activate()
    }
    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.recalcularEstado() }
    }
    #endif
}
#endif

// MARK: - Guardado local

/// Guarda las series en disco.
///
/// AGENTS.md §6: la base local es la fuente de verdad de la sesión en curso, no
/// la respuesta del servidor. Si la app se cierra a mitad de una sesión, lo
/// registrado tiene que seguir ahí.
///
/// 🛑 Esto **no** va al llavero: no son credenciales. Y tampoco lleva nada que
/// identifique a la persona — sólo series de un entrenamiento (§8, §12.1).
public final class AlmacenDeSeries: @unchecked Sendable {
    private let archivo: URL?

    public init(nombre: String = "sesion-en-curso.json") {
        let carpeta = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
        self.archivo = carpeta?.appendingPathComponent(nombre)
    }

    public func leer() -> [SerieRegistrada] {
        guard let archivo, let datos = try? Data(contentsOf: archivo) else { return [] }
        guard let series = try? JSONDecoder().decode([SerieRegistrada].self, from: datos) else {
            // Ilegible: se aparta antes de que el próximo guardado lo pise.
            ArchivoIlegible.apartar(archivo)
            return []
        }
        return series
    }

    public func guardar(_ series: [SerieRegistrada]) {
        guard let archivo, let datos = try? JSONEncoder().encode(series) else { return }
        // Pesos y repeticiones de un entrenamiento: cifrado hasta el primer desbloqueo,
        // igual que lo que se guarda del servidor (`CacheDelServidor`).
        try? datos.write(to: archivo, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    public func borrar() {
        guard let archivo else { return }
        try? FileManager.default.removeItem(at: archivo)
    }
}
