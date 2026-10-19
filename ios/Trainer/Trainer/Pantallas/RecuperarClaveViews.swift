import SwiftUI
import TrainerCore

// =============================================================================
// Las cuatro pantallas de recuperación de contraseña: pedir el correo, verificar
// el código, elegir la clave nueva y confirmar. Son los tres endpoints del
// contrato —`/auth/password/forgot`, `/verify` y `/reset`— más la confirmación.
//
// 🛑 El texto anti-enumeración de `clave-correo` **no es decorativo**: el
// servidor responde igual exista o no la cuenta (AGENTS.md §12), y la pantalla
// tiene que decirlo. Si dijera "te mandamos el código" a secas, quien pruebe
// correos ajenos aprendería cuáles existen mirando la diferencia.
// =============================================================================

/// `clave-correo`
struct ClaveCorreoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.passwordResetEmailTitle, texto: Textos.passwordResetEmailBody) {
            ScrollViewReader { desplazamiento in
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    CampoTexto(etiqueta: Textos.commonEmailLabel,
                               marcador: Textos.commonEmailPlaceholder,
                               texto: $flujo.recuperacionCorreo,
                               contenido: .correo, teclado: .correo)
                        .disabled(flujo.enCurso)

                    // Mientras se escribe no se juzga: el error aparece al tocar el
                    // botón (`FlujoEntrada.correoRechazado`).
                    if flujo.correoRechazado {
                        PistaDeCorreoRechazado()
                    }
                }
                .muestraElCorreoRechazado(flujo.correoRechazado, desplazando: desplazamiento)
            }
        } pie: {
            Text(Textos.passwordResetEmailAntiEnumeration)
                .estilo(.notaLegal, color: Paleta.textoTerciario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Se prende con algo escrito: si no parece un correo, lo dice el toque.
            BotonPrimario(Textos.passwordResetEmailSend,
                          habilitado: !flujo.recuperacionCorreo.isEmpty && !flujo.enCurso,
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
                CampoCodigo(codigo: $flujo.recuperacionCodigo)
                    .disabled(flujo.enCurso)

                FilaDeReenvio(pedidos: flujo.pedidosDeCodigo,
                              habilitada: !flujo.enCurso,
                              cambiarCorreo: { flujo.volver() },
                              reenviar: { Task { await flujo.pedirCodigoDeClave() } })
            }
        } pie: {
            BotonPrimario(Textos.passwordResetCodeVerify,
                          habilitado: listo && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.verificarCodigoDeClave() }
            }
        }
    }
}

/// `clave-nueva`
struct ClaveNuevaView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.passwordResetNewTitle, texto: Textos.passwordResetNewBody) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                CampoTexto(etiqueta: Textos.passwordResetNewLabel,
                           marcador: Textos.commonPasswordPlaceholder,
                           texto: $flujo.claveNueva,
                           contenido: .claveNueva, seguro: true)

                CampoTexto(etiqueta: Textos.passwordResetNewRepeatLabel,
                           marcador: Textos.commonPasswordPlaceholder,
                           texto: $flujo.claveNuevaRepetida,
                           contenido: .claveNueva, seguro: true)

                MedidorDeClave(cumplidas: flujo.reglasDeClaveNuevaCumplidas,
                               reglas: flujo.reglasDeClave(flujo.claveNueva))

                if !flujo.claveNuevaRepetida.isEmpty {
                    PistaDeCampo(estado: flujo.claveNuevaCoincide
                                 ? .correcto(Textos.passwordResetNewMatch)
                                 : .error(Textos.passwordResetNewNoMatch))
                }
            }
            .disabled(flujo.enCurso)
        } pie: {
            BotonPrimario(Textos.passwordResetNewSave,
                          habilitado: flujo.claveNuevaLista && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.commonCompleteToContinue) {
                Task { await flujo.guardarClaveNueva() }
            }
        }
    }
}

