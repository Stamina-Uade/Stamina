import Foundation

/// Agrupa los puntos GPS en tramos separados cuando hubo una pausa o salto,
/// evitando trazar una línea recta que una puntos distantes tras pausar.
public enum SegmentadorDeRecorrido {
    public static func segmentar(
        _ puntos: [PuntoDeRecorrido],
        umbralPausaSegundos: Double = 20.0,
        umbralSaltoMetros: Double = 60.0
    ) -> [[PuntoDeRecorrido]] {
        guard !puntos.isEmpty else { return [] }
        var tramos: [[PuntoDeRecorrido]] = []
        var tramoActual: [PuntoDeRecorrido] = []

        for punto in puntos {
            if let anterior = tramoActual.last {
                let segundos = Double(punto.atMs - anterior.atMs) / 1000.0
                let distancia = distanciaMetros(lat1: anterior.lat, lon1: anterior.lon,
                                                lat2: punto.lat, lon2: punto.lon)
                let huboPausa = segundos > umbralPausaSegundos
                let huboSalto = distancia > umbralSaltoMetros && segundos > 3.0
                if huboPausa || huboSalto {
                    tramos.append(tramoActual)
                    tramoActual = [punto]
                    continue
                }
            }
            tramoActual.append(punto)
        }

        if !tramoActual.isEmpty {
            tramos.append(tramoActual)
        }
        return tramos
    }

    public static func distanciaMetros(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let radioTierra = 6_371_000.0
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let deltaPhi = (lat2 - lat1) * .pi / 180
        let deltaLambda = (lon2 - lon1) * .pi / 180
        let sPhi = sin(deltaPhi / 2)
        let sLam = sin(deltaLambda / 2)
        let a = sPhi * sPhi + cos(phi1) * cos(phi2) * sLam * sLam
        return radioTierra * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }

    public static func rumboEntre(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let deltaLambda = (lon2 - lon1) * .pi / 180
        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        let radians = atan2(y, x)
        return (radians * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
