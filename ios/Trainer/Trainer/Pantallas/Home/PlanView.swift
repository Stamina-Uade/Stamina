import SwiftUI
import TrainerCore

/// `plan` — el bloque de semanas, con sus fases, el selector de semana y los
/// siete días.
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
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(Textos.homeTabPlan)
                        .estilo(.marca)
                        .accessibilityAddTraits(.isHeader)
                    if !planVencido, let bloque = bloqueVisible {
                        Text(bloque.subtitulo)
                            .estilo(.labelCampo, color: Paleta.textoTerciario)
                    }
                }

                if !planVencido && planesDeObjetivos.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TokensEspaciado.e8) {
                            ForEach(planesDeObjetivos, id: \.goalId) { item in
                                Button(nombreDelObjetivo(item.plan.goal)) {
                                    objetivoElegido = item.goalId
                                    estado.semanaElegida = 1
                                }
                                .buttonStyle(EstiloPresionado())
                                .foregroundStyle(objetivoElegido == item.goalId ? Paleta.acento : Paleta.textoSecundario)
                                .padding(TokensEspaciado.e12)
                                .background(Paleta.superficie)
                                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.chip))
                            }
                        }
                    }
                }

                if planVencido || faltanObjetivos {
                    SelectorInteractivoDeMetasView()
                } else if let bloque = bloqueVisible, let semana = semanaVisible {
                    if objetivoElegido == "principal" { AvisoDeLoGuardado(seccion: estado.contenido.plan) }
                    tarjetaDelEvento(bloque)
                    selectorDeSemana(bloque)
                    encabezadoDeLaSemana(semana)

                    VStack(spacing: TokensEspaciado.e7) {
                        ForEach(semana.dias) { dia in
                            FilaDeDiaDelPlan(dia: dia)
                        }
                    }
                } else {
                    SinDatosView(problema: estado.contenido.plan.problema, actualizando: estado.actualizando) {
                        Task { await estado.actualizar() }
                    }
                }
                Button { mostrarHistorial = true } label: {
                    Label(Textos.historialTitulo, systemImage: "map")
                        .estilo(.labelCampo, color: Paleta.acento)
                        .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo)
                        .background(Paleta.superficie)
                        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card))
                }
                .buttonStyle(EstiloPresionado())
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

    private func tarjetaDelEvento(_ bloque: BloqueDelPlan) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            HStack(alignment: .top, spacing: TokensEspaciado.e12) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                    Text(bloque.evento).estilo(.campoTexto)
                    Text(bloque.cuando)
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(bloque.semanasQueFaltan)")
                        .estilo(.marca, color: Paleta.acento)
                    Text(Textos.planFaltanSemanas(bloque.semanasQueFaltan))
                        .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Textos.planFaltanSemanas(bloque.semanasQueFaltan))
            }

            // Las fases, proporcionales a su cantidad de semanas.
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
                                color: fase.enCurso ? Paleta.acento : Paleta.textoTerciario)
                        .frame(maxWidth: .infinity, alignment: alineacion(de: fase, en: bloque))
                }
            }
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
    }

    private func colorDeFase(_ fase: FaseDelPlan) -> Color {
        if fase.hecha { return Paleta.acento }
        if fase.enCurso { return Paleta.acento.opacity(0.45) }
        return Paleta.superficieControl
    }

    private func alineacion(de fase: FaseDelPlan, en bloque: BloqueDelPlan) -> Alignment {
        guard let primera = bloque.fases.first, let ultima = bloque.fases.last else { return .center }
        if fase.id == primera.id { return .leading }
        if fase.id == ultima.id { return .trailing }
        return .center
    }

    private func selectorDeSemana(_ bloque: BloqueDelPlan) -> some View {
        HStack(spacing: TokensEspaciado.e6) {
            ForEach(bloque.semanas) { semana in
                let elegida = semana.numero == estado.semanaElegida
                Button { estado.semanaElegida = semana.numero } label: {
                    Text(Textos.planSemanaChip(semana.numero))
                        .estilo(.labelCampo, color: elegida ? Paleta.acento : Paleta.textoTerciario)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                        .background(elegida ? Paleta.acentoChipActivo : Paleta.superficie)
                        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.chip, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: TokensRadio.chip, style: .continuous)
                                .strokeBorder(elegida ? Paleta.acento : Paleta.bordeSuperficie,
                                              lineWidth: TokensEspaciado.e1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityLabel(Textos.planSemana(semana.numero))
                .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func encabezadoDeLaSemana(_ semana: SemanaDelPlan) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(semana.enCurso
                 ? Textos.planSemanaEnCurso(semana.numero)
                 : Textos.planSemana(semana.numero))
                .estilo(.tituloCard)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(Textos.planKmDe(
                Formato.distancia(semana.metrosHechos, unidades: estado.sistemaDeUnidades, decimales: 0),
                Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades, decimales: 0)))
                .estilo(.notaLegal, color: Paleta.textoTerciario)
                .monospacedDigit()
        }
    }
}

