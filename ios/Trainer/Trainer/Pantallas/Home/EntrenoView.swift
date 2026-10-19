import SwiftUI
import MapKit
import TrainerCore

/// `entreno` — la sesión a pantalla completa al estilo Strava (imagen 3):
/// mapa interactivo con brújula que rota según el heading y reorienta al norte,
/// botones flotantes (capas, 3D, centrar), tarjeta flotante de métricas y dock inferior balanceado.
struct EntrenoView: View {
    @EnvironmentObject private var estado: EstadoHome
    @State private var explicarUbicacion = false
    @State private var deporteElegido: DeporteDeSesion = .running
    @State private var deportesDisponibles: [DeporteDeSesion] = [
        .running,
        .ciclismo,
        .natacion,
        .trekking,
        .triatlon
    ]
    @State private var seguirUsuario = true
    @State private var mapHeading: Double = 0.0
    @State private var mapType: MKMapType = .standard
    @State private var is3D = false
    @State private var centrarNorteTrigger = 0
    @State private var centrarUsuarioTrigger = 0
    @State private var mostrarAvisoSinMovimiento = false
    @State private var mostrarDetallePlan = false
    @State private var mostrandoCuentaRegresiva = false

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
            deportesDisponibles = GestorDeportesFrecuentes.compartido.deportesOrdenados(usuarioId: usuarioId)
            estado.seguimiento.prepararMapa()
            if let sesion = estado.sesion {
                let tipo = sesion.tipo.lowercased()
                if tipo.contains("natac") || tipo.contains("swim") || tipo.contains("nad") {
                    deporteElegido = .natacion
                } else if tipo.contains("bici") || tipo.contains("cicl") {
                    deporteElegido = .ciclismo
                } else if tipo.contains("trek") || tipo.contains("camin") {
                    deporteElegido = .trekking
                }
            } else {
                switch estado.perfil?.sport {
                case .ciclismo: deporteElegido = .ciclismo
                case .trekking: deporteElegido = .trekking
                default: break
                }
            }
        }
        .alert(Textos.entrenoPermisoTitulo, isPresented: $explicarUbicacion) {
            Button(Textos.entrenoPermisoContinuar) { estado.empezarOPausar(deporte: deporteElegido) }
            Button(Textos.entrenoPermisoCancelar, role: .cancel) {}
        } message: {
            Text(Textos.entrenoPermisoDetalle)
        }
        .alert("Sin movimiento", isPresented: $mostrarAvisoSinMovimiento) {
            Button("Reanudar", role: .cancel) {
                estado.empezarOPausar(deporte: deporteElegido)
            }
            Button("Descartar", role: .destructive) {
                estado.descartarSesion()
            }
        } message: {
            Text("El entrenamiento no registró desplazamiento suficiente o duró menos de 10 segundos. ¿Deseas descartarlo o reanudarlo?")
        }
    }

    private var contenidoEntreno: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // 1. Mapa interactivo de fondo completo (mantenido caliente en memoria)
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
                    .ignoresSafeArea()

                // 2. Vista de esqueleto mientras se obtiene la primera ubicación
                if estado.ubicacionDeLaSesion == nil {
                    VistaEsqueletoMapa()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // 3. Capa de controles superiores y flotantes
                VStack(spacing: 0) {
                    barraSuperior
                        .padding(.top, safeAreaTop(geo: geo))

                    if mostrarDetallePlan, let sesion = estado.sesion {
                        desplegableDeSesion(sesion)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)

                    // Botones flotantes laterales a la derecha
                    HStack {
                        Spacer()
                        botonesFlotantesDerecha
                    }
                    .padding(.bottom, TokensEspaciado.e12)

                    // Tarjeta flotante de métricas
                    tarjetaEstadisticasFlotante
                        .padding(.bottom, TokensEspaciado.e10)

                    // Dock inferior con controles circulares
                    baseControles
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea()
    }

    private func safeAreaTop(geo: GeometryProxy) -> CGFloat {
        #if canImport(UIKit)
        let escena = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        let windowTop = escena?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top
            ?? escena?.windows.first?.safeAreaInsets.top ?? 0
        let topEfectivo = max(geo.safeAreaInsets.top, windowTop)
        return topEfectivo > 0 ? (topEfectivo + TokensEspaciado.e4) : 54
        #else
        return max(geo.safeAreaInsets.top, 54)
        #endif
    }

    // MARK: - Barra Superior

    private var barraSuperior: some View {
        HStack(alignment: .center, spacing: TokensEspaciado.e10) {
            // Botón cerrar (círculo adaptativo día/noche con X accesible y un poco más pequeña)
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    estado.volverDeLaPantallaSecundaria()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Paleta.textoPrimario)
                    .frame(width: 44, height: 44)
                    .background(Paleta.superficieOverlayFondo)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Paleta.bordeBotonSecundario, lineWidth: 1))
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityLabel(Textos.comunVolver)

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

            // Botón brújula táctica profesional: desaparece apuntando al norte, reaparece al girar
            BotonBrujula(heading: mapHeading) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    centrarNorteTrigger += 1
                    seguirUsuario = true
                }
            }
            .opacity(estaApuntandoAlNorte ? 0 : 1)
            .animation(.easeInOut(duration: 0.25), value: estaApuntandoAlNorte)
            .allowsHitTesting(!estaApuntandoAlNorte)
        }
        .padding(.horizontal, TokensEspaciado.e16)
    }

    private var estaApuntandoAlNorte: Bool {
        let normal = (mapHeading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        return normal <= 2.0 || normal >= 358.0
    }

    private var pildoraCentral: some View {
        HStack(spacing: TokensEspaciado.e8) {
            ZStack {
                Circle()
                    .fill(Paleta.acento.opacity(0.2))
                    .frame(width: 28, height: 28)
                IconoDeporte(deporte: deporteElegido, color: Paleta.acento, tamano: 13)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(tituloPildora)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                    .lineLimit(1)
                Text(subtituloPildora)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Paleta.textoSecundario)
                    .lineLimit(1)
            }

            if estado.sesion != nil {
                Image(systemName: mostrarDetallePlan ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Paleta.textoTerciario)
            }
        }
        .padding(.horizontal, TokensEspaciado.e12)
        .padding(.vertical, TokensEspaciado.e6)
        .background(Paleta.superficieOverlayFondo)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Paleta.bordeInput, lineWidth: 1))
    }

    private var tituloPildora: String {
        if estado.haySesionEnCurso {
            return estado.estadoDeLaSesion == .pausada ? "En pausa" : (estado.sesion?.tipo ?? "Entrenamiento en curso")
        }
        if let sesion = estado.sesion {
            return sesion.tipo
        }
        return nombreDeporte(deporteElegido)
    }

    private var subtituloPildora: String {
        if let sesion = estado.sesion {
            return objetivo(de: sesion)
        }
        return estado.haySesionEnCurso ? "Grabando GPS" : "Listo para iniciar"
    }

    // MARK: - Botones Flotantes Laterales

    private var botonesFlotantesDerecha: some View {
        VStack(spacing: TokensEspaciado.e10) {
            // 1. Selector de Capas del Mapa (Satélite / Estándar)
            Button {
                withAnimation {
                    mapType = (mapType == .standard) ? .hybrid : .standard
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Paleta.superficieOverlayFondo)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(mapType == .hybrid ? Paleta.acento : Paleta.bordeBotonSecundario, lineWidth: 1))
                    Image(systemName: "square.2.layers.3d")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(mapType == .hybrid ? Paleta.acento : Paleta.textoPrimario)
                }
            }
            .buttonStyle(EstiloPresionado())

            // 2. Botón 3D
            Button {
                withAnimation {
                    is3D.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Paleta.superficieOverlayFondo)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(is3D ? Paleta.acento : Paleta.bordeBotonSecundario, lineWidth: 1))
                    Text("3D")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(is3D ? Paleta.acento : Paleta.textoPrimario)
                }
            }
            .buttonStyle(EstiloPresionado())

            // 3. Recentrar en el usuario
            Button {
                withAnimation(.easeInOut) {
                    centrarUsuarioTrigger += 1
                    seguirUsuario = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Paleta.superficieOverlayFondo)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(seguirUsuario ? Paleta.acento : Paleta.bordeBotonSecundario, lineWidth: 1))
                    IconoMiraUbicacion(centrado: seguirUsuario, color: seguirUsuario ? Paleta.acento : Paleta.textoPrimario)
                }
            }
            .buttonStyle(EstiloPresionado())
        }
        .padding(.trailing, TokensEspaciado.e16)
    }

    // MARK: - Tarjeta Flotante de Métricas

    private var tarjetaEstadisticasFlotante: some View {
        VStack(spacing: TokensEspaciado.e10) {
            // Encabezado de la tarjeta con nombre de deporte e icono de expandir
            HStack {
                Text(estado.sesion?.tipo ?? nombreDeporte(deporteElegido))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Paleta.textoPrimario)
                Spacer()
                if estado.sesion != nil {
                    Button {
                        withAnimation { mostrarDetallePlan.toggle() }
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Paleta.textoSecundario)
                    }
                }
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e12)

            // Cuadrícula 3 columnas: Duración, Ritmo/Velocidad, Distancia
            HStack(spacing: 0) {
                // Columna 1: Duración
                columnaMetrica(
                    valor: Formato.cronometro(segundos: estado.segundosDeLaSesion),
                    etiqueta: Textos.entrenoDuracion
                )

                divisorEstadistica

                // Columna 2: Ritmo o Velocidad promedio
                if deporteElegido == .ciclismo {
                    let velocidadTexto = Formato.velocidadNumero(
                        metros: estado.metrosDeLaSesion,
                        segundos: estado.segundosDeLaSesion,
                        unidades: estado.sistemaDeUnidades,
                        decimales: 1
                    )
                    let unidadVelocidad = Formato.unidadDeVelocidad(estado.sistemaDeUnidades)
                    columnaMetrica(
                        valor: velocidadTexto,
                        etiqueta: "\(unidadVelocidad) promedio"
                    )
                } else {
                    columnaMetrica(
                        valor: Formato.ritmo(segundosPorKm: estado.ritmoDeLaSesion, unidades: estado.sistemaDeUnidades),
                        etiqueta: "ritmo prom. (/\(estado.sistemaDeUnidades == .imperial ? "mi" : "km"))"
                    )
                }

                divisorEstadistica

                // Columna 3: Distancia
                columnaMetrica(
                    valor: Formato.distancia(estado.metrosDeLaSesion, unidades: estado.sistemaDeUnidades, decimales: 2),
                    etiqueta: "Distancia (\(estado.sistemaDeUnidades == .imperial ? "mi" : "km"))"
                )
            }
            .padding(.horizontal, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e14)
        }
        .background(Paleta.superficieOverlayFondo)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeInput, lineWidth: 1)
        )
        .padding(.horizontal, TokensEspaciado.e16)
    }

    private func columnaMetrica(valor: String, etiqueta: String) -> some View {
        VStack(spacing: TokensEspaciado.e3) {
            Text(valor)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Paleta.textoPrimario)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(etiqueta)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Paleta.textoTerciario)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var divisorEstadistica: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(width: 1, height: 32)
    }

    // MARK: - Dock Inferior

    private var baseControles: some View {
        VStack(spacing: TokensEspaciado.e12) {
            // Tirador central
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, TokensEspaciado.e8)

            switch estado.estadoDeLaSesion {
            case .detenida:
                controlesDetenido
            case .corriendo:
                controlesCorriendo
            case .pausada:
                controlesPausado
            }
        }
        .padding(.horizontal, TokensEspaciado.e20)
        .padding(.top, TokensEspaciado.e12)
        .padding(.bottom, TokensEspaciado.e34)
        .frame(maxWidth: .infinity)
        .background(
            Paleta.fondo
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // Estado: DETENIDO (Listo para empezar)
    private var controlesDetenido: some View {
        HStack(alignment: .center) {
            // Botón 1: Deporte
            Menu {
                ForEach(deportesDisponibles, id: \.self) { dep in
                    Button {
                        deporteElegido = dep
                        let usuarioId = estado.perfil?.id ?? "local"
                        GestorDeportesFrecuentes.compartido.registrarSeleccion(deporte: dep, usuarioId: usuarioId)
                        deportesDisponibles = GestorDeportesFrecuentes.compartido.deportesOrdenados(usuarioId: usuarioId)
                    } label: {
                        Label {
                            Text(nombreDeporte(dep))
                        } icon: {
                            IconoDeporte(deporte: dep, color: Paleta.acento, tamano: 18)
                        }
                    }
                }
            } label: {
                VStack(spacing: TokensEspaciado.e4) {
                    ZStack {
                        Circle()
                            .fill(Paleta.superficieOverlay)
                            .frame(width: 56, height: 56)
                            .overlay(Circle().strokeBorder(Paleta.bordeInput, lineWidth: 1))
                        IconoDeporte(deporte: deporteElegido, color: Paleta.acento, tamano: 22)
                    }
                    Text(nombreDeporte(deporteElegido))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Paleta.textoPrimario)
                }
            }
            .buttonStyle(EstiloPresionado())
            .frame(maxWidth: .infinity)

            // Botón 2: INICIO (Acento 72x72)
            Button {
                if estado.seguimiento.errorDeUbicacion {
                    explicarUbicacion = true
                } else {
                    mostrandoCuentaRegresiva = true
                }
            } label: {
                VStack(spacing: TokensEspaciado.e4) {
                    ZStack {
                        Circle()
                            .fill(Paleta.acento)
                            .frame(width: 72, height: 72)
                            .shadow(color: Paleta.acento.opacity(0.35), radius: 8, y: 3)
                        Image(systemName: "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Paleta.sobreAcento)
                            .offset(x: 2)
                    }
                    Text(Textos.entrenoEmpezar)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                }
            }
            .buttonStyle(EstiloPresionado())
            .frame(maxWidth: .infinity)

            // Botón 3: Rutas / Plan
            Button {
                withAnimation { mostrarDetallePlan.toggle() }
            } label: {
                VStack(spacing: TokensEspaciado.e4) {
                    ZStack {
                        Circle()
                            .fill(Paleta.superficieOverlay)
                            .frame(width: 56, height: 56)
                            .overlay(Circle().strokeBorder(mostrarDetallePlan ? Paleta.acento : Paleta.bordeInput, lineWidth: 1))
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(mostrarDetallePlan ? Paleta.acento : Paleta.textoPrimario)
                    }
                    Text(estado.sesion != nil ? "Plan de hoy" : "Rutas")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Paleta.textoPrimario)
                }
            }
            .buttonStyle(EstiloPresionado())
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, TokensEspaciado.e6)
    }

    // Estado: CORRIENDO (En curso)
    private var controlesCorriendo: some View {
        Button {
            estado.empezarOPausar(deporte: deporteElegido)
        } label: {
            VStack(spacing: TokensEspaciado.e4) {
                ZStack {
                    Circle()
                        .fill(Paleta.controlPausa)
                        .frame(width: 72, height: 72)
                        .shadow(color: Paleta.controlPausa.opacity(0.35), radius: 8, y: 3)
                    Image(systemName: "pause.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Paleta.sobreControlPausa)
                }
                Text(Textos.entrenoPausar)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Paleta.controlPausa)
            }
        }
        .buttonStyle(EstiloPresionado())
        .padding(.vertical, TokensEspaciado.e6)
    }

    // Estado: PAUSADO (Reanudar o Finalizar)
    private var controlesPausado: some View {
        HStack(spacing: TokensEspaciado.e34) {
            // Reanudar
            Button {
                estado.empezarOPausar(deporte: deporteElegido)
            } label: {
                VStack(spacing: TokensEspaciado.e4) {
                    ZStack {
                        Circle()
                            .fill(Paleta.controlReanudar)
                            .frame(width: 68, height: 68)
                            .shadow(color: Paleta.controlReanudar.opacity(0.35), radius: 8, y: 3)
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Paleta.sobreControlPausa)
                            .offset(x: 2)
                    }
                    Text(Textos.entrenoReanudar)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Paleta.controlReanudar)
                }
            }
            .buttonStyle(EstiloPresionado())

            // Finalizar
            Button {
                if ValidadorDeSalida.sePuedeGuardar(segundos: estado.segundosDeLaSesion, metros: estado.metrosDeLaSesion) {
                    estado.terminarSesion()
                } else {
                    mostrarAvisoSinMovimiento = true
                }
            } label: {
                VStack(spacing: TokensEspaciado.e4) {
                    ZStack {
                        Circle()
                            .fill(Paleta.errorFondo)
                            .frame(width: 68, height: 68)
                            .overlay(Circle().strokeBorder(Paleta.errorBorde, lineWidth: 1.5))
                        Image(systemName: "flag.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Paleta.error)
                    }
                    Text(Textos.entrenoTerminar)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Paleta.error)
                }
            }
            .buttonStyle(EstiloPresionado())
        }
        .padding(.vertical, TokensEspaciado.e6)
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
                            .font(.system(size: 20))
                            .foregroundStyle(Paleta.textoTerciario)
                    }
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
                    Text(Textos.entrenoAvituallamiento)
                        .estilo(.etiquetaSeccion, color: Paleta.acento)
                        .padding(.top, TokensEspaciado.e4)
                    FlujoHorizontal(espaciado: TokensEspaciado.e6) {
                        ChipInformativo(texto: "\(avituallamiento.geles) gel", destacado: true)
                        ChipInformativo(texto: Formato.litros(avituallamiento.mililitrosTotales), destacado: true)
                        ChipInformativo(texto: "\(avituallamiento.sodioMg) mg", destacado: true)
                    }
                }
            }
            .padding(TokensEspaciado.e16)
        }
        .frame(maxHeight: 260)
        .background(Paleta.fondo)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.bordeInput, lineWidth: 1)
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
        if let zona = sesion.zona { partes.append(Textos.zonaVoiceover(zona.numero)) }
        return partes.joined(separator: " · ")
    }

    private func iconoDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return "figure.run"
        case .ciclismo: return "bicycle"
        case .trekking: return "figure.hiking"
        case .natacion: return "figure.pool.swim"
        case .fuerza: return "dumbbell.fill"
        case .otro: return "figure.mixed.cardio"
        case .triatlon: return "figure.mixed.cardio"
        }
    }

    private func nombreDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return "Carrera"
        case .ciclismo: return "Bicicleta"
        case .natacion: return "Natación"
        case .trekking: return "Caminata"
        case .fuerza: return "Fuerza"
        case .otro: return "Otro"
        case .triatlon: return "Triatlón"
        }
    }
}

