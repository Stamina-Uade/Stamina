import SwiftUI
import TrainerCore

/// "Accesos rápidos": cuatro baldosas con ícono y nombre para ir directo a lo
/// que más se usa. Con letra muy grande pasan a dos columnas para que el nombre
/// entre entero.
struct InicioAccesosRapidos: View {
    @EnvironmentObject private var estado: EstadoHome
    @Environment(\.dynamicTypeSize) private var tamanoDeLetra
    /// El apto se abre como hoja desde el inicio, que es quien la presenta.
    let abrirApto: () -> Void

    private struct Acceso: Identifiable {
        let id: String
        let simbolo: String
        let titulo: String
        let pista: String
        let accion: () -> Void
    }

    private var accesos: [Acceso] {
        [
            Acceso(id: "entreno", simbolo: "bolt.fill",
                   titulo: estado.haySesionEnCurso
                    ? String(localized: "Volver a la salida", comment: "Acceso rápido con una salida en curso")
                    : String(localized: "Empezar salida", comment: "Acceso rápido al entreno"),
                   pista: String(localized: "Abre el entreno con GPS", comment: "VoiceOver del acceso rápido"),
                   accion: { estado.ir(a: .entreno) }),
            Acceso(id: "plan", simbolo: "calendar",
                   titulo: String(localized: "Ver mi plan", comment: "Acceso rápido al plan"),
                   pista: String(localized: "Abre tu plan semana a semana", comment: "VoiceOver del acceso rápido"),
                   accion: { estado.ir(a: .plan) }),
            Acceso(id: "historial", simbolo: "clock.arrow.circlepath",
                   titulo: String(localized: "Historial", comment: "Acceso rápido al historial"),
                   pista: String(localized: "Abre todo lo que hiciste", comment: "VoiceOver del acceso rápido"),
                   accion: { estado.ir(a: .historial) }),
            Acceso(id: "apto", simbolo: "checkmark.shield",
                   titulo: String(localized: "Apto físico", comment: "Acceso rápido al apto físico"),
                   pista: String(localized: "Abre tu apto físico", comment: "VoiceOver del acceso rápido"),
                   accion: abrirApto),
        ]
    }

    private var columnas: [GridItem] {
        let cantidad = tamanoDeLetra >= .xxxLarge ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: TokensEspaciado.e8), count: cantidad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(String(localized: "Accesos rápidos", comment: "Título de sección del inicio"))
            LazyVGrid(columns: columnas, spacing: TokensEspaciado.e8) {
                ForEach(accesos) { acceso in
                    Button {
                        Haptico.toque()
                        acceso.accion()
                    } label: {
                        baldosa(acceso)
                    }
                    .buttonStyle(EstiloPresionado())
                    .accessibilityLabel(acceso.titulo)
                    .accessibilityHint(acceso.pista)
                }
            }
        }
    }

    private func baldosa(_ acceso: Acceso) -> some View {
        VStack(spacing: TokensEspaciado.e6) {
            Image(systemName: acceso.simbolo)
                .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                .foregroundStyle(Paleta.acento)
                .frame(width: TokensEspaciado.e36, height: TokensEspaciado.e36)
                .background(Circle().fill(Paleta.acentoChipActivo))
                .accessibilityHidden(true)
            Text(acceso.titulo)
                .estilo(.chip, color: Paleta.textoPrimario)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, TokensEspaciado.e12)
        .padding(.horizontal, TokensEspaciado.e4)
        .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo)
        .tarjeta(radio: TokensRadio.boton)
        .contentShape(Rectangle())
    }
}
