import SwiftUI
import TrainerCore

// =============================================================================
// Piezas que comparten el resumen de salida y el detalle del historial.
//
// Antes las dos pantallas tenían copiadas la fila de métrica, los splits, los
// tramos con sus pausas y el mapa con su botón de reproducir. Ahora viven acá
// y las dos pantallas se ven (y se arreglan) igual.
// =============================================================================

// MARK: - Roles chicos con cifras tabulares

extension EstiloTipografico {
    /// El valor de una fila (ritmo de un parcial, duración de un tramo).
    static let resumenCifraFila = EstiloTipografico(
        tamano: TokensTipografia.valorFilaTamano,
        peso: TokensTipografia.valorFilaPeso,
        cifrasTabulares: true, referencia: .callout)

    /// El dato chico debajo de una fila ("1 km · 5:12").
    static let resumenCifraChica = EstiloTipografico(
        tamano: TokensTipografia.labelCampoTamano,
        peso: TokensTipografia.labelCampoPeso,
        cifrasTabulares: true, referencia: .caption)
}

// MARK: - Cálculos de presentación

enum ResumenFormato {
    /// "/km" o "/mi", para pegarle al ritmo.
    static func unidadDeRitmo(_ unidades: SistemaDeUnidades) -> String {
        unidades == .imperial ? "/mi" : "/km"
    }

    /// "25,4" desde km/h, convertido al sistema elegido. Sin la unidad.
    static func velocidadNumero(kmh: Double, unidades: SistemaDeUnidades) -> String {
        let valor = unidades == .imperial ? kmh * 0.621371 : kmh
        return String(format: "%.1f", valor).replacingOccurrences(of: ".", with: ",")
    }

    /// Ritmo medio en s/km. Bajo 100 m no hay ritmo honesto.
    static func ritmoMedio(metros: Int, segundos: Int) -> Int? {
        guard metros >= 100, segundos > 0 else { return nil }
        return Int((Double(segundos) * 1000.0 / Double(metros)).rounded())
    }

    /// La estimación de calorías que ya usaban las dos pantallas.
    static func caloriasEstimadas(deporte: DeporteDeSesion, segundos: Int) -> Int {
        let minutos = max(1, segundos / 60)
        let factor: Double
        switch deporte {
        case .ciclismo: factor = 9.0
        case .running: factor = 11.5
        case .trekking: factor = 7.0
        default: factor = 8.0
        }
        return Int((Double(minutos) * factor).rounded())
    }

    static func hora(_ ms: Int64) -> String {
        Date(timeIntervalSince1970: Double(ms) / 1000).formatted(date: .omitted, time: .standard)
    }

    static func fechaHora(_ ms: Int64) -> String {
        Date(timeIntervalSince1970: Double(ms) / 1000).formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Ícono del deporte en un círculo rosado

struct ResumenIconoDeDeporte: View {
    let deporte: DeporteDeSesion
    var diametro: CGFloat = TokensEspaciado.e44

    var body: some View {
        ZStack {
            Circle().fill(Paleta.acentoChipActivo)
            Circle().strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1)
            IconoDeporte(deporte: deporte, color: Paleta.acento, tamano: diametro * 0.45)
        }
        .frame(width: diametro, height: diametro)
        .accessibilityHidden(true)
    }
}

// MARK: - Tarjeta contenedora

private struct ResumenFondoDeTarjeta: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
    }
}

extension View {
    /// La tarjeta gris oscura con borde finito del rediseño.
    func resumenTarjeta() -> some View {
        modifier(ResumenFondoDeTarjeta())
    }
}

// MARK: - Grilla de métricas

/// Lo que hace falta para armar las tarjetas de métrica de una actividad.
struct ResumenDatosDeMetricas {
    let deporte: DeporteDeSesion
    let metros: Int
    let segundos: Int
    let analisis: AnalisisDeRecorrido
    let pulsoMedio: Int?
    let pulsoMaximo: Int?
    let desnivelMetros: Int
    let calorias: Int
    let unidades: SistemaDeUnidades

