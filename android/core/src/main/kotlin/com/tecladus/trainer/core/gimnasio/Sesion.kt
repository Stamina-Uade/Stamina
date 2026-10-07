package com.tecladus.trainer.core.gimnasio

/**
 * La sesión de gimnasio: qué pide el plan, qué se hizo, y las reglas que deciden
 * lo que la pantalla muestra.
 *
 * Está en `:core` y no en la pantalla por dos motivos. El reloj hace las mismas
 * series (AGENTS.md §10.2) y no va a reimplementar esto; y estas reglas se
 * prueban con tests de JVM, sin emulador, que es la diferencia entre verificarlas
 * y afirmarlas.
 *
 * 🛑 Nada de acá inventa progresiones ni decide cargas. Eso es el motor de la
 * fase 7 y va en el servidor (§9.1). Acá sólo hay reglas de presentación:
 * cuál serie está apuntada, con qué valor viene precargada y cómo se ve cada chip.
 */

/** Qué significa el número que acompaña a las repeticiones. */
enum class UnidadDeCarga {
    /** Peso levantado, en kilos. */
    KILOS,

    /** Peso AGREGADO al cuerpo: dominadas con lastre. Un 0 acá es "sólo tu peso". */
    LASTRE,

    /**
     * El ejercicio se mide en segundos y el segundo número es la pausa.
     *
     * Viene de una discrepancia real entre las fuentes: `HomeB` dice
     * "3 series × 45 s · 45 s de pausa" y el reloj lo modela con peso 0 y la
     * etiqueta "Pausa (seg)", que muestra un 0 que no quiere decir nada. Manda
     * `HomeB`, que es canónico para el teléfono (`ESPECIFICACION.md` §6.2).
     */
    TIEMPO,
}

/**
 * Una serie tal como la pide el plan.
 *
 * La prescripción es una LISTA de series, una entrada por serie. No es una cadena
 * ("4 series × 8 · 45 kg"): esa discrepancia se resolvió a favor de lo
 * estructurado el 2026-09-08 (`ESPECIFICACION.md` §6.2). Con un string, un peso
 * que sube serie a serie —una rampa de aproximación— no se puede ni expresar.
 */
data class SerieObjetivo(
    val reps: Int,
    val peso: Double,
    /** `true` si la agregó la persona y no el plan. Se muestra con un "+". */
    val esExtra: Boolean = false,
)

/** Una serie tal como quedó registrada. */
data class SerieHecha(
    val reps: Int,
    val peso: Double,
    /** Salteada entera. No cuenta para la precarga de la siguiente. */
    val salteada: Boolean = false,
)

/** El ejercicio dentro de la rutina del día. */
data class Ejercicio(
    val id: String,
    val unidad: UnidadDeCarga,
    val descansoSegundos: Int,
    val prescripcion: List<SerieObjetivo>,
)

/** De dónde salió el valor que aparece precargado. La pantalla lo puede decir. */
enum class OrigenDeLaPrecarga {
    /** Del plan, para ESA serie. Pasa cuando el peso varía entre series. */
    OBJETIVO,

    /** De la última serie que se hizo de verdad EN ESTA SESIÓN. */
    ULTIMA_HECHA,

    /**
     * De lo que se hizo en esa misma serie **la sesión anterior**.
     *
     * Es la columna PREVIA. Existe porque en la primera serie del día no hay nada
     * de esta sesión con qué precargar, y el objetivo del plan puede estar lejos
     * de lo que la persona viene levantando de verdad.
     */
    SESION_ANTERIOR,
}

data class Precarga(val reps: Int, val peso: Double, val origen: OrigenDeLaPrecarga)

/**
 * Cómo se ve un chip del strip de series.
 *
 * 🛑 Cada estado se distingue por FORMA y por PALABRA, no sólo por color
 * (AGENTS.md §10.1 y `ESPECIFICACION.md` §9.3). Una serie salteada tiene borde
 * punteado y dice "salteada"; una hecha tiene borde lleno y dice "hecha". Quien
 * no distingue los colores sigue leyendo la pantalla.
 */
