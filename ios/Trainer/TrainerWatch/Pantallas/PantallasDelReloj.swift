import SwiftUI
import MapKit
import TrainerCore
#if os(watchOS)
import WatchKit
#endif

private struct IconoEnCursoReloj: View {
    let simbolo: String
    let triatlon: Bool
    let tamano: CGFloat
    let color: Color

    var body: some View {
        Group {
            if triatlon {
                IconoTriatlon(color: color).frame(width: tamano, height: tamano)
            } else {
                Image(systemName: simbolo)
                    .font(.system(size: tamano, weight: .bold))
                    .foregroundStyle(color)
            }
        }
    }
}

// =============================================================================
// Las pantallas de la v1 del reloj (decisión 0003 y ajustes posteriores).
//
// Lo que NO está, y es deliberado:
//
// - `animo` (mensaje de ánimo de un contacto) queda **fuera de la v1 entera**.
// - De `abrir` se van los toggles de compartir por deporte.
// - De `controles` se va "compartir ubicación": de 6 botones a 5.
// - De `mapa` se va "quién te está viendo" —avatares y contador—.
// - De `ajustes` se van compartir y ánimos: de 4 toggles a 2.
//
// Los cinco recortes son la misma decisión: compartir ubicación en vivo expone
// lo que AGENTS.md §8 marca como el dato más delicado del producto —*los puntos
// de inicio y fin de una carrera son la casa de alguien*—, y se reconsidera
// cuando exista una decisión de privacidad escrita, no antes.
//
// Reglas del reloj que gobiernan todas estas pantallas (§10.2):
// interacción **de un dedo y sin mirar**, objetivos grandes, cero formularios,
// y la batería como requisito funcional (fondo negro puro).
// =============================================================================

struct RaizReloj: View {
    @StateObject private var estado = EstadoReloj()

    var body: some View {
        // El color que llega del teléfono re-crea SÓLO el contenido: `estado`
        // (la salida en curso) vive arriba y no se reinicia.
        contenido
            .redibujoConAcentoDelReloj()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PaletaReloj.fondo)
            .environmentObject(estado)
            .overlay {
                if let aviso = estado.avisoDeAvituallamiento {
                    AlertaEntrenamientoCompletaView(aviso: aviso) {
                        estado.cerrarAvisoDeAvituallamiento()
                    }
                    .zIndex(30)
                }
            }
    }

    @ViewBuilder
    private var contenido: some View {
        if !estado.estaAutenticado && !estado.corriendo {
            SinTelefonoView()
        } else if estado.cuentaRegresivaActiva {
            VistaCuentaRegresiva {
                estado.completarCuentaRegresiva()
            }
            .ignoresSafeArea()
        } else {
            switch estado.pantalla {
            case .abrir:        PortadaRelojView()
            case .metricas, .controles, .musica, .mapa, .parciales:
                                CarruselEntrenamientoRelojView()
            case .rutina:       RutinaView()
            case .avisos:       AvisosView()
            case .ajustes:      AjustesDeSesionView()
            case .confirmarFinalizacion: ConfirmarFinalizacionView()
            case .sinMovimiento: SinMovimientoView()
            case .resumen:      ResumenView()
            case .gimnasio:     GimnasioRelojView()
            case .resumenGimnasio: ResumenGimnasioRelojView()
            case .sinTelefono:  SinTelefonoView()
            }
        }
    }
}

// MARK: - `abrir`

/// La portada tiene dos páginas horizontales suaves con TabView.
/// Los ajustes están a la izquierda (tag 0) y los deportes/gimnasio a la derecha (tag 1, por defecto).
struct PortadaRelojView: View {
    @State private var pagina = 1

    var body: some View {
        TabView(selection: $pagina) {
            AjustesInicialesView()
                .tag(0)

            AbrirView()
                .tag(1)
        }
        .tabViewStyle(.page)
    }
}

/// Empezar un entrenamiento: Objetivo de hoy (gimnasio/rutina), deportes en tarjetas
/// rectangulares con iconos de igual tamaño, y botón para compartir ubicación.
struct OpcionDeporteReloj: Identifiable {
    let id: String
    let deporte: DeporteDeSesion
    let esInterior: Bool
    let nombre: String
    let icono: String
}

/// Empezar un entrenamiento: Objetivo de hoy (rutina o salida planificada), deportes
/// divididos en exterior e interior con iconos bien diferenciados, y cuenta regresiva 3-2-1.
struct AbrirView: View {
    @EnvironmentObject private var estado: EstadoReloj

    private let deportes: [OpcionDeporteReloj] = [
        OpcionDeporteReloj(id: "run-ext", deporte: .running, esInterior: false,
                           nombre: TextosReloj.startOptionRunOutdoor, icono: "figure.run"),
        OpcionDeporteReloj(id: "bike-ext", deporte: .ciclismo, esInterior: false,
                           nombre: TextosReloj.startOptionBikeOutdoor, icono: "bicycle"),
        OpcionDeporteReloj(id: "run-int", deporte: .running, esInterior: true,
                           nombre: TextosReloj.startOptionRunIndoor, icono: "figure.run.treadmill"),
        OpcionDeporteReloj(id: "bike-int", deporte: .ciclismo, esInterior: true,
                           nombre: TextosReloj.startOptionBikeIndoor, icono: "figure.indoor.cycle"),
        OpcionDeporteReloj(id: "walk-ext", deporte: .trekking, esInterior: false,
                           nombre: TextosReloj.startOptionWalkOutdoor, icono: "figure.walk"),
        OpcionDeporteReloj(id: "walk-int", deporte: .trekking, esInterior: true,
                           nombre: TextosReloj.startOptionWalkIndoor, icono: "figure.walk.treadmill"),
        OpcionDeporteReloj(id: "swim-ext", deporte: .natacion, esInterior: false,
                           nombre: TextosReloj.startOptionSwimPool, icono: "figure.pool.swim"),
        OpcionDeporteReloj(id: "triatlon", deporte: .natacion, esInterior: false,
                           nombre: TextosReloj.startOptionTriathlon, icono: "figure.mixed.cardio")
    ]

