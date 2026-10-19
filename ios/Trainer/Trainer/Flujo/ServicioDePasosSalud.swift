import Foundation
import HealthKit

/// Los pasos diarios de Apple Salud (HealthKit).
///
/// Sólo lee: quién guarda, sube o decide qué número vale es `SincronizadorDePasos`.
///
/// 🛑 HealthKit no dice si la persona dio permiso de LECTURA (es privado a
/// propósito): con el permiso negado, las consultas no fallan, devuelven vacío. Lo
/// único que se puede saber es si ya se le pidió (`yaSePidioPermiso`).
@MainActor
public final class ServicioDePasosSalud: ObservableObject {
    public static let compartido = ServicioDePasosSalud()

    private let healthStore = HKHealthStore()
    private let tipoPasos = HKQuantityType.quantityType(forIdentifier: .stepCount)

    /// Si ya se le mostró a la persona el pedido de permiso de Salud.
    @Published public private(set) var permisoSolicitado: Bool = false

    /// Salud existe en este aparato (en un iPad viejo, no).
    public var disponible: Bool {
        HKHealthStore.isHealthDataAvailable() && tipoPasos != nil
    }

    /// `true` si el pedido de permiso ya se mostró: el sistema contesta `.unnecessary`.
    /// No dice qué contestó la persona.
    public func yaSePidioPermiso() async -> Bool {
        guard disponible, let tipoPasos else { return false }
        let store = healthStore
        let estado: HKAuthorizationRequestStatus = await withCheckedContinuation { continuacion in
            store.getRequestStatusForAuthorization(toShare: [], read: [tipoPasos]) { estado, error in
                continuacion.resume(returning: error == nil ? estado : .unknown)
            }
        }
        permisoSolicitado = estado == .unnecessary
        return permisoSolicitado
    }

    /// Muestra el pedido de permiso, si no se mostró nunca (si ya se mostró, el
    /// sistema no lo repite). Devuelve si quedó pedido.
    @discardableResult
    public func pedirPermiso() async -> Bool {
        guard disponible, let tipoPasos else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [tipoPasos])
        } catch {
            return false
        }
        return await yaSePidioPermiso()
    }

    /// Los pasos de cada día del rango (las dos puntas incluidas), en el calendario
    /// del teléfono.
    ///
    /// Una sola consulta de estadísticas por intervalos de un día: la suma de Salud
    /// ya junta iPhone y Apple Watch sin contar dos veces el mismo paso, que es lo
    /// que hace la app Salud. Un día sin muestras NO viene en el diccionario: "no
    /// hay dato" no es "cero pasos".
    ///
    /// - Returns: las claves son el comienzo de cada día. `nil` si Salud no está o la
    ///   consulta falló (por ejemplo, con el teléfono bloqueado).
    public func pasosDiarios(desde: Date, hasta: Date) async -> [Date: Int]? {
        guard disponible, let tipoPasos else { return nil }
        let calendario = Calendar.current
        let inicio = calendario.startOfDay(for: min(desde, hasta))
        guard let fin = calendario.date(byAdding: .day, value: 1,
                                        to: calendario.startOfDay(for: max(desde, hasta))) else { return nil }
        let predicado = HKQuery.predicateForSamples(withStart: inicio, end: fin, options: .strictStartDate)
        let store = healthStore

        return await withCheckedContinuation { (continuacion: CheckedContinuation<[Date: Int]?, Never>) in
            let consulta = HKStatisticsCollectionQuery(
                quantityType: tipoPasos,
                quantitySamplePredicate: predicado,
                options: .cumulativeSum,
                anchorDate: inicio,
                intervalComponents: DateComponents(day: 1)
            )
            consulta.initialResultsHandler = { _, coleccion, error in
                if let error {
                    // Sin muestras en el rango no es una falla: es un rango vacío.
                    let sinDatos = (error as? HKError)?.code == .errorNoData
                    continuacion.resume(returning: sinDatos ? [:] : nil)
                    return
                }
                guard let coleccion else {
                    continuacion.resume(returning: nil)
                    return
                }
                var porDia: [Date: Int] = [:]
                for estadistica in coleccion.statistics() where estadistica.startDate < fin {
                    guard let suma = estadistica.sumQuantity() else { continue }
                    porDia[estadistica.startDate] = Int(suma.doubleValue(for: HKUnit.count()).rounded())
                }
                continuacion.resume(returning: porDia)
            }
            store.execute(consulta)
        }
    }
}
