import SwiftUI

// =============================================================================
// Los campos de entrada del flujo.
//
// El borde en foco es acento (12.59:1). El borde en reposo es `bordeSignificante`
// y **no lleva significado** por sí solo: el estado del
// campo se comunica con el mensaje de abajo, nunca sólo con el color del borde
// (AGENTS.md §10.1, `design/ESPECIFICACION.md` §9.1).
// =============================================================================

/// Qué le dice el campo a quien lo está completando.
public enum EstadoCampo: Equatable, Sendable {
    case neutro
    /// Va bien. Lleva el acento, pero el TEXTO ya dice qué pasa: el color solo
    /// nunca es la señal.
    case correcto(String)
    case error(String)

    public var mensaje: String? {
        switch self {
        case .neutro: return nil
        case .correcto(let m), .error(let m): return m
        }
    }

    public var color: Color {
        switch self {
        case .neutro: return Paleta.textoSecundario
        case .correcto: return Paleta.textoAcento
        case .error: return Paleta.error
        }
    }
}

/// Campo de texto con etiqueta flotante (2026-10-21, pedido de Iván).
///
/// Vacío y sin foco, el campo muestra QUÉ dato pide —la etiqueta, no un ejemplo—
/// en el lugar del texto. Al tocarlo o con algo escrito, la etiqueta se achica y
/// sube al borde, que se abre para dejarla pasar (como los campos "outlined").
/// Las contraseñas llevan un ojo para ver lo que se escribió.
///
/// `marcador` ya no se muestra: queda en la firma para no tocar las 18 llamadas,
/// y porque un ejemplo ("juan@mail.com") se confunde con un valor cargado.
public struct CampoTexto: View {
    private let etiqueta: String
    private let marcador: String
    @Binding private var texto: String
    private let estilo: EstiloTipografico
    private let contenido: UITextContentTypeCompat
    private let teclado: TipoTecladoCompat
    private let seguro: Bool
    /// Si la contraseña lleva el ojo para verla. La confirmación no lo lleva
    /// (2026-10-21): repetirla a ciegas es lo que la hace útil.
    private let conOjo: Bool
    /// El dato falló al validarlo: borde y etiqueta en rojo. El porqué lo dice
    /// el mensaje de abajo; el color solo no alcanza (ver arriba).
    private let conError: Bool

    @FocusState private var enfocado: Bool
    @State private var claveVisible = false
    @State private var tamanoEtiqueta: CGSize = .zero
    @Environment(\.isEnabled) private var habilitado

    public init(
        etiqueta: String,
        marcador: String = "",
        texto: Binding<String>,
        estilo: EstiloTipografico = .campoTexto,
        contenido: UITextContentTypeCompat = .ninguno,
        teclado: TipoTecladoCompat = .normal,
        seguro: Bool = false,
        conOjo: Bool = true,
        conError: Bool = false
    ) {
        self.conOjo = conOjo
        self.conError = conError
        self.etiqueta = etiqueta
        self.marcador = marcador
        self._texto = texto
        self.estilo = estilo
        self.contenido = contenido
        self.teclado = teclado
        self.seguro = seguro
    }

    /// La etiqueta está arriba, en el borde.
    private var flotando: Bool { enfocado || !texto.isEmpty }

    private var colorDelBorde: Color {
        if conError { return Paleta.error }
        return enfocado ? Paleta.bordeEnfocado : Paleta.bordeSignificante
    }

    private var anchoDelBorde: CGFloat { enfocado || conError ? TokensEspaciado.e2 : TokensEspaciado.e1 }