    /// Lo que deja elegir `MVP` (hoy: sólo carrera exterior e interior). Los
    /// demás deportes siguen definidos arriba y vuelven con `MVP.soloRunning = false`.
    private var deportesVisibles: [OpcionDeporteReloj] {
        deportes.filter { opcion in
            let esTriatlon = opcion.id == "triatlon"
            return esTriatlon ? MVP.permite(.triatlon) : MVP.permite(opcion.deporte)
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e8)) {
                // 1. Objetivo de hoy (oculto completamente si hoy es día de descanso)
                if !estado.esDiaDeDescanso && (estado.sesionCardioPlanificada != nil || estado.tieneGimnasioHoy) {
                    Text(TextosReloj.startTodayGoal.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.textoSecundario)
                        .tracking(0.6)

                    if let sesionCardio = estado.sesionCardioPlanificada {
                        tarjetaEntrenamientoDeHoy(sesionCardio)
                    }
                    if estado.tieneGimnasioHoy {
                        tarjetaGimnasio()
                    }
                }

                // 2. Elegí un deporte
                Text(TextosReloj.startChooseSport.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PaletaReloj.textoSecundario)
                    .tracking(0.6)
                    .padding(.top, TokensEspaciado.e4)

                ForEach(deportesVisibles) { opcion in
                    tarjeta(opcion)
                }
            }
            .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e16))
            .padding(.top, PaletaReloj.puntosDeDiseno(TokensEspaciado.e8))
            .padding(.bottom, TokensEspaciado.e20)
        }
        .scrollIndicators(.hidden)
    }

    private func tituloCortoCardio(para tipo: String) -> String {
        let limpio = Formato.limpiarTituloEvento(tipo, enTriatlon: estado.esTriatlon)
        var texto = limpio
        // Quitar paréntesis y lo de adentro como (168 min), (90 min), (45m), etc.
        texto = texto.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
        // Quitar dos puntos ":"
        texto = texto.replacingOccurrences(of: ":", with: "")
        // Quitar puntos suspensivos y signos de exclamación agregados
        texto = texto.replacingOccurrences(of: "...", with: "")
        texto = texto.replacingOccurrences(of: "…", with: "")
        texto = texto.replacingOccurrences(of: "¡", with: "")
        texto = texto.replacingOccurrences(of: "!", with: "")
        // Quitar prefijos comunes redundantes
        let prefijos = ["Entrenamiento de ", "Sesión de ", "Rutina de ", "Día de ", "Objetivo ", "Tu objetivo "]
        for p in prefijos {
            if texto.lowercased().hasPrefix(p.lowercased()) {
                texto = String(texto.dropFirst(p.count))
            }
        }
        // Quitar espacios múltiples y recortar
        texto = texto.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        texto = texto.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r:;·-.,¡!…"))
        return texto.isEmpty ? limpio : texto
    }

    private func iconoTarjeta(simbolo: String, color: Color) -> some View {
        Group {
            if simbolo == "figure.mixed.cardio" {
                IconoTriatlon(color: color)
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: simbolo)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private func tarjetaEntrenamientoDeHoy(_ sesion: SesionCompartida) -> some View {
        Button {
            // MVP sólo running: no se deduce triatlón del título.
            let esTri = MVP.permite(.triatlon) &&
                (sesion.tipo.lowercased().contains("triatl") || sesion.tipo.lowercased().contains("ironman"))
            let dep: DeporteDeSesion = esTri ? .natacion : deporteDesdeTipo(sesion.tipo)
            let interior = sesion.tipo.lowercased().contains("interior") || sesion.tipo.lowercased().contains("cinta")
            estado.prepararInicioConCuentaRegresiva(
                deporte: dep,
                esInterior: interior,
                objetivoMetros: sesion.distanciaMetros,
                esTriatlon: esTri,
                icono: simbolo(para: sesion.tipo)
            )
        } label: {
            HStack(spacing: 12) {
                iconoTarjeta(simbolo: simbolo(para: sesion.tipo),
                             color: estado.objetivoHoyCumplido ? Color.green : PaletaReloj.acento)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(tituloCortoCardio(para: sesion.tipo))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(PaletaReloj.textoPrimario)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        if estado.objetivoHoyCumplido {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.green)
                        }
                    }

                    if estado.objetivoHoyCumplido {
                        let metros = estado.distanciaEntrenoHoyMetros > 0 ? estado.distanciaEntrenoHoyMetros : (sesion.distanciaMetros ?? 0)
                        Text(TextosReloj.startGoalCompletedDistance(Formato.distancia(metros, unidades: estado.sistemaDeUnidades, decimales: 2)))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.green)
                    } else if let metros = sesion.distanciaMetros, metros > 0 {
                        Text(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PaletaReloj.acento)
                    } else {
                        Text(TextosReloj.startBegin)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PaletaReloj.acento)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PaletaReloj.textoSecundario.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(PaletaReloj.superficie)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(estado.objetivoHoyCumplido ? Color.green.opacity(0.5) : PaletaReloj.acento.opacity(0.6), lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tarjetaGimnasio() -> some View {
        Button {
            estado.ir(a: .gimnasio)
        } label: {
            HStack(spacing: 12) {
                iconoTarjeta(simbolo: "dumbbell.fill", color: PaletaReloj.acento)

                VStack(alignment: .leading, spacing: 2) {
                    Text(TextosReloj.sportGym)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    let totalSeries = estado.rutina.reduce(0) { $0 + $1.series }
                    if totalSeries > 0 {
                        Text(TextosReloj.startGymSetsCount(totalSeries))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PaletaReloj.acento)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PaletaReloj.textoSecundario.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(PaletaReloj.superficie)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(PaletaReloj.acento.opacity(0.6), lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tarjeta(_ opcion: OpcionDeporteReloj) -> some View {
        Button {
            let esTri = opcion.id == "triatlon"
            estado.prepararInicioConCuentaRegresiva(
                deporte: opcion.deporte,
                esInterior: opcion.esInterior,
                esTriatlon: esTri,
                icono: opcion.icono
            )
        } label: {
            HStack(spacing: 12) {
                iconoTarjeta(simbolo: opcion.icono, color: PaletaReloj.acento)

                VStack(alignment: .leading, spacing: 2) {
                    Text(opcion.nombre)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    Text(TextosReloj.startBegin)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.acento)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PaletaReloj.textoSecundario.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(PaletaReloj.superficie)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// El deporte deducido del título, acotado al MVP (sólo running: siempre running).
    private func deporteDesdeTipo(_ tipo: String) -> DeporteDeSesion {
        MVP.acotado(deporteDesdeTipoSinAcotar(tipo))
    }

    private func deporteDesdeTipoSinAcotar(_ tipo: String) -> DeporteDeSesion {
        let t = tipo.lowercased()
        if t.contains("natac") || t.contains("natat") || t.contains("swim") || t.contains("nad") { return .natacion }
        if t.contains("bici") || t.contains("cicl") || t.contains("bik") || t.contains("cycl") || t.contains("velo") || t.contains("vélo") { return .ciclismo }
        if t.contains("trek") || t.contains("camin") || t.contains("hik") || t.contains("walk") || t.contains("randonn") { return .trekking }
        return .running
    }

    private func simbolo(para tipo: String) -> String {
        let t = tipo.lowercased()
        let interior = t.contains("interior") || t.contains("cinta")
        // Cada ícono sólo si el MVP deja ese deporte; si no, cae al de carrera.
        if MVP.permite(.triatlon), t.contains("triatl") || t.contains("ironman") { return "figure.mixed.cardio" }
        if MVP.permite(.natacion), t.contains("natac") || t.contains("natat") || t.contains("swim") || t.contains("nad") { return "figure.pool.swim" }
        if MVP.permite(.ciclismo), t.contains("bici") || t.contains("cicl") || t.contains("bik") || t.contains("cycl") || t.contains("velo") || t.contains("vélo") { return interior ? "figure.indoor.cycle" : "bicycle" }
        if MVP.permite(.trekking), t.contains("trek") || t.contains("camin") || t.contains("hik") || t.contains("walk") || t.contains("randonn") { return interior ? "figure.walk.treadmill" : "figure.walk" }
        if t.contains("gim") || t.contains("fuerza") || t.contains("gym") || t.contains("strength") || t.contains("muscu") { return "dumbbell.fill" }
        return interior ? "figure.run.treadmill" : "figure.run"
    }
}

struct AjustesInicialesView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e8)) {
                Text(TextosReloj.homeSettingsTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 2)

                // 1. Tarjeta Unidades (toque directo conmuta métrico/imperial)
                Button {
                    estado.toggleUnidades()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TextosReloj.settingsUnitsTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(estado.sistemaDeUnidades == .metrico ? TextosReloj.settingsUnitsMetric : TextosReloj.settingsUnitsImperial)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PaletaReloj.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                // 2. Sección Pausa automática (Carrera y Bici con detección de parada real)
                Text(TextosReloj.settingsAutoPause)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 4)

                HStack {
                    Text(TextosReloj.sportRunning)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle(String(), isOn: $estado.pausaAutoCarrera)
                        .labelsHidden()
                        .tint(PaletaReloj.acento)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PaletaReloj.superficie)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))


                // 3. Sección Alertas
                Text(TextosReloj.settingsAlertsSection)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 4)

                HStack {
                    Text(TextosReloj.settingsAlertsWorkout)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle(String(), isOn: $estado.avisosDeAvituallamiento)
                        .labelsHidden()
                        .tint(PaletaReloj.acento)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PaletaReloj.superficie)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            }
            .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e16))
            .padding(.top, PaletaReloj.puntosDeDiseno(TokensEspaciado.e8))
            .padding(.bottom, TokensEspaciado.e16)
        }
        .scrollIndicators(.hidden)
    }
}

/// Alerta a pantalla completa durante el entrenamiento que vibra el reloj para hidratarse o nutrirse.
/// Tapa toda la pantalla de forma análoga al contador del principio. Tocar cualquier parte
/// de la pantalla la descarta al instante y vuelve al lugar exacto en el que estaba el usuario.
struct AlertaEntrenamientoCompletaView: View {
    let aviso: TipoDeAvisoDeAvituallamiento
    let alCerrar: () -> Void

    private var titulo: String {
        switch aviso {
        case .agua: return TextosReloj.fuelFullscreenWaterTitle
        case .gel: return TextosReloj.fuelFullscreenGelTitle
        case .sales: return TextosReloj.fuelFullscreenSaltsTitle
        }
    }

    private var subtitulo: String {
        switch aviso {
        case .agua: return TextosReloj.fuelFullscreenWaterSubtitle
        case .gel: return TextosReloj.fuelFullscreenGelSubtitle
        case .sales: return TextosReloj.fuelFullscreenSaltsSubtitle
        }
    }

    private var icono: String {
        switch aviso {
        case .agua: return "drop.fill"
        case .gel: return "bolt.fill"
        case .sales: return "pills.fill"
        }
    }

    var body: some View {
        ZStack {
            // Fondo negro puro que cubre 100% de la pantalla (como el contador del inicio)
            PaletaReloj.fondo.ignoresSafeArea()

            // Círculo exterior decorativo
            Circle()
                .stroke(PaletaReloj.acento.opacity(0.18), lineWidth: 10)
                .frame(width: 140, height: 140)

            Circle()
                .stroke(PaletaReloj.acento, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 140, height: 140)

            VStack(spacing: 5) {
                Image(systemName: icono)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PaletaReloj.acento)

                Text(titulo)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitulo)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PaletaReloj.textoSecundario)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(TextosReloj.alertTapToContinue)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(PaletaReloj.acento)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            #if os(watchOS)
            WKInterfaceDevice.current().play(.click)
            #endif
            alCerrar()
        }
    }
}

