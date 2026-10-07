package com.tecladus.trainer.core.tema

import androidx.compose.ui.graphics.Color
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * Contraste WCAG 2.1, calculado — no estimado a ojo.
 *
 * Existe por dos motivos concretos, los dos de `design/ESPECIFICACION.md` §9.1:
 *
 * 1. **Los tokens tienen alfa.** `telefonoTextoSecundario` es blanco al 60 %.
 *    Un 60 % sobre la card y un 60 % sobre el fondo de pantalla NO dan el mismo
 *    contraste. Medir el token contra el fondo sin componerlo primero da un
 *    número que no es el que ve la persona. Por eso [razonSobre] compone.
 * 2. **El acento es un parámetro** (`tokens.json` → `parametros_del_tablero.accent`).
 *    Si alguien lo cambia por uno oscuro, el texto negro que hoy va encima deja de
 *    leerse. [mejorSobre] elige el color de encima por contraste medido, así que
 *    el producto no depende de que el acento siga siendo claro.
 *
 * Las fórmulas son las de la norma, sin aproximar:
 * <https://www.w3.org/TR/WCAG21/#dfn-relative-luminance>
 * <https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio>
 */
object Contraste {

    /** WCAG 1.4.3 AA, texto normal. */
    const val AA_TEXTO: Double = 4.5

    /**
     * WCAG 1.4.3 AA, texto grande (≥ 18 pt, o ≥ 14 pt en negrita).
     * Mismo umbral que 1.4.11, por coincidencia de la norma, no por ser lo mismo.
     */
    const val AA_TEXTO_GRANDE: Double = 3.0

    /** WCAG 1.4.11: bordes y rellenos que comunican un control o su estado. */
    const val AA_COMPONENTE: Double = 3.0

    /**
     * Compone [frente] sobre [fondo] usando el alfa de [frente].
     *
     * Se asume [fondo] opaco: si no lo fuera, habría que componerlo antes contra
     * lo que tenga debajo. En este diseño el fondo de pantalla y las cards lo son.
     */
    fun componer(frente: Color, fondo: Color): Color {
        val a = frente.alpha
        if (a >= 1f) return frente
        return Color(
            red = frente.red * a + fondo.red * (1f - a),
            green = frente.green * a + fondo.green * (1f - a),
            blue = frente.blue * a + fondo.blue * (1f - a),
            alpha = 1f,
        )
    }

    /** Luminancia relativa. El color se toma como opaco: componé antes si tiene alfa. */
    fun luminancia(color: Color): Double {
        fun canal(v: Float): Double {
            val c = v.toDouble()
            return if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * canal(color.red) + 0.7152 * canal(color.green) + 0.0722 * canal(color.blue)
    }

    /** Razón de contraste entre dos colores OPACOS. De 1.0 (iguales) a 21.0 (negro/blanco). */
    fun razon(a: Color, b: Color): Double {
        val la = luminancia(a)
        val lb = luminancia(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /**
     * Lo que ve la persona: [frente] compuesto sobre [fondo], medido contra [fondo].
     * Es la única de las tres que hay que usar con tokens que tienen alfa.
     */
    fun razonSobre(frente: Color, fondo: Color): Double = razon(componer(frente, fondo), fondo)

    /**
     * Elige, entre [candidatos], el que más contraste da sobre [fondo].
     *
     * Se usa para el color de ENCIMA del acento. Con el acento por defecto elige el
     * casi-negro, igual que el diseño; con un acento oscuro elige el claro solo, sin
     * que nadie tenga que acordarse.
     *
     * Toma una lista y no un `vararg` porque `Color` es una value class y Kotlin
     * prohibe `vararg` de esos tipos: no hay array del tipo subyacente que pasar.
     */
    fun mejorSobre(fondo: Color, candidatos: List<Color>): Color {
        require(candidatos.isNotEmpty()) { "mejorSobre necesita al menos un candidato" }
        return candidatos.maxByOrNull { razonSobre(it, fondo) }!!
    }

    /** `true` si [frente] sobre [fondo] llega al umbral. Redondea como la norma: no afloja. */
    fun cumple(frente: Color, fondo: Color, umbral: Double): Boolean =
        razonSobre(frente, fondo) >= umbral
}
