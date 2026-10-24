import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

@Suite("Fondos de las tarjetas héroe: una foto por día, sin repetir")
struct FondosDeTarjetaTests {

    /// Calendario fijo con horario de verano (marzo y noviembre), para que el
    /// test no dependa de dónde corre.
    private let calendario: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return cal
    }()

    private func dia(_ anio: Int, _ mes: Int, _ dia: Int, hora: Int = 12) -> Date {
        calendario.date(from: DateComponents(year: anio, month: mes, day: dia, hour: hora)) ?? Date()
    }

    private func dias(desde inicio: Date, cantidad: Int) -> [Date] {
        (0..<cantidad).compactMap { calendario.date(byAdding: .day, value: $0, to: inicio) }
    }

    private func fotos(_ disciplina: Disciplina, _ contexto: String, _ fechas: [Date],
                       disponibles: Set<String>, soloRunning: Bool = false) -> [String?] {
        fechas.map {
            FondosDeTarjeta.imagen(para: disciplina, fecha: $0, contexto: contexto,
                                   disponibles: disponibles, soloRunning: soloRunning,
                                   calendario: calendario)
        }
    }

    @Test("Con el pool completo no se repite ninguna foto mientras quedan candidatas (cruzando el horario de verano)")
    func noRepiteEn20Dias() {
        // Del 1/2 al ~30/4: incluye el cambio de hora de marzo.
        let fechas = dias(desde: dia(2026, 2, 1), cantidad: 90)
        for disciplina in Disciplina.allCases {
            let pool = Set(FondosDeTarjeta.pool(de: disciplina))
            let n = FondosDeTarjeta.candidatas(para: disciplina, disponibles: pool).count
            for contexto in ["inicio", "plan", "otro-contexto"] {
                let elegidas = fotos(disciplina, contexto, fechas, disponibles: pool)
                #expect(elegidas.allSatisfy { $0 != nil })
                for desde in 0...(elegidas.count - n) {
                    let ventana = elegidas[desde..<(desde + n)].compactMap { $0 }
                    #expect(Set(ventana).count == n,
                            "\(disciplina) / \(contexto): se repitió una foto en la ventana que arranca el día \(desde)")
                }
            }
        }
    }

    @Test("La foto cambia a medianoche y es la misma todo el día")
    func mismaFotoTodoElDia() {
        let pool = Set(FondosDeTarjeta.pool(de: .running))
        let manana = FondosDeTarjeta.imagen(para: .running, fecha: dia(2026, 10, 19, hora: 0), contexto: "inicio",
                                            disponibles: pool, calendario: calendario)
        let noche = FondosDeTarjeta.imagen(para: .running, fecha: dia(2026, 10, 19, hora: 23), contexto: "inicio",
                                           disponibles: pool, calendario: calendario)
        let siguiente = FondosDeTarjeta.imagen(para: .running, fecha: dia(2026, 10, 20, hora: 0), contexto: "inicio",
                                               disponibles: pool, calendario: calendario)
        #expect(manana == noche)
        #expect(manana != siguiente)
    }

    @Test("Inicio y Plan no muestran la misma foto el mismo día")
    func contextosDistintos() {
        let fechas = dias(desde: dia(2026, 1, 1), cantidad: 60)
        let completos = Set(FondosDeTarjeta.pool(de: .running))
        let soloRespaldo: Set<String> = ["BienvenidaAmanecer", "BienvenidaMontana"]
        for disponibles in [completos, soloRespaldo] {
            let inicio = fotos(.running, "inicio", fechas, disponibles: disponibles)
            let plan = fotos(.running, "plan", fechas, disponibles: disponibles)
            for (a, b) in zip(inicio, plan) {
                #expect(a != nil && a != b)
            }
        }
    }

    @Test("Con menos de 20 fotos rota entre las que existen, sin repetir dentro de esa cantidad")
    func poolIncompleto() {
        let existentes: Set<String> = ["FondoRunning02", "FondoRunning06", "FondoRunning13",
                                       "FondoRunning15", "FondoRunning19"]
        let fechas = dias(desde: dia(2026, 3, 1), cantidad: 30)
        let elegidas = fotos(.running, "inicio", fechas, disponibles: existentes)
        #expect(elegidas.allSatisfy { foto in
            guard let foto else { return false }
            return existentes.contains(foto)
        })
        for desde in 0...(elegidas.count - existentes.count) {
            let ventana = elegidas[desde..<(desde + existentes.count)].compactMap { $0 }
            #expect(Set(ventana).count == existentes.count)
        }
    }

    @Test("Running sin fotos propias usa las de respaldo y nunca la de ciclismo")
    func respaldoDeRunning() {
        let fechas = dias(desde: dia(2026, 5, 1), cantidad: 40)
        // Aunque la foto de bici exista en el catálogo, running no la usa.
        let disponibles: Set<String> = ["BienvenidaAmanecer", "BienvenidaMontana", "BienvenidaRuta"]
        let elegidas = fotos(.running, "inicio", fechas, disponibles: disponibles)
        #expect(elegidas.allSatisfy { $0 == "BienvenidaAmanecer" || $0 == "BienvenidaMontana" })
        #expect(Set(elegidas.compactMap { $0 }).count == 2)

        let soloBici = fotos(.running, "plan", fechas, disponibles: ["BienvenidaRuta"])
        #expect(soloBici.allSatisfy { $0 == nil })
    }

    @Test("Sin ninguna foto devuelve nil (la tarjeta usa el degradado)")
    func sinFotos() {
        let foto = FondosDeTarjeta.imagen(para: .natacion, fecha: dia(2026, 7, 1), contexto: "plan",
                                          disponibles: [], soloRunning: false, calendario: calendario)
        #expect(foto == nil)
    }

    @Test("Con soloRunning todo es running; sin él, cada deporte va a su pool")
    func disciplinaSegunMVP() {
        #expect(FondosDeTarjeta.disciplina(de: .ciclismo, soloRunning: true) == .running)
        #expect(FondosDeTarjeta.disciplina(de: .natacion, soloRunning: true) == .running)
        #expect(FondosDeTarjeta.disciplina(de: .ciclismo, soloRunning: false) == .ciclismo)
        #expect(FondosDeTarjeta.disciplina(de: .natacion, soloRunning: false) == .natacion)
        #expect(FondosDeTarjeta.disciplina(de: .trekking, soloRunning: false) == .running)
        #expect(FondosDeTarjeta.disciplina(de: .triatlon, soloRunning: false) == .running)

        let todo = Set(Disciplina.allCases.flatMap(FondosDeTarjeta.pool(de:)))
        let foto = FondosDeTarjeta.imagen(para: .ciclismo, fecha: dia(2026, 8, 1), contexto: "inicio",
                                          disponibles: todo, soloRunning: true, calendario: calendario)
        #expect(foto?.hasPrefix("FondoRunning") == true)
    }

    @Test("La persona se ve entera: sólo se eligen fotos con encuadre, y las demás nunca")
    func soloFotosQueEntran() {
        let pool = Set(FondosDeTarjeta.pool(de: .running))
        let candidatas = FondosDeTarjeta.candidatas(para: .running, disponibles: pool)
        #expect(Set(candidatas) == Set(FondosDeTarjeta.encuadres.keys))
        #expect(FondosDeTarjeta.noEntranEnLaTarjeta.isDisjoint(with: candidatas))
        // Las 20 están revisadas: cada una tiene encuadre o está afuera.
        #expect(pool == Set(FondosDeTarjeta.encuadres.keys).union(FondosDeTarjeta.noEntranEnLaTarjeta))
        #expect(FondosDeTarjeta.encuadre(de: "FondoRunning15").y > 0.5)
        #expect(FondosDeTarjeta.encuadre(de: nil) == .center)
    }

    @Test("Los nombres del pool coinciden con los del catálogo (FondoRunning01…20)")
    func nombresDelPool() {
        let pool = FondosDeTarjeta.pool(de: .natacion)
        #expect(pool.count == 20)
        #expect(pool.first == "FondoNatacion01")
        #expect(pool.last == "FondoNatacion20")
    }
}
