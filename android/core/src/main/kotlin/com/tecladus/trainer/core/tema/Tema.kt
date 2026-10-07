package com.tecladus.trainer.core.tema

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit

/**
 * El design system de Trainer. AGENTS.md §10.1.
 *
 * Todo lo que una pantalla necesita para pintarse sale de acá, y todo lo que hay
 * acá sale de `TokensGenerados.kt`, que sale de `shared/design/tokens.json`. Una
 * pantalla que escriba un color o un tamaño a mano hace fallar
 * `scripts/verificar-tokens.mjs`, y eso corta el build (ver `:core:verificarTokens`).
 *
 * Dos cosas que no son obvias y por eso están escritas:
 *
 * 1. **El acento es un parámetro, no una constante.** `tokens.json` lo expone como
 *    `parametros_del_tablero.accent`. Acá entra por [TrainerTema] y todo lo que
 *    deriva de él —el relleno del chip activo, el borde suave, y sobre todo el
 *    color del texto que va ENCIMA— se recalcula. El texto de encima no está
 *    escrito: lo elige [Contraste.mejorSobre] midiendo. Con el acento por defecto
 *    da el casi-negro, igual que el diseño; con un acento oscuro se da vuelta solo.
 * 2. **El diseño es sólo oscuro.** No hay tema claro y no es un olvido:
 *    `tokens.json` lo declara en `pendientes[tema-claro]`. Por eso [TrainerTema] no
 *    tiene parámetro de tema y el esquema de Material se arma siempre oscuro.
 */

// ---------------------------------------------------------------------- color

/**
 * Los roles de color del teléfono. Nombrados por lo que SIGNIFICAN, no por su
 * valor: `superficie` y no `verde oscuro`.
 */
@Immutable
class EsquemaColor internal constructor(
    /** El parámetro del tablero. Cambiarlo cambia el producto entero desde un lugar. */
    val acento: Color,
) {
    /**
     * El color del texto y los íconos que van ENCIMA del acento.
     * Medido, no elegido: ver la nota 1 del encabezado.
     */
    val sobreAcento: Color = Contraste.mejorSobre(
        acento,
        listOf(TokensColor.marcaSobreAcento, TokensColor.telefonoTextoPrimario),
    )

    /** Los alfas salen del token: si el acento es el de fábrica, esto ES el token. */
    val acentoRellenoActivo: Color = acento.copy(alpha = TokensColor.marcaAcentoChipActivo.alpha)
    val acentoRellenoSuave: Color = acento.copy(alpha = TokensColor.marcaAcentoSuaveFondo.alpha)
    val acentoBordeSuave: Color = acento.copy(alpha = TokensColor.marcaAcentoSuaveBorde.alpha)

    val fondo: Color = TokensColor.telefonoFondo
    val superficie: Color = TokensColor.telefonoSuperficie
    val superficieAlterna: Color = TokensColor.telefonoSuperficieAlterna
    val superficieDestacada: Color = TokensColor.telefonoSuperficieDestacada
    val superficieBarra: Color = TokensColor.telefonoSuperficieBarra
    val superficieInput: Color = TokensColor.telefonoSuperficieInput
    val superficieOverlay: Color = TokensColor.telefonoSuperficieOverlay

    /** Relleno de un control apoyado sobre una card. NO es un borde. */
    val superficieHundida: Color = TokensColor.telefonoSuperficieHundida

    /** Relleno de botón secundario: los −/+ de los steppers. */
    val superficieControl: Color = TokensColor.telefonoSuperficieControl

    /** El oscurecido detrás de una hoja inferior. */
    val velo: Color = TokensColor.telefonoVelo

    val textoPrimario: Color = TokensColor.telefonoTextoPrimario
    val textoCuerpo: Color = TokensColor.telefonoTextoCuerpo
    val textoSecundario: Color = TokensColor.telefonoTextoSecundario
    val textoTerciario: Color = TokensColor.telefonoTextoTerciario
    val textoDeshabilitado: Color = TokensColor.telefonoTextoDeshabilitado

    /**
     * TODO(tokens): el rol `texto_placeholder` de `tokens.json` es el heredado de
     * `design/origen/`, blanco al 32 %, y da 2.75:1 sobre el input — no llega a AA
     * 4.5 y `ContrasteTest` lo deja fijado. Las pantallas nuevas usan el terciario,
     * que sobre el mismo fondo da 4.92:1. Cuando se corrija el token, esta línea
     * vuelve a apuntar a `telefonoTextoPlaceholder` y el test que lo documenta se
     * borra en el mismo commit.
     */
    val placeholder: Color = TokensColor.telefonoTextoTerciario

    /**
     * El único borde que puede COMUNICAR algo (serie hecha, chip elegido, campo en
     * foco). Pasa WCAG 1.4.11 sobre las cuatro superficies del diseño; los otros
     * bordes no llegan y por eso son decorativos.
     */
    val bordeSignificante: Color = TokensColor.telefonoBordeSignificante
    val bordeSuperficie: Color = TokensColor.telefonoBordeSuperficie
    val bordeInput: Color = TokensColor.telefonoBordeInput
    val bordeBotonSecundario: Color = TokensColor.telefonoBordeBotonSecundario
    val divisor: Color = TokensColor.telefonoDivisor

    val error: Color = TokensColor.estadoError
    val errorBorde: Color = TokensColor.estadoErrorBorde
    val errorFondo: Color = TokensColor.estadoErrorFondo
    val sobreError: Color = Contraste.mejorSobre(
        Contraste.componer(error, fondo),
        listOf(TokensColor.marcaSobreAcento, TokensColor.telefonoTextoPrimario),
    )

    /** Series de datos de los gráficos. Nunca son el único portador de significado. */
    val datosSerie: List<Color> = listOf(
        TokensColor.datosSerie1,
        TokensColor.datosSerie2,
        TokensColor.datosSerie3,
    )
}

