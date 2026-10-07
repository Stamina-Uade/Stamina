package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.DispositivoDeOrigen
import com.tecladus.trainer.core.red.EjercicioDeRutina
import com.tecladus.trainer.core.red.RutinaDelDia
import com.tecladus.trainer.core.red.SerieDeGimnasio
import com.tecladus.trainer.core.red.SerieDeGimnasioEntrada
import kotlin.math.roundToInt

/**
 * El puente entre lo que manda el servidor, lo que muestra la pantalla y lo que se guarda.
 *
 * Son tres modelos para lo mismo, y cada uno tiene su motivo. `RutinaDelDia` es el
 * contrato. [EstadoDelEjercicio] es la pantalla: va por índice y lleva lo que sólo le
 * importa a ella —el borrador de una fila, la fila que se corrige, el descanso elegido—.
 * [SerieRegistrada] es lo que se fusiona, se guarda y viaja.
 *
 * 🛑 La fuente de verdad de lo HECHO son las series registradas: la pantalla se arma desde
 * ellas ([conSeries]) y cada cambio de la pantalla vuelve como series ([cambiosEntre]).
 * Si la pantalla guardara su propio "hecho", la sincronización tendría dos verdades que
 * reconciliar, y una de las dos se perdería en silencio.
 */
object SeriesDeLaRutina {

    /** El id con el que el propio contrato dice "sin equipo" (`equipment_assumed`). */
    private const val SIN_EQUIPO = "ninguno"

    /** `unit` de un ejercicio que se mide en segundos. */
    private const val UNIDAD_TIEMPO = "tiempo"

    private const val GRAMOS_POR_KILO = 1000.0

    /** El ejercicio del contrato, en el modelo de la pantalla. */
    fun ejercicioDe(e: EjercicioDeRutina): Ejercicio = Ejercicio(
        id = e.exerciseId,
        unidad = unidadDe(e),
        descansoSegundos = e.restS,
        prescripcion = e.sets.sortedBy { it.number }.map { SerieObjetivo(it.reps, kilosDe(it.weightG)) },
    )

    /**
     * Qué quiere decir el número de la carga.
     *
     * Con `tiempo`, las repeticiones son segundos. Sin equipo, el peso es LASTRE —lo que se
     * agrega al cuerpo, donde 0 es "sólo tu peso"—; con cualquier equipo, kilos. El
     * equipamiento es dato del catálogo y no un enum, pero `ninguno` es el id con el que el
     * contrato mismo dice "sin equipo", y no crece con el catálogo.
     */
    fun unidadDe(e: EjercicioDeRutina): UnidadDeCarga = when {
        e.unit == UNIDAD_TIEMPO -> UnidadDeCarga.TIEMPO
        e.equipment == SIN_EQUIPO -> UnidadDeCarga.LASTRE
        else -> UnidadDeCarga.KILOS
    }

    /** La columna PREVIA: lo que hizo la vez anterior en cada serie, por índice. */
    fun previasDe(e: EjercicioDeRutina): Map<Int, SerieHecha> = e.previousSets
        .filter { it.number >= 1 }
        .associate { (it.number - 1) to SerieHecha(it.reps, kilosDe(it.weightG), salteada = it.skipped) }

    /** La rutina entera en el modelo de la pantalla, con lo registrado de su sesión encima. */
    fun estadosDe(rutina: RutinaDelDia, series: List<SerieRegistrada>): List<EstadoDelEjercicio> {
        val porEjercicio = series.groupBy { it.ejercicioId }
        return rutina.exercises.map { e ->
            conSeries(
                EstadoDelEjercicio(ejercicioDe(e), previas = previasDe(e)),
                porEjercicio[e.exerciseId].orEmpty(),
            )
        }
    }

    /**
     * El mismo estado de pantalla, con lo registrado puesto al día.
     *
     * Lo hecho sale de las series. Lo que es sólo de la pantalla —la fila que se corrige, las
     * borradas, el descanso elegido, el borrador de una fila sin serie— se conserva: así, una
     * sincronización que trae lo del reloj no le mueve nada a quien está escribiendo.
     */
    fun conSeries(estado: EstadoDelEjercicio, series: List<SerieRegistrada>): EstadoDelEjercicio {
        val propias = series.filter { it.ejercicioId == estado.ejercicio.id && it.numero >= 1 }
        val hechas = HashMap<Int, SerieHecha>()
        val borradores = estado.borradores.toMutableMap()
        for (s in propias) {
            val i = s.numero - 1
            when {
                s.hecha -> {
                    hechas[i] = SerieHecha(s.repeticiones, kilosDe(s.pesoG))
                    borradores.remove(i)
                }
                s.salteada -> {
                    hechas[i] = SerieHecha(0, 0.0, salteada = true)
                    borradores.remove(i)
                }
                // Desmarcada: queda como borrador con sus números, igual que al destildar.
                else -> borradores[i] = SerieHecha(s.repeticiones, kilosDe(s.pesoG))
            }
        }
        val ultima = propias.maxOfOrNull { it.numero } ?: 0
        val extras = maxOf(estado.extras, ultima - estado.ejercicio.prescripcion.size)
        return estado.copy(hechas = hechas, borradores = borradores, extras = extras)
    }

