import SwiftUI
import TrainerCore

/// `ajustes` — una lista corta de filas, y cada una abre su página: Aspecto
/// (`AjustesApariencia.swift` + `AjustesColor.swift`), Notificaciones,
/// Unidades y Objetivos (`Ajustes<Página>.swift`). Las piezas están en
/// `AjustesPiezas.swift`.
///
/// La navegación es local (`pagina`): Ajustes vive en las pestañas propias del
/// Home, no en un `NavigationStack`. El estado, las claves, el guardado y los
/// avisos de error viven acá, así sobreviven a ir y volver entre páginas.
///
/// 🛑 Lo que **falta** y bloquea la publicación está anotado, no disimulado:
/// exportar mis datos y borrar mi cuenta son features, no favores (AGENTS.md
/// §8), y hoy no existen. `ESPECIFICACION.md` §8.2 las lista entre los huecos.
struct AjustesView: View {
    @EnvironmentObject private var estado: EstadoHome
    /// Cerrar la sesión es del flujo de entrada, no del Home: es el que sabe
    /// volver a la bienvenida y olvidar lo que quedó en memoria.
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    @AppStorage(ModoApariencia.clave) private var modoApariencia: ModoApariencia = ModoApariencia.predeterminado
    @AppStorage("ajuste_notif_manana") private var notificacionManana = true
    @AppStorage("ajuste_notif_recordatorio_antes") private var notificacionPrevio = true
    @AppStorage("ajuste_notif_calor") private var notificacionCalor = true

    /// La página abierta; `nil` es la raíz.
    @State private var pagina: PaginaDeAjustes?
    /// Al reabrir Aspecto después de aplicar un color: dónde dejar el scroll.
    @State private var anclaDeAspecto: String?

    @State private var guardandoUnidades = false
    @State private var unidadEnCurso: SistemaDeUnidades?
    @State private var errorDeUnidades = false
    @State private var objetivosEnEdicion: [ObjetivoDeUsuario] = []
    @State private var guardandoObjetivos = false
    @State private var errorDeObjetivos = false
    @State private var confirmandoCierre = false
    @State private var guiasRestablecidas = false

    /// Lo que "Ver tour" vuelve a mostrar: la guía de cada pestaña y el
    /// recorrido de bienvenida (`tour_visto`).
    private static let clavesDeAyuda = [
        "guia_inicio", "guia_plan", "guia_historial", "guia_perfil", "guia_ajustes", "tour_visto",
    ]

