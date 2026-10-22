import SwiftUI
#if canImport(UIKit) && os(iOS)
import UIKit
#endif

// =============================================================================
// Las alertas de la app: iguales a las del sistema, con los botones APILADOS.
//
// 2026-10-22 (Iván): con dos o más botones van uno debajo del otro y el de
// cancelar —"Cancelar", "Ahora no", "Intentar de nuevo"…— siempre último, abajo.
// El `.alert` de SwiftUI pone dos botones lado a lado con cancelar a la
// izquierda, y no hay forma de pedirle otra cosa: por eso esta pieza.
//
// 🛑 Se ve como la del sistema y no como la app: fondo de material, tipografía
// del sistema, separadores finos, el azul del sistema en los botones, el de
// cancelar en negrita y los destructivos en rojo. NUNCA el color de la app: se
// dibuja en una ventana propia, encima de todo (también de las hojas), y esa
// ventana no hereda el `.tint` de `RaizFlujoView`. Los controles de la app —
// Toggle, DatePicker, ColorPicker— siguen con el color elegido.
//
// VoiceOver: la caja es modal (no se puede salir de ella con el dedo), el foco
// arranca en el título y cada botón se anuncia como botón.
// =============================================================================

// El reloj no tiene alertas propias (watchOS 9 ni siquiera tiene los materiales).
#if !os(watchOS)

/// Un botón de una alerta.
public struct BotonDeAlerta: Identifiable {
    public enum Rol: Sendable {
        case normal
        /// Va último, en negrita. "Cancelar", "Ahora no", "Intentar de nuevo"…
        case cancelar
        /// En rojo: borra, desactiva, cierra.
        case destructivo
    }

    public let id = UUID()
    public let titulo: String
    public let rol: Rol
    public let accion: () -> Void

    public init(_ titulo: String, rol: Rol = .normal, accion: @escaping () -> Void = {}) {
        self.titulo = titulo
        self.rol = rol
        self.accion = accion
    }
}

/// Un campo de texto dentro de la alerta (los pasos del día, la contraseña de una
/// cuenta para vincularla).
public struct CampoDeAlerta {
    public let etiqueta: String
    public let texto: Binding<String>
    public let seguro: Bool
    public let teclado: TipoTecladoCompat
    public let contenido: UITextContentTypeCompat

    public init(_ etiqueta: String, texto: Binding<String>, seguro: Bool = false,
                teclado: TipoTecladoCompat = .normal, contenido: UITextContentTypeCompat = .ninguno) {
        self.etiqueta = etiqueta
        self.texto = texto
        self.seguro = seguro
        self.teclado = teclado
        self.contenido = contenido
    }
}

/// Lo que muestra una alerta.
public struct ContenidoDeAlerta: Identifiable {
    public let id = UUID()
    public let titulo: String
    public let mensaje: String?
    public let campo: CampoDeAlerta?
    public let botones: [BotonDeAlerta]

    public init(_ titulo: String, mensaje: String? = nil, campo: CampoDeAlerta? = nil,
                botones: [BotonDeAlerta]) {
        self.titulo = titulo
        self.mensaje = mensaje
        self.campo = campo
        self.botones = botones
    }

    /// Los botones en el orden en que se dibujan: los de cancelar al final, y sin
    /// botones queda un "Ok" para que la alerta siempre se pueda cerrar.
    var botonesOrdenados: [BotonDeAlerta] {
        let resto = botones.filter { $0.rol != .cancelar }
        let cancelar = botones.filter { $0.rol == .cancelar }
        return resto + cancelar
    }

    /// Lo que cambia lo que se ve: si cambia mientras está a la vista, se redibuja.
    var firma: String {
        ([titulo, mensaje ?? "", campo?.etiqueta ?? ""] + botones.map(\.titulo)).joined(separator: "\u{1F}")
    }
}

extension View {
    /// Una alerta con los botones apilados y cancelar abajo, igual a la del sistema.
    public func alertaApilada(_ titulo: String, isPresented presentada: Binding<Bool>,
                              mensaje: String? = nil, campo: CampoDeAlerta? = nil,
                              botones: [BotonDeAlerta]) -> some View {
        modifier(ModificadorDeAlerta(
            visible: presentada.wrappedValue,
            contenido: ContenidoDeAlerta(titulo, mensaje: mensaje, campo: campo, botones: botones),
            cerrar: { presentada.wrappedValue = false }))
    }

