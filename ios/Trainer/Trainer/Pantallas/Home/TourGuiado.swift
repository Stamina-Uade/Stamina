import SwiftUI
import TrainerCore
import UIKit

// =============================================================================
// "Así funciona Stamina", a lo Clippy: la app DE VERDAD queda visible detrás de
// un velo, la mascota se para en una esquina y habla con un globito al lado de
// la cabeza, con el piquito hacia la boca. Cada paso abre la pestaña real que
// explica (`irA`), así lo que se ve detrás es lo que se está contando.
//
// Lo dibuja `RaizHomeView` encima de todo (barra incluida) mientras
// `tour_visto` es `false`. Mientras está, la app de abajo no se toca: sólo
// responden los botones del globito.
//
// 🪤 Nada se ubica "a ojo" sobre la pantalla de abajo: lo único que se recorta
// del velo es la barra de pestañas, y su marco se MIDE (`MarcoDeLaBarraDelTour`).
// Lo que sí está medido a mano es el dibujo de cada animación (dónde está la
// boca, hasta dónde llega el dibujo a la altura de la cabeza): eso no depende
// de la pantalla, sino de los WebP.
// =============================================================================

/// El marco de la barra de pestañas, para recortarla del velo y apoyar la
/// mascota encima. Lo publica `RaizHomeView` con `anchorPreference`.
struct MarcoDeLaBarraDelTour: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

// MARK: - Los pasos

/// Dónde se para la mascota en un paso.
enum LugarDeLaMascota {
    case abajoALaDerecha
    case abajoALaIzquierda
    /// Arriba del ⚡ del medio de la barra, con el dedo apuntándolo.
    case sobreElRayo
}

/// Un paso del tour: qué pestaña se abre detrás, qué hace la mascota, dónde se
/// para y qué dice (una línea corta).
struct PasoDelTour {
    /// `nil`: se queda en la pestaña que está. Entreno no se abre de verdad
    /// (arranca el GPS y el mapa): la mascota señala el ⚡ de la barra.
    let pestana: PestanaHome?
    let animacion: AnimacionDeMascota
    let lugar: LugarDeLaMascota
    /// La frase del globo. Es una plantilla: donde dice `%@` va el botón del
    /// rayo dibujado en chiquito (`TextoConRayo`), en lugar del emoji ⚡.
    let texto: (String) -> String

    /// En el orden de la barra, y un cierre.
    static var todos: [PasoDelTour] {
        [
            PasoDelTour(pestana: .inicio, animacion: .saludando, lugar: .abajoALaDerecha,
                        texto: { _ in Textos.tourPageHomeBubble }),
            PasoDelTour(pestana: .plan, animacion: .senalandoArriba, lugar: .abajoALaDerecha,
                        texto: { _ in Textos.tourCoachPlanBubble }),
            PasoDelTour(pestana: nil, animacion: .senalandoAbajo, lugar: .sobreElRayo,
                        texto: Textos.tourCoachWorkoutBubble),
            PasoDelTour(pestana: .historial, animacion: .senalandoCostado, lugar: .abajoALaIzquierda,
                        texto: { _ in Textos.tourPageHistoryBubble }),
            PasoDelTour(pestana: .perfil, animacion: .parpadeoOrejas, lugar: .abajoALaIzquierda,
                        texto: { _ in Textos.tourPageProfileBubble }),
            PasoDelTour(pestana: .inicio, animacion: .pulgarArriba, lugar: .abajoALaDerecha,
                        texto: Textos.tourCoachDoneBubble),
        ]
    }
}

// MARK: - El dibujo de cada animación

/// Dónde está cada cosa en el cuadro (cuadrado) de una animación, en
/// fracciones de su lado. Medido sobre los WebP: la boca en el primer cuadro y
/// los bordes del dibujo, en todos los cuadros, desde las orejas hasta un poco
/// más abajo de la boca. El globito no pasa de esos bordes.
struct GeometriaDeMascota {
    let boca: CGPoint
    /// Dónde empiezan las orejas.
    let tope: CGFloat
    let izquierda: CGFloat
    let derecha: CGFloat
    /// Dónde está la mano que señala (sólo `senalandoAbajo`).
    var dedo: CGFloat = 0.5
}

