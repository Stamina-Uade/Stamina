import SwiftUI
import TrainerCore

// =============================================================================
// Las piezas de las páginas que EDITAN el perfil: Datos personales y
// Entrenamiento (ronda 6).
//
// Cada dato es una fila que se despliega ahí mismo con su editor (como las
// fechas del Calendario de iOS): no hay hojas ni pantallas nuevas. Abajo, fijo,
// UN "Guardar" que manda un solo `PATCH /me` con lo que cambió
// (`EditorDePerfil.swift`). Volver con cambios sin guardar pregunta antes.
// =============================================================================

/// Una fila que se toca y despliega su editor debajo, dentro de la tarjeta.
struct AjustesFilaDesplegable<Editor: View>: View {
    private let simbolo: String
    private let titulo: String
    private let valor: String
    /// Cambió y todavía no se guardó: el valor va en el color de la app.
    private let editado: Bool
    private let abierta: Bool
    private let alTocar: () -> Void
    private let editor: Editor

    init(simbolo: String, titulo: String, valor: String, editado: Bool, abierta: Bool,
         alTocar: @escaping () -> Void, @ViewBuilder editor: () -> Editor) {
        self.simbolo = simbolo
        self.titulo = titulo
        self.valor = valor
        self.editado = editado
        self.abierta = abierta
        self.alTocar = alTocar
        self.editor = editor()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: alTocar) {
                HStack(spacing: TokensEspaciado.e12) {
                    AjustesIcono(simbolo: simbolo)
                    Text(titulo)
                        .estilo(.opcionTitulo, color: Paleta.textoPrimario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                    Spacer(minLength: TokensEspaciado.e8)
                    Text(valor)
                        .estilo(.cuerpoSecundario, color: editado ? Paleta.textoAcento : Paleta.textoTerciario)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                        .foregroundStyle(abierta ? Paleta.acento : Paleta.textoTerciario)
                        .rotationEffect(.degrees(abierta ? 90 : 0))
                }
                .padding(.horizontal, TokensEspaciado.e14)
                .padding(.vertical, TokensEspaciado.e8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .objetivoTactilAlto()
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(titulo)
            .accessibilityValue(valor)
            .accessibilityAddTraits(abierta ? [.isButton, .isSelected] : .isButton)

            if abierta {
                editor
                    .padding(.horizontal, TokensEspaciado.e14)
                    .padding(.top, TokensEspaciado.e4)
                    .padding(.bottom, TokensEspaciado.e14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// La barra fija de abajo: el error con su "Reintentar", "Guardar" con la
/// ruedita mientras viaja, y el tilde breve cuando llegó.
struct AjustesBarraDeGuardado: View {
    let estado: GuardadoDePerfil.Estado
    let habilitado: Bool
    let guardar: () -> Void

    var body: some View {
        VStack(spacing: TokensEspaciado.e8) {
            if case .fallo(let mensaje) = estado {
                HStack(alignment: .top, spacing: TokensEspaciado.e8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                        .foregroundStyle(Paleta.error)
                        .accessibilityHidden(true)
                    Text(mensaje)
                        .estilo(.labelCampo, color: Paleta.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

            if estado == .guardado {
                PildoraDeEstado(Self.textoGuardado, simbolo: "checkmark", tono: .acento)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: TokensTamano.botonPrimario)
                    .transition(.scale.combined(with: .opacity))
            } else {
                BotonPrimario(esReintento ? Textos.commonRetry : Textos.commonSave,
                              habilitado: habilitado,
                              cargando: estado == .guardando,
                              motivoDeshabilitado: Self.motivoDeshabilitado,
                              accion: guardar)
            }
        }
        .padding(.horizontal, TokensEspaciado.e16)
        .padding(.top, TokensEspaciado.e10)
        .padding(.bottom, TokensEspaciado.e8)
        .frame(maxWidth: .infinity)
        .background(Paleta.fondo)
        .overlay(alignment: .top) { Divider().background(Paleta.divisor) }
    }

    private var esReintento: Bool {
        if case .fallo = estado { return true }
        return false
    }

    static let textoGuardado = Textos.settingsProfileSaved
    static let motivoDeshabilitado = Textos.settingsProfileFixToSave
}

/// Una página de Ajustes que edita: el andamio de siempre (`AjustesPagina`),
/// la barra de guardar abajo y la pregunta de descartar al volver.
struct AjustesPaginaDeEdicion<Contenido: View>: View {
    private let titulo: String
    private let hayCambios: Bool
    private let puedeGuardar: Bool
    @ObservedObject private var guardado: GuardadoDePerfil
    private let guardar: () -> Void
    private let volver: () -> Void
    private let contenido: Contenido

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var confirmandoDescarte = false

    init(_ titulo: String, hayCambios: Bool, puedeGuardar: Bool, guardado: GuardadoDePerfil,
         guardar: @escaping () -> Void, volver: @escaping () -> Void,
         @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.hayCambios = hayCambios
        self.puedeGuardar = puedeGuardar
        self.guardado = guardado
        self.guardar = guardar
        self.volver = volver
        self.contenido = contenido()
    }

    var body: some View {
        AjustesPagina(titulo, volver: intentarVolver) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                contenido
            }
            // Mientras viaja, no se edita: la respuesta re-arma lo que se ve.
            .disabled(guardado.estado == .guardando)
        }
        .scrollDismissesKeyboardCompat()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if muestraLaBarra {
                AjustesBarraDeGuardado(estado: guardado.estado, habilitado: puedeGuardar, guardar: guardar)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida), value: muestraLaBarra)
        .animation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida), value: guardado.estado)
        .alert(Self.tituloDescartar, isPresented: $confirmandoDescarte) {
            Button(Textos.commonDiscard, role: .destructive) { volver() }
            Button(Self.seguirEditando, role: .cancel) {}
        } message: {
            Text(Self.mensajeDescartar)
        }
    }

    private var muestraLaBarra: Bool { hayCambios || guardado.estado != .quieto }

    /// Con cambios sin guardar, primero se pregunta. Con un guardado en viaje no:
    /// termina solo y el Home lo toma igual.
    private func intentarVolver() {
        guard hayCambios, guardado.estado != .guardando else { return volver() }
        Haptico.toque()
        confirmandoDescarte = true
    }

    static var tituloDescartar: String {
        Textos.settingsProfileDiscardTitle
    }
    static var mensajeDescartar: String {
        Textos.settingsProfileDiscardMessage
    }
    static var seguirEditando: String {
        Textos.settingsProfileKeepEditing
    }
}

/// Mientras llega `GET /me`: la ruedita, y si no llega, "Reintentar".
struct AjustesCargandoPerfil: View {
    let titulo: String
    let volver: () -> Void
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var cargando = true

    var body: some View {
        AjustesPagina(titulo, volver: volver) {
            VStack(spacing: TokensEspaciado.e14) {
                if cargando {
                    ProgressView()
                        .tint(Paleta.acento)
                } else {
                    Text(Textos.settingsProfileLoadFailed)
                        .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                        .multilineTextAlignment(.center)
                    BotonTonal(Textos.commonRetry) { Task { await cargar() } }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, TokensEspaciado.e40)
        }
        .task { await cargar() }
    }

    private func cargar() async {
        cargando = true
        await flujo.cargarPerfil()
        // Si llegó, quien llama ya cambió esta vista por la página.
        cargando = false
    }
}
