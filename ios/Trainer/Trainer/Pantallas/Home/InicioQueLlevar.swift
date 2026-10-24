import SwiftUI
import TrainerCore

/// "Qué llevar hoy": la hoja que abre la línea «Qué llevar: …» de la tarjeta de hoy.
///
/// Junta lo que antes estaba repartido entre las píldoras de hidratación y la agenda
/// "Tu día" (el snack de antes, los bidones y los geles, la recuperación). 🛑 Todos los
/// números son los del avituallamiento que calcula el servidor: si un dato no vino,
/// su fila no va. Nunca un número de ejemplo.
struct HojaQueLlevarHoy: View {
    let sesion: SesionDelDia
    let unidades: SistemaDeUnidades
    @Environment(\.dismiss) private var cerrar

    /// El snack de antes, a esta distancia de la hora de salir: la misma regla que
    /// tenía la agenda.
    static let minutosDelSnackAntes = 180

    var body: some View {
        HojaAMedida(estimado: 460) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                EncabezadoDeHoja(titulo: Textos.homeExplainerWhatToBringToday,
                                 bajada: Textos.homeBringFor(paraQue))
                VStack(spacing: 0) {
                    ForEach(Array(filas.enumerated()), id: \.offset) { indice, fila in
                        if indice > 0 {
                            Rectangle().fill(Paleta.divisor).frame(height: TokensEspaciado.e1)
                                .accessibilityHidden(true)
                        }
                        FilaDeHoja(titulo: fila.titulo, valor: fila.valor)
                    }
                }
                .padding(.horizontal, TokensEspaciado.e14)
                .tarjeta()
                BotonPrimario(Textos.commonDone) {
                    Haptico.toque()
                    cerrar()
                }
            }
            .margenesDeHoja()
        }
    }

    /// "Rodaje suave · 8 km": la sesión de hoy, con su distancia.
    private var paraQue: String {
        guard let metros = sesion.distanciaMetros else { return sesion.tipo }
        return "\(sesion.tipo) · \(Formato.distancia(metros, unidades: unidades))"
    }

    private var filas: [(titulo: String, valor: String)] {
        guard let a = sesion.avituallamiento else { return [] }
        var filas: [(String, String)] = []
        if a.mililitrosPorHora > 0 {
            filas.append((Textos.homeBringWaterWithSalts, Textos.homeBringMlPerHour(a.mililitrosPorHora)))
        }
        filas.append((Textos.homeExplainerGels, "\(a.geles)"))
        if a.carbohidratosPorHoraG > 0 {
            filas.append((Textos.homeExplainerCarbs, Textos.homeBringGramsPerHour(a.carbohidratosPorHoraG)))
        }
        if a.carbohidratosAntesG > 0 {
            if let minuto = sesion.minutoDelDia {
                let hora = Formato.hora(minutoDelDia: (minuto - Self.minutosDelSnackAntes + 24 * 60) % (24 * 60))
                filas.append((Textos.homeBringSnackBefore, Textos.homeBringSnackAt(hora, a.carbohidratosAntesG)))
            } else {
                filas.append((Textos.homeBringSnackBefore, Textos.homeBringSnack(a.carbohidratosAntesG)))
            }
        }
        if a.proteinaDespuesG > 0 || a.carbohidratosDespuesG > 0 {
            filas.append((Textos.homeBringRecovery, Textos.homeBringRecoveryValue(a.proteinaDespuesG, a.carbohidratosDespuesG)))
        }
        return filas
    }
}

/// Una fila de una hoja: el nombre a la izquierda y el valor a la derecha.
struct FilaDeHoja: View {
    let titulo: String
    let valor: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e12) {
            Text(titulo).estilo(.cuerpoDestacado)
            Spacer(minLength: TokensEspaciado.e8)
            Text(valor)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.vertical, TokensEspaciado.e12)
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        .accessibilityElement(children: .combine)
    }
}