// ----------------------------------------------------------------- tipografía

/**
 * Los roles de texto. Cada uno arma su `TextStyle` desde el token: tamaño, peso,
 * interlineado y espaciado de letras.
 *
 * `cifrasTabulares` no es cosmética. Sin ella, un cronómetro que baja de un
 * segundo a otro cambia el ancho de cada dígito y el número entero salta.
 * `tokens.json` la declara obligatoria para métricas, horas, cronómetro, peso,
 * distancia, kcal y macros.
 */
@Immutable
class Tipografia internal constructor() {

    /**
     * La palabra "Trainer" del logotipo. Más chica que [tituloBienvenida] a
     * propósito: la marca acompaña y el titular es lo que se lee primero.
     */
    val marca: TextStyle = estilo(
        TokensTipografia.marcaTamano,
        TokensTipografia.marcaPeso,
        espaciadoLetras = TokensTipografia.marcaEspaciadoLetras,
    )

    val tituloBienvenida: TextStyle = estilo(
        TokensTipografia.tituloBienvenidaTamano,
        TokensTipografia.tituloBienvenidaPeso,
        TokensTipografia.tituloBienvenidaInterlineado,
        TokensTipografia.tituloBienvenidaEspaciadoLetras,
    )

    val tituloPantalla: TextStyle = estilo(
        TokensTipografia.tituloPantallaTamano,
        TokensTipografia.tituloPantallaPeso,
        TokensTipografia.tituloPantallaInterlineado,
        TokensTipografia.tituloPantallaEspaciadoLetras,
    )

    /** El nombre del ejercicio en la captura de serie. */
    val tituloEjercicio: TextStyle = estilo(
        TokensTipografia.tituloEjercicioTamano,
        TokensTipografia.tituloEjercicioPeso,
        TokensTipografia.tituloEjercicioInterlineado,
        TokensTipografia.tituloEjercicioEspaciadoLetras,
    )

    val numeroGrande: TextStyle = estilo(
        TokensTipografia.numeroGrandeTamano,
        TokensTipografia.numeroGrandePeso,
        TokensTipografia.numeroGrandeInterlineado,
        TokensTipografia.numeroGrandeEspaciadoLetras,
        tabular = true,
    )

    val cronometro: TextStyle = estilo(
        TokensTipografia.cronometroTamano,
        TokensTipografia.cronometroPeso,
        TokensTipografia.cronometroInterlineado,
        TokensTipografia.cronometroEspaciadoLetras,
        tabular = true,
    )

    val tituloCard: TextStyle = estilo(
        TokensTipografia.tituloCardTamano,
        TokensTipografia.tituloCardPeso,
    )

    val cuerpo: TextStyle = estilo(
        TokensTipografia.cuerpoTamano,
        TokensTipografia.cuerpoPeso,
        TokensTipografia.cuerpoInterlineado,
    )

    val cuerpoSecundario: TextStyle = estilo(
        TokensTipografia.cuerpoSecundarioTamano,
        TokensTipografia.cuerpoSecundarioPeso,
        TokensTipografia.cuerpoSecundarioInterlineado,
    )

    val labelCampo: TextStyle = estilo(
        TokensTipografia.labelCampoTamano,
        TokensTipografia.labelCampoPeso,
    )

