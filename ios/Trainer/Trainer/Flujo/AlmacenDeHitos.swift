import Foundation
import Combine
import SwiftUI
import TrainerCore

/// Almacén persistente de hitos diarios: entrenamientos completados y pasos registrados.
/// Permite consultar qué se entrenó cada día (incluyendo múltiples sesiones en un mismo día)
/// y cuántos pasos se dieron, preservando los datos de forma local en el dispositivo.
@MainActor
public final class AlmacenDeHitos: ObservableObject {
    public static let compartido = AlmacenDeHitos()

    private let clavePasosStorage = "stamina_hitos_pasos_por_dia"
    private let claveActividadesStorage = "stamina_hitos_actividades_por_dia"

    @Published public private(set) var pasosPorDia: [String: Int] = [:]
    @Published public private(set) var actividadesPorDia: [String: [Actividad]] = [:]
    @Published public private(set) var todasLasActividades: [Actividad] = []

    private var suscripciones = Set<AnyCancellable>()

    private static let formatoFechaClave: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        return df
    }()

    public static func clave(para fecha: Date) -> String {
        formatoFechaClave.string(from: fecha)
    }

    public static func fecha(desde clave: String) -> Date? {
        formatoFechaClave.date(from: clave)
    }

    private init() {
        cargarDeDisco()
        conectarConServicioDePasos()
        verificarDatosIniciales()
    }

    // MARK: - Conexión con Salud y Sincronización

    private func conectarConServicioDePasos() {
        // Escuchar cambios de Apple Health y fusionarlos
        ServicioDePasosSalud.compartido.$pasosPorDia
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pasosHealth in
                guard let self else { return }
                var huboCambios = false
                for (clave, cant) in pasosHealth where cant > 0 {
                    if self.pasosPorDia[clave] != cant {
                        self.pasosPorDia[clave] = cant
                        huboCambios = true
                    }
                }
                if huboCambios {
                    self.guardarEnDisco()
                }
            }
            .store(in: &suscripciones)
    }

    // MARK: - Persistencia

    private func cargarDeDisco() {
        if let datosPasos = UserDefaults.standard.dictionary(forKey: clavePasosStorage) as? [String: Int] {
            self.pasosPorDia = datosPasos
        }

        if let datosRaw = UserDefaults.standard.data(forKey: claveActividadesStorage),
           let guardadas = try? JSONDecoder().decode([String: [Actividad]].self, from: datosRaw) {
            self.actividadesPorDia = guardadas
            recalcularListaPlana()
        }
    }

    private func guardarEnDisco() {
        UserDefaults.standard.set(pasosPorDia, forKey: clavePasosStorage)

        if let datosEncoded = try? JSONEncoder().encode(actividadesPorDia) {
            UserDefaults.standard.set(datosEncoded, forKey: claveActividadesStorage)
        }
        recalcularListaPlana()
    }

    private func recalcularListaPlana() {
        let todas = actividadesPorDia.values.flatMap { $0 }
        self.todasLasActividades = todas.sorted { $0.startedAtMs > $1.startedAtMs }
    }

    // MARK: - Gestión de Pasos

    /// Guarda la cantidad de pasos para una fecha determinada (ej: 5000 pasos ayer).
    public func guardarPasos(_ pasos: Int, para fecha: Date) {
        let clave = Self.clave(para: fecha)
        pasosPorDia[clave] = max(0, pasos)
        guardarEnDisco()
    }

    /// Obtiene la cantidad de pasos para una fecha dada.
    public func pasos(para fecha: Date) -> Int {
        let clave = Self.clave(para: fecha)
        return pasosPorDia[clave] ?? 0
    }

    // MARK: - Gestión de Actividades

    /// Registra un entrenamiento asociándolo a su fecha correspondiente.
    public func registrarActividad(_ actividad: Actividad) {
        let fecha = Date(timeIntervalSince1970: Double(actividad.startedAtMs) / 1000)
        let clave = Self.clave(para: fecha)

        var lista = actividadesPorDia[clave] ?? []
        lista.removeAll { $0.id == actividad.id }
        lista.insert(actividad, at: 0)
        lista.sort { $0.startedAtMs > $1.startedAtMs }

        actividadesPorDia[clave] = lista
        guardarEnDisco()
    }

    /// Retorna la lista de entrenamientos realizados en una fecha determinada.
    public func actividades(para fecha: Date) -> [Actividad] {
        let clave = Self.clave(para: fecha)
        return actividadesPorDia[clave] ?? []
    }

    /// Calcula el nivel de intensidad (0 a 4) para el mapa de calor estilo GitHub.
    public func nivelDeActividad(para fecha: Date) -> Int {
        let entrenamientos = actividades(para: fecha)
        if entrenamientos.isEmpty {
            let p = pasos(para: fecha)
            if p >= 10_000 { return 2 }
            if p >= 5_000 { return 1 }
            return 0
        }

        let totalMetros = entrenamientos.reduce(0) { $0 + Int($1.distanceM ?? 0) }
        let cantidad = entrenamientos.count

        if cantidad >= 3 || totalMetros >= 12_000 {
            return 4
        } else if cantidad >= 2 || totalMetros >= 6_000 {
            return 3
        } else if totalMetros >= 3_000 {
            return 2
        } else {
            return 1
        }
    }

    /// Estadísticas acumuladas para el resumen del calendario anual.
    public func resumenAnual() -> (totalSesiones: Int, totalKm: Double, totalPasos: Int, diasEntrenados: Int) {
        var totalMetros = 0
        var totalSesiones = 0
        var diasConEntreno = 0

        for (_, lista) in actividadesPorDia {
            if !lista.isEmpty {
                diasConEntreno += 1
                totalSesiones += lista.count
                totalMetros += lista.reduce(0) { $0 + Int($1.distanceM ?? 0) }
            }
        }

        let totalPasos = pasosPorDia.values.reduce(0, +)
        return (totalSesiones, Double(totalMetros) / 1000.0, totalPasos, diasConEntreno)
    }

    // MARK: - Datos Iniciales de Ejemplo (Caso de uso del usuario)

    /// Si no hay registros previos, inicializa con el ejemplo solicitado por el usuario:
    /// - Ayer: 5.000 pasos, y 2 sesiones de running (1 km corriendo y 2 km corriendo).
    /// - Días previos para llenar el gráfico anual de GitHub de forma realista.
    private func verificarDatosIniciales() {
        guard actividadesPorDia.isEmpty else { return }

        let cal = Calendar.current
        let hoy = Date()

        // 1. AYER (Ejemplo explícito del usuario: 5000 pasos, 1 km corriendo y 2 km corriendo)
        if let ayer = cal.date(byAdding: .day, value: -1, to: hoy) {
            let claveAyer = Self.clave(para: ayer)
            pasosPorDia[claveAyer] = 5000

            let baseAyerMs = Int64(cal.startOfDay(for: ayer).timeIntervalSince1970 * 1000)

            // Primer entrenamiento: 1 km corriendo a las 8:30
            let act1 = Actividad(
                id: "ejemplo-ayer-1km",
                sport: .running,
                startedAtMs: baseAyerMs + (8 * 3600 + 30 * 60) * 1000,
                durationS: 320, // 5m 20s
                distanceM: 1000,
                elevationGainM: 12,
                avgHrBpm: 142,
                maxHrBpm: 158,
                kcal: 68,
                device: .telefono,
                createdAtMs: baseAyerMs,
                updatedAtMs: baseAyerMs
            )

            // Segundo entrenamiento: 2 km corriendo a las 18:15
            let act2 = Actividad(
                id: "ejemplo-ayer-2km",
                sport: .running,
                startedAtMs: baseAyerMs + (18 * 3600 + 15 * 60) * 1000,
                durationS: 645, // 10m 45s
                distanceM: 2000,
                elevationGainM: 25,
                avgHrBpm: 151,
                maxHrBpm: 169,
                kcal: 142,
                device: .telefono,
                createdAtMs: baseAyerMs,
                updatedAtMs: baseAyerMs
            )

            actividadesPorDia[claveAyer] = [act1, act2]

            // Guardar rutas GPS locales para poder reproducir el recorrido en 3D
            let ruta1 = generarRutaGPS(
                latBase: -34.5880, lonBase: -58.3900,
                puntosCant: 30, distanciaM: 1000,
                inicioMs: act1.startedAtMs, duracionS: act1.durationS
            )
            AlmacenDeRecorridos.compartido.guardar(id: act1.id, puntos: ruta1)

            let ruta2 = generarRutaGPS(
                latBase: -34.5820, lonBase: -58.3950,
                puntosCant: 50, distanciaM: 2000,
                inicioMs: act2.startedAtMs, duracionS: act2.durationS
            )
            AlmacenDeRecorridos.compartido.guardar(id: act2.id, puntos: ruta2)
        }

        // 2. Historial de semanas anteriores para poblar el calendario anual
        let diasPatron: [(diasAtras: Int, pasos: Int, deporte: DeporteDeSesion, metros: Int, segundos: Int)] = [
            (diasAtras: 3, pasos: 8200, deporte: .running, metros: 5200, segundos: 1620),
            (diasAtras: 4, pasos: 6400, deporte: .ciclismo, metros: 18400, segundos: 2800),
            (diasAtras: 6, pasos: 10200, deporte: .running, metros: 8000, segundos: 2450),
            (diasAtras: 8, pasos: 7100, deporte: .running, metros: 4000, segundos: 1250),
            (diasAtras: 10, pasos: 9300, deporte: .ciclismo, metros: 22000, segundos: 3400),
            (diasAtras: 12, pasos: 5500, deporte: .running, metros: 3000, segundos: 960),
            (diasAtras: 15, pasos: 11000, deporte: .running, metros: 10000, segundos: 3100),
            (diasAtras: 18, pasos: 6000, deporte: .ciclismo, metros: 15000, segundos: 2400),
            (diasAtras: 21, pasos: 8500, deporte: .running, metros: 6500, segundos: 2050),
            (diasAtras: 25, pasos: 7800, deporte: .running, metros: 5000, segundos: 1550),
            (diasAtras: 30, pasos: 12000, deporte: .running, metros: 12000, segundos: 3700),
            (diasAtras: 35, pasos: 6200, deporte: .ciclismo, metros: 20000, segundos: 3100),
            (diasAtras: 42, pasos: 9100, deporte: .running, metros: 7000, segundos: 2200),
            (diasAtras: 48, pasos: 8400, deporte: .running, metros: 5500, segundos: 1700),
            (diasAtras: 56, pasos: 10500, deporte: .ciclismo, metros: 25000, segundos: 3900),
            (diasAtras: 63, pasos: 7200, deporte: .running, metros: 4500, segundos: 1400),
            (diasAtras: 70, pasos: 13000, deporte: .running, metros: 15000, segundos: 4800)
        ]

        for item in diasPatron {
            if let fecha = cal.date(byAdding: .day, value: -item.diasAtras, to: hoy) {
                let clave = Self.clave(para: fecha)
                pasosPorDia[clave] = item.pasos

                let inicioMs = Int64(cal.startOfDay(for: fecha).timeIntervalSince1970 * 1000) + 9 * 3600 * 1000
                let act = Actividad(
                    id: "ejemplo-hist-\(item.diasAtras)",
                    sport: item.deporte,
                    startedAtMs: inicioMs,
                    durationS: Int64(item.segundos),
                    distanceM: Int64(item.metros),
                    elevationGainM: 35,
                    avgHrBpm: 148,
                    maxHrBpm: 165,
                    kcal: Int64(item.metros / 15),
                    device: .telefono,
                    createdAtMs: inicioMs,
                    updatedAtMs: inicioMs
                )
                actividadesPorDia[clave] = [act]
            }
        }

        guardarEnDisco()
    }

    private func generarRutaGPS(
        latBase: Double,
        lonBase: Double,
        puntosCant: Int,
        distanciaM: Double,
        inicioMs: Int64,
        duracionS: Int64
    ) -> [PuntoDeRecorrido] {
        var puntos: [PuntoDeRecorrido] = []
        let dtMs = duracionS * 1000 / Int64(max(1, puntosCant))
        for i in 0..<puntosCant {
            let frac = Double(i) / Double(max(1, puntosCant - 1))
            let lat = latBase + (sin(frac * .pi * 2.5) * 0.003) + (frac * 0.007)
            let lon = lonBase + (cos(frac * .pi * 2.0) * 0.004) + (frac * 0.005)
            puntos.append(PuntoDeRecorrido(lat: lat, lon: lon, atMs: inicioMs + Int64(i) * dtMs))
        }
        return puntos
    }
}