// MARK: - Ícono Mira de Ubicación (Imagen 3)

struct IconoMiraUbicacion: View {
    let centrado: Bool
    var color: Color = Paleta.textoPrimario

    var body: some View {
        ZStack {
            // Ticks de la mira (4 marcas perpendiculares saliendo del círculo exterior)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 22)

            Rectangle()
                .fill(color)
                .frame(width: 22, height: 2)

            // Círculo exterior
            Circle()
                .fill(Paleta.superficieOverlayFondo)
                .frame(width: 17, height: 17)

            Circle()
                .strokeBorder(color, lineWidth: 2)
                .frame(width: 17, height: 17)

            // Punto central: lleno si está centrado en el usuario, vacío/hueco si no
            if centrado {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Botón Brújula (Estilo Imágenes 1, 2, 3)

struct TrianguloHaciaCentro: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Base en la parte superior (borde exterior), vértice apuntando hacia abajo (al centro)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct BotonBrujula: View {
    let heading: Double
    let accion: () -> Void

    private var headingNormalizado: Double {
        (heading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    private var letraCardinal: String {
        let idioma = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "es"
        let normal = headingNormalizado
        let esIngles = (idioma == "en")
        switch normal {
        case 337.5...360.0, 0.0..<22.5: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return esIngles ? "SW" : "SO"
        case 247.5..<292.5: return esIngles ? "W" : "O"
        case 292.5..<337.5: return esIngles ? "NW" : "NO"
        default: return "N"
        }
    }

    var body: some View {
        Button(action: accion) {
            ZStack {
                // 1. Círculo oscuro de fondo (tamaño chico: 44x44, Imágenes 1, 2, 3)
                Circle()
                    .fill(Color(red: 0.11, green: 0.12, blue: 0.14))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)

                // 2. Roseta / dial que rota con el mapa (-heading)
                ZStack {
                    // Marcas finas alrededor del círculo (cada 22.5°, omitiendo los 4 cardinales)
                    ForEach(0..<16) { i in
                        let angulo = Double(i) * 22.5
                        if i % 4 != 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.42))
                                .frame(width: 1.0, height: 3.2)
                                .offset(y: -18.0)
                                .rotationEffect(.degrees(angulo))
                        }
                    }

                    // Triángulo rojo en el borde señalando hacia el Norte y que se mueve al girar
                    TrianguloHaciaCentro()
                        .fill(Color(red: 0.95, green: 0.20, blue: 0.20))
                        .frame(width: 5.5, height: 4.8)
                        .offset(y: -17.5)
                        .rotationEffect(.degrees(0))

                    // Pequeños triángulos blancos en los otros puntos cardinales (E, S, O)
                    ForEach([90.0, 180.0, 270.0], id: \.self) { angulo in
                        TrianguloHaciaCentro()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 4.6, height: 3.8)
                            .offset(y: -18.0)
                            .rotationEffect(.degrees(angulo))
                    }
                }
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-heading))

                // 3. Letra de la dirección actual en el centro: blanca, grande y fija
                Text(letraCardinal)
                    .font(.system(
                        size: letraCardinal.count > 1 ? 13 : 18,
                        weight: .heavy,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel("Brújula, orientación \(letraCardinal), \(Int(headingNormalizado)) grados")
    }
}

// MARK: - Fila de Bloque

struct FilaDeBloque: View {
    let bloque: BloqueDeSesion
    let activo: Bool
    let pasado: Bool

    var body: some View {
        HStack(spacing: TokensEspaciado.e9) {
            Circle()
                .fill(activo ? Paleta.acento : Paleta.bordeSignificante)
                .frame(width: TokensEspaciado.e5, height: TokensEspaciado.e5)

            VStack(alignment: .leading, spacing: TokensEspaciado.e1) {
                Text(bloque.titulo).estilo(.labelCampo)
                Text(bloque.detalle)
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let insignia = insigniaVisible {
                Text(insignia)
                    .estilo(.etiquetaSeccion.enMinusculas, color: activo ? Paleta.acento : Paleta.textoTerciario)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, TokensEspaciado.e10)
        .padding(.vertical, TokensEspaciado.e8)
        .background(activo ? Paleta.acentoSuaveFondo : Paleta.superficieHundida)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.chip, style: .continuous)
                .strokeBorder(activo ? Paleta.acentoSuaveBorde : Paleta.divisor, lineWidth: TokensEspaciado.e1)
        )
        .opacity(pasado ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private var insigniaVisible: String? {
        if activo { return bloque.insignia ?? Textos.entrenoEnCurso }
        if pasado { return Textos.planHecho }
        return bloque.insignia
    }
}

// MARK: - Cono de Rumbo y Marcador de Ubicación en UIKit Nativo

final class VistaConoRumbo: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 38.0
        let spread: CGFloat = .pi / 5.5
        let startAngle: CGFloat = -.pi / 2.0 - spread
        let endAngle: CGFloat = -.pi / 2.0 + spread

        let path = UIBezierPath()
        path.move(to: center)
        path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.close()

        // Relleno degradado radial
        ctx.saveGState()
        path.addClip()

        let colors: [CGColor] = [
            UIColor(red: 0.20, green: 0.70, blue: 1.0, alpha: 0.85).cgColor,
            UIColor(red: 0.10, green: 0.55, blue: 1.0, alpha: 0.15).cgColor
        ]
        let locations: [CGFloat] = [8.0 / radius, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 8.0, endCenter: center, endRadius: radius, options: [])
        }
        ctx.restoreGState()

        // Borde exterior del cono
        ctx.saveGState()
        ctx.setStrokeColor(UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.45).cgColor)
        ctx.setLineWidth(1.0)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

final class VistaAnotacionUsuarioConRumbo: MKAnnotationView {
    private let vistaCono = VistaConoRumbo(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
    private let haloView = UIView()
    private let puntoView = UIView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        centerOffset = CGPoint(x: 0, y: 0)
        backgroundColor = .clear
        canShowCallout = false
        isUserInteractionEnabled = false

        // 1. Cono de rumbo
        addSubview(vistaCono)

        // 2. Halo azul translúcido
        haloView.frame = CGRect(x: 26, y: 26, width: 28, height: 28)
        haloView.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 1.0, alpha: 0.25)
        haloView.layer.cornerRadius = 14
        haloView.isUserInteractionEnabled = false
        addSubview(haloView)

        // 3. Punto de ubicación normal con borde blanco
        puntoView.frame = CGRect(x: 31, y: 31, width: 18, height: 18)
        puntoView.backgroundColor = UIColor(red: 0.05, green: 0.5, blue: 1.0, alpha: 1.0)
        puntoView.layer.cornerRadius = 9
        puntoView.layer.borderColor = UIColor.white.cgColor
        puntoView.layer.borderWidth = 2.5
        puntoView.layer.shadowColor = UIColor.black.cgColor
        puntoView.layer.shadowOpacity = 0.35
        puntoView.layer.shadowRadius = 2
        puntoView.layer.shadowOffset = CGSize(width: 0, height: 1)
        puntoView.isUserInteractionEnabled = false
        addSubview(puntoView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        vistaCono.transform = .identity
    }

    func actualizar(rumboCelular: Double, rumboCamara: Double = 0.0) {
        let anguloPantalla = (rumboCelular - rumboCamara).truncatingRemainder(dividingBy: 360.0)
        let radians = CGFloat(anguloPantalla * .pi / 180.0)
        vistaCono.transform = CGAffineTransform(rotationAngle: radians)
        vistaCono.isHidden = (rumboCelular <= 0)
    }

    func actualizar(rumbo: Double) {
        actualizar(rumboCelular: rumbo, rumboCamara: 0.0)
    }
}

// MARK: - Gestor de Instancia Reutilizable de Mapa (Pool / Warm Cache)

@MainActor
final class GestorDeMapa {
    static let shared = GestorDeMapa()

    private var mapaInstancia: MKMapView?

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.liberarSiNoEstaEnUso()
            }
        }
    }

