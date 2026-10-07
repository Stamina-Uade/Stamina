package com.tecladus.trainer.pantallas

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonSecundario
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.objetivoTactil
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.tema.Tema
import com.tecladus.trainer.core.red.ApiTrainer
import com.tecladus.trainer.core.red.Objetivo
import com.tecladus.trainer.core.red.ObjetivoActivo
import com.tecladus.trainer.core.red.ObjetivoEntrada
import com.tecladus.trainer.core.red.PlanDeObjetivo
import com.tecladus.trainer.core.red.Resultado
import com.tecladus.trainer.pantallas.acceso.opcionesDeObjetivo
import kotlinx.coroutines.launch

/**
 * Las cinco secciones del producto (AGENTS.md §1): registro de actividad,
 * alimentación y plan, más el inicio y el perfil.
 *
 * Gimnasio está construido; Perfil permite editar los objetivos y Plan muestra
 * sus bloques resumidos. Inicio y Nutrición todavía esperan su UI canónica en
 * `design/origen/HomeB.dc.html` y muestran ese estado a la persona.
 *
 * El ícono de cada sección se dibuja con trazos ([Iconos]) y NO es un emoji. Un
 * emoji lo pinta el sistema: cambia de forma entre teléfonos, no se puede teñir
 * con el acento cuando la pestaña está elegida, y el lector de pantalla lo lee con
 * su nombre de Unicode en el medio de la frase. Ninguno va solo: siempre tiene su
 * etiqueta debajo, y la etiqueta es lo que se anuncia.
 */
enum class Seccion(
    val icono: @Composable (Color, Modifier) -> Unit,
    @param:StringRes val etiqueta: Int,
    val dondeEstaElDiseno: String?,
) {
    INICIO({ c, m -> Iconos.Casa(c, m) }, R.string.tab_inicio, "design/origen/HomeB.dc.html · pantalla inicio"),
    PLAN({ c, m -> Iconos.Almanaque(c, m) }, R.string.tab_plan, "design/origen/HomeB.dc.html · pantalla plan"),
    GIMNASIO({ c, m -> Iconos.Mancuerna(c, m) }, R.string.tab_gimnasio, null),
    NUTRICION({ c, m -> Iconos.Manzana(c, m) }, R.string.tab_nutricion, "design/origen/HomeB.dc.html · pantalla nutricion"),
    PERFIL({ c, m -> Iconos.Persona(c, m) }, R.string.tab_perfil, "design/origen/HomeB.dc.html · perfil y ajustes"),
}

@Composable
fun CascaronApp(
    api: ApiTrainer,
    contenidoDeGimnasio: @Composable (Modifier) -> Unit,
    onSalir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var seccion by remember { mutableStateOf(Seccion.GIMNASIO) }

    Column(modifier = modifier.fillMaxSize().background(Tema.color.fondo)) {
        Box(modifier = Modifier.weight(1f)) {
            when (seccion) {
                Seccion.GIMNASIO -> contenidoDeGimnasio(Modifier.fillMaxSize())
                Seccion.PERFIL -> SeccionPerfil(api, onSalir)
                Seccion.PLAN -> SeccionPlan(api) { seccion = Seccion.PERFIL }
                else -> SeccionSinConstruir(seccion)
            }
        }
        BarraDeSecciones(seccion) { seccion = it }
    }
}

