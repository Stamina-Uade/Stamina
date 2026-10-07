import SwiftUI
import TrainerCore

/// `ajustes` — avisos, anticipación, unidades, cuenta y privacidad.
///
/// 🛑 Lo que **falta** y bloquea la publicación está anotado, no disimulado:
/// exportar mis datos y borrar mi cuenta son features, no favores (AGENTS.md
/// §8), y hoy no existen. `ESPECIFICACION.md` §8.2 las lista entre los huecos.
struct AjustesView: View {
    @EnvironmentObject private var estado: EstadoHome
    /// Cerrar la sesión es del flujo de entrada, no del Home: es el que sabe
    /// volver a la bienvenida y olvidar lo que quedó en memoria.
    @EnvironmentObject private var flujo: FlujoEntrada

    @AppStorage(ModoApariencia.clave) private var modoApariencia: ModoApariencia = .automatico
    @AppStorage("ajuste_notif_manana") private var notificacionManana = true
    @AppStorage("ajuste_notif_recordatorio_antes") private var notificacionPrevio = true
    @AppStorage("ajuste_notif_calor") private var notificacionCalor = true

    @State private var guardandoUnidades = false
    @State private var errorDeUnidades = false
    @State private var objetivosEnEdicion: [ObjetivoDeUsuario] = []
    @State private var guardandoObjetivos = false
    @State private var errorDeObjetivos = false

    var body: some View {
        VStack(spacing: 0) {
            CabeceraSecundaria(titulo: Textos.ajustesTitulo) {
                estado.volverDeLaPantallaSecundaria()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                    seccion("Apariencia") {
                        selectorDeApariencia
                    }

                    seccion("Notificaciones") {
                        ajustesDeNotificaciones
                    }

                    seccion(Textos.ajustesUnidades) {
                        selectorDeUnidades
                    }

                    seccion("Objetivos de entrenamiento") {
                        editorDeObjetivos
                    }

                    botonDeCerrarSesion

                    Text(Textos.ajustesVersion(versionDeLaApp))
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, TokensEspaciado.e16)
                .padding(.bottom, TokensEspaciado.e36)
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
    }

    private func seccion<Contenido: View>(_ titulo: String,
                                          @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            TituloDeSeccion(titulo)
            contenido()
        }
    }

