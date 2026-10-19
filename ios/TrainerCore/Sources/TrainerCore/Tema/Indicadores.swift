import SwiftUI

// =============================================================================
// Barras, interruptores y steppers: los controles que el Home usa y el flujo de
// entrada no tenía.
// =============================================================================

/// Una barra de progreso horizontal. Siempre lleva su valor en texto al lado:
/// una barra sola no se lee con VoiceOver ni se entiende sin ver el color.
public struct BarraDeProgreso: View {
    private let fraccion: Double
    private let color: Color
    private let alto: CGFloat
    private let descripcion: String

    public init(fraccion: Double, color: Color = Paleta.acento,
                alto: CGFloat = TokensEspaciado.e5, descripcion: String) {
        self.fraccion = min(max(fraccion, 0), 1)
        self.color = color
        self.alto = alto
        self.descripcion = descripcion
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Paleta.superficieControl)
                Capsule().fill(color).frame(width: geo.size.width * fraccion)
            }
        }
        .frame(height: alto)
        .accessibilityElement()
        .accessibilityLabel(descripcion)
        .accessibilityValue(Text(fraccion, format: .percent.precision(.fractionLength(0))))
    }
}

/// El interruptor de ajustes.
///
/// El diseño lo dibuja de 44×26, y ESPECIFICACION §9.2 lo marca como el objetivo
/// táctil más chico del producto. Acá se dibuja igual y responde en 48.
public struct Interruptor: View {
    private let titulo: String
    private let detalle: String?
    @Binding private var encendido: Bool

    public init(titulo: String, detalle: String? = nil, encendido: Binding<Bool>) {
        self.titulo = titulo
        self.detalle = detalle
        self._encendido = encendido
    }

    public var body: some View {
        Button { encendido.toggle() } label: {
            HStack(spacing: TokensEspaciado.e12) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(titulo).estilo(.tituloCard)
                    if let detalle {
                        Text(detalle)
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: encendido ? .trailing : .leading) {
                    Capsule()
                        .fill(encendido ? Paleta.interruptorActivo : Paleta.superficieControl)
                        .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e26)
                        // El halo rosa de lo que está prendido, como el mockup.
                        .shadow(color: encendido ? Paleta.acentoProfundo : Color.clear,
                                radius: TokensEspaciado.e6)
                    Circle()
                        .fill(encendido ? Paleta.interruptorThumb : Paleta.textoTerciario)
                        .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e20)
                        .padding(.horizontal, TokensEspaciado.e3)
                }
                .animation(.easeOut(duration: TokensMovimiento.rapida), value: encendido)
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .padding(.vertical, TokensEspaciado.e12)
            .frame(maxWidth: .infinity)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(encendido ? Text(verbatim: "1") : Text(verbatim: "0"))
    }
}

/// Un stepper de − y +. Los dos botones responden en 48 aunque se dibujen de 34.
public struct StepperDeValor: View {
    private let etiqueta: String
    private let valor: String
    private let puedeBajar: Bool
    private let puedeSubir: Bool
    private let bajar: () -> Void
    private let subir: () -> Void

    public init(etiqueta: String, valor: String,
                puedeBajar: Bool = true, puedeSubir: Bool = true,
                bajar: @escaping () -> Void, subir: @escaping () -> Void) {
        self.etiqueta = etiqueta
        self.valor = valor
        self.puedeBajar = puedeBajar
        self.puedeSubir = puedeSubir
        self.bajar = bajar
        self.subir = subir
    }

    public var body: some View {
        HStack(spacing: TokensEspaciado.e8) {
            boton("minus", accion: bajar, habilitado: puedeBajar)
            Text(valor)
                .estilo(.campoNumero)
                .frame(maxWidth: .infinity)
            boton("plus", accion: subir, habilitado: puedeSubir)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiqueta)
        .accessibilityValue(valor)
        .accessibilityAdjustableAction { direccion in
            switch direccion {
            case .increment: if puedeSubir { subir() }
            case .decrement: if puedeBajar { bajar() }
            @unknown default: break
            }
        }
    }

    private func boton(_ simbolo: String, accion: @escaping () -> Void, habilitado: Bool) -> some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: TokensTipografia.opcionTituloTamano,
                              weight: TokensTipografia.tituloCardPeso))
                .foregroundStyle(habilitado ? Paleta.textoPrimario : Paleta.textoTerciario)
                .frame(width: TokensTamano.objetivoTactilMinimo,
                       height: TokensTamano.objetivoTactilMinimo)
                .background(Paleta.superficieAlterna)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
                .contentShape(Circle())
        }
        .buttonStyle(EstiloPresionado())
        .disabled(!habilitado)
    }
}

/// Un botón de "agregar" con borde punteado, como el del diseño.
public struct BotonAgregar: View {
    private let titulo: String
    private let accion: () -> Void

    public init(_ titulo: String, accion: @escaping () -> Void) {
        self.titulo = titulo
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e8) {
                Image(systemName: "plus")
                    .font(.system(size: TokensTipografia.labelCampoTamano,
                                  weight: TokensTipografia.tituloCardPeso))
                Text(titulo).estilo(.tituloCard, color: Paleta.textoCuerpo)
            }
            .foregroundStyle(Paleta.textoCuerpo)
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.bordeSignificante,
                                  style: StrokeStyle(lineWidth: TokensEspaciado.e1, dash: [4, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
    }
}
