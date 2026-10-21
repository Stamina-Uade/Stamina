import SwiftUI
import TrainerCore

// =============================================================================
// Paso 4: el aviso de salud, donde NACE la cuenta. Y los términos completos.
//
// 🛑 Este paso no está en el diseño canónico: lo pidió Iván el 2026-09-09, y
// Android lo tiene igual (`PantallaAviso.kt`). Queda abierto que se pisa con
// `reg-salud` (B-007): acá es la constancia legal versionada, allá los síntomas
// para parar y consultar.
//
// 🛑 El texto NO está en el catálogo de la app: baja de `GET /legal`, y lo que se
// manda al crear la cuenta es la VERSIÓN de ese texto. Una aceptación que no dice
// qué se aceptó no sirve el día que haga falta, porque para entonces el texto
// cambió tres veces. Por el mismo motivo la casilla arranca sin marcar: una
// aceptación por defecto no es una aceptación.
//
// Lo que sí sale del catálogo es lo que es NUESTRO y no del texto legal: el
// cartel de "todavía no lo revisó nadie con formación legal", los botones y los
// estados de carga.
// =============================================================================

/// `reg-aviso` · paso 4 de 15 · `GET /legal` y `POST /auth/register/complete`
struct RegAvisoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        Group {
            if let legales = flujo.legales {
                conTexto(legales)
            } else {
                sinTexto
            }
        }
        .task { await flujo.cargarLegalesSiFaltan() }
    }

    private func conTexto(_ legales: TextosLegales) -> some View {
        let aviso = legales.healthNotice
        return PantallaPaso(titulo: aviso.title, texto: aviso.summary) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                if legales.reviewed == false {
                    AvisoSuave(Textos.legalNotReviewed)
                }
                SeccionesLegales(secciones: aviso.sections, enTarjetas: true)
                BotonTexto(Textos.legalViewTerms) { flujo.ir(a: .regTerminos) }
            }
        } pie: {
            if flujo.ofrecerRenovarSocial, let proveedor = flujo.proveedorDelAlta {
                // El permiso de Google/Apple venció: se renueva sin perder el código.
                BotonTexto(Textos.signupSocialRetry(proveedor == .google ? "Google" : "Apple")) {
                    Task { await flujo.renovarPermisoSocial() }
                }
            }
            if flujo.ofrecerEmpezarDeNuevo {
                // El permiso venció sin usarse: hace falta otro código.
                BotonTexto(Textos.legalStartOver) { flujo.empezarElAltaDeNuevo() }
            }
            if flujo.ofrecerLogin {
                // 🛑 Volver al correo sería una trampa: si la cuenta se creó y la
                // respuesta no llegó, `POST /auth/register` contesta 202 igual y el
                // código no llega nunca. La salida es entrar.
                BotonTexto(flujo.laCuentaYaExiste ? Textos.legalSignInWithEmail : Textos.legalGoToLogin) {
                    flujo.irAlLoginDesdeElAlta()
                }
            }

            Casilla(texto: aviso.acceptance, marcada: $flujo.aceptoElAviso)
                .disabled(flujo.enCurso)

            BotonPrimario(Textos.legalCreateAccount,
                          habilitado: flujo.aceptoElAviso && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.legalMustAccept) {
                Task { await flujo.crearCuenta() }
            }
        }
    }

    /// Sin el texto no se puede aceptar nada, y se dice: no una pantalla vacía con
    /// un botón que igual funciona.
    private var sinTexto: some View {
        PantallaPaso(titulo: Textos.legalTitle,
                     texto: flujo.falloLegales ? Textos.legalNoText : Textos.legalLoading) {
            if flujo.cargandoLegales {
                ProgressView()
                    .tint(Paleta.acento)
                    .frame(maxWidth: .infinity)
            }
        } pie: {
            if flujo.falloLegales {
                BotonPrimario(Textos.legalRetry, habilitado: !flujo.cargandoLegales) {
                    Task { await flujo.cargarLegales() }
                }
            }
        }
    }
}

