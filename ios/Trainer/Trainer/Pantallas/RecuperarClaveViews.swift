import SwiftUI
import TrainerCore

// =============================================================================
// Las tres pantallas de recuperación de contraseña: pedir el correo, verificar
// el código y elegir la clave nueva. Son los tres endpoints del contrato
// —`/auth/password/forgot`, `/verify` y `/reset`—. Al guardar no hay pantalla
// de cierre: una alerta pregunta por las otras sesiones y se entra al Inicio.
//
// Desde la 1.4.0 el servidor dice si el correo no tiene cuenta (decisión de
// Iván): ya no hace falta el pie "el mensaje se envía aunque no esté registrado".
// =============================================================================

/// `clave-correo`
struct ClaveCorreoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.passwordResetEmailTitle, texto: Textos.passwordResetEmailBody) {
            CampoTexto(etiqueta: Textos.commonEmailLabel,
                       marcador: Textos.commonEmailPlaceholder,
                       texto: $flujo.recuperacionCorreo,
                       contenido: .correo, teclado: .correo)
                .disabled(flujo.enCurso)
        } pie: {
            // Se habilita con un correo válido (2026-10-22).
            BotonPrimario(Textos.passwordResetEmailSend,
                          habilitado: DatosRegistro.pareceCorreo(flujo.recuperacionCorreo) && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.pedirCodigoDeClave() }
            }
            // Acá había un "Volver al inicio de sesión". Se fue: la flecha de la
            // cabecera ya vuelve al login, y dos formas de hacer lo mismo, una
            // arriba y otra abajo, es ruido.
        }
    }
}

/// `clave-codigo`
struct ClaveCodigoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private var listo: Bool { flujo.recuperacionCodigo.count == CampoCodigo.largo }

    var body: some View {
        PantallaPaso(titulo: Textos.passwordResetCodeTitle,
                     texto: Textos.passwordResetCodeBody(flujo.correoDelDesafio)) {
            VStack(spacing: TokensEspaciado.e14) {
                CampoCodigo(codigo: $flujo.recuperacionCodigo, marcador: Textos.commonCodeLabel)
                    .disabled(flujo.enCurso || flujo.codigoAgotado)

                // Con el código vencido o agotado no se reenvía: se vuelve al
                // principio. Para cambiar el correo está la flecha de arriba.
                if !flujo.codigoAgotado {
                    FilaDeReenvio(enviado: flujo.envioDelCodigo,
                                  habilitada: !flujo.enCurso,
                                  reenviar: { Task { await flujo.pedirCodigoDeClave() } })
                }
            }
        } pie: {
            BotonPrimario(Textos.passwordResetCodeVerify,
                          habilitado: listo && !flujo.enCurso && !flujo.codigoAgotado,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.verificarCodigoDeClave() }
            }
        }
    }
}

/// `clave-nueva`
///
/// Sin texto debajo del título: los requisitos están en la lista. Al guardar no
/// hay pantalla final: una alerta pregunta por las otras sesiones y se entra.
struct ClaveNuevaView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.passwordResetNewTitle) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                CampoTexto(etiqueta: Textos.passwordResetNewLabel,
                           marcador: Textos.commonPasswordPlaceholder,
                           texto: $flujo.claveNueva,
                           contenido: .claveNueva, seguro: true)

                // La contraseña segura del iPhone llena las dos: no se repite. El
                // ojo va sólo en la primera.
                if !flujo.claveNuevaSugeridaPorElSistema {
                    CampoTexto(etiqueta: Textos.passwordResetNewRepeatLabel,
                               marcador: Textos.commonPasswordPlaceholder,
                               texto: $flujo.claveNuevaRepetida,
                               contenido: .claveNueva, seguro: true, conOjo: false,
                               conError: flujo.error(de: .claveRepetida) != nil)
                    ErrorDeCampo(flujo.error(de: .claveRepetida))
                }

                MedidorDeClave(cumplidas: flujo.reglasDeClaveNuevaCumplidas,
                               reglas: flujo.reglasDeClave(flujo.claveNueva))
            }
            .disabled(flujo.enCurso)
            .onChange(of: flujo.claveNueva) { _ in flujo.corrigiendo(.claveRepetida) }
            .onChange(of: flujo.claveNuevaRepetida) { _ in flujo.corrigiendo(.claveRepetida) }
        } pie: {
            // Se habilita con las tres reglas; si las dos no coinciden, lo dice el
            // rojo debajo de "Repetir contraseña" al tocar.
            BotonPrimario(Textos.passwordResetNewSave,
                          habilitado: flujo.puedeGuardarClaveNueva && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.guardarClaveNueva() }
            }
        }
    }
}

