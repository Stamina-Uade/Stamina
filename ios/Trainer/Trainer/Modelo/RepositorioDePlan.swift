import Foundation
import TrainerCore

// =============================================================================
// De dónde salen los números y los textos del plan que muestra la app.
//
// 🛑 REGLA 1 — el plan lo calcula el SERVIDOR.
// AGENTS.md §10 y §9.1 son explícitos: el plan se calcula en el servidor, es
// determinístico y explicable, y el cliente lo muestra. Este protocolo existe
// para que esa frontera sea visible en el código y no una intención.
//
// Hay dos implementaciones, y ninguna calcula nada:
//
// - `RepositorioDelServidor` es la de la app: lo que manda el motor de la 1.1.0,
//   con lo último bueno guardado en disco para abrir sin señal (AGENTS.md §6).
// - `RepositorioProvisional` tiene exactamente los datos de
//   `design/origen/HomeB.dc.html`. **No son datos reales ni calculados acá: son la
//   maqueta del diseño, transcripta**, y existen sólo para las vistas previas,
//   `-datosDeEjemplo` y los dobles de los tests. 🛑 La app de verdad no los muestra
//   NUNCA: sin nada guardado y sin red, el Home dice eso.
//
// El protocolo devuelve ESTADOS, no valores sueltos: primero lo guardado
// (`guardado()`, sin red), después lo que contestó el servidor (`actualizar()`),
// cada parte con su problema si lo hubo. `EstadoHome` los publica.
//
// Lo que este archivo NO hace, a propósito: derivar geles de los minutos,
// mililitros de la zona o carbohidratos de la intensidad. Esas fórmulas están en
// el JavaScript del prototipo y ahí se quedan hasta que las tenga el servidor
// (decisión 0007 §13).
//
// 🛑 REGLA 2 — por qué estos textos NO están en el catálogo de strings.
// AGENTS.md §10 pide que ningún texto **de la interfaz** vaya hardcodeado, y se
// cumple: etiquetas, botones, títulos de sección y mensajes salen de
// `Localizable.xcstrings`. Lo de acá es otra cosa: es **contenido que manda la
// API** —el nombre de una sesión, el detalle de un día del plan, un plato del
// catálogo—. Una respuesta del servidor no se traduce en el cliente; la manda
// traducida o estructurada. Ponerlos en el catálogo daría la impresión falsa de
// que la app los traduce, cuando en producción no los va a ver nunca.
// =============================================================================

protocol RepositorioDePlan {
    /// Lo que se ve al abrir, sin esperar a la red.
    func guardado() -> ContenidoDelHome
    /// Lo que se ve después de preguntarle al servidor: lo nuevo, o lo guardado con
    /// el motivo por el que no se pudo actualizar.
    func actualizar() async -> ContenidoDelHome
    /// Las métricas de una salida en curso.
    func sesionEnCurso() -> SesionEnCurso
    /// Quien sube al servidor las series de este sincronizador y trae las de los otros
    /// dispositivos (decisión 0006). `nil` si no hay servidor: la maqueta.
    @MainActor
    func sincronizacion(de sincronizador: SincronizadorDeSesion) -> SincronizacionConElServidor?
    /// La cola de las comidas guardadas o borradas que esperan para subir. `nil` si no
    /// hay servidor: la maqueta.
    @MainActor
    func colaDeComidas() -> ColaDeComidas?
    @MainActor
    func servicioDeActividades() -> (any ServicioDeActividades)?
    @MainActor
    func servicioDelCatalogo() -> (any ServicioDelPlan)?
    func platosFrecuentes() -> [PlatoSugerido]
    func platosReconocibles() -> [PlatoSugerido]
}

// MARK: -

struct RepositorioProvisional: RepositorioDePlan {

    /// El diseño tiene dos bloques, y cuál se ve depende del objetivo.
    var objetivo: Objetivo = .mediaMaraton

    func guardado() -> ContenidoDelHome {
        let bloque = bloqueDelPlan(paraObjetivo: objetivo)
        let sesion = sesionDelDia()
        return ContenidoDelHome(
            plan: Seccion(valor: PlanDelHome(
                bloque: bloque,
                hoy: DiaDeHoy(titulo: sesion.tipo, detalle: "", sesion: sesion, esFuerza: false),
                semanaDeHoy: bloque.semanas.first(where: \.enCurso)?.numero,
                cargaSemanal: cargaSemanal(), indiceDeHoy: 3)),
            rutina: Seccion(valor: RutinaDelHome(ejercicios: rutinaDeGimnasio(), planificada: true)),
            nutricion: Seccion(valor: NutricionDelHome(
                objetivo: objetivoNutricional(), motivoSinObjetivo: nil, provisional: false,
                comidas: comidasDeHoy(), aguaTomadaMl: 1_800)))
    }

