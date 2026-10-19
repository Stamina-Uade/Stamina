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
        AjustesPagina(Textos.settingsNotificationsTitle,
                      volver: volver) {
            AjustesTarjetaDeFilas {
                AjustesFilaInterruptor(
                    simbolo: "sunrise.fill",
                    titulo: Textos.settingsNotificationsDailyPlan,
                    pista: Textos.settingsNotificationsDailyPlanDetail,
                    encendido: $manana)

                AjustesDivisorDeFila()

                AjustesFilaInterruptor(
                    simbolo: "alarm.fill",
                    titulo: Textos.settingsNotificationsThirtyMinBefore,
                    pista: Textos.settingsNotificationsThirtyMinBeforeDetail,
                    encendido: $previo)

                AjustesDivisorDeFila()

                AjustesFilaInterruptor(
                    simbolo: "thermometer.sun.fill",
                    titulo: Textos.settingsNotificationsHeat,
                    pista: Textos.settingsNotificationsHeatDetail,
                    encendido: $calor)
            }

            // La atribución que Apple exige para los datos de WeatherKit.
            AtribucionDeAppleWeather()
                .padding(.leading, TokensEspaciado.e4)
        }
    }
}
