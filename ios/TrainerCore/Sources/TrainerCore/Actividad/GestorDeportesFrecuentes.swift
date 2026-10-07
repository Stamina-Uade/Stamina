import Foundation

/// Administra el orden de los deportes de forma adaptativa e individual por usuario.
///
/// Orden predeterminado para usuarios nuevos:
/// 1. Carrera (.running)
/// 2. Bicicleta (.ciclismo)
/// 3. Natación (.natacion)
/// 4. Caminata (.trekking)
/// 5. Triatlón (.triatlon)
///
/// A medida que el usuario selecciona deportes, se incrementa su frecuencia de uso
/// y la lista se reordena progresivamente priorizando las actividades más utilizadas.
public final class GestorDeportesFrecuentes: @unchecked Sendable {
    public static let shared = GestorDeportesFrecuentes()
    public static let compartido = shared

    public static let ordenInicial: [DeporteDeSesion] = [
        .running,
        .ciclismo,
        .natacion,
        .trekking,
        .triatlon
    ]

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func claveParaUsuario(_ userId: String) -> String {
        let limpio = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let claveId = limpio.isEmpty ? "default" : limpio
        return "frecuencia_deportes_\(claveId)"
    }

    /// Registra la selección o realización de un entrenamiento en un deporte específico.
    public func registrarUso(deporte: DeporteDeSesion, userId: String = "default") {
        let clave = claveParaUsuario(userId)
        var frecuencias = defaults.dictionary(forKey: clave) as? [String: Int] ?? [:]
        frecuencias[deporte.rawValue, default: 0] += 1
        defaults.set(frecuencias, forKey: clave)
    }

    /// Devuelve la lista ordenada de deportes adaptada a la frecuencia del usuario.
    public func deportesOrdenados(userId: String = "default") -> [DeporteDeSesion] {
        let clave = claveParaUsuario(userId)
        guard let frecuencias = defaults.dictionary(forKey: clave) as? [String: Int], !frecuencias.isEmpty else {
            return Self.ordenInicial
        }

        return Self.ordenInicial.sorted { a, b in
            let countA = frecuencias[a.rawValue] ?? 0
            let countB = frecuencias[b.rawValue] ?? 0
            if countA != countB {
                return countA > countB
            }
            let idxA = Self.ordenInicial.firstIndex(of: a) ?? 999
            let idxB = Self.ordenInicial.firstIndex(of: b) ?? 999
            return idxA < idxB
        }
    }

    public func registrarSeleccion(deporte: DeporteDeSesion, usuarioId: String = "default") {
        registrarUso(deporte: deporte, userId: usuarioId)
    }

    public func deportesOrdenados(usuarioId: String) -> [DeporteDeSesion] {
        deportesOrdenados(userId: usuarioId)
    }
}
