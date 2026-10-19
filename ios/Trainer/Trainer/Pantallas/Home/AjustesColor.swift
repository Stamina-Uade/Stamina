import SwiftUI
import TrainerCore

// =============================================================================
// Ajustes → Apariencia → Color de la app.
//
// Arriba, una vista previa EN VIVO pintada con el color candidato (armado con
// sus componentes, no con `Paleta.acento`, que es el que ya está aplicado).
// Abajo, la paleta y un último círculo para elegir cualquier color.
//
// 🪤 Guardar el color re-crea el Home entero (`RaizHomeView` usa
// `.id(acentoGuardado)`), así que todo `@State` de acá se pierde al aplicar.
// Por eso:
//  - Un círculo de la paleta se aplica al toque: no hay pasos que recordar.
//  - El selector libre NO guarda en cada arrastre (re-crearía la pantalla y le
//    cerraría el selector del sistema en la mano). Muestra el candidato en la
//    vista previa y recién guarda con "Usar este color", que es el último paso.
//  - `AjustesAncla` recuerda volver acá, porque el scroll arranca de cero.
// =============================================================================

/// Dónde dejar el scroll de Ajustes después de que el color re-crea el Home.
/// Es `static` justamente para sobrevivir a esa re-creación.
enum AjustesAncla {
    static let color = "ajustes_color"
    /// Se lee y se borra en el `onAppear` de `AjustesView`.
    static var alVolver: String?
}

struct AjustesSelectorDeColor: View {
    @AppStorage(AcentoPersonalizado.clave) private var acentoGuardado = ""
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    /// Lo que muestra el selector libre. Arranca en el color aplicado.
    @State private var colorLibre: Color = AcentoPersonalizado.color(
        paraGuardado: UserDefaults.standard.string(forKey: AcentoPersonalizado.clave) ?? "")
    /// "r,g,b" del color libre elegido y todavía NO aplicado.
    @State private var librePendiente: String?