    struct Tarjeta: Identifiable {
        let etiqueta: String
        let valor: String
        var unidad: String? = nil
        var simbolo: String? = nil
        var id: String { etiqueta }
    }

    var tarjetas: [Tarjeta] {
        var lista: [Tarjeta] = [
            Tarjeta(etiqueta: String(localized: "Duración total", comment: "Resumen: métrica"),
                    valor: Formato.cronometroCompleto(segundos: segundos), simbolo: "clock")
        ]
        if analisis.tiempoEnMovimientoSegundos < segundos {
            lista.append(Tarjeta(etiqueta: String(localized: "En movimiento", comment: "Resumen: tiempo en movimiento"),
                                 valor: Formato.cronometroCompleto(segundos: analisis.tiempoEnMovimientoSegundos),
                                 simbolo: "timer"))
        }
        if deporte == .ciclismo {
            let promedio = (metros >= 50 && segundos > 0)
                ? Formato.velocidadNumero(metros: metros, segundos: segundos, unidades: unidades)
                : "0,0"
            lista.append(Tarjeta(etiqueta: String(localized: "Velocidad prom.", comment: "Resumen: velocidad promedio"),
                                 valor: promedio, unidad: Formato.unidadDeVelocidad(unidades),
                                 simbolo: "speedometer"))
            if let maxima = analisis.velocidadMaximaKmh {
                lista.append(Tarjeta(etiqueta: String(localized: "Velocidad máx.", comment: "Resumen: velocidad máxima"),
                                     valor: ResumenFormato.velocidadNumero(kmh: maxima, unidades: unidades),
                                     unidad: Formato.unidadDeVelocidad(unidades), simbolo: "bolt.fill"))
            }
        } else {
            lista.append(Tarjeta(etiqueta: String(localized: "Ritmo prom.", comment: "Resumen: ritmo promedio"),
                                 valor: Formato.ritmo(segundosPorKm: ResumenFormato.ritmoMedio(metros: metros, segundos: segundos),
                                                      unidades: unidades),
                                 unidad: ResumenFormato.unidadDeRitmo(unidades), simbolo: "speedometer"))
            if let mejor = analisis.ritmoMaximoSegPorKm {
                lista.append(Tarjeta(etiqueta: String(localized: "Mejor ritmo", comment: "Resumen: mejor ritmo"),
                                     valor: Formato.ritmo(segundosPorKm: mejor, unidades: unidades),
                                     unidad: ResumenFormato.unidadDeRitmo(unidades), simbolo: "bolt.fill"))
            }
        }
        if let pulsoMedio {
            lista.append(Tarjeta(etiqueta: Textos.resumenPulsoMedio, valor: "\(pulsoMedio)",
                                 unidad: "ppm", simbolo: "heart.fill"))
        }
        if let pulsoMaximo {
            lista.append(Tarjeta(etiqueta: Textos.resumenPulsoMax, valor: "\(pulsoMaximo)",
                                 unidad: "ppm", simbolo: "heart.fill"))
        }
        lista.append(Tarjeta(etiqueta: String(localized: "Desnivel", comment: "Resumen: desnivel acumulado"),
                             valor: Formato.desnivel(metros: desnivelMetros, unidades: unidades),
                             simbolo: "mountain.2.fill"))
        lista.append(Tarjeta(etiqueta: String(localized: "Calorías", comment: "Resumen: calorías activas"),
                             valor: Formato.kcal(calorias), unidad: "kcal", simbolo: "flame.fill"))
        return lista
    }
}

/// "21,10 km" grande y abajo las tarjetas de dos en dos.
struct ResumenMetricasPrincipales: View {
    let datos: ResumenDatosDeMetricas

