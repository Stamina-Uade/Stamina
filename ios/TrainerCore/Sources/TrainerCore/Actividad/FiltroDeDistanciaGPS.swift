import Foundation

/// Muestra mínima para medir distancia sin atar el dominio a Core Location.
public struct MuestraGPS: Equatable, Sendable {
    public let latitud: Double
    public let longitud: Double
    public let instanteMs: Int64
    public let precisionMetros: Double
    /// Velocidad calculada por el sistema. Un valor negativo significa que no
    /// hay una medición utilizable.
    public let velocidadMetrosPorSegundo: Double

    public init(latitud: Double, longitud: Double, instanteMs: Int64,
                precisionMetros: Double, velocidadMetrosPorSegundo: Double) {
        self.latitud = latitud
        self.longitud = longitud
        self.instanteMs = instanteMs
        self.precisionMetros = precisionMetros
        self.velocidadMetrosPorSegundo = velocidadMetrosPorSegundo
    }
}

/// Descarta deriva de GPS y saltos que no concuerdan con la velocidad medida.
/// Mantiene un ancla mientras el movimiento real todavía es menor que la
/// incertidumbre de la ubicación, para no perder una carrera lenta.
public struct FiltroDeDistanciaGPS: Sendable {
    private var ancla: MuestraGPS?

    public init() {}

    public mutating func reiniciar() { ancla = nil }

    public mutating func agregar(_ muestra: MuestraGPS, deporte: DeporteDeSesion) -> Int {
        // En ciudad y cerca de edificios el reloj suele informar 20–30 m de
        // precisión aun cuando la velocidad medida sí es útil. Rechazar esas
        // muestras dejaba salidas reales enteras en 0 m.
        guard muestra.precisionMetros >= 0, muestra.precisionMetros <= 30 else {
            ancla = nil
            return 0
        }

        let limites: (minima: Double, maxima: Double) = switch deporte {
        case .ciclismo: (0.8, 40)
        case .trekking: (0.20, 14)
        // Elegir Carrera no significa que cada tramo se corra. Caminar, subir
        // escaleras o arrancar despacio también tiene que sumar recorrido.
        case .running: (0.25, 14)
        case .natacion: (0.20, 4)
        case .fuerza: (.greatestFiniteMagnitude, 0)
        case .otro, .triatlon: (0.20, 14)
        }
        let velocidadMinima = limites.minima
        let velocidadMaxima = limites.maxima

        let velocidadMedida = muestra.velocidadMetrosPorSegundo >= 0
            ? muestra.velocidadMetrosPorSegundo : nil
        // Una lectura explícitamente quieta nunca mueve el ancla. De ese modo
        // mover el brazo no suma HealthKit, pero una caminata lenta puede
        // acumular varios pasos hasta superar la incertidumbre del GPS.
        if let velocidadMedida, velocidadMedida < velocidadMinima { return 0 }
        if let velocidadMedida, velocidadMedida > velocidadMaxima {
            ancla = muestra
            return 0
        }
        guard let anterior = ancla else {
            ancla = muestra
            return 0
        }

        let segundos = Double(muestra.instanteMs - anterior.instanteMs) / 1_000
        guard segundos > 0, segundos <= 120 else {
            ancla = muestra
            return 0
        }
        let distancia = Self.distanciaMetros(entre: anterior, y: muestra)
        let precisionMedia = (anterior.precisionMetros + muestra.precisionMetros) / 2
        let incertidumbreBase = max(2.5, min(8, hypot(anterior.precisionMetros,
                                                      muestra.precisionMetros) * 0.45))
        // Sin velocidad del sistema sólo aceptamos un cambio mayor que la
        // precisión declarada. Esto conserva recorridos interiores lentos sin
        // convertir una nube de GPS quieta en distancia.
        let incertidumbre = velocidadMedida == nil
            ? max(incertidumbreBase, min(20, precisionMedia))
            : incertidumbreBase
        guard distancia >= incertidumbre else { return 0 }

        let velocidadGeometrica = distancia / segundos
        guard velocidadGeometrica >= velocidadMinima,
              velocidadGeometrica <= velocidadMaxima else {
            ancla = muestra
            return 0
        }
        if let velocidadMedida {
            let tolerancia = max(8, anterior.precisionMetros + muestra.precisionMetros)
            let distanciaCompatible = velocidadMedida * segundos + tolerancia
            guard distancia <= distanciaCompatible else {
                ancla = muestra
                return 0
            }
        }

        ancla = muestra
        return Int(distancia.rounded())
    }

    private static func distanciaMetros(entre a: MuestraGPS, y b: MuestraGPS) -> Double {
        let radioTierra = 6_371_000.0
        let lat1 = a.latitud * .pi / 180
        let lat2 = b.latitud * .pi / 180
        let deltaLat = (b.latitud - a.latitud) * .pi / 180
        let deltaLon = (b.longitud - a.longitud) * .pi / 180
        let senoLat = sin(deltaLat / 2)
        let senoLon = sin(deltaLon / 2)
        let h = senoLat * senoLat + cos(lat1) * cos(lat2) * senoLon * senoLon
        return radioTierra * 2 * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}

/// Una salida muy breve o sin desplazamiento confirmado no se guarda. La regla
/// vive en Core para que iPhone y Watch decidan exactamente lo mismo.
public enum ValidadorDeSalida {
    public static func sePuedeGuardar(segundos: Int, metros: Int) -> Bool {
        segundos >= 10 && metros > 0
    }
}

/// Combina la distancia que estima HealthKit con el desplazamiento confirmado
/// por GPS. HealthKit mejora la continuidad de una salida, pero por sí solo puede
/// interpretar movimiento del brazo como avance. Por eso sólo se usa cuando el
/// GPS ya confirmó movimiento y ambos valores son compatibles.
public struct MedidorDeDistanciaExterior: Sendable {
    private var filtro = FiltroDeDistanciaGPS()
    private var metrosGPS = 0
    private var metrosDeSalud: Int?

    public init() {}

    public mutating func reiniciar() {
        filtro.reiniciar()
        metrosGPS = 0
        metrosDeSalud = nil
    }

    /// Corta la continuidad entre dos muestras sin borrar lo recorrido. Se usa
    /// al pausar y reanudar para que el cambio de ubicación durante la pausa no
    /// se sume a la salida.
    public mutating func reiniciarAnclaGPS() {
        filtro.reiniciar()
    }

    /// Restaura una salida guardada después de que watchOS cerró el proceso.
    public mutating func recuperar(metrosConfirmados: Int) {
        filtro.reiniciar()
        metrosGPS = max(0, metrosConfirmados)
        metrosDeSalud = nil
    }

    @discardableResult
    public mutating func agregarGPS(_ muestra: MuestraGPS, deporte: DeporteDeSesion) -> Int {
        metrosGPS += filtro.agregar(muestra, deporte: deporte)
        return metros
    }

    @discardableResult
    public mutating func actualizarSalud(metros: Int) -> Int {
        metrosDeSalud = max(0, metros)
        return self.metros
    }

    public var metros: Int {
        guard metrosGPS >= 10, let metrosDeSalud else { return metrosGPS }
        let tolerancia = max(20, Int((Double(metrosGPS) * 0.15).rounded()))
        return abs(metrosDeSalud - metrosGPS) <= tolerancia ? metrosDeSalud : metrosGPS
    }
}
