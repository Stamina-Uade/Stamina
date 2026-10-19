import SwiftUI
import TrainerCore

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
            cabecera
            carruselDeMetas
            tarjetaExplicativa
            selectorDeFecha

            BotonPrimario(String(localized: "Diseñar nuevo plan para \(metaActual.titulo)", comment: "Selector de metas"), cargando: guardando) {
                guardar()
            }
            .padding(.top, TokensEspaciado.e4)
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

            Text("Elegí tu próxima meta")
                .estilo(.tituloPantalla)
                .accessibilityAddTraits(.isHeader)

            Text("Tus metas anteriores ya finalizaron. Seleccioná el objetivo que querés conquistar para que el motor diseñe tu nuevo plan periodizado.")
                .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, TokensEspaciado.e4)
    }

    // MARK: - Carrusel de metas

    private var carruselDeMetas: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TokensEspaciado.e10) {
                ForEach(metas) { meta in
                    tarjetaDeMeta(meta, elegida: meta.id == seleccionada)
                }
            }
            .padding(.vertical, TokensEspaciado.e2)
        }
    }

    private func tarjetaDeMeta(_ meta: MetaDidactica, elegida: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                seleccionada = meta.id
                fechaEvento = Calendar.current.date(byAdding: .weekOfYear, value: meta.semanasMinimas, to: Date()) ?? Date()
            }
        } label: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
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

                    Spacer()

                    if elegida {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: TokensEspaciado.e16, weight: .bold))
                            .foregroundStyle(Paleta.acento)
                    }
                }

                Text(meta.titulo)
                    .estilo(.opcionTitulo, color: elegida ? Paleta.textoPrimario : Paleta.textoSecundario)
                    .lineLimit(1)

                Text(meta.distancia)
                    .estilo(.chip, color: elegida ? Paleta.acento : Paleta.textoTerciario)
            }
            .padding(TokensEspaciado.e12)
            .frame(width: TokensEspaciado.e56 * 2 + TokensEspaciado.e40,
                   height: TokensEspaciado.e56 * 2, alignment: .leading)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(elegida ? Paleta.acento : Paleta.bordeSuperficie,
                                  lineWidth: elegida ? TokensEspaciado.e2 : TokensEspaciado.e1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Tarjeta didáctica de la meta elegida

    private var tarjetaExplicativa: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            HStack(spacing: TokensEspaciado.e8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: TokensEspaciado.e14, weight: .semibold))
                    .foregroundStyle(Paleta.acento)
                Text("¿En qué consiste?")
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
    }

    // MARK: - Fecha del evento

    private var selectorDeFecha: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            HStack {
                Text("Fecha del evento")
                    .estilo(.opcionTitulo)
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
                    Text("El plan durará \(semanasCalculadas) semanas de preparación")
                        .estilo(.chip, color: Paleta.acento)
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

    // MARK: - Guardar

    private func guardar() {
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
    }
}
