package com.tecladus.trainer

import android.view.View
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.tecladus.trainer.pantallas.TemaDeLaApp
import com.tecladus.trainer.pantallas.acceso.PantallaRegistroCorreo
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeoutException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * TalkBack se entera cuando el toque rechaza el correo.
 *
 * El foco del lector de pantalla se queda en el botón, así que el error tiene que
 * anunciarse (ver `recordarChequeoDeCorreo`). Acá no hay TalkBack: se escucha lo
 * mismo que le llegaría a él, los eventos de accesibilidad, con el `UiAutomation`
 * de la instrumentación. Alcanza con el paso del registro porque el login y
 * recuperar la contraseña piden el chequeo a la misma función.
 *
 * Los nombres van con guiones bajos y no con espacios: con `minSdk` 26, el DEX de
 * un test instrumentado no acepta espacios en un nombre.
 */
@RunWith(AndroidJUnit4::class)
class AnuncioDelCorreoRechazadoTest {

    @get:Rule
    val compose = createComposeRule()

    private val instrumentacion = InstrumentationRegistry.getInstrumentation()
    private val contexto = instrumentacion.targetContext
    private val aviso = contexto.getString(R.string.reg_correo_mal)
    private val boton = contexto.getString(R.string.reg_correo_enviar)
    private val campo = contexto.getString(R.string.reg_correo_campo)
    private var enviados = 0
    private var vista: View? = null

    @Before
    fun prenderLaAccesibilidad() {
        // Con un UiAutomation conectado el sistema da la accesibilidad por prendida, y
        // recién ahí `announceForAccessibility` manda el evento. A la app el aviso le
        // llega un momento después de conectar.
        instrumentacion.uiAutomation
        val accesibilidad = contexto.getSystemService(AccessibilityManager::class.java)
        val limite = System.currentTimeMillis() + 5_000
        while (!accesibilidad.isEnabled && System.currentTimeMillis() < limite) Thread.sleep(50)
        assertTrue("la accesibilidad no se prendió con el UiAutomation", accesibilidad.isEnabled)
    }

    private fun mostrarElPaso(correoInicial: String) {
        compose.setContent {
            vista = LocalView.current
            TemaDeLaApp {
                var correo by remember { mutableStateOf(correoInicial) }
                PantallaRegistroCorreo(
                    correo = correo,
                    onCorreo = { correo = it },
                    enCurso = false,
                    error = null,
                    onEnviar = { enviados++ },
                )
            }
        }
    }

    /** Lo que se oyó mientras se hacía algo: si llegó el anuncio buscado, y todo lo demás. */
    private class Escucha(val llegoElAnuncio: Boolean, val eventos: List<String>)

    /**
     * Hace [accion], deja que Compose se acomode, y escucha hasta tres segundos o
     * hasta que llegue un anuncio con [texto]. Guarda todos los eventos que pasan,
     * para que un test que falla diga qué se oyó en vez del anuncio.
     *
     * 🪤 El `waitForIdle` va ADENTRO de lo que se escucha. En un test de Compose la
     * recomposición que dispara el toque recién corre en el próximo punto de
     * sincronización; sin esto, el anuncio salía en la aserción de después, con el
     * test ya sin escuchar. Y los tests que esperan que NO haya anuncio pasaban sin
     * haber dejado recomponer.
     */
    private fun escuchar(texto: String = aviso, accion: () -> Unit): Escucha {
        val eventos = CopyOnWriteArrayList<String>()
        val llego = try {
            instrumentacion.uiAutomation.executeAndWaitForEvent(
                {
                    accion()
                    compose.waitForIdle()
                },
                { evento ->
                    eventos += "${AccessibilityEvent.eventTypeToString(evento.eventType)} ${evento.text}"
                    evento.eventType == AccessibilityEvent.TYPE_ANNOUNCEMENT &&
                        evento.text.joinToString() == texto
                },
                3_000,
            )
            true
        } catch (_: TimeoutException) {
            false
        }
        return Escucha(llego, eventos)
    }

    private fun tocarElBoton() {
        compose.onNodeWithText(boton).performClick()
    }

    /**
     * Sin esto, los tests que esperan que NO haya anuncio pasarían aunque el test no
     * pudiera oír nada.
     */
    @Test
    fun el_test_oye_un_anuncio_hecho_a_mano() {
        mostrarElPaso("")
        val escucha = escuchar("prueba") { compose.runOnUiThread { vista!!.announceForAccessibility("prueba") } }
        assertTrue("el test no oye anuncios. Se oyó: ${escucha.eventos}", escucha.llegoElAnuncio)
    }

    @Test
    fun tocar_con_un_correo_que_no_parece_lo_anuncia_y_no_manda_nada() {
        mostrarElPaso("ivan@correo")

        val escucha = escuchar { tocarElBoton() }

        compose.onNodeWithText(aviso).assertExists()
        assertTrue("TalkBack no se enteró del error. Se oyó: ${escucha.eventos}", escucha.llegoElAnuncio)
        assertEquals("con el correo rechazado no viaja nada", 0, enviados)
    }

    @Test
    fun escribir_no_anuncia_nada() {
        mostrarElPaso("")

        val escucha = escuchar { compose.onNodeWithContentDescription(campo).performTextInput("ivan@") }

        assertFalse("mientras se escribe el correo no se juzga", escucha.llegoElAnuncio)
        compose.onNodeWithText(aviso).assertDoesNotExist()
    }

    @Test
    fun tocar_con_un_correo_que_parece_no_anuncia_y_sigue() {
        mostrarElPaso("ivan@correo.com")

        val escucha = escuchar { tocarElBoton() }

        assertFalse("un correo que pasa no tiene nada que anunciar", escucha.llegoElAnuncio)
        assertEquals(1, enviados)
    }

    @Test
    fun corregir_y_volver_a_equivocarse_lo_anuncia_otra_vez() {
        mostrarElPaso("ivan@correo")
        val primera = escuchar { tocarElBoton() }
        assertTrue("el primer rechazo no se anunció. Se oyó: ${primera.eventos}", primera.llegoElAnuncio)

        // Sigue sin parecer un correo, pero es otro: el error se va y el próximo toque
        // es un rechazo nuevo, que se anuncia de nuevo.
        compose.onNodeWithContentDescription(campo).performTextInput(".")
        compose.onNodeWithText(aviso).assertDoesNotExist()

        val segunda = escuchar { tocarElBoton() }
        assertTrue("el segundo rechazo no se anunció. Se oyó: ${segunda.eventos}", segunda.llegoElAnuncio)
        assertEquals(0, enviados)
    }
}
