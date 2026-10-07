import SwiftUI
import TrainerCore

@main
struct TrainerApp: App {
    /// La red se arma UNA vez por proceso. Dos `RenovadorDeSesion` serían dos
    /// renovaciones posibles en vuelo con el mismo refresh, que es exactamente lo
    /// que hace que el servidor revoque la sesión entera (B-008). Adentro de los
    /// tests, en DEBUG, se arman los dobles (`ServiciosDeLaApp.paraEsteProceso`).
    private let servicios = ServiciosDeLaApp.paraEsteProceso()

    init() {
        NotificadorDeEntrenamiento.configurarPresentacionEnPrimerPlano()
    }

    var body: some Scene {
        WindowGroup {
            RaizFlujoView(flujo: FlujoEntrada(servicio: servicios.cuenta,
                                              consultarVersion: servicios.consultarVersion,
                                              sincronizador: servicios.sincronizador),
                          repositorioDelHome: Self.repositorioDelHome(servicios))
                .environment(\.locale, ConfiguracionDeIdioma.localeEfectivo)
        }
    }

    /// El Home habla con el servidor. Sólo en DEBUG y sólo con `-datosDeEjemplo`
    /// muestra la maqueta del diseño, para revisar pantallas sin cuenta ni red.
    private static func repositorioDelHome(_ servicios: ServiciosDeLaApp) -> () -> RepositorioDePlan {
        ArranqueDePrueba.conDatosDeEjemplo ? { RepositorioProvisional() } : servicios.repositorioDelHome
    }
}
