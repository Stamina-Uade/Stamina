import SwiftUI
#if os(watchOS)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cuenta regresiva 3 → 2 → 1 antes de arrancar una salida deportiva.
/// - Se muestra 3 → 2 → 1 sin el 0.
/// - Un único círculo exterior se vacía de forma continua durante los 3 segundos.
/// - Tocar la pantalla saltea la cuenta y arranca al instante.
/// - Al terminar de vaciarse el círculo, arranca solo.
public struct VistaCuentaRegresiva: View {
    private let duracionTotal: Double = 3.0
    private let alCompletar: () -> Void

    @State private var tiempoRestante: Double = 3.0
    @State private var ultimoEntero = 3
    @State private var terminado = false
    @State private var fechaInicio: Date?

    public init(alCompletar: @escaping () -> Void) {
        self.alCompletar = alCompletar
    }

    private var numeroMostrado: String {
        let n = Int(ceil(max(0.01, tiempoRestante)))
        return "\(min(3, max(1, n)))"
    }

    private var progresoCirculo: CGFloat {
        CGFloat(max(0.0, min(1.0, tiempoRestante / duracionTotal)))
    }

    public var body: some View {
        TimelineView(.animation) { context in
            ZStack {
                Paleta.fondo.ignoresSafeArea()

                // Círculo base apagado
                Circle()
                    .stroke(Paleta.acento.opacity(0.18), lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Círculo que se vacía de forma continua
                Circle()
                    .trim(from: 0, to: progresoCirculo)
                    .stroke(
                        Paleta.acento,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)

                // Número 3 → 2 → 1
                Text(numeroMostrado)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                    .monospacedDigit()
                    .contentTransition(.identity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Tocar la pantalla saltea la cuenta y arranca al instante
                terminar()
            }
            .onChange(of: context.date) { fechaActual in
                actualizarProgreso(fechaActual: fechaActual)
            }
            .onAppear {
                fechaInicio = Date()
                sonarHaptico()
            }
        }
    }

    private func actualizarProgreso(fechaActual: Date) {
        guard !terminado else { return }
        guard let inicio = fechaInicio else {
            fechaInicio = fechaActual
            return
        }

        let transcurrido = fechaActual.timeIntervalSince(inicio)
        let restante = max(0.0, duracionTotal - transcurrido)
        tiempoRestante = restante

        let enteroActual = Int(ceil(max(0.01, restante)))
        if enteroActual != ultimoEntero && enteroActual >= 1 {
            ultimoEntero = enteroActual
            sonarHaptico()
        }

        if restante <= 0.0 {
            terminar()
        }
    }

    private func terminar() {
        guard !terminado else { return }
        terminado = true
        sonarHapticoFinal()
        alCompletar()
    }

    private func sonarHaptico() {
        #if canImport(UIKit) && !os(watchOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private func sonarHapticoFinal() {
        #if canImport(UIKit) && !os(watchOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }
}
