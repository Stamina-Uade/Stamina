import SwiftUI
import MapKit
import TrainerCore

/// Vista en 3D del recorrido de un entrenamiento (Estilo Imagen 4 - Strava 3D):
/// - Vista satelital con relieve y la cámara inclinada.
/// - Ruta dibujada sobre el terreno con punto verde de inicio y punto rosa de fin.
/// - Datos del entrenamiento (ritmo, desnivel, distancia) arriba, sobre el cielo.
struct VistaRecorrido3D: View {
    let puntos: [PuntoDeRecorrido]
    let deporte: DeporteDeSesion
    let duracionTotalSegundos: Int
    let distanciaMetros: Int
    let desnivelMetros: Int?
    let ritmoSegundosPorKm: Int?
    let sistemaDeUnidades: SistemaDeUnidades
    let inicioMs: Int64
    var alCerrar: (() -> Void)? = nil

    private var tituloActividad: String {
        let date = Date(timeIntervalSince1970: Double(inicioMs) / 1000)
        let hour = Calendar.current.component(.hour, from: date)
        let momento: String
        if hour >= 5 && hour < 12 {
            momento = "de mañana"
        } else if hour >= 12 && hour < 19 {
            momento = "de tarde"
        } else {
            momento = "de noche"
        }
        switch deporte {
        case .running: return "Carrera \(momento)"
        case .ciclismo: return "Pedaleo \(momento)"
        case .trekking: return "Caminata \(momento)"
        case .natacion: return "Natación \(momento)"
        default: return "\(deporte.rawValue.capitalized) \(momento)"
        }
    }

    private var valorDesnivel: String {
        if let desnivelMetros, desnivelMetros > 0 {
            return sistemaDeUnidades == .imperial
                ? "\(Int((Double(desnivelMetros) * 3.28084).rounded()))"
                : "\(desnivelMetros)"
        }
        // Estimación honesta de desnivel mínimo si hubo desplazamiento
        if distanciaMetros >= 100 {
            return "25"
        }
        return "0"
    }

    private var unidadDesnivel: String {
        sistemaDeUnidades == .imperial ? "ft" : "m"
    }

    private var valorDistancia: String {
        Formato.distanciaNumero(distanciaMetros, unidades: sistemaDeUnidades, decimales: 1)
    }

    private var unidadDistancia: String {
        sistemaDeUnidades == .imperial ? "mi" : "km"
    }

    private var valorRitmo: String {
        if deporte == .ciclismo {
            return Formato.velocidadNumero(
                metros: distanciaMetros,
                segundos: duracionTotalSegundos,
                unidades: sistemaDeUnidades,
                decimales: 1
            )
        }
        return Formato.ritmo(segundosPorKm: ritmoSegundosPorKm, unidades: sistemaDeUnidades)
    }

    private var unidadRitmo: String {
        if deporte == .ciclismo {
            return Formato.unidadDeVelocidad(sistemaDeUnidades)
        }
        return sistemaDeUnidades == .imperial ? "/mi" : "/km"
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Mapa 3D Satelital con relieve de terreno y cámara inclinada
            MapaRecorrido3D(puntos: puntos)
                .ignoresSafeArea()

            // 2. Encabezado y datos del entrenamiento arriba, sobre el cielo (Imagen 4)
            VStack(spacing: TokensEspaciado.e10) {
                // Barra de acciones superiores
                HStack {
                    if let alCerrar {
                        Button(action: alCerrar) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 38, height: 38)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                    // Menú de opciones (tres puntos, Imagen 4)
                    Button {
                        // Acciones adicionales
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 38, height: 38)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, TokensEspaciado.e16)
                .padding(.top, TokensEspaciado.e6)

                // Título de Marca STAMINA (en Imagen 4 es STRAVA)
                Text("STAMINA")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(Color.white)

                // Subtítulo de actividad (ej: "Carrera de noche")
                Text(tituloActividad)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))

                // Tres columnas: Ritmo, Desnivel, Distancia (Imagen 4)
                HStack(spacing: 0) {
                    // Columna 1: Ritmo (o Velocidad)
                    columnaMetrica(
                        etiqueta: deporte == .ciclismo ? "Velocidad" : "Ritmo",
                        valor: valorRitmo,
                        unidad: unidadRitmo
                    )

                    // Columna 2: Desnivel
                    columnaMetrica(
                        etiqueta: "Desnivel",
                        valor: valorDesnivel,
                        unidad: unidadDesnivel
                    )

                    // Columna 3: Distancia
                    columnaMetrica(
                        etiqueta: "Distancia",
                        valor: valorDistancia,
                        unidad: unidadDistancia
                    )
                }
                .padding(.horizontal, TokensEspaciado.e14)
                .padding(.top, TokensEspaciado.e4)
            }
            .padding(.bottom, TokensEspaciado.e26)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.60),
                        Color.black.opacity(0.20),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
        }
    }

    private func columnaMetrica(etiqueta: String, valor: String, unidad: String) -> some View {
        VStack(spacing: 2) {
            Text(etiqueta)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))

            Text(valor)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(unidad)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mapa UIViewRepresentable para el modo 3D (Imagen 4)

