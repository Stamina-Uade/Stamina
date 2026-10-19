import SwiftUI
import TrainerCore

// =============================================================================
// Peso, altura y edad: para qué los usa la app y cómo se actualizan.
//
// Ronda 3 (pedido de Ivan: "no entiendo qué hace cada cosa"): cada tarjeta del
// cuerpo se toca y abre esta hoja, que explica el dato sin jerga. Editar un dato
// ya cargado no existe todavía en la app: sólo se puede completar uno que falta,
// con los mismos pasos del alta (`FlujoEntrada.retomarPerfil()`). La hoja lo
// dice así, sin prometer una edición que no hay.
// =============================================================================

/// Uno de los tres datos del cuerpo que muestra el perfil.
enum DatoDelCuerpo: String, Identifiable, CaseIterable {
    case peso, altura, edad

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .peso: return Textos.perfilPeso
        case .altura: return Textos.perfilAltura
        case .edad: return Textos.perfilEdad
        }
    }

    var simbolo: String {
        switch self {
        case .peso: return "scalemass"
        case .altura: return "ruler"
        case .edad: return "calendar"
        }
    }

    /// Para qué lo usa la app, en frases cortas.
    var usos: [PuntoDeGuia] {
        switch self {
        case .peso:
            return [
                PuntoDeGuia("flame", String(localized: "Calcula las calorías que gastás en cada entrenamiento.",
                                             comment: "Para qué se usa el peso")),
                PuntoDeGuia("drop", String(localized: "Ajusta la hidratación: cuánta agua tomar en las salidas largas.",
                                            comment: "Para qué se usa el peso")),
            ]
        case .altura:
            return [
                PuntoDeGuia("figure.stand", String(localized: "Junto con el peso, afina la estimación de la energía que gastás.",
                                                    comment: "Para qué se usa la altura")),
            ]
        case .edad:
            return [
                PuntoDeGuia("heart", String(localized: "Estima tu pulso máximo y, con él, tus zonas de pulso.",
                                             comment: "Para qué se usa la edad")),
                PuntoDeGuia("waveform.path.ecg", String(localized: "Las zonas ordenan la intensidad: la zona 2 (Z2) es un ritmo suave, en el que todavía podés charlar.",
                                                         comment: "Explica qué es la zona 2")),
            ]
        }
    }
}

/// La hoja que se abre al tocar peso, altura o edad.
struct DetalleDeDatoDelCuerpo: View {
    let dato: DatoDelCuerpo
    let valor: String
    /// `true` si el dato todavía no está cargado: entonces se ofrece completarlo.
    let falta: Bool
    let alCompletar: () -> Void

    @Environment(\.dismiss) private var cerrar

    init(dato: DatoDelCuerpo, valor: String, falta: Bool, alCompletar: @escaping () -> Void) {
        self.dato = dato
        self.valor = valor
        self.falta = falta
        self.alCompletar = alCompletar
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                cabecera
                seccionUsos
                seccionComoActualizar
            }
            .padding(.horizontal, TokensEspaciado.e20)
            .padding(.top, TokensEspaciado.e20)
            .padding(.bottom, TokensEspaciado.e20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var cabecera: some View {
        HStack(spacing: TokensEspaciado.e12) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                Image(systemName: dato.simbolo)
                    .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(dato.titulo)
                    .estilo(.labelCampo, color: Paleta.textoSecundario)
                Text(valor)
                    .estilo(.metricaMedia)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            BotonCircular("xmark", etiqueta: Textos.comunListo) {
                Haptico.toque()
                cerrar()
            }
        }
    }

    private var seccionUsos: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            Text(String(localized: "Para qué lo usamos", comment: "Título en la hoja de un dato del cuerpo"))
                .estilo(.tituloSeccion)
                .accessibilityAddTraits(.isHeader)
            ForEach(dato.usos) { uso in
                HStack(alignment: .top, spacing: TokensEspaciado.e10) {
                    Image(systemName: uso.simbolo)
                        .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                        .foregroundStyle(Paleta.acento)
                        .frame(width: TokensEspaciado.e20)
                        .padding(.top, TokensEspaciado.e2)
                        .accessibilityHidden(true)
                    Text(uso.texto)
                        .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    private var seccionComoActualizar: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            Text(String(localized: "Cómo actualizarlo", comment: "Título en la hoja de un dato del cuerpo"))
                .estilo(.tituloSeccion)
                .accessibilityAddTraits(.isHeader)
            if falta {
                Text(String(localized: "Todavía no lo cargaste. Completalo con los mismos pasos del registro.",
                            comment: "Dato del cuerpo que falta"))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                BotonPrimario(String(localized: "Completar ahora", comment: "Botón para completar el perfil")) {
                    Haptico.toque()
                    alCompletar()
                }
            } else {
                Text(String(localized: "Lo cargaste al registrarte. Por ahora no se puede cambiar desde la app.",
                            comment: "Dato del cuerpo ya cargado, sin edición"))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
