package com.tecladus.trainer.pantallas

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.colorResource
import com.tecladus.trainer.R
import com.tecladus.trainer.core.tema.TrainerTema

/**
 * El tema de la app de teléfono. **Es el único lugar donde se lee el color del
 * producto**, y por eso toda Activity tiene que envolverse en esto y no en
 * [TrainerTema] directamente.
 *
 * ## Cómo se cambia el color de la app
 *
 * Se edita el hex de `acento` en `res/values/colors.xml`. Nada más: ni una pantalla,
 * ni un generador, ni un token. Ese color entra acá y `EsquemaColor` deriva todo lo
 * demás — el relleno del chip elegido, el borde suave, y **el color del texto que va
 * encima**, que no está escrito sino medido con `Contraste.mejorSobre`.
 *
 * ## Por qué existe esta función y no se llama a `TrainerTema` y listo
 *
 * `TrainerTema` vive en `:core`, que comparten el teléfono y el reloj (AGENTS.md
 * §4.1), y un módulo de librería no puede leer los recursos de la app que lo usa.
 * Así que alguien del lado de `:app` tiene que leer el recurso y pasárselo.
 *
 * 🛑 Ese "alguien" es **una sola función** a propósito. Si cada Activity leyera el
 * recurso por su cuenta, la primera que se olvide de hacerlo se dibuja con el valor
 * de fábrica de los tokens y queda de otro color que el resto de la app —y eso no
 * rompe nada, no falla ningún test, y se descubre mirando dos capturas al lado.
 * Con una sola puerta, o pasan todas o no pasa ninguna.
 */
@Composable
fun TemaDeLaApp(contenido: @Composable () -> Unit) {
    TrainerTema(acento = colorResource(R.color.acento), contenido = contenido)
}