/// Diálogo ágil previo al inicio: pregunta si el usuario lleva hidratación o geles.
/// Si toca cualquier parte de la pantalla o "No", se saltea al instante sin fricción.
struct PreguntaAvituallamientoView: View {
    @EnvironmentObject private var estado: EstadoReloj
    @State private var configurando = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !configurando {
                        estado.iniciarSinAvituallamiento()
                    }
                }

            if !configurando {
                VStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(PaletaReloj.acento)

                    Text(TextosReloj.fuelPromptQuestion)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Text(TextosReloj.fuelPromptTapToSkip)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PaletaReloj.textoSecundario)

                    HStack(spacing: 8) {
                        Button {
                            estado.iniciarSinAvituallamiento()
                        } label: {
                            Text(TextosReloj.commonNo)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(PaletaReloj.superficieAlterna)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                configurando = true
                            }
                        } label: {
                            Text(TextosReloj.commonYes)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PaletaReloj.fondo)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(PaletaReloj.acento)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 10)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 7) {
                        Text(TextosReloj.fuelPromptTitle)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(PaletaReloj.acento)

                        controlItem(titulo: TextosReloj.fuelPromptWater, valor: "\(estado.aguaMlQueLleva) ml",
                                    alMenos: { estado.aguaMlQueLleva = max(0, estado.aguaMlQueLleva - 250) },
                                    alMas: { estado.aguaMlQueLleva = min(3000, estado.aguaMlQueLleva + 250) })

                        controlItem(titulo: TextosReloj.fuelPromptGels, valor: "\(estado.gelesQueLleva)",
                                    alMenos: { estado.gelesQueLleva = max(0, estado.gelesQueLleva - 1) },
                                    alMas: { estado.gelesQueLleva = min(15, estado.gelesQueLleva + 1) })

                        controlItem(titulo: TextosReloj.fuelPromptSalts, valor: "\(estado.salesQueLleva)",
                                    alMenos: { estado.salesQueLleva = max(0, estado.salesQueLleva - 1) },
                                    alMas: { estado.salesQueLleva = min(15, estado.salesQueLleva + 1) })

                        Button {
                            estado.confirmarAvituallamientoEIniciar()
                        } label: {
                            Text(TextosReloj.commonStart)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PaletaReloj.fondo)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(PaletaReloj.acento)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func controlItem(titulo: String, valor: String, alMenos: @escaping () -> Void, alMas: @escaping () -> Void) -> some View {
        HStack {
            Text(titulo)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button(action: alMenos) {
                Text(verbatim: "-")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(PaletaReloj.superficieAlterna)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(valor)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PaletaReloj.acento)
                .frame(minWidth: 44)

            Button(action: alMas) {
                Text(verbatim: "+")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(PaletaReloj.superficieAlterna)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PaletaReloj.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - `carrusel` / `paginador` de entrenamiento

/// Paginador horizontal de entrenamiento con TabView y estilo .page:
/// Muestra los 3 círculos indicadores de paginación en la parte inferior idénticos a PortadaRelojView:
/// - Tag 0 (Izquierda): Controles (los botones: pausar, bloquear, ajustes, vuelta)
/// - Tag 1 (Centro): Métricas (con acceso vertical a Mapa y Parciales)
/// - Tag 2 (Derecha): Música (NowPlayingView nativo)
struct CarruselEntrenamientoRelojView: View {
    @EnvironmentObject private var estado: EstadoReloj
    @State private var paginaHorizontal: Int = 1

    var body: some View {
        TabView(selection: $paginaHorizontal) {
            ControlesView()
                .tag(0)

            MetricasContenedorVerticalView()
                .tag(1)

            MusicaView()
                .tag(2)
        }
        .tabViewStyle(.page)
        .onAppear {
            actualizarPaginaSegunEstado()
        }
        .onChange(of: estado.pantalla) { _ in
            actualizarPaginaSegunEstado()
        }
        .onChange(of: paginaHorizontal) { nuevaPagina in
            if nuevaPagina == 0 {
                if estado.pantalla != .controles {
                    estado.ir(a: .controles)
                }
            } else if nuevaPagina == 2 {
                if estado.pantalla != .musica {
                    estado.ir(a: .musica)
                }
            } else if nuevaPagina == 1 {
                if estado.pantalla != .metricas && estado.pantalla != .mapa && estado.pantalla != .parciales {
                    estado.ir(a: .metricas)
                }
            }
        }
    }

    private func actualizarPaginaSegunEstado() {
        switch estado.pantalla {
        case .controles:
            if paginaHorizontal != 0 { paginaHorizontal = 0 }
        case .musica:
            if paginaHorizontal != 2 { paginaHorizontal = 2 }
        case .metricas, .mapa, .parciales:
            if paginaHorizontal != 1 { paginaHorizontal = 1 }
        default:
            break
        }
    }
}

/// Contenedor vertical para la página central del entrenamiento (Estilo Strava):
/// Mientras el usuario desliza verticalmente, la pantalla se desenfoca progresivamente.
/// Al soltar el dedo tras superar el umbral, cambia de pantalla al instante y el desenfoque
/// se disipa con una transición rápida (0.18s), sin desplazamiento físico de láminas superpuestas.
struct MetricasContenedorVerticalView: View {
    @EnvironmentObject private var estado: EstadoReloj
    @State private var radioBlur: CGFloat = 0

    var body: some View {
        ZStack {
            PaletaReloj.fondo.ignoresSafeArea()

            Group {
                switch estado.pantalla {
                case .mapa:
                    MapaView()
                case .parciales:
                    ParcialesView()
                default:
                    MetricasView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .blur(radius: radioBlur)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { valor in
                    let dx = valor.translation.width
                    let dy = valor.translation.height
                    // Solo activar si el gesto es netamente vertical
                    guard abs(dy) > abs(dx) * 1.15 else { return }

                    // En la lista de parciales, deslizar hacia arriba es para scrollear los parciales;
                    // solo desenfocar si desliza hacia abajo (para regresar a métricas)
                    if estado.pantalla == .parciales && dy < 0 {
                        return
                    }

                    // El desenfoque aumenta con la distancia del dedo hasta un máximo de 16
                    let progreso = min(1.0, abs(dy) / 40.0)
                    radioBlur = progreso * 16.0
                }
                .onEnded { valor in
                    let dx = valor.translation.width
                    let dy = valor.translation.height
                    if abs(dy) > 32 && abs(dy) > abs(dx) * 1.15 {
                        cambiarPantallaVertical(dy: dy)
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            radioBlur = 0
                        }
                    }
                }
        )
        .onChange(of: estado.pantalla) { nuevaPantalla in
            // Si la pantalla cambió por toque de botón u otra vía externa:
            if radioBlur == 0 && (nuevaPantalla == .metricas || nuevaPantalla == .mapa || nuevaPantalla == .parciales) {
                radioBlur = 14
                withAnimation(.easeOut(duration: 0.18)) {
                    radioBlur = 0
                }
            }
        }
    }

    private func cambiarPantallaVertical(dy: CGFloat) {
        let destino: EstadoReloj.Pantalla?
        switch estado.pantalla {
        case .metricas:
            destino = dy < 0 ? .parciales : .mapa
        case .mapa:
            destino = .metricas
        case .parciales:
            destino = dy > 0 ? .metricas : nil
        default:
            destino = nil
        }

        guard let target = destino else {
            withAnimation(.easeOut(duration: 0.15)) {
                radioBlur = 0
            }
            return
        }

        radioBlur = 16.0
        estado.ir(a: target)
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
        withAnimation(.easeOut(duration: 0.18)) {
            radioBlur = 0
        }
    }
}

// MARK: - `metricas`

/// La pantalla que se mira corriendo. Números enormes, nada más.
///
/// El ritmo alterna entre promedio y parcial **al tocarlo**, que es el gesto que
/// el diseño define y el único que se puede hacer sin mirar.
/// La pantalla que se mira corriendo: diseño vertical amplio, limpio y de alto contraste
/// idéntico a Apple Entreno (imagen 2). Números grandes, etiquetas apiladas a la derecha.
struct MetricasView: View {
    @EnvironmentObject private var estado: EstadoReloj

    private var colorTimer: Color {
        PaletaReloj.acento
    }

    var body: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                let _ = timeline.date
                VStack(alignment: .leading, spacing: 5) {
                    // Barra superior: ícono de deporte a la izquierda e indicador de pausa a la derecha
                    HStack(alignment: .center) {
                        IconoEnCursoReloj(simbolo: estado.simboloDeporteEnCurso,
                                         triatlon: estado.esTriatlon, tamano: 16,
                                         color: PaletaReloj.acento)

                        Spacer(minLength: 0)

                        if estado.pausada {
                            Text(estado.esAutoPausada ? TextosReloj.workoutStatusAutoPaused : TextosReloj.workoutStatusPaused)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(PaletaReloj.acento)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(PaletaReloj.acentoSuave)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 2)

                    // 1. Duración del entrenamiento
                    Text(Formato.cronometroCompleto(segundos: estado.segundos))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(colorTimer)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    // 2. Ritmo promedio / parcial (al tocar conmuta en el mismo lugar)
                    if estado.deporte == .ciclismo {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(estado.velocidadTexto)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: -1) {
                                Text(estado.unidadDeVelocidad.uppercased())
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .foregroundStyle(.white)
                                Text(estado.ritmoParcial ? TextosReloj.workoutPaceCurrent : TextosReloj.workoutPaceAverage)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(PaletaReloj.textoSecundario)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { estado.ritmoParcial.toggle() }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(estado.ritmoMostrado)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: -1) {
                                Text("/" + estado.unidadDeDistancia.uppercased())
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .foregroundStyle(.white)
                                Text(estado.ritmoParcial ? TextosReloj.workoutPaceCurrent : TextosReloj.workoutPaceAverage)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(PaletaReloj.textoSecundario)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { estado.ritmoParcial.toggle() }
                    }

                    // 3. Kilómetros (distancia)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(estado.distanciaMostrada)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text(estado.unidadDeDistancia.uppercased())
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // 4. Frecuencia cardíaca
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(estado.pulso.map(String.init) ?? "—")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.red)
                            .offset(y: -1)
                    }

                    if estado.pantallaBloqueada {
                        Text(TextosReloj.metricsLocked)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PaletaReloj.acento)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }

            // Aviso in-workout cuando se alcanza el objetivo
            if estado.mostrarAvisoObjetivoCumplido {
                Color.black.opacity(0.88).ignoresSafeArea()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.green)
                    Text(TextosReloj.goalReached)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let obj = estado.objetivoMetrosSesion {
                        Text(Formato.distancia(obj, unidades: estado.sistemaDeUnidades))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PaletaReloj.acento)
                    }
                    HStack(spacing: 6) {
                        Button {
                            estado.continuarEntrenamientoTrasObjetivo()
                        } label: {
                            Text(TextosReloj.commonContinue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(PaletaReloj.superficieAlterna)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            estado.marcarObjetivoHoyCumplido(metros: estado.metros)
                            estado.descartarAvisoObjetivoCumplido()
                            estado.solicitarFinalizacion()
                        } label: {
                            Text(TextosReloj.commonFinish)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(PaletaReloj.fondo)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(PaletaReloj.superficie)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.green.opacity(0.5), lineWidth: 1.5))
            }
        }
    }
}

// MARK: - `rutina`

struct RutinaView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e8)) {
            Text(TextosReloj.routineTitle)
                .estilo(.relojEtiqueta, color: PaletaReloj.textoSecundario)