    private var columnas: [GridItem] {
        [GridItem(.flexible(), spacing: TokensEspaciado.e8),
         GridItem(.flexible(), spacing: TokensEspaciado.e8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
            MetricaHeroe(
                Formato.distanciaNumero(datos.metros, unidades: datos.unidades, decimales: 2),
                unidad: Formato.unidadDeDistancia(datos.unidades),
                etiquetaAccesible: Textos.entrenoDistancia
            )
            LazyVGrid(columns: columnas, alignment: .leading, spacing: TokensEspaciado.e8) {
                ForEach(datos.tarjetas) { tarjeta in
                    TarjetaMetrica(tarjeta.etiqueta, valor: tarjeta.valor,
                                   unidad: tarjeta.unidad, simbolo: tarjeta.simbolo)
                }
            }
        }
    }
}

// MARK: - Mapa del recorrido con su botón de reproducir

struct ResumenMapaDelRecorrido: View {
    let puntos: [PuntoDeRecorrido]
    let deporte: DeporteDeSesion
    let segundos: Int
    let metros: Int
    let desnivelMetros: Int?
    let ritmoSegundosPorKm: Int?
    let unidades: SistemaDeUnidades
    let inicioMs: Int64

    @State private var modoReproduccion = false

    /// El alto del mapa: deja ver el relieve sin tapar las métricas.
    private var altoDelMapa: CGFloat { TokensEspaciado.e52 * 8 }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            HStack(spacing: TokensEspaciado.e8) {
                Text(String(localized: "Recorrido", comment: "Resumen: título del mapa"))
                    .estilo(.tituloSeccion)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    modoReproduccion = true
                } label: {
                    HStack(spacing: TokensEspaciado.e5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                            .foregroundStyle(Paleta.sobreAcento)
                            .accessibilityHidden(true)
                        Text("Reproducir recorrido")
                            .estilo(.chip, color: Paleta.sobreAcento)
                    }
                    .padding(.horizontal, TokensEspaciado.e12)
                    .padding(.vertical, TokensEspaciado.e8)
                    .background(Paleta.acento)
                    .clipShape(Capsule())
                    .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e8)
                    .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
            }

            VistaRecorrido3D(
                puntos: puntos,
                deporte: deporte,
                duracionTotalSegundos: segundos,
                distanciaMetros: metros,
                desnivelMetros: desnivelMetros,
                ritmoSegundosPorKm: ritmoSegundosPorKm,
                sistemaDeUnidades: unidades,
                inicioMs: inicioMs
            )
            .frame(maxWidth: .infinity)
            .frame(height: altoDelMapa)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
        }
        .fullScreenCover(isPresented: $modoReproduccion) {
            ReproductorDeRecorridoView(
                puntos: puntos,
                deporte: deporte,
                duracionTotalSegundos: segundos,
                sistemaDeUnidades: unidades,
                alCerrar: { modoReproduccion = false }
            )
        }
    }
}

// MARK: - Parciales por kilómetro

/// Una barra por kilómetro: el más rápido en rosa, el resto en gris.
struct ResumenParciales: View {
    let splits: [SplitKilometro]
    let deporte: DeporteDeSesion
    let unidades: SistemaDeUnidades

    private var mejorRitmo: Int {
        splits.map(\.ritmoSegPorKm).filter { $0 > 0 }.min() ?? 1
    }

    private var peorRitmo: Int {
        max(mejorRitmo + 1, splits.map(\.ritmoSegPorKm).filter { $0 > 0 }.max() ?? 1)
    }