// MARK: - Piezas compartidas por el flujo

/// El mensaje bajo un campo. Lleva el color del estado **y** el texto: el color
/// nunca es la única señal (AGENTS.md §10.1).
struct PistaDeCampo: View {
    let estado: EstadoCampo

    var body: some View {
        if let mensaje = estado.mensaje {
            Text(mensaje)
                .estilo(.labelCampo, color: estado.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// El error de un campo, debajo de él y en rojo (2026-10-21: en vez de una
/// alerta). VoiceOver lo anuncia al aparecer. Sin error no ocupa lugar.
struct ErrorDeCampo: View {
    let mensaje: String?

    init(_ mensaje: String?) { self.mensaje = mensaje }

    var body: some View {
        if let mensaje {
            PistaDeCampo(estado: .error(mensaje))
                .transition(.opacity)
                .onAppear { UIAccessibility.post(notification: .announcement, argument: mensaje) }
        }
    }
}

/// Las tres barras y las tres reglas de la contraseña.
struct MedidorDeClave: View {
    let cumplidas: Int
    let reglas: [FlujoEntrada.ReglaDeClave]

    static let colores: [Color] = [Paleta.error, Paleta.amarilloMedidor, Paleta.verdeMedidor]

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            HStack(spacing: TokensEspaciado.e5) {
                // 2026-10-21: cada tramo tiene su color —rojo, amarillo, verde—, así
                // la barra "escala" a verde a medida que se cumplen las reglas. El
                // estado también lo dicen la lista de reglas y VoiceOver: no sólo
                // el color (AGENTS.md §10.1).
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i < cumplidas ? Self.colores[i] : Paleta.superficieControl)
                        .frame(height: TokensEspaciado.e4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Textos.passwordResetNewStrength(cumplidas))

            ForEach(reglas) { regla in
                HStack(spacing: TokensEspaciado.e8) {
                    // Tilde o punto: la regla cumplida no se distingue sólo por
                    // color, que es lo que §10.1 prohíbe.
                    Image(systemName: regla.cumple ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: TokensTipografia.labelCampoTamano))
                        .foregroundStyle(regla.cumple ? Paleta.verdeMedidor : Paleta.textoTerciario)
                    Text(regla.texto)
                        .estilo(.labelCampo,
                                color: regla.cumple ? Paleta.textoCuerpo : Paleta.textoTerciario)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// "Reenviar en 0:42", y después "Reenviar código".
///
/// La cuenta arranca cuando el SERVIDOR aceptó el pedido anterior (`enviado`), no
/// cuando se dibujó la fila: antes de los 60 segundos contesta
/// `code_resend_too_soon`. Se calcula desde esa hora en cada segundo —no se
/// descuenta de a uno—, así que sigue corriendo con la app en segundo plano: al
/// volver muestra lo que de verdad falta.
struct FilaDeReenvio: View {
    /// Cuándo el servidor aceptó el último pedido de código.
    let enviado: Date?
    let habilitada: Bool
    let reenviar: () -> Void

    /// `REENVIO_MS` de `backend/src/dominios/auth/servicio.ts`: el mismo número que
    /// `SEGUNDOS_PARA_REENVIAR` de Android, y lo que dice el contrato.
    static let segundosParaReenviar = 60

    /// Los segundos que faltan para poder reenviar, a esta hora.
    static func restantes(desde enviado: Date?, ahora: Date) -> Int {
        guard let enviado else { return 0 }
        let pasados = Int(ahora.timeIntervalSince(enviado).rounded(.down))
        return max(0, segundosParaReenviar - pasados)
    }

    var body: some View {
        TimelineView(.periodic(from: enviado ?? .now, by: 1)) { contexto in
            let restantes = Self.restantes(desde: enviado, ahora: contexto.date)
            HStack {
                Spacer()
                if restantes > 0 {
                    Text(Textos.commonResendIn(String(format: "%d:%02d", restantes / 60, restantes % 60)))
                        .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                        .monospacedDigit()
                } else {
                    Button(action: reenviar) {
                        Text(Textos.commonResendCode)
                            .estilo(.cuerpoSecundario, color: Paleta.acento)
                            .objetivoTactilAlto()
                    }
                }
                Spacer()
            }
        }
        .disabled(!habilitada)
    }
}