enum class EstadoDeChip {
    /** Hecha. Borde lleno en acento. */
    HECHA,

    /** Salteada. Borde PUNTEADO. La forma cambia, no sólo el color. */
    SALTEADA,

    /** Se está corrigiendo justo ahora. Borde punteado grueso en acento. */
    CORRIGIENDO,

    /** Es la que toca. Borde grueso en acento. */
    AHORA,

    /** Todavía no llegó. Borde fino neutro. */
    PENDIENTE,
}

data class Chip(
    val indice: Int,
    val estado: EstadoDeChip,
    /** Las repeticiones a mostrar: las hechas si ya se hizo, el objetivo si no. */
    val reps: Int,
    /** `true` si es una serie que agregó la persona: se muestra con "+". */
    val esExtra: Boolean,
)

/**
 * El estado de UN ejercicio dentro de la sesión.
 *
 * @param extras cuántas series de más agregó la persona.
 * @param hechas lo registrado, por índice de serie. Es un mapa y no una lista
 *   porque se puede corregir la serie 1 con la 3 ya hecha, y una lista con
 *   agujeros es una fuente de nulls sueltos.
 * @param corrigiendo el índice que la persona está corrigiendo, o `null`.
 * @param previas lo que se hizo en cada serie **la sesión anterior**. Es la columna
 *   PREVIA de la tabla. Viene del historial: el cliente no la calcula.
 * @param borradores lo que la persona escribió en una fila y todavía **no marcó**.
 *   Sin esto, editar el peso de la serie 3 antes de hacerla no tendría dónde vivir,
 *   y la tabla obligaría a marcar para poder escribir.
 */
