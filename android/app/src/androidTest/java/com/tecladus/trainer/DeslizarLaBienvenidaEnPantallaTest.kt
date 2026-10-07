package com.tecladus.trainer

import android.view.ViewConfiguration
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.test.swipeRight
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.tecladus.trainer.core.tema.Tema
import com.tecladus.trainer.pantallas.TemaDeLaApp
import com.tecladus.trainer.pantallas.acceso.MILISEGUNDOS_POR_SLIDE
import com.tecladus.trainer.pantallas.acceso.PantallaBienvenida
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La bienvenida se pasa deslizando el dedo, sin perder lo que ya hacía.
 *
 * Es el gesto de verdad, en el emulador. La regla de a qué slide lleva está probada en
 * la JVM (`DeslizarLaBienvenidaTest`); acá se mira que el dedo llegue a ella en
 * cualquier parte de la pantalla, que el recorrido se cuente desde donde se apoyó, que
 * el carrusel espere mientras el dedo arrastra y que los botones sigan respondiendo.
 *
 * El reloj de Compose va a mano (`autoAdvance = false`): así el carrusel no pasa solo en
 * el medio de una prueba, y cuando lo que se prueba es el autoplay, el tiempo lo pone la
 * prueba. La contracara es que nada se redibuja solo: después de cada gesto hay que
 * empujar el reloj ([dejarQueSeDibuje]).
 *
 * Los nombres van con guiones bajos y no con espacios: con `minSdk` 26, el DEX de un
 * test instrumentado no acepta espacios en un nombre.
 */
@RunWith(AndroidJUnit4::class)
class DeslizarLaBienvenidaEnPantallaTest {

    @get:Rule
    val compose = createComposeRule()

    private val contexto = InstrumentationRegistry.getInstrumentation().targetContext
    private val titulos = listOf(R.string.bien_slide1_t, R.string.bien_slide2_t, R.string.bien_slide3_t)
        .map { contexto.getString(it) }
    private val crearCuenta = contexto.getString(R.string.bien_crear)
    private var cuentasCreadas = 0

    @Before
    fun mostrarLaBienvenida() {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            TemaDeLaApp {
                PantallaBienvenida(onCrearCuenta = { cuentasCreadas++ }, onYaTengoCuenta = {})
            }
        }
    }

    @Test
    fun deslizar_pasa_de_slide_en_cualquier_parte_y_los_botones_siguen_andando() {
        seVe(0)

        // Hacia la derecha va el anterior, y desde el primero da la vuelta.
        compose.onRoot().performTouchInput { swipeRight() }
        dejarQueSeDibuje()
        seVe(2)

        // Arrancando sobre el título: otra vez el anterior.
        compose.onNodeWithText(titulos[2]).performTouchInput { swipeRight() }
        dejarQueSeDibuje()
        seVe(1)

        // Arrancando sobre el botón, hacia la izquierda: el siguiente. Deslizar por
        // encima del botón no lo aprieta...
        compose.onNodeWithText(crearCuenta).performTouchInput { swipeLeft() }
        dejarQueSeDibuje()
        seVe(2)
        assertEquals(0, cuentasCreadas)

        // ...y tocarlo sigue andando.
        compose.onNodeWithText(crearCuenta).performClick()
        dejarQueSeDibuje()
        assertEquals(1, cuentasCreadas)
    }

    @Test
    fun el_recorrido_se_cuenta_desde_donde_se_apoyo_el_dedo() {
        val umbral = with(compose.density) { Tema.tactilMinimo.toPx() }
        val tolerancia = ViewConfiguration.get(contexto).scaledTouchSlop.toFloat()

        // Soltando quieto no hay velocidad, así que decide sólo el recorrido. Un poco
        // menos que un objetivo táctil no pasa...
        arrastrarYSoltarQuieto(-(umbral - tolerancia / 2))
        seVe(0)

        // ...y un poco más sí, aunque lo que `draggable` cuenta desde su tolerancia de
        // arrastre se quede corto.
        arrastrarYSoltarQuieto(-(umbral + tolerancia / 2))
        seVe(1)
    }

    @Test
    fun mientras_el_dedo_arrastra_el_carrusel_no_pasa_solo() {
        val umbral = with(compose.density) { Tema.tactilMinimo.toPx() }
        compose.onRoot().performTouchInput {
            down(center)
            // Medio objetivo táctil: ya es un arrastre, pero no alcanza para pasar.
            repeat(PASOS) { moveBy(Offset(-umbral / 2 / PASOS, 0f)) }
        }
        compose.mainClock.advanceTimeBy(MILISEGUNDOS_POR_SLIDE * 2)
        seVe(0)

        // Al soltar vuelve a contar desde cero.
        compose.onRoot().performTouchInput {
            advanceEventTime(QUIETO_ANTES_DE_SOLTAR_MS)
            up()
        }
        compose.mainClock.advanceTimeBy(MILISEGUNDOS_POR_SLIDE - MARGEN_MS)
        seVe(0)
        compose.mainClock.advanceTimeBy(MARGEN_MS * 2)
        seVe(1)
    }

    private fun seVe(slide: Int) {
        compose.onNodeWithText(titulos[slide]).assertIsDisplayed()
    }

    /** Con el reloj quieto nada se redibuja solo: se lo empuja un momento, lejos de los 4200 ms del autoplay. */
    private fun dejarQueSeDibuje() {
        compose.mainClock.advanceTimeBy(UN_MOMENTO_MS)
    }

    private fun arrastrarYSoltarQuieto(recorrido: Float) {
        compose.onRoot().performTouchInput {
            down(center)
            repeat(PASOS) { moveBy(Offset(recorrido / PASOS, 0f)) }
            // Quieto un rato antes de levantar: al soltar, el dedo no lleva velocidad.
            advanceEventTime(QUIETO_ANTES_DE_SOLTAR_MS)
            up()
        }
        dejarQueSeDibuje()
    }

    private companion object {
        const val PASOS = 10
        const val UN_MOMENTO_MS = 100L
        const val MARGEN_MS = 300L
        const val QUIETO_ANTES_DE_SOLTAR_MS = 200L
    }
}
