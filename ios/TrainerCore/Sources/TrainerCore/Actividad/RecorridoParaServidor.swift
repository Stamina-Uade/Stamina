import Foundation

/// El contrato acepta hasta 10.000 puntos. La captura local conserva todos;
/// esta función prepara únicamente la copia que viaja al servidor, repartiendo
/// las muestras sobre el recorrido completo e incluyendo siempre inicio y final,
/// y garantizando que los instantes temporales sean estrictamente crecientes para
/// evitar que el servidor rechace la ruta con bad_request.
public enum RecorridoParaServidor {
    public static func preparar(_ puntos: [PuntoDeRecorrido], maximo: Int = 10_000) -> [PuntoDeRecorrido] {
        guard !puntos.isEmpty, maximo > 0 else { return [] }
        guard puntos.count > 1 else { return puntos }

        let seleccionados: [PuntoDeRecorrido]
        if puntos.count > maximo {
            let ultimo = puntos.count - 1
            seleccionados = (0..<maximo).map { posicion in
                let indice = Int((Double(posicion) * Double(ultimo) / Double(maximo - 1)).rounded())
                return puntos[indice]
            }
        } else {
            seleccionados = puntos
        }

        // Garantizar que los timestamps sean estrictamente crecientes sin saltos temporales falsos
        var resultado: [PuntoDeRecorrido] = []
        resultado.reserveCapacity(seleccionados.count)

        for p in seleccionados {
            if let ultimo = resultado.last {
                if p.atMs <= ultimo.atMs {
                    // Si el punto tiene timestamp repetido o menor, se incrementa al menos 1 ms
                    let corregido = PuntoDeRecorrido(lat: p.lat, lon: p.lon, atMs: ultimo.atMs + 1)
                    resultado.append(corregido)
                } else {
                    resultado.append(p)
                }
            } else {
                resultado.append(p)
            }
        }

        return resultado
    }
}
