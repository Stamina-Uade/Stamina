import SwiftUI
import TrainerCore

/// "Así funciona Stamina": cinco páginas, una por pestaña de la barra, que se
/// ven una sola vez al entrar al Home (`tour_visto`, en `RaizHomeView`). Se pasa
/// deslizando o con "Siguiente", y se puede saltar desde cualquier página.
/// Lo cuenta la mascota: una línea por globito, nada de párrafos.
struct TourView: View {
    /// Se llama al tocar "Empezar" o "Saltar": quien lo presenta lo cierra y
    /// anota que ya se vio.
    let alTerminar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var pagina = 0

    private let paginas = TourPagina.todas
    private var esLaUltima: Bool { pagina >= paginas.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            barraSuperior

            TabView(selection: $pagina) {
                ForEach(Array(paginas.enumerated()), id: \.offset) { indice, contenido in
                    TourPaginaView(contenido: contenido, visible: indice == pagina)
                        .tag(indice)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            puntos
                .padding(.bottom, TokensEspaciado.e20)

            BotonPrimario(esLaUltima
                          ? String(localized: "Empezar", comment: "Último botón del tour")
                          : String(localized: "Siguiente", comment: "Pasa a la siguiente página del tour")) {
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
            Text(String(localized: "Así funciona \(MarcaApp.nombre)", comment: "Sobretítulo del tour"))
                .estilo(.etiquetaSeccion, color: Paleta.acento)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if !esLaUltima {
                Button {
                    Haptico.toque()
                    alTerminar()
                } label: {
                    Text(String(localized: "Saltar", comment: "Saltea el tour"))
                        .estilo(.tituloCard, color: Paleta.textoSecundario)
                        .padding(.horizontal, TokensEspaciado.e8)
                        .frame(minWidth: TokensTamano.objetivoTactilMinimo,
                               minHeight: TokensTamano.objetivoTactilMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityHint(String(localized: "Cierra el tour y va al inicio", comment: "VoiceOver de Saltar"))
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
        .accessibilityLabel(String(localized: "Página \(pagina + 1) de \(paginas.count)", comment: "VoiceOver de los puntos del tour"))
    }

    // MARK: - Fondo: negro con un resplandor del acento arriba

    private var fondo: some View {
        ZStack {
            Paleta.fondo
            RadialGradient(colors: [Paleta.acentoProfundo, Color.clear],
                           center: .top, startRadius: 0,
                           endRadius: TokensEspaciado.e56 * 6)
                .opacity(0.6)
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

/// Una página del tour: la pose de la mascota, lo que dice en el globito (una
/// línea) y, abajo, una leyenda chiquita con dónde está eso en la app.
struct TourPagina {
    let pose: PoseDeMascota
    let globito: String
    let leyenda: String

    /// Una por pestaña, en el orden de la barra. Saluda para explicar, corre
    /// para entrenar y ver el progreso, y festeja con la medalla al final.
    static var todas: [TourPagina] {
        [
            TourPagina(
                pose: .saludo,
                globito: String(localized: "¡Hola! Acá ves lo que te toca hoy.", comment: "Tour: globito de Inicio"),
                leyenda: String(localized: "Inicio · tocá una tarjeta para ver más", comment: "Tour: leyenda de Inicio")),
            TourPagina(
                pose: .saludo,
                globito: String(localized: "Tu plan, semana a semana.", comment: "Tour: globito de Plan"),
                leyenda: String(localized: "Plan · tocá un día para ver la sesión", comment: "Tour: leyenda de Plan")),
            TourPagina(
                pose: .corriendo,
                globito: String(localized: "Tocá ⚡ y salimos a correr.", comment: "Tour: globito de Entreno"),
                leyenda: String(localized: "GPS, ritmo y pausa · también desde el reloj", comment: "Tour: leyenda de Entreno")),
            TourPagina(
                pose: .corriendo,
                globito: String(localized: "Cada salida queda guardada.", comment: "Tour: globito de Historial"),
                leyenda: String(localized: "Historial · mapa, números y tu constancia", comment: "Tour: leyenda de Historial")),
            TourPagina(
                pose: .medalla,
                globito: String(localized: "¡Listo para tu primera carrera!", comment: "Tour: globito final"),
                leyenda: String(localized: "Perfil · tus datos, ajustes y el color de la app", comment: "Tour: leyenda de Perfil")),
        ]
    }
}

/// Una página: la mascota grande hablando con su globito, y la leyenda abajo.
/// Al llegar a la página la mascota entra con un fundido y el globito brota
/// desde el piquito (todo eso vive en `MascotaConBocadillo`).
private struct TourPaginaView: View {
    let contenido: TourPagina
    /// Si es la página que se está mirando: la mascota entra y se mueve.
    let visible: Bool

    var body: some View {
        VStack(spacing: TokensEspaciado.e16) {
            Spacer(minLength: 0)
            MascotaConBocadillo(pose: contenido.pose,
                                texto: contenido.globito,
                                altoMaximo: TokensEspaciado.e56 * 5,
                                activa: visible)
            Text(contenido.leyenda)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, TokensEspaciado.e8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
