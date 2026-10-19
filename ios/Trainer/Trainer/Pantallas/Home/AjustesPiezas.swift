import SwiftUI
import TrainerCore

// =============================================================================
// Las piezas con las que se arma Ajustes (rediseño 2026-10, ronda 3).
//
// Pedido de Ivan: "entro y no entiendo qué hace cada cosa". Cada ajuste lleva su
// ícono, su título y UNA frase que dice qué pasa si lo tocás.
// =============================================================================

/// El tono del cuadradito del ícono. El color nunca va solo: siempre hay texto.
enum AjustesTono {
    case acento, neutro, alerta
}

/// El rótulo chico en mayúsculas que separa los grupos ("APARIENCIA", "AVISOS").
struct AjustesRotulo: View {
    private let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto)
            .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, TokensEspaciado.e4)
            .padding(.top, TokensEspaciado.e10)
            .accessibilityAddTraits(.isHeader)
    }
}

/// El ícono de un ajuste, en su cuadradito tonal.
struct AjustesIcono: View {
    let simbolo: String
    var tono: AjustesTono = .acento

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: TokensTipografia.valorFilaTamano, weight: .semibold))
            .foregroundStyle(colorDelIcono)
            .frame(width: TokensEspaciado.e34, height: TokensEspaciado.e34)
            .background(fondo)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous))
            .accessibilityHidden(true)
    }

    private var colorDelIcono: Color {
        switch tono {
        case .acento: return Paleta.acento
        case .neutro: return Paleta.textoSecundario
        case .alerta: return Paleta.error
        }
    }

    private var fondo: Color {
        switch tono {
        case .acento: return Paleta.acentoChipActivo
        case .neutro: return Paleta.superficieHundida
        case .alerta: return Paleta.errorFondo
        }
    }
}

/// Ícono + título + la frase que explica qué hace. Arriba de cada tarjeta.
struct AjustesEncabezado: View {
    let simbolo: String
    let titulo: String
    let explicacion: String
    var tono: AjustesTono = .acento
    /// Un dato al costado ("2 activos"), en píldora.
    var detalle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e12) {
            AjustesIcono(simbolo: simbolo, tono: tono)
            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(titulo)
                    .estilo(.tituloCardGrande)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(explicacion)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let detalle {
                PildoraDeEstado(detalle)
            }
        }
    }
}

/// Una tarjeta de Ajustes: encabezado explicado y, abajo, sus controles.
struct AjustesGrupo<Contenido: View>: View {
    private let titulo: String
    private let simbolo: String
    private let explicacion: String
    private let tono: AjustesTono
    private let detalle: String?
    private let contenido: Contenido

    init(_ titulo: String, simbolo: String, explicacion: String,
         tono: AjustesTono = .acento, detalle: String? = nil,
         @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.simbolo = simbolo
        self.explicacion = explicacion
        self.tono = tono
        self.detalle = detalle
        self.contenido = contenido()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
            AjustesEncabezado(simbolo: simbolo, titulo: titulo, explicacion: explicacion,
                              tono: tono, detalle: detalle)
            contenido
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(radio: TokensRadio.card)
    }
}

/// Un aviso que se prende y se apaga: ícono, qué es y cuándo llega.
struct AjustesFilaInterruptor: View {
    let simbolo: String
    let titulo: String
    let detalle: String
    @Binding var encendido: Bool

    var body: some View {
        Toggle(isOn: $encendido) {
            HStack(alignment: .top, spacing: TokensEspaciado.e12) {
                AjustesIcono(simbolo: simbolo, tono: encendido ? .acento : .neutro)
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(titulo)
                        .estilo(.tituloCard, color: Paleta.textoPrimario)
                    Text(detalle)
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Paleta.interruptorActivo)
        .objetivoTactilAlto()
        .onChange(of: encendido) { _ in Haptico.seleccion() }
    }
}

/// Una fila que HACE algo al tocarla: ícono, qué hace, y a la derecha la
/// flecha (o el estado, si ya se hizo).
struct AjustesFilaDeAccion: View {
    let simbolo: String
    let titulo: String
    let detalle: String
    var simboloFinal: String = "chevron.right"
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(alignment: .center, spacing: TokensEspaciado.e12) {
                AjustesIcono(simbolo: simbolo)
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(titulo)
                        .estilo(.tituloCard, color: Paleta.textoPrimario)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detalle)
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: simboloFinal)
                    .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                    .foregroundStyle(simboloFinal == "chevron.right" ? Paleta.textoTerciario : Paleta.acento)
                    .accessibilityHidden(true)
            }
            .padding(TokensEspaciado.e14)
            .frame(maxWidth: .infinity)
            .tarjeta(radio: TokensRadio.card)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