extension AnimacionDeMascota {
    var geometria: GeometriaDeMascota {
        switch self {
        case .saludando:
            return GeometriaDeMascota(boca: CGPoint(x: 0.43, y: 0.36), tope: 0.056, izquierda: 0.27, derecha: 0.83)
        case .senalandoAbajo:
            return GeometriaDeMascota(boca: CGPoint(x: 0.52, y: 0.36), tope: 0.075, izquierda: 0.31, derecha: 0.74,
                                      dedo: 0.34)
        case .senalandoArriba:
            return GeometriaDeMascota(boca: CGPoint(x: 0.53, y: 0.40), tope: 0.064, izquierda: 0.20, derecha: 0.73)
        case .senalandoCostado:
            return GeometriaDeMascota(boca: CGPoint(x: 0.51, y: 0.37), tope: 0.078, izquierda: 0.31, derecha: 0.81)
        case .corriendo:
            return GeometriaDeMascota(boca: CGPoint(x: 0.75, y: 0.36), tope: 0.056, izquierda: 0.42, derecha: 0.85)
        case .medalla:
            return GeometriaDeMascota(boca: CGPoint(x: 0.50, y: 0.40), tope: 0.039, izquierda: 0.28, derecha: 0.77)
        case .pulgarArriba:
            return GeometriaDeMascota(boca: CGPoint(x: 0.58, y: 0.51), tope: 0.039, izquierda: 0.16, derecha: 0.84)
        case .parpadeoOrejas:
            return GeometriaDeMascota(boca: CGPoint(x: 0.51, y: 0.37), tope: 0.083, izquierda: 0.26, derecha: 0.70)
        }
    }
}

// MARK: - Dónde va cada cosa

/// La cuenta de dónde van la mascota, el globito y su piquito, y qué se recorta
/// del velo. Todo en coordenadas de la pantalla entera (sin áreas seguras).
///
/// El globito va al costado de la cabeza, del lado con más lugar, con el borde
/// de abajo un poco más arriba que la boca y el piquito bajando hacia ella. Si
/// al costado no entra (la mascota en el medio, sobre el ⚡), va arriba de la
/// cabeza con el piquito hacia abajo. Nunca pisa el dibujo: queda a
/// `separacion` de sus bordes.
struct DisposicionDelTour {
    /// El globito: el ancho, dónde empieza a la izquierda y dónde termina
    /// abajo. El alto lo pone su texto, y crece hacia arriba.
    struct MarcoDelGlobo: Equatable {
        let minX: CGFloat
        let ancho: CGFloat
        let maxY: CGFloat

        var maxX: CGFloat { minX + ancho }
    }

    let mascota: CGRect
    let globo: MarcoDelGlobo
    /// Dónde termina el piquito.
    let punta: CGPoint
    /// Lo que se ve sin velo: la barra, con el ⚡ que sobresale.
    let hueco: CGRect?
    let globoAlCostado: Bool

    static let separacion: CGFloat = TokensEspaciado.e12
    static let anchoMaximoDelGlobo: CGFloat = TokensEspaciado.e56 * 5
    static let anchoMinimoAlCostado: CGFloat = TokensEspaciado.e56 * 3 + TokensEspaciado.e22
    /// Cuánto sobresale el ⚡ por arriba de la barra (`BarraDePestanas`).
    static let sobresaleElRayo: CGFloat = TokensEspaciado.e16
    /// Sólo si la barra todavía no se midió.
    static let altoEstimadoDeLaBarra: CGFloat = TokensEspaciado.e56 + TokensEspaciado.e34

    /// El alto de la mascota: 168 pt, o menos en un teléfono angosto.
    static func altoDeLaMascota(anchoDePantalla: CGFloat) -> CGFloat {
        min(TokensEspaciado.e56 * 3, anchoDePantalla * 0.42)
    }

