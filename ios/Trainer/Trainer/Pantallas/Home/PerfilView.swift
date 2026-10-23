import SwiftUI
import TrainerCore

/// `perfil` — "menos cosas a la vista" (decisión de Iván del 2026-10-23):
///
///   la barra fija «Perfil» con el fueguito y el engranaje de Ajustes
///   quién eres: las iniciales, el nombre y "Running · Intermedio"
///   un solo grupo de filas con su resumen, y cada una abre su página:
///     Tu cuerpo       72 kg · 1,78 m · 33 años
///     Metas           Media maratón · faltan 20 semanas
///     Días y horario  Lun, Mié y Vie · 18:30
///     Apto físico     Sin cargar / Vigente / Vence en N días (punto rojo si falta o vence)
///
/// Se fue "Tu actividad" (la racha ya está en el fueguito y la semana en Plan) y las
/// tarjetas y chips de antes. Los datos se editan en Ajustes: tocar una fila abre
/// Ajustes ya en esa página (`AjustesAncla.paginaAlVolver`).
struct PerfilView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var metasActivas: [ObjetivoDeUsuario] = []
    @State private var mostrarApto = false
    @ObservedObject private var apto = AlmacenDeAptoFisico.compartido

    private var inicioDeHoyMs: Int64 {
        Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
    }

    var body: some View {
        PantallaDePestana(Textos.homeTabProfile) {
            HStack(spacing: TokensEspaciado.e8) {
                FueguitoDeLaBarra()
                BotonCircular("gearshape", etiqueta: Textos.profileViewSettings) {
                    Haptico.toque()
                    estado.ir(a: .ajustes)
                }
            }
        } contenido: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                identidad
                filas
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .task {
            await flujo.cargarObjetivos()
            metasActivas = flujo.objetivosActivos.filter { obj in
                guard let f = obj.goalDateMs else { return true }
                return f >= inicioDeHoyMs
            }
        }
        .sheet(isPresented: $mostrarApto) { AptoFisicoView() }
    }

    // MARK: - Identidad

    /// Las iniciales con el halo del acento, el nombre y "Running · Intermedio".
    private var identidad: some View {
        HStack(alignment: .center, spacing: TokensEspaciado.e14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Paleta.acentoProfundo, Paleta.superficie],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e2))
                Text(estado.iniciales)
                    .estilo(.unidadHeroe, color: Paleta.acento)
            }
            .frame(width: TokensEspaciado.e56, height: TokensEspaciado.e56)
            .accessibilityLabel(Textos.profileNoPhoto)

            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                Text(estado.nombreCompleto)
                    .estilo(.tituloSeccion)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(deporteYNivel)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Las cuatro filas

    private var filas: some View {
        VStack(spacing: 0) {
            FilaDeAccesoDePerfil(simbolo: "figure.stand", titulo: Textos.profileYourBody,
                                 subtitulo: resumenDelCuerpo) {
                abrirAjustes(en: .datosPersonales)
            }
            divisor
            FilaDeAccesoDePerfil(simbolo: "flag.fill", titulo: Textos.profileGoals,
                                 subtitulo: resumenDeMetas) {
                abrirAjustes(en: .objetivos)
            }
            divisor
            FilaDeAccesoDePerfil(simbolo: "calendar", titulo: Textos.profileDaysAndTime,
                                 subtitulo: resumenDeDias) {
                abrirAjustes(en: .entrenamiento)
            }
            divisor
            FilaDeAccesoDePerfil(simbolo: "cross.case.fill", titulo: Textos.medicalTitle,
                                 subtitulo: resumenDelApto, conAviso: aptoParaMirar) {
                mostrarApto = true
            }
        }
        .tarjeta()
    }

    private var divisor: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(height: TokensEspaciado.e1)
            .padding(.leading, TokensEspaciado.e14 + TokensEspaciado.e40 + TokensEspaciado.e12)
            .accessibilityHidden(true)
    }

    /// Abre Ajustes ya en una página. `AjustesView` lee el ancla en su
    /// `onAppear` y la borra: al volver de la página se cae en la raíz de Ajustes.
    private func abrirAjustes(en pagina: PaginaDeAjustes) {
        AjustesAncla.paginaAlVolver = pagina
        estado.ir(a: .ajustes)
    }

    // MARK: - Los resúmenes

    /// "72 kg · 1,78 m · 33 años", con lo que haya. Sin nada, "Sin completar".
    private var resumenDelCuerpo: String {
        var partes: [String] = []
        if let gramos = estado.perfil?.weightG {
            partes.append(Formato.peso(Int(gramos), unidades: estado.sistemaDeUnidades))
        }
        if let altura { partes.append(altura) }
        if let edad { partes.append(Textos.profileAgeYears(edad)) }
        return partes.isEmpty ? Textos.commonNotSet : partes.joined(separator: " · ")
    }

    /// "Media maratón · faltan 20 semanas": la próxima meta y cuánto falta.
    private var resumenDeMetas: String {
        guard let meta = metasActivas.first ?? flujo.objetivosActivos.first else { return Textos.profileGoalsNoneActive }
        let nombre = TraduccionDelServidor.nombre(de: meta.goal)
        guard let fechaMs = meta.goalDateMs else { return nombre }
        return "\(nombre) · \(cuentaRegresiva(diasRestantes(fechaMs)))"
    }

    /// "faltan 20 semanas" de lejos, "faltan 12 días" de cerca, "es hoy".
    private func cuentaRegresiva(_ dias: Int) -> String {
        switch dias {
        case 0: return Textos.profileCountdownToday
        case 1: return Textos.profileCountdownOneDay
        case 2..<14: return Textos.profileCountdownDays(dias)
        default: return Textos.profileCountdownWeeks(dias / 7)
        }
    }

    /// "Lun, Mié y Vie · 18:30". La hora va si es la misma todos los días.
    private var resumenDeDias: String {
        let dias = (estado.perfil?.trainingDays ?? []).sorted { $0.weekday < $1.weekday }
        guard !dias.isEmpty else { return Textos.commonNotSet }
        let nombres = dias.map { PlanFechas.diaCorto(Int($0.weekday)) }
        let formato = ListFormatter()
        formato.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        let lista = formato.string(from: nombres) ?? nombres.joined(separator: ", ")
        let minutos = Set(dias.map(\.minuteOfDay))
        guard minutos.count == 1, let minuto = minutos.first else { return lista }
        return "\(lista) · \(Formato.hora(minutoDelDia: Int(minuto)))"
    }

    private var resumenDelApto: String {
        switch apto.estado {
        case .sinCargar: return Textos.profileMedicalNone
        case .vigente: return Textos.profileMedicalValid
        case .porVencer(let dias):
            return dias == 0 ? Textos.profileMedicalExpiresToday : Textos.profileMedicalExpiresIn(dias)
        case .vencido: return Textos.profileMedicalExpiredShort
        }
    }

    /// Sin cargar, por vencer o vencido: el punto rojo.
    private var aptoParaMirar: Bool {
        if case .vigente = apto.estado { return false }
        return true
    }

    // MARK: - Auxiliares

    /// Días enteros hasta la fecha de la meta (0 = hoy). La fecha es un día sin hora.
    private func diasRestantes(_ ms: Int64) -> Int {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        let evento = calendario.startOfDay(for: Date(timeIntervalSince1970: Double(ms) / 1000))
        return max(0, calendario.dateComponents([.day], from: hoy, to: evento).day ?? 0)
    }

    /// "1,78 m" o 5′10″.
    private var altura: String? {
        guard let mm = estado.perfil?.heightMm else { return nil }
        switch estado.sistemaDeUnidades {
        case .metrico:
            return "\((Double(mm) / 1000).formatted(.number.precision(.fractionLength(2)))) m"
        case .imperial:
            let pulgadas = Int((Double(mm) / 25.4).rounded())
            return "\(pulgadas / 12)′\(pulgadas % 12)″"
        }
    }

    private var edad: Int? {
        guard let nacimiento = estado.perfil?.birthdateMs else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let cumple = utc.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(nacimiento) / 1000))
        let hoy = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        guard let y = cumple.year, let m = cumple.month, let d = cumple.day,
              let hy = hoy.year, let hm = hoy.month, let hd = hoy.day else { return nil }
        return hy - y - ((hm, hd) < (m, d) ? 1 : 0)
    }

    private var deporteYNivel: String {
        guard let perfil = estado.perfil else { return Textos.commonNotSet }
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
