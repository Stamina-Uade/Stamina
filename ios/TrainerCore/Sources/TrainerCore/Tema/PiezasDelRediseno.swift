import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// =============================================================================
// Las piezas del rediseño 2026-10 (mockup "7 pantallas principales del MVP").
//
// El mockup se apoya en cinco gestos que se repiten en todas las pantallas:
//
//   1. un título PESADO arriba, con una línea chica encima (fecha, contexto);
//   2. píldoras de estado ("GPS ok", "Apto vigente · vence en 45 días");
//   3. UN número protagonista con la unidad chica pegada ("7,42 km");
//   4. tarjetas de métrica en fila (tiempo, ritmo, pulso);
//   5. una tarjeta héroe con foto o degradado y el acento rosa abajo.
//
// Están acá, en el design system, y no copiadas en cada pantalla: así un cambio
// de radio o de peso se hace una vez. Todo sale de Paleta y de los tokens.
// =============================================================================

// MARK: - 1. Encabezado de pestaña

/// "Viernes 16 de octubre" chico arriba y "Buen día, Sofi" grande abajo. Lo
/// que va a la derecha (campana, avatar, racha) lo pone la pantalla.
public struct EncabezadoDePestana<Accesorio: View>: View {
    private let titulo: String
    private let sobretitulo: String?
    private let accesorio: Accesorio

    public init(_ titulo: String, sobretitulo: String? = nil,
                @ViewBuilder accesorio: () -> Accesorio) {
        self.titulo = titulo
        self.sobretitulo = sobretitulo
        self.accesorio = accesorio()
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: TokensEspaciado.e12) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                if let sobretitulo, !sobretitulo.isEmpty {
                    Text(sobretitulo)
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                }
                Text(titulo)
                    .estilo(.display)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            accesorio
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension EncabezadoDePestana where Accesorio == EmptyView {
    public init(_ titulo: String, sobretitulo: String? = nil) {
        self.init(titulo, sobretitulo: sobretitulo) { EmptyView() }
    }
}

// MARK: - 2. Píldora de estado

/// El tono de una píldora. El color nunca va solo: siempre hay ícono o texto.
public enum TonoDePildora: Sendable {
    /// Lo que está bien o activo: acento.
    case acento
    /// Un dato, sin juicio.
    case neutro
    /// Algo que hay que mirar: el rojo de error.
    case alerta
}

/// "● GPS ok", "♥ 165", "Apto vigente · vence en 45 días".
public struct PildoraDeEstado: View {
    private let texto: String
    private let simbolo: String?
    private let tono: TonoDePildora

    public init(_ texto: String, simbolo: String? = nil, tono: TonoDePildora = .neutro) {
        self.texto = texto
        self.simbolo = simbolo
        self.tono = tono
    }

    private var colorDelIcono: Color {
        switch tono {
        case .acento: return Paleta.acento
        case .neutro: return Paleta.textoSecundario
        case .alerta: return Paleta.error
        }
    }

    private var fondo: Color {
        switch tono {
        case .acento: return Paleta.acentoChipActivo
        case .neutro: return Paleta.superficie
        case .alerta: return Paleta.errorFondo
        }
    }

    private var borde: Color {
        switch tono {
        case .acento: return Paleta.acentoSuaveBorde
        case .neutro: return Paleta.bordeSuperficie
        case .alerta: return Paleta.errorBorde
        }
    }

    public var body: some View {
        HStack(spacing: TokensEspaciado.e5) {
            if let simbolo {
                Image(systemName: simbolo)
                    .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                    .foregroundStyle(colorDelIcono)
                    .accessibilityHidden(true)
            } else {
                Circle()
                    .fill(colorDelIcono)
                    .frame(width: TokensEspaciado.e6, height: TokensEspaciado.e6)
                    .accessibilityHidden(true)
            }
            Text(texto)
                .estilo(.chip, color: Paleta.textoPrimario)
                .lineLimit(1)
        }
        .padding(.horizontal, TokensEspaciado.e10)
        .padding(.vertical, TokensEspaciado.e6)
        .background(fondo)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(borde, lineWidth: TokensEspaciado.e1))
        .accessibilityElement(children: .combine)
    }
}

extension EstiloTipografico {
    /// Texto dentro de una píldora o chip (`tokens.json` → `chip`).
    public static let chip = EstiloTipografico(
        tamano: TokensTipografia.chipTamano,
        peso: TokensTipografia.chipPeso,
        interlineado: 1.35, referencia: .caption)
}

// MARK: - 3. Métrica protagonista

/// "7,42 km": el número enorme y la unidad chica, alineados por la base.
public struct MetricaHeroe: View {
    private let valor: String
    private let unidad: String?
    private let color: Color
    private let etiquetaAccesible: String?