    /// El piquito medido desde la esquina de abajo a la izquierda del globito,
    /// que es como lo dibuja `FormaDeGloboConPunta`.
    var puntaEnElGlobo: CGPoint {
        CGPoint(x: punta.x - globo.minX, y: punta.y - globo.maxY)
    }

    init(lugar: LugarDeLaMascota, geometria g: GeometriaDeMascota,
         tamano: CGSize, margenes: EdgeInsets, barra: CGRect?) {
        let izquierdaLibre = margenes.leading + TokensEspaciado.e16
        let derechaLibre = tamano.width - margenes.trailing - TokensEspaciado.e16
        let alto = Self.altoDeLaMascota(anchoDePantalla: tamano.width)
        let sobresale = Self.sobresaleElRayo

        // La mascota, parada sobre la barra (y sobre el ⚡, que sobresale).
        let techo = barra.map { $0.minY - sobresale }
            ?? tamano.height - margenes.bottom - Self.altoEstimadoDeLaBarra
        let x: CGFloat
        switch lugar {
        case .abajoALaDerecha:
            x = derechaLibre - alto
        case .abajoALaIzquierda:
            x = izquierdaLibre
        case .sobreElRayo:
            let rayo = barra?.midX ?? tamano.width / 2
            x = min(max(rayo - alto * g.dedo, izquierdaLibre), derechaLibre - alto)
        }
        let mascota = CGRect(x: x, y: techo - TokensEspaciado.e4 - alto, width: alto, height: alto)
        self.mascota = mascota
        hueco = barra.map {
            CGRect(x: $0.minX + TokensEspaciado.e8, y: $0.minY - sobresale,
                   width: max(0, $0.width - TokensEspaciado.e16), height: $0.height + sobresale)
        }

        // El globito.
        let boca = CGPoint(x: mascota.minX + alto * g.boca.x, y: mascota.minY + alto * g.boca.y)
        let bordeIzquierdo = mascota.minX + alto * g.izquierda
        let bordeDerecho = mascota.minX + alto * g.derecha
        let libreALaIzquierda = bordeIzquierdo - Self.separacion - izquierdaLibre
        let libreALaDerecha = derechaLibre - (bordeDerecho + Self.separacion)

        if max(libreALaIzquierda, libreALaDerecha) >= Self.anchoMinimoAlCostado {
            globoAlCostado = true
            let maxY = boca.y - Self.separacion
            if libreALaIzquierda >= libreALaDerecha {
                let ancho = min(libreALaIzquierda, Self.anchoMaximoDelGlobo)
                globo = MarcoDelGlobo(minX: bordeIzquierdo - Self.separacion - ancho, ancho: ancho, maxY: maxY)
                punta = CGPoint(x: bordeIzquierdo - TokensEspaciado.e2, y: boca.y)
            } else {
                let ancho = min(libreALaDerecha, Self.anchoMaximoDelGlobo)
                globo = MarcoDelGlobo(minX: bordeDerecho + Self.separacion, ancho: ancho, maxY: maxY)
                punta = CGPoint(x: bordeDerecho + TokensEspaciado.e2, y: boca.y)
            }
        } else {
            globoAlCostado = false
            let ancho = max(0, min(derechaLibre - izquierdaLibre, Self.anchoMaximoDelGlobo))
            let punta = CGPoint(x: boca.x, y: mascota.minY + alto * g.tope - TokensEspaciado.e4)
            let minX = min(max(punta.x - ancho / 2, izquierdaLibre), derechaLibre - ancho)
            self.punta = punta
            globo = MarcoDelGlobo(minX: minX, ancho: ancho, maxY: punta.y - Self.separacion)
        }
    }
}

// MARK: - La vista