/// Los términos completos. No cuentan como paso: son una lectura, no un dato.
///
/// 🛑 Sin botón "Volver" al pie. Android lo tiene (`PantallaTerminos`); acá la
/// flecha de la cabecera ya vuelve al aviso, y dos controles que hacen lo mismo,
/// uno arriba y otro abajo, es ruido — el mismo motivo por el que se sacó el
/// "Volver al inicio de sesión" de `clave-correo` (decisión 0010 §12.2). Lo agarró
/// `testCadaPantallaTieneComoMuchoUnaFlechaDeVolver`: con el botón, había dos.
struct RegTerminosView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        if let terminos = flujo.legales?.terms {
            PantallaPaso(titulo: terminos.title, texto: terminos.summary, contenido: {
                SeccionesLegales(secciones: terminos.sections, enTarjetas: false)
            }, pie: {
                EmptyView()
            })
        } else {
            PantallaPaso(titulo: Textos.legalTitle, texto: Textos.legalNoText, pie: {
                EmptyView()
            })
        }
    }
}

/// Las secciones de un bloque legal: un título corto y un párrafo cada una.
///
/// El contrato las deja "deliberadamente tontas" (`TextosLegales`) para que quien
/// corrija la redacción no rompa la pantalla, y por eso acá no se interpreta nada:
/// se muestran en el orden en que llegan.
struct SeccionesLegales: View {
    let secciones: [SeccionLegal]
    /// El aviso las muestra en tarjetas, como el diseño muestra lo que hay que
    /// leer para seguir; los términos, corridas, porque son para consultar.
    let enTarjetas: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            ForEach(Array(secciones.enumerated()), id: \.offset) { _, seccion in
                if enTarjetas {
                    Tarjeta { contenido(seccion) }
                } else {
                    contenido(seccion)
                }
            }
        }
    }

    private func contenido(_ seccion: SeccionLegal) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            Text(seccion.title)
                .estilo(.tituloCard)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(seccion.body)
                .estilo(.cuerpo, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Términos y privacidad, desde el pie del registro

/// Qué texto legal se abre desde un enlace.
enum DocumentoLegal: String, Identifiable, CaseIterable {
    case terminos, privacidad, salud
    var id: String { rawValue }

    /// Los enlaces del catálogo son `stamina-legal://terminos` y
    /// `stamina-legal://privacidad` (`signup.email.legal_links`).
    static let esquema = "stamina-legal"

    init?(url: URL) {
        guard url.scheme == Self.esquema, let host = url.host,
              let documento = DocumentoLegal(rawValue: host) else { return nil }
        self = documento
    }

    /// El nombre corto de la pestaña.
    var pestana: String {
        switch self {
        case .terminos: return Textos.legalTabTerms
        case .privacidad: return Textos.legalTabPrivacy
        case .salud: return Textos.legalTabHealth
        }
    }

    /// El título mientras el texto no llegó del servidor.
    var tituloDeRespaldo: String {
        switch self {
        case .terminos: return Textos.legalTermsTitle
        case .privacidad: return Textos.legalPrivacyTitle
        case .salud: return Textos.legalHealthTitle
        }
    }
}

/// Una nota con enlaces en markdown (`[términos](stamina-legal://terminos)`):
/// el texto en gris y lo que se toca en celeste (2026-10-21, Iván: celeste y no
/// el rosa del acento).
struct TextoConEnlacesLegales: View {
    private let markdown: String
    private let abrir: (DocumentoLegal) -> Void

    init(_ markdown: String, abrir: @escaping (DocumentoLegal) -> Void) {
        self.markdown = markdown
        self.abrir = abrir
    }

    var body: some View {
        Text(atribuido)
            .estilo(.notaLegal, color: Paleta.textoTerciario)
            .tint(Paleta.enlace)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                guard let documento = DocumentoLegal(url: url) else { return .systemAction }
                abrir(documento)
                return .handled
            })
    }

    private var atribuido: AttributedString {
        let opciones = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var texto = (try? AttributedString(markdown: markdown, options: opciones)) ?? AttributedString(markdown)
        // El color va en el tramo: el `foregroundStyle` de la vista no pinta enlaces.
        let enlaces = texto.runs.filter { $0.link != nil }.map(\.range)
        for rango in enlaces {
            texto[rango].foregroundColor = Paleta.enlace
            texto[rango].font = Font.system(size: TokensTipografia.notaLegalTamano, weight: .semibold)
        }
        return texto
    }
}