    /// - Parameter etiquetaAccesible: qué es el número ("Distancia"). VoiceOver
    ///   lee "Distancia, 7,42 km" en vez de dos textos sueltos.
    public init(_ valor: String, unidad: String? = nil, color: Color = Paleta.textoPrimario,
                etiquetaAccesible: String? = nil) {
        self.valor = valor
        self.unidad = unidad
        self.color = color
        self.etiquetaAccesible = etiquetaAccesible
    }

    private var textoAccesible: String {
        var partes: [String] = []
        if let etiquetaAccesible { partes.append(etiquetaAccesible + ",") }
        partes.append(valor)
        if let unidad, !unidad.isEmpty { partes.append(unidad) }
        return partes.joined(separator: " ")
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e4) {
            Text(valor)
                .estilo(.metricaHeroe, color: color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let unidad, !unidad.isEmpty {
                Text(unidad)
                    .estilo(.unidadHeroe, color: Paleta.acento)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: textoAccesible))
    }
}

// MARK: - 4. Tarjeta de métrica

/// La tarjeta chica de "Tiempo 1:00:07", "Ritmo 5'11''", "Pulso 165".
public struct TarjetaMetrica: View {
    private let etiqueta: String
    private let valor: String
    private let unidad: String?
    private let simbolo: String?
    private let destacada: Bool

    public init(_ etiqueta: String, valor: String, unidad: String? = nil,
                simbolo: String? = nil, destacada: Bool = false) {
        self.etiqueta = etiqueta
        self.valor = valor
        self.unidad = unidad
        self.simbolo = simbolo
        self.destacada = destacada
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            HStack(spacing: TokensEspaciado.e4) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                        .foregroundStyle(destacada ? Paleta.acento : Paleta.textoTerciario)
                        .accessibilityHidden(true)
                }
                Text(etiqueta)
                    .estilo(.labelCampo, color: Paleta.textoSecundario)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e2) {
                Text(valor)
                    .estilo(.metricaMedia, color: Paleta.textoPrimario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unidad, !unidad.isEmpty {
                    Text(unidad).estilo(.labelCampo, color: Paleta.textoTerciario)
                }
            }
        }
        .padding(.horizontal, TokensEspaciado.e12)
        .padding(.vertical, TokensEspaciado.e11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(destacada ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                              lineWidth: TokensEspaciado.e1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [etiqueta + ",", valor, unidad ?? ""]
            .filter { !$0.isEmpty }.joined(separator: " ")))
    }
}

// MARK: - 5. Tarjeta héroe

/// La tarjeta grande con foto (o degradado) y el contenido abajo, sobre un velo
/// que asegura la lectura. Es la de "23 días para tu media maratón".
public struct TarjetaHeroe<Contenido: View>: View {
    private let imagen: String?
    private let encuadre: UnitPoint
    private let alto: CGFloat
    private let contenido: Contenido

    /// - Parameters:
    ///   - imagen: un recurso del catálogo de assets. Sin imagen, la tarjeta usa
    ///     el degradado de la marca: nunca queda un rectángulo vacío.
    ///   - encuadre: dónde está la persona en la foto (fracciones de la foto). El
    ///     recorte se centra en ese punto, sin salirse de la foto, para que no
    ///     quede afuera la cabeza. Sin dato, el centro.
    ///   - alto: alto mínimo; crece si el contenido lo pide (Dynamic Type).
    public init(imagen: String? = nil, encuadre: UnitPoint = .center, alto: CGFloat = TokensEspaciado.e56 * 4,
                @ViewBuilder contenido: () -> Contenido) {
        self.imagen = imagen
        self.encuadre = encuadre
        self.alto = alto
        self.contenido = contenido()
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            fondo
            // Ronda 7: la foto va A COLOR y casi entera. El degradado sólo
            // oscurece la franja de abajo, donde va el texto, para que se lea.
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.15), location: 0.0),
                    .init(color: Color.clear, location: 0.25),
                    .init(color: Color.clear, location: 0.45),
                    .init(color: Color.black.opacity(0.45), location: 0.72),
                    .init(color: Color.black.opacity(0.78), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom)
                .accessibilityHidden(true)
            contenido
                .padding(TokensEspaciado.e16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: alto, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
        // Sobre la foto el texto es siempre claro, aun en modo día.
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var fondo: some View {
        if let imagen {
            GeometryReader { geo in
                let recorte = EncuadreDeFoto.recorte(foto: EncuadreDeFoto.tamanoDeFoto(imagen),
                                                      marco: geo.size, encuadre: encuadre)
                Image(imagen)
                    .resizable()
                    .scaledToFill()
                    .frame(width: recorte.width, height: recorte.height)
                    .offset(x: recorte.minX, y: recorte.minY)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .clipped()
            }
            .accessibilityHidden(true)
        } else {
            ZStack {
                Color.black
                RadialGradient(colors: [Paleta.acentoProfundo, Color.clear],
                               center: .bottomTrailing, startRadius: 0,
                               endRadius: TokensEspaciado.e56 * 5)
            }
            .accessibilityHidden(true)
        }
    }
}

