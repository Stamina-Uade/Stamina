import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 1 y 2: "Crea tu cuenta" (nombre, apellido, correo y contraseña) y
// "Valida tu correo".
//
// El correo se valida **antes** de pedir cualquier otro dato. Es la decisión 1
// del tablero del diseño, y no es cosmética: evita completar quince pasos para
// descubrir al final que había un error de tipeo.
//
// El paso 3 —"Antes de empezar", donde nace la cuenta— está en
// `RegistroAvisoViews.swift`.
// =============================================================================

/// `reg-correo` · paso 1 de 11 · `POST /auth/register`
///
/// Nombre, apellido, correo, contraseña y su confirmación, todo junto.
/// "Enviarme el código" se habilita con el nombre, un correo válido y la
/// contraseña con sus tres reglas (el apellido es opcional). El único rojo es
/// "Las contraseñas no coinciden", al tocar; lo demás lo dicen las alertas.
///
/// También es el primer paso de un alta que empezó con Google o Apple: llega con
/// nombre, apellido y correo ya escritos, la persona los revisa y no hay
/// contraseña.
struct RegCorreoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupEmailTitle, texto: texto) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                // Nombre y apellido en la misma fila, mitad y mitad (2026-10-21).
                HStack(alignment: .top, spacing: TokensEspaciado.e10) {
                    CampoTexto(etiqueta: Textos.signupNameLabel,
                               marcador: Textos.signupNamePlaceholder,
                               texto: $flujo.datos.nombre, contenido: .nombre)
                        .frame(maxWidth: .infinity)
                    CampoTexto(etiqueta: Textos.signupLastNameLabel,
                               marcador: Textos.signupLastNamePlaceholder,
                               texto: $flujo.datos.apellido, contenido: .apellido)
                        .frame(maxWidth: .infinity)
                }
                .disabled(flujo.enCurso)
                CampoTexto(etiqueta: Textos.commonEmailLabel,
                           marcador: Textos.commonEmailPlaceholder,
                           texto: $flujo.datos.correo,
                           contenido: .correo, teclado: .correo)
                    // El correo que verificó Google/Apple no se cambia: otro
                    // correo habría que validarlo con código.
                    .disabled(flujo.enCurso || flujo.correoValidadoPorProveedor)

                // 2026-10-21: la contraseña va en el MISMO paso que el correo.
                // Con Google o Apple no hay contraseña.
                if flujo.proveedorDelAlta == nil {
                    CampoTexto(etiqueta: Textos.loginPasswordLabel,
                               texto: $flujo.claveDeRegistro,
                               contenido: .claveNueva, seguro: true)
                        .disabled(flujo.enCurso)
                    // La contraseña segura del iPhone llena las dos: la
                    // confirmación sobra (y SwiftUI la dibujaba vacía). El ojo va
                    // sólo en la primera.
                    if !flujo.claveSugeridaPorElSistema {
                        CampoTexto(etiqueta: Textos.passwordResetNewRepeatLabel,
                                   texto: $flujo.claveDeRegistroRepetida,
                                   contenido: .claveNueva, seguro: true, conOjo: false,
                                   conError: flujo.error(de: .claveRepetida) != nil)
                            .disabled(flujo.enCurso)
                        ErrorDeCampo(flujo.error(de: .claveRepetida))
                    }
                    MedidorDeClave(cumplidas: flujo.reglasDeClaveDeRegistroCumplidas,
                                   reglas: flujo.reglasDeClave(flujo.claveDeRegistro))
                }
            }
            .onChange(of: flujo.claveDeRegistro) { _ in flujo.corrigiendo(.claveRepetida) }
            .onChange(of: flujo.claveDeRegistroRepetida) { _ in flujo.corrigiendo(.claveRepetida) }
        } pie: {
            if flujo.correoValidadoPorProveedor {
                // Google/Apple ya validaron el correo: sin código, a "Antes de empezar".
                BotonPrimario(Textos.commonContinue,
                              habilitado: flujo.puedePedirCodigoDeRegistro && !flujo.enCurso,
                              motivoDeshabilitado: Textos.commonCompleteToContinue) {
                    flujo.seguirConDatosDelProveedor()
                }
            } else {
                // Con Google/Apple y el correo sin validar, "Continuar" pide el código.
                BotonPrimario(flujo.proveedorDelAlta == nil ? Textos.signupEmailSend : Textos.commonContinue,
                              habilitado: flujo.puedePedirCodigoDeRegistro && !flujo.enCurso,
                              cargando: flujo.enCurso,
                              motivoDeshabilitado: Textos.commonCompleteToContinue) {
                    Task { await flujo.pedirCodigoDeRegistro() }
                }
            }
        }
    }

    /// Con Google o Apple, que revise lo que trajimos de su cuenta (y nunca el
    /// nombre del otro proveedor).
    private var texto: String {
        if let proveedor = flujo.proveedorDelAlta { return Textos.signupSocialReview(proveedor.nombre) }
        return Textos.signupEmailBody
    }
}

/// `reg-codigo` · paso 2 de 11 · `POST /auth/register/verify`
///
/// Sin "Cambiar correo": para eso está la flecha de arriba.
struct RegCodigoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupCodeTitle,
                     texto: Textos.signupCodeBody(flujo.datos.correo.isEmpty
                                                  ? Textos.commonEmailPlaceholder
                                                  : flujo.datos.correo)) {
            VStack(spacing: TokensEspaciado.e14) {
                CampoCodigo(codigo: $flujo.datos.codigo, marcador: Textos.commonCodeLabel)
                    .disabled(flujo.enCurso || flujo.codigoAgotado)

                // Con el código vencido o agotado no se reenvía: se vuelve a "Crea
                // tu cuenta" con lo escrito.
                if !flujo.codigoAgotado {
                    FilaDeReenvio(enviado: flujo.envioDelCodigo,
                                  habilitada: !flujo.enCurso,
                                  reenviar: { Task { await flujo.pedirCodigoDeRegistro() } })
                }
            }
        } pie: {
            BotonPrimario(Textos.signupCodeVerify,
                          habilitado: flujo.datos.codigoCompleto && !flujo.enCurso && !flujo.codigoAgotado,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.verificarCodigoDeRegistro() }
            }
        }
    }
}