    var body: some View {
        ZStack {
            if let abierta = pagina {
                paginaAbierta(abierta)
                    .transition(transicionDePagina)
                    .zIndex(1)
            } else {
                raiz
                    .transition(transicionDeRaiz)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reabrirPagina() }
        .onChange(of: notificacionManana) { _ in estado.reprogramarRecordatorios() }
        .onChange(of: notificacionPrevio) { _ in estado.reprogramarRecordatorios() }
        .onChange(of: notificacionCalor) { _ in estado.reprogramarRecordatorios() }
        .task {
            await flujo.cargarObjetivos()
            let inicioDeHoyMs = Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
            objetivosEnEdicion = flujo.objetivosActivos.filter { obj in
                guard let f = obj.goalDateMs else { return true }
                return f >= inicioDeHoyMs
            }
        }
        .alert(Textos.ajustesUnidades, isPresented: $errorDeUnidades) {
            Button(Textos.comunListo, role: .cancel) {}
        } message: {
            Text(flujo.errorVisible ?? Textos.ajustesUnidadesDetalle)
        }
        .alert("No se guardaron los objetivos", isPresented: $errorDeObjetivos) {
            Button(Textos.comunListo, role: .cancel) {}
        } message: {
            Text(flujo.errorVisible ?? "Revisá la conexión e intentá de nuevo.")
        }
        .confirmationDialog(String(localized: "¿Cerrar la sesión?", comment: "Ajustes: confirmar el cierre de sesión"),
                            isPresented: $confirmandoCierre, titleVisibility: .visible) {
            Button(Textos.ajustesCerrarSesion, role: .destructive) {
                // El llavero se borra antes de salir, sin esperar a la red: sin señal
                // las credenciales se van igual, y `POST /auth/logout` sale por detrás
                // (`FlujoEntrada.cerrarSesion`).
                Task { await flujo.cerrarSesion() }
            }
            Button(Textos.comunCancelar, role: .cancel) {}
        }
    }

    // MARK: - Navegación

    private var transicionDePagina: AnyTransition {
        reducirMovimiento ? .opacity : .move(edge: .trailing)
    }

    private var transicionDeRaiz: AnyTransition {
        reducirMovimiento ? .opacity : AnyTransition.offset(x: -TokensEspaciado.e56).combined(with: .opacity)
    }

    private func ir(a destino: PaginaDeAjustes?) {
        if destino != nil { Haptico.toque() }
        anclaDeAspecto = nil
        let animacion: Animation = reducirMovimiento
            ? Animation.easeOut(duration: TokensMovimiento.rapida)
            : Animation.spring(response: TokensMovimiento.media, dampingFraction: 0.88)
        withAnimation(animacion) {
            pagina = destino
        }
    }

    /// Cambiar el color re-crea el Home y todo `@State` vuelve a cero: si el
    /// cambio salió de Aspecto, se vuelve ahí, sin animación, al bloque de color.
    private func reabrirPagina() {
        guard let guardada = AjustesAncla.paginaAlVolver else { return }
        AjustesAncla.paginaAlVolver = nil
        var sinAnimacion = Transaction()
        sinAnimacion.disablesAnimations = true
        withTransaction(sinAnimacion) {
            anclaDeAspecto = guardada == .aspecto ? AjustesAncla.color : nil
            pagina = guardada
        }
    }

    @ViewBuilder
    private func paginaAbierta(_ abierta: PaginaDeAjustes) -> some View {
        let volver = { ir(a: nil) }
        switch abierta {
        case .aspecto:
            AjustesPaginaAspecto(modo: $modoApariencia, ancla: anclaDeAspecto, volver: volver)
        case .notificaciones:
            AjustesPaginaNotificaciones(manana: $notificacionManana, previo: $notificacionPrevio,
                                        calor: $notificacionCalor, volver: volver)
        case .unidades:
            AjustesPaginaUnidades(elegido: estado.sistemaDeUnidades, enCurso: unidadEnCurso,
                                  guardando: guardandoUnidades, alElegir: elegirUnidad, volver: volver)
        case .objetivos:
            AjustesPaginaObjetivos(objetivos: $objetivosEnEdicion, guardando: guardandoObjetivos,
                                   alGuardar: guardarObjetivos, volver: volver)
        }
    }

    // MARK: - Raíz

    private var raiz: some View {
        AjustesPagina(Textos.ajustesTitulo, volver: { estado.volverDeLaPantallaSecundaria() }) {
            AjustesTarjetaDeFilas {
                AjustesFila(simbolo: "paintpalette.fill",
                            titulo: String(localized: "Aspecto", comment: "Ajustes: fila de modo y color"),
                            valor: modoApariencia.nombreCorto,
                            muestra: Paleta.acento,
                            valorAccesible: "\(modoApariencia.nombreCorto), \(nombreDelColor)") {
                    ir(a: .aspecto)
                }
                AjustesDivisorDeFila()
                AjustesFila(simbolo: "bell.badge.fill",
                            titulo: String(localized: "Notificaciones", comment: "Ajustes: fila de avisos"),
                            valor: resumenDeAvisos) {
                    ir(a: .notificaciones)
                }
            }

            AjustesTarjetaDeFilas {
                AjustesFila(simbolo: "ruler",
                            titulo: Textos.ajustesUnidades,
                            valor: estado.sistemaDeUnidades == .metrico ? "km" : "mi") {
                    ir(a: .unidades)
                }
                AjustesDivisorDeFila()
                AjustesFila(simbolo: "flag.checkered",
                            titulo: String(localized: "Objetivos", comment: "Ajustes: fila de objetivos"),
                            valor: String(localized: "\(objetivosEnEdicion.count) activos",
                                          comment: "Ajustes: cuántos objetivos hay")) {
                    ir(a: .objetivos)
                }
            }

            AjustesTarjetaDeFilas {
                AjustesFila(simbolo: "sparkles",
                            titulo: String(localized: "Ver tour", comment: "Ajustes: volver a mostrar el tour y las guías"),
                            valorAccesible: guiasRestablecidas
                                ? String(localized: "Listo: las guías vuelven a aparecer en cada pestaña.",
                                         comment: "Ajustes: guías restablecidas")
                                : nil,
                            simboloFinal: guiasRestablecidas ? "checkmark.circle.fill" : "chevron.right") {
                    restablecerGuias()
                }
                AjustesDivisorDeFila()
                AjustesFila(simbolo: "rectangle.portrait.and.arrow.right",
                            titulo: Textos.ajustesCerrarSesion,
                            tono: .alerta,
                            simboloFinal: nil) {
                    Haptico.toque()
                    confirmandoCierre = true
                }
            }

            Text(Textos.ajustesVersion(versionDeLaApp))
                .estilo(.notaLegal, color: Paleta.textoTerciario)
                .frame(maxWidth: .infinity)
                .padding(.top, TokensEspaciado.e8)
        }
    }

    /// "3 activas", "1 activa" o "Apagadas".
    private var resumenDeAvisos: String {
        let activas = [notificacionManana, notificacionPrevio, notificacionCalor].filter { $0 }.count
        switch activas {
        case 0: return String(localized: "Apagadas", comment: "Ajustes: ningún aviso prendido")
        case 1: return String(localized: "1 activa", comment: "Ajustes: un aviso prendido")
        default: return String(localized: "\(activas) activas", comment: "Ajustes: cuántos avisos están prendidos")
        }
    }

    /// El nombre del color aplicado, para VoiceOver.
    private var nombreDelColor: String {
        let guardado = UserDefaults.standard.string(forKey: AcentoPersonalizado.clave) ?? ""
        if AcentoPersonalizado.esPredeterminado(guardado) { return AcentoPersonalizado.predeterminado.nombre }
        return AcentoPersonalizado.opcion(paraGuardado: guardado)?.nombre
            ?? String(localized: "Personalizado", comment: "Ajustes: el color libre")
    }

    // MARK: - Unidades

    private func elegirUnidad(_ sistema: SistemaDeUnidades) {
        Haptico.seleccion()
        guardandoUnidades = true
        unidadEnCurso = sistema
        Task {
            if await flujo.guardarUnidades(sistema) {
                estado.sistemaDeUnidades = sistema
            } else {
                errorDeUnidades = true
            }
            guardandoUnidades = false
            unidadEnCurso = nil
        }
    }

    // MARK: - Objetivos

    private func guardarObjetivos() {
        guardandoObjetivos = true
        let normalizados = objetivosEnEdicion.enumerated().map { indice, valor in
            ObjetivoDeUsuario(id: indice == 0 ? "principal" :
                (valor.id == "principal" ? "" : valor.id),
                goal: valor.goal, goalDateMs: valor.goalDateMs)
        }
        Task {
            if await flujo.guardarObjetivos(normalizados) {
                Haptico.exito()
                objetivosEnEdicion = flujo.objetivosActivos
                await estado.actualizar()
            } else {
                errorDeObjetivos = true
            }
            guardandoObjetivos = false
        }
    }

    // MARK: - Ayuda

    private func restablecerGuias() {
        Haptico.exito()
        withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.media)) {
            for clave in Self.clavesDeAyuda {
                UserDefaults.standard.set(false, forKey: clave)
            }
            guiasRestablecidas = true
        }
    }

    private var versionDeLaApp: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9"
    }
}
