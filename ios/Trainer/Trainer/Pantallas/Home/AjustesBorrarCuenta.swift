import SwiftUI
import TrainerCore

/// Ajustes → Borrar cuenta. App Store 5.1.1(v): quien creó la cuenta en la app
/// tiene que poder borrarla desde la app, sin mandar un mail ni entrar a una web.
///
/// `POST /me/delete` borra todo en el acto (no hay 30 días de gracia). Por eso
/// hay dos frenos: la contraseña, si la cuenta tiene una (un teléfono
/// desbloqueado no alcanza para borrarle la cuenta a nadie), y una confirmación.
/// Las cuentas de Google o Apple no tienen contraseña: la sesión es la prueba.
struct AjustesPaginaBorrarCuenta: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    let volver: () -> Void

    @State private var clave = ""
    @State private var errorDeClave: String?
    @State private var errorGeneral: String?
    @State private var confirmando = false
    @State private var borrando = false

    var body: some View {
        AjustesPagina(Textos.settingsDeleteAccount, volver: volver) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                Text(Textos.settingsDeleteAccountBody)
                    .estilo(.cuerpo, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)

                if flujo.cuentaConContrasena {
                    Text(Textos.settingsDeleteAccountPasswordHint)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                        CampoTexto(etiqueta: Textos.loginPasswordLabel,
                                   texto: $clave,
                                   contenido: .claveActual, seguro: true,
                                   conError: errorDeClave != nil)
                            .disabled(borrando)
                        ErrorDeCampo(errorDeClave)
                    }
                    .onChange(of: clave) { _ in errorDeClave = nil }
                } else {
                    Text(Textos.settingsDeleteAccountSocialHint)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorGeneral {
                    PistaDeCampo(estado: .error(errorGeneral))
                }

                Button {
                    Haptico.toque()
                    confirmando = true
                } label: {
                    ZStack {
                        if borrando {
                            ProgressView().tint(.white)
                        } else {
                            Text(Textos.settingsDeleteAccountConfirmButton)
                                .estilo(.botonPrimario, color: .white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: TokensEspaciado.e56)
                    .background(
                        RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                            .fill(Paleta.peligro)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .disabled(borrando || (flujo.cuentaConContrasena && clave.isEmpty))
                .padding(.top, TokensEspaciado.e8)
            }
        }
        .alert(Textos.settingsDeleteAccountAlertTitle, isPresented: $confirmando) {
            Button(Textos.commonCancel, role: .cancel) {}
            Button(Textos.settingsDeleteAccountAlertConfirm, role: .destructive) { borrar() }
        } message: {
            Text(Textos.settingsDeleteAccountAlertMessage)
        }
        .task { await flujo.cargarPerfil() }
    }

    private func borrar() {
        borrando = true
        errorGeneral = nil
        Task {
            let resultado = await flujo.borrarCuenta(clave: clave.isEmpty ? nil : clave)
            borrando = false
            switch resultado {
            case .borrada:
                Haptico.exito()
            case .claveIncorrecta:
                errorDeClave = Textos.fieldPasswordWrong
            case .fallo(let texto):
                errorGeneral = texto
            }
        }
    }
}
