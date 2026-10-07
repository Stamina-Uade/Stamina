package com.tecladus.trainer.core.tema

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Ata el contraste MEDIDO a los números publicados en `design/ESPECIFICACION.md` §9.1.
 *
 * No es un test de "la función devuelve un double". Cada número de acá salió de la
 * tabla de esa sección, y la tabla salió de medir las fuentes canónicas. Si alguien
 * toca un token de `shared/design/tokens.json` y regenera, este test falla y dice
 * exactamente qué par de colores dejó de dar lo que el documento afirma. Sin esto,
 * la tabla se vuelve mentira en silencio: nadie mira contraste hasta que un usuario
 * no puede leer la pantalla al sol.
 */
class ContrasteTest {

    /** Los números de la tabla están a dos decimales; esto tolera el redondeo, nada más. */
    private val tolerancia = 0.05

    private fun assertRazon(esperado: Double, frente: Color, fondo: Color, que: String) {
        val medido = Contraste.razonSobre(frente, fondo)
        assertEquals(que, esperado, medido, tolerancia)
    }

    // ---------------------------------------------------------------- la fórmula

    @Test
    fun `negro contra blanco da 21, que es el maximo de la norma`() {
        assertEquals(21.0, Contraste.razon(Color.Black, Color.White), 0.001)
    }

    @Test
    fun `un color contra si mismo da 1`() {
        assertEquals(1.0, Contraste.razon(TokensColor.telefonoFondo, TokensColor.telefonoFondo), 0.001)
    }

    @Test
    fun `componer respeta el alfa y devuelve algo opaco`() {
        val compuesto = Contraste.componer(TokensColor.telefonoTextoSecundario, TokensColor.telefonoSuperficie)
        assertEquals("el resultado de componer siempre es opaco", 1f, compuesto.alpha, 0.0001f)
    }

    @Test
    fun `componer un color opaco no lo cambia`() {
        val opaco = TokensColor.telefonoTextoPrimario
        assertEquals(opaco, Contraste.componer(opaco, TokensColor.telefonoSuperficie))
    }

    // ------------------------------------------- los números de ESPECIFICACION 9.1

    @Test
    fun `texto primario reproduce la tabla`() {
        assertRazon(18.97, TokensColor.telefonoTextoPrimario, TokensColor.telefonoFondo, "primario sobre fondo")
        assertRazon(16.60, TokensColor.telefonoTextoPrimario, TokensColor.telefonoSuperficie, "primario sobre superficie")
    }

    /** Con el acento verde #44D62C de los tokens actuales. */
    @Test
    fun `el acento reproduce la tabla`() {
        assertRazon(9.54, TokensColor.marcaAcento, TokensColor.telefonoSuperficie, "acento sobre superficie")
        assertRazon(10.90, TokensColor.marcaAcento, TokensColor.telefonoFondo, "acento sobre fondo")
        assertRazon(10.18, TokensColor.marcaSobreAcento, TokensColor.marcaAcento, "texto sobre boton de acento")
    }

    @Test
    fun `los textos con alfa reproducen la tabla`() {
        assertRazon(6.54, TokensColor.telefonoTextoSecundario, TokensColor.telefonoSuperficie, "secundario sobre superficie")
        assertRazon(6.22, TokensColor.telefonoTextoSecundario, TokensColor.telefonoSuperficieAlterna, "secundario sobre alterna")
        assertRazon(6.68, TokensColor.telefonoTextoSecundario, TokensColor.telefonoFondo, "secundario sobre fondo")
        assertRazon(4.93, TokensColor.telefonoTextoTerciario, TokensColor.telefonoSuperficie, "terciario sobre superficie")
        assertRazon(12.16, TokensColor.telefonoTextoCuerpo, TokensColor.telefonoSuperficie, "cuerpo sobre superficie")
    }

    @Test
    fun `el borde significante pasa 1_4_11 sobre los cuatro fondos donde se apoya`() {
        val hundida = Contraste.componer(TokensColor.telefonoSuperficieHundida, TokensColor.telefonoSuperficie)
        assertRazon(3.58, TokensColor.telefonoBordeSignificante, TokensColor.telefonoSuperficie, "sobre superficie")
        assertRazon(3.39, TokensColor.telefonoBordeSignificante, TokensColor.telefonoFondo, "sobre fondo")
        assertRazon(3.55, TokensColor.telefonoBordeSignificante, TokensColor.telefonoSuperficieAlterna, "sobre alterna")
        assertRazon(3.55, TokensColor.telefonoBordeSignificante, hundida, "sobre el relleno hundido")
    }

