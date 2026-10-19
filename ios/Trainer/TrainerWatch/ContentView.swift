import SwiftUI
import TrainerCore

/// El punto de entrada de la vista del reloj.
///
/// Escucha el color que manda el teléfono (`AparienciaDelReloj`): al cambiar, se
/// vuelve a evaluar y el `.tint` de todo el reloj pasa al color nuevo.
///
/// 🛑 El `.id` que fuerza el redibujo completo NO va acá: `RaizReloj` crea
/// `EstadoReloj` con `@StateObject`, y ese objeto es dueño del sincronizador y
/// del `SeguimientoDelReloj` (la sesión de entrenamiento). Cambiarle la
/// identidad a `RaizReloj` lo re-crearía y cortaría una salida en curso. El
/// `.id` va DEBAJO del `@StateObject`, con `redibujoConAcentoDelReloj()` sobre
/// el contenido de `RaizReloj`.
struct ContentView: View {
    @ObservedObject private var apariencia = AparienciaDelReloj.compartida

    var body: some View {
        RaizReloj()
            .tint(PaletaReloj.acento)
    }
}

extension View {
    /// Re-crea esta vista cuando cambia el color que mandó el teléfono, para que
    /// TODO lo que lee `PaletaReloj.acento` (y lo que deriva de él) se repinte.
    ///
    /// 🛑 Sólo debajo del `@StateObject` que guarda el entrenamiento (en
    /// `RaizReloj`, sobre `contenido`): lo que esté debajo pierde su `@State`.
    func redibujoConAcentoDelReloj() -> some View {
        modifier(RedibujoConAcentoDelReloj())
    }
}

private struct RedibujoConAcentoDelReloj: ViewModifier {
    @ObservedObject private var apariencia = AparienciaDelReloj.compartida

    func body(content: Content) -> some View {
        content
            .id(apariencia.acentoGuardado)
            .tint(PaletaReloj.acento)
    }
}
