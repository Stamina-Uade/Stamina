import SwiftUI
import TrainerCore
import UIKit

/// Un texto con el botón del rayo de la barra —el círculo rosa con el rayo—
/// dibujado en chiquito, adentro del renglón, donde la plantilla dice `%@`.
///
/// 2026-10-22 (Iván): reemplaza al emoji ⚡ del tour y del historial vacío. Un
/// `Text` sólo acepta imágenes adentro, así que el botón se dibuja una vez como
/// imagen (`ImageRenderer`) del alto de la letra. VoiceOver lee la frase con
/// "botón de entreno" en ese lugar.
enum TextoConRayo {
    /// - Parameters:
    ///   - plantilla: el texto del catálogo, con un `%@` donde va el botón.
    ///   - alto: el alto del círculo, en puntos; el de la letra del renglón.
    @MainActor
    static func texto(_ plantilla: (String) -> String, alto: CGFloat) -> Text {
        let marca = "\u{FFFC}"
        let partes = plantilla(marca).components(separatedBy: marca)
        var texto = Text(verbatim: partes.first ?? "")
        for parte in partes.dropFirst() {
            texto = texto
                + Text(imagen(alto: alto)).baselineOffset(-alto * 0.22)
                + Text(verbatim: parte)
        }
        return texto
    }

    /// Lo que lee VoiceOver en lugar de la imagen.
    static func etiqueta(_ plantilla: (String) -> String) -> String {
        plantilla(Textos.commonWorkoutButton)
    }

    @MainActor
    private static func imagen(alto: CGFloat) -> Image {
        let boton = ZStack {
            Circle().fill(Paleta.acento)
            Image(systemName: "bolt.fill")
                .font(.system(size: alto * 0.55, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(width: alto, height: alto)
        let dibujante = ImageRenderer(content: boton)
        dibujante.scale = 3
        guard let dibujo = dibujante.uiImage else { return Image(systemName: "bolt.circle.fill") }
        return Image(uiImage: dibujo)
    }
}
