import SwiftUI
import UniformTypeIdentifiers
import TrainerCore

/// "Tu apto físico" — la pantalla 1 del mockup del MVP. Se abre como hoja desde
/// la píldora del inicio y desde Perfil.
///
/// Archivo (PDF o foto) + fecha de vencimiento + declaración jurada. Lo guarda
/// `AlmacenDeAptoFisico`, sólo en el teléfono.
struct AptoFisicoView: View {
    @ObservedObject private var almacen = AlmacenDeAptoFisico.compartido
    @Environment(\.dismiss) private var cerrar

    @State private var archivoElegido: URL?
    @State private var vence: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var declaracion = false
    @State private var eligiendoArchivo = false
    @State private var error: String?

    /// Lo que hace falta para confirmar: un archivo (nuevo o el que ya estaba),
    /// una fecha futura y la casilla.
    private var puedeConfirmar: Bool {
        (archivoElegido != nil || almacen.apto != nil) && declaracion && vence > Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                    HStack {
                        FlechaVolver { cerrar() }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                        Text(String(localized: "Tu apto físico", comment: "Título de la pantalla del apto"))
                            .estilo(.display)
                            .accessibilityAddTraits(.isHeader)
                        Text(String(localized: "Con un apto vigente, Stamina puede darte sugerencias en carrera.",
                                    comment: "Explicación del apto físico"))
                            .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    tarjetaDelArchivo

                    VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                        HStack {
                            Text(String(localized: "Vencimiento", comment: "Etiqueta de la fecha del apto"))
                                .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                            Spacer()
                            Text(String(localized: "Vence el \(vence.formatted(.dateTime.day().month(.abbreviated).year()))",
                                        comment: "Fecha de vencimiento elegida"))
                                .estilo(.labelCampo, color: Paleta.acento)
                        }
                        DatePicker("", selection: $vence,
                                   in: Date()...,
                                   displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TokensEspaciado.e4)
                            .tarjeta()
                            .accessibilityLabel(String(localized: "Fecha de vencimiento", comment: "VoiceOver"))

                        PildoraDeEstado(String(localized: "Vigente · te avisamos 30 días antes",
                                               comment: "Promesa de aviso antes del vencimiento"),
                                        simbolo: "checkmark", tono: .acento)
                    }

                    VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                        Casilla(texto: String(localized: "Declaro que mis datos de salud son verdaderos",
                                              comment: "Declaración jurada del apto"),
                                marcada: $declaracion)
                        Text(String(localized: "Declaración jurada", comment: "Aclaración de la casilla"))
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                            .padding(.leading, TokensEspaciado.e36)
                    }

                    if let error {
                        Text(error)
                            .estilo(.cuerpoSecundario, color: Paleta.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if almacen.apto != nil {
                        BotonTexto(String(localized: "Borrar apto guardado", comment: "Acción del apto"),
                                   color: Paleta.error) {
                            almacen.borrar()
                            archivoElegido = nil
                            declaracion = false
                        }
                    }
                }
                .padding(.horizontal, TokensEspaciado.e22)
                .padding(.top, TokensEspaciado.e12)
                .padding(.bottom, TokensEspaciado.e20)
            }

