import SwiftUI
import TrainerCore

/// `plan` — el bloque de semanas, con sus fases, el selector de semana y los
/// siete días.
///
/// Las piezas viven al lado, con prefijo `Plan`: las fases en
/// `PlanTarjetaDeFases.swift`, la semana en `PlanSemana.swift`, cada día en
/// `PlanFilaDeDia.swift` y el selector de metas para cuando el plan terminó en
/// `PlanSelectorDeMetasView.swift`.
struct PlanView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var mostrarHistorial = false
    @State private var planesDeObjetivos: [PlanDeObjetivo] = []
    @State private var objetivoElegido = "principal"
    @State private var faltanObjetivos = false
    /// El día abierto en la línea de tiempo (`"semana-día"`). Uno a la vez: es un
    /// acordeón. Vive acá y no en la fila porque los días de un objetivo que no es
    /// el principal se traducen de nuevo en cada `body` y sus `id` cambian.
    @State private var diaAbierto: String?
    @State private var yaAbrioHoy = false

    private var bloqueVisible: BloqueDelPlan? {
        guard objetivoElegido != "principal" else { return estado.bloque }
        guard let remoto = planesDeObjetivos.first(where: { $0.goalId == objetivoElegido }) else { return nil }
        return TraduccionDelServidor.plan(remoto.plan, ahoraMs: RenovadorDeSesion.ahoraEnMs())?.bloque
    }

    private var semanaVisible: SemanaDelPlan? {
        guard let bloque = bloqueVisible else { return nil }
        return bloque.semanas.first { $0.numero == estado.semanaElegida } ?? bloque.semanas.first
    }

    private var planVencido: Bool { estado.planVencido }
    private var esElPrincipal: Bool { objetivoElegido == "principal" }

    private var animacion: Animation? {
        reducirMovimiento ? nil : .spring(response: TokensMovimiento.media, dampingFraction: 0.86)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                encabezado

                if !planVencido && planesDeObjetivos.count > 1 {
                    selectorDeObjetivo
                }

                if planVencido || faltanObjetivos {
                    SelectorInteractivoDeMetasView()
                } else if let bloque = bloqueVisible, let semana = semanaVisible {
                    if esElPrincipal { AvisoDeLoGuardado(seccion: estado.contenido.plan) }
                    tarjetaDelEvento(bloque)
                    if !bloque.fases.isEmpty {
                        PlanTarjetaDeFases(fases: bloque.fases)
                            .id(objetivoElegido)
                    }
                    semanaYDias(bloque: bloque, semana: semana)
                } else {
                    SinDatosView(problema: estado.contenido.plan.problema, actualizando: estado.actualizando) {
                        Task { await estado.actualizar() }
                    }
                }
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: estado.semana?.numero) {
            await estado.cargarPasosDeLaSemana()
        }
        .task { await cargarPlanes() }
        .onAppear { abrirHoySiHaceFalta() }
        .onChange(of: estado.semanaElegida) { _ in
            withAnimation(animacion) { diaAbierto = nil }
            abrirHoySiHaceFalta()
        }
        .sheet(isPresented: $mostrarHistorial) {
            HistorialDeActividadesView(servicio: estado.repositorio.servicioDeActividades())
                .environmentObject(estado)
        }
    }

    // MARK: - Encabezado

    /// "Tu plan" grande, el subtítulo del bloque arriba; el historial a la derecha.
    private var encabezado: some View {
        EncabezadoDePestana(
            Textos.planTitle,
            sobretitulo: (!planVencido ? bloqueVisible?.subtitulo : nil)
        ) {
            BotonCircular("map", etiqueta: Textos.historyTitle) {
                Haptico.toque()
                mostrarHistorial = true
            }
            .accessibilityHint(Textos.historyOpensPastWorkouts)
        }
    }

    // MARK: - Selector de objetivo

    /// El control segmentado del mockup ("15K | 21K | 42K"). Con muchas metas se
    /// desplaza de costado en vez de apretar los nombres.
    private var selectorDeObjetivo: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TokensEspaciado.e2) {
                ForEach(planesDeObjetivos, id: \.goalId) { item in
                    let elegido = objetivoElegido == item.goalId
                    Button {
                        guard !elegido else { return }
                        Haptico.seleccion()
                        withAnimation(animacion) {
                            objetivoElegido = item.goalId
                            estado.semanaElegida = 1
                            diaAbierto = nil
                        }
                    } label: {
                        Text(nombreDelObjetivo(item.plan.goal))
                            .estilo(.tituloCard, color: elegido ? Paleta.textoPrimario : Paleta.textoTerciario)
                            .lineLimit(1)
                            .padding(.horizontal, TokensEspaciado.e16)
                            .frame(minHeight: TokensEspaciado.e40)
                            .background(Capsule().fill(elegido ? Paleta.superficieAlterna : Color.clear))
                            .overlay(Capsule().strokeBorder(elegido ? Paleta.bordeSuperficie : Color.clear,
                                                            lineWidth: TokensEspaciado.e1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(EstiloPresionado())
                    .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
                    .accessibilityHint(Textos.planGoalHint)
                }
            }
            .padding(TokensEspaciado.e4)
            .background(Capsule().fill(Paleta.superficie))
            .overlay(Capsule().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
        }
    }

    private func cargarPlanes() async {
        guard let servicio = estado.repositorio.servicioDelCatalogo() else { return }
        if case .ok(let planes) = await servicio.planes() {
            planesDeObjetivos = planes
            faltanObjetivos = planes.isEmpty
            if !planes.contains(where: { $0.goalId == objetivoElegido }) { objetivoElegido = "principal" }
        }
    }

    private func nombreDelObjetivo(_ objetivo: Objetivo) -> String {
        switch objetivo {
        case .c5k: return Textos.signupGoalC5k
        case .c10k: return Textos.signupGoalC10k
        case .mediaMaraton: return Textos.signupGoalHalfMarathon
        case .maraton: return Textos.signupGoalMarathon
        case .trailMontana: return Textos.signupGoalMountainTrail
        case .triatlonOlimpico: return Textos.signupGoalOlympicTriathlon
        case .volverSinLesiones: return Textos.signupGoalInjuryFree
        }
    }

    // MARK: - Tarjeta héroe del evento

    /// Foto + cuenta regresiva ("6 semanas") + la etapa en la que estás. La
    /// barra de etapas, ahora tocable, va en su propia tarjeta abajo.
    private func tarjetaDelEvento(_ bloque: BloqueDelPlan) -> some View {
        TarjetaHeroe(imagen: FondosDeTarjeta.imagen(para: .running, contexto: "plan")) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                if !bloque.cuando.isEmpty {
                    PildoraDeEstado(bloque.cuando, simbolo: "calendar")
                }

                VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                    if let dias = bloque.diasParaLaCarrera() {
                        MetricaHeroe("\(dias)",
                                     unidad: dias == 1
                                        ? Textos.commonDay
                                        : Textos.commonDays,
                                     etiquetaAccesible: Textos.commonToGo)
                        Text(Textos.planUntilRace)
                            .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    } else if bloque.semanasQueFaltan > 0 {
                        MetricaHeroe("\(bloque.semanasQueFaltan)",
                                     unidad: Textos.commonWeeks,
                                     etiquetaAccesible: Textos.planWeeksLeft(bloque.semanasQueFaltan))
                    }
                    Text(bloque.evento)
                        .estilo(bloque.semanasQueFaltan > 0 ? EstiloTipografico.tituloCard : EstiloTipografico.tituloSeccion,
                                color: bloque.semanasQueFaltan > 0 ? Paleta.textoSecundario : Paleta.textoPrimario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actual = bloque.fases.first(where: { $0.enCurso }) {
                    PildoraDeEstado(
                        Textos.planCurrentPhase(actual.titulo),
                        simbolo: "location.fill", tono: .acento)
                }
            }
        }
    }

    // MARK: - Semana y días

    private func semanaYDias(bloque: BloqueDelPlan, semana: SemanaDelPlan) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            PlanSelectorDeSemana(semanas: bloque.semanas, elegida: semana.numero) { numero in
                elegirSemana(numero)
            }

            PlanProgresoDeLaSemana(
                semana: semana,
                unidades: estado.sistemaDeUnidades,
                hayAnterior: indice(de: semana, en: bloque).map { $0 > 0 } ?? false,
                haySiguiente: indice(de: semana, en: bloque).map { $0 < bloque.semanas.count - 1 } ?? false,
                alMoverse: { paso in moverSemana(paso, desde: semana, en: bloque) })

            lineaDeTiempo(semana)
                // Deslizar de costado sobre los días cambia de semana. Es simultáneo
                // para no robarle el gesto vertical al scroll.
                .simultaneousGesture(
                    DragGesture(minimumDistance: TokensEspaciado.e26)
                        .onEnded { arrastre in
                            let dx = arrastre.translation.width
                            let dy = arrastre.translation.height
                            guard abs(dx) > TokensEspaciado.e56, abs(dx) > abs(dy) * 2 else { return }
                            moverSemana(dx < 0 ? 1 : -1, desde: semana, en: bloque)
                        })
        }
    }

    private func lineaDeTiempo(_ semana: SemanaDelPlan) -> some View {
        // Sin hueco entre filas para que la línea no se corte.
        VStack(spacing: 0) {
            ForEach(Array(semana.dias.enumerated()), id: \.offset) { indice, dia in
                let clave = claveDelDia(dia, en: semana)
                FilaDeDiaDelPlan(dia: dia,
                                 datos: datos(de: dia),
                                 abierto: diaAbierto == clave,
                                 esPrimero: indice == 0,
                                 esUltimo: indice == semana.dias.count - 1,
                                 alTocar: { alternar(clave) },
                                 abrirHistorial: {
                                     Haptico.toque()
                                     mostrarHistorial = true
                                 })
            }
        }
    }

    private func indice(de semana: SemanaDelPlan, en bloque: BloqueDelPlan) -> Int? {
        bloque.semanas.firstIndex { $0.numero == semana.numero }
    }

    private func elegirSemana(_ numero: Int) {
        guard numero != estado.semanaElegida else { return }
        Haptico.seleccion()
        withAnimation(animacion) { estado.semanaElegida = numero }
    }

    private func moverSemana(_ paso: Int, desde semana: SemanaDelPlan, en bloque: BloqueDelPlan) {
        guard let actual = indice(de: semana, en: bloque) else { return }
        let destino = actual + paso
        guard bloque.semanas.indices.contains(destino) else { return }
        elegirSemana(bloque.semanas[destino].numero)
    }

    private func claveDelDia(_ dia: DiaDelPlan, en semana: SemanaDelPlan) -> String {
        "\(semana.numero)-\(dia.diaDeLaSemana)"
    }

    private func alternar(_ clave: String) {
        Haptico.toque()
        withAnimation(animacion) { diaAbierto = diaAbierto == clave ? nil : clave }
    }

    /// La primera vez, el día de hoy aparece abierto: es lo que más se busca.
    /// Después lo que abra o cierre la persona manda.
    private func abrirHoySiHaceFalta() {
        guard !yaAbrioHoy, let semana = semanaVisible, let hoy = semana.dias.first(where: { $0.esHoy }) else { return }
        yaAbrioHoy = true
        diaAbierto = claveDelDia(hoy, en: semana)
    }

    /// Lo que se sabe de un día además de su fila: el cronograma del plan
    /// principal y, si es hoy, la sesión entera. De otro objetivo no hay más
    /// que el título y el detalle.
    private func datos(de dia: DiaDelPlan) -> PlanDatosDelDia {
        guard esElPrincipal else { return PlanDatosDelDia(dia: dia) }
        let planificado: DiaPlanificadoCompartido? = dia.fecha.flatMap { fecha in
            estado.plan?.cronograma.first { $0.fechaIso == PlanDatosDelDia.iso(fecha) }
        }
        let deHoy = dia.esHoy ? estado.hoy : nil
        return PlanDatosDelDia(dia: dia, planificado: planificado,
                               sesion: deHoy?.sesion,
                               esFuerzaHoy: deHoy?.esFuerza ?? false)
    }
}
