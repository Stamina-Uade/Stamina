import SwiftUI

// =============================================================================
// Accesibilidad que se hace cumplir con código, no con buena voluntad.
//
// AGENTS.md §10.1 exige 48 pt de objetivo táctil mínimo, sin excepciones.
// `design/ESPECIFICACION.md` §9.2 midió el diseño y encontró **13 de 34**
// elementos accionables por debajo del mínimo en el flujo de entrada, con el
// indicador del carousel en 3 px como peor caso.
//
// La corrección que la propia especificación propone es "área táctil ampliada,
// sin tocar densidad ni layout": el control se DIBUJA como está diseñado y
// RESPONDE en 48. Eso es lo que hace `objetivoTactil()`.
// =============================================================================

// 🛑 DÓNDE SE APLICA — la parte que es fácil de hacer mal, y que ya se hizo mal
// una vez: **va ADENTRO del `label:` del botón, no afuera.**
//
//     Button { … } label: { Image(…).objetivoTactil() }   ✅
//     Button { … } label: { Image(…) }.objetivoTactil()   ❌
//
// SwiftUI hace hit-testing sobre el contenido del label, no sobre el frame que
// se le ponga al botón desde afuera. Aplicado afuera, el control **se ve** de 48
// y **se toca** en 13: exactamente el bug que esta función existe para evitar.
// La versión de abajo lleva `contentShape`, así que adentro del label también
// funciona sobre relleno transparente.

extension View {
    /// Garantiza el objetivo táctil mínimo sin cambiar cómo se ve el control.
    ///
    /// El área crece alrededor del dibujo, así que el layout no se mueve: un
    /// indicador de carousel de 3 pt de alto sigue midiendo 3 pt en pantalla y
    /// se toca en 48.
    ///
    /// - Important: adentro del `label:`. Ver el bloque de arriba.
    public func objetivoTactil() -> some View {
        frame(
            minWidth: TokensTamano.objetivoTactilMinimo,
            minHeight: TokensTamano.objetivoTactilMinimo
        )
        .contentShape(Rectangle())
    }

    /// Igual que `objetivoTactil()` pero sólo en alto, para controles de ancho
    /// completo o que viven en una fila apretada.
    public func objetivoTactilAlto() -> some View {
        frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .contentShape(Rectangle())
    }
}
