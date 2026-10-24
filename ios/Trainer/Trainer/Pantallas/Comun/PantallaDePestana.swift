import SwiftUI
import TrainerCore

/// Una de las cuatro pestañas de la barra (Inicio, Plan, Historial, Perfil), con su
/// barra fija arriba: el título a la izquierda y, a la derecha, el fueguito (y lo que
/// la pestaña agregue, como el engranaje de Perfil).
///
/// 2026-10-23 (decisión de Iván, "menos cosas a la vista"): la barra no se va con el
/// scroll. Arriba de todo tiene el mismo fondo que la pantalla y nada más; al bajar,
/// el contenido pasa POR DEBAJO y la barra sigue con fondo sólido —nada de
/// `.ultraThinMaterial` ni transparencias: el contenido no se ve a través— y suma una
/// línea fina abajo.
///
/// Va con `safeAreaInset` y no adentro del `ScrollView`: así el contenido arranca
/// debajo de la barra, el "tirar para actualizar" sale debajo de ella y el indicador
/// de scroll no la cruza.
struct PantallaDePestana<Accesorio: View, Contenido: View>: View {
    private let titulo: String
    private let alRefrescar: (() async -> Void)?
    private let accesorio: Accesorio
    private let contenido: Contenido

    /// Si el contenido bajó más de un punto: la barra lleva la línea.
    @State private var desplazado = false
    /// Dónde estaba el borde de arriba del contenido al aparecer (en la pantalla).
    @State private var yInicial: CGFloat?

    init(_ titulo: String,
         alRefrescar: (() async -> Void)? = nil,
         @ViewBuilder accesorio: () -> Accesorio,
         @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.alRefrescar = alRefrescar
        self.accesorio = accesorio()
        self.contenido = contenido()
    }

    var body: some View {
        desplazable
            .onPreferenceChange(InicioDelContenidoDePestana.self) { y in
                // En iOS 18 manda `onScrollGeometryChange` (`avisandoElScroll`).
                if #available(iOS 18.0, *) { return }
                if yInicial == nil { yInicial = y }
                let bajo = y < (yInicial ?? y) - 1
                if bajo != desplazado { desplazado = bajo }
            }
            .safeAreaInset(edge: .top, spacing: 0) { barra }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paleta.fondo)
    }

    @ViewBuilder
    private var desplazable: some View {
        let vista = ScrollView {
            VStack(spacing: 0) {
                // Una marca de alto cero arriba de todo: dice cuánto bajó el contenido.
                GeometryReader { geo in
                    Color.clear.preference(key: InicioDelContenidoDePestana.self,
                                           value: geo.frame(in: .global).minY)
                }
                .frame(height: 0)
                contenido
            }
        }
        if let alRefrescar {
            vista.refreshable { await alRefrescar() }.avisandoElScroll($desplazado)
        } else {
            vista.avisandoElScroll($desplazado)
        }
    }

    private var barra: some View {
        HStack(spacing: TokensEspaciado.e8) {
            Text(titulo)
                .estilo(.tituloSeccion)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            accesorio
        }
        .padding(.horizontal, TokensEspaciado.e16)
        .frame(minHeight: TokensTamano.objetivoTactilMinimo + TokensEspaciado.e8)
        .frame(maxWidth: .infinity)
        // Sólido siempre: arriba de todo es el mismo color que la pantalla, y al bajar
        // tapa lo que pasa por debajo.
        .background(Paleta.fondo.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Paleta.bordeSuperficie)
                .frame(height: TokensEspaciado.e1)
                .opacity(desplazado ? 1 : 0)
                .accessibilityHidden(true)
        }
    }
}

/// Dónde está el borde de arriba del contenido, en la pantalla.
private struct InicioDelContenidoDePestana: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private extension View {
    /// En iOS 18, cuánto bajó el contenido lo dice el `ScrollView` mismo; la marca de
    /// alto cero de arriba queda para iOS 16 y 17.
    @ViewBuilder
    func avisandoElScroll(_ desplazado: Binding<Bool>) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 1
            } action: { _, bajo in
                if bajo != desplazado.wrappedValue { desplazado.wrappedValue = bajo }
            }
        } else {
            self
        }
    }
}

/// El fueguito de la barra fija. Sin plan, apagado en 0: la barra lo muestra igual,
/// en el mismo lugar, en las cuatro pestañas.
struct FueguitoDeLaBarra: View {
    @EnvironmentObject private var estado: EstadoHome

    var body: some View {
        InsigniaDeRacha(racha: estado.plan?.racha ?? RachaHome())
    }
}
