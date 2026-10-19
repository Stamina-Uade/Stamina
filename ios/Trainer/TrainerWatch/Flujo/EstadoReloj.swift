import Combine
import Foundation
import SwiftUI
import TrainerCore
#if os(watchOS)
import WatchKit
#endif

/// El estado del reloj: **la sesión en curso, y nada más.**
///
/// 🛑 AGENTS.md §10.2, la regla que gobierna este archivo entero:
///
///   *"El reloj no escribe configuración de la cuenta. Los ajustes que el reloj
///    ofrece valen sólo para la sesión en curso y se descartan al terminarla."*
///
/// Por eso `avisosDeSales` y `guiaDeRutina` son propiedades comunes y **no se
/// persisten en ningún lado**: al terminar la sesión vuelven a su valor inicial.
/// Eso le saca un caso entero al conflicto teléfono↔reloj, porque un dispositivo
/// que está offline la mitad del tiempo no tiene preferencias que sincronizar.
public struct ParcialKilometro: Identifiable, Equatable {
    public var id: Int { numero }
    public let numero: Int
    public let segundos: Int
    public let ritmoSegPorKm: Int?
    public let metros: Int
    public let completado: Bool

    public init(numero: Int, segundos: Int, ritmoSegPorKm: Int?, metros: Int, completado: Bool) {
        self.numero = numero
        self.segundos = segundos
        self.ritmoSegPorKm = ritmoSegPorKm
        self.metros = metros
        self.completado = completado
    }
}

public struct ObjetivoSeries: Equatable {
    public let totalSeries: Int
    public let metrosPorSerie: Int
    public let descripcion: String

    public init(totalSeries: Int, metrosPorSerie: Int, descripcion: String) {
        self.totalSeries = totalSeries
        self.metrosPorSerie = metrosPorSerie
        self.descripcion = descripcion
    }
}

public struct ItemSerieObjetivo: Identifiable, Equatable {
    public var id: Int { numero }
    public let numero: Int
    public let metrosObjetivo: Int
    public var metrosCompletados: Int
    public var segundos: Int?
    public var ritmoSegPorKm: Int?
    public var completada: Bool

    public init(numero: Int, metrosObjetivo: Int, metrosCompletados: Int = 0,
                segundos: Int? = nil, ritmoSegPorKm: Int? = nil, completada: Bool = false) {
        self.numero = numero
        self.metrosObjetivo = metrosObjetivo
        self.metrosCompletados = metrosCompletados
        self.segundos = segundos
        self.ritmoSegPorKm = ritmoSegPorKm
        self.completada = completada
    }
}

public enum DetectorDeSeries {
    public static func detectar(en texto: String) -> ObjetivoSeries? {
        let limpio = texto.lowercased()
        let patrones = [
            #"(\d+)\s*(?:series|pasadas|intervalos|repeticiones)\s*(?:de\s*)?(\d+)\s*(?:m|metros)?"#,
            #"(\d+)\s*x\s*(\d+)\s*(?:m|metros)?"#
        ]
        for patron in patrones {
            if let regex = try? NSRegularExpression(pattern: patron, options: .caseInsensitive),
               let match = regex.firstMatch(in: limpio, options: [], range: NSRange(location: 0, length: limpio.utf16.count)) {
                if let r1 = Range(match.range(at: 1), in: limpio),
                   let r2 = Range(match.range(at: 2), in: limpio),
                   let total = Int(limpio[r1]),
                   let metros = Int(limpio[r2]),
                   total > 0 && metros > 0 {
                    return ObjetivoSeries(totalSeries: total, metrosPorSerie: metros, descripcion: texto)
                }
            }
        }
        return nil
    }
}

@MainActor
final class EstadoReloj: ObservableObject {

    enum Pantalla: String, CaseIterable {
        case abrir, metricas, rutina, controles, avisos, mapa
        case ajustes, confirmarFinalizacion, sinMovimiento, resumen, gimnasio, sinTelefono
        case musica, parciales
        case resumenGimnasio
    }

    @Published private(set) var pantalla: Pantalla = .abrir
    @Published var deporte: DeporteDeSesion = .running
    @Published var iconoDeporteEnCurso: String? = nil
    @Published private(set) var corriendo = false
    @Published private(set) var pausada = false
    @Published var pantallaBloqueada = false
    /// El ritmo alterna entre promedio y parcial al tocarlo.
    @Published var ritmoParcial = false
    @Published private(set) var fuenteLocal = false
    @Published private(set) var sistemaDeUnidades: SistemaDeUnidades

    // MARK: - Ajustes DE LA SESIÓN. No persisten. Ver el encabezado.

    @Published var avisosDeSales = true
    @Published var guiaDeRutina = true
    @Published var avisosDeAvituallamiento = true
    @Published var gelesQueLleva = 0
    @Published var salesQueLleva = 0
    @Published var aguaMlQueLleva = 0
    @Published var avisoDeAvituallamiento: TipoDeAvisoDeAvituallamiento?
    private var planificadorDeAvituallamiento = PlanificadorDeAvituallamiento()
    private var idDeSalidaConAvisos: String?

    func cerrarAvisoDeAvituallamiento() {
        avisoDeAvituallamiento = nil
    }

