package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.RutinaDelDia
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Lo que el teléfono guarda del gimnasio, entero. Es exactamente lo que se borra al cerrar
 * sesión: si algo del gimnasio quedara fuera de acá, se escaparía de ese borrado.
 */
@Serializable
data class ContenidoDelDiario(
    /** La última rutina buena que mandó el servidor. Sin red, es la que se muestra. */
    @SerialName("rutina")
    val rutina: RutinaDelDia? = null,
    /** La zona del perfil, para saber sin red si la rutina guardada es la de hoy. */
    @SerialName("zona")
    val zona: String? = null,
    /** Si ya se le preguntó la zona al perfil. Un perfil sin zona no se pregunta en cada apertura. */
    @SerialName("zona_consultada")
    val zonaConsultada: Boolean = false,
    /** Las series por id de sesión: la de la rutina, y las de otros días que todavía no subieron. */
    @SerialName("sesiones")
    val sesiones: Map<String, SeriesDeSesion> = emptyMap(),
) {
    /** Cuántas series no llegaron al servidor, sumando todas las sesiones. */
    val sinSubir: Int
        get() = sesiones.values.sumOf { sesion -> sesion.series.count { it.pendiente } }
}

@Serializable
data class SeriesDeSesion(
    /** Una fila por serie, ordenadas por ejercicio y número. */
    @SerialName("series")
    val series: List<SerieRegistrada> = emptyList(),
    /**
     * El intento que salió y no tuvo respuesta. 🛑 Se reintenta IGUAL —la misma clave y el
     * mismo cuerpo—: con otra clave el servidor lo aplicaría otra vez, y con la misma clave y
     * otro cuerpo contestaría 409.
     */
    @SerialName("envio")
    val envio: EnvioEnCurso? = null,
) {
    val tieneAlgoSinSubir: Boolean
        get() = envio != null || series.any { it.pendiente }
}

/** Un intento de `POST /gym/sessions/{id}/sets`: la clave y las series tal como salieron. */
@Serializable
data class EnvioEnCurso(
    @SerialName("clave")
    val clave: String,
    @SerialName("series")
    val series: List<SerieRegistrada>,
)

/**
 * Dónde queda el diario entre una apertura de la app y la siguiente.
 *
 * En el teléfono es [AlmacenDeGimnasioCifrado]; los tests usan [AlmacenDeGimnasioEnMemoria].
 * Lo que cumple toda implementación es lo mismo que `AlmacenDeSesion`:
 *
 * - **[leer] no tira.** Devuelve `null` si no hay nada, y también si lo que hay no se puede
 *   leer; en ese caso lo borra.
 * - **[guardar] no tira.** Si no puede, queda lo anterior entero —nunca un archivo a medio
 *   escribir— y lo nuevo sigue en memoria para el próximo intento.
 * - **[borrar] no tira, y lo borrado no vuelve.**
 * - **Nada de esto va a un log.** Son datos de salud (AGENTS.md §8).
 */
interface AlmacenDeGimnasio {
    fun leer(): ContenidoDelDiario?
    fun guardar(contenido: ContenidoDelDiario)
    fun borrar()
}

/** El diario en una variable. Es el doble de los tests. */
class AlmacenDeGimnasioEnMemoria(inicial: ContenidoDelDiario? = null) : AlmacenDeGimnasio {

    @Volatile
    var guardado: ContenidoDelDiario? = inicial
        private set

    override fun leer(): ContenidoDelDiario? = guardado

    override fun guardar(contenido: ContenidoDelDiario) {
        guardado = contenido
    }

    override fun borrar() {
        guardado = null
    }
}

/**
 * El diario del gimnasio en este proceso: en memoria, y en el disco en cada cambio.
 *
 * Todo pasa por acá y con [candado]: la pantalla registra series, el sincronizador trae lo
 * del servidor y cerrar sesión lo borra. Las tres cosas pueden pasar a la vez.
 *
 * 🛑 **Cada borrado abre una generación nueva.** Un pedido que salió antes de cerrar la
 * sesión puede volver después, con las series o la rutina de la cuenta que se fue. Quien
 * pide anota la generación con la que salió ([leer]) y escribe con [cambiar], que no toca
 * nada si ya no es la misma. Sin esto, cerrar sesión con una sincronización en el aire
 * dejaba el diario de la cuenta anterior de vuelta en el disco, listo para la siguiente.
 *
 * Toca el disco en cada operación: se llama fuera del hilo principal.
 */
class DiarioDeGimnasio(private val almacen: AlmacenDeGimnasio) {

    /** Lo que hay, y de qué generación es. */
    data class Instantanea(val contenido: ContenidoDelDiario, val generacion: Long)

    private val candado = Any()

    /** Sólo con [candado]. `null` hasta la primera lectura del disco. */
    private var contenido: ContenidoDelDiario? = null

    /** Sólo con [candado]. */
    private var generacion = 0L

    private val cambiosInternos = MutableStateFlow<Instantanea?>(null)

    /** El diario cada vez que cambia. `null` hasta que alguien lo lee por primera vez. */
    val cambios: StateFlow<Instantanea?> = cambiosInternos.asStateFlow()

    /** Lo que hay ahora. La primera vez lo lee del disco. */
    fun leer(): Instantanea = synchronized(candado) { Instantanea(cargado(), generacion) }

    /**
     * Aplica [cambio] si el diario sigue siendo de la generación [desde], y lo guarda.
     *
     * @return `false` si mientras tanto se borró: no tocó nada, y quien llamó tiene datos de
     *   una sesión que ya no está.
     */
    fun cambiar(desde: Long, cambio: (ContenidoDelDiario) -> ContenidoDelDiario): Boolean =
        synchronized(candado) {
            if (desde != generacion) return false
            val antes = cargado()
            val despues = cambio(antes)
            if (despues != antes) {
                contenido = despues
                almacen.guardar(despues)
                cambiosInternos.value = Instantanea(despues, generacion)
            }
            true
        }

    /**
     * Borra todo: la memoria, el disco y lo que esté por volver de la red. No tira.
     *
     * Lo llama [AlmacenDeSesionQueBorraElGimnasio] en cualquier cierre de sesión.
     */
    fun olvidarTodo() {
        synchronized(candado) {
            generacion += 1
            contenido = ContenidoDelDiario()
            almacen.borrar()
            cambiosInternos.value = Instantanea(ContenidoDelDiario(), generacion)
        }
    }

    /** Con [candado]. */
    private fun cargado(): ContenidoDelDiario = contenido ?: (almacen.leer() ?: ContenidoDelDiario()).also {
        contenido = it
        cambiosInternos.value = Instantanea(it, generacion)
    }
}
