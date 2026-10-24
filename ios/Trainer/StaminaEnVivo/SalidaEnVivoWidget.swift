import ActivityKit
import SwiftUI
import TrainerCore
import WidgetKit

// =============================================================================
// Cómo se ve la actividad en vivo de una salida.
//
// Pantalla bloqueada (decisión de Iván, como la de Strava): el deporte arriba al
// centro —con "En pausa" al lado si corresponde—, el ícono de Stamina arriba a
// la derecha, y tres columnas: Duración, Ritmo y Distancia. Fondo oscuro, texto
// claro, siempre: la tarjeta no cambia con el modo claro u oscuro del teléfono,
// por eso usa los tokens del modo noche directamente y no la `Paleta` dinámica.
//
// Dynamic Island: compacta, ícono a la izquierda y duración a la derecha;
// mínima, el ícono; expandida, lo mismo que la pantalla bloqueada.
//
// La duración avanza sola (`Text(timerInterval:)`) desde `inicioDelCronometro`;
// en pausa se ve el valor fijo. Ritmo y distancia cambian cuando la app manda
// una actualización (ver `PlanificadorDeActividadEnVivo` en la app).
// =============================================================================

struct SalidaEnVivoWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AtributosDeSalidaEnVivo.self) { contexto in
            TarjetaDeSalidaEnVivo(deporte: contexto.attributes.deporte, estado: contexto.state)
                .activityBackgroundTint(ColoresEnVivo.fondo)
                .activitySystemActionForegroundColor(ColoresEnVivo.texto)
                .widgetURL(EnlaceDeSalidaEnVivo.url)
        } dynamicIsland: { contexto in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IconoDeStamina(tamano: TokensEspaciado.e26)
                }
                DynamicIslandExpandedRegion(.center) {
                    TituloDeSalidaEnVivo(deporte: contexto.attributes.deporte, estado: contexto.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ColumnasDeSalidaEnVivo(estado: contexto.state)
                        .padding(.top, TokensEspaciado.e4)
                }
            } compactLeading: {
                IconoDeStamina(tamano: TokensEspaciado.e20)
                    .accessibilityLabel(TextosEnVivo.deporte(contexto.attributes.deporte))
            } compactTrailing: {
                DuracionEnVivo(estado: contexto.state)
                    .estilo(.tituloCard, color: ColoresEnVivo.texto)
                    .frame(maxWidth: TokensEspaciado.e56)
            } minimal: {
                IconoDeStamina(tamano: TokensEspaciado.e20)
                    .accessibilityLabel(TextosEnVivo.deporte(contexto.attributes.deporte))
            }
            .widgetURL(EnlaceDeSalidaEnVivo.url)
            .keylineTint(ColoresEnVivo.acento)
        }
    }
}

/// Los colores de la tarjeta: los del modo noche, fijos.
enum ColoresEnVivo {
    static let fondo = TokensColor.telefonoFondo
    static let texto = TokensColor.telefonoTextoPrimario
    static let etiqueta = TokensColor.telefonoTextoSecundario
    /// Fuera de la app no hay color elegido en Ajustes: es el de fábrica.
    static let acento = Paleta.acento
}

// MARK: - Pantalla bloqueada

struct TarjetaDeSalidaEnVivo: View {
    let deporte: DeporteDeSesion
    let estado: EstadoDeSalidaEnVivo

    var body: some View {
        VStack(spacing: TokensEspaciado.e14) {
            ZStack {
                TituloDeSalidaEnVivo(deporte: deporte, estado: estado)
                HStack {
                    Spacer()
                    IconoDeStamina(tamano: TokensEspaciado.e26)
                }
            }
            ColumnasDeSalidaEnVivo(estado: estado)
        }
        .padding(TokensEspaciado.e16)
    }
}

/// "Carrera" y, en pausa, "En pausa" al lado.
struct TituloDeSalidaEnVivo: View {
    let deporte: DeporteDeSesion
    let estado: EstadoDeSalidaEnVivo