    func precalentar() {
        if mapaInstancia == nil {
            let mapa = MKMapView(frame: UIScreen.main.bounds)
            mapa.overrideUserInterfaceStyle = .dark
            mapa.showsCompass = false
            mapa.isRotateEnabled = true
            mapa.isPitchEnabled = true
            mapa.isScrollEnabled = true
            mapa.isZoomEnabled = true
            mapaInstancia = mapa
        }
    }

    func obtenerMapa() -> MKMapView {
        if let mapa = mapaInstancia {
            mapa.removeFromSuperview()
            return mapa
        }
        let mapa = MKMapView(frame: UIScreen.main.bounds)
        mapa.overrideUserInterfaceStyle = .dark
        mapa.showsCompass = false
        mapa.isRotateEnabled = true
        mapa.isPitchEnabled = true
        mapa.isScrollEnabled = true
        mapa.isZoomEnabled = true
        mapaInstancia = mapa
        return mapa
    }

    func liberarSiNoEstaEnUso() {
        guard let mapa = mapaInstancia, mapa.superview == nil else { return }
        mapa.delegate = nil
        mapa.removeAnnotations(mapa.annotations)
        mapa.removeOverlays(mapa.overlays)
        mapaInstancia = nil
    }
}

// MARK: - Contenedor de Vista de Mapa

