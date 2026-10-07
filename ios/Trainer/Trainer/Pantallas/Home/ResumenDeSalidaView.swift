import SwiftUI
import MapKit
import TrainerCore

/// Resumen de salida al estilo Strava y Apple Entreno:
/// fondo OLED negro puro sin fondos grises, mapa del recorrido completo arriba,
/// lista vertical limpia de métricas de alto contraste con divisores sutiles,
/// splits por kilómetro, tramos y estado de racha de entrenamientos.
struct ResumenDeSalidaView: View {
    let salida: SalidaCapturada
    let alTerminar: () -> Void

    @EnvironmentObject private var estado: EstadoHome

    private var fechaHora: String {
        Date(timeIntervalSince1970: Double(salida.inicioMs) / 1000)
            .formatted(date: .abbreviated, time: .shortened)
    }

    @State private var modoReproduccion = false

    private var metricas: AnalisisDeRecorrido {
        AnalizadorDeRecorrido.analizar(
            puntos: salida.puntos,
            deporte: salida.deporte,
            duracionTotalSegundos: salida.segundos
        )
    }

    private var ritmoMedio: Int? {
        guard salida.metros >= 100, salida.segundos > 0 else { return nil }
        let segundos = Double(salida.segundos)
        let metros = Double(salida.metros)
        return Int((segundos * 1000.0 / metros).rounded())
    }

