import Foundation

public struct SplitKilometro: Equatable, Sendable, Identifiable {
    public var id: Int { numero }
    public let numero: Int
    public let metros: Int
    public let segundos: Int
    public let ritmoSegPorKm: Int
    public let velocidadKmh: Double

    public init(numero: Int, metros: Int, segundos: Int, ritmoSegPorKm: Int, velocidadKmh: Double) {
        self.numero = numero
        self.metros = metros
        self.segundos = segundos
        self.ritmoSegPorKm = ritmoSegPorKm
        self.velocidadKmh = velocidadKmh
    }
}

public struct DetallePausa: Equatable, Sendable, Identifiable {
    public var id: Int { numero }
    public let numero: Int
    public let inicioMs: Int64
    public let finMs: Int64
    public let duracionSegundos: Int
    public let lat: Double
    public let lon: Double

    public init(numero: Int, inicioMs: Int64, finMs: Int64, duracionSegundos: Int, lat: Double, lon: Double) {
        self.numero = numero
        self.inicioMs = inicioMs
        self.finMs = finMs
        self.duracionSegundos = duracionSegundos
        self.lat = lat
        self.lon = lon
    }
}

public struct DetalleTramo: Equatable, Sendable, Identifiable {
    public var id: Int { numero }
    public let numero: Int
    public let metros: Int
    public let segundos: Int
    public let ritmoSegPorKm: Int?
    public let velocidadKmh: Double?
    public let puntos: [PuntoDeRecorrido]

    public init(numero: Int, metros: Int, segundos: Int, ritmoSegPorKm: Int?, velocidadKmh: Double?, puntos: [PuntoDeRecorrido]) {
        self.numero = numero
        self.metros = metros
        self.segundos = segundos
        self.ritmoSegPorKm = ritmoSegPorKm
        self.velocidadKmh = velocidadKmh
        self.puntos = puntos
    }
}

public struct AnalisisDeRecorrido: Equatable, Sendable {
    public let tramos: [DetalleTramo]
    public let pausas: [DetallePausa]
    public let splitsKm: [SplitKilometro]
    public let tiempoEnMovimientoSegundos: Int
    public let velocidadMaximaKmh: Double?
    public let ritmoMaximoSegPorKm: Int?

    public init(tramos: [DetalleTramo], pausas: [DetallePausa], splitsKm: [SplitKilometro], tiempoEnMovimientoSegundos: Int, velocidadMaximaKmh: Double?, ritmoMaximoSegPorKm: Int?) {
        self.tramos = tramos
        self.pausas = pausas
        self.splitsKm = splitsKm
        self.tiempoEnMovimientoSegundos = tiempoEnMovimientoSegundos
        self.velocidadMaximaKmh = velocidadMaximaKmh
        self.ritmoMaximoSegPorKm = ritmoMaximoSegPorKm
    }
}

