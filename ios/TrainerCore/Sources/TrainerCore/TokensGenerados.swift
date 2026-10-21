// =============================================================================
// GENERADO por scripts/generar-tema.mjs desde shared/design/tokens.json
// NO EDITAR A MANO: se reescribe en cada `npm run generar:tema`, y el CI falla
// si el archivo commiteado no coincide con lo que el generador produce.
//
// tokens.json version 0.6.0 · extraído el 2026-09-08
//
// AGENTS.md §10.1: ningún color, tamaño, radio ni fuente se escribe a mano en una
// pantalla. Todo sale de acá. Un #FF5722 suelto en un .kt es el principio de que
// Android e iOS dejen de parecerse, y nadie lo va a ver hasta tener las dos
// capturas al lado. `scripts/verificar-tokens.mjs` lo hace fallar en CI.
//
// ⚠️ El diseño es ÚNICAMENTE OSCURO. No existe tema claro (pendientes[tema-claro]).
// =============================================================================

import SwiftUI

/// Colores del diseño, con el alfa ya aplicado.
public enum TokensColor {
    /// procedencia: reloj
    public static let datosSerie1 = Color(.sRGB, red: 0.2667, green: 0.8392, blue: 0.1725, opacity: 1)
    /// procedencia: reloj
    public static let datosSerie2 = Color(.sRGB, red: 0.2667, green: 0.0000, blue: 0.6000, opacity: 1)
    /// procedencia: reloj
    public static let datosSerie3 = Color(.sRGB, red: 0.5490, green: 0.3216, blue: 1.0000, opacity: 1)
    /// procedencia: app · 2026-10-21: el segundo tramo del medidor de la contrasena (amarillo).
    public static let estadoAdvertencia = Color(.sRGB, red: 1.0000, green: 0.8000, blue: 0.0000, opacity: 1)
    /// procedencia: app · 2026-10-21 (Ivan): los textos que se tocan (terminos, privacidad) van en celeste, no en el rosa del acento. Sobre el fondo negro da 10.6:1.
    public static let estadoEnlace = Color(.sRGB, red: 0.3529, green: 0.7843, blue: 0.9804, opacity: 1)
    /// procedencia: app · El celeste para el tema claro: #5AC8FA sobre blanco no llega a 4.5:1; este da 5.6:1.
    public static let estadoEnlaceClaro = Color(.sRGB, red: 0.0000, green: 0.4392, blue: 0.6588, opacity: 1)
    /// procedencia: app · 2026-10-21 (Ivan): rojo fuerte, #FF0000. Antes rgba(255,140,120,.9). Sobre el fondo negro da 5.25:1.
    public static let estadoError = Color(.sRGB, red: 1.0000, green: 0.0000, blue: 0.0000, opacity: 1)
    /// procedencia: home reloj
    public static let estadoErrorBorde = Color(.sRGB, red: 1.0000, green: 0.0000, blue: 0.0000, opacity: 0.4)
    /// procedencia: home reloj
    public static let estadoErrorFondo = Color(.sRGB, red: 1.0000, green: 0.0000, blue: 0.0000, opacity: 0.14)
    /// procedencia: app · 2026-10-21: el tercer tramo del medidor de la contrasena (verde). El acento sigue haciendo de 'hecho' en el resto de la app.
    public static let estadoExito = Color(.sRGB, red: 0.2039, green: 0.7804, blue: 0.3490, opacity: 1)
    /// procedencia: app home reloj · Pantone 802 C. Expuesto como variable CSS --ac / --ac-rgb y como parametro 'accent' del tablero. Ver parametros_del_tablero.accent.
    public static let marcaAcento = Color(.sRGB, red: 1.0000, green: 0.1373, blue: 0.6549, opacity: 1)
    /// procedencia: app · Relleno del boton primario DESHABILITADO.
    public static let marcaAcentoApagado = Color(.sRGB, red: 1.0000, green: 0.1373, blue: 0.6549, opacity: 0.35)
    /// procedencia: app home reloj
    public static let marcaAcentoChipActivo = Color(.sRGB, red: 1.0000, green: 0.1373, blue: 0.6549, opacity: 0.14)
    /// procedencia: app home
    public static let marcaAcentoSuaveBorde = Color(.sRGB, red: 1.0000, green: 0.1373, blue: 0.6549, opacity: 0.25)
    /// procedencia: app home
    public static let marcaAcentoSuaveFondo = Color(.sRGB, red: 1.0000, green: 0.1373, blue: 0.6549, opacity: 0.08)
    /// procedencia: app home reloj · Pantone Violet C. Color secundario de la app.
    public static let marcaSecundario = Color(.sRGB, red: 0.2667, green: 0.0000, blue: 0.6000, opacity: 1)
    /// procedencia: app home reloj
    public static let marcaSecundarioSuaveBorde = Color(.sRGB, red: 0.2667, green: 0.0000, blue: 0.6000, opacity: 0.35)
    /// procedencia: app home reloj
    public static let marcaSecundarioSuaveFondo = Color(.sRGB, red: 0.2667, green: 0.0000, blue: 0.6000, opacity: 0.15)
    /// procedencia: app home
    public static let marcaSobreAcento = Color(.sRGB, red: 0.0431, green: 0.0471, blue: 0.0392, opacity: 1)
    /// procedencia: app
    public static let proveedorAppleBordeOscuro = Color(.sRGB, red: 0.5569, green: 0.5686, blue: 0.5608, opacity: 1)
    /// procedencia: app
    public static let proveedorAppleFondo = Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1)
    /// procedencia: app
    public static let proveedorAppleFondoOscuro = Color(.sRGB, red: 0.0745, green: 0.0745, blue: 0.0784, opacity: 1)
    /// procedencia: app
    public static let proveedorAppleTexto = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1)
    /// procedencia: app
    public static let proveedorAppleTextoOscuro = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1)
    /// procedencia: app
    public static let proveedorGoogleBorde = Color(.sRGB, red: 0.4549, green: 0.4667, blue: 0.4588, opacity: 1)
    /// procedencia: app
    public static let proveedorGoogleBordeOscuro = Color(.sRGB, red: 0.5569, green: 0.5686, blue: 0.5608, opacity: 1)
    /// procedencia: app
    public static let proveedorGoogleFondo = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1)
    /// procedencia: app
    public static let proveedorGoogleFondoOscuro = Color(.sRGB, red: 0.0745, green: 0.0745, blue: 0.0784, opacity: 1)
    /// procedencia: app
    public static let proveedorGoogleTexto = Color(.sRGB, red: 0.1216, green: 0.1216, blue: 0.1216, opacity: 1)
    /// procedencia: app
    public static let proveedorGoogleTextoOscuro = Color(.sRGB, red: 0.8902, green: 0.8902, blue: 0.8902, opacity: 1)
    /// procedencia: reloj
    public static let relojAcentoSuave = Color(.sRGB, red: 0.2667, green: 0.8392, blue: 0.1725, opacity: 0.12)
    /// procedencia: reloj
    public static let relojBordeSuperficie = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.12)
    /// procedencia: reloj · Fondo negro puro OLED.
    public static let relojFondo = Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1)
    /// procedencia: reloj · Superficie de tarjetas.
    public static let relojSuperficie = Color(.sRGB, red: 0.0824, green: 0.0902, blue: 0.0588, opacity: 1)
    /// procedencia: reloj
    public static let relojSuperficieAlterna = Color(.sRGB, red: 0.1333, green: 0.1451, blue: 0.1059, opacity: 1)
    /// procedencia: reloj
    public static let relojSuperficieOverlay = Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 0.72)
    /// procedencia: reloj
    public static let relojTextoPrimario = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 1)
    /// procedencia: reloj
    public static let relojTextoSecundario = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 0.5)
    /// procedencia: app home
    public static let telefonoBordeBotonSecundario = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.14)
    /// procedencia: app home reloj
    public static let telefonoBordeInput = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.12)
    /// procedencia: gym
    public static let telefonoBordeSignificante = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.38)
    /// procedencia: app home
    public static let telefonoBordeSuperficie = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.09)
    /// procedencia: app home
    public static let telefonoDivisor = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.07)
    /// procedencia: app home reloj
    public static let telefonoFondo = Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1)
    /// procedencia: app home reloj · Card. El fondo mas usado del producto.
    public static let telefonoSuperficie = Color(.sRGB, red: 0.0745, green: 0.0824, blue: 0.0667, opacity: 1)
    /// procedencia: home
    public static let telefonoSuperficieAlterna = Color(.sRGB, red: 0.1098, green: 0.1176, blue: 0.0941, opacity: 1)
    /// procedencia: home · Tab bar.
    public static let telefonoSuperficieBarra = Color(.sRGB, red: 0.0431, green: 0.0471, blue: 0.0392, opacity: 1)
    /// procedencia: home gym · Relleno de boton secundario (los -/+ de los steppers). Mismo valor que 'divisor' pero otro rol: uno es relleno y el otro es linea.
    public static let telefonoSuperficieControl = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.07)
    /// procedencia: home · Extremo claro del degradado de la card de sesion.
    public static let telefonoSuperficieDestacada = Color(.sRGB, red: 0.1451, green: 0.1569, blue: 0.1255, opacity: 1)
    /// procedencia: home gym · Relleno de un control apoyado sobre una card: chip pendiente, campo numerico. NO es un borde.
    public static let telefonoSuperficieHundida = Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.04)
    /// procedencia: app
    public static let telefonoSuperficieInput = Color(.sRGB, red: 0.0824, green: 0.0902, blue: 0.0706, opacity: 1)
    /// procedencia: home · Hoja inferior.
    public static let telefonoSuperficieOverlay = Color(.sRGB, red: 0.0745, green: 0.0824, blue: 0.0667, opacity: 0.94)
    /// procedencia: gym · Cuerpo largo dentro de card. Es el escalon que faltaba entre texto_primario (1) y texto_secundario (.6).
    public static let telefonoTextoCuerpo = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 0.85)
    /// procedencia: app
    public static let telefonoTextoDeshabilitado = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 0.34)
    /// procedencia: app
    public static let telefonoTextoPlaceholder = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 0.32)
    /// procedencia: app home reloj
    public static let telefonoTextoPrimario = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 1)
    /// procedencia: app home reloj
    public static let telefonoTextoSecundario = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 0.6)
    /// procedencia: app home reloj
    public static let telefonoTextoTerciario = Color(.sRGB, red: 0.9490, green: 0.9569, blue: 0.9412, opacity: 0.5)
    /// procedencia: home gym · Fondo oscurecido detras de una hoja inferior.
    public static let telefonoVelo = Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 0.78)
}

