import Foundation

/// Por qué lo que se ve no es lo último que tiene el servidor.
public enum ProblemaDeCarga: Equatable, Sendable {
    /// No se llegó al servidor: sin señal, o diez segundos sin respuesta.
    case sinRed
    /// `profile_incomplete`: al perfil le falta algo que el motor necesita. La app
    /// lo convierte en el aviso de completar el perfil, que ya existe.
    case perfilIncompleto
    /// El servidor contestó, pero no con el dato: un 5xx, una respuesta rara o un
    /// rechazo que no se arregla reintentando ya.
    case servidor

    /// Lo que pasó en un pedido, o `nil` si salió bien.
    public static func de<Valor>(_ resultado: Resultado<Valor>) -> ProblemaDeCarga? {
        switch resultado {
        case .ok: return nil
        case .sinRed: return .sinRed
        case .rechazado(let codigo, _) where codigo == "profile_incomplete": return .perfilIncompleto
        case .rechazado, .respuestaRara: return .servidor
        }
    }
}

/// Una parte del Home que sale del servidor: lo último bueno que llegó, cuándo
/// llegó, y qué pasó la última vez que se pidió.
///
/// 🛑 Que no haya `valor` NO es motivo para inventarlo. Sin nada guardado y sin red,
/// la pantalla dice eso; nunca pone datos de ejemplo en su lugar.
public struct Seccion<Valor> {
    public var valor: Valor?
    /// ms epoch de cuando llegó `valor`.
    public var guardadoEnMs: Int64?
    /// `nil` si la última vez salió bien, o si todavía no se preguntó.
    public var problema: ProblemaDeCarga?

    public init(valor: Valor? = nil, guardadoEnMs: Int64? = nil, problema: ProblemaDeCarga? = nil) {
        self.valor = valor
        self.guardadoEnMs = guardadoEnMs
        self.problema = problema
    }

    /// Lo guardado, antes de preguntarle nada al servidor.
    public init(_ guardado: Guardado<Valor>?) {
        self.init(valor: guardado?.valor, guardadoEnMs: guardado?.guardadoEnMs)
    }

    /// Hay algo para mostrar, pero no se pudo confirmar que siga siendo lo último:
    /// la pantalla lo muestra y lo dice.
    public var desactualizada: Bool { valor != nil && problema != nil }

    /// El mismo estado, con el valor transformado para mostrar.
    public func map<Otro>(_ transformar: (Valor) -> Otro?) -> Seccion<Otro> {
        Seccion<Otro>(valor: valor.flatMap(transformar), guardadoEnMs: guardadoEnMs, problema: problema)
    }
}

extension Seccion: Equatable where Valor: Equatable {}
extension Seccion: Sendable where Valor: Sendable {}
