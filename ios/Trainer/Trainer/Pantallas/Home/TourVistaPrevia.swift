import SwiftUI
import TrainerCore

// =============================================================================
// El escenario de cada página del tour: la pantalla REAL de la pestaña, achicada
// dentro de un teléfono, con un anillo del acento sobre lo que importa, un velo
// sobre el resto, y la mascota al costado señalándolo con una flecha.
//
// 🪤 Las pantallas se dibujan al tamaño de un teléfono de referencia (393 × 852)
// y se achican con `scaleEffect`: así se ven igual que en la app, sin que cada
// una tenga que saber que está en miniatura. Dónde va el anillo se da en esas
// mismas coordenadas, y es APROXIMADO (se midió a ojo contra el layout de cada
// pantalla): por eso los anillos son generosos.
//
// Entreno NO se instancia (arranca el GPS y el mapa): se muestra la barra de
// pestañas con el botón ⚡ sobre el fondo oscuro.
// =============================================================================

/// La pestaña que explica cada página.
enum SeccionDelTour {
    case inicio, plan, entreno, historial, perfil

    var nombre: String {
        switch self {
        case .inicio: return Textos.homeTabHome
        case .plan: return Textos.homeTabPlan
        case .entreno: return Textos.homeTabWorkout
        case .historial: return Textos.historyTab
        case .perfil: return Textos.homeTabProfile
        }
    }

    /// La que se ve elegida en la barra. Con Entreno abierto la barra marca la
    /// pestaña de antes, como en la app: Inicio.
    fileprivate var pestanaElegida: PestanaHome {
        switch self {
        case .inicio, .entreno: return .inicio
        case .plan: return .plan
        case .historial: return .historial
        case .perfil: return .perfil
        }
    }

    /// Su lugar entre los cuatro ítems de los costados de la barra.
    fileprivate var indiceEnLaBarra: Int {
        switch self {
        case .inicio, .entreno: return 0
        case .plan: return 1
        case .historial: return 2
        case .perfil: return 3
        }
    }
}

/// Qué se señala, en coordenadas del teléfono de referencia.
struct ResalteDelTour {
    let marco: CGRect
    let esCirculo: Bool
}

// MARK: - La pantalla de referencia

/// La pantalla tal cual, al tamaño del teléfono de referencia: el hueco de la
/// barra de estado, el contenido de la pestaña, la barra de pestañas y el hueco
/// del indicador de inicio. No responde a toques: es una foto que se mueve.
struct TourPantallaDeReferencia: View {
    let seccion: SeccionDelTour
    let estado: EstadoHome?
    let flujo: FlujoEntrada

    static let tamano = CGSize(width: 393, height: 852)
    static let altoBarraDeEstado: CGFloat = 54
    static let altoDeLaBarra: CGFloat = 84
    static let altoIndicadorDeInicio: CGFloat = 34
    static var altoDelContenido: CGFloat {
        tamano.height - altoBarraDeEstado - altoDeLaBarra - altoIndicadorDeInicio
    }
    /// Cuánto se "baja" el Plan para que se vean los días de la semana, que en
    /// la pantalla quedan debajo de la carrera y las etapas.
    static let desplazamientoDelPlan: CGFloat = 320

    /// El Plan sólo se baja si tiene semanas que mostrar; si no, arriba está el
    /// selector de metas, que es lo que hay que ver.
    static func planDesplazado(_ estado: EstadoHome?) -> Bool {
        guard let estado else { return false }
        return estado.bloque != nil && !estado.planVencido
    }

