package com.tecladus.trainer.pantallas

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.repeatOnLifecycle

/**
 * Pregunta la puerta de versión cada vez que la app vuelve a primer plano, y no una sola
 * vez por pantalla.
 *
 * 🛑 Preguntar sólo al crear la pantalla deja dos agujeros. Una app que pasa días abierta
 * en segundo plano no se entera de un `update_required` publicado mientras tanto. Y como
 * una falla deja pasar (docs/API.md §4), la primera pregunta hecha en un sótano sin señal
 * dejaba a la app sin puerta hasta que se volviera a crear la pantalla. Volver a primer
 * plano es el momento de reintentar: la persona está mirando.
 *
 * Suspende mientras exista [ciclo]. Cada vez que pasa a STARTED corre [preguntar]; si la
 * app sale de primer plano con la pregunta en el aire, se cancela y se vuelve a hacer la
 * próxima vez. Qué hace una falla con una respuesta clara de antes lo decide
 * `ApiTrainer.consultarPuertaDeVersion`: no la deshace.
 */
internal suspend fun preguntarCadaVezQueVuelve(ciclo: Lifecycle, preguntar: suspend () -> Unit) {
    ciclo.repeatOnLifecycle(Lifecycle.State.STARTED) { preguntar() }
}
