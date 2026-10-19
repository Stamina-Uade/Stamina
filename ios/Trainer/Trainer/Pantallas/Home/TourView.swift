import SwiftUI
import TrainerCore

/// "Así funciona Stamina": cinco páginas, una por pestaña de la barra, que se
/// ven una sola vez al entrar al Home (`tour_visto`, en `RaizHomeView`). Se pasa
/// deslizando o con "Siguiente", y se puede saltar desde cualquier página.
///
/// Ronda 5: cada página muestra la pantalla DE VERDAD, achicada dentro de un
/// teléfono (ver `TourVistaPrevia.swift`), con un anillo del acento sobre lo que
/// importa y la mascota al costado, quieta, señalándolo con una flecha. Lo que
/// dice va en un globito de una línea.
struct TourView: View {
    /// El estado del Home, para dibujar las pantallas reales. 🪤 Hay que pasarlo
    /// a mano: el `fullScreenCover` de `RaizHomeView` cuelga por FUERA de su
    /// `.environmentObject(estado)` y no lo hereda. Sin él, cada página muestra
    /// sólo la barra de pestañas con la pestaña señalada.
    let estado: EstadoHome?
    /// Se llama al tocar "Empezar" o "Saltar": quien lo presenta lo cierra y
    /// anota que ya se vio.
    let alTerminar: () -> Void

    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var pagina = 0

    init(estado: EstadoHome? = nil, alTerminar: @escaping () -> Void) {
        self.estado = estado
        self.alTerminar = alTerminar
    }

