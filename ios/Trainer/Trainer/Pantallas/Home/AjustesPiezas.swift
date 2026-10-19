import SwiftUI
import TrainerCore

// =============================================================================
// Las piezas con las que se arma Ajustes (rediseño 2026-10, ronda 4).
//
// Pedido de Ivan: limpio, visual, textos ultra cortos. La raíz es una lista
// corta de filas (ícono + una o dos palabras + valor + chevron) y cada fila
// abre su página. Ronda 5: la flecha y el título van fijos arriba, en una
// línea, como una barra de navegación; abajo scrollea el contenido.
// =============================================================================

/// Las páginas que se abren desde la raíz de Ajustes.
enum PaginaDeAjustes: String, Hashable {
    case aspecto, notificaciones, unidades, objetivos
}

/// Lo que sobrevive a que el color re-cree el Home (`RaizHomeView` usa
/// `.id(acentoGuardado)` y todo `@State` de Ajustes se pierde). Es `static`
/// justamente por eso: `AjustesView` lo lee y lo borra en su `onAppear`.
enum AjustesAncla {
    /// El `id` del bloque de color, para volver a él con el scroll.
    static let color = "ajustes_color"
    /// La página que estaba abierta cuando se aplicó el color.
    static var paginaAlVolver: PaginaDeAjustes?
}

/// El tono del cuadradito del ícono. El color nunca va solo: siempre hay texto.
/// `peligro`: acciones destructivas (cerrar sesión), en el rojo fuerte.
enum AjustesTono {
    case acento, neutro, peligro
}

// MARK: - Página

/// Una página de Ajustes: arriba, fijos, la flecha para volver y el título
/// (`CabeceraSecundaria`); abajo, el contenido que scrollea. Se vuelve también
/// deslizando desde el borde izquierdo.
struct AjustesPagina<Contenido: View>: View {
    private let titulo: String
    /// Si viene, el scroll arranca en ese `id` (ver `AjustesAncla`).
    private let ancla: String?
    private let volver: () -> Void
    private let contenido: Contenido

    init(_ titulo: String, ancla: String? = nil, volver: @escaping () -> Void,
         @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.ancla = ancla
        self.volver = volver
        self.contenido = contenido()
    }

    var body: some View {
        VStack(spacing: 0) {
            CabeceraSecundaria(titulo: titulo, volver: volver)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                        contenido
                    }
                    .padding(.horizontal, TokensEspaciado.e16)
                    .padding(.top, TokensEspaciado.e8)
                    .padding(.bottom, TokensEspaciado.e36)
                }
                .onAppear {
                    guard let ancla else { return }
                    DispatchQueue.main.async { proxy.scrollTo(ancla, anchor: .top) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Paleta.fondo)
        .modifier(AjustesDeslizarParaVolver(accion: volver))
    }
}

/// El gesto de volver de iOS, hecho a mano: Ajustes vive en las pestañas
/// propias del Home, no en un `NavigationStack`.
private struct AjustesDeslizarParaVolver: ViewModifier {
    let accion: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: TokensEspaciado.e20)
                .onEnded { gesto in
                    let dx = gesto.translation.width
                    guard gesto.startLocation.x < TokensEspaciado.e26,
                          dx > TokensEspaciado.e56 + TokensEspaciado.e20,
                          abs(gesto.translation.height) < dx / 2 else { return }
                    accion()
                }
        )
    }
}

// MARK: - Filas

/// El ícono de un ajuste, en su cuadradito tonal.
struct AjustesIcono: View {
    let simbolo: String
    var tono: AjustesTono = .acento

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: TokensTipografia.valorFilaTamano, weight: .semibold))
            .foregroundStyle(colorDelIcono)
            .frame(width: TokensEspaciado.e34, height: TokensEspaciado.e34)
            .background(fondo)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous))
            .accessibilityHidden(true)
    }

    private var colorDelIcono: Color {
        switch tono {
        case .acento: return Paleta.acento
        case .neutro: return Paleta.textoSecundario
        case .peligro: return Paleta.peligro
        }
    }

    private var fondo: Color {
        switch tono {
        case .acento: return Paleta.acentoChipActivo
        case .neutro: return Paleta.superficieHundida
        case .peligro: return Paleta.peligro.opacity(0.15)
        }
    }
}

/// Una tarjeta con filas una abajo de la otra, separadas por un divisor.
struct AjustesTarjetaDeFilas<Contenido: View>: View {
    private let contenido: Contenido

    init(@ViewBuilder contenido: () -> Contenido) {
        self.contenido = contenido()
    }

    var body: some View {
        VStack(spacing: 0) {
            contenido
        }
        .frame(maxWidth: .infinity)
        .tarjeta(radio: TokensRadio.card)
    }
}

/// El divisor entre filas, alineado con el texto (no con el ícono).
struct AjustesDivisorDeFila: View {
    var body: some View {
        Divider()
            .background(Paleta.divisor)
            .padding(.leading, TokensEspaciado.e14 + TokensEspaciado.e34 + TokensEspaciado.e12)
    }
}

/// Una fila que se toca: ícono, título, un valor corto y el chevron.
struct AjustesFila: View {
    let simbolo: String
    let titulo: String
    var valor: String? = nil
    /// Un puntito de color al lado del valor (el color de la app).
    var muestra: Color? = nil
    /// Lo que lee VoiceOver como valor, si no alcanza con `valor`.
    var valorAccesible: String? = nil
    var tono: AjustesTono = .acento
    /// `nil`: sin nada al final (p.ej. Cerrar sesión).
    var simboloFinal: String? = "chevron.right"
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e12) {
                AjustesIcono(simbolo: simbolo, tono: tono)
                Text(titulo)
                    .estilo(.opcionTitulo, color: tono == .peligro ? Paleta.peligro : Paleta.textoPrimario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: TokensEspaciado.e8)
                if let valor {
                    Text(valor)
                        .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                        .lineLimit(1)
                }
                if let muestra {
                    Circle()
                        .fill(muestra)
                        .frame(width: TokensEspaciado.e12, height: TokensEspaciado.e12)
                        .overlay(Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
                }
                if let simboloFinal {
                    Image(systemName: simboloFinal)
                        .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                        .foregroundStyle(simboloFinal == "chevron.right" ? Paleta.textoTerciario : Paleta.acento)
                }
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .padding(.vertical, TokensEspaciado.e8)
            .frame(maxWidth: .infinity)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titulo)
        .accessibilityValue(valorAccesible ?? valor ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

/// Un aviso que se prende y se apaga: ícono y título. Lo que hace va en la
/// pista de VoiceOver, no en pantalla.
struct AjustesFilaInterruptor: View {
    let simbolo: String
    let titulo: String
    var pista: String? = nil
    @Binding var encendido: Bool

    var body: some View {
        Toggle(isOn: $encendido) {
            HStack(spacing: TokensEspaciado.e12) {
                AjustesIcono(simbolo: simbolo, tono: encendido ? .acento : .neutro)
                Text(titulo)
                    .estilo(.opcionTitulo, color: Paleta.textoPrimario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .tint(Paleta.interruptorActivo)
        .padding(.horizontal, TokensEspaciado.e14)
        .padding(.vertical, TokensEspaciado.e8)
        .objetivoTactilAlto()
        .accessibilityHint(pista ?? "")
        .onChange(of: encendido) { _ in Haptico.seleccion() }
    }
}

/// El rótulo chico en mayúsculas que separa bloques ("MODO", "COLOR").
struct AjustesRotulo: View {
    private let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto)
            .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, TokensEspaciado.e4)
            .accessibilityAddTraits(.isHeader)
    }
}
