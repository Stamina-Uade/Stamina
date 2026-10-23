import SwiftUI
import WidgetKit

// =============================================================================
// La extensión de widgets de Stamina. Hoy tiene una sola cosa: la actividad en
// vivo de la salida (`SalidaEnVivoWidget`). No hay widgets de la pantalla de
// inicio; si algún día los hay, se suman acá.
// =============================================================================

@main
struct StaminaEnVivoBundle: WidgetBundle {
    var body: some Widget {
        SalidaEnVivoWidget()
    }
}
