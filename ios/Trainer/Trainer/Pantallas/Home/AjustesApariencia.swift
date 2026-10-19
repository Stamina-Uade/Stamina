import SwiftUI
import TrainerCore

// =============================================================================
// Ajustes → Aspecto: la página, y el modo con tres teléfonos en miniatura.
//
// Cada miniatura se dibuja con la Paleta de VERDAD: el mismo `Paleta.fondo`,
// `superficie` y `acento` de la app, resueltos en claro o en oscuro con
// `.environment(\.colorScheme, …)`. Si mañana cambia un color, la miniatura
// cambia sola. "Automático" es la mitad de cada una, cortada en diagonal.
// =============================================================================

/// La página Aspecto: el modo y el color de la app, sin más.
struct AjustesPaginaAspecto: View {
    @Binding var modo: ModoApariencia
    /// Al volver de aplicar un color, el scroll arranca en el bloque de color.
    let ancla: String?
    let volver: () -> Void

    var body: some View {
        AjustesPagina(Textos.settingsAppearanceTitle,
                      ancla: ancla, volver: volver) {
            AjustesSelectorDeModo(modo: $modo)

            AjustesRotulo(Textos.settingsAppearanceColor)
                .padding(.top, TokensEspaciado.e8)
                .id(AjustesAncla.color)
            AjustesSelectorDeColor()
        }
    }
}

extension ModoApariencia {
    /// "Automático", "Claro", "Oscuro": lo que se ve en Ajustes.
    var nombreCorto: String {
        switch self {
        case .automatico: return Textos.settingsAppearanceAutomatic
        case .claro: return Textos.settingsAppearanceLight
        case .oscuro: return Textos.settingsAppearanceDark
        }
    }
}

