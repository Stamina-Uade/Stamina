import SwiftUI
import TrainerCore

/// `ajustes` — apariencia (modo y color), avisos, unidades, objetivos, ayuda y
/// cuenta. Cada ajuste dice qué hace: las piezas están en `AjustesPiezas.swift`,
/// el modo en `AjustesApariencia.swift` y el color en `AjustesColor.swift`.
///
/// 🛑 Lo que **falta** y bloquea la publicación está anotado, no disimulado:
/// exportar mis datos y borrar mi cuenta son features, no favores (AGENTS.md
/// §8), y hoy no existen. `ESPECIFICACION.md` §8.2 las lista entre los huecos.
struct AjustesView: View {
    @EnvironmentObject private var estado: EstadoHome
    /// Cerrar la sesión es del flujo de entrada, no del Home: es el que sabe
    /// volver a la bienvenida y olvidar lo que quedó en memoria.
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    @AppStorage(ModoApariencia.clave) private var modoApariencia: ModoApariencia = ModoApariencia.predeterminado
    @AppStorage("ajuste_notif_manana") private var notificacionManana = true
    @AppStorage("ajuste_notif_recordatorio_antes") private var notificacionPrevio = true
    @AppStorage("ajuste_notif_calor") private var notificacionCalor = true

    @State private var guardandoUnidades = false
    @State private var unidadEnCurso: SistemaDeUnidades?
    @State private var errorDeUnidades = false
    @State private var objetivosEnEdicion: [ObjetivoDeUsuario] = []
    @State private var guardandoObjetivos = false
    @State private var errorDeObjetivos = false
    @State private var confirmandoCierre = false
    @State private var guiasRestablecidas = false

    private static let claveDeLaGuia = "guia_ajustes"

    /// Lo que "Ver de nuevo cómo funciona Stamina" vuelve a mostrar: la guía de
    /// cada pestaña y el recorrido de bienvenida (`tour_visto`).
    private static let clavesDeAyuda = [
        "guia_inicio", "guia_plan", "guia_historial", "guia_perfil", "guia_ajustes", "tour_visto",
    ]

    var body: some View {
        VStack(spacing: 0) {
            CabeceraSecundaria(titulo: Textos.ajustesTitulo) {
                estado.volverDeLaPantallaSecundaria()
            }
            .overlay(alignment: .trailing) {
                BotonDeAyuda(clave: Self.claveDeLaGuia)
                    .padding(.trailing, TokensEspaciado.e16)
                    .padding(.bottom, TokensEspaciado.e8)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                        guia

                        AjustesRotulo(String(localized: "Apariencia", comment: "Ajustes: grupo"))
                        grupoModo
                        grupoColor
                            .id(AjustesAncla.color)

                        AjustesRotulo(String(localized: "Avisos", comment: "Ajustes: grupo"))
                        grupoNotificaciones

                        AjustesRotulo(String(localized: "Entrenamiento", comment: "Ajustes: grupo"))
                        grupoUnidades
                        grupoObjetivos

                        AjustesRotulo(String(localized: "Ayuda", comment: "Ajustes: grupo"))
                        filaVerDeNuevo

                        AjustesRotulo(Textos.ajustesCuenta)
                        grupoCuenta

                        Text(Textos.ajustesVersion(versionDeLaApp))
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                            .frame(maxWidth: .infinity)
                            .padding(.top, TokensEspaciado.e8)
                    }
                    .padding(.horizontal, TokensEspaciado.e16)
                    .padding(.top, TokensEspaciado.e4)
                    .padding(.bottom, TokensEspaciado.e36)
                }
                .onAppear { volverAlAncla(proxy) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: notificacionManana) { _ in estado.reprogramarRecordatorios() }
        .onChange(of: notificacionPrevio) { _ in estado.reprogramarRecordatorios() }
        .onChange(of: notificacionCalor) { _ in estado.reprogramarRecordatorios() }
        .task {
            await flujo.cargarObjetivos()
            let inicioDeHoyMs = Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
            objetivosEnEdicion = flujo.objetivosActivos.filter { obj in
                guard let f = obj.goalDateMs else { return true }
                return f >= inicioDeHoyMs
            }
        }
        .alert(Textos.ajustesUnidades, isPresented: $errorDeUnidades) {
            Button(Textos.comunListo, role: .cancel) {}
        } message: {
            Text(flujo.errorVisible ?? Textos.ajustesUnidadesDetalle)
        }
        .alert("No se guardaron los objetivos", isPresented: $errorDeObjetivos) {
            Button(Textos.comunListo, role: .cancel) {}
        } message: {
            Text(flujo.errorVisible ?? "Revisá la conexión e intentá de nuevo.")
        }
        .confirmationDialog(String(localized: "¿Cerrar la sesión?", comment: "Ajustes: confirmar el cierre de sesión"),
                            isPresented: $confirmandoCierre, titleVisibility: .visible) {
            Button(Textos.ajustesCerrarSesion, role: .destructive) {
                // El llavero se borra antes de salir, sin esperar a la red: sin señal
                // las credenciales se van igual, y `POST /auth/logout` sale por detrás
                // (`FlujoEntrada.cerrarSesion`).
                Task { await flujo.cerrarSesion() }
            }
            Button(Textos.comunCancelar, role: .cancel) {}
        } message: {
            Text(String(localized: "Vas a volver a la pantalla de bienvenida y para usar Stamina tenés que entrar de nuevo.",
                        comment: "Ajustes: qué pasa al cerrar la sesión"))
        }
    }

