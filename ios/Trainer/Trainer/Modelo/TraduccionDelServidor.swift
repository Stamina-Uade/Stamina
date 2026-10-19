import Foundation
import TrainerCore

// =============================================================================
// De lo que manda el servidor a lo que muestran las pantallas.
//
// 🛑 TRADUCE, NO CALCULA. Cada número sale de la respuesta tal cual —metros,
// minutos, geles, kcal, series—, y los textos del plan (`title`, `detail`,
// `reasons`, el nombre y el "por qué" de cada ejercicio) llegan ya en el idioma de
// la persona por `Accept-Language`: no se vuelven a traducir. Lo único que pone el
// cliente son las unidades para mostrar, las fechas en su calendario y los nombres
// de los CÓDIGOS estables —la fase, el objetivo—, que son texto de la interfaz
// (AGENTS.md §10).
//
// Y "hoy" se cuenta en la zona del plan, que es la del perfil: con la del
// teléfono, alguien de viaje vería la sesión de otro día.
// =============================================================================

enum TraduccionDelServidor {

    /// Las semanas que muestra el selector del plan: la anterior, la de hoy y las
    /// tres que vienen, como el diseño. Once chips no entran en el ancho con el
    /// mínimo táctil.
    static let semanasALaVista = 5

    // MARK: - Plan

    static func plan(_ plan: Plan, ahoraMs: Int64) -> PlanDelHome? {
        let zona = FuenteDelServidor.zona(de: plan)
        let hoyMs = FuenteDelServidor.inicioDelDia(ahoraMs, zona: zona)
        let dias = plan.days.sorted { $0.dateMs < $1.dateMs }
        let diaDeHoy = dias.first { $0.dateMs == hoyMs }
        let semanaDeHoy = diaDeHoy.map { Int($0.weekNumber) }
        let yaTermino = dias.last.map { hoyMs > $0.dateMs } ?? false
        let total = Int(plan.totalWeeks)

        // La ventana de semanas: alrededor de hoy, o las últimas si el bloque terminó.
        let referencia = semanaDeHoy ?? (yaTermino ? total : 1)
        let primera = max(1, min(referencia - 1, total - semanasALaVista + 1))
        let semanas = plan.weeks
            .sorted { $0.number < $1.number }
            .filter { Int($0.number) >= primera && Int($0.number) < primera + semanasALaVista }

        // MVP sólo running: nunca se deduce triatlón (un día de bici es cross-training).
        let esTriatlon = MVP.permite(.triatlon) &&
                         (plan.days.contains { $0.sport == .natacion } ||
                          (plan.days.contains { $0.sport == .ciclismo } && plan.days.contains { $0.sport == .running }))

        let bloque = BloqueDelPlan(
            subtitulo: subtitulo(plan, semanaDeHoy: semanaDeHoy, enTriatlon: esTriatlon),
            evento: nombre(de: plan.goal, enTriatlon: esTriatlon),
            cuando: plan.eventDateMs.map { fechaLarga($0, zona: zona) } ?? Textos.planSinFecha,
            semanasQueFaltan: semanaDeHoy.map { max(0, total - $0) } ?? (yaTermino ? 0 : total),
            totalDeSemanas: total,
            fases: plan.phases
                .sorted { $0.firstWeek < $1.firstWeek }
                .map { fase($0, semanaDeHoy: semanaDeHoy, yaTermino: yaTermino) },
            semanas: semanas.map { semana in
                SemanaDelPlan(
                    numero: Int(semana.number),
                    metrosHechos: Int(semana.doneDistanceM),
                    metrosPrevistos: Int(semana.plannedDistanceM),
                    dias: dias.filter { $0.weekNumber == semana.number }
                        .map { dia($0, hoyMs: hoyMs, zona: zona, enTriatlon: esTriatlon) },
                    enCurso: Int(semana.number) == semanaDeHoy)
            },
            fechaDelEventoMs: plan.eventDateMs,
            distanciaDelEventoMetros: esTriatlon ? nil : distanciaEnMetros(de: plan.goal))

        let diasDeEstaSemana = semanaDeHoy.map { numero in dias.filter { Int($0.weekNumber) == numero } } ?? []
        let racha = plan.streak.map { s in
            RachaHome(dias: Int(s.current), activaHoy: s.activeToday, entrenadoHoy: s.trainedToday, tocaHoy: s.scheduledToday)
        } ?? RachaHome()

        let dfIso: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = zona
            return df
        }()
        let cronogramaCompartido: [DiaPlanificadoCompartido] = dias.map { d in
            let fecha = Date(timeIntervalSince1970: TimeInterval(d.dateMs) / 1000)
            let iso = dfIso.string(from: fecha)
            let esFuerza = d.sport == .fuerza || d.type == .fuerza
            let esDescanso = d.type == .descanso
            let esEvento = d.type == .carrera || d.title.localizedCaseInsensitiveContains("evento") || d.title.localizedCaseInsensitiveContains("marat")
            let tipoLimpio = esEvento ? Formato.limpiarTituloEvento(d.title, enTriatlon: esTriatlon) : d.title
            return DiaPlanificadoCompartido(
                fechaIso: iso,
                diaDeLaSemana: Int(d.weekday),
                tipo: tipoLimpio,
                distanciaMetros: d.distanceM.map { Int($0) },
                duracionMinutos: Int(d.durationMin),
                minutoDelDia: d.scheduledMinuteOfDay.map { Int($0) },
                geles: d.fueling.map { Int($0.gels) },
                aguaMl: d.fueling.map { Int($0.fluidTotalMl) },
                sales: d.fueling.map { $0.sodiumTotalMg > 0 ? max(1, Int(($0.sodiumTotalMg + 499) / 500)) : 0 },
                esDescanso: esDescanso,
                esFuerza: esFuerza
            )
        }