final class ContenedorMapaView: UIView {
    private weak var mapa: MKMapView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = UIColor(Paleta.fondo)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func alojar(mapa: MKMapView) {
        if self.mapa === mapa && mapa.superview == self { return }
        self.mapa = mapa
        mapa.removeFromSuperview()
        mapa.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mapa)
        NSLayoutConstraint.activate([
            mapa.topAnchor.constraint(equalTo: topAnchor),
            mapa.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapa.trailingAnchor.constraint(equalTo: trailingAnchor),
            mapa.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func desalojar() {
        mapa?.removeFromSuperview()
        mapa = nil
    }
}

// MARK: - Mapa De Salida

final class PolilineaSegmento: MKPolyline {}
final class PolilineaPausa: MKPolyline {}

struct MapaDeSalida: UIViewRepresentable {
    let puntos: [PuntoDeRecorrido]
    let segmentos: [SegmentoActividad]
    let pausas: [PausaActividad]
    let puntosPausaActual: [PuntoDeRecorrido]
    let ubicacion: CLLocationCoordinate2D?
    let rumbo: Double
    let mostrarUsuario: Bool
    @Binding var seguirUsuario: Bool
    @Binding var heading: Double
    var mapType: MKMapType
    var is3D: Bool
    var centrarNorteTrigger: Int
    var centrarUsuarioTrigger: Int

    init(puntos: [PuntoDeRecorrido],
         segmentos: [SegmentoActividad] = [],
         pausas: [PausaActividad] = [],
         puntosPausaActual: [PuntoDeRecorrido] = [],
         ubicacion: CLLocationCoordinate2D?,
         rumbo: Double = 0.0,
         mostrarUsuario: Bool,
         seguirUsuario: Binding<Bool> = .constant(false),
         heading: Binding<Double> = .constant(0.0),
         mapType: MKMapType = .standard,
         is3D: Bool = false,
         centrarNorteTrigger: Int = 0,
         centrarUsuarioTrigger: Int = 0) {
        self.puntos = puntos
        self.segmentos = segmentos
        self.pausas = pausas
        self.puntosPausaActual = puntosPausaActual
        self.ubicacion = ubicacion
        self.rumbo = rumbo
        self.mostrarUsuario = mostrarUsuario
        self._seguirUsuario = seguirUsuario
        self._heading = heading
        self.mapType = mapType
        self.is3D = is3D
        self.centrarNorteTrigger = centrarNorteTrigger
        self.centrarUsuarioTrigger = centrarUsuarioTrigger
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapaDeSalida
        weak var mapa: MKMapView?
        var estaDesmantelado = false
        var ultimoHashRevision = -1
        var ultimaUbicacion: CLLocationCoordinate2D?
        var ultimoTriggerNorte = 0
        var ultimoTriggerUsuario = 0
        var ultimoPitch3D = false
        var bloqueadoAlNorte = false
        var animandoCamaraProgramatica = false
        var ultimaCoordenadaAnimada: CLLocationCoordinate2D?
        var ultimoRumboAnimado: Double = -1
        private var panGesture: UIPanGestureRecognizer?
        private var pinchGesture: UIPinchGestureRecognizer?
        private var rotateGesture: UIRotationGestureRecognizer?

        init(_ parent: MapaDeSalida) {
            self.parent = parent
        }

        func configurarGestos(en mapa: MKMapView) {
            removerGestos(de: mapa)
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMapTouch(_:)))
            pan.delegate = self
            mapa.addGestureRecognizer(pan)
            self.panGesture = pan

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleMapTouch(_:)))
            pinch.delegate = self
            mapa.addGestureRecognizer(pinch)
            self.pinchGesture = pinch

