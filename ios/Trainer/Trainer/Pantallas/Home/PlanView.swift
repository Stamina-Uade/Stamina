import SwiftUI
import TrainerCore

/// `plan` — "menos cosas a la vista" (decisión de Iván del 2026-10-23):
///
///   la barra fija «Tu plan» con el fueguito (`PantallaDePestana`)
///   el selector de objetivo (21K | 10K), si hay más de uno
///   la cabecera de la semana: ‹ Semana 2 de 20 ›, "Etapa Base ⓘ" y los km
///   los 7 días en filas iguales; tocar uno abre su hoja
///
/// Se fueron el héroe de "20 semanas para tu carrera", la tarjeta fija de las etapas
/// (ahora es una hoja que abre "Etapa Base"), los chips S1…S20 (ahora flechas, y
/// deslizar sigue andando) y el botón del mapa (era la pestaña Historial).
///
/// Las piezas viven al lado, con prefijo `Plan`: la cabecera en `PlanSemana.swift`,
/// cada día y su hoja en `PlanFilaDeDia.swift`, las etapas en
/// `PlanTarjetaDeFases.swift` y el selector de metas para cuando el plan terminó en
/// `PlanSelectorDeMetasView.swift`.
struct PlanView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var planesDeObjetivos: [PlanDeObjetivo] = []
    @State private var objetivoElegido = "principal"
    @State private var faltanObjetivos = false
    /// El día cuya hoja está abierta.
    @State private var diaElegido: DiaElegido?
    @State private var mostrarEtapas = false

    private var bloqueVisible: BloqueDelPlan? {
        guard objetivoElegido != "principal" else { return estado.bloque }
        guard let remoto = planesDeObjetivos.first(where: { $0.goalId == objetivoElegido }) else { return nil }
        return TraduccionDelServidor.plan(remoto.plan, ahoraMs: RenovadorDeSesion.ahoraEnMs())?.bloque
    }

    private var semanaVisible: SemanaDelPlan? {
        guard let bloque = bloqueVisible else { return nil }
        return bloque.semanas.first { $0.numero == estado.semanaElegida }
            ?? bloque.semanas.first { $0.enCurso }
            ?? bloque.semanas.first
    }

    private var planVencido: Bool { estado.planVencido }
    private var esElPrincipal: Bool { objetivoElegido == "principal" }

    private var animacion: Animation? {
        reducirMovimiento ? nil : .spring(response: TokensMovimiento.media, dampingFraction: 0.86)
    }

    var body: some View {
        PantallaDePestana(Textos.planTitle, alRefrescar: { await refrescar() }) {
            FueguitoDeLaBarra()
        } contenido: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                if !planVencido && planesDeObjetivos.count > 1 {
                    selectorDeObjetivo
                }

                if planVencido || faltanObjetivos {
                    SelectorInteractivoDeMetasView()
                } else if let bloque = bloqueVisible, let semana = semanaVisible {
                    if esElPrincipal { AvisoDeLoGuardado(seccion: estado.contenido.plan) }
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
        .task(id: estado.semana?.numero) {
            await estado.cargarPasosDeLaSemana()
        }
        .task { await cargarPlanes() }
        .sheet(item: $diaElegido) { elegido in
            HojaDelDiaDelPlan(dia: elegido.dia, alMarcar: { await marcarComoHecho(elegido.dia) })
        }
        .sheet(isPresented: $mostrarEtapas) {
            HojaDeEtapas(fases: bloqueVisible?.fases ?? [],
                         etapaDeHoy: bloqueVisible?.semanas.first(where: { $0.enCurso })?.etapa)
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
                            estado.semanaElegida = semanaDeHoy(de: item) ?? 1
                        }
                    } label: {
                        Text(TraduccionDelServidor.nombre(de: item.plan.goal))
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

    /// La semana de hoy en otro objetivo, para no abrirlo en la semana 1.
    private func semanaDeHoy(de item: PlanDeObjetivo) -> Int? {
        TraduccionDelServidor.plan(item.plan, ahoraMs: RenovadorDeSesion.ahoraEnMs())?.semanaDeHoy
    }

    private func cargarPlanes() async {
        guard let servicio = estado.repositorio.servicioDelCatalogo() else { return }
        if case .ok(let planes) = await servicio.planes() {
            planesDeObjetivos = planes
            faltanObjetivos = planes.isEmpty
            if !planes.contains(where: { $0.goalId == objetivoElegido }) { objetivoElegido = "principal" }
        }
    }

    private func refrescar() async {
        await estado.actualizar()
        await cargarPlanes()
    }

    /// Lo marca en el servidor y trae los planes de nuevo (el principal y los demás).
    private func marcarComoHecho(_ dia: DiaDelPlan) async -> Bool {
        guard await estado.marcarComoHecho(dia) else { return false }
        await cargarPlanes()
        return true
    }

    // MARK: - Semana y días

    private func semanaYDias(bloque: BloqueDelPlan, semana: SemanaDelPlan) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            PlanCabeceraDeSemana(
                semana: semana,
                totalDeSemanas: bloque.totalDeSemanas,
                unidades: estado.sistemaDeUnidades,
                hayAnterior: indice(de: semana, en: bloque).map { $0 > 0 } ?? false,
                haySiguiente: indice(de: semana, en: bloque).map { $0 < bloque.semanas.count - 1 } ?? false,
                alMoverse: { paso in moverSemana(paso, desde: semana, en: bloque) },
                abrirEtapas: {
                    Haptico.toque()
                    mostrarEtapas = true
                })

            VStack(spacing: TokensEspaciado.e8) {
                ForEach(Array(semana.dias.enumerated()), id: \.offset) { _, dia in
                    FilaDeDiaDelPlan(dia: dia) {
                        Haptico.toque()
                        diaElegido = DiaElegido(dia: dia)
                    }
                }
            }
            .contentShape(Rectangle())
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

    private func indice(de semana: SemanaDelPlan, en bloque: BloqueDelPlan) -> Int? {
        bloque.semanas.firstIndex { $0.numero == semana.numero }
    }

    private func moverSemana(_ paso: Int, desde semana: SemanaDelPlan, en bloque: BloqueDelPlan) {
        guard let actual = indice(de: semana, en: bloque) else { return }
        let destino = actual + paso
        guard bloque.semanas.indices.contains(destino) else { return }
        Haptico.seleccion()
        withAnimation(animacion) { estado.semanaElegida = bloque.semanas[destino].numero }
    }
}

/// El día de la hoja abierta. Los `id` de `DiaDelPlan` son `UUID()` que cambian en
/// cada traducción, así que la hoja se identifica por la fecha.
private struct DiaElegido: Identifiable {
    let dia: DiaDelPlan
    var id: String { "\(dia.fechaMs ?? 0)-\(dia.diaDeLaSemana)" }
}
