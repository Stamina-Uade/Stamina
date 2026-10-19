import UIKit
import MapKit

// Las vistas UIKit del punto del usuario en el mapa: el punto azul con halo y
// el cono que marca hacia dónde apunta el celular.

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
