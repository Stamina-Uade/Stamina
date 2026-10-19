import SwiftUI
import TrainerCore

// Las piezas chicas de `InicioView`: la fila de la agenda, sus chips, el gráfico
// de carga y la racha. Separadas para que el `body` del inicio se lea de corrido.

// MARK: - La fila de la agenda

struct FilaDeAgendaView: View {
    @EnvironmentObject private var estado: EstadoHome
    let fila: FilaDeAgenda

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e11) {
            Text(Formato.hora(minutoDelDia: fila.minutoDelDia))
                .estilo(.notaLegal, color: fila.clase == .sesion ? Paleta.acento : Paleta.textoTerciario)
                .monospacedDigit()
                .frame(width: TokensEspaciado.e44, alignment: .leading)
                .padding(.top, TokensEspaciado.e12)

            switch fila.clase {
            case .sesion:
                if let sesion = estado.sesion { tarjetaDeLaSesion(sesion) }
            case .simple, .gimnasio:
                tarjetaSimple
            }
        }
    }

    /// La única fila con chips: es la sesión del día. Lleva el borde del acento.
    private func tarjetaDeLaSesion(_ sesion: SesionDelDia) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e9) {
            HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e10) {
                Button { estado.ir(a: .entreno) } label: {
                    Text(titulo(de: sesion))
                        .estilo(.cuerpoDestacado)
                        .multilineTextAlignment(.leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                Spacer(minLength: 0)
            }

            // Sin el peso, el servidor no calcula el avituallamiento: no se inventa.
            if let avituallamiento = sesion.avituallamiento {
                FlujoDeChips(chips: chips(de: avituallamiento))

                if let zona = sesion.zona {
                    Text(Textos.homeHydrationNote(
                        avituallamiento.mililitrosPorHora,
                        avituallamiento.carbohidratosPorHoraG,
                        zona.corta,
                        InicioTextos.intensidad(zona)))
                        .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, TokensEspaciado.e13)
        .padding(.vertical, TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1)
        )
    }

    private var tarjetaSimple: some View {
        Button {
            if let destino = fila.destino { estado.ir(a: destino) }
        } label: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                Text(fila.titulo).estilo(.cuerpoSecundario)
                Text(fila.detalle)
                    .estilo(.notaLegal, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TokensEspaciado.e13)
            .padding(.vertical, TokensEspaciado.e11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjeta(radio: TokensRadio.boton)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .disabled(fila.destino == nil)
        .accessibilityElement(children: .combine)
    }

    /// "Running suave (51 min) · 7,1 km · Z2", con lo que el plan traiga.
    private func titulo(de sesion: SesionDelDia) -> String {
        var partes = [sesion.tipo]
        if let metros = sesion.distanciaMetros {
            partes.append(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))
        }
        if let zona = sesion.zona { partes.append(zona.corta) }
        return partes.joined(separator: " · ")
    }

    private func chips(de avituallamiento: AvituallamientoDeSesion) -> [(String, Bool)] {
        var chips: [(String, Bool)] = []
        if avituallamiento.geles > 0 {
            chips.append((Textos.homeGelCount(avituallamiento.geles), true))
        }
        chips.append(("\(avituallamiento.mililitrosPorHora) ml/h", false))
        chips.append(("\(avituallamiento.carbohidratosPorHoraG) g/h", false))
        return chips
    }
}

/// Los chips de una fila, que se acomodan solos cuando no entran.
struct FlujoDeChips: View {
    let chips: [(String, Bool)]

    var body: some View {
        // `WrappingHStack` no existe en iOS 16; el layout de flujo se arma con
        // un `Layout` propio, que es la forma que no depende de la versión.
        FlujoHorizontal(espaciado: TokensEspaciado.e6) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                ChipInformativo(texto: chip.0, destacado: chip.1)
            }
        }
    }
}

// MARK: - Gráfico de carga

/// Las barras de la carga semanal: acento apagado lo que tiene metros, acento
/// vivo con halo el día de hoy. Se estiran al alto que les dé la tarjeta.
///
/// Con `alElegir`, cada barra es un botón (y VoiceOver la lee con su etiqueta);
/// sin él, es un dibujo y se oculta: el número está arriba.
struct GraficoDeCarga: View {
    let metrosPorDia: [Int]
    let diaDestacado: Int
    /// La barra elegida, con un borde para que se note cuál se está mirando.
    var seleccionado: Int? = nil
    /// "L M M J…" debajo de cada barra. Vacío o de otro largo, no se dibuja.
    var etiquetas: [String] = []
    /// "Lunes 20, 8 km": lo que dice VoiceOver de cada barra tocable.
    var etiquetasAccesibles: [String] = []
    var alElegir: ((Int) -> Void)? = nil