/// Un día del plan. Lo hecho se atenúa y lleva tilde; hoy lleva el acento y la
/// palabra — nunca sólo el color (AGENTS.md §10.1).
struct FilaDeDiaDelPlan: View {
    @EnvironmentObject private var estado: EstadoHome
    let dia: DiaDelPlan

    var body: some View {
        Button {
            guard dia.abrible else { return }
            estado.ir(a: .entreno)
        } label: {
            HStack(spacing: TokensEspaciado.e10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(nombreDelDia)
                    Text("\(dia.numeroDeDia) \(dia.mesCorto)")
                }
                .estilo(.etiquetaSeccion.enMinusculas, color: dia.esHoy ? Paleta.acento : Paleta.textoTerciario)
                .monospacedDigit()
                .frame(width: TokensEspaciado.e34, alignment: .leading)

                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(dia.titulo).estilo(.cuerpoSecundario)
                    HStack(spacing: TokensEspaciado.e6) {
                        Text(dia.detalle)
                            .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoSecundario)
                        if let pasos = estado.pasos(para: dia), pasos > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(Formato.pasos(pasos))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(Paleta.textoTerciario)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Paleta.superficieAlterna)
                            .clipShape(Capsule())
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
                        .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.acento)
                }
            }
            .padding(.horizontal, TokensEspaciado.e13)
            .padding(.vertical, TokensEspaciado.e12)
            .frame(maxWidth: .infinity)
            .background(dia.esHoy ? Paleta.acentoSuaveFondo : Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                    .strokeBorder(dia.esHoy ? Paleta.acentoSuaveBorde : Paleta.divisor,
                                  lineWidth: TokensEspaciado.e1)
            )
            .opacity(dia.hecho ? 0.6 : 1)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .disabled(!dia.abrible)
        .accessibilityElement(children: .combine)
    }

    /// El nombre corto del día, del calendario del sistema y no de una lista fija.
    private var nombreDelDia: String {
        let simbolos = Calendar.current.shortWeekdaySymbols
        // `shortWeekdaySymbols` arranca en domingo; el plan arranca en lunes.
        let indice = (dia.diaDeLaSemana % 7)
        return simbolos.indices.contains(indice) ? simbolos[indice].capitalized : ""
    }
}