            if estado.rutina.isEmpty {
                Spacer(minLength: 0)
                Text(TextosReloj.routineNone).estilo(.relojTituloAviso)
                    .tituloDelReloj()
                Text(TextosReloj.routineNoneDetail)
                    .estilo(.relojCuerpo, color: PaletaReloj.textoSecundario)
                    .cuerpoDelReloj()
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(estado.rutina.prefix(2).enumerated()), id: \.offset) { _, ejercicio in
                    VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e2)) {
                        Text(ejercicio.nombre)
                            .estilo(.relojCuerpo)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(verbatim: "\(ejercicio.series) × \(ejercicio.repeticiones)")
                            .estilo(.relojEtiqueta, color: PaletaReloj.textoSecundario)
                    }
                    .padding(PaletaReloj.puntosDeDiseno(TokensEspaciado.e8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PaletaReloj.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e16))
        .padding(.vertical, PaletaReloj.puntosDeDiseno(TokensEspaciado.e8))
        .navegacionDelReloj(abajo: { estado.ir(a: .metricas) })
    }
}

// MARK: - `controles`

/// 🛑 **Cinco botones, no seis.** El sexto era "compartir ubicación" y quedó
/// fuera de la v1 (decisión 0003). La grilla se rehízo para cinco en vez de
/// dejar un hueco donde estaba.
struct ControlesView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        VStack(spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e6)) {
            if estado.esTriatlon, let siguiente = estado.siguienteDeporteTriatlon {
                Button {
                    estado.transicionarSiguienteDeporteTriatlon()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: siguiente.icono)
                            .font(.system(size: 13, weight: .bold))
                        Text(siguiente.textoBoton)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(PaletaReloj.fondo)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(PaletaReloj.acento)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e6)) {
                control(TextosReloj.controlsFinish, simbolo: "flag.fill", tono: .error) {
                    estado.solicitarFinalizacion()
                }
                control(estado.pausada ? TextosReloj.controlsResume : TextosReloj.controlsPause,
                        simbolo: estado.pausada ? "play.fill" : "pause.fill", tono: .pausa) {
                    estado.pausarOReanudar()
                }
            }
            HStack(spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e6)) {
                control(TextosReloj.controlsSettings, simbolo: "gearshape.fill", tono: .normal) {
                    estado.ir(a: .ajustes)
                }
                control(TextosReloj.controlsLap, simbolo: "arrow.triangle.2.circlepath", tono: .vuelta) {
                    estado.marcarVuelta()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e6))
        .padding(.top, PaletaReloj.puntosDeDiseno(TokensEspaciado.e4))
        .padding(.bottom, PaletaReloj.puntosDeDiseno(TokensEspaciado.e10))
    }

    private enum TonoControl: Equatable { case normal, acento, error, vuelta, pausa }

    private func control(_ titulo: String, simbolo: String, tono: TonoControl,
                         accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(spacing: 4) {
                Image(systemName: simbolo)
                    .font(.system(size: 26, weight: .bold))
                Text(titulo)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(color(tono))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .foregroundStyle(color(tono))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(fondo(tono))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borde(tono), lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fondo(_ tono: TonoControl) -> Color {
        switch tono {
        case .normal: PaletaReloj.superficie
        case .acento: PaletaReloj.acento
        case .error: PaletaReloj.errorFondo
        case .vuelta: PaletaReloj.vueltaFondo
        case .pausa: PaletaReloj.controlPausa
        }
    }

    private func color(_ tono: TonoControl) -> Color {
        switch tono {
        case .normal: PaletaReloj.textoPrimario
        case .acento: PaletaReloj.sobreAcento
        case .error: PaletaReloj.error
        case .vuelta: PaletaReloj.vuelta
        case .pausa: PaletaReloj.sobreControlPausa
        }
    }

    private func borde(_ tono: TonoControl) -> Color {
        switch tono {
        case .error: PaletaReloj.error.opacity(0.4)
        case .vuelta: PaletaReloj.vuelta.opacity(0.4)
        case .pausa: PaletaReloj.controlPausa.opacity(0.4)
        default: .clear
        }
    }
}

// MARK: - Confirmar finalización (Unificada en ResumenView)

/// Al finalizar se muestra directamente la pantalla completa con todas las métricas
/// alcanzadas, tiempo de pausa, y los botones Guardar y Reanudar.
struct ConfirmarFinalizacionView: View {
    var body: some View {
        ResumenView()
    }
}

// MARK: - Salida inválida

struct SinMovimientoView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical) {
                VStack(spacing: TokensEspaciado.e6) {
                    Text(TextosReloj.stationaryTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 28)

                    Text(TextosReloj.stationaryDetail)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    botonGrande(TextosReloj.stationaryResume,
                                color: PaletaReloj.superficieAlterna,
                                texto: PaletaReloj.textoPrimario) {
                        estado.reanudarDesdeFinalizacion()
                    }
                    botonGrande(TextosReloj.stationaryDiscard,
                                color: PaletaReloj.errorFondo,
                                texto: PaletaReloj.error) {
                        estado.descartar()
                    }
                }
                .padding(.horizontal, TokensEspaciado.e8)
                .padding(.bottom, TokensEspaciado.e20)
            }
            .scrollIndicators(.hidden)

            Button {
                estado.reanudarDesdeFinalizacion()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PaletaReloj.textoPrimario)
                    .frame(width: 32, height: 32)
                    .background(PaletaReloj.superficieAlterna)
                    .clipShape(Circle())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.leading, 6)
            .zIndex(10)
            .accessibilityLabel(TextosReloj.stationaryClose)
        }
    }

    private func botonGrande(_ titulo: String, color: Color, texto: Color,
                             accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(titulo)
                .font(.title3.weight(.bold))
                .foregroundStyle(texto)
                .frame(maxWidth: .infinity, minHeight: TokensEspaciado.e56)
                .background(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - `avisos`

struct AvisosView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e8)) {
            Text(TextosReloj.alertsUpcoming)
                .estilo(.relojEtiqueta, color: PaletaReloj.acento)

            Text(TextosReloj.alertsEmpty)
                .estilo(.relojCuerpo, color: PaletaReloj.textoSecundario)
                .lineLimit(3)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)

            Text(TextosReloj.alertsPast)
                .estilo(.relojEtiqueta, color: PaletaReloj.textoSecundario)

            if let aviso = estado.avisosPasados.last {
                VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e2)) {
                    Text(aviso.titulo)
                        .estilo(.relojCuerpo, color: PaletaReloj.textoSecundario)
                        .lineLimit(1)
                    Text(verbatim: "\(aviso.detalle) · \(aviso.cuando)")
                        .estilo(.relojEtiqueta, color: PaletaReloj.textoSecundario)
                        .lineLimit(2)
                }
                .padding(PaletaReloj.puntosDeDiseno(TokensEspaciado.e8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PaletaReloj.superficie)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                .opacity(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e16))
        .padding(.vertical, PaletaReloj.puntosDeDiseno(TokensEspaciado.e8))
        .navegacionDelReloj(izquierda: { estado.ir(a: .metricas) })
    }
}

