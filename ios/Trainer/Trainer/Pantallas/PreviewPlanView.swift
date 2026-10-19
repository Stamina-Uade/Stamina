import SwiftUI
import TrainerCore

/// `preview-plan` — qué va a ver la persona cuando el plan exista.
///
/// 🪤 Lo que muestra esta pantalla es **ejemplo, no un cálculo**. El plan lo
/// calcula el servidor (AGENTS.md §10) y el motor es de la fase 7. Que se lea
/// como ejemplo y no como "tu plan" importa: prometer un número de hidratación
/// que todavía no existe es exactamente lo que §9.2 no quiere.
struct PreviewPlanView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e11) {
                            Text(Textos.previewEtiqueta).estilo(.etiquetaSeccion, color: Paleta.acento)
                            Text(Textos.previewSesion).estilo(.tituloCardGrande)
                            HStack(spacing: TokensEspaciado.e6) {
                                PildoraDeEstado(Textos.previewChipLiquido, simbolo: "drop.fill")
                                PildoraDeEstado(Textos.previewChipGel, simbolo: "bolt.fill", tono: .acento)
                                PildoraDeEstado(Textos.previewChipSodio)
                            }
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                            Text(Textos.previewAntesEtiqueta)
                                .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                            Text(Textos.previewAntesTexto)
                                .estilo(.cuerpo, color: Paleta.textoCuerpo)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, TokensEspaciado.e22)
                .padding(.top, TokensEspaciado.e26)
            }

            VStack(spacing: TokensEspaciado.e16) {
                Text(Textos.previewCtaTitulo)
                    .estilo(.display)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                BotonPrimario(Textos.previewEmpezar) { flujo.ir(a: .regCorreo) }

                HStack(spacing: TokensEspaciado.e4) {
                    Text(Textos.previewYaTenesCuenta)
                        .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                    Button { flujo.ir(a: .login) } label: {
                        Text(Textos.previewIniciarSesion)
                            .estilo(.cuerpoSecundario, color: Paleta.acento)
                            .objetivoTactilAlto()
                    }
                }
            }
            .padding(.horizontal, TokensEspaciado.e22)
            .padding(.bottom, TokensEspaciado.e34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }
}
