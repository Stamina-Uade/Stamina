import SwiftUI
import UniformTypeIdentifiers
import TrainerCore

/// "Tu apto físico" — la pantalla 1 del mockup del MVP. Se abre como hoja desde
/// la píldora del inicio y desde Perfil.
///
/// Archivo (PDF o foto) + fecha de vencimiento + declaración jurada. Lo guarda
/// `AlmacenDeAptoFisico`, sólo en el teléfono.
///
/// 2026-10-22: también es el último paso del alta (`RegAptoView`). Ahí no lleva
/// su cabecera —la flecha y la barra son de `RaizFlujoView`—, el texto cuenta
/// para qué sirve, y abajo van "Guardar" y "Lo subo después".
struct AptoFisicoView: View {
    @ObservedObject private var almacen = AlmacenDeAptoFisico.compartido
    @Environment(\.dismiss) private var cerrar

    /// Es el paso del alta y no la hoja de Perfil.
    private let enElAlta: Bool
    /// Lo que pasa al guardar o al dejarlo para después, en el alta.
    private let alTerminar: () -> Void

    init(enElAlta: Bool = false, alTerminar: @escaping () -> Void = {}) {
        self.enElAlta = enElAlta
        self.alTerminar = alTerminar
    }

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

    /// Termina: en el alta sigue al Inicio; en Perfil cierra la hoja.
    private func terminar() {
        if enElAlta { alTerminar() } else { cerrar() }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !enElAlta {
                // Flecha y título fijos arriba, como una barra de navegación.
                CabeceraSecundaria(titulo: Textos.medicalYourClearance) {
                    cerrar()
                }
                .padding(.top, TokensEspaciado.e12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                    if enElAlta {
                        Text(Textos.medicalYourClearance)
                            .estilo(.display)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Text(enElAlta ? Textos.signupMedicalBody : Textos.medicalAddBody)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)

                    tarjetaDelArchivo

                    VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                        HStack {
                            Text(Textos.medicalExpiration)
                                .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                            Spacer()
                            Text(Textos.medicalExpiresOn(vence.formatted(.dateTime.day().month(.abbreviated).year())))
                                .estilo(.labelCampo, color: Paleta.acento)
                        }
                        DatePicker(String(), selection: $vence,
                                   in: Date()...,
                                   displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TokensEspaciado.e4)
                            .tarjeta()
                            .accessibilityLabel(Textos.medicalExpirationDate)

                        PildoraDeEstado(Textos.medicalValidReminder,
                                        simbolo: "checkmark", tono: .acento)
                    }

                    VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                        Casilla(texto: Textos.medicalSwornStatementDeclare,
                                marcada: $declaracion)
                        Text(Textos.medicalSwornStatement)
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                            .padding(.leading, TokensEspaciado.e36)
                    }

                    if let error {
                        Text(error)
                            .estilo(.cuerpoSecundario, color: Paleta.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if almacen.apto != nil {
                        BotonTexto(Textos.medicalDelete,
                                   color: Paleta.peligro) {
                            almacen.borrar()
                            archivoElegido = nil
                            declaracion = false
                        }
                    }
                }
                .padding(.horizontal, TokensEspaciado.e22)
                .padding(.top, TokensEspaciado.e8)
                .padding(.bottom, TokensEspaciado.e20)
            }

            VStack(spacing: TokensEspaciado.e10) {
                BotonPrimario(enElAlta ? Textos.commonSave : Textos.commonConfirm,
                              habilitado: puedeConfirmar,
                              motivoDeshabilitado: Textos.medicalFormIncomplete) {
                    confirmar()
                }
                if enElAlta {
                    BotonTexto(Textos.signupMedicalLater, color: Paleta.textoSecundario) { alTerminar() }
                }
                Text(Textos.medicalDisclaimer)
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
                error = Textos.medicalErrorOpenFailed
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
            ? Textos.medicalFileAccessibility(nombreDelArchivo)
            : Textos.medicalUploadAccessibility)
    }

    private var tieneArchivo: Bool { archivoElegido != nil || almacen.apto != nil }

    private var nombreDelArchivo: String {
        if let archivoElegido { return archivoElegido.lastPathComponent }
        if let apto = almacen.apto { return apto.nombreOriginal }
        return Textos.medicalUpload
    }

    private var detalleDelArchivo: String {
        if archivoElegido != nil {
            return Textos.medicalReadyToSave
        }
        if let apto = almacen.apto {
            let tamano = ByteCountFormatter.string(fromByteCount: apto.bytes, countStyle: .file)
            let fecha = Date(timeIntervalSince1970: TimeInterval(apto.subidoMs) / 1000)
                .formatted(date: .abbreviated, time: .omitted)
            return "\(tamano) · \(fecha)"
        }
        return Textos.medicalCertificateDetail
    }

    // MARK: - Confirmar

    private func confirmar() {
        if let archivoElegido {
            switch almacen.guardar(desde: archivoElegido, vence: vence, declaracionAceptada: declaracion) {
            case .success:
                terminar()
            case .failure(.muyGrande):
                error = Textos.medicalErrorTooLarge
            case .failure:
                error = Textos.medicalErrorSaveFailed
            }
        } else if almacen.actualizarVencimiento(vence, declaracionAceptada: declaracion) {
            terminar()
        } else {
            error = Textos.medicalErrorSaveFailed
        }
    }
}