struct ConoDeRumbo: Shape {
    var anguloApertura: Double = 60.0
    var longitud: CGFloat = 36.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centro = CGPoint(x: rect.midX, y: rect.midY)
        let inicioAngulo = Angle(degrees: -90 - anguloApertura / 2)
        let finAngulo = Angle(degrees: -90 + anguloApertura / 2)
        path.move(to: centro)
        path.addArc(center: centro, radius: longitud,
                    startAngle: inicioAngulo, endAngle: finAngulo, clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// 🛑 **Sólo el recorrido propio.** Se fueron los avatares de "quién te está
/// viendo", su contador y su estado vacío: compartir ubicación en vivo quedó
/// fuera de la v1 (decisión 0003).
struct MapaView: View {
    var body: some View {
        if #available(iOS 17.0, watchOS 10.0, *) {
            MapaModernoView()
        } else {
            Text(TextosReloj.mapNoGps)
                .estilo(.relojEtiqueta, color: PaletaReloj.textoSecundario)
        }
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct MapaModernoView: View {
    @EnvironmentObject private var estado: EstadoReloj
    @State private var posicion: MapCameraPosition = .userLocation(fallback: .automatic)

    private var tramos: [[CLLocationCoordinate2D]] {
        #if os(watchOS)
        let pts = estado.fuenteLocal
            ? estado.seguimiento.puntos
            : (estado.sincronizador.salidaRemota?.puntos ?? [])
        #else
        let pts = (estado.sincronizador.salidaRemota?.puntos ?? [])
        #endif
        return SegmentadorDeRecorrido.segmentar(pts).map { tramo in
            tramo.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        }
    }

    private var ubicacionActual: CLLocationCoordinate2D? {
        #if os(watchOS)
        if estado.fuenteLocal { return estado.seguimiento.ubicacion ?? tramos.last?.last }
        #endif
        return tramos.last?.last
    }

    private func colorPorDeporte(_ deporte: DeporteDeSesion) -> Color {
        switch deporte {
        case .natacion:
            return Color(red: 0.0, green: 0.75, blue: 0.95) // Cyan / celeste piscina
        case .ciclismo:
            return Color(red: 1.0, green: 0.58, blue: 0.0) // Naranja bici
        case .running, .fuerza, .trekking, .otro, .triatlon:
            return PaletaReloj.acento // Verde lima
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            PaletaReloj.fondo.ignoresSafeArea()

            // Encabezado superior con icono del deporte y badge de pausa condicional
            HStack(alignment: .center) {
                IconoEnCursoReloj(simbolo: estado.simboloDeporteEnCurso,
                                 triatlon: estado.esTriatlon, tamano: 16,
                                 color: PaletaReloj.acento)

                Spacer(minLength: 0)

                if estado.pausada {
                    Text(estado.esAutoPausada ? TextosReloj.workoutStatusAutoPaused : TextosReloj.workoutStatusPaused)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.acento)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(PaletaReloj.acentoSuave)
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                estado.ir(a: .metricas)
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .zIndex(10)

            if #available(iOS 17.0, watchOS 10.0, *) {
                Map(position: $posicion, interactionModes: []) {
                    // Si es triatlón, dibujar cada deporte con su color propio
                    if estado.esTriatlon && !estado.tramosPorDeporte.isEmpty {
                        ForEach(estado.tramosPorDeporte) { tramo in
                            let coords = tramo.puntos.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                            if coords.count > 1 {
                                MapPolyline(coordinates: coords)
                                    .stroke(colorPorDeporte(tramo.deporte), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            }
                        }
                    } else {
                        // Cada tramo de actividad normal se dibuja por separado
                        ForEach(Array(tramos.enumerated()), id: \.offset) { indice, tramo in
                            let coordenadas: [CLLocationCoordinate2D] = {
                                var pts = tramo
                                if indice == tramos.count - 1, let act = ubicacionActual {
                                    if let ultimo = pts.last {
                                        let dist = SegmentadorDeRecorrido.distanciaMetros(
                                            lat1: ultimo.latitude, lon1: ultimo.longitude,
                                            lat2: act.latitude, lon2: act.longitude)
                                        if dist > 1.0 { pts.append(act) }
                                    } else {
                                        pts = [act]
                                    }
                                }
                                return pts
                            }()

                            if coordenadas.count > 1 {
                                MapPolyline(coordinates: coordenadas)
                                    .stroke(PaletaReloj.acento, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            }
                            if let primero = tramo.first {
                                Annotation("", coordinate: primero) {
                                    ZStack {
                                        Circle().fill(PaletaReloj.acento).frame(width: 15, height: 15)
                                        Text(verbatim: "\(indice + 1)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(PaletaReloj.fondo)
                                    }
                                }
                            }
                        }
                    }

                    // Tramos recorridos en pausa: dibujados en color de pausa con línea discontinua
                    ForEach(Array(estado.tramosDePausa.enumerated()), id: \.offset) { _, tramo in
                        let coords = tramo.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(PaletaReloj.controlPausa, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [4, 3]))
                        }
                    }

                    // Marcas exactas en la ruta: vuelta, pausa y reanudación
                    ForEach(estado.marcasDeRuta) { marca in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: marca.latitud, longitude: marca.longitud)) {
                            switch marca.tipo {
                            case .vuelta:
                                ZStack {
                                    Circle()
                                        .fill(PaletaReloj.acento)
                                        .frame(width: 16, height: 16)
                                    Image(systemName: "flag.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(PaletaReloj.fondo)
                                }
                            case .pausa:
                                ZStack {
                                    Circle()
                                        .fill(PaletaReloj.controlPausa)
                                        .frame(width: 16, height: 16)
                                    Image(systemName: "pause.fill")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(PaletaReloj.fondo)
                                }
                            case .reanudacion:
                                ZStack {
                                    Circle()
                                        .fill(PaletaReloj.acento)
                                        .frame(width: 16, height: 16)
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(PaletaReloj.fondo)
                                }
                            }
                        }
                    }

                    // Marcador actual de la persona: punto azul con borde blanco (sin cono en el reloj)
                    #if os(watchOS)
                    if let actual = ubicacionActual {
                        Annotation("", coordinate: actual) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.15, green: 0.55, blue: 1.0).opacity(0.25))
                                    .frame(width: 28, height: 28)

                                Circle()
                                    .fill(Color(red: 0.05, green: 0.5, blue: 1.0))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                                    .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                            }
                            .frame(width: 32, height: 32)
                        }
                    } else if estado.fuenteLocal {
                        UserAnnotation()
                    }
                    #else
                    if let actual = ubicacionActual {
                        Annotation("", coordinate: actual) {
                            ZStack {
                                ConoDeRumbo(anguloApertura: 60, longitud: 36)
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.2, green: 0.7, blue: 1.0).opacity(0.85),
                                                Color(red: 0.2, green: 0.7, blue: 1.0).opacity(0.18)
                                            ]),
                                            center: .center,
                                            startRadius: 8,
                                            endRadius: 36
                                        )
                                    )
                                    .overlay(
                                        ConoDeRumbo(anguloApertura: 60, longitud: 36)
                                            .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.4), lineWidth: 1)
                                    )
                                    .rotationEffect(.degrees(estado.rumbo))

                                Circle()
                                    .fill(Color(red: 0.15, green: 0.55, blue: 1.0).opacity(0.25))
                                    .frame(width: 28, height: 28)

                                Circle()
                                    .fill(Color(red: 0.05, green: 0.5, blue: 1.0))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                                    .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                            }
                            .frame(width: 80, height: 80)
                        }
                    }
                    #endif
                }
                .ignoresSafeArea()
                .mapStyle(.standard(elevation: .flat))
                .allowsHitTesting(false)
                .onAppear {
                    #if os(watchOS)
                    if let act = ubicacionActual, CLLocationCoordinate2DIsValid(act) {
                        posicion = .region(MKCoordinateRegion(center: act, latitudinalMeters: 100, longitudinalMeters: 100))
                    } else if estado.fuenteLocal {
                        posicion = .userLocation(fallback: .automatic)
                    }
                    #endif
                }
                .onChange(of: ubicacionActual?.latitude) { _ in
                    #if os(watchOS)
                    if let act = ubicacionActual, CLLocationCoordinate2DIsValid(act) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            posicion = .region(MKCoordinateRegion(center: act, latitudinalMeters: 100, longitudinalMeters: 100))
                        }
                    }
                    #endif
                }
            } else {
                Text(TextosReloj.mapNoGps)
                    .estilo(.relojEtiqueta, color: PaletaReloj.textoSecundario)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TokensEspaciado.e20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - `musica` (Pantalla derecha del entrenamiento)

struct MusicaView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        #if os(watchOS)
        NowPlayingView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        Color.black
            .overlay(Text(TextosReloj.musicPlaceholder).foregroundStyle(.white))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

// MARK: - `parciales` (Pantalla de abajo del entrenamiento: splits o series)

struct ParcialesView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        ZStack {
            PaletaReloj.fondo.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    IconoEnCursoReloj(simbolo: estado.simboloDeporteEnCurso,
                                     triatlon: estado.esTriatlon, tamano: 16,
                                     color: PaletaReloj.acento)

                    Spacer(minLength: 0)

                    if estado.pausada {
                        Text(estado.esAutoPausada ? TextosReloj.workoutStatusAutoPaused : TextosReloj.workoutStatusPaused)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(PaletaReloj.acento)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(PaletaReloj.acentoSuave)
                            .clipShape(Capsule())
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    estado.ir(a: .metricas)
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)

                if let objetivo = estado.objetivoSeries, !estado.objetivoSeriesContinuado {
                    contenidoSeries(objetivo: objetivo)
                } else {
                    contenidoKilometros
                }
            }

            if estado.mostrarAvisoFinObjetivoSeries {
                avisoFinObjetivoSeriesModal
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Modo Objetivo de Series (Lista de Tareas)

    private func contenidoSeries(objetivo: ObjetivoSeries) -> some View {
        let completadas = estado.itemsSeries.filter { $0.completada }.count
        let total = objetivo.totalSeries

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(TextosReloj.intervalsTitle)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(PaletaReloj.acento)
                    .tracking(0.5)

                Spacer()

                Text(TextosReloj.commonCountOf(completadas, total))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PaletaReloj.superficie)
                        .frame(height: 5)
                    Capsule()
                        .fill(PaletaReloj.acento)
                        .frame(width: geo.size.width * CGFloat(completadas) / CGFloat(max(1, total)), height: 5)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 10)

            ScrollView(.vertical) {
                VStack(spacing: 5) {
                    ForEach(estado.itemsSeries) { item in
                        filaSerie(item)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 3)
    }

    private func filaSerie(_ item: ItemSerieObjetivo) -> some View {
        let esActual = !item.completada && item.numero == estado.serieActualIndice + 1

        return HStack(spacing: 8) {
            if item.completada {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PaletaReloj.acento)
            } else if esActual {
                Circle()
                    .strokeBorder(PaletaReloj.acento, lineWidth: 2)
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .strokeBorder(PaletaReloj.textoSecundario.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(TextosReloj.intervalsSetNumber(item.numero))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(item.completada ? .white : (esActual ? PaletaReloj.acento : PaletaReloj.textoSecundario))

                if esActual {
                    Text(verbatim: "\(item.metrosCompletados) / \(item.metrosObjetivo) m")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PaletaReloj.textoSecundario)
                        .monospacedDigit()
                } else {
                    Text(verbatim: "\(item.metrosObjetivo) m")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PaletaReloj.textoSecundario.opacity(0.8))
                }
            }

            Spacer(minLength: 0)

            if item.completada, let ritmo = item.ritmoSegPorKm {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Formato.ritmo(segundosPorKm: ritmo, unidades: estado.sistemaDeUnidades))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("/" + estado.unidadDeDistancia.uppercased())
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(PaletaReloj.textoSecundario)
                }
            } else if esActual {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(estado.ritmoMostrado)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.acento)
                        .monospacedDigit()
                    Text(TextosReloj.workoutPaceCurrent)
                        .font(.system(size: 7.5, weight: .heavy))
                        .foregroundStyle(PaletaReloj.acento)
                }
            } else {
                Text(verbatim: "—")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PaletaReloj.textoSecundario.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(esActual ? PaletaReloj.acentoSuave : PaletaReloj.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Modo Ritmos por Kilómetro (Listados de abajo hacia arriba: 1 al fondo, N en el tope)

    private var contenidoKilometros: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(TextosReloj.splitsTitle)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(PaletaReloj.acento)
                    .tracking(0.5)

                Spacer()

                Text(verbatim: "\(estado.distanciaMostrada) \(estado.unidadDeDistancia.uppercased())")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)

            ScrollView(.vertical) {
                VStack(spacing: 5) {
                    let parciales = estado.listaParcialesVisuales
                    if parciales.isEmpty {
                        VStack(spacing: 6) {
                            Text(TextosReloj.splitsEmpty)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PaletaReloj.textoSecundario)
                                .multilineTextAlignment(.center)
                                .padding(.top, 16)
                        }
                    } else {
                        ForEach(parciales) { p in
                            filaKm(p)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 3)
    }

    private func filaKm(_ p: ParcialKilometro) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(TextosReloj.splitsKmNumber(p.numero))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(p.completado ? .white : PaletaReloj.acento)

                if !p.completado {
                    Circle()
                        .fill(PaletaReloj.acento)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(PaletaReloj.fondo)
                        )
                }
            }

            Spacer(minLength: 0)

            Text(Formato.cronometroCompleto(segundos: p.segundos))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(PaletaReloj.textoSecundario)
                .monospacedDigit()

            if let ritmo = p.ritmoSegPorKm {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Formato.ritmo(segundosPorKm: ritmo, unidades: estado.sistemaDeUnidades))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(p.completado ? .white : PaletaReloj.acento)
                        .monospacedDigit()
                    Text("/" + estado.unidadDeDistancia.uppercased())
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(PaletaReloj.textoSecundario)
                }
            } else {
                Text(verbatim: "—")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PaletaReloj.textoSecundario)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(p.completado ? PaletaReloj.superficie : PaletaReloj.acentoSuave)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Modal de Fin de Series

    private var avisoFinObjetivoSeriesModal: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.green)

                Text(TextosReloj.goalCompleted)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(TextosReloj.goalAllSetsDone)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PaletaReloj.textoSecundario)
                    .multilineTextAlignment(.center)

                VStack(spacing: 5) {
                    Button {
                        estado.continuarTrasFinDeSeries()
                    } label: {
                        Text(TextosReloj.goalContinueWorkout)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PaletaReloj.sobreAcento)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(PaletaReloj.acento)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        estado.finalizarDesdeFinDeSeries()
                    } label: {
                        Text(TextosReloj.goalFinishToday)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(PaletaReloj.superficieAlterna)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        estado.cancelarAvisoFinDeSeries()
                    } label: {
                        Text(TextosReloj.commonCancel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PaletaReloj.textoSecundario)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 10)
        }
        .transition(.opacity)
        .zIndex(100)
    }
}

