import SwiftUI
import UIKit
import MapKit
import TrainerCore

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