    /// Una alerta que se muestra mientras haya un `mensaje` (un error, por ejemplo).
    public func alertaApilada(_ titulo: String, mensaje: Binding<String?>,
                              botones: [BotonDeAlerta]) -> some View {
        modifier(ModificadorDeAlerta(
            visible: mensaje.wrappedValue != nil,
            contenido: mensaje.wrappedValue.map { ContenidoDeAlerta(titulo, mensaje: $0, botones: botones) },
            cerrar: { mensaje.wrappedValue = nil }))
    }

    /// La misma alerta, presentada mientras `item` no sea `nil`.
    public func alertaApilada<Item: Identifiable>(item: Binding<Item?>,
                                                  contenido: (Item) -> ContenidoDeAlerta) -> some View {
        modifier(ModificadorDeAlerta(
            visible: item.wrappedValue != nil,
            contenido: item.wrappedValue.map(contenido),
            cerrar: { item.wrappedValue = nil }))
    }
}

private struct ModificadorDeAlerta: ViewModifier {
    let visible: Bool
    let contenido: ContenidoDeAlerta?
    let cerrar: () -> Void
    @State private var id = UUID()
    /// 🪤 Lo último que se dibujó. Los `onChange` de un `ViewModifier` pueden
    /// correr con la copia VIEJA del modificador (se vio en iOS 26: llegaba
    /// `visible == false` justo después de prenderla), así que leen de acá, que
    /// es una referencia y se actualiza en cada `body`.
    @State private var ultimo = Ultimo()

    final class Ultimo {
        var visible = false
        var contenido: ContenidoDeAlerta?
        var cerrar: () -> Void = {}
    }

    func body(content: Content) -> some View {
        ultimo.visible = visible
        ultimo.contenido = contenido
        ultimo.cerrar = cerrar
        return content
            .onAppear { sincronizar() }
            .onDisappear { PresentadorDeAlertas.compartido.ocultar(id) }
            .onChange(of: visible) { _ in sincronizar() }
            .onChange(of: contenido?.firma) { _ in sincronizar() }
    }

    private func sincronizar() {
        guard ultimo.visible, let contenido = ultimo.contenido else {
            PresentadorDeAlertas.compartido.ocultar(id)
            return
        }
        PresentadorDeAlertas.compartido.mostrar(id, contenido: contenido, cerrar: ultimo.cerrar)
    }
}

// MARK: - La ventana

/// Pone las alertas en una ventana propia, encima de la app, una a la vez: si
/// llega otra mientras hay una a la vista, se ve la última y, al cerrarla, vuelve
/// la anterior.
@MainActor
final class PresentadorDeAlertas {
    static let compartido = PresentadorDeAlertas()

    private struct Pendiente {
        let id: UUID
        let contenido: ContenidoDeAlerta
        let cerrar: () -> Void
    }

    private var pila: [Pendiente] = []

    #if canImport(UIKit) && os(iOS)
    private var ventana: UIWindow?
    private var anfitrion: UIHostingController<AnyView>?
    #endif

    func mostrar(_ id: UUID, contenido: ContenidoDeAlerta, cerrar: @escaping () -> Void) {
        let nueva = Pendiente(id: id, contenido: contenido, cerrar: cerrar)
        if let i = pila.firstIndex(where: { $0.id == id }) {
            // La misma alerta con otro contenido: se reemplaza en su lugar.
            if pila[i].contenido.firma == contenido.firma { return }
            pila[i] = nueva
        } else {
            pila.append(nueva)
        }
        dibujar()
    }

    func ocultar(_ id: UUID) {
        guard pila.contains(where: { $0.id == id }) else { return }
        pila.removeAll { $0.id == id }
        dibujar()
    }

    private func tocar(_ boton: BotonDeAlerta, en id: UUID) {
        guard let pendiente = pila.first(where: { $0.id == id }) else { return }
        // 🛑 Primero se cierra y DESPUÉS corre la acción: una acción que abre otra
        // alerta en el mismo lugar (`FlujoEntrada.alertaError`) no tiene que
        // borrarse a sí misma al cerrar la anterior.
        pila.removeAll { $0.id == id }
        pendiente.cerrar()
        dibujar()
        boton.accion()
    }

