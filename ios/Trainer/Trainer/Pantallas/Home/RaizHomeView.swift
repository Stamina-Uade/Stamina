import SwiftUI
import TrainerCore

/// La app después del login: siete pestañas y dos modales.
///
/// Cinco pestañas están en la barra —inicio, plan, el botón central de entreno,
/// nutrición y perfil—; `gimnasio` se abre desde la agenda y `ajustes` desde el
/// perfil. Es el reparto de `design/origen/HomeB.dc.html`.
struct RaizHomeView: View {
    @StateObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.scenePhase) private var fase

    /// El perfil guardado (`GET /me` o la última respuesta de `PATCH /me`). Llega
    /// DESPUÉS de que el Home ya se ve: esperar a la red para mostrar la primera
    /// pantalla es lo que una app offline-primero no puede hacer (AGENTS.md §6).
    private let perfil: Perfil?

    /// - Parameter repositorio: se evalúa una sola vez, cuando `StateObject` arma el
    ///   estado; los redibujos no piden otro.
    init(nombreCompleto: String = "", objetivo: Objetivo = .mediaMaraton,
         perfil: Perfil? = nil, repositorio: @autoclosure @escaping () -> RepositorioDePlan,
         sincronizador: SincronizadorDeSesion? = nil) {
        let repo = repositorio()
        _estado = StateObject(wrappedValue: EstadoHome(repositorio: repo,
                                                       nombreCompleto: nombreCompleto,
                                                       objetivo: objetivo,
                                                       sincronizador: sincronizador ?? SincronizadorDeSesion(dispositivo: .telefono)))
        self.perfil = perfil
    }

    var body: some View {
        // 🪤 Cada pestaña se hace grande DESDE SU PROPIA RAÍZ, con
        // `.frame(maxHeight: .infinity)` en su `body`. Ponerlo acá, sobre el
        // `switch`, no alcanza: el contenido se quedaba con su altura ideal y
        // abajo quedaba media pantalla negra. Es el mismo patrón que
        // `PantallaPaso`, que es el que funciona en este código.
        ZStack {
            VStack(spacing: 0) {
                // Arriba del inicio, que es la pantalla con la que se entra: ahí se ve
                // antes que nada, y no tapa las otras pestañas.
                // También cuando el que lo dice es el motor (`profile_incomplete`), aunque
                // `GET /me` todavía no haya llegado.
                if estado.pestana == .inicio, flujo.pasoPendienteDelPerfil != nil || estado.faltaPerfil {
                    AvisoDePerfilIncompleto { retomarPerfil() }
                        .padding(.horizontal, TokensEspaciado.e16)
                        .padding(.top, TokensEspaciado.e8)
                }
                contenido
                if estado.muestraLaBarra {
                    BarraDePestanas(
                        items: [
                            ItemDePestana(id: PestanaHome.inicio.rawValue, titulo: Textos.homeTabInicio, simbolo: "house"),
                            ItemDePestana(id: PestanaHome.plan.rawValue, titulo: Textos.homeTabPlan, simbolo: "calendar"),
                            ItemDePestana(id: PestanaHome.nutricion.rawValue, titulo: Textos.homeTabNutricion, simbolo: "fork.knife"),
                            ItemDePestana(id: PestanaHome.perfil.rawValue, titulo: Textos.homeTabPerfil, simbolo: "person"),
                        ],
                        elegida: estado.pestana == .entreno ? estado.pestanaPrevia.rawValue : estado.pestana.rawValue,
                        central: ItemDePestana(id: PestanaHome.entreno.rawValue,
                                               titulo: Textos.homeTabEntreno, simbolo: "bolt.fill"),
                        alElegir: { id in
                            if let destino = PestanaHome(rawValue: id) { estado.ir(a: destino) }
                        },
                        alTocarCentral: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                estado.ir(a: .entreno)
                            }
                        })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if estado.pestana == .entreno {
                EntrenoView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .clipped()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .environmentObject(estado)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: estado.pestana)
        .sheet(item: $estado.modal) { modal in
            switch modal {
            case .registrarComida: RegistrarComidaView().environmentObject(estado)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                GestorDeMapa.shared.precalentar()
            }
            aplicar(perfil)
        }
        .onChange(of: perfil) { aplicar($0) }
        // Offline primero (AGENTS.md §6): lo guardado ya se ve. Esto trae lo nuevo al
        // entrar y cada vez que la app vuelve a primer plano.
        .task { await estado.actualizar() }
        .onChange(of: fase) { nueva in
            if nueva == .active { Task { await estado.actualizar() } }
        }
        // El aviso lleva al primer paso que falta, y QUÉ falta lo dice el perfil.
        .onChange(of: estado.faltaPerfil) { falta in
            if falta, flujo.pasoPendienteDelPerfil == nil { Task { await flujo.cargarPerfil() } }
        }
    }

    /// Al primer hueco del perfil. Si el que avisó fue el motor y el perfil todavía
    /// no llegó, primero se pide: sin él no se sabe a qué paso ir.
    private func retomarPerfil() {
        guard flujo.pasoPendienteDelPerfil == nil else { return flujo.retomarPerfil() }
        Task {
            await flujo.cargarPerfil()
            flujo.retomarPerfil()
        }
    }

    /// Lo único del perfil que el Home usa: el nombre y el objetivo. Plan, rutina,
    /// comidas y series tienen sus propios endpoints desde la 1.1.0
    /// (`ServicioDelPlan`, en `ApiTrainer`); de dónde los saca el Home lo decide
    /// `RepositorioDePlan`.
    private func aplicar(_ perfil: Perfil?) {
        guard let perfil else { return }
        estado.perfil = perfil
        if let unidades = perfil.unitSystem {
            estado.sistemaDeUnidades = unidades == .imperial ? .imperial : .metrico
        }
        let nombre = [perfil.firstName, perfil.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !nombre.isEmpty { estado.nombreCompleto = nombre }
        if let objetivo = perfil.goal { estado.objetivo = objetivo }
    }

    @ViewBuilder
    private var contenido: some View {
        let actual = (estado.pestana == .entreno) ? estado.pestanaPrevia : estado.pestana
        switch actual {
        case .inicio:    InicioView()
        case .plan:      PlanView()
        case .nutricion: NutricionView()
        case .perfil:    PerfilView()
        case .ajustes:   AjustesView()
        case .gimnasio:  GimnasioView()
        case .entreno:   InicioView()
        }
    }
}

/// El aviso de un perfil al que le faltan datos del alta: un texto y el botón que
/// lleva al primer hueco. Chico a propósito: reusa las pantallas del alta en vez de
/// traer un formulario propio.
struct AvisoDePerfilIncompleto: View {
    let retomar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            AvisoSuave(Textos.homePerfilIncompletoTexto)
            BotonTexto(Textos.homePerfilIncompletoBoton, accion: retomar)
        }
    }
}

