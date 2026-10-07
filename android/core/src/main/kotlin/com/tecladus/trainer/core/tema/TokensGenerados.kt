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

package com.tecladus.trainer.core.tema

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em

/**
 * Colores del diseño, con el alfa ya compuesto en el canal A.
 *
 * `marcaAcento` es el DEFAULT del parámetro `accent` del tablero
 * (tokens.json → parametros_del_tablero.accent). Es UN token: cambiarlo en
 * tokens.json y regenerar cambia el producto entero desde un solo lugar. Ninguna
 * pantalla lo escribe a mano.
 */
object TokensColor {
    /** procedencia: reloj */
    val datosSerie1: Color = Color(0xFF44D62C)
    /** procedencia: reloj */
    val datosSerie2: Color = Color(0xFF440099)
    /** procedencia: reloj */
    val datosSerie3: Color = Color(0xFF8C52FF)
    /** procedencia: app · rgba(255,140,120,.9). Unico rol de estado con color propio. */
    val estadoError: Color = Color(0xE6FF8C78)
    /** procedencia: home reloj */
    val estadoErrorBorde: Color = Color(0x66FF8C78)
    /** procedencia: home reloj */
    val estadoErrorFondo: Color = Color(0x24FF8C78)
    /** procedencia: app home reloj · Pantone 802 C. Expuesto como variable CSS --ac / --ac-rgb y como parametro 'accent' del tablero. Ver parametros_del_tablero.accent. */
    val marcaAcento: Color = Color(0xFF44D62C)
    /** procedencia: app · Relleno del boton primario DESHABILITADO. */
    val marcaAcentoApagado: Color = Color(0x5944D62C)
    /** procedencia: app home reloj */
    val marcaAcentoChipActivo: Color = Color(0x2444D62C)
    /** procedencia: app home */
    val marcaAcentoSuaveBorde: Color = Color(0x4044D62C)
    /** procedencia: app home */
    val marcaAcentoSuaveFondo: Color = Color(0x1444D62C)
    /** procedencia: app home reloj · Pantone Violet C. Color secundario de la app. */
    val marcaSecundario: Color = Color(0xFF440099)
    /** procedencia: app home reloj */
    val marcaSecundarioSuaveBorde: Color = Color(0x59440099)
    /** procedencia: app home reloj */
    val marcaSecundarioSuaveFondo: Color = Color(0x26440099)
    /** procedencia: app home */
    val marcaSobreAcento: Color = Color(0xFF0B0C0A)
    /** procedencia: app */
    val proveedorAppleFondo: Color = Color(0xFF000000)
    /** procedencia: app */
    val proveedorAppleTexto: Color = Color(0xFFFFFFFF)
    /** procedencia: app */
    val proveedorGoogleBorde: Color = Color(0xFF747775)
    /** procedencia: app */
    val proveedorGoogleFondo: Color = Color(0xFFFFFFFF)
    /** procedencia: app */
    val proveedorGoogleTexto: Color = Color(0xFF1F1F1F)
    /** procedencia: reloj */
    val relojAcentoSuave: Color = Color(0x1F44D62C)
    /** procedencia: reloj */
    val relojBordeSuperficie: Color = Color(0x1FFFFFFF)
    /** procedencia: reloj · Fondo negro puro OLED. */
    val relojFondo: Color = Color(0xFF000000)
    /** procedencia: reloj · Superficie de tarjetas. */
    val relojSuperficie: Color = Color(0xFF15170F)
    /** procedencia: reloj */
    val relojSuperficieAlterna: Color = Color(0xFF22251B)
    /** procedencia: reloj */
    val relojSuperficieOverlay: Color = Color(0xB8000000)
    /** procedencia: reloj */
    val relojTextoPrimario: Color = Color(0xFFF2F4F0)
    /** procedencia: reloj */
    val relojTextoSecundario: Color = Color(0x80F2F4F0)
    /** procedencia: app home */
    val telefonoBordeBotonSecundario: Color = Color(0x24FFFFFF)
    /** procedencia: app home reloj */
    val telefonoBordeInput: Color = Color(0x1FFFFFFF)
    /** procedencia: gym */
    val telefonoBordeSignificante: Color = Color(0x61FFFFFF)
    /** procedencia: app home */
    val telefonoBordeSuperficie: Color = Color(0x17FFFFFF)
    /** procedencia: app home */
    val telefonoDivisor: Color = Color(0x12FFFFFF)
    /** procedencia: app home reloj */
    val telefonoFondo: Color = Color(0xFF000000)
    /** procedencia: app home reloj · Card. El fondo mas usado del producto. */
    val telefonoSuperficie: Color = Color(0xFF131511)
    /** procedencia: home */
    val telefonoSuperficieAlterna: Color = Color(0xFF1C1E18)
    /** procedencia: home · Tab bar. */
    val telefonoSuperficieBarra: Color = Color(0xFF0B0C0A)
    /** procedencia: home gym · Relleno de boton secundario (los -/+ de los steppers). Mismo valor que 'divisor' pero otro rol: uno es relleno y el otro es linea. */
    val telefonoSuperficieControl: Color = Color(0x12FFFFFF)
    /** procedencia: home · Extremo claro del degradado de la card de sesion. */
    val telefonoSuperficieDestacada: Color = Color(0xFF252820)
    /** procedencia: home gym · Relleno de un control apoyado sobre una card: chip pendiente, campo numerico. NO es un borde. */
    val telefonoSuperficieHundida: Color = Color(0x0AFFFFFF)
    /** procedencia: app */
    val telefonoSuperficieInput: Color = Color(0xFF151712)
    /** procedencia: home · Hoja inferior. */
    val telefonoSuperficieOverlay: Color = Color(0xF0131511)
    /** procedencia: gym · Cuerpo largo dentro de card. Es el escalon que faltaba entre texto_primario (1) y texto_secundario (.6). */
    val telefonoTextoCuerpo: Color = Color(0xD9F2F4F0)
    /** procedencia: app */
    val telefonoTextoDeshabilitado: Color = Color(0x57F2F4F0)
    /** procedencia: app */
    val telefonoTextoPlaceholder: Color = Color(0x52F2F4F0)
    /** procedencia: app home reloj */
    val telefonoTextoPrimario: Color = Color(0xFFF2F4F0)
    /** procedencia: app home reloj */
    val telefonoTextoSecundario: Color = Color(0x99F2F4F0)
    /** procedencia: app home reloj */
    val telefonoTextoTerciario: Color = Color(0x80F2F4F0)
    /** procedencia: home gym · Fondo oscurecido detras de una hoja inferior. */
    val telefonoVelo: Color = Color(0xC7000000)
}

