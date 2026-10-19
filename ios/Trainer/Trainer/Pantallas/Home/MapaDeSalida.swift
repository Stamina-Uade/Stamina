import SwiftUI
import UIKit
import MapKit
import TrainerCore

// MARK: - Mapa De Salida

final class PolilineaSegmento: MKPolyline {}
final class PolilineaPausa: MKPolyline {}

/// Dibuja la polilínea con una sombra del mismo color: el "halo" de lo vivo.
/// La sombra de Quartz va en el espacio base, así que el desenfoque no cambia
/// con el zoom del mapa.
final class RenderizadorDeRutaConBrillo: MKPolylineRenderer {
    /// Se fija en el hilo principal al crear el renderer; acá sólo se lee.
    var colorDelBrillo: CGColor?

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let colorDelBrillo else {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            return
        }
        context.saveGState()
        context.setShadow(offset: .zero, blur: 10, color: colorDelBrillo)
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        context.restoreGState()
    }
}

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
                // La ruta en acento con halo, como en el mockup del entreno en vivo.
                let renderer = RenderizadorDeRutaConBrillo(polyline: polyline)
                renderer.colorDelBrillo = UIColor(Paleta.acento).withAlphaComponent(0.75).cgColor
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
