import SwiftUI
import TrainerCore

/// Ajustes → Notificaciones: los tres avisos, ícono y título. Las claves y
/// el reprogramar viven en `AjustesView`; acá sólo se prenden y se apagan.
struct AjustesPaginaNotificaciones: View {
    @Binding var manana: Bool
    @Binding var previo: Bool
    @Binding var calor: Bool
    let volver: () -> Void

    var body: some View {
        AjustesPagina(String(localized: "Notificaciones", comment: "Ajustes: página de avisos"),
                      volver: volver) {
            AjustesTarjetaDeFilas {
                AjustesFilaInterruptor(
                    simbolo: "sunrise.fill",
                    titulo: String(localized: "Plan del día", comment: "Ajustes: aviso de la mañana"),
                    pista: String(localized: "Los días de entreno, a primera hora: qué toca hacer hoy y a qué hora.",
                                  comment: "Ajustes: qué hace el aviso de la mañana"),
                    encendido: $manana)

                AjustesDivisorDeFila()

                AjustesFilaInterruptor(
                    simbolo: "alarm.fill",
                    titulo: String(localized: "30 min antes", comment: "Ajustes: recordatorio previo al entreno"),
                    pista: String(localized: "30 minutos antes de la hora definida para el entrenamiento"),
                    encendido: $previo)

                AjustesDivisorDeFila()

                AjustesFilaInterruptor(
                    simbolo: "thermometer.sun.fill",
                    titulo: String(localized: "Calor", comment: "Ajustes: aviso de calor"),
                    pista: String(localized: "Si el pronóstico supera los 30 °C antes de entrenar, te avisamos por la mañana."),
                    encendido: $calor)
            }

            // La atribución que pide la licencia de los datos del clima.
            Link(String(localized: "Clima: MET Norway (CC BY 4.0)", comment: "Ajustes: atribución de los datos del clima"),
                 destination: URL(string: "https://api.met.no/weatherapi/locationforecast/2.0/")!)
                .estilo(.notaLegal, color: Paleta.textoTerciario)
                .padding(.leading, TokensEspaciado.e4)
        }
    }
}
