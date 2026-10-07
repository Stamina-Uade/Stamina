package com.tecladus.trainer.core.red

/**
 * Dónde queda la sesión entre una vez que se abre la app y la siguiente.
 *
 * En el teléfono es [AlmacenDeSesionCifrado], sobre el Android Keystore. Es una
 * interfaz para que el cliente no dependa del Keystore —que en la JVM de los tests
 * no existe—; los tests usan [AlmacenDeSesionEnMemoria].
 *
 * Lo que cumple toda implementación, y [ClienteApi] da por hecho:
 *
 * - **[leer] no tira.** Devuelve `null` si no hay nada, y también si lo que hay no
 *   se puede leer. En ese caso lo borra: una sesión ilegible no se arregla
 *   reintentando, y dejarla es fallar igual en cada arranque.
 * - **[guardar] no tira, y si no puede guardar NO deja la sesión anterior.** El
 *   refresh de la anterior ya se canjeó: si quedara en el disco, el próximo arranque
 *   lo mandaría de nuevo, el servidor vería un reuso y revocaría la familia entera.
 *   Mejor pedir login que eso.
 * - **[borrar] no tira, y lo borrado no vuelve.** Aunque el disco no deje borrar, lo
 *   que quedó no se puede volver a leer. Si no, un logout sin señal reaparece adentro
 *   de la cuenta en el próximo arranque, o vuelve un refresh ya canjeado.
 * - **Nada de esto va a un log.** Ni la sesión, ni los tokens, ni lo cifrado.
 *
 * Las tres operaciones pueden tocar el disco: [ClienteApi] las llama fuera del hilo
 * principal.
 */
interface AlmacenDeSesion {
    fun leer(): Sesion?
    fun guardar(sesion: Sesion)
    fun borrar()
}

/**
 * La sesión en una variable, y nada más.
 *
 * Es el doble de los tests y el valor por defecto de [ClienteApi]: sin un almacén
 * explícito, cerrar la app cierra la sesión, que es lo seguro para quien no dijo
 * dónde guardarla.
 */
class AlmacenDeSesionEnMemoria(inicial: Sesion? = null) : AlmacenDeSesion {

    @Volatile
    private var guardada: Sesion? = inicial

    override fun leer(): Sesion? = guardada

    override fun guardar(sesion: Sesion) {
        guardada = sesion
    }

    override fun borrar() {
        guardada = null
    }
}
