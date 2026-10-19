import SwiftUI
import TrainerCore

/// "Así funciona Stamina": cinco páginas, una por pestaña de la barra, que se
/// ven una sola vez al entrar al Home (`tour_visto`, en `RaizHomeView`). Se pasa
/// deslizando o con "Siguiente", y se puede saltar desde cualquier página.
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

struct TourPagina {
    let simbolo: String
    let titulo: String
    let texto: String

    /// Una por pestaña, en el orden de la barra.
    static var todas: [TourPagina] {
        [
            TourPagina(
                simbolo: "house.fill",
                titulo: String(localized: "Tu día, de un vistazo", comment: "Tour: título de Inicio"),
                texto: String(localized: "En Inicio ves lo que te toca hoy y cuánto falta para tu próxima carrera. Tocá cada tarjeta para ver más.",
                              comment: "Tour: texto de Inicio")),
            TourPagina(
                simbolo: "calendar",
                titulo: String(localized: "Tu plan, semana a semana", comment: "Tour: título de Plan"),
                texto: String(localized: "En Plan está todo tu entrenamiento ordenado por semanas. Tocá un día para ver el detalle de la sesión.",
                              comment: "Tour: texto de Plan")),
            TourPagina(
                simbolo: "bolt.fill",
                titulo: String(localized: "El botón del medio", comment: "Tour: título de Entreno"),
                texto: String(localized: "Con ⚡ empezás una salida: el GPS mide distancia y ritmo, podés pausar cuando quieras y seguirla desde tu reloj.",
                              comment: "Tour: texto de Entreno")),
            TourPagina(
                simbolo: "clock.arrow.circlepath",
                titulo: String(localized: "Todo lo que hiciste", comment: "Tour: título de Historial"),
                texto: String(localized: "En Historial queda cada actividad con su mapa y sus números, y un calendario para ver tu constancia.",
                              comment: "Tour: texto de Historial")),
            TourPagina(
                simbolo: "person.crop.circle.fill",
                titulo: String(localized: "Vos y tu app", comment: "Tour: título de Perfil"),
                texto: String(localized: "En Perfil están tus datos, tu apto físico, los ajustes y el color de la app.",
                              comment: "Tour: texto de Perfil")),
        ]
    }
}

/// Una página: el ícono grande en un círculo que brilla con el acento, el
/// título pesado y dos líneas de texto.
private struct TourPaginaView: View {
    let contenido: TourPagina
    /// Si es la página que se está mirando: el ícono entra con un rebote chico.
    let visible: Bool

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido

    var body: some View {
        VStack(spacing: TokensEspaciado.e26) {
            Spacer(minLength: 0)
            icono
            VStack(spacing: TokensEspaciado.e12) {
                Text(contenido.titulo)
                    .estilo(.display)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(contenido.texto)
                    .estilo(.cuerpo, color: Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TokensEspaciado.e8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var icono: some View {
        let diametro = TokensEspaciado.e56 * 2 + TokensEspaciado.e16
        return ZStack {
            Circle()
                .fill(Paleta.acentoChipActivo)
                .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e40)
            Circle()
                .strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1)
            Image(systemName: contenido.simbolo)
                .font(.system(size: TokensEspaciado.e52, weight: .bold))
                .foregroundStyle(Paleta.acento)
        }
        .frame(width: diametro, height: diametro)
        .scaleEffect(visible || movimientoReducido ? 1 : 0.82)
        .opacity(visible || movimientoReducido ? 1 : 0.4)
        .animation(movimientoReducido ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: visible)
        .accessibilityHidden(true)
    }
}
