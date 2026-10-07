import Foundation
import TrainerCore

// =============================================================================
// Dónde se arma la red de la app, una sola vez.
//
// Es el único archivo de la app que sabe que existen `URLSession`, el Keychain y
// la URL del servidor. Las pantallas y `FlujoEntrada` hablan con un
// `ServicioDeCuenta`, que en los tests es un doble: así se prueba el flujo entero
// —el alta, la recuperación, la sesión que se cierra— sin un servidor corriendo y
// sin tocar el llavero del simulador.
//
// 🛑 Adentro de los tests la app NO arma los servicios de verdad. `TrainerTests`
// corre hospedado en la app, y sin esto cada corrida arrancaba `TrainerApp` con la
// puerta de versión y el llavero reales, hablándole al servidor de producción.
// =============================================================================

struct ServiciosDeLaApp {
    let cuenta: any ServicioDeCuenta
    let consultarVersion: @Sendable () async -> DecisionDeVersion
    /// El repositorio de cada Home que se arma. Todos comparten la misma fuente y
    /// la misma caché, que es la que se borra al cerrar la sesión.
    let repositorioDelHome: () -> RepositorioDePlan
    let sincronizador: SincronizadorDeSesion?

    /// Los de este proceso: los de verdad, salvo en DEBUG cuando la app corre
    /// adentro de un test (`usaDobles`).
    static func paraEsteProceso() -> ServiciosDeLaApp {
        #if DEBUG
        let proceso = ProcessInfo.processInfo
        if usaDobles(argumentos: proceso.arguments, entorno: proceso.environment) {
            return sinServidor()
        }
        #endif
        return reales()
    }

    /// Los de verdad: producción, o lo que diga `-apiBase` en DEBUG
    /// (`ConfiguracionDeRed`), con la sesión en el llavero.
    static func reales() -> ServiciosDeLaApp {
        armar(cliente: ClienteAPI(base: ConfiguracionDeRed.base()),
              almacen: AlmacenEnLlavero(),
              series: AlmacenDeSeries(),
              cache: CacheDelServidor())
    }

    /// Cómo se conectan las piezas. Está aparte de `reales()` para que un test arme
    /// EXACTAMENTE esto, con una red de mentira, un llavero en memoria y un archivo
    /// de series y una caché propios.
    ///
    /// Un solo `ClienteAPI` para todo: la puerta de versión, el alta y el
    /// renovador comparten la misma `URLSession` sin caché.
    static func armar(cliente: ClienteAPI, almacen: any AlmacenDeCredenciales,
                      series: AlmacenDeSeries, cache: CacheDelServidor,
                      sincronizador: SincronizadorDeSesion? = nil) -> ServiciosDeLaApp {
        // 🛑 Las series del gimnasio que quedaron en disco y lo que se guardó del
        // servidor —el plan, la nutrición, las comidas por subir— son de quien cerró
        // la sesión: se van con el llavero, en el mismo instante y por cualquier
        // motivo —"Cerrar sesión" o una revocación del servidor—. Si no, la próxima
        // persona que entra en este teléfono arranca con el entrenamiento y los datos
        // de salud de otra.
        let renovador = RenovadorDeSesion(cliente: cliente, almacen: almacen,
                                          alCerrar: {
                                              series.borrar()
                                              cache.borrarTodo()
                                              AlmacenDeSalidas().borrar()
                                              AlmacenDeTransferenciasDeSalida().borrarTodo()
                                              if let sincronizador {
                                                  Task { @MainActor in
                                                      sincronizador.cerrarSesion()
                                                  }
                                              }
                                          })
        let puerta = PuertaDeVersion(cliente: cliente)
        let api = ApiTrainer(cliente: cliente, renovador: renovador)
        return ServiciosDeLaApp(
            cuenta: api,
            consultarVersion: { await puerta.consultar() },
            repositorioDelHome: { RepositorioDelServidor(servicio: api, cache: cache) },
            sincronizador: sincronizador
        )
    }

    #if DEBUG
    /// El argumento de lanzamiento que pide los dobles. Lo pasan los tests de UI y
    /// la acción de test del esquema, para la app que hospeda los unitarios.
    static let argumentoDeDobles = "-serviciosDePrueba"

    /// Si este proceso corre adentro de un test.
    ///
    /// El argumento es el camino principal. El entorno de XCTest es la red de abajo:
    /// una corrida desde otro esquema o un plan de tests sin el argumento tampoco
    /// puede terminar hablándole al servidor de verdad.
    static func usaDobles(argumentos: [String], entorno: [String: String]) -> Bool {
        argumentos.contains(argumentoDeDobles)
            || entorno["XCTestConfigurationFilePath"] != nil
            || entorno["XCTestBundlePath"] != nil
            || entorno["XCTestSessionIdentifier"] != nil
    }

