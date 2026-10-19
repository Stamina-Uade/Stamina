import SwiftUI
import TrainerCore

// Controles que se dibujan encima del mapa: la mira de "centrar en mí", la
// brújula y el esqueleto mientras llega la primera ubicación.

// MARK: - Ícono Mira de Ubicación (Imagen 3)

struct IconoMiraUbicacion: View {
    let centrado: Bool
    var color: Color = Paleta.textoPrimario

    var body: some View {
        ZStack {
            // Ticks de la mira (4 marcas perpendiculares saliendo del círculo exterior)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 22)

            Rectangle()
                .fill(color)
                .frame(width: 22, height: 2)

            // Círculo exterior
            Circle()
                .fill(Paleta.superficieOverlayFondo)
                .frame(width: 17, height: 17)

            Circle()
                .strokeBorder(color, lineWidth: 2)
                .frame(width: 17, height: 17)

            // Punto central: lleno si está centrado en el usuario, vacío/hueco si no
            if centrado {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Botón Brújula (Estilo Imágenes 1, 2, 3)

struct TrianguloHaciaCentro: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Base en la parte superior (borde exterior), vértice apuntando hacia abajo (al centro)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct BotonBrujula: View {
    let heading: Double
    let accion: () -> Void

    private var headingNormalizado: Double {
        (heading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    private var letraCardinal: String {
        let idioma = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "es"
        let normal = headingNormalizado
        let esIngles = (idioma == "en")
        switch normal {
        case 337.5...360.0, 0.0..<22.5: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return esIngles ? "SW" : "SO"
        case 247.5..<292.5: return esIngles ? "W" : "O"
        case 292.5..<337.5: return esIngles ? "NW" : "NO"
        default: return "N"
        }
    }

    var body: some View {
        Button(action: accion) {
            ZStack {
                // 1. Círculo oscuro de fondo (tamaño chico: 44x44, Imágenes 1, 2, 3)
                Circle()
                    .fill(Color(red: 0.11, green: 0.12, blue: 0.14))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)

                // 2. Roseta / dial que rota con el mapa (-heading)
                ZStack {
                    // Marcas finas alrededor del círculo (cada 22.5°, omitiendo los 4 cardinales)
                    ForEach(0..<16) { i in
                        let angulo = Double(i) * 22.5
                        if i % 4 != 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.42))
                                .frame(width: 1.0, height: 3.2)
                                .offset(y: -18.0)
                                .rotationEffect(.degrees(angulo))
                        }
                    }

                    // Triángulo rojo en el borde señalando hacia el Norte y que se mueve al girar
                    TrianguloHaciaCentro()
                        .fill(Color(red: 0.95, green: 0.20, blue: 0.20))
                        .frame(width: 5.5, height: 4.8)
                        .offset(y: -17.5)
                        .rotationEffect(.degrees(0))

                    // Pequeños triángulos blancos en los otros puntos cardinales (E, S, O)
                    ForEach([90.0, 180.0, 270.0], id: \.self) { angulo in
                        TrianguloHaciaCentro()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 4.6, height: 3.8)
                            .offset(y: -18.0)
                            .rotationEffect(.degrees(angulo))
                    }
                }
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-heading))

                // 3. Letra de la dirección actual en el centro: blanca, grande y fija
                Text(letraCardinal)
                    .font(.system(
                        size: letraCardinal.count > 1 ? 13 : 18,
                        weight: .heavy,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(Textos.mapCompassAccessibility(letraCardinal, Int(headingNormalizado)))
    }
}

// MARK: - Vista Esqueleto de Carga de Mapa

struct VistaEsqueletoMapa: View {
    @State private var animar = false

    var body: some View {
        ZStack {
            Paleta.fondo
                .ignoresSafeArea()

            GeometryReader { geo in
                Canvas { context, size in
                    var path = Path()
                    let step: CGFloat = 60
                    for x in stride(from: 0, to: size.width + step, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, to: size.height + step, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(Paleta.divisor), lineWidth: 1.5)

                    var diag = Path()
                    diag.move(to: CGPoint(x: 0, y: size.height * 0.3))
                    diag.addLine(to: CGPoint(x: size.width, y: size.height * 0.7))
                    diag.move(to: CGPoint(x: size.width * 0.2, y: 0))
                    diag.addLine(to: CGPoint(x: size.width * 0.8, y: size.height))
                    context.stroke(diag, with: .color(Paleta.bordeSignificante.opacity(0.15)), lineWidth: 3)
                }
            }

            ZStack {
                Circle()
                    .stroke(Paleta.acento.opacity(animar ? 0.0 : 0.5), lineWidth: 2)
                    .frame(width: animar ? 140 : 20, height: animar ? 140 : 20)

                Circle()
                    .fill(Paleta.acento.opacity(0.2))
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(Paleta.acento)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Paleta.fondo, lineWidth: 2))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                animar = true
            }
        }
    }
}