            let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleMapTouch(_:)))
            rotate.delegate = self
            mapa.addGestureRecognizer(rotate)
            self.rotateGesture = rotate
        }

        func removerGestos(de mapa: MKMapView) {
            if let pan = panGesture { mapa.removeGestureRecognizer(pan); panGesture = nil }
            if let pinch = pinchGesture { mapa.removeGestureRecognizer(pinch); pinchGesture = nil }
            if let rotate = rotateGesture { mapa.removeGestureRecognizer(rotate); rotateGesture = nil }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func handleMapTouch(_ gesture: UIGestureRecognizer) {
            guard !estaDesmantelado else { return }
            if gesture.state == .began || gesture.state == .changed {
                if gesture is UIRotationGestureRecognizer {
                    bloqueadoAlNorte = false
                }
                if parent.seguirUsuario {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, !self.estaDesmantelado else { return }
                        self.parent.seguirUsuario = false
                    }
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let pausaPoly = overlay as? PolilineaPausa {
                let renderer = MKPolylineRenderer(polyline: pausaPoly)
                renderer.strokeColor = UIColor(Paleta.acento).withAlphaComponent(0.85)
                renderer.lineWidth = 4
                renderer.lineDashPattern = [NSNumber(value: 4), NSNumber(value: 6)]
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Paleta.acento)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let identifier = "UsuarioUbicacionConRumbo"
                let customView = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? VistaAnotacionUsuarioConRumbo)
                    ?? VistaAnotacionUsuarioConRumbo(annotation: annotation, reuseIdentifier: identifier)
                customView.annotation = annotation
                customView.actualizar(rumboCelular: parent.rumbo, rumboCamara: mapView.camera.heading)
                return customView
            }
            let identifier = "MarcadorRuta"
            let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            marker.annotation = annotation
            marker.canShowCallout = true

            let titulo = annotation.title??.lowercased() ?? ""
            if titulo.contains("inicio") {
                marker.markerTintColor = UIColor.systemGreen
                marker.glyphImage = UIImage(systemName: "play.fill")
            } else if titulo.contains("fin") {
                marker.markerTintColor = UIColor.systemRed
                marker.glyphImage = UIImage(systemName: "flag.fill")
            } else if titulo.contains("pausa") {
                marker.markerTintColor = UIColor(Paleta.acento)
                marker.glyphImage = UIImage(systemName: "pause.fill")
            } else if titulo.contains("reanud") {
                marker.markerTintColor = UIColor.systemGreen
                marker.glyphImage = UIImage(systemName: "play.fill")
            } else if titulo.contains("vuelta") {
                marker.markerTintColor = UIColor(Paleta.acento)
                marker.glyphImage = UIImage(systemName: "flag.fill")
            } else {
                marker.markerTintColor = UIColor(Paleta.acento)
            }
            return marker
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            guard !estaDesmantelado, !animandoCamaraProgramatica else { return }
            let nuevoHeading = mapView.camera.heading
            if abs(parent.heading - nuevoHeading) > 0.5 {
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.estaDesmantelado, !self.animandoCamaraProgramatica else { return }
                    self.parent.heading = nuevoHeading
                }
            }
            if let userView = mapView.view(for: mapView.userLocation) as? VistaAnotacionUsuarioConRumbo {
                userView.actualizar(rumboCelular: parent.rumbo, rumboCamara: nuevoHeading)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ContenedorMapaView {
        let contenedor = ContenedorMapaView()
        let mapa = GestorDeMapa.shared.obtenerMapa()
        mapa.delegate = context.coordinator
        context.coordinator.mapa = mapa

        mapa.mapType = mapType
        mapa.showsUserLocation = mostrarUsuario

        context.coordinator.configurarGestos(en: mapa)
        contenedor.alojar(mapa: mapa)

        if let u = ubicacion {
            context.coordinator.ultimaUbicacion = u
            let cam = MKMapCamera(lookingAtCenter: u, fromDistance: 450, pitch: is3D ? 65 : 0, heading: rumbo > 0 ? rumbo : 0)
            mapa.setCamera(cam, animated: false)
        }

        return contenedor
    }

    static func dismantleUIView(_ contenedor: ContenedorMapaView, coordinator: Coordinator) {
        coordinator.estaDesmantelado = true
        if let mapa = coordinator.mapa {
            mapa.delegate = nil
            mapa.showsUserLocation = false
            mapa.layer.removeAllAnimations()
            coordinator.removerGestos(de: mapa)
        }
        contenedor.desalojar()
        coordinator.mapa = nil
    }

    func updateUIView(_ contenedor: ContenedorMapaView, context: Context) {
        guard !context.coordinator.estaDesmantelado, let mapa = context.coordinator.mapa else { return }

        let coord = context.coordinator
        coord.parent = self

        if mapa.superview != contenedor {
            contenedor.alojar(mapa: mapa)
        }

        mapa.showsUserLocation = mostrarUsuario

        if #available(iOS 16.0, *) {
            if mapType == .hybrid || mapType == .satellite {
                let desiredElevation: MKMapConfiguration.ElevationStyle = .realistic
                if let hybridConfig = mapa.preferredConfiguration as? MKHybridMapConfiguration {
                    if hybridConfig.elevationStyle != desiredElevation {
                        let config = MKHybridMapConfiguration(elevationStyle: desiredElevation)
                        config.showsTraffic = false
                        mapa.preferredConfiguration = config
                    }
                } else {
                    let config = MKHybridMapConfiguration(elevationStyle: desiredElevation)
                    config.showsTraffic = false
                    mapa.preferredConfiguration = config
                }
            } else {
                let desiredElevation: MKMapConfiguration.ElevationStyle = is3D ? .realistic : .flat
                if let stdConfig = mapa.preferredConfiguration as? MKStandardMapConfiguration {
                    if stdConfig.elevationStyle != desiredElevation {
                        let config = MKStandardMapConfiguration(elevationStyle: desiredElevation)
                        config.emphasisStyle = .default
                        mapa.preferredConfiguration = config
                    }
                } else {
                    let config = MKStandardMapConfiguration(elevationStyle: desiredElevation)
                    config.emphasisStyle = .default
                    mapa.preferredConfiguration = config
                }
            }
        } else {
            let targetType: MKMapType = (mapType == .hybrid && is3D) ? .hybridFlyover : mapType
            if mapa.mapType != targetType {
                mapa.mapType = targetType
            }
        }

        if let userView = mapa.view(for: mapa.userLocation) as? VistaAnotacionUsuarioConRumbo {
            userView.actualizar(rumboCelular: rumbo, rumboCamara: mapa.camera.heading)
        }

        // Si antes no teníamos ubicación y ahora sí, centrar inmediatamente la cámara
        if coord.ultimaUbicacion == nil, let u = ubicacion {
            coord.ultimaUbicacion = u
            let cam = MKMapCamera(lookingAtCenter: u, fromDistance: 450, pitch: is3D ? 65 : 0, heading: rumbo > 0 ? rumbo : 0)
            mapa.setCamera(cam, animated: false)
        }

        // Reset Norte
        if centrarNorteTrigger != coord.ultimoTriggerNorte {
            coord.ultimoTriggerNorte = centrarNorteTrigger
            coord.bloqueadoAlNorte = true
            coord.animandoCamaraProgramatica = true
            let centro = ubicacion ?? mapa.centerCoordinate
            let pitch: CGFloat = is3D ? 65 : 0
            let distanciaCamara = mapa.camera.centerCoordinateDistance > 100 ? mapa.camera.centerCoordinateDistance : 450
            let cam = MKMapCamera(lookingAtCenter: centro, fromDistance: distanciaCamara, pitch: pitch, heading: 0)
            mapa.setCamera(cam, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak coord] in
                guard let coord, !coord.estaDesmantelado else { return }
                coord.animandoCamaraProgramatica = false
                coord.parent.heading = 0.0
            }
            return
        }

        // Recentrar usuario (sin cambiar bruscamente altura ni saltos de zoom)
        if centrarUsuarioTrigger != coord.ultimoTriggerUsuario {
            coord.ultimoTriggerUsuario = centrarUsuarioTrigger
            coord.bloqueadoAlNorte = false
            coord.animandoCamaraProgramatica = true
            let centro = ubicacion ?? mapa.userLocation.coordinate
            if is3D {
                let pitch: CGFloat = 65
                let headingCamara: Double = (rumbo > 0) ? rumbo : mapa.camera.heading
                let distanciaCamara = mapa.camera.centerCoordinateDistance > 100 ? mapa.camera.centerCoordinateDistance : 450
                let cam = MKMapCamera(lookingAtCenter: centro, fromDistance: distanciaCamara, pitch: pitch, heading: headingCamara)
                mapa.setCamera(cam, animated: true)
            } else {
                mapa.setCenter(centro, animated: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak coord] in
                guard let coord, !coord.estaDesmantelado else { return }
                coord.animandoCamaraProgramatica = false
                coord.ultimaCoordenadaAnimada = centro
            }
            return
        }

        // Toggle 3D
        if is3D != coord.ultimoPitch3D {
            coord.ultimoPitch3D = is3D
            coord.animandoCamaraProgramatica = true
            // Refrescar la anotación del usuario para alternar entre el punto nativo (2D) y el cono (3D)
            mapa.showsUserLocation = false
            mapa.showsUserLocation = mostrarUsuario
            let pitch: CGFloat = is3D ? 65 : 0
            let centro = seguirUsuario ? (ubicacion ?? mapa.userLocation.coordinate) : mapa.centerCoordinate
            let headingCamara: Double = coord.bloqueadoAlNorte ? 0 : ((is3D && rumbo > 0) ? rumbo : mapa.camera.heading)
            let distanciaCamara = mapa.camera.centerCoordinateDistance > 100 ? mapa.camera.centerCoordinateDistance : 450
            let cam = MKMapCamera(lookingAtCenter: centro, fromDistance: distanciaCamara, pitch: pitch, heading: headingCamara)
            mapa.setCamera(cam, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak coord] in
                guard let coord, !coord.estaDesmantelado else { return }
                coord.animandoCamaraProgramatica = false
            }
            return
        }

        if seguirUsuario && !coord.animandoCamaraProgramatica {
            let centro = ubicacion ?? mapa.userLocation.coordinate
            if CLLocationCoordinate2DIsValid(centro), centro.latitude != 0, centro.longitude != 0 {
                var debeMover = false
                if let ult = coord.ultimaCoordenadaAnimada {
                    let d = SegmentadorDeRecorrido.distanciaMetros(lat1: ult.latitude, lon1: ult.longitude,
                                                                  lat2: centro.latitude, lon2: centro.longitude)
                    if d >= 1.5 { debeMover = true }
                } else {
                    debeMover = true
                }
                if is3D {
                    let headingCamara: Double = coord.bloqueadoAlNorte ? 0 : (rumbo > 0 ? rumbo : mapa.camera.heading)
                    if abs(coord.ultimoRumboAnimado - headingCamara) > 4.0 { debeMover = true }
                }
                if debeMover {
                    coord.ultimaCoordenadaAnimada = centro
                    if is3D {
                        let headingCamara: Double = coord.bloqueadoAlNorte ? 0 : (rumbo > 0 ? rumbo : mapa.camera.heading)
                        coord.ultimoRumboAnimado = headingCamara
                        let distancia = mapa.camera.centerCoordinateDistance > 100 ? mapa.camera.centerCoordinateDistance : 450
                        let cam = MKMapCamera(lookingAtCenter: centro, fromDistance: distancia, pitch: 65, heading: headingCamara)
                        mapa.setCamera(cam, animated: true)
                    } else {
                        mapa.setCenter(centro, animated: true)
                    }
                }
            }
        }

        // Actualizar overlays de recorrido cuando cambia la cantidad de puntos o segmentos
        let hashRevision = puntos.count &+ (segmentos.count &* 1000) &+ (pausas.count &* 10000) &+ puntosPausaActual.count
        if coord.ultimoHashRevision != hashRevision {
            coord.ultimoHashRevision = hashRevision
            coord.ultimaUbicacion = ubicacion

            mapa.removeOverlays(mapa.overlays)
            mapa.removeAnnotations(mapa.annotations)

            var rectTotal: MKMapRect?

            if !segmentos.isEmpty {
                // 1. Trazar cada segmento completado (línea continua acento)
                for seg in segmentos {
                    let coords = seg.puntos.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                    if coords.count > 1 {
                        let poly = PolilineaSegmento(coordinates: coords, count: coords.count)
                        mapa.addOverlay(poly)
                        rectTotal = rectTotal.map { $0.union(poly.boundingMapRect) } ?? poly.boundingMapRect
                    }

                    // Marcador de inicio del segmento (verde)
                    let pinInicio = MKPointAnnotation()
                    pinInicio.coordinate = CLLocationCoordinate2D(latitude: seg.inicioCoords.latitud, longitude: seg.inicioCoords.longitud)
                    pinInicio.title = (seg.numero == 1) ? "Inicio" : "Inicio \(seg.numero)"
                    mapa.addAnnotation(pinInicio)

                    // Marcador de fin / pausa del segmento (naranja)
                    let pinPausa = MKPointAnnotation()
                    pinPausa.coordinate = CLLocationCoordinate2D(latitude: seg.finCoords.latitud, longitude: seg.finCoords.longitud)
                    pinPausa.title = "Pausa \(seg.numero)"
                    mapa.addAnnotation(pinPausa)
                }

                // 2. Trazar cada pausa completada (línea punteada / discontinua naranja)
                for pausa in pausas {
                    var coordsPausa = pausa.puntosPausa.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                    if coordsPausa.count < 2 {
                        coordsPausa = [
                            CLLocationCoordinate2D(latitude: pausa.inicioCoords.latitud, longitude: pausa.inicioCoords.longitud),
                            CLLocationCoordinate2D(latitude: pausa.finCoords.latitud, longitude: pausa.finCoords.longitud)
                        ]
                    }
                    if coordsPausa.count > 1 {
                        let polyPausa = PolilineaPausa(coordinates: coordsPausa, count: coordsPausa.count)
                        mapa.addOverlay(polyPausa)
                        rectTotal = rectTotal.map { $0.union(polyPausa.boundingMapRect) } ?? polyPausa.boundingMapRect
                    }
                }

                // 3. Tramo activo actual si está corriendo
                let puntosTotalesEnSegmentos = segmentos.reduce(0) { $0 + $1.puntos.count }
                let puntosRestantes = puntos.count > puntosTotalesEnSegmentos ? Array(puntos.suffix(puntos.count - puntosTotalesEnSegmentos)) : []
                var coordsActivas = puntosRestantes.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                if let act = ubicacion {
                    if let ult = coordsActivas.last {
                        let dist = SegmentadorDeRecorrido.distanciaMetros(lat1: ult.latitude, lon1: ult.longitude, lat2: act.latitude, lon2: act.longitude)
                        if dist > 1.0 { coordsActivas.append(act) }
                    } else {
                        coordsActivas = [act]
                    }
                }
                if coordsActivas.count > 1 {
                    let polyActivo = PolilineaSegmento(coordinates: coordsActivas, count: coordsActivas.count)
                    mapa.addOverlay(polyActivo)
                    rectTotal = rectTotal.map { $0.union(polyActivo.boundingMapRect) } ?? polyActivo.boundingMapRect
                }
                if !coordsActivas.isEmpty {
                    let pinInicioActivo = MKPointAnnotation()
                    pinInicioActivo.coordinate = coordsActivas.first!
                    pinInicioActivo.title = "Inicio \(segmentos.count + 1)"
                    mapa.addAnnotation(pinInicioActivo)
                }

                // 4. Pausa activa actual si está pausado y registrando movimiento
                if puntosPausaActual.count > 1 {
                    let coordsPausaAct = puntosPausaActual.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                    let polyPausaAct = PolilineaPausa(coordinates: coordsPausaAct, count: coordsPausaAct.count)
                    mapa.addOverlay(polyPausaAct)
                    rectTotal = rectTotal.map { $0.union(polyPausaAct.boundingMapRect) } ?? polyPausaAct.boundingMapRect
                }
            } else {
                // Modo estándar inicial sin pausas
                let tramos = SegmentadorDeRecorrido.segmentar(puntos)
                for (indice, tramo) in tramos.enumerated() {
                    var coords = tramo.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                    if indice == tramos.count - 1, let act = ubicacion {
                        if let ultimo = coords.last {
                            let dist = SegmentadorDeRecorrido.distanciaMetros(
                                lat1: ultimo.latitude, lon1: ultimo.longitude,
                                lat2: act.latitude, lon2: act.longitude)
                            if dist > 1.0 { coords.append(act) }
                        } else {
                            coords = [act]
                        }
                    }
                    if coords.count > 1 {
                        let polyline = PolilineaSegmento(coordinates: coords, count: coords.count)
                        mapa.addOverlay(polyline)
                        rectTotal = rectTotal.map { $0.union(polyline.boundingMapRect) } ?? polyline.boundingMapRect
                    }
                    if indice < tramos.count - 1, let ultimoPausa = coords.last {
                        let pin = MKPointAnnotation()
                        pin.coordinate = ultimoPausa
                        pin.title = "Pausa \(indice + 1)"
                        mapa.addAnnotation(pin)
                    }
                }

                if puntosPausaActual.count > 1 {
                    let coordsPausa = puntosPausaActual.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                    let polyPausa = PolilineaPausa(coordinates: coordsPausa, count: coordsPausa.count)
                    mapa.addOverlay(polyPausa)
                    rectTotal = rectTotal.map { $0.union(polyPausa.boundingMapRect) } ?? polyPausa.boundingMapRect
                }
            }

            if !mostrarUsuario, let primerPunto = puntos.first {
                let pinInicio = MKPointAnnotation()
                pinInicio.coordinate = CLLocationCoordinate2D(latitude: primerPunto.lat, longitude: primerPunto.lon)
                pinInicio.title = "Inicio"
                mapa.addAnnotation(pinInicio)

                if puntos.count > 1, let ultimoPunto = puntos.last {
                    let pinFin = MKPointAnnotation()
                    pinFin.coordinate = CLLocationCoordinate2D(latitude: ultimoPunto.lat, longitude: ultimoPunto.lon)
                    pinFin.title = "Fin"
                    mapa.addAnnotation(pinFin)
                }
            }

            if !seguirUsuario, let rectTotal, !mostrarUsuario {
                mapa.setVisibleMapRect(rectTotal, edgePadding: UIEdgeInsets(top: 40, left: 30, bottom: 40, right: 30), animated: true)
            }
        }
    }
}

