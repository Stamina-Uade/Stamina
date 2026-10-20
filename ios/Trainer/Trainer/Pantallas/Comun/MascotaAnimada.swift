import ImageIO
import QuartzCore
import SwiftUI
import UIKit

// =============================================================================
// La mascota EN MOVIMIENTO: ocho animaciones del serval, cada una un WebP
// animado con transparencia (360 × 360, 12 cuadros por segundo, 96 cuadros, en
// loop) guardado como data asset (`<nombre>.dataset/<nombre>.webp`).
//
// Cómo se reproduce: EN STREAMING. Se guarda el WebP tal cual (≈ 1,3 MB) y sus
// demoras, leídas una vez. Cada mascota que se ve tiene su `CGImageSource`, y
// un `CADisplayLink` va pidiendo el cuadro que toca: se decodifica en una cola
// de fondo (ya achicado a alto × escala de la pantalla) y se pone en
// `layer.contents`. Se adelanta UN cuadro, nada más.
//
// 🪤 La memoria. Decodificar los 96 cuadros de una vez son ≈ 50 MB por
// animación. Así, en cambio, una mascota que se mueve tiene en memoria el
// cuadro que se ve y el que viene (≈ 0,5 MB cada uno a 360²), más el WebP
// comprimido, que se comparte: menos de 3 MB.
//
// El reloj se apaga cuando la vista sale de la ventana o se oculta. Con
// "Reducir movimiento" (o `reproducir: false`) queda el primer cuadro, quieto.
//
// Si el WebP no se puede leer, queda la pose quieta en PNG que corresponde
// ("MascotaSaludo", "MascotaCorriendo", "MascotaMedalla"): por eso esos assets
// siguen en el catálogo. Sólo existe en el target del iPhone.
// =============================================================================

/// Las animaciones de la mascota. El valor es el nombre del data asset.
enum AnimacionDeMascota: String, CaseIterable {
    case saludando
    case senalandoAbajo = "senalando_abajo"
    case senalandoArriba = "senalando_arriba"
    case senalandoCostado = "senalando_costado"
    case corriendo
    case medalla
    case pulgarArriba = "pulgar_arriba"
    case parpadeoOrejas = "parpadeo_orejas"

    /// El data asset (`<nombre>.dataset/<nombre>.webp`).
    var recurso: String { rawValue }

    /// La pose quieta que la reemplaza si el WebP no se puede decodificar.
    var poseDeRespaldo: PoseDeMascota {
        switch self {
        case .corriendo: return .corriendo
        case .medalla, .pulgarArriba: return .medalla
        case .saludando, .senalandoAbajo, .senalandoArriba, .senalandoCostado, .parpadeoOrejas:
            return .saludo
        }
    }
}

// MARK: - La vista

/// La mascota animada, cuadrada, del alto que se le pida (o menos, si no hay
/// lugar). Con "Reducir movimiento" muestra sólo el primer cuadro.
///
/// - `loop: false` la pasa una vez y se queda en el último cuadro (la medalla).
/// - `reproducir: false` muestra el primer cuadro, quieto: para las que están
///   ocultas, como las fotos que no se ven de la bienvenida.
struct MascotaAnimada: View {
    private let animacion: AnimacionDeMascota
    private let loop: Bool
    private let alto: CGFloat
    private let reproducir: Bool

    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @Environment(\.displayScale) private var escala
    @State private var datos: DatosDeMascota?
    @State private var fallo = false

    init(_ animacion: AnimacionDeMascota, loop: Bool = true, alto: CGFloat, reproducir: Bool = true) {
        self.animacion = animacion
        self.loop = loop
        self.alto = alto
        self.reproducir = reproducir
    }

    var body: some View {
        contenido
            .aspectRatio(1, contentMode: .fit)
            .frame(maxHeight: alto)
            .accessibilityHidden(true)
            .task(id: animacion) { [animacion = self.animacion] in await cargar(animacion) }
    }

    @ViewBuilder
    private var contenido: some View {
        if fallo {
            Image(animacion.poseDeRespaldo.recurso)
                .resizable()
                .scaledToFit()
        } else if let datos, datos.animacion == animacion {
            ReproductorDeMascota(datos: datos, loop: loop,
                                 anima: reproducir && !movimientoReducido && datos.cantidad > 1,
                                 ladoMaximo: DecodificadorDeMascota.ladoEnPixeles(alto: alto, escala: escala),
                                 alFallar: { fallo = true })
        } else {
            // Lo que tarda en leerse el WebP: un instante.
            Color.clear
        }
    }

    @MainActor
    private func cargar(_ animacion: AnimacionDeMascota) async {
        fallo = false
        let leidos = await AlmacenDeMascota.compartido.datos(de: animacion)
        guard !Task.isCancelled else { return }
        if let leidos {
            datos = leidos
        } else {
            fallo = true
        }
    }
}