/// Los textos legales en una hoja, con el diseño de la app (2026-10-21, Iván):
/// el fondo con el halo del acento, una X a la izquierda para cerrar, y pestañas
/// para pasar de términos a privacidad o al aviso de salud sin cerrar y volver a
/// abrir. Bajan de `GET /legal`, en el idioma del teléfono.
struct HojaLegal: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.dismiss) private var cerrar
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var elegido: DocumentoLegal

    init(documento: DocumentoLegal) {
        _elegido = State(initialValue: documento)
    }

    private func bloque(_ documento: DocumentoLegal) -> BloqueLegal? {
        switch documento {
        case .terminos: return flujo.legales?.terms
        case .privacidad: return flujo.legales?.privacy
        case .salud: return flujo.legales?.healthNotice
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BotonCerrarHoja { cerrar() }
                Spacer()
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e16)

            pestanas
                .padding(.horizontal, TokensEspaciado.e20)
                .padding(.top, TokensEspaciado.e12)
                .padding(.bottom, TokensEspaciado.e8)

            ScrollViewReader { proxy in
                ScrollView {
                    contenido
                        .id("arriba")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, TokensEspaciado.e20)
                        .padding(.top, TokensEspaciado.e12)
                        .padding(.bottom, TokensEspaciado.e34)
                }
                // Al cambiar de pestaña se empieza a leer desde arriba.
                .onChange(of: elegido) { _ in proxy.scrollTo("arriba", anchor: .top) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            ZStack {
                Paleta.fondo
                RadialGradient(colors: [Paleta.acentoProfundo, Color.clear],
                               center: .topLeading, startRadius: 0,
                               endRadius: TokensEspaciado.e56 * 4)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        )
        .presentationDragIndicator(.visible)
        .task { await flujo.cargarLegalesSiFaltan() }
    }

    /// Las pestañas: la misma cápsula segmentada de Ajustes › Unidades.
    private var pestanas: some View {
        HStack(spacing: TokensEspaciado.e4) {
            ForEach(DocumentoLegal.allCases) { documento in
                let esElegido = documento == elegido
                Button {
                    Haptico.seleccion()
                    withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida)) {
                        elegido = documento
                    }
                } label: {
                    Text(documento.pestana)
                        .estilo(.opcionTitulo, color: esElegido ? Paleta.sobreAcento : Paleta.textoSecundario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                        .background(
                            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                                .fill(esElegido ? Paleta.acento : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityAddTraits(esElegido ? [.isSelected] : [])
            }
        }
        .padding(TokensEspaciado.e4)
        .background(Paleta.superficieHundida)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton + TokensEspaciado.e4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton + TokensEspaciado.e4, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
    }

    @ViewBuilder
    private var contenido: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
            if let bloque = bloque(elegido) {
                Text(bloque.title)
                    .estilo(.tituloPantalla)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(bloque.summary)
                    .estilo(.cuerpo, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                SeccionesLegales(secciones: bloque.sections, enTarjetas: true)
            } else if flujo.falloLegales || flujo.legales != nil {
                // Falló la carga, o el servidor es anterior a la 1.4.0 y no manda
                // la privacidad.
                Text(elegido.tituloDeRespaldo)
                    .estilo(.tituloPantalla)
                    .accessibilityAddTraits(.isHeader)
                Text(Textos.legalNoText)
                    .estilo(.cuerpo, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                BotonTexto(Textos.legalRetry) { Task { await flujo.cargarLegales() } }
            } else {
                HStack(spacing: TokensEspaciado.e8) {
                    ProgressView().tint(Paleta.acento)
                    Text(Textos.legalLoading)
                        .estilo(.cuerpo, color: Paleta.textoSecundario)
                }
            }
        }
    }
}

/// La X de una hoja: el mismo círculo que la flecha de volver, a la izquierda.
struct BotonCerrarHoja: View {
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: "xmark")
                .font(.system(size: TokensTipografia.labelCampoTamano, weight: .bold))
                .foregroundStyle(Paleta.textoPrimario)
                .frame(width: TokensTamano.botonCircularCalendario + TokensEspaciado.e4,
                       height: TokensTamano.botonCircularCalendario + TokensEspaciado.e4)
                .background(Paleta.superficieAlterna)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
                .objetivoTactil()
        }
        .accessibilityLabel(Textos.commonClose)
    }
}
