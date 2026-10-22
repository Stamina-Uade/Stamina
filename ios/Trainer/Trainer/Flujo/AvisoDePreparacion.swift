import Foundation

// =============================================================================
// "Notificación para prepararte": el aviso antes de cada sesión.
//
// 2026-10-22 (Iván): reemplaza al aviso fijo de "30 minutos antes" (y al "45
// minutos" que decían los textos del alta). Se elige en el alta —"Días y
// horarios"— y en Ajustes › Notificaciones, y las dos pantallas escriben en el
// MISMO lugar: las preferencias del teléfono, donde viven los otros avisos. El
// servidor no programa ningún aviso, así que no hay nada que guardar en el perfil.
// =============================================================================

enum AvisoDePreparacion {
    /// Si el aviso está prendido. Es la clave que ya usaba "30 min antes".
    static let claveEncendido = "ajuste_notif_recordatorio_antes"
    /// Cuántos minutos antes de la sesión.
    static let claveMinutos = "ajuste_notif_recordatorio_minutos"

    static let minutosPorDefecto = 30
    static let rango = 5...60
    static let paso = 5

    /// Lo guardado, dentro del rango y en pasos de 5.
    static func minutos(en preferencias: UserDefaults = .standard) -> Int {
        let guardado = preferencias.object(forKey: claveMinutos) as? Int ?? minutosPorDefecto
        return ajustado(guardado)
    }

    static func encendido(en preferencias: UserDefaults = .standard) -> Bool {
        preferencias.object(forKey: claveEncendido) as? Bool ?? true
    }

    static func ajustado(_ minutos: Int) -> Int {
        let redondeado = (minutos + paso / 2) / paso * paso
        return min(max(redondeado, rango.lowerBound), rango.upperBound)
    }

    /// "30 min", "1 h": abreviado y en el idioma del teléfono.
    static func texto(_ minutos: Int) -> String {
        let formato = DateComponentsFormatter()
        formato.unitsStyle = .abbreviated
        formato.allowedUnits = minutos >= 60 ? [.hour, .minute] : [.minute]
        return formato.string(from: TimeInterval(minutos * 60)) ?? "\(minutos)"
    }
}
