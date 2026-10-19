import SwiftUI
import TrainerCore

/// Lo que se ve en lugar de una parte del Home que no tiene nada que mostrar.
///
/// 🛑 Honesto a propósito: sin nada guardado y sin red, dice eso. Poner los datos
/// de ejemplo en su lugar sería mostrarle a alguien un plan que no es el suyo.
struct SinDatosView: View {
    let problema: ProblemaDeCarga?
    let actualizando: Bool
    let reintentar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            if actualizando {
                HStack(spacing: TokensEspaciado.e8) {
                    ProgressView()
                        .tint(Paleta.acento)
                    Text(Textos.homeDataLoading)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                }
            } else {
                HStack(alignment: .top, spacing: TokensEspaciado.e10) {
                    Image(systemName: simbolo)
                        .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                        .foregroundStyle(Paleta.textoTerciario)
                        .frame(width: TokensEspaciado.e34, height: TokensEspaciado.e34)
                        .background(Paleta.superficieHundida)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                    Text(texto)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Reintentar no completa un perfil: para eso está el aviso de arriba.
                if problema != .perfilIncompleto {
                    BotonTexto(Textos.homeDataRetry, accion: reintentar)
                }
            }
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    /// El ícono acompaña al texto, nunca lo reemplaza.
    private var simbolo: String {
        switch problema {
        case .sinRed: return "wifi.slash"
        case .perfilIncompleto: return "person.crop.circle.badge.exclamationmark"
        case .servidor: return "exclamationmark.icloud"
        case nil: return "tray"
        }
    }

    private var texto: String {
        switch problema {
        case .sinRed: return Textos.homeDataOffline
        case .perfilIncompleto: return Textos.homeDataProfileIncomplete
        case .servidor: return Textos.homeDataError
        case nil: return Textos.homeDataEmpty
        }
    }
}

/// El aviso de que lo que se ve es lo guardado, y no se pudo confirmar que siga
/// siendo lo último. Sin eso, un plan viejo se leería como el de hoy.
struct AvisoDeLoGuardado<Valor>: View {
    let seccion: Seccion<Valor>

    var body: some View {
        if seccion.desactualizada, let guardadoEnMs = seccion.guardadoEnMs {
            AvisoSuave(texto(guardadoEnMs))
        }
    }

    private func texto(_ guardadoEnMs: Int64) -> String {
        let formato = RelativeDateTimeFormatter()
        // En el idioma en el que la app muestra sus textos, no en el del teléfono:
        // si no, "hace 2 horas" saldría en otro idioma que el resto de la frase.
        formato.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        let cuando = formato.localizedString(for: Date(timeIntervalSince1970: TimeInterval(guardadoEnMs) / 1000),
                                             relativeTo: Date())
        return seccion.problema == .sinRed
            ? Textos.homeDataSavedOffline(cuando)
            : Textos.homeDataSavedWithError(cuando)
    }
}
