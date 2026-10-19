import Foundation

// =============================================================================
// El MVP es 100% running. Bici, natación y triatlón NO se borraron: quedan
// escondidos detrás de este único interruptor. Para volver a mostrarlos,
// `soloRunning = false` y listo (teléfono y reloj leen lo mismo).
//
// Los datos que ya existan de otros deportes se siguen viendo (historial,
// resumen): lo que se esconde es la posibilidad de elegirlos.
// =============================================================================

public enum MVP {
    /// El interruptor. `true` = sólo carrera (trail incluido: es running).
    public static let soloRunning = true

    /// Deportes que se pueden elegir al grabar una sesión (teléfono y reloj).
    public static let deportes: [DeporteDeSesion] = soloRunning ? [.running] : DeporteDeSesion.allCases

    /// Deportes que se pueden elegir en el perfil (paso `reg-deporte`).
    public static let deportesDePerfil: [Deporte] = soloRunning ? [.running] : Deporte.allCases

    /// Objetivos que se pueden elegir (alta y selector de metas del Plan).
    public static let objetivos: [Objetivo] = soloRunning
        ? Objetivo.allCases.filter { $0 != .triatlonOlimpico }
        : Objetivo.allCases

    /// ¿Se puede elegir este deporte de sesión?
    public static func permite(_ deporte: DeporteDeSesion) -> Bool {
        deportes.contains(deporte)
    }

    /// ¿Se puede elegir este objetivo?
    public static func permite(_ objetivo: Objetivo) -> Bool {
        objetivos.contains(objetivo)
    }

    /// El deporte a usar cuando se sugiere/infiere uno: si el MVP no lo
    /// permite, cae a running.
    public static func acotado(_ deporte: DeporteDeSesion) -> DeporteDeSesion {
        permite(deporte) ? deporte : .running
    }
}