    private func dibujar() {
        #if canImport(UIKit) && os(iOS)
        guard let arriba = pila.last else {
            ventana?.isHidden = true
            ventana = nil
            anfitrion = nil
            return
        }
        let vista = AnyView(
            CajaDeAlerta(contenido: arriba.contenido) { [weak self] boton in
                self?.tocar(boton, en: arriba.id)
            }
        )
        if let anfitrion {
            anfitrion.rootView = vista
            return
        }
        guard let escena = Self.escenaActiva() else { return }
        let nuevaVentana = UIWindow(windowScene: escena)
        nuevaVentana.windowLevel = .alert
        nuevaVentana.backgroundColor = .clear
        // La ventana no hereda el modo claro/noche que eligió la persona: se copia
        // de la ventana de la app.
        nuevaVentana.overrideUserInterfaceStyle =
            escena.windows.first(where: \.isKeyWindow)?.traitCollection.userInterfaceStyle ?? .unspecified
        let controlador = UIHostingController(rootView: vista)
        controlador.view.backgroundColor = .clear
        nuevaVentana.rootViewController = controlador
        nuevaVentana.makeKeyAndVisible()
        ventana = nuevaVentana
        anfitrion = controlador
        #endif
    }

    #if canImport(UIKit) && os(iOS)
    private static func escenaActiva() -> UIWindowScene? {
        let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return escenas.first { $0.activationState == .foregroundActive } ?? escenas.first
    }
    #endif
}

// MARK: - La caja

/// La alerta dibujada como la del sistema, en sus dos versiones:
///
/// - **iOS 26 en adelante** (la que se ve hoy en el iPhone): tarjeta de vidrio con
///   esquinas de 34 pt, título y mensaje alineados a la izquierda, y los botones
///   como cápsulas grises a todo el ancho. Medida contra una alerta nativa en el
///   simulador de iOS 26.5 (2026-10-22).
/// - **Antes de iOS 26**: la de `UIAlertController`, de 270 pt, esquinas de 14,
///   todo centrado y los botones de 44 pt separados por una línea fina.
///
/// En las dos los botones van apilados, con cancelar abajo.
struct CajaDeAlerta: View {
    let contenido: ContenidoDeAlerta
    let tocar: (BotonDeAlerta) -> Void

    @State private var aparecio = false
    @FocusState private var campoEnfocado: Bool
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var nueva: Bool {
        #if os(iOS)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    var body: some View {
        ZStack {
            Color.black.opacity(aparecio ? 0.2 : 0)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Group {
                if nueva { tarjetaNueva } else { tarjetaClasica }
            }
            .scaleEffect(aparecio || reducirMovimiento ? 1 : 1.15)
            .opacity(aparecio ? 1 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { aparecio = true }
            if contenido.campo != nil {
                DispatchQueue.main.async { campoEnfocado = true }
            }
        }
    }

    // MARK: iOS 26

    private enum MedidaNueva {
        static let anchoMaximo: CGFloat = 318
        static let radio: CGFloat = 34
        static let margenDeTexto: CGFloat = 30
        static let margenDeBotones: CGFloat = 16
        static let altoDeBoton: CGFloat = 48
        static let entreBotones: CGFloat = 8
    }

    private var tarjetaNueva: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(contenido.titulo)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let mensaje = contenido.mensaje, !mensaje.isEmpty {
                    Text(mensaje)
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let campo = contenido.campo {
                    campoVista(campo, radio: 12, alto: 40)
                        .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MedidaNueva.margenDeTexto - MedidaNueva.margenDeBotones)
            .padding(.top, 22)
            .padding(.bottom, 20)

            VStack(spacing: MedidaNueva.entreBotones) {
                ForEach(contenido.botonesOrdenados) { boton in
                    Button { tocar(boton) } label: {
                        etiqueta(de: boton)
                            .frame(maxWidth: .infinity, minHeight: MedidaNueva.altoDeBoton)
                            .padding(.horizontal, 12)
                            .background(Capsule().fill(Color(uiColorCompat: .tertiarySystemFill)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(EstiloDeBotonDeAlerta(forma: .capsula))
                }
            }
        }
        .padding(MedidaNueva.margenDeBotones)
        .frame(maxWidth: MedidaNueva.anchoMaximo)
        .background(fondoNuevo)
        .padding(.horizontal, 40)
    }

    /// Casi opaco, como la del sistema: el vidrio con refracción dejaba pasar los
    /// colores de atrás (el rosa de un botón) y no se parecía.
    private var fondoNuevo: some View {
        RoundedRectangle(cornerRadius: MedidaNueva.radio, style: .continuous)
            .fill(.thickMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: MedidaNueva.radio, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }

    // MARK: Antes de iOS 26

    private enum MedidaClasica {
        static let ancho: CGFloat = 270
        static let radio: CGFloat = 14
        static let altoDeBoton: CGFloat = 44
        static let margen: CGFloat = 16
    }

    private var tarjetaClasica: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(contenido.titulo)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let mensaje = contenido.mensaje, !mensaje.isEmpty {
                    Text(mensaje)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let campo = contenido.campo {
                    campoVista(campo, radio: 5, alto: 26)
                        .padding(.top, MedidaClasica.margen - 2)
                }
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MedidaClasica.margen)
            .padding(.top, 19)
            .padding(.bottom, MedidaClasica.margen + 1)

            ForEach(contenido.botonesOrdenados) { boton in
                Divider()
                Button { tocar(boton) } label: {
                    etiqueta(de: boton)
                        .frame(maxWidth: .infinity, minHeight: MedidaClasica.altoDeBoton)
                        .padding(.horizontal, MedidaClasica.margen)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloDeBotonDeAlerta(forma: .rectangulo))
            }
        }
        .frame(width: MedidaClasica.ancho)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MedidaClasica.radio, style: .continuous))
    }

