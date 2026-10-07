import Foundation

// =============================================================================
// Las comidas que la persona guardó o borró, hasta que las recibe el servidor.
//
// AGENTS.md §6 y §5.2. Tres reglas:
//
// 1. **Lo que la persona hace se ve YA y queda en disco** antes de salir a la red:
//    una comida anotada en el subte no se pierde por cerrar la app.
// 2. **`PUT /meals/{id}` es idempotente por id**, y el id lo genera el cliente antes
//    del primer intento: reintentar un guardado —aunque la respuesta se haya
//    perdido— nunca crea dos comidas. `DELETE` también es idempotente: borrar lo
//    que no existe da 204.
// 3. **En orden, y de a una.** Si una operación no sale —sin red, un 5xx—, la cola
//    se detiene ahí y conserva el resto, para que un borrado nunca llegue antes que
//    el guardado de la misma comida.
//
// La cola vive en la caché del servidor (`CacheDelServidor`): dato de salud, con
// Data Protection, y se borra en cada cierre de sesión.
// =============================================================================

/// Lo que espera para subir.
public enum OperacionDeComida: Codable, Equatable, Sendable {
    case guardar(id: String, comida: ComidaEntrada)
    case borrar(id: String)

    public var id: String {
        switch self {
        case .guardar(let id, _), .borrar(let id): return id
        }
    }
}

@MainActor
public final class ColaDeComidas {
    private let servicio: any ServicioDelPlan
    private let cache: CacheDelServidor
    private let reloj: @Sendable () -> Int64

    public private(set) var pendientes: [OperacionDeComida]
    private var enCurso: Task<Void, Never>?
    private var otraVuelta = false

    public init(servicio: any ServicioDelPlan, cache: CacheDelServidor,
                reloj: @escaping @Sendable () -> Int64 = RenovadorDeSesion.ahoraEnMs) {
        self.servicio = servicio
        self.cache = cache
        self.reloj = reloj
        // Lo que quedó de antes: la app se cerró con cosas sin subir.
        pendientes = cache.leer(.comidasPendientes, como: [OperacionDeComida].self)?.valor ?? []
    }

    /// Anota una comida nueva o corregida. Una versión anterior de la misma que no
    /// subió todavía ya no hace falta: el PUT manda la fila entera.
    public func guardar(id: String, _ comida: ComidaEntrada) {
        let nueva = OperacionDeComida.guardar(id: id, comida: comida)
        if let i = pendientes.firstIndex(where: { if case .guardar = $0 { return $0.id == id }; return false }) {
            pendientes[i] = nueva
        } else {
            pendientes.append(nueva)
        }
        persistir(generacion: nil)
    }

    /// Anota que se borró. Si su guardado no había subido, se descarta; el DELETE sale
    /// igual, porque ese guardado pudo haber llegado sin que volviera la respuesta.
    public func borrar(id: String) {
        pendientes.removeAll { $0.id == id }
        pendientes.append(.borrar(id: id))
        persistir(generacion: nil)
    }

    /// Sube lo pendiente, en orden. Con una vuelta en el aire no sale otra: se anota
    /// para cuando termine.
    public func subir() async {
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
        let alSalir = cache.generacion
        while let operacion = pendientes.first {
            let seVa: Bool
            switch operacion {
            case .guardar(let id, let comida):
                seVa = Self.terminada(await servicio.guardarComida(id: id, comida).map { _ in () })
            case .borrar(let id):
                seVa = Self.terminada(await servicio.borrarComida(id: id).map { _ in () })
            }
            // La sesión se cerró mientras viajaba: la cola era de quien se fue.
            guard cache.generacion == alSalir else { return }
            guard seVa else { return }
            // Por igualdad: si mientras viajaba la persona la corrigió, la versión nueva
            // se queda y sale en la próxima vuelta.
            if let i = pendientes.firstIndex(of: operacion) { pendientes.remove(at: i) }
            persistir(generacion: alSalir)
        }
    }

    /// Si la operación ya no tiene que volver a salir.
    private static func terminada(_ resultado: Resultado<Void>) -> Bool {
        switch resultado {
        case .ok:
            return true
        case .rechazado(_, let http) where http == 404:
            // Un PUT sobre una comida que se borró en otro lado: borrar gana.
            return true
        case .rechazado(_, let http) where (400..<500).contains(http) && http != 401 && http != 429:
            // No se arregla reintentando lo mismo, y trabaría todo lo que viene atrás.
            return true
        case .rechazado, .sinRed, .respuestaRara:
            // Sin red, un 5xx, un 429 o una sesión que se está renovando: queda en la
            // cola, con el mismo id, para el próximo intento.
            return false
        }
    }

    private func persistir(generacion: Int?) {
        if pendientes.isEmpty, generacion == nil || generacion == cache.generacion {
            cache.borrar(.comidasPendientes)
            return
        }
        cache.guardar(pendientes, en: .comidasPendientes, ahoraMs: reloj(), generacion: generacion)
    }
}