public enum AnalizadorDeRecorrido {
    public static func analizar(
        puntos: [PuntoDeRecorrido],
        deporte: DeporteDeSesion = .running,
        duracionTotalSegundos: Int? = nil
    ) -> AnalisisDeRecorrido {
        guard !puntos.isEmpty else {
            return AnalisisDeRecorrido(
                tramos: [],
                pausas: [],
                splitsKm: [],
                tiempoEnMovimientoSegundos: duracionTotalSegundos ?? 0,
                velocidadMaximaKmh: nil,
                ritmoMaximoSegPorKm: nil
            )
        }

        let segmentos = SegmentadorDeRecorrido.segmentar(puntos)
        var tramos: [DetalleTramo] = []
        var pausas: [DetallePausa] = []

        for (indice, tramo) in segmentos.enumerated() {
            var dist = 0.0
            if tramo.count > 1 {
                for i in 0..<(tramo.count - 1) {
                    dist += SegmentadorDeRecorrido.distanciaMetros(
                        lat1: tramo[i].lat, lon1: tramo[i].lon,
                        lat2: tramo[i+1].lat, lon2: tramo[i+1].lon
                    )
                }
            }
            let segs: Int = {
                guard let primero = tramo.first, let ultimo = tramo.last, ultimo.atMs > primero.atMs else { return 0 }
                return max(1, Int((ultimo.atMs - primero.atMs) / 1000))
            }()
            let m = Int(dist.rounded())
            let ritmo = m >= 50 && segs > 0 ? Int((Double(segs) * 1000.0 / Double(m)).rounded()) : nil
            let vel = segs > 0 ? (Double(m) / Double(segs)) * 3.6 : nil
            tramos.append(DetalleTramo(numero: indice + 1, metros: m, segundos: segs, ritmoSegPorKm: ritmo, velocidadKmh: vel, puntos: tramo))

            // Pausa entre este tramo y el siguiente
            if indice < segmentos.count - 1 {
                let sig = segmentos[indice + 1]
                if let finTramo = tramo.last, let inicioSig = sig.first, inicioSig.atMs > finTramo.atMs {
                    let durPausa = max(1, Int((inicioSig.atMs - finTramo.atMs) / 1000))
                    pausas.append(DetallePausa(
                        numero: indice + 1,
                        inicioMs: finTramo.atMs,
                        finMs: inicioSig.atMs,
                        duracionSegundos: durPausa,
                        lat: finTramo.lat,
                        lon: finTramo.lon
                    ))
                }
            }
        }

        let segsMovimiento = tramos.reduce(0) { $0 + $1.segundos }
        let duracionReferencia = duracionTotalSegundos ?? (puntos.last.flatMap { ult in puntos.first.map { prim in max(1, Int((ult.atMs - prim.atMs) / 1000)) } } ?? segsMovimiento)
        let tiempoMovimiento = segsMovimiento > 0 ? min(duracionReferencia, segsMovimiento) : duracionReferencia

        // Velocidad máxima y ritmo máximo
        var velMaxMs: Double = 0.0
        let velLimite = deporte == .ciclismo ? 28.0 : 14.0
        for tramo in segmentos {
            guard tramo.count > 1 else { continue }
            for i in 0..<(tramo.count - 1) {
                let dt = Double(tramo[i+1].atMs - tramo[i].atMs) / 1000.0
                if dt >= 1.0 {
                    let d = SegmentadorDeRecorrido.distanciaMetros(
                        lat1: tramo[i].lat, lon1: tramo[i].lon,
                        lat2: tramo[i+1].lat, lon2: tramo[i+1].lon
                    )
                    let v = d / dt
                    if v < velLimite && v > velMaxMs {
                        velMaxMs = v
                    }
                }
            }
        }
        let velMaxKmh = velMaxMs > 0.5 ? velMaxMs * 3.6 : nil
        let ritmoMax = velMaxMs > 0.5 ? Int((1000.0 / velMaxMs).rounded()) : nil

        // Splits por km
        var splits: [SplitKilometro] = []
        var distAcum = 0.0
        var ultimoKmIndex = 0
        var inicioKmMs = puntos.first?.atMs ?? 0
        var distInicioKm = 0.0

        for (idx, pt) in puntos.enumerated() {
            if idx > 0 {
                let ant = puntos[idx - 1]
                distAcum += SegmentadorDeRecorrido.distanciaMetros(lat1: ant.lat, lon1: ant.lon, lat2: pt.lat, lon2: pt.lon)
            }
            if distAcum >= Double(ultimoKmIndex + 1) * 1000.0 {
                ultimoKmIndex += 1
                let dur = max(1, Int((pt.atMs - inicioKmMs) / 1000))
                let distKm = Int((distAcum - distInicioKm).rounded())
                let ritmoKm = max(1, Int((Double(dur) * 1000.0 / Double(max(1, distKm))).rounded()))
                let velKm = (Double(distKm) / Double(dur)) * 3.6
                splits.append(SplitKilometro(
                    numero: ultimoKmIndex,
                    metros: distKm,
                    segundos: dur,
                    ritmoSegPorKm: ritmoKm,
                    velocidadKmh: velKm
                ))
                inicioKmMs = pt.atMs
                distInicioKm = distAcum
            }
        }

        // Tramo final si quedaron más de 100 metros después del último km completo
        let restoMetros = Int((distAcum - distInicioKm).rounded())
        if restoMetros >= 100, let ultimoPt = puntos.last, ultimoPt.atMs > inicioKmMs {
            let dur = max(1, Int((ultimoPt.atMs - inicioKmMs) / 1000))
            let ritmoKm = max(1, Int((Double(dur) * 1000.0 / Double(restoMetros)).rounded()))
            let velKm = (Double(restoMetros) / Double(dur)) * 3.6
            splits.append(SplitKilometro(
                numero: ultimoKmIndex + 1,
                metros: restoMetros,
                segundos: dur,
                ritmoSegPorKm: ritmoKm,
                velocidadKmh: velKm
            ))
        }

        return AnalisisDeRecorrido(
            tramos: tramos,
            pausas: pausas,
            splitsKm: splits,
            tiempoEnMovimientoSegundos: tiempoMovimiento,
            velocidadMaximaKmh: velMaxKmh,
            ritmoMaximoSegPorKm: ritmoMax
        )
    }
}

extension Actividad: Identifiable {}