// MARK: - `ajustes`

/// 🛑 **Ajustes DE LA SESIÓN, y la pantalla lo dice.**
///
/// AGENTS.md §10.2: *"cada control de esos dice en pantalla que es de esta
/// sesión — un switch pelado hace creer que se cambió para siempre y al día
/// siguiente se vive como un bug"*. De ahí el subtítulo, que no es decorativo.
///
/// De los 4 toggles del diseño quedan **2**: compartir y ánimos se fueron con el
/// recorte de la v1.
struct AjustesDeSesionView: View {
    @EnvironmentObject private var estado: EstadoReloj

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e8)) {
                    Text(TextosReloj.settingsTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, TokensEspaciado.e34)
                        .padding(.bottom, TokensEspaciado.e2)

                    // 1. Tarjeta Unidades
                    Button {
                        estado.toggleUnidades()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TextosReloj.settingsUnitsTitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(estado.sistemaDeUnidades == .metrico ? TextosReloj.settingsUnitsMetric : TextosReloj.settingsUnitsImperial)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PaletaReloj.superficie)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // 2. Sección Pausa automática
                    Text(TextosReloj.settingsAutoPause)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 4)

                    // Carrera toggle
                    HStack {
                        Text(TextosReloj.sportRunning)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Toggle(String(), isOn: $estado.pausaAutoCarrera)
                            .labelsHidden()
                            .tint(PaletaReloj.acento)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(PaletaReloj.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))


                    // 3. Sección Alertas
                    Text(TextosReloj.settingsAlertsSection)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 4)

                    // Alertas de entrenamiento toggle
                    HStack {
                        Text(TextosReloj.settingsAlertsWorkout)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Toggle(String(), isOn: $estado.avisosDeAvituallamiento)
                            .labelsHidden()
                            .tint(PaletaReloj.acento)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(PaletaReloj.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e16))
                .padding(.bottom, TokensEspaciado.e16)
            }
            .scrollIndicators(.hidden)

            Button {
                estado.ir(a: .controles)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(PaletaReloj.superficieAlterna)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, TokensEspaciado.e2)
            .padding(.leading, TokensEspaciado.e8)
        }
        .navegacionDelReloj(derecha: { estado.ir(a: .controles) })
    }
}

// MARK: - `resumen`

struct ResumenView: View {
    @EnvironmentObject private var estado: EstadoReloj
    @State private var mostrarConfirmacionDescarte = false

    private struct TramoConPausa: Identifiable {
        let id: Int
        let numero: Int
        let metros: Int
        let segundos: Int
        let pausaSegundos: Int?
    }

    private var tramosConPausa: [TramoConPausa] {
        #if os(watchOS)
        let pts = estado.fuenteLocal
            ? estado.seguimiento.puntos
            : (estado.sincronizador.salidaRemota?.puntos ?? [])
        #else
        let pts = (estado.sincronizador.salidaRemota?.puntos ?? [])
        #endif
        let segmentos = SegmentadorDeRecorrido.segmentar(pts)
        return segmentos.enumerated().map { indice, tramo in
            var dist = 0.0
            if tramo.count > 1 {
                for i in 0..<(tramo.count - 1) {
                    dist += SegmentadorDeRecorrido.distanciaMetros(
                        lat1: tramo[i].lat, lon1: tramo[i].lon,
                        lat2: tramo[i+1].lat, lon2: tramo[i+1].lon
                    )
                }
            }
            let segs: Int = {
                guard let primero = tramo.first, let ultimo = tramo.last, ultimo.atMs > primero.atMs else { return 0 }
                return max(1, Int((ultimo.atMs - primero.atMs) / 1000))
            }()
            let pausaPosterior: Int? = {
                guard indice < segmentos.count - 1 else { return nil }
                let siguiente = segmentos[indice + 1]
                guard let finActual = tramo.last, let inicioSig = siguiente.first, inicioSig.atMs > finActual.atMs else { return nil }
                return max(1, Int((inicioSig.atMs - finActual.atMs) / 1000))
            }()
            return TramoConPausa(id: indice + 1, numero: indice + 1, metros: Int(dist.rounded()), segundos: segs, pausaSegundos: pausaPosterior)
        }
    }

    private var caloriasAproximadas: Int {
        let minutos = max(1, estado.segundos / 60)
        let factor: Double = switch estado.deporte {
        case .ciclismo: 9.0
        case .running: 11.5
        case .trekking: 7.0
        default: 8.0
        }
        return Int((Double(minutos) * factor).rounded())
    }

    var body: some View {
        ZStack {
            ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                // Cabecera unificada
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PaletaReloj.acento)
                    Text(TextosReloj.finishTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.acento)
                    Spacer()
                    IconoEnCursoReloj(simbolo: estado.simboloDeporteEnCurso,
                                     triatlon: estado.esTriatlon, tamano: 14,
                                     color: PaletaReloj.textoSecundario)
                }
                .padding(.top, 2)

                // Datos organizados verticalmente, tipografía limpia, sin fondos grises
                filaVertical(etiqueta: TextosReloj.summaryDistance,
                             valor: Formato.distancia(estado.metros, unidades: estado.sistemaDeUnidades, decimales: 2),
                             destacado: true)

                filaVertical(etiqueta: TextosReloj.summaryDuration,
                             valor: Formato.cronometroCompleto(segundos: estado.segundos))

                // Tiempo total en pausa
                filaVertical(etiqueta: TextosReloj.summaryPausedTime,
                             valor: Formato.cronometroCompleto(segundos: estado.segundosEnPausa),
                             colorIcono: PaletaReloj.vuelta,
                             icono: "pause.circle.fill")

                if estado.deporte == .ciclismo {
                    filaVertical(etiqueta: TextosReloj.summaryAverageSpeed,
                                 valor: "\(estado.velocidadTexto) \(estado.unidadDeVelocidad)")
                } else {
                    filaVertical(etiqueta: TextosReloj.summaryPace,
                                 valor: Formato.ritmo(segundosPorKm: estado.ritmoPromedioSegPorKm,
                                                      unidades: estado.sistemaDeUnidades))
                }

                if let pulso = estado.pulso {
                    filaVertical(etiqueta: TextosReloj.metricsHeartRate,
                                 valor: "\(pulso) ppm",
                                 colorIcono: .red,
                                 icono: "heart.fill")
                }

                filaVertical(etiqueta: TextosReloj.summaryElevationGain, valor: Formato.desnivel(metros: 0, unidades: estado.sistemaDeUnidades))

                filaVertical(etiqueta: TextosReloj.summaryActiveCalories, valor: "\(caloriasAproximadas) kcal")

