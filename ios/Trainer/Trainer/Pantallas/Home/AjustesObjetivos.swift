import SwiftUI
import TrainerCore

/// Ajustes → Objetivos: el editor de objetivos. La lista en edición y el
/// guardado viven en `AjustesView` (cargan al entrar a Ajustes); acá se edita.
struct AjustesPaginaObjetivos: View {
    @Binding var objetivos: [ObjetivoDeUsuario]
    let guardando: Bool
    let alGuardar: () -> Void
    let volver: () -> Void

    var body: some View {
        AjustesPagina(String(localized: "Objetivos", comment: "Ajustes: página de objetivos"),
                      volver: volver) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                if objetivos.isEmpty {
                    HStack(spacing: TokensEspaciado.e8) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(Paleta.textoTerciario)
                            .accessibilityHidden(true)
                        Text(String(localized: "Sin objetivos", comment: "Ajustes: no hay objetivos cargados"))
                            .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                    }
                    .padding(.leading, TokensEspaciado.e4)
                }
                ForEach(objetivos.indices, id: \.self) { indice in
                    tarjetaDeObjetivo(indice)
                }
                if objetivos.count < 10 {
                    menuAgregarObjetivo
                }
                BotonTonal(String(localized: "Guardar", comment: "Ajustes: guardar los objetivos")) { alGuardar() }
                    .disabled(guardando)
                    .opacity(guardando ? 0.5 : 1)
            }
        }
    }

    private func tarjetaDeObjetivo(_ indice: Int) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            HStack {
                Text(indice == 0 ? "Plan principal" : "Plan \(indice + 1)")
                    .estilo(.labelCampo, color: indice == 0 ? Paleta.textoAcento : Paleta.textoTerciario)
                Spacer()
                Button {
                    Haptico.toque()
                    objetivos.remove(at: indice)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: TokensTipografia.valorFilaTamano, weight: .bold))
                        .foregroundStyle(Paleta.error)
                        .objetivoTactil()
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityLabel(Text("Quitar"))
            }
            Menu {
                ForEach(MVP.objetivos, id: \.self) { objetivo in
                    Button(TraduccionDelServidor.nombre(de: objetivo)) {
                        let anterior = objetivos[indice]
                        objetivos[indice] = ObjetivoDeUsuario(
                            id: anterior.id, goal: objetivo, goalDateMs: anterior.goalDateMs)
                    }
                }
            } label: {
                HStack {
                    Text(TraduccionDelServidor.nombre(de: objetivos[indice].goal))
                        .estilo(.opcionTitulo)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                }
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            }
            if let fechaMs = objetivos[indice].goalDateMs {
                HStack(spacing: TokensEspaciado.e8) {
                    DatePicker(selection: Binding(
                        get: { fechaLocalDeObjetivo(fechaMs) },
                        set: { nueva in
                            let anterior = objetivos[indice]
                            objetivos[indice] = ObjetivoDeUsuario(
                                id: anterior.id, goal: anterior.goal,
                                goalDateMs: DatosRegistro.fechaDelCalendarioEnMs(nueva, zona: .current))
                        }), displayedComponents: .date) {
                        Image(systemName: "calendar")
                            .foregroundStyle(Paleta.acento)
                            .accessibilityLabel(Text("Fecha del evento"))
                    }
                    .tint(Paleta.acento)
                    Button {
                        let anterior = objetivos[indice]
                        objetivos[indice] = ObjetivoDeUsuario(
                            id: anterior.id, goal: anterior.goal, goalDateMs: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: TokensTipografia.valorDatoTamano, weight: .semibold))
                            .foregroundStyle(Paleta.textoTerciario)
                            .objetivoTactil()
                    }
                    .buttonStyle(EstiloPresionado())
                    .accessibilityLabel(Text("Quitar fecha"))
                }
            } else {
                Button {
                    let anterior = objetivos[indice]
                    objetivos[indice] = ObjetivoDeUsuario(
                        id: anterior.id, goal: anterior.goal,
                        goalDateMs: DatosRegistro.fechaDelCalendarioEnMs(Date(), zona: .current))
                } label: {
                    Label {
                        Text(String(localized: "Fecha", comment: "Ajustes: agregar la fecha del evento"))
                            .estilo(.tituloCard, color: Paleta.textoAcento)
                    } icon: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                            .foregroundStyle(Paleta.acento)
                    }
                    .objetivoTactilAlto()
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityLabel(Text("Agregar fecha del evento"))
            }
        }
        .padding(TokensEspaciado.e12)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(indice == 0 ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                              lineWidth: TokensEspaciado.e1)
        )
    }

    private var menuAgregarObjetivo: some View {
        Menu {
            ForEach(MVP.objetivos, id: \.self) { objetivo in
                Button(TraduccionDelServidor.nombre(de: objetivo)) {
                    objetivos.append(ObjetivoDeUsuario(
                        id: objetivos.isEmpty ? "principal" : "",
                        goal: objetivo, goalDateMs: nil))
                }
            }
        } label: {
            Label {
                Text("Agregar objetivo").estilo(.tituloCard, color: Paleta.textoAcento)
            } icon: {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Paleta.acento)
            }
            .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo)
        }
    }

    private func fechaLocalDeObjetivo(_ ms: Int64) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let dia = utc.dateComponents([.year, .month, .day],
                                     from: Date(timeIntervalSince1970: Double(ms) / 1000))
        return Calendar.current.date(from: DateComponents(year: dia.year, month: dia.month, day: dia.day))
            ?? Date(timeIntervalSince1970: Double(ms) / 1000)
    }
}
