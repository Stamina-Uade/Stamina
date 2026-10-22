import SwiftUI
import TrainerCore

/// Selector didáctico e interactivo de metas cuando el plan anterior terminó o no hay objetivos activos.
struct SelectorInteractivoDeMetasView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    struct MetaDidactica: Identifiable {
        let id: Objetivo
        let titulo: String
        let distancia: String
        let icono: String
        let descripcion: String
        let semanasRecomendadas: String
        let semanasMinimas: Int
    }

    private let todasLasMetas: [MetaDidactica] = [
        MetaDidactica(id: .c5k, titulo: Textos.goalsC5kTitle, distancia: "5 km", icono: "figure.run",
                      descripcion: Textos.goalsC5kBody,
                      semanasRecomendadas: Textos.goalsWeeks68, semanasMinimas: 6),
        MetaDidactica(id: .c10k, titulo: Textos.goalsC10kTitle, distancia: "10 km", icono: "figure.run",
                      descripcion: Textos.goalsC10kBody,
                      semanasRecomendadas: Textos.goalsWeeks812, semanasMinimas: 8),
        MetaDidactica(id: .mediaMaraton, titulo: Textos.goalsHalfMarathonTitle, distancia: "21.1 km", icono: "figure.run",
                      descripcion: Textos.goalsHalfMarathonBody,
                      semanasRecomendadas: Textos.goalsWeeks1216, semanasMinimas: 12),
        MetaDidactica(id: .maraton, titulo: Textos.goalsMarathonTitle, distancia: "42.2 km", icono: "figure.run",
                      descripcion: Textos.goalsMarathonBody,
                      semanasRecomendadas: Textos.goalsWeeks1624, semanasMinimas: 16),
        MetaDidactica(id: .trailMontana, titulo: Textos.goalsMountainTrailTitle, distancia: Textos.goalsElevationPlus, icono: "figure.hiking",
                      descripcion: Textos.goalsMountainTrailBody,
                      semanasRecomendadas: Textos.goalsWeeks1014, semanasMinimas: 10),
        MetaDidactica(id: .triatlonOlimpico, titulo: Textos.goalsOlympicTriathlonTitle, distancia: "1.5K · 40K · 10K", icono: "figure.mixed.cardio",
                      descripcion: Textos.goalsOlympicTriathlonBody,
                      semanasRecomendadas: Textos.goalsWeeks1420, semanasMinimas: 14),
        MetaDidactica(id: .volverSinLesiones, titulo: Textos.goalsInjuryFreeTitle, distancia: Textos.goalsHealthAndBase, icono: "heart.text.square",
                      descripcion: Textos.goalsInjuryFreeBody,
                      semanasRecomendadas: Textos.goalsWeeks610, semanasMinimas: 6)
    ]

    /// Las que se ofrecen: el MVP (sólo running) esconde el triatlón.
    private var metas: [MetaDidactica] {
        todasLasMetas.filter { MVP.permite($0.id) }
    }

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
            cabecera
            pasos
            grillaDeMetas
            tarjetaExplicativa
            selectorDeFecha
            llamadoAAccion
        }
        .alertaApilada(Textos.goalsSaveFailedTitle, isPresented: $errorGuardado,
                       mensaje: Textos.goalsSaveFailedMessage,
                       botones: [BotonDeAlerta(Textos.commonOk, rol: .cancelar)])
    }

    // MARK: - Cabecera motivadora

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            PildoraDeEstado(Textos.goalsNewChapter, simbolo: "flag.checkered", tono: .acento)

            Text(Textos.goalsTitle)
                .estilo(.tituloPantalla)
                .accessibilityAddTraits(.isHeader)

            Text(Textos.goalsIntro)
                .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, TokensEspaciado.e4)
    }

    /// Los tres pasos, para que se sepa cuánto falta antes de empezar.
    private var pasos: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            paso(1, Textos.goalsStepChooseGoal)
            paso(2, Textos.goalsStepSetDate)
            paso(3, Textos.goalsStepBuildPlan)
        }
        .accessibilityElement(children: .combine)
    }

    private func paso(_ numero: Int, _ texto: String) -> some View {
        HStack(spacing: TokensEspaciado.e6) {
            Text(verbatim: "\(numero)")
                .estilo(.chip, color: Paleta.sobreAcento)
                .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e20)
                .background(Circle().fill(Paleta.acento))
            Text(texto)
                .estilo(.labelCampo, color: Paleta.textoSecundario)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Grilla de metas

    /// Dos columnas: todas las metas a la vista, sin tener que descubrir que
    /// había más deslizando de costado.
    private var grillaDeMetas: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: TokensEspaciado.e10),
                            GridItem(.flexible(), spacing: TokensEspaciado.e10)],
                  spacing: TokensEspaciado.e10) {
            ForEach(metas) { meta in
                tarjetaDeMeta(meta, elegida: meta.id == seleccionada)
            }
        }
    }

    private func tarjetaDeMeta(_ meta: MetaDidactica, elegida: Bool) -> some View {
        Button {
            if !elegida { Haptico.seleccion() }
            withAnimation(reducirMovimiento ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                seleccionada = meta.id
                fechaEvento = Calendar.current.date(byAdding: .weekOfYear, value: meta.semanasMinimas, to: Date()) ?? Date()
            }
        } label: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(elegida ? Paleta.acento : Paleta.superficieHundida)
                            .shadow(color: elegida ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e8)
                        Image(systemName: meta.icono)
                            .font(.system(size: TokensEspaciado.e16, weight: .bold))
                            .foregroundStyle(elegida ? Paleta.sobreAcento : Paleta.textoSecundario)
                    }
                    .frame(width: TokensEspaciado.e36, height: TokensEspaciado.e36)
                    .accessibilityHidden(true)

                    Spacer()

                    if elegida {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: TokensEspaciado.e16, weight: .bold))
                            .foregroundStyle(Paleta.acento)
                            .accessibilityHidden(true)
                    }
                }

                Text(meta.titulo)
                    .estilo(.opcionTitulo, color: elegida ? Paleta.textoPrimario : Paleta.textoSecundario)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(meta.distancia)
                    .estilo(.chip, color: elegida ? Paleta.acento : Paleta.textoTerciario)

                Spacer(minLength: 0)

                HStack(spacing: TokensEspaciado.e4) {
                    Image(systemName: "calendar")
                        .font(.system(size: TokensTipografia.chipTamano, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(meta.semanasRecomendadas)
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Paleta.textoTerciario)
            }
            .padding(TokensEspaciado.e12)
            .frame(maxWidth: .infinity, minHeight: TokensEspaciado.e56 * 2 + TokensEspaciado.e40, alignment: .topLeading)
            .background(elegida ? Paleta.acentoSuaveFondo : Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(elegida ? Paleta.acento : Paleta.bordeSuperficie,
                                  lineWidth: elegida ? TokensEspaciado.e2 : TokensEspaciado.e1)
            )
            .contentShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(Textos.goalsChooseHint)
    }

    // MARK: - Tarjeta didáctica de la meta elegida

    private var tarjetaExplicativa: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            HStack(spacing: TokensEspaciado.e8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: TokensEspaciado.e14, weight: .semibold))
                    .foregroundStyle(Paleta.acento)
                    .accessibilityHidden(true)
                Text(Textos.goalsWhatIs(metaActual.titulo))
                    .estilo(.tituloCard)
            }

            Text(metaActual.descripcion)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(Textos.goalsSuggestedPrep)
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
                Text(metaActual.semanasRecomendadas)
                    .estilo(.chip, color: Paleta.acento)
            }
            .padding(.top, TokensEspaciado.e2)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fecha del evento

    /// Con fecha, menos semanas que las mínimas de la meta merecen un aviso.
    private var faltaTiempo: Bool { conFecha && semanasCalculadas < metaActual.semanasMinimas }

    private var selectorDeFecha: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            HStack {
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(Textos.goalsDateQuestion)
                        .estilo(.opcionTitulo)
                    Text(Textos.goalsDateBody)
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle(String(), isOn: $conFecha)
                    .labelsHidden()
                    .tint(Paleta.interruptorActivo)
                    .accessibilityLabel(Textos.commonEventDate)
            }

            if conFecha {
                DatePicker(Textos.goalsChooseDate, selection: $fechaEvento, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Paleta.acento)

                HStack(spacing: TokensEspaciado.e6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: TokensEspaciado.e12))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                    Text(Textos.goalsPlanDuration(semanasCalculadas))
                        .estilo(.chip, color: Paleta.acento)
                }

                if faltaTiempo {
                    HStack(alignment: .top, spacing: TokensEspaciado.e6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: TokensEspaciado.e12, weight: .semibold))
                            .foregroundStyle(Paleta.textoSecundario)
                            .accessibilityHidden(true)
                        Text(Textos.goalsTooShort(metaActual.semanasMinimas))
                            .estilo(.labelCampo, color: Paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(TokensEspaciado.e10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Paleta.superficieAlterna)
                    .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text(Textos.goalsOngoingPlan)
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
            }
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity)
        .tarjeta()
    }

    // MARK: - Llamado a la acción

    private var llamadoAAccion: some View {
        VStack(spacing: TokensEspaciado.e8) {
            BotonPrimario(Textos.goalsBuildMyPlan(metaActual.titulo), cargando: guardando) {
                Haptico.toque()
                guardar()
            }
            Text(Textos.goalsFooter)
                .estilo(.labelCampo, color: Paleta.textoTerciario)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, TokensEspaciado.e4)
    }

    // MARK: - Guardar

    private func guardar() {
        guardando = true
        Task {
            let fechaMs: Int64? = conFecha ? DatosRegistro.fechaDelCalendarioEnMs(fechaEvento, zona: .current) : nil
            let nuevoObjetivo = ObjetivoDeUsuario(id: "principal", goal: seleccionada, goalDateMs: fechaMs)
            // Los objetivos adicionales se conservan: antes este guardado los borraba.
            let adicionales = flujo.objetivosActivos.filter { $0.id != "principal" }
            if await flujo.guardarObjetivos([nuevoObjetivo] + adicionales) {
                Haptico.exito()
                await estado.actualizar()
            } else {
                errorGuardado = true
            }
            guardando = false
        }
    }
}