/// Escala tipográfica medida en el diseño.
public enum TokensTipografia {
    public static let tituloBienvenidaTamano: CGFloat = 29
    public static let tituloBienvenidaPeso: Font.Weight = .semibold
    public static let tituloBienvenidaInterlineado: CGFloat = 31.9
    public static let tituloBienvenidaEspaciadoLetras: CGFloat = -0.87
    public static let tituloPantallaTamano: CGFloat = 25
    public static let tituloPantallaPeso: Font.Weight = .semibold
    public static let tituloPantallaInterlineado: CGFloat = 30
    public static let tituloPantallaEspaciadoLetras: CGFloat = -0.75
    public static let numeroGrandeTamano: CGFloat = 30
    public static let numeroGrandePeso: Font.Weight = .bold
    public static let numeroGrandeInterlineado: CGFloat = 30
    public static let numeroGrandeEspaciadoLetras: CGFloat = -0.9
    public static let tituloCardTamano: CGFloat = 13
    public static let tituloCardPeso: Font.Weight = .semibold
    public static let cuerpoTamano: CGFloat = 13
    public static let cuerpoPeso: Font.Weight = .regular
    public static let cuerpoInterlineado: CGFloat = 20.15
    public static let cuerpoSecundarioTamano: CGFloat = 12.5
    public static let cuerpoSecundarioPeso: Font.Weight = .regular
    public static let cuerpoSecundarioInterlineado: CGFloat = 18.75
    public static let labelCampoTamano: CGFloat = 11.5
    public static let labelCampoPeso: Font.Weight = .regular
    public static let etiquetaSeccionTamano: CGFloat = 10
    public static let etiquetaSeccionPeso: Font.Weight = .semibold
    public static let etiquetaSeccionEspaciadoLetras: CGFloat = 1.4
    public static let etiquetaSeccionMayusculas: Bool = true
    public static let labelNavegacionTamano: CGFloat = 9.5
    public static let labelNavegacionPeso: Font.Weight = .semibold
    public static let tituloEjercicioTamano: CGFloat = 19
    public static let tituloEjercicioPeso: Font.Weight = .semibold
    public static let tituloEjercicioInterlineado: CGFloat = 22.8
    public static let tituloEjercicioEspaciadoLetras: CGFloat = -0.38
    public static let valorDatoTamano: CGFloat = 16
    public static let valorDatoPeso: Font.Weight = .bold
    public static let valorDatoInterlineado: CGFloat = 19.2
    public static let valorDatoEspaciadoLetras: CGFloat = -0.32
    public static let valorFilaTamano: CGFloat = 14
    public static let valorFilaPeso: Font.Weight = .semibold
    public static let chipTamano: CGFloat = 11
    public static let chipPeso: Font.Weight = .semibold
    public static let chipInterlineado: CGFloat = 14.85
    public static let notaTamano: CGFloat = 11
    public static let notaPeso: Font.Weight = .regular
    public static let notaInterlineado: CGFloat = 14.3
    public static let cronometroTamano: CGFloat = 38
    public static let cronometroPeso: Font.Weight = .bold
    public static let cronometroInterlineado: CGFloat = 38
    public static let cronometroEspaciadoLetras: CGFloat = -1.52
    public static let teclaTamano: CGFloat = 21
    public static let teclaPeso: Font.Weight = .semibold
    public static let marcaTamano: CGFloat = 22
    public static let marcaPeso: Font.Weight = .bold
    public static let marcaEspaciadoLetras: CGFloat = -0.44
    public static let codigoTamano: CGFloat = 27
    public static let codigoPeso: Font.Weight = .semibold
    public static let codigoEspaciadoLetras: CGFloat = 9.72
    public static let tituloConfirmacionTamano: CGFloat = 28
    public static let tituloConfirmacionPeso: Font.Weight = .semibold
    public static let tituloConfirmacionInterlineado: CGFloat = 32.2
    public static let tituloConfirmacionEspaciadoLetras: CGFloat = -0.84
    public static let numeroDatoTamano: CGFloat = 38
    public static let numeroDatoPeso: Font.Weight = .bold
    public static let numeroDatoInterlineado: CGFloat = 38
    public static let numeroDatoEspaciadoLetras: CGFloat = -1.52
    public static let tituloCardGrandeTamano: CGFloat = 17
    public static let tituloCardGrandePeso: Font.Weight = .semibold
    public static let tituloCardGrandeEspaciadoLetras: CGFloat = -0.34
    public static let campoNumeroTamano: CGFloat = 20
    public static let campoNumeroPeso: Font.Weight = .semibold
    public static let campoTextoTamano: CGFloat = 15
    public static let campoTextoPeso: Font.Weight = .regular
    public static let botonPrimarioTamano: CGFloat = 14.5
    public static let botonPrimarioPeso: Font.Weight = .bold
    public static let botonGrandeTamano: CGFloat = 17
    public static let botonGrandePeso: Font.Weight = .bold
    public static let opcionTituloTamano: CGFloat = 14
    public static let opcionTituloPeso: Font.Weight = .semibold
    public static let cuerpoDestacadoTamano: CGFloat = 13.5
    public static let cuerpoDestacadoPeso: Font.Weight = .regular
    public static let cuerpoDestacadoInterlineado: CGFloat = 20.25
    public static let notaLegalTamano: CGFloat = 11
    public static let notaLegalPeso: Font.Weight = .regular
    public static let notaLegalInterlineado: CGFloat = 16.5
    public static let displayTamano: CGFloat = 34
    public static let displayPeso: Font.Weight = .heavy
    public static let displayInterlineado: CGFloat = 35.7
    public static let displayEspaciadoLetras: CGFloat = -1.19
    public static let metricaHeroeTamano: CGFloat = 64
    public static let metricaHeroePeso: Font.Weight = .heavy
    public static let metricaHeroeInterlineado: CGFloat = 64
    public static let metricaHeroeEspaciadoLetras: CGFloat = -2.88
    public static let unidadHeroeTamano: CGFloat = 22
    public static let unidadHeroePeso: Font.Weight = .bold
    public static let unidadHeroeEspaciadoLetras: CGFloat = -0.44
    public static let metricaMediaTamano: CGFloat = 20
    public static let metricaMediaPeso: Font.Weight = .bold
    public static let metricaMediaInterlineado: CGFloat = 20
    public static let metricaMediaEspaciadoLetras: CGFloat = -0.4
    public static let tituloSeccionTamano: CGFloat = 17
    public static let tituloSeccionPeso: Font.Weight = .bold
    public static let tituloSeccionEspaciadoLetras: CGFloat = -0.34
    public static let relojCronometroTamano: CGFloat = 62
    public static let relojCronometroPeso: Font.Weight = .bold
    public static let relojCronometroInterlineado: CGFloat = 62
    public static let relojCronometroEspaciadoLetras: CGFloat = -2.79
    public static let relojMetricaTamano: CGFloat = 46
    public static let relojMetricaPeso: Font.Weight = .bold
    public static let relojMetricaInterlineado: CGFloat = 46
    public static let relojMetricaEspaciadoLetras: CGFloat = -1.84
    public static let relojTituloAvisoTamano: CGFloat = 34
    public static let relojTituloAvisoPeso: Font.Weight = .bold
    public static let relojTituloAvisoInterlineado: CGFloat = 35.7
    public static let relojTituloAvisoEspaciadoLetras: CGFloat = -1.02
    public static let relojEstadoTamano: CGFloat = 28
    public static let relojEstadoPeso: Font.Weight = .bold
    public static let relojEstadoEspaciadoLetras: CGFloat = -0.84
    public static let relojBotonTamano: CGFloat = 16
    public static let relojBotonPeso: Font.Weight = .bold
    public static let relojUnidadTamano: CGFloat = 15
    public static let relojUnidadPeso: Font.Weight = .medium
    public static let relojUnidadInterlineado: CGFloat = 17.25
    public static let relojCuerpoTamano: CGFloat = 14
    public static let relojCuerpoPeso: Font.Weight = .medium
    public static let relojCuerpoInterlineado: CGFloat = 19.6
    public static let relojEtiquetaTamano: CGFloat = 13
    public static let relojEtiquetaPeso: Font.Weight = .bold
    public static let relojEtiquetaEspaciadoLetras: CGFloat = 1.3
    public static let relojEtiquetaMayusculas: Bool = true
}