    /// La maqueta no tiene red: lo "nuevo" es lo mismo.
    func actualizar() async -> ContenidoDelHome {
        guardado()
    }

    /// Ni servidor al que subir las series: quedan en el teléfono y en el reloj.
    @MainActor
    func sincronizacion(de sincronizador: SincronizadorDeSesion) -> SincronizacionConElServidor? {
        nil
    }

    /// Ni al que subir las comidas: la maqueta las anota sólo en memoria.
    @MainActor
    func colaDeComidas() -> ColaDeComidas? {
        nil
    }

    @MainActor
    func servicioDeActividades() -> (any ServicioDeActividades)? { nil }
    func servicioDelCatalogo() -> (any ServicioDelPlan)? { nil }

    func sesionDelDia() -> SesionDelDia {
        SesionDelDia(
            tipo: "Fondo largo",
            distanciaMetros: 14_000,
            zona: .z2,
            minutoDelDia: 18 * 60 + 30,
            duracionMinutos: 78,
            bloques: [
                BloqueDeSesion(titulo: "Calentamiento",
                               detalle: "2 km en Zona 1 + estiramiento dinámico"),
                BloqueDeSesion(titulo: "Bloque principal",
                               detalle: "11 km en Z2", insignia: "11 km"),
                BloqueDeSesion(titulo: "Vuelta a la calma",
                               detalle: "1,5 km suaves + estiramientos de 30 s"),
            ],
            // Los números de la maqueta, incluidos los que el prototipo derivaba en
            // JavaScript (antes y después de la salida): acá están escritos, no
            // calculados.
            avituallamiento: AvituallamientoDeSesion(
                geles: 2, mililitrosTotales: 950, mililitrosPorHora: 750, sodioMg: 900,
                carbohidratosPorHoraG: 50, carbohidratosAntesG: 60, carbohidratosDespuesG: 80,
                proteinaDespuesG: 25),
            notaDelClima: "26° y 62 % de humedad: el objetivo sube a 750 ml/h y 50 g de carbos por hora."
        )
    }

    func sesionEnCurso() -> SesionEnCurso {
        SesionEnCurso(segundos: 72 * 60 + 34, ritmoSegPorKm: 5 * 60 + 12, metros: 9_800,
                      bloqueActivo: 1,
                      proximoAviso: "Gel + 300 ml con sales",
                      proximoAvisoEn: "en 4:20",
                      proximoAvisoPorcentaje: 0.78,
                      estadoDelAvituallamiento: "570 de 950 ml · 1 de 2 geles · 50 g carbos/h")
    }

    func bloqueDelPlan(paraObjetivo objetivo: Objetivo) -> BloqueDelPlan {
        objetivo == .c5k ? Self.bloquePrincipiante : Self.bloqueMediaMaraton
    }

    func objetivoNutricional() -> ObjetivoNutricional {
        // 🛑 Estos cuatro números los tiene que producir el servidor, que es el
        // único que hace cumplir los guardarraíles de AGENTS.md §9.2.
        ObjetivoNutricional(kcal: 2410, carbohidratosG: 310, proteinaG: 122, grasaG: 80, aguaMl: 3_200)
    }

    func comidasDeHoy() -> [Comida] {
        [
            Comida(minutoDelDia: 7 * 60 + 10, nombre: "Avena con banana y miel",
                   kcal: 420, carbohidratosG: 72, proteinaG: 12, grasaG: 9),
            Comida(minutoDelDia: 10 * 60 + 40, nombre: "Yogur con granola y frutos secos",
                   kcal: 500, carbohidratosG: 58, proteinaG: 26, grasaG: 18),
            Comida(minutoDelDia: 13 * 60 + 20, nombre: "Pollo, arroz y verduras",
                   kcal: 640, carbohidratosG: 78, proteinaG: 46, grasaG: 14),
            Comida(minutoDelDia: 15 * 60 + 30, nombre: "Snack pre-entreno",
                   kcal: 260, carbohidratosG: 60, proteinaG: 6, grasaG: 4),
        ]
    }

