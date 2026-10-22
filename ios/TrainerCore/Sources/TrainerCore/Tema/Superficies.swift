import SwiftUI

// =============================================================================
// Superficies y piezas de estructura: la card, la fila de resumen, la barra de
// avance y el andamio de una pantalla del flujo.
//
// `tokens.json` → `elevacion`: **el diseño no usa ni una sombra**. La jerarquía
// se comunica con color de superficie más un borde de 1 pt. Es una decisión del
// diseño y no se le agrega elevación de Material por costumbre.
// =============================================================================

/// La card del producto: superficie, borde de 1 pt, radio 18.
public struct Tarjeta<Contenido: View>: View {
    private let relleno: CGFloat
    private let contenido: Contenido

    public init(relleno: CGFloat = TokensEspaciado.e16, @ViewBuilder contenido: () -> Contenido) {
        self.relleno = relleno
        self.contenido = contenido()
    }

    public var body: some View {
        contenido
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
    }
}

/// Una línea "etiqueta … valor". El resumen de `reg-listo` y de `clave-lista`.
public struct FilaResumen: View {
    private let etiqueta: String
    private let valor: String

    public init(_ etiqueta: String, _ valor: String) {
        self.etiqueta = etiqueta
        self.valor = valor
    }

    public var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e10) {
            Text(etiqueta).estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
            Spacer(minLength: 0)
            Text(valor)
                .estilo(.cuerpoSecundario)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// La barra de avance del registro. El diseño decidió **no mostrar el número**
/// de paso; para VoiceOver sí se anuncia, porque ahí no hay barra que mirar.
public struct BarraAvance: View {
    private let paso: Int
    private let total: Int
    private let descripcion: String

    public init(paso: Int, total: Int, descripcion: String) {
        self.paso = paso
        self.total = total
        self.descripcion = descripcion
    }

    private var fraccion: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(paso) / Double(total)))
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Paleta.superficieControl)
                Capsule()
                    .fill(Paleta.acento)
                    .frame(width: geo.size.width * fraccion)
            }
        }
        .frame(height: TokensEspaciado.e3)
        .animation(.easeInOut(duration: TokensMovimiento.media), value: fraccion)
        .accessibilityElement()
        .accessibilityLabel(descripcion)
        .accessibilityValue(Text(verbatim: "\(paso)/\(total)"))
    }
}

/// Una nota: texto común en color secundario con un ícono de información a la
/// izquierda.
///
/// 2026-10-22 (Iván): ya no es la caja con fondo y borde del color de la app —un
/// recuadro rosa se leía como algo para tocar o como un error—. Vale en todos los
/// lugares donde se usa.
public struct AvisoSuave: View {
    private let texto: String

    public init(_ texto: String) {
        self.texto = texto
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e8) {
            Image(systemName: "info.circle")
                .font(.system(size: TokensTipografia.labelCampoTamano, weight: .semibold))
                .foregroundStyle(Paleta.textoSecundario)
                .accessibilityHidden(true)
            Text(texto)
                .estilo(.labelCampo, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// El cuadro rojo de "pará y consultá" de `reg-salud`.
public struct AvisoAtencion<Contenido: View>: View {
    private let titulo: String
    private let contenido: Contenido

    public init(titulo: String, @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.contenido = contenido()
    }

    public var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                Text(titulo).estilo(.etiquetaSeccion, color: Paleta.error)
                contenido
            }
        }
    }
}

/// Un ítem del cuadro de atención: punto rojo y texto.
public struct ItemAtencion: View {
    private let texto: String

    public init(_ texto: String) {
        self.texto = texto
    }

    public var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e9) {
            Circle()
                .fill(Paleta.error)
                .frame(width: TokensEspaciado.e5, height: TokensEspaciado.e5)
                .padding(.top, TokensEspaciado.e6)
            Text(texto)
                .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
