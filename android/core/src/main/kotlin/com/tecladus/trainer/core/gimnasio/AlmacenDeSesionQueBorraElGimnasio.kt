package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.AlmacenDeSesion
import com.tecladus.trainer.core.red.Sesion

/**
 * La sesión guardada, atada al diario del gimnasio: cuando se va la sesión, se va el gimnasio.
 *
 * 🛑 **Por cualquier motivo.** `ClienteApi` borra su almacén en TODOS los caminos por los que
 * una sesión deja de existir: el logout, `olvidarSesion`, una renovación que el servidor
 * rechaza y un `session_revoked` después de renovar —los dos que avisan por
 * `sesionCerrada`—. Colgarse de ese borrado, y no de cada pantalla que cierra sesión, es lo
 * que hace que no se escape ninguno, ni siquiera el que pasa sin ninguna pantalla abierta.
 * Si se escapara uno, la cuenta que entra después vería la rutina y las series de la
 * anterior, o peor: las subiría como propias.
 *
 * El gimnasio se borra ANTES que la sesión. Si el proceso muere entre los dos, queda una
 * sesión sin diario —que se vuelve a bajar— y nunca un diario sin sesión.
 *
 * Y una sesión que no se puede leer al arrancar también se lo lleva: `AlmacenDeSesionCifrado`
 * borra por su cuenta lo que no descifra (una llave perdida, un backup de otro teléfono), y
 * ese borrado no pasa por acá.
 */
class AlmacenDeSesionQueBorraElGimnasio(
    private val sesion: AlmacenDeSesion,
    private val gimnasio: DiarioDeGimnasio,
) : AlmacenDeSesion {

    override fun leer(): Sesion? = sesion.leer().also { if (it == null) gimnasio.olvidarTodo() }

    override fun guardar(sesion: Sesion) = this.sesion.guardar(sesion)

    override fun borrar() {
        gimnasio.olvidarTodo()
        sesion.borrar()
    }
}