    public var body: some View {
        HStack(spacing: TokensEspaciado.e8) {
            campo
                .estilo(estilo)
                .focused($enfocado)
                .accessibilityLabel(etiqueta)
            if seguro && conOjo {
                Button {
                    claveVisible.toggle()
                    // Cambiar entre SecureField y TextField desmonta el que tenía
                    // el foco: se devuelve en la vuelta siguiente, cuando el otro
                    // ya existe, para que se pueda seguir escribiendo.
                    DispatchQueue.main.async { enfocado = true }
                } label: {
                    Image(systemName: claveVisible ? "eye.slash" : "eye")
                        .font(.system(size: TokensTipografia.campoTextoTamano + 2))
                        .foregroundStyle(Paleta.textoTerciario)
                        .frame(width: TokensTamano.objetivoTactilMinimo,
                               height: TokensTamano.objetivoTactilMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(claveVisible
                    ? String(localized: "common.password.hide", defaultValue: "Hide password", bundle: .main)
                    : String(localized: "common.password.show", defaultValue: "Show password", bundle: .main))
            }
        }
        .padding(.leading, TokensEspaciado.e16)
        .padding(.trailing, seguro && conOjo ? TokensEspaciado.e4 : TokensEspaciado.e16)
        .frame(minHeight: TokensEspaciado.e56)
        .contentShape(Rectangle())
        .onTapGesture { enfocado = true }
        .overlay(alignment: .leading) { etiquetaFlotante }
        .background(borde)
        .padding(.top, TokensEspaciado.e8)   // lugar para la etiqueta arriba del borde
        .opacity(habilitado ? 1 : 0.6)
        .animation(.easeOut(duration: TokensMovimiento.rapida), value: flotando)
        .animation(.easeOut(duration: TokensMovimiento.rapida), value: enfocado)
    }

    /// La etiqueta: grande y en el lugar del texto cuando el campo está vacío;
    /// chica, sobre el borde, cuando se escribe. No se toca: el toque es del campo.
    private var etiquetaFlotante: some View {
        Text(etiqueta)
            .estilo(flotando ? .labelCampo : estilo,
                    color: conError ? Paleta.error : (enfocado ? Paleta.textoAcento : Paleta.textoTerciario))
            .lineLimit(1)
            .padding(.horizontal, TokensEspaciado.e4)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TamanoDeEtiquetaKey.self, value: geo.size)
                }
            )
            .onPreferenceChange(TamanoDeEtiquetaKey.self) { tamanoEtiqueta = $0 }
            // Sin foco y vacía: centrada en el alto del campo, sea cual sea el
            // tamaño de letra. Flotando: arriba, con su centro sobre el borde.
            .frame(maxHeight: .infinity, alignment: flotando ? .top : .center)
            .offset(x: TokensEspaciado.e12, y: flotando ? -tamanoEtiqueta.height / 2 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// El borde redondeado, abierto donde pasa la etiqueta flotante. Se abre con
    /// una máscara y no tapando con un color: así sirve sobre cualquier fondo
    /// (la pantalla o una tarjeta).
    private var borde: some View {
        RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
            .strokeBorder(colorDelBorde, lineWidth: anchoDelBorde)
            .mask(
                ZStack(alignment: .topLeading) {
                    Rectangle()
                    if flotando {
                        // El hueco mide lo que la etiqueta, centrado en el borde.
                        Rectangle()
                            .frame(width: tamanoEtiqueta.width, height: tamanoEtiqueta.height)
                            .offset(x: TokensEspaciado.e12, y: -tamanoEtiqueta.height / 2)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
            )
    }

    @ViewBuilder
    private var campo: some View {
        if seguro && !claveVisible {
            SecureField("", text: $texto)
                .contenidoDeTexto(contenido)
        } else {
            TextField("", text: $texto)
                .contenidoDeTexto(contenido)
                .applyKeyboard(seguro ? .clave : teclado)
        }
    }
}

private struct TamanoDeEtiquetaKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// El campo de 6 caracteres de `reg-codigo` y `clave-codigo`.
public struct CampoCodigo: View {
    public static let largo = 6

    @Binding private var codigo: String
    private let marcador: String
    @FocusState private var enfocado: Bool

    /// `marcador`: qué se pide ("Código de 6 caracteres"), nunca un código de ejemplo.
    public init(codigo: Binding<String>, marcador: String = "") {
        self._codigo = codigo
        self.marcador = marcador
    }

    public var body: some View {
        TextField("", text: $codigo)
            .estilo(.codigo)
            .accessibilityLabel(marcador)
            // Vacío, dice qué se pide con letra normal: con la del código (grande,
            // espaciada y en mayúsculas) "Código de 6 caracteres" no entra.
            .overlay {
                if codigo.isEmpty {
                    Text(marcador)
                        .estilo(.campoTexto, color: Paleta.textoPlaceholder)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .multilineTextAlignment(.center)
            .applyKeyboard(.codigo)
            .contenidoDeTexto(.codigoUnaVez)
            .autocorrectionDisabled()
            .padding(.vertical, TokensEspaciado.e20)
            .padding(.horizontal, TokensEspaciado.e10)
            .frame(maxWidth: .infinity)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous)
                    .strokeBorder(enfocado ? Paleta.bordeEnfocado : Paleta.bordeInput,
                                  lineWidth: enfocado ? TokensEspaciado.e2 : TokensEspaciado.e1)
            )
            // El halo rosa de lo "vivo": el código se está escribiendo.
            .shadow(color: enfocado ? Paleta.acentoProfundo : Color.clear, radius: TokensEspaciado.e12)
            .animation(.easeOut(duration: TokensMovimiento.rapida), value: enfocado)
            .focused($enfocado)
            .onChange(of: codigo) { nuevo in
                // El servidor espera 6 alfanuméricos en mayúscula. Se normaliza
                // acá para que pegar un código de un mail no rompa nada.
                let normalizado = String(
                    nuevo.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(Self.largo)
                )
                if normalizado != codigo { codigo = normalizado }
            }
    }
}

// -----------------------------------------------------------------------------
// Compatibilidad: `UITextContentType` y `UIKeyboardType` son de UIKit y no
// existen al compilar el paquete para macOS, que es como se corren los tests
// rápidos. Estos envoltorios dejan que el design system se describa una sola vez.
// -----------------------------------------------------------------------------

public enum UITextContentTypeCompat: Sendable {
    case ninguno, correo, claveNueva, claveActual, nombre, apellido, codigoUnaVez

}

public enum TipoTecladoCompat: Sendable {
    case normal, correo, decimal, codigo
    /// Sólo dígitos: los pasos del día.
    case numero
    /// Una contraseña a la vista: sin mayúscula automática ni autocorrector.
    case clave
}

extension View {
    /// El autocompletado del sistema: es lo que hace que el código llegue solo
    /// desde el SMS o el mail, y que el llavero ofrezca guardar la contraseña.
    @ViewBuilder
    func contenidoDeTexto(_ tipo: UITextContentTypeCompat) -> some View {
        #if os(iOS)   // El reloj no tiene teclado (AGENTS.md §10.2).
        switch tipo {
        case .ninguno:      self
        case .correo:       self.textContentType(.emailAddress)
        case .claveNueva:   self.textContentType(.newPassword)
        case .claveActual:  self.textContentType(.password)
        case .nombre:       self.textContentType(.givenName)
        case .apellido:     self.textContentType(.familyName)
        case .codigoUnaVez: self.textContentType(.oneTimeCode)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyKeyboard(_ tipo: TipoTecladoCompat) -> some View {
        #if os(iOS)   // El reloj no tiene teclado (AGENTS.md §10.2).
        switch tipo {
        case .normal:
            self
        case .correo:
            self.keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .decimal:
            self.keyboardType(.decimalPad)
        case .numero:
            self.keyboardType(.numberPad)
        case .codigo:
            self.textInputAutocapitalization(.characters)
        case .clave:
            self.textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        #else
        self
        #endif
    }
}
