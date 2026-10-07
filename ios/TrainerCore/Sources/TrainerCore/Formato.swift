import Foundation


// =============================================================================
// Cómo se muestran los números.
//
// AGENTS.md §10: "Fechas, números y unidades se formatean con el locale del
// sistema, nunca fijos." El diseño escribe "9,8 km" y "1.240 kcal" porque está
// pensado en es-AR; en en-US eso es "9.8 km" y "1,240 kcal". Nada de eso se
// escribe a mano.
//
// Y §5: la API habla en unidad base —metros, gramos, kcal enteras, minutos desde
// medianoche—. La conversión a lo que se ve es de acá y de ningún otro lado.
// =============================================================================

/// Métrico o imperial. Es preferencia de PRESENTACIÓN: lo que se guarda y lo que
/// viaja por la API sigue siendo la unidad base (AGENTS.md §10 y §5).
public enum SistemaDeUnidades: String, CaseIterable, Identifiable {
    case metrico, imperial
    public var id: String { rawValue }
}

public enum Formato {

    // MARK: - Números

    private static func numero(_ valor: Double, decimales: Int) -> String {
        valor.formatted(.number.precision(.fractionLength(decimales)).grouping(.automatic))
    }

    /// Pasos con separador de miles: "8.432".
    public static func pasos(_ cantidad: Int) -> String {
        cantidad.formatted(.number.grouping(.automatic))
    }

    /// Kilómetros con un decimal: "9,8". Sin la unidad, que la pone quien llama.
    public static func kilometros(_ metros: Int, decimales: Int = 1) -> String {
        numero(Double(metros) / 1000, decimales: decimales)
    }

    /// "14 km" — la distancia con su unidad, en el sistema que la persona eligió.
    public static func distancia(_ metros: Int, unidades: SistemaDeUnidades, decimales: Int = 1) -> String {
        "\(distanciaNumero(metros, unidades: unidades, decimales: decimales)) \(unidadDeDistancia(unidades))"
    }

    public static func distanciaNumero(_ metros: Int, unidades: SistemaDeUnidades,
                                       decimales: Int = 1) -> String {
        let valor = unidades == .metrico ? Double(metros) / 1000 : Double(metros) / 1609.344
        return numero(valor, decimales: valor == valor.rounded() ? 0 : decimales)
    }

    public static func unidadDeDistancia(_ unidades: SistemaDeUnidades) -> String {
        unidades == .metrico ? "km" : "mi"
    }

    /// Velocidad con un decimal (o sin decimal si es exacto): "25,4". Sin la unidad.
    public static func velocidadNumero(metros: Int, segundos: Int, unidades: SistemaDeUnidades,
                                       decimales: Int = 1) -> String {
        guard segundos > 0, metros > 5 else { return "0,0" }
        let horas = Double(segundos) / 3600.0
        let distancia = unidades == .metrico ? Double(metros) / 1000.0 : Double(metros) / 1609.344
        let vel = distancia / horas
        return numero(vel, decimales: decimales)
    }

    /// "km/h" o "mph" según el sistema de unidades elegido.
    public static func unidadDeVelocidad(_ unidades: SistemaDeUnidades) -> String {
        unidades == .metrico ? "km/h" : "mph"
    }

    /// "25,4 km/h" o "15,8 mph" con su unidad formateada.
    public static func velocidad(metros: Int, segundos: Int, unidades: SistemaDeUnidades,
                                 decimales: Int = 1) -> String {
        "\(velocidadNumero(metros: metros, segundos: segundos, unidades: unidades, decimales: decimales)) \(unidadDeVelocidad(unidades))"
    }

    /// Formatea el desnivel acumulado en metros o pies.
    public static func desnivel(metros: Int, unidades: SistemaDeUnidades) -> String {
        switch unidades {
        case .metrico:
            return "\(metros) m"
        case .imperial:
            let pies = Int((Double(metros) * 3.28084).rounded())
            return "\(pies) ft"
        }
    }

