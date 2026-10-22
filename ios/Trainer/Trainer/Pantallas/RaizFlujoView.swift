import SwiftUI
import TrainerCore

/// La raíz de la app: decide qué pantalla se ve y dibuja lo que es común a todas —
/// la flecha de volver, la barra de avance del registro y, encima de todo, la
/// actualización obligatoria.
///
/// El diseño muestra esa cabecera **sólo en los pasos del registro**, y la barra
/// **no lleva número**: es una decisión explícita del tablero. Para VoiceOver sí
/// se anuncia el paso, porque ahí no hay barra que mirar.
struct RaizFlujoView: View {
    @StateObject private var flujo: FlujoEntrada
    @Environment(\.openURL) private var abrirEnlace
    /// De dónde saca el Home lo que muestra (`ServiciosDeLaApp.repositorioDelHome`).
    private let repositorioDelHome: () -> RepositorioDePlan

    /// `flujo` se evalúa una sola vez: `StateObject` guarda el primero y descarta
    /// los que SwiftUI construya al redibujar la escena.
    init(flujo: @autoclosure @escaping () -> FlujoEntrada,
         repositorioDelHome: @escaping () -> RepositorioDePlan) {
        _flujo = StateObject(wrappedValue: flujo())
        self.repositorioDelHome = repositorioDelHome
    }

