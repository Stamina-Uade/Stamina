import Foundation

// =============================================================================
// Lo que el Home necesita del motor —el plan, la rutina y la nutrición de hoy—,
// offline primero (AGENTS.md §6).
//
// Tres reglas:
//
// 1. **Lo guardado se ve YA.** `guardado()` no toca la red: es lo que se muestra al
//    abrir, antes de que conteste nadie.
// 2. **Una respuesta buena reemplaza a lo guardado; una mala, no.** Sin red o con un
//    5xx, lo guardado sigue a la vista y se dice que está desactualizado. Un pedido
//    que falló nunca borra lo último bueno.
// 3. 🛑 **Lo de un día no se muestra como si fuera de hoy.** La rutina y la nutrición
//    son de UN día: si lo guardado es de ayer, para hoy no hay nada guardado, y la
//    pantalla dice eso en vez de mostrar lo de ayer. El día se cuenta en la zona del
//    PLAN, que es la del perfil —con la que el servidor elige el día—, no en la del
//    teléfono. El plan no tiene ese problema: es el bloque entero, y hoy es uno de
//    sus días.
// =============================================================================

/// Lo que el Home muestra del motor, cada parte con su estado.
public struct DatosDelHome: Sendable {
    public var plan: Seccion<Plan>
    public var rutina: Seccion<RutinaDelDia>
    public var nutricion: Seccion<DiaNutricional>

    public init(plan: Seccion<Plan>, rutina: Seccion<RutinaDelDia>, nutricion: Seccion<DiaNutricional>) {
        self.plan = plan
        self.rutina = rutina
        self.nutricion = nutricion
    }
}

public final class FuenteDelServidor: Sendable {
    private let servicio: any ServicioDelPlan
    private let cache: CacheDelServidor
    private let reloj: @Sendable () -> Int64

    public init(servicio: any ServicioDelPlan, cache: CacheDelServidor,
                reloj: @escaping @Sendable () -> Int64 = RenovadorDeSesion.ahoraEnMs) {
        self.servicio = servicio
        self.cache = cache
        self.reloj = reloj
    }

    /// Lo guardado, sin tocar la red (regla 1).
    public func guardado() -> DatosDelHome {
        let ahora = reloj()
        let plan = cache.leer(.plan, como: Plan.self)
        let hoy = Self.inicioDelDia(ahora, zona: Self.zona(de: plan?.valor))
        let rutina = cache.leer(.rutina, como: RutinaDelDia.self)
        let nutricion = cache.leer(.nutricion, como: DiaNutricional.self)
        return DatosDelHome(
            plan: Seccion(plan),
            rutina: Seccion(rutina?.valor.dateMs == hoy ? rutina : nil),
            nutricion: Seccion(nutricion?.valor.dateMs == hoy ? nutricion : nil))
    }

    /// Le pregunta todo al servidor, a la vez, y guarda lo que llegó bien (regla 2).
    public func actualizar() async -> DatosDelHome {
        let generacion = cache.generacion
        let ahora = reloj()
        async let plan = servicio.plan()
        async let rutina = servicio.rutina(delDia: ahora)
        async let nutricion = servicio.nutricion(delDia: ahora)
        let respuestas = await (plan, rutina, nutricion)

        // La sesión se cerró mientras se esperaba: lo que volvió es de quien se fue.
        guard cache.generacion == generacion else { return guardado() }

        let previo = guardado()
        return DatosDelHome(
            plan: resolver(respuestas.0, en: .plan, previo: previo.plan, ahora: ahora, generacion: generacion),
            rutina: resolver(respuestas.1, en: .rutina, previo: previo.rutina, ahora: ahora,
                             generacion: generacion),
            nutricion: resolver(respuestas.2, en: .nutricion, previo: previo.nutricion, ahora: ahora,
                                generacion: generacion))
    }

    private func resolver<Valor: Codable>(_ respuesta: Resultado<Valor>, en clave: CacheDelServidor.Clave,
                                          previo: Seccion<Valor>, ahora: Int64,
                                          generacion: Int) -> Seccion<Valor> {
        if case .ok(let valor) = respuesta {
            cache.guardar(valor, en: clave, ahoraMs: ahora, generacion: generacion)
            return Seccion(valor: valor, guardadoEnMs: ahora)
        }
        var seccion = previo
        seccion.problema = ProblemaDeCarga.de(respuesta)
        return seccion
    }

    // MARK: - El día

    /// La zona con la que el servidor cuenta los días: la del plan, que es la del
    /// perfil. Sin plan guardado, la del teléfono.
    public static func zona(de plan: Plan?) -> TimeZone {
        plan.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    /// Las 00:00 del día de `instanteMs` en `zona`, en ms epoch: lo mismo que manda
    /// el servidor como `date_ms` de ese día (docs/API.md §8).
    public static func inicioDelDia(_ instanteMs: Int64, zona: TimeZone) -> Int64 {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zona
        let inicio = calendario.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(instanteMs) / 1000))
        return Int64((inicio.timeIntervalSince1970 * 1000).rounded())
    }
}
