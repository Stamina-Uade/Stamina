import Foundation
@testable import TrainerCore

/// Un `ServicioDelPlan` de mentira: cada ruta contesta lo que el test le diga, y
/// anota en orden lo que se le pidió. No hay `URLSession` abajo: lo que se prueba
/// con esto es lo que la app hace con las respuestas, no cómo viajan (eso lo prueba
/// `ApiDelPlanTests`).
final class PlanDePrueba: ServicioDelPlan, @unchecked Sendable {
    private let cerrojo = NSLock()
    private var registro: [String] = []

    private var _plan: Resultado<Plan> = .sinRed
    private var _rutina: Resultado<RutinaDelDia> = .sinRed
    private var _nutricion: Resultado<DiaNutricional> = .sinRed
    private var _alSincronizar: (String, [SerieDeGimnasioEntrada], String) -> Resultado<SesionDeGimnasio> =
        { _, _, _ in .sinRed }
    private var _alPedirSesion: (String) -> Resultado<SesionDeGimnasio> = { _ in .sinRed }
    private var _alGuardarComida: (String, ComidaEntrada) -> Resultado<ComidaRegistrada> = { _, _ in .sinRed }
    private var _alBorrarComida: (String) -> Resultado<SinCuerpo> = { _ in .sinRed }
    private var _compuerta: CompuertaDePrueba?

    var respuestaDelPlan: Resultado<Plan> {
        get { con { _plan } }
        set { con { _plan = newValue } }
    }
    var respuestaDeRutina: Resultado<RutinaDelDia> {
        get { con { _rutina } }
        set { con { _rutina = newValue } }
    }
    var respuestaDeNutricion: Resultado<DiaNutricional> {
        get { con { _nutricion } }
        set { con { _nutricion = newValue } }
    }
    var alSincronizar: (String, [SerieDeGimnasioEntrada], String) -> Resultado<SesionDeGimnasio> {
        get { con { _alSincronizar } }
        set { con { _alSincronizar = newValue } }
    }
    var alPedirSesion: (String) -> Resultado<SesionDeGimnasio> {
        get { con { _alPedirSesion } }
        set { con { _alPedirSesion = newValue } }
    }
    var alGuardarComida: (String, ComidaEntrada) -> Resultado<ComidaRegistrada> {
        get { con { _alGuardarComida } }
        set { con { _alGuardarComida = newValue } }
    }
    var alBorrarComida: (String) -> Resultado<SinCuerpo> {
        get { con { _alBorrarComida } }
        set { con { _alBorrarComida = newValue } }
    }
    /// Si está, cada pedido espera a que se abra antes de contestar.
    var compuerta: CompuertaDePrueba? {
        get { con { _compuerta } }
        set { con { _compuerta = newValue } }
    }

    /// Lo que se pidió, en orden: `"plan"`, `"POST gym-2026-09-10 [clave]"`, `"PUT <id>"`…
    var llamadas: [String] { con { registro } }

    private func con<T>(_ hacer: () -> T) -> T {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return hacer()
    }

    private func anotar(_ llamada: String) async {
        con { registro.append(llamada) }
        await compuerta?.pasar()
    }

    func plan() async -> Resultado<Plan> {
        await anotar("plan")
        return respuestaDelPlan
    }

    func rutina(delDia fechaMs: Int64) async -> Resultado<RutinaDelDia> {
        await anotar("rutina")
        return respuestaDeRutina
    }

    func nutricion(delDia fechaMs: Int64) async -> Resultado<DiaNutricional> {
        await anotar("nutricion")
        return respuestaDeNutricion
    }

    func guardarComida(id: String, _ comida: ComidaEntrada) async -> Resultado<ComidaRegistrada> {
        await anotar("PUT \(id)")
        return alGuardarComida(id, comida)
    }

    func borrarComida(id: String) async -> Resultado<SinCuerpo> {
        await anotar("DELETE \(id)")
        return alBorrarComida(id)
    }

    func sincronizarSeries(sesion: String, _ series: [SerieDeGimnasioEntrada],
                           claveDeIdempotencia: String) async -> Resultado<SesionDeGimnasio> {
        await anotar("POST \(sesion) \(claveDeIdempotencia)")
        return alSincronizar(sesion, series, claveDeIdempotencia)
    }

    func sesionDeGimnasio(_ id: String) async -> Resultado<SesionDeGimnasio> {
        await anotar("GET \(id)")
        return alPedirSesion(id)
    }

    func sesionesDeGimnasio(limite: Int?, cursor: String?) async -> Resultado<Pagina<ResumenDeSesionDeGimnasio>> {
        await anotar("sesiones")
        return .sinRed
    }

    func ejercicios(limite: Int?, cursor: String?) async -> Resultado<Pagina<EjercicioCatalogado>> {
        await anotar("ejercicios")
        return .sinRed
    }
}

/// Espera a que algo pase, con techo: un test roto falla en vez de colgarse.
func esperar(hasta condicion: () -> Bool) async {
    var intentos = 0
    while !condicion(), intentos < 1_000 {
        try? await Task.sleep(nanoseconds: 2_000_000)
        intentos += 1
    }
}
