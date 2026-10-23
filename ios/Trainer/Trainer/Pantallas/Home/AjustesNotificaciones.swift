import SwiftUI
import TrainerCore

/// Ajustes → Notificaciones: los tres avisos, ícono y título. Las claves y
/// el reprogramar viven en `AjustesView`; acá sólo se prenden y se apagan.
///
/// 2026-10-22: "30 min antes" pasó a ser la "Notificación para prepararte", con
/// el mismo interruptor y el mismo tiempo (5 min a 1 h) que en el alta, guardado
/// en el mismo lugar (`AvisoDePreparacion`).
struct AjustesPaginaNotificaciones: View {
    @Binding var manana: Bool
    @Binding var previo: Bool
    @Binding var minutosPrevio: Int
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
                    titulo: Textos.notificationsPrepTitle,
                    pista: Textos.settingsNotificationsPrepDetail,
                    encendido: $previo.animation(.easeInOut(duration: TokensMovimiento.rapida)))

                if previo {
                    FilaDeMinutosDeAviso(minutos: $minutosPrevio)
                        .padding(.horizontal, TokensEspaciado.e14)
                        .padding(.vertical, TokensEspaciado.e8)
                        .padding(.leading, TokensEspaciado.e34 + TokensEspaciado.e12)
                }

                AjustesDivisorDeFila()

                AjustesFilaInterruptor(
                    simbolo: "thermometer.sun.fill",
                    titulo: Textos.settingsNotificationsHeat,
                    pista: Textos.settingsNotificationsHeatDetail,
                    encendido: $calor)

                // La atribución que Apple exige para los datos de WeatherKit, debajo
                // de la fila del aviso que los usa (2026-10-23: el cuerpo de la
                // notificación ya no dice "Datos:  Weather.").
                AtribucionDeAppleWeather()
                    .padding(.leading, TokensEspaciado.e14 + TokensEspaciado.e34 + TokensEspaciado.e12)
                    .padding(.trailing, TokensEspaciado.e14)
                    .padding(.bottom, TokensEspaciado.e12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