    var body: some View {
        HStack(spacing: TokensEspaciado.e6) {
            Text(TextosEnVivo.deporte(deporte))
                .estilo(.tituloCardGrande, color: ColoresEnVivo.texto)
            if estado.pausada {
                Text(TextosEnVivo.pausada)
                    .estilo(.tituloCard, color: ColoresEnVivo.acento)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Duración, Ritmo y Distancia, en tres columnas iguales.
struct ColumnasDeSalidaEnVivo: View {
    let estado: EstadoDeSalidaEnVivo

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            ColumnaDeSalidaEnVivo(etiqueta: TextosEnVivo.duracion, unidad: nil) {
                DuracionEnVivo(estado: estado)
            }
            ColumnaDeSalidaEnVivo(etiqueta: TextosEnVivo.ritmo,
                                  unidad: PresentacionDeSalidaEnVivo.unidadDeRitmo(estado.unidades)) {
                Text(PresentacionDeSalidaEnVivo.ritmo(estado))
            }
            ColumnaDeSalidaEnVivo(etiqueta: TextosEnVivo.distancia,
                                  unidad: PresentacionDeSalidaEnVivo.unidadDeDistancia(estado.unidades)) {
                Text(PresentacionDeSalidaEnVivo.distancia(estado))
            }
        }
    }
}

struct ColumnaDeSalidaEnVivo<Valor: View>: View {
    let etiqueta: String
    let unidad: String?
    @ViewBuilder let valor: () -> Valor

    var body: some View {
        VStack(spacing: TokensEspaciado.e4) {
            Text(etiqueta)
                .estilo(.labelCampo, color: ColoresEnVivo.etiqueta)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e2) {
                valor()
                    .estilo(.numeroGrande, color: ColoresEnVivo.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let unidad {
                    Text(unidad)
                        .estilo(.labelCampo, color: ColoresEnVivo.etiqueta)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// La duración que avanza sola. En pausa, el valor fijo.
struct DuracionEnVivo: View {
    let estado: EstadoDeSalidaEnVivo
    /// Una salida no llega a esto; el cronómetro se detiene acá en vez de en el
    /// fin de los tiempos, que algunos sistemas dibujan mal.
    private static let tope: TimeInterval = 24 * 60 * 60

    var body: some View {
        if estado.pausada {
            Text(PresentacionDeSalidaEnVivo.duracionFija(estado))
                .monospacedDigit()
        } else {
            let inicio = estado.inicioDelCronometro
            Text(timerInterval: inicio...inicio.addingTimeInterval(Self.tope), countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.center)
        }
    }
}

/// El ícono de la app, con la forma redondeada de los íconos de iOS.
struct IconoDeStamina: View {
    let tamano: CGFloat
    /// La curva de los íconos de iOS es ~22 % del lado.
    private static let proporcionDelRadio: CGFloat = 0.2237

    var body: some View {
        Image("IconoStamina")
            .resizable()
            .scaledToFill()
            .frame(width: tamano, height: tamano)
            .clipShape(RoundedRectangle(cornerRadius: tamano * Self.proporcionDelRadio, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Vistas previas

#if DEBUG
@available(iOS 17.0, *)
#Preview("Pantalla bloqueada", as: .content, using: AtributosDeSalidaEnVivo(deporte: .running)) {
    SalidaEnVivoWidget()
} contentStates: {
    EstadoDeSalidaEnVivo(inicioDelCronometro: Date().addingTimeInterval(-1_725), segundos: 1_725,
                         pausada: false, metros: 5_230, ritmoSegPorKm: 330, enMillas: false)
    EstadoDeSalidaEnVivo(inicioDelCronometro: Date(), segundos: 1_725,
                         pausada: true, metros: 5_230, ritmoSegPorKm: 330, enMillas: true)
}
#endif