// MARK: - Los datos de una animación

/// El WebP de una animación, comprimido, y cuánto dura cada cuadro. Inmutable:
/// se comparte entre hilos y entre todas las mascotas que la muestran.
final class DatosDeMascota: @unchecked Sendable {
    let animacion: AnimacionDeMascota
    let datos: Data
    let demoras: [TimeInterval]

    init(animacion: AnimacionDeMascota, datos: Data, demoras: [TimeInterval]) {
        self.animacion = animacion
        self.datos = datos
        self.demoras = demoras
    }

    var cantidad: Int { demoras.count }
}

/// Lee un WebP animado con ImageIO. Todo es estático y sin estado: se llama
/// desde cualquier hilo.
enum DecodificadorDeMascota {
    /// 12 cuadros por segundo: lo que duran los de la mascota.
    static let demoraPorDefecto: TimeInterval = 1.0 / 12.0
    /// Una demora menor que esto se toma como "no dice": es la regla de los
    /// navegadores para los GIF y WebP con demora 0 o casi.
    static let demoraMinima: TimeInterval = 0.011

    /// La demora de un cuadro, a partir de sus propiedades
    /// (`CGImageSourceCopyPropertiesAtIndex`): la sin recortar si la hay, si
    /// no la recortada, y si ninguna sirve, 1/12 s.
    static func demora(de propiedades: [String: Any]?) -> TimeInterval {
        guard let webp = propiedades?[kCGImagePropertyWebPDictionary as String] as? [String: Any] else {
            return demoraPorDefecto
        }
        let claves = [kCGImagePropertyWebPUnclampedDelayTime as String, kCGImagePropertyWebPDelayTime as String]
        for clave in claves {
            if let valor = numero(webp[clave]), valor >= demoraMinima { return valor }
        }
        return demoraPorDefecto
    }

    /// El lado, en píxeles, con el que se dibuja una mascota de `alto` puntos.
    static func ladoEnPixeles(alto: CGFloat, escala: CGFloat) -> Int {
        max(1, Int((alto * max(escala, 1)).rounded(.up)))
    }

    /// El cuadro que va después de `indice`: el siguiente, o el primero si da
    /// la vuelta. `nil` si terminó (sin loop, en el último).
    static func siguiente(a indice: Int, de total: Int, loop: Bool) -> Int? {
        guard total > 0 else { return nil }
        let proximo = indice + 1
        if proximo < total { return proximo }
        return loop ? 0 : nil
    }

    /// El WebP y las demoras de sus cuadros (sólo metadatos: no decodifica
    /// ningún cuadro). `nil` si no es una imagen que ImageIO entienda.
    static func leer(_ datos: Data, animacion: AnimacionDeMascota) -> DatosDeMascota? {
        guard let fuente = crearFuente(datos) else { return nil }
        let total = CGImageSourceGetCount(fuente)
        guard total > 0 else { return nil }
        let demoras = (0..<total).map { indice in
            demora(de: CGImageSourceCopyPropertiesAtIndex(fuente, indice, nil) as? [String: Any])
        }
        return DatosDeMascota(animacion: animacion, datos: datos, demoras: demoras)
    }

    /// Sin caché propia: la fuente no se queda con los cuadros que decodifica.
    static func crearFuente(_ datos: Data) -> CGImageSource? {
        let opciones: [CFString: Any] = [kCGImageSourceShouldCache: false]
        return CGImageSourceCreateWithData(datos as CFData, opciones as CFDictionary)
    }

    /// Un cuadro, achicado a `ladoMaximo` y ya decodificado
    /// (`ShouldCacheImmediately`): así no se decodifica después, en el hilo
    /// principal, al dibujarlo.
    static func cuadro(de fuente: CGImageSource, en indice: Int, ladoMaximo: Int) -> CGImage? {
        let opciones: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: ladoMaximo,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(fuente, indice, opciones as CFDictionary)
    }

    /// Un número de un diccionario de ImageIO (llegan como `CFNumber`).
    private static func numero(_ valor: Any?) -> Double? {
        if let doble = valor as? Double { return doble }
        if let numero = valor as? NSNumber { return numero.doubleValue }
        return nil
    }
}

// MARK: - El almacén