/** Escala tipográfica medida en el diseño. Los tamaños van en sp: escalan con el sistema. */
object TokensTipografia {
    val tituloBienvenidaTamano: TextUnit = 29.sp
    val tituloBienvenidaPeso: FontWeight = FontWeight(600)
    val tituloBienvenidaInterlineado: TextUnit = 31.9.sp
    val tituloBienvenidaEspaciadoLetras: TextUnit = (-0.03).em
    val tituloPantallaTamano: TextUnit = 25.sp
    val tituloPantallaPeso: FontWeight = FontWeight(600)
    val tituloPantallaInterlineado: TextUnit = 30.sp
    val tituloPantallaEspaciadoLetras: TextUnit = (-0.03).em
    val numeroGrandeTamano: TextUnit = 30.sp
    val numeroGrandePeso: FontWeight = FontWeight(700)
    val numeroGrandeInterlineado: TextUnit = 30.sp
    val numeroGrandeEspaciadoLetras: TextUnit = (-0.03).em
    val tituloCardTamano: TextUnit = 13.sp
    val tituloCardPeso: FontWeight = FontWeight(600)
    val cuerpoTamano: TextUnit = 13.sp
    val cuerpoPeso: FontWeight = FontWeight(400)
    val cuerpoInterlineado: TextUnit = 20.15.sp
    val cuerpoSecundarioTamano: TextUnit = 12.5.sp
    val cuerpoSecundarioPeso: FontWeight = FontWeight(400)
    val cuerpoSecundarioInterlineado: TextUnit = 18.75.sp
    val labelCampoTamano: TextUnit = 11.5.sp
    val labelCampoPeso: FontWeight = FontWeight(400)
    val etiquetaSeccionTamano: TextUnit = 10.sp
    val etiquetaSeccionPeso: FontWeight = FontWeight(600)
    val etiquetaSeccionEspaciadoLetras: TextUnit = (0.14).em
    val etiquetaSeccionMayusculas: Boolean = true
    val labelNavegacionTamano: TextUnit = 9.5.sp
    val labelNavegacionPeso: FontWeight = FontWeight(600)
    val tituloEjercicioTamano: TextUnit = 19.sp
    val tituloEjercicioPeso: FontWeight = FontWeight(600)
    val tituloEjercicioInterlineado: TextUnit = 22.8.sp
    val tituloEjercicioEspaciadoLetras: TextUnit = (-0.02).em
    val valorDatoTamano: TextUnit = 16.sp
    val valorDatoPeso: FontWeight = FontWeight(700)
    val valorDatoInterlineado: TextUnit = 19.2.sp
    val valorDatoEspaciadoLetras: TextUnit = (-0.02).em
    val valorFilaTamano: TextUnit = 14.sp
    val valorFilaPeso: FontWeight = FontWeight(600)
    val chipTamano: TextUnit = 11.sp
    val chipPeso: FontWeight = FontWeight(600)
    val chipInterlineado: TextUnit = 14.85.sp
    val notaTamano: TextUnit = 11.sp
    val notaPeso: FontWeight = FontWeight(400)
    val notaInterlineado: TextUnit = 14.3.sp
    val cronometroTamano: TextUnit = 38.sp
    val cronometroPeso: FontWeight = FontWeight(700)
    val cronometroInterlineado: TextUnit = 38.sp
    val cronometroEspaciadoLetras: TextUnit = (-0.04).em
    val teclaTamano: TextUnit = 21.sp
    val teclaPeso: FontWeight = FontWeight(600)
    val marcaTamano: TextUnit = 22.sp
    val marcaPeso: FontWeight = FontWeight(700)
    val marcaEspaciadoLetras: TextUnit = (-0.02).em
    val codigoTamano: TextUnit = 27.sp
    val codigoPeso: FontWeight = FontWeight(600)
    val codigoEspaciadoLetras: TextUnit = (0.36).em
    val tituloConfirmacionTamano: TextUnit = 28.sp
    val tituloConfirmacionPeso: FontWeight = FontWeight(600)
    val tituloConfirmacionInterlineado: TextUnit = 32.2.sp
    val tituloConfirmacionEspaciadoLetras: TextUnit = (-0.03).em
    val numeroDatoTamano: TextUnit = 38.sp
    val numeroDatoPeso: FontWeight = FontWeight(700)
    val numeroDatoInterlineado: TextUnit = 38.sp
    val numeroDatoEspaciadoLetras: TextUnit = (-0.04).em
    val tituloCardGrandeTamano: TextUnit = 17.sp
    val tituloCardGrandePeso: FontWeight = FontWeight(600)
    val tituloCardGrandeEspaciadoLetras: TextUnit = (-0.02).em
    val campoNumeroTamano: TextUnit = 20.sp
    val campoNumeroPeso: FontWeight = FontWeight(600)
    val campoTextoTamano: TextUnit = 15.sp
    val campoTextoPeso: FontWeight = FontWeight(400)
    val botonPrimarioTamano: TextUnit = 14.5.sp
    val botonPrimarioPeso: FontWeight = FontWeight(600)
    val opcionTituloTamano: TextUnit = 14.sp
    val opcionTituloPeso: FontWeight = FontWeight(600)
    val cuerpoDestacadoTamano: TextUnit = 13.5.sp
    val cuerpoDestacadoPeso: FontWeight = FontWeight(400)
    val cuerpoDestacadoInterlineado: TextUnit = 20.25.sp
    val notaLegalTamano: TextUnit = 11.sp
    val notaLegalPeso: FontWeight = FontWeight(400)
    val notaLegalInterlineado: TextUnit = 16.5.sp
    val relojCronometroTamano: TextUnit = 62.sp
    val relojCronometroPeso: FontWeight = FontWeight(700)
    val relojCronometroInterlineado: TextUnit = 62.sp
    val relojCronometroEspaciadoLetras: TextUnit = (-0.045).em
    val relojMetricaTamano: TextUnit = 46.sp
    val relojMetricaPeso: FontWeight = FontWeight(700)
    val relojMetricaInterlineado: TextUnit = 46.sp
    val relojMetricaEspaciadoLetras: TextUnit = (-0.04).em
    val relojTituloAvisoTamano: TextUnit = 34.sp
    val relojTituloAvisoPeso: FontWeight = FontWeight(700)
    val relojTituloAvisoInterlineado: TextUnit = 35.7.sp
    val relojTituloAvisoEspaciadoLetras: TextUnit = (-0.03).em
    val relojEstadoTamano: TextUnit = 28.sp
    val relojEstadoPeso: FontWeight = FontWeight(700)
    val relojEstadoEspaciadoLetras: TextUnit = (-0.03).em
    val relojBotonTamano: TextUnit = 16.sp
    val relojBotonPeso: FontWeight = FontWeight(700)
    val relojUnidadTamano: TextUnit = 15.sp
    val relojUnidadPeso: FontWeight = FontWeight(500)
    val relojUnidadInterlineado: TextUnit = 17.25.sp
    val relojCuerpoTamano: TextUnit = 14.sp
    val relojCuerpoPeso: FontWeight = FontWeight(500)
    val relojCuerpoInterlineado: TextUnit = 19.6.sp
    val relojEtiquetaTamano: TextUnit = 13.sp
    val relojEtiquetaPeso: FontWeight = FontWeight(700)
    val relojEtiquetaEspaciadoLetras: TextUnit = (0.1).em
    val relojEtiquetaMayusculas: Boolean = true

