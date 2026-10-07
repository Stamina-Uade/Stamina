import SwiftUI

// =============================================================================
// Los controles de elección del registro: sexo, deporte, nivel, objetivo,
// medición, días y el descargo médico.
//
// Todos comparten la misma regla de AGENTS.md §10.1: lo elegido **nunca** se
// comunica sólo por color. Cada uno cambia relleno, borde y marca a la vez, y
// expone el rasgo `.isSelected` para VoiceOver.
// =============================================================================

/// Fila de opción única: un punto, un título y una explicación.
/// `reg-sexo`, `reg-deporte`, `reg-nivel` y `reg-medicion`.
public struct FilaOpcion: View {
    private let titulo: String
    private let detalle: String?
    private let elegida: Bool
    private let conMarca: Bool
    private let accion: () -> Void

    /// - Parameter conMarca: `reg-nivel` apila título y detalle sin el punto.
    ///   Lo elegido se sigue viendo por relleno y borde, y VoiceOver lo sabe por
    ///   el rasgo `.isSelected`.
    public init(
        titulo: String,
        detalle: String? = nil,
        elegida: Bool,
        conMarca: Bool = true,
        accion: @escaping () -> Void
    ) {
        self.titulo = titulo
        self.detalle = detalle
        self.elegida = elegida
        self.conMarca = conMarca
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            HStack(alignment: .top, spacing: TokensEspaciado.e12) {
                if conMarca {
                    Marca(elegida: elegida)
                        .padding(.top, TokensEspaciado.e4)
                }

                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(titulo).estilo(.opcionTitulo)
                    if let detalle {
                        Text(detalle)
                            .estilo(.labelCampo, color: Paleta.textoTerciario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(TokensEspaciado.e16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fondoDeOpcion(elegida: elegida)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
    }
}

/// Fila del objetivo: título a la izquierda, distancia a la derecha.
/// `reg-objetivo`, con sus 7 opciones cerradas.
public struct FilaObjetivo: View {
    private let titulo: String
    private let distancia: String
    private let elegido: Bool
    private let accion: () -> Void

    public init(titulo: String, distancia: String, elegido: Bool, accion: @escaping () -> Void) {
        self.titulo = titulo
        self.distancia = distancia
        self.elegido = elegido
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e11) {
                Marca(elegida: elegido)
                Text(titulo)
                    .estilo(.tituloCard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(distancia)
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
            }
            .padding(TokensEspaciado.e13)
            .fondoDeOpcion(elegida: elegido)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
    }
}

/// Chip de día de la semana. `reg-dias`.
///
/// El diseño lo dibuja de 41 pt de alto; acá responde en 48 sin cambiar el
/// dibujo (ESPECIFICACION §9.2, "área táctil ampliada sin tocar densidad").
public struct ChipDia: View {
    private let abreviatura: String
    private let nombreCompleto: String
    private let elegido: Bool
    private let accion: () -> Void

    public init(abreviatura: String, nombreCompleto: String, elegido: Bool, accion: @escaping () -> Void) {
        self.abreviatura = abreviatura
        self.nombreCompleto = nombreCompleto
        self.elegido = elegido
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            Text(abreviatura)
                .estilo(.cuerpoSecundario, color: elegido ? Paleta.textoAcento : Paleta.textoPrimario)
                .frame(maxWidth: .infinity)
                .frame(height: TokensTamano.chipDia)
                .fondoDeOpcion(elegida: elegido, radio: TokensRadio.chip)
                .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(nombreCompleto)
        .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
    }
}

/// El descargo médico de `reg-salud`. Es una casilla, no un interruptor: acepta
/// una vez y queda.
public struct Casilla: View {
    private let texto: String
    @Binding private var marcada: Bool

    public init(texto: String, marcada: Binding<Bool>) {
        self.texto = texto
        self._marcada = marcada
    }

    public var body: some View {
        Button { marcada.toggle() } label: {
            HStack(alignment: .top, spacing: TokensEspaciado.e11) {
                ZStack {
                    RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous)
                        .fill(marcada ? Paleta.seleccionadoBorde : Color.clear)
                    RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous)
                        .strokeBorder(marcada ? Paleta.seleccionadoBorde : Paleta.bordeSignificante,
                                      lineWidth: TokensEspaciado.e2)
                    if marcada {
                        Image(systemName: "checkmark")
                            .font(.system(size: TokensTipografia.notaLegalTamano,
                                          weight: TokensTipografia.tituloCardPeso))
                            .foregroundStyle(Paleta.dinamico(claro: Color.white, oscuro: Paleta.sobreAcento))
                    }
                }
                .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e20)

                Text(texto)
                    .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(TokensEspaciado.e14)
            .fondoDeOpcion(elegida: marcada)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityAddTraits(marcada ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(texto)
    }
}

// -----------------------------------------------------------------------------

/// El punto que marca la opción elegida.
///
/// El diseño lo dibuja en blanco al 20 % cuando no está elegido: **2.01:1**, por
/// debajo del 3.0 que WCAG 1.4.11 pide para un componente que significa algo
/// (`design/ESPECIFICACION.md` §9.1). Acá va en `borde_significante` (3.58:1).
/// Y el punto nunca es la única señal: la fila entera cambia relleno y borde.
private struct Marca: View {
    let elegida: Bool

    var body: some View {
        Circle()
            .fill(elegida ? Paleta.seleccionadoBorde : Paleta.bordeSignificante)
            .frame(width: TokensEspaciado.e9, height: TokensEspaciado.e9)
    }
}

extension View {
    /// El relleno y el borde compartidos por todo control elegible.
    fileprivate func fondoDeOpcion(elegida: Bool, radio: CGFloat = TokensRadio.boton) -> some View {
        background(elegida ? Paleta.seleccionadoFondo : Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(elegida ? Paleta.seleccionadoBorde : Paleta.bordeSuperficie,
                                  lineWidth: TokensEspaciado.e1)
            )
    }
}
