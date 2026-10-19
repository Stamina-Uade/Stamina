import Combine
import CoreLocation
import Foundation
import SwiftUI
import TrainerCore
#if canImport(MediaPlayer)
import MediaPlayer
#endif

/// El estado de la app después del login: qué pestaña se ve, qué semana se mira,
/// si hay una sesión corriendo, qué se comió hoy y qué series de gimnasio se
/// hicieron.
///
/// Lo que **no** hace: calcular el plan. Todo lo que muestra sale de
/// `RepositorioDePlan` (ver el encabezado de ese archivo y AGENTS.md §10), y lo
/// publica en dos tiempos: al abrir, lo guardado; cuando contesta el servidor, lo
/// nuevo —o lo guardado, con el aviso de que no se pudo actualizar—.
@MainActor
final class EstadoHome: ObservableObject {

    // MARK: - Navegación

    @Published private(set) var pestana: PestanaHome = .inicio
    /// A dónde vuelve `gimnasio` y `ajustes`, que no están en la barra.
    @Published private(set) var pestanaPrevia: PestanaHome = .inicio

    /// El modal abierto, si hay alguno. Uno por vez, como en el diseño.
    @Published var modal: ModalDelHome?

    enum ModalDelHome: Identifiable {
        case registrarComida
        var id: Int { 0 }
    }

    // MARK: - Plan

    @Published var semanaElegida: Int = 1
    var estadoDeLaSesion: EstadoDeSesion {
        if seguimiento.fase == .detenida, let remota = salidaRemotaActiva {
            return remota.pausada ? .pausada : .corriendo
        }
        switch seguimiento.fase {
        case .detenida: return .detenida
        case .corriendo: return .corriendo
        case .pausada: return .pausada
        }
    }

    enum EstadoDeSesion { case detenida, corriendo, pausada }

    private var salidaRemotaActiva: EstadoDeSalidaCompartido? {
        guard let salida = sincronizador.salidaRemota,
              salida.corriendo || salida.pausada else { return nil }
        if salida.pausada { return salida }
        let ahora = Int64((Date().timeIntervalSince1970 * 1_000).rounded())
        return ahora - salida.actualizadoMs <= 30_000 ? salida : nil
    }

    var salidaVieneDelReloj: Bool {
        seguimiento.fase == .detenida && salidaRemotaActiva != nil
    }

    var segundosDeLaSesion: Int { salidaVieneDelReloj ? salidaRemotaActiva?.segundos ?? 0 : seguimiento.segundos }
    var metrosDeLaSesion: Int { salidaVieneDelReloj ? salidaRemotaActiva?.metros ?? 0 : seguimiento.metros }
    var ritmoDeLaSesion: Int? { salidaVieneDelReloj ? salidaRemotaActiva?.ritmoSegPorKm : seguimiento.ritmoSegPorKm }
    var puntosDeLaSesion: [PuntoDeRecorrido] { salidaVieneDelReloj ? salidaRemotaActiva?.puntos ?? [] : seguimiento.puntos }
    var ubicacionDeLaSesion: CLLocationCoordinate2D? {
        if salidaVieneDelReloj, let ultimo = salidaRemotaActiva?.puntos.last {
            return CLLocationCoordinate2D(latitude: ultimo.lat, longitude: ultimo.lon)
        }
        return seguimiento.ubicacion
    }
    var rumboDeLaSesion: Double { seguimiento.rumbo }

    /// Si ya se eligió la semana de hoy. Después, una actualización no le cambia a la
    /// persona la semana que está mirando.
    private var semanaDeHoyElegida = false

    // MARK: - Lo que viene del servidor

    /// Lo que se ve, cada parte con su estado.
    @Published private(set) var contenido: ContenidoDelHome
    /// Hay un pedido en el aire.
    @Published private(set) var actualizando = false
    @Published var resumenSalida: SalidaCapturada?

    // MARK: - Actividades / Salidas
    @Published private(set) var actividadesDeHoy: [Actividad] = []
    @Published private(set) var recorridosLocales: [String: [PuntoDeRecorrido]] = [:]

    @Published private(set) var comidas: [Comida] = []

    // MARK: - Pasos de Apple Health
    @Published private(set) var pasosPorDia: [String: Int] = [:]