            VStack(spacing: TokensEspaciado.e10) {
                BotonPrimario(String(localized: "Confirmar", comment: "Confirma el apto"),
                              habilitado: puedeConfirmar,
                              motivoDeshabilitado: String(localized: "Elegí el archivo, la fecha y marcá la declaración.",
                                                          comment: "VoiceOver: por qué no se puede confirmar")) {
                    confirmar()
                }
                Text(String(localized: "Stamina no reemplaza la consulta médica. Tu apto se guarda sólo en este teléfono, protegido, y no se comparte con nadie.",
                            comment: "Nota legal del apto"))
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TokensEspaciado.e22)
            .padding(.bottom, TokensEspaciado.e12)
        }
        .background(Paleta.fondo.ignoresSafeArea())
        .fileImporter(isPresented: $eligiendoArchivo,
                      allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: false) { resultado in
            switch resultado {
            case .success(let urls):
                archivoElegido = urls.first
                error = nil
            case .failure:
                error = String(localized: "No pudimos abrir ese archivo. Probá con otro.", comment: "Error del apto")
            }
        }
        .onAppear {
            if let apto = almacen.apto {
                vence = apto.vence
                declaracion = apto.declaracionAceptada
            }
        }
    }

    // MARK: - El archivo

    private var tarjetaDelArchivo: some View {
        Button { eligiendoArchivo = true } label: {
            HStack(spacing: TokensEspaciado.e12) {
                ZStack {
                    RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous)
                        .fill(Paleta.superficieAlterna)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: TokensTipografia.tituloCardGrandeTamano, weight: .bold))
                        .foregroundStyle(Paleta.textoPrimario)
                }
                .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                    Text(nombreDelArchivo)
                        .estilo(.opcionTitulo)
                        .lineLimit(1)
                    Text(detalleDelArchivo)
                        .estilo(.notaLegal, color: Paleta.textoSecundario)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                if tieneArchivo {
                    ZStack {
                        Circle().fill(Paleta.acento)
                        Image(systemName: "checkmark")
                            .font(.system(size: TokensTipografia.notaLegalTamano, weight: .heavy))
                            .foregroundStyle(Paleta.sobreAcento)
                    }
                    .frame(width: TokensEspaciado.e26, height: TokensEspaciado.e26)
                    .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e8)
                    .accessibilityHidden(true)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: TokensEspaciado.e22, weight: .semibold))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                }
            }
            .padding(TokensEspaciado.e14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjeta()
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(tieneArchivo ? Paleta.acentoSuaveBorde : Color.clear, lineWidth: TokensEspaciado.e1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(tieneArchivo
            ? String(localized: "Archivo del apto: \(nombreDelArchivo). Tocá para cambiarlo.", comment: "VoiceOver")
            : String(localized: "Subir el apto, foto o PDF", comment: "VoiceOver"))
    }

    private var tieneArchivo: Bool { archivoElegido != nil || almacen.apto != nil }

    private var nombreDelArchivo: String {
        if let archivoElegido { return archivoElegido.lastPathComponent }
        if let apto = almacen.apto { return apto.nombreOriginal }
        return String(localized: "Subir foto o PDF", comment: "Tarjeta del archivo vacía")
    }

    private var detalleDelArchivo: String {
        if archivoElegido != nil {
            return String(localized: "Listo para guardar", comment: "Archivo elegido y sin guardar")
        }
        if let apto = almacen.apto {
            let tamano = ByteCountFormatter.string(fromByteCount: apto.bytes, countStyle: .file)
            let fecha = Date(timeIntervalSince1970: TimeInterval(apto.subidoMs) / 1000)
                .formatted(date: .abbreviated, time: .omitted)
            return "\(tamano) · \(fecha)"
        }
        return String(localized: "El certificado que te dio tu médico", comment: "Ayuda de la tarjeta del archivo")
    }

    // MARK: - Confirmar

    private func confirmar() {
        if let archivoElegido {
            switch almacen.guardar(desde: archivoElegido, vence: vence, declaracionAceptada: declaracion) {
            case .success:
                cerrar()
            case .failure(.muyGrande):
                error = String(localized: "El archivo pesa más de 15 MB. Probá con una foto más liviana.", comment: "Error del apto")
            case .failure:
                error = String(localized: "No pudimos guardar el apto. Probá de nuevo.", comment: "Error del apto")
            }
        } else if almacen.actualizarVencimiento(vence, declaracionAceptada: declaracion) {
            cerrar()
        } else {
            error = String(localized: "No pudimos guardar el apto. Probá de nuevo.", comment: "Error del apto")
        }
    }
}

// MARK: - La píldora del inicio

/// "Apto vigente · vence en 45 días". Tocarla abre la pantalla del apto.
struct PildoraDelApto: View {
    @ObservedObject private var almacen = AlmacenDeAptoFisico.compartido
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            switch almacen.estado {
            case .sinCargar:
                PildoraDeEstado(String(localized: "Cargá tu apto físico", comment: "Píldora del inicio sin apto"),
                                simbolo: "plus", tono: .neutro)
            case .vigente(let dias):
                PildoraDeEstado(String(localized: "Apto vigente · vence en \(dias) días", comment: "Píldora del inicio"),
                                simbolo: "checkmark.shield", tono: .acento)
            case .porVencer(let dias):
                PildoraDeEstado(dias == 0
                                ? String(localized: "Tu apto vence hoy", comment: "Píldora del inicio")
                                : String(localized: "Tu apto vence en \(dias) días", comment: "Píldora del inicio"),
                                simbolo: "exclamationmark.shield", tono: .alerta)
            case .vencido:
                PildoraDeEstado(String(localized: "Apto vencido · renovalo", comment: "Píldora del inicio"),
                                simbolo: "xmark.shield", tono: .alerta)
            }
        }
        .buttonStyle(EstiloPresionado())
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
    }
}
