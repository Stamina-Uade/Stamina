import SwiftUI
import TrainerCore

/// El splash: lo primero que se ve al abrir la app.
///
/// Arranca idéntico a la pantalla de lanzamiento de iOS (`UILaunchScreen` en
/// `Trainer-Info.plist`: fondo `FondoArranque` y la imagen `LogoArranque`, del
/// mismo tamaño y centrada), así que el paso de una a otra no se nota. Después
/// el logo se enciende con el halo del acento, aparece el nombre, y se funde
/// hacia la pantalla que corresponda: el Home si hay sesión, la bienvenida si no.
///
/// No espera a la red: la sesión se decide antes de dibujar nada
/// (`FlujoEntrada.init`) y la puerta de versión corre en paralelo (AGENTS.md §6).
struct PantallaDeArranque: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var encendido = false

    /// Cuánto queda en pantalla antes de fundirse.
    static let duracion: UInt64 = 1_100_000_000

    /// Los tests de UI la saltean: taparía la primera pantalla un segundo.
    static var seMuestra: Bool {
        #if DEBUG
        return !ProcessInfo.processInfo.arguments.contains(ServiciosDeLaApp.argumentoDeDobles)
        #else
        return true
        #endif
    }

    var body: some View {
        ZStack {
            Color("FondoArranque")
            RadialGradient(colors: [Paleta.acento.opacity(encendido ? 0.30 : 0), Color.clear],
                           center: .center, startRadius: 0, endRadius: TokensEspaciado.e56 * 5)

            Image("LogoArranque")
                .shadow(color: Paleta.acentoBrillo.opacity(encendido ? 1 : 0), radius: TokensEspaciado.e26)
                .scaleEffect(encendido && !reducirMovimiento ? 1.06 : 1)
                // El nombre va debajo sin mover el logo del centro, que es donde
                // lo dejó la pantalla de lanzamiento.
                .overlay(alignment: .bottom) {
                    Text(MarcaApp.nombre.uppercased())
                        .estilo(.marca, color: .white)
                        .tracking(TokensEspaciado.e4)
                        .fixedSize()
                        .opacity(encendido ? 1 : 0)
                        .offset(y: encendido || reducirMovimiento ? TokensEspaciado.e44 : TokensEspaciado.e34 + TokensEspaciado.e20)
                }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: reducirMovimiento ? 0.2 : 0.6)) { encendido = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MarcaApp.nombre)
    }
}
