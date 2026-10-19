import SwiftUI

/// Tres disciplinas en un solo trazo escalable: ciclismo, carrera y natación.
/// Las coordenadas se escalan con el marco para que también se lean en el reloj.
public struct IconoTriatlon: View {
    private let color: Color

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            let lado = min(geometry.size.width, geometry.size.height)
            TrazoTriatlon()
                .stroke(color, style: StrokeStyle(lineWidth: max(1.0, lado * 0.065),
                                                  lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(String(localized: "sport.triathlon", defaultValue: "Triatlón", bundle: .main,
                                   comment: "VoiceOver: ícono del triatlón (TrainerCore)"))
    }
}

public struct IconoDeporte: View {
    public let deporte: DeporteDeSesion
    public let color: Color
    public let tamano: CGFloat

    public init(deporte: DeporteDeSesion, color: Color, tamano: CGFloat) {
        self.deporte = deporte
        self.color = color
        self.tamano = tamano
    }

    public var body: some View {
        Group {
            if deporte == .triatlon {
                IconoTriatlon(color: color)
                    .frame(width: tamano, height: tamano)
            } else {
                Image(systemName: simbolo)
                    .font(.system(size: tamano, weight: .bold))
                    .foregroundStyle(color)
            }
        }
    }

    private var simbolo: String {
        switch deporte {
        case .running: "figure.run"
        case .ciclismo: "bicycle"
        case .natacion: "figure.pool.swim"
        case .trekking: "figure.hiking"
        case .fuerza: "dumbbell.fill"
        case .otro, .triatlon: "figure.mixed.cardio"
        }
    }
}

private struct TrazoTriatlon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let lado = min(rect.width, rect.height)
        let s = (lado * 0.90) / 32
        let offsetX = rect.minX + (rect.width - 32 * s) / 2
        let offsetY = rect.minY + (rect.height - 32 * s) / 2
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * s, y: offsetY + y * s)
        }
        func line(_ coordinates: [(CGFloat, CGFloat)]) {
            guard let first = coordinates.first else { return }
            p.move(to: point(first.0, first.1))
            for (x, y) in coordinates.dropFirst() { p.addLine(to: point(x, y)) }
        }
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            p.addEllipse(in: CGRect(x: offsetX + (x - r) * s, y: offsetY + (y - r) * s,
                                  width: 2 * r * s, height: 2 * r * s))
        }

        // Ciclista arriba a la izquierda
        circle(4.0, 13.0, 2.3); circle(14.0, 13.0, 2.3); circle(8.6, 3.5, 1.3)
        line([(4.0, 13.0), (8.0, 8.5), (10.0, 13.0), (4.0, 13.0)])
        line([(10.0, 13.0), (14.0, 13.0), (11.5, 8.5), (8.0, 8.5)])
        line([(8.6, 5.0), (7.0, 7.5), (10.5, 9.0), (12.8, 8.0)])

        // Corredor arriba a la derecha
        circle(24.0, 3.5, 1.4)
        line([(23.0, 5.8), (21.0, 10.0), (24.5, 11.2)])
        line([(21.0, 10.0), (18.0, 9.0), (17.0, 11.0)])
        line([(21.0, 10.0), (20.5, 14.5), (17.5, 16.5)])
        line([(20.5, 14.5), (24.5, 16.0), (27.5, 15.0)])
        line([(22.5, 7.2), (26.0, 8.2), (28.0, 6.8)])

        // Nadador abajo: cabeza, brazo y ola
        circle(8.0, 21.5, 1.3)
        line([(5.5, 22.8), (10.5, 20.0), (15.5, 22.0), (20.5, 20.0), (26.5, 21.0)])
        line([(3.5, 26.0), (7.5, 24.8), (11.5, 26.0), (15.5, 24.8), (19.5, 26.0), (23.5, 24.8), (28.5, 26.0)])
        return p
    }
}