    /// Dónde va el anillo. Sin el estado no hay pantalla real: se señala la
    /// pestaña en la barra.
    static func resalte(de seccion: SeccionDelTour, estado: EstadoHome?) -> ResalteDelTour {
        guard estado != nil else { return resalteEnLaBarra(de: seccion) }
        switch seccion {
        case .inicio:
            // La tarjeta de la carrera (o la del próximo objetivo).
            return ResalteDelTour(marco: CGRect(x: 10, y: 252, width: 373, height: 238), esCirculo: false)
        case .plan:
            // Los días de la semana; sin plan, el selector de metas.
            return planDesplazado(estado)
                ? ResalteDelTour(marco: CGRect(x: 8, y: 436, width: 377, height: 292), esCirculo: false)
                : ResalteDelTour(marco: CGRect(x: 8, y: 136, width: 377, height: 300), esCirculo: false)
        case .historial:
            // La franja de "Tus números" (o el estado vacío, que va en el mismo lugar).
            return ResalteDelTour(marco: CGRect(x: 10, y: 126, width: 373, height: 244), esCirculo: false)
        case .perfil:
            // La tarjeta con el nombre y el avatar.
            return ResalteDelTour(marco: CGRect(x: 10, y: 120, width: 373, height: 168), esCirculo: false)
        case .entreno:
            return resalteEnLaBarra(de: .entreno)
        }
    }

    /// Copia la geometría de `BarraDePestanas`: e16 de margen más e8 de relleno a
    /// cada lado, el hueco central de e56 + e14 y el botón ⚡ de e56 + e4, subido
    /// e16 desde el centro de la barra.
    private static func resalteEnLaBarra(de seccion: SeccionDelTour) -> ResalteDelTour {
        let centroY = tamano.height - altoIndicadorDeInicio - altoDeLaBarra / 2
        if seccion == .entreno {
            let diametro = TokensEspaciado.e56 + TokensEspaciado.e4 + TokensEspaciado.e16
            return ResalteDelTour(marco: CGRect(x: tamano.width / 2 - diametro / 2,
                                                y: centroY - TokensEspaciado.e16 - diametro / 2,
                                                width: diametro, height: diametro),
                                  esCirculo: true)
        }
        let margen = TokensEspaciado.e16 + TokensEspaciado.e8
        let hueco = TokensEspaciado.e56 + TokensEspaciado.e14
        let anchoDelItem = (tamano.width - margen * 2 - hueco) / 4
        let indice = seccion.indiceEnLaBarra
        let x = margen + anchoDelItem * CGFloat(indice) + (indice >= 2 ? hueco : 0)
        let alto = TokensEspaciado.e56 + TokensEspaciado.e4
        return ResalteDelTour(marco: CGRect(x: x, y: centroY - alto / 2, width: anchoDelItem, height: alto),
                              esCirculo: false)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Self.altoBarraDeEstado)
            contenido
                .frame(width: Self.tamano.width, height: Self.altoDelContenido, alignment: .top)
                .clipped()
            barra
                .frame(width: Self.tamano.width, height: Self.altoDeLaBarra)
            Color.clear.frame(height: Self.altoIndicadorDeInicio)
        }
        .frame(width: Self.tamano.width, height: Self.tamano.height)
        .background(Paleta.fondo)
    }

    @ViewBuilder
    private var contenido: some View {
        if let estado, seccion != .entreno {
            pantallaReal(estado)
                .environmentObject(estado)
                .environmentObject(flujo)
        } else {
            fondoOscuro
        }
    }

    /// Las mismas vistas que arma `RaizHomeView`.
    @ViewBuilder
    private func pantallaReal(_ estado: EstadoHome) -> some View {
        switch seccion {
        case .inicio:
            InicioView()
        case .plan:
            if Self.planDesplazado(estado) {
                PlanView()
                    .frame(height: Self.altoDelContenido + Self.desplazamientoDelPlan)
                    .offset(y: -Self.desplazamientoDelPlan)
            } else {
                PlanView()
            }
        case .historial:
            HistorialDeActividadesView(servicio: estado.repositorio.servicioDeActividades(), esPestana: true)
        case .perfil:
            PerfilView()
        case .entreno:
            fondoOscuro
        }
    }

    /// Lo que hay detrás de la barra en la página de Entreno: negro, con el
    /// resplandor del acento abajo, donde está el ⚡.
    private var fondoOscuro: some View {
        ZStack {
            Paleta.fondo
            RadialGradient(colors: [Paleta.acentoProfundo, Color.clear],
                           center: .bottom, startRadius: 0,
                           endRadius: TokensEspaciado.e56 * 5)
        }
    }

    /// La barra de la app, con los mismos ítems que `RaizHomeView`, sin acción.
    private var barra: some View {
        BarraDePestanas(
            items: [
                ItemDePestana(id: PestanaHome.inicio.rawValue, titulo: Textos.homeTabHome, simbolo: "house"),
                ItemDePestana(id: PestanaHome.plan.rawValue, titulo: Textos.homeTabPlan, simbolo: "calendar"),
                ItemDePestana(id: PestanaHome.historial.rawValue,
                              titulo: SeccionDelTour.historial.nombre,
                              simbolo: "clock.arrow.circlepath"),
                ItemDePestana(id: PestanaHome.perfil.rawValue, titulo: Textos.homeTabProfile, simbolo: "person"),
            ],
            elegida: seccion.pestanaElegida.rawValue,
            central: ItemDePestana(id: PestanaHome.entreno.rawValue,
                                   titulo: Textos.homeTabWorkout, simbolo: "bolt.fill"),
            alElegir: { _ in },
            alTocarCentral: {})
    }
}

