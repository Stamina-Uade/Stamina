import SwiftUI
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
        case .z1: return Textos.zonaBaja
        case .z2: return Textos.zonaModerada
        case .z3: return Textos.zonaModeradaAlta
        case .z4: return Textos.zonaAlta
        case .z5: return Textos.zonaMaxima
        }
    }

    /// Cómo se siente cada zona, en palabras simples: la prueba del habla.
    static func comoSeSiente(_ zona: ZonaDeIntensidad) -> String {
        switch zona {
        case .z1:
            return String(localized: "Muy suave. Podrías charlar sin parar. Sirve para recuperar.",
                          comment: "Explicación de la zona 1")
        case .z2:
            return String(localized: "Cómoda. Hablás en frases completas. Es la que arma tu base y la que más vas a usar.",
                          comment: "Explicación de la zona 2")
        case .z3:
            return String(localized: "Exigente pero sostenible. Te salen frases cortas. Afina tu ritmo de carrera.",
                          comment: "Explicación de la zona 3")
        case .z4:
            return String(localized: "Dura. Sólo palabras sueltas. Va en tramos, para subir tu umbral.",
                          comment: "Explicación de la zona 4")
        case .z5:
            return String(localized: "Al máximo. No podés hablar. Tramos muy cortos, para la velocidad.",
                          comment: "Explicación de la zona 5")
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
struct HojaDeExplicacion: View {
    let explicacion: ExplicacionDeInicio
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                switch explicacion {
                case .zonas(let actual):
                    encabezado(
                        String(localized: "Zonas de intensidad", comment: "Título de la hoja de zonas"),
                        bajada: String(localized: "La zona dice qué tan fuerte ir. La forma más simple de medirla: cuánto podés hablar mientras te movés.",
                                       comment: "Bajada de la hoja de zonas"))
                    ForEach(ZonaDeIntensidad.allCases, id: \.self) { zona in
                        FilaDeZona(zona: zona, esLaDeHoy: zona == actual)
                    }
                case .avituallamiento(let a, let duracion):
                    encabezado(
                        String(localized: "Qué llevar hoy", comment: "Título de la hoja de hidratación"),
                        bajada: String(localized: "Lo que conviene tomar en esta salida, calculado con tu peso y la sesión de hoy.",
                                       comment: "Bajada de la hoja de hidratación"))
                    if duracion > 0 {
                        PildoraDeEstado(String(localized: "Salida de \(duracion) min", comment: "Duración en la hoja de hidratación"),
                                        simbolo: "clock", tono: .neutro)
                    }
                    ContenidoDelAvituallamiento(a: a)
                }

                BotonPrimario(String(localized: "Entendido", comment: "Cierra la hoja de explicación")) {
                    Haptico.toque()
                    cerrar()
                }
                .padding(.top, TokensEspaciado.e4)
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e20)
            .padding(.bottom, TokensEspaciado.e20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
                        PildoraDeEstado(String(localized: "Hoy", comment: "Marca la zona de la sesión de hoy"),
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

    /// Cinco rayitas: tantas llenas como el número de la zona.
    private var medidor: some View {
        HStack(spacing: TokensEspaciado.e2) {
            ForEach(1...5, id: \.self) { nivel in
                Capsule(style: .continuous)
                    .fill(nivel <= zona.numero ? Paleta.acento : Paleta.superficieControl)
                    .frame(width: TokensEspaciado.e6, height: TokensEspaciado.e4 + CGFloat(nivel) * TokensEspaciado.e2)
            }
        }
        .frame(height: TokensEspaciado.e14, alignment: .bottom)
        .accessibilityHidden(true)
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
                titulo: String(localized: "Agua", comment: "Fila de la hoja de hidratación"),
                valor: "\(a.mililitrosPorHora) ml/h",
                texto: textoDelAgua)
            FilaDeAvituallamiento(
                simbolo: "leaf.fill",
                titulo: String(localized: "Carbohidratos", comment: "Fila de la hoja de hidratación"),
                valor: "\(a.carbohidratosPorHoraG) g/h",
                texto: String(localized: "La energía que tu cuerpo usa más rápido. Es lo que conviene sumar por cada hora, entre geles, bebida deportiva o algo sólido.",
                              comment: "Explicación de los carbohidratos por hora"))
            FilaDeAvituallamiento(
                simbolo: "bolt.fill",
                titulo: String(localized: "Geles", comment: "Fila de la hoja de hidratación"),
                valor: "\(a.geles)",
                texto: a.geles > 0
                    ? String(localized: "Sobres de carbohidratos rápidos. Tomalos con agua, repartidos durante la salida.",
                             comment: "Explicación de los geles")
                    : String(localized: "Hoy no hacen falta: con el agua alcanza.",
                             comment: "Explicación sin geles"))
            if a.sodioMg > 0 {
                FilaDeAvituallamiento(
                    simbolo: "sparkles",
                    titulo: String(localized: "Sodio", comment: "Fila de la hoja de hidratación"),
                    valor: "\(a.sodioMg) mg",
                    texto: String(localized: "Las sales que perdés al transpirar. Van en una bebida con electrolitos o en pastillas de sal.",
                                  comment: "Explicación del sodio"))
            }
            if a.carbohidratosAntesG > 0 {
                FilaDeAvituallamiento(
                    simbolo: "sunrise.fill",
                    titulo: String(localized: "Antes de salir", comment: "Fila de la hoja de hidratación"),
                    valor: "\(a.carbohidratosAntesG) g",
                    texto: String(localized: "Carbohidratos en la comida previa, para salir con energía.",
                                  comment: "Explicación de los carbohidratos antes"))
            }
            if a.carbohidratosDespuesG > 0 || a.proteinaDespuesG > 0 {
                FilaDeAvituallamiento(
                    simbolo: "house.fill",
                    titulo: String(localized: "Al volver", comment: "Fila de la hoja de hidratación"),
                    valor: "\(a.carbohidratosDespuesG) g + \(a.proteinaDespuesG) g",
                    texto: String(localized: "Carbohidratos y proteína para recuperarte.",
                                  comment: "Explicación de la comida de después"))
            }
        }
    }

    private var textoDelAgua: String {
        let base = String(localized: "Lo que conviene tomar por cada hora: mejor en sorbos chicos y seguidos que todo de golpe.",
                          comment: "Explicación del agua por hora")
        guard a.mililitrosTotales > 0 else { return base }
        let total = String(localized: "En toda la salida: \(Formato.litros(a.mililitrosTotales)).",
                           comment: "Agua total de la salida")
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