    // --------------------------------------------------- las garantías del sistema

    /**
     * La que importa: NINGÚN rol de texto del design system nuevo puede quedar por
     * debajo de AA sobre NINGUNA de las superficies donde el diseño lo apoya.
     */
    @Test
    fun `todo rol de texto del sistema cumple AA sobre toda superficie donde se apoya`() {
        val superficies = mapOf(
            "fondo" to TokensColor.telefonoFondo,
            "superficie" to TokensColor.telefonoSuperficie,
            "superficie alterna" to TokensColor.telefonoSuperficieAlterna,
            "superficie destacada" to TokensColor.telefonoSuperficieDestacada,
            "superficie de barra" to TokensColor.telefonoSuperficieBarra,
            "superficie de input" to TokensColor.telefonoSuperficieInput,
            "relleno hundido" to Contraste.componer(TokensColor.telefonoSuperficieHundida, TokensColor.telefonoSuperficie),
            "relleno de control" to Contraste.componer(TokensColor.telefonoSuperficieControl, TokensColor.telefonoSuperficie),
        )
        val textos = mapOf(
            "texto primario" to TokensColor.telefonoTextoPrimario,
            "texto cuerpo" to TokensColor.telefonoTextoCuerpo,
            "texto secundario" to TokensColor.telefonoTextoSecundario,
            "texto terciario" to TokensColor.telefonoTextoTerciario,
            "acento" to TokensColor.marcaAcento,
        )
        val fallan = mutableListOf<String>()
        for ((nombreTexto, texto) in textos) {
            for ((nombreFondo, fondo) in superficies) {
                val r = Contraste.razonSobre(texto, fondo)
                if (r < Contraste.AA_TEXTO) fallan += "$nombreTexto sobre $nombreFondo = ${"%.2f".format(r)}"
            }
        }
        assertTrue("por debajo de AA 4.5: $fallan", fallan.isEmpty())
    }

    @Test
    fun `el color de encima del acento se elige por contraste, no por costumbre`() {
        val elegido = Contraste.mejorSobre(
            TokensColor.marcaAcento,
            listOf(TokensColor.telefonoTextoPrimario, TokensColor.marcaSobreAcento),
        )
        // assertEquals y no assertSame: Color es una value class y comparar la
        // identidad de dos cajas distintas no dice nada sobre el color.
        assertEquals(
            "con el acento por defecto (claro) el texto de encima es el casi-negro",
            TokensColor.marcaSobreAcento,
            elegido,
        )
        // Y con un acento oscuro tiene que dar vuelta la elección sin que nadie lo toque.
        val elegidoOscuro = Contraste.mejorSobre(
            TokensColor.telefonoFondo,
            listOf(TokensColor.telefonoTextoPrimario, TokensColor.marcaSobreAcento),
        )
        assertEquals(
            "con un acento oscuro el texto de encima pasa a ser el claro",
            TokensColor.telefonoTextoPrimario,
            elegidoOscuro,
        )
    }

    // ------------------------------------------------- lo que NO cumple, a propósito

    /**
     * Estos dos NO pasan, y el test lo fija para que nadie los use creyendo que sí.
     * Si algún día se arreglan en `tokens.json`, este test falla y hay que venir a
     * borrarlo — que es exactamente lo que se quiere que pase.
     */
    @Test
    fun `el placeholder heredado no llega a AA y por eso las pantallas nuevas no lo usan`() {
        val r = Contraste.razonSobre(TokensColor.telefonoTextoPlaceholder, TokensColor.telefonoSuperficieInput)
        assertEquals("placeholder heredado sobre input", 2.75, r, tolerancia)
        assertTrue("sigue por debajo de AA: si se arregló, borrá este test", r < Contraste.AA_TEXTO)
        // El que sí se usa en el diseño nuevo, sobre el mismo fondo.
        assertRazon(4.92, TokensColor.telefonoTextoTerciario, TokensColor.telefonoSuperficieInput, "terciario sobre input")
    }

    @Test
    fun `los bordes decorativos no llegan a 1_4_11 y por eso no comunican nada`() {
        val divisor = Contraste.razonSobre(TokensColor.telefonoDivisor, TokensColor.telefonoFondo)
        val bordeCard = Contraste.razonSobre(TokensColor.telefonoBordeSuperficie, TokensColor.telefonoFondo)
        assertTrue("divisor = $divisor", divisor < Contraste.AA_COMPONENTE)
        assertTrue("borde de card = $bordeCard", bordeCard < Contraste.AA_COMPONENTE)
    }
}