/// Radios de esquina.
public enum TokensRadio {
    public static let minimo: CGFloat = 2
    public static let celda: CGFloat = 9
    public static let chip: CGFloat = 11
    public static let input: CGFloat = 12
    public static let boton: CGFloat = 14
    public static let card: CGFloat = 18
    public static let cardDestacada: CGFloat = 20
    public static let pill: CGFloat = 999
}

/// Espaciado: la escala MEDIDA, transcripta. No es una escala consolidada
/// (pendientes[escala-espaciado]).
public enum TokensEspaciado {
    public static let e1: CGFloat = 1
    public static let e2: CGFloat = 2
    public static let e3: CGFloat = 3
    public static let e4: CGFloat = 4
    public static let e5: CGFloat = 5
    public static let e6: CGFloat = 6
    public static let e7: CGFloat = 7
    public static let e8: CGFloat = 8
    public static let e9: CGFloat = 9
    public static let e10: CGFloat = 10
    public static let e11: CGFloat = 11
    public static let e12: CGFloat = 12
    public static let e13: CGFloat = 13
    public static let e14: CGFloat = 14
    public static let e16: CGFloat = 16
    public static let e20: CGFloat = 20
    public static let e22: CGFloat = 22
    public static let e26: CGFloat = 26
    public static let e34: CGFloat = 34
    public static let e36: CGFloat = 36
    public static let e40: CGFloat = 40
    public static let e44: CGFloat = 44
    public static let e52: CGFloat = 52
    public static let e56: CGFloat = 56
}