    public static func kcal(_ valor: Int) -> String {
        valor.formatted(.number.grouping(.automatic))
    }

    public static func gramos(_ valor: Int) -> String {
        "\(valor.formatted(.number.grouping(.automatic))) g"
    }

    /// Litros con un decimal, para "0,9 L con sales".
    public static func litros(_ mililitros: Int) -> String {
        "\(numero(Double(mililitros) / 1000, decimales: 1)) L"
    }

    /// Peso corporal o de una mancuerna, desde gramos.
    public static func peso(_ gramos: Int, unidades: SistemaDeUnidades) -> String {
        switch unidades {
        case .metrico:
            let kg = Double(gramos) / 1000
            return "\(numero(kg, decimales: kg == kg.rounded() ? 0 : 1)) kg"
        case .imperial:
            let lb = Double(gramos) / 453.59237
            return "\(numero(lb, decimales: 0)) lb"
        }
    }

    // MARK: - Tiempo

    /// Minutos desde medianoche → la hora, en el formato del locale (12 o 24 h).
    public static func hora(minutoDelDia: Int) -> String {
        var componentes = DateComponents()
        componentes.hour = (minutoDelDia / 60) % 24
        componentes.minute = minutoDelDia % 60
        let fecha = Calendar.current.date(from: componentes) ?? Date()
        return fecha.formatted(.dateTime.hour().minute())
    }

    /// "1:12:34" o "28:40" — el cronómetro de la sesión.
    public static func cronometro(segundos: Int) -> String {
        let h = segundos / 3600, m = (segundos % 3600) / 60, s = segundos % 60
        let dosDigitos = { (n: Int) in String(format: "%02d", n) }
        return h > 0 ? "\(h):\(dosDigitos(m)):\(dosDigitos(s))" : "\(m):\(dosDigitos(s))"
    }

    /// Cronómetro del reloj: conserva horas, minutos y segundos para que la
    /// jerarquía no cambie mientras corre la sesión.
    public static func cronometroCompleto(segundos: Int) -> String {
        let h = max(0, segundos) / 3600
        let m = (max(0, segundos) % 3600) / 60
        let s = max(0, segundos) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// "5:12" — el ritmo. Nunca inventa: sin dato, muestra un guión.
    public static func ritmo(segundosPorKm: Int?) -> String {
        guard let s = segundosPorKm else { return "—" }
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    public static func ritmo(segundosPorKm: Int?, unidades: SistemaDeUnidades) -> String {
        guard let segundosPorKm else { return "—" }
        let segundos = unidades == .metrico
            ? segundosPorKm
            : Int((Double(segundosPorKm) * 1.609344).rounded())
        return "\(segundos / 60):\(String(format: "%02d", segundos % 60))"
    }

    /// "2 h 15 min" — una duración larga, para la cuenta regresiva.
    public static func duracionLarga(minutos: Int) -> String {
        let h = minutos / 60, m = minutos % 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m)) min" : "\(m) min"
    }

    /// Una cantidad de ingrediente, escalada por la porción. Lo contable se
    /// redondea a medios; lo que se pesa, a enteros.
    public static func cantidad(_ base: Double, porcion: Double, contable: Bool) -> String {
        let valor = base * porcion
        if contable {
            let redondeado = max(0.5, (valor * 2).rounded() / 2)
            return numero(redondeado, decimales: redondeado == redondeado.rounded() ? 0 : 1)
        }
        return numero(valor.rounded(), decimales: 0)
    }

    // MARK: - Eventos

