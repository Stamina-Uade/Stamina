import SwiftUI
import MapKit
import UIKit
import TrainerCore

/// `entreno` — la sesión en vivo a pantalla completa (mockup "4. Entreno en vivo"):
/// píldoras de estado arriba, la distancia protagonista, tiempo y ritmo en
/// tarjetas, el mapa con la ruta en acento y los controles redondos abajo.
///
/// El mapa y sus piezas viven en `MapaDeSalida.swift`, `MapaControles.swift`,
/// `MapaAnotaciones.swift` y `MapaGestorDeInstancia.swift`.
struct EntrenoView: View {
    @EnvironmentObject private var estado: EstadoHome
    @State private var explicarUbicacion = false
    @State private var deporteElegido: DeporteDeSesion = .running
    /// MVP sólo running: la lista arranca (y queda) acotada por `MVP`.
    @State private var deportesDisponibles: [DeporteDeSesion] = MVP.deportes
    @State private var seguirUsuario = true
    @State private var mapHeading: Double = 0.0
    @State private var mapType: MKMapType = .standard
    @State private var is3D = false
    @State private var centrarNorteTrigger = 0
    @State private var centrarUsuarioTrigger = 0
    @State private var mostrarAvisoSinMovimiento = false
    @State private var mostrarDetallePlan = false
    @State private var mostrandoCuentaRegresiva = false
    /// Terminar mientras corre pide confirmación: el botón queda al lado del de pausa.
    @State private var confirmarTerminar = false

    /// El botón grande del centro y los dos chicos que lo acompañan.
    private let diametroPrincipal: CGFloat = TokensEspaciado.e56 + TokensEspaciado.e16
    private let diametroSecundario: CGFloat = TokensEspaciado.e52