    private var calorias: Int {
        let minutos = max(1, salida.segundos / 60)
        let factor: Double = switch salida.deporte {
        case .ciclismo: 9.0
        case .running: 11.5
        case .trekking: 7.0
        default: 8.0
        }
        return Int((Double(minutos) * factor).rounded())
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                // 1. Cabecera limpia con deporte y fecha
                HStack(spacing: TokensEspaciado.e10) {
                    ZStack {
                        Circle()
                            .fill(Paleta.acento.opacity(0.18))
                            .frame(width: 44, height: 44)
                        IconoDeporte(deporte: salida.deporte, color: Paleta.acento, tamano: 20)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(nombreDeporte(salida.deporte))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Paleta.textoPrimario)
                        Text(fechaHora)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Paleta.textoSecundario)
                    }

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Paleta.acento)
                }
                .padding(.top, TokensEspaciado.e8)

                // 2. Mapa grande del recorrido completo (estilo Strava) y reproducción a pantalla completa
                if !salida.puntos.isEmpty {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                        HStack {
                            Text("RECORRIDO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Paleta.textoSecundario)
                            Spacer()
                            Button {
                                modoReproduccion = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Reproducir recorrido")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Paleta.sobreAcento)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Paleta.acento)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(EstiloPresionado())
                        }

                        VistaRecorrido3D(
                            puntos: salida.puntos,
                            deporte: salida.deporte,
                            duracionTotalSegundos: salida.segundos,
                            distanciaMetros: salida.metros,
                            desnivelMetros: nil,
                            ritmoSegundosPorKm: ritmoMedio,
                            sistemaDeUnidades: estado.sistemaDeUnidades,
                            inicioMs: salida.inicioMs
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                                .strokeBorder(Paleta.bordeInput, lineWidth: 1)
                        )
                    }
                    .fullScreenCover(isPresented: $modoReproduccion) {
                        ReproductorDeRecorridoView(
                            puntos: salida.puntos,
                            deporte: salida.deporte,
                            duracionTotalSegundos: salida.segundos,
                            sistemaDeUnidades: estado.sistemaDeUnidades,
                            alCerrar: { modoReproduccion = false }
                        )
                    }
                }

                // 3. Métricas en lista vertical limpia (sin tarjetas grises, fondo OLED puro)
                VStack(alignment: .leading, spacing: 12) {
                    filaMetrica(
                        etiqueta: Textos.entrenoDistancia,
                        valor: Formato.distancia(salida.metros, unidades: estado.sistemaDeUnidades, decimales: 2),
                        destacado: true
                    )

                    filaMetrica(
                        etiqueta: "DURACIÓN TOTAL",
                        valor: Formato.cronometroCompleto(segundos: salida.segundos)
                    )

                    if metricas.tiempoEnMovimientoSegundos < salida.segundos {
                        filaMetrica(
                            etiqueta: "TIEMPO EN MOVIMIENTO",
                            valor: Formato.cronometroCompleto(segundos: metricas.tiempoEnMovimientoSegundos)
                        )
                    }

                    if salida.deporte == .ciclismo {
                        let velPromedio: String = {
                            guard salida.metros >= 50, salida.segundos > 0 else {
                                return "0,0 \(Formato.unidadDeVelocidad(estado.sistemaDeUnidades))"
                            }
                            return Formato.velocidad(metros: salida.metros, segundos: salida.segundos, unidades: estado.sistemaDeUnidades)
                        }()
                        filaMetrica(
                            etiqueta: "VELOCIDAD PROMEDIO",
                            valor: velPromedio
                        )

                        if let maxKmh = metricas.velocidadMaximaKmh {
                            let maxVel = estado.sistemaDeUnidades == .imperial ? maxKmh * 0.621371 : maxKmh
                            let unidad = Formato.unidadDeVelocidad(estado.sistemaDeUnidades)
                            filaMetrica(
                                etiqueta: "VELOCIDAD MÁXIMA",
                                valor: String(format: "%.1f %@", maxVel, unidad).replacingOccurrences(of: ".", with: ",")
                            )
                        }
                    } else {
                        filaMetrica(
                            etiqueta: "RITMO PROMEDIO",
                            valor: Formato.ritmo(segundosPorKm: ritmoMedio, unidades: estado.sistemaDeUnidades)
                        )

                        if let ritmoMax = metricas.ritmoMaximoSegPorKm {
                            filaMetrica(
                                etiqueta: "MEJOR RITMO",
                                valor: Formato.ritmo(segundosPorKm: ritmoMax, unidades: estado.sistemaDeUnidades)
                            )
                        }
                    }

                    if let medio = salida.pulsoMedio {
                        filaMetrica(
                            etiqueta: Textos.resumenPulsoMedio,
                            valor: "\(medio) ppm",
                            colorIcono: .red,
                            icono: "heart.fill"
                        )
                    }

                    if let maximo = salida.pulsoMaximo {
                        filaMetrica(
                            etiqueta: Textos.resumenPulsoMax,
                            valor: "\(maximo) ppm",
                            colorIcono: .red,
                            icono: "heart.fill"
                        )
                    }

                    filaMetrica(
                        etiqueta: "DESNIVEL ACUMULADO",
                        valor: Formato.desnivel(metros: 0, unidades: estado.sistemaDeUnidades)
                    )

                    filaMetrica(
                        etiqueta: "CALORÍAS ACTIVAS",
                        valor: "\(calorias) kcal"
                    )
                }

                // 4. Splits por kilómetro (con barras de ritmo relativo)
                if !metricas.splitsKm.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ESTADÍSTICA POR KILÓMETRO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Paleta.textoSecundario)
                            .padding(.top, 4)

                        let ritmos = metricas.splitsKm.map(\.ritmoSegPorKm).filter { $0 > 0 }
                        let mejorRitmo = ritmos.min() ?? 1
                        let peorRitmo = max(mejorRitmo + 1, ritmos.max() ?? 1)

                        ForEach(metricas.splitsKm) { split in
                            VStack(spacing: 6) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle().fill(Paleta.acento).frame(width: 24, height: 24)
                                        Text("\(split.numero)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Paleta.fondo)
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Km \(split.numero)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Paleta.textoPrimario)
                                        Text(Formato.distancia(split.metros, unidades: estado.sistemaDeUnidades, decimales: 2))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Paleta.textoTerciario)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(salida.deporte == .ciclismo
                                            ? String(format: "%.1f %@", estado.sistemaDeUnidades == .imperial ? split.velocidadKmh * 0.621371 : split.velocidadKmh, Formato.unidadDeVelocidad(estado.sistemaDeUnidades)).replacingOccurrences(of: ".", with: ",")
                                            : Formato.ritmo(segundosPorKm: split.ritmoSegPorKm, unidades: estado.sistemaDeUnidades) + (estado.sistemaDeUnidades == .imperial ? " /mi" : " /km"))
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(Paleta.textoPrimario)
                                            .monospacedDigit()
                                        Text(Formato.cronometro(segundos: split.segundos))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Paleta.textoSecundario)
                                            .monospacedDigit()
                                    }
                                }

                                // Barra visual de ritmo relativo
                                GeometryReader { geo in
                                    let ancho = geo.size.width
                                    let ratio: CGFloat = {
                                        guard peorRitmo > mejorRitmo else { return 1.0 }
                                        let r = 1.0 - (Double(split.ritmoSegPorKm - mejorRitmo) / Double(peorRitmo - mejorRitmo))
                                        return CGFloat(max(0.2, min(1.0, 0.3 + 0.7 * r)))
                                    }()
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Paleta.superficie)
                                            .frame(height: 5)
                                        Capsule()
                                            .fill(Paleta.acento)
                                            .frame(width: ancho * ratio, height: 5)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .padding(.vertical, 3)
                            Divider().background(Paleta.divisor)
                        }
                    }
                }

                // 5. Tramos, pausas y reanudaciones
                let tieneSegmentosReales = !(salida.segmentos ?? []).isEmpty
                let tieneTramos = tieneSegmentosReales || !metricas.pausas.isEmpty || metricas.tramos.count > 1

                if tieneTramos {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TRAMOS, PAUSAS Y REANUDACIONES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Paleta.textoSecundario)
                            .padding(.top, 4)

                        if tieneSegmentosReales, let segs = salida.segmentos {
                            ForEach(segs) { seg in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Paleta.superficieOverlay).frame(width: 24, height: 24)
                                            Circle().stroke(Paleta.acento, lineWidth: 1.5).frame(width: 24, height: 24)
                                            Text("\(seg.numero)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Paleta.acento)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Tramo \(seg.numero)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Paleta.textoPrimario)
                                            Text(Formato.distancia(seg.distanciaMetros, unidades: estado.sistemaDeUnidades, decimales: 2))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Paleta.textoSecundario)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text(Formato.cronometro(segundos: seg.duracionSegundos))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(Paleta.textoPrimario)
                                                .monospacedDigit()
                                            if seg.distanciaMetros >= 50 && seg.duracionSegundos > 0 {
                                                let ritmo = Int((Double(seg.duracionSegundos) * 1000.0 / Double(seg.distanciaMetros)).rounded())
                                                Text(Formato.ritmo(segundosPorKm: ritmo, unidades: estado.sistemaDeUnidades) + " /km")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(Paleta.textoTerciario)
                                            }
                                        }
                                    }

                                    if let pausas = salida.pausas, let pausa = pausas.first(where: { $0.numero == seg.numero }) {
                                        let horaPausa = Date(timeIntervalSince1970: Double(pausa.inicioMs) / 1000).formatted(date: .omitted, time: .standard)
                                        let horaReanuda = Date(timeIntervalSince1970: Double(pausa.finMs) / 1000).formatted(date: .omitted, time: .standard)

                                        HStack(spacing: 8) {
                                            Image(systemName: "pause.circle.fill")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Paleta.controlPausa)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Pausa \(pausa.numero): \(Formato.cronometro(segundos: pausa.duracionSegundos))")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Paleta.controlPausa)
                                                Text("Pausa: \(horaPausa) · Reanudación: \(horaReanuda)")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundStyle(Paleta.textoTerciario)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Paleta.controlPausa.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(.vertical, 3)
                                Divider().background(Paleta.divisor)
                            }
                        } else {
                            ForEach(metricas.tramos) { tramo in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Paleta.superficieOverlay).frame(width: 24, height: 24)
                                            Circle().stroke(Paleta.acento, lineWidth: 1.5).frame(width: 24, height: 24)
                                            Text("\(tramo.numero)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Paleta.acento)
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Tramo \(tramo.numero)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Paleta.textoPrimario)
                                            Text(Formato.distancia(tramo.metros, unidades: estado.sistemaDeUnidades, decimales: 2))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Paleta.textoSecundario)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text(Formato.cronometro(segundos: tramo.segundos))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(Paleta.textoPrimario)
                                                .monospacedDigit()
                                            if let ritmo = tramo.ritmoSegPorKm {
                                                Text(Formato.ritmo(segundosPorKm: ritmo, unidades: estado.sistemaDeUnidades) + " /km")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(Paleta.textoTerciario)
                                            }
                                        }
                                    }

                                    if let pausa = metricas.pausas.first(where: { $0.numero == tramo.numero }) {
                                        let horaPausa = Date(timeIntervalSince1970: Double(pausa.inicioMs) / 1000).formatted(date: .omitted, time: .standard)
                                        let horaReanuda = Date(timeIntervalSince1970: Double(pausa.finMs) / 1000).formatted(date: .omitted, time: .standard)

                                        HStack(spacing: 8) {
                                            Image(systemName: "pause.circle.fill")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Paleta.controlPausa)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Pausa \(pausa.numero): \(Formato.cronometro(segundos: pausa.duracionSegundos))")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Paleta.controlPausa)
                                                Text("Pausa: \(horaPausa) · Reanudación: \(horaReanuda)")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundStyle(Paleta.textoTerciario)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Paleta.controlPausa.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(.vertical, 3)
                                Divider().background(Paleta.divisor)
                            }
                        }
                    }
                }

                // 6. Racha de entrenamientos (diseño integrado sin fondo gris pesado)
                HStack(spacing: TokensEspaciado.e12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Textos.resumenRachaMantenida)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Paleta.textoPrimario)
                        Text(Textos.rachaDetalleActiva)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Paleta.textoSecundario)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, TokensEspaciado.e10)
                .overlay(alignment: .bottom) {
                    Divider().background(Paleta.divisor)
                }

                Spacer(minLength: TokensEspaciado.e16)

                // 7. Botón Guardar y Cerrar
                BotonPrimario(Textos.resumenGuardarCerrar) {
                    alTerminar()
                }
                .padding(.bottom, TokensEspaciado.e22)
            }
            .padding(.horizontal, TokensEspaciado.e16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }

    private func filaMetrica(etiqueta: String, valor: String, destacado: Bool = false,
                             colorIcono: Color? = nil, icono: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(etiqueta)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Paleta.textoSecundario)
            HStack(spacing: 5) {
                Text(valor)
                    .font(.system(size: destacado ? 26 : 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                    .monospacedDigit()
                if let icono, let colorIcono {
                    Image(systemName: icono)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(colorIcono)
                }
            }
            Divider()
                .background(Paleta.divisor)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iconoDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return "figure.run"
        case .ciclismo: return "bicycle"
        case .trekking: return "figure.hiking"
        case .natacion: return "figure.pool.swim"
        case .fuerza: return "dumbbell.fill"
        case .otro, .triatlon: return "figure.mixed.cardio"
        }
    }

    private func nombreDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return Textos.regDeporteRunning
        case .ciclismo: return Textos.regDeporteCiclismo
        case .trekking: return Textos.regDeporteTrekking
        case .triatlon: return Textos.regDeporteTriatlon
        default: return deporte.rawValue.capitalized
        }
    }
}
