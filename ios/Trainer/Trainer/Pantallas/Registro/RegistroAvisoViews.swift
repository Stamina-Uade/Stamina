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
                    AvisoSuave(Textos.legalSinRevisar)
                }
                SeccionesLegales(secciones: aviso.sections, enTarjetas: true)
                BotonTexto(Textos.legalVerTerminos) { flujo.ir(a: .regTerminos) }
            }
        } pie: {
            if flujo.ofrecerEmpezarDeNuevo {
                // El permiso venció sin usarse: hace falta otro código.
                BotonTexto(Textos.legalEmpezarDeNuevo) { flujo.empezarElAltaDeNuevo() }
            }
            if flujo.ofrecerLogin {
                // 🛑 Volver al correo sería una trampa: si la cuenta se creó y la
                // respuesta no llegó, `POST /auth/register` contesta 202 igual y el
                // código no llega nunca. La salida es entrar.
                BotonTexto(flujo.laCuentaYaExiste ? Textos.legalEntrarConEseCorreo : Textos.legalIrAlLogin) {
                    flujo.irAlLoginDesdeElAlta()
                }
            }

            Casilla(texto: aviso.acceptance, marcada: $flujo.aceptoElAviso)
                .disabled(flujo.enCurso)

            BotonPrimario(Textos.legalCrearCuenta,
                          habilitado: flujo.aceptoElAviso && !flujo.enCurso,
                          cargando: flujo.enCurso,
                          motivoDeshabilitado: Textos.legalFaltaAceptar) {
                Task { await flujo.crearCuenta() }
            }
        }
    }

    /// Sin el texto no se puede aceptar nada, y se dice: no una pantalla vacía con
    /// un botón que igual funciona.
    private var sinTexto: some View {
        PantallaPaso(titulo: Textos.legalTitulo,
                     texto: flujo.falloLegales ? Textos.legalSinTexto : Textos.legalCargando) {
            if flujo.cargandoLegales {
                ProgressView()
                    .tint(Paleta.acento)
                    .frame(maxWidth: .infinity)
            }
        } pie: {
            if flujo.falloLegales {
                BotonPrimario(Textos.legalReintentar, habilitado: !flujo.cargandoLegales) {
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
            PantallaPaso(titulo: Textos.legalTitulo, texto: Textos.legalSinTexto, pie: {
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
