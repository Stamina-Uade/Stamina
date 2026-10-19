import SwiftUI

// =============================================================================
// Los controles de elección del registro: sexo, deporte, nivel, objetivo,
// medición, días y el descargo médico.
//
// Todos comparten la misma regla de AGENTS.md §10.1: lo elegido **nunca** se
// comunica sólo por color. Cada uno cambia relleno, borde y marca a la vez, y
// expone el rasgo `.isSelected` para VoiceOver.
// =============================================================================

/// Fila de opción única: un título, una explicación y la marca a la derecha.
/// `reg-sexo`, `reg-deporte`, `reg-nivel` y `reg-medicion`.
public struct FilaOpcion: View {
    private let titulo: String
    private let detalle: String?
    private let elegida: Bool
    private let conMarca: Bool
    private let accion: () -> Void

    /// - Parameter conMarca: `reg-nivel` apila título y detalle sin el aro vacío;
    ///   la elegida igual lleva su tilde, además del borde rosa, y VoiceOver lo
    ///   sabe por el rasgo `.isSelected`.
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
            HStack(alignment: .center, spacing: TokensEspaciado.e12) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                    Text(titulo).estilo(.opcionTitulo)
                    if let detalle {
                        Text(detalle)
                            .estilo(.labelCampo, color: Paleta.textoTerciario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                // Rediseño 2026-10: la tilde rosa va a la derecha, como en el
                // mockup. Sin marca, sólo aparece cuando está elegida.
                if conMarca || elegida {
                    Marca(elegida: elegida)
                }
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.vertical, TokensEspaciado.e14)
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
                Text(titulo)
                    .estilo(.opcionTitulo)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(distancia)
                    .estilo(.chip, color: elegido ? Paleta.textoAcento : Paleta.textoTerciario)
                Marca(elegida: elegido)
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.vertical, TokensEspaciado.e13)
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
            // Elegido es la píldora rosa llena: cambia relleno, borde y color de
            // texto a la vez, y VoiceOver lo sabe por `.isSelected`.
            Text(abreviatura)
                .estilo(.chip, color: elegido ? Paleta.sobreAcento : Paleta.textoPrimario)
                .frame(maxWidth: .infinity)
                .frame(height: TokensTamano.chipDia)
                .background(elegido ? Paleta.acento : Paleta.superficie)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(elegido ? Paleta.acento : Paleta.bordeSuperficie,
                                           lineWidth: TokensEspaciado.e1)
                )
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
            // El mockup la dibuja suelta, sin tarjeta: un círculo y el texto. El
            // círculo se llena de rosa con tilde; el borde apagado es
            // `borde_significante` (3.58:1), no decorativo.
            HStack(alignment: .top, spacing: TokensEspaciado.e12) {
                ZStack {
                    Circle()
                        .fill(marcada ? Paleta.acento : Color.clear)
                    Circle()
                        .strokeBorder(marcada ? Paleta.acento : Paleta.bordeSignificante,
                                      lineWidth: TokensEspaciado.e2)
                    if marcada {
                        Image(systemName: "checkmark")
                            .font(.system(size: TokensTipografia.notaLegalTamano,
                                          weight: .heavy))
                            .foregroundStyle(Paleta.sobreAcento)
                    }
                }
                .frame(width: TokensEspaciado.e22, height: TokensEspaciado.e22)
                .animation(.easeOut(duration: TokensMovimiento.rapida), value: marcada)

                Text(texto)
                    .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, TokensEspaciado.e10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityAddTraits(marcada ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(texto)
    }
}

// -----------------------------------------------------------------------------

/// La marca de la opción: un aro vacío o el círculo rosa con tilde.
///
/// El aro apagado va en `borde_significante` (3.58:1) y no en el blanco al 20 %
/// del diseño original (2.01:1, por debajo de WCAG 1.4.11). Y la marca nunca es
/// la única señal: la fila entera cambia de borde y VoiceOver lee `.isSelected`.
private struct Marca: View {
    let elegida: Bool

    var body: some View {
        ZStack {
            if elegida {
                Circle().fill(Paleta.acento)
                Image(systemName: "checkmark")
                    .font(.system(size: TokensTipografia.notaLegalTamano, weight: .heavy))
                    .foregroundStyle(Paleta.sobreAcento)
            } else {
                Circle().strokeBorder(Paleta.bordeSignificante, lineWidth: TokensEspaciado.e2)
            }
        }
        .frame(width: TokensEspaciado.e22, height: TokensEspaciado.e22)
        .animation(.easeOut(duration: TokensMovimiento.rapida), value: elegida)
        .accessibilityHidden(true)
    }
}

extension View {
    /// La tarjeta oscura compartida por todo control elegible: elegida, el borde
    /// se vuelve rosa y más grueso (rediseño 2026-10).
    fileprivate func fondoDeOpcion(elegida: Bool, radio: CGFloat = TokensRadio.card) -> some View {
        background(elegida ? Paleta.acentoSuaveFondo : Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(elegida ? Paleta.seleccionadoBorde : Paleta.bordeSuperficie,
                                  lineWidth: elegida ? TokensEspaciado.e2 : TokensEspaciado.e1)
            )
    }
}