    private func evaluarAvisoDeAvituallamiento(segundos: Int, deporte: DeporteDeSesion) {
        guard avisosDeAvituallamiento, avisoDeAvituallamiento == nil else { return }
        let insumos = InsumosDeSalida(geles: gelesQueLleva, sales: salesQueLleva,
                                     aguaMl: aguaMlQueLleva)
        if let aviso = planificadorDeAvituallamiento.siguiente(
            segundos: segundos, insumos: insumos, deporte: deporte) {
            avisoDeAvituallamiento = aviso
            #if os(watchOS)
            WKInterfaceDevice.current().play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                WKInterfaceDevice.current().play(.directionUp)
            }
            #endif
        }
    }

    // MARK: - Gimnasio en la muñeca, sincronizado con el teléfono

    @Published var ejercicioActual = 0
    @Published var repeticiones = 1
    @Published var pesoKg = 0
    @Published var seriesExtraPorEjercicio: [String: Int] = [:]

    /// 🛑 Las series no viven acá: viven en el sincronizador, que las fusiona con
    /// lo que registre el teléfono (decisión 0006).
    let sincronizador = SincronizadorDeSesion(dispositivo: .reloj)
    #if os(watchOS)
    lazy var seguimiento = SeguimientoDelReloj(sincronizador: sincronizador)
    #endif
    let idDeSesion = ClaveDeSerie.sesionDeGimnasio()
    private var suscripciones = Set<AnyCancellable>()
    private static let claveDeUnidades = "sistema-de-unidades-del-reloj"
    private static let claveCompartirUbicacion = "compartir-ubicacion-del-reloj"
    private static let clavePausaAutoCarrera = "pausa_auto_carrera"
    private static let clavePausaAutoBici = "pausa_auto_bici"
    private static let claveAvisosAudioParciales = "avisos_audio_parciales"
    private static let claveAvisosAudioInicioFinPausa = "avisos_audio_inicio_fin_pausa"
    private static let claveVolumenAudio = "volumen_audio_entreno"

    @Published var compartirUbicacion: Bool {
        didSet {
            UserDefaults.standard.set(compartirUbicacion, forKey: Self.claveCompartirUbicacion)
        }
    }

    @Published var pausaAutoCarrera: Bool {
        didSet {
            UserDefaults.standard.set(pausaAutoCarrera, forKey: Self.clavePausaAutoCarrera)
        }
    }

    @Published var pausaAutoBici: Bool {
        didSet {
            UserDefaults.standard.set(pausaAutoBici, forKey: Self.clavePausaAutoBici)
        }
    }

    @Published var avisosAudioParciales: Bool {
        didSet {
            UserDefaults.standard.set(avisosAudioParciales, forKey: Self.claveAvisosAudioParciales)
        }
    }

    @Published var avisosAudioInicioFinPausa: Bool {
        didSet {
            UserDefaults.standard.set(avisosAudioInicioFinPausa, forKey: Self.claveAvisosAudioInicioFinPausa)
        }
    }

    @Published var volumenAudio: Double {
        didSet {
            UserDefaults.standard.set(volumenAudio, forKey: Self.claveVolumenAudio)
        }
    }

    // MARK: - Música en el Reloj

    @Published var musicaReproduciendo: Bool = true
    @Published var cancionActual: CancionReproduciendo? = nil
    @Published var volumenMusica: Double = 0.7
    @Published var tiempoReproduccionActual: Double = 0.0

    private var indiceCancionActual: Int = 0
    private let listaMusicaEntrenamiento: [CancionReproduciendo] = [
        CancionReproduciendo(titulo: "Running Cadence 180", artista: "Trainer Beats", album: "Cardio Energy"),
        CancionReproduciendo(titulo: "Marathon Rhythm", artista: "Stamina Audio", album: "Cardio Energy"),
        CancionReproduciendo(titulo: "High Altitude", artista: "Peak Performance", album: "Elevation"),
        CancionReproduciendo(titulo: "Endurance Flow", artista: "Tempo Track", album: "Rhythm Run")
    ]

    public struct CancionReproduciendo: Equatable {
        public var titulo: String
        public var artista: String
        public var album: String

        public init(titulo: String, artista: String, album: String = "") {
            self.titulo = titulo
            self.artista = artista
            self.album = album
        }
    }

    func actualizarInfoMusica() {
        if cancionActual == nil {
            cancionActual = listaMusicaEntrenamiento[indiceCancionActual % listaMusicaEntrenamiento.count]
        }
    }

    func alternarReproduccionMusica() {
        musicaReproduciendo.toggle()
        _ = sincronizador.solicitarComando(.musicaAlternar)
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    func siguienteCancion() {
        indiceCancionActual = (indiceCancionActual + 1) % listaMusicaEntrenamiento.count
        cancionActual = listaMusicaEntrenamiento[indiceCancionActual]
        tiempoReproduccionActual = 0.0
        _ = sincronizador.solicitarComando(.musicaSiguiente)
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    func anteriorCancion() {
        // Si la canción lleva más de 2 segundos, retrocede a 0 (inicio de la pista).
        // Si ya está en 0 (o <= 2 segundos), retrocede a la canción anterior.
        if tiempoReproduccionActual > 2.0 {
            tiempoReproduccionActual = 0.0
            _ = sincronizador.solicitarComando(.musicaRebobinar)
        } else {
            indiceCancionActual = (indiceCancionActual - 1 + listaMusicaEntrenamiento.count) % listaMusicaEntrenamiento.count
            cancionActual = listaMusicaEntrenamiento[indiceCancionActual]
            tiempoReproduccionActual = 0.0
            _ = sincronizador.solicitarComando(.musicaAnterior)
        }
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    // MARK: - Parciales por Km y Objetivo de Series

    @Published var objetivoSeries: ObjetivoSeries? = nil
    @Published var itemsSeries: [ItemSerieObjetivo] = []
    @Published var serieActualIndice: Int = 0
    @Published var metrosInicioSerieActual: Int = 0
    @Published var segundosInicioSerieActual: Int = 0
    @Published var objetivoSeriesContinuado: Bool = false
    @Published var mostrarAvisoFinObjetivoSeries: Bool = false

    @Published var parcialesKm: [ParcialKilometro] = []
    @Published var metrosUltimoKm: Int = 0
    @Published var segundosUltimoKm: Int = 0

    func continuarTrasFinDeSeries() {
        mostrarAvisoFinObjetivoSeries = false
        objetivoSeriesContinuado = true
    }

    func finalizarDesdeFinDeSeries() {
        mostrarAvisoFinObjetivoSeries = false
        solicitarFinalizacion()
    }

    func cancelarAvisoFinDeSeries() {
        mostrarAvisoFinObjetivoSeries = false
    }

    var parcialKmEnCurso: ParcialKilometro? {
        guard corriendo || metros > 0 else { return nil }
        let currentMetros = self.metros
        let currentSegundos = self.segundos
        let numero = parcialesKm.count + 1
        let metrosTramo = max(0, currentMetros - metrosUltimoKm)
        let segsTramo = max(1, currentSegundos - segundosUltimoKm)
        let ritmo: Int? = metrosTramo >= 20 ? Int((Double(segsTramo) * 1000.0 / Double(metrosTramo)).rounded()) : nil
        return ParcialKilometro(
            numero: numero,
            segundos: segsTramo,
            ritmoSegPorKm: ritmo,
            metros: metrosTramo,
            completado: false
        )
    }

    /// Lista de parciales listados de ABAJO hacia ARRIBA (1 en el fondo, N en el tope)
    var listaParcialesVisuales: [ParcialKilometro] {
        var lista: [ParcialKilometro] = []
        if let actual = parcialKmEnCurso {
            lista.append(actual)
        }
        lista.append(contentsOf: parcialesKm.reversed())
        return lista
    }

    func actualizarProgresoSeriesYKm() {
        guard corriendo else { return }
        let currentMetros = self.metros
        let currentSegundos = self.segundos

        // 1. Objetivo de series
        if let _ = objetivoSeries, !objetivoSeriesContinuado, serieActualIndice < itemsSeries.count {
            let metrosSerie = max(0, currentMetros - metrosInicioSerieActual)
            let segsSerie = max(1, currentSegundos - segundosInicioSerieActual)
            itemsSeries[serieActualIndice].metrosCompletados = min(metrosSerie, itemsSeries[serieActualIndice].metrosObjetivo)
            if metrosSerie >= itemsSeries[serieActualIndice].metrosObjetivo {
                itemsSeries[serieActualIndice].completada = true
                itemsSeries[serieActualIndice].segundos = segsSerie
                itemsSeries[serieActualIndice].ritmoSegPorKm = Int((Double(segsSerie) * 1000.0 / Double(max(1, metrosSerie))).rounded())
                serieActualIndice += 1
                metrosInicioSerieActual = currentMetros
                segundosInicioSerieActual = currentSegundos
                if serieActualIndice >= itemsSeries.count {
                    mostrarAvisoFinObjetivoSeries = true
                }
            }
        }

        // 2. Parciales de kilómetro automáticos
        while currentMetros >= 1000 * (parcialesKm.count + 1) {
            let numero = parcialesKm.count + 1
            let segsKm = max(1, currentSegundos - segundosUltimoKm)
            let ritmo = segsKm
            let nuevoKm = ParcialKilometro(
                numero: numero,
                segundos: segsKm,
                ritmoSegPorKm: ritmo,
                metros: 1000,
                completado: true
            )
            parcialesKm.append(nuevoKm)
            segundosUltimoKm = currentSegundos
            metrosUltimoKm = 1000 * numero
        }
    }

    func toggleUnidades() {
        seleccionar(unidades: sistemaDeUnidades == .metrico ? .imperial : .metrico)
    }

    var sinSincronizarCount: Int {
        #if os(watchOS)
        return seguimiento.pendientesCount
        #else
        return 0
        #endif
    }

    func seriesHechas(enEjercicio indice: Int) -> Int {
        guard rutina.indices.contains(indice) else { return 0 }
        let id = rutina[indice].id
        return sincronizador.series.filter { $0.clave.ejercicio == id && $0.hecha }.count
    }

    public enum MotivoSinConexion: Equatable {
        case telefonoDesconectado
        case sesionNoIniciada
    }

    /// Si el teléfono está conectado y con sesión activa.
    @Published var telefonoConectado = true
    @Published var motivoSinConexion: MotivoSinConexion = .telefonoDesconectado

    private static let claveUsuarioId = "usuario_vinculado_id_reloj"

    var estaAutenticado: Bool {
        #if DEBUG
        if ArranqueDePruebaReloj.sinTelefono { return false }
        if ArranqueDePruebaReloj.pantalla != nil { return true }
        #endif
        #if os(watchOS)
        let usuario = sincronizador.usuarioRemotoId ?? seguimiento.usuarioVinculadoId ?? UserDefaults.standard.string(forKey: Self.claveUsuarioId)
        return usuario != nil && usuario?.isEmpty == false
        #else
        return (sincronizador.usuarioRemotoId?.isEmpty == false)
        #endif
    }

    func continuarSinTelefono() {
        pantalla = .abrir
    }

    // MARK: -

    init() {
        sistemaDeUnidades = SistemaDeUnidades(
            rawValue: UserDefaults.standard.string(forKey: Self.claveDeUnidades) ?? ""
        ) ?? .metrico
        compartirUbicacion = UserDefaults.standard.bool(forKey: Self.claveCompartirUbicacion)
        pausaAutoCarrera = UserDefaults.standard.bool(forKey: Self.clavePausaAutoCarrera)
        pausaAutoBici = UserDefaults.standard.object(forKey: Self.clavePausaAutoBici) as? Bool ?? true
        avisosAudioParciales = UserDefaults.standard.object(forKey: Self.claveAvisosAudioParciales) as? Bool ?? true
        avisosAudioInicioFinPausa = UserDefaults.standard.object(forKey: Self.claveAvisosAudioInicioFinPausa) as? Bool ?? true
        volumenAudio = UserDefaults.standard.object(forKey: Self.claveVolumenAudio) as? Double ?? 0.8
        if let slug = ArranqueDePruebaReloj.pantalla {
            pantalla = slug
        } else if !estaAutenticado {
            pantalla = .sinTelefono
            motivoSinConexion = .sesionNoIniciada
            telefonoConectado = false
        }
        if ArranqueDePruebaReloj.sinTelefono {
            telefonoConectado = false
            motivoSinConexion = .telefonoDesconectado
            pantalla = .sinTelefono
        } else {
            #if os(watchOS)
            let alcanzable = sincronizador.telefonoAlcanzable
            telefonoConectado = alcanzable && estaAutenticado
            motivoSinConexion = !estaAutenticado ? .sesionNoIniciada : (!alcanzable ? .telefonoDesconectado : .sesionNoIniciada)
            #else
            telefonoConectado = true
            #endif
        }
        if ArranqueDePruebaReloj.enCurso { corriendo = true }
        sincronizador.configurar(prescritasPorEjercicio: Dictionary(
            uniqueKeysWithValues: rutina.map { ($0.id, $0.series) }))
        reenviarCambiosDelSincronizador()
        sincronizador.$telefonoAlcanzable
            .sink { [weak self] alcanzable in
                guard let self else { return }
                #if DEBUG
                if ArranqueDePruebaReloj.sinTelefono {
                    self.telefonoConectado = false
                    self.motivoSinConexion = .telefonoDesconectado
                    return
                }
                #endif
                let autenticado = self.estaAutenticado
                self.telefonoConectado = alcanzable && autenticado
                if !autenticado {
                    self.motivoSinConexion = .sesionNoIniciada
                    if !self.corriendo && self.pantalla != .sinTelefono {
                        self.pantalla = .sinTelefono
                    }
                } else if !alcanzable {
                    self.motivoSinConexion = .telefonoDesconectado
                }
            }
            .store(in: &suscripciones)
        sincronizador.$usuarioRemotoId
            .dropFirst()
            .sink { [weak self] usuario in
                guard let self else { return }
                #if DEBUG
                if ArranqueDePruebaReloj.sinTelefono { return }
                #endif
                if let usuario, !usuario.isEmpty {
                    UserDefaults.standard.set(usuario, forKey: Self.claveUsuarioId)
                    self.telefonoConectado = true
                    if self.pantalla == .sinTelefono {
                        self.pantalla = .abrir
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: Self.claveUsuarioId)
                    #if os(watchOS)
                    self.seguimiento.desconectarUsuarioPorCierreDeSesion()
                    #endif
                    self.telefonoConectado = false
                    self.motivoSinConexion = .sesionNoIniciada
                    self.pantalla = .sinTelefono
                    self.pausada = false
                    self.corriendo = false
                }
            }
            .store(in: &suscripciones)
        sincronizador.$salidaRemota
            .sink { [weak self] salida in
                guard let self else { return }
                guard !self.fuenteLocal else { return }
                if let salida {
                    if self.idDeSalidaConAvisos != salida.id {
                        self.idDeSalidaConAvisos = salida.id
                        self.planificadorDeAvituallamiento = PlanificadorDeAvituallamiento()
                        self.avisoDeAvituallamiento = nil
                    }
                    self.corriendo = salida.corriendo || salida.pausada
                    self.pausada = salida.pausada
                    if salida.corriendo || salida.pausada {
                        if self.pantalla == .abrir || self.pantalla == .sinTelefono {
                            self.pantalla = .metricas
                        }
                        if let dep = salida.deporte {
                            self.deporte = dep
                        }
                        if salida.corriendo && !salida.pausada {
                            if self.musicaReproduciendo {
                                self.tiempoReproduccionActual += 1.0
                            }
                            self.evaluarAvisoDeAvituallamiento(
                                segundos: salida.segundos, deporte: salida.deporte ?? self.deporte)
                        }
                    } else if self.pantalla == .metricas {
                        self.pantalla = .resumen
                    }
                } else {
                    if self.sincronizador.telefonoAlcanzable {
                        if self.corriendo {
                            self.corriendo = false
                            self.pausada = false
                            if self.pantalla == .metricas {
                                self.pantalla = .abrir
                            }
                        }
                    }
                }
            }
            .store(in: &suscripciones)
        #if os(watchOS)
        seguimiento.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                self.actualizarProgresoSeriesYKm()
                self.objectWillChange.send()
            }
            .store(in: &suscripciones)
        seguimiento.$segundos
            .sink { [weak self] segundos in
                guard let self, self.corriendo, self.fuenteLocal else { return }
                if self.musicaReproduciendo {
                    self.tiempoReproduccionActual += 1.0
                }
                self.evaluarAvisoDeAvituallamiento(
                    segundos: segundos,
                    deporte: self.esTriatlon ? self.disciplinaTriatlonActual : self.deporte)
            }
            .store(in: &suscripciones)
        seguimiento.alCambiar = { [weak self] salida in
            self?.sincronizador.publicarSalida(salida)
        }
        sincronizador.alComandoDeSalida = { [weak self] comando in
            guard let self, self.fuenteLocal else { return }
            switch comando {
            case .pausar where self.seguimiento.fase == .corriendo,
                 .reanudar where self.seguimiento.fase == .pausada:
                self.seguimiento.pausarOReanudar()
            case .terminar where self.seguimiento.fase != .detenida:
                self.terminar()
            case .descartar where self.seguimiento.fase != .detenida:
                self.descartar()
            default: break
            }
        }
        seguimiento.$fase
            .sink { [weak self] fase in
                guard let self, self.fuenteLocal else { return }
                self.corriendo = fase != .detenida
                self.pausada = fase == .pausada
                if fase == .corriendo { self.ir(a: .metricas) }
            }
            .store(in: &suscripciones)
        if seguimiento.fase != .detenida {
            fuenteLocal = true
            corriendo = true
            pausada = seguimiento.fase == .pausada
            pantalla = .metricas
        }
        #endif
        sincronizador.$rutinaRemota
            .sink { [weak self] rutina in
                self?.sincronizador.configurar(prescritasPorEjercicio:
                    Dictionary(uniqueKeysWithValues: rutina.map { ($0.id, $0.series) }))
            }
            .store(in: &suscripciones)
        if ArranqueDePruebaReloj.registrarSerieDePrueba { serieHecha() }
    }


    /// 🪤 Reenviar los cambios del sincronizador.
    ///
    /// `sincronizador` es un `ObservableObject` **adentro de otro**, y SwiftUI no
    /// propaga eso solo: al cambiar `sincronizador.series` se publica en el
    /// sincronizador, no acá, y las vistas —que observan este objeto— no se
    /// redibujan. El síntoma es de los peores: el dato se guarda bien y la
    /// pantalla se queda vieja, así que parece que la sincronización no anduvo.
    private func reenviarCambiosDelSincronizador() {
        sincronizador.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &suscripciones)
    }

    // El teléfono publica lo medido por GPS. Sin lectura de HealthKit todavía,
    // el pulso se muestra vacío: jamás se presenta un número de la maqueta.
    var segundos: Int {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.segundos }
        #endif
        return sincronizador.salidaRemota?.segundos ?? 0
    }
    var ritmoPromedioSegPorKm: Int? {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.ritmoPromedioSegPorKm ?? seguimiento.ritmoSegPorKm }
        #endif
        return sincronizador.salidaRemota?.ritmoSegPorKm
    }
    var ritmoParcialSegPorKm: Int? {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.ritmoActualSegPorKm ?? seguimiento.ritmoSegPorKm }
        #endif
        return nil
    }
    var metros: Int {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.metros }
        #endif
        return sincronizador.salidaRemota?.metros ?? 0
    }
    var pulso: Int? {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.pulso }
        #endif
        return nil
    }
    @Published var esTriatlon: Bool = false

    var disciplinaTriatlonActual: DeporteDeSesion {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.disciplinaTriatlonActual }
        #endif
        return deporte
    }

    var siguienteDeporteTriatlon: (deporte: DeporteDeSesion, icono: String, textoBoton: String)? {
        guard esTriatlon else { return nil }
        #if os(watchOS)
        if fuenteLocal {
            guard let sig = seguimiento.siguienteDisciplinaTriatlon() else { return nil }
            switch sig {
            case .ciclismo: return (.ciclismo, "bicycle", "Pasar a Bicicleta")
            case .running: return (.running, "figure.run", "Pasar a Carrera")
            default: return nil
            }
        }
        #endif
        return nil
    }

    func transicionarSiguienteDeporteTriatlon() {
        #if os(watchOS)
        if fuenteLocal {
            seguimiento.transicionarSiguienteDeporteTriatlon()
            deporte = seguimiento.disciplinaTriatlonActual
        }
        #endif
    }

    var marcasDeRuta: [MarcaRuta] {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.marcas }
        #endif
        return []
    }

    var tramosDePausa: [[PuntoDeRecorrido]] {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.tramosDePausa }
        #endif
        return []
    }

    var tramosPorDeporte: [TramoPorDeporte] {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.tramosPorDeporte }
        #endif
        return []
    }

    var simboloDeporteEnCurso: String {
        if let icono = iconoDeporteEnCurso { return icono }
        let tipo: DeporteDeSesion? = {
            #if os(watchOS)
            if fuenteLocal {
                return esTriatlon ? seguimiento.disciplinaTriatlonActual : seguimiento.deporteActivo
            }
            #endif
            return sincronizador.salidaRemota?.deporte
        }()
        let interior = esInterior
        return switch tipo {
        case .ciclismo: interior ? "figure.indoor.cycle" : "bicycle"
        case .trekking: interior ? "figure.walk.treadmill" : "figure.walk"
        case .natacion: "figure.pool.swim"
        case .fuerza: "dumbbell.fill"
        case .otro, .triatlon: "figure.mixed.cardio"
        case .running, .none: interior ? "figure.run.treadmill" : "figure.run"
        }
    }
    var ritmoActual: Int? { ritmoParcial ? ritmoParcialSegPorKm : ritmoPromedioSegPorKm }
    var distanciaMostrada: String {
        Formato.distanciaNumero(metros, unidades: sistemaDeUnidades, decimales: 2)
    }
    var unidadDeDistancia: String { Formato.unidadDeDistancia(sistemaDeUnidades) }
    var ritmoMostrado: String {
        Formato.ritmo(segundosPorKm: ritmoActual, unidades: sistemaDeUnidades)
    }
    var velocidadTexto: String {
        Formato.velocidadNumero(metros: metros, segundos: segundos, unidades: sistemaDeUnidades)
    }
    var velocidadKmhTexto: String {
        velocidadTexto
    }
    var unidadDeVelocidad: String {
        Formato.unidadDeVelocidad(sistemaDeUnidades)
    }
    var esAutoPausada: Bool {
        #if os(watchOS)
        return fuenteLocal && seguimiento.autoPausada
        #else
        return false
        #endif
    }
    var segundosEnPausa: Int {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.segundosEnPausa }
        #endif
        return 0
    }
    #if os(watchOS)
    var vueltas: [VueltaRegistrada] {
        if fuenteLocal { return seguimiento.vueltas }
        return []
    }
    #endif
    var rumbo: Double {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.rumbo }
        #endif
        return 0.0
    }
    var esInterior: Bool {
        #if os(watchOS)
        if fuenteLocal { return seguimiento.esInterior }
        #endif
        return false
    }
    var planVigente: Bool {
        guard !sincronizador.cronogramaRemoto.isEmpty else { return false }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let hoyIso = df.string(from: Date())
        let diasFuturosOHoy = sincronizador.cronogramaRemoto.filter { $0.fechaIso >= hoyIso }
        return !diasFuturosOHoy.isEmpty
    }

    var sesionPlanificada: SesionCompartida? {
        if let sesion = sincronizador.sesionRemota {
            return sesion
        }
        guard planVigente else { return nil }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let hoyIso = df.string(from: Date())

        if let diaHoy = sincronizador.cronogramaRemoto.first(where: { $0.fechaIso == hoyIso }) {
            let tipoLimpio = Formato.limpiarTituloEvento(diaHoy.tipo, enTriatlon: esTriatlon)
            return SesionCompartida(
                tipo: tipoLimpio,
                distanciaMetros: diaHoy.distanciaMetros,
                duracionMinutos: diaHoy.duracionMinutos,
                minutoDelDia: diaHoy.minutoDelDia,
                geles: diaHoy.geles,
                aguaMl: diaHoy.aguaMl,
                sales: diaHoy.sales,
                esDescanso: diaHoy.esDescanso,
                esFuerza: diaHoy.esFuerza
            )
        }
        return nil
    }

    var esDiaDeDescanso: Bool {
        if let sesion = sesionPlanificada {
            if sesion.esDescanso == true { return true }
            let t = sesion.tipo.lowercased()
            if t.contains("descanso") || t.contains("rest") || t.contains("repos") {
                return true
            }
            return false
        }
        return false
    }

    /// Sesión de cardio planificada para hoy (running, ciclismo, natación, trekking).
    /// Devuelve nil si hoy es descanso o si la sesión es de gimnasio/fuerza.
    var sesionCardioPlanificada: SesionCompartida? {
        guard !esDiaDeDescanso, let sesion = sesionPlanificada else { return nil }
        if sesion.esFuerza == true { return nil }
        let t = sesion.tipo.lowercased()
        if t.contains("fuerza") || t.contains("gimnasio") || t.contains("gym") || t.contains("pesas") || t.contains("strength") || t.contains("muscu") {
            return nil
        }
        return sesion
    }

    /// Indica si hoy corresponde realizar entrenamiento de gimnasio / rutina de fuerza.
    /// Si hoy es día de descanso o no hay plan vigente, nunca se muestra ningún objetivo.
    var tieneGimnasioHoy: Bool {
        guard !esDiaDeDescanso, let sesion = sesionPlanificada else { return false }
        if sesion.esFuerza == true { return true }
        let t = sesion.tipo.lowercased()
        if t.contains("fuerza") || t.contains("gimnasio") || t.contains("gym") || t.contains("pesas") || t.contains("strength") || t.contains("muscu") {
            return true
        }
        return false
    }

    private static var claveObjetivoHoy: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "objetivo_hoy_cumplido_\(df.string(from: Date()))"
    }

    private static var claveDistanciaHoy: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "distancia_hoy_metros_\(df.string(from: Date()))"
    }

    @Published var objetivoHoyCumplido: Bool = {
        UserDefaults.standard.bool(forKey: claveObjetivoHoy)
    }()

    @Published var distanciaEntrenoHoyMetros: Int = {
        UserDefaults.standard.integer(forKey: claveDistanciaHoy)
    }()

    func marcarObjetivoHoyCumplido(metros: Int? = nil) {
        objetivoHoyCumplido = true
        UserDefaults.standard.set(true, forKey: Self.claveObjetivoHoy)
        let total = max(distanciaEntrenoHoyMetros, metros ?? self.metros)
        if total > 0 {
            distanciaEntrenoHoyMetros = total
            UserDefaults.standard.set(total, forKey: Self.claveDistanciaHoy)
        }
    }

    func continuarEntrenamientoTrasObjetivo() {
        #if os(watchOS)
        marcarObjetivoHoyCumplido(metros: seguimiento.metros)
        seguimiento.mostrarAvisoObjetivoCumplido = false
        #else
        marcarObjetivoHoyCumplido()
        #endif
    }

    var mostrarAvisoObjetivoCumplido: Bool {
        #if os(watchOS)
        return seguimiento.mostrarAvisoObjetivoCumplido
        #else
        return false
        #endif
    }

    var objetivoMetrosSesion: Int? {
        #if os(watchOS)
        return seguimiento.objetivoMetros
        #else
        return nil
        #endif
    }

    func descartarAvisoObjetivoCumplido() {
        #if os(watchOS)
        seguimiento.mostrarAvisoObjetivoCumplido = false
        #endif
    }

    /// 🛑 Los `id` son los del catálogo y tienen que ser **los mismos** que usa
    /// el teléfono: son parte de la clave determinística de una serie.
    var rutina: [(id: String, nombre: String, repeticiones: Int, pesoKg: Int, series: Int, etiqueta: String, unidad: String)] {
        sincronizador.rutinaRemota.map {
            ($0.id, $0.nombre, $0.repeticiones, ($0.pesoGramos ?? 0) / 1000,
             $0.series, $0.etiqueta, $0.unidad)
        }
    }

    /// Los avisos: lo que viene primero y destacado, lo que pasó abajo y
    /// atenuado. Es el orden que pide el diseño.
    let avisosPasados: [(titulo: String, detalle: String, cuando: String)] = []

    // MARK: - Conexión y Acciones

    func verificarConexion() {
        #if DEBUG
        if ArranqueDePruebaReloj.sinTelefono {
            telefonoConectado = false
            motivoSinConexion = .telefonoDesconectado
            pantalla = .sinTelefono
            return
        }
        #endif
        sincronizador.verificarConexion()
        #if os(watchOS)
        let alcanzable = sincronizador.telefonoAlcanzable
        let autenticado = estaAutenticado
        self.telefonoConectado = alcanzable && autenticado
        if !autenticado {
            self.motivoSinConexion = .sesionNoIniciada
            self.pantalla = .sinTelefono
        } else if !alcanzable {
            self.motivoSinConexion = .telefonoDesconectado
        } else if self.pantalla == .sinTelefono {
            self.pantalla = .abrir
        }
        #else
        self.telefonoConectado = true
        #endif
    }

    func reintentarConexion() {
        verificarConexion()
    }

    func ir(a destino: Pantalla) {
        if !estaAutenticado && !corriendo && destino != .sinTelefono {
            pantalla = .sinTelefono
            motivoSinConexion = .sesionNoIniciada
            return
        }
        pantalla = destino
    }

    // MARK: - Cuenta regresiva antes de arrancar entrenamiento

    @Published var cuentaRegresivaActiva = false
    @Published var preguntaAvituallamientoActiva = false
    private var deportePendiente: DeporteDeSesion?
    private var esInteriorPendiente: Bool = false
    private var objetivoMetrosPendiente: Int?
    private var esTriatlonPendiente: Bool = false
    private var iconoPendiente: String?

    func prepararInicioConCuentaRegresiva(deporte deportePedido: DeporteDeSesion, esInterior: Bool = false, objetivoMetros: Int? = nil, esTriatlon triatlonPedido: Bool = false, icono iconoPedido: String? = nil) {
        guard estaAutenticado else {
            ir(a: .sinTelefono)
            return
        }
        // MVP sólo running: un deporte escondido arranca como carrera (y sin su ícono).
        let deporte = MVP.acotado(deportePedido)
        let esTriatlon = triatlonPedido && MVP.permite(.triatlon)
        let icono = deporte == deportePedido ? iconoPedido : nil
        self.deporte = deporte
        self.esTriatlon = esTriatlon
        self.deportePendiente = deporte
        self.esInteriorPendiente = esInterior
        self.objetivoMetrosPendiente = objetivoMetros
        self.esTriatlonPendiente = esTriatlon
        self.iconoPendiente = icono
        self.iconoDeporteEnCurso = icono

        iniciarSinAvituallamiento()
    }

    func iniciarSinAvituallamiento() {
        if let sesion = sesionPlanificada {
            gelesQueLleva = sesion.geles ?? 0
            salesQueLleva = sesion.sales ?? 0
            aguaMlQueLleva = sesion.aguaMl ?? 0
        } else {
            gelesQueLleva = 0
            salesQueLleva = 0
            aguaMlQueLleva = 0
        }
        preguntaAvituallamientoActiva = false
        cuentaRegresivaActiva = true
        pantalla = .metricas
    }

    func confirmarAvituallamientoEIniciar() {
        if let sesion = sesionPlanificada {
            gelesQueLleva = sesion.geles ?? 0
            salesQueLleva = sesion.sales ?? 0
            aguaMlQueLleva = sesion.aguaMl ?? 0
        }
        preguntaAvituallamientoActiva = false
        cuentaRegresivaActiva = true
        pantalla = .metricas
    }

    func completarCuentaRegresiva() {
        cuentaRegresivaActiva = false
        let dep = deportePendiente ?? self.deporte
        let interior = esInteriorPendiente
        let obj = objetivoMetrosPendiente
        let tri = esTriatlonPendiente
        let ic = iconoPendiente
        deportePendiente = nil
        objetivoMetrosPendiente = nil
        esTriatlonPendiente = false
        iconoPendiente = nil
        empezar(deporte: dep, esInterior: interior, objetivoMetros: obj, esTriatlon: tri, icono: ic)
    }

    func cancelarCuentaRegresiva() {
        cuentaRegresivaActiva = false
        deportePendiente = nil
        objetivoMetrosPendiente = nil
        esTriatlonPendiente = false
        esTriatlon = false
        iconoPendiente = nil
        iconoDeporteEnCurso = nil
        ir(a: .abrir)
    }

    func empezar(deporte deportePedido: DeporteDeSesion? = nil, esInterior: Bool = false, objetivoMetros: Int? = nil, esTriatlon triatlonPedido: Bool = false, icono iconoPedido: String? = nil) {
        // MVP sólo running: mismo acotado que en `prepararInicioConCuentaRegresiva`.
        let deporte = deportePedido.map { MVP.acotado($0) }
        let esTriatlon = triatlonPedido && MVP.permite(.triatlon)
        let icono = deporte == deportePedido ? iconoPedido : nil
        planificadorDeAvituallamiento = PlanificadorDeAvituallamiento()
        avisoDeAvituallamiento = nil
        cuentaRegresivaActiva = false
        self.esTriatlon = esTriatlon
        if let deporte {
            self.deporte = deporte
        }
        if let icono {
            self.iconoDeporteEnCurso = icono
        }
        // Insumos configurados desde el celular
        if let sesion = sesionPlanificada {
            self.gelesQueLleva = sesion.geles ?? 0
            self.salesQueLleva = sesion.sales ?? 0
            self.aguaMlQueLleva = sesion.aguaMl ?? 0
        } else {
            self.gelesQueLleva = 0
            self.salesQueLleva = 0
            self.aguaMlQueLleva = 0
        }
        guard estaAutenticado else {
            ir(a: .sinTelefono)
            return
        }

        // Inicializar series u objetivo si la sesión planificada lo define
        if let tipoSesion = sesionPlanificada?.tipo,
           let detector = DetectorDeSeries.detectar(en: tipoSesion) {
            self.objetivoSeries = detector
            self.itemsSeries = (1...detector.totalSeries).map { num in
                ItemSerieObjetivo(numero: num, metrosObjetivo: detector.metrosPorSerie)
            }
        } else {
            self.objetivoSeries = nil
            self.itemsSeries = []
        }
        self.serieActualIndice = 0
        self.metrosInicioSerieActual = 0
        self.segundosInicioSerieActual = 0
        self.objetivoSeriesContinuado = false
        self.mostrarAvisoFinObjetivoSeries = false
        self.parcialesKm = []
        self.metrosUltimoKm = 0
        self.segundosUltimoKm = 0

        if let salida = sincronizador.salidaRemota,
           Int64((Date().timeIntervalSince1970 * 1000).rounded()) - salida.actualizadoMs < 20_000,
           salida.corriendo || salida.pausada {
            fuenteLocal = false
            ir(a: .metricas)
        } else {
            #if os(watchOS)
            fuenteLocal = true
            corriendo = true
            pausada = false
            let tipo: DeporteDeSesion = MVP.acotado(self.deporte)
            let obj = objetivoMetros ?? (sesionPlanificada?.distanciaMetros)
            seguimiento.empezar(deporte: tipo, esInterior: esInterior, objetivoMetros: obj, esTriatlon: esTriatlon)
            ir(a: .metricas)
            #endif
        }
    }

    func pausarOReanudar() {
        #if os(watchOS)
        if fuenteLocal { seguimiento.pausarOReanudar(); return }
        #endif
        if !sincronizador.solicitarComando(pausada ? .reanudar : .pausar) { ir(a: .sinTelefono) }
    }

    func marcarVuelta() {
        #if os(watchOS)
        if fuenteLocal {
            if let _ = objetivoSeries, !objetivoSeriesContinuado, serieActualIndice < itemsSeries.count {
                let currentMetros = self.metros
                let currentSegundos = self.segundos
                let metrosSerie = max(1, currentMetros - metrosInicioSerieActual)
                let segsSerie = max(1, currentSegundos - segundosInicioSerieActual)
                itemsSeries[serieActualIndice].completada = true
                itemsSeries[serieActualIndice].metrosCompletados = metrosSerie
                itemsSeries[serieActualIndice].segundos = segsSerie
                itemsSeries[serieActualIndice].ritmoSegPorKm = Int((Double(segsSerie) * 1000.0 / Double(metrosSerie)).rounded())
                serieActualIndice += 1
                metrosInicioSerieActual = currentMetros
                segundosInicioSerieActual = currentSegundos
                if serieActualIndice >= itemsSeries.count {
                    mostrarAvisoFinObjetivoSeries = true
                }
                return
            }
            _ = seguimiento.registrarVuelta()
            return
        }
        #endif
    }

    func vuelta() {
        marcarVuelta()
    }

    func seleccionar(unidades: SistemaDeUnidades) {
        sistemaDeUnidades = unidades
        UserDefaults.standard.set(unidades.rawValue, forKey: Self.claveDeUnidades)
    }

    /// Pausa y abre directamente el resumen completo de la salida con opciones de
    /// Guardar o Reanudar en una sola pantalla.
    func solicitarFinalizacion() {
        #if os(watchOS)
        if fuenteLocal {
            seguimiento.congelarPausaParaFinalizacion()
        } else if !pausada {
            _ = sincronizador.solicitarComando(.pausar)
        }
        #endif
        pausada = true
        guard ValidadorDeSalida.sePuedeGuardar(segundos: segundos, metros: metros) else {
            ir(a: .sinMovimiento)
            return
        }
        ir(a: .resumen)
    }

    /// Descarta la pausa y reanuda el entrenamiento volviendo a métricas.
    func reanudarDesdeFinalizacion() {
        #if os(watchOS)
        if fuenteLocal {
            seguimiento.descongelarYReanudar()
        } else {
            _ = sincronizador.solicitarComando(.reanudar)
        }
        #endif
        corriendo = true
        pausada = false
        ir(a: .metricas)
    }

    /// Guarda la salida de forma definitiva y vuelve a la portada.
    func guardarDesdeFinalizacion() {
        guard ValidadorDeSalida.sePuedeGuardar(segundos: segundos, metros: metros) else {
            ir(a: .sinMovimiento)
            return
        }
        #if os(watchOS)
        if seguimiento.objetivoCumplido || (seguimiento.objetivoMetros != nil && metros >= (seguimiento.objetivoMetros ?? 0)) {
            marcarObjetivoHoyCumplido(metros: metros)
        }
        if fuenteLocal {
            seguimiento.terminar()
            corriendo = false
            pausada = false
            esTriatlon = false
            iconoDeporteEnCurso = nil
            avisosDeSales = true
            avisoDeAvituallamiento = nil
            gelesQueLleva = 0
            salesQueLleva = 0
            aguaMlQueLleva = 0
            guiaDeRutina = true
            ir(a: .abrir)
            return
        }
        #endif
        if !sincronizador.solicitarComando(.terminar) { ir(a: .sinTelefono); return }
        corriendo = false
        pausada = false
        esTriatlon = false
        iconoDeporteEnCurso = nil
        avisosDeSales = true
        avisoDeAvituallamiento = nil
        gelesQueLleva = 0
        salesQueLleva = 0
        aguaMlQueLleva = 0
        guiaDeRutina = true
        ir(a: .abrir)
    }

    func descartar() {
        #if os(watchOS)
        if fuenteLocal {
            seguimiento.descartar()
        } else if !sincronizador.solicitarComando(.descartar) {
            ir(a: .sinTelefono)
            return
        }
        #endif
        corriendo = false
        pausada = false
        fuenteLocal = false
        esTriatlon = false
        iconoDeporteEnCurso = nil
        avisosDeSales = true
        avisoDeAvituallamiento = nil
        gelesQueLleva = 0
        salesQueLleva = 0
        aguaMlQueLleva = 0
        guiaDeRutina = true
        ir(a: .abrir)
    }

    func terminar() {
        guardarDesdeFinalizacion()
    }

    func totalSeries(enEjercicio indice: Int) -> Int {
        guard rutina.indices.contains(indice) else { return 0 }
        let id = rutina[indice].id
        let base = rutina[indice].series
        let extras = seriesExtraPorEjercicio[id] ?? 0
        let hechas = seriesHechas(enEjercicio: indice)
        return max(base + extras, hechas)
    }

    func agregarSerieExtra() {
        guard rutina.indices.contains(ejercicioActual) else { return }
        let id = rutina[ejercicioActual].id
        seriesExtraPorEjercicio[id, default: 0] += 1
    }

    func desmarcarUltimaSerie() {
        guard rutina.indices.contains(ejercicioActual) else { return }
        let ejercicio = rutina[ejercicioActual]
        let hechas = seriesHechas(enEjercicio: ejercicioActual)
        guard hechas > 0 else {
            if ejercicioActual > 0 {
                ejercicioActual -= 1
                cargarPrescripcion()
            }
            return
        }
        let clave = ClaveDeSerie(sesion: idDeSesion, ejercicio: ejercicio.id, numero: hechas)
        sincronizador.desmarcar(clave: clave)
    }

    /// Registra la serie que está en pantalla. Es lo que viaja al teléfono.
    func serieHecha() {
        guard estaAutenticado else {
            ir(a: .sinTelefono)
            return
        }
        guard rutina.indices.contains(ejercicioActual) else { return }
        let ejercicio = rutina[ejercicioActual]
        let total = totalSeries(enEjercicio: ejercicioActual)
        let numero = seriesHechas(enEjercicio: ejercicioActual) + 1

        sincronizador.registrar(
            clave: ClaveDeSerie(sesion: idDeSesion, ejercicio: ejercicio.id, numero: numero),
            hecha: true,
            repeticiones: repeticiones,
            pesoGramos: ejercicio.pesoKg > 0 ? pesoKg * 1000 : nil,
            esExtra: numero > ejercicio.series)

        if numero >= total, ejercicioActual + 1 < rutina.count {
            ejercicioActual += 1
            cargarPrescripcion()
        }
    }

    func cargarPrescripcion() {
        guard rutina.indices.contains(ejercicioActual) else { return }
        repeticiones = rutina[ejercicioActual].repeticiones
        pesoKg = rutina[ejercicioActual].pesoKg
    }

    // MARK: - Resumen y Finalización de Gimnasio

    var totalSeriesGimnasioHechas: Int {
        sincronizador.series.filter { $0.hecha }.count
    }

    var totalRepeticionesGimnasio: Int {
        sincronizador.series.filter { $0.hecha }.reduce(0) { $0 + $1.repeticiones }
    }

    var totalKilosGimnasio: Int {
        sincronizador.series.filter { $0.hecha }.reduce(0) { $0 + ((($1.pesoGramos ?? 0) / 1000) * $1.repeticiones) }
    }

    var ejerciciosCompletadosGimnasio: Int {
        rutina.indices.filter { seriesHechas(enEjercicio: $0) >= rutina[$0].series }.count
    }

    func terminarGimnasio() {
        ir(a: .resumenGimnasio)
    }

    func guardarGimnasio() {
        marcarObjetivoHoyCumplido()
        ir(a: .abrir)
    }

    func descartarGimnasio() {
        sincronizador.descartarSeries()
        seriesExtraPorEjercicio.removeAll()
        ejercicioActual = 0
        ir(a: .abrir)
    }
}

/// Arrancar el reloj en una pantalla, para revisarla sin recorrer la sesión.
/// Sólo en DEBUG, igual que en el teléfono.
enum ArranqueDePruebaReloj {
    #if DEBUG
    static var pantalla: EstadoReloj.Pantalla? {
        guard let slug = valor("-pantallaReloj") else { return nil }
        return EstadoReloj.Pantalla(rawValue: slug)
    }
    static var sinTelefono: Bool { ProcessInfo.processInfo.arguments.contains("-sinTelefono") }
    static var enCurso: Bool { ProcessInfo.processInfo.arguments.contains("-enCurso") }
    /// Registra una serie al arrancar. Existe para poder verificar la
    /// sincronización sin depender de acertarle a un botón en un simulador de
    /// reloj, que es una fuente de falsos negativos.
    static var registrarSerieDePrueba: Bool {
        ProcessInfo.processInfo.arguments.contains("-registrarSerieDePrueba")
    }

    private static func valor(_ bandera: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: bandera), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
    #else
    static var pantalla: EstadoReloj.Pantalla? { nil }
    static var sinTelefono: Bool { false }
    static var enCurso: Bool { false }
    static var registrarSerieDePrueba: Bool { false }
    #endif
}
