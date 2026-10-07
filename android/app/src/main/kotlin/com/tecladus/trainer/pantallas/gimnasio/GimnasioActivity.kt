package com.tecladus.trainer.pantallas.gimnasio

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.tecladus.trainer.BuildConfig
import com.tecladus.trainer.R
import com.tecladus.trainer.core.gimnasio.EstadoDelGimnasio
import com.tecladus.trainer.core.gimnasio.SeriesDeLaRutina
import com.tecladus.trainer.core.gimnasio.SincronizadorDeGimnasio
import com.tecladus.trainer.pantallas.RaizDeLaApp
import com.tecladus.trainer.pantallas.RedDeLaApp
import com.tecladus.trainer.pantallas.TemaDeLaApp
import com.tecladus.trainer.pantallas.preguntarCadaVezQueVuelve
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * El anfitrión de las pantallas de gimnasio.
 *
 * 🛑 La NAVEGACIÓN sigue siendo un andamio: la real —de la agenda del día a la rutina, de la
 * rutina a la captura, del catálogo de vuelta a la rutina— está en
 * `design/ESPECIFICACION.md` §6.3 y se cablea cuando existan las otras pantallas. Los
 * DATOS ya no: la rutina viene del servidor y las series se guardan en el teléfono en el
 * momento en que se registran, así que sobreviven a que el sistema mate el proceso con la
 * pantalla apagada y el teléfono en el bolsillo. Ver [SincronizadorDeGimnasio].
 */
class GimnasioActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // UNO por proceso y no uno por Activity: ver RedDeLaApp.
        val api = RedDeLaApp.api(applicationContext)
        val gimnasio = RedDeLaApp.gimnasio(applicationContext)
        setContent {
            TemaDeLaApp {
                // La puerta de versión, la sesión guardada y el acceso: ver RaizDeLaApp.
                RaizDeLaApp(
                    api = api,
                    build = BuildConfig.VERSION_CODE.toLong(),
                    contenidoDeGimnasio = { m -> Gimnasio(gimnasio, m) },
                    modifier = Modifier
                        .fillMaxSize()
                        .windowInsetsPadding(WindowInsets.systemBars)
                        .consumeWindowInsets(WindowInsets.systemBars),
                )
            }
        }
    }
}

/**
 * La sección de gimnasio: la rutina de hoy, si la hay, y adentro la sesión.
 *
 * Sincroniza al entrar y cada vez que la app vuelve a primer plano. Mientras tanto se ve lo
 * guardado (offline primero, AGENTS.md §6), y sin nada guardado se dice eso.
 *
 * 🛑 **Nunca una rutina de ejemplo.** Una rutina inventada en la pantalla de alguien que no
 * tiene señal es un plan que nadie le hizo, y las series que registre ahí no son de ninguna
 * sesión. La de ejemplo quedó sólo para la vista previa (`VistaPreviaDeGimnasio.kt`).
 */
@Composable
private fun Gimnasio(sincronizador: SincronizadorDeGimnasio, modifier: Modifier) {
    val estado by sincronizador.estado.collectAsState(initial = EstadoDelGimnasio.Buscando)
    val alcance = rememberCoroutineScope()
    val cicloDeVida = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(sincronizador, cicloDeVida) {
        preguntarCadaVezQueVuelve(cicloDeVida) { sincronizador.sincronizar() }
    }
    val reintentar: () -> Unit = { alcance.launch { sincronizador.sincronizar() } }

    when (val e = estado) {
        EstadoDelGimnasio.Buscando ->
            EstadoSinRutina(R.string.gym_buscando_titulo, detalle = null, onReintentar = null, modifier = modifier)

        EstadoDelGimnasio.SinRutinaNiConexion ->
            EstadoSinRutina(R.string.gym_sin_rutina_sin_red_titulo, R.string.gym_sin_rutina_sin_red_detalle, reintentar, modifier)

        is EstadoDelGimnasio.SinRutina -> if (e.codigo == CODIGO_PERFIL_INCOMPLETO) {
            EstadoSinRutina(R.string.gym_sin_rutina_perfil_titulo, R.string.gym_sin_rutina_perfil_detalle, reintentar, modifier)
        } else {
            EstadoSinRutina(R.string.gym_sin_rutina_titulo, R.string.gym_sin_rutina_detalle, reintentar, modifier)
        }

        is EstadoDelGimnasio.ConRutina -> if (e.rutina.exercises.isEmpty()) {
            EstadoSinRutina(R.string.gym_rutina_vacia_titulo, R.string.gym_rutina_vacia_detalle, reintentar, modifier)
        } else {
            // Una rutina distinta —la del día siguiente, o una que el servidor recalculó— arma
            // la pantalla de cero: el foco y los borradores de otra rutina no significan nada.
            key(e.rutina) { SesionDeHoy(e, sincronizador, modifier) }
        }
    }
}

