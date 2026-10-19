import SwiftUI
import TrainerCore

/// `perfil` — foto, datos del cuerpo, deporte y nivel, objetivo y días. El
/// engranaje de arriba a la derecha lleva a `ajustes`.
///
/// Ronda 3: cada bloque dice qué es y qué pasa si lo tocás. La guía de arriba
/// se cierra y el "?" la vuelve a mostrar; los datos del cuerpo explican para
/// qué se usan (`PerfilDatosDelCuerpo.swift`); las metas llevan al plan; y abajo
/// quedan los accesos con ícono, título y subtítulo (`PerfilPiezas.swift`).
struct PerfilView: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var metasActivas: [ObjetivoDeUsuario] = []
    @State private var cargandoMetas = true
    @State private var mostrarApto = false
    @State private var mostrarRacha = false
    @State private var datoElegido: DatoDelCuerpo?
    /// "Completar ahora" en la hoja de un dato: primero se cierra la hoja y, al
    /// terminar de cerrarse, se va a los pasos del alta.
    @State private var completarAlCerrar = false
    @ObservedObject private var apto = AlmacenDeAptoFisico.compartido
    @AppStorage(AcentoPersonalizado.clave) private var acentoGuardado = ""

    private static let claveDeGuia = "guia_perfil"
    /// La lee `RaizHomeView` con `@AppStorage`: en `false`, muestra el recorrido.
    private static let claveDelTour = "tour_visto"

    private var inicioDeHoyMs: Int64 {
        Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                encabezado
                guia
                tarjetaDeIdentidad
                datosDelCuerpo
                if let plan = estado.plan {
                    seccionActividad(plan)
                }
                seccionMetas
                seccionDias
                seccionAccesos
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
        .sheet(item: $datoElegido, onDismiss: completarSiSePidio) { dato in
            DetalleDeDatoDelCuerpo(dato: dato, valor: valor(de: dato), falta: falta(dato)) {
                completarAlCerrar = true
                datoElegido = nil
            }
        }
    }

    // MARK: - Encabezado y guía

    /// "Perfil" grande, como las otras pestañas, el "?" de la guía y el engranaje.
    private var encabezado: some View {
        EncabezadoDePestana(Textos.homeTabPerfil) {
            HStack(spacing: TokensEspaciado.e8) {
                BotonDeAyuda(clave: Self.claveDeGuia)
                BotonCircular("gearshape", etiqueta: Textos.perfilVerAjustes) {
                    Haptico.toque()
                    estado.ir(a: .ajustes)
                }
            }
        }
    }

    private var guia: some View {
        TarjetaDeGuia(
            clave: Self.claveDeGuia,
            titulo: String(localized: "Tu perfil, en un vistazo", comment: "Título de la guía del perfil"),
            puntos: [
                PuntoDeGuia("hand.tap", String(localized: "Tocá peso, altura o edad para ver para qué los usa la app.",
                                                comment: "Guía del perfil")),
                PuntoDeGuia("flag.checkered", String(localized: "Tus metas muestran cuánto falta; tocá una para ver tu plan.",
                                                      comment: "Guía del perfil")),
                PuntoDeGuia("calendar", String(localized: "Los días resaltados son los que elegiste para entrenar.",
                                                comment: "Guía del perfil")),
                PuntoDeGuia("gearshape", String(localized: "En Ajustes cambiás el color, las notificaciones y las unidades.",
                                                 comment: "Guía del perfil")),
            ]
        )
    }

    // MARK: - Identidad

    /// Las iniciales con el halo del acento, el nombre, la píldora de deporte y
    /// nivel, y abajo "Tu color", que lleva a Ajustes.
    private var tarjetaDeIdentidad: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
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

            Rectangle()
                .fill(Paleta.divisor)
                .frame(height: TokensEspaciado.e1)
                .accessibilityHidden(true)

            filaDeColor
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    /// La muestra del acento elegido. Tocarla abre Ajustes, donde se cambia.
    private var filaDeColor: some View {
        Button {
            Haptico.toque()
            estado.ir(a: .ajustes)
        } label: {
            HStack(spacing: TokensEspaciado.e10) {
                Circle()
                    .fill(Paleta.acento)
                    .overlay(Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
                    .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e4)
                    .frame(width: TokensEspaciado.e22, height: TokensEspaciado.e22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(String(localized: "Tu color · \(nombreDelColor)", comment: "Color de acento en el perfil"))
                        .estilo(.tituloCard)
                    Text(String(localized: "Cambiá el color de la app en Ajustes", comment: "Ayuda del color en el perfil"))
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                    .foregroundStyle(Paleta.textoTerciario)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var nombreDelColor: String {
        if acentoGuardado.isEmpty { return AcentoPersonalizado.predeterminado.nombre }
        return AcentoPersonalizado.opcion(paraGuardado: acentoGuardado)?.nombre
            ?? String(localized: "Personalizado", comment: "Color de acento elegido a mano")
    }

    // MARK: - Datos del cuerpo

    /// Peso, altura y edad: tres tarjetas de métrica en fila. Cada una se toca
    /// y explica para qué la usa la app.
    private var datosDelCuerpo: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(String(localized: "Tu cuerpo", comment: "Sección del perfil"),
                                detalle: String(localized: "tocá un dato para saber por qué", comment: "Ayuda de la sección"))
            HStack(spacing: TokensEspaciado.e8) {
                ForEach(DatoDelCuerpo.allCases) { dato in
                    tarjetaDeDato(dato)
                }
            }
        }
    }

    private func tarjetaDeDato(_ dato: DatoDelCuerpo) -> some View {
        Button {
            Haptico.toque()
            datoElegido = dato
        } label: {
            TarjetaMetrica(dato.titulo, valor: valor(de: dato), simbolo: dato.simbolo, destacada: falta(dato))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "info.circle")
                        .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                        .foregroundStyle(Paleta.textoTerciario)
                        .padding(TokensEspaciado.e8)
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(dato.titulo), \(valor(de: dato))"))
        .accessibilityHint(String(localized: "Explica para qué lo usa la app", comment: "Pista de un dato del cuerpo"))
        .accessibilityAddTraits(.isButton)
    }

    private func valor(de dato: DatoDelCuerpo) -> String {
        switch dato {
        case .peso:
            return estado.perfil?.weightG.map { Formato.peso(Int($0), unidades: estado.sistemaDeUnidades) } ?? "—"
        case .altura:
            return altura
        case .edad:
            return edad.map(Textos.perfilAnios) ?? "—"
        }
    }

    private func falta(_ dato: DatoDelCuerpo) -> Bool {
        switch dato {
        case .peso: return estado.perfil?.weightG == nil
        case .altura: return estado.perfil?.heightMm == nil
        case .edad: return estado.perfil?.birthdateMs == nil
        }
    }

    private func completarSiSePidio() {
        guard completarAlCerrar else { return }
        completarAlCerrar = false
        retomarPerfil()
    }

    /// Los mismos pasos del alta, al primer hueco (como el aviso del inicio en
    /// `RaizHomeView`). Si el perfil todavía no llegó, primero se pide.
    private func retomarPerfil() {
        guard flujo.pasoPendienteDelPerfil == nil else { return flujo.retomarPerfil() }
        Task {
            await flujo.cargarPerfil()
            flujo.retomarPerfil()
        }
    }

    // MARK: - Tu actividad

    /// Sólo con plan: la racha y la semana en curso, todo del servidor.
    private func seccionActividad(_ plan: PlanDelHome) -> some View {
        let semanaDeHoy = plan.semanaDeHoy.flatMap { numero in
            plan.bloque.semanas.first { $0.numero == numero }
        }
        return VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(String(localized: "Tu actividad", comment: "Sección del perfil"))
            HStack(spacing: TokensEspaciado.e8) {
                Button {
                    Haptico.toque()
                    mostrarRacha = true
                } label: {
                    TarjetaMetrica(Textos.rachaTitulo, valor: "\(plan.racha.dias)", unidad: Textos.rachaDias,
                                   simbolo: plan.racha.dias > 0 ? "flame.fill" : "flame",
                                   destacada: plan.racha.dias > 0 && plan.racha.activaHoy)
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityHint(String(localized: "Muestra cómo funciona la racha", comment: "Pista de la racha"))

                if let numero = plan.semanaDeHoy, plan.bloque.totalDeSemanas > 0 {
                    botonAlPlan {
                        TarjetaMetrica(String(localized: "Semana", comment: "Semana del plan en el perfil"),
                                       valor: "\(numero)",
                                       unidad: String(localized: "de \(plan.bloque.totalDeSemanas)",
                                                      comment: "Total de semanas del plan"),
                                       simbolo: "calendar")
                    }
                }

                if let semana = semanaDeHoy, semana.metrosPrevistos > 0 {
                    botonAlPlan {
                        TarjetaMetrica(String(localized: "Esta semana", comment: "Distancia de la semana en el perfil"),
                                       valor: Formato.distanciaNumero(semana.metrosHechos, unidades: estado.sistemaDeUnidades),
                                       unidad: String(localized: "de \(Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades))",
                                                      comment: "Distancia prevista de la semana"),
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
        .accessibilityHint(String(localized: "Abre tu plan", comment: "Pista de una tarjeta que lleva al plan"))
    }

    // MARK: - Metas y Objetivos

    private var seccionMetas: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(String(localized: "Metas y objetivos", comment: "Perfil: sección de metas"), accion: String(localized: "+ Gestionar", comment: "Perfil: acción de la sección de metas")) {
                Haptico.toque()
                estado.ir(a: .ajustes)
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
            Text(String(localized: "Buscando tus metas…", comment: "Cargando las metas en el perfil"))
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

            Text("Sin metas activas")
                .estilo(.opcionTitulo)

            Text("Tus metas anteriores ya finalizaron. Definí una nueva meta para comenzar tu próximo plan.")
                .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, TokensEspaciado.e12)

            Button {
                Haptico.toque()
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
                        Text(meta.goalDateMs.map(formatoFecha) ?? "Plan sin fecha fija")
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
        .accessibilityHint(String(localized: "Abre tu plan", comment: "Pista de una tarjeta que lleva al plan"))
    }

    /// "Faltan 12 días" de cerca, "Faltan 9 sem" de lejos.
    private func cuentaRegresiva(_ dias: Int) -> String {
        switch dias {
        case 0: return String(localized: "¡Es hoy!", comment: "Cuenta regresiva de una meta")
        case 1: return String(localized: "Falta 1 día", comment: "Cuenta regresiva de una meta")
        case 2..<14: return String(localized: "Faltan \(dias) días", comment: "Cuenta regresiva de una meta")
        default: return String(localized: "Faltan \(dias / 7) sem", comment: "Cuenta regresiva de una meta, en semanas")
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
            EncabezadoDeSeccion(String(localized: "Días de entrenamiento", comment: "Perfil: sección de días de entrenamiento"),
                                detalle: elegidos > 0
                                    ? String(localized: "\(elegidos) por semana", comment: "Cantidad de días de entrenamiento")
                                    : nil)

            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                HStack(spacing: TokensEspaciado.e6) {
                    ForEach(1...7, id: \.self) { weekday in
                        chipDia(weekday: weekday)
                    }
                }

                if elegidos > 0 {
                    Text(String(localized: "Los días llenos son los que elegiste: tu plan reparte los entrenamientos en ellos, a esa hora.",
                                comment: "Explicación de los días de entrenamiento"))
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(String(localized: "Todavía no elegiste días. Completá tu perfil para que el plan sepa cuándo entrenás.",
                                comment: "Sin días de entrenamiento"))
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                    BotonTonal(String(localized: "Completar perfil", comment: "Botón para completar el perfil")) {
                        Haptico.toque()
                        retomarPerfil()
                    }
                }
            }
            .padding(TokensEspaciado.e14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjeta()
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

    // MARK: - Accesos

    /// Las filas de abajo: apto, ajustes y el recorrido por la app. Cerrar sesión
    /// sigue en Ajustes.
    private var seccionAccesos: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(String(localized: "Más", comment: "Sección de accesos del perfil"))
            VStack(spacing: 0) {
                FilaDeAccesoDePerfil(simbolo: "cross.case.fill",
                                     titulo: String(localized: "Apto físico", comment: "Fila del perfil"),
                                     subtitulo: textoDelApto,
                                     colorDelSubtitulo: colorDelApto) {
                    mostrarApto = true
                }
                separador
                FilaDeAccesoDePerfil(simbolo: "paintpalette",
                                     titulo: String(localized: "Ajustes y color", comment: "Fila del perfil"),
                                     subtitulo: String(localized: "Color, apariencia, notificaciones, unidades y cerrar sesión",
                                                       comment: "Qué hay en Ajustes")) {
                    estado.ir(a: .ajustes)
                }
                separador
                FilaDeAccesoDePerfil(simbolo: "questionmark.circle",
                                     titulo: String(localized: "Cómo funciona Stamina", comment: "Fila del perfil"),
                                     subtitulo: String(localized: "Volvé a ver el recorrido por la app", comment: "Fila del perfil")) {
                    // `RaizHomeView` escucha esta clave con `@AppStorage`: el recorrido aparece al toque.
                    UserDefaults.standard.set(false, forKey: Self.claveDelTour)
                }
            }
            .tarjeta()
        }
    }

    private var separador: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(height: TokensEspaciado.e1)
            .padding(.leading, TokensEspaciado.e14 + TokensEspaciado.e40 + TokensEspaciado.e12)
            .accessibilityHidden(true)
    }

    private var textoDelApto: String {
        switch apto.estado {
        case .sinCargar:
            return String(localized: "Sin cargar · subí foto o PDF", comment: "Estado del apto en el perfil")
        case .vigente(let dias), .porVencer(let dias):
            let fecha = apto.apto?.vence.formatted(date: .abbreviated, time: .omitted) ?? ""
            return String(localized: "Vence el \(fecha) · faltan \(dias) días", comment: "Estado del apto en el perfil")
        case .vencido:
            return String(localized: "Vencido · renovalo", comment: "Estado del apto en el perfil")
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
