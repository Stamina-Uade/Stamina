package com.tecladus.trainer.pantallas.gimnasio

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import com.tecladus.trainer.R
import com.tecladus.trainer.core.gimnasio.Ejercicio
import com.tecladus.trainer.core.gimnasio.EstadoDelEjercicio
import com.tecladus.trainer.core.gimnasio.SerieHecha
import com.tecladus.trainer.core.gimnasio.SerieObjetivo
import com.tecladus.trainer.core.gimnasio.UnidadDeCarga
import com.tecladus.trainer.pantallas.TemaDeLaApp

/**
 * La rutina de ejemplo, SÓLO para la vista previa de Android Studio.
 *
 * 🛑 Ninguna pantalla de la app la muestra: la rutina de verdad viene de
 * `GET /plan/routine`, y sin ella la sección dice que no hay (ver `GimnasioActivity`).
 * Estuvo cableada en la sección de gimnasio hasta que se conectó el endpoint, y quedó acá
 * porque el press con RAMPA es el único caso que hace visible la regla de precarga
 * (`ESPECIFICACION.md` §6.2): el servidor todavía no prescribe peso.
 *
 * Los seis ejercicios y sus prescripciones salen de `design/origen/HomeB.dc.html`, que es
 * la fuente canónica del teléfono. La distribución muscular y la duración también son de
 * ejemplo: con datos reales, hoy la pantalla no las muestra.
 */
@Preview
@Composable
private fun VistaPreviaDeLaRutina() {
    TemaDeLaApp {
        PantallaRutina(
            ejercicios = RUTINA_DE_EJEMPLO.map { EstadoDelEjercicio(it.ejercicio, previas = it.previas) },
            nombres = RUTINA_DE_EJEMPLO.map { stringResource(it.nombre) },
            distribucion = DISTRIBUCION_DE_EJEMPLO.map { stringResource(it.first) to it.second },
            minutosEstimados = MINUTOS_DE_EJEMPLO,
            aviso = null,
            onEmpezar = {},
            onIrAEjercicio = {},
        )
    }
}

/** Un ejercicio de la rutina de ejemplo: el modelo más su nombre para mostrar. */
private class EjercicioDeEjemplo(
    @param:StringRes val nombre: Int,
    val ejercicio: Ejercicio,
    /** Lo que "se hizo la sesión anterior": alimenta la columna PREVIA. */
    val previas: Map<Int, SerieHecha> = emptyMap(),
)

private val RUTINA_DE_EJEMPLO: List<EjercicioDeEjemplo> = listOf(
    EjercicioDeEjemplo(
        R.string.gym_demo_press,
        Ejercicio(
            id = "press-banca",
            unidad = UnidadDeCarga.KILOS,
            descansoSegundos = 90,
            prescripcion = listOf(
                SerieObjetivo(10, 40.0),
                SerieObjetivo(8, 45.0),
                SerieObjetivo(8, 45.0),
                SerieObjetivo(6, 47.5),
            ),
        ),
        previas = mapOf(
            0 to SerieHecha(10, 40.0),
            1 to SerieHecha(8, 45.0),
            2 to SerieHecha(8, 42.5),
            3 to SerieHecha(6, 45.0),
        ),
    ),
    EjercicioDeEjemplo(
        R.string.gym_demo_dominadas,
        Ejercicio(
            id = "dominadas",
            unidad = UnidadDeCarga.LASTRE,
            descansoSegundos = 90,
            prescripcion = List(4) { SerieObjetivo(6, 0.0) },
        ),
    ),
    EjercicioDeEjemplo(
        R.string.gym_demo_remo,
        Ejercicio(
            id = "remo-barra",
            unidad = UnidadDeCarga.KILOS,
            descansoSegundos = 75,
            prescripcion = List(3) { SerieObjetivo(10, 35.0) },
        ),
        previas = mapOf(0 to SerieHecha(10, 32.5), 1 to SerieHecha(10, 32.5)),
    ),
    EjercicioDeEjemplo(
        R.string.gym_demo_bulgara,
        Ejercicio(
            id = "bulgara",
            unidad = UnidadDeCarga.KILOS,
            descansoSegundos = 75,
            prescripcion = List(3) { SerieObjetivo(10, 12.0) },
        ),
    ),
    EjercicioDeEjemplo(
        R.string.gym_demo_talones,
        Ejercicio(
            id = "talones",
            unidad = UnidadDeCarga.KILOS,
            descansoSegundos = 60,
            prescripcion = List(3) { SerieObjetivo(15, 20.0) },
        ),
    ),
    EjercicioDeEjemplo(
        R.string.gym_demo_plancha,
        Ejercicio(
            id = "plancha",
            unidad = UnidadDeCarga.TIEMPO,
            descansoSegundos = 45,
            prescripcion = List(3) { SerieObjetivo(45, 45.0) },
        ),
    ),
)

private val DISTRIBUCION_DE_EJEMPLO: List<Pair<Int, Int>> = listOf(
    R.string.gym_musculo_pecho to 26,
    R.string.gym_musculo_espalda to 24,
    R.string.gym_musculo_cuadriceps to 18,
    R.string.gym_musculo_gluteos to 14,
    R.string.gym_musculo_gemelos to 10,
    R.string.gym_musculo_core to 8,
)

private const val MINUTOS_DE_EJEMPLO = 55