    /// El número del parcial más rápido (sólo si hay más de uno para comparar).
    private var numeroDelMejor: Int? {
        guard splits.count > 1 else { return nil }
        return splits.filter { $0.ritmoSegPorKm > 0 }.min { $0.ritmoSegPorKm < $1.ritmoSegPorKm }?.numero
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            EncabezadoDeSeccion(String(localized: "Parciales", comment: "Resumen: splits por kilómetro"),
                                detalle: String(localized: "cada km", comment: "Resumen: los parciales son por kilómetro"))
            VStack(spacing: TokensEspaciado.e10) {
                ForEach(splits) { split in
                    fila(split, esMejor: split.numero == numeroDelMejor)
                }
            }
            .padding(TokensEspaciado.e14)
            .resumenTarjeta()
        }
    }

    private func valor(_ split: SplitKilometro) -> String {
        if deporte == .ciclismo {
            return "\(ResumenFormato.velocidadNumero(kmh: split.velocidadKmh, unidades: unidades)) \(Formato.unidadDeVelocidad(unidades))"
        }
        return "\(Formato.ritmo(segundosPorKm: split.ritmoSegPorKm, unidades: unidades)) \(ResumenFormato.unidadDeRitmo(unidades))"
    }

    /// Largo relativo de la barra: el más rápido llega al tope.
    private func proporcion(_ split: SplitKilometro) -> CGFloat {
        guard peorRitmo > mejorRitmo else { return 1.0 }
        let r = 1.0 - (Double(split.ritmoSegPorKm - mejorRitmo) / Double(peorRitmo - mejorRitmo))
        return CGFloat(max(0.2, min(1.0, 0.3 + 0.7 * r)))
    }

    private func fila(_ split: SplitKilometro, esMejor: Bool) -> some View {
        HStack(spacing: TokensEspaciado.e10) {
            Text("Km \(split.numero)")
                .estilo(.resumenCifraChica, color: esMejor ? Paleta.textoPrimario : Paleta.textoSecundario)
                .frame(minWidth: TokensEspaciado.e40, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Paleta.superficieDestacada)
                    Capsule()
                        .fill(esMejor ? Paleta.acento : Paleta.textoTerciario)
                        .frame(width: geo.size.width * proporcion(split))
                        .shadow(color: esMejor ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e4)
                }
            }
            .frame(height: TokensEspaciado.e6)
            .accessibilityHidden(true)

            VStack(alignment: .trailing, spacing: TokensEspaciado.e1) {
                HStack(spacing: TokensEspaciado.e3) {
                    if esMejor {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: TokensTipografia.notaTamano, weight: .bold))
                            .foregroundStyle(Paleta.acento)
                            .accessibilityHidden(true)
                    }
                    Text(valor(split))
                        .estilo(.resumenCifraFila, color: esMejor ? Paleta.acento : Paleta.textoPrimario)
                        .lineLimit(1)
                }
                Text("\(Formato.distancia(split.metros, unidades: unidades, decimales: 2)) · \(Formato.cronometro(segundos: split.segundos))")
                    .estilo(.resumenCifraChica, color: Paleta.textoTerciario)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(esMejor ? Text(String(localized: "Parcial más rápido", comment: "Resumen: accesibilidad del mejor split")) : Text(""))
    }
}

// MARK: - Tramos, pausas y reanudaciones

struct ResumenPausa {
    let numero: Int
    let inicioMs: Int64
    let finMs: Int64
    let duracionSegundos: Int
}

/// Un tramo en movimiento y, si la hubo, la pausa que lo cerró.
struct ResumenFilaDeTramo: Identifiable {
    let numero: Int
    let metros: Int
    let segundos: Int
    let ritmoSegPorKm: Int?
    let pausa: ResumenPausa?
    var id: Int { numero }

    /// Desde los segmentos reales que grabó la salida.
    static func desde(segmentos: [SegmentoActividad], pausas: [PausaActividad]?) -> [ResumenFilaDeTramo] {
        segmentos.map { seg in
            let ritmo: Int? = (seg.distanciaMetros >= 50 && seg.duracionSegundos > 0)
                ? Int((Double(seg.duracionSegundos) * 1000.0 / Double(seg.distanciaMetros)).rounded())
                : nil
            let pausa = pausas?.first(where: { $0.numero == seg.numero }).map {
                ResumenPausa(numero: $0.numero, inicioMs: $0.inicioMs, finMs: $0.finMs,
                             duracionSegundos: $0.duracionSegundos)
            }
            return ResumenFilaDeTramo(numero: seg.numero, metros: seg.distanciaMetros,
                                      segundos: seg.duracionSegundos, ritmoSegPorKm: ritmo, pausa: pausa)
        }
    }