/// Duraciones de animación, en segundos (SwiftUI trabaja en segundos).
public enum TokensMovimiento {
    public static let rapida: Double = 0.200
    public static let media: Double = 0.350
    public static let lenta: Double = 0.400
    public static let muyLenta: Double = 0.900
}

/// 🛑 Objetivo táctil mínimo. AGENTS.md §10.1, sin excepciones.
public enum TokensTamano {
    public static let objetivoTactilMinimo: CGFloat = 48
    public static let botonPrimario: CGFloat = 49
    public static let itemRuedaFecha: CGFloat = 46
    public static let chipDia: CGFloat = 41
    public static let celdaCalendario: CGFloat = 34
    public static let botonCircularCalendario: CGFloat = 30
    public static let switchAjustes: CGFloat = 26
    public static let botonRelojMasMenos: CGFloat = 38
    public static let botonRelojCircular: CGFloat = 32
}

/// Los alfa con los que el acento se deriva a sí mismo.
///
/// 🛑 El VALOR del acento **no** está acá: vive en el catálogo de assets de la
/// app (Assets.xcassets/AccentColor.colorset), para poder cambiarlo desde Xcode.
/// Estos son los alfa que Paleta le aplica encima, y salen de tokens.json para
/// que Android e iOS deriven igual.
public enum TokensAcento {
    /// El valor de tokens.json. Es el RESPALDO: se usa si el catálogo de assets
    /// no está disponible (previews del paquete, tests fuera de la app).
    public static let respaldo = Color(.sRGB, red: 1.0000, green: 0.1373, blue: 0.6549, opacity: 1)
    /// El nombre del color en el catálogo de assets.
    public static let nombreEnAssets = "AccentColor"
    public static let alfaApagado: Double = 0.35
    public static let alfaChipActivo: Double = 0.14
    public static let alfaSuaveBorde: Double = 0.25
    public static let alfaSuaveFondo: Double = 0.08
}

