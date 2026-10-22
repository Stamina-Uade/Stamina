import SwiftUI
import TrainerCore

/// "Antes de cada sesión  − 30 min +": cuánto antes llega la notificación para
/// prepararte, de 5 minutos a 1 hora, de a 5. La usan "Días y horarios" del alta
/// y Ajustes › Notificaciones (`AvisoDePreparacion`).
struct FilaDeMinutosDeAviso: View {
    @Binding var minutos: Int

    var body: some View {
        HStack(spacing: TokensEspaciado.e10) {
            Text(Textos.notificationsPrepBefore)
                .estilo(.opcionTitulo, color: Paleta.textoPrimario)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: TokensEspaciado.e8)
            BotonCircular("minus", etiqueta: Textos.commonLess) { cambiar(-AvisoDePreparacion.paso) }
                .disabled(minutos <= AvisoDePreparacion.rango.lowerBound)
            Text(AvisoDePreparacion.texto(minutos))
                .estilo(.opcionTitulo, color: Paleta.textoPrimario)
                .monospacedDigit()
                .frame(minWidth: TokensEspaciado.e56)
            BotonCircular("plus", etiqueta: Textos.commonMore) { cambiar(AvisoDePreparacion.paso) }
                .disabled(minutos >= AvisoDePreparacion.rango.upperBound)
        }
        // Para VoiceOver es un solo control que se ajusta deslizando arriba/abajo.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Textos.notificationsPrepBefore)
        .accessibilityValue(AvisoDePreparacion.texto(minutos))
        .accessibilityAdjustableAction { direccion in
            switch direccion {
            case .increment: cambiar(AvisoDePreparacion.paso)
            case .decrement: cambiar(-AvisoDePreparacion.paso)
            @unknown default: break
            }
        }
    }

    private func cambiar(_ delta: Int) {
        let nuevo = AvisoDePreparacion.ajustado(minutos + delta)
        guard nuevo != minutos else { return }
        Haptico.seleccion()
        minutos = nuevo
    }
}
