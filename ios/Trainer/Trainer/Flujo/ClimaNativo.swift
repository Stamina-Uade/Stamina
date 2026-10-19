import CoreLocation
import Foundation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Una hora del pronóstico, con lo único que usa la app.
struct HoraDeClima: Equatable, Sendable {
    let fecha: Date
    let temperaturaC: Double
    /// La sensación térmica (calor + humedad + viento).
    let sensacionC: Double
    /// De 0 a 1.
    let humedad: Double

    /// Lo que siente el cuerpo: la mayor entre temperatura y sensación.
    var calorC: Double { max(temperaturaC, sensacionC) }
}

/// Lo que pide la atribución de Apple Weather: las dos marcas y la página legal.
struct AtribucionDelClima: Equatable, Sendable {
    let marcaOscura: URL
    let marcaClara: URL
    let paginaLegal: URL
}

/// El clima, del sistema (WeatherKit), sin APIs de terceros ni servidor propio.
///
/// 🛑 Falla en silencio: sin el permiso de WeatherKit, sin red o con cualquier
/// error devuelve `nil`, y lo que dependa del clima simplemente no aparece. No
/// pide permisos: la ubicación la pone quien llama (la que ya tiene la app).
enum ClimaNativo {

    /// La página legal fija, por si la atribución del sistema no llega.
    static let paginaLegalPorDefecto = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    /// Las próximas `horas` horas del pronóstico horario, o `nil` si no hay.
    static func proximasHoras(en coordenada: CLLocationCoordinate2D, horas: Int = 48) async -> [HoraDeClima]? {
        #if canImport(WeatherKit)
        guard CLLocationCoordinate2DIsValid(coordenada), horas > 0 else { return nil }
        let ubicacion = CLLocation(latitude: coordenada.latitude, longitude: coordenada.longitude)
        let desde = Date()
        let hasta = desde.addingTimeInterval(TimeInterval(horas) * 60 * 60)
        do {
            let pronostico = try await WeatherService.shared.weather(
                for: ubicacion, including: .hourly(startDate: desde, endDate: hasta))
            let resultado = pronostico.forecast.map { hora in
                HoraDeClima(fecha: hora.date,
                            temperaturaC: hora.temperature.converted(to: .celsius).value,
                            sensacionC: hora.apparentTemperature.converted(to: .celsius).value,
                            humedad: hora.humidity)
            }
            return resultado.isEmpty ? nil : resultado
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// La hora más calurosa entre `inicio` y `fin`. Las horas del pronóstico caen
    /// en punto: se cuenta también la de hasta media hora antes del inicio.
    static func pico(entre inicio: Date, y fin: Date, en horas: [HoraDeClima]) -> HoraDeClima? {
        let desde = inicio.addingTimeInterval(-30 * 60)
        return horas
            .filter { $0.fecha >= desde && $0.fecha <= fin }
            .max { $0.calorC < $1.calorC }
    }

    /// La atribución oficial del sistema, o `nil` si WeatherKit no contesta.
    static func atribucion() async -> AtribucionDelClima? {
        #if canImport(WeatherKit)
        do {
            let atribucion = try await WeatherService.shared.attribution
            return AtribucionDelClima(marcaOscura: atribucion.combinedMarkDarkURL,
                                      marcaClara: atribucion.combinedMarkLightURL,
                                      paginaLegal: atribucion.legalPageURL)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
