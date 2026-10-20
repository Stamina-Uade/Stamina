import SwiftUI
import TrainerCore

/// Ajustes → Entrenamiento: el nivel y los días con su hora. El deporte se ve
/// pero no se elige: el MVP es sólo running (`MVP.deportesDePerfil`). Guardar
/// es un solo `PATCH /me`, y como cambia el plan, el Home lo vuelve a pedir.
struct AjustesPaginaEntrenamiento: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    let volver: () -> Void

    var body: some View {
        if let perfil = flujo.perfil ?? estado.perfil {
            AjustesEditorEntrenamiento(perfil: perfil, unidades: estado.sistemaDeUnidades, volver: volver)
        } else {
            AjustesCargandoPerfil(titulo: Self.titulo, volver: volver)
        }
    }

    static var titulo: String {
        Textos.settingsTrainingTitle
    }

    static func nombre(de nivel: Nivel) -> String {
        switch nivel {
        case .principiante: return Textos.signupLevelBeginner
        case .intermedio: return Textos.signupLevelIntermediate
        case .avanzado: return Textos.signupLevelAdvanced
        }
    }
}

private struct AjustesEditorEntrenamiento: View {
    private enum Campo: Hashable { case nivel, dias }

    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @StateObject private var guardado = GuardadoDePerfil()

    private let volver: () -> Void
    @State private var original: EdicionDePerfil
    @State private var borrador: EdicionDePerfil
    @State private var abierto: Campo?

    init(perfil: Perfil, unidades: SistemaDeUnidades, volver: @escaping () -> Void) {
        let base = EdicionDePerfil(perfil: perfil, unidades: unidades)
        _original = State(initialValue: base)
        _borrador = State(initialValue: base)
        self.volver = volver
    }

    var body: some View {
        AjustesPaginaDeEdicion(AjustesPaginaEntrenamiento.titulo,
                               hayCambios: borrador != original,
                               puedeGuardar: puedeGuardar,
                               guardado: guardado,
                               guardar: guardar,
                               volver: volver) {
            AjustesSeccion {
                AjustesFilaDeDato(simbolo: "figure.run", titulo: Self.tituloDeporte,
                                  valor: Textos.signupSportRunning)
                AjustesDivisorDeFila()
                filaNivel
                AjustesDivisorDeFila()
                filaDias
            }
        }
        .onChange(of: borrador) { nuevo in guardado.contenidoCambio(hayCambios: nuevo != original) }
    }

    private var puedeGuardar: Bool {
        borrador.esValida(desde: original)
            && borrador.cambios(desde: original, zona: .autoupdatingCurrent) != nil
    }

    // MARK: - Filas

    private var filaNivel: some View {
        AjustesFilaDesplegable(simbolo: "chart.bar.fill", titulo: Self.tituloNivel,
                               valor: borrador.nivel.map(AjustesPaginaEntrenamiento.nombre(de:)) ?? "—",
                               editado: borrador.nivel != original.nivel,
                               abierta: abierto == .nivel, alTocar: { alternar(.nivel) }) {
            VStack(spacing: TokensEspaciado.e8) {
                ForEach(opcionesDeNivel, id: \.0) { valor, detalle in
                    FilaOpcion(titulo: AjustesPaginaEntrenamiento.nombre(de: valor), detalle: detalle,
                               elegida: borrador.nivel == valor, conMarca: false) {
                        Haptico.seleccion()
                        borrador.nivel = valor
                    }
                }
            }
        }
    }