                #if os(watchOS)
                if !estado.vueltas.isEmpty {
                    Text(TextosReloj.summaryLapsTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PaletaReloj.vuelta)
                        .padding(.top, 4)

                    ForEach(estado.vueltas) { vuelta in
                        HStack {
                            ZStack {
                                Circle().fill(PaletaReloj.vuelta).frame(width: 14, height: 14)
                                Text(verbatim: "\(vuelta.numero)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(PaletaReloj.fondo)
                            }
                            Text(TextosReloj.summaryLapsItem(vuelta.numero))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PaletaReloj.textoPrimario)
                            Spacer()
                            Text(Formato.distancia(vuelta.metros, unidades: estado.sistemaDeUnidades, decimales: 2))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PaletaReloj.textoSecundario)
                            Text("· " + Formato.cronometro(segundos: vuelta.segundos))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PaletaReloj.textoSecundario)
                        }
                        .padding(.vertical, 1)
                    }
                }
                #endif

                if tramosConPausa.count > 1 {
                    Text(TextosReloj.summarySegmentsTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PaletaReloj.textoSecundario)
                        .padding(.top, 4)

                    ForEach(tramosConPausa) { tramo in
                        VStack(spacing: 2) {
                            HStack {
                                ZStack {
                                    Circle().fill(PaletaReloj.acento).frame(width: 14, height: 14)
                                    Text(verbatim: "\(tramo.numero)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(PaletaReloj.fondo)
                                }
                                Text(TextosReloj.summarySegmentsZone(tramo.numero))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PaletaReloj.textoPrimario)
                                Spacer()
                                Text(Formato.distancia(tramo.metros, unidades: estado.sistemaDeUnidades, decimales: 2))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(PaletaReloj.textoSecundario)
                                if tramo.segundos > 0 {
                                    Text("· " + Formato.cronometro(segundos: tramo.segundos))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(PaletaReloj.textoSecundario)
                                }
                            }
                            if let pausa = tramo.pausaSegundos, pausa > 0 {
                                HStack(spacing: 4) {
                                    Spacer()
                                    Image(systemName: "pause.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(PaletaReloj.vuelta)
                                    Text(TextosReloj.summarySegmentsPauseAfter(Formato.cronometro(segundos: pausa)))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(PaletaReloj.vuelta)
                                }
                                .padding(.trailing, 2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Botones Guardar y Reanudar (reemplazan a 'Listo' de la v1 anterior)
                VStack(spacing: TokensEspaciado.e8) {
                    Button {
                        estado.guardarDesdeFinalizacion()
                    } label: {
                        HStack(spacing: TokensEspaciado.e6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                            Text(TextosReloj.finishSave)
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(PaletaReloj.fondo)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(PaletaReloj.acento)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        estado.reanudarDesdeFinalizacion()
                    } label: {
                        HStack(spacing: TokensEspaciado.e6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(TextosReloj.finishResume)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PaletaReloj.superficieAlterna)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        mostrarConfirmacionDescarte = true
                    } label: {
                        HStack(spacing: TokensEspaciado.e6) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(TextosReloj.commonDiscard)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(PaletaReloj.error)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PaletaReloj.errorFondo)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaletaReloj.fondo)
        .contentShape(Rectangle())

        if mostrarConfirmacionDescarte {
            modalConfirmacionDescarte
        }
    }
}

    private var modalConfirmacionDescarte: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    mostrarConfirmacionDescarte = false
                }

            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(PaletaReloj.error)
                        .padding(.top, 4)

                    Text(TextosReloj.commonDiscardConfirmation)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)

                    VStack(spacing: 8) {
                        Button {
                            mostrarConfirmacionDescarte = false
                        } label: {
                            Text(TextosReloj.commonCancel)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PaletaReloj.textoPrimario)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(PaletaReloj.superficieAlterna)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            mostrarConfirmacionDescarte = false
                            estado.descartar()
                        } label: {
                            Text(TextosReloj.commonDiscard)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(PaletaReloj.error)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
                .background(PaletaReloj.superficie)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
        }
        .transition(.opacity)
        .zIndex(100)
    }

    private func filaVertical(etiqueta: String, valor: String, destacado: Bool = false,
                              colorIcono: Color? = nil, icono: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(etiqueta)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PaletaReloj.textoSecundario)
            HStack(spacing: 4) {
                Text(valor)
                    .font(.system(size: destacado ? 20 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PaletaReloj.textoPrimario)
                    .monospacedDigit()
                if let icono, let colorIcono {
                    Image(systemName: icono)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(colorIcono)
                }
            }
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - `gimnasio`

/// La sesión de gimnasio en la muñeca: un ejercicio por vez, repeticiones y peso,
/// agregar series extras, desmarcar, demostración animada y pantalla de resumen.
struct GimnasioRelojView: View {
    @EnvironmentObject private var estado: EstadoReloj
    @State private var mostrarDemostracion = false

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e7)) {
                if estado.rutina.indices.contains(estado.ejercicioActual) {
                    let ejercicio = estado.rutina[estado.ejercicioActual]
                    let hechas = estado.seriesHechas(enEjercicio: estado.ejercicioActual)
                    let total = estado.totalSeries(enEjercicio: estado.ejercicioActual)

                    // Cabecera con selector de ejercicio y botón de técnica
                    HStack(alignment: .center) {
                        Button {
                            if estado.ejercicioActual > 0 {
                                estado.ejercicioActual -= 1
                                estado.cargarPrescripcion()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(estado.ejercicioActual > 0 ? PaletaReloj.acento : Color.gray.opacity(0.3))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .disabled(estado.ejercicioActual == 0)

                        Spacer()

                        Button {
                            mostrarDemostracion = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(TextosReloj.gymTechnique)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(PaletaReloj.acento)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PaletaReloj.acento.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            if estado.ejercicioActual < estado.rutina.count - 1 {
                                estado.ejercicioActual += 1
                                estado.cargarPrescripcion()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(estado.ejercicioActual < estado.rutina.count - 1 ? PaletaReloj.acento : Color.gray.opacity(0.3))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .disabled(estado.ejercicioActual >= estado.rutina.count - 1)
                    }

                    Text(ejercicio.nombre)
                        .estilo(.relojCuerpo)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack {
                        Text(TextosReloj.gymSetProgress(min(hechas + 1, total), total))
                            .estilo(.relojEtiqueta, color: PaletaReloj.acento)
                        Spacer()
                        if hechas >= total {
                            Text(TextosReloj.commonCompleted)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.green)
                        }
                    }

                    StepperDelReloj(valor: "\(estado.repeticiones)",
                                    unidad: TextosReloj.gymReps,
                                    bajar: { estado.repeticiones = max(1, estado.repeticiones - 1) },
                                    subir: { estado.repeticiones = min(200, estado.repeticiones + 1) })

                    if ejercicio.pesoKg > 0 {
                        StepperDelReloj(valor: "\(estado.pesoKg)",
                                        unidad: ejercicio.unidad,
                                        bajar: { estado.pesoKg = max(0, estado.pesoKg - 5) },
                                        subir: { estado.pesoKg = min(300, estado.pesoKg + 5) })
                    }

                    // Botón Serie hecha
                    BotonDelReloj(titulo: TextosReloj.gymSetDone, destacado: true) {
                        estado.serieHecha()
                        VibracionReloj.avisar()
                    }

                    // Fila de acciones secundarias: + Serie, Desmarcar, Finalizar
                    HStack(spacing: 6) {
                        Button {
                            estado.agregarSerieExtra()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text(TextosReloj.gymSet)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(PaletaReloj.textoPrimario)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(PaletaReloj.superficieAlterna)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if hechas > 0 {
                            Button {
                                estado.desmarcarUltimaSerie()
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(TextosReloj.commonUndo)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(PaletaReloj.error)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(PaletaReloj.errorFondo)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            estado.terminarGimnasio()
                        } label: {
                            Text(TextosReloj.commonFinish)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PaletaReloj.acento)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(PaletaReloj.superficie)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                } else {
                    Text(TextosReloj.routineNone).estilo(.relojCuerpo)
                }
            }
            .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e16))
            .padding(.vertical, PaletaReloj.puntosDeDiseno(TokensEspaciado.e8))
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { estado.cargarPrescripcion() }
        .sheet(isPresented: $mostrarDemostracion) {
            if estado.rutina.indices.contains(estado.ejercicioActual) {
                DemostracionEjercicioView(nombre: estado.rutina[estado.ejercicioActual].nombre)
            }
        }
    }
}

// MARK: - Demostración Animada de Ejercicio (0 KB de Assets)

struct AnimacionSiluetaEjercicio: View {
    let nombre: String
    let progreso: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let t = progreso

            let esPiernas = nombre.localizedCaseInsensitiveContains("sentadilla") || nombre.localizedCaseInsensitiveContains("squat") || nombre.localizedCaseInsensitiveContains("prensa") || nombre.localizedCaseInsensitiveContains("estocada")
            let esPecho = nombre.localizedCaseInsensitiveContains("banca") || nombre.localizedCaseInsensitiveContains("press") || nombre.localizedCaseInsensitiveContains("pecho")

            let colorAtleta = Color(red: 0.95, green: 0.55, blue: 0.15)
            let colorBarra = Color.white.opacity(0.85)

            if esPiernas {
                let drop = t * 18.0
                let cabezaCentro = CGPoint(x: w * 0.5, y: h * 0.22 + drop)
                let cuello = CGPoint(x: w * 0.5, y: h * 0.32 + drop)
                let cadera = CGPoint(x: w * 0.5, y: h * 0.55 + drop)
                let rodillaIzq = CGPoint(x: w * 0.35 + (t * 6), y: h * 0.72 + (drop * 0.4))
                let rodillaDer = CGPoint(x: w * 0.65 - (t * 6), y: h * 0.72 + (drop * 0.4))
                let pieIzq = CGPoint(x: w * 0.32, y: h * 0.92)
                let pieDer = CGPoint(x: w * 0.68, y: h * 0.92)

                context.fill(Path(ellipseIn: CGRect(x: cabezaCentro.x - 7, y: cabezaCentro.y - 7, width: 14, height: 14)), with: .color(colorAtleta))

                var cuerpo = Path()
                cuerpo.move(to: cuello)
                cuerpo.addLine(to: cadera)
                cuerpo.move(to: cadera)
                cuerpo.addLine(to: rodillaIzq)
                cuerpo.addLine(to: pieIzq)
                cuerpo.move(to: cadera)
                cuerpo.addLine(to: rodillaDer)
                cuerpo.addLine(to: pieDer)
                context.stroke(cuerpo, with: .color(colorAtleta), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                var barra = Path()
                barra.move(to: CGPoint(x: w * 0.2, y: cuello.y + 2))
                barra.addLine(to: CGPoint(x: w * 0.8, y: cuello.y + 2))
                context.stroke(barra, with: .color(colorBarra), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else if esPecho {
                let push = (1.0 - t) * 16.0
                let cabeza = CGPoint(x: w * 0.25, y: h * 0.5)
                let hombro = CGPoint(x: w * 0.38, y: h * 0.5)
                let cadera = CGPoint(x: w * 0.75, y: h * 0.5)
                let codo = CGPoint(x: w * 0.42, y: h * 0.42 + (t * 10))
                let mano = CGPoint(x: w * 0.44, y: h * 0.28 + push)

                var banco = Path()
                banco.move(to: CGPoint(x: w * 0.15, y: h * 0.58))
                banco.addLine(to: CGPoint(x: w * 0.85, y: h * 0.58))
                context.stroke(banco, with: .color(Color.gray.opacity(0.5)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                context.fill(Path(ellipseIn: CGRect(x: cabeza.x - 6, y: cabeza.y - 6, width: 12, height: 12)), with: .color(colorAtleta))

                var cuerpo = Path()
                cuerpo.move(to: cabeza)
                cuerpo.addLine(to: hombro)
                cuerpo.addLine(to: cadera)
                cuerpo.move(to: hombro)
                cuerpo.addLine(to: codo)
                cuerpo.addLine(to: mano)
                context.stroke(cuerpo, with: .color(colorAtleta), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                var barra = Path()
                barra.move(to: CGPoint(x: mano.x - 18, y: mano.y))
                barra.addLine(to: CGPoint(x: mano.x + 18, y: mano.y))
                context.stroke(barra, with: .color(colorBarra), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            } else {
                let curl = t * 18.0
                let cabeza = CGPoint(x: w * 0.5, y: h * 0.18)
                let hombro = CGPoint(x: w * 0.5, y: h * 0.28)
                let cadera = CGPoint(x: w * 0.5, y: h * 0.58)
                let codo = CGPoint(x: w * 0.58, y: h * 0.44)
                let mano = CGPoint(x: w * 0.58 - (t * 8), y: h * 0.56 - curl)

                context.fill(Path(ellipseIn: CGRect(x: cabeza.x - 7, y: cabeza.y - 7, width: 14, height: 14)), with: .color(colorAtleta))

                var cuerpo = Path()
                cuerpo.move(to: hombro)
                cuerpo.addLine(to: cadera)
                cuerpo.addLine(to: CGPoint(x: w * 0.42, y: h * 0.9))
                cuerpo.move(to: cadera)
                cuerpo.addLine(to: CGPoint(x: w * 0.58, y: h * 0.9))
                cuerpo.move(to: hombro)
                cuerpo.addLine(to: codo)
                cuerpo.addLine(to: mano)
                context.stroke(cuerpo, with: .color(colorAtleta), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                var pesa = Path()
                pesa.move(to: CGPoint(x: mano.x - 6, y: mano.y))
                pesa.addLine(to: CGPoint(x: mano.x + 6, y: mano.y))
                context.stroke(pesa, with: .color(colorBarra), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }
    }
}

struct DemostracionEjercicioView: View {
    let nombre: String
    @Environment(\.dismiss) private var dismiss
    @State private var faseAnimacion: CGFloat = 0.0

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                HStack {
                    Text(nombre)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(PaletaReloj.textoSecundario)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PaletaReloj.superficie)
                        .frame(height: 90)

                    AnimacionSiluetaEjercicio(nombre: nombre, progreso: faseAnimacion)
                        .frame(width: 80, height: 75)
                }

                Text(TextosReloj.gymTimerCue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PaletaReloj.textoSecundario)
                    .multilineTextAlignment(.center)

                Button {
                    dismiss()
                } label: {
                    Text(TextosReloj.commonContinue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(PaletaReloj.acento)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                faseAnimacion = 1.0
            }
        }
    }
}

// MARK: - Resumen de Gimnasio

struct ResumenGimnasioRelojView: View {
    @EnvironmentObject private var estado: EstadoReloj
    @State private var mostrarConfirmacionDescarte = false

    var body: some View {
        ZStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(PaletaReloj.acento)
                        Text(TextosReloj.finishTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(PaletaReloj.acento)
                        Spacer()
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(TextosReloj.gymSummaryExercises)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PaletaReloj.textoSecundario)
                            Spacer()
                            Text(TextosReloj.commonCountOf(estado.ejerciciosCompletadosGimnasio, estado.rutina.count))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(PaletaReloj.textoPrimario)
                        }

                        HStack {
                            Text(TextosReloj.gymSummarySetsLogged)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PaletaReloj.textoSecundario)
                            Spacer()
                            Text(verbatim: "\(estado.totalSeriesGimnasioHechas)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(PaletaReloj.textoPrimario)
                        }

                        HStack {
                            Text(TextosReloj.gymSummaryReps)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PaletaReloj.textoSecundario)
                            Spacer()
                            Text(verbatim: "\(estado.totalRepeticionesGimnasio)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(PaletaReloj.textoPrimario)
                        }

                        if estado.totalKilosGimnasio > 0 {
                            HStack {
                                Text(TextosReloj.gymSummaryTotalVolume)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PaletaReloj.textoSecundario)
                                Spacer()
                                Text(verbatim: "\(estado.totalKilosGimnasio) kg")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(PaletaReloj.textoPrimario)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(PaletaReloj.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: TokensEspaciado.e8) {
                        Button {
                            estado.guardarGimnasio()
                        } label: {
                            HStack(spacing: TokensEspaciado.e6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                Text(TextosReloj.finishSave)
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundStyle(PaletaReloj.fondo)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(PaletaReloj.acento)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            estado.ir(a: .gimnasio)
                        } label: {
                            HStack(spacing: TokensEspaciado.e6) {
                                Image(systemName: "arrow.backward")
                                    .font(.system(size: 14, weight: .bold))
                                Text(TextosReloj.commonGoBack)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(PaletaReloj.textoPrimario)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(PaletaReloj.superficieAlterna)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            mostrarConfirmacionDescarte = true
                        } label: {
                            HStack(spacing: TokensEspaciado.e6) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(TextosReloj.commonDiscard)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(PaletaReloj.error)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(PaletaReloj.errorFondo)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PaletaReloj.fondo)
            .contentShape(Rectangle())

            if mostrarConfirmacionDescarte {
                modalConfirmacionDescarte
            }
        }
    }

    private var modalConfirmacionDescarte: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    mostrarConfirmacionDescarte = false
                }

            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(PaletaReloj.error)
                        .padding(.top, 4)

                    Text(TextosReloj.commonDiscardConfirmation)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PaletaReloj.textoPrimario)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)

                    VStack(spacing: 8) {
                        Button {
                            mostrarConfirmacionDescarte = false
                        } label: {
                            Text(TextosReloj.commonCancel)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PaletaReloj.textoPrimario)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(PaletaReloj.superficieAlterna)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            mostrarConfirmacionDescarte = false
                            estado.descartarGimnasio()
                        } label: {
                            Text(TextosReloj.commonDiscard)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(PaletaReloj.error)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// El iPhone no está conectado o no se detecta sesión activa (imagen 1).
struct SinTelefonoView: View {
    @EnvironmentObject private var estado: EstadoReloj

    private var mensaje: String {
        switch estado.motivoSinConexion {
        case .sesionNoIniciada:
            return TextosReloj.phoneMissingSignedOut
        case .telefonoDesconectado:
            return TextosReloj.phoneMissingDisconnected
        }
    }

    private var simbolo: String {
        switch estado.motivoSinConexion {
        case .sesionNoIniciada:
            return "person.crop.circle.badge.exclamationmark"
        case .telefonoDesconectado:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }

    var body: some View {
        VStack(spacing: PaletaReloj.puntosDeDiseno(TokensEspaciado.e10)) {
            Spacer(minLength: 0)

            // Ícono de teléfono con el color de la aplicación (PaletaReloj.acento)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PaletaReloj.acento, lineWidth: 2)
                    .frame(width: 32, height: 48)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Image(systemName: simbolo)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PaletaReloj.acento)
                    Spacer(minLength: 0)
                    Circle()
                        .stroke(PaletaReloj.acento, lineWidth: 1.2)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 3)
                }
                .frame(width: 32, height: 48)
            }

            Text(mensaje)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(PaletaReloj.textoPrimario)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e10))
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            VStack(spacing: TokensEspaciado.e6) {
                // Botón principal de reintentar
                Button {
                    estado.reintentarConexion()
                } label: {
                    Text(TextosReloj.phoneMissingRetry)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Color(red: 0.22, green: 0.28, blue: 0.45))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Botón para continuar sin teléfono (permite entrenar de inmediato)
                Button {
                    estado.continuarSinTelefono()
                } label: {
                    Text(TextosReloj.phoneMissingContinueWithout)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PaletaReloj.textoSecundario)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PaletaReloj.puntosDeDiseno(TokensEspaciado.e12))
            .padding(.bottom, PaletaReloj.puntosDeDiseno(TokensEspaciado.e6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaletaReloj.fondo)
        .contentShape(Rectangle())
    }
}