    // MARK: - Gimnasio, sincronizado con el reloj

    /// 🛑 Las series ya no viven acá: viven en el sincronizador, que las fusiona
    /// con lo que registre el reloj (decisión 0006). Este objeto sólo las lee.
    let sincronizador: SincronizadorDeSesion

    /// El id de la sesión de hoy. Parte de la clave determinística de una serie.
    /// Se deriva en `TrainerCore` para que el reloj llegue exactamente al mismo.
    let idDeSesion = ClaveDeSerie.sesionDeGimnasio()

    // MARK: - Ajustes

    @Published var avisoDePreparacion = true
    @Published var avisoDeCarrera = true
    @Published var resumenSemanal = true
    @Published var perfilPrivado = true
    /// Minutos de anticipación del aviso de preparación.
    @Published var anticipacionMinutos: Int = 45
    @Published var sistemaDeUnidades: SistemaDeUnidades = .metrico

    // MARK: - Perfil

    @Published var nombreCompleto: String
    @Published var objetivo: Objetivo
    @Published var perfil: Perfil? {
        didSet {
            sincronizador.publicarUsuario(perfil?.id)
            sincronizador.reintentarSalidasRecibidas()
        }
    }

    // MARK: -

    let repositorio: RepositorioDePlan
    let seguimiento: SeguimientoDeSalida
    private var suscripciones = Set<AnyCancellable>()
    /// Sube las series al servidor y trae las de los otros dispositivos. `nil` con la
    /// maqueta, que no tiene servidor.
    private var sincronizacionConElServidor: SincronizacionConElServidor?
    /// Avisa cuando vuelve la red, para subir lo que quedó pendiente.
    private var monitorDeRed: MonitorDeRed?
    /// Las comidas que esperan para subir. `nil` con la maqueta.
    private var colaDeComidas: ColaDeComidas?
    private var ultimaConsultaCalor: Date?

