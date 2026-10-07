import Foundation
import Network

/// Avisa cuando vuelve la red, para subir lo que quedó pendiente (AGENTS.md §6: la
/// app se usa sin señal y sincroniza después).
///
/// Sólo el paso de "sin red" a "con red": al abrir, el Home ya pide todo por su lado,
/// y avisar también en el primer estado haría salir los mismos pedidos dos veces.
final class MonitorDeRed {
    private let monitor = NWPathMonitor()

    /// Lo que se vio la última vez. Sólo lo toca la cola del monitor.
    private final class Visto: @unchecked Sendable {
        var habiaRed: Bool?
    }

    init(alVolver: @escaping @MainActor () -> Void) {
        let visto = Visto()
        monitor.pathUpdateHandler = { camino in
            let hayRed = camino.status == .satisfied
            let volvio = hayRed && visto.habiaRed == false
            visto.habiaRed = hayRed
            guard volvio else { return }
            Task { @MainActor in alVolver() }
        }
        monitor.start(queue: DispatchQueue(label: "com.tecladus.Trainer.red"))
    }

    deinit {
        monitor.cancel()
    }
}
