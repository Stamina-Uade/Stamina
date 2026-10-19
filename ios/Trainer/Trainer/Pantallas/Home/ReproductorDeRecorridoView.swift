import SwiftUI
import MapKit
import TrainerCore

/// Reproductor animado de recorrido a pantalla completa en 3D y tercera persona:
/// - Vista satelital con relieve realista en 3D siguiendo al atleta en tercera persona.
/// - La ruta NO se muestra adelantada en gris: se va trazando en rosa vivo a medida que avanza.
/// - Telemetría sobre el mapa flotante: solo tiempo transcurrido, ritmo, velocidad y kilómetro actual.
/// - Al terminar la reproducción: tarjeta visible con el tiempo total.
/// - Selector de velocidad (1x, 2x, 4x) y scrubber interactivo.
/// - Punto verde de inicio y punto rosa de fin.
struct ReproductorDeRecorridoView: View {
    let puntos: [PuntoDeRecorrido]
    let deporte: DeporteDeSesion
    let duracionTotalSegundos: Int
    let sistemaDeUnidades: SistemaDeUnidades
    var alCerrar: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var tiempoActual: Double = 0.0
    @State private var reproduciendo = false
    @State private var velocidadMultiplicador: Double = 5.0 // 1x = 5x real
    @State private var timer: Timer?

    private var analisis: AnalisisDeRecorrido {
        AnalizadorDeRecorrido.analizar(
            puntos: puntos,
            deporte: deporte,
            duracionTotalSegundos: duracionTotalSegundos
        )
    }

    private var duracionEfectiva: Double {
        max(1.0, Double(duracionTotalSegundos))
    }

    private var puntosHastaTiempo: [PuntoDeRecorrido] {
        guard !puntos.isEmpty else { return [] }
        guard let primerPunto = puntos.first else { return [] }
        let inicioMs = primerPunto.atMs
        let corteMs = inicioMs + Int64((tiempoActual * 1000).rounded())
        let filtrados = puntos.filter { $0.atMs <= corteMs }
        return filtrados.isEmpty ? [primerPunto] : filtrados
    }

    private var puntoActual: PuntoDeRecorrido? {
        puntosHastaTiempo.last ?? puntos.first
    }

    private var distanciaActualMetros: Int {
        let pts = puntosHastaTiempo
        guard pts.count > 1 else { return 0 }
        var dist = 0.0
        for i in 0..<(pts.count - 1) {
            dist += SegmentadorDeRecorrido.distanciaMetros(
                lat1: pts[i].lat, lon1: pts[i].lon,
                lat2: pts[i+1].lat, lon2: pts[i+1].lon
            )
        }
        return Int(dist.rounded())
    }

    private var velocidadActualKmh: Double {
        let pts = puntosHastaTiempo
        guard pts.count >= 2 else { return 0.0 }
        let p1 = pts[pts.count - 2]
        let p2 = pts[pts.count - 1]
        let dt = Double(max(1, p2.atMs - p1.atMs)) / 1000.0
        let dist = SegmentadorDeRecorrido.distanciaMetros(lat1: p1.lat, lon1: p1.lon, lat2: p2.lat, lon2: p2.lon)
        return (dist / dt) * 3.6
    }

    private var ritmoActualSegPorKm: Int? {
        guard velocidadActualKmh >= 1.0 else { return nil }
        return Int((3600.0 / velocidadActualKmh).rounded())
    }

    private var haTerminado: Bool {
        tiempoActual >= duracionEfectiva
    }

    private var valorVelocidadTexto: String {
        let vel = sistemaDeUnidades == .imperial ? velocidadActualKmh * 0.621371 : velocidadActualKmh
        let unidad = Formato.unidadDeVelocidad(sistemaDeUnidades)
        return String(format: "%.1f %@", vel, unidad).replacingOccurrences(of: ".", with: ",")
    }

    private var valorRitmoTexto: String {
        Formato.ritmo(segundosPorKm: ritmoActualSegPorKm, unidades: sistemaDeUnidades) + (sistemaDeUnidades == .imperial ? " /mi" : " /km")
    }

