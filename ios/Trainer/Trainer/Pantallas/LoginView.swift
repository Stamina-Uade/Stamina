import SwiftUI
import TrainerCore

/// `login` — correo y contraseña contra `POST /auth/login`, o Google / Apple
/// contra `POST /auth/social` (contrato 1.4.0).
///
/// Con un proveedor, si la cuenta ya existe se entra; si es nueva, sigue el alta
/// de siempre con nombre, apellido y correo ya escritos (ver
/// `FlujoEntrada.entrarCon`). Los dos botones son un par limpio —mismo fondo, borde
/// fino, logo y texto centrados— como la referencia que mandó Iván.
struct LoginView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                    Text(Textos.loginTitle)
                        .estilo(.display)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    // Llegar acá de rebote —la sesión venció o se cerró desde otro
                    // lado— no es un error de quien está mirando: se explica con el
                    // aviso suave, no con el rojo.
                    if let aviso = flujo.avisoDelLogin {
                        AvisoSuave(aviso)
                    }

                    VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                        // Mientras se escribe no se juzga: el error aparece al tocar
                        // "Ingresar" (`FlujoEntrada.correoRechazado`), pegado al campo.
                        ScrollViewReader { desplazamiento in
                            VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                                CampoTexto(etiqueta: Textos.commonEmailLabel,
                                           marcador: Textos.commonEmailPlaceholder,
                                           texto: $flujo.loginCorreo,
                                           contenido: .correo, teclado: .correo,
                                           conError: flujo.correoRechazado || flujo.error(de: .correo) != nil)
                                if flujo.correoRechazado {
                                    PistaDeCorreoRechazado()
                                } else {
                                    ErrorDeCampo(flujo.error(de: .correo))
                                }
                            }
                            .muestraElCorreoRechazado(flujo.correoRechazado, desplazando: desplazamiento)
                        }

                        CampoTexto(etiqueta: Textos.loginPasswordLabel,
                                   marcador: Textos.commonPasswordPlaceholder,
                                   texto: $flujo.loginClave,
                                   contenido: .claveActual, seguro: true,
                                   conError: flujo.error(de: .clave) != nil)
                        ErrorDeCampo(flujo.error(de: .clave))
                            .padding(.top, -TokensEspaciado.e6)

                        HStack {
                            Spacer()
                            Button { flujo.irARecuperarClave() } label: {
                                Text(Textos.loginForgotPassword)
                                    .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                                    .padding(.vertical, TokensEspaciado.e4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, TokensEspaciado.e4)

                        // "Ingresar" va acá, pegado a los campos que habilita, y
                        // no al pie de la pantalla: quien termina de escribir la
                        // contraseña lo tiene abajo del pulgar, sin bajar la
                        // vista. Apagado sigue siendo el color de la app.
                        BotonPrimario(Textos.loginSignIn,
                                      habilitado: flujo.loginListo && !flujo.enCurso,
                                      cargando: flujo.enCurso && flujo.conectandoCon == nil,
                                      motivoDeshabilitado: Textos.commonCompleteToContinue) {
                            Task { await flujo.entrar() }
                        }
                    }
                    .disabled(flujo.enCurso)

                    separador

                    // El grupo alinea los textos: "Continuar…" empieza en el mismo
                    // pixel en los dos botones.
                    GrupoDeProveedores {
                        BotonProveedor(.google, titulo: Textos.loginGoogle,
                                       cargando: flujo.conectandoCon == .google) {
                            Task { await flujo.entrarCon(.google) }
                        }
                        BotonProveedor(.apple, titulo: Textos.loginApple,
                                       cargando: flujo.conectandoCon == .apple) {
                            Task { await flujo.entrarCon(.apple) }
                        }
                    }
                    .disabled(flujo.enCurso)

                    // 2026-10-21: va DENTRO del scroll, debajo de Google y Apple, y
                    // no pegado al pie. Pegado al pie subía con el teclado y se
                    // chocaba con los botones de "Continuar con…".
                    HStack(spacing: TokensEspaciado.e4) {
                        Text(Textos.loginNoAccount)
                            .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                        Button { flujo.ir(a: .regCorreo) } label: {
                            Text(Textos.loginSignUp)
                                .estilo(.cuerpoSecundario, color: Paleta.acento)
                                .padding(.vertical, TokensEspaciado.e4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, TokensEspaciado.e8)
                }
                .padding(.horizontal, TokensEspaciado.e22)
                .padding(.top, TokensEspaciado.e12)
                .padding(.bottom, TokensEspaciado.e34)
            }
            .scrollDismissesKeyboardCompat()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        // Un error viejo no tiene que quedar pegado a lo que se está corrigiendo.
        .onChange(of: flujo.loginClave) { _ in
            flujo.errorVisible = nil
            flujo.corrigiendo(.clave)
        }
        .onChange(of: flujo.loginCorreo) { _ in flujo.corrigiendo(.correo) }
    }

    private var separador: some View {
        HStack(spacing: TokensEspaciado.e12) {
            Rectangle().fill(Paleta.divisor).frame(height: TokensEspaciado.e1)
            Text(Textos.loginOr).estilo(.chip, color: Paleta.textoTerciario)
            Rectangle().fill(Paleta.divisor).frame(height: TokensEspaciado.e1)
        }
        .accessibilityHidden(true)
    }
}

/// El mensaje de error de una pantalla. Lleva ícono **además** de color: nada se
/// comunica sólo por color (AGENTS.md §10.1).
struct MensajeDeError: View {
    private let texto: String

    init(_ texto: String) {
        self.texto = texto
    }

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e9) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: TokensTipografia.labelCampoTamano))
                .foregroundStyle(Paleta.error)
            Text(texto)
                .estilo(.labelCampo, color: Paleta.error)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(TokensEspaciado.e12)
        .background(Paleta.errorFondo)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
                .strokeBorder(Paleta.errorBorde, lineWidth: TokensEspaciado.e1)
        )
        .accessibilityElement(children: .combine)
    }
}