    /// Desde el análisis de los puntos GPS.
    static func desde(analisis: AnalisisDeRecorrido) -> [ResumenFilaDeTramo] {
        analisis.tramos.map { tramo in
            let pausa = analisis.pausas.first(where: { $0.numero == tramo.numero }).map {
                ResumenPausa(numero: $0.numero, inicioMs: $0.inicioMs, finMs: $0.finMs,
                             duracionSegundos: $0.duracionSegundos)
            }
            return ResumenFilaDeTramo(numero: tramo.numero, metros: tramo.metros, segundos: tramo.segundos,
                                      ritmoSegPorKm: tramo.ritmoSegPorKm, pausa: pausa)
        }
    }
}

/// La lista de lo que pasó durante la salida: cada tramo y cada pausa.
struct ResumenTramos: View {
    let filas: [ResumenFilaDeTramo]
    let colorPausa: Color
    let unidades: SistemaDeUnidades

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            EncabezadoDeSeccion(String(localized: "Tramos, pausas y reanudaciones", comment: "Resumen: sección de tramos"))
            VStack(spacing: 0) {
                ForEach(Array(filas.enumerated()), id: \.element.id) { indice, fila in
                    if indice > 0 {
                        Divider().background(Paleta.divisor)
                    }
                    filaDeTramo(fila)
                    if let pausa = fila.pausa {
                        filaDePausa(pausa)
                    }
                }
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .padding(.vertical, TokensEspaciado.e6)
            .resumenTarjeta()
        }
    }

    private func filaDeTramo(_ fila: ResumenFilaDeTramo) -> some View {
        HStack(spacing: TokensEspaciado.e10) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                Text("\(fila.numero)")
                    .estilo(.chip, color: Paleta.acento)
            }
            .frame(width: TokensEspaciado.e34, height: TokensEspaciado.e34)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e1) {
                Text("Tramo \(fila.numero)")
                    .estilo(.tituloCard)
                Text(Formato.distancia(fila.metros, unidades: unidades, decimales: 2))
                    .estilo(.resumenCifraChica, color: Paleta.textoSecundario)
            }
            Spacer(minLength: TokensEspaciado.e8)
            VStack(alignment: .trailing, spacing: TokensEspaciado.e1) {
                Text(Formato.cronometro(segundos: fila.segundos))
                    .estilo(.resumenCifraFila)
                if let ritmo = fila.ritmoSegPorKm {
                    Text("\(Formato.ritmo(segundosPorKm: ritmo, unidades: unidades)) \(ResumenFormato.unidadDeRitmo(unidades))")
                        .estilo(.resumenCifraChica, color: Paleta.textoTerciario)
                }
            }
        }
        .padding(.vertical, TokensEspaciado.e10)
        .accessibilityElement(children: .combine)
    }

    private func filaDePausa(_ pausa: ResumenPausa) -> some View {
        HStack(spacing: TokensEspaciado.e8) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: TokensTipografia.valorDatoTamano))
                .foregroundStyle(colorPausa)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TokensEspaciado.e1) {
                Text("Pausa \(pausa.numero): \(Formato.cronometro(segundos: pausa.duracionSegundos))")
                    .estilo(.tituloCard, color: colorPausa)
                Text("Pausa: \(ResumenFormato.hora(pausa.inicioMs)) · Reanudación: \(ResumenFormato.hora(pausa.finMs))")
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, TokensEspaciado.e10)
        .padding(.vertical, TokensEspaciado.e6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorPausa.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous))
        .padding(.bottom, TokensEspaciado.e10)
        .accessibilityElement(children: .combine)
    }
}
