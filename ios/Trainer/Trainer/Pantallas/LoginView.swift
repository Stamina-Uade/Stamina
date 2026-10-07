import SwiftUI
import TrainerCore

/// `login` — correo y contraseña contra `POST /auth/login`, con las dos
/// alternativas de proveedor.
///
/// 🪤 Google y Apple están **diseñados y no implementados**: el contrato v1 no
/// tiene endpoint de OAuth (`shared/api/openapi.yaml` sólo trae `/auth/login`).
/// El botón dice la verdad en vez de fingir: avisa que todavía no está. Un botón
/// que no hace nada es peor que uno que explica por qué — y uno que dice "algo
/// salió mal" miente, porque no salió nada.
struct LoginView: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var avisoDeProveedor = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                    Text(Textos.loginTitulo)
                        .estilo(.tituloPantalla)
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
                                CampoTexto(etiqueta: Textos.comunCorreoLabel,
                                           marcador: Textos.comunCorreoMarcador,
                                           texto: $flujo.loginCorreo,
                                           contenido: .correo, teclado: .correo)
                                if flujo.correoRechazado {
                                    PistaDeCorreoRechazado()
                                }
                            }
                            .muestraElCorreoRechazado(flujo.correoRechazado, desplazando: desplazamiento)
                        }

                        CampoTexto(etiqueta: Textos.loginClaveLabel,
                                   marcador: Textos.comunClaveMarcador,
                                   texto: $flujo.loginClave,
                                   contenido: .claveActual, seguro: true)

                        HStack {
                            Spacer()
                            Button { flujo.irARecuperarClave() } label: {
                                Text(Textos.loginOlvidaste)
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
                        BotonPrimario(Textos.loginIngresar,
                                      habilitado: flujo.loginListo && !flujo.enCurso,
                                      cargando: flujo.enCurso,
                                      motivoDeshabilitado: Textos.comunCompletaParaSeguir) {
                            Task { await flujo.entrar() }
                        }
                    }
                    .disabled(flujo.enCurso)

                    separador

                    VStack(spacing: TokensEspaciado.e10) {
                        BotonProveedor(.google, titulo: Textos.loginGoogle) {
                            avisoDeProveedor = true
                        }
                        BotonProveedor(.apple, titulo: Textos.loginApple) {
                            avisoDeProveedor = true
                        }
                        if avisoDeProveedor {
                            AvisoSuave(Textos.loginSocialFalta)
                        }
                    }
                }
                .padding(.horizontal, TokensEspaciado.e26)
                .padding(.top, TokensEspaciado.e12)
            }
            .scrollDismissesKeyboardCompat()

            VStack(spacing: TokensEspaciado.e12) {
                HStack(spacing: TokensEspaciado.e4) {
                    Text(Textos.loginNoTenesCuenta)
                        .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                    Button { flujo.ir(a: .regCorreo) } label: {
                        Text(Textos.loginRegistrate)
                            .estilo(.cuerpoSecundario, color: Paleta.acento)
                            .padding(.vertical, TokensEspaciado.e4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, TokensEspaciado.e26)
            .padding(.bottom, TokensEspaciado.e34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
        // Un error viejo no tiene que quedar pegado a lo que se está corrigiendo.
        .onChange(of: flujo.loginClave) { _ in flujo.errorVisible = nil }
    }

    private var separador: some View {
        HStack(spacing: TokensEspaciado.e12) {
            Rectangle().fill(Paleta.divisor).frame(height: TokensEspaciado.e1)
            Text(Textos.loginO).estilo(.notaLegal, color: Paleta.textoTerciario)
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
