import SwiftUI
import TrainerCore

// =============================================================================
// La actualización obligatoria (AGENTS.md §5.1), y el texto de los dos avisos de
// versión.
//
// Esta pantalla no está en el diseño. Se arma con `PantallaCierre` —el andamio de
// `clave-lista` y `reg-listo`— para no inventar una estética: es un final, y el
// design system ya sabe dibujar finales.
// =============================================================================

struct ActualizacionRequeridaView: View {
    let aviso: AvisoDeVersion
    @Environment(\.openURL) private var abrirEnlace

    var body: some View {
        PantallaCierre(titulo: Textos.versionRequiredTitle,
                       texto: aviso.texto(generico: Textos.versionRequiredBody),
                       pie: {
                           // Sin enlace a la tienda no hay botón: uno que no hace nada
                           // es peor que el texto, que ya dice dónde actualizar.
                           if let tienda = aviso.tienda {
                               BotonPrimario(Textos.versionUpdate) { abrirEnlace(tienda) }
                           }
                       })
            // Opaca hasta el borde: lo de abajo no se tiene que ver ni tocar.
            .background(Paleta.fondo.ignoresSafeArea())
            .accessibilityAddTraits(.isModal)
    }
}

extension AvisoDeVersion {
    /// El texto de un aviso de versión.
    ///
    /// docs/API.md §4: el cliente prefiere su traducción del `code`, y el
    /// `message` del servidor es el respaldo para un `code` que esta versión no
    /// conoce. Hoy la app no conoce ninguno —el contrato no fija la lista, sólo da
    /// un ejemplo—, así que va el `message` si vino y, si no, el texto propio.
    ///
    /// A diferencia del `message` de un error, éste SÍ se muestra: el servidor lo
    /// escribe para la persona, ya traducido según el `Accept-Language`.
    func texto(generico: String) -> String {
        let delServidor = mensaje?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return delServidor.isEmpty ? generico : delServidor
    }
}