    // MARK: Piezas comunes

    private func etiqueta(de boton: BotonDeAlerta) -> some View {
        Text(boton.titulo)
            .font(boton.rol == .cancelar ? .body.weight(.semibold) : .body)
            .foregroundStyle(color(de: boton.rol))
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func campoVista(_ campo: CampoDeAlerta, radio: CGFloat, alto: CGFloat) -> some View {
        Group {
            if campo.seguro {
                SecureField(campo.etiqueta, text: campo.texto)
            } else {
                TextField(campo.etiqueta, text: campo.texto)
            }
        }
        .font(nueva ? .body : .footnote)
        .focused($campoEnfocado)
        .applyKeyboard(campo.teclado)
        .contenidoDeTexto(campo.contenido)
        .padding(.horizontal, nueva ? 12 : 6)
        .frame(height: alto)
        .background(Color(uiColorCompat: nueva ? .tertiarySystemFill : .systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: radio, style: .continuous)
                .strokeBorder(Color(uiColorCompat: .separator), lineWidth: nueva ? 0 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
    }

    private func color(de rol: BotonDeAlerta.Rol) -> Color {
        switch rol {
        case .destructivo: return Color(uiColorCompat: .systemRed)
        case .normal, .cancelar: return Color(uiColorCompat: .systemBlue)
        }
    }
}

/// Presionado, el botón se oscurece como en la alerta del sistema.
private struct EstiloDeBotonDeAlerta: ButtonStyle {
    enum Forma { case capsula, rectangulo }
    let forma: Forma

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    switch forma {
                    case .capsula: Capsule().fill(Color.primary.opacity(0.1))
                    case .rectangulo: Rectangle().fill(Color.primary.opacity(0.08))
                    }
                }
            }
    }
}

// MARK: - Compatibilidad con macOS (para `swift build` del paquete)

extension Color {
    enum ColorDeSistema { case systemBackground, separator, systemRed, systemBlue, tertiarySystemFill }

    init(uiColorCompat color: ColorDeSistema) {
        #if canImport(UIKit) && os(iOS)
        switch color {
        case .systemBackground: self.init(uiColor: .systemBackground)
        case .separator: self.init(uiColor: .separator)
        case .systemRed: self.init(uiColor: .systemRed)
        case .systemBlue: self.init(uiColor: .systemBlue)
        case .tertiarySystemFill: self.init(uiColor: .tertiarySystemFill)
        }
        #else
        switch color {
        case .systemBackground: self = .white
        case .separator: self = .gray
        case .systemRed: self = .red
        case .systemBlue: self = .blue
        case .tertiarySystemFill: self = .gray.opacity(0.2)
        }
        #endif
    }
}

#endif
