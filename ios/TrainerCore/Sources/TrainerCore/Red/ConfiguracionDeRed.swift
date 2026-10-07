import Foundation

// =============================================================================
// A qué servidor habla la app.
//
// Release habla SIEMPRE con producción. En DEBUG también por defecto —así la
// versión que se prueba en el teléfono es la que se publica—, pero se puede
// apuntar a otro servidor con un argumento de lanzamiento:
//
//   xcrun simctl launch <udid> com.tecladus.Trainer -apiBase http://localhost:8082/v1
//
// o en Xcode: Product › Scheme › Edit Scheme › Run › Arguments.
//
// 🛑 SÓLO EN DEBUG, igual que `ArranqueDePrueba.swift`. En release el bloque no
// existe: una app publicada no tiene forma de hablarle a otro servidor, porque
// eso sería la puerta para que alguien le haga creer que su servidor es el
// nuestro. Los argumentos de lanzamiento los pone Xcode o `simctl`, nunca quien
// usa la app.
//
// `http://` al backend local NO choca con App Transport Security, y por eso no hace
// falta una excepción en el `Info.plist` (que tocaría el `.pbxproj`). Verificado el
// 2026-09-10 en el simulador de iOS 18.1 con `127.0.0.1` y con `localhost`: el
// pedido falla con "no se pudo conectar" (-1004) y no con el -1022 de ATS. Lo
// sostiene `PlataformaTests.atsDejaElBackendLocal`, en TrainerTests. Un host que no
// sea local por http no se probó.
// =============================================================================

public enum ConfiguracionDeRed {

    /// Producción. Con el prefijo de versión del contrato: el backend registra
    /// TODAS sus rutas bajo `/v1`, y sin él cada llamada se lleva un 404 bien
    /// formado, que es la peor manera de fallar porque parece que el servidor dijo
    /// que no (docs/CORRER-LOCAL.md).
    public static let baseDeProduccion = URL(string: "https://stamina.com.ar/v1")!

    /// El argumento de lanzamiento que la sobreescribe, sólo en DEBUG.
    public static let argumento = "-apiBase"

    /// La base que usa la app.
    public static func base(argumentos: [String] = ProcessInfo.processInfo.arguments) -> URL {
        #if DEBUG
        return baseSobreescrita(en: argumentos) ?? baseDeProduccion
        #else
        return baseDeProduccion
        #endif
    }

    /// Lo que viene después de `-apiBase`, si es una URL http(s) con host.
    ///
    /// Lo que no se entiende se ignora y se usa producción: un typo en el esquema
    /// de Xcode no puede dejar la app hablándole a la nada sin avisar. Está afuera
    /// del `#if` para poder probarlo, pero en release no lo llama nadie.
    static func baseSobreescrita(en argumentos: [String]) -> URL? {
        guard let indice = argumentos.firstIndex(of: argumento),
              argumentos.indices.contains(indice + 1) else { return nil }

        var texto = argumentos[indice + 1].trimmingCharacters(in: .whitespaces)
        while texto.hasSuffix("/") { texto.removeLast() }

        guard let url = URL(string: texto),
              let esquema = url.scheme?.lowercased(), esquema == "http" || esquema == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