// MARK: - Piezas compartidas por las pestañas

/// El encabezado de una pantalla secundaria (gimnasio, ajustes): flecha para
/// volver y título. Las pestañas de la barra no lo llevan: ellas usan
/// `EncabezadoDePestana`, con el título grande del rediseño.
struct CabeceraSecundaria: View {
    let titulo: String
    let volver: () -> Void

    var body: some View {
        HStack(spacing: TokensEspaciado.e12) {
            FlechaVolver(accion: volver)
            Text(titulo)
                .estilo(.tituloSeccion)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .padding(.horizontal, TokensEspaciado.e16)
        .padding(.bottom, TokensEspaciado.e8)
    }
}

/// Título de una sección dentro de una pestaña: el "Semana de carrera" del
/// mockup, pesado y apretado.
struct TituloDeSeccion: View {
    private let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto)
            .estilo(.tituloSeccion)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Un chip informativo: los del plan de avituallamiento y los de la sesión.
/// Tiene la forma de las píldoras del rediseño: cápsula con borde finito.
struct ChipInformativo: View {
    let texto: String
    var destacado: Bool = false

    var body: some View {
        Text(texto)
            .estilo(.chip, color: destacado ? Paleta.acento : Paleta.textoCuerpo)
            .padding(.horizontal, TokensEspaciado.e10)
            .padding(.vertical, TokensEspaciado.e6)
            .background(destacado ? Paleta.acentoChipActivo : Paleta.superficie)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(destacado ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                                       lineWidth: TokensEspaciado.e1)
            )
    }
}
