import SwiftUI
import UIKit
import TrainerCore

// Las hojas que explican la jerga de la tarjeta "Hoy": qué es una zona (Z1–Z5)
// y qué hay que llevar (ml/h, geles, g/h). Se abren tocando la píldora de la
// zona o los chips de la hidratación. Los números son los de la sesión: acá no
// se inventa ninguno, sólo se explica qué quiere decir cada uno.

/// Lo que se explica en la hoja del inicio. Va con los datos del momento en que
/// se tocó, para que la hoja no dependa de que el plan siga igual.
enum ExplicacionDeInicio: Identifiable {
    case zonas(actual: ZonaDeIntensidad)
    case avituallamiento(AvituallamientoDeSesion, duracionMinutos: Int)

    var id: String {
        switch self {
        case .zonas: return "zonas"
        case .avituallamiento: return "avituallamiento"
        }
    }
}

/// Textos chicos que comparten las piezas del inicio. En un `enum` con nombre
/// propio para no chocar con extensiones de otras pantallas.
enum InicioTextos {
    /// "moderada", "alta": el nombre de la intensidad de cada zona.
    static func intensidad(_ zona: ZonaDeIntensidad) -> String {
        switch zona {
        case .z1: return Textos.zoneLow
        case .z2: return Textos.zoneModerate
        case .z3: return Textos.zoneModerateHigh
        case .z4: return Textos.zoneHigh
        case .z5: return Textos.zoneMax
        }
    }

    /// Cómo se siente cada zona, en palabras simples: la prueba del habla.
    static func comoSeSiente(_ zona: ZonaDeIntensidad) -> String {
        switch zona {
        case .z1:
            return Textos.homeExplainerZone1
        case .z2:
            return Textos.homeExplainerZone2
        case .z3:
            return Textos.homeExplainerZone3
        case .z4:
            return Textos.homeExplainerZone4
        case .z5:
            return Textos.homeExplainerZone5
        }
    }

    /// "viernes" → "Viernes".
    static func primeraMayuscula(_ texto: String) -> String {
        guard let primera = texto.first else { return texto }
        return primera.uppercased() + String(texto.dropFirst())
    }
}

// MARK: - La hoja

/// El marco común: título, bajada, contenido y "Entendido".
///
/// La hoja mide exactamente lo que mide su contenido: se mide el alto ideal
/// (dentro de un `ScrollView`, que no lo aprieta) y ese alto es el único detent.
/// Hasta tenerlo medido se usa una estimación por tipo de hoja, para que no
/// aparezca con un tamaño muy distinto y después salte. Si el contenido pasa del
/// 85 % de la pantalla, la hoja va a `.large` y recién ahí se puede desplazar.
struct HojaDeExplicacion: View {
    let explicacion: ExplicacionDeInicio
    @Environment(\.dismiss) private var cerrar
    /// El alto ideal del contenido; `nil` hasta la primera medición.
    @State private var altoMedido: CGFloat? = nil

