import SwiftUI
import TrainerCore

/// `perfil` — foto, datos del cuerpo, deporte y nivel, objetivo y días. El
/// engranaje de arriba a la derecha lleva a `ajustes`.
struct PerfilView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var metasActivas: [ObjetivoDeUsuario] = []
    @State private var cargandoMetas = true

    private var inicioDeHoyMs: Int64 {
        Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                encabezado
                tarjetaDeCuerpo
                seccionHitos
                seccionMetas
                seccionDias
                seccionAjustes
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await flujo.cargarObjetivos()
            metasActivas = flujo.objetivosActivos.filter { obj in
                guard let f = obj.goalDateMs else { return true }
                return f >= inicioDeHoyMs
            }
            cargandoMetas = false
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack(alignment: .center, spacing: TokensEspaciado.e14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Paleta.acentoChipActivo, Paleta.superficie],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(Paleta.acento.opacity(0.35), lineWidth: 1.5)
                    )
                Text(estado.iniciales)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(width: 58, height: 58)
            .accessibilityLabel(Textos.perfilSinFoto)

            VStack(alignment: .leading, spacing: 3) {
                Text(estado.nombreCompleto)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 6) {
                    Image(systemName: iconoDeporte)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                    Text(deporteYNivel)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Paleta.textoSecundario)
                }
            }

            Spacer(minLength: 0)

            Button {
                estado.ir(a: .ajustes)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Paleta.textoSecundario)
                    .frame(width: 40, height: 40)
                    .background(Paleta.superficie)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: 1))
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityLabel(Textos.perfilVerAjustes)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tarjeta de Métricas

    private var tarjetaDeCuerpo: some View {
        HStack(spacing: 0) {
            dato(titulo: Textos.perfilPeso, valor: estado.perfil?.weightG.map {
                Formato.peso(Int($0), unidades: estado.sistemaDeUnidades)
            } ?? "—", icono: "scalemass")

            divisor

            dato(titulo: Textos.perfilAltura, valor: altura, icono: "ruler")

            divisor

            dato(titulo: Textos.perfilEdad, valor: edad.map(Textos.perfilAnios) ?? "—", icono: "calendar")
        }
        .padding(.vertical, TokensEspaciado.e14)
        .frame(maxWidth: .infinity)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: 1)
        )
    }

    private func dato(titulo: String, valor: String, icono: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icono)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Paleta.acento.opacity(0.85))

            Text(valor)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Paleta.textoPrimario)
                .monospacedDigit()

            Text(titulo)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Paleta.textoTerciario)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divisor: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(width: TokensEspaciado.e1, height: TokensEspaciado.e34)
    }

    // MARK: - Hitos de Actividad (GitHub Heatmap)

    private var seccionHitos: some View {
        CalendarioDeHitosView()
    }

    // MARK: - Metas y Objetivos

    private var seccionMetas: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            HStack {
                Text("Metas y objetivos")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)

                Spacer()

                Button {
                    estado.ir(a: .ajustes)
                } label: {
                    Text("+ Gestionar")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.acento)
                }
            }

            if metasActivas.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "flag.slash")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Paleta.textoTerciario)

                    Text("Sin metas activas")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.textoPrimario)

                    Text("Tus metas anteriores ya finalizaron. Definí una nueva meta para comenzar tu próximo plan.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    Button {
                        estado.ir(a: .plan)
                    } label: {
                        Text("Elegir nueva meta")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Paleta.fondo)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Paleta.acento)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Paleta.superficie)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                        .strokeBorder(Paleta.bordeSuperficie, lineWidth: 1)
                )
            } else {
                VStack(spacing: TokensEspaciado.e8) {
                    ForEach(metasActivas.indices, id: \.self) { idx in
                        tarjetaMeta(metasActivas[idx], indice: idx)
                    }
                }
            }
        }
    }

    private func tarjetaMeta(_ meta: ObjetivoDeUsuario, indice: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Paleta.acentoChipActivo)
                    .frame(width: 40, height: 40)
                Image(systemName: iconoParaObjetivo(meta.goal))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(nombreDelObjetivo(meta.goal))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)

                if let fechaMs = meta.goalDateMs {
                    Text(formatoFecha(fechaMs))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                } else {
                    Text("Plan sin fecha fija")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Paleta.textoTerciario)
                }
            }

            Spacer(minLength: 0)

            if let fechaMs = meta.goalDateMs {
                let semanas = semanasRestantes(fechaMs)
                if semanas > 0 {
                    Text("Faltan \(semanas) sem")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.acento)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Paleta.acentoChipActivo)
                        .clipShape(Capsule())
                } else {
                    Text("¡Esta semana!")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Paleta.exito)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Paleta.exito.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: 1)
        )
    }

    // MARK: - Días de Entrenamiento

    private var seccionDias: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            Text("Días de entrenamiento")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Paleta.textoPrimario)

            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    chipDia(weekday: weekday)
                }
            }
        }
    }

    private func chipDia(weekday: Int) -> some View {
        let diaConfigurado = estado.perfil?.trainingDays?.first { $0.weekday == Int64(weekday) }
        let activo = diaConfigurado != nil
        let nombreDia = nombreCortoDia(weekday)

        return VStack(spacing: 4) {
            Text(nombreDia)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(activo ? Paleta.acento : Paleta.textoTerciario)

            if let diaConfigurado {
                Circle()
                    .fill(Paleta.acento)
                    .frame(width: 6, height: 6)
                Text(Formato.hora(minutoDelDia: Int(diaConfigurado.minuteOfDay)))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Paleta.textoSecundario)
                    .monospacedDigit()
            } else {
                Circle()
                    .fill(Paleta.textoTerciario.opacity(0.2))
                    .frame(width: 6, height: 6)
                Text("—")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Paleta.textoTerciario.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(activo ? Paleta.acentoChipActivo : Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(activo ? Paleta.acento.opacity(0.4) : Paleta.bordeSuperficie, lineWidth: 1)
        )
    }

    // MARK: - Sección Ajustes

    private var seccionAjustes: some View {
        FilaDeNavegacion(titulo: Textos.perfilVerAjustes, valor: nil) {
            estado.ir(a: .ajustes)
        }
    }

    // MARK: - Auxiliares

    private var iconoDeporte: String {
        switch estado.perfil?.sport {
        case .running: "figure.run"
        case .ciclismo: "bicycle"
        case .trekking: "figure.walk"
        case .triatlon: "figure.mixed.cardio"
        default: "figure.run"
        }
    }

    private func iconoParaObjetivo(_ obj: Objetivo) -> String {
        switch obj {
        case .c5k, .c10k, .mediaMaraton, .maraton: return "figure.run"
        case .trailMontana: return "figure.hiking"
        case .triatlonOlimpico: return "figure.mixed.cardio"
        case .volverSinLesiones: return "heart.text.square"
        }
    }

    private func formatoFecha(_ ms: Int64) -> String {
        let f = Date(timeIntervalSince1970: Double(ms) / 1000)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = .current
        return df.string(from: f)
    }

    private func semanasRestantes(_ ms: Int64) -> Int {
        let ahora = Date()
        let evento = Date(timeIntervalSince1970: Double(ms) / 1000)
        let dif = Calendar.current.dateComponents([.day], from: ahora, to: evento).day ?? 0
        return max(0, dif / 7)
    }

    private func nombreCortoDia(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Lun"
        case 2: return "Mar"
        case 3: return "Mié"
        case 4: return "Jue"
        case 5: return "Vie"
        case 6: return "Sáb"
        case 7: return "Dom"
        default: return ""
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

    private var dias: String {
        guard let dias = estado.perfil?.trainingDays, !dias.isEmpty else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = .current
        let nombres = formatter.shortWeekdaySymbols ?? []
        return dias.sorted { $0.weekday < $1.weekday }.compactMap { dia in
            guard (1...7).contains(dia.weekday), nombres.count == 7 else { return nil }
            return "\(nombres[Int(dia.weekday) % 7]) \(Formato.hora(minutoDelDia: Int(dia.minuteOfDay)))"
        }.joined(separator: " · ")
    }

    private var altura: String {
        guard let mm = estado.perfil?.heightMm else { return "—" }
        switch estado.sistemaDeUnidades {
        case .metrico: return "\((Double(mm) / 10).formatted(.number.precision(.fractionLength(0)))) cm"
        case .imperial:
            let pulgadas = Int((Double(mm) / 25.4).rounded())
            return "\(pulgadas / 12)′\(pulgadas % 12)″"
        }
    }

    private var edad: Int? {
        guard let nacimiento = estado.perfil?.birthdateMs else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let nacimientoFecha = Date(timeIntervalSince1970: Double(nacimiento) / 1000)
        let cumple = utc.dateComponents([.year, .month, .day], from: nacimientoFecha)
        let hoy = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        guard let y = cumple.year, let m = cumple.month, let d = cumple.day,
              let hy = hoy.year, let hm = hoy.month, let hd = hoy.day else { return nil }
        return hy - y - ((hm, hd) < (m, d) ? 1 : 0)
    }

    private var deporteYNivel: String {
        guard let perfil = estado.perfil else { return "—" }
        let deporte: String? = switch perfil.sport {
        case .running: Textos.regDeporteRunning
        case .ciclismo: Textos.regDeporteCiclismo
        case .trekking: Textos.regDeporteTrekking
        case .triatlon: Textos.regDeporteTriatlon
        case nil: nil
        }
        let nivel: String? = switch perfil.level {
        case .principiante: Textos.regNivelPrincipiante
        case .intermedio: Textos.regNivelIntermedio
        case .avanzado: Textos.regNivelAvanzado
        case nil: nil
        }
        return [deporte, nivel].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct FilaDatoDePerfil: View {
    let titulo: String
    let valor: String

    var body: some View {
        HStack(spacing: TokensEspaciado.e12) {
            Text(titulo).estilo(.tituloCard)
            Spacer()
            Text(valor).estilo(.notaLegal, color: Paleta.textoTerciario)
                .multilineTextAlignment(.trailing)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity)
        .tarjeta(radio: TokensRadio.boton)
    }
}

/// Una fila que lleva a otro lado, con su valor actual y la flecha.
struct FilaDeNavegacion: View {
    let titulo: String
    let valor: String?
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e12) {
                Text(titulo)
                    .estilo(.tituloCard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let valor {
                    Text(valor)
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .multilineTextAlignment(.trailing)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.etiquetaSeccionTamano,
                                  weight: TokensTipografia.tituloCardPeso))
                    .foregroundStyle(Paleta.textoTerciario)
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .padding(.vertical, TokensEspaciado.e14)
            .frame(maxWidth: .infinity)
            .tarjeta(radio: TokensRadio.boton)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
    }
}
