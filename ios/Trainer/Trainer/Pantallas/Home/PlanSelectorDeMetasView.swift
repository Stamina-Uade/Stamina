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
        .alert("No se pudo guardar el objetivo", isPresented: $errorGuardado) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text("Revisá tu conexión e intentá de nuevo.")
        }
    }

    // MARK: - Cabecera motivadora

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            PildoraDeEstado(String(localized: "Nueva etapa", comment: "Selector de metas"), simbolo: "flag.checkered", tono: .acento)

            Text(String(localized: "Elegí tu próxima carrera", comment: "Selector de metas, título"))
                .estilo(.tituloPantalla)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Tu plan anterior terminó o todavía no tenés una meta. Contanos qué querés correr y cuándo, y armamos semanas a tu medida.",
                        comment: "Selector de metas, explicación"))
                .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, TokensEspaciado.e4)
    }

    /// Los tres pasos, para que se sepa cuánto falta antes de empezar.
    private var pasos: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            paso(1, String(localized: "Elegí la meta", comment: "Selector de metas, paso 1"))
            paso(2, String(localized: "Poné la fecha", comment: "Selector de metas, paso 2"))
            paso(3, String(localized: "Armamos tu plan", comment: "Selector de metas, paso 3"))
        }
        .accessibilityElement(children: .combine)
    }

    private func paso(_ numero: Int, _ texto: String) -> some View {
        HStack(spacing: TokensEspaciado.e6) {
            Text("\(numero)")
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
        .accessibilityHint(String(localized: "Elige esta meta para tu próximo plan", comment: "VoiceOver, selector de metas"))
    }

    // MARK: - Tarjeta didáctica de la meta elegida

    private var tarjetaExplicativa: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            HStack(spacing: TokensEspaciado.e8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: TokensEspaciado.e14, weight: .semibold))
                    .foregroundStyle(Paleta.acento)
                    .accessibilityHidden(true)
                Text(String(localized: "¿En qué consiste \(metaActual.titulo)?", comment: "Selector de metas"))
                    .estilo(.tituloCard)
            }

            Text(metaActual.descripcion)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Preparación sugerida:")
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
                    Text(String(localized: "¿Ya tenés fecha de carrera?", comment: "Selector de metas, fecha"))
                        .estilo(.opcionTitulo)
                    Text(String(localized: "Con fecha, el plan cuenta las semanas hasta ese día.", comment: "Selector de metas, fecha"))
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $conFecha)
                    .labelsHidden()
                    .tint(Paleta.interruptorActivo)
                    .accessibilityLabel("Fecha del evento")
            }

            if conFecha {
                DatePicker("Elegir fecha", selection: $fechaEvento, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Paleta.acento)

                HStack(spacing: TokensEspaciado.e6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: TokensEspaciado.e12))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                    Text("El plan durará \(semanasCalculadas) semanas de preparación")
                        .estilo(.chip, color: Paleta.acento)
                }

                if faltaTiempo {
                    HStack(alignment: .top, spacing: TokensEspaciado.e6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: TokensEspaciado.e12, weight: .semibold))
                            .foregroundStyle(Paleta.textoSecundario)
                            .accessibilityHidden(true)
                        Text(String(localized: "Es menos de lo recomendado para esta meta (al menos \(metaActual.semanasMinimas) semanas). Podés elegir una fecha más lejana o una meta más corta.",
                                    comment: "Selector de metas, aviso de poco tiempo"))
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
                Text("Se armará un plan continuo sin fecha límite.")
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
            BotonPrimario(String(localized: "Armar mi plan de \(metaActual.titulo)", comment: "Selector de metas"), cargando: guardando) {
                Haptico.toque()
                guardar()
            }
            Text(String(localized: "Con tu meta y la fecha, el plan arma tus semanas: etapas, días y kilómetros.",
                        comment: "Selector de metas, qué pasa al tocar"))
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
