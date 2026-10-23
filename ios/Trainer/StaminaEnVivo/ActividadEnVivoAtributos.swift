import Foundation
import TrainerCore
#if canImport(ActivityKit)
import ActivityKit
#endif

// =============================================================================
// La actividad en vivo de una salida: lo que la app le manda a la pantalla
// bloqueada y a la Dynamic Island, y cómo se escriben sus números.
//
// 🛑 Este archivo lo compilan DOS targets: la extensión `StaminaEnVivo` (dueña de
// la carpeta) y la app `Trainer`, que lo suma con una excepción de membresía del
// grupo sincronizado (`project.pbxproj`, "Exceptions for StaminaEnVivo folder in
// Trainer target"). Es la misma definición en los dos lados, sin copia: ActivityKit
// decodifica en la extensión lo que la app codificó, así que una copia que se
// desfasara rompería la actividad sin un solo error de compilación.
//
// Por qué no en TrainerCore: el paquete también lo compila el reloj (watchOS) y
// macOS, donde ActivityKit no existe; habría que llenarlo de `#if os(iOS)` para
// algo que es sólo del teléfono.
//
// 🛑 Acá no va ningún texto visible. Si un `String(localized:)` entrara en este
// archivo, el catálogo de la APP también lo levantaría (`SWIFT_EMIT_LOC_STRINGS`).
// Los textos de la actividad viven en `StaminaEnVivo/Localizable.xcstrings` y se
// piden sólo desde los archivos de la extensión.
// =============================================================================

/// Lo que cambia mientras dura la salida. Es un tipo propio, sin `@available`,
/// para que la lógica de cuándo mandar una actualización (en la app) se pueda
/// probar sin ActivityKit.
struct EstadoDeSalidaEnVivo: Codable, Hashable {
    /// Cuándo habría empezado el cronómetro si la salida nunca se hubiera pausado:
    /// la hora de inicio más todo el tiempo en pausa. Con eso la duración avanza
    /// sola en pantalla (`Text(timerInterval:)`) sin mandar una actualización por
    /// segundo.
    var inicioDelCronometro: Date
    /// Los segundos en movimiento al momento de esta actualización. Es lo que se
    /// muestra, fijo, mientras la salida está en pausa.
    var segundos: Int
    var pausada: Bool
    var metros: Int
    /// Ritmo promedio de la salida hasta ahora, en segundos por kilómetro.
    /// `nil` mientras no haya distancia suficiente para que signifique algo.
    var ritmoSegPorKm: Int?
    /// La preferencia de la persona: millas o kilómetros.
    var enMillas: Bool

    var unidades: SistemaDeUnidades { enMillas ? .imperial : .metrico }
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct AtributosDeSalidaEnVivo: ActivityAttributes {
    typealias ContentState = EstadoDeSalidaEnVivo

    /// El deporte no cambia durante la salida: va en lo fijo.
    var deporte: DeporteDeSesion
}
#endif

/// El enlace que abre la app en la pantalla de la salida al tocar la actividad.
/// El esquema está declarado en `Trainer-Info.plist` (`CFBundleURLTypes`).
enum EnlaceDeSalidaEnVivo {
    static let esquema = "stamina"
    static let anfitrion = "salida"
    static let url: URL = {
        var partes = URLComponents()
        partes.scheme = esquema
        partes.host = anfitrion
        return partes.url ?? URL(fileURLWithPath: "/")
    }()

    static func esDeLaSalida(_ url: URL) -> Bool {
        url.scheme?.lowercased() == esquema && url.host?.lowercased() == anfitrion
    }
}

/// Los números de la actividad, en las unidades que eligió la persona. Sólo
/// números y símbolos de unidad (los mismos de `Formato`): nada que traducir.
enum PresentacionDeSalidaEnVivo {

    /// "5:12" por kilómetro, u "8:22" por milla. Sin dato, un guión.
    static func ritmo(_ estado: EstadoDeSalidaEnVivo) -> String {
        Formato.ritmo(segundosPorKm: estado.ritmoSegPorKm, unidades: estado.unidades)
    }

    /// "/km" o "/mi".
    static func unidadDeRitmo(_ unidades: SistemaDeUnidades) -> String {
        "/" + Formato.unidadDeDistancia(unidades)
    }

    /// "3,45" (km) o "2,14" (mi): siempre con dos decimales, para que el número
    /// no cambie de ancho cada vez que pasa por un entero.
    static func distancia(_ estado: EstadoDeSalidaEnVivo) -> String {
        let divisor = estado.enMillas ? 1609.344 : 1000
        let valor = Double(max(0, estado.metros)) / divisor
        return valor.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
    }

    static func unidadDeDistancia(_ unidades: SistemaDeUnidades) -> String {
        Formato.unidadDeDistancia(unidades)
    }

    /// La duración fija, para la pausa: "28:40" o "1:12:34".
    static func duracionFija(_ estado: EstadoDeSalidaEnVivo) -> String {
        Formato.cronometro(segundos: max(0, estado.segundos))
    }
}