    var body: some View {
        Group {
            if let salida = estado.resumenSalida {
                ResumenDeSalidaView(salida: salida) {
                    estado.cerrarResumen()
                }
            } else if mostrandoCuentaRegresiva {
                VistaCuentaRegresiva {
                    mostrandoCuentaRegresiva = false
                    estado.empezarOPausar(deporte: deporteElegido)
                }
            } else {
                contenidoEntreno
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .onAppear {
            let usuarioId = estado.perfil?.id ?? "local"
            deportesDisponibles = deportesOrdenados(usuarioId: usuarioId)
            estado.seguimiento.prepararMapa()
            if let sugerido = deporteSugerido() {
                deporteElegido = sugerido
            }
        }
        .alertaApilada(Textos.workoutPermissionTitle, isPresented: $explicarUbicacion,
                       mensaje: Textos.workoutPermissionDetail,
                       botones: [
                           BotonDeAlerta(Textos.workoutPermissionContinue) {
                               estado.empezarOPausar(deporte: deporteElegido)
                           },
                           BotonDeAlerta(Textos.workoutPermissionCancel, rol: .cancelar),
                       ])
        .alertaApilada(Textos.workoutNoMovementTitle, isPresented: $mostrarAvisoSinMovimiento,
                       mensaje: Textos.workoutNoMovementMessage,
                       botones: [
                           BotonDeAlerta(Textos.commonDiscard, rol: .destructivo) {
                               estado.descartarSesion()
                           },
                           BotonDeAlerta(Textos.commonResume, rol: .cancelar) {
                               // Desde "en curso" no hay nada que reanudar: alternar la pausaría.
                               if estado.estadoDeLaSesion == .pausada {
                                   estado.empezarOPausar(deporte: deporteElegido)
                               }
                           },
                       ])
        .alertaApilada(Textos.workoutFinishConfirm, isPresented: $confirmarTerminar,
                       botones: [
                           BotonDeAlerta(Textos.workoutFinish, rol: .destructivo) { estado.terminarSesion() },
                           BotonDeAlerta(Textos.commonKeepGoing, rol: .cancelar),
                       ])
    }

    /// Los deportes por frecuencia de uso, sólo los que el MVP deja elegir.
    private func deportesOrdenados(usuarioId: String) -> [DeporteDeSesion] {
        let ordenados = GestorDeportesFrecuentes.compartido.deportesOrdenados(usuarioId: usuarioId)
            .filter { MVP.permite($0) }
        return ordenados.isEmpty ? [.running] : ordenados
    }

    /// El deporte a preseleccionar, acotado al MVP (sólo running: siempre running).
    private func deporteSugerido() -> DeporteDeSesion? {
        deporteSugeridoSinAcotar().map { MVP.acotado($0) }
    }

    /// El deporte que conviene preseleccionar: el de la sesión del plan (sólo
    /// trae el título, así que se deduce de él) o, sin sesión, el del perfil.
    private func deporteSugeridoSinAcotar() -> DeporteDeSesion? {
        if let sesion = estado.sesion {
            let tipo = sesion.tipo.lowercased()
            if tipo.contains("natac") || tipo.contains("swim") || tipo.contains("nad") {
                return .natacion
            } else if tipo.contains("bici") || tipo.contains("cicl") {
                return .ciclismo
            } else if tipo.contains("trek") || tipo.contains("camin") {
                return .trekking
            }
            return nil
        }
        switch estado.perfil?.sport {
        case .ciclismo: return .ciclismo
        case .trekking: return .trekking
        default: return nil
        }
    }

    // MARK: - Estructura

    private var contenidoEntreno: some View {
        GeometryReader { geo in
            VStack(spacing: TokensEspaciado.e12) {
                barraSuperior

                ZStack(alignment: .top) {
                    VStack(spacing: TokensEspaciado.e14) {
                        panelDeMetricas
                        tarjetaDelMapa
                    }

                    // El plan de hoy se despliega por encima, sin empujar el mapa.
                    if mostrarDetallePlan, let sesion = estado.sesion {
                        desplegableDeSesion(sesion)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                baseControles
            }
            .padding(.top, safeAreaTop(geo: geo))
            .padding(.bottom, safeAreaBottom(geo: geo))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    /// La raíz presenta esta vista con `.ignoresSafeArea()`: los insets se leen
    /// de la ventana para no quedar debajo de la isla ni del indicador de inicio.
    private func insetsDeVentana() -> UIEdgeInsets? {
        let escena = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return escena?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets
            ?? escena?.windows.first?.safeAreaInsets
    }

    private func safeAreaTop(geo: GeometryProxy) -> CGFloat {
        let topEfectivo = max(geo.safeAreaInsets.top, insetsDeVentana()?.top ?? 0)
        return topEfectivo > 0 ? (topEfectivo + TokensEspaciado.e4) : 54
    }

    private func safeAreaBottom(geo: GeometryProxy) -> CGFloat {
        let abajoEfectivo = max(geo.safeAreaInsets.bottom, insetsDeVentana()?.bottom ?? 0)
        return abajoEfectivo > 0 ? (abajoEfectivo + TokensEspaciado.e4) : TokensEspaciado.e20
    }

    // MARK: - Barra superior

    private var barraSuperior: some View {
        HStack(alignment: .center, spacing: TokensEspaciado.e10) {
            BotonCircular("xmark", etiqueta: Textos.commonBack, estilo: .secundario,
                          diametro: TokensTamano.objetivoTactilMinimo) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    estado.volverDeLaPantallaSecundaria()
                }
            }

            Spacer(minLength: 0)

            // Píldora central con deporte / estado de sesión
            pildoraCentral
                .onTapGesture {
                    if estado.sesion != nil {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            mostrarDetallePlan.toggle()
                        }
                    }
                }

            Spacer(minLength: 0)

            // Contrapeso del botón cerrar: así la píldora queda centrada.
            Color.clear
                .frame(width: TokensTamano.objetivoTactilMinimo, height: TokensTamano.objetivoTactilMinimo)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, TokensEspaciado.e16)
    }

    private var pildoraCentral: some View {
        HStack(spacing: TokensEspaciado.e8) {
            ZStack {
                Circle()
                    .fill(Paleta.acentoSuaveFondo)
                    .frame(width: TokensEspaciado.e26 + TokensEspaciado.e2,
                           height: TokensEspaciado.e26 + TokensEspaciado.e2)
                IconoDeporte(deporte: deporteElegido, color: Paleta.acento, tamano: TokensEspaciado.e13)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e1) {
                Text(tituloPildora)
                    .estilo(.tituloCard)
                    .lineLimit(1)
                Text(subtituloPildora)
                    .estilo(.labelCampo, color: Paleta.textoSecundario)
                    .lineLimit(1)
            }

            if estado.sesion != nil {
                Image(systemName: mostrarDetallePlan ? "chevron.up" : "chevron.down")
                    .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                    .foregroundStyle(Paleta.textoTerciario)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, TokensEspaciado.e12)
        .padding(.vertical, TokensEspaciado.e6)
        .background(Paleta.superficie)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
        .accessibilityElement(children: .combine)
    }

    private var tituloPildora: String {
        if estado.haySesionEnCurso {
            return estado.estadoDeLaSesion == .pausada ? Textos.workoutPaused : (estado.sesion?.tipo ?? Textos.workoutInProgress)
        }
        if let sesion = estado.sesion {
            return sesion.tipo
        }
        return deporteElegido.nombreVisible
    }

    private var subtituloPildora: String {
        if let sesion = estado.sesion {
            return objetivo(de: sesion)
        }
        return estado.haySesionEnCurso ? Textos.workoutGpsRecording : Textos.workoutReadyToStart
    }

    // MARK: - Métricas

    private var estaPausada: Bool { estado.estadoDeLaSesion == .pausada }

    private var unidadDeDistancia: String { Formato.unidadDeDistancia(estado.sistemaDeUnidades) }

    private var panelDeMetricas: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            filaDeEstado

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Textos.commonDistance)
                        .estilo(.etiquetaSeccion, color: Paleta.textoSecundario)
                    Spacer(minLength: 0)
                    if estaPausada {
                        // La pausa se ve sin depender del botón: texto + ícono, en su color.
                        Label(Textos.workoutPaused, systemImage: "pause.fill")
                            .labelStyle(.titleAndIcon)
                            .estilo(.etiquetaSeccion, color: Paleta.controlPausa)
                    }
                }
                MetricaHeroe(
                    Formato.distanciaNumero(estado.metrosDeLaSesion, unidades: estado.sistemaDeUnidades, decimales: 2),
                    unidad: unidadDeDistancia,
                    color: estaPausada ? Paleta.textoSecundario : Paleta.textoPrimario,
                    etiquetaAccesible: Textos.commonDistance
                )
            }

            HStack(spacing: TokensEspaciado.e8) {
                TarjetaMetrica(Textos.workoutDuration,
                               valor: Formato.cronometro(segundos: estado.segundosDeLaSesion),
                               simbolo: "stopwatch")
                tarjetaDeRitmo
                if let metros = estado.sesion?.distanciaMetros {
                    TarjetaMetrica(Textos.workoutTarget,
                                   valor: Formato.distanciaNumero(metros, unidades: estado.sistemaDeUnidades),
                                   unidad: unidadDeDistancia,
                                   simbolo: "flag.checkered")
                }
            }
        }
        .padding(.horizontal, TokensEspaciado.e16)
    }

    /// En bici se mira la velocidad; en el resto, el ritmo.
    @ViewBuilder
    private var tarjetaDeRitmo: some View {
        if deporteElegido == .ciclismo {
            TarjetaMetrica(Textos.commonAvgSpeed,
                           valor: Formato.velocidadNumero(metros: estado.metrosDeLaSesion,
                                                          segundos: estado.segundosDeLaSesion,
                                                          unidades: estado.sistemaDeUnidades,
                                                          decimales: 1),
                           unidad: Formato.unidadDeVelocidad(estado.sistemaDeUnidades),
                           simbolo: "speedometer",
                           destacada: true)
        } else {
            TarjetaMetrica(Textos.commonAvgPace,
                           valor: Formato.ritmo(segundosPorKm: estado.ritmoDeLaSesion, unidades: estado.sistemaDeUnidades),
                           unidad: "/\(unidadDeDistancia)",
                           simbolo: "timer",
                           destacada: true)
        }
    }

    /// Sólo lo que la app sabe de verdad: GPS y reloj. No hay pulso en vivo en
    /// el teléfono, así que esa píldora del mockup no va.
    private var filaDeEstado: some View {
        FlujoHorizontal(espaciado: TokensEspaciado.e6) {
            if estado.salidaVieneDelReloj {
                PildoraDeEstado(Textos.workoutRecordingOnWatch,
                                simbolo: "applewatch", tono: .acento)
            } else if estado.seguimiento.errorDeUbicacion {
                PildoraDeEstado(Textos.workoutGpsNone,
                                simbolo: "location.slash.fill", tono: .alerta)
            } else if estado.ubicacionDeLaSesion != nil {
                PildoraDeEstado(Textos.workoutGpsOk,
                                simbolo: "location.fill", tono: .acento)
            } else {
                PildoraDeEstado(Textos.workoutGpsSearching,
                                simbolo: "location", tono: .neutro)
            }

            if !estado.salidaVieneDelReloj && relojVinculado {
                PildoraDeEstado(Textos.workoutWatchConnected,
                                simbolo: "applewatch", tono: .neutro)
            }
        }
    }

    private var relojVinculado: Bool {
        switch estado.sincronizador.estado {
        case .alDia, .hayQueRevisar: return true
        case .sinPar, .sinAppEnElOtroLado: return false
        }
    }

    // MARK: - Mapa

    private var tarjetaDelMapa: some View {
        ZStack(alignment: .topTrailing) {
            // Mapa interactivo (mantenido caliente en memoria por GestorDeMapa)
            MapaDeSalida(puntos: estado.puntosDeLaSesion,
                         segmentos: estado.seguimiento.segmentos,
                         pausas: estado.seguimiento.pausas,
                         puntosPausaActual: estado.seguimiento.puntosPausaActual,
                         ubicacion: estado.ubicacionDeLaSesion,
                         rumbo: estado.rumboDeLaSesion,
                         mostrarUsuario: true,
                         seguirUsuario: $seguirUsuario,
                         heading: $mapHeading,
                         mapType: mapType,
                         is3D: is3D,
                         centrarNorteTrigger: centrarNorteTrigger,
                         centrarUsuarioTrigger: centrarUsuarioTrigger)

            // Esqueleto mientras se obtiene la primera ubicación
            if estado.ubicacionDeLaSesion == nil {
                VistaEsqueletoMapa()
                    .transition(.opacity)
            }

            botonesDelMapa
                .padding(TokensEspaciado.e8)
        }
        .overlay(alignment: .bottom) {
            avisoDeAvituallamiento
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
        .padding(.horizontal, TokensEspaciado.e16)
    }

    private var estaApuntandoAlNorte: Bool {
        let normal = (mapHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        return normal <= 2.0 || normal >= 358.0
    }

    private var botonesDelMapa: some View {
        VStack(spacing: TokensEspaciado.e6) {
            // Brújula: desaparece apuntando al norte, reaparece al girar
            BotonBrujula(heading: mapHeading) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    centrarNorteTrigger += 1
                    seguirUsuario = true
                }
            }
            .opacity(estaApuntandoAlNorte ? 0 : 1)
            .animation(.easeInOut(duration: 0.25), value: estaApuntandoAlNorte)
            .allowsHitTesting(!estaApuntandoAlNorte)
            .accessibilityHidden(estaApuntandoAlNorte)

            // Capas del mapa (satélite / estándar)
            BotonDelMapa(activo: mapType == .hybrid,
                         etiqueta: Textos.workoutMapSatellite) {
                withAnimation {
                    mapType = (mapType == .standard) ? .hybrid : .standard
                }
            } icono: {
                Image(systemName: "square.2.layers.3d")
                    .font(.system(size: TokensEspaciado.e16, weight: .semibold))
            }

            // Vista 3D
            BotonDelMapa(activo: is3D,
                         etiqueta: Textos.workoutMapView3d) {
                withAnimation {
                    is3D.toggle()
                }
            } icono: {
                Text(verbatim: "3D").estilo(.tituloCard, color: is3D ? Paleta.acento : Paleta.textoPrimario)
            }

            // Antes de empezar, "centrar" vive acá; en curso, abajo junto a la pausa.
            if estado.estadoDeLaSesion == .detenida {
                BotonDelMapa(activo: seguirUsuario, etiqueta: etiquetaCentrar) {
                    centrarEnElUsuario()
                } icono: {
                    IconoMiraUbicacion(centrado: seguirUsuario,
                                       color: seguirUsuario ? Paleta.acento : Paleta.textoPrimario)
                }
            }
        }
    }

    private var etiquetaCentrar: String {
        Textos.workoutMapCenterOnMe
    }

    private func centrarEnElUsuario() {
        withAnimation(.easeInOut) {
            centrarUsuarioTrigger += 1
            seguirUsuario = true
        }
    }

    /// La tarjeta flotante del mockup ("Momento de hidratarte"). Sale de lo que
    /// el plan calculó para hoy; sin avituallamiento no se muestra nada.
    @ViewBuilder
    private var avisoDeAvituallamiento: some View {
        if estado.haySesionEnCurso, !mostrarDetallePlan, let avituallamiento = estado.sesion?.avituallamiento {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { mostrarDetallePlan = true }
            } label: {
                HStack(spacing: TokensEspaciado.e10) {
                    ZStack {
                        Circle()
                            .fill(Paleta.acento)
                            .frame(width: TokensEspaciado.e34, height: TokensEspaciado.e34)
                        Image(systemName: "drop.fill")
                            .font(.system(size: TokensEspaciado.e14, weight: .bold))
                            .foregroundStyle(Paleta.sobreAcento)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                        Text(Textos.workoutFueling)
                            .estilo(.tituloCard)
                        Text(detalleDeAvituallamiento(avituallamiento))
                            .estilo(.labelCampo, color: Paleta.textoSecundario)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up")
                        .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                        .foregroundStyle(Paleta.textoTerciario)
                        .accessibilityHidden(true)
                }
                .padding(TokensEspaciado.e10)
                .background(Paleta.superficieOverlayFondo)
                .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                        .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityElement(children: .combine)
            .accessibilityHint(Textos.workoutOpensTodayPlan)
            .padding(TokensEspaciado.e10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func detalleDeAvituallamiento(_ avituallamiento: AvituallamientoDeSesion) -> String {
        "\(Formato.litros(avituallamiento.mililitrosPorHora))/h · \(avituallamiento.geles) gel · \(avituallamiento.sodioMg) mg"
    }

    // MARK: - Controles

    private var baseControles: some View {
        Group {
            switch estado.estadoDeLaSesion {
            case .detenida:
                controlesDetenido
            case .corriendo:
                controlesEnCurso(pausado: false)
            case .pausada:
                controlesEnCurso(pausado: true)
            }
        }
        .padding(.horizontal, TokensEspaciado.e20)
        .padding(.top, TokensEspaciado.e4)
    }

    /// Un control redondo con su nombre abajo. El nombre es sólo visual: el
    /// botón ya se lo dice a VoiceOver.
    private func control<Boton: View>(_ etiqueta: String,
                                      color: Color = Paleta.textoSecundario,
                                      @ViewBuilder boton: () -> Boton) -> some View {
        VStack(spacing: TokensEspaciado.e6) {
            boton()
                .frame(height: diametroPrincipal)
            Text(etiqueta)
                .estilo(.labelCampo, color: color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    // Estado: DETENIDO (listo para empezar)
    private var controlesDetenido: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            control(deporteElegido.nombreVisible, color: Paleta.textoPrimario) {
                menuDeDeporte
            }

            control(Textos.workoutStart, color: Paleta.acento) {
                BotonCircular("play.fill", etiqueta: Textos.workoutStart,
                              estilo: .primario, diametro: diametroPrincipal) {
                    if estado.seguimiento.errorDeUbicacion {
                        explicarUbicacion = true
                    } else {
                        mostrandoCuentaRegresiva = true
                    }
                }
            }

            control(etiquetaPlan, color: mostrarDetallePlan ? Paleta.acento : Paleta.textoPrimario) {
                BotonCircular("point.topleft.down.to.point.bottomright.curvepath.fill",
                              etiqueta: etiquetaPlan, estilo: .secundario, diametro: diametroSecundario) {
                    withAnimation { mostrarDetallePlan.toggle() }
                }
            }
        }
    }

    private var etiquetaPlan: String {
        estado.sesion != nil ? Textos.workoutTodayPlan : Textos.workoutRoutes
    }

    /// Con un solo deporte posible (MVP sólo running) no hay nada que elegir:
    /// queda el ícono quieto, sin menú.
    @ViewBuilder
    private var menuDeDeporte: some View {
        if deportesDisponibles.count <= 1 {
            iconoDelDeporteElegido
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Textos.workoutSport)
                .accessibilityValue(deporteElegido.nombreVisible)
        } else {
            menuDeDeporteConOpciones
        }
    }

    private var iconoDelDeporteElegido: some View {
        ZStack {
            Circle()
                .fill(Paleta.superficieAlterna)
            Circle()
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            IconoDeporte(deporte: deporteElegido, color: Paleta.acento, tamano: TokensEspaciado.e20)
        }
        .frame(width: diametroSecundario, height: diametroSecundario)
    }

    private var menuDeDeporteConOpciones: some View {
        Menu {
            ForEach(deportesDisponibles, id: \.self) { dep in
                Button {
                    deporteElegido = dep
                    let usuarioId = estado.perfil?.id ?? "local"
                    GestorDeportesFrecuentes.compartido.registrarSeleccion(deporte: dep, usuarioId: usuarioId)
                    deportesDisponibles = deportesOrdenados(usuarioId: usuarioId)
                } label: {
                    Label {
                        Text(dep.nombreVisible)
                    } icon: {
                        IconoDeporte(deporte: dep, color: Paleta.acento, tamano: TokensEspaciado.e16)
                    }
                }
            }
        } label: {
            iconoDelDeporteElegido
                .contentShape(Circle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(Textos.workoutSport)
        .accessibilityValue(deporteElegido.nombreVisible)
    }

    // Estado: EN CURSO o PAUSADO. El botón grande alterna; su ícono y su nombre
    // dicen en qué estado está, cada uno con su color de control.
    private func controlesEnCurso(pausado: Bool) -> some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            control(Textos.workoutMapCenter,
                    color: seguirUsuario ? Paleta.acento : Paleta.textoSecundario) {
                BotonCircular(seguirUsuario ? "location.fill" : "location",
                              etiqueta: etiquetaCentrar, estilo: .secundario, diametro: diametroSecundario) {
                    centrarEnElUsuario()
                }
            }

            control(pausado ? Textos.commonResume : Textos.workoutPause,
                    color: pausado ? Paleta.controlReanudar : Paleta.controlPausa) {
                BotonCircular(pausado ? "play.fill" : "pause.fill",
                              etiqueta: pausado ? Textos.commonResume : Textos.workoutPause,
                              estilo: .primario, diametro: diametroPrincipal) {
                    estado.empezarOPausar(deporte: deporteElegido)
                }
            }

            control(Textos.workoutFinish, color: Paleta.error) {
                BotonCircular("stop.fill", etiqueta: Textos.workoutFinish,
                              estilo: .secundario, diametro: diametroSecundario) {
                    terminar(desdePausa: pausado)
                }
            }
        }
    }

    /// Una salida sin movimiento no se guarda: se ofrece descartarla. En pausa
    /// se termina directo (como siempre); en curso, primero se confirma.
    private func terminar(desdePausa: Bool) {
        if ValidadorDeSalida.sePuedeGuardar(segundos: estado.segundosDeLaSesion, metros: estado.metrosDeLaSesion) {
            if desdePausa {
                estado.terminarSesion()
            } else {
                confirmarTerminar = true
            }
        } else {
            mostrarAvisoSinMovimiento = true
        }
    }

    // MARK: - Desplegable de Plan

    private func desplegableDeSesion(_ sesion: SesionDelDia) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                HStack {
                    Text(sesion.tipo).estilo(.tituloCardGrande)
                    Spacer()
                    Button {
                        withAnimation { mostrarDetallePlan = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: TokensEspaciado.e20))
                            .foregroundStyle(Paleta.textoTerciario)
                            .frame(width: TokensTamano.objetivoTactilMinimo,
                                   height: TokensTamano.objetivoTactilMinimo)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Textos.workoutClosePlan)
                }

                Text(objetivo(de: sesion))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)

                VStack(spacing: TokensEspaciado.e6) {
                    ForEach(Array(sesion.bloques.enumerated()), id: \.element.id) { indice, bloque in
                        FilaDeBloque(bloque: bloque,
                                     activo: estado.haySesionEnCurso && indice == 1,
                                     pasado: estado.haySesionEnCurso && indice < 1)
                    }
                }

                if let avituallamiento = sesion.avituallamiento {
                    Text(Textos.workoutFueling)
                        .estilo(.etiquetaSeccion, color: Paleta.acento)
                        .padding(.top, TokensEspaciado.e4)
                    FlujoHorizontal(espaciado: TokensEspaciado.e6) {
                        ChipInformativo(texto: Textos.homeGelCount(avituallamiento.geles), destacado: true)
                        ChipInformativo(texto: Formato.litros(avituallamiento.mililitrosTotales), destacado: true)
                        ChipInformativo(texto: "\(avituallamiento.sodioMg) mg", destacado: true)
                    }
                }
            }
            .padding(TokensEspaciado.e16)
        }
        .frame(maxHeight: 260)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
        .padding(.horizontal, TokensEspaciado.e16)
        .padding(.top, TokensEspaciado.e8)
    }

    // MARK: - Helpers

    private func objetivo(de sesion: SesionDelDia) -> String {
        var partes: [String] = []
        if let metros = sesion.distanciaMetros {
            partes.append(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))
        }
        if let zona = sesion.zona { partes.append(Textos.zoneAccessibility(zona.numero)) }
        return partes.joined(separator: " · ")
    }
}

// MARK: - Botón flotante del mapa

/// Los botones redondos chicos que van sobre el mapa (capas, 3D, centrar). El
/// borde y el ícono se pintan de acento cuando la opción está activa.
private struct BotonDelMapa<Icono: View>: View {
    let activo: Bool
    let etiqueta: String
    let accion: () -> Void
    @ViewBuilder let icono: () -> Icono

    var body: some View {
        Button(action: accion) {
            ZStack {
                Circle()
                    .fill(Paleta.superficieOverlayFondo)
                Circle()
                    .strokeBorder(activo ? Paleta.acento : Paleta.bordeBotonSecundario, lineWidth: TokensEspaciado.e1)
                icono()
                    .foregroundStyle(activo ? Paleta.acento : Paleta.textoPrimario)
            }
            .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e44)
            .frame(width: TokensTamano.objetivoTactilMinimo, height: TokensTamano.objetivoTactilMinimo)
            .contentShape(Circle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(etiqueta)
        .accessibilityAddTraits(activo ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}