    private let columnas = [
        GridItem(.adaptive(minimum: TokensEspaciado.e56 + TokensEspaciado.e8),
                 spacing: TokensEspaciado.e8, alignment: .top),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
            AjustesVistaPreviaDeColor(componentes: componentesCandidatos,
                                      sinAplicar: librePendiente != nil)

            if let librePendiente {
                confirmacion(librePendiente)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            LazyVGrid(columns: columnas, alignment: .center, spacing: TokensEspaciado.e12) {
                ForEach(AcentoPersonalizado.opciones) { opcion in
                    muestra(opcion)
                }
                muestraLibre
            }

            if !AcentoPersonalizado.esPredeterminado(acentoGuardado) {
                botonRestablecer
            }
        }
        .animation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida),
                   value: librePendiente == nil)
    }

    // MARK: Estado derivado

    /// Lo que pinta la vista previa: el libre sin aplicar o, si no hay, el aplicado.
    private var componentesCandidatos: (Double, Double, Double) {
        if let librePendiente, let c = AcentoPersonalizado.componentes(de: librePendiente) {
            return c
        }
        return AcentoPersonalizado.componentesOPredeterminado(de: acentoGuardado)
    }

    private func estaElegida(_ opcion: OpcionDeAcento) -> Bool {
        guard librePendiente == nil else { return false }
        if AcentoPersonalizado.esPredeterminado(acentoGuardado) {
            return opcion == AcentoPersonalizado.predeterminado
        }
        return opcion.guardado == acentoGuardado
    }

    private var libreElegido: Bool {
        librePendiente != nil || AcentoPersonalizado.esLibre(acentoGuardado)
    }

    // MARK: Círculos

    private func muestra(_ opcion: OpcionDeAcento) -> some View {
        let elegida = estaElegida(opcion)
        return Button {
            elegir(opcion)
        } label: {
            VStack(spacing: TokensEspaciado.e6) {
                AjustesCirculoDeColor(color: opcion.color, elegido: elegida,
                                      tildeOscuro: AcentoPersonalizado.textoOscuroEncima(
                                          opcion.rojo, opcion.verde, opcion.azul))
                nombre(opcion.nombre, elegido: elegida)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(opcion.nombre)
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
    }

    /// El último círculo: el selector de color del sistema, con su aro de
    /// colores (que ya dice "cualquier color" sin palabras).
    private var muestraLibre: some View {
        VStack(spacing: TokensEspaciado.e6) {
            ZStack {
                Circle()
                    .strokeBorder(libreElegido ? Paleta.textoPrimario : Color.clear,
                                  lineWidth: TokensEspaciado.e2)
                    .allowsHitTesting(false)
                ColorPicker(String(localized: "Color personalizado",
                                   comment: "Ajustes: selector de un color libre para la app"),
                            selection: bindingLibre, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(1.45)
                    .accessibilityHint(String(localized: "Elegí cualquier color y después tocá Usar este color",
                                              comment: "Ajustes: cómo se usa el color personalizado"))
            }
            .frame(width: TokensEspaciado.e52, height: TokensEspaciado.e52)
            nombre(String(localized: "Personalizado", comment: "Ajustes: el color libre"),
                   elegido: libreElegido)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private func nombre(_ texto: String, elegido: Bool) -> some View {
        Text(texto)
            .estilo(.notaLegal, color: elegido ? Paleta.textoPrimario : Paleta.textoSecundario)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var bindingLibre: Binding<Color> {
        Binding(
            get: { colorLibre },
            set: { nuevo in
                colorLibre = nuevo
                guard let guardado = AcentoPersonalizado.guardado(de: nuevo) else { return }
                librePendiente = guardado == acentoGuardado ? nil : guardado
            })
    }

    // MARK: Confirmar el color libre

    private func confirmacion(_ guardado: String) -> some View {
        let c = AcentoPersonalizado.componentesOPredeterminado(de: guardado)
        let encima = AcentoPersonalizado.textoOscuroEncima(c.0, c.1, c.2)
            ? TokensColor.marcaSobreAcento : Color.white
        return HStack(spacing: TokensEspaciado.e10) {
            Button {
                Haptico.toque()
                librePendiente = nil
                colorLibre = AcentoPersonalizado.color(paraGuardado: acentoGuardado)
            } label: {
                Text(String(localized: "Descartar", comment: "Ajustes: no usar el color elegido"))
                    .estilo(.tituloCard, color: Paleta.textoSecundario)
                    .padding(.horizontal, TokensEspaciado.e14)
                    .objetivoTactil()
            }
            .buttonStyle(EstiloPresionado())

            Button {
                aplicar(guardado)
            } label: {
                Text(String(localized: "Usar este color", comment: "Ajustes: aplicar el color elegido"))
                    .estilo(.botonPrimario, color: encima)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: TokensTamano.botonPrimario)
                    .background(Capsule().fill(AcentoPersonalizado.color(paraGuardado: guardado)))
                    .contentShape(Capsule())
            }
            .buttonStyle(EstiloPresionado())
        }
    }

    private var botonRestablecer: some View {
        Button {
            Haptico.toque()
            guardar("")
        } label: {
            Label {
                Text(String(localized: "Restablecer color de Stamina",
                            comment: "Ajustes: volver al color de fábrica"))
                    .estilo(.tituloCard, color: Paleta.textoAcento)
            } icon: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(maxWidth: .infinity)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
    }

    // MARK: Acciones

    private func elegir(_ opcion: OpcionDeAcento) {
        let valor = AcentoPersonalizado.valorAGuardar(para: opcion)
        librePendiente = nil
        guard valor != acentoGuardado else {
            // Ya era este: sólo se descarta el libre que estuviera a prueba.
            colorLibre = AcentoPersonalizado.color(paraGuardado: acentoGuardado)
            return
        }
        Haptico.seleccion()
        guardar(valor)
    }

    private func aplicar(_ guardado: String) {
        Haptico.exito()
        librePendiente = nil
        guardar(guardado)
    }

    /// Lo último que pasa antes de que el Home se re-cree: recordar volver acá.
    private func guardar(_ valor: String) {
        AjustesAncla.alVolver = AjustesAncla.color
        acentoGuardado = valor
    }
}

// MARK: - Un círculo de color

struct AjustesCirculoDeColor: View {
    let color: Color
    let elegido: Bool
    /// Si el tilde va en casi-negro (colores claros) o en blanco.
    let tildeOscuro: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(elegido ? Paleta.textoPrimario : Color.clear, lineWidth: TokensEspaciado.e2)
            Circle()
                .fill(color)
                .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
                .overlay(Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
            if elegido {
                Image(systemName: "checkmark")
                    .font(.system(size: TokensTipografia.valorFilaTamano, weight: .heavy))
                    .foregroundStyle(tildeOscuro ? TokensColor.marcaSobreAcento : Color.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: TokensEspaciado.e52, height: TokensEspaciado.e52)
        .accessibilityHidden(true)
    }
}

// MARK: - La vista previa en vivo

/// Una pantallita con las piezas que llevan el color: la píldora, una barra de
/// progreso, el botón primario y el rayo de la barra. Todo armado con el color
/// candidato, así se ve el resultado ANTES de aplicarlo.
struct AjustesVistaPreviaDeColor: View {
    let componentes: (Double, Double, Double)
    /// `true` mientras el color libre no se aplicó.
    let sinAplicar: Bool

    private var color: Color {
        Color(.sRGB, red: componentes.0, green: componentes.1, blue: componentes.2, opacity: 1)
    }

    private var textoOscuro: Bool {
        AcentoPersonalizado.textoOscuroEncima(componentes.0, componentes.1, componentes.2)
    }

    private var encima: Color { textoOscuro ? TokensColor.marcaSobreAcento : Color.white }

    private var seLeePoco: Bool {
        AcentoPersonalizado.contrasteSobreNegro(componentes.0, componentes.1, componentes.2) < 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            Text(sinAplicar
                 ? String(localized: "Vista previa · todavía sin aplicar", comment: "Ajustes: rótulo de la vista previa")
                 : String(localized: "Así se ve", comment: "Ajustes: rótulo de la vista previa"))
                .estilo(.etiquetaSeccion, color: sinAplicar ? Paleta.textoSecundario : Paleta.textoTerciario)

            pantalla
                .accessibilityHidden(true)

            nota(simbolo: "textformat",
                 texto: textoOscuro
                    ? String(localized: "Encima de este color el texto va en negro, que se lee mejor.",
                             comment: "Ajustes: contraste del texto sobre el color elegido")
                    : String(localized: "Encima de este color el texto va en blanco, que se lee mejor.",
                             comment: "Ajustes: contraste del texto sobre el color elegido"),
                 colorDelIcono: Paleta.textoTerciario)

            if seLeePoco {
                nota(simbolo: "exclamationmark.triangle.fill",
                     texto: String(localized: "Este color se lee poco sobre fondo oscuro. Probá uno más claro.",
                                   comment: "Ajustes: aviso de bajo contraste del color elegido"),
                     colorDelIcono: Paleta.error)
            }
        }
    }

    private var pantalla: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            HStack(spacing: TokensEspaciado.e8) {
                pildora
                Spacer(minLength: 0)
                Text(String(localized: "Hoy", comment: "Ajustes: ejemplo en la vista previa"))
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
            }

            VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "Tu semana", comment: "Ajustes: ejemplo en la vista previa"))
                        .estilo(.tituloCardGrande)
                    Spacer(minLength: 0)
                    Text(verbatim: "3/5")
                        .estilo(.tituloCard, color: color)
                }
                barraDeProgreso
            }

            HStack(spacing: TokensEspaciado.e12) {
                Text(String(localized: "Empezar", comment: "Ajustes: ejemplo de botón en la vista previa"))
                    .estilo(.botonPrimario, color: encima)
                    .frame(maxWidth: .infinity)
                    .frame(height: TokensEspaciado.e40)
                    .background(Capsule().fill(color))
                    .shadow(color: color.opacity(0.45), radius: TokensEspaciado.e8)
                rayo
            }
        }
        .padding(TokensEspaciado.e14)
        .background(Paleta.fondo)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
    }

    private var pildora: some View {
        HStack(spacing: TokensEspaciado.e5) {
            Circle()
                .fill(color)
                .frame(width: TokensEspaciado.e6, height: TokensEspaciado.e6)
            Text(String(localized: "En curso", comment: "Ajustes: ejemplo de píldora en la vista previa"))
                .estilo(.chip, color: Paleta.textoPrimario)
        }
        .padding(.horizontal, TokensEspaciado.e10)
        .padding(.vertical, TokensEspaciado.e6)
        .background(Capsule().fill(color.opacity(TokensAcento.alfaChipActivo)))
        .overlay(Capsule().strokeBorder(color.opacity(TokensAcento.alfaSuaveBorde), lineWidth: TokensEspaciado.e1))
    }

    private var barraDeProgreso: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Paleta.superficieHundida)
                Capsule().fill(color).frame(width: geo.size.width * 0.6)
            }
        }
        .frame(height: TokensEspaciado.e6)
    }

    private var rayo: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: TokensTipografia.valorDatoTamano, weight: .bold))
            .foregroundStyle(encima)
            .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e44)
            .background(Circle().fill(color))
            .shadow(color: color.opacity(0.45), radius: TokensEspaciado.e8)
    }

    private func nota(simbolo: String, texto: String, colorDelIcono: Color) -> some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            Image(systemName: simbolo)
                .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                .foregroundStyle(colorDelIcono)
                .padding(.top, TokensEspaciado.e1)
                .accessibilityHidden(true)
            Text(texto)
                .estilo(.notaLegal, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
