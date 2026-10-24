import SwiftUI
import TrainerCore

// =============================================================================
// La fila del perfil: ícono, qué es, su resumen y la flecha (2026-10-23: las
// tarjetas y los chips de antes pasaron a ser cuatro filas así).
// =============================================================================

/// Una fila que lleva a otro lado: ícono, qué es, qué vas a encontrar y la flecha.
struct FilaDeAccesoDePerfil: View {
    let simbolo: String
    let titulo: String
    let subtitulo: String
    var colorDelSubtitulo: Color = Paleta.textoSecundario
    /// Algo para mirar (el apto que falta o está por vencer): un punto rojo.
    var conAviso: Bool = false
    let accion: () -> Void

    var body: some View {
        Button {
            Haptico.toque()
            accion()
        } label: {
            HStack(spacing: TokensEspaciado.e12) {
                ZStack {
                    Circle().fill(Paleta.acentoChipActivo)
                    Image(systemName: simbolo)
                        .font(.system(size: TokensTipografia.valorDatoTamano, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                }
                .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                    Text(titulo)
                        .estilo(.opcionTitulo)
                    Text(subtitulo)
                        .estilo(.notaLegal, color: colorDelSubtitulo)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if conAviso {
                    Circle()
                        .fill(Paleta.peligro)
                        .frame(width: TokensEspaciado.e8, height: TokensEspaciado.e8)
                        .accessibilityHidden(true)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                    .foregroundStyle(Paleta.textoTerciario)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .padding(.vertical, TokensEspaciado.e12)
            .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
