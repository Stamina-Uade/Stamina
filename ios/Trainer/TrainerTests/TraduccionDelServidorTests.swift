import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

/// Las respuestas de verdad de staging, en `ios/TrainerCore/Tests/TrainerCoreTests/Fixturas/`.
///
/// Se leen de ahí y no se copian: una sola copia, la misma que usa `swift test`. El
/// simulador lee el disco de la Mac, así que alcanza con la ruta de este archivo.
enum FixturasDelServidor {
    static func texto(_ nombre: String, archivo: StaticString = #filePath) throws -> String {
        let url = URL(fileURLWithPath: "\(archivo)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("../TrainerCore/Tests/TrainerCoreTests/Fixturas/\(nombre).json")
            .standardized
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func dato<Valor: Decodable>(_ nombre: String, como tipo: Valor.Type = Valor.self) throws -> Valor {
        try JSONDecoder().decode(SobreDeLaFixtura<Valor>.self, from: Data(texto(nombre).utf8)).data
    }
}

private struct SobreDeLaFixtura<Valor: Decodable>: Decodable {
    let data: Valor
}

@Suite("De lo que manda el servidor a lo que muestran las pantallas")
struct TraduccionDelServidorTests {

    /// 00:00 del 2026-09-10 en Buenos Aires: el primer día del plan de las fixturas.
    static let dia10: Int64 = 1_789_009_200_000
    static let diezDeLaManana = dia10 + 10 * 3_600_000
    static let unDia: Int64 = 86_400_000
    static let buenosAires = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    @Test("El plan es la semana de hoy, su fase y la sesión del día, con los números del servidor")
    func planDeHoy() throws {
        let plan = try FixturasDelServidor.dato("plan", como: Plan.self)

        let home = try #require(TraduccionDelServidor.plan(plan, ahoraMs: Self.diezDeLaManana))

        #expect(home.semanaDeHoy == 1)
        #expect(home.bloque.totalDeSemanas == 11)
        #expect(home.bloque.semanasQueFaltan == 10)
        #expect(home.bloque.evento == Textos.regObjetivoMediaMaraton)
        #expect(home.bloque.fases.map(\.peso) == [5, 2, 2, 1, 1])
        #expect(home.bloque.fases.first?.titulo == "\(Textos.planFaseBase) · 1-5")
        #expect(home.bloque.fases.map(\.enCurso) == [true, false, false, false, false])
        #expect(home.bloque.semanas.map(\.numero) == [1, 2, 3, 4, 5])

        let semana = try #require(home.bloque.semanas.first)
        #expect(semana.enCurso)
        #expect(semana.metrosPrevistos == 28_400)
        #expect(semana.dias.count == 7)
        #expect(semana.dias.first?.esHoy == true)
        #expect(semana.dias.first?.numeroDeDia == 10)
        #expect(semana.dias.first?.diaDeLaSemana == 4, "jueves, contado desde el lunes")
        #expect(semana.dias.first?.titulo == "Running suave (51 min)")
        #expect(semana.dias.filter(\.abrible).count == 1, "sólo hoy abre la salida")

        let hoy = try #require(home.hoy)
        let sesion = try #require(hoy.sesion)
        #expect(sesion.tipo == "Running suave (51 min)", "el título del servidor, sin traducirlo de nuevo")
        #expect(sesion.distanciaMetros == 7_100)
        #expect(sesion.zona == .z2)
        #expect(sesion.minutoDelDia == 1_140)
        #expect(sesion.duracionMinutos == 51)
        #expect(sesion.motivos.count == 2)
        #expect(sesion.bloques.first?.detalle == hoy.detalle)
        let avituallamiento = try #require(sesion.avituallamiento)
        #expect(avituallamiento.geles == 1)
        #expect(avituallamiento.mililitrosTotales == 680)
        #expect(avituallamiento.mililitrosPorHora == 800)
        #expect(avituallamiento.carbohidratosAntesG == 36)
        #expect(avituallamiento.carbohidratosDespuesG == 72)
        #expect(avituallamiento.proteinaDespuesG == 22)

        #expect(home.cargaSemanal.count == 7)
        #expect(home.cargaSemanal.first == 7_100)
        #expect(home.indiceDeHoy == 0)
    }

    @Test("Un descanso y un día de fuerza no son una salida")
    func descansoYFuerza() throws {
        let plan = try FixturasDelServidor.dato("plan", como: Plan.self)

        let descanso = try #require(TraduccionDelServidor.plan(plan, ahoraMs: Self.diezDeLaManana + Self.unDia)?.hoy)
        let fuerza = try #require(TraduccionDelServidor.plan(plan, ahoraMs: Self.diezDeLaManana + 2 * Self.unDia)?.hoy)

        #expect(descanso.titulo == "Descanso")
        #expect(descanso.sesion == nil)
        #expect(!descanso.esFuerza)
        #expect(fuerza.esFuerza)
        #expect(fuerza.sesion == nil, "la fuerza se hace en gimnasio, no en entreno")
    }

    @Test("Fuera del bloque no hay día de hoy, y el plan se muestra igual")
    func fueraDelBloque() throws {
        let plan = try FixturasDelServidor.dato("plan", como: Plan.self)

        let antes = try #require(TraduccionDelServidor.plan(plan, ahoraMs: Self.dia10 - 3 * Self.unDia))
        let despues = try #require(TraduccionDelServidor.plan(plan, ahoraMs: Self.dia10 + 90 * Self.unDia))

        #expect(antes.hoy == nil)
        #expect(antes.semanaDeHoy == nil)
        #expect(antes.bloque.semanasQueFaltan == 11)
        #expect(antes.bloque.semanas.first?.numero == 1)
        #expect(despues.hoy == nil)
        #expect(despues.bloque.semanasQueFaltan == 0)
        #expect(despues.bloque.semanas.last?.numero == 11)
        // 🪤 Con un key path, `#expect` descompone la llamada a `allSatisfy`, que es
        // `rethrows`, y pide `try`: con una clausura no.
        #expect(despues.bloque.fases.allSatisfy { $0.hecha })
    }

    @Test("La rutina trae la prescripción serie por serie y la columna PREVIA")
    func rutina() throws {
        let rutina = try FixturasDelServidor.dato("rutina-con-series-previas", como: RutinaDelDia.self)

        let home = try #require(TraduccionDelServidor.rutina(rutina))

        #expect(!home.planificada, "el 10 de septiembre el plan no pone gimnasio")
        #expect(home.ejercicios.count == 6)
        let estocada = try #require(home.ejercicios.first)
        #expect(estocada.id == "estocada-deficit", "el id del catálogo: es parte de la clave de cada serie")
        #expect(estocada.nombre == "Zancada con déficit")
        #expect(estocada.prescripcion.series.map(\.repeticiones) == [10, 10, 10])
        #expect(estocada.prescripcion.series.allSatisfy { $0.pesoGramos == nil }, "el motor no prescribe carga")
        #expect(estocada.prescripcion.descansoSegundos == 75)
        #expect(estocada.prescripcion.unidadDePeso == .kilogramos)
        #expect(estocada.seriesPrevias == [
            SeriePrevia(numero: 1, repeticiones: 10, pesoGramos: 12_000, salteada: false),
            SeriePrevia(numero: 2, repeticiones: 8, pesoGramos: nil, salteada: false),
        ])
        let plancha = try #require(home.ejercicios.first { $0.id == "plancha-pies-elevados" })
        #expect(plancha.prescripcion.series.allSatisfy { $0.porTiempo })
        #expect(plancha.prescripcion.unidadDePeso == nil)
        #expect(plancha.seriesPrevias.isEmpty)
    }