@Composable
private fun BarraDeSecciones(actual: Seccion, onElegir: (Seccion) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Tema.color.superficieBarra)
            .padding(vertical = Tema.aire.e4),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        for (s in Seccion.entries) {
            val elegida = s == actual
            val etiqueta = stringResource(s.etiqueta)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .objetivoTactil()
                    .heightIn(min = Tema.tactilMinimo)
                    .clickable { onElegir(s) }
                    .clearAndSetSemantics { contentDescription = etiqueta },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                s.icono(
                    if (elegida) Tema.color.acento else Tema.color.textoSecundario,
                    Modifier.size(Iconos.tamano),
                )
                Box(modifier = Modifier.size(Tema.aire.e3))
                Text(
                    text = etiqueta,
                    style = Tema.texto.labelNavegacion,
                    color = if (elegida) Tema.color.acento else Tema.color.textoSecundario,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/**
 * Lo que se ve donde todavía no hay nada.
 *
 * Dice qué falta y dónde está el diseño. Una sección vacía sin explicación se lee
 * como un error de la app; ésta se lee como lo que es: trabajo que no se hizo.
 */
@Composable
private fun SeccionSinConstruir(seccion: Seccion) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Tema.aire.e20),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e10, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        seccion.icono(Tema.color.textoSecundario, Modifier.size(Tema.aire.e36))
        Text(
            text = stringResource(seccion.etiqueta),
            style = Tema.texto.tituloPantalla,
            color = Tema.color.textoPrimario,
        )
        Nota(
            texto = stringResource(R.string.seccion_falta_titulo),
            icono = { c, m -> Iconos.Aviso(c, m) },
            tono = Tema.color.textoSecundario,
            estilo = Tema.texto.valorDato,
        )
        Text(
            text = stringResource(R.string.seccion_falta_cuerpo, seccion.dondeEstaElDiseno.orEmpty()),
            style = Tema.texto.cuerpo,
            color = Tema.color.textoTerciario,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun SeccionPerfil(api: ApiTrainer, onSalir: () -> Unit) {
    var actuales by remember { mutableStateOf<List<ObjetivoActivo>>(emptyList()) }
    var elegidos by remember { mutableStateOf<List<Objetivo>>(emptyList()) }
    var cargando by remember { mutableStateOf(true) }
    var guardando by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf(false) }
    val alcance = rememberCoroutineScope()
    LaunchedEffect(api) {
        when (val r = api.misObjetivos()) {
            is Resultado.Ok -> { actuales = r.dato; elegidos = r.dato.map { it.goal } }
            else -> error = true
        }
        cargando = false
    }
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Tema.aire.e20),
        verticalArrangement = Arrangement.spacedBy(Tema.aire.e12),
    ) {
        Seccion.PERFIL.icono(Tema.color.textoSecundario, Modifier.size(Tema.aire.e36))
        Text(
            text = stringResource(Seccion.PERFIL.etiqueta),
            style = Tema.texto.tituloPantalla,
            color = Tema.color.textoPrimario,
        )
        Text(stringResource(R.string.perfil_objetivos_titulo), style = Tema.texto.valorDato,
            color = Tema.color.textoPrimario)
        if (!cargando) {
            Text(stringResource(R.string.perfil_objetivos_cantidad, elegidos.size),
                style = Tema.texto.cuerpo, color = Tema.color.textoSecundario)
            opcionesDeObjetivo().forEach { opcion ->
                val marcada = opcion.id in elegidos
                Row(
                    modifier = Modifier.fillMaxWidth().heightIn(min = Tema.tactilMinimo)
                        .toggleable(value = marcada, enabled = !guardando, role = Role.Checkbox,
                            onValueChange = { elegidos = if (marcada) elegidos - opcion.id else elegidos + opcion.id }),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Checkbox(checked = marcada, onCheckedChange = null, enabled = !guardando)
                    Text(opcion.titulo, style = Tema.texto.cuerpo, color = Tema.color.textoPrimario)
                }
            }
            if (error) Text(stringResource(R.string.perfil_objetivos_error),
                style = Tema.texto.cuerpo, color = Tema.color.error)
            BotonPrimario(
                titulo = stringResource(R.string.perfil_objetivos_guardar),
                onClick = {
                    guardando = true
                    error = false
                    alcance.launch {
                        val entrada = elegidos.mapIndexed { indice, elegido ->
                            val previo = actuales.firstOrNull { it.goal == elegido }
                            ObjetivoEntrada(
                                id = if (indice == 0) "principal" else previo?.id?.takeIf { it != "principal" },
                                goal = elegido, goalDateMs = previo?.goalDateMs,
                            )
                        }
                        when (val r = api.guardarObjetivos(entrada)) {
                            is Resultado.Ok -> actuales = r.dato
                            else -> error = true
                        }
                        guardando = false
                    }
                },
                modifier = Modifier.fillMaxWidth(), habilitado = !guardando,
            )
        }
        BotonSecundario(
            texto = stringResource(R.string.seccion_salir),
            onClick = onSalir,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun SeccionPlan(api: ApiTrainer, onElegirObjetivos: () -> Unit) {
    var sinObjetivos by remember { mutableStateOf(false) }
    var planes by remember { mutableStateOf<List<PlanDeObjetivo>>(emptyList()) }
    LaunchedEffect(api) {
        val respuesta = api.misObjetivos()
        if (respuesta is Resultado.Ok) sinObjetivos = respuesta.dato.isEmpty()
        if (!sinObjetivos) {
            val calculados = api.planes()
            if (calculados is Resultado.Ok) planes = calculados.dato
        }
    }
    if (sinObjetivos) {
        Column(modifier = Modifier.fillMaxSize().padding(Tema.aire.e20),
            verticalArrangement = Arrangement.spacedBy(Tema.aire.e12, Alignment.CenterVertically)) {
            Text(stringResource(R.string.plan_proximo_titulo), style = Tema.texto.tituloPantalla,
                color = Tema.color.textoPrimario)
            BotonPrimario(titulo = stringResource(R.string.plan_proximo_boton),
                onClick = onElegirObjetivos, modifier = Modifier.fillMaxWidth())
        }
    } else if (planes.isNotEmpty()) {
        Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(Tema.aire.e20), verticalArrangement = Arrangement.spacedBy(Tema.aire.e12)) {
            Text(stringResource(R.string.perfil_objetivos_titulo), style = Tema.texto.tituloPantalla,
                color = Tema.color.textoPrimario)
            val etiquetas = opcionesDeObjetivo().associate { it.id to it.titulo }
            planes.forEach { plan ->
                Text(etiquetas[plan.plan.goal] ?: plan.plan.goal.name,
                    style = Tema.texto.valorDato, color = Tema.color.textoPrimario)
                Text(stringResource(R.string.plan_semanas, plan.plan.totalWeeks),
                    style = Tema.texto.cuerpo, color = Tema.color.textoSecundario)
            }
        }
    } else SeccionSinConstruir(Seccion.PLAN)
}