    /// - Parameter repositorio: 🛑 sin valor por defecto, a propósito. La app pasa el
    ///   del servidor; las vistas previas y `-datosDeEjemplo`, el provisional. Con un
    ///   defecto, olvidarse de pasarlo mostraría la maqueta del diseño como si fuera
    ///   el plan de alguien.
    init(repositorio: RepositorioDePlan, nombreCompleto: String = "", objetivo: Objetivo = .mediaMaraton,
         sincronizador: SincronizadorDeSesion? = nil) {
        let sinc = sincronizador ?? SincronizadorDeSesion(dispositivo: .telefono)
        self.repositorio = repositorio
        self.sincronizador = sinc
        self.seguimiento = SeguimientoDeSalida(servicio: repositorio.servicioDeActividades())
        self.nombreCompleto = nombreCompleto
        self.objetivo = objetivo
        // Offline primero (AGENTS.md §6): lo guardado se ve antes de preguntar nada.
        self.contenido = repositorio.guardado()
        if let pedida = ArranqueDePrueba.pestanaHome { self.pestana = pedida }
        // Antes de mostrar nada: lo que espera en la cola también se ve al abrir.
        colaDeComidas = repositorio.colaDeComidas()
        aplicar(contenido)
        reenviarCambiosDelSincronizador()
        seguimiento.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &suscripciones)
        seguimiento.alCambiar = { [weak self] salida in
            self?.sincronizador.publicarSalida(salida)
        }
        sinc.alComandoDeSalida = { [weak self] comando in
            guard let self else { return }
            switch comando {
            case .pausar where self.seguimiento.fase == .corriendo,
                 .reanudar where self.seguimiento.fase == .pausada:
                self.seguimiento.pausarOReanudar()
            case .terminar where self.seguimiento.fase != .detenida:
                self.seguimiento.terminar()
            case .descartar where self.seguimiento.fase != .detenida:
                self.seguimiento.descartar()
            case .musicaAlternar:
                #if os(iOS)
                let player = MPMusicPlayerController.systemMusicPlayer
                if player.playbackState == .playing { player.pause() } else { player.play() }
                #endif
            case .musicaSiguiente:
                #if os(iOS)
                MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
                #endif
            case .musicaAnterior:
                #if os(iOS)
                let player = MPMusicPlayerController.systemMusicPlayer
                if player.currentPlaybackTime > 2.0 {
                    player.skipToBeginning()
                } else {
                    player.skipToPreviousItem()
                }
                #endif
            case .musicaRebobinar:
                #if os(iOS)
                MPMusicPlayerController.systemMusicPlayer.skipToBeginning()
                #endif
            default: break
            }
        }
        sinc.alRecibirSalidaDelReloj = { [weak self] salida in
            guard let self, self.perfil?.id == salida.usuarioId else { return false }
            let aceptada = self.seguimiento.recibirDelReloj(salida)
            if aceptada {
                AlmacenDeRecorridos.compartido.guardar(id: salida.id, puntos: salida.puntos)
                let ahoraMs = RenovadorDeSesion.ahoraEnMs()
                let nuevaActividad = Actividad(
                    id: salida.id,
                    sport: salida.deporte,
                    startedAtMs: salida.inicioMs,
                    durationS: Int64(salida.segundos),
                    distanceM: Int64(salida.metros),
                    elevationGainM: 0,
                    avgHrBpm: salida.pulsoMedio.map(Int64.init),
                    maxHrBpm: salida.pulsoMaximo.map(Int64.init),
                    kcal: nil,
                    device: .reloj,
                    createdAtMs: ahoraMs,
                    updatedAtMs: ahoraMs
                )
                self.recorridosLocales[salida.id] = salida.puntos
                self.actividadesDeHoy.removeAll { $0.id == salida.id }
                self.actividadesDeHoy.insert(nuevaActividad, at: 0)
                AlmacenDeHitos.compartido.registrarActividad(nuevaActividad)
            }
            return aceptada
        }
        sinc.$salidaRemota
            .compactMap { $0 }
            .filter { salida in
                guard salida.corriendo || salida.pausada else { return false }
                let ahora = Int64((Date().timeIntervalSince1970 * 1_000).rounded())
                return ahora - salida.actualizadoMs <= 30_000
            }
            .sink { [weak self] _ in self?.ir(a: .entreno) }
            .store(in: &suscripciones)
        sincronizacionConElServidor = repositorio.sincronizacion(de: sinc)
        if sincronizacionConElServidor != nil {
            subirLoPendienteCuandoCambie()
            // Sin red lo pendiente espera en disco; cuando vuelve, sale solo.
            monitorDeRed = MonitorDeRed { [weak self] in
                Task { await self?.actualizar() }
            }
        }
        ServicioDePasosSalud.compartido.$pasosPorDia
            .sink { [weak self] nuevos in self?.pasosPorDia = nuevos }
            .store(in: &suscripciones)
        seguimiento.$ubicacion
            .compactMap { $0 }
            .sink { [weak self] _ in self?.programarAvisoCalor() }
            .store(in: &suscripciones)
    }

    /// Cada serie nueva —de este teléfono o del reloj— sale apenas queda algo
    /// pendiente, con un segundo de espera: una serie corregida dos veces seguidas
    /// viaja una vez.
    ///
    /// 🛑 Sólo con algo pendiente QUE SE PUEDA MANDAR: lo que se fusionó del servidor
    /// no vuelve a salir, y una serie fuera del contrato —que nunca viaja— no puede
    /// disparar una vuelta tras otra.
    private func subirLoPendienteCuandoCambie() {
        sincronizador.$series
            .dropFirst()
            .filter { series in
                series.contains { $0.recibidaEnServidorMs == nil && SincronizacionConElServidor.cumpleElContrato($0) }
            }
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.sincronizarSeries() }
            }
            .store(in: &suscripciones)
    }

    /// Decisión 0006: primero lo pendiente, después lo del servidor.
    func sincronizarSeries() async {
        await sincronizacionConElServidor?.sincronizar()
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

    // MARK: - Actualizar

    /// Le pregunta al servidor y publica lo que haya. Lo llaman la entrada al Home y
    /// la vuelta a primer plano. Con un pedido en el aire no sale otro: traerían lo
    /// mismo.
    func actualizar() async {
        guard !actualizando else { return }
        actualizando = true
        // Primero sube lo pendiente y después se trae: una comida que todavía no llegó
        // no tiene por qué faltar en lo que contesta el servidor.
        await colaDeComidas?.subir()
        await seguimiento.subirPendientes()
        let nuevo = await repositorio.actualizar()
        await cargarActividadesDeHoy()
        actualizando = false
        aplicar(nuevo)
        // Las series van aparte del plan: ver `SincronizacionConElServidor`.
        await sincronizarSeries()
    }

    func cargarActividadesDeHoy() async {
        guard let servicio = repositorio.servicioDeActividades() else { return }
        let resp = await servicio.actividades(limite: 20, cursor: nil)
        guard case .ok(let pagina) = resp else { return }
        let inicioDelDiaMs = FuenteDelServidor.inicioDelDia(RenovadorDeSesion.ahoraEnMs(), zona: .current)
        let deHoy = pagina.elementos.filter { $0.startedAtMs >= inicioDelDiaMs }
        var fusionadas = deHoy
        for local in actividadesDeHoy {
            if !fusionadas.contains(where: { $0.id == local.id }) {
                fusionadas.append(local)
            }
        }
        actividadesDeHoy = fusionadas.sorted(by: { $0.startedAtMs > $1.startedAtMs })
        for act in pagina.elementos {
            AlmacenDeHitos.compartido.registrarActividad(act)
        }
    }

    private func aplicar(_ nuevo: ContenidoDelHome) {
        contenido = nuevo
        let nutricion = nuevo.nutricion.valor
        let zona = nutricion?.zona ?? .current
        comidas = TraduccionDelServidor.comidas(
            nutricion?.comidas ?? [], conPendientes: colaDeComidas?.pendientes ?? [],
            diaMs: nutricion?.diaMs ?? FuenteDelServidor.inicioDelDia(RenovadorDeSesion.ahoraEnMs(), zona: zona),
            zona: zona)
        // El sincronizador necesita saber cuántas series prescribe cada
        // ejercicio para poder avisar cuando la unión deja de más.
        sincronizador.configurar(prescritasPorEjercicio: Dictionary(
            rutina.map { ($0.id, $0.prescripcion.series.count) }, uniquingKeysWith: max))
        sincronizador.publicarRutina(rutina.compactMap { ejercicio in
            guard let primera = ejercicio.prescripcion.series.first else { return nil }
            return EjercicioCompartido(id: ejercicio.id, nombre: ejercicio.nombre,
                                       repeticiones: primera.repeticiones,
                                       pesoGramos: primera.pesoGramos,
                                       series: ejercicio.prescripcion.series.count,
                                       etiqueta: ejercicio.etiqueta,
                                       unidad: ejercicio.prescripcion.unidadDePeso == .libras ? "lb" : "kg")
        })
        let sesionCompartida: SesionCompartida? = {
            if let s = sesion {
                let agua = s.avituallamiento?.mililitrosTotales
                let sales = s.avituallamiento.map { $0.sodioMg > 0 ? max(1, Int(($0.sodioMg + 499) / 500)) : 0 }
                return SesionCompartida(tipo: s.tipo,
                                        distanciaMetros: s.distanciaMetros,
                                        duracionMinutos: s.duracionMinutos,
                                        minutoDelDia: s.minutoDelDia,
                                        geles: s.avituallamiento?.geles,
                                        aguaMl: agua,
                                        sales: sales,
                                        esDescanso: false,
                                        esFuerza: false)
            } else if let hoy = nuevo.plan.valor?.hoy {
                if hoy.esFuerza {
                    return SesionCompartida(tipo: hoy.titulo,
                                            distanciaMetros: nil,
                                            duracionMinutos: 0,
                                            minutoDelDia: nil,
                                            geles: nil,
                                            esDescanso: false,
                                            esFuerza: true)
                } else if hoy.titulo.localizedCaseInsensitiveContains("descanso") || hoy.sesion == nil {
                    return SesionCompartida(tipo: hoy.titulo,
                                            distanciaMetros: nil,
                                            duracionMinutos: 0,
                                            minutoDelDia: nil,
                                            geles: nil,
                                            esDescanso: true,
                                            esFuerza: false)
                }
            }
            return nil
        }()
        sincronizador.publicarSesion(sesionCompartida)
        if let cronograma = nuevo.plan.valor?.cronograma, !cronograma.isEmpty {
            sincronizador.publicarCronograma(cronograma)
        }
        programarRecordatorios(plan: nuevo.plan.valor)
        programarAvisoCalor()
        if !semanaDeHoyElegida, let semana = nuevo.plan.valor?.semanaDeHoy {
            semanaElegida = semana
            semanaDeHoyElegida = true
        }
    }

    func reprogramarRecordatorios() {
        programarRecordatorios(plan: contenido.plan.valor)
        ultimaConsultaCalor = nil
        programarAvisoCalor()
    }

    private func programarAvisoCalor() {
        let habilitado = UserDefaults.standard.object(forKey: "ajuste_notif_calor") as? Bool ?? true
        if !habilitado { Task { await NotificadorDeEntrenamiento.limpiarAvisosDeCalor() } }
        guard habilitado, let coord = seguimiento.ubicacion,
              let plan = contenido.plan.valor,
              let servicio = repositorio.servicioDelCatalogo() else { return }
        if let ultimaConsultaCalor, Date().timeIntervalSince(ultimaConsultaCalor) < 60 * 60 { return }
        ultimaConsultaCalor = Date()
        Task {
            guard case .ok(let pronostico) = await servicio.pronostico(
                lat: coord.latitude, lon: coord.longitude) else { return }
            guard UserDefaults.standard.object(forKey: "ajuste_notif_calor") as? Bool ?? true else { return }
            await NotificadorDeEntrenamiento.limpiarAvisosDeCalor()
            let ahora = Date()
            let calendario = Calendar.current
            let formato = DateFormatter()
            formato.dateFormat = "yyyy-MM-dd"
            for dia in plan.cronograma where dia.esDescanso != true {
                guard let fecha = formato.date(from: dia.fechaIso) else { continue }
                var componentes = calendario.dateComponents([.year, .month, .day], from: fecha)
                componentes.hour = 8
                componentes.minute = 0
                guard let manana = calendario.date(from: componentes), manana > ahora else { continue }
                let pronosticada = pronostico.hours.min { a, b in
                    abs(Double(a.atMs) / 1000 - manana.timeIntervalSince1970) <
                    abs(Double(b.atMs) / 1000 - manana.timeIntervalSince1970)
                }
                guard let pronosticada,
                      abs(Double(pronosticada.atMs) / 1000 - manana.timeIntervalSince1970) <= 90 * 60,
                      pronosticada.airTemperatureC >= 30 else { continue }
                NotificadorDeEntrenamiento.programarRecordatorio(
                    id: "calor-\(dia.fechaIso)",
                    titulo: "Calor previsto para entrenar",
                    cuerpo: "Se esperan \(Int(pronosticada.airTemperatureC.rounded())) °C. Revisá el horario y llevá agua. Fuente: MET Norway.",
                    fecha: manana)
            }
        }
    }

    private func programarRecordatorios(plan: PlanDelHome?) {
        guard let plan, !plan.cronograma.isEmpty else { return }
        NotificadorDeEntrenamiento.limpiarRecordatorios()

        let avisoMananaHabilitado = UserDefaults.standard.object(forKey: "ajuste_notif_manana") as? Bool ?? true
        let recordatorioPrevioHabilitado = UserDefaults.standard.object(forKey: "ajuste_notif_recordatorio_antes") as? Bool ?? true

        guard avisoMananaHabilitado || recordatorioPrevioHabilitado else { return }

        let ahora = Date()
        let calendario = Calendar.current
        let dfIso = DateFormatter()
        dfIso.dateFormat = "yyyy-MM-dd"

        for dia in plan.cronograma {
            guard dia.esDescanso != true else { continue }
            guard let fechaDia = dfIso.date(from: dia.fechaIso) else { continue }

            let componentesDia = calendario.dateComponents([.year, .month, .day], from: fechaDia)

            // 1. Notificación matutina a las 8:00 AM
            if avisoMananaHabilitado {
                var compManana = componentesDia
                compManana.hour = 8
                compManana.minute = 0
                if let fechaManana = calendario.date(from: compManana), fechaManana > ahora {
                    let minutoEntreno = dia.minutoDelDia ?? 1140
                    let horaTexto = Formato.hora(minutoDelDia: minutoEntreno)
                    let titulo = Textos.notificacionRecordatorioMananaTitulo
                    let cuerpo = Textos.notificacionRecordatorioMananaCuerpo(horaTexto, dia.tipo)
                    NotificadorDeEntrenamiento.programarRecordatorio(
                        id: "manana-\(dia.fechaIso)",
                        titulo: titulo,
                        cuerpo: cuerpo,
                        fecha: fechaManana
                    )
                }
            }

            // 2. Notificación previa al entrenamiento: 30 minutos antes de la hora definida
            if recordatorioPrevioHabilitado {
                let minutoEntreno = dia.minutoDelDia ?? 1140
                let minutoAviso = max(0, minutoEntreno - 30)
                var compHora = componentesDia
                compHora.hour = minutoAviso / 60
                compHora.minute = minutoAviso % 60
                if let fechaHora = calendario.date(from: compHora), fechaHora > ahora {
                    let titulo = Textos.notificacionRecordatorioHoraTitulo
                    let cuerpo = Textos.notificacionRecordatorioHoraCuerpo(dia.tipo)
                    NotificadorDeEntrenamiento.programarRecordatorio(
                        id: "hora-\(dia.fechaIso)",
                        titulo: titulo,
                        cuerpo: cuerpo,
                        fecha: fechaHora
                    )
                }
            }
        }
    }

    // MARK: - Lo que leen las pantallas

    /// `nil` mientras no haya un plan que mostrar: la pantalla dice por qué.
    var plan: PlanDelHome? { contenido.plan.valor }
    var bloque: BloqueDelPlan? { plan?.bloque }
    var hoy: DiaDeHoy? { plan?.hoy }
    /// La salida de hoy. `nil` sin plan, en un descanso y en un día de fuerza.
    var sesion: SesionDelDia? { hoy?.sesion }
    var rutina: [EjercicioDeGimnasio] { contenido.rutina.valor?.ejercicios ?? [] }
    /// 🛑 `nil` si el servidor no dio objetivos: nunca se completa con un número.
    var objetivoNutricional: ObjetivoNutricional? { contenido.nutricion.valor?.objetivo }

    var semana: SemanaDelPlan? {
        guard let bloque else { return nil }
        return bloque.semanas.first { $0.numero == semanaElegida } ?? bloque.semanas.first
    }

    // MARK: - Pasos de Apple Health

    func pasos(para dia: DiaDelPlan) -> Int? {
        guard let fecha = dia.fecha else { return nil }
        let clave = ServicioDePasosSalud.clave(para: fecha)
        return pasosPorDia[clave]
    }

    func cargarPasosDeLaSemana() async {
        guard let semana else { return }
        let fechas = semana.dias.compactMap { $0.fecha }
        guard !fechas.isEmpty else { return }
        await ServicioDePasosSalud.compartido.solicitarPermisoYConsultar(fechas: fechas)
    }

    /// El motor dijo `profile_incomplete`: el Home muestra el aviso de completar el
    /// perfil aunque `GET /me` todavía no haya llegado.
    var faltaPerfil: Bool {
        [contenido.plan.problema, contenido.rutina.problema, contenido.nutricion.problema]
            .contains(.perfilIncompleto)
    }

    var iniciales: String {
        nombreCompleto.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined().uppercased()
    }

    /// La barra de pestañas se esconde en `entreno`: es pantalla completa.
    var muestraLaBarra: Bool { pestana != .entreno }

    var haySesionEnCurso: Bool { estadoDeLaSesion != .detenida }

    /// La agenda del día. El **orden, los horarios y los números** salen de la
    /// sesión que manda el servidor; los títulos son de la interfaz y por eso sí
    /// están localizados. Sin horario no hay nada que ordenar, y lo que el servidor
    /// no calculó —el avituallamiento, sin el peso— no se anota.
    var agenda: [FilaDeAgenda] {
        var filas: [FilaDeAgenda] = []
        if let s = sesion, let minuto = s.minutoDelDia {
            filas.append(FilaDeAgenda(minutoDelDia: minuto, titulo: "", detalle: "",
                                      clase: .sesion, destino: .entreno))
            if let a = s.avituallamiento {
                filas.append(FilaDeAgenda(minutoDelDia: minuto - 180,
                                          titulo: Textos.agendaSnack,
                                          detalle: Textos.agendaSnackDetalle(a.carbohidratosAntesG),
                                          clase: .simple, destino: .nutricion))
                filas.append(FilaDeAgenda(minutoDelDia: minuto - anticipacionMinutos,
                                          titulo: Textos.agendaPreparar,
                                          detalle: Textos.agendaPrepararDetalle(Formato.litros(a.mililitrosTotales),
                                                                               a.geles, anticipacionMinutos),
                                          clase: .simple, destino: nil))
                filas.append(FilaDeAgenda(minutoDelDia: minuto + s.duracionMinutos + 20,
                                          titulo: Textos.agendaRecuperacion,
                                          detalle: Textos.agendaRecuperacionDetalle(a.proteinaDespuesG,
                                                                                    a.carbohidratosDespuesG),
                                          clase: .simple, destino: .nutricion))
            }
        }
        if contenido.rutina.valor?.planificada == true, !rutina.isEmpty {
            filas.append(FilaDeAgenda(minutoDelDia: 12 * 60,
                                      titulo: Textos.agendaGimnasio,
                                      detalle: Textos.agendaGimnasioDetalle(rutina.count),
                                      clase: .gimnasio, destino: .gimnasio))
        }
        return filas.sorted { $0.minutoDelDia < $1.minutoDelDia }
    }

    // MARK: - Nutrición, lo consumido

    var consumido: ObjetivoNutricional {
        ObjetivoNutricional(
            kcal: comidas.reduce(0) { $0 + $1.kcal },
            carbohidratosG: comidas.reduce(0) { $0 + $1.carbohidratosG },
            proteinaG: comidas.reduce(0) { $0 + $1.proteinaG },
            grasaG: comidas.reduce(0) { $0 + $1.grasaG })
    }

    // MARK: - Gimnasio

    var seriesTotalesDeLaRutina: Int { rutina.reduce(0) { $0 + $1.prescripcion.series.count } }

    var seriesHechasDeLaRutina: Int {
        rutina.reduce(0) { total, ejercicio in
            total + min(seriesHechas(enEjercicio: ejercicio.id), ejercicio.prescripcion.series.count)
        }
    }

    func seriesHechas(enEjercicio indice: Int) -> Int {
        guard rutina.indices.contains(indice) else { return 0 }
        return seriesHechas(enEjercicio: rutina[indice].id)
    }

    func seriesHechas(enEjercicio id: String) -> Int {
        sincronizador.series.filter { $0.clave.ejercicio == id && $0.hecha }.count
    }

    private func clave(ejercicio: String, numero: Int) -> ClaveDeSerie {
        ClaveDeSerie(sesion: idDeSesion, ejercicio: ejercicio, numero: numero)
    }

    // MARK: - Acciones

    func ir(a destino: PestanaHome) {
        guard destino != pestana else { return }
        if PestanaHome.enLaBarra.contains(pestana) {
            pestanaPrevia = pestana
        }
        pestana = destino
    }

    func volverDeLaPantallaSecundaria() {
        if pestanaPrevia == .entreno || !PestanaHome.enLaBarra.contains(pestanaPrevia) {
            pestana = .inicio
        } else {
            pestana = pestanaPrevia
        }
    }

    /// Se ve YA, queda en la cola —en disco— y sube cuando se pueda (`ColaDeComidas`).
    func agregar(_ comida: Comida) {
        comidas.append(comida)
        comidas.sort { $0.minutoDelDia < $1.minutoDelDia }
        modal = nil
        guard let cola = colaDeComidas else { return }
        cola.guardar(id: comida.id, Self.entrada(de: comida))
        Task { await cola.subir() }
    }

    /// Desaparece YA; el `DELETE` espera en la cola si no hay señal.
    func quitarComida(_ id: String) {
        comidas.removeAll { $0.id == id }
        guard let cola = colaDeComidas else { return }
        cola.borrar(id: id)
        Task { await cola.subir() }
    }

    /// Lo que viaja en `PUT /meals/{id}`. La hora es la de HOY a ese minuto, en el
    /// calendario del teléfono, que es con el que la pantalla la eligió. El nombre va
    /// con el tope del contrato: uno más largo sería un 400.
    static func entrada(de comida: Comida, hoy: Date = Date()) -> ComidaEntrada {
        let comidaEn = Calendar.current.startOfDay(for: hoy).addingTimeInterval(TimeInterval(comida.minutoDelDia * 60))
        return ComidaEntrada(eatenAtMs: Int64((comidaEn.timeIntervalSince1970 * 1000).rounded()),
                             name: String(comida.nombre.prefix(120)),
                             kcal: Int64(comida.kcal), carbsG: Int64(comida.carbohidratosG),
                             proteinG: Int64(comida.proteinaG), fatG: Int64(comida.grasaG))
    }

    /// Registra una serie concreta. Lo que se propaga al reloj es esto.
    func registrarSerie(ejercicio indice: Int, numero: Int, repeticiones: Int, pesoGramos: Int?) {
        guard rutina.indices.contains(indice) else { return }
        let ejercicio = rutina[indice]
        sincronizador.registrar(clave: clave(ejercicio: ejercicio.id, numero: numero),
                                hecha: true, repeticiones: repeticiones, pesoGramos: pesoGramos)
    }

    func registrarSerie(ejercicio indice: Int, hasta serie: Int) {
        guard rutina.indices.contains(indice) else { return }
        let ejercicio = rutina[indice]
        // "hasta N" marca las N primeras: es lo que hacía el contador viejo.
        for numero in 1...max(1, serie) where numero <= ejercicio.prescripcion.series.count {
            let prescrita = ejercicio.prescripcion.series[numero - 1]
            sincronizador.registrar(clave: clave(ejercicio: ejercicio.id, numero: numero),
                                    hecha: true,
                                    repeticiones: prescrita.repeticiones,
                                    pesoGramos: prescrita.pesoGramos)
        }
    }


    func empezarOPausar(deporte: DeporteDeSesion = .running) {
        if seguimiento.fase != .detenida {
            seguimiento.pausarOReanudar()
        } else if let remota = salidaRemotaActiva {
            _ = sincronizador.solicitarComando(remota.pausada ? .reanudar : .pausar)
        } else {
            seguimiento.pedirPermisoYEmpezar(deporte: deporte)
        }
    }

    func terminarSesion() {
        var salidaTerminada: SalidaCapturada?
        if seguimiento.fase != .detenida {
            if let salida = seguimiento.terminar() {
                salidaTerminada = salida
                self.resumenSalida = salida
            }
        } else if let remota = salidaRemotaActiva {
            _ = sincronizador.solicitarComando(.terminar)
            let salida = SalidaCapturada(
                id: remota.id,
                deporte: remota.deporte ?? .running,
                inicioMs: remota.actualizadoMs - Int64(remota.segundos * 1000),
                segundos: remota.segundos,
                metros: remota.metros,
                puntos: remota.puntos,
                dispositivo: .reloj,
                pulsoMedio: nil,
                pulsoMaximo: nil
            )
            salidaTerminada = salida
            self.resumenSalida = salida
        }
        if let terminada = salidaTerminada {
            let ahoraMs = RenovadorDeSesion.ahoraEnMs()
            let nuevaActividad = Actividad(
                id: terminada.id,
                sport: terminada.deporte,
                startedAtMs: terminada.inicioMs,
                durationS: Int64(terminada.segundos),
                distanceM: Int64(terminada.metros),
                elevationGainM: 0,
                avgHrBpm: terminada.pulsoMedio.map(Int64.init),
                maxHrBpm: terminada.pulsoMaximo.map(Int64.init),
                kcal: nil,
                device: terminada.dispositivo ?? .telefono,
                createdAtMs: ahoraMs,
                updatedAtMs: ahoraMs
            )
            recorridosLocales[terminada.id] = terminada.puntos
            AlmacenDeRecorridos.compartido.guardar(id: terminada.id, puntos: terminada.puntos)
            actividadesDeHoy.removeAll { $0.id == terminada.id }
            actividadesDeHoy.insert(nuevaActividad, at: 0)
            AlmacenDeHitos.compartido.registrarActividad(nuevaActividad)
        }
    }

    func descartarSesion() {
        if seguimiento.fase != .detenida {
            seguimiento.descartar()
        } else if salidaRemotaActiva != nil {
            _ = sincronizador.solicitarComando(.descartar)
        }
        self.resumenSalida = nil
    }

    func cerrarResumen() {
        self.resumenSalida = nil
        ir(a: .inicio)
    }
}