data class EstadoDelEjercicio(
    val ejercicio: Ejercicio,
    val extras: Int = 0,
    val hechas: Map<Int, SerieHecha> = emptyMap(),
    val corrigiendo: Int? = null,
    val previas: Map<Int, SerieHecha> = emptyMap(),
    val borradores: Map<Int, SerieHecha> = emptyMap(),
    /**
     * Series borradas. Se guardan los ÍNDICES y no se toca nada más: lo que había
     * en `hechas` y en `borradores` sigue ahí, así que deshacer la devuelve tal
     * cual estaba. Borrar sin poder deshacer es destructivo, y una serie borrada
     * sin querer es una serie que la persona hizo y no queda en ningún lado.
     */
    val quitadas: Set<Int> = emptySet(),
    /** El descanso que eligió la persona para este ejercicio, o `null` = el del plan. */
    val descansoElegido: Int? = null,
) {

    /** El descanso que corre al marcar una serie. */
    val descansoSegundos: Int
        get() = descansoElegido ?: ejercicio.descansoSegundos

    /** El plan más las series extra. Una extra copia el objetivo de la última. */
    val objetivos: List<SerieObjetivo> by lazy {
        val base = ejercicio.prescripcion
        if (extras <= 0 || base.isEmpty()) {
            base
        } else {
            base + List(extras) { base.last().copy(esExtra = true) }
        }
    }

    /** `true` si el plan pide un peso distinto en alguna serie: una rampa. */
    val elPesoVariaEntreSeries: Boolean
        get() = objetivos.isNotEmpty() && objetivos.any { it.peso != objetivos.first().peso }

    /** Los índices que siguen en la tabla, en orden. Los borrados no están. */
    val filasVisibles: List<Int>
        get() = objetivos.indices.filter { it !in quitadas }

    /** La primera serie sin registrar, o `null` si están todas. Saltea las borradas. */
    val serieActual: Int?
        get() = filasVisibles.firstOrNull { it !in hechas }

    /** La serie apuntada: la que se está corrigiendo, o la actual, o la última. */
    val serieEnFoco: Int
        get() = corrigiendo ?: serieActual ?: (objetivos.size - 1).coerceAtLeast(0)

    /** Cuántas se hicieron de verdad. Las salteadas y las borradas no cuentan. */
    val hechasDeVerdad: Int
        get() = hechas.entries.count { it.key !in quitadas && !it.value.salteada }

    /** El índice de la última serie efectivamente hecha, o `null`. */
    val ultimaHecha: Int?
        get() = hechas.keys
            .filter { it !in quitadas && !hechas.getValue(it).salteada }
            .maxOrNull()

    /**
     * 🛑 La regla de precarga, y es determinística a propósito.
     *
     * - Si el plan pide un peso **distinto según la serie** (una rampa), se
     *   precarga el objetivo de ESA serie: el plan ya dijo qué quiere.
     * - Si el peso es **igual en todas**, se precarga la última serie
     *   efectivamente hecha: es lo que la persona acaba de levantar.
     * - Si todavía no hizo ninguna en esta sesión, **lo que hizo en esa misma
     *   serie la sesión anterior** (la columna PREVIA). Agregado el 2026-09-08 al
     *   pasar la captura a tabla: en la primera serie del día no hay nada de esta
     *   sesión con qué precargar, y el objetivo del plan puede estar lejos de lo
     *   que la persona viene levantando.
     * - Y si tampoco hay historial, el objetivo.
     *
     * No adivina progresiones. Subir la carga es del motor de la fase 7, que ve
     * el historial y el plan; una heurística acá sería el motor escondido en una
     * pantalla, donde nadie la puede revisar.
     */
    fun precarga(indice: Int): Precarga {
        val objetivo = objetivos.getOrNull(indice)
            ?: objetivos.lastOrNull()
            ?: return Precarga(0, 0.0, OrigenDeLaPrecarga.OBJETIVO)

        if (elPesoVariaEntreSeries) {
            return Precarga(objetivo.reps, objetivo.peso, OrigenDeLaPrecarga.OBJETIVO)
        }
        val ultima = ultimaHecha?.let { hechas[it] }
        if (ultima != null) {
            return Precarga(ultima.reps, ultima.peso, OrigenDeLaPrecarga.ULTIMA_HECHA)
        }
        val previa = previas[indice]
        if (previa != null && !previa.salteada) {
            return Precarga(previa.reps, previa.peso, OrigenDeLaPrecarga.SESION_ANTERIOR)
        }
        return Precarga(objetivo.reps, objetivo.peso, OrigenDeLaPrecarga.OBJETIVO)
    }

    /**
     * Lo que muestra la fila `indice` de la tabla: lo marcado, si no el borrador,
     * si no la sugerencia. Es la única fuente del número que se ve en una fila.
     */
    fun valoresDeLaFila(indice: Int): Precarga {
        hechas[indice]?.let { if (!it.salteada) return Precarga(it.reps, it.peso, OrigenDeLaPrecarga.ULTIMA_HECHA) }
        borradores[indice]?.let { return Precarga(it.reps, it.peso, OrigenDeLaPrecarga.ULTIMA_HECHA) }
        return precarga(indice)
    }

    /** `true` si la fila ya está marcada como hecha. */
    fun estaMarcada(indice: Int): Boolean = hechas[indice]?.salteada == false

    /** Escribe en una fila sin marcarla: se puede preparar la serie 3 antes de hacerla. */
    fun escribirEnLaFila(indice: Int, reps: Int, peso: Double): EstadoDelEjercicio {
        val yaHecha = hechas[indice]
        return if (yaHecha != null && !yaHecha.salteada) {
            // Editar una fila ya marcada la corrige en el lugar. No la desmarca:
            // desmarcar por escribir borraría el progreso sin que nadie lo pida.
            copy(hechas = hechas + (indice to SerieHecha(reps, peso)))
        } else {
            copy(borradores = borradores + (indice to SerieHecha(reps, peso)))
        }
    }

    /**
     * El tilde de la fila. Marcar guarda lo que muestra la fila; desmarcar deja
     * ESE valor como borrador, así que destildar sin querer no borra el número.
     */
    fun alternarLaFila(indice: Int): EstadoDelEjercicio {
        val v = valoresDeLaFila(indice)
        return if (estaMarcada(indice)) {
            copy(
                hechas = hechas - indice,
                borradores = borradores + (indice to SerieHecha(v.reps, v.peso)),
                corrigiendo = null,
            )
        } else {
            copy(
                hechas = hechas + (indice to SerieHecha(v.reps, v.peso)),
                borradores = borradores - indice,
                corrigiendo = null,
            )
        }
    }

    /** Lo que hay que mostrar en los campos: lo registrado si se corrige, si no la precarga. */
    fun valoresDelFoco(): Precarga {
        val k = serieEnFoco
        val yaHecha = hechas[k]
        return if (yaHecha != null && !yaHecha.salteada) {
            Precarga(yaHecha.reps, yaHecha.peso, OrigenDeLaPrecarga.ULTIMA_HECHA)
        } else {
            precarga(k)
        }
    }

    /** El strip completo, listo para dibujar. Sin las borradas. */
    fun strip(): List<Chip> = objetivos.mapIndexedNotNull { j, objetivo ->
        if (j in quitadas) return@mapIndexedNotNull null
        val hecha = hechas[j]
        val estado = when {
            hecha != null && hecha.salteada -> EstadoDeChip.SALTEADA
            hecha != null && j == corrigiendo -> EstadoDeChip.CORRIGIENDO
            hecha != null -> EstadoDeChip.HECHA
            j == serieEnFoco -> EstadoDeChip.AHORA
            else -> EstadoDeChip.PENDIENTE
        }
        Chip(
            indice = j,
            estado = estado,
            reps = if (hecha != null && !hecha.salteada) hecha.reps else objetivo.reps,
            esExtra = objetivo.esExtra,
        )
    }

    // ------------------------------------------------------------- transiciones

    /**
     * Registra la serie en foco. Una serie fallida se guarda como HECHA con el
     * número real: nunca como error. Bajás las repeticiones y confirmás, un tap
     * más que una serie normal. Sin rojo, sin tilde tachado, sin "no cumpliste":
     * el tono no es punitivo (AGENTS.md §9.2), y eso es regla de código y no de
     * redacción.
     */
    fun confirmar(reps: Int, peso: Double): EstadoDelEjercicio = copy(
        hechas = hechas + (serieEnFoco to SerieHecha(reps, peso)),
        corrigiendo = null,
    )

    /** Saltea la serie en foco. Un tap. El foco pasa solo a la siguiente. */
    fun saltear(): EstadoDelEjercicio = copy(
        hechas = hechas + (serieEnFoco to SerieHecha(0, 0.0, salteada = true)),
        corrigiendo = null,
    )

    /**
     * Agrega una serie más de la que pedía el plan. El progreso pasa a 4/3 y no se
     * rompe: la sesión reporta lo que se hizo, no lo que estaba prescripto.
     */
    fun agregarSerieExtra(): EstadoDelEjercicio = copy(extras = extras + 1)

    /** Apunta los campos a una serie ya hecha para corregirla, sin salir de la pantalla. */
    fun corregir(indice: Int): EstadoDelEjercicio = copy(corrigiendo = indice)

    /**
     * Borra una serie. No pierde el dato: lo guardado sigue guardado y
     * [restaurarSerie] la devuelve como estaba.
     */
    fun borrarSerie(indice: Int): EstadoDelEjercicio =
        copy(quitadas = quitadas + indice, corrigiendo = null)

    /** Deshacer. */
    fun restaurarSerie(indice: Int): EstadoDelEjercicio =
        copy(quitadas = quitadas - indice)

    /**
     * Cambia el descanso de ESTE ejercicio, para esta sesión.
     *
     * No toca el plan: el plan lo decide el motor de la fase 7. Esto es lo que la
     * persona quiere hoy, que puede no ser lo mismo.
     */
    fun conDescanso(segundos: Int): EstadoDelEjercicio =
        copy(descansoElegido = segundos.coerceIn(DESCANSO_MINIMO, DESCANSO_MAXIMO))

    companion object {
        /** Un descanso de cero es "sin descanso", y es válido: superseries. */
        const val DESCANSO_MINIMO = 0

        /** Diez minutos. Más que eso no es un descanso, es otra sesión. */
        const val DESCANSO_MAXIMO = 600
    }
}