    func platosFrecuentes() -> [PlatoSugerido] {
        [
            PlatoSugerido(nombre: "Avena con banana y miel", kcal: 420, carbohidratosG: 72, proteinaG: 12, grasaG: 9),
            PlatoSugerido(nombre: "Pollo, arroz y verduras", kcal: 640, carbohidratosG: 78, proteinaG: 46, grasaG: 14),
            PlatoSugerido(nombre: "Yogur con granola", kcal: 290, carbohidratosG: 38, proteinaG: 16, grasaG: 8),
            PlatoSugerido(nombre: "Sándwich de atún", kcal: 480, carbohidratosG: 52, proteinaG: 32, grasaG: 15),
        ]
    }

    func platosReconocibles() -> [PlatoSugerido] {
        [
            PlatoSugerido(nombre: "Pollo grillado con arroz y brócoli",
                          kcal: 640, carbohidratosG: 78, proteinaG: 46, grasaG: 14, certezaPorcentaje: 92,
                          ingredientes: [
                            IngredienteSugerido(nombre: "Pechuga de pollo grillada", cantidad: 180, unidad: "g", contable: false),
                            IngredienteSugerido(nombre: "Arroz blanco cocido", cantidad: 200, unidad: "g", contable: false),
                            IngredienteSugerido(nombre: "Brócoli al vapor", cantidad: 90, unidad: "g", contable: false),
                            IngredienteSugerido(nombre: "Aceite de oliva", cantidad: 1, unidad: "cda", contable: false),
                          ]),
            PlatoSugerido(nombre: "Tostadas con palta y huevo",
                          kcal: 520, carbohidratosG: 44, proteinaG: 24, grasaG: 27, certezaPorcentaje: 88,
                          ingredientes: [
                            IngredienteSugerido(nombre: "Pan integral", cantidad: 2, unidad: "rebanadas", contable: true),
                            IngredienteSugerido(nombre: "Palta", cantidad: 0.5, unidad: "unidades", contable: true),
                            IngredienteSugerido(nombre: "Huevo revuelto", cantidad: 2, unidad: "unidades", contable: true),
                          ]),
            PlatoSugerido(nombre: "Milanesa con puré",
                          kcal: 780, carbohidratosG: 68, proteinaG: 42, grasaG: 36, certezaPorcentaje: 85,
                          ingredientes: [
                            IngredienteSugerido(nombre: "Milanesa de carne al horno", cantidad: 160, unidad: "g", contable: false),
                            IngredienteSugerido(nombre: "Puré de papas", cantidad: 250, unidad: "g", contable: false),
                            IngredienteSugerido(nombre: "Ensalada de tomate", cantidad: 80, unidad: "g", contable: false),
                          ]),
        ]
    }

    func rutinaDeGimnasio() -> [EjercicioDeGimnasio] {
        func kg(_ v: Double) -> Int { Int(v * 1000) }
        func series(_ n: Int, reps: Int, peso: Int?, tiempo: Bool = false) -> [SeriePrescrita] {
            (0..<n).map { _ in SeriePrescrita(repeticiones: reps, pesoGramos: peso, porTiempo: tiempo) }
        }
        return [
            EjercicioDeGimnasio(
                id: "press-banca-barra",
                nombre: "Press plano con barra",
                prescripcion: .init(series: series(4, reps: 8, peso: kg(45)), descansoSegundos: 90, unidadDePeso: .kilogramos),
                etiqueta: "General",
                porQue: "Fuerza de empuje: no aporta a la carrera, pero es tu objetivo estético."),
            EjercicioDeGimnasio(
                id: "dominadas",
                nombre: "Dominadas",
                prescripcion: .init(series: series(4, reps: 6, peso: nil), descansoSegundos: 90, unidadDePeso: nil),
                etiqueta: "General",
                porQue: "Tracción y espalda alta; ayuda a mantener el torso firme al correr cansado."),
            EjercicioDeGimnasio(
                id: "remo-barra",
                nombre: "Remo con barra",
                prescripcion: .init(series: series(3, reps: 10, peso: kg(35)), descansoSegundos: 75, unidadDePeso: .kilogramos),
                etiqueta: "General",
                porQue: "Equilibra el trabajo de empuje del press."),
            EjercicioDeGimnasio(
                id: "sentadilla-bulgara",
                nombre: "Sentadilla búlgara",
                prescripcion: .init(series: series(3, reps: 10, peso: kg(12)), descansoSegundos: 75, unidadDePeso: .kilogramos),
                etiqueta: "Para correr",
                porQue: "Fuerza unilateral: menos desequilibrios y menos riesgo de lesión."),
            EjercicioDeGimnasio(
                id: "elevacion-talones",
                nombre: "Elevación de talones",
                prescripcion: .init(series: series(3, reps: 15, peso: kg(20)), descansoSegundos: 60, unidadDePeso: .kilogramos),
                etiqueta: "Para correr",
                porQue: "Protege tendón de Aquiles y sóleo, los que más sufren en fondos largos."),
            EjercicioDeGimnasio(
                id: "plancha-frontal",
                nombre: "Plancha frontal",
                prescripcion: .init(series: series(3, reps: 45, peso: nil, tiempo: true), descansoSegundos: 45, unidadDePeso: nil),
                etiqueta: "Para correr",
                porQue: "Core estable = mejor economía de carrera en los últimos kilómetros."),
        ]
    }

