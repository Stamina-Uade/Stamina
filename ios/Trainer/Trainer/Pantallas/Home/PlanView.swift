import SwiftUI
import TrainerCore

/// `plan` — el bloque de semanas, con sus fases, el selector de semana y los
/// siete días.
///
/// El selector de metas para cuando el plan terminó vive en
/// `PlanSelectorDeMetasView.swift`.
struct PlanView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var mostrarHistorial = false
    @State private var planesDeObjetivos: [PlanDeObjetivo] = []
    @State private var objetivoElegido = "principal"
    @State private var faltanObjetivos = false

    private var bloqueVisible: BloqueDelPlan? {
        guard objetivoElegido != "principal" else { return estado.bloque }
        guard let remoto = planesDeObjetivos.first(where: { $0.goalId == objetivoElegido }) else { return nil }
        return TraduccionDelServidor.plan(remoto.plan, ahoraMs: RenovadorDeSesion.ahoraEnMs())?.bloque
    }

    private var semanaVisible: SemanaDelPlan? {
        guard let bloque = bloqueVisible else { return nil }
        return bloque.semanas.first { $0.numero == estado.semanaElegida } ?? bloque.semanas.first
    }

    private var planVencido: Bool {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let hoyIso = df.string(from: Date())
        guard let cronograma = estado.contenido.plan.valor?.cronograma, !cronograma.isEmpty else {
            return true
        }
        let diasFuturosOHoy = cronograma.filter { $0.fechaIso >= hoyIso }
        return diasFuturosOHoy.isEmpty
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
                    if objetivoElegido == "principal" { AvisoDeLoGuardado(seccion: estado.contenido.plan) }
                    tarjetaDelEvento(bloque)
                    selectorDeSemana(bloque)

                    VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                        encabezadoDeLaSemana(semana)
                        // Línea de tiempo: sin hueco entre filas para que la línea no se corte.
                        VStack(spacing: 0) {
                            ForEach(Array(semana.dias.enumerated()), id: \.element.id) { indice, dia in
                                FilaDeDiaDelPlan(dia: dia,
                                                 esPrimero: indice == 0,
                                                 esUltimo: indice == semana.dias.count - 1)
                            }
                        }
                    }
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
        .sheet(isPresented: $mostrarHistorial) {
            HistorialDeActividadesView(servicio: estado.repositorio.servicioDeActividades())
        }
    }

    // MARK: - Encabezado

    /// "Tu plan" grande, el subtítulo del bloque arriba y el historial a la derecha.
    private var encabezado: some View {
        EncabezadoDePestana(
            String(localized: "Tu plan", comment: "Título de la pestaña del plan"),
            sobretitulo: (!planVencido ? bloqueVisible?.subtitulo : nil)
        ) {
            BotonCircular("map", etiqueta: Textos.historialTitulo) { mostrarHistorial = true }
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
                        objetivoElegido = item.goalId
                        estado.semanaElegida = 1
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
        case .c5k: return Textos.regObjetivoC5k
        case .c10k: return Textos.regObjetivoC10k
        case .mediaMaraton: return Textos.regObjetivoMediaMaraton
        case .maraton: return Textos.regObjetivoMaraton
        case .trailMontana: return Textos.regObjetivoTrailMontana
        case .triatlonOlimpico: return Textos.regObjetivoTriatlonOlimpico
        case .volverSinLesiones: return Textos.regObjetivoVolverSinLesiones
        }
    }

    // MARK: - Tarjeta héroe del evento

    /// Foto + cuenta regresiva ("6 semanas") + las fases del bloque.
    private func tarjetaDelEvento(_ bloque: BloqueDelPlan) -> some View {
        TarjetaHeroe(imagen: "BienvenidaMontana") {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                if !bloque.cuando.isEmpty {
                    PildoraDeEstado(bloque.cuando, simbolo: "calendar")
                }

                VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                    if bloque.semanasQueFaltan > 0 {
                        MetricaHeroe("\(bloque.semanasQueFaltan)",
                                     unidad: String(localized: "semanas", comment: "Unidad de la cuenta regresiva de la carrera"),
                                     etiquetaAccesible: Textos.planFaltanSemanas(bloque.semanasQueFaltan))
                    }
                    Text(bloque.evento)
                        .estilo(bloque.semanasQueFaltan > 0 ? EstiloTipografico.tituloCard : EstiloTipografico.tituloSeccion,
                                color: bloque.semanasQueFaltan > 0 ? Paleta.textoSecundario : Paleta.textoPrimario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                barraDeFases(bloque)
            }
        }
    }

    /// Las fases, proporcionales a su cantidad de semanas, con el nombre abajo.
    private func barraDeFases(_ bloque: BloqueDelPlan) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            // `layoutPriority` no reparte ancho en proporción —sólo decide quién
            // se achica primero—, así que el ancho se calcula.
            GeometryReader { geo in
                let huecos = TokensEspaciado.e4 * CGFloat(max(0, bloque.fases.count - 1))
                let util = max(0, geo.size.width - huecos)
                let total = CGFloat(bloque.fases.reduce(0) { $0 + $1.peso })
                HStack(spacing: TokensEspaciado.e4) {
                    ForEach(bloque.fases) { fase in
                        Capsule()
                            .fill(colorDeFase(fase))
                            .shadow(color: fase.enCurso ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e4)
                            .frame(width: total > 0 ? util * CGFloat(fase.peso) / total : 0)
                    }
                }
            }
            .frame(height: TokensEspaciado.e4)
            .accessibilityHidden(true)

            HStack(alignment: .top, spacing: TokensEspaciado.e8) {
                ForEach(bloque.fases) { fase in
                    Text(fase.titulo)
                        .estilo(.etiquetaSeccion.enMinusculas,
                                color: fase.enCurso ? Paleta.acento : Paleta.textoSecundario)
                        .frame(maxWidth: .infinity, alignment: alineacion(de: fase, en: bloque))
                }
            }
        }
    }

    private func colorDeFase(_ fase: FaseDelPlan) -> Color {
        if fase.hecha { return Paleta.acento }
        if fase.enCurso { return Paleta.acentoApagado }
        return Paleta.superficieControl
    }

    private func alineacion(de fase: FaseDelPlan, en bloque: BloqueDelPlan) -> Alignment {
        guard let primera = bloque.fases.first, let ultima = bloque.fases.last else { return .center }
        if fase.id == primera.id { return .leading }
        if fase.id == ultima.id { return .trailing }
        return .center
    }

    // MARK: - Selector de semana

    /// Las semanas como segmentos del mismo control que el de objetivos.
    private func selectorDeSemana(_ bloque: BloqueDelPlan) -> some View {
        HStack(spacing: TokensEspaciado.e2) {
            ForEach(bloque.semanas) { semana in
                let elegida = semana.numero == estado.semanaElegida
                Button { estado.semanaElegida = semana.numero } label: {
                    Text(Textos.planSemanaChip(semana.numero))
                        .estilo(.tituloCard, color: elegida ? Paleta.sobreAcento : Paleta.textoTerciario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: TokensEspaciado.e40)
                        .background(Capsule().fill(elegida ? Paleta.acento : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityLabel(Textos.planSemana(semana.numero))
                .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(TokensEspaciado.e4)
        .background(Capsule().fill(Paleta.superficie))
        .overlay(Capsule().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
    }

    private func encabezadoDeLaSemana(_ semana: SemanaDelPlan) -> some View {
        EncabezadoDeSeccion(
            semana.enCurso ? Textos.planSemanaEnCurso(semana.numero) : Textos.planSemana(semana.numero),
            detalle: Textos.planKmDe(
                Formato.distancia(semana.metrosHechos, unidades: estado.sistemaDeUnidades, decimales: 0),
                Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades, decimales: 0)))
    }
}

// MARK: - Un día, en la línea de tiempo

/// Un día del plan. Lo hecho se atenúa y lleva tilde; hoy lleva el acento y la
/// palabra — nunca sólo el color (AGENTS.md §10.1). A la izquierda, el punto y
/// la línea de "Semana de carrera" del mockup.
struct FilaDeDiaDelPlan: View {
    @EnvironmentObject private var estado: EstadoHome
    let dia: DiaDelPlan
    var esPrimero: Bool = false
    var esUltimo: Bool = false

    var body: some View {
        Button {
            guard dia.abrible else { return }
            estado.ir(a: .entreno)
        } label: {
            tarjeta
        }
        .buttonStyle(EstiloPresionado())
        .disabled(!dia.abrible)
        .accessibilityElement(children: .combine)
        .padding(.leading, TokensEspaciado.e26)
        .padding(.vertical, TokensEspaciado.e4)
        .overlay(alignment: .topLeading) { lineaDeTiempo }
    }

    private var tarjeta: some View {
        HStack(spacing: TokensEspaciado.e10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(nombreDelDia)
                Text("\(dia.numeroDeDia) \(dia.mesCorto)")
            }
            .estilo(.etiquetaSeccion.enMinusculas, color: dia.esHoy ? Paleta.acento : Paleta.textoTerciario)
            .monospacedDigit()
            .frame(width: TokensEspaciado.e34, alignment: .leading)

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(dia.titulo).estilo(.cuerpoDestacado)
                HStack(spacing: TokensEspaciado.e6) {
                    Text(dia.detalle)
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                    if let pasos = estado.pasos(para: dia), pasos > 0 {
                        pildoraDePasos(pasos)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if dia.hecho {
                Image(systemName: "checkmark")
                    .font(.system(size: TokensTipografia.notaLegalTamano,
                                  weight: TokensTipografia.tituloCardPeso))
                    .foregroundStyle(Paleta.acento)
                    .accessibilityLabel(Textos.planHecho)
            } else if dia.esHoy {
                Text(Textos.planHoy)
                    .estilo(.etiquetaSeccion, color: Paleta.acento)
            }
        }
        .padding(.horizontal, TokensEspaciado.e13)
        .padding(.vertical, TokensEspaciado.e12)
        .frame(maxWidth: .infinity)
        .background(dia.esHoy ? Paleta.acentoSuaveFondo : Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(dia.esHoy ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                              lineWidth: TokensEspaciado.e1)
        )
        .opacity(dia.hecho ? 0.6 : 1)
        .objetivoTactilAlto()
    }

    private func pildoraDePasos(_ pasos: Int) -> some View {
        HStack(spacing: TokensEspaciado.e3) {
            Image(systemName: "figure.walk")
                .font(.system(size: TokensTipografia.etiquetaSeccionTamano, weight: .semibold))
            Text(Formato.pasos(pasos))
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                .monospacedDigit()
        }
        .foregroundStyle(Paleta.textoTerciario)
        .padding(.horizontal, TokensEspaciado.e5)
        .padding(.vertical, TokensEspaciado.e2)
        .background(Paleta.superficieAlterna)
        .clipShape(Capsule())
    }

    /// El punto y la línea vertical. Es decoración: el estado ya lo dicen la
    /// tilde y "HOY" dentro de la tarjeta.
    private var lineaDeTiempo: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(esPrimero ? Color.clear : Paleta.acentoSuaveBorde)
                .frame(width: TokensEspaciado.e2, height: TokensEspaciado.e22)
            Circle()
                .fill(colorDelPunto)
                .frame(width: TokensEspaciado.e12, height: TokensEspaciado.e12)
                .overlay(Circle().strokeBorder(dia.hecho || dia.esHoy ? Color.clear : Paleta.bordeSuperficie,
                                               lineWidth: TokensEspaciado.e1))
                .shadow(color: dia.esHoy ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e6)
            Rectangle()
                .fill(esUltimo ? Color.clear : Paleta.acentoSuaveBorde)
                .frame(width: TokensEspaciado.e2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: TokensEspaciado.e16)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }

    private var colorDelPunto: Color {
        if dia.esHoy || dia.hecho { return Paleta.acento }
        return Paleta.superficieControl
    }

    /// El nombre corto del día, del calendario en el idioma de la app y no de una lista fija.
    private var nombreDelDia: String {
        var calendario = Calendar.current
        calendario.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        let simbolos = calendario.shortWeekdaySymbols
        // `shortWeekdaySymbols` arranca en domingo; el plan arranca en lunes.
        let indice = (dia.diaDeLaSemana % 7)
        return simbolos.indices.contains(indice) ? simbolos[indice].capitalized : ""
    }
}