// MARK: - El escenario

/// El teléfono, el anillo, la flecha y la mascota, acomodados en el lugar que
/// haya. Al llegar a la página, el velo, el anillo y la flecha entran una vez
/// (la flecha se "dibuja"); después nada se mueve.
struct TourEscenario: View {
    let pagina: TourPagina
    let estado: EstadoHome?
    let flujo: FlujoEntrada
    let visible: Bool

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var senal = false

    var body: some View {
        GeometryReader { geo in
            let resalte = TourPantallaDeReferencia.resalte(de: pagina.seccion, estado: estado)
            let medidas = MedidasDelEscenario(tamano: geo.size,
                                              mascotaALaIzquierda: pagina.mascotaALaIzquierda,
                                              resalte: resalte.marco)
            ZStack(alignment: .topLeading) {
                telefono(medidas, resalte: resalte)
                anillo(medidas, esCirculo: resalte.esCirculo)
                flecha(medidas)
                mascota(medidas)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .accessibilityHidden(true)
        .onAppear {
            if visible { mostrarSenal() }
        }
        .onChange(of: visible) { ahora in
            if ahora { mostrarSenal() }
        }
    }

    private var senalVisible: Bool { senal || movimientoReducido }

    private func telefono(_ medidas: MedidasDelEscenario, resalte: ResalteDelTour) -> some View {
        let forma = RoundedRectangle(cornerRadius: TokensEspaciado.e52 * medidas.escala, style: .continuous)
        let hueco = CGRect(x: resalte.marco.minX * medidas.escala,
                           y: resalte.marco.minY * medidas.escala,
                           width: resalte.marco.width * medidas.escala,
                           height: resalte.marco.height * medidas.escala)
        return TourPantallaDeReferencia(seccion: pagina.seccion, estado: estado, flujo: flujo)
            .scaleEffect(medidas.escala, anchor: .topLeading)
            .frame(width: medidas.telefono.width, height: medidas.telefono.height, alignment: .topLeading)
            .overlay(
                VeloConHueco(hueco: hueco,
                             radio: TokensRadio.card * medidas.escala,
                             esCirculo: resalte.esCirculo)
                    .fill(Paleta.fondo, style: FillStyle(eoFill: true))
                    .opacity(senalVisible ? 0.45 : 0)
                    .animation(movimientoReducido ? nil : .easeOut(duration: TokensMovimiento.lenta),
                               value: senal)
            )
            .clipShape(forma)
            .overlay(forma.strokeBorder(Paleta.bordeSignificante, lineWidth: TokensEspaciado.e3))
            .shadow(color: Paleta.acentoProfundo, radius: TokensEspaciado.e20)
            .allowsHitTesting(false)
            .disabled(true)
            .position(x: medidas.telefono.midX, y: medidas.telefono.midY)
    }

    private func anillo(_ medidas: MedidasDelEscenario, esCirculo: Bool) -> some View {
        let marco = medidas.resalte.insetBy(dx: -TokensEspaciado.e2, dy: -TokensEspaciado.e2)
        return FormaDeResalte(esCirculo: esCirculo, radio: TokensRadio.card * medidas.escala + TokensEspaciado.e2)
            .stroke(Paleta.acento, lineWidth: TokensEspaciado.e3)
            .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e10)
            .frame(width: marco.width, height: marco.height)
            .scaleEffect(senalVisible ? 1 : 1.06)
            .opacity(senalVisible ? 1 : 0)
            .animation(movimientoReducido ? nil : .easeOut(duration: TokensMovimiento.lenta), value: senal)
            .position(x: marco.midX, y: marco.midY)
            .allowsHitTesting(false)
    }

    private func flecha(_ medidas: MedidasDelEscenario) -> some View {
        FlechaDelTour(desde: medidas.inicioDeFlecha, hasta: medidas.finDeFlecha)
            .trim(from: 0, to: senalVisible ? 1 : 0)
            .stroke(Paleta.acento, style: StrokeStyle(lineWidth: TokensEspaciado.e3,
                                                      lineCap: .round, lineJoin: .round))
            .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e4)
            .animation(movimientoReducido
                       ? nil
                       : Animation.easeOut(duration: TokensMovimiento.lenta).delay(TokensMovimiento.rapida),
                       value: senal)
            .frame(width: medidas.tamano.width, height: medidas.tamano.height)
            .allowsHitTesting(false)
    }