/** La rutina de hoy y la captura de series, sobre lo que hay guardado. */
@Composable
private fun SesionDeHoy(
    e: EstadoDelGimnasio.ConRutina,
    sincronizador: SincronizadorDeGimnasio,
    modifier: Modifier,
) {
    val rutina = e.rutina
    val ejercicios = remember {
        mutableStateListOf(*SeriesDeLaRutina.estadosDe(rutina, e.series).toTypedArray())
    }
    // Lo que vuelve del servidor —lo del reloj, o lo propio ya con hora de llegada— se pone al
    // día sin tocar lo que es sólo de la pantalla: el foco, los borradores, el descanso.
    LaunchedEffect(e.series) {
        for (i in ejercicios.indices) ejercicios[i] = SeriesDeLaRutina.conSeries(ejercicios[i], e.series)
    }
    val nombres = remember(rutina) { rutina.exercises.map { it.name } }
    var entrenando by remember { mutableStateOf(false) }
    var actual by remember { mutableIntStateOf(0) }
    var segundos by remember { mutableIntStateOf(0) }

    LaunchedEffect(entrenando, segundos) {
        if (entrenando) {
            delay(MILISEGUNDOS_POR_SEGUNDO)
            segundos += 1
        }
    }

    if (!entrenando) {
        PantallaRutina(
            ejercicios = ejercicios,
            nombres = nombres,
            // TODO(catálogo): la distribución muscular sale de cruzar la rutina con el catálogo
            // (`GET /exercises`), y la duración no la da el servidor. Sin datos no se inventan:
            // la pantalla no muestra esas dos cosas.
            distribucion = emptyList(),
            minutosEstimados = null,
            aviso = avisoDe(e),
            onEmpezar = {
                entrenando = true
                segundos = 0
            },
            onIrAEjercicio = {
                actual = it
                entrenando = true
            },
            modifier = modifier,
        )
    } else {
        PantallaEntrenando(
            estado = ejercicios[actual],
            nombreEjercicio = nombres[actual],
            nombresDeLaRutina = nombres,
            indiceEjercicio = actual,
            segundosDeSesion = segundos,
            onEstado = { nuevo ->
                val antes = ejercicios[actual]
                ejercicios[actual] = nuevo
                // 🛑 Al disco en el momento, y a la red si hay: una serie que sólo vive en la
                // pantalla se pierde cuando el sistema mata la app entre serie y serie.
                sincronizador.registrar(
                    rutina.sessionId,
                    SeriesDeLaRutina.cambiosEntre(antes, nuevo, System.currentTimeMillis()),
                )
            },
            onIrAEjercicio = { actual = it },
            onTerminar = { entrenando = false },
            modifier = modifier,
        )
    }
}

/** Lo que conviene saber de la sincronización, sin alarmar: la app funciona igual sin señal. */
@Composable
private fun avisoDe(e: EstadoDelGimnasio.ConRutina): String? = when {
    e.sinConexion -> stringResource(R.string.gym_aviso_sin_conexion)
    e.sinSubir > 0 -> stringResource(R.string.gym_aviso_sin_subir, e.sinSubir)
    else -> null
}

/** El código del contrato para un perfil al que le falta lo que el plan necesita. */
private const val CODIGO_PERFIL_INCOMPLETO = "profile_incomplete"