/// Lee cada WebP una sola vez (datos + demoras) y lo guarda. Si dos vistas
/// piden el mismo a la vez, la segunda espera a la primera.
actor AlmacenDeMascota {
    static let compartido = AlmacenDeMascota()

    /// Unos pocos WebP comprimidos (≈ 1,3 MB cada uno).
    private let leidos = NSCache<NSString, DatosDeMascota>()
    private var enCurso: [AnimacionDeMascota: Task<DatosDeMascota?, Never>] = [:]

    init() {
        leidos.countLimit = 4
    }

    func datos(de animacion: AnimacionDeMascota) async -> DatosDeMascota? {
        let clave = animacion.rawValue as NSString
        if let listos = leidos.object(forKey: clave) { return listos }
        if let enMarcha = enCurso[animacion] { return await enMarcha.value }

        let tarea = Task.detached(priority: .userInitiated) { () -> DatosDeMascota? in
            guard let datos = NSDataAsset(name: animacion.recurso)?.data else { return nil }
            return DecodificadorDeMascota.leer(datos, animacion: animacion)
        }
        enCurso[animacion] = tarea
        let resultado = await tarea.value
        enCurso[animacion] = nil
        if let resultado {
            leidos.setObject(resultado, forKey: clave, cost: resultado.datos.count)
        }
        return resultado
    }
}

// MARK: - El reproductor

/// La vista de UIKit que pasa los cuadros, envuelta para SwiftUI.
private struct ReproductorDeMascota: UIViewRepresentable {
    let datos: DatosDeMascota
    let loop: Bool
    let anima: Bool
    let ladoMaximo: Int
    let alFallar: () -> Void

    func makeUIView(context: Context) -> VistaDeMascota {
        VistaDeMascota(frame: .zero)
    }

    func updateUIView(_ vista: VistaDeMascota, context: Context) {
        vista.alFallar = alFallar
        vista.configurar(datos: datos, loop: loop, anima: anima, ladoMaximo: ladoMaximo)
    }

    static func dismantleUIView(_ vista: VistaDeMascota, coordinator: ()) {
        vista.detener()
    }
}

/// Decodifica cuadros en una cola de fondo propia, con SU `CGImageSource`
/// (que sólo se toca en esa cola). Cada pedido lleva la generación de la
/// vista: si la vista ya cambió de animación, el pedido viejo se descarta.
private final class CuadrosEnCola: @unchecked Sendable {
    private let cola = DispatchQueue(label: "stamina.mascota.cuadros", qos: .userInitiated)
    private var fuente: CGImageSource?
    private var generacion = 0

    func preparar(_ datos: Data, generacion: Int) {
        cola.async {
            self.generacion = generacion
            self.fuente = DecodificadorDeMascota.crearFuente(datos)
        }
    }

    func cuadro(_ indice: Int, ladoMaximo: Int, generacion: Int,
                listo: @escaping (CGImage?) -> Void) {
        cola.async {
            guard self.generacion == generacion else { return }
            let imagen = self.fuente.flatMap {
                DecodificadorDeMascota.cuadro(de: $0, en: indice, ladoMaximo: ladoMaximo)
            }
            DispatchQueue.main.async { listo(imagen) }
        }
    }

    func soltar() {
        cola.async {
            self.generacion = -1
            self.fuente = nil
        }
    }
}

/// El destino del `CADisplayLink`, que retiene a su destino: así la vista no
/// queda retenida por el reloj. Si la vista ya no está, apaga el reloj.
@MainActor
private final class DestinoDebil: NSObject {
    weak var vista: VistaDeMascota?

    init(_ vista: VistaDeMascota) {
        self.vista = vista
    }

    @objc func tic(_ enlace: CADisplayLink) {
        guard let vista else { return enlace.invalidate() }
        vista.tic(enlace)
    }
}

/// Muestra un cuadro por vez en `layer.contents` y, mientras anima, un
/// `CADisplayLink` cuenta el tiempo y pide el siguiente. Todo en el hilo
/// principal salvo la decodificación (`CuadrosEnCola`).
private final class VistaDeMascota: UIView {
    var alFallar: (() -> Void)?

    private struct Configuracion: Equatable {
        let datos: ObjectIdentifier
        let loop: Bool
        let anima: Bool
        let ladoMaximo: Int
    }

    private let decodificador = CuadrosEnCola()
    private var configuracion: Configuracion?
    private var generacion = 0
    private var demoras: [TimeInterval] = []
    private var loop = true
    private var anima = false
    private var ladoMaximo = 1

