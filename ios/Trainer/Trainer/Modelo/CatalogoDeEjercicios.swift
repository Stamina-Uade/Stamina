import Foundation
import SwiftUI
import TrainerCore

// =============================================================================
// El catálogo de ejercicios.
//
// 🛑 Es DATO, no código (AGENTS.md §9.1): un ejercicio nuevo entra sin
// desplegar. La app consulta `/exercises` y `/exercises/dictionary`: el catálogo
// que ve la persona siempre es el que trae el servidor.
//
// Ninguna pantalla enumera el catálogo: `ESPECIFICACION.md` §6.4 lo pide
// explícito —"50 o 500 entradas se ven igual"—, así que todo es búsqueda y
// filtro, nunca una lista completa con su cantidad a la vista.
// =============================================================================

struct EjercicioDelCatalogo: Identifiable, Decodable {
    let id: String
    let nombre: [String: String?]
    let patron: String
    let equipamiento: String
    let lado: String
    let unidad: String
    let musculos: [MusculoDelEjercicio]
    let sustitutos: [SustitutoDelEjercicio]

    struct MusculoDelEjercicio: Decodable, Hashable {
        let id: String
        let rol: String
        var esPrincipal: Bool { rol == "principal" }
    }

    struct SustitutoDelEjercicio: Decodable, Hashable {
        let id: String
        let tipo: String
    }

    /// El nombre en el idioma de la persona, con el castellano de respaldo.
    ///
    /// El catálogo trae `null` en pt-BR y ja-JP a propósito: `ESPECIFICACION.md`
    /// §6.5 avisa que esas traducciones no las revisó un hablante nativo. Un
    /// `null` cae al castellano en vez de mostrar un hueco.
    func nombre(para idioma: String) -> String {
        if let propio = nombre[idioma] ?? nil, !propio.isEmpty { return propio }
        if let base = nombre["es-AR"] ?? nil { return base }
        return id
    }
}

struct DiccionariosDelCatalogo: Decodable {
    let musculos: [String: [String: String?]]
    let equipamiento: [String: [String: String?]]
    let patrones: [String: [String: String?]]

    func nombre(_ diccionario: [String: [String: String?]], _ clave: String, idioma: String) -> String {
        guard let entrada = diccionario[clave] else { return clave }
        if let propio = entrada[idioma] ?? nil, !propio.isEmpty { return propio }
        if let base = entrada["es-AR"] ?? nil { return base }
        return clave
    }
}

/// Trae todas las páginas del catálogo del servidor y responde búsquedas y filtros.
@MainActor
final class CatalogoDeEjercicios: ObservableObject {
    static let compartido = CatalogoDeEjercicios()

    @Published private(set) var ejercicios: [EjercicioDelCatalogo] = []
    @Published private(set) var diccionarios = DiccionariosDelCatalogo(musculos: [:], equipamiento: [:], patrones: [:])
    @Published private(set) var falloDeRed = false
    private var cargado = false
    @Published private(set) var cargando = false

    /// El idioma con el que se muestran los nombres. Sale del sistema.
    let idioma: String

    private init() {
        let preferido = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        self.idioma = ["es-AR", "en-US", "pt-BR", "ja-JP"].contains(preferido)
            ? preferido
            : (Locale.current.language.languageCode?.identifier == "en" ? "en-US" : "es-AR")

    }

    func cargar(desde servicio: (any ServicioDelPlan)?) async {
        guard !cargado, !cargando, let servicio else { return }
        cargando = true
        defer { cargando = false }
        var obtenidos: [EjercicioCatalogado] = []
        var cursor: String?
        repeat {
            guard case .ok(let pagina) = await servicio.ejercicios(limite: 100, cursor: cursor) else {
                falloDeRed = true
                return
            }
            obtenidos.append(contentsOf: pagina.elementos)
            cursor = pagina.paginacion.hasMore ? pagina.paginacion.nextCursor : nil
        } while cursor != nil

        guard case .ok(let diccionario) = await servicio.diccionarioDeEjercicios() else {
            falloDeRed = true
            return
        }
        ejercicios = obtenidos.map { e in
            EjercicioDelCatalogo(id: e.id, nombre: [idioma: e.name],
                                 patron: e.pattern, equipamiento: e.equipment, lado: e.side,
                                 unidad: e.unit,
                                 musculos: e.muscles.map { .init(id: $0.id, rol: $0.role.rawValue) },
                                 sustitutos: e.substitutes.map {
                                     .init(id: $0.id, tipo: $0.kind == .mismoPatron ? "mismo-patron" : "mismo-musculo")
                                 })
        }
        func mapa(_ entradas: [EntradaDeDiccionario]) -> [String: [String: String?]] {
            Dictionary(uniqueKeysWithValues: entradas.map { ($0.id, [idioma: $0.name]) })
        }
        diccionarios = DiccionariosDelCatalogo(musculos: mapa(diccionario.muscles),
                                                equipamiento: mapa(diccionario.equipment),
                                                patrones: mapa(diccionario.patterns))
        falloDeRed = false
        cargado = true
    }

    func nombre(de ejercicio: EjercicioDelCatalogo) -> String { ejercicio.nombre(para: idioma) }

    func musculo(_ clave: String) -> String {
        diccionarios.nombre(diccionarios.musculos, clave, idioma: idioma)
    }

    func equipamiento(_ clave: String) -> String {
        diccionarios.nombre(diccionarios.equipamiento, clave, idioma: idioma)
    }

    func patron(_ clave: String) -> String {
        diccionarios.nombre(diccionarios.patrones, clave, idioma: idioma)
    }

    func ejercicio(_ id: String) -> EjercicioDelCatalogo? {
        ejercicios.first { $0.id == id }
    }

    /// Busca por nombre **y por músculo**, que es como lo pide el diseño: quien
    /// busca "espalda" no se sabe el nombre del ejercicio.
    func buscar(_ texto: String, musculos: Set<String>, equipamiento equipos: Set<String>,
                sinEquipo: Bool) -> [EjercicioDelCatalogo] {
        let consulta = texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)

        return ejercicios.filter { ejercicio in
            if sinEquipo, ejercicio.equipamiento != "ninguno" { return false }
            if !equipos.isEmpty, !equipos.contains(ejercicio.equipamiento) { return false }
            if !musculos.isEmpty, !ejercicio.musculos.contains(where: { musculos.contains($0.id) }) { return false }
            guard !consulta.isEmpty else { return true }

            let nombreNormalizado = nombre(de: ejercicio)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            if nombreNormalizado.contains(consulta) { return true }

            return ejercicio.musculos.contains { musculo in
                self.musculo(musculo.id)
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                    .contains(consulta)
            }
        }
    }

    /// Los músculos que existen, para la hoja de filtros.
    var musculosDisponibles: [String] {
        Array(Set(ejercicios.flatMap { $0.musculos.map(\.id) })).sorted { musculo($0) < musculo($1) }
    }

    var equipamientosDisponibles: [String] {
        Array(Set(ejercicios.map(\.equipamiento))).sorted { equipamiento($0) < equipamiento($1) }
    }
}
