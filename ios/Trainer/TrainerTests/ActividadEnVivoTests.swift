import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

/// La actividad en vivo de la salida: cuándo se pide, se actualiza y se cierra, y
/// cómo se escriben sus números. Lo de ActivityKit no se prueba acá (necesita el
/// sistema); lo que decide, sí.
@Suite("Actividad en vivo: cuándo hablar con el sistema y qué mostrar")
struct ActividadEnVivoTests {

    typealias P = PlanificadorDeActividadEnVivo
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func lectura(segundos: Int, metros: Int, pausada: Bool = false, ritmo: Int? = 300,
                 unidades: SistemaDeUnidades = .metrico, deporte: DeporteDeSesion = .running,
                 en instante: Date) -> LecturaDeSalidaEnVivo {
        LecturaDeSalidaEnVivo(deporte: deporte, pausada: pausada, segundos: segundos, metros: metros,
                              ritmoSegPorKm: ritmo, unidades: unidades, medidoEn: instante)
    }

    func esActualizar(_ accion: P.Accion) -> Bool {
        if case .actualizar = accion { return true }
        return false
    }

    @Test("Sin salida no se pide nada; con salida se pide una sola vez")
    func pideAlEmpezar() {
        var p = P()
        #expect(p.decidir(nil, ahora: t0) == .ninguna)
        let accion = p.decidir(lectura(segundos: 0, metros: 0, ritmo: nil, en: t0), ahora: t0)
        guard case .empezar(let deporte, let estado) = accion else {
            Issue.record("Esperaba .empezar y llegó \(accion)")
            return
        }
        #expect(deporte == .running)
        #expect(estado.inicioDelCronometro == t0)
        #expect(estado.pausada == false)
        #expect(p.enCurso)
        // Un segundo después, nada que contar: la duración avanza sola.
        let t1 = t0.addingTimeInterval(1)
        #expect(p.decidir(lectura(segundos: 1, metros: 0, ritmo: nil, en: t1), ahora: t1) == .ninguna)
    }

    @Test("Ritmo y distancia no se mandan más seguido que el intervalo")
    func respetaElIntervalo() {
        var p = P()
        _ = p.decidir(lectura(segundos: 0, metros: 0, en: t0), ahora: t0)
        var actualizaciones: [Date] = []
        // Una muestra por segundo durante dos minutos, a 3 m/s y ritmo cambiante.
        for s in 1...120 {
            let ahora = t0.addingTimeInterval(TimeInterval(s))
            let accion = p.decidir(lectura(segundos: s, metros: s * 3, ritmo: 300 + s % 7, en: ahora), ahora: ahora)
            if esActualizar(accion) { actualizaciones.append(ahora) }
        }
        #expect(!actualizaciones.isEmpty)
        var anterior = t0
        for fecha in actualizaciones {
            #expect(fecha.timeIntervalSince(anterior) >= P.intervaloMinimo)
            anterior = fecha
        }
        // 120 s / 10 s: no más de doce.
        #expect(actualizaciones.count <= Int(120 / P.intervaloMinimo))
    }

    @Test("Pausar y reanudar se mandan al momento; en pausa no sale nada")
    func pausaYReanudacion() {
        var p = P()
        _ = p.decidir(lectura(segundos: 0, metros: 0, en: t0), ahora: t0)

        let tPausa = t0.addingTimeInterval(62)
        let pausa = p.decidir(lectura(segundos: 62, metros: 180, pausada: true, en: tPausa), ahora: tPausa)
        guard case .actualizar(let enPausa) = pausa else {
            Issue.record("Pausar tenía que actualizar al momento, llegó \(pausa)")
            return
        }
        #expect(enPausa.pausada)
        #expect(enPausa.segundos == 62)

        // Un minuto en pausa: los números no cambian y no se manda nada.
        for s in 1...60 {
            let ahora = tPausa.addingTimeInterval(TimeInterval(s))
            #expect(p.decidir(lectura(segundos: 62, metros: 180, pausada: true, en: ahora), ahora: ahora) == .ninguna)
        }

        // Reanuda 2 min después de pausar: el cronómetro arranca descontando la pausa.
        let tSigue = tPausa.addingTimeInterval(120)
        let sigue = p.decidir(lectura(segundos: 62, metros: 180, en: tSigue), ahora: tSigue)
        guard case .actualizar(let corriendo) = sigue else {
            Issue.record("Reanudar tenía que actualizar al momento, llegó \(sigue)")
            return
        }
        #expect(!corriendo.pausada)
        #expect(corriendo.inicioDelCronometro == tSigue.addingTimeInterval(-62))
    }

