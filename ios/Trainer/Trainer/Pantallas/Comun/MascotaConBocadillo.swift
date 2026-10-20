import SwiftUI
import TrainerCore

// =============================================================================
// La mascota de Stamina (el serval de remera negra) y su globito de diálogo.
//
// Tres poses, cada una para un momento:
// - `saludo`: dar la bienvenida y explicar (animación `saludando`).
// - `corriendo`: entrenamientos y progreso (`corriendo`).
// - `medalla`: logros y cierres (`medalla`, una sola pasada que termina con la
//   medalla en alto).
//
// Ronda 6: la mascota se MUEVE (ver `MascotaAnimada`). Su lugar no cambia:
// entra una vez, con un fundido y un leve crecimiento, cuando aparece (o cuando
// su página pasa a ser la que se mira). Con "Reducir movimiento" no hay entrada
// ni animación: queda el primer cuadro. Las animaciones (y las poses en PNG,
// que quedan de respaldo) sólo existen en el target del iPhone: estas vistas
// no se usan en el reloj.
// =============================================================================

enum PoseDeMascota {
    case saludo
    case corriendo
    case medalla

    /// La pose quieta en PNG: el respaldo si la animación no se puede leer.
    var recurso: String {
        switch self {
        case .saludo: return "MascotaSaludo"
        case .corriendo: return "MascotaCorriendo"
        case .medalla: return "MascotaMedalla"
        }
    }

    /// La animación que la reemplaza.
    var animacion: AnimacionDeMascota {
        switch self {
        case .saludo: return .saludando
        case .corriendo: return .corriendo
        case .medalla: return .medalla
        }
    }

    /// La medalla se pasa una vez y queda en alto; las otras, en loop.
    var repite: Bool { self != .medalla }

    /// Desde qué tamaño crece al entrar. Apenas: es una entrada, no un salto.
    fileprivate var escalaInicial: CGFloat {
        switch self {
        case .saludo, .corriendo: return 0.94
        case .medalla: return 0.9
        }
    }
}

// MARK: - La mascota

/// La mascota sola, con un halo suave del acento detrás. Ocupa el ancho que
/// tenga y hasta `altoMaximo` de alto, sin deformarse.
struct Mascota: View {
    let pose: PoseDeMascota
    var altoMaximo: CGFloat = TokensEspaciado.e56 * 4
    /// Si es la que se está mirando: al pasar a `true` hace la entrada (una
    /// sola vez). Al pasar a `false` no hace nada: quien la contiene la oculta.
    var activa: Bool = true
    /// Dada vuelta en espejo. La de `saludo` apoya el codo a la derecha:
    /// espejada lo apoya a la izquierda.
    var espejada: Bool = false

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var entro = false

    var body: some View {
        // Sólo se reproduce la que se mira: las ocultas cargan un cuadro y nada más.
        MascotaAnimada(pose.animacion, loop: pose.repite, alto: altoMaximo, reproducir: activa)
            .scaleEffect(x: espejada ? -1 : 1, y: 1)
            .scaleEffect(visible ? 1 : pose.escalaInicial, anchor: .bottom)
            .opacity(visible ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: altoMaximo)
            .background(brillo)
            .accessibilityHidden(true)
            .onAppear {
                if activa { entrar() }
            }
            .onChange(of: activa) { ahora in
                if ahora { entrar() }
            }
    }

    private var visible: Bool { entro || movimientoReducido }

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

    /// La entrada: vuelve al tamaño chico sin animar y, en la vuelta siguiente,
    /// crece y aparece. 🪤 Las dos cosas en la misma vuelta se funden en un solo
    /// cambio y no se anima nada: por eso el `async`.
    private func entrar() {
        guard !movimientoReducido else {
            entro = true
            return
        }
        var sinAnimar = Transaction()
        sinAnimar.disablesAnimations = true
        withTransaction(sinAnimar) { entro = false }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: TokensMovimiento.lenta)) { entro = true }
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
    private let posicionDeCola: CGFloat
    private let contenido: Contenido

    /// - Parameter posicionDeCola: dónde sale el piquito a lo ancho, de 0
    ///   (izquierda) a 1 (derecha). Por defecto, en el medio.
    init(cola: LadoDeLaCola = .abajo, posicionDeCola: CGFloat = 0.5,
         @ViewBuilder contenido: () -> Contenido) {
        self.cola = cola
        self.posicionDeCola = posicionDeCola
        self.contenido = contenido()
    }

    var body: some View {
        let ladoDeLaCola: Edge.Set = cola == .arriba ? .top : .bottom
        return contenido
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.vertical, TokensEspaciado.e12)
            .padding(ladoDeLaCola, FormaDeBocadillo.altoDeCola)
            .background(FormaDeBocadillo(cola: cola, posicionDeCola: posicionDeCola).fill(Paleta.superficieAlterna))
            .overlay(FormaDeBocadillo(cola: cola, posicionDeCola: posicionDeCola)
                .stroke(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
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
/// lado de arriba o en el de abajo (en el medio, o donde diga
/// `posicionDeCola`), en un solo trazo: así el borde no se corta donde se juntan.
struct FormaDeBocadillo: Shape {
    var cola: LadoDeLaCola
    /// De 0 (izquierda) a 1 (derecha). Nunca se mete en las esquinas redondeadas.
    var posicionDeCola: CGFloat = 0.5

    static let altoDeCola: CGFloat = TokensEspaciado.e10
    static let anchoDeCola: CGFloat = TokensEspaciado.e20

    func path(in rect: CGRect) -> Path {
        let arriba = cola == .arriba ? rect.minY + Self.altoDeCola : rect.minY
        let abajo = cola == .abajo ? rect.maxY - Self.altoDeCola : rect.maxY
        let radio = max(0, min(TokensRadio.card, (abajo - arriba) / 2, rect.width / 2))
        let mitad = max(0, min(Self.anchoDeCola / 2, rect.width / 2 - radio))
        let margen = radio + mitad
        let deseado = rect.minX + rect.width * min(max(posicionDeCola, 0), 1)
        let medio = min(max(deseado, rect.minX + margen), rect.maxX - margen)

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
/// (piquito hacia arriba). Al activarse, la mascota entra con un fundido (ver
/// `Mascota`) y el globito "brota" desde el piquito un instante después; después
/// todo queda quieto. Con "Reducir movimiento" aparece todo de una.
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
    }

    private var globito: some View {
        Bocadillo(texto, cola: bocadilloArriba ? .abajo : .arriba)
            .accessibilityAddTraits(esEncabezado ? .isHeader : [])
            .scaleEffect(visible ? 1 : 0.85, anchor: bocadilloArriba ? .bottom : .top)
            .opacity(visible ? 1 : 0)
            .animation(movimientoReducido
                       ? nil
                       : Animation.easeOut(duration: TokensMovimiento.media).delay(TokensMovimiento.rapida * 0.6),
                       value: entro)
    }
}