    func cargaSemanal() -> [Int] {
        [6_000, 9_000, 4_000, 12_000, 3_000, 8_000, 14_000]
    }
}

// MARK: - Los dos bloques del diseño

extension RepositorioProvisional {

    /// `RACE` del diseño: media maratón, 12 semanas.
    static let bloqueMediaMaraton = BloqueDelPlan(
        subtitulo: "Bloque de 12 semanas · media maratón",
        evento: "Media maratón de Buenos Aires",
        cuando: "Domingo 11 de octubre · 21,1 km",
        semanasQueFaltan: 6,
        totalDeSemanas: 12,
        fases: [
            FaseDelPlan(titulo: "Base · 1-5", peso: 5, hecha: true, enCurso: false),
            FaseDelPlan(titulo: "Carga · 6-10", peso: 1, hecha: false, enCurso: true),
            FaseDelPlan(titulo: "Afinamiento · 11-12", peso: 6, hecha: false, enCurso: false),
        ],
        semanas: [
            semana(5, hechos: 42_000, previstos: 42_000, desde: 18, mes: "ago", diasHechos: 7, hoy: -1, filas: [
                ("Recuperación · 5 km", "Zona 1 · 32 min"), ("Series · 6×400 m", "6 km totales · 1 gel"),
                ("Descanso", "Fuerza opcional · 30 min"), ("Fondo largo · 12 km", "Zona 2 · 650 ml/h · 1 gel"),
                ("Descanso", "Movilidad y elongación"), ("Ritmo · 8 km", "5:00 /km · 07:00"),
                ("Suave · 6 km", "Zona 1-2 · sin geles")]),
            semana(6, hechos: 48_000, previstos: 62_000, desde: 25, mes: "ago", diasHechos: 3, hoy: 3, filas: [
                ("Recuperación · 6 km", "Zona 1 · 38 min"), ("Series · 8×400 m", "7 km totales · 1 gel"),
                ("Descanso", "Fuerza opcional · 30 min"), ("Fondo largo · 14 km", "Zona 2 · 750 ml/h · 2 geles"),
                ("Descanso", "Movilidad y elongación"), ("Ritmo · 10 km", "4:55 /km · 07:00"),
                ("Suave · 8 km", "Zona 1-2 · sin geles")]),
            semana(7, hechos: 0, previstos: 68_000, desde: 1, mes: "sep", diasHechos: 0, hoy: -1, filas: [
                ("Recuperación · 6 km", "Zona 1 · 38 min"), ("Series · 6×800 m", "10 km totales · 1 gel"),
                ("Descanso", "Fuerza opcional · 30 min"), ("Fondo largo · 16 km", "Zona 2 · 750 ml/h · 2 geles"),
                ("Descanso", "Movilidad y elongación"), ("Ritmo · 12 km", "4:55 /km · 07:00"),
                ("Suave · 8 km", "Zona 1-2 · sin geles")]),
            semana(8, hechos: 0, previstos: 74_000, desde: 8, mes: "sep", diasHechos: 0, hoy: -1, filas: [
                ("Recuperación · 7 km", "Zona 1 · 45 min"), ("Series · 5×1000 m", "10 km totales · 1 gel"),
                ("Descanso", "Fuerza opcional · 30 min"), ("Fondo largo · 18 km", "Zona 2 · 800 ml/h · 3 geles"),
                ("Descanso", "Movilidad y elongación"), ("Ritmo · 12 km", "4:50 /km · 07:00"),
                ("Suave · 9 km", "Zona 1-2 · sin geles")]),
            semana(9, hechos: 0, previstos: 78_000, desde: 15, mes: "sep", diasHechos: 0, hoy: -1, filas: [
                ("Recuperación · 7 km", "Zona 1 · 45 min"), ("Series · 6×1000 m", "11 km totales · 1 gel"),
                ("Descanso", "Fuerza opcional · 30 min"), ("Fondo largo · 20 km", "Zona 2 · 800 ml/h · 3 geles"),
                ("Descanso", "Movilidad y elongación"), ("Ritmo · 14 km", "4:50 /km · 07:00"),
                ("Suave · 9 km", "Zona 1-2 · sin geles")]),
        ])

