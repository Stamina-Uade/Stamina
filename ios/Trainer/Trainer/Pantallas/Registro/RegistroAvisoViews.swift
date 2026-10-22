import SwiftUI
import TrainerCore

// =============================================================================
// Paso 3: "Antes de empezar", donde NACE la cuenta. Y la hoja de los textos
// legales (términos, privacidad y salud), que se abre desde acá y desde Ajustes.
//
// 2026-10-22 (Iván): reemplaza al aviso de salud que bajaba del servidor, a los
// términos y a "Antes de arrancar" (el descargo médico, que era un paso de
// perfil). El texto de la pantalla es de la APP, no del servidor: así se lee sin
// señal. Lo que sigue bajando de `GET /legal` es la versión de los textos, que es
// lo que se manda al crear la cuenta: una aceptación que no dice qué se aceptó no
// sirve el día que haga falta. Las casillas arrancan sin marcar: una aceptación
// por defecto no es una aceptación.
// =============================================================================

/// `reg-antes-de-empezar` · paso 3 de 11 · `POST /auth/register/complete`
struct RegAntesDeEmpezarView: View {
    @EnvironmentObject private var flujo: FlujoEntrada
    @State private var leyendo: DocumentoLegal?

    var body: some View {
        PantallaPaso(titulo: Textos.signupBeforeTitle, texto: Textos.signupBeforeBody) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
                AvisoAtencion(titulo: Textos.signupHealthStopAndConsult) {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                        ItemAtencion(Textos.signupHealthSymptom1)
                        ItemAtencion(Textos.signupHealthSymptom2)
                        ItemAtencion(Textos.signupHealthSymptom3)
                    }
                }
                BotonTexto(Textos.signupBeforeReadLegal) { leyendo = .terminos }
            }
        } pie: {
            if flujo.ofrecerRenovarSocial, let proveedor = flujo.proveedorDelAlta {
                // El permiso de Google/Apple venció: se renueva sin perder el código.
                BotonTexto(Textos.signupSocialRetry(proveedor.nombre)) {
                    Task { await flujo.renovarPermisoSocial() }
                }
            }
            if flujo.ofrecerLogin {
                // 🛑 Volver al correo sería una trampa: si la cuenta se creó y la
                // respuesta no llegó, `POST /auth/register` contesta "ya
                // registrado". La salida es entrar.
                BotonTexto(flujo.laCuentaYaExiste ? Textos.legalSignInWithEmail : Textos.legalGoToLogin) {
                    flujo.irAlLoginDesdeElAlta()
                }
            }

            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                Casilla(texto: Textos.signupBeforeAcceptTerms, marcada: $flujo.aceptoElAviso)
                Casilla(texto: Textos.signupBeforeAcceptHealth, marcada: $flujo.aceptoElDescargo)
            }
            .disabled(flujo.enCurso)

            BotonPrimario(Textos.legalCreateAccount,
                          habilitado: flujo.puedeCrearCuenta && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.signupBeforeMustAccept) {
                Task { await flujo.crearCuenta() }
            }
        }
        .sheet(item: $leyendo) { HojaLegal(documento: $0).environmentObject(flujo) }
        // La versión se trae de antemano: sin ella no se puede crear la cuenta, y
        // si no hay señal se vuelve a pedir al tocar "Crear mi cuenta".
        .task { await flujo.cargarLegalesSiFaltan() }
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

// MARK: - Términos, privacidad y salud

/// Qué texto legal se abre desde un enlace.
enum DocumentoLegal: String, Identifiable, CaseIterable {
    case terminos, privacidad, salud
    var id: String { rawValue }

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
                // Cargando: sólo la ruedita.
                ProgressView()
                    .tint(Paleta.acento)
                    .frame(maxWidth: .infinity)
                    .padding(.top, TokensEspaciado.e20)
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
