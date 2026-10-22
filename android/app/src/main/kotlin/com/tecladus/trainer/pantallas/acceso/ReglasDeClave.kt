package com.tecladus.trainer.pantallas.acceso

import androidx.annotation.StringRes
import com.tecladus.trainer.R

/**
 * Las reglas de contraseña que la pantalla MUESTRA mientras alguien escribe.
 *
 * 🛑 Son exactamente TRES, y no es un número redondo elegido acá: el diseño
 * (`design/origen/Trainer App.dc.html`, pantalla `fpNew`) dibuja **tres barras de
 * fuerza y tres puntitos**. Una cuarta regla no tiene dónde ir, y una tercera que
 * sobre deja un puntito que no se puede completar.
 *
 * 🛑 Y son las mismas tres que aplica `backend/src/infra/password.ts`.
 * `scripts/test/entorno-local.test.mjs` lo comprueba leyendo los dos archivos: si
 * el servidor deja de exigir la mayúscula y esto no, la pantalla pide de más; al
 * revés, deja pasar algo que el servidor rechaza y el error llega después del
 * viaje.
 *
 * Desde el contrato 1.6.0 el servidor ya no rechaza contraseñas conocidas ni con
 * pocos caracteres distintos: `weak_password` es sólo no cumplir estas tres. Si
 * igual llega, `error_weak_password` repite las tres reglas.
 */
class ReglaDeClave internal constructor(
    /** El id que usa el test para chequear que las tres siguen estando. */
    val id: String,
    @param:StringRes val etiqueta: Int,
    /** El argumento de formato de [etiqueta], o `null` si no lleva. */
    val argumento: Int?,
    val cumple: (String) -> Boolean,
)

/**
 * El mínimo que piden el contrato (`components.schemas.Password.minLength`) y el
 * servidor (`LARGO_MINIMO` de `password.ts`). Los tres tienen que decir lo mismo y
 * hay un test que lo verifica.
 *
 * El diseño dice 8. Iván decidió el 2026-09-09 quedarse con 10 y sumarle igual la
 * mayúscula y el número del diseño: lo más estricto de los dos lados.
 */
const val LARGO_MINIMO_DE_CLAVE = 10

/**
 * Mayúsculas acentuadas y la Ñ cuentan.
 *
 * `Character.isUpperCase` y no `it in 'A'..'Z'` por el mismo motivo que el
 * servidor usa `\p{Lu}`: a alguien que escribió `Ángela-corre-2026` decirle que le
 * falta una mayúscula es justo lo que hace que termine poniendo `Password1`.
 */
val REGLAS_DE_CLAVE: List<ReglaDeClave> = listOf(
    ReglaDeClave(
        id = "LARGO",
        etiqueta = R.string.reg_clave_regla_largo,
        argumento = LARGO_MINIMO_DE_CLAVE,
        cumple = { it.length >= LARGO_MINIMO_DE_CLAVE },
    ),
    ReglaDeClave(
        id = "MAYUSCULA",
        etiqueta = R.string.reg_clave_regla_mayuscula,
        argumento = null,
        cumple = { clave -> clave.any { it.isUpperCase() } },
    ),
    ReglaDeClave(
        id = "NUMERO",
        etiqueta = R.string.reg_clave_regla_numero,
        argumento = null,
        cumple = { clave -> clave.any { it.isDigit() } },
    ),
)

/** Cuántas de las tres cumple. Es lo que llena las barras. */
fun fuerzaDeClave(clave: String): Int = REGLAS_DE_CLAVE.count { it.cumple(clave) }

/** `true` si cumple las tres. No dice nada de las reglas que sólo el servidor ve. */
fun claveCompleta(clave: String): Boolean = fuerzaDeClave(clave) == REGLAS_DE_CLAVE.size
