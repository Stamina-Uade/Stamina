import SwiftUI
import TrainerCore

/// `bienvenida` — carousel de 3 momentos con autoplay, que también se pasa
/// deslizando, la marca, y las dos salidas: crear cuenta o entrar.
///
/// Rediseño 2026-10 (ronda 4): lo protagoniza la mascota. Cada momento es una
/// pose (saluda, corre, festeja con la medalla) que dice el título en un
/// globito; las fotos en blanco y negro quedan de fondo, bien veladas.
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
        let pose: PoseDeMascota
        let titulo: String
        let descripcion: String
    }

    /// Sin el párrafo de cada foto (`bienvenidaSlideNTexto`): el pedido es
    /// textos ultra cortos, y el título ya lo dice la mascota.
    private var fotos: [Foto] {
        [
            Foto(recurso: "BienvenidaAmanecer", pose: .saludo,
                 titulo: Textos.welcomeSlide1Title, descripcion: Textos.welcomeSlide1Photo),
            // "BienvenidaRuta" es una foto de ciclismo: el MVP es running.
            Foto(recurso: "BienvenidaMontana", pose: .corriendo,
                 titulo: Textos.welcomeSlide2Title, descripcion: Textos.welcomeSlide2Photo),
            Foto(recurso: "BienvenidaAmanecer", pose: .medalla,
                 titulo: Textos.welcomeSlide3Title, descripcion: Textos.welcomeSlide3Photo),
        ]
    }

    var body: some View {
        // La foto va a sangre —también bajo la barra de estado, como el diseño—
        // y la marca, la mascota y el pie se quedan DENTRO del área segura.
        //
        // 🪤 La foto va como FONDO y no como hermana en un ZStack. Con
        // `scaledToFill` la imagen reporta un tamaño mayor que la pantalla, y en
        // un ZStack eso se propaga: el pie recibía más ancho del que hay y se
        // cortaba por los dos lados. `background` no participa del layout.
        //
        // 🪤 La marca va arriba y el pie mide siempre lo mismo (ver
        // `conElAltoDelMasAlto`): la mascota se lleva el alto que sobra, así ni la
        // marca ni el título se mueven al cambiar de foto (lo mira un test de UI).
        VStack(spacing: 0) {
            marca
            escenario
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            pie
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// El velo: la foto se ve A COLOR arriba (ronda 7: los fondos tienen que
    /// dar ganas de salir) y se funde con el fondo abajo, donde va el pie.
    private var veloDeLaFoto: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Paleta.fondo.opacity(0.25), location: 0.0),
                    .init(color: Paleta.fondo.opacity(0.05), location: 0.3),
                    .init(color: Paleta.fondo.opacity(0.55), location: 0.55),
                    .init(color: Paleta.fondo, location: 0.75),
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

    private var marca: some View {
        HStack(spacing: TokensEspaciado.e9) {
            LogoApp()
            Text(MarcaApp.nombre).estilo(.marca, color: Paleta.textoAcento)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MarcaApp.nombre)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TokensEspaciado.e22)
        .padding(.top, TokensEspaciado.e8)
    }

    /// Las tres poses, una encima de la otra: la de la foto actual se ve,
    /// animada; las otras se funden y quedan en su primer cuadro (no cargan la
    /// animación, ver `MascotaAnimada`). Al entrar, la nueva sube un poquito y
    /// aparece.
    private var escenario: some View {
        ZStack {
            ForEach(Array(fotos.enumerated()), id: \.offset) { indice, foto in
                let esLaActual = indice == actual
                Mascota(pose: foto.pose, altoMaximo: TokensEspaciado.e56 * 6, activa: esLaActual)
                    .opacity(esLaActual ? 1 : 0)
                    .offset(y: esLaActual || movimientoReducido ? 0 : TokensEspaciado.e16)
            }
        }
        .padding(.horizontal, TokensEspaciado.e22)
        .padding(.vertical, TokensEspaciado.e12)
        .animation(movimientoReducido ? nil : .easeInOut(duration: TokensMovimiento.lenta),
                   value: actual)
        .accessibilityHidden(true)
    }

    private var pie: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
            // El título lo dice la mascota, en un globito que apunta hacia ella.
            // El globito NO se anima en tamaño ni posición: sólo cambia el texto,
            // con un fundido (el test de UI mide dónde queda el título).
            //
            // 🪤 Los títulos de las tres fotos no miden lo mismo, y el pie está
            // pegado abajo: con uno de dos renglones al lado de uno de uno, cada
            // cambio de foto movía todo. El globito se reserva el alto del más
            // alto de los tres —al tamaño de letra que tenga puesto la persona,
            // sin cortar nada— dibujando los tres debajo del que se ve.
            Bocadillo(cola: .arriba) {
                conElAltoDelMasAlto(fotos.map(\.titulo)) { titulo in
                    TextoDeBocadillo(texto: titulo)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(movimientoReducido ? nil : .easeInOut(duration: TokensMovimiento.lenta),
                       value: actual)

            indicadores

            VStack(spacing: TokensEspaciado.e8) {
                BotonPrimario(Textos.welcomeCreateAccount) { flujo.ir(a: .regCorreo) }
                BotonTexto(Textos.welcomeHaveAccount) { flujo.ir(a: .login) }
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
        ZStack(alignment: .top) {
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
                .accessibilityLabel(Textos.welcomeGoToPhoto(indice + 1, fotos.count))
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