    /// El cuadro que se ve, y desde cuándo.
    private var indice = 0
    private var transcurrido: TimeInterval = 0
    private var ultimoInstante: CFTimeInterval?
    private var mostrandoAlgo = false
    private var tamanoDelPrimero: CGSize?
    /// El que viene, ya decodificado (si llegó).
    private var proximo: (indice: Int, imagen: CGImage)?
    private var pidiendo = false
    private var termino = false
    private var enlace: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        layer.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// Sin tamaño propio: lo decide SwiftUI.
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { detenerElReloj() } else { arrancarElReloj() }
    }

    override var isHidden: Bool {
        didSet { if isHidden { detenerElReloj() } else { arrancarElReloj() } }
    }

    // MARK: Configurar

    func configurar(datos: DatosDeMascota, loop: Bool, anima: Bool, ladoMaximo: Int) {
        let nueva = Configuracion(datos: ObjectIdentifier(datos), loop: loop, anima: anima, ladoMaximo: ladoMaximo)
        guard nueva != configuracion else { return }
        configuracion = nueva
        detenerElReloj()
        generacion += 1
        demoras = datos.demoras
        self.loop = loop
        self.anima = anima
        self.ladoMaximo = ladoMaximo
        indice = 0
        transcurrido = 0
        ultimoInstante = nil
        mostrandoAlgo = false
        tamanoDelPrimero = nil
        proximo = nil
        pidiendo = false
        termino = false
        // El cuadro de antes queda a la vista hasta que llegue el primero.
        decodificador.preparar(datos.datos, generacion: generacion)
        pedir(0)
    }

    /// Al desmontarla: se apaga el reloj y se suelta la fuente.
    func detener() {
        detenerElReloj()
        generacion += 1
        configuracion = nil
        decodificador.soltar()
    }

    // MARK: Pedir y mostrar cuadros

    private func pedir(_ buscado: Int) {
        guard !pidiendo else { return }
        pidiendo = true
        let generacion = self.generacion
        decodificador.cuadro(buscado, ladoMaximo: ladoMaximo, generacion: generacion) { [weak self] imagen in
            guard let self, self.generacion == generacion else { return }
            self.pidiendo = false
            self.llego(imagen, indice: buscado)
        }
    }

    private func llego(_ imagen: CGImage?, indice llegado: Int) {
        guard let imagen else { return fallar() }
        // 🪤 Los cuadros del WebP son recortes del lienzo; ImageIO los entrega
        // ya compuestos, todos del mismo tamaño. Si uno llegara de otro tamaño,
        // la animación saltaría: mejor la pose quieta.
        let tamano = CGSize(width: imagen.width, height: imagen.height)
        if let primero = tamanoDelPrimero, primero != tamano { return fallar() }
        if tamanoDelPrimero == nil { tamanoDelPrimero = tamano }

        guard mostrandoAlgo else {
            // El primero: se muestra ya y, si anima, arranca el reloj.
            layer.contents = imagen
            indice = llegado
            mostrandoAlgo = true
            if anima {
                pedirElQueSigue()
                arrancarElReloj()
            }
            return
        }
        proximo = (indice: llegado, imagen: imagen)
    }

    private func pedirElQueSigue() {
        guard let siguiente = DecodificadorDeMascota.siguiente(a: indice, de: demoras.count, loop: loop) else { return }
        pedir(siguiente)
    }

    private func fallar() {
        detenerElReloj()
        generacion += 1
        alFallar?()
    }

    // MARK: El reloj

    private func arrancarElReloj() {
        guard enlace == nil, anima, mostrandoAlgo, !termino, window != nil, !isHidden else { return }
        let nuevo = CADisplayLink(target: DestinoDebil(self), selector: #selector(DestinoDebil.tic(_:)))
        // Los cuadros van a 12 por segundo: no hace falta despertar a 120.
        nuevo.preferredFrameRateRange = CAFrameRateRange(minimum: 12, maximum: 30, preferred: 24)
        ultimoInstante = nil
        nuevo.add(to: .main, forMode: .common)
        enlace = nuevo
    }

    private func detenerElReloj() {
        enlace?.invalidate()
        enlace = nil
        ultimoInstante = nil
    }

    fileprivate func tic(_ enlace: CADisplayLink) {
        let ahora = enlace.timestamp
        defer { ultimoInstante = ahora }
        guard let antes = ultimoInstante else { return }
        // Después de una pausa larga no se salta de golpe: sigue de donde estaba.
        transcurrido += min(max(ahora - antes, 0), DecodificadorDeMascota.demoraPorDefecto * 3)

        let demora = demoras.indices.contains(indice) ? demoras[indice] : DecodificadorDeMascota.demoraPorDefecto
        guard transcurrido >= demora else { return }
        guard let listo = proximo else {
            // El que viene todavía se está decodificando: espera sin acumular.
            transcurrido = demora
            return
        }
        proximo = nil
        layer.contents = listo.imagen
        indice = listo.indice
        transcurrido -= demora

        if DecodificadorDeMascota.siguiente(a: indice, de: demoras.count, loop: loop) == nil {
            // Sin loop, en el último: queda quieto ahí (la medalla en alto).
            termino = true
            detenerElReloj()
        } else {
            pedirElQueSigue()
        }
    }
}