/// El tour encima de la app: velo, mascota y globito. `tamano` y `margenes` son
/// los de la pantalla entera (quien lo dibuja ignora las áreas seguras).
struct TourGuiado: View {
    let tamano: CGSize
    let margenes: EdgeInsets
    /// El marco medido de la barra de pestañas, en las mismas coordenadas.
    let marcoDeLaBarra: CGRect?
    /// Abre de verdad una pestaña de la app, detrás del velo.
    let irA: (PestanaHome) -> Void
    /// "Empezar" o "Saltar": quien lo dibuja lo saca y anota que ya se vio.
    let alTerminar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var indice = 0

    private let pasos = PasoDelTour.todos

    private var paso: PasoDelTour { pasos[min(max(indice, 0), pasos.count - 1)] }
    private var esElUltimo: Bool { indice >= pasos.count - 1 }

    var body: some View {
        let disposicion = DisposicionDelTour(lugar: paso.lugar, geometria: paso.animacion.geometria,
                                             tamano: tamano, margenes: margenes, barra: marcoDeLaBarra)
        return ZStack(alignment: .topLeading) {
            bloqueo

            VeloConHueco(hueco: disposicion.hueco, radio: TokensRadio.cardDestacada + TokensEspaciado.e8)
                .fill(Paleta.veloFoto, style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // Un paso, una mascota y un globito nuevos (`.id`): se funden, no se
            // deslizan de una esquina a la otra.
            mascota(disposicion)
                .id(indice)
                .transition(.opacity)

            globo(disposicion)
                .id(indice)
                .transition(.opacity)
        }
        .frame(width: tamano.width, height: tamano.height)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear { entrar(en: 0) }
    }

    // MARK: Las capas

    /// Se come todos los toques: la app de abajo no responde durante el tour.
    private var bloqueo: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {}
            .accessibilityHidden(true)
    }

    private func mascota(_ disposicion: DisposicionDelTour) -> some View {
        MascotaAnimada(paso.animacion, alto: disposicion.mascota.height)
            .frame(width: disposicion.mascota.width, height: disposicion.mascota.height)
            .position(x: disposicion.mascota.midX, y: disposicion.mascota.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// El globito, anclado por su esquina de abajo a la izquierda: el alto lo
    /// pone el texto y crece hacia arriba, lejos de la mascota.
    private func globo(_ disposicion: DisposicionDelTour) -> some View {
        let forma = FormaDeGloboConPunta(punta: disposicion.puntaEnElGlobo)
        return contenidoDelGlobo
            .padding(TokensEspaciado.e16)
            .frame(width: disposicion.globo.ancho, alignment: .leading)
            .background(forma.fill(Paleta.superficieAlterna))
            .overlay(forma.stroke(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
            .padding(.leading, max(0, disposicion.globo.minX))
            .padding(.bottom, max(0, tamano.height - disposicion.globo.maxY))
            .frame(width: tamano.width, height: tamano.height, alignment: .bottomLeading)
    }

    private var contenidoDelGlobo: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            Text(verbatim: "\(indice + 1)/\(pasos.count)")
                .estilo(.etiquetaSeccion, color: Paleta.textoAcento)
                .accessibilityLabel(Textos.tourPageOf(indice + 1, pasos.count))
            TextoConRayo.texto(paso.texto, alto: TokensTipografia.tituloCardTamano * 1.15)
                .estilo(.tituloCard)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(TextoConRayo.etiqueta(paso.texto))
                .accessibilityAddTraits(.isHeader)
            botones
        }
    }

    /// "Saltar" a la izquierda y "Siguiente" a la derecha; si no entran en una
    /// fila (letra muy grande), uno arriba del otro.
    private var botones: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: TokensEspaciado.e8) {
                botonSaltar
                Spacer(minLength: TokensEspaciado.e8)
                botonSiguiente
            }
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                botonSiguiente
                botonSaltar
            }
        }
    }

    private var botonSiguiente: some View {
        Button(action: avanzar) {
            Text(esElUltimo ? Textos.commonStart : Textos.commonNext)
                .estilo(.tituloCard, color: Paleta.sobreAcento)
                .lineLimit(1)
                .padding(.horizontal, TokensEspaciado.e20)
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                .background(Capsule().fill(Paleta.acento))
                .contentShape(Capsule())
        }
        .buttonStyle(EstiloPresionado())
    }

    @ViewBuilder
    private var botonSaltar: some View {
        if !esElUltimo {
            Button {
                Haptico.toque()
                alTerminar()
            } label: {
                Text(Textos.commonSkip)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .lineLimit(1)
                    .padding(.horizontal, TokensEspaciado.e4)
                    .objetivoTactil()
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityHint(Textos.tourCloseHint)
        }
    }

    // MARK: Pasar de paso

    private func avanzar() {
        guard !esElUltimo else {
            Haptico.exito()
            alTerminar()
            return
        }
        Haptico.seleccion()
        let siguiente = indice + 1
        if movimientoReducido {
            indice = siguiente
        } else {
            withAnimation(.easeInOut(duration: TokensMovimiento.media)) { indice = siguiente }
        }
        entrar(en: siguiente)
    }

    /// Abre la pestaña del paso detrás del velo, avisa a VoiceOver que cambió
    /// todo y deja leído el WebP del paso que viene.
    private func entrar(en nuevo: Int) {
        guard pasos.indices.contains(nuevo) else { return }
        if let pestana = pasos[nuevo].pestana { irA(pestana) }
        UIAccessibility.post(notification: .screenChanged, argument: nil)
        precargar(nuevo + 1)
    }

    /// Sólo el WebP comprimido y sus demoras (≈ 1,3 MB): los cuadros se
    /// decodifican de a uno, cuando toca mostrarlos.
    private func precargar(_ indiceQueViene: Int) {
        guard pasos.indices.contains(indiceQueViene) else { return }
        let animacion = pasos[indiceQueViene].animacion
        Task(priority: .utility) {
            _ = await AlmacenDeMascota.compartido.datos(de: animacion)
        }
    }
}

