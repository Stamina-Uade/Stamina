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

    @AppStorage(ModoApariencia.clave) private var modoApariencia: ModoApariencia = .automatico

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .preferredColorScheme(modoApariencia.colorScheme)
        .environmentObject(flujo)
        .animation(.easeInOut(duration: TokensMovimiento.media), value: flujo.pantalla)
        .animation(.easeInOut(duration: TokensMovimiento.media), value: flujo.decisionDeVersion)
        // La puerta NO frena el arranque. Una app que se usa en el sótano de un
        // gimnasio no puede esperar diez segundos a la red para mostrar la primera
        // pantalla (AGENTS.md §6): se pregunta en paralelo y, si hay que cerrar,
        // se cierra encima de lo que se esté viendo.
        .task { await flujo.consultarPuertaDeVersion() }
        .task { await flujo.escucharCierres() }
        .alert(Textos.versionRecomendadaTitulo,
               isPresented: recomendacionVisible,
               presenting: flujo.actualizacionRecomendada) { aviso in
            if let tienda = aviso.tienda {
                Button(Textos.versionActualizar) {
                    flujo.recomendacionDescartada = true
                    abrirEnlace(tienda)
                }
            }
            Button(Textos.versionAhoraNo, role: .cancel) {
                flujo.recomendacionDescartada = true
            }
        } message: { aviso in
            Text(aviso.texto(generico: Textos.versionRecomendadaTexto))
        }
        .alert(Textos.sesionExpiradaTitulo, isPresented: $flujo.alertaSesionExpirada) {
            Button(Textos.comunListo, role: .cancel) {
                flujo.irAlLoginDesdeSesionExpirada()
            }
        } message: {
            Text(Textos.sesionExpiradaMensaje)
        }
        .alert(flujo.alertaError?.titulo ?? Textos.comunListo,
               isPresented: Binding(
                   get: { flujo.alertaError != nil },
                   set: { if !$0 { flujo.alertaError = nil } }
               ),
               presenting: flujo.alertaError) { alerta in
            Button(alerta.boton, role: .cancel) {
                flujo.alertaError = nil
            }
        } message: { alerta in
            Text(alerta.mensaje)
        }
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
                BarraAvance(paso: flujo.pantalla.numeroDePaso ?? 1,
                            total: Pantalla.pasosDelRegistro.count,
                            descripcion: Textos.comunAvanceRegistro)
            case .soloVolver, .ninguna:
                Spacer()
            }
        }
        // El mismo alto con flecha o sin ella: si no, el contenido del primer paso
        // de perfil quedaría más arriba que el de los demás.
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        .padding(.horizontal, TokensEspaciado.e22)
        .padding(.bottom, TokensEspaciado.e12)
    }

    @ViewBuilder
    private var contenido: some View {
        switch flujo.pantalla {
        case .bienvenida:    BienvenidaView()
        case .problema:      ProblemaView()
        case .previewPlan:   PreviewPlanView()

        case .login:         LoginView()
        case .claveCorreo:   ClaveCorreoView()
        case .claveCodigo:   ClaveCodigoView()
        case .claveNueva:    ClaveNuevaView()
        case .claveLista:    ClaveListaView()

        case .regCorreo:     RegCorreoView()
        case .regCodigo:     RegCodigoView()
        case .regClave:      RegClaveView()
        case .regAviso:      RegAvisoView()
        case .regTerminos:   RegTerminosView()
        case .regNombre:     RegNombreView()
        case .regNacimiento: RegNacimientoView()
        case .regSexo:       RegSexoView()
        case .regCuerpo:     RegCuerpoView()
        case .regDeporte:    RegDeporteView()
        case .regNivel:      RegNivelView()
        case .regObjetivo:   RegObjetivoView()
        case .regSalud:      RegSaludView()
        case .regMedicion:   RegMedicionView()
        case .regDias:       RegDiasView()
        case .regListo:      RegListoView()

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
