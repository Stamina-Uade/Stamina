import SwiftUI
import TrainerCore

// MARK: - Fila de Bloque

struct FilaDeBloque: View {
    let bloque: BloqueDeSesion
    let activo: Bool
    let pasado: Bool

    var body: some View {
        HStack(spacing: TokensEspaciado.e9) {
            Circle()
                .fill(activo ? Paleta.acento : Paleta.bordeSignificante)
                .frame(width: TokensEspaciado.e5, height: TokensEspaciado.e5)

            VStack(alignment: .leading, spacing: TokensEspaciado.e1) {
                Text(bloque.titulo).estilo(.labelCampo)
                Text(bloque.detalle)
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let insignia = insigniaVisible {
                Text(insignia)
                    .estilo(.etiquetaSeccion.enMinusculas, color: activo ? Paleta.acento : Paleta.textoTerciario)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, TokensEspaciado.e10)
        .padding(.vertical, TokensEspaciado.e8)
        .background(activo ? Paleta.acentoSuaveFondo : Paleta.superficieHundida)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.chip, style: .continuous)
                .strokeBorder(activo ? Paleta.acentoSuaveBorde : Paleta.divisor, lineWidth: TokensEspaciado.e1)
        )
        .opacity(pasado ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private var insigniaVisible: String? {
        if activo { return bloque.insignia ?? Textos.entrenoEnCurso }
        if pasado { return Textos.planHecho }
        return bloque.insignia
    }
}
