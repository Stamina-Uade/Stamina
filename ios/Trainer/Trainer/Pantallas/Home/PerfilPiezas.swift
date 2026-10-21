import SwiftUI
import TrainerCore

// =============================================================================
// Piezas chicas del perfil: la fila de acceso (ícono, título, subtítulo y
// flecha), la cápsula de "Completar", la barra de progreso de una meta y el
// chip redondo de un día.
// Separadas para que el `body` de PerfilView se lea de corrido.
// =============================================================================

/// Una fila que lleva a otro lado: ícono, qué es, qué vas a encontrar y la flecha.
struct FilaDeAccesoDePerfil: View {
    let simbolo: String
    let titulo: String
    let subtitulo: String
    var colorDelSubtitulo: Color = Paleta.textoSecundario
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

/// La cápsula rosa chica con "+" y un texto ("Completar ahora"). Es sólo la
/// etiqueta: el botón (o la tarjeta tocable) la pone quien la usa.
struct EtiquetaCompletar: View {
    let texto: String

    var body: some View {
        HStack(spacing: TokensEspaciado.e6) {
            Image(systemName: "plus")
                .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                .accessibilityHidden(true)
            Text(texto)
                .estilo(.chip, color: Paleta.textoAcento)
        }
        .foregroundStyle(Paleta.textoAcento)
        .padding(.horizontal, TokensEspaciado.e12)
        .padding(.vertical, TokensEspaciado.e8)
        .background(Paleta.acentoChipActivo)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1))
    }
}

/// La barrita de "semana 3 de 12" de una meta.
struct BarraDeProgresoDeMeta: View {
    let actual: Int
    let total: Int

    private var fraccion: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(min(max(actual, 0), total)) / CGFloat(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Paleta.superficieControl)
                    Capsule()
                        .fill(Paleta.acento)
                        .frame(width: max(TokensEspaciado.e6, geo.size.width * fraccion))
                }
            }
            .frame(height: TokensEspaciado.e6)
            .accessibilityHidden(true)

            Text(Textos.profilePlanWeekOf(actual, total))
                .estilo(.notaLegal, color: Paleta.textoTerciario)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Un día de la semana como chip redondo: lleno si se entrena, con la hora abajo.
struct ChipDeDiaDePerfil: View {
    let nombreCorto: String
    let nombreLargo: String
    /// Minuto del día del entrenamiento; `nil` si ese día no se eligió.
    let minutoDelDia: Int?
    let esHoy: Bool

    private var activo: Bool { minutoDelDia != nil }

    var body: some View {
        VStack(spacing: TokensEspaciado.e6) {
            ZStack {
                Circle()
                    .fill(activo ? Paleta.acento : Paleta.superficie)
                Circle()
                    .strokeBorder(borde, lineWidth: esHoy ? TokensEspaciado.e2 : TokensEspaciado.e1)
                Text(nombreCorto)
                    .estilo(.chip, color: activo ? Paleta.sobreAcento : Paleta.textoTerciario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: activo ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e6)

            // Sin hora es un día de descanso: se dice, en vez de una raya.
            Text(minutoDelDia.map { Formato.hora(minutoDelDia: $0) } ?? Textos.profileDayOff)
                .estilo(.etiquetaSeccion.enMinusculas,
                        color: activo ? Paleta.textoSecundario : Paleta.textoTerciario)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: textoAccesible))
    }

    private var borde: Color {
        if esHoy { return Paleta.textoPrimario }
        return activo ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie
    }

    private var textoAccesible: String {
        var partes = [nombreLargo]
        if esHoy { partes.append(Textos.commonTodayLowercase) }
        if let minutoDelDia {
            partes.append(Textos.profileYouTrainAt(Formato.hora(minutoDelDia: minutoDelDia)))
        } else {
            partes.append(Textos.profileNoWorkout)
        }
        return partes.joined(separator: ", ")
    }
}