    var body: some View {
        let maximo = max(metrosPorDia.max() ?? 1, 1)
        VStack(spacing: TokensEspaciado.e6) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: TokensEspaciado.e6) {
                    ForEach(Array(metrosPorDia.enumerated()), id: \.offset) { indice, metros in
                        barra(indice: indice,
                              alto: max(TokensEspaciado.e6, geo.size.height * CGFloat(metros) / CGFloat(maximo)),
                              metros: metros)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            if !etiquetas.isEmpty, etiquetas.count == metrosPorDia.count {
                HStack(spacing: TokensEspaciado.e6) {
                    ForEach(Array(etiquetas.enumerated()), id: \.offset) { indice, etiqueta in
                        Text(etiqueta)
                            .estilo(.notaLegal, color: indice == seleccionado ? Paleta.textoPrimario : Paleta.textoTerciario)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(alElegir == nil)
    }

    @ViewBuilder
    private func barra(indice: Int, alto: CGFloat, metros: Int) -> some View {
        let esHoy = indice == diaDestacado
        let elegida = indice == seleccionado
        let capsula = Capsule(style: .continuous)
            .fill(color(metros: metros, esHoy: esHoy))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(elegida ? Paleta.textoPrimario : Color.clear, lineWidth: TokensEspaciado.e2)
            )
            .shadow(color: esHoy ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e6)
            .frame(maxWidth: .infinity)
            .frame(height: alto)
        if let alElegir {
            Button { alElegir(indice) } label: {
                capsula
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityLabel(indice < etiquetasAccesibles.count ? etiquetasAccesibles[indice] : "\(indice + 1)")
            .accessibilityAddTraits(elegida ? .isSelected : [])
        } else {
            capsula
        }
    }

    private func color(metros: Int, esHoy: Bool) -> Color {
        if esHoy { return Paleta.acento }
        return metros > 0 ? Paleta.acentoApagado : Paleta.superficieControl
    }
}

// MARK: - Fueguitos / Racha estilo Duolingo

struct InsigniaDeRacha: View {
    let racha: RachaHome
    @State private var mostrandoDetalle = false

    private var encendida: Bool { racha.dias > 0 && racha.activaHoy }

    var body: some View {
        Button { mostrandoDetalle = true } label: {
            HStack(spacing: TokensEspaciado.e5) {
                Image(systemName: encendida ? "flame.fill" : "flame")
                    .font(.system(size: TokensEspaciado.e16, weight: .bold))
                    .foregroundStyle(racha.dias > 0
                        ? (racha.activaHoy ? Paleta.acento : Paleta.textoSecundario)
                        : Paleta.textoTerciario)
                Text(verbatim: "\(racha.dias)")
                    .estilo(.cuerpoDestacado, color: racha.dias > 0 ? Paleta.textoPrimario : Paleta.textoSecundario)
                    .monospacedDigit()
            }
            .padding(.horizontal, TokensEspaciado.e12)
            .frame(minHeight: TokensEspaciado.e36)
            .background(Capsule().fill(encendida ? Paleta.acentoChipActivo : Paleta.superficie))
            .overlay(
                Capsule()
                    .strokeBorder(encendida ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                                  lineWidth: TokensEspaciado.e1)
            )
            .shadow(color: encendida ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e8)
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Textos.streakAccessibility(Textos.streakTitle, racha.dias, Textos.streakDays))
        .sheet(isPresented: $mostrandoDetalle) {
            DetalleDeRachaView(racha: racha)
        }
    }
}

struct DetalleDeRachaView: View {
    let racha: RachaHome
    @Environment(\.dismiss) private var cerrar

    private var encendida: Bool { racha.dias > 0 && racha.activaHoy }

    var body: some View {
        VStack(spacing: TokensEspaciado.e20) {
            Capsule()
                .fill(Paleta.divisor)
                .frame(width: TokensEspaciado.e36, height: TokensEspaciado.e4)
                .padding(.top, TokensEspaciado.e10)

            ZStack {
                Circle()
                    .fill(encendida ? Paleta.acentoChipActivo : Paleta.superficieOverlay)
                    .frame(width: TokensEspaciado.e44 * 2,
                           height: TokensEspaciado.e44 * 2)
                    .shadow(color: encendida ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e20)
                Image(systemName: encendida ? "flame.fill" : "flame")
                    .font(.system(size: TokensEspaciado.e44, weight: .bold))
                    .foregroundStyle(encendida ? Paleta.acento : Paleta.textoSecundario)
            }
            .padding(.top, TokensEspaciado.e12)
            .accessibilityHidden(true)

            VStack(spacing: TokensEspaciado.e4) {
                MetricaHeroe("\(racha.dias)", unidad: Textos.streakDays, etiquetaAccesible: Textos.streakTitle)
                Text(Textos.streakTitle)
                    .estilo(.etiquetaSeccion, color: Paleta.acento)
            }

            VStack(spacing: TokensEspaciado.e10) {
                Text(mensajeDeEstado)
                    .estilo(.tituloSeccion)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TokensEspaciado.e16)

                Text(Textos.streakExplanation)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TokensEspaciado.e20)
            }

            Spacer()

            BotonPrimario(Textos.commonDone) {
                cerrar()
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.bottom, TokensEspaciado.e20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }

    private var mensajeDeEstado: String {
        if racha.dias > 0 {
            if racha.entrenadoHoy {
                return Textos.streakDetailActive
            } else if !racha.tocaHoy {
                return Textos.streakDetailRest
            } else {
                return Textos.streakDetailPending
            }
        } else {
            return Textos.streakDetailLost
        }
    }
}