    /// Limpia el título de un evento importante o día de carrera eliminando signos de exclamación,
    /// puntos suspensivos ("..." o "…"), textos agregados ("día del evento", "event day", etc.),
    /// sufijos o prefijos redundantes ("Tu objetivo: ", "(21K)", etc.).
    /// Para triatlón con distancias de medio o fondo, devuelve nombres genéricos protegidos
    /// de infracción de marca ("Triatlón media distancia", "Triatlón larga distancia").
    public static func limpiarTituloEvento(_ titulo: String, enTriatlon: Bool = false) -> String {
        var texto = titulo

        // 1. Quitar signos de exclamación
        texto = texto.replacingOccurrences(of: "¡", with: "")
        texto = texto.replacingOccurrences(of: "!", with: "")

        // 2. Quitar puntos suspensivos agregados ("..." o "…")
        texto = texto.replacingOccurrences(of: "...", with: "")
        texto = texto.replacingOccurrences(of: "…", with: "")

        // 3. Quitar menciones de "día del evento" / "event day" / "día de la carrera" / "race day"
        texto = texto.replacingOccurrences(of: #"(?i)[\s:·-]*d[ií]a del evento[\s:·-]*"#, with: "", options: .regularExpression)
        texto = texto.replacingOccurrences(of: #"(?i)[\s:·-]*event day[\s:·-]*"#, with: "", options: .regularExpression)
        texto = texto.replacingOccurrences(of: #"(?i)[\s:·-]*d[ií]a de la carrera[\s:·-]*"#, with: "", options: .regularExpression)
        texto = texto.replacingOccurrences(of: #"(?i)[\s:·-]*race day[\s:·-]*"#, with: "", options: .regularExpression)

        // 4. Quitar prefijos de motivación u objetivo redundantes: "Tu objetivo: ", "Objetivo: ", "Goal: ", "Your goal: "
        texto = texto.replacingOccurrences(of: #"(?i)^(tu\s+objetivo|objetivo|your\s+goal|goal)\s*[:·-]*\s*"#, with: "", options: .regularExpression)

        // 5. Quitar paréntesis con distancias, minutos o comentarios: "(21K)", "(42K)", "(168 min)", etc.
        texto = texto.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)

        // 6. Quitar sufijos de distancia o tipo comunes separados por guión, punto o dos puntos: " · 21K", " - 21K", " · 42K", etc.
        texto = texto.replacingOccurrences(of: #"(?i)[\s:·-]+(21k|42k|5k|10k)\b"#, with: "", options: .regularExpression)

        // 7. Quitar dos puntos, puntos, guiones y comas sueltos al inicio o al final
        texto = texto.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r:;·-.,¡!…"))

        let lower = texto.lowercased()

        // 8. Triatlón
        if enTriatlon || lower.contains("triatl") || lower.contains("ironman") {
            if lower.contains("media") || lower.contains("medio") || lower.contains("half") || lower.contains("21k") || lower.contains("70.3") {
                return lower.contains("half") ? "Middle distance triathlon" : "Triatlón media distancia"
            }
            if lower.contains("larga") || lower.contains("long") || lower.contains("maratón") || lower.contains("maraton") || lower.contains("marathon") || lower.contains("42k") || lower.contains("140.6") {
                return lower.contains("long") || lower.contains("marathon") ? "Long distance triathlon" : "Triatlón larga distancia"
            }
            if lower.contains("olímpico") || lower.contains("olimpico") || lower.contains("olympic") {
                return lower.contains("olympic") ? "Olympic triathlon" : "Triatlón olímpico"
            }
            if lower.contains("sprint") {
                return "Triatlón sprint"
            }
            return lower.contains("triathlon") ? "Triathlon" : "Triatlón"
        }

        // 9. Disciplinas individuales limpias si coinciden con patrones de eventos conocidos
        if lower.contains("media maratón") || lower.contains("media maraton") || lower.contains("half marathon") {
            return lower.contains("half marathon") ? "Half marathon" : "Media maratón"
        }
        if lower.contains("maratón") || lower.contains("maraton") || lower.contains("marathon") {
            return lower.contains("marathon") ? "Marathon" : "Maratón"
        }
        if lower == "5k" || lower.hasPrefix("5k") {
            return "5K"
        }
        if lower == "10k" || lower.hasPrefix("10k") {
            return "10K"
        }

        return texto.isEmpty ? titulo : texto
    }
}
