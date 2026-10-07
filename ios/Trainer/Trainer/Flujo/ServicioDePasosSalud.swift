import Foundation
import HealthKit

/// Servicio para consultar la cantidad de pasos diarios desde Apple Health (HealthKit).
/// Pide permiso al usuario la primera vez que se consulta.
@MainActor
public final class ServicioDePasosSalud: ObservableObject {
    public static let compartido = ServicioDePasosSalud()

    private let healthStore = HKHealthStore()
    private let tipoPasos = HKQuantityType.quantityType(forIdentifier: .stepCount)

    @Published public private(set) var pasosPorDia: [String: Int] = [:]
    @Published public private(set) var permisoSolicitado: Bool = false

    private static let formatoFechaClave: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        return df
    }()

    public static func clave(para fecha: Date) -> String {
        formatoFechaClave.string(from: fecha)
    }

    public func solicitarPermisoYConsultar(fechas: [Date]) async {
        guard HKHealthStore.isHealthDataAvailable(), let tipoPasos else { return }

        if !permisoSolicitado {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [tipoPasos])
                permisoSolicitado = true
            } catch {
                return
            }
        }

        await consultarPasos(para: fechas)
    }

    public func consultarPasos(para fechas: [Date]) async {
        guard HKHealthStore.isHealthDataAvailable(), let tipoPasos else { return }

        let calendario = Calendar.current
        var nuevosPasos: [String: Int] = [:]

        for fecha in fechas {
            let inicio = calendario.startOfDay(for: fecha)
            guard let fin = calendario.date(byAdding: .day, value: 1, to: inicio) else { continue }

            let clave = Self.clave(para: inicio)
            let predicado = HKQuery.predicateForSamples(withStart: inicio, end: fin, options: .strictStartDate)

            let pasos: Int = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: tipoPasos,
                    quantitySamplePredicate: predicado,
                    options: .cumulativeSum
                ) { _, estadisticas, _ in
                    let total = estadisticas?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    continuation.resume(returning: Int(total.rounded()))
                }
                self.healthStore.execute(query)
            }

            nuevosPasos[clave] = pasos
        }

        self.pasosPorDia.merge(nuevosPasos) { _, nuevo in nuevo }
    }
}