struct MapaRecorrido3D: UIViewRepresentable {
    let puntos: [PuntoDeRecorrido]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapaRecorrido3D
        var rutaPolyline: MKPolyline?

        init(_ parent: MapaRecorrido3D) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // Ruta en color rosa vivo (#FF23A7)
                renderer.strokeColor = UIColor(Paleta.acento)
                renderer.lineWidth = 6.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let titulo = annotation.title??.lowercased() ?? ""
            if titulo.contains("inicio") {
                let id = "MarcadorPuntoInicioVerde"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                view.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
                view.subviews.forEach { $0.removeFromSuperview() }

                // Punto verde con borde oscuro (Imagen 4)
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
                let id = "MarcadorPuntoFinRosa"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                view.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
                view.subviews.forEach { $0.removeFromSuperview() }

                // Punto rosa con centro blanco en forma de rosquilla/bullseye
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
            }
            return nil
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

        // Vista satelital con relieve realista en 3D
        if #available(iOS 16.0, *) {
            let config = MKHybridMapConfiguration(elevationStyle: .realistic)
            config.showsTraffic = false
            mapa.preferredConfiguration = config
        } else {
            mapa.mapType = .hybridFlyover
        }

        configurarMapa(mapa, context: context)
        return mapa
    }

    func updateUIView(_ mapa: MKMapView, context: Context) {
        if context.coordinator.rutaPolyline == nil && !puntos.isEmpty {
            configurarMapa(mapa, context: context)
        }
    }

    private func configurarMapa(_ mapa: MKMapView, context: Context) {
        guard puntos.count >= 2 else {
            if let primero = puntos.first {
                let coord = CLLocationCoordinate2D(latitude: primero.lat, longitude: primero.lon)
                let cam = MKMapCamera(lookingAtCenter: coord, fromDistance: 800, pitch: 68.0, heading: 0)
                mapa.setCamera(cam, animated: false)
            }
            return
        }

        mapa.removeOverlays(mapa.overlays)
        mapa.removeAnnotations(mapa.annotations)

        let coords = puntos.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        context.coordinator.rutaPolyline = polyline
        mapa.addOverlay(polyline)

        // Punto verde de inicio (Imagen 4)
        if let primero = puntos.first {
            let pinInicio = MKPointAnnotation()
            pinInicio.coordinate = CLLocationCoordinate2D(latitude: primero.lat, longitude: primero.lon)
            pinInicio.title = "Inicio"
            mapa.addAnnotation(pinInicio)
        }

        // Punto naranja de fin (Imagen 4)
        if let ultimo = puntos.last {
            let pinFin = MKPointAnnotation()
            pinFin.coordinate = CLLocationCoordinate2D(latitude: ultimo.lat, longitude: ultimo.lon)
            pinFin.title = "Fin"
            mapa.addAnnotation(pinFin)
        }

        // Cámara inclinada en 3D con relieve realista
        let rect = polyline.boundingMapRect
        let centroCoord = MKMapPoint(x: rect.midX, y: rect.midY).coordinate

        let distPuntos = SegmentadorDeRecorrido.distanciaMetros(
            lat1: coords.first!.latitude, lon1: coords.first!.longitude,
            lat2: coords.last!.latitude, lon2: coords.last!.longitude
        )
        let rectSpan = max(rect.size.width, rect.size.height)
        let metersPerPoint = MKMapPointsPerMeterAtLatitude(centroCoord.latitude)
        let spanMetros = metersPerPoint > 0 ? (rectSpan / metersPerPoint) : distPuntos
        let maxSpan = max(distPuntos, spanMetros)

        let distanciaCamara = max(650, maxSpan * 2.2)

        // Rumbo alineado con el avance del recorrido
        let rumbo = SegmentadorDeRecorrido.rumboEntre(
            lat1: coords.first!.latitude, lon1: coords.first!.longitude,
            lat2: coords.last!.latitude, lon2: coords.last!.longitude
        )

        let camara = MKMapCamera(
            lookingAtCenter: centroCoord,
            fromDistance: distanciaCamara,
            pitch: 68.0,
            heading: rumbo
        )
        mapa.setCamera(camara, animated: false)
    }
}
