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
                tarjetaDeIdentidad
                datosDelCuerpo
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

    /// "Perfil" grande, como las otras pestañas, y el engranaje que lleva a ajustes.
    private var encabezado: some View {
        EncabezadoDePestana(Textos.homeTabPerfil) {
            BotonCircular("gearshape", etiqueta: Textos.perfilVerAjustes) {
                estado.ir(a: .ajustes)
            }
        }
    }

    /// Las iniciales con el halo rosa, el nombre y la píldora de deporte y nivel.
    private var tarjetaDeIdentidad: some View {
        HStack(alignment: .center, spacing: TokensEspaciado.e14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Paleta.acentoProfundo, Paleta.superficie],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e2))
                    .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e12)
                Text(estado.iniciales)
                    .estilo(.unidadHeroe, color: Paleta.acento)
            }
            .frame(width: TokensEspaciado.e56, height: TokensEspaciado.e56)
            .accessibilityLabel(Textos.perfilSinFoto)

            VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                Text(estado.nombreCompleto)
                    .estilo(.tituloSeccion)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: TokensEspaciado.e6) {
                    IconoDeporte(deporte: deporteDeLaSesion, color: Paleta.acento,
                                 tamano: TokensTipografia.chipTamano)
                        .accessibilityHidden(true)
                    Text(deporteYNivel)
                        .estilo(.chip, color: Paleta.textoSecundario)
                        .lineLimit(1)
                }
                .padding(.horizontal, TokensEspaciado.e10)
                .padding(.vertical, TokensEspaciado.e6)
                .background(Paleta.acentoChipActivo)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1))
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    // MARK: - Datos del cuerpo

    /// Peso, altura y edad: tres tarjetas de métrica en fila, como las del entreno.
    private var datosDelCuerpo: some View {
        HStack(spacing: TokensEspaciado.e8) {
            TarjetaMetrica(Textos.perfilPeso,
                           valor: estado.perfil?.weightG.map {
                               Formato.peso(Int($0), unidades: estado.sistemaDeUnidades)
                           } ?? "—",
                           simbolo: "scalemass")
            TarjetaMetrica(Textos.perfilAltura, valor: altura, simbolo: "ruler")
            TarjetaMetrica(Textos.perfilEdad, valor: edad.map(Textos.perfilAnios) ?? "—",
                           simbolo: "calendar")
        }
    }

    // MARK: - Hitos de Actividad (GitHub Heatmap)

    private var seccionHitos: some View {
        CalendarioDeHitosView()
    }

    // MARK: - Metas y Objetivos

    private var seccionMetas: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion("Metas y objetivos", accion: "+ Gestionar") {
                estado.ir(a: .ajustes)
            }

            if metasActivas.isEmpty {
                sinMetas
            } else {
                VStack(spacing: TokensEspaciado.e8) {
                    ForEach(metasActivas.indices, id: \.self) { idx in
                        tarjetaMeta(metasActivas[idx], indice: idx)
                    }
                }
            }
        }
    }

    private var sinMetas: some View {
        VStack(spacing: TokensEspaciado.e8) {
            Image(systemName: "flag.slash")
                .font(.system(size: TokensTipografia.tituloEjercicioTamano, weight: .bold))
                .foregroundStyle(Paleta.textoTerciario)
                .accessibilityHidden(true)

            Text("Sin metas activas")
                .estilo(.opcionTitulo)

            Text("Tus metas anteriores ya finalizaron. Definí una nueva meta para comenzar tu próximo plan.")
                .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, TokensEspaciado.e12)

            Button {
                estado.ir(a: .plan)
            } label: {
                Text("Elegir nueva meta")
                    .estilo(.tituloCard, color: Paleta.sobreAcento)
                    .padding(.horizontal, TokensEspaciado.e20)
                    .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                    .background(Paleta.acento)
                    .clipShape(Capsule())
                    .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e8)
            }
            .buttonStyle(EstiloPresionado())
            .padding(.top, TokensEspaciado.e4)
        }
        .padding(.vertical, TokensEspaciado.e20)
        .frame(maxWidth: .infinity)
        .tarjeta()
    }

    private func tarjetaMeta(_ meta: ObjetivoDeUsuario, indice: Int) -> some View {
        HStack(spacing: TokensEspaciado.e12) {
            ZStack {
                Circle()
                    .fill(Paleta.acentoChipActivo)
                    .overlay(Circle().strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1))
                Image(systemName: iconoParaObjetivo(meta.goal))
                    .font(.system(size: TokensTipografia.valorDatoTamano, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                Text(TraduccionDelServidor.nombre(de: meta.goal))
                    .estilo(.opcionTitulo)

                Text(meta.goalDateMs.map(formatoFecha) ?? "Plan sin fecha fija")
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
            }

            Spacer(minLength: 0)

            if let fechaMs = meta.goalDateMs {
                let semanas = semanasRestantes(fechaMs)
                if semanas > 0 {
                    PildoraDeEstado("Faltan \(semanas) sem", simbolo: "flag.fill", tono: .acento)
                } else {
                    PildoraDeEstado("¡Esta semana!", simbolo: "bolt.fill", tono: .acento)
                }
            }
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    // MARK: - Días de Entrenamiento

    private var seccionDias: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion("Días de entrenamiento")

            HStack(spacing: TokensEspaciado.e6) {
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

        return VStack(spacing: TokensEspaciado.e4) {
            Text(nombreDia)
                .estilo(.chip, color: activo ? Paleta.acento : Paleta.textoTerciario)

            Circle()
                .fill(activo ? Paleta.acento : Paleta.superficieControl)
                .frame(width: TokensEspaciado.e6, height: TokensEspaciado.e6)

            if let diaConfigurado {
                Text(Formato.hora(minutoDelDia: Int(diaConfigurado.minuteOfDay)))
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoSecundario)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("—")
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TokensEspaciado.e8)
        .background(activo ? Paleta.acentoChipActivo : Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
                .strokeBorder(activo ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                              lineWidth: TokensEspaciado.e1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sección Ajustes

    private var seccionAjustes: some View {
        FilaDeNavegacion(titulo: Textos.perfilVerAjustes, valor: nil) {
            estado.ir(a: .ajustes)
        }
    }

    // MARK: - Auxiliares

    /// El deporte del perfil como deporte de sesión, para `IconoDeporte` y
    /// `nombreVisible`: los dos enums comparten los valores crudos.
    private var deporteDeLaSesion: DeporteDeSesion {
        estado.perfil?.sport.flatMap { DeporteDeSesion(rawValue: $0.rawValue) } ?? .running
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
        let deporte: String? = perfil.sport
            .flatMap { DeporteDeSesion(rawValue: $0.rawValue) }?.nombreVisible
        let nivel: String? = switch perfil.level {
        case .principiante: Textos.regNivelPrincipiante
        case .intermedio: Textos.regNivelIntermedio
        case .avanzado: Textos.regNivelAvanzado
        case nil: nil
        }
        return [deporte, nivel].compactMap { $0 }.joined(separator: " · ")
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