// MARK: - Las formas

/// El velo: toda la pantalla menos el hueco (se pinta con `eoFill`).
private struct VeloConHueco: Shape {
    let hueco: CGRect?
    let radio: CGFloat

    func path(in rect: CGRect) -> Path {
        var trazo = Path(rect)
        if let hueco {
            trazo.addRoundedRect(in: hueco, cornerSize: CGSize(width: radio, height: radio), style: .continuous)
        }
        return trazo
    }
}

/// El globito del tour: un rectángulo redondeado con un piquito que sale del
/// borde de abajo —lo más cerca de la punta que dejan las esquinas— y termina
/// en `punta`, en un solo trazo (como `FormaDeBocadillo`). La punta se mide
/// desde la esquina de abajo a la izquierda y puede caer fuera del rectángulo:
/// abajo y a un costado, hacia la boca de la mascota.
struct FormaDeGloboConPunta: Shape {
    var punta: CGPoint

    func path(in rect: CGRect) -> Path {
        let radio = max(0, min(TokensRadio.card, rect.height / 2, rect.width / 2))
        let mitad = max(0, min(FormaDeBocadillo.anchoDeCola / 2, rect.width / 2 - radio))
        let fin = CGPoint(x: rect.minX + punta.x, y: rect.maxY + punta.y)
        let centro = min(max(fin.x, rect.minX + radio + mitad), rect.maxX - radio - mitad)

        var trazo = Path()
        trazo.move(to: CGPoint(x: rect.minX + radio, y: rect.minY))
        trazo.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radio)
        trazo.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radio)
        // El piquito sólo si la punta cae abajo del globito.
        if fin.y > rect.maxY {
            trazo.addLine(to: CGPoint(x: centro + mitad, y: rect.maxY))
            trazo.addLine(to: fin)
            trazo.addLine(to: CGPoint(x: centro - mitad, y: rect.maxY))
        }
        trazo.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radio)
        trazo.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radio)
        trazo.closeSubpath()
        return trazo
    }
}