    /// `BEGINNER` del diseño: primeros 5 km, 4 semanas.
    static let bloquePrincipiante = BloqueDelPlan(
        subtitulo: "Bloque de 4 semanas · primeros 5 km",
        evento: "Tus primeros 5 km",
        cuando: "Domingo 27 de septiembre · 5 km",
        semanasQueFaltan: 3,
        totalDeSemanas: 4,
        fases: [
            FaseDelPlan(titulo: "Caminar y trotar · 1", peso: 1, hecha: true, enCurso: false),
            FaseDelPlan(titulo: "Trote continuo · 2", peso: 1, hecha: false, enCurso: true),
            FaseDelPlan(titulo: "Prueba de 5 km · 3-4", peso: 2, hecha: false, enCurso: false),
        ],
        semanas: [
            semana(1, hechos: 10_000, previstos: 10_000, desde: 1, mes: "sep", diasHechos: 7, hoy: -1, filas: [
                ("Caminar y trotar · 3 km", "4′ trote / 1′ caminata × 4"), ("Descanso", "Movilidad 15 min"),
                ("Caminar y trotar · 3 km", "4′ trote / 1′ caminata × 4"), ("Descanso", "Fuerza 30 min"),
                ("Caminar y trotar · 4 km", "4′ trote / 1′ caminata × 5"), ("Descanso", "Elongación"),
                ("Caminata rápida · 4 km", "Zona 1, sin trotar")]),
            semana(2, hechos: 6_000, previstos: 13_000, desde: 8, mes: "sep", diasHechos: 3, hoy: 3, filas: [
                ("Caminar y trotar · 4 km", "5′ trote / 1′ caminata × 4"), ("Descanso", "Movilidad 15 min"),
                ("Trote continuo · 2 km", "Zona 2, sin caminar"), ("Caminar y trotar · 5 km", "5′ trote / 1′ caminata × 5"),
                ("Descanso", "Fuerza 30 min"), ("Trote continuo · 3 km", "Zona 2 · ritmo cómodo"),
                ("Caminata rápida · 5 km", "Zona 1")]),
            semana(3, hechos: 0, previstos: 16_000, desde: 15, mes: "sep", diasHechos: 0, hoy: -1, filas: [
                ("Trote continuo · 3 km", "Zona 2"), ("Descanso", "Movilidad 15 min"),
                ("Trote continuo · 4 km", "Zona 2"), ("Descanso", "Fuerza 30 min"),
                ("Series suaves · 6×400 m", "Con 1′ de caminata entre series"), ("Descanso", "Elongación"),
                ("Trote continuo · 5 km", "Ritmo de tu carrera")]),
            semana(4, hechos: 0, previstos: 12_000, desde: 22, mes: "sep", diasHechos: 0, hoy: -1, filas: [
                ("Trote continuo · 3 km", "Zona 2, suave"), ("Descanso", "Movilidad 15 min"),
                ("Trote continuo · 2 km", "Zona 2 + 3 sprints"), ("Descanso", "Elongación"),
                ("Activación · 2 km", "Trote muy suave"), ("Descanso", "Dormí 8 h"),
                ("Carrera · 5 km", "Tu objetivo · 750 ml/h · sin geles")]),
        ])

    private static func semana(_ numero: Int, hechos: Int, previstos: Int, desde: Int, mes: String,
                               diasHechos: Int, hoy: Int, filas: [(String, String)]) -> SemanaDelPlan {
        SemanaDelPlan(
            numero: numero, metrosHechos: hechos, metrosPrevistos: previstos,
            dias: filas.enumerated().map { i, fila in
                DiaDelPlan(diaDeLaSemana: i + 1, numeroDeDia: desde + i, mesCorto: mes,
                           titulo: fila.0, detalle: fila.1,
                           hecho: i < diasHechos, esHoy: i == hoy,
                           // Un descanso no se abre, y lo ya hecho tampoco.
                           abrible: !fila.0.hasPrefix("Descanso") && i >= diasHechos)
            },
            enCurso: hoy >= 0)
    }
}