/// El recorte de la foto de una `TarjetaHeroe`, centrado en la persona.
public enum EncuadreDeFoto {
    /// El tamaño de la foto en el catálogo; sin ella, `nil` (se recorta al centro).
    static func tamanoDeFoto(_ nombre: String) -> CGSize? {
        #if canImport(UIKit)
        return UIImage(named: nombre)?.size
        #else
        return nil
        #endif
    }

    /// Dónde va la foto escalada para llenar `marco` con `encuadre` lo más al
    /// centro posible, sin dejar huecos: el origen (negativo) y el tamaño.
    public static func recorte(foto: CGSize?, marco: CGSize, encuadre: UnitPoint) -> CGRect {
        guard let foto, foto.width > 0, foto.height > 0, marco.width > 0, marco.height > 0 else {
            return CGRect(origin: .zero, size: marco)
        }
        let escala = max(marco.width / foto.width, marco.height / foto.height)
        let ancho = foto.width * escala
        let alto = foto.height * escala
        let x = min(0, max(marco.width - ancho, marco.width / 2 - encuadre.x * ancho))
        let y = min(0, max(marco.height - alto, marco.height / 2 - encuadre.y * alto))
        return CGRect(x: x, y: y, width: ancho, height: alto)
    }
}

// MARK: - 6. Botón circular

/// Los botones redondos del entreno en vivo: el grande rosa con halo (pausa) y
/// los chicos oscuros a los costados (centrar, finalizar).
public struct BotonCircular: View {
    public enum Estilo: Sendable { case primario, secundario }

    private let simbolo: String
    private let etiqueta: String
    private let estilo: Estilo
    private let diametro: CGFloat
    private let accion: () -> Void

    /// - Parameter etiqueta: lo que VoiceOver dice. Un ícono sin nombre es un
    ///   botón que no existe para quien no ve.
    public init(_ simbolo: String, etiqueta: String, estilo: Estilo = .secundario,
                diametro: CGFloat = TokensTamano.objetivoTactilMinimo,
                accion: @escaping () -> Void) {
        self.simbolo = simbolo
        self.etiqueta = etiqueta
        self.estilo = estilo
        self.diametro = max(diametro, TokensTamano.objetivoTactilMinimo)
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            ZStack {
                Circle()
                    .fill(estilo == .primario ? Paleta.acento : Paleta.superficieAlterna)
                    .shadow(color: estilo == .primario ? Paleta.acentoBrillo : Color.clear,
                            radius: diametro * 0.3)
                if estilo == .secundario {
                    Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
                }
                Image(systemName: simbolo)
                    .font(.system(size: diametro * 0.36, weight: .bold))
                    .foregroundStyle(estilo == .primario ? Color.white : Paleta.textoPrimario)
            }
            .frame(width: diametro, height: diametro)
            .contentShape(Circle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(etiqueta)
    }
}

// MARK: - 7. Botón tonal

/// La cápsula oscura que acompaña al primario con el mismo peso visual menor:
/// "Pausar" al lado de "Seguir".
public struct BotonTonal: View {
    private let titulo: String
    private let cargando: Bool
    private let accion: () -> Void

    /// - Parameter cargando: mientras espera, sólo la ruedita en lugar del texto.
    public init(_ titulo: String, cargando: Bool = false, accion: @escaping () -> Void) {
        self.titulo = titulo
        self.cargando = cargando
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            ZStack {
                if cargando {
                    ProgressView().tint(Paleta.textoPrimario)
                } else {
                    Text(titulo)
                        .estilo(.botonPrimario, color: Paleta.textoPrimario)
                }
            }
                .frame(maxWidth: .infinity)
                .frame(minHeight: TokensTamano.botonPrimario)
                .background(Paleta.superficieAlterna)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Paleta.bordeBotonSecundario, lineWidth: TokensEspaciado.e1))
                .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(titulo)
    }
}

// MARK: - 8. Encabezado de sección

/// "Semana de carrera" a la izquierda y, si hace falta, "Ver todo" a la derecha.
public struct EncabezadoDeSeccion: View {
    private let titulo: String
    private let detalle: String?
    private let accion: String?
    private let alTocar: (() -> Void)?

    public init(_ titulo: String, detalle: String? = nil,
                accion: String? = nil, alTocar: (() -> Void)? = nil) {
        self.titulo = titulo
        self.detalle = detalle
        self.accion = accion
        self.alTocar = alTocar
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e6) {
            Text(titulo)
                .estilo(.tituloSeccion)
                .accessibilityAddTraits(.isHeader)
            if let detalle {
                Text(detalle).estilo(.labelCampo, color: Paleta.textoTerciario)
            }
            Spacer(minLength: 0)
            if let accion, let alTocar {
                Button(action: alTocar) {
                    Text(accion)
                        .estilo(.tituloCard, color: Paleta.textoAcento)
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
            }
        }
    }
}
