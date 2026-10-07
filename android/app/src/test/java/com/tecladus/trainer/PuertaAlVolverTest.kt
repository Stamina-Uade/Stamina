package com.tecladus.trainer

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.tecladus.trainer.pantallas.preguntarCadaVezQueVuelve
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * La puerta de versión se vuelve a preguntar al volver a primer plano (AGENTS.md §5.1).
 *
 * Corre en la JVM: el ciclo de vida es un `LifecycleRegistry` que el test mueve a mano,
 * sin Activity ni emulador. `repeatOnLifecycle` corre en `Dispatchers.Main`, que acá es
 * el de mentira.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class PuertaAlVolverTest {

    @Before
    fun antes() {
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @After
    fun despues() {
        Dispatchers.resetMain()
    }

    @Test
    fun `se pregunta al entrar, no otra vez en segundo plano, y de nuevo al volver`() = runTest {
        val pantalla = Pantalla()
        var preguntas = 0
        val vigia = launch { preguntarCadaVezQueVuelve(pantalla.lifecycle) { preguntas++ } }

        pantalla.registro.currentState = Lifecycle.State.RESUMED
        runCurrent()
        assertEquals("al entrar se pregunta", 1, preguntas)

        pantalla.registro.currentState = Lifecycle.State.CREATED
        runCurrent()
        assertEquals("en segundo plano no se pregunta", 1, preguntas)

        pantalla.registro.currentState = Lifecycle.State.RESUMED
        runCurrent()
        assertEquals("al volver a primer plano se pregunta de nuevo", 2, preguntas)

        vigia.cancel()
    }

    /** Una pantalla sin pantalla: sólo el ciclo de vida, sin chequeo de hilo principal. */
    private class Pantalla : LifecycleOwner {
        val registro: LifecycleRegistry = LifecycleRegistry.createUnsafe(this)

        override val lifecycle: Lifecycle
            get() = registro
    }
}
