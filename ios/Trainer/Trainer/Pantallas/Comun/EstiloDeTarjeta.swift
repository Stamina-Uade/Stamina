import SwiftUI
import TrainerCore

extension View {
    /// El fondo y el borde de una tarjeta del Home. Se repite en todas las
    /// pestañas, así que vive en un solo lugar. (Antes estaba en NutricionView,
    /// que salió de la app en el rediseño 2026-10.)
    func tarjeta(radio: CGFloat = TokensRadio.card) -> some View {
        background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
    }
}
