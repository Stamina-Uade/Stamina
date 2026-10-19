import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 1, 2, 3 y 5: correo, código, contraseña y nombre.
//
// El correo se valida **antes** de pedir cualquier otro dato. Es la decisión 1
// del tablero del diseño, y no es cosmética: evita completar quince pasos para
// descubrir al final que había un error de tipeo.
//
// El paso 4 —el aviso de salud, donde nace la cuenta— está en
// `RegistroAvisoViews.swift`.
// =============================================================================

/// `reg-correo` · paso 1 de 15 · `POST /auth/register`
struct RegCorreoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupEmailTitle, texto: Textos.signupEmailBody) {
            ScrollViewReader { desplazamiento in
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    CampoTexto(etiqueta: Textos.signupNameLabel,
                               marcador: Textos.signupNamePlaceholder,
                               texto: $flujo.datos.nombre, contenido: .nombre)
                        .disabled(flujo.enCurso)
                    CampoTexto(etiqueta: Textos.signupLastNameLabel,
                               marcador: Textos.signupLastNamePlaceholder,
                               texto: $flujo.datos.apellido, contenido: .apellido)
                        .disabled(flujo.enCurso)
                    if flujo.datos.nombreCompletoListo {
                    CampoTexto(etiqueta: Textos.commonEmailLabel,
                               marcador: Textos.commonEmailPlaceholder,
                               texto: $flujo.datos.correo,
                               contenido: .correo, teclado: .correo)
                        .disabled(flujo.enCurso)
                    }
                    // Mientras se escribe no se juzga: el error aparece al tocar el
                    // botón (`FlujoEntrada.correoRechazado`).
                    if flujo.correoRechazado {
                        PistaDeCorreoRechazado()
                    }
                }
                .muestraElCorreoRechazado(flujo.correoRechazado, desplazando: desplazamiento)
            }
        } pie: {
            Text(Textos.signupEmailLegal)
                .estilo(.notaLegal, color: Paleta.textoTerciario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Se prende con algo escrito: si no parece un correo, lo dice el toque.
            BotonPrimario(Textos.signupEmailSend,
                          habilitado: flujo.datos.nombreCompletoListo && !flujo.datos.correo.isEmpty && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.pedirCodigoDeRegistro() }
            }
        }
    }
}

/// `reg-codigo` · paso 2 de 15 · `POST /auth/register/verify`
struct RegCodigoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupCodeTitle,
                     texto: Textos.signupCodeBody(flujo.datos.correo.isEmpty
                                                  ? Textos.commonEmailPlaceholder
                                                  : flujo.datos.correo)) {
            VStack(spacing: TokensEspaciado.e14) {
                CampoCodigo(codigo: $flujo.datos.codigo)
                    .disabled(flujo.enCurso)

                FilaDeReenvio(pedidos: flujo.pedidosDeCodigo,
                              habilitada: !flujo.enCurso,
                              cambiarCorreo: { flujo.volver() },
                              reenviar: { Task { await flujo.pedirCodigoDeRegistro() } })
            }
        } pie: {
            BotonPrimario(Textos.signupCodeVerify,
                          habilitado: flujo.datos.codigoCompleto && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.verificarCodigoDeRegistro() }
            }
        }
    }
}

/// `reg-clave` · paso 3 de 15 · 🛑 NO ESTÁ EN EL DISEÑO (B-004)
///
/// Los trece pasos de `Trainer App.dc.html` nunca piden contraseña, y
/// `POST /auth/register/complete` la exige. Acá no se decidió nada: la pantalla
/// existe para que el alta se pueda terminar contra el servidor de verdad y **lo
/// dice en la propia pantalla**, igual que la marca B-004. Usa los controles de
/// `clave-nueva`, que es lo que el diseño sí dibuja para elegir una contraseña, y
/// está en el mismo lugar del alta que `PantallaRegistroClave` de Android.
///
/// No sale ningún pedido desde acá: la contraseña viaja con el paso 4, que es el
/// que crea la cuenta. Por eso el botón dice "Continuar" y no "Crear cuenta".
struct RegClaveView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupPasswordTitle,
                     texto: Textos.signupPasswordBody(FlujoEntrada.largoMinimoDeClave)) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                AvisoSuave(Textos.signupPasswordGapNote)

                CampoTexto(etiqueta: Textos.passwordResetNewLabel,
                           marcador: Textos.commonPasswordPlaceholder,
                           texto: $flujo.claveDeRegistro,
                           contenido: .claveNueva, seguro: true)

                CampoTexto(etiqueta: Textos.passwordResetNewRepeatLabel,
                           marcador: Textos.commonPasswordPlaceholder,
                           texto: $flujo.claveDeRegistroRepetida,
                           contenido: .claveNueva, seguro: true)

                MedidorDeClave(cumplidas: flujo.reglasDeClaveDeRegistroCumplidas,
                               reglas: flujo.reglasDeClave(flujo.claveDeRegistro))

                if !flujo.claveDeRegistroRepetida.isEmpty {
                    PistaDeCampo(estado: flujo.claveDeRegistroCoincide
                                 ? .correcto(Textos.passwordResetNewMatch)
                                 : .error(Textos.passwordResetNewNoMatch))
                }
            }
        } pie: {
            BotonPrimario(Textos.commonContinue,
                          habilitado: flujo.claveDeRegistroLista,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                flujo.seguirConLaClave()
            }
        }
        .onChange(of: flujo.claveDeRegistro) { _ in flujo.errorVisible = nil }
    }
}

/// `reg-nombre` · paso 5 de 15 · el primero con la cuenta ya creada
///
/// Sin flecha de volver (ver `Pantalla.cabecera`): atrás está el aviso de salud,
/// con un permiso que ya se consumió.
struct RegNombreView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupNameTitle, texto: Textos.signupNameBody) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                CampoTexto(etiqueta: Textos.signupNameLabel,
                           marcador: Textos.signupNamePlaceholder,
                           texto: $flujo.datos.nombre, contenido: .nombre)
                // Opcional, como en el diseño. Vacío se guarda como `null`, que es
                // lo único que borra uno que ya estaba (docs/API.md §7).
                CampoTexto(etiqueta: Textos.signupLastNameLabel,
                           marcador: Textos.signupLastNamePlaceholder,
                           texto: $flujo.datos.apellido, contenido: .apellido)
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.nombreListo)
        }
    }
}
