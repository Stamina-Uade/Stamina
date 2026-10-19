import SwiftUI
import TrainerCore

// =============================================================================
// La mascota de Stamina (el serval de remera negra) y su globito de diálogo.
//
// Tres poses, cada una para un momento:
// - `saludo`: dar la bienvenida y explicar.
// - `corriendo`: entrenamientos y progreso.
// - `medalla`: logros y cierres.
//
// Se mueve poquito y en loop mientras está a la vista (flota, trota o respira);
// con "Reducir movimiento" queda quieta. Las imágenes sólo existen en el target
// del iPhone: estas vistas no se usan en el reloj.
// =============================================================================

enum PoseDeMascota {
    case saludo
    case corriendo
    case medalla

    var recurso: String {
        switch self {
        case .saludo: return "MascotaSaludo"
        case .corriendo: return "MascotaCorriendo"
        case .medalla: return "MascotaMedalla"
        }
    }

    /// Desde dónde "salta" al aparecer: la de la medalla, más, porque festeja.
    fileprivate var escalaInicial: CGFloat {
        switch self {
        case .saludo, .corriendo: return 0.94
        case .medalla: return 0.82
        }
    }

    /// El loop en reposo: flotar lento, trotar rápido, respirar.
    fileprivate var animacionEnReposo: Animation {
        switch self {
        case .saludo: return .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        case .corriendo: return .easeInOut(duration: 0.38).repeatForever(autoreverses: true)
        case .medalla: return .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
        }
    }

    fileprivate var desplazamientoEnReposo: CGFloat {
        switch self {
        case .saludo: return -TokensEspaciado.e6
        case .corriendo: return -TokensEspaciado.e8
        case .medalla: return -TokensEspaciado.e4
        }
    }

    /// Corriendo se inclina un poco hacia adelante en cada zancada.
    fileprivate var giroEnReposo: (desde: Double, hasta: Double) {
        switch self {
        case .corriendo: return (desde: -3, hasta: 2)
        case .saludo, .medalla: return (desde: 0, hasta: 0)
        }
    }

    fileprivate var respiroEnReposo: CGFloat {
        switch self {
        case .medalla: return 1.035
        case .saludo, .corriendo: return 1
        }
    }
}

// MARK: - La mascota

/// La mascota sola, con un halo suave del acento detrás. Ocupa el ancho que
/// tenga y hasta `altoMaximo` de alto, sin deformarse.
struct Mascota: View {
    let pose: PoseDeMascota
    var altoMaximo: CGFloat = TokensEspaciado.e56 * 4
    /// Si es la que se está mirando: al pasar a `true` hace el "pop" de entrada
    /// y arranca el loop. Al pasar a `false` se achica de vuelta, para volver a
    /// saltar la próxima vez.
    var activa: Bool = true

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var aparecio = false
    @State private var enMovimiento = false

    var body: some View {
        Image(pose.recurso)
            .resizable()
            .scaledToFit()
            // El pop de entrada va con su propio resorte: la animación de más
            // afuera (el loop) no lo pisa, gana la más cercana.
            .scaleEffect(escalaDeAparicion, anchor: .bottom)
            .animation(movimientoReducido ? nil : .spring(response: 0.45, dampingFraction: 0.55),
                       value: aparecio)
            .scaleEffect(enMovimiento ? pose.respiroEnReposo : 1, anchor: .bottom)
            .rotationEffect(.degrees(enMovimiento ? pose.giroEnReposo.hasta : pose.giroEnReposo.desde),
                            anchor: .bottom)
            .offset(y: enMovimiento ? pose.desplazamientoEnReposo : 0)
            .animation(movimientoReducido ? nil : pose.animacionEnReposo, value: enMovimiento)
            .frame(maxWidth: .infinity, maxHeight: altoMaximo)
            .background(brillo)
            .accessibilityHidden(true)
            .onAppear {
                if activa { arrancar() }
            }
            .onChange(of: activa) { ahora in
                if ahora {
                    arrancar()
                } else {
                    aparecio = false
                }
            }
            .onDisappear(perform: detener)
    }

    private var escalaDeAparicion: CGFloat {
        aparecio || movimientoReducido ? 1 : pose.escalaInicial
    }