    /**
     * Las series que hay que registrar porque la pantalla pasó de [antes] a [despues].
     *
     * Cuenta sólo lo que cambia lo HECHO: marcar, corregir una marcada, saltear o desmarcar.
     * Escribir en una fila sin marcarla es un borrador y no viaja: una serie que nadie hizo
     * no es un dato, y en el servidor terminaría en la columna PREVIA de la próxima vez.
     *
     * 🛑 Desmarcar sí viaja, como una fila sin `hecha`, porque es una acción de la persona.
     * Pero la fusión es monotónica (decisión 0006, regla 2): si esa serie ya había llegado
     * hecha al servidor, la próxima sincronización la vuelve a traer hecha.
     */
    fun cambiosEntre(antes: EstadoDelEjercicio, despues: EstadoDelEjercicio, ahoraMs: Long): List<SerieRegistrada> =
        (antes.hechas.keys + despues.hechas.keys).sorted().mapNotNull { i ->
            val a = antes.hechas[i]
            val d = despues.hechas[i]
            when {
                a == d -> null
                d == null -> {
                    val v = despues.valoresDeLaFila(i)
                    registrada(despues, i, hecha = false, salteada = false, reps = v.reps, kilos = v.peso, ahoraMs)
                }
                d.salteada -> registrada(despues, i, hecha = false, salteada = true, reps = 0, kilos = 0.0, ahoraMs)
                else -> registrada(despues, i, hecha = true, salteada = false, reps = d.reps, kilos = d.peso, ahoraMs)
            }
        }

    private fun registrada(
        estado: EstadoDelEjercicio,
        indice: Int,
        hecha: Boolean,
        salteada: Boolean,
        reps: Int,
        kilos: Double,
        ahoraMs: Long,
    ) = SerieRegistrada(
        ejercicioId = estado.ejercicio.id,
        numero = indice + 1,
        hecha = hecha,
        repeticiones = reps,
        pesoG = gramosDe(kilos, estado.ejercicio.unidad),
        salteada = salteada,
        esExtra = indice >= estado.ejercicio.prescripcion.size,
        registradaLocalMs = ahoraMs,
        recibidaEnServidorMs = null,
        dispositivo = DispositivoDeOrigen.TELEFONO,
    )

    /** Lo que viaja en `POST .../sets`. La hora de llegada la pone el servidor, no se manda. */
    fun entradaDe(s: SerieRegistrada) = SerieDeGimnasioEntrada(
        exerciseId = s.ejercicioId,
        number = s.numero,
        done = s.hecha,
        reps = s.repeticiones,
        weightG = s.pesoG,
        skipped = s.salteada,
        isExtra = s.esExtra,
        recordedAtMs = s.registradaLocalMs,
        device = s.dispositivo,
    )

    /** Lo que volvió del servidor, ya con su hora de llegada. */
    fun registradaDe(s: SerieDeGimnasio) = SerieRegistrada(
        ejercicioId = s.exerciseId,
        numero = s.number,
        hecha = s.done,
        repeticiones = s.reps,
        pesoG = s.weightG,
        salteada = s.skipped,
        esExtra = s.isExtra,
        registradaLocalMs = s.recordedAtMs,
        recibidaEnServidorMs = s.receivedAtMs,
        dispositivo = s.device,
    )

    /** Gramos del contrato a los kilos de la pantalla. Sin peso es 0: peso corporal. */
    fun kilosDe(gramos: Int?): Double = (gramos ?: 0) / GRAMOS_POR_KILO

    /**
     * Los kilos de la pantalla a los gramos del contrato.
     *
     * Con tiempo no hay peso que mandar: el segundo número de esa tabla no es una carga. Y 0
     * kilos es peso corporal, que en el contrato es el campo AUSENTE y no un cero.
     */
    fun gramosDe(kilos: Double, unidad: UnidadDeCarga): Int? = when {
        unidad == UnidadDeCarga.TIEMPO -> null
        kilos <= 0.0 -> null
        else -> (kilos * GRAMOS_POR_KILO).roundToInt()
    }
}