    var body: some View {
        ScrollView {
            contenido
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: AltoDelContenidoDeLaHoja.self, value: geo.size.height)
                    }
                )
        }
        .scrollDisabled(!desborda)
        .onPreferenceChange(AltoDelContenidoDeLaHoja.self) { alto in
            guard alto > 0 else { return }
            let redondeado = alto.rounded(.up)
            if abs(redondeado - (altoMedido ?? 0)) > 0.5 {
                altoMedido = redondeado
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .presentationDetents([desborda ? PresentationDetent.large : PresentationDetent.height(altoDelContenido)])
        .presentationDragIndicator(.visible)
    }

    private var contenido: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
            switch explicacion {
            case .zonas(let actual):
                encabezado(
                    Textos.homeExplainerZonesTitle,
                    bajada: Textos.homeExplainerZonesBody)
                ForEach(ZonaDeIntensidad.allCases, id: \.self) { zona in
                    FilaDeZona(zona: zona, esLaDeHoy: zona == actual)
                }
            case .avituallamiento(let a, let duracion):
                encabezado(
                    Textos.homeExplainerWhatToBringToday,
                    bajada: Textos.homeExplainerFuelingBody)
                if duracion > 0 {
                    PildoraDeEstado(Textos.homeExplainerWorkoutMinutes(duracion),
                                    simbolo: "clock", tono: .neutro)
                }
                ContenidoDelAvituallamiento(a: a)
            }

            BotonPrimario(Textos.commonGotIt) {
                Haptico.toque()
                cerrar()
            }
            .padding(.top, TokensEspaciado.e4)
        }
        .padding(.horizontal, TokensEspaciado.e16)
        .padding(.top, TokensEspaciado.e20)
        .padding(.bottom, TokensEspaciado.e20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Alto de la hoja

    /// Lo medido o, mientras tanto, la estimación.
    private var altoDelContenido: CGFloat {
        altoMedido ?? altoEstimado
    }

    /// Más del 85 % de la pantalla: la hoja se abre grande y se desplaza.
    private var desborda: Bool {
        altoDelContenido > altoDePantalla * 0.85
    }

    private var altoDePantalla: CGFloat {
        let escena = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return escena?.screen.bounds.height ?? 800
    }

    /// Una cuenta gruesa con los tamaños de cada pieza (márgenes, encabezado,
    /// filas, botón), sólo para el primer cuadro: después manda la medición.
    private var altoEstimado: CGFloat {
        let margenes = TokensEspaciado.e20 * 2
        let encabezado: CGFloat = 96
        let boton = TokensEspaciado.e52 + TokensEspaciado.e4
        let separacion = TokensEspaciado.e16
        switch explicacion {
        case .zonas:
            let filas = CGFloat(ZonaDeIntensidad.allCases.count)
            return margenes + encabezado + filas * 92 + (filas + 1) * separacion + boton
        case .avituallamiento(let a, let duracion):
            var filas: CGFloat = 3
            if a.sodioMg > 0 { filas += 1 }
            if a.carbohidratosAntesG > 0 { filas += 1 }
            if a.carbohidratosDespuesG > 0 || a.proteinaDespuesG > 0 { filas += 1 }
            let pildora: CGFloat = duracion > 0 ? TokensEspaciado.e34 + separacion : 0
            let cuerpo: CGFloat = filas * 88 + (filas - 1) * TokensEspaciado.e8
            let marco: CGFloat = margenes + encabezado + pildora + 2 * separacion + boton
            return marco + cuerpo
        }
    }

    private func encabezado(_ titulo: String, bajada: String) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            Text(titulo)
                .estilo(.tituloSeccion)
                .accessibilityAddTraits(.isHeader)
            Text(bajada)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Zonas

/// "Z2 · Moderada" con su medidor de cinco rayitas y cómo se siente.
private struct FilaDeZona: View {
    let zona: ZonaDeIntensidad
    let esLaDeHoy: Bool

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e12) {
            Text(zona.corta)
                .estilo(.tituloCard, color: esLaDeHoy ? Paleta.sobreAcento : Paleta.textoPrimario)
                .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
                .background(Circle().fill(esLaDeHoy ? Paleta.acento : Paleta.superficieAlterna))
                .shadow(color: esLaDeHoy ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e8)

            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                HStack(spacing: TokensEspaciado.e6) {
                    Text(InicioTextos.primeraMayuscula(InicioTextos.intensidad(zona)))
                        .estilo(.cuerpoDestacado)
                    if esLaDeHoy {
                        PildoraDeEstado(Textos.commonToday,
                                        simbolo: "figure.run", tono: .acento)
                    }
                    Spacer(minLength: 0)
                    medidor
                }
                Text(InicioTextos.comoSeSiente(zona))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(esLaDeHoy ? Paleta.acentoSuaveFondo : Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(esLaDeHoy ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                              lineWidth: TokensEspaciado.e1)
        )
        .accessibilityElement(children: .combine)
    }

    /// Cinco rayitas como el ícono de señal: crecen de izquierda a derecha, todas
    /// paradas sobre la misma base, y van llenas tantas como el número de la zona.
    private var medidor: some View {
        let ancho = TokensEspaciado.e6
        return HStack(alignment: .bottom, spacing: TokensEspaciado.e2) {
            ForEach(1...5, id: \.self) { nivel in
                RoundedRectangle(cornerRadius: ancho * 0.35, style: .continuous)
                    .fill(nivel <= zona.numero ? Paleta.acento : Paleta.superficieControl)
                    .frame(width: ancho, height: TokensEspaciado.e4 + CGFloat(nivel) * TokensEspaciado.e3)
            }
        }
        .frame(height: TokensEspaciado.e4 + 5 * TokensEspaciado.e3, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// El alto ideal del contenido de `HojaDeExplicacion`, medido desde adentro.
private struct AltoDelContenidoDeLaHoja: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Avituallamiento

/// Una fila por número que manda el servidor. Lo que viene en cero no se muestra
/// (salvo los geles, donde "hoy no hacen falta" también es información).
private struct ContenidoDelAvituallamiento: View {
    let a: AvituallamientoDeSesion

    var body: some View {
        VStack(spacing: TokensEspaciado.e8) {
            FilaDeAvituallamiento(
                simbolo: "drop.fill",
                titulo: Textos.homeExplainerWater,
                valor: "\(a.mililitrosPorHora) ml/h",
                texto: textoDelAgua)
            FilaDeAvituallamiento(
                simbolo: "leaf.fill",
                titulo: Textos.homeExplainerCarbs,
                valor: "\(a.carbohidratosPorHoraG) g/h",
                texto: Textos.homeExplainerCarbsBody)
            FilaDeAvituallamiento(
                simbolo: "bolt.fill",
                titulo: Textos.homeExplainerGels,
                valor: "\(a.geles)",
                texto: a.geles > 0
                    ? Textos.homeExplainerGelsBody
                    : Textos.homeExplainerNotNeededToday)
            if a.sodioMg > 0 {
                FilaDeAvituallamiento(
                    simbolo: "sparkles",
                    titulo: Textos.homeExplainerSodium,
                    valor: "\(a.sodioMg) mg",
                    texto: Textos.homeExplainerSodiumBody)
            }
            if a.carbohidratosAntesG > 0 {
                FilaDeAvituallamiento(
                    simbolo: "sunrise.fill",
                    titulo: Textos.homeExplainerBefore,
                    valor: "\(a.carbohidratosAntesG) g",
                    texto: Textos.homeExplainerCarbsBefore)
            }
            if a.carbohidratosDespuesG > 0 || a.proteinaDespuesG > 0 {
                FilaDeAvituallamiento(
                    simbolo: "house.fill",
                    titulo: Textos.homeExplainerAfter,
                    valor: "\(a.carbohidratosDespuesG) g + \(a.proteinaDespuesG) g",
                    texto: Textos.homeExplainerCarbsAfter)
            }
        }
    }

    private var textoDelAgua: String {
        let base = Textos.homeExplainerWaterBody
        guard a.mililitrosTotales > 0 else { return base }
        let total = Textos.homeExplainerWholeWorkout(Formato.litros(a.mililitrosTotales))
        return base + " " + total
    }
}

private struct FilaDeAvituallamiento: View {
    let simbolo: String
    let titulo: String
    let valor: String
    let texto: String

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e12) {
            Image(systemName: simbolo)
                .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                .foregroundStyle(Paleta.acento)
                .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
                .background(Circle().fill(Paleta.acentoChipActivo))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e6) {
                    Text(titulo).estilo(.cuerpoDestacado)
                    Spacer(minLength: 0)
                    Text(valor)
                        .estilo(.tituloCard, color: Paleta.acento)
                        .monospacedDigit()
                }
                Text(texto)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(radio: TokensRadio.boton)
        .accessibilityElement(children: .combine)
    }
}