    /// El halo del acento: un degradé radial que se apaga antes del borde, para
    /// que no se vea el corte del rectángulo.
    private var brillo: some View {
        GeometryReader { geo in
            RadialGradient(colors: [Paleta.acentoBrillo, Color.clear],
                           center: .center, startRadius: 0,
                           endRadius: min(geo.size.width, geo.size.height) * 0.5)
        }
        .scaleEffect(1.3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func arrancar() {
        guard !movimientoReducido else { return }
        aparecio = true
        if !enMovimiento { enMovimiento = true }
    }

    /// Al irse de pantalla se frena sin animación: si no, el loop seguiría
    /// "volviendo" para siempre.
    private func detener() {
        var quieto = Transaction()
        quieto.disablesAnimations = true
        withTransaction(quieto) {
            aparecio = false
            enMovimiento = false
        }
    }
}

// MARK: - El globito

/// Para qué lado sale el piquito del globito: hacia donde está la mascota.
enum LadoDeLaCola {
    case arriba
    case abajo
}

/// Un globito de diálogo: superficie alterna, borde finito y un piquito que
/// apunta a la mascota. Pensado para UNA línea corta (≈70 caracteres).
struct Bocadillo<Contenido: View>: View {
    private let cola: LadoDeLaCola
    private let contenido: Contenido

    init(cola: LadoDeLaCola = .abajo, @ViewBuilder contenido: () -> Contenido) {
        self.cola = cola
        self.contenido = contenido()
    }

    var body: some View {
        let ladoDeLaCola: Edge.Set = cola == .arriba ? .top : .bottom
        return contenido
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.vertical, TokensEspaciado.e12)
            .padding(ladoDeLaCola, FormaDeBocadillo.altoDeCola)
            .background(FormaDeBocadillo(cola: cola).fill(Paleta.superficieAlterna))
            .overlay(FormaDeBocadillo(cola: cola).stroke(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
    }
}

extension Bocadillo where Contenido == TextoDeBocadillo {
    /// El caso de siempre: una línea de texto.
    init(_ texto: String, cola: LadoDeLaCola = .abajo) {
        self.init(cola: cola) { TextoDeBocadillo(texto: texto) }
    }
}

/// El texto de un globito: grande, pesado y centrado.
struct TextoDeBocadillo: View {
    let texto: String

    var body: some View {
        Text(texto)
            .estilo(.tituloCardGrande)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// El contorno del globito: un rectángulo redondeado con el piquito en el
/// medio del lado de arriba o del de abajo, en un solo trazo (así el borde no
/// se corta donde se juntan).
struct FormaDeBocadillo: Shape {
    var cola: LadoDeLaCola

    static let altoDeCola: CGFloat = TokensEspaciado.e10
    static let anchoDeCola: CGFloat = TokensEspaciado.e20

    func path(in rect: CGRect) -> Path {
        let arriba = cola == .arriba ? rect.minY + Self.altoDeCola : rect.minY
        let abajo = cola == .abajo ? rect.maxY - Self.altoDeCola : rect.maxY
        let radio = max(0, min(TokensRadio.card, (abajo - arriba) / 2, rect.width / 2))
        let medio = rect.midX
        let mitad = max(0, min(Self.anchoDeCola / 2, rect.width / 2 - radio))

        var trazo = Path()
        trazo.move(to: CGPoint(x: rect.minX + radio, y: arriba))
        if cola == .arriba {
            trazo.addLine(to: CGPoint(x: medio - mitad, y: arriba))
            trazo.addLine(to: CGPoint(x: medio, y: rect.minY))
            trazo.addLine(to: CGPoint(x: medio + mitad, y: arriba))
        }
        trazo.addArc(tangent1End: CGPoint(x: rect.maxX, y: arriba),
                     tangent2End: CGPoint(x: rect.maxX, y: abajo), radius: radio)
        trazo.addArc(tangent1End: CGPoint(x: rect.maxX, y: abajo),
                     tangent2End: CGPoint(x: rect.minX, y: abajo), radius: radio)
        if cola == .abajo {
            trazo.addLine(to: CGPoint(x: medio + mitad, y: abajo))
            trazo.addLine(to: CGPoint(x: medio, y: rect.maxY))
            trazo.addLine(to: CGPoint(x: medio - mitad, y: abajo))
        }
        trazo.addArc(tangent1End: CGPoint(x: rect.minX, y: abajo),
                     tangent2End: CGPoint(x: rect.minX, y: arriba), radius: radio)
        trazo.addArc(tangent1End: CGPoint(x: rect.minX, y: arriba),
                     tangent2End: CGPoint(x: rect.maxX, y: arriba), radius: radio)
        trazo.closeSubpath()
        return trazo
    }
}

// MARK: - Mascota + globito

/// La mascota hablando: el globito arriba (piquito hacia abajo) o abajo
/// (piquito hacia arriba). Al activarse, la mascota sube con un fundido y el
/// globito "brota" desde el piquito un instante después. Con "Reducir
/// movimiento" aparece todo de una.
struct MascotaConBocadillo: View {
    let pose: PoseDeMascota
    let texto: String
    var altoMaximo: CGFloat = TokensEspaciado.e56 * 4
    var activa: Bool = true
    var bocadilloArriba: Bool = true
    /// El texto del globito es el título del momento: VoiceOver lo anuncia así.
    var esEncabezado: Bool = true

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var entro = false

    var body: some View {
        VStack(spacing: TokensEspaciado.e10) {
            if bocadilloArriba {
                globito
                mascota
            } else {
                mascota
                globito
            }
        }
        .onAppear { entro = activa }
        .onChange(of: activa) { entro = $0 }
    }

    private var visible: Bool { entro || movimientoReducido }

    private var mascota: some View {
        Mascota(pose: pose, altoMaximo: altoMaximo, activa: activa)
            .layoutPriority(1)
            .offset(y: visible ? 0 : TokensEspaciado.e20)
            .opacity(visible ? 1 : 0)
            .animation(movimientoReducido ? nil : .easeOut(duration: TokensMovimiento.lenta), value: entro)
    }

    private var globito: some View {
        Bocadillo(texto, cola: bocadilloArriba ? .abajo : .arriba)
            .accessibilityAddTraits(esEncabezado ? .isHeader : [])
            .scaleEffect(visible ? 1 : 0.85, anchor: bocadilloArriba ? .bottom : .top)
            .opacity(visible ? 1 : 0)
            .animation(movimientoReducido
                       ? nil
                       : Animation.spring(response: 0.4, dampingFraction: 0.7).delay(TokensMovimiento.rapida * 0.6),
                       value: entro)
    }
}