    /// Sin red y sin llavero: cada pedido contesta "sin red", no hay sesión guardada
    /// y la puerta de versión deja pasar, que es lo que hace la de verdad cuando no
    /// puede preguntar. El Home es el de verdad sobre esa red: sin nada guardado,
    /// muestra su estado vacío (la maqueta la pide `-datosDeEjemplo`).
    static func sinServidor() -> ServiciosDeLaApp {
        let cache = CacheDelServidor(nombre: "cache-sin-servidor")
        return ServiciosDeLaApp(cuenta: CuentaSinServidor(), consultarVersion: { .pasar },
                                repositorioDelHome: { RepositorioDelServidor(servicio: PlanSinServidor(), cache: cache) },
                                sincronizador: nil)
    }
    #endif
}

#if DEBUG
/// El motor adentro de los tests: todo contesta "sin red".
struct PlanSinServidor: ServicioDelPlan, ServicioDeActividades {
    func plan() async -> Resultado<Plan> { .sinRed }
    func rutina(delDia fechaMs: Int64) async -> Resultado<RutinaDelDia> { .sinRed }
    func nutricion(delDia fechaMs: Int64) async -> Resultado<DiaNutricional> { .sinRed }
    func guardarComida(id: String, _ comida: ComidaEntrada) async -> Resultado<ComidaRegistrada> { .sinRed }
    func borrarComida(id: String) async -> Resultado<SinCuerpo> { .sinRed }
    func sincronizarSeries(sesion: String, _ series: [SerieDeGimnasioEntrada],
                           claveDeIdempotencia: String) async -> Resultado<SesionDeGimnasio> { .sinRed }
    func sesionDeGimnasio(_ id: String) async -> Resultado<SesionDeGimnasio> { .sinRed }
    func sesionesDeGimnasio(limite: Int?, cursor: String?) async -> Resultado<Pagina<ResumenDeSesionDeGimnasio>> {
        .sinRed
    }
    func ejercicios(limite: Int?, cursor: String?) async -> Resultado<Pagina<EjercicioCatalogado>> { .sinRed }
    func guardarActividad(id: String, _ actividad: ActividadEntrada) async -> Resultado<Actividad> { .sinRed }
    func guardarRecorrido(id: String, _ puntos: [PuntoDeRecorrido]) async -> Resultado<RecorridoDeActividad> { .sinRed }
    func actividades(limite: Int?, cursor: String?) async -> Resultado<Pagina<Actividad>> { .sinRed }
    func recorrido(id: String) async -> Resultado<RecorridoDeActividad> { .sinRed }
}
#endif

#if DEBUG
/// La cuenta de la app adentro de los tests: nunca llega a un servidor ni toca el
/// llavero. 🛑 Sólo existe en DEBUG: un binario de release no tiene cómo armarla.
struct CuentaSinServidor: ServicioDeCuenta {
    let habiaSesionAlArrancar = false

    func salud() async -> Resultado<Health> { .sinRed }
    func textosLegales() async -> Resultado<TextosLegales> { .sinRed }
    func pedirCodigoDeRegistro(correo: String) async -> Resultado<DesafioCorreo> { .sinRed }
    func verificarCodigoDeRegistro(correo: String, codigo: String) async -> Resultado<TokenDeRegistro> {
        .sinRed
    }
    func completarRegistro(token: String, clave: String, aceptacion: AceptacionLegal,
                           perfil: PerfilEntrada) async -> Resultado<SesionAbierta> { .sinRed }
    func entrar(correo: String, clave: String) async -> Resultado<SesionAbierta> { .sinRed }
    func pedirCodigoDeClave(correo: String) async -> Resultado<DesafioCorreo> { .sinRed }
    func verificarCodigoDeClave(correo: String, codigo: String) async -> Resultado<TokenDeReseteo> { .sinRed }
    func cambiarClave(token: String, clave: String) async -> Resultado<SesionAbierta> { .sinRed }
    func miPerfil() async -> Resultado<Perfil> { .sinRed }
    func guardarPerfil(_ perfil: PerfilEntrada, anulando: Set<CampoAnulable>,
                       claveDeIdempotencia: String) async -> Resultado<Perfil> { .sinRed }
    func haySesion() async -> Bool { false }
    func cerrarSesion() async {}
    /// Sin sesión no hay cierres que avisar: quien escucha, espera para siempre.
    func cierres() async -> AsyncStream<MotivoDeCierre> { AsyncStream { _ in } }
}
#endif