/// `clave-lista`
///
/// 🛑 El diseño manda al login desde acá. Se entra derecho: el servidor devolvió
/// una sesión nueva junto con la contraseña cambiada, y pedirle a alguien que
/// tipee la contraseña que eligió treinta segundos antes es un trámite sin
/// sentido. Es el mismo desvío que Android (`FlujoDeClave.kt`).
struct ClaveListaView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaCierre(titulo: Textos.passwordResetDoneTitle, texto: Textos.passwordResetDoneBody) {
            Tarjeta {
                VStack(spacing: TokensEspaciado.e9) {
                    FilaResumen(Textos.passwordResetDoneAccount, flujo.correoDelDesafio)
                    FilaResumen(Textos.passwordResetDoneChanged,
                                Date.now.formatted(date: .abbreviated, time: .shortened))
                }
            }
        } pie: {
            BotonPrimario(Textos.passwordResetDoneGoHome) { flujo.entrarConLaClaveNueva() }
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

/// El "no parece un correo", debajo del campo. Aparece recién al tocar el botón.
struct PistaDeCorreoRechazado: View {
    static let ancla = "correo-rechazado"

    var body: some View {
        PistaDeCampo(estado: .error(Textos.signupEmailInvalid))
            .id(Self.ancla)
    }
}

extension View {
    /// Cuando se rechaza el correo, lo deja a la vista y VoiceOver lo anuncia.
    ///
    /// 🪤 Con el teclado arriba el pie de la pantalla sube, y si el campo quedó al
    /// borde de lo que se ve, el renglón nuevo queda tapado y el toque parece no
    /// hacer nada: se desplaza lo justo para mostrarlo, y nada si ya se ve. El foco
    /// de VoiceOver, en cambio, se queda en el botón que se acaba de tocar: sin el
    /// anuncio el toque no diría nada. Antes lo explicaba el botón apagado.
    func muestraElCorreoRechazado(_ rechazado: Bool,
                                  desplazando desplazamiento: ScrollViewProxy) -> some View {
        onChange(of: rechazado) { ahora in
            guard ahora else { return }
            UIAccessibility.post(notification: .announcement, argument: Textos.signupEmailInvalid)
            // Recién en la vuelta siguiente el renglón nuevo tiene lugar en pantalla.
            DispatchQueue.main.async {
                desplazamiento.scrollTo(PistaDeCorreoRechazado.ancla)
            }
        }
    }
}

/// Las tres barras y las tres reglas de la contraseña.
struct MedidorDeClave: View {
    let cumplidas: Int
    let reglas: [FlujoEntrada.ReglaDeClave]

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            HStack(spacing: TokensEspaciado.e5) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i < cumplidas ? Paleta.acento : Paleta.superficieControl)
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
                        .foregroundStyle(regla.cumple ? Paleta.acento : Paleta.textoTerciario)
                    Text(regla.texto)
                        .estilo(.labelCampo,
                                color: regla.cumple ? Paleta.textoCuerpo : Paleta.textoTerciario)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// "Cambiar correo · Reenviar en 0:42".
///
/// El contador es real y arranca cuando el SERVIDOR aceptó el pedido anterior, no
/// cuando se dibujó la fila: antes de los 60 segundos contesta
/// `code_resend_too_soon`. Tocar "Reenviar" pide el código de verdad; si el
/// servidor lo acepta, `pedidos` cambia y la cuenta vuelve a empezar.
struct FilaDeReenvio: View {
    /// Cambia cada vez que el servidor aceptó un pedido de código.
    let pedidos: Int
    let habilitada: Bool
    let cambiarCorreo: () -> Void
    let reenviar: () -> Void

    /// `REENVIO_MS` de `backend/src/dominios/auth/servicio.ts`: el mismo número que
    /// `SEGUNDOS_PARA_REENVIAR` de Android, y lo que dice el contrato.
    static let segundosParaReenviar = 60

    @State private var restantes = FilaDeReenvio.segundosParaReenviar
    @State private var reloj: Timer?

    var body: some View {
        HStack {
            Button(action: cambiarCorreo) {
                Text(Textos.commonChangeEmail)
                    .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                    .objetivoTactilAlto()
            }

            Spacer()

            if restantes > 0 {
                Text(Textos.commonResendIn(relojMmss))
                    .estilo(.cuerpoSecundario, color: Paleta.textoTerciario)
                    .monospacedDigit()
            } else {
                Button(action: reenviar) {
                    Text(Textos.commonResendCode)
                        .estilo(.cuerpoSecundario, color: Paleta.acento)
                        .objetivoTactilAlto()
                }
            }
        }
        .disabled(!habilitada)
        .onAppear(perform: arrancar)
        .onDisappear { reloj?.invalidate(); reloj = nil }
        .onChange(of: pedidos) { _ in
            restantes = Self.segundosParaReenviar
            arrancar()
        }
    }

    private var relojMmss: String {
        String(format: "%d:%02d", restantes / 60, restantes % 60)
    }

    private func arrancar() {
        reloj?.invalidate()
        reloj = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if restantes > 0 { restantes -= 1 } else { reloj?.invalidate() }
            }
        }
    }
}
