import SwiftUI
import TrainerCore

/// `bienvenida` — carousel de 3 fotos con autoplay, que también se pasa
/// deslizando, la marca, y las dos salidas: crear cuenta o entrar.
///
/// Las fotos van **empaquetadas** y no se piden a la red. El diseño las trae de
/// Unsplash en caliente y `design/ESPECIFICACION.md` §8.1 marca por qué eso no
/// sirve: es la primera pantalla de una app offline-primero (AGENTS.md §6), y
/// sin señal quedaría en negro.
struct BienvenidaView: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido

    @State private var actual = 0
    @State private var reloj: Timer?
    /// Si hay un dedo deslizando. Mientras tanto el autoplay espera: si la foto
    /// cambiara sola en medio del gesto, al soltar se saltearía una. Es
    /// `@GestureState` y no `@State` porque vuelve a `false` también cuando el
    /// sistema cancela el gesto, que no pasa por `onEnded`.
    @GestureState private var deslizando = false

    private struct Foto {
        let recurso: String
        let titulo: String
        let texto: String
        let descripcion: String
    }

    private var fotos: [Foto] {
        [
            Foto(recurso: "BienvenidaAmanecer", titulo: Textos.bienvenidaSlide1Titulo,
                 texto: Textos.bienvenidaSlide1Texto, descripcion: Textos.bienvenidaSlide1Foto),
            Foto(recurso: "BienvenidaRuta", titulo: Textos.bienvenidaSlide2Titulo,
                 texto: Textos.bienvenidaSlide2Texto, descripcion: Textos.bienvenidaSlide2Foto),
            Foto(recurso: "BienvenidaMontana", titulo: Textos.bienvenidaSlide3Titulo,
                 texto: Textos.bienvenidaSlide3Texto, descripcion: Textos.bienvenidaSlide3Foto),
        ]
    }

    var body: some View {
        // La foto va a sangre —también bajo la barra de estado, como el diseño—
        // y el pie se queda DENTRO del área segura.
        //
        // 🪤 La foto va como FONDO y no como hermana en un ZStack. Con
        // `scaledToFill` la imagen reporta un tamaño mayor que la pantalla, y en
        // un ZStack eso se propaga: el pie recibía más ancho del que hay y se
        // cortaba por los dos lados. `background` no participa del layout.
        pie
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background(carousel.ignoresSafeArea())
            .background(Paleta.fondo)
            // Se desliza en toda la pantalla y no sólo sobre la foto: el pie ocupa
            // la mitad de abajo, que es donde está el pulgar.
            //
            // 🪤 `highPriorityGesture` y no `gesture`. Con `gesture` gana el botón:
            // un deslizamiento que empezaba arriba de «Crear cuenta gratis» no
            // pasaba de foto (lo cazó el test de UI). Con prioridad pasa lo de
            // cualquier carousel: si el dedo se mueve, pasa de foto y el botón no
            // se dispara; un toque que no se mueve sigue siendo del botón.
            .contentShape(Rectangle())
            .highPriorityGesture(deslizar)
            .onChange(of: deslizando) { enCurso in
                if enCurso { pausarAutoplay() } else { arrancarAutoplay() }
            }
            .onAppear(perform: arrancarAutoplay)
            .onDisappear(perform: pausarAutoplay)
    }

    private var carousel: some View {
        ZStack {
            ForEach(Array(fotos.enumerated()), id: \.offset) { indice, foto in
                // Rediseño 2026-10: foto en blanco y negro, como las tarjetas
                // héroe del mockup. El rosa queda para lo que importa.
                Image(foto.recurso)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1)
                    .opacity(indice == actual ? 1 : 0)
                    .accessibilityLabel(foto.descripcion)
            }
            veloDeLaFoto
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(movimientoReducido ? nil : .easeInOut(duration: TokensMovimiento.muyLenta),
                   value: actual)
        .accessibilityElement(children: .contain)
    }

    /// El velo: oscurece la foto entera y la funde con el fondo abajo, donde va
    /// el texto. Abajo a la derecha, el halo rosa de la marca.
    private var veloDeLaFoto: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Paleta.fondo.opacity(0.35), location: 0.0),
                    .init(color: Paleta.fondo.opacity(0.15), location: 0.25),
                    .init(color: Paleta.fondo.opacity(0.85), location: 0.55),
                    .init(color: Paleta.fondo, location: 0.72),
                    .init(color: Paleta.fondo, location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [Paleta.acentoProfundo, Color.clear],
                           center: .bottomTrailing, startRadius: 0,
                           endRadius: TokensEspaciado.e56 * 6)
        }
        .accessibilityHidden(true)
    }

    private var pie: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
            HStack(spacing: TokensEspaciado.e9) {
                LogoApp()
                Text(MarcaApp.nombre).estilo(.marca, color: Paleta.textoAcento)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MarcaApp.nombre)

            // 🪤 Los títulos y los textos de las tres fotos no miden lo mismo, y el
            // pie está pegado abajo: con uno de dos renglones al lado de uno de uno,
            // cada cambio de foto movía la marca y el título. Cada bloque se reserva
            // el alto del más alto de los tres —al tamaño de letra que tenga puesto
            // la persona, sin cortar nada— dibujando los tres debajo del que se ve.
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                conElAltoDelMasAlto(fotos.map(\.titulo)) { titulo in
                    Text(titulo)
                        .estilo(.display)
                        .fixedSize(horizontal: false, vertical: true)
                }
                conElAltoDelMasAlto(fotos.map(\.texto)) { texto in
                    Text(texto)
                        .estilo(.cuerpoDestacado, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(movimientoReducido ? nil : .easeInOut(duration: TokensMovimiento.lenta),
                       value: actual)

            indicadores

            VStack(spacing: TokensEspaciado.e8) {
                BotonPrimario(Textos.bienvenidaCrearCuenta) { flujo.ir(a: .regCorreo) }
                BotonTexto(Textos.bienvenidaYaTengoCuenta) { flujo.ir(a: .login) }
            }
        }
        .padding(.horizontal, TokensEspaciado.e22)
        .padding(.bottom, TokensEspaciado.e12)
    }

    /// El de la foto actual, encima de los de las tres fotos, ocultos: el bloque
    /// mide lo que el más alto. Los ocultos sólo ocupan lugar: no se ven, no se
    /// tocan y VoiceOver no los lee.
    private func conElAltoDelMasAlto<Contenido: View>(
        _ valores: [String],
        @ViewBuilder _ dibujar: @escaping (String) -> Contenido
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(valores.indices, id: \.self) { indice in
                dibujar(valores[indice])
                    .hidden()
                    .accessibilityHidden(true)
            }
            dibujar(valores[actual])
        }
    }

    /// El indicador del carousel del diseño mide **3 px de alto y es clicable**:
    /// el peor objetivo táctil de todo el archivo (`ESPECIFICACION.md` §9.2).
    /// Se dibuja igual y responde en 48.
    private var indicadores: some View {
        HStack(spacing: TokensEspaciado.e6) {
            ForEach(Array(fotos.enumerated()), id: \.offset) { indice, _ in
                Button {
                    actual = indice
                    arrancarAutoplay()
                } label: {
                    // La actual es más larga y rosa, con halo: no se distingue
                    // sólo por color.
                    Capsule()
                        .fill(indice == actual ? Paleta.acento : Paleta.bordeSignificante)
                        .frame(width: indice == actual ? TokensEspaciado.e34 : TokensEspaciado.e16,
                               height: TokensEspaciado.e4)
                        .shadow(color: indice == actual ? Paleta.acentoBrillo : Color.clear,
                                radius: TokensEspaciado.e4)
                        .objetivoTactil()
                }
                .accessibilityLabel(Textos.bienvenidaIrAFoto(indice + 1, fotos.count))
                .accessibilityAddTraits(indice == actual ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Deslizar pasa de foto: hacia la izquierda la siguiente, hacia la derecha la
    /// anterior. Cambia con el mismo fundido que el autoplay y los indicadores
    /// —sin fundido con "reducir movimiento", igual que ellos—, y al soltar el
    /// autoplay vuelve a contar los 4,2 s desde cero.
    private var deslizar: some Gesture {
        DragGesture()
            .updating($deslizando) { _, enCurso, _ in enCurso = true }
            .onEnded { gesto in
                actual = Self.fotoTrasDeslizar(desde: actual, de: fotos.count,
                                               prediccion: gesto.predictedEndTranslation)
            }
    }

    /// A qué foto lleva un deslizamiento. En las puntas da la vuelta, como el
    /// autoplay. Un gesto más vertical que horizontal, o que no recorre al menos
    /// un objetivo táctil, deja la foto donde está.
    ///
    /// Se mira la traslación PREDICHA y no la recorrida: un gesto corto pero
    /// rápido también pasa de foto, como en los carousels del sistema. Android
    /// llega a lo mismo con la velocidad de fling.
    static func fotoTrasDeslizar(desde actual: Int, de total: Int, prediccion: CGSize) -> Int {
        let horizontal = prediccion.width
        guard total > 1,
              abs(horizontal) > abs(prediccion.height),
              abs(horizontal) >= TokensTamano.objetivoTactilMinimo
        else { return actual }
        let paso = horizontal < 0 ? 1 : -1
        return (actual + paso + total) % total
    }

    /// Autoplay de 4200 ms, como el diseño. Con "reducir movimiento" activado
    /// **no arranca**: un carousel que se mueve solo es exactamente lo que ese
    /// ajuste pide que no pase (`tokens.json` → `pendientes[movimiento-reducido]`).
    private func arrancarAutoplay() {
        reloj?.invalidate()
        guard !movimientoReducido else { return }
        reloj = Timer.scheduledTimer(withTimeInterval: 4.2, repeats: true) { _ in
            Task { @MainActor in actual = (actual + 1) % fotos.count }
        }
    }

    private func pausarAutoplay() {
        reloj?.invalidate()
        reloj = nil
    }
}