// MARK: - Vista Esqueleto de Carga de Mapa

struct VistaEsqueletoMapa: View {
    @State private var animar = false

    var body: some View {
        ZStack {
            Paleta.fondo
                .ignoresSafeArea()

            GeometryReader { geo in
                Canvas { context, size in
                    var path = Path()
                    let step: CGFloat = 60
                    for x in stride(from: 0, to: size.width + step, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, to: size.height + step, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(Paleta.divisor), lineWidth: 1.5)

                    var diag = Path()
                    diag.move(to: CGPoint(x: 0, y: size.height * 0.3))
                    diag.addLine(to: CGPoint(x: size.width, y: size.height * 0.7))
                    diag.move(to: CGPoint(x: size.width * 0.2, y: 0))
                    diag.addLine(to: CGPoint(x: size.width * 0.8, y: size.height))
                    context.stroke(diag, with: .color(Paleta.bordeSignificante.opacity(0.15)), lineWidth: 3)
                }
            }

            ZStack {
                Circle()
                    .stroke(Paleta.acento.opacity(animar ? 0.0 : 0.5), lineWidth: 2)
                    .frame(width: animar ? 140 : 20, height: animar ? 140 : 20)

                Circle()
                    .fill(Paleta.acento.opacity(0.2))
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(Paleta.acento)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Paleta.fondo, lineWidth: 2))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                animar = true
            }
        }
    }
}
