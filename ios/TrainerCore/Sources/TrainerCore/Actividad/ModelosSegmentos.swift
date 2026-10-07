import Foundation

/// Coordenada geográfica plana para persistencia y desacoplamiento de CoreLocation.
public struct CoordenadaGPS: Codable, Equatable, Sendable {
    public let latitud: Double
    public let longitud: Double

    public init(latitud: Double, longitud: Double) {
        self.latitud = latitud
        self.longitud = longitud
    }
}

/// Representa un tramo activo continuo de un entrenamiento.
public struct SegmentoActividad: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { numero }
    public let numero: Int
    public let inicioMs: Int64
    public let finMs: Int64
    public let distanciaMetros: Int
    public let duracionSegundos: Int
    public let inicioCoords: CoordenadaGPS
    public let finCoords: CoordenadaGPS
    public let puntos: [PuntoDeRecorrido]

    public init(
        numero: Int,
        inicioMs: Int64,
        finMs: Int64,
        distanciaMetros: Int,
        duracionSegundos: Int,
        inicioCoords: CoordenadaGPS,
        finCoords: CoordenadaGPS,
        puntos: [PuntoDeRecorrido]
    ) {
        self.numero = numero
        self.inicioMs = inicioMs
        self.finMs = finMs
        self.distanciaMetros = distanciaMetros
        self.duracionSegundos = duracionSegundos
        self.inicioCoords = inicioCoords
        self.finCoords = finCoords
        self.puntos = puntos
    }

    public var ritmoSegPorKm: Int? {
        guard distanciaMetros >= 50, duracionSegundos > 0 else { return nil }
        return Int((Double(duracionSegundos) * 1000.0 / Double(distanciaMetros)).rounded())
    }
}

/// Representa un período de pausa durante el entrenamiento.
public struct PausaActividad: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { numero }
    public let numero: Int
    public let inicioMs: Int64
    public let finMs: Int64
    public let duracionSegundos: Int
    public let inicioCoords: CoordenadaGPS
    public let finCoords: CoordenadaGPS
    public let puntosPausa: [PuntoDeRecorrido]

    public init(
        numero: Int,
        inicioMs: Int64,
        finMs: Int64,
        duracionSegundos: Int,
        inicioCoords: CoordenadaGPS,
        finCoords: CoordenadaGPS,
        puntosPausa: [PuntoDeRecorrido] = []
    ) {
        self.numero = numero
        self.inicioMs = inicioMs
        self.finMs = finMs
        self.duracionSegundos = duracionSegundos
        self.inicioCoords = inicioCoords
        self.finCoords = finCoords
        self.puntosPausa = puntosPausa
    }

    /// Distancia desplazada durante la pausa (excluida del total del entrenamiento).
    public var distanciaDesplazadaMetros: Int {
        guard puntosPausa.count > 1 else { return 0 }
        var total = 0.0
        for i in 0..<(puntosPausa.count - 1) {
            total += SegmentadorDeRecorrido.distanciaMetros(
                lat1: puntosPausa[i].lat, lon1: puntosPausa[i].lon,
                lat2: puntosPausa[i+1].lat, lon2: puntosPausa[i+1].lon
            )
        }
        return Int(total.rounded())
    }
}

/// Tipo de hito o marca en la ruta del mapa.
public enum TipoMarcaRuta: Codable, Equatable, Sendable {
    case vuelta(Int)
    case pausa
    case reanudacion
}

/// Marca exacta en la ruta donde se tocó vuelta, pausa o reanudar.
public struct MarcaRuta: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let tipo: TipoMarcaRuta
    public let latitud: Double
    public let longitud: Double
    public let instanteMs: Int64

    public init(id: String = UUID().uuidString, tipo: TipoMarcaRuta, latitud: Double, longitud: Double, instanteMs: Int64) {
        self.id = id
        self.tipo = tipo
        self.latitud = latitud
        self.longitud = longitud
        self.instanteMs = instanteMs
    }
}

/// Tramo de recorrido asociado a un deporte específico (para multideporte / triatlón).
public struct TramoPorDeporte: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let deporte: DeporteDeSesion
    public var puntos: [PuntoDeRecorrido]

    public init(id: String = UUID().uuidString, deporte: DeporteDeSesion, puntos: [PuntoDeRecorrido] = []) {
        self.id = id
        self.deporte = deporte
        self.puntos = puntos
    }
}