    @Test("Pasar un kilómetro o cambiar de unidades no espera el intervalo")
    func cambiosQueNoEsperan() {
        var p = P()
        let t1 = t0.addingTimeInterval(290)
        _ = p.decidir(lectura(segundos: 290, metros: 995, en: t1), ahora: t1)
        let t2 = t1.addingTimeInterval(2)
        #expect(esActualizar(p.decidir(lectura(segundos: 292, metros: 1_002, en: t2), ahora: t2)))

        let t3 = t2.addingTimeInterval(1)
        let enMillas = p.decidir(lectura(segundos: 293, metros: 1_005, unidades: .imperial, en: t3), ahora: t3)
        guard case .actualizar(let estado) = enMillas else {
            Issue.record("Cambiar de unidades tenía que actualizar, llegó \(enMillas)")
            return
        }
        #expect(estado.enMillas)
    }

    @Test("Un segundo de diferencia no mueve el cronómetro; uno que se corrió, sí")
    func cronometroEstable() {
        var p = P()
        _ = p.decidir(lectura(segundos: 100, metros: 300, en: t0), ahora: t0)
        let inicio = p.ultimoEnviado?.inicioDelCronometro

        // 10 s después, con un segundo menos (el entero se redondeó para abajo).
        let t1 = t0.addingTimeInterval(10)
        let accion = p.decidir(lectura(segundos: 109, metros: 340, en: t1), ahora: t1)
        guard case .actualizar(let estado) = accion else {
            Issue.record("Esperaba una actualización de ritmo y distancia, llegó \(accion)")
            return
        }
        #expect(estado.inicioDelCronometro == inicio)

        // Un salto de 5 s (el reloj se puso al día): se manda aunque no pasó el intervalo.
        let t2 = t1.addingTimeInterval(1)
        let salto = p.decidir(lectura(segundos: 105, metros: 340, en: t2), ahora: t2)
        guard case .actualizar(let corregido) = salto else {
            Issue.record("El cronómetro corrido tenía que mandarse, llegó \(salto)")
            return
        }
        #expect(corregido.inicioDelCronometro == t2.addingTimeInterval(-105))
    }

    @Test("La salida del reloj cuenta desde que la midió el reloj, no desde que llegó")
    func medidoEnElReloj() {
        let medido = t0.addingTimeInterval(-4)
        let estado = P.estado(de: lectura(segundos: 600, metros: 2_000, en: medido), anterior: nil)
        #expect(estado.inicioDelCronometro == medido.addingTimeInterval(-600))
    }

    @Test("Al terminar o descartar se cierra con lo último que se vio, una sola vez")
    func terminaUnaVez() {
        var p = P()
        _ = p.decidir(lectura(segundos: 0, metros: 0, en: t0), ahora: t0)
        let t1 = t0.addingTimeInterval(30)
        _ = p.decidir(lectura(segundos: 30, metros: 90, en: t1), ahora: t1)
        let ultimo = p.ultimoEnviado

        let accion = p.decidir(nil, ahora: t1.addingTimeInterval(1))
        #expect(accion == .terminar(ultimo))
        #expect(!p.enCurso)
        #expect(p.decidir(nil, ahora: t1.addingTimeInterval(2)) == .ninguna)
    }

    @Test("Una actividad que quedó de antes se retoma: no se pide otra")
    func retomaLaQueQuedo() {
        var p = P()
        let quedo = EstadoDeSalidaEnVivo(inicioDelCronometro: t0, segundos: 300, pausada: false,
                                         metros: 900, ritmoSegPorKm: 333, enMillas: false)
        p.adoptar(quedo, deporte: .running, ahora: t0)
        // La app volvió con la salida recuperada en pausa: se actualiza, no se pide.
        let t1 = t0.addingTimeInterval(400)
        let accion = p.decidir(lectura(segundos: 300, metros: 900, pausada: true, ritmo: 333, en: t1), ahora: t1)
        #expect(esActualizar(accion))
    }

