package com.tecladus.trainer.pantallas

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.tecladus.trainer.BuildConfig
import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.DecisionDeVersion
import com.tecladus.trainer.core.red.Plataforma
import com.tecladus.trainer.core.red.PuertaDeVersion
import com.tecladus.trainer.core.red.VersionGate
import com.tecladus.trainer.core.tema.Tema
import com.tecladus.trainer.pantallas.acceso.FlujoDeAcceso
import com.tecladus.trainer.pantallas.acceso.recordarTraductorDeErrores
import kotlinx.coroutines.launch

/**
 * La raíz de la app: lo que se decide antes que cualquier pantalla.
 *
 * Tres cosas, en este orden de prioridad:
 *
 * 1. **La puerta de versión** (AGENTS.md §5.1). Se pregunta al arrancar y otra vez cada
 *    vez que la app vuelve a primer plano ([preguntarCadaVezQueVuelve]), en paralelo y
 *    SIN esperarla: una app que se usa en un sótano no puede quedarse diez segundos en
 *    blanco esperando a un servidor que no va a contestar. Si la respuesta es
 *    `update_required`, tapa todo en cuanto llega; si es `update_recommended`, aparece
 *    un aviso que se puede descartar. Sin red, con un 503 o con cualquier otra cosa,
 *    deja pasar ([PuertaDeVersion.decidir]), salvo que el servidor ya haya contestado
 *    claro en este proceso: eso no lo deshace una falla.
 * 2. **La sesión guardada.** Si hay una, se entra derecho a la app y el flujo de acceso
 *    ni se ve. Mientras se lee —es descifrar un bloque con el Keystore, milisegundos—
 *    se pinta el fondo y nada más, para que no parpadee la bienvenida.
 * 3. **La sesión que se cierra sola.** Si el servidor dice que la sesión ya no existe,
 *    el cliente la borra y avisa por `sesionCerrada`. Acá se escucha, y se vuelve al
 *    login con el motivo a la vista, esté la persona adentro de la app o en la mitad
 *    del perfil.
 *
 * @param build el `versionCode` de este build: lo que se le manda a la puerta.
 */
@Composable
fun RaizDeLaApp(
    api: ApiTrainer,
    build: Long,
    contenidoDeGimnasio: @Composable (Modifier) -> Unit,
    modifier: Modifier = Modifier,
) {
    val traducir by rememberUpdatedState(recordarTraductorDeErrores())
    val alcance = rememberCoroutineScope()
    val abrirEnlace = LocalUriHandler.current

    var sesionLeida by remember { mutableStateOf(false) }
    var enLaApp by remember { mutableStateOf(false) }
    var avisoParaElLogin by remember { mutableStateOf<String?>(null) }
    // Cambia cada vez que el acceso tiene que arrancar de cero —cerrar sesión, o una
    // sesión que se cerró sola—: el flujo se vuelve a crear y no arrastra el paso, el
    // correo ni el borrador del perfil de antes.
    var vueltasAlAcceso by remember { mutableIntStateOf(0) }
    var puerta by remember { mutableStateOf<DecisionDeVersion>(DecisionDeVersion.Pasar) }
    var recomendacionDescartada by rememberSaveable { mutableStateOf(false) }
    var noSeAbrioLaTienda by remember { mutableStateOf(false) }

    LaunchedEffect(api) {
        enLaApp = api.restaurarSesion()
        sesionLeida = true
    }
    val cicloDeVida = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(api, build, cicloDeVida) {
        // Al arrancar y cada vez que la app vuelve a primer plano.
        preguntarCadaVezQueVuelve(cicloDeVida) {
            puerta = api.consultarPuertaDeVersion(Plataforma.ANDROID, build)
        }
    }
    LaunchedEffect(api) {
        api.sesionCerrada.collect { motivo ->
            avisoParaElLogin = traducir(motivo)
            enLaApp = false
            vueltasAlAcceso += 1
        }
    }

    fun abrirTienda(desde: VersionGate) {
        noSeAbrioLaTienda = false
        try {
            abrirEnlace.openUri(PuertaDeVersion.direccionDeLaTienda(desde, BuildConfig.APPLICATION_ID))
        } catch (e: IllegalArgumentException) {
            // Un teléfono sin Play ni navegador. Se dice, en vez de un botón que no hace nada.
            noSeAbrioLaTienda = true
        }
    }

    val decision = puerta
    Box(modifier = modifier.fillMaxSize()) {
        when {
            decision is DecisionDeVersion.Bloquear -> PantallaActualizacionObligatoria(
                puerta = decision.puerta,
                noSeAbrioLaTienda = noSeAbrioLaTienda,
                onActualizar = { abrirTienda(decision.puerta) },
            )

            !sesionLeida -> Box(modifier = Modifier.fillMaxSize().background(Tema.color.fondo))

            else -> Column(modifier = Modifier.fillMaxSize()) {
                if (decision is DecisionDeVersion.Recomendar && !recomendacionDescartada) {
                    AvisoDeActualizacion(
                        puerta = decision.puerta,
                        noSeAbrioLaTienda = noSeAbrioLaTienda,
                        onActualizar = { abrirTienda(decision.puerta) },
                        onDescartar = { recomendacionDescartada = true },
                    )
                }
                Box(modifier = Modifier.weight(1f)) {
                    if (enLaApp) {
                        CascaronApp(
                            api = api,
                            contenidoDeGimnasio = contenidoDeGimnasio,
                            onSalir = {
                                // La pantalla vuelve a la bienvenida YA. El logout sigue en
                                // segundo plano y, antes de salir a la red, borra la sesión
                                // guardada: cerrar la app en ese momento no la resucita.
                                alcance.launch { api.cerrarSesion() }
                                avisoParaElLogin = null
                                enLaApp = false
                                vueltasAlAcceso += 1
                            },
                            modifier = Modifier.fillMaxSize(),
                        )
                    } else {
                        key(vueltasAlAcceso) {
                            FlujoDeAcceso(
                                api = api,
                                onEntro = {
                                    avisoParaElLogin = null
                                    enLaApp = true
                                },
                                modifier = Modifier.fillMaxSize(),
                                avisoInicial = avisoParaElLogin,
                            )
                        }
                    }
                }
            }
        }
    }
}
