import SwiftUI
import TrainerCore

/// `perfil` — foto, datos del cuerpo, deporte y nivel, objetivo y días. El
/// engranaje de arriba a la derecha lleva a `ajustes`.
///
/// Ronda 5: sin guías ni explicaciones. Los datos del cuerpo son tres tarjetas
/// (`PerfilDatosDelCuerpo.swift`) y, si falta alguno, un botón chico para
/// completarlo; las metas llevan al plan; y abajo queda la fila del apto físico
/// (`PerfilPiezas.swift`).
///
/// Ronda 6: nada de ajustes acá (ni el color ni el recorrido): todo eso vive en
/// Ajustes. Queda el apto físico, que es un dato personal. Los datos del cuerpo
/// y los días se editan en Ajustes: tocarlos abre Ajustes ya en "Datos
/// personales" o en "Entrenamiento" (`AjustesAncla.paginaAlVolver`).
struct PerfilView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var metasActivas: [ObjetivoDeUsuario] = []
    @State private var cargandoMetas = true
    @State private var mostrarApto = false
    @State private var mostrarRacha = false
    @ObservedObject private var apto = AlmacenDeAptoFisico.compartido

    private var inicioDeHoyMs: Int64 {
        Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                encabezado
                tarjetaDeIdentidad
                datosDelCuerpo
                if let plan = estado.plan {
                    seccionActividad(plan)
                }
                seccionMetas
                seccionDias
                seccionApto
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
        .sheet(isPresented: $mostrarApto) { AptoFisicoView() }
        .sheet(isPresented: $mostrarRacha) {
            if let racha = estado.plan?.racha {
                DetalleDeRachaView(racha: racha)
            }
        }
    }

    // MARK: - Encabezado

    /// "Perfil" grande, como las otras pestañas, y el engranaje.
    private var encabezado: some View {
        EncabezadoDePestana(Textos.homeTabProfile) {
            BotonCircular("gearshape", etiqueta: Textos.profileViewSettings) {
                Haptico.toque()
                estado.ir(a: .ajustes)
            }
        }
    }

    // MARK: - Identidad

    /// Las iniciales con el halo del acento, el nombre y la píldora de deporte y
    /// nivel.
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
            .accessibilityLabel(Textos.profileNoPhoto)

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

    /// Peso, altura y edad: tres tarjetas de métrica en fila. Si falta alguno,
    /// abajo va un botón chico para completarlo en Ajustes → Datos personales.
    private var datosDelCuerpo: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(Textos.profileYourBody)
            HStack(spacing: TokensEspaciado.e8) {
                ForEach(DatoDelCuerpo.allCases) { dato in
                    tarjetaDeDato(dato)
                }
            }
            if DatoDelCuerpo.allCases.contains(where: { falta($0) }) {
                botonCompletarDatos
            }
        }
    }

    /// Cada tarjeta abre Ajustes → Datos personales, donde se edita.
    private func tarjetaDeDato(_ dato: DatoDelCuerpo) -> some View {
        Button {
            abrirAjustes(en: .datosPersonales)
        } label: {
            TarjetaMetrica(dato.titulo, valor: valor(de: dato), simbolo: dato.simbolo, destacada: falta(dato))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(dato.titulo), \(valor(de: dato))"))
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityHint(Self.pistaDatosPersonales)
    }

    /// "Completar ahora": chico, en línea, sólo si falta un dato. Abre Ajustes →
    /// Datos personales.
    private var botonCompletarDatos: some View {
        Button {
            abrirAjustes(en: .datosPersonales)
        } label: {
            EtiquetaCompletar(texto: Textos.profileCompleteNow)
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityHint(Self.pistaDatosPersonales)
    }

    private func valor(de dato: DatoDelCuerpo) -> String {
        switch dato {
        case .peso:
            return estado.perfil?.weightG.map { Formato.peso(Int($0), unidades: estado.sistemaDeUnidades) } ?? "—"
        case .altura:
            return altura
        case .edad:
            return edad.map(Textos.profileAgeYears) ?? "—"
        }
    }

    private func falta(_ dato: DatoDelCuerpo) -> Bool {
        switch dato {
        case .peso: return estado.perfil?.weightG == nil
        case .altura: return estado.perfil?.heightMm == nil
        case .edad: return estado.perfil?.birthdateMs == nil
        }
    }

    /// Abre Ajustes ya en una página. `AjustesView` lee el ancla en su
    /// `onAppear` y la borra: al volver de la página se cae en la raíz de Ajustes.
    private func abrirAjustes(en pagina: PaginaDeAjustes) {
        Haptico.toque()
        AjustesAncla.paginaAlVolver = pagina
        estado.ir(a: .ajustes)
    }

    // MARK: - Tu actividad

    /// Sólo con plan: la racha y la semana en curso, todo del servidor.
    private func seccionActividad(_ plan: PlanDelHome) -> some View {
        let semanaDeHoy = plan.semanaDeHoy.flatMap { numero in
            plan.bloque.semanas.first { $0.numero == numero }
        }
        return VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(Textos.profileYourActivity)
            HStack(spacing: TokensEspaciado.e8) {
                Button {
                    Haptico.toque()
                    mostrarRacha = true
                } label: {
                    TarjetaMetrica(Textos.streakTitle, valor: "\(plan.racha.dias)", unidad: Textos.streakDays,
                                   simbolo: plan.racha.dias > 0 ? "flame.fill" : "flame",
                                   destacada: plan.racha.dias > 0 && plan.racha.activaHoy)
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityHint(Textos.profileStreakHint)

                if let numero = plan.semanaDeHoy, plan.bloque.totalDeSemanas > 0 {
                    botonAlPlan {
                        TarjetaMetrica(Textos.commonWeek,
                                       valor: "\(numero)",
                                       unidad: Textos.profileOfNumber(plan.bloque.totalDeSemanas),
                                       simbolo: "calendar")
                    }
                }

                if let semana = semanaDeHoy, semana.metrosPrevistos > 0 {
                    botonAlPlan {
                        TarjetaMetrica(Textos.profileThisWeek,
                                       valor: Formato.distanciaNumero(semana.metrosHechos, unidades: estado.sistemaDeUnidades),
                                       unidad: Textos.profileOfText(Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades)),
                                       simbolo: "figure.run")
                    }
                }
            }
        }
    }

    private func botonAlPlan<Contenido: View>(@ViewBuilder _ contenido: () -> Contenido) -> some View {
        Button {
            Haptico.toque()
            estado.ir(a: .plan)
        } label: {
            contenido()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityHint(Textos.profileOpensPlan)
    }

    // MARK: - Metas y Objetivos

    private var seccionMetas: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(Textos.profileGoalsTitle, accion: Textos.profileGoalsManage) {
                abrirAjustes(en: .objetivos)
            }

            if metasActivas.isEmpty {
                if cargandoMetas {
                    cargandoLasMetas
                } else {
                    sinMetas
                }
            } else {
                VStack(spacing: TokensEspaciado.e8) {
                    ForEach(metasActivas.indices, id: \.self) { idx in
                        tarjetaMeta(metasActivas[idx])
                    }
                }
            }
        }
    }

    private var cargandoLasMetas: some View {
        HStack(spacing: TokensEspaciado.e10) {
            ProgressView().tint(Paleta.acento)
            Text(Textos.profileGoalsLoading)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity)
        .tarjeta()
    }

    private var sinMetas: some View {
        VStack(spacing: TokensEspaciado.e8) {
            Image(systemName: "flag.slash")
                .font(.system(size: TokensTipografia.tituloEjercicioTamano, weight: .bold))
                .foregroundStyle(Paleta.textoTerciario)
                .accessibilityHidden(true)

            Text(Textos.profileGoalsNoneActive)
                .estilo(.opcionTitulo)

            Text(Textos.profileGoalsFinished)
                .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, TokensEspaciado.e12)

            Button {
                Haptico.toque()
                estado.ir(a: .plan)
            } label: {
                Text(Textos.profileGoalsChooseNew)
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

    /// La meta con su cuenta regresiva y, si coincide con el plan en curso, la
    /// barra de semanas. Tocarla abre el plan.
    private func tarjetaMeta(_ meta: ObjetivoDeUsuario) -> some View {
        let avance = progreso(de: meta)
        return Button {
            Haptico.toque()
            estado.ir(a: .plan)
        } label: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
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
                        Text(meta.goalDateMs.map(formatoFecha) ?? Textos.profileGoalsNoFixedDate)
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                    }

                    Spacer(minLength: 0)

                    if let fechaMs = meta.goalDateMs {
                        let dias = diasRestantes(fechaMs)
                        PildoraDeEstado(cuentaRegresiva(dias),
                                        simbolo: dias < 7 ? "bolt.fill" : "flag.fill", tono: .acento)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                        .foregroundStyle(Paleta.textoTerciario)
                        .accessibilityHidden(true)
                }

                if let avance {
                    BarraDeProgresoDeMeta(actual: avance.actual, total: avance.total)
                }
            }
            .padding(TokensEspaciado.e12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjeta()
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Textos.profileOpensPlan)
    }

    /// "Faltan 12 días" de cerca, "Faltan 9 sem" de lejos.
    private func cuentaRegresiva(_ dias: Int) -> String {
        switch dias {
        case 0: return Textos.profileGoalsToday
        case 1: return Textos.profileGoalsOneDayLeft
        case 2..<14: return Textos.profileGoalsDaysLeft(dias)
        default: return Textos.profileGoalsWeeksLeft(dias / 7)
        }
    }

    /// El avance del plan, sólo si la meta es la del plan en curso (misma fecha).
    /// Sin plan o sin fecha no hay barra: no se inventa un progreso.
    private func progreso(de meta: ObjetivoDeUsuario) -> (actual: Int, total: Int)? {
        guard let plan = estado.plan,
              let fechaMeta = meta.goalDateMs,
              let fechaPlan = plan.bloque.fechaDelEventoMs,
              abs(fechaMeta - fechaPlan) <= 86_400_000,
              plan.bloque.totalDeSemanas > 0 else { return nil }
        let total = plan.bloque.totalDeSemanas
        let actual = plan.semanaDeHoy ?? (total - plan.bloque.semanasQueFaltan)
        return (min(max(actual, 0), total), total)
    }

    // MARK: - Días de Entrenamiento

    private var seccionDias: some View {
        let elegidos = estado.perfil?.trainingDays?.count ?? 0
        return VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(Textos.profileTrainingDays,
                                detalle: elegidos > 0
                                    ? Textos.profilePerWeek(elegidos)
                                    : nil)

            // Toda la tarjeta abre Ajustes → Entrenamiento (días y horarios).
            Button {
                abrirAjustes(en: .entrenamiento)
            } label: {
                VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                    HStack(spacing: TokensEspaciado.e6) {
                        ForEach(1...7, id: \.self) { weekday in
                            chipDia(weekday: weekday)
                        }
                    }

                    if elegidos > 0 {
                        Text(Textos.profileTrainingDaysDetail)
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(Textos.profileTrainingDaysNone)
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                            .fixedSize(horizontal: false, vertical: true)
                        EtiquetaCompletar(texto: Textos.profileCompleteProfile)
                    }
                }
                .padding(TokensEspaciado.e14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tarjeta()
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityHint(Self.pistaEntrenamiento)
        }
    }

    private func chipDia(weekday: Int) -> some View {
        let diaConfigurado = estado.perfil?.trainingDays?.first { $0.weekday == Int64(weekday) }
        return ChipDeDiaDePerfil(nombreCorto: nombreCortoDia(weekday),
                                 nombreLargo: nombreLargoDia(weekday),
                                 minutoDelDia: diaConfigurado.map { Int($0.minuteOfDay) },
                                 esHoy: weekday == diaDeHoyISO)
    }

    /// Hoy en ISO (1 = lunes), como `trainingDays`.
    private var diaDeHoyISO: Int {
        let gregoriano = Calendar.current.component(.weekday, from: Date()) // 1 = domingo
        return ((gregoriano + 5) % 7) + 1
    }

    // MARK: - Apto físico

    /// El apto es un dato tuyo: su vencimiento y, al tocarlo, la hoja para verlo
    /// o cargarlo. Cerrar sesión, el color y el recorrido siguen en Ajustes.
    private var seccionApto: some View {
        FilaDeAccesoDePerfil(simbolo: "cross.case.fill",
                             titulo: Textos.medicalTitle,
                             subtitulo: textoDelApto,
                             colorDelSubtitulo: colorDelApto) {
            mostrarApto = true
        }
        .tarjeta()
    }

    private var textoDelApto: String {
        switch apto.estado {
        case .sinCargar:
            return Textos.profileMedicalNotAdded
        case .vigente(let dias), .porVencer(let dias):
            let fecha = apto.apto?.vence.formatted(date: .abbreviated, time: .omitted) ?? ""
            return Textos.profileMedicalExpiresOnDaysLeft(fecha, dias)
        case .vencido:
            return Textos.profileMedicalExpired
        }
    }

    private var colorDelApto: Color {
        switch apto.estado {
        case .vencido: return Paleta.error
        case .porVencer: return Paleta.textoAcento
        case .sinCargar, .vigente: return Paleta.textoSecundario
        }
    }

    // MARK: - Auxiliares

    private static let pistaDatosPersonales = Textos.profileOpensPersonalData

    private static let pistaEntrenamiento = Textos.profileOpensTraining

    /// El deporte del perfil como deporte de sesión, para `IconoDeporte` y
    /// `nombreVisible`: los dos enums comparten los valores crudos.
    /// MVP sólo running: un deporte escondido se muestra como running.
    private var deporteDeLaSesion: DeporteDeSesion {
        MVP.acotado(estado.perfil?.sport.flatMap { DeporteDeSesion(rawValue: $0.rawValue) } ?? .running)
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

    /// Días enteros hasta la fecha de la meta (0 = hoy).
    private func diasRestantes(_ ms: Int64) -> Int {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        let evento = calendario.startOfDay(for: Date(timeIntervalSince1970: Double(ms) / 1000))
        return max(0, calendario.dateComponents([.day], from: hoy, to: evento).day ?? 0)
    }

    private func nombreCortoDia(_ weekday: Int) -> String {
        switch weekday {
        case 1: return Textos.weekdayShortMon
        case 2: return Textos.weekdayShortTue
        case 3: return Textos.weekdayShortWed
        case 4: return Textos.weekdayShortThu
        case 5: return Textos.weekdayShortFri
        case 6: return Textos.weekdayShortSat
        case 7: return Textos.weekdayShortSun
        default: return ""
        }
    }

    /// El nombre completo para VoiceOver. `weekdaySymbols` empieza en domingo.
    private func nombreLargoDia(_ weekday: Int) -> String {
        let simbolos = Calendar.current.weekdaySymbols
        let indice = weekday % 7
        return simbolos.indices.contains(indice) ? simbolos[indice] : nombreCortoDia(weekday)
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
            .flatMap { DeporteDeSesion(rawValue: $0.rawValue) }
            .map { MVP.acotado($0).nombreVisible }
        let nivel: String? = switch perfil.level {
        case .principiante: Textos.signupLevelBeginner
        case .intermedio: Textos.signupLevelIntermediate
        case .avanzado: Textos.signupLevelAdvanced
        case nil: nil
        }
        return [deporte, nivel].compactMap { $0 }.joined(separator: " · ")
    }
}
