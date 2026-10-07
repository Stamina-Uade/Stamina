import SwiftUI
import TrainerCore

// =============================================================================
// El andamio de una pantalla del flujo: título, explicación, contenido y un pie
// que no se va de la pantalla.
//
// El diseño pone el botón primario abajo de todo con `margin-top:auto`, es
// decir: pegado al fondo, siempre visible. Acá el contenido scrollea y **el pie
// no**. Es lo que hace que con Dynamic Type grande el botón siga estando donde
// la persona lo busca, en vez de quedar tres pantallazos más abajo.
// =============================================================================

// 🛑 NO AGREGAR UN PARÁMETRO DE CLOSURE ANTES DE `contenido`.
//
// Ya pasó una vez, compiló sin un warning y rompió las 16 pantallas: con un
// `volver: (() -> Void)? = nil` acá arriba, Swift emparejaba la trailing closure
// sin etiqueta —el CONTENIDO de la pantalla— con `volver`, la ejecutaba como
// `() -> Void` descartando el resultado, y `contenido` caía a su `EmptyView()`
// por defecto. Resultado: las pantallas perdían su contenido y aparecía una
// flecha de más. La flecha vive en `RaizFlujoView`, que es un solo lugar.
struct PantallaPaso<Contenido: View, Pie: View>: View {
    private let titulo: String
    private let texto: String?
    private let contenido: Contenido
    private let pie: Pie

    init(
        titulo: String,
        texto: String? = nil,
        @ViewBuilder contenido: () -> Contenido = { EmptyView() },
        @ViewBuilder pie: () -> Pie
    ) {
        self.titulo = titulo
        self.texto = texto
        self.contenido = contenido()
        self.pie = pie()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
                    Text(titulo)
                        .estilo(.tituloPantalla)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let texto {
                        Text(texto)
                            .estilo(.cuerpo, color: Paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    contenido
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, TokensEspaciado.e26)
                .padding(.top, TokensEspaciado.e12)
                .padding(.bottom, TokensEspaciado.e20)
            }
            .scrollDismissesKeyboardCompat()

            VStack(spacing: TokensEspaciado.e10) { pie }
                .padding(.horizontal, TokensEspaciado.e26)
                .padding(.bottom, TokensEspaciado.e34)
                .padding(.top, TokensEspaciado.e12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }
}

/// Pantalla de cierre de un flujo: `clave-lista` y `reg-listo`. El diseño las
/// dibuja distinto —cuadrado de acento arriba, título más grande— porque son un
/// final, no un paso más.
struct PantallaCierre<Contenido: View, Pie: View>: View {
    private let titulo: String
    private let texto: String
    private let contenido: Contenido
    private let pie: Pie

    init(
        titulo: String,
        texto: String,
        @ViewBuilder contenido: () -> Contenido = { EmptyView() },
        @ViewBuilder pie: () -> Pie
    ) {
        self.titulo = titulo
        self.texto = texto
        self.contenido = contenido()
        self.pie = pie()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                    RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                        .fill(Paleta.acento)
                        .frame(width: TokensEspaciado.e52, height: TokensEspaciado.e52)
                        .accessibilityHidden(true)

                    Text(titulo)
                        .estilo(.tituloConfirmacion)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(texto)
                        .estilo(.cuerpoDestacado, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)

                    contenido
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, TokensEspaciado.e26)
                .padding(.top, TokensEspaciado.e26)
                .padding(.bottom, TokensEspaciado.e20)
            }

            VStack(spacing: TokensEspaciado.e10) { pie }
                .padding(.horizontal, TokensEspaciado.e26)
                .padding(.bottom, TokensEspaciado.e34)
                .padding(.top, TokensEspaciado.e12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }
}

/// El pie de los pasos de perfil (decisión 0008): el error del guardado,
/// "Continuar" —que guarda ESE paso con `PATCH /me` antes de avanzar— y la salida
/// "Completar después".
///
/// El error va acá y no con el contenido: el contenido scrollea, y un error que
/// queda tres pantallazos arriba del botón que lo produjo no lo lee nadie.
struct PieDePerfil: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    private let habilitado: Bool
    private let motivoDeshabilitado: String
    private let ahoraNo: (() -> Void)?

    /// - Parameter ahoraNo: el "Ahora no" de `reg-medicion`, el único paso que el
    ///   diseño deja saltear sin elegir.
    init(habilitado: Bool = true,
         motivoDeshabilitado: String = Textos.comunCompletaParaSeguir,
         ahoraNo: (() -> Void)? = nil) {
        self.habilitado = habilitado
        self.motivoDeshabilitado = motivoDeshabilitado
        self.ahoraNo = ahoraNo
    }

    var body: some View {
        VStack(spacing: TokensEspaciado.e10) {
            BotonPrimario(Textos.comunContinuar,
                          habilitado: habilitado && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: motivoDeshabilitado) {
                Task { await flujo.guardarYSeguir() }
            }

            if let ahoraNo {
                BotonTexto(Textos.regMedicionAhoraNo, color: Paleta.textoSecundario, accion: ahoraNo)
                    .disabled(flujo.enCurso)
            }

            if flujo.pantalla.ofreceCompletarDespues {
                BotonTexto(Textos.regCompletarDespues, color: Paleta.textoSecundario) {
                    flujo.completarDespues()
                }
                // Mientras "Continuar" guarda, salir dejaría su error sin nadie que lo lea.
                .disabled(flujo.enCurso)
            }
        }
    }
}

/// La flecha `‹` de volver. Se dibuja del tamaño del diseño y responde en 48.
struct FlechaVolver: View {
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: "chevron.left")
                .font(.system(size: TokensTipografia.tituloCardTamano,
                              weight: TokensTipografia.tituloCardPeso))
                .foregroundStyle(Paleta.textoSecundario)
                .objetivoTactil()
        }
        .accessibilityLabel(Textos.comunVolver)
    }
}

extension View {
    /// `scrollDismissesKeyboard` es de iOS 16, pero se aísla igual: el día que
    /// el mínimo baje, el `#available` está en un solo lugar.
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}