    private var kilometroActualTexto: String {
        let pasoMetros = sistemaDeUnidades == .imperial ? 1609.34 : 1000.0
        let num = max(1, Int((Double(distanciaActualMetros) / pasoMetros).rounded(.down)) + 1)
        let prefijo = sistemaDeUnidades == .imperial ? "MI" : "KM"
        return "\(prefijo) \(num)"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // 1. Mapa completo en 3D satelital con cámara en tercera persona siguiendo al atleta
                MapaReproductor(
                    puntosTotales: puntos,
                    puntosRecorridos: puntosHastaTiempo,
                    puntoActual: puntoActual,
                    pausas: analisis.pausas,
                    splits: analisis.splitsKm
                )
                .ignoresSafeArea()

                // 2. Capa superior: Botón cerrar + Selector de velocidad
                VStack(spacing: TokensEspaciado.e12) {
                    HStack(alignment: .center) {
                        BotonCircular("xmark", etiqueta: "Cerrar reproducción") {
                            pausar()
                            if let alCerrar {
                                alCerrar()
                            } else {
                                dismiss()
                            }
                        }

                        Spacer()

                        selectorDeVelocidad
                    }
                    .padding(.horizontal, TokensEspaciado.e16)
                    .padding(.top, max(geo.safeAreaInsets.top, TokensEspaciado.e52))

                    // 3. Telemetría flotante requerida: tiempo transcurrido, ritmo, velocidad, kilómetro actual
                    hudTelemetria
                        .padding(.horizontal, TokensEspaciado.e16)

                    // 4. Cartel al terminar mostrando el TIEMPO TOTAL
                    if haTerminado {
                        tarjetaTiempoTotal
                            .padding(.top, TokensEspaciado.e10)
                    }

                    Spacer()

                    // 5. Controles inferiores (Barra de progreso / Play / Pause / Reiniciar)
                    panelInferiorControles
                        .padding(.horizontal, TokensEspaciado.e16)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, TokensEspaciado.e26))
                }
                // El mapa es siempre oscuro: los controles encima, también.
                .environment(\.colorScheme, .dark)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            reproducir()
        }
        .onDisappear {
            pausar()
        }
    }

    // MARK: - Superficie de los paneles flotantes

    /// El vidrio oscuro con borde finito de todos los paneles sobre el mapa.
    private func panelFlotante<Contenido: View>(_ contenido: Contenido) -> some View {
        contenido
            .background(Paleta.superficieOverlay)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
    }

    // MARK: - HUD de Telemetría (4 métricas requeridas sobre el mapa)

    private var hudTelemetria: some View {
        panelFlotante(
            HStack(spacing: 0) {
                columnaHUD(titulo: "TIEMPO", valor: Formato.cronometroCompleto(segundos: Int(tiempoActual)))
                divisorHUD
                columnaHUD(titulo: "RITMO", valor: valorRitmoTexto)
                divisorHUD
                columnaHUD(titulo: "VELOCIDAD", valor: valorVelocidadTexto)
                divisorHUD
                columnaHUD(titulo: "KILÓMETRO", valor: kilometroActualTexto)
            }
            .padding(.vertical, TokensEspaciado.e12)
        )
    }

    private func columnaHUD(titulo: String, valor: String) -> some View {
        VStack(spacing: TokensEspaciado.e4) {
            Text(valor)
                .estilo(.resumenCifraFila)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(titulo)
                .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divisorHUD: some View {
        Rectangle()
            .fill(Paleta.divisor)
            .frame(width: TokensEspaciado.e1, height: TokensEspaciado.e26)
    }

    // MARK: - Tarjeta de Tiempo Total al Finalizar

    private var tarjetaTiempoTotal: some View {
        VStack(spacing: TokensEspaciado.e6) {
            HStack(spacing: TokensEspaciado.e8) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: TokensTipografia.valorDatoTamano, weight: .bold))
                    .foregroundStyle(Paleta.acento)
                    .accessibilityHidden(true)
                Text("TIEMPO TOTAL")
                    .estilo(.etiquetaSeccion, color: Paleta.textoSecundario)
            }
            Text(Formato.cronometroCompleto(segundos: duracionTotalSegundos))
                .estilo(.numeroGrande, color: Paleta.acento)
        }
        .padding(.vertical, TokensEspaciado.e12)
        .padding(.horizontal, TokensEspaciado.e20)
        .background(Paleta.superficieOverlay)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                .strokeBorder(Paleta.acentoSuaveBorde, lineWidth: TokensEspaciado.e1)
        )
        .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e16)
        .accessibilityElement(children: .combine)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Panel Inferior de Controles

    private var panelInferiorControles: some View {
        panelFlotante(
            VStack(spacing: TokensEspaciado.e10) {
                // Scrubber
                VStack(spacing: TokensEspaciado.e3) {
                    Slider(
                        value: $tiempoActual,
                        in: 0...duracionEfectiva,
                        onEditingChanged: { editando in
                            if editando {
                                pausar()
                            }
                        }
                    )
                    .tint(Paleta.acento)

                    HStack {
                        Text(Formato.cronometro(segundos: Int(tiempoActual)))
                            .estilo(.resumenCifraChica, color: Paleta.textoSecundario)
                        Spacer()
                        Text(Formato.cronometro(segundos: Int(duracionEfectiva)))
                            .estilo(.resumenCifraChica, color: Paleta.textoTerciario)
                    }
                }

                // Botones
                HStack(spacing: TokensEspaciado.e22) {
                    BotonCircular("backward.end.fill", etiqueta: "Reiniciar reproducción") {
                        tiempoActual = 0.0
                        reproducir()
                    }

                    BotonCircular(reproduciendo ? "pause.fill" : "play.fill",
                                  etiqueta: reproduciendo ? "Pausar" : "Reproducir",
                                  estilo: .primario,
                                  diametro: TokensEspaciado.e56) {
                        if reproduciendo {
                            pausar()
                        } else {
                            reproducir()
                        }
                    }
                }
            }
            .padding(TokensEspaciado.e14)
        )
    }

    private var selectorDeVelocidad: some View {
        HStack(spacing: TokensEspaciado.e4) {
            botonVelocidad(titulo: "1x", mult: 5.0)
            botonVelocidad(titulo: "2x", mult: 10.0)
            botonVelocidad(titulo: "4x", mult: 20.0)
        }
        .padding(TokensEspaciado.e4)
        .background(Paleta.superficieOverlay)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
    }

    private func botonVelocidad(titulo: String, mult: Double) -> some View {
        let activo = velocidadMultiplicador == mult
        return Button {
            velocidadMultiplicador = mult
        } label: {
            Text(titulo)
                .estilo(.chip, color: activo ? Paleta.sobreAcento : Paleta.textoSecundario)
                .padding(.horizontal, TokensEspaciado.e12)
                .frame(minHeight: TokensEspaciado.e40)
                .background(activo ? Paleta.acento : Color.clear)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(Text("Velocidad \(titulo)"))
        .accessibilityAddTraits(activo ? .isSelected : [])
    }

    private func reproducir() {
        if tiempoActual >= duracionEfectiva {
            tiempoActual = 0.0
        }
        reproduciendo = true
        timer?.invalidate()
        let intervalo = 0.05 // 20 actualizaciones por segundo
        timer = Timer.scheduledTimer(withTimeInterval: intervalo, repeats: true) { _ in
            let avance = intervalo * velocidadMultiplicador
            if tiempoActual + avance >= duracionEfectiva {
                tiempoActual = duracionEfectiva
                pausar()
            } else {
                tiempoActual += avance
            }
        }
    }

    private func pausar() {
        reproduciendo = false
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Mapa UIViewRepresentable para el reproductor (3D satelital en tercera persona)

private struct MapaReproductor: UIViewRepresentable {
    let puntosTotales: [PuntoDeRecorrido]
    let puntosRecorridos: [PuntoDeRecorrido]
    let puntoActual: PuntoDeRecorrido?
    let pausas: [DetallePausa]
    let splits: [SplitKilometro]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapaReproductor
        var rutaActivaOverlay: MKPolyline?
        var marcadorAtleta: MKPointAnnotation?
        var ultimaCoordenadaCamara: CLLocationCoordinate2D?
        var ultimoRumboCamara: Double = 0.0

        init(_ parent: MapaReproductor) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // Ruta en el rosa del acento, trazándose a medida que avanza
                renderer.strokeColor = UIColor(Paleta.acento)
                renderer.lineWidth = 5.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let titulo = annotation.title??.lowercased() ?? ""
            if titulo.contains("inicio") {
                let id = "MarcadorInicioVerde"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                view.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
                view.subviews.forEach { $0.removeFromSuperview() }

                let dot = UIView(frame: CGRect(x: 2, y: 2, width: 18, height: 18))
                dot.backgroundColor = UIColor(red: 0.20, green: 0.82, blue: 0.35, alpha: 1.0)
                dot.layer.cornerRadius = 9
                dot.layer.borderColor = UIColor(white: 0.10, alpha: 0.95).cgColor
                dot.layer.borderWidth = 2.5
                dot.layer.shadowColor = UIColor.black.cgColor
                dot.layer.shadowOpacity = 0.5
                dot.layer.shadowRadius = 3
                dot.layer.shadowOffset = CGSize(width: 0, height: 1.5)
                view.addSubview(dot)
                return view
            } else if titulo.contains("fin") {
                let id = "MarcadorFinRosa"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                view.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
                view.subviews.forEach { $0.removeFromSuperview() }

                let outer = UIView(frame: CGRect(x: 2, y: 2, width: 20, height: 20))
                outer.backgroundColor = UIColor(Paleta.acento)
                outer.layer.cornerRadius = 10
                outer.layer.borderColor = UIColor.white.cgColor
                outer.layer.borderWidth = 3.0
                outer.layer.shadowColor = UIColor.black.cgColor
                outer.layer.shadowOpacity = 0.55
                outer.layer.shadowRadius = 3
                outer.layer.shadowOffset = CGSize(width: 0, height: 1.5)

                let inner = UIView(frame: CGRect(x: 5.5, y: 5.5, width: 9, height: 9))
                inner.backgroundColor = .white
                inner.layer.cornerRadius = 4.5
                outer.addSubview(inner)
                view.addSubview(outer)
                return view
            } else if titulo.contains("atleta") {
                let id = "MarcadorAtleta"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                view.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
                view.subviews.forEach { $0.removeFromSuperview() }

                let dot = UIView(frame: CGRect(x: 2, y: 2, width: 18, height: 18))
                dot.backgroundColor = UIColor.white
                dot.layer.cornerRadius = 9
                dot.layer.borderColor = UIColor(Paleta.acento).cgColor
                dot.layer.borderWidth = 3.5
                dot.layer.shadowColor = UIColor.black.cgColor
                dot.layer.shadowOpacity = 0.6
                dot.layer.shadowRadius = 3
                dot.layer.shadowOffset = CGSize(width: 0, height: 1.5)
                view.addSubview(dot)
                return view
            }

            let identifier = "MarcadorReproductor"
            let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            marker.annotation = annotation

            if titulo.contains("pausa") {
                marker.markerTintColor = UIColor(Paleta.acento)
                marker.glyphImage = UIImage(systemName: "pause.fill")
            } else if titulo.contains("km") {
                marker.markerTintColor = UIColor.systemBlue
                marker.glyphText = annotation.subtitle ?? "KM"
            } else {
                marker.markerTintColor = UIColor(Paleta.acento)
            }
            return marker
        }
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapa = MKMapView()
        mapa.delegate = context.coordinator
        mapa.overrideUserInterfaceStyle = .dark
        mapa.showsCompass = false
        mapa.showsTraffic = false
        mapa.isRotateEnabled = true
        mapa.isPitchEnabled = true
        mapa.isScrollEnabled = true
        mapa.isZoomEnabled = true

        // Vista satelital con relieve en 3D
        if #available(iOS 16.0, *) {
            let config = MKHybridMapConfiguration(elevationStyle: .realistic)
            config.showsTraffic = false
            mapa.preferredConfiguration = config
        } else {
            mapa.mapType = .hybridFlyover
        }

        // Configurar anotaciones estáticas (Inicio verde, Fin naranja rosquilla, Pausas)
        if let inicio = puntosTotales.first {
            let pinInicio = MKPointAnnotation()
            pinInicio.coordinate = CLLocationCoordinate2D(latitude: inicio.lat, longitude: inicio.lon)
            pinInicio.title = "Inicio"
            mapa.addAnnotation(pinInicio)
        }
        if let fin = puntosTotales.last, puntosTotales.count > 1 {
            let pinFin = MKPointAnnotation()
            pinFin.coordinate = CLLocationCoordinate2D(latitude: fin.lat, longitude: fin.lon)
            pinFin.title = "Fin"
            mapa.addAnnotation(pinFin)
        }
        for pausa in pausas {
            let pinPausa = MKPointAnnotation()
            pinPausa.coordinate = CLLocationCoordinate2D(latitude: pausa.lat, longitude: pausa.lon)
            pinPausa.title = "Pausa \(pausa.numero)"
            mapa.addAnnotation(pinPausa)
        }

        // Marcador del atleta móvil y cámara inicial en 3D en tercera persona
        let atleta = MKPointAnnotation()
        atleta.title = "Atleta"
        if let actual = puntoActual {
            let coord = CLLocationCoordinate2D(latitude: actual.lat, longitude: actual.lon)
            atleta.coordinate = coord

            let rumboInicial: Double
            if puntosTotales.count >= 2 {
                rumboInicial = SegmentadorDeRecorrido.rumboEntre(
                    lat1: puntosTotales[0].lat, lon1: puntosTotales[0].lon,
                    lat2: puntosTotales[1].lat, lon2: puntosTotales[1].lon
                )
            } else {
                rumboInicial = 0.0
            }
            context.coordinator.ultimoRumboCamara = rumboInicial
            context.coordinator.ultimaCoordenadaCamara = coord

            let camara = MKMapCamera(
                lookingAtCenter: coord,
                fromDistance: 380,
                pitch: 65.0,
                heading: rumboInicial
            )
            mapa.setCamera(camara, animated: false)
        }
        context.coordinator.marcadorAtleta = atleta
        mapa.addAnnotation(atleta)

        return mapa
    }

    func updateUIView(_ mapa: MKMapView, context: Context) {
        let coord = context.coordinator

        // Actualizar overlay activo de recorrido trazado (NO mostrar ruta completa adelantada en gris)
        if let viejo = coord.rutaActivaOverlay {
            mapa.removeOverlay(viejo)
            coord.rutaActivaOverlay = nil
        }
        let coordsRecorridas = puntosRecorridos.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        if coordsRecorridas.count > 1 {
            let activo = MKPolyline(coordinates: coordsRecorridas, count: coordsRecorridas.count)
            coord.rutaActivaOverlay = activo
            mapa.addOverlay(activo)
        }

        // Mover el marcador del atleta y cámara en 3D en tercera persona siguiendo al atleta
        if let actual = puntoActual, let marcador = coord.marcadorAtleta {
            let actualCoord = CLLocationCoordinate2D(latitude: actual.lat, longitude: actual.lon)
            marcador.coordinate = actualCoord

            let rumboCamara: Double
            if coordsRecorridas.count >= 2 {
                let penultimo = coordsRecorridas[coordsRecorridas.count - 2]
                let dist = SegmentadorDeRecorrido.distanciaMetros(
                    lat1: penultimo.latitude, lon1: penultimo.longitude,
                    lat2: actualCoord.latitude, lon2: actualCoord.longitude
                )
                if dist >= 1.0 {
                    rumboCamara = SegmentadorDeRecorrido.rumboEntre(
                        lat1: penultimo.latitude, lon1: penultimo.longitude,
                        lat2: actualCoord.latitude, lon2: actualCoord.longitude
                    )
                    coord.ultimoRumboCamara = rumboCamara
                } else {
                    rumboCamara = coord.ultimoRumboCamara
                }
            } else {
                rumboCamara = coord.ultimoRumboCamara
            }

            var debeMoverCamara = false
            if let ult = coord.ultimaCoordenadaCamara {
                let d = SegmentadorDeRecorrido.distanciaMetros(
                    lat1: ult.latitude, lon1: ult.longitude,
                    lat2: actualCoord.latitude, lon2: actualCoord.longitude
                )
                if d >= 1.5 || abs(coord.ultimoRumboCamara - rumboCamara) > 4.0 {
                    debeMoverCamara = true
                }
            } else {
                debeMoverCamara = true
            }

            if debeMoverCamara {
                coord.ultimaCoordenadaCamara = actualCoord
                let camara = MKMapCamera(
                    lookingAtCenter: actualCoord,
                    fromDistance: 380,
                    pitch: 65.0,
                    heading: rumboCamara
                )
                mapa.setCamera(camara, animated: true)
            }
        }
    }
}