    /**
     * ⚠️ El diseño usa 34 tamaños distintos, con medios píxeles.
     * NO es una escala modular (pendientes[escala-tipografica]). Portado tal cual a
     * cuatro plataformas se vuelve insostenible: hay que consolidarlo antes de que
     * esto se use en más de una pantalla.
     */
    val ADVERTENCIA_ESCALA = "34 tamanos distintos, con medios pixeles (9.5, 12.5, 14.5). NO es una escala modular. Portado tal cual a cuatro plataformas se vuelve insostenible."
}

/** Radios de esquina. Los del marco del teléfono y del reloj NO se portan. */
object TokensRadio {
    val minimo: Dp = 2.dp
    val celda: Dp = 9.dp
    val chip: Dp = 11.dp
    val input: Dp = 12.dp
    val boton: Dp = 14.dp
    val card: Dp = 18.dp
    val cardDestacada: Dp = 20.dp
    val pill: Dp = 999.dp
}

/**
 * Espaciado. Es la escala MEDIDA en el diseño, transcripta tal cual y nombrada por
 * su valor — NO una escala consolidada.
 *
 * ⚠️ El diseño usa 24 gaps distintos, casi continuos.
 * Consolidarlos es una decisión de diseño que NO está tomada
 * (pendientes[escala-espaciado]) y este generador no la inventa. Existe acá para
 * que ninguna pantalla tenga que escribir un `12.dp` a mano mientras tanto.
 */
