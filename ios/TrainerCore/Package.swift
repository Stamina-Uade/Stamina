// swift-tools-version: 5.9
// =============================================================================
// ios/TrainerCore — el módulo compartido de las dos apps de Apple.
//
// 🛑 NO BORRAR. Sin este archivo, `ios/TrainerCore` deja de ser un paquete y la
// app de iOS se queda sin design system, sin modelos y sin cliente de red.
//
// Qué vive acá y por qué:
//
// - `TokensGenerados.swift` lo escribe `scripts/generar-tema.mjs` desde
//   `shared/design/tokens.json` (AGENTS.md §10.1). No se edita a mano.
// - El design system (`Tema/`) es la única capa autorizada a leer esos tokens y
//   convertirlos en componentes. Una pantalla usa componentes, nunca valores.
// - Los modelos y el cliente de red salen del contrato (`shared/api/openapi.yaml`)
//   y los comparten el teléfono y el reloj (AGENTS.md §10.2: el reloj sincroniza
//   con su propia cola, pero habla el mismo idioma).
//
// `macOS` está declarado a propósito, y no porque exista una app de Mac: permite
// `swift build` y `swift test` sin abrir Xcode ni levantar un simulador, que es
// la verificación más barata que tenemos. El destino real sigue siendo iOS 16.
// =============================================================================

import PackageDescription

let package = Package(
    name: "TrainerCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TrainerCore", type: .dynamic, targets: ["TrainerCore"]),
    ],
    targets: [
        .target(name: "TrainerCore"),
        .testTarget(
            name: "TrainerCoreTests",
            dependencies: ["TrainerCore"],
            // Respuestas de verdad del servidor, capturadas de staging con el contrato
            // 1.1.0. Los tests de decodificación leen ESTO y no un JSON escrito a mano:
            // uno escrito a mano se parece a lo que uno cree que manda el servidor.
            resources: [.copy("Fixturas")]
        ),
    ]
)