        return PlanDelHome(
            bloque: bloque,
            hoy: diaDeHoy.map { hoy($0, enTriatlon: esTriatlon) },
            semanaDeHoy: semanaDeHoy,
            cargaSemanal: diasDeEstaSemana.map { Int($0.distanceM ?? 0) },
            indiceDeHoy: diasDeEstaSemana.firstIndex { $0.dateMs == hoyMs },
            racha: racha,
            cronograma: cronogramaCompartido)
    }

    static func limpiarTituloEvento(_ titulo: String, enTriatlon: Bool = false) -> String {
        Formato.limpiarTituloEvento(titulo, enTriatlon: enTriatlon)
    }

    private static func hoy(_ dia: DiaPlanificado, enTriatlon: Bool = false) -> DiaDeHoy {
        let esFuerza = dia.sport == .fuerza || dia.type == .fuerza
        // Un descanso no se sale a correr, y la fuerza se hace en `gimnasio`.
        let haySalida = !esFuerza && dia.type != .descanso
        let esEvento = dia.type == .carrera || dia.title.localizedCaseInsensitiveContains("evento") || dia.title.localizedCaseInsensitiveContains("marat")
        let tituloLimpio = esEvento ? Formato.limpiarTituloEvento(dia.title, enTriatlon: enTriatlon) : dia.title
        return DiaDeHoy(titulo: tituloLimpio, detalle: dia.detail,
                        sesion: haySalida ? sesion(dia, enTriatlon: enTriatlon) : nil, esFuerza: esFuerza)
    }

    private static func sesion(_ dia: DiaPlanificado, enTriatlon: Bool = false) -> SesionDelDia {
        let esEvento = dia.type == .carrera || dia.title.localizedCaseInsensitiveContains("evento") || dia.title.localizedCaseInsensitiveContains("marat")
        let tituloLimpio = esEvento ? Formato.limpiarTituloEvento(dia.title, enTriatlon: enTriatlon) : dia.title
        return SesionDelDia(
            tipo: tituloLimpio,
            distanciaMetros: dia.distanceM.map { Int($0) },
            zona: dia.zone.flatMap { ZonaDeIntensidad(rawValue: $0.rawValue) },
            minutoDelDia: dia.scheduledMinuteOfDay.map { Int($0) },
            duracionMinutos: Int(dia.durationMin),
            // El servidor manda la estructura como un párrafo, no en bloques: va
            // entero, y no se parte adivinando dónde termina el calentamiento.
            bloques: [BloqueDeSesion(titulo: Textos.entrenoEstructura, detalle: dia.detail)],
            avituallamiento: dia.fueling.map(avituallamiento),
            motivos: dia.reasons.map(\.text))
    }

    private static func avituallamiento(_ a: Avituallamiento) -> AvituallamientoDeSesion {
        AvituallamientoDeSesion(
            geles: Int(a.gels),
            mililitrosTotales: Int(a.fluidTotalMl),
            mililitrosPorHora: Int(a.fluidMlPerHour),
            sodioMg: Int(a.sodiumTotalMg),
            carbohidratosPorHoraG: Int(a.carbsGPerHour),
            carbohidratosAntesG: Int(a.preCarbsG),
            carbohidratosDespuesG: Int(a.postCarbsG),
            proteinaDespuesG: Int(a.postProteinG))
    }

    private static func fase(_ tramo: TramoDeFase, semanaDeHoy: Int?, yaTermino: Bool) -> FaseDelPlan {
        let desde = Int(tramo.firstWeek)
        let hasta = max(desde, Int(tramo.lastWeek))
        let semanas = desde == hasta ? "\(desde)" : "\(desde)-\(hasta)"
        return FaseDelPlan(
            titulo: "\(nombre(de: tramo.phase)) · \(semanas)",
            peso: hasta - desde + 1,
            hecha: yaTermino || (semanaDeHoy.map { $0 > hasta } ?? false),
            enCurso: semanaDeHoy.map { (desde...hasta).contains($0) } ?? false)
    }

    private static func dia(_ dia: DiaPlanificado, hoyMs: Int64, zona: TimeZone, enTriatlon: Bool = false) -> DiaDelPlan {
        let fecha = Date(timeIntervalSince1970: TimeInterval(dia.dateMs) / 1000)
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zona
        var mes = Date.FormatStyle.dateTime.month(.abbreviated)
        mes.timeZone = zona
        mes.locale = idioma
        let esHoy = dia.dateMs == hoyMs
        let esEvento = dia.type == .carrera || dia.title.localizedCaseInsensitiveContains("evento") || dia.title.localizedCaseInsensitiveContains("marat")
        let tituloLimpio = esEvento ? Formato.limpiarTituloEvento(dia.title, enTriatlon: enTriatlon) : dia.title
        return DiaDelPlan(
            diaDeLaSemana: Int(dia.weekday),
            numeroDeDia: calendario.component(.day, from: fecha),
            mesCorto: fecha.formatted(mes),
            titulo: tituloLimpio,
            detalle: resumen(dia),
            hecho: dia.done,
            esHoy: esHoy,
            // Tocar un día abre `entreno`, que muestra la salida de HOY: abrir otro
            // día mostraría una sesión que no es la suya.
            abrible: esHoy && !dia.done && dia.type != .descanso && dia.sport != .fuerza,
            fecha: fecha)
    }

    /// El renglón de abajo del título: lo estructurado, corto. El `detail` del
    /// servidor es un párrafo, y se lee entero en `entreno`.
    private static func resumen(_ dia: DiaPlanificado) -> String {
        var partes: [String] = []
        if let metros = dia.distanceM { partes.append(Formato.distancia(Int(metros), unidades: .metrico)) }
        if let zona = dia.zone { partes.append(zona.rawValue.uppercased()) }
        return partes.joined(separator: " · ")
    }

    private static func subtitulo(_ plan: Plan, semanaDeHoy: Int?, enTriatlon: Bool = false) -> String {
        let nombreObj = nombre(de: plan.goal, enTriatlon: enTriatlon)
        guard let semanaDeHoy else { return nombreObj }
        return Textos.planSubtitulo(nombreObj, semanaDeHoy, Int(plan.totalWeeks))
    }

    // MARK: - Rutina

    static func rutina(_ rutina: RutinaDelDia) -> RutinaDelHome? {
        RutinaDelHome(ejercicios: rutina.exercises.map(ejercicio), planificada: rutina.planned)
    }

    private static func ejercicio(_ ejercicio: EjercicioDeRutina) -> EjercicioDeGimnasio {
        let porTiempo = ejercicio.unit == "tiempo"
        return EjercicioDeGimnasio(
            // 🛑 El id del catálogo, tal cual: es parte de la clave determinística de
            // cada serie (decisión 0006).
            id: ejercicio.exerciseId,
            nombre: ejercicio.name,
            prescripcion: PrescripcionDeEjercicio(
                series: ejercicio.sets.sorted { $0.number < $1.number }.map {
                    SeriePrescrita(repeticiones: Int($0.reps), pesoGramos: $0.weightG.map { Int($0) },
                                   porTiempo: porTiempo)
                },
                descansoSegundos: Int(ejercicio.restS),
                // El motor no prescribe carga: la pone la persona. Se le pide peso salvo
                // en lo que va por tiempo o no usa equipo.
                unidadDePeso: porTiempo || ejercicio.equipment == "ninguno" ? nil : .kilogramos),
            etiqueta: ejercicio.label,
            porQue: ejercicio.reason,
            seriesPrevias: ejercicio.previousSets.sorted { $0.number < $1.number }.map {
                SeriePrevia(numero: Int($0.number), repeticiones: Int($0.reps),
                            pesoGramos: $0.weightG.map { Int($0) }, salteada: $0.skipped)
            })
    }

    // MARK: - Nutrición

    static func nutricion(_ dia: DiaNutricional, zona: TimeZone) -> NutricionDelHome? {
        NutricionDelHome(
            objetivo: dia.targets.map {
                ObjetivoNutricional(kcal: Int($0.kcal), carbohidratosG: Int($0.carbsG), proteinaG: Int($0.proteinG),
                                    grasaG: Int($0.fatG), aguaMl: Int($0.waterMl))
            },
            // 🛑 AGENTS.md §9.2: sin objetivos, el motivo. Nunca un número de reemplazo.
            motivoSinObjetivo: dia.targets == nil ? dia.unavailableReason : nil,
            provisional: dia.targets?.provisional ?? false,
            comidas: dia.meals
                .map { comida($0, zona: zona) }
                .sorted { $0.minutoDelDia < $1.minutoDelDia },
            diaMs: dia.dateMs,
            zona: zona)
    }

    /// Lo comido que mandó el servidor más lo que espera en la cola para subir: lo
    /// guardado aparece —o se corrige— y lo borrado desaparece. Sin esto, una comida
    /// anotada sin señal desaparecería en la próxima actualización.
    static func comidas(_ delServidor: [Comida], conPendientes pendientes: [OperacionDeComida],
                        diaMs: Int64, zona: TimeZone) -> [Comida] {
        var porId = Dictionary(delServidor.map { ($0.id, $0) }, uniquingKeysWith: { primera, _ in primera })
        var orden = delServidor.map(\.id)
        for operacion in pendientes {
            switch operacion {
            case .borrar(let id):
                porId[id] = nil
            case .guardar(let id, let entrada):
                // Espera en la cola, pero es de otro día.
                guard FuenteDelServidor.inicioDelDia(entrada.eatenAtMs, zona: zona) == diaMs else { continue }
                if porId[id] == nil { orden.append(id) }
                porId[id] = Comida(id: id, minutoDelDia: minutoDelDia(entrada.eatenAtMs, zona: zona),
                                   nombre: entrada.name, kcal: Int(entrada.kcal),
                                   carbohidratosG: Int(entrada.carbsG), proteinaG: Int(entrada.proteinG),
                                   grasaG: Int(entrada.fatG))
            }
        }
        return orden.compactMap { porId[$0] }.sorted { $0.minutoDelDia < $1.minutoDelDia }
    }

    static func comida(_ comida: ComidaRegistrada, zona: TimeZone) -> Comida {
        Comida(id: comida.id, minutoDelDia: minutoDelDia(comida.eatenAtMs, zona: zona), nombre: comida.name,
               kcal: Int(comida.kcal), carbohidratosG: Int(comida.carbsG), proteinaG: Int(comida.proteinG),
               grasaG: Int(comida.fatG))
    }

    static func minutoDelDia(_ instanteMs: Int64, zona: TimeZone) -> Int {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zona
        let partes = calendario.dateComponents([.hour, .minute],
                                               from: Date(timeIntervalSince1970: TimeInterval(instanteMs) / 1000))
        return (partes.hour ?? 0) * 60 + (partes.minute ?? 0)
    }

    // MARK: - Nombres de los códigos

    /// En el idioma en que la app muestra sus textos.
    private static var idioma: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
    }

    private static func fechaLarga(_ instanteMs: Int64, zona: TimeZone) -> String {
        var estilo = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        estilo.timeZone = zona
        estilo.locale = idioma
        return Date(timeIntervalSince1970: TimeInterval(instanteMs) / 1000).formatted(estilo)
    }

    static func nombre(de objetivo: Objetivo, enTriatlon: Bool = false) -> String {
        switch objetivo {
        case .c5k: return Textos.regObjetivoC5k
        case .c10k: return Textos.regObjetivoC10k
        case .mediaMaraton: return enTriatlon ? "Triatlón media distancia" : Textos.regObjetivoMediaMaraton
        case .maraton: return enTriatlon ? "Triatlón larga distancia" : Textos.regObjetivoMaraton
        case .trailMontana: return Textos.regObjetivoTrailMontana
        case .triatlonOlimpico: return Textos.regObjetivoTriatlonOlimpico
        case .volverSinLesiones: return Textos.regObjetivoVolverSinLesiones
        }
    }

    /// La distancia de la carrera, para la píldora "Dom 8 nov · 21 km" del inicio.
    /// Sin distancia fija (trail, volver sin lesiones) no se inventa una.
    static func distanciaEnMetros(de objetivo: Objetivo) -> Int? {
        switch objetivo {
        case .c5k: return 5_000
        case .c10k: return 10_000
        case .mediaMaraton: return 21_097
        case .maraton: return 42_195
        case .trailMontana, .triatlonOlimpico, .volverSinLesiones: return nil
        }
    }

    static func nombre(de fase: Fase) -> String {
        switch fase {
        case .base: return Textos.planFaseBase
        case .construccion: return Textos.planFaseConstruccion
        case .pico: return Textos.planFasePico
        case .afinamiento: return Textos.planFaseAfinamiento
        case .carrera: return Textos.planFaseCarrera
        }
    }
}
