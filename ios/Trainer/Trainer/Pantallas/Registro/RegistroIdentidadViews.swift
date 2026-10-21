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

/// `reg-correo` · paso 1 de 13 · `POST /auth/register`
///
/// Nombre, apellido, correo, contraseña y su confirmación, todo junto.
///
/// También es el primer paso de un alta que empezó con Google o Apple: llega con
/// nombre, apellido y correo ya escritos, y la persona los revisa.
struct RegCorreoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    /// Los términos o la privacidad, abiertos desde el pie.
    @State private var documento: DocumentoLegal?

    var body: some View {
        PantallaPaso(titulo: Textos.signupEmailTitle, texto: Textos.signupEmailBody) {
            ScrollViewReader { desplazamiento in
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    // Vino de "Continuar con Google / Apple": los datos ya están
                    // escritos. Si el proveedor verificó el correo, no hay código.
                    if let proveedor = flujo.proveedorDelAlta {
                        let nombre = proveedor == .google ? "Google" : "Apple"
                        AvisoSuave(flujo.correoValidadoPorProveedor
                                   ? Textos.signupSocialBannerVerified(nombre, nombre)
                                   : Textos.signupSocialBanner(nombre))
                            .padding(.bottom, TokensEspaciado.e4)
                    }
                    // Nombre y apellido en la misma fila, mitad y mitad (2026-10-21).
                    HStack(alignment: .top, spacing: TokensEspaciado.e10) {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                            CampoTexto(etiqueta: Textos.signupNameLabel,
                                       marcador: Textos.signupNamePlaceholder,
                                       texto: $flujo.datos.nombre, contenido: .nombre,
                                       conError: flujo.error(de: .nombre) != nil)
                            ErrorDeCampo(flujo.error(de: .nombre))
                        }
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
                               contenido: .correo, teclado: .correo,
                               conError: flujo.correoRechazado || flujo.error(de: .correo) != nil)
                        // El correo que verificó Google/Apple no se cambia: otro
                        // correo habría que validarlo con código.
                        .disabled(flujo.enCurso || flujo.correoValidadoPorProveedor)
                    // Mientras se escribe no se juzga: el error aparece al tocar el
                    // botón (`FlujoEntrada.correoRechazado`).
                    if flujo.correoRechazado {
                        PistaDeCorreoRechazado()
                    } else {
                        ErrorDeCampo(flujo.error(de: .correo))
                    }

                    // 2026-10-21: la contraseña va en el MISMO paso que el correo.
                    // Con Google o Apple no hay contraseña.
                    if flujo.proveedorDelAlta == nil {
                        CampoTexto(etiqueta: Textos.loginPasswordLabel,
                                   texto: $flujo.claveDeRegistro,
                                   contenido: .claveNueva, seguro: true,
                                   conError: flujo.error(de: .clave) != nil)
                            .disabled(flujo.enCurso)
                        ErrorDeCampo(flujo.error(de: .clave))
                        // La contraseña segura del iPhone llena las dos: la
                        // confirmación sobra (y SwiftUI la dibujaba vacía).
                        if !flujo.claveSugeridaPorElSistema {
                            CampoTexto(etiqueta: Textos.passwordResetNewRepeatLabel,
                                       texto: $flujo.claveDeRegistroRepetida,
                                       contenido: .claveNueva, seguro: true, conOjo: false,
                                       conError: flujo.error(de: .claveRepetida) != nil)
                                .disabled(flujo.enCurso)
                            ErrorDeCampo(flujo.error(de: .claveRepetida))
                        }
                        // Que coincidan no se anuncia (2026-10-21): sólo el error.
                        MedidorDeClave(cumplidas: flujo.reglasDeClaveDeRegistroCumplidas,
                                       reglas: flujo.reglasDeClave(flujo.claveDeRegistro))
                    }
                }
                .muestraElCorreoRechazado(flujo.correoRechazado, desplazando: desplazamiento)
                .onChange(of: flujo.datos.nombre) { _ in flujo.corrigiendo(.nombre) }
                .onChange(of: flujo.datos.correo) { _ in flujo.corrigiendo(.correo) }
                .onChange(of: flujo.claveDeRegistro) { _ in flujo.corrigiendo(.clave) }
                .onChange(of: flujo.claveDeRegistroRepetida) { _ in flujo.corrigiendo(.claveRepetida) }
            }
        } pie: {
            // "Términos y condiciones" y "Política de privacidad" se tocan, en celeste.
            TextoConEnlacesLegales(Textos.signupEmailLegalLinks) { documento = $0 }

            if flujo.correoValidadoPorProveedor {
                // Google/Apple ya validaron el correo: sin código, al aviso.
                BotonPrimario(Textos.commonContinue,
                              habilitado: flujo.datos.identidadLista && !flujo.enCurso,
                              motivoDeshabilitado: Textos.commonCompleteToContinue) {
                    flujo.seguirConDatosDelProveedor()
                }
            } else {
                // Se prende con algo escrito: si no parece un correo, lo dice el toque.
                BotonPrimario(Textos.signupEmailSend,
                              // Con Google/Apple (correo no verificado) no hay contraseña.
                              // Se prende con todo escrito; qué falla lo dice el
                              // toque, debajo de cada campo (2026-10-21).
                              habilitado: !flujo.datos.nombre.isEmpty && !flujo.datos.correo.isEmpty
                                  && (flujo.proveedorDelAlta != nil
                                      || (!flujo.claveDeRegistro.isEmpty
                                          && (flujo.claveSugeridaPorElSistema
                                              || !flujo.claveDeRegistroRepetida.isEmpty)))
                                  && !flujo.enCurso,
                              cargando: flujo.enCurso,
                              motivoDeshabilitado: Textos.commonCompleteToContinue) {
                    Task { await flujo.pedirCodigoDeRegistro() }
                }
            }
        }
        .sheet(item: $documento) { HojaLegal(documento: $0).environmentObject(flujo) }
        .task { await flujo.cargarLegalesSiFaltan() }
    }
}

/// `reg-codigo` · paso 2 de 13 · `POST /auth/register/verify`
struct RegCodigoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupCodeTitle,
                     texto: Textos.signupCodeBody(flujo.datos.correo.isEmpty
                                                  ? Textos.commonEmailPlaceholder
                                                  : flujo.datos.correo)) {
            VStack(spacing: TokensEspaciado.e14) {
                CampoCodigo(codigo: $flujo.datos.codigo, marcador: Textos.commonCodeLabel)
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
                           contenido: .claveNueva, seguro: true, conOjo: false)

                MedidorDeClave(cumplidas: flujo.reglasDeClaveDeRegistroCumplidas,
                               reglas: flujo.reglasDeClave(flujo.claveDeRegistro))

                // Sólo el error: que coincidan no se anuncia (2026-10-21).
                if !flujo.claveDeRegistroRepetida.isEmpty && !flujo.claveDeRegistroCoincide {
                    PistaDeCampo(estado: .error(Textos.fieldPasswordNoMatch))
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