    private var filaDias: some View {
        AjustesFilaDesplegable(simbolo: "calendar.badge.clock", titulo: Textos.profileDaysAndTimes,
                               valor: resumenDeDias,
                               editado: borrador.dias != original.dias,
                               abierta: abierto == .dias, alTocar: { alternar(.dias) }) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                HStack(spacing: TokensEspaciado.e5) {
                    ForEach(diasEnOrden, id: \.self) { iso in
                        ChipDia(abreviatura: RegDiasView.abreviatura(iso),
                                nombreCompleto: RegDiasView.nombre(iso),
                                elegido: borrador.dias[iso] != nil) {
                            alternarDia(iso)
                        }
                    }
                }
                ForEach(diasEnOrden.filter { borrador.dias[$0] != nil }, id: \.self) { iso in
                    filaDeHora(iso)
                }
                if borrador.faltanDias(desde: original) {
                    PistaDeCampo(estado: .error(Textos.signupDaysNoDays))
                }
            }
        }
    }

    /// El día y su hora, como en `reg-dias`.
    private func filaDeHora(_ iso: Int) -> some View {
        HStack {
            Text(RegDiasView.nombre(iso))
                .estilo(.tituloCard)
            Spacer()
            DatePicker(Textos.signupDaysTimeOf(RegDiasView.nombre(iso)),
                       selection: enlaceDeHora(iso),
                       displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Paleta.acento)
        }
        .padding(.vertical, TokensEspaciado.e4)
        .padding(.horizontal, TokensEspaciado.e12)
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
        .background(Paleta.superficieHundida)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous))
    }

    // MARK: - Valores

    private var opcionesDeNivel: [(Nivel, String)] {
        [
            (.principiante, Textos.signupLevelBeginnerDetail),
            (.intermedio, Textos.signupLevelIntermediateDetail),
            (.avanzado, Textos.signupLevelAdvancedDetail),
        ]
    }

    /// Días ISO (1 = lunes), desde el primer día de la semana del locale.
    private var diasEnOrden: [Int] {
        let primero = Calendar.autoupdatingCurrent.firstWeekday  // 1 = domingo
        let isoDelPrimero = primero == 1 ? 7 : primero - 1
        return (0..<7).map { ((isoDelPrimero - 1 + $0) % 7) + 1 }
    }

    /// "Mar · Jue · Sáb", en el orden de la semana del locale.
    private var resumenDeDias: String {
        let elegidos = diasEnOrden.filter { borrador.dias[$0] != nil }
        return elegidos.isEmpty ? "—" : elegidos.map(RegDiasView.abreviatura).joined(separator: " · ")
    }

    /// El contrato guarda minutos desde la medianoche LOCAL; el `DatePicker`
    /// trabaja con `Date`. Es la misma traducción que `reg-dias`.
    private func enlaceDeHora(_ iso: Int) -> Binding<Date> {
        Binding(
            get: {
                let inicio = Calendar.autoupdatingCurrent.startOfDay(for: Date())
                return Calendar.autoupdatingCurrent
                    .date(byAdding: .minute, value: borrador.dias[iso] ?? 0, to: inicio) ?? inicio
            },
            set: { nueva in
                let c = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: nueva)
                borrador.dias[iso] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }

    // MARK: - Acciones

    private func alternar(_ campo: Campo) {
        Haptico.toque()
        withAnimation(reducirMovimiento ? nil : .spring(response: TokensMovimiento.media, dampingFraction: 0.9)) {
            abierto = abierto == campo ? nil : campo
        }
    }

    /// Un día nuevo arranca a la hora del alta (18:30), o a la del que vuelve.
    private func alternarDia(_ iso: Int) {
        Haptico.seleccion()
        withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida)) {
            if borrador.dias[iso] != nil {
                borrador.dias.removeValue(forKey: iso)
            } else {
                borrador.dias[iso] = original.dias[iso] ?? 18 * 60 + 30
            }
        }
    }

    private func guardar() {
        guard borrador.esValida(desde: original),
              let cambios = borrador.cambios(desde: original, zona: .autoupdatingCurrent) else { return }
        Task { @MainActor in
            guard let nuevo = await guardado.guardar(cambios, en: flujo) else { return }
            estado.perfil = nuevo
            let base = EdicionDePerfil(perfil: nuevo, unidades: estado.sistemaDeUnidades)
            original = base
            borrador = base
            withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida)) {
                abierto = nil
            }
            // Nivel y días cambian el plan y los avisos: se trae lo nuevo (al
            // aplicarlo, `EstadoHome` reprograma los recordatorios).
            if cambios.tocaElPlan { await estado.actualizar() }
        }
    }

    // MARK: - Textos nuevos

    private static let tituloDeporte = Textos.settingsTrainingSport
    private static let tituloNivel = Textos.settingsTrainingLevel
}