    @Test("Otro deporte cierra la actividad: lo fijo no se cambia")
    func otroDeporte() {
        var p = P()
        _ = p.decidir(lectura(segundos: 0, metros: 0, en: t0), ahora: t0)
        let t1 = t0.addingTimeInterval(1)
        let accion = p.decidir(lectura(segundos: 0, metros: 0, deporte: .ciclismo, en: t1), ahora: t1)
        guard case .terminar = accion else {
            Issue.record("Esperaba .terminar, llegó \(accion)")
            return
        }
        guard case .empezar(.ciclismo, _) = p.decidir(lectura(segundos: 0, metros: 0, deporte: .ciclismo, en: t1),
                                                      ahora: t1) else {
            Issue.record("Después de cerrar tenía que pedir la nueva")
            return
        }
    }

    // MARK: - Los números

    func estado(metros: Int, ritmo: Int?, enMillas: Bool, segundos: Int = 0) -> EstadoDeSalidaEnVivo {
        EstadoDeSalidaEnVivo(inicioDelCronometro: t0, segundos: segundos, pausada: true,
                             metros: metros, ritmoSegPorKm: ritmo, enMillas: enMillas)
    }

    func dosDecimales(_ valor: Double) -> String {
        valor.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
    }

    @Test("En kilómetros: /km, km y la distancia con dos decimales")
    func kilometros() {
        let e = estado(metros: 5_230, ritmo: 330, enMillas: false)
        #expect(PresentacionDeSalidaEnVivo.unidadDeRitmo(e.unidades) == "/km")
        #expect(PresentacionDeSalidaEnVivo.unidadDeDistancia(e.unidades) == "km")
        #expect(PresentacionDeSalidaEnVivo.ritmo(e) == "5:30")
        #expect(PresentacionDeSalidaEnVivo.distancia(e) == dosDecimales(5.23))
        // Un entero no pierde los decimales: el ancho no salta.
        #expect(PresentacionDeSalidaEnVivo.distancia(estado(metros: 5_000, ritmo: nil, enMillas: false))
                == dosDecimales(5))
    }

    @Test("En millas: /mi, mi, y el ritmo y la distancia convertidos")
    func millas() {
        let e = estado(metros: 3_219, ritmo: 300, enMillas: true)
        #expect(PresentacionDeSalidaEnVivo.unidadDeRitmo(e.unidades) == "/mi")
        #expect(PresentacionDeSalidaEnVivo.unidadDeDistancia(e.unidades) == "mi")
        // 5:00 /km = 8:03 /mi (300 × 1,609344 = 482,8 s).
        #expect(PresentacionDeSalidaEnVivo.ritmo(e) == "8:03")
        #expect(PresentacionDeSalidaEnVivo.distancia(e) == dosDecimales(3_219 / 1_609.344))
    }

    @Test("Sin ritmo, un guión; la duración fija, como el cronómetro de la app")
    func sinDatoYDuracionFija() {
        #expect(PresentacionDeSalidaEnVivo.ritmo(estado(metros: 50, ritmo: nil, enMillas: false)) == "—")
        #expect(PresentacionDeSalidaEnVivo.duracionFija(estado(metros: 0, ritmo: nil, enMillas: false,
                                                               segundos: 1_720)) == "28:40")
        #expect(PresentacionDeSalidaEnVivo.duracionFija(estado(metros: 0, ritmo: nil, enMillas: false,
                                                               segundos: 4_354)) == "1:12:34")
    }

    @Test("El enlace de la actividad es el de la salida, y ningún otro")
    func enlace() {
        #expect(EnlaceDeSalidaEnVivo.url.absoluteString == "stamina://salida")
        #expect(EnlaceDeSalidaEnVivo.esDeLaSalida(EnlaceDeSalidaEnVivo.url))
        #expect(!EnlaceDeSalidaEnVivo.esDeLaSalida(URL(string: "stamina://perfil")!))
        #expect(!EnlaceDeSalidaEnVivo.esDeLaSalida(URL(string: "https://salida")!))
    }
}
