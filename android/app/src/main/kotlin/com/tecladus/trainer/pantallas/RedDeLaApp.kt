package com.tecladus.trainer.pantallas

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import com.tecladus.trainer.BuildConfig
import com.tecladus.trainer.core.gimnasio.AlmacenDeGimnasioCifrado
import com.tecladus.trainer.core.gimnasio.AlmacenDeSesionQueBorraElGimnasio
import com.tecladus.trainer.core.gimnasio.DiarioDeGimnasio
import com.tecladus.trainer.core.gimnasio.SincronizadorDeGimnasio
import com.tecladus.trainer.core.red.AlmacenDeSesionCifrado
import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.ClienteApi

/**
 * El cliente de red de la app de teléfono y el gimnasio que va con él: UNO de cada uno por
 * proceso.
 *
 * 🛑 No es comodidad: es lo que sostiene la regla de una sola renovación en vuelo. El
 * candado que impide canjear dos veces el mismo refresh vive ADENTRO de cada
 * `ClienteApi`, así que dos instancias son dos candados. Mientras la sesión vivía sólo
 * en memoria alcanzaba con uno por Activity; con la sesión guardada ya no: al rotar el
 * teléfono en la mitad de una renovación, la Activity nueva levantaría del almacén el
 * refresh que la vieja estaba canjeando, y lo mandaría otra vez. Dentro de los dos
 * minutos el servidor le devuelve el mismo sucesor (decisión 0013), pero en cuanto una
 * de las dos lo usa, el canje de la otra es un reuso y revoca la familia entera. Con el
 * gimnasio pasa lo mismo: dos sincronizadores sobre el mismo diario mandarían lo mismo
 * pendiente con dos claves.
 *
 * 🛑 **La sesión y el gimnasio nacen juntos a propósito.** La sesión se guarda en un
 * [AlmacenDeSesionQueBorraElGimnasio]: cualquier cierre de sesión —el botón, el servidor
 * que la da por terminada, una sesión que no se puede leer al arrancar— borra también la
 * rutina y las series guardadas, antes que la sesión. Si el gimnasio se armara aparte, ese
 * borrado dependería de que alguna pantalla se acuerde.
 *
 * Está acá y no en `TrainerApplication` porque ésa es de la app original
 * (`src/main/java`), que se descarta entera (AGENTS.md §1.2).
 *
 * La base sale de `BuildConfig.API_BASE`: en release, el servidor —hoy el de staging,
 * porque el dominio de producción no está decidido—, y en debug lo que diga
 * `trainer.apiBase` (ver `app/build.gradle.kts` y docs/CORRER-LOCAL.md §4).
 */
object RedDeLaApp {

    private class Red(val api: ApiTrainer, val gimnasio: SincronizadorDeGimnasio)

    @Volatile
    private var red: Red? = null

    fun api(contexto: Context): ApiTrainer = red(contexto).api

    fun gimnasio(contexto: Context): SincronizadorDeGimnasio = red(contexto).gimnasio

    private fun red(contexto: Context): Red =
        red ?: synchronized(this) {
            red ?: crear(contexto.applicationContext).also { red = it }
        }

    private fun crear(app: Context): Red {
        val diario = DiarioDeGimnasio(AlmacenDeGimnasioCifrado(app))
        val api = ApiTrainer(
            ClienteApi(
                baseUrl = BuildConfig.API_BASE,
                almacen = AlmacenDeSesionQueBorraElGimnasio(AlmacenDeSesionCifrado(app), diario),
            ),
        )
        val gimnasio = SincronizadorDeGimnasio(api, diario)
        vigilarLaRed(app, gimnasio)
        return Red(api, gimnasio)
    }

    /**
     * Cuando vuelve la red, lo pendiente sube solo: sin esto, las series registradas en el
     * sótano esperarían a que alguien vuelva a abrir la pantalla. Sin sesión no hace nada.
     *
     * Si el sistema no deja registrar el aviso —hay fabricantes que limitan cuántos tiene
     * una app—, lo pendiente sube igual al volver a primer plano.
     */
    private fun vigilarLaRed(app: Context, gimnasio: SincronizadorDeGimnasio) {
        val conectividad = app.getSystemService(ConnectivityManager::class.java) ?: return
        try {
            conectividad.registerDefaultNetworkCallback(
                object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        gimnasio.volvioLaRed()
                    }
                },
            )
        } catch (e: RuntimeException) {
            // Queda la sincronización al volver a primer plano. Nada que loguear: no hay dato.
        }
    }
}