    /**
     * Va en MAYÚSCULAS: el token lo declara y por eso no se decide en la pantalla.
     * Quien lo use tiene que aplicar la transformación al texto, no escribirlo
     * gritado en el string — un string en mayúsculas no se puede traducir bien y
     * un lector de pantalla lo deletrea.
     */
    val etiquetaSeccion: TextStyle = estilo(
        TokensTipografia.etiquetaSeccionTamano,
        TokensTipografia.etiquetaSeccionPeso,
        espaciadoLetras = TokensTipografia.etiquetaSeccionEspaciadoLetras,
    )

    /** `true` si [etiquetaSeccion] va en mayúsculas. Lo dice el token, no la pantalla. */
    val etiquetaSeccionEnMayusculas: Boolean = TokensTipografia.etiquetaSeccionMayusculas

    val labelNavegacion: TextStyle = estilo(
        TokensTipografia.labelNavegacionTamano,
        TokensTipografia.labelNavegacionPeso,
    )

    /** Un número que se lee de un vistazo: valor prescrito, chip de serie, botón primario. */
    val valorDato: TextStyle = estilo(
        TokensTipografia.valorDatoTamano,
        TokensTipografia.valorDatoPeso,
        TokensTipografia.valorDatoInterlineado,
        TokensTipografia.valorDatoEspaciadoLetras,
        tabular = true,
    )

    /** El valor dentro de una fila de lista. */
    val valorFila: TextStyle = estilo(
        TokensTipografia.valorFilaTamano,
        TokensTipografia.valorFilaPeso,
        tabular = true,
    )

    val chip: TextStyle = estilo(
        TokensTipografia.chipTamano,
        TokensTipografia.chipPeso,
        TokensTipografia.chipInterlineado,
    )

    val nota: TextStyle = estilo(
        TokensTipografia.notaTamano,
        TokensTipografia.notaPeso,
        TokensTipografia.notaInterlineado,
    )

    val tecla: TextStyle = estilo(
        TokensTipografia.teclaTamano,
        TokensTipografia.teclaPeso,
        tabular = true,
    )

    /**
     * El código de 6 caracteres del correo. Es el único espaciado de letras
     * POSITIVO del diseño, y no es capricho: un código se lee de a un carácter, no
     * como palabra, y separarlos es lo que evita confundir `0` con `O`.
     */
    val codigo: TextStyle = estilo(
        TokensTipografia.codigoTamano,
        TokensTipografia.codigoPeso,
        espaciadoLetras = TokensTipografia.codigoEspaciadoLetras,
        tabular = true,
    )

    private companion object {
        /**
         * TODO(tokens): `tokens.json` dice que la familia es Archivo y que hay que
         * empaquetarla (`pendientes[fuente-empaquetada]`); en el diseño se baja de
         * Google Fonts por red, que en una app no es una opción. Hasta que el
         * archivo de fuente esté en el repo, esto usa la del sistema. Es la única
         * desviación tipográfica del diseño y está acá para que se vea.
         */
        val familia: FontFamily = FontFamily.Default

        fun estilo(
            tamano: TextUnit,
            peso: FontWeight,
            interlineado: TextUnit = TextUnit.Unspecified,
            espaciadoLetras: TextUnit = TextUnit.Unspecified,
            tabular: Boolean = false,
        ): TextStyle = TextStyle(
            fontFamily = familia,
            fontSize = tamano,
            fontWeight = peso,
            lineHeight = interlineado,
            letterSpacing = espaciadoLetras,
            fontFeatureSettings = if (tabular) "tnum" else null,
            textAlign = TextAlign.Unspecified,
        )
    }
}

// ---------------------------------------------------------------- formas y aire

/** Los radios del diseño. Los del marco del teléfono y del reloj no se portan. */
@Immutable
class Formas internal constructor() {
    val minimo = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.minimo)
    val celda = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.celda)
    val chip = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.chip)
    val input = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.input)
    val boton = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.boton)
    val card = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.card)
    val cardDestacada = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.cardDestacada)
    val pill = androidx.compose.foundation.shape.RoundedCornerShape(TokensRadio.pill)
}

/**
 * El aire. Es la escala MEDIDA, no una consolidada: `tokens.json` declara
 * `pendientes[escala-espaciado]` con 24 gaps casi continuos. Existe para que
 * ninguna pantalla escriba un tamaño a mano mientras esa decisión no esté tomada.
 */