object TokensEspaciado {
    val e1: Dp = 1.dp
    val e2: Dp = 2.dp
    val e3: Dp = 3.dp
    val e4: Dp = 4.dp
    val e5: Dp = 5.dp
    val e6: Dp = 6.dp
    val e7: Dp = 7.dp
    val e8: Dp = 8.dp
    val e9: Dp = 9.dp
    val e10: Dp = 10.dp
    val e11: Dp = 11.dp
    val e12: Dp = 12.dp
    val e13: Dp = 13.dp
    val e14: Dp = 14.dp
    val e16: Dp = 16.dp
    val e20: Dp = 20.dp
    val e22: Dp = 22.dp
    val e26: Dp = 26.dp
    val e34: Dp = 34.dp
    val e36: Dp = 36.dp
    val e40: Dp = 40.dp
    val e44: Dp = 44.dp
    val e52: Dp = 52.dp
    val e56: Dp = 56.dp
}

/** Duraciones de animación, en milisegundos. */
object TokensMovimiento {
    const val rapida: Int = 200
    const val media: Int = 350
    const val lenta: Int = 400
    const val muyLenta: Int = 900
}

/**
 * 🛑 Objetivo táctil mínimo. AGENTS.md §10.1, sin excepciones.
 *
 * El diseño de design/origen/ NO lo cumple: el detalle, agrupado por tipo de
 * arreglo, está en design/ESPECIFICACION.md §9.2. design/nuevo/gimnasio.dc.html sí.
 */
object TokensTamano {
    val objetivoTactilMinimo: Dp = 48.dp
    val botonPrimario: Dp = 49.dp
    val itemRuedaFecha: Dp = 46.dp
    val chipDia: Dp = 41.dp
    val celdaCalendario: Dp = 34.dp
    val botonCircularCalendario: Dp = 30.dp
    val switchAjustes: Dp = 26.dp
    val botonRelojMasMenos: Dp = 38.dp
    val botonRelojCircular: Dp = 32.dp
}

/**
 * Lo que tokens.json declara PENDIENTE. Está acá, en el código, a propósito: un
 * hueco que sólo vive en un JSON no lo ve nadie.
 */
object TokensPendientes {
    val LISTA: List<String> = listOf(
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
    )
}
