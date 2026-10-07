import Foundation

public enum TipoDeAvisoDeAvituallamiento: String, Equatable, Sendable {
    case agua, gel, sales
}

public struct InsumosDeSalida: Equatable, Sendable {
    public var geles: Int
    public var sales: Int
    public var aguaMl: Int

    public init(geles: Int, sales: Int, aguaMl: Int) {
        self.geles = max(0, min(geles, 20))
        self.sales = max(0, min(sales, 20))
        self.aguaMl = max(0, min(aguaMl, 5_000))
    }
}

/// Recordatorios por tiempo activo. Cada aviso consume una unidad declarada;
/// al reanudar una salida no se repiten los ya mostrados.
public struct PlanificadorDeAvituallamiento: Sendable {
    private var aguaAvisada = 0
    private var gelesAvisados = 0
    private var salesAvisadas = 0
    private var ultimoAvisoSegundos = -180

    public init() {}

    public mutating func siguiente(
        segundos: Int,
        insumos: InsumosDeSalida,
        deporte: DeporteDeSesion = .running
    ) -> TipoDeAvisoDeAvituallamiento? {
        guard segundos >= 0, segundos - ultimoAvisoSegundos >= 180 else { return nil }
        // En natación y fuerza no interrumpimos para consumir insumos.
        if deporte == .natacion || deporte == .fuerza { return nil }
        // Intervalos de recordatorio según el deporte, no dosis obligatorias.
        let intervalos: (agua: Int, gel: Int, sales: Int) = switch deporte {
        case .ciclismo: (900, 2_400, 3_600)
        case .trekking: (1_500, 3_600, 5_400)
        default: (1_200, 2_700, 3_600)
        }
        let aguaDisponible = min((insumos.aguaMl + 199) / 200, 20)
        if aguaAvisada < aguaDisponible && segundos >= (aguaAvisada + 1) * intervalos.agua {
            aguaAvisada += 1
            ultimoAvisoSegundos = segundos
            return .agua
        }
        if gelesAvisados < insumos.geles && segundos >= (gelesAvisados + 1) * intervalos.gel {
            gelesAvisados += 1
            ultimoAvisoSegundos = segundos
            return .gel
        }
        if salesAvisadas < insumos.sales && segundos >= (salesAvisadas + 1) * intervalos.sales {
            salesAvisadas += 1
            ultimoAvisoSegundos = segundos
            return .sales
        }
        return nil
    }
}