    /// Cambiar el color re-crea el Home y el scroll vuelve arriba: si el cambio
    /// salió de acá, se vuelve al selector de color.
    private func volverAlAncla(_ proxy: ScrollViewProxy) {
        guard let ancla = AjustesAncla.alVolver else { return }
        AjustesAncla.alVolver = nil
        DispatchQueue.main.async {
            proxy.scrollTo(ancla, anchor: .top)
        }
    }

    // MARK: - Guía

    private var guia: some View {
        TarjetaDeGuia(
            clave: Self.claveDeLaGuia,
            titulo: String(localized: "Acá dejás Stamina a tu gusto", comment: "Guía de Ajustes: título"),
            puntos: [
                PuntoDeGuia("paintpalette.fill",
                            String(localized: "Apariencia: modo día o noche y el color de toda la app.",
                                   comment: "Guía de Ajustes")),
                PuntoDeGuia("bell.badge.fill",
                            String(localized: "Avisos: qué te recordamos y cuándo. Cada uno se apaga solo.",
                                   comment: "Guía de Ajustes")),
                PuntoDeGuia("flag.checkered",
                            String(localized: "Objetivos: tu meta y la fecha del evento. El plan se arma con eso.",
                                   comment: "Guía de Ajustes")),
                PuntoDeGuia("checkmark.circle",
                            String(localized: "Todo se guarda al tocarlo, salvo los objetivos: esos llevan Guardar.",
                                   comment: "Guía de Ajustes")),
            ])
    }

    // MARK: - Apariencia

    private var grupoModo: some View {
        AjustesGrupo(String(localized: "Modo", comment: "Ajustes: modo de apariencia"),
                     simbolo: "circle.lefthalf.filled",
                     explicacion: String(localized: "Claro u oscuro. Cambia los fondos de todas las pantallas.",
                                         comment: "Ajustes: qué hace el modo de apariencia")) {
            AjustesSelectorDeModo(modo: $modoApariencia)
        }
    }

    private var grupoColor: some View {
        AjustesGrupo(String(localized: "Color de la app", comment: "Ajustes: color de acento"),
                     simbolo: "paintpalette.fill",
                     explicacion: String(localized: "El de los botones, la barra y lo que está activo. Se aplica al tocar.",
                                         comment: "Ajustes: qué hace el color de la app")) {
            AjustesSelectorDeColor()
        }
    }

    // MARK: - Avisos