    /// Mira hacia el teléfono: el dibujo apoya el codo a la derecha, así que
    /// del lado derecho va espejada.
    private func mascota(_ medidas: MedidasDelEscenario) -> some View {
        Mascota(pose: .saludo, altoMaximo: medidas.mascota.height, activa: visible,
                espejada: !pagina.mascotaALaIzquierda)
            .frame(width: medidas.mascota.width, height: medidas.mascota.height)
            .position(x: medidas.mascota.midX, y: medidas.mascota.midY)
    }

    /// Vuelve a esconder la señal sin animar y, un instante después de que la
    /// página llegó, la muestra. Con "Reducir movimiento", de una.
    private func mostrarSenal() {
        guard !movimientoReducido else {
            senal = true
            return
        }
        var sinAnimar = Transaction()
        sinAnimar.disablesAnimations = true
        withTransaction(sinAnimar) { senal = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + TokensMovimiento.media) {
            senal = true
        }
    }
}

// MARK: - Las medidas

/// Dónde va cada cosa del escenario, en sus coordenadas. Es cálculo puro: el
/// teléfono lo más alto que entre (sin pasar de dos tercios del ancho), la
/// mascota en lo que sobra, con el codo a la altura de lo señalado, y la flecha
/// del codo al borde del anillo.
struct MedidasDelEscenario {
    let tamano: CGSize
    let telefono: CGRect
    let escala: CGFloat
    let resalte: CGRect
    let mascota: CGRect
    let inicioDeFlecha: CGPoint
    let finDeFlecha: CGPoint

    /// Ancho / alto del dibujo de `MascotaSaludo`, y dónde tiene el codo
    /// apoyado (fracciones del dibujo sin espejar).
    static let proporcionDeLaMascota: CGFloat = 0.577
    static let codoDeLaMascota = CGPoint(x: 0.97, y: 0.5)
    static let anchoMaximoDelTelefono: CGFloat = 0.66
    static let altoMaximoDeLaMascota: CGFloat = 0.62