struct AjustesSelectorDeModo: View {
    @Binding var modo: ModoApariencia
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e12) {
            ForEach(ModoApariencia.allCases) { opcion in
                boton(opcion)
            }
        }
        .padding(.top, TokensEspaciado.e4)
    }

    private func boton(_ opcion: ModoApariencia) -> some View {
        let elegido = opcion == modo
        return Button {
            elegir(opcion)
        } label: {
            VStack(spacing: TokensEspaciado.e8) {
                AjustesMiniTelefono(modo: opcion)
                    .padding(TokensEspaciado.e4)
                    .overlay(
                        RoundedRectangle(cornerRadius: TokensRadio.boton + TokensEspaciado.e4, style: .continuous)
                            .strokeBorder(elegido ? Paleta.acento : Paleta.bordeSuperficie,
                                          lineWidth: elegido ? TokensEspaciado.e2 : TokensEspaciado.e1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if elegido {
                            marcaDeElegido
                                .offset(x: TokensEspaciado.e6, y: -TokensEspaciado.e6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                HStack(spacing: TokensEspaciado.e4) {
                    Image(systemName: icono(de: opcion))
                        .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                        .foregroundStyle(elegido ? Paleta.acento : Paleta.textoSecundario)
                    Text(opcion.nombreCorto)
                        .estilo(.tituloCard, color: elegido ? Paleta.textoAcento : Paleta.textoPrimario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(opcion.nombreCorto)
        .accessibilityHint(descripcion(de: opcion))
        .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
    }

    /// El tilde en el círculo del color de la app.
    private var marcaDeElegido: some View {
        Image(systemName: "checkmark")
            .font(.system(size: TokensTipografia.notaTamano, weight: .heavy))
            .foregroundStyle(Paleta.sobreAcento)
            .frame(width: TokensEspaciado.e22, height: TokensEspaciado.e22)
            .background(Circle().fill(Paleta.acento))
            .overlay(Circle().strokeBorder(Paleta.fondo, lineWidth: TokensEspaciado.e2))
            .accessibilityHidden(true)
    }

    private func elegir(_ opcion: ModoApariencia) {
        guard opcion != modo else { return }
        Haptico.seleccion()
        withAnimation(reducirMovimiento ? nil : .easeInOut(duration: TokensMovimiento.rapida)) {
            modo = opcion
        }
    }

    private func icono(de modo: ModoApariencia) -> String {
        switch modo {
        case .automatico: return "circle.lefthalf.filled"
        case .claro: return "sun.max.fill"
        case .oscuro: return "moon.fill"
        }
    }

    /// Sólo para VoiceOver: en pantalla, la miniatura ya lo dice.
    private func descripcion(de modo: ModoApariencia) -> String {
        switch modo {
        case .automatico:
            return Textos.settingsAppearanceAutomaticDetail
        case .claro:
            return Textos.settingsAppearanceLightDetail
        case .oscuro:
            return Textos.settingsAppearanceDarkDetail
        }
    }
}

// MARK: - La miniatura

/// Un teléfono chiquito: encabezado, una tarjeta, el botón y la barra.
struct AjustesMiniTelefono: View {
    let modo: ModoApariencia

    var body: some View {
        Group {
            switch modo {
            case .claro:
                AjustesMiniPantalla()
                    .environment(\.colorScheme, .light)
            case .oscuro:
                AjustesMiniPantalla()
                    .environment(\.colorScheme, .dark)
            case .automatico:
                ZStack {
                    AjustesMiniPantalla()
                        .environment(\.colorScheme, .light)
                    AjustesMiniPantalla()
                        .environment(\.colorScheme, .dark)
                        .mask { AjustesMitadDiagonal() }
                }
            }
        }
        .aspectRatio(0.6, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// El contenido de la miniatura. Usa la Paleta: el esquema lo pone quien la usa.
struct AjustesMiniPantalla: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e5) {
            // La isla de arriba.
            Capsule()
                .fill(Paleta.textoPrimario)
                .frame(width: TokensEspaciado.e14, height: TokensEspaciado.e4)
                .frame(maxWidth: .infinity)

            // El encabezado: un título pesado y el avatar.
            HStack(spacing: TokensEspaciado.e4) {
                Capsule()
                    .fill(Paleta.textoPrimario)
                    .frame(width: TokensEspaciado.e26, height: TokensEspaciado.e5)
                Spacer(minLength: 0)
                Circle()
                    .fill(Paleta.superficieAlterna)
                    .frame(width: TokensEspaciado.e8, height: TokensEspaciado.e8)
            }
            .padding(.top, TokensEspaciado.e2)

            // Una tarjeta con dos renglones y un dato en el color de la app.
            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                Capsule()
                    .fill(Paleta.textoSecundario)
                    .frame(width: TokensEspaciado.e20, height: TokensEspaciado.e3)
                Capsule()
                    .fill(Paleta.textoTerciario)
                    .frame(height: TokensEspaciado.e3)
                Capsule()
                    .fill(Paleta.acento)
                    .frame(width: TokensEspaciado.e16, height: TokensEspaciado.e4)
            }
            .padding(TokensEspaciado.e5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensEspaciado.e5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensEspaciado.e5, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )

            // Otra tarjeta, más baja.
            RoundedRectangle(cornerRadius: TokensEspaciado.e5, style: .continuous)
                .fill(Paleta.superficie)
                .frame(height: TokensEspaciado.e12)

            Spacer(minLength: 0)

            // El botón primario, cápsula del color de la app.
            Capsule()
                .fill(Paleta.acento)
                .frame(height: TokensEspaciado.e9)

            // La barra con el rayo en el medio.
            HStack(spacing: 0) {
                puntoDeBarra
                Spacer(minLength: 0)
                puntoDeBarra
                Spacer(minLength: 0)
                Circle()
                    .fill(Paleta.acento)
                    .frame(width: TokensEspaciado.e10, height: TokensEspaciado.e10)
                Spacer(minLength: 0)
                puntoDeBarra
                Spacer(minLength: 0)
                puntoDeBarra
            }
            .padding(.horizontal, TokensEspaciado.e2)
        }
        .padding(TokensEspaciado.e7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Paleta.fondo)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(Paleta.bordeInput, lineWidth: TokensEspaciado.e1)
        )
    }

    private var puntoDeBarra: some View {
        Circle()
            .fill(Paleta.pestanaInactiva)
            .frame(width: TokensEspaciado.e4, height: TokensEspaciado.e4)
    }
}

/// La mitad de abajo a la derecha de un rectángulo, cortada en diagonal.
struct AjustesMitadDiagonal: Shape {
    func path(in rect: CGRect) -> Path {
        var camino = Path()
        camino.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        camino.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        camino.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        camino.closeSubpath()
        return camino
    }
}