    @Test("La nutrición trae los objetivos y lo comido, a la hora local del perfil")
    func nutricion() throws {
        let dia = try FixturasDelServidor.dato("nutricion-del-dia", como: DiaNutricional.self)

        let home = try #require(TraduccionDelServidor.nutricion(dia, zona: Self.buenosAires))

        let objetivo = try #require(home.objetivo)
        #expect(objetivo.kcal == 2_750)
        #expect(objetivo.carbohidratosG == 360)
        #expect(objetivo.proteinaG == 115)
        #expect(objetivo.grasaG == 94)
        #expect(objetivo.aguaMl == 3_132)
        #expect(home.provisional)
        #expect(home.motivoSinObjetivo == nil)
        #expect(home.comidas.map(\.nombre) == ["Avena con banana"])
        #expect(home.comidas.first?.id == "063349d2-0a4b-45c5-9cf6-c54d692ea7ad", "el id del servidor, para borrarla")
        #expect(home.comidas.first?.minutoDelDia == 6 * 60 + 45)
        #expect(home.aguaTomadaMl == nil, "la API no registra el agua tomada: no se inventa")
    }

    @Test("Sin objetivos viene el motivo, y ningún número")
    func sinObjetivos() throws {
        let dia = try FixturasDelServidor.dato("nutricion-sin-objetivos", como: DiaNutricional.self)
        let mujer = try FixturasDelServidor.dato("nutricion-con-objetivos-mujer", como: DiaNutricional.self)

        let sin = try #require(TraduccionDelServidor.nutricion(dia, zona: Self.buenosAires))
        let con = try #require(TraduccionDelServidor.nutricion(mujer, zona: Self.buenosAires))

        #expect(sin.objetivo == nil)
        #expect(sin.motivoSinObjetivo == .faltaEmbarazoOLactancia)
        #expect(!sin.provisional)
        #expect(sin.comidas.count == 1, "lo comido se muestra igual")
        #expect(con.objetivo?.kcal == 2_526)
        #expect(con.motivoSinObjetivo == nil)
    }
}
