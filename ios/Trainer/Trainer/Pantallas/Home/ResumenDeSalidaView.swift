import SwiftUI
import TrainerCore

/// Resumen de salida, la pantalla de "¡Llegaste!": título pesado, la distancia
/// final enorme, las tarjetas de métrica, el mapa del recorrido, los parciales
/// por kilómetro, los tramos con sus pausas y la racha.
struct ResumenDeSalidaView: View {
    let salida: SalidaCapturada
    let alTerminar: () -> Void

    @EnvironmentObject private var estado: EstadoHome

    private var metricas: AnalisisDeRecorrido {
        AnalizadorDeRecorrido.analizar(
            puntos: salida.puntos,
            deporte: salida.deporte,
            duracionTotalSegundos: salida.segundos
        )
    }

    private var ritmoMedio: Int? {
        ResumenFormato.ritmoMedio(metros: salida.metros, segundos: salida.segundos)
    }

    var body: some View {
        // Se calcula una vez por render, no una por sección.
        let analisis = metricas
        return ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e22) {
                cabecera

                ResumenMetricasPrincipales(datos: ResumenDatosDeMetricas(
                    deporte: salida.deporte,
                    metros: salida.metros,
                    segundos: salida.segundos,
                    analisis: analisis,
                    pulsoMedio: salida.pulsoMedio,
                    pulsoMaximo: salida.pulsoMaximo,
                    // La salida capturada no trae desnivel: se muestra 0, como antes.
                    desnivelMetros: 0,
                    calorias: ResumenFormato.caloriasEstimadas(deporte: salida.deporte, segundos: salida.segundos),
                    unidades: estado.sistemaDeUnidades
                ))

                if !salida.puntos.isEmpty {
                    ResumenMapaDelRecorrido(
                        puntos: salida.puntos,
                        deporte: salida.deporte,
                        segundos: salida.segundos,
                        metros: salida.metros,
                        desnivelMetros: nil,
                        ritmoSegundosPorKm: ritmoMedio,
                        unidades: estado.sistemaDeUnidades,
                        inicioMs: salida.inicioMs
                    )
                }

                if !analisis.splitsKm.isEmpty {
                    ResumenParciales(splits: analisis.splitsKm, deporte: salida.deporte,
                                     unidades: estado.sistemaDeUnidades)
                }

                tramos(analisis)

                ResumenTarjetaDeRacha()

                BotonPrimario(Textos.resumenGuardarCerrar) {
                    alTerminar()
                }
                .padding(.top, TokensEspaciado.e8)
                .padding(.bottom, TokensEspaciado.e22)
            }
            .padding(.horizontal, TokensEspaciado.e16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }

    // MARK: - Cabecera

    private var cabecera: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e12) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                Text(String(localized: "¡Llegaste!", comment: "Resumen de salida: título al terminar"))
                    .estilo(.display)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: TokensEspaciado.e6) {
                    IconoDeporte(deporte: salida.deporte, color: Paleta.acento, tamano: TokensTipografia.labelCampoTamano)
                        .accessibilityHidden(true)
                    Text("\(salida.deporte.nombreVisible) · \(ResumenFormato.fechaHora(salida.inicioMs))")
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: TokensEspaciado.e26))
                .foregroundStyle(Paleta.acento)
                .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e10)
                .accessibilityHidden(true)
        }
        .padding(.top, TokensEspaciado.e16)
    }

    // MARK: - Tramos

    @ViewBuilder
    private func tramos(_ analisis: AnalisisDeRecorrido) -> some View {
        let segmentosReales = salida.segmentos ?? []
        let tieneTramos = !segmentosReales.isEmpty || !analisis.pausas.isEmpty || analisis.tramos.count > 1
        if tieneTramos {
            ResumenTramos(
                filas: segmentosReales.isEmpty
                    ? ResumenFilaDeTramo.desde(analisis: analisis)
                    : ResumenFilaDeTramo.desde(segmentos: segmentosReales, pausas: salida.pausas),
                colorPausa: Paleta.controlPausa,
                unidades: estado.sistemaDeUnidades
            )
        }
    }
}

/// "¡Mantuviste tu racha!" con el fueguito rosa.
private struct ResumenTarjetaDeRacha: View {
    var body: some View {
        HStack(spacing: TokensEspaciado.e12) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                Image(systemName: "flame.fill")
                    .font(.system(size: TokensEspaciado.e20, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e44)
            .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e8)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(Textos.resumenRachaMantenida)
                    .estilo(.tituloCardGrande)
                Text(Textos.rachaDetalleActiva)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
            }
            Spacer(minLength: 0)
        }
        .padding(TokensEspaciado.e14)
        .resumenTarjeta()
        .accessibilityElement(children: .combine)
    }
}
