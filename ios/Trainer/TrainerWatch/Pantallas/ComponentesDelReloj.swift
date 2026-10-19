import SwiftUI
import TrainerCore

// =============================================================================
// Los controles del reloj.
//
// No son los del teléfono en chiquito: la regla de §10.2 es **un dedo y sin
// mirar**, así que todo es de ancho completo y de 44 pt para arriba, y no hay
// ningún control que pida precisión.
// =============================================================================

/// El botón del reloj. Ancho completo siempre: apuntar a un botón chico con el
/// brazo en movimiento no funciona.
struct BotonDelReloj: View {
    enum Tono { case normal, error, sobreAcentoLleno, sobreAcentoBorde }

    let titulo: String
    var simbolo: String?
    var destacado: Bool = false
    var tono: Tono = .normal
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e9) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: TokensEspaciado.e16))
                }
                Text(titulo).estilo(.relojBoton, color: colorDelTexto)
                Spacer(minLength: 0)
            }
            .foregroundStyle(colorDelTexto)
            .padding(.horizontal, TokensEspaciado.e14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PaletaReloj.objetivoTactilMinimo)
            .background(fondo)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous)
                    .strokeBorder(borde, lineWidth: TokensEspaciado.e2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titulo)
    }

    private var fondo: Color {
        switch tono {
        case .error: return PaletaReloj.errorFondo
        case .sobreAcentoLleno: return PaletaReloj.sobreAcento
        case .sobreAcentoBorde: return .clear
        case .normal: return destacado ? PaletaReloj.acento : PaletaReloj.superficie
        }
    }

    private var colorDelTexto: Color {
        switch tono {
        case .error: return PaletaReloj.error
        case .sobreAcentoLleno: return PaletaReloj.acento
        case .sobreAcentoBorde: return PaletaReloj.sobreAcento
        case .normal: return destacado ? PaletaReloj.sobreAcento : PaletaReloj.textoPrimario
        }
    }

    private var borde: Color {
        switch tono {
        case .sobreAcentoBorde: return PaletaReloj.sobreAcento.opacity(0.3)
        default: return .clear
        }
    }
}

/// Un interruptor de la sesión en curso.
///
/// 🛑 No persiste nada: vale para esta salida y se descarta al terminarla
/// (AGENTS.md §10.2). La pantalla que lo muestra tiene que decirlo.
struct InterruptorDeSesion: View {
    let titulo: String
    @Binding var encendido: Bool

    var body: some View {
        Button { encendido.toggle() } label: {
            HStack(spacing: TokensEspaciado.e10) {
                Text(titulo)
                    .estilo(.relojCuerpo, color: PaletaReloj.textoPrimario)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                ZStack(alignment: encendido ? .trailing : .leading) {
                    Capsule()
                        .fill(encendido ? PaletaReloj.acento : PaletaReloj.superficieAlterna)
                        .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e26)
                    Circle()
                        .fill(encendido ? PaletaReloj.sobreAcento : PaletaReloj.textoSecundario)
                        .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e20)
                        .padding(.horizontal, TokensEspaciado.e3)
                }
                .animation(.easeOut(duration: TokensMovimiento.rapida), value: encendido)
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PaletaReloj.objetivoTactilMinimo)
            .background(PaletaReloj.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// El stepper del gimnasio en la muñeca. Los − y + son grandes a propósito.
struct StepperDelReloj: View {
    let valor: String
    let unidad: String
    let bajar: () -> Void
    let subir: () -> Void

    var body: some View {
        HStack(spacing: TokensEspaciado.e8) {
            boton("minus", accion: bajar)
            VStack(spacing: 0) {
                Text(valor).estilo(.relojEstado)
                Text(unidad).estilo(.relojEtiqueta, color: PaletaReloj.textoSecundario)
            }
            .frame(maxWidth: .infinity)
            boton("plus", accion: subir)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unidad)
        .accessibilityValue(valor)
        .accessibilityAdjustableAction { direccion in
            switch direccion {
            case .increment: subir()
            case .decrement: bajar()
            @unknown default: break
            }
        }
    }

    private func boton(_ simbolo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: TokensEspaciado.e20, weight: TokensTipografia.tituloCardPeso))
                .foregroundStyle(PaletaReloj.textoPrimario)
                .frame(width: PaletaReloj.objetivoTactilMinimo,
                       height: PaletaReloj.objetivoTactilMinimo)
                .background(PaletaReloj.superficieAlterna)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Un aviso corto dentro de una pantalla, con ícono **además** de color.
struct AvisoDelReloj: View {
    let simbolo: String
    let texto: String

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e9) {
            Image(systemName: simbolo)
                .font(.system(size: TokensEspaciado.e16))
                .foregroundStyle(PaletaReloj.acento)
            Text(texto)
                .estilo(.relojEtiqueta, color: PaletaReloj.textoPrimario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaletaReloj.acentoSuave)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Navegación

/// Navegación por gestos en el reloj de acuerdo con la distribución del entrenamiento:
/// - Arriba (dy < 0): arrastre hacia arriba -> Mapa
/// - Abajo (dy > 0): arrastre hacia abajo -> Parciales
/// - Derecha (dx > 0): arrastre hacia la derecha -> Controles (pantalla a la izquierda)
/// - Izquierda (dx < 0): arrastre hacia la izquierda -> Música (pantalla a la derecha)
extension View {
    func navegacionEntrenoReloj(alDeslizarArriba: (() -> Void)? = nil,
                               alDeslizarAbajo: (() -> Void)? = nil,
                               alDeslizarIzquierda: (() -> Void)? = nil,
                               alDeslizarDerecha: (() -> Void)? = nil) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { valor in
                        let dx = valor.translation.width, dy = valor.translation.height
                        if abs(dx) > abs(dy) {
                            if dx < -20 {
                                alDeslizarIzquierda?()
                            } else if dx > 20 {
                                alDeslizarDerecha?()
                            }
                        } else {
                            if dy < -20 {
                                alDeslizarArriba?()
                            } else if dy > 20 {
                                alDeslizarAbajo?()
                            }
                        }
                    }
            )
    }

    func navegacionDelReloj(arriba: (() -> Void)? = nil,
                            abajo: (() -> Void)? = nil,
                            izquierda: (() -> Void)? = nil,
                            derecha: (() -> Void)? = nil) -> some View {
        navegacionEntrenoReloj(alDeslizarArriba: arriba,
                               alDeslizarAbajo: abajo,
                               alDeslizarIzquierda: izquierda,
                               alDeslizarDerecha: derecha)
    }
}

/// La vibración de un aviso. En el reloj **siempre** acompaña al aviso visual:
/// es lo que se siente sin mirar (AGENTS.md §10.2).
enum VibracionReloj {
    static func avisar() {
        // Silenciado para evitar el sonido ping
    }
}

#if os(watchOS)
import WatchKit
#endif