    private var grupoNotificaciones: some View {
        AjustesGrupo(String(localized: "Notificaciones", comment: "Ajustes: grupo de avisos"),
                     simbolo: "bell.badge.fill",
                     explicacion: String(localized: "Lo que Stamina te avisa en el iPhone. Prendé sólo los que te sirvan.",
                                         comment: "Ajustes: qué hacen las notificaciones")) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                AjustesFilaInterruptor(
                    simbolo: "sunrise.fill",
                    titulo: String(localized: "Aviso de la mañana"),
                    detalle: String(localized: "Los días de entreno, a primera hora: qué toca hacer hoy y a qué hora.",
                                    comment: "Ajustes: qué hace el aviso de la mañana"),
                    encendido: $notificacionManana)

                Divider().background(Paleta.divisor)

                AjustesFilaInterruptor(
                    simbolo: "alarm.fill",
                    titulo: String(localized: "Recordatorio previo"),
                    detalle: String(localized: "30 minutos antes de la hora definida para el entrenamiento"),
                    encendido: $notificacionPrevio)

                Divider().background(Paleta.divisor)

                AjustesFilaInterruptor(
                    simbolo: "thermometer.sun.fill",
                    titulo: String(localized: "Aviso de calor"),
                    detalle: String(localized: "Si el pronóstico supera los 30 °C antes de entrenar, te avisamos por la mañana."),
                    encendido: $notificacionCalor)

                Link("Datos meteorológicos: MET Norway (CC BY 4.0)",
                     destination: URL(string: "https://api.met.no/weatherapi/locationforecast/2.0/")!)
                    .estilo(.notaLegal, color: Paleta.textoAcento)
                    .padding(.leading, TokensEspaciado.e34 + TokensEspaciado.e12)
            }
        }
    }

    // MARK: - Unidades

    private var grupoUnidades: some View {
        AjustesGrupo(Textos.ajustesUnidades,
                     simbolo: "ruler",
                     explicacion: String(localized: "Kilómetros o millas, kilos o libras, en toda la app.",
                                         comment: "Ajustes: qué hacen las unidades")) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                HStack(spacing: TokensEspaciado.e6) {
                    ForEach(SistemaDeUnidades.allCases) { sistema in
                        botonDeUnidad(sistema)
                    }
                }
                // AGENTS.md §10: métrico e imperial son preferencia de PRESENTACIÓN.
                Text(Textos.ajustesUnidadesDetalle)
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func botonDeUnidad(_ sistema: SistemaDeUnidades) -> some View {
        let elegido = sistema == estado.sistemaDeUnidades
        return Button {
            Haptico.seleccion()
            guardandoUnidades = true
            unidadEnCurso = sistema
            Task {
                if await flujo.guardarUnidades(sistema) {
                    estado.sistemaDeUnidades = sistema
                } else {
                    errorDeUnidades = true
                }
                guardandoUnidades = false
                unidadEnCurso = nil
            }
        } label: {
            VStack(spacing: TokensEspaciado.e2) {
                HStack(spacing: TokensEspaciado.e6) {
                    if unidadEnCurso == sistema {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Paleta.acento)
                    }
                    Text(sistema == .metrico ? Textos.ajustesMetrico : Textos.ajustesImperial)
                        .estilo(.tituloCard, color: elegido ? Paleta.textoAcento : Paleta.textoSecundario)
                }
                Text(verbatim: sistema == .metrico ? "km · kg" : "mi · lb")
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: TokensTamano.objetivoTactilMinimo + TokensEspaciado.e8)
            .background(elegido ? Paleta.seleccionadoFondo : Paleta.superficieHundida)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous)
                    .strokeBorder(elegido ? Paleta.seleccionadoBorde : Color.clear,
                                  lineWidth: TokensEspaciado.e1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .disabled(guardandoUnidades)
        .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Objetivos

    private var grupoObjetivos: some View {
        AjustesGrupo(String(localized: "Objetivos de entrenamiento", comment: "Ajustes: grupo"),
                     simbolo: "flag.checkered",
                     explicacion: String(localized: "Para qué entrenás. El plan se arma con el principal; tocá Guardar al terminar.",
                                         comment: "Ajustes: qué hacen los objetivos"),
                     detalle: String(localized: "\(objetivosEnEdicion.count) activos",
                                     comment: "Ajustes: cuántos objetivos hay")) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                if objetivosEnEdicion.isEmpty {
                    Text("Elegí un objetivo para que podamos armar tu primer plan.")
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                }
                ForEach(objetivosEnEdicion.indices, id: \.self) { indice in
                    tarjetaDeObjetivo(indice)
                }
                if objetivosEnEdicion.count < 10 {
                    menuAgregarObjetivo
                }
                BotonTonal("Guardar objetivos") { guardarObjetivos() }
                    .disabled(guardandoObjetivos)
                    .opacity(guardandoObjetivos ? 0.5 : 1)
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
                    objetivosEnEdicion.remove(at: indice)
                } label: {
                    Label {
                        Text("Quitar").estilo(.tituloCard, color: Paleta.error)
                    } icon: {
                        Image(systemName: "trash")
                            .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                            .foregroundStyle(Paleta.error)
                    }
                    .objetivoTactilAlto()
                }
                .buttonStyle(EstiloPresionado())
            }
            Menu {
                ForEach(Objetivo.allCases, id: \.self) { objetivo in
                    Button(TraduccionDelServidor.nombre(de: objetivo)) {
                        let anterior = objetivosEnEdicion[indice]
                        objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                            id: anterior.id, goal: objetivo, goalDateMs: anterior.goalDateMs)
                    }
                }
            } label: {
                HStack {
                    Text(TraduccionDelServidor.nombre(de: objetivosEnEdicion[indice].goal))
                        .estilo(.opcionTitulo)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                }
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            }
            if let fechaMs = objetivosEnEdicion[indice].goalDateMs {
                DatePicker(selection: Binding(
                    get: { fechaLocalDeObjetivo(fechaMs) },
                    set: { nueva in
                        let anterior = objetivosEnEdicion[indice]
                        objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                            id: anterior.id, goal: anterior.goal,
                            goalDateMs: DatosRegistro.fechaDelCalendarioEnMs(nueva, zona: .current))
                    }), displayedComponents: .date) {
                    Text("Fecha del evento").estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                }
                .tint(Paleta.acento)
                Button {
                    let anterior = objetivosEnEdicion[indice]
                    objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                        id: anterior.id, goal: anterior.goal, goalDateMs: nil)
                } label: {
                    Text("Quitar fecha").estilo(.tituloCard, color: Paleta.textoSecundario)
                        .objetivoTactilAlto()
                }
                .buttonStyle(EstiloPresionado())
            } else {
                Button {
                    let anterior = objetivosEnEdicion[indice]
                    objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                        id: anterior.id, goal: anterior.goal,
                        goalDateMs: DatosRegistro.fechaDelCalendarioEnMs(Date(), zona: .current))
                } label: {
                    Label {
                        Text("Agregar fecha del evento").estilo(.tituloCard, color: Paleta.textoAcento)
                    } icon: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                            .foregroundStyle(Paleta.acento)
                    }
                    .objetivoTactilAlto()
                }
                .buttonStyle(EstiloPresionado())
            }
        }
        .padding(TokensEspaciado.e12)
        .background(Paleta.superficieHundida)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
                .strokeBorder(indice == 0 ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                              lineWidth: TokensEspaciado.e1)
        )
    }

    private var menuAgregarObjetivo: some View {
        Menu {
            ForEach(Objetivo.allCases, id: \.self) { objetivo in
                Button(TraduccionDelServidor.nombre(de: objetivo)) {
                    objetivosEnEdicion.append(ObjetivoDeUsuario(
                        id: objetivosEnEdicion.isEmpty ? "principal" : "",
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

    private func guardarObjetivos() {
        guardandoObjetivos = true
        let normalizados = objetivosEnEdicion.enumerated().map { indice, valor in
            ObjetivoDeUsuario(id: indice == 0 ? "principal" :
                (valor.id == "principal" ? "" : valor.id),
                goal: valor.goal, goalDateMs: valor.goalDateMs)
        }
        Task {
            if await flujo.guardarObjetivos(normalizados) {
                Haptico.exito()
                objetivosEnEdicion = flujo.objetivosActivos
                await estado.actualizar()
            } else {
                errorDeObjetivos = true
            }
            guardandoObjetivos = false
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

    // MARK: - Ayuda

    private var filaVerDeNuevo: some View {
        AjustesFilaDeAccion(
            simbolo: "sparkles",
            titulo: String(localized: "Ver de nuevo cómo funciona Stamina", comment: "Ajustes: volver a mostrar las guías"),
            detalle: guiasRestablecidas
                ? String(localized: "Listo: las guías vuelven a aparecer en cada pestaña.",
                         comment: "Ajustes: guías restablecidas")
                : String(localized: "Abre otra vez el recorrido por la app y vuelven las guías de cada pestaña.",
                         comment: "Ajustes: qué hace volver a ver las guías"),
            simboloFinal: guiasRestablecidas ? "checkmark.circle.fill" : "chevron.right"
        ) {
            restablecerGuias()
        }
    }

    private func restablecerGuias() {
        Haptico.exito()
        withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.media)) {
            for clave in Self.clavesDeAyuda {
                UserDefaults.standard.set(false, forKey: clave)
            }
            guiasRestablecidas = true
        }
    }

    // MARK: - Cuenta

    private var grupoCuenta: some View {
        AjustesGrupo(String(localized: "Sesión en este iPhone", comment: "Ajustes: grupo de la sesión"),
                     simbolo: "rectangle.portrait.and.arrow.right",
                     explicacion: String(localized: "Salís de tu cuenta en este teléfono. Te pedimos confirmarlo antes.",
                                         comment: "Ajustes: qué hace cerrar sesión"),
                     tono: .alerta) {
            Button {
                Haptico.toque()
                confirmandoCierre = true
            } label: {
                Text(Textos.ajustesCerrarSesion)
                    .estilo(.botonPrimario, color: Paleta.error)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: TokensTamano.botonPrimario)
                    .background(Paleta.errorFondo)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Paleta.errorBorde, lineWidth: TokensEspaciado.e1))
                    .contentShape(Capsule())
            }
            .buttonStyle(EstiloPresionado())
        }
    }

    private var versionDeLaApp: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9"
    }
}
