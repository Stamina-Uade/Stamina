import Foundation
import TrainerCore

/// El repositorio de la app de verdad: lo que manda el motor de la 1.1.0, con lo
/// último bueno guardado para cuando no hay red (`FuenteDelServidor`, AGENTS.md §6).
///
/// Lo único que agrega es la traducción a lo que muestran las pantallas
/// (`TraduccionDelServidor`). No calcula nada del plan, y cuando no hay nada que
/// mostrar devuelve NADA: nunca completa con los datos de `RepositorioProvisional`.
struct RepositorioDelServidor: RepositorioDePlan {
    let servicio: any ServicioDelPlan
    /// La misma que borra el cierre de sesión (`ServiciosDeLaApp.armar`).
    let cache: CacheDelServidor
    var reloj: @Sendable () -> Int64 = RenovadorDeSesion.ahoraEnMs

    private var fuente: FuenteDelServidor {
        FuenteDelServidor(servicio: servicio, cache: cache, reloj: reloj)
    }

    func guardado() -> ContenidoDelHome {
        traducir(fuente.guardado())
    }

    func actualizar() async -> ContenidoDelHome {
        traducir(await fuente.actualizar())
    }

    /// Sin GPS —que es de otra fase— no hay métricas de una salida en curso, y no se
    /// inventan.
    func sesionEnCurso() -> SesionEnCurso {
        .detenida
    }

    /// La API no tiene catálogo de alimentos todavía (docs/API.md §9): no hay
    /// frecuentes que ofrecer.
    func platosFrecuentes() -> [PlatoSugerido] {
        []
    }

    /// Ni reconocimiento de platos por foto.
    func platosReconocibles() -> [PlatoSugerido] {
        []
    }

    /// Con la generación de la caché: lo que vuelve de un pedido que salió antes de un
    /// cierre de sesión no se escribe en las series del que entró después.
    @MainActor
    func sincronizacion(de sincronizador: SincronizadorDeSesion) -> SincronizacionConElServidor? {
        let cache = self.cache
        return SincronizacionConElServidor(servicio: servicio, sincronizador: sincronizador,
                                           generacion: { cache.generacion })
    }

    /// Sobre la misma caché: la cola es dato de salud, y se va con la sesión.
    @MainActor
    func colaDeComidas() -> ColaDeComidas? {
        ColaDeComidas(servicio: servicio, cache: cache, reloj: reloj)
    }

    @MainActor
    func servicioDeActividades() -> (any ServicioDeActividades)? {
        servicio as? any ServicioDeActividades
    }

    func servicioDelCatalogo() -> (any ServicioDelPlan)? { servicio }

    private func traducir(_ datos: DatosDelHome) -> ContenidoDelHome {
        let ahora = reloj()
        let zona = FuenteDelServidor.zona(de: datos.plan.valor)
        return ContenidoDelHome(
            plan: datos.plan.map { TraduccionDelServidor.plan($0, ahoraMs: ahora) },
            rutina: datos.rutina.map { TraduccionDelServidor.rutina($0) },
            nutricion: datos.nutricion.map { TraduccionDelServidor.nutricion($0, zona: zona) })
    }
}
