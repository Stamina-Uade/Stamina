package com.tecladus.trainer.pantallas.gimnasio

import com.tecladus.trainer.core.ds.Tecla

/**
 * Lo poco que comparten las pantallas de gimnasio y no es design system.
 *
 * Está en su propio archivo y no repetido en cada pantalla porque un tope de
 * repeticiones que vive en dos lugares es un tope que en algún momento va a valer
 * dos cosas distintas.
 */

internal const val MILISEGUNDOS_POR_SEGUNDO = 1000L
private const val SEGUNDOS_POR_MINUTO = 60
internal const val SEGUNDOS_QUE_AGREGA_EL_MAS = 30

/**
 * 🛑 Topes de CLIENTE. No son validación: el servidor no existe todavía y cuando
 * exista, el tope tiene que estar de ese lado (AGENTS.md §14.1). Están acá para
 * que el teclado no deje escribir un número absurdo, no para proteger el dato.
 */
internal const val TOPE_REPETICIONES = 999
internal const val TOPE_CARGA = 500.0

private const val LARGO_MAXIMO_DEL_BUFFER = 6

/** m:ss. Con cifras tabulares el número no salta al cambiar de segundo. */
internal fun relojDe(segundos: Int): String {
    val s = segundos.coerceAtLeast(0)
    return "${s / SEGUNDOS_POR_MINUTO}:${(s % SEGUNDOS_POR_MINUTO).toString().padStart(2, '0')}"
}

/**
 * El buffer del teclado numérico. Es una función pura a propósito: se puede
 * probar sin levantar una pantalla.
 */
internal fun aplicarTecla(buffer: String, tecla: Tecla, soloEnteros: Boolean): String = when (tecla) {
    is Tecla.Borrar -> buffer.dropLast(1)
    is Tecla.Coma -> if (soloEnteros || buffer.contains(',')) buffer else "$buffer,"
    is Tecla.Digito -> (buffer + tecla.valor).take(LARGO_MAXIMO_DEL_BUFFER)
    is Tecla.Hueco -> buffer
}