    private var selectorDeApariencia: some View {
        VStack(spacing: TokensEspaciado.e8) {
            ForEach(ModoApariencia.allCases) { modo in
                let elegido = modo == modoApariencia
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        modoApariencia = modo
                    }
                } label: {
                    HStack(spacing: TokensEspaciado.e12) {
                        Text(icono(de: modo))
                            .font(.system(size: 20))
                            .frame(width: 34, height: 34)
                            .background(elegido ? Paleta.seleccionadoFondo : Paleta.superficieHundida)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(modo.titulo)
                                .estilo(.tituloCard, color: elegido ? Paleta.textoAcento : Paleta.textoPrimario)
                            Text(descripcion(de: modo))
                                .estilo(.notaLegal, color: Paleta.textoTerciario)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        ZStack {
                            Circle()
                                .strokeBorder(elegido ? Paleta.seleccionadoBorde : Paleta.bordeInput, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if elegido {
                                Circle()
                                    .fill(Paleta.acento)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                    .padding(TokensEspaciado.e12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(elegido ? Paleta.seleccionadoFondo.opacity(0.4) : Paleta.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                            .strokeBorder(elegido ? Paleta.seleccionadoBorde : Paleta.bordeSuperficie,
                                          lineWidth: TokensEspaciado.e1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func icono(de modo: ModoApariencia) -> String {
        switch modo {
        case .automatico: return "🌗"
        case .claro: return "☀️"
        case .oscuro: return "🌙"
        }
    }

    private func descripcion(de modo: ModoApariencia) -> String {
        switch modo {
        case .automatico: return "Sigue la apariencia del sistema operativo de tu iPhone"
        case .claro: return "Fondo blanco puro con acentos en violeta legibles bajo la luz solar"
        case .oscuro: return "Fondo negro puro con acentos en verde lima de alto contraste"
        }
    }

    private var ajustesDeNotificaciones: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            Toggle(isOn: $notificacionManana) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aviso de la mañana")
                        .estilo(.tituloCard, color: Paleta.textoPrimario)
                    Text("Buen día, hoy es día de entreno. Hoy a las ... toca hacer ...")
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Paleta.interruptorActivo)

            Divider().background(Paleta.divisor)

            Toggle(isOn: $notificacionPrevio) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recordatorio previo")
                        .estilo(.tituloCard, color: Paleta.textoPrimario)
                    Text("30 minutos antes de la hora definida para el entrenamiento")
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Paleta.interruptorActivo)

            Divider().background(Paleta.divisor)
            Toggle(isOn: $notificacionCalor) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aviso de calor")
                        .estilo(.tituloCard, color: Paleta.textoPrimario)
                    Text("Si el pronóstico supera los 30 °C antes de entrenar, te avisamos por la mañana.")
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                }
            }
            .tint(Paleta.interruptorActivo)
            Link("Datos meteorológicos: MET Norway (CC BY 4.0)",
                 destination: URL(string: "https://api.met.no/weatherapi/locationforecast/2.0/")!)
                .font(.footnote)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity)
        .tarjeta(radio: TokensRadio.boton)
    }

    private var selectorDeUnidades: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            HStack(spacing: TokensEspaciado.e6) {
                ForEach(SistemaDeUnidades.allCases) { sistema in
                    let elegido = sistema == estado.sistemaDeUnidades
                    Button {
                        guardandoUnidades = true
                        Task {
                            if await flujo.guardarUnidades(sistema) {
                                estado.sistemaDeUnidades = sistema
                            } else {
                                errorDeUnidades = true
                            }
                            guardandoUnidades = false
                        }
                    } label: {
                        Text(sistema == .metrico ? Textos.ajustesMetrico : Textos.ajustesImperial)
                            .estilo(.tituloCard, color: elegido ? Paleta.textoAcento : Paleta.textoSecundario)
                            .frame(maxWidth: .infinity)
                            .frame(height: TokensTamano.objetivoTactilMinimo)
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
            }
            // AGENTS.md §10: métrico e imperial son preferencia de PRESENTACIÓN.
            Text(Textos.ajustesUnidadesDetalle)
                .estilo(.notaLegal, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity)
        .tarjeta(radio: TokensRadio.boton)
    }

    private var editorDeObjetivos: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            Text("\(objetivosEnEdicion.count) objetivos activos")
                .estilo(.labelCampo, color: Paleta.textoSecundario)
            if objetivosEnEdicion.isEmpty {
                Text("Elegí un objetivo para que podamos armar tu primer plan.")
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
            }
            ForEach(objetivosEnEdicion.indices, id: \.self) { indice in
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    HStack {
                        Text(indice == 0 ? "Plan principal" : "Plan \(indice + 1)")
                            .estilo(.labelCampo, color: Paleta.textoTerciario)
                        Spacer()
                        Button("Quitar") { objetivosEnEdicion.remove(at: indice) }
                            .foregroundStyle(Paleta.error)
                    }
                    Menu {
                        ForEach(Objetivo.allCases, id: \.self) { objetivo in
                            Button(nombreDelObjetivo(objetivo)) {
                                let anterior = objetivosEnEdicion[indice]
                                objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                                    id: anterior.id, goal: objetivo, goalDateMs: anterior.goalDateMs)
                            }
                        }
                    } label: {
                        HStack {
                            Text(nombreDelObjetivo(objetivosEnEdicion[indice].goal))
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                    }
                    if let fechaMs = objetivosEnEdicion[indice].goalDateMs {
                        DatePicker("Fecha del evento", selection: Binding(
                            get: { fechaLocalDeObjetivo(fechaMs) },
                            set: { nueva in
                                let anterior = objetivosEnEdicion[indice]
                                objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                                    id: anterior.id, goal: anterior.goal,
                                    goalDateMs: DatosRegistro.fechaDelCalendarioEnMs(nueva, zona: .current))
                            }), displayedComponents: .date)
                        Button("Quitar fecha") {
                            let anterior = objetivosEnEdicion[indice]
                            objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                                id: anterior.id, goal: anterior.goal, goalDateMs: nil)
                        }
                    } else {
                        Button("Agregar fecha del evento") {
                            let anterior = objetivosEnEdicion[indice]
                            objetivosEnEdicion[indice] = ObjetivoDeUsuario(
                                id: anterior.id, goal: anterior.goal,
                                goalDateMs: DatosRegistro.fechaDelCalendarioEnMs(Date(), zona: .current))
                        }
                    }
                }
                .padding(TokensEspaciado.e12)
                .background(Paleta.superficieHundida)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda))
            }
            if objetivosEnEdicion.count < 10 {
                Menu {
                    ForEach(Objetivo.allCases, id: \.self) { objetivo in
                        Button(nombreDelObjetivo(objetivo)) {
                            objetivosEnEdicion.append(ObjetivoDeUsuario(
                                id: objetivosEnEdicion.isEmpty ? "principal" : "",
                                goal: objetivo, goalDateMs: nil))
                        }
                    }
                } label: {
                    Label("Agregar objetivo", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo)
                }
            }
            Button("Guardar objetivos") {
                guardandoObjetivos = true
                let normalizados = objetivosEnEdicion.enumerated().map { indice, valor in
                    ObjetivoDeUsuario(id: indice == 0 ? "principal" :
                        (valor.id == "principal" ? "" : valor.id),
                        goal: valor.goal, goalDateMs: valor.goalDateMs)
                }
                Task {
                    if await flujo.guardarObjetivos(normalizados) {
                        objetivosEnEdicion = flujo.objetivosActivos
                        await estado.actualizar()
                    } else {
                        errorDeObjetivos = true
                    }
                    guardandoObjetivos = false
                }
            }
            .disabled(guardandoObjetivos)
            .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity)
        .tarjeta(radio: TokensRadio.boton)
    }

    private func fechaLocalDeObjetivo(_ ms: Int64) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let dia = utc.dateComponents([.year, .month, .day],
                                     from: Date(timeIntervalSince1970: Double(ms) / 1000))
        return Calendar.current.date(from: DateComponents(year: dia.year, month: dia.month, day: dia.day))
            ?? Date(timeIntervalSince1970: Double(ms) / 1000)
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

    private var botonDeCerrarSesion: some View {
        Button {
            // El llavero se borra antes de salir, sin esperar a la red: sin señal
            // las credenciales se van igual, y `POST /auth/logout` sale por detrás
            // (`FlujoEntrada.cerrarSesion`).
            Task { await flujo.cerrarSesion() }
        } label: {
            Text(Textos.ajustesCerrarSesion)
                .estilo(.tituloCard, color: Paleta.error)
                .frame(maxWidth: .infinity)
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                .background(Paleta.errorFondo)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                        .strokeBorder(Paleta.errorBorde, lineWidth: TokensEspaciado.e1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
    }

    private var versionDeLaApp: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9"
    }
}
