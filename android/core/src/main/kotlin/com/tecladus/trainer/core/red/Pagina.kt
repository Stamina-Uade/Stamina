package com.tecladus.trainer.core.red

/**
 * Una página de una lista del contrato (docs/API.md §1): lo que vino en `data` y la
 * `pagination` que viaja al lado.
 *
 * Para la página siguiente se pasa `paginacion.nextCursor` tal cual vino. Es opaco: el
 * cliente no lo arma ni lo interpreta, y sin `nextCursor` no hay otra página.
 */
data class Pagina<T>(val datos: List<T>, val paginacion: Paginacion)
