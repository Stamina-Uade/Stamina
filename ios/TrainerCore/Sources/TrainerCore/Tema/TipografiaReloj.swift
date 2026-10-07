import SwiftUI

/// Los roles tipográficos del reloj.
///
/// Son propios y no una escala del teléfono en chiquito: el cronómetro es de
/// **62 pt** —el número más grande del producto— porque se mira de reojo, con el
/// brazo en movimiento y transpirado. Salen de `tokens.json`, igual que todo.
extension EstiloTipografico {

    public static let relojCronometro = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojCronometroTamano),
        peso: TokensTipografia.relojCronometroPeso,
        interlineado: 1.0, espaciadoLetrasEm: -0.045,
        cifrasTabulares: true, referencia: .largeTitle)

    public static let relojMetrica = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojMetricaTamano),
        peso: TokensTipografia.relojMetricaPeso,
        interlineado: 1.0, espaciadoLetrasEm: -0.04,
        cifrasTabulares: true, referencia: .largeTitle)

    public static let relojTituloAviso = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojTituloAvisoTamano),
        peso: TokensTipografia.relojTituloAvisoPeso,
        interlineado: 1.05, espaciadoLetrasEm: -0.03, referencia: .title)

    public static let relojEstado = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojEstadoTamano),
        peso: TokensTipografia.relojEstadoPeso,
        espaciadoLetrasEm: -0.03, cifrasTabulares: true, referencia: .title2)

    public static let relojBoton = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojBotonTamano),
        peso: TokensTipografia.relojBotonPeso, referencia: .headline)

    public static let relojUnidad = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojUnidadTamano),
        peso: TokensTipografia.relojUnidadPeso,
        interlineado: 1.15, referencia: .body)

    public static let relojCuerpo = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojCuerpoTamano),
        peso: TokensTipografia.relojCuerpoPeso,
        interlineado: 1.4, referencia: .body)

    public static let relojEtiqueta = EstiloTipografico(
        tamano: PaletaReloj.puntosDeDiseno(TokensTipografia.relojEtiquetaTamano),
        peso: TokensTipografia.relojEtiquetaPeso,
        espaciadoLetrasEm: 0.1, mayusculas: true, referencia: .caption)
}

// -----------------------------------------------------------------------------

extension View {
    /// Un NÚMERO que no se puede truncar.
    ///
    /// 🛑 En la muñeca la pantalla es angosta y el ritmo se dibuja a 46 pt: sin
    /// esto, "5:48" sale como "5:4" — que no es un número chico, es **otro
    /// número**. Antes que truncar, se achica.
    public func numeroDelReloj() -> some View {
        lineLimit(1).minimumScaleFactor(0.5)
    }

    /// Un título de aviso: puede ocupar varias líneas y achicarse un poco, pero
    /// nunca cortarse con puntos suspensivos. Es lo que se lee sin parar de
    /// correr.
    public func tituloDelReloj() -> some View {
        lineLimit(3).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
    }

    /// Un texto de cuerpo del reloj: envuelve, no se corta.
    public func cuerpoDelReloj() -> some View {
        fixedSize(horizontal: false, vertical: true)
    }
}
