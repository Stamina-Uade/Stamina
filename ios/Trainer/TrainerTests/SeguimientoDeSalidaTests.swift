import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

/// La cola de salidas GPS del iPhone: qué se reintenta, qué va a cuarentena y
/// cómo se recupera una salida que quedó a medias.
@MainActor
@Suite("Seguimiento de salida: cola, cuarentena y recuperación")
struct SeguimientoDeSalidaTests {

    @Test("Sin red, 5xx, 401 y 429 se reintentan; un 4xx permanente va a cuarentena")
    func clasificaLasRespuestas() {
        typealias S = SeguimientoDeSalida
        #expect(S.desenlace(Resultado<Int>.ok(1)) == .aceptada)
        #expect(S.desenlace(Resultado<Int>.sinRed) == .reintentar)
        #expect(S.desenlace(Resultado<Int>.respuestaRara(http: 502)) == .reintentar)
        #expect(S.desenlace(Resultado<Int>.rechazado(codigo: "internal", http: 500)) == .reintentar)
        #expect(S.desenlace(Resultado<Int>.rechazado(codigo: "unauthorized", http: 401)) == .reintentar)
        #expect(S.desenlace(Resultado<Int>.rechazado(codigo: "rate_limited", http: 429)) == .reintentar)
        #expect(S.desenlace(Resultado<Int>.rechazado(codigo: "validation_error", http: 422)) == .rechazada)
        #expect(S.desenlace(Resultado<Int>.rechazado(codigo: "conflict", http: 409)) == .rechazada)
    }

    @Test("Una salida recuperada abre la pausa en lo último observado, nunca en el epoch")
    func pausaRecuperada() {
        let conPuntos = SalidaCapturada(id: "s", deporte: .running, inicioMs: 1_000, segundos: 60, metros: 100,
                                        puntos: [PuntoDeRecorrido(lat: 0, lon: 0, atMs: 5_000),
                                                 PuntoDeRecorrido(lat: 0, lon: 0, atMs: 9_000)])
        #expect(SeguimientoDeSalida.inicioDePausaRecuperada(conPuntos, ahoraMs: 20_000) == 9_000)

        let sinPuntos = SalidaCapturada(id: "s", deporte: .running, inicioMs: 1_000, segundos: 0, metros: 0,
                                        puntos: [])
        #expect(SeguimientoDeSalida.inicioDePausaRecuperada(sinPuntos, ahoraMs: 20_000) == 20_000)
    }

    @Test("Un rechazo permanente no frena a las siguientes y la rechazada queda en disco")
    func cuarentenaNoBloquea() async {
        let nombre = "tests-salidas-\(UUID().uuidString).json"
        let almacen = AlmacenDeSalidas(nombre: nombre)
        defer { almacen.borrar() }
        let servicio = ServidorQueRechaza(rechazados: ["mala"])
        let seguimiento = SeguimientoDeSalida(servicio: servicio, almacen: almacen)
        seguimiento.recibirDelReloj(Self.salidaDelReloj("mala"))
        seguimiento.recibirDelReloj(Self.salidaDelReloj("buena"))

        for _ in 0..<50 where seguimiento.pendientes > 0 {
            await seguimiento.subirPendientes()
            await Task.yield()
        }

        #expect(seguimiento.pendientes == 0)
        #expect(await servicio.guardadas.contains("buena"))
        let reabierto = SeguimientoDeSalida(servicio: nil, almacen: almacen)
        #expect(reabierto.pendientes == 0)
        #expect(reabierto.cantidadEnCuarentena == 1)
    }

    private static func salidaDelReloj(_ id: String) -> SalidaDelReloj {
        // 0 m: no dispara la notificación de felicitación.
        SalidaDelReloj(id: id, usuarioId: "", deporte: .running, inicioMs: 1_790_000_000_000,
                       segundos: 600, metros: 0, puntos: [], pulsoMedio: nil, pulsoMaximo: nil)
    }
}

/// Acepta todo menos los ids de `rechazados`, que contesta con un 422.
private actor ServidorQueRechaza: ServicioDeActividades {
    let rechazados: Set<String>
    private(set) var guardadas: [String] = []

    init(rechazados: Set<String>) { self.rechazados = rechazados }

    func guardarActividad(id: String, _ actividad: ActividadEntrada) async -> Resultado<Actividad> {
        if rechazados.contains(id) { return .rechazado(codigo: "validation_error", http: 422) }
        guardadas.append(id)
        return .ok(Actividad(id: id, sport: actividad.sport, startedAtMs: actividad.startedAtMs,
                             durationS: actividad.durationS, distanceM: actividad.distanceM,
                             elevationGainM: nil, avgHrBpm: nil, maxHrBpm: nil, kcal: nil,
                             device: actividad.device, createdAtMs: 0, updatedAtMs: 0))
    }

    func guardarRecorrido(id: String, _ puntos: [PuntoDeRecorrido]) async -> Resultado<RecorridoDeActividad> {
        .ok(RecorridoDeActividad(points: puntos))
    }

    func actividades(limite: Int?, cursor: String?) async -> Resultado<Pagina<Actividad>> { .sinRed }
    func recorrido(id: String) async -> Resultado<RecorridoDeActividad> { .sinRed }
}