/// Selector didáctico e interactivo de metas cuando el plan anterior terminó o no hay objetivos activos.
struct SelectorInteractivoDeMetasView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada

    struct MetaDidactica: Identifiable {
        let id: Objetivo
        let titulo: String
        let distancia: String
        let icono: String
        let descripcion: String
        let semanasRecomendadas: String
        let semanasMinimas: Int
    }

    private let metas: [MetaDidactica] = [
        MetaDidactica(id: .c5k, titulo: "5K Express", distancia: "5 km", icono: "figure.run",
                      descripcion: "Velocidad y consistencia. Ideal para iniciarse o mejorar marca personal.",
                      semanasRecomendadas: "6 a 8 semanas", semanasMinimas: 6),
        MetaDidactica(id: .c10k, titulo: "10K Progresivo", distancia: "10 km", icono: "figure.run",
                      descripcion: "El equilibrio clásico entre fondo aeróbico y ritmo de carrera.",
                      semanasRecomendadas: "8 a 12 semanas", semanasMinimas: 8),
        MetaDidactica(id: .mediaMaraton, titulo: "Media Maratón", distancia: "21.1 km", icono: "figure.run",
                      descripcion: "Prueba intermedia exigente. Requiere fondos largos progresivos y nutrición en ruta.",
                      semanasRecomendadas: "12 a 16 semanas", semanasMinimas: 12),
        MetaDidactica(id: .maraton, titulo: "Maratón", distancia: "42.2 km", icono: "figure.run",
                      descripcion: "El desafío supremo de resistencia aeróbica, fuerza mental y fondo.",
                      semanasRecomendadas: "16 a 24 semanas", semanasMinimas: 16),
        MetaDidactica(id: .trailMontana, titulo: "Trail Montaña", distancia: "Desnivel +", icono: "figure.hiking",
                      descripcion: "Terrenos técnicos, cuestas y adaptación a senderos y montaña.",
                      semanasRecomendadas: "10 a 14 semanas", semanasMinimas: 10),
        MetaDidactica(id: .triatlonOlimpico, titulo: "Triatlón Olímpico", distancia: "1.5K · 40K · 10K", icono: "figure.mixed.cardio",
                      descripcion: "Natación en aguas abiertas, ciclismo y carrera en transiciones.",
                      semanasRecomendadas: "14 a 20 semanas", semanasMinimas: 14),
        MetaDidactica(id: .volverSinLesiones, titulo: "Volver sin lesiones", distancia: "Salud y base", icono: "heart.text.square",
                      descripcion: "Acondicionamiento físico suave para retomar el hábito con seguridad.",
                      semanasRecomendadas: "6 a 10 semanas", semanasMinimas: 6)
    ]

    @State private var seleccionada: Objetivo = .mediaMaraton
    @State private var conFecha = true
    @State private var fechaEvento = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date()) ?? Date()
    @State private var guardando = false
    @State private var errorGuardado = false

    private var metaActual: MetaDidactica {
        metas.first { $0.id == seleccionada } ?? metas[0]
    }

    private var semanasCalculadas: Int {
        let ahora = Date()
        let dif = Calendar.current.dateComponents([.day], from: ahora, to: fechaEvento).day ?? 0
        return max(1, dif / 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
            // Cabecera motivadora
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                    Text("NUEVA ETAPA")
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Paleta.acento)
                        .tracking(0.8)
                }

                Text("Elegí tu próxima meta")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)

                Text("Tus metas anteriores ya finalizaron. Seleccioná el objetivo que querés conquistar para que el motor diseñe tu nuevo plan periodizado.")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Paleta.textoTerciario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)

            // Selector horizontal interactivo de metas
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TokensEspaciado.e10) {
                    ForEach(metas) { meta in
                        let elegida = meta.id == seleccionada
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                seleccionada = meta.id
                                fechaEvento = Calendar.current.date(byAdding: .weekOfYear, value: meta.semanasMinimas, to: Date()) ?? Date()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(elegida ? Paleta.acento : Paleta.superficieHundida)
                                            .frame(width: 36, height: 36)
                                        Image(systemName: meta.icono)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(elegida ? Paleta.fondo : Paleta.textoSecundario)
                                    }

                                    Spacer()

                                    if elegida {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Paleta.acento)
                                    }
                                }

                                Text(meta.titulo)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(elegida ? Paleta.textoPrimario : Paleta.textoSecundario)
                                    .lineLimit(1)

                                Text(meta.distancia)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(elegida ? Paleta.acento : Paleta.textoTerciario)
                            }
                            .padding(TokensEspaciado.e12)
                            .frame(width: 150, height: 110, alignment: .leading)
                            .background(Paleta.superficie)
                            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                                    .strokeBorder(elegida ? Paleta.acento : Paleta.bordeSuperficie, lineWidth: elegida ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            // Tarjeta didáctica explicativa de la meta elegida
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Paleta.acento)
                    Text("¿En qué consiste?")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.textoPrimario)
                }

                Text(metaActual.descripcion)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("Preparación sugerida:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                    Text(metaActual.semanasRecomendadas)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.acento)
                }
                .padding(.top, 2)
            }
            .padding(TokensEspaciado.e14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: 1)
            )

            // Selector interactivo de fecha
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                HStack {
                    Text("Fecha del evento")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.textoPrimario)
                    Spacer()
                    Toggle("", isOn: $conFecha)
                        .labelsHidden()
                        .tint(Paleta.interruptorActivo)
                }

                if conFecha {
                    DatePicker("Elegir fecha", selection: $fechaEvento, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Paleta.acento)

                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                            .foregroundStyle(Paleta.acento)
                        Text("El plan durará \(semanasCalculadas) semanas de preparación")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Paleta.acento)
                    }
                } else {
                    Text("Se armará un plan continuo sin fecha límite.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                }
            }
            .padding(TokensEspaciado.e14)
            .frame(maxWidth: .infinity)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: 1)
            )

            // Botón interactivo de confirmación
            Button {
                guardando = true
                Task {
                    let fechaMs: Int64? = conFecha ? DatosRegistro.fechaDelCalendarioEnMs(fechaEvento, zona: .current) : nil
                    let nuevoObjetivo = ObjetivoDeUsuario(id: "principal", goal: seleccionada, goalDateMs: fechaMs)
                    if await flujo.guardarObjetivos([nuevoObjetivo]) {
                        await estado.actualizar()
                    } else {
                        errorGuardado = true
                    }
                    guardando = false
                }
            } label: {
                HStack(spacing: 8) {
                    if guardando {
                        ProgressView()
                            .tint(Paleta.fondo)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text("Diseñar nuevo plan para \(metaActual.titulo)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(Paleta.fondo)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Paleta.acento)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(guardando)
            .padding(.top, 4)
        }
        .alert("No se pudo guardar el objetivo", isPresented: $errorGuardado) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text("Revisá tu conexión e intentá de nuevo.")
        }
    }
}