/// Lo que tokens.json declara PENDIENTE.
public enum TokensPendientes {
    public static let lista: [String] = [
        "tema-claro: No existe tema claro; el diseno canonico es solo oscuro.",
        "color-exito: No hay color de exito propio; se usa el acento, que tambien significa 'tocable'.",
        "color-advertencia: No hay color de advertencia ni de informacion.",
        "unidades-dp-pt: El diseno esta en px CSS. Falta la regla de conversion a dp/pt y que hacer con los medios pixeles.",
        "escala-tipografica: 34 tamanos, no modular, con medios pixeles.",
        "escala-espaciado: 24 gaps distintos, casi continuos.",
        "tipografia-escalada: Ninguna definicion de como responde el diseno a Dynamic Type / fontScale.",
        "objetivo-tactil-reloj: El minimo tactil del RELOJ no esta fijado. AGENTS.md 10.1 dice '48dp / 44pt' sin separar plataformas y el diseno del reloj usa 44. El del telefono ya esta fijado en 48 (ver tamano_control.objetivo_tactil_minimo).",
        "fuente-empaquetada: Archivo se carga de Google Fonts por red.",
        "set-de-iconos: El propio tablero lo declara pendiente. Hay SVG en 'home' y 'reloj' pero sin set nombrado ni versionado.",
        "estados-de-control: Solo existe 'deshabilitado' (opacity .35). No hay pressed, ni foco visible, ni loading por componente.",
        "escala-overlay-reloj: El reloj usa negro al 30/35/70/72/88% sin criterio nombrado.",
        "modo-ambient: El modo ambient del reloj baja TODA la pantalla a opacity .45.",
        "movimiento-reducido: No hay regla para prefers-reduced-motion.",
        "generador: RESUELTO el 2026-09-08: scripts/generar-tema.mjs emite el tema de Compose y el de SwiftUI desde este archivo. Se corre con `npm run generar:tema` y el CI verifica que lo commiteado coincida. El generador de MODELOS DE RED desde shared/api/openapi.yaml ya existe para SWIFT: scripts/generar-modelos-swift.mjs, `npm run generar:modelos`, con su verificacion de no-diff en CI. Falta el de KOTLIN, que se hace en la fase 6."
    ]
}