    @AppStorage(ModoApariencia.clave) private var modoApariencia: ModoApariencia = ModoApariencia.predeterminado
    @AppStorage(AcentoPersonalizado.clave) private var acentoGuardado = ""
    /// El splash del arranque (`PantallaDeArranque`): una vez por apertura.
    @State private var mostrandoArranque = PantallaDeArranque.seMuestra

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if flujo.pantalla.cabecera != .ninguna {
                    cabecera
                }
                contenido
            }

            // 🛑 La actualización obligatoria va ENCIMA de todo —el flujo y el
            // Home— y no como un caso más del `switch`: no tiene flecha, no tiene a
            // dónde volver y no se saltea. Aparece sólo si llegó un
            // `update_required` entero: sin red o con un 503, la puerta deja pasar.
            if let aviso = flujo.actualizacionRequerida {
                ActualizacionRequeridaView(aviso: aviso)
                    .transition(.opacity)
                    .zIndex(1)
            }
            if mostrandoArranque {
                PantallaDeArranque()
                    .transition(.opacity)
                    .zIndex(2)
                    .task {
                        try? await Task.sleep(nanoseconds: PantallaDeArranque.duracion)
                        withAnimation(.easeOut(duration: TokensMovimiento.media)) { mostrandoArranque = false }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .preferredColorScheme(modoApariencia.colorScheme)
        // Los controles del sistema (Toggle, DatePicker, ColorPicker) también
        // llevan el color elegido.
        .tint(AcentoPersonalizado.componentes(de: acentoGuardado)
            .map { Color(.sRGB, red: $0.0, green: $0.1, blue: $0.2, opacity: 1) } ?? Paleta.acento)
        .environmentObject(flujo)
        .animation(.easeInOut(duration: TokensMovimiento.media), value: flujo.pantalla)
        .animation(.easeInOut(duration: TokensMovimiento.media), value: flujo.decisionDeVersion)
        // La puerta NO frena el arranque. Una app que se usa en el sótano de un
        // gimnasio no puede esperar diez segundos a la red para mostrar la primera
        // pantalla (AGENTS.md §6): se pregunta en paralelo y, si hay que cerrar,
        // se cierra encima de lo que se esté viendo.
        .task { await flujo.consultarPuertaDeVersion() }
        .task { await flujo.escucharCierres() }
        // Las alertas van con `alertaApilada` (TrainerCore): iguales a las del
        // sistema, con los botones apilados y cancelar abajo, y sin el color de
        // la app — se dibujan en su propia ventana, que no hereda el `.tint` de
        // arriba.
        .alertaApilada(Textos.versionRecommendedTitle,
                       isPresented: recomendacionVisible,
                       mensaje: flujo.actualizacionRecomendada?.texto(generico: Textos.versionRecommendedBody),
                       botones: botonesDeLaRecomendacion)
        .alertaApilada(Textos.sessionExpiredTitle, isPresented: $flujo.alertaSesionExpirada,
                       mensaje: Textos.sessionExpiredMessage,
                       botones: [BotonDeAlerta(Textos.commonOk, rol: .cancelar) {
                           flujo.irAlLoginDesdeSesionExpirada()
                       }])
        .alertaApilada(item: $flujo.alerta) { $0 }
    }

    private var botonesDeLaRecomendacion: [BotonDeAlerta] {
        var botones: [BotonDeAlerta] = []
        if let tienda = flujo.actualizacionRecomendada?.tienda {
            botones.append(BotonDeAlerta(Textos.versionUpdate) {
                flujo.recomendacionDescartada = true
                abrirEnlace(tienda)
            })
        }
        botones.append(BotonDeAlerta(Textos.versionNotNow, rol: .cancelar) {
            flujo.recomendacionDescartada = true
        })
        return botones
    }

    /// La recomendación se muestra una vez por arranque: "Ahora no" es ahora no,
    /// no un cartel que vuelve cada vez que se cambia de pantalla.
    private var recomendacionVisible: Binding<Bool> {
        Binding(get: { flujo.actualizacionRecomendada != nil },
                set: { visible in if !visible { flujo.recomendacionDescartada = true } })
    }

    /// La flecha de volver y, sólo en el registro, la barra de avance.
    ///
    /// 🛑 Es el **único** lugar del flujo que dibuja una flecha de volver. Que
    /// además la dibujara cada pantalla es lo que produjo las dos flechas.
    private var cabecera: some View {
        HStack(spacing: TokensEspaciado.e14) {
            if flujo.pantalla.cabecera != .soloAvance {
                // Con un pedido en el aire no se vuelve (ver `FlujoEntrada.volver`),
                // y VoiceOver tiene que poder decir por qué no responde.
                FlechaVolver { flujo.volver() }
                    .disabled(flujo.enCurso)
            }

            switch flujo.pantalla.cabecera {
            case .volverYAvance, .soloAvance:
                // Con Google o Apple el alta no tiene contraseña: un paso menos.
                BarraAvanceSegmentada(paso: flujo.numeroDelPasoActual ?? 1,
                                      total: flujo.pasosDelAlta.count,
                                      descripcion: Textos.commonSignupProgress)
            case .soloVolver, .ninguna:
                Spacer()
            }
        }
        // El mismo alto con flecha o sin ella: si no, el contenido del primer paso
        // de perfil quedaría más arriba que el de los demás.
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        // Con flecha, el círculo ya trae su aire dentro de los 48 pt táctiles.
        .padding(.leading, flujo.pantalla.cabecera == .soloAvance ? TokensEspaciado.e22 : TokensEspaciado.e14)
        .padding(.trailing, TokensEspaciado.e22)
        .padding(.bottom, TokensEspaciado.e8)
    }

    @ViewBuilder
    private var contenido: some View {
        switch flujo.pantalla {
        case .bienvenida:    BienvenidaView()

        case .login:         LoginView()
        case .claveCorreo:   ClaveCorreoView()
        case .claveCodigo:   ClaveCodigoView()
        case .claveNueva:    ClaveNuevaView()

        case .regCorreo:     RegCorreoView()
        case .regCodigo:     RegCodigoView()
        case .regAntesDeEmpezar: RegAntesDeEmpezarView()
        case .regNacimiento: RegNacimientoView()
        case .regSexo:       RegSexoView()
        case .regCuerpo:     RegCuerpoView()
        case .regDeporte:    RegDeporteView()
        case .regNivel:      RegNivelView()
        case .regObjetivo:   RegObjetivoView()
        case .regDias:       RegDiasView()
        case .regApto:       RegAptoView()

        case .home:
            RaizHomeView(nombreCompleto: nombreParaElHome,
                         objetivo: flujo.datos.objetivo ?? .mediaMaraton,
                         perfil: flujo.perfil,
                         repositorio: repositorioDelHome(),
                         sincronizador: flujo.sincronizador)
                .task { await flujo.cargarPerfil() }
        }
    }

    /// Lo que se sabe del nombre antes de que llegue `GET /me`: lo que se cargó en
    /// el alta, si se acaba de hacer.
    private var nombreParaElHome: String {
        "\(flujo.datos.nombre) \(flujo.datos.apellido)".trimmingCharacters(in: .whitespaces)
    }
}

/// La barra de avance del registro con el look del mockup: un segmento por paso,
/// rosas los hechos y el actual, con su halo.
///
/// Dice a VoiceOver exactamente lo mismo que `BarraAvance` (TrainerCore): la
/// descripción y "paso/total". Tampoco muestra el número en pantalla: es la
/// decisión del tablero (ver el comentario de `RaizFlujoView`).
private struct BarraAvanceSegmentada: View {
    let paso: Int
    let total: Int
    let descripcion: String

    var body: some View {
        HStack(spacing: TokensEspaciado.e3) {
            ForEach(0..<max(total, 1), id: \.self) { indice in
                Capsule()
                    .fill(indice < paso ? Paleta.acento : Paleta.superficieControl)
                    .frame(height: TokensEspaciado.e4)
                    .shadow(color: indice == paso - 1 ? Paleta.acentoBrillo : Color.clear,
                            radius: TokensEspaciado.e4)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: TokensMovimiento.media), value: paso)
        .accessibilityElement()
        .accessibilityLabel(descripcion)
        .accessibilityValue(Text(verbatim: "\(paso)/\(total)"))
    }
}
