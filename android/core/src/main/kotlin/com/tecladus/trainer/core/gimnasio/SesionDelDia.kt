package com.tecladus.trainer.core.gimnasio

import java.time.DateTimeException
import java.time.Instant
import java.time.ZoneId
import java.util.Locale

/**
 * El id de la sesión de gimnasio de un día: `gym-YYYY-MM-DD`, con la fecha LOCAL.
 *
 * Es el id que derivan los dos dispositivos y el servidor (`IdDeSesionDeGimnasio` en el
 * contrato, `ClaveDeSerie.sesionDeGimnasio` en TrainerCore): así el teléfono y el reloj
 * escriben en la misma sesión sin haberse puesto de acuerdo.
 *
 * 🛑 La fecha local es la de la zona del PERFIL, y la del teléfono sólo si el perfil no
 * tiene zona. Con la del teléfono a secas, a quien viajó y entrena de noche el teléfono le
 * diría "hoy" y el servidor "mañana", y cada uno anotaría en una sesión distinta.
 *
 * Una zona que no existe —un id mal escrito, o uno que el sistema todavía no conoce— cae
 * en la del teléfono: mejor un día que puede estar corrido que no poder registrar nada.
 */
fun idDeSesionDeGimnasio(instanteMs: Long, zonaDelPerfil: String?): String {
    val zona = zonaDelPerfil?.let(::zonaONull) ?: ZoneId.systemDefault()
    val fecha = Instant.ofEpochMilli(instanteMs).atZone(zona).toLocalDate()
    return String.format(Locale.ROOT, "gym-%04d-%02d-%02d", fecha.year, fecha.monthValue, fecha.dayOfMonth)
}

private fun zonaONull(id: String): ZoneId? = try {
    ZoneId.of(id)
} catch (e: DateTimeException) {
    null
}