@Immutable
class Espacios internal constructor() {
    val e1: Dp = TokensEspaciado.e1
    val e2: Dp = TokensEspaciado.e2
    val e3: Dp = TokensEspaciado.e3
    val e4: Dp = TokensEspaciado.e4
    val e5: Dp = TokensEspaciado.e5
    val e6: Dp = TokensEspaciado.e6
    val e7: Dp = TokensEspaciado.e7
    val e8: Dp = TokensEspaciado.e8
    val e9: Dp = TokensEspaciado.e9
    val e10: Dp = TokensEspaciado.e10
    val e11: Dp = TokensEspaciado.e11
    val e12: Dp = TokensEspaciado.e12
    val e13: Dp = TokensEspaciado.e13
    val e14: Dp = TokensEspaciado.e14
    val e16: Dp = TokensEspaciado.e16
    val e20: Dp = TokensEspaciado.e20
    val e22: Dp = TokensEspaciado.e22
    val e26: Dp = TokensEspaciado.e26
    val e34: Dp = TokensEspaciado.e34
    val e36: Dp = TokensEspaciado.e36
    val e40: Dp = TokensEspaciado.e40
    val e44: Dp = TokensEspaciado.e44
    val e52: Dp = TokensEspaciado.e52
    val e56: Dp = TokensEspaciado.e56
}

// ------------------------------------------------------------------ el tema

private val LocalEsquemaColor = staticCompositionLocalOf {
    EsquemaColor(TokensColor.marcaAcento)
}
private val LocalTipografia = staticCompositionLocalOf { Tipografia() }
private val LocalFormas = staticCompositionLocalOf { Formas() }
private val LocalEspacios = staticCompositionLocalOf { Espacios() }

/** El punto de acceso desde una pantalla: `Tema.color.superficie`, `Tema.texto.cuerpo`. */
object Tema {
    val color: EsquemaColor
        @Composable @ReadOnlyComposable get() = LocalEsquemaColor.current

    val texto: Tipografia
        @Composable @ReadOnlyComposable get() = LocalTipografia.current

    val forma: Formas
        @Composable @ReadOnlyComposable get() = LocalFormas.current

    val aire: Espacios
        @Composable @ReadOnlyComposable get() = LocalEspacios.current

    /**
     * 🛑 El objetivo táctil mínimo. AGENTS.md §10.1, sin excepciones.
     * Está acá, y no en cada pantalla, para que haya un solo número que discutir.
     */
    val tactilMinimo: Dp get() = TokensTamano.objetivoTactilMinimo
}

/**
 * Envuelve la app. Provee color, tipografía, formas y aire, y además configura
 * `MaterialTheme` para que lo que venga de Material 3 —el ripple, el color de
 * selección de texto, los diálogos— no se vea de otro producto.
 *
 * @param acento el parámetro del tablero. Por defecto, el del diseño.
 */
@Composable
fun TrainerTema(
    acento: Color = TokensColor.marcaAcento,
    contenido: @Composable () -> Unit,
) {
    // El diseño es sólo oscuro (pendientes[tema-claro]). Se lee la preferencia del
    // sistema para NO usarla: dejarla sin leer haría creer que algún día se respeta.
    @Suppress("UNUSED_VARIABLE")
    val elSistemaPideOscuro = isSystemInDarkTheme()

    val color = remember(acento) { EsquemaColor(acento) }
    val texto = remember { Tipografia() }
    val formas = remember { Formas() }
    val espacios = remember { Espacios() }

    val esquemaMaterial = darkColorScheme(
        primary = color.acento,
        onPrimary = color.sobreAcento,
        primaryContainer = color.acentoRellenoActivo,
        onPrimaryContainer = color.textoPrimario,
        secondary = color.acento,
        onSecondary = color.sobreAcento,
        background = color.fondo,
        onBackground = color.textoPrimario,
        surface = color.superficie,
        onSurface = color.textoPrimario,
        surfaceVariant = color.superficieAlterna,
        onSurfaceVariant = color.textoSecundario,
        outline = color.bordeSignificante,
        outlineVariant = color.divisor,
        error = color.error,
        onError = color.sobreError,
        errorContainer = color.errorFondo,
        onErrorContainer = color.textoPrimario,
        scrim = color.velo,
    )

    CompositionLocalProvider(
        LocalEsquemaColor provides color,
        LocalTipografia provides texto,
        LocalFormas provides formas,
        LocalEspacios provides espacios,
    ) {
        MaterialTheme(
            colorScheme = esquemaMaterial,
            shapes = Shapes(
                extraSmall = formas.celda,
                small = formas.chip,
                medium = formas.boton,
                large = formas.card,
                extraLarge = formas.cardDestacada,
            ),
            content = contenido,
        )
    }
}