    init(tamano: CGSize, mascotaALaIzquierda izquierda: Bool, resalte deReferencia: CGRect) {
        self.tamano = tamano
        let referencia = TourPantallaDeReferencia.tamano

        // El teléfono.
        var alto = max(tamano.height, 1)
        var ancho = alto * referencia.width / referencia.height
        let anchoMaximo = tamano.width * Self.anchoMaximoDelTelefono
        if ancho > anchoMaximo {
            ancho = anchoMaximo
            alto = ancho * referencia.height / referencia.width
        }
        let telefono = CGRect(x: izquierda ? tamano.width - ancho : 0,
                              y: (tamano.height - alto) / 2,
                              width: ancho, height: alto)
        let escala = ancho / referencia.width
        let resalte = CGRect(x: telefono.minX + deReferencia.minX * escala,
                             y: telefono.minY + deReferencia.minY * escala,
                             width: deReferencia.width * escala,
                             height: deReferencia.height * escala)

        // La mascota, pegada al teléfono del lado que le toca.
        let separacion = TokensEspaciado.e26
        let libre = max(tamano.width - ancho - separacion, 0)
        let altoMascota = min(libre / Self.proporcionDeLaMascota, tamano.height * Self.altoMaximoDeLaMascota)
        let anchoMascota = altoMascota * Self.proporcionDeLaMascota
        let arriba = min(max(resalte.midY - altoMascota * Self.codoDeLaMascota.y, 0),
                         max(tamano.height - altoMascota, 0))
        let mascota = CGRect(x: izquierda ? libre - anchoMascota : tamano.width - libre,
                             y: arriba, width: anchoMascota, height: altoMascota)

        // La flecha: del codo al borde del anillo más cercano.
        let codo = CGPoint(x: izquierda
                              ? mascota.minX + anchoMascota * Self.codoDeLaMascota.x
                              : mascota.maxX - anchoMascota * Self.codoDeLaMascota.x,
                           y: mascota.minY + altoMascota * Self.codoDeLaMascota.y)
        let aire = TokensEspaciado.e6
        let margenVertical = min(TokensEspaciado.e12, resalte.height / 2)
        let inicio = CGPoint(x: codo.x + (izquierda ? aire : -aire), y: codo.y)
        let fin = CGPoint(x: izquierda ? resalte.minX - aire : resalte.maxX + aire,
                          y: min(max(codo.y, resalte.minY + margenVertical), resalte.maxY - margenVertical))

        self.telefono = telefono
        self.escala = escala
        self.resalte = resalte
        self.mascota = mascota
        self.inicioDeFlecha = inicio
        self.finDeFlecha = fin
    }
}

// MARK: - Las formas

/// Todo el rectángulo menos el hueco: con relleno par-impar queda el velo con
/// el agujero donde está lo señalado.
private struct VeloConHueco: Shape {
    var hueco: CGRect
    var radio: CGFloat
    var esCirculo: Bool

    func path(in rect: CGRect) -> Path {
        var trazo = Path(rect)
        if esCirculo {
            trazo.addEllipse(in: hueco)
        } else {
            trazo.addRoundedRect(in: hueco, cornerSize: CGSize(width: radio, height: radio), style: .continuous)
        }
        return trazo
    }
}

/// El anillo: un círculo (el ⚡) o un rectángulo redondeado (una tarjeta).
private struct FormaDeResalte: Shape {
    var esCirculo: Bool
    var radio: CGFloat

    func path(in rect: CGRect) -> Path {
        if esCirculo {
            return Path(ellipseIn: rect)
        }
        return Path(roundedRect: rect, cornerRadius: min(radio, rect.height / 2), style: .continuous)
    }
}

/// Una flecha curva, con la punta abierta. Se dibuja en las coordenadas del
/// escenario entero: `desde` y `hasta` ya vienen en ellas.
private struct FlechaDelTour: Shape {
    var desde: CGPoint
    var hasta: CGPoint

    func path(in rect: CGRect) -> Path {
        let dx = hasta.x - desde.x
        let dy = hasta.y - desde.y
        let distancia = (dx * dx + dy * dy).squareRoot()
        var trazo = Path()
        guard distancia >= TokensEspaciado.e8 else { return trazo }

        // Una panza hacia arriba, proporcional al largo: corta, casi recta.
        let panza = min(TokensEspaciado.e16, distancia * 0.3)
        let control = CGPoint(x: (desde.x + hasta.x) / 2, y: min(desde.y, hasta.y) - panza)
        trazo.move(to: desde)
        trazo.addQuadCurve(to: hasta, control: control)

        let angulo = atan2(hasta.y - control.y, hasta.x - control.x)
        let largo = TokensEspaciado.e9
        let abertura = CGFloat.pi / 6
        trazo.move(to: CGPoint(x: hasta.x - largo * cos(angulo - abertura),
                               y: hasta.y - largo * sin(angulo - abertura)))
        trazo.addLine(to: hasta)
        trazo.addLine(to: CGPoint(x: hasta.x - largo * cos(angulo + abertura),
                                  y: hasta.y - largo * sin(angulo + abertura)))
        return trazo
    }
}