    private let paginas = TourPagina.todas
    private var esLaUltima: Bool { pagina >= paginas.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            barraSuperior

            TabView(selection: $pagina) {
                ForEach(Array(paginas.enumerated()), id: \.offset) { indice, contenido in
                    TourPaginaView(contenido: contenido, estado: estado, flujo: flujo,
                                   visible: indice == pagina)
                        .tag(indice)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            puntos
                .padding(.top, TokensEspaciado.e12)
                .padding(.bottom, TokensEspaciado.e16)

            BotonPrimario(esLaUltima
                          ? Textos.commonStart
                          : Textos.commonNext) {
                avanzar()
            }
        }
        .padding(.horizontal, TokensEspaciado.e16)
        .padding(.bottom, TokensEspaciado.e16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(fondo.ignoresSafeArea())
        .onChange(of: pagina) { _ in Haptico.seleccion() }
    }

    // MARK: - Arriba: el nombre del tour y "Saltar"

    private var barraSuperior: some View {
        HStack(spacing: TokensEspaciado.e8) {
            Text(Textos.tourHowItWorks(MarcaApp.nombre))
                .estilo(.etiquetaSeccion, color: Paleta.acento)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if !esLaUltima {
                Button {
                    Haptico.toque()
                    alTerminar()
                } label: {
                    Text(Textos.commonSkip)
                        .estilo(.tituloCard, color: Paleta.textoSecundario)
                        .padding(.horizontal, TokensEspaciado.e8)
                        .frame(minWidth: TokensTamano.objetivoTactilMinimo,
                               minHeight: TokensTamano.objetivoTactilMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityHint(Textos.tourCloseHint)
            }
        }
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        .padding(.top, TokensEspaciado.e8)
    }

    // MARK: - Los puntos de página

    private var puntos: some View {
        HStack(spacing: TokensEspaciado.e6) {
            ForEach(paginas.indices, id: \.self) { indice in
                Capsule(style: .continuous)
                    .fill(indice == pagina ? Paleta.acento : Paleta.superficieControl)
                    .frame(width: indice == pagina ? TokensEspaciado.e20 : TokensEspaciado.e6,
                           height: TokensEspaciado.e6)
            }
        }
        .animation(movimientoReducido ? nil : .easeOut(duration: TokensMovimiento.rapida), value: pagina)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Textos.tourPageOf(pagina + 1, paginas.count))
    }

    // MARK: - Fondo: negro con un resplandor del acento arriba

    private var fondo: some View {
        ZStack {
            Paleta.fondo
            RadialGradient(colors: [Paleta.acentoProfundo, Color.clear],
                           center: .top, startRadius: 0,
                           endRadius: TokensEspaciado.e56 * 6)
                .opacity(0.5)
        }
        .accessibilityHidden(true)
    }

    private func avanzar() {
        guard !esLaUltima else {
            Haptico.exito()
            alTerminar()
            return
        }
        if movimientoReducido {
            pagina += 1
        } else {
            withAnimation(.easeInOut(duration: TokensMovimiento.media)) { pagina += 1 }
        }
    }
}

// MARK: - El contenido de cada página

/// Una página del tour: qué pantalla se muestra, qué dice la mascota (una línea
/// corta, ≤ 60 caracteres) y de qué lado del teléfono se para.
struct TourPagina {
    let seccion: SeccionDelTour
    let globito: String
    let mascotaALaIzquierda: Bool

    /// Una por pestaña, en el orden de la barra. La mascota cambia de lado en
    /// cada página, para que no se vea siempre igual.
    static var todas: [TourPagina] {
        [
            TourPagina(
                seccion: .inicio,
                globito: Textos.tourPageHomeBubble,
                mascotaALaIzquierda: true),
            TourPagina(
                seccion: .plan,
                globito: Textos.tourPagePlanBubble,
                mascotaALaIzquierda: false),
            TourPagina(
                seccion: .entreno,
                globito: Textos.tourPageWorkoutBubble,
                mascotaALaIzquierda: true),
            TourPagina(
                seccion: .historial,
                globito: Textos.tourPageHistoryBubble,
                mascotaALaIzquierda: false),
            TourPagina(
                seccion: .perfil,
                globito: Textos.tourPageProfileBubble,
                mascotaALaIzquierda: true),
        ]
    }
}

/// Una página: el globito arriba, con el piquito hacia el lado de la mascota, y
/// abajo el escenario (teléfono + anillo + flecha + mascota). Al llegar a la
/// página el globito brota una vez; después todo queda quieto.
private struct TourPaginaView: View {
    let contenido: TourPagina
    let estado: EstadoHome?
    let flujo: FlujoEntrada
    /// Si es la página que se está mirando: la mascota, el anillo y la flecha entran.
    let visible: Bool

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var entro = false

    var body: some View {
        VStack(spacing: TokensEspaciado.e12) {
            globito
            escenario
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, TokensEspaciado.e4)
        .padding(.bottom, TokensEspaciado.e4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // El teléfono es decorado: VoiceOver lee qué pestaña es y lo que dice la mascota.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(contenido.seccion.nombre + ". " + contenido.globito)
        .accessibilityAddTraits(.isHeader)
        .onAppear { entro = visible }
        .onChange(of: visible) { entro = $0 }
    }

    private var aparecido: Bool { entro || movimientoReducido }

    private var globito: some View {
        Bocadillo(cola: .abajo, posicionDeCola: contenido.mascotaALaIzquierda ? 0.16 : 0.84) {
            Text(contenido.globito)
                .estilo(.tituloCard)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .scaleEffect(aparecido ? 1 : 0.9,
                     anchor: contenido.mascotaALaIzquierda ? .bottomLeading : .bottomTrailing)
        .opacity(aparecido ? 1 : 0)
        .animation(movimientoReducido
                   ? nil
                   : Animation.easeOut(duration: TokensMovimiento.media).delay(TokensMovimiento.rapida),
                   value: entro)
    }

    /// Con el estado, el escenario lo observa: si el plan llega mientras se
    /// mira el tour, la vista previa (y dónde va el anillo) se acomoda sola.
    @ViewBuilder
    private var escenario: some View {
        if let estado {
            TourEscenarioObservado(estado: estado, pagina: contenido, flujo: flujo, visible: visible)
        } else {
            TourEscenario(pagina: contenido, estado: nil, flujo: flujo, visible: visible)
        }
    }
}

/// El escenario, redibujado cada vez que cambia el estado del Home.
private struct TourEscenarioObservado: View {
    @ObservedObject var estado: EstadoHome
    let pagina: TourPagina
    let flujo: FlujoEntrada
    let visible: Bool

    var body: some View {
        TourEscenario(pagina: pagina, estado: estado, flujo: flujo, visible: visible)
    }
}
