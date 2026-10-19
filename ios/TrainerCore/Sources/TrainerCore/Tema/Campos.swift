import SwiftUI

// =============================================================================
// Los campos de entrada del flujo.
//
// El borde en foco es acento (12.59:1). El borde en reposo es blanco al 12 %
// (1.40:1) y por eso **no lleva significado**: es decorativo, y el estado del
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

/// Campo de texto con su etiqueta arriba, como en todo el flujo de registro.
public struct CampoTexto: View {
    private let etiqueta: String
    private let marcador: String
    @Binding private var texto: String
    private let estilo: EstiloTipografico
    private let contenido: UITextContentTypeCompat
    private let teclado: TipoTecladoCompat
    private let seguro: Bool

    @FocusState private var enfocado: Bool

    public init(
        etiqueta: String,
        marcador: String,
        texto: Binding<String>,
        estilo: EstiloTipografico = .campoTexto,
        contenido: UITextContentTypeCompat = .ninguno,
        teclado: TipoTecladoCompat = .normal,
        seguro: Bool = false
    ) {
        self.etiqueta = etiqueta
        self.marcador = marcador
        self._texto = texto
        self.estilo = estilo
        self.contenido = contenido
        self.teclado = teclado
        self.seguro = seguro
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e7) {
            Text(etiqueta)
                .estilo(.labelCampo, color: Paleta.textoTerciario)

            // Rediseño 2026-10: el campo es una tarjeta oscura, como las del
            // mockup; en foco el borde se vuelve rosa y más grueso.
            campo
                .estilo(estilo)
                .padding(.horizontal, TokensEspaciado.e16)
                .padding(.vertical, TokensEspaciado.e6)
                .frame(minHeight: TokensTamano.objetivoTactilMinimo + TokensEspaciado.e4)
                .background(Paleta.superficie)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                        .strokeBorder(enfocado ? Paleta.bordeEnfocado : Paleta.bordeInput,
                                      lineWidth: enfocado ? TokensEspaciado.e2 : TokensEspaciado.e1)
                )
                .animation(.easeOut(duration: TokensMovimiento.rapida), value: enfocado)
                .focused($enfocado)
                .accessibilityLabel(etiqueta)
        }
    }

    @ViewBuilder
    private var campo: some View {
        if seguro {
            SecureField("", text: $texto, prompt: promptMarcador)
                .contenidoDeTexto(contenido)
        } else {
            TextField("", text: $texto, prompt: promptMarcador)
                .contenidoDeTexto(contenido)
                .applyKeyboard(teclado)
        }
    }

    /// El `prompt` permite darle color propio al marcador; el placeholder por
    /// defecto de SwiftUI no es configurable y quedaría por debajo de AA.
    private var promptMarcador: Text {
        Text(marcador).foregroundColor(Paleta.textoPlaceholder)
    }
}

/// El campo de 6 caracteres de `reg-codigo` y `clave-codigo`.
public struct CampoCodigo: View {
    public static let largo = 6

    @Binding private var codigo: String
    private let marcador: String
    @FocusState private var enfocado: Bool

    public init(codigo: Binding<String>, marcador: String = "A7K2Q9") {
        self._codigo = codigo
        self.marcador = marcador
    }

    public var body: some View {
        TextField("", text: $codigo, prompt: Text(marcador).foregroundColor(Paleta.textoPlaceholder))
            .estilo(.codigo)
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
        case .codigo:
            self.textInputAutocapitalization(.characters)
        }
        #else
        self
        #endif
    }
}
