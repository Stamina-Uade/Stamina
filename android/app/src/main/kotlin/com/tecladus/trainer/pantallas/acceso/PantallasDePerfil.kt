package com.tecladus.trainer.pantallas.acceso

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import com.tecladus.trainer.R
import com.tecladus.trainer.core.ds.BotonDeTexto
import com.tecladus.trainer.core.ds.BotonPrimario
import com.tecladus.trainer.core.ds.CampoDeTexto
import com.tecladus.trainer.core.ds.Card
import com.tecladus.trainer.core.ds.EtiquetaSeccion
import com.tecladus.trainer.core.ds.Iconos
import com.tecladus.trainer.core.ds.Nota
import com.tecladus.trainer.core.red.Deporte
import com.tecladus.trainer.core.red.Nivel
import com.tecladus.trainer.core.red.Objetivo
import com.tecladus.trainer.core.red.SexoBiologico
import com.tecladus.trainer.core.tema.Tema
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.Month
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * Las once pantallas de perfil: `regName` … `regDone` de
 * `design/origen/Trainer App.dc.html`.
 *
 * 🛑 **Corren DESPUÉS de crear la cuenta.** El diseño las dibuja antes, y en el
 * diseño todo el perfil viaja junto en el pedido que crea la cuenta. Acá la cuenta
 * ya existe desde el paso 4 y cada una de éstas guarda lo suyo con `PATCH /me`
 * apenas se toca "Continuar". El motivo y lo que se pierde está en
 * `docs/decisiones/0008-el-perfil-va-despues-de-crear-la-cuenta.md`; en una línea:
 * mientras no haya persistencia (fase 8), un registro de quince pasos que se
 * pierde entero porque Android mató el proceso en el catorce es peor que un
 * perfil que se completa de a pedazos.
 *
 * De eso sale la única cosa que estas pantallas tienen y el diseño no: **"Completar
 * después"**. Con la cuenta ya creada, una pantalla que sólo se puede pasar
 * guardando deja encerrado a quien se quedó sin señal en el medio, con la cuenta
 * hecha y sin poder entrar. El contrato acompaña: `PerfilEntrada` no tiene ningún
 * campo obligatorio.
 */

// -------------------------------------------------------------------- molde

/**
 * El molde de las once: título, cuerpo, el contenido propio, y abajo el botón de
 * seguir con la salida de "completar después".
 */
private class MarcoDePerfil(
    val paso: PasoDePerfil,
    val borrador: BorradorDePerfil,
    val enCurso: Boolean,
    val error: String?,
    val onSeguir: () -> Unit,
    val onCompletarDespues: () -> Unit,
    val modifier: Modifier,
)

@Composable
private fun MoldeDePerfil(
    marco: MarcoDePerfil,
    titulo: String,
    cuerpo: String,
    textoDelBoton: String,
    conSalida: Boolean,
    contenido: @Composable ColumnScope.() -> Unit,
) {
    val enCurso = marco.enCurso
    val error = marco.error
    val onSeguir = marco.onSeguir
    val modifier = marco.modifier
    val puedeSeguir = marco.borrador.puedeSeguir(marco.paso)
    PasoDeRegistro(
        modifier = modifier,
        arriba = {
            TituloYCuerpo(titulo = titulo, cuerpo = cuerpo)
            contenido()
            if (error != null) {
                Nota(
                    texto = error,
                    icono = { c, m -> Iconos.Aviso(c, m) },
                    tono = Tema.color.error,
                    estilo = Tema.texto.cuerpo,
                )
            }
        },
        abajo = {
            BotonPrimario(
                titulo = textoDelBoton,
                onClick = onSeguir,
                modifier = Modifier.fillMaxWidth(),
                habilitado = !enCurso && puedeSeguir,
            )
            if (conSalida) {
                BotonDeTexto(
                    texto = stringResource(R.string.perf_despues),
                    onClick = marco.onCompletarDespues,
                    enfasis = false,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
    )
}

/** El idioma con el que se formatean fechas y meses. El de la app, no el del JVM. */
@Composable
private fun idiomaActual(): Locale = LocalContext.current.resources.configuration.locales[0]

// --------------------------------------------------------------- despachador

/**
 * Dibuja el paso que toque. Un `when` exhaustivo y no un mapa: si mañana aparece
 * un paso doce, esto no compila hasta que alguien decida qué dibuja.
 */
@Composable
fun PantallaDePerfil(
    paso: PasoDePerfil,
    borrador: BorradorDePerfil,
    onBorrador: (BorradorDePerfil) -> Unit,
    enCurso: Boolean,
    error: String?,
    onSeguir: () -> Unit,
    onCompletarDespues: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val marco = MarcoDePerfil(
        paso = paso,
        borrador = borrador,
        enCurso = enCurso,
        error = error,
        onSeguir = onSeguir,
        onCompletarDespues = onCompletarDespues,
        modifier = modifier,
    )
    val seguir = stringResource(R.string.perf_continuar)

    when (paso) {
        PasoDePerfil.NOMBRE -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_nombre_titulo),
            cuerpo = stringResource(R.string.perf_nombre_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            CampoDeTexto(
                valor = borrador.nombre,
                onCambio = { onBorrador(borrador.copy(nombre = it.take(LARGO_MAXIMO_DEL_NOMBRE))) },
                etiqueta = stringResource(R.string.perf_nombre_campo),
                marcador = stringResource(R.string.perf_nombre_pista),
                habilitado = !enCurso,
            )
            CampoDeTexto(
                valor = borrador.apellido,
                onCambio = {
                    onBorrador(borrador.copy(apellido = it.take(LARGO_MAXIMO_DEL_NOMBRE)))
                },
                etiqueta = stringResource(R.string.perf_apellido_campo),
                marcador = stringResource(R.string.perf_apellido_pista),
                ayuda = stringResource(R.string.perf_apellido_opcional),
                esUltimo = true,
                habilitado = !enCurso,
            )
        }

        PasoDePerfil.NACIMIENTO -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_nacimiento_titulo, borrador.nombre.trim()),
            cuerpo = stringResource(R.string.perf_nacimiento_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            RuedaDeNacimiento(
                borrador = borrador,
                onBorrador = onBorrador,
                habilitado = !enCurso,
            )
        }

        PasoDePerfil.SEXO -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_sexo_titulo),
            cuerpo = stringResource(R.string.perf_sexo_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            ListaDeOpciones(
                opciones = opcionesDeSexo(),
                elegida = borrador.sexo,
                onElegir = { onBorrador(borrador.copy(sexo = it)) },
                habilitado = !enCurso,
            )
        }

        PasoDePerfil.CUERPO -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_cuerpo_titulo),
            cuerpo = stringResource(R.string.perf_cuerpo_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            val pesoMal = borrador.pesoEscrito.isNotBlank() &&
                pesoAGramos(borrador.pesoEscrito) == null
            val alturaMal = borrador.alturaEscrita.isNotBlank() &&
                alturaAMilimetros(borrador.alturaEscrita) == null
            CampoDeTexto(
                valor = borrador.pesoEscrito,
                onCambio = { onBorrador(borrador.copy(pesoEscrito = it)) },
                etiqueta = stringResource(R.string.perf_peso_campo),
                marcador = stringResource(R.string.perf_peso_pista),
                error = if (pesoMal) {
                    stringResource(
                        R.string.perf_peso_mal,
                        PESO_MINIMO_G / GRAMOS_POR_KILO,
                        PESO_MAXIMO_G / GRAMOS_POR_KILO,
                    )
                } else {
                    null
                },
                esDecimal = true,
                habilitado = !enCurso,
            )
            CampoDeTexto(
                valor = borrador.alturaEscrita,
                onCambio = { onBorrador(borrador.copy(alturaEscrita = it)) },
                etiqueta = stringResource(R.string.perf_altura_campo),
                marcador = stringResource(R.string.perf_altura_pista),
                error = if (alturaMal) {
                    stringResource(
                        R.string.perf_altura_mal,
                        ALTURA_MINIMA_MM / MILIMETROS_POR_CENTIMETRO,
                        ALTURA_MAXIMA_MM / MILIMETROS_POR_CENTIMETRO,
                    )
                } else {
                    null
                },
                esDecimal = true,
                esUltimo = true,
                habilitado = !enCurso,
            )
        }

        PasoDePerfil.DEPORTE -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_deporte_titulo),
            cuerpo = stringResource(R.string.perf_deporte_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            ListaDeOpciones(
                opciones = opcionesDeDeporte(),
                elegida = borrador.deporte,
                onElegir = { onBorrador(borrador.copy(deporte = it)) },
                habilitado = !enCurso,
            )
        }

        PasoDePerfil.NIVEL -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_nivel_titulo),
            cuerpo = stringResource(R.string.perf_nivel_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            ListaDeOpciones(
                opciones = opcionesDeNivel(),
                elegida = borrador.nivel,
                onElegir = { onBorrador(borrador.copy(nivel = it)) },
                habilitado = !enCurso,
            )
        }

        PasoDePerfil.OBJETIVO -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_objetivo_titulo),
            cuerpo = stringResource(R.string.perf_objetivo_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e10)) {
                opcionesDeObjetivo().forEach { opcion ->
                    val marcada = opcion.id == borrador.objetivo || opcion.id in borrador.objetivosAdicionales
                    Row(
                        modifier = Modifier.fillMaxWidth().toggleable(
                            value = marcada, enabled = !enCurso, role = Role.Checkbox,
                            onValueChange = { seleccionada ->
                                val elegidos = listOfNotNull(borrador.objetivo) + borrador.objetivosAdicionales
                                val nuevos = if (seleccionada) elegidos + opcion.id else elegidos - opcion.id
                                onBorrador(borrador.copy(
                                    objetivo = nuevos.firstOrNull(),
                                    objetivosAdicionales = nuevos.drop(1),
                                ))
                            },
                        ).padding(vertical = Tema.aire.e10),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Checkbox(checked = marcada, onCheckedChange = null, enabled = !enCurso)
                        Text(opcion.titulo)
                    }
                }
            }
            CalendarioDelObjetivo(
                borrador = borrador,
                onBorrador = onBorrador,
                habilitado = !enCurso,
            )
        }

        PasoDePerfil.SALUD -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_salud_titulo),
            cuerpo = stringResource(R.string.perf_salud_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e10)) {
                    EtiquetaSeccion(
                        texto = stringResource(R.string.perf_salud_parar),
                        color = Tema.color.error,
                    )
                    listOf(
                        R.string.perf_salud_sintoma_pecho,
                        R.string.perf_salud_sintoma_aire,
                        R.string.perf_salud_sintoma_articulacion,
                    ).forEach { sintoma ->
                        Nota(
                            texto = stringResource(sintoma),
                            icono = { c, m -> Iconos.Punto(c, m) },
                            tono = Tema.color.textoCuerpo,
                            estilo = Tema.texto.cuerpoSecundario,
                        )
                    }
                }
            }
            Casilla(
                texto = stringResource(R.string.perf_salud_acepto),
                marcada = borrador.descargoAceptado,
                onMarcar = { onBorrador(borrador.copy(descargoAceptado = it)) },
                habilitada = !enCurso,
            )
        }

        PasoDePerfil.MEDICION -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_medicion_titulo),
            cuerpo = stringResource(R.string.perf_medicion_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            ListaDeOpciones(
                opciones = opcionesDeMedicion(),
                elegida = borrador.medicion,
                onElegir = { onBorrador(borrador.copy(medicion = it)) },
                habilitado = !enCurso,
            )
            // 🛑 B-006: el contrato no tiene dónde guardar esto. Se dice acá, en la
            // pantalla, y no sólo en un comentario: alguien que elige "Garmin" y
            // después no ve su reloj conectado merece saber por qué.
            Nota(
                texto = stringResource(R.string.perf_medicion_hueco),
                icono = { c, m -> Iconos.Aviso(c, m) },
            )
        }

        PasoDePerfil.DIAS -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_dias_titulo),
            cuerpo = stringResource(R.string.perf_dias_cuerpo),
            textoDelBoton = seguir,
            conSalida = true,
        ) {
            DiasYHorarios(borrador = borrador, onBorrador = onBorrador, habilitado = !enCurso)
        }

        PasoDePerfil.LISTO -> MoldeDePerfil(
            marco = marco,
            titulo = stringResource(R.string.perf_listo_titulo, borrador.nombre.trim()),
            cuerpo = stringResource(R.string.perf_listo_cuerpo),
            textoDelBoton = stringResource(R.string.perf_listo_ir),
            // Del último paso no se "completa después": el botón YA entra a la app.
            conSalida = false,
        ) {
            ResumenDelPerfil(borrador)
        }
    }
}

// ------------------------------------------------------------------ opciones

@Composable
private fun opcionesDeSexo(): List<OpcionDeLista<SexoBiologico>> = listOf(
    OpcionDeLista(
        SexoBiologico.FEMENINO,
        stringResource(R.string.perf_sexo_femenino),
        stringResource(R.string.perf_sexo_femenino_det),
    ),
    OpcionDeLista(
        SexoBiologico.MASCULINO,
        stringResource(R.string.perf_sexo_masculino),
        stringResource(R.string.perf_sexo_masculino_det),
    ),
    OpcionDeLista(
        SexoBiologico.SIN_DECLARAR,
        stringResource(R.string.perf_sexo_sin_declarar),
        stringResource(R.string.perf_sexo_sin_declarar_det),
    ),
)

@Composable
private fun opcionesDeDeporte(): List<OpcionDeLista<Deporte>> = listOf(
    OpcionDeLista(
        Deporte.RUNNING,
        stringResource(R.string.perf_deporte_running),
        stringResource(R.string.perf_deporte_running_det),
    ),
    OpcionDeLista(
        Deporte.CICLISMO,
        stringResource(R.string.perf_deporte_ciclismo),
        stringResource(R.string.perf_deporte_ciclismo_det),
    ),
    OpcionDeLista(
        Deporte.TREKKING,
        stringResource(R.string.perf_deporte_trekking),
        stringResource(R.string.perf_deporte_trekking_det),
    ),
    OpcionDeLista(
        Deporte.TRIATLON,
        stringResource(R.string.perf_deporte_triatlon),
        stringResource(R.string.perf_deporte_triatlon_det),
    ),
)

@Composable
private fun opcionesDeNivel(): List<OpcionDeLista<Nivel>> = listOf(
    OpcionDeLista(
        Nivel.PRINCIPIANTE,
        stringResource(R.string.perf_nivel_principiante),
        stringResource(R.string.perf_nivel_principiante_det),
    ),
    OpcionDeLista(
        Nivel.INTERMEDIO,
        stringResource(R.string.perf_nivel_intermedio),
        stringResource(R.string.perf_nivel_intermedio_det),
    ),
    OpcionDeLista(
        Nivel.AVANZADO,
        stringResource(R.string.perf_nivel_avanzado),
        stringResource(R.string.perf_nivel_avanzado_det),
    ),
)

/**
 * Los siete objetivos cerrados. El orden es el del diseño.
 *
 * 🛑 La lista es CERRADA y eso no es una limitación de la pantalla: es lo que hace
 * que el plan sea determinístico y explicable (AGENTS.md §9.1). Los mismos siete
 * están en `Objetivo` del contrato, generado desde `openapi.yaml`, así que agregar
 * uno acá sin agregarlo allá no compila.
 */
@Composable
internal fun opcionesDeObjetivo(): List<OpcionDeLista<Objetivo>> = listOf(
    Objetivo.C5K to (R.string.perf_obj_5k to R.string.perf_obj_5k_dist),
    Objetivo.C10K to (R.string.perf_obj_10k to R.string.perf_obj_10k_dist),
    Objetivo.MEDIA_MARATON to (R.string.perf_obj_media to R.string.perf_obj_media_dist),
    Objetivo.MARATON to (R.string.perf_obj_maraton to R.string.perf_obj_maraton_dist),
    Objetivo.TRAIL_MONTANA to (R.string.perf_obj_trail to R.string.perf_obj_trail_dist),
    Objetivo.TRIATLON_OLIMPICO to (R.string.perf_obj_triatlon to R.string.perf_obj_triatlon_dist),
    Objetivo.VOLVER_SIN_LESIONES to (R.string.perf_obj_volver to R.string.perf_obj_volver_dist),
).map { (id, textos) ->
    OpcionDeLista(id, stringResource(textos.first), alFinal = stringResource(textos.second))
}

@Composable
private fun opcionesDeMedicion(): List<OpcionDeLista<FuenteDeMedicion>> = listOf(
    OpcionDeLista(
        FuenteDeMedicion.GPS,
        stringResource(R.string.perf_med_gps),
        stringResource(R.string.perf_med_gps_det),
    ),
    OpcionDeLista(
        FuenteDeMedicion.GARMIN,
        stringResource(R.string.perf_med_garmin),
        stringResource(R.string.perf_med_garmin_det),
    ),
    OpcionDeLista(
        FuenteDeMedicion.APPLE,
        stringResource(R.string.perf_med_apple),
        stringResource(R.string.perf_med_apple_det),
    ),
    OpcionDeLista(
        FuenteDeMedicion.MANUAL,
        stringResource(R.string.perf_med_manual),
        stringResource(R.string.perf_med_manual_det),
    ),
)

// ------------------------------------------------------------- nacimiento

/**
 * La rueda de tres columnas, armada en el orden del idioma.
 *
 * 🛑 **Muestra una fecha desde el principio y NO la da por elegida.** Una rueda sin
 * nada en el centro no existe: siempre hay una fila ahí. Pero de esa fecha sale el
 * metabolismo basal y la zona de frecuencia cardíaca, así que "no contesté" y
 * "contesté" no pueden ser lo mismo del otro lado. La rueda arranca en treinta años
 * atrás —el medio del rango que ofrece, sin insinuar una edad "correcta"— y el
 * botón de seguir queda apagado hasta que alguien la toque. La línea de abajo lo
 * dice, para que el botón apagado no sea un misterio.
 */
@Composable
private fun RuedaDeNacimiento(
    borrador: BorradorDePerfil,
    onBorrador: (BorradorDePerfil) -> Unit,
    habilitado: Boolean,
) {
    val idioma = idiomaActual()
    val hoy = remember { LocalDate.now() }
    val ultimoAnio = hoy.year - EDAD_MINIMA_DEL_DISENO
    val anios = remember(ultimoAnio) { (PRIMER_ANIO_DE_NACIMIENTO..ultimoAnio).toList() }
    val porDefecto = remember(hoy) { FechaSimple.de(hoy.minusYears(EDAD_INICIAL_DE_LA_RUEDA)) }
    val fecha = borrador.nacimiento ?: porDefecto

    val meses = remember(idioma) {
        (1..MESES_DEL_ANIO).map {
            Month.of(it).getDisplayName(java.time.format.TextStyle.SHORT, idioma).removeSuffix(".")
        }
    }
    val orden = remember(idioma) { ordenDeLaFecha(idioma) }

    fun mover(anio: Int, mes: Int, dia: Int) {
        if (!habilitado) return
        // Cambiar de mes o de año puede dejar un 31 en un mes que no lo tiene, o un
        // 29 de febrero fuera de un bisiesto. Se recorta en vez de rechazar: quien
        // giró la rueda del año no está pidiendo perder el día.
        val diaValido = dia.coerceAtMost(diasDelMes(anio, mes))
        onBorrador(borrador.copy(nacimiento = FechaSimple(anio, mes, diaValido)))
    }

    val columnas = orden.map { parte ->
        when (parte) {
            ParteDeFecha.DIA -> ColumnaDeRueda(
                etiqueta = stringResource(R.string.perf_parte_dia),
                elementos = (1..diasDelMes(fecha.anio, fecha.mes)).map { it.toString() },
                elegido = fecha.dia - 1,
                onElegir = { mover(fecha.anio, fecha.mes, it + 1) },
            )
            ParteDeFecha.MES -> ColumnaDeRueda(
                etiqueta = stringResource(R.string.perf_parte_mes),
                elementos = meses,
                elegido = fecha.mes - 1,
                onElegir = { mover(fecha.anio, it + 1, fecha.dia) },
            )
            ParteDeFecha.ANIO -> ColumnaDeRueda(
                etiqueta = stringResource(R.string.perf_parte_anio),
                elementos = anios.map { it.toString() },
                elegido = (anios.indexOf(fecha.anio)).coerceAtLeast(0),
                onElegir = { mover(anios[it], fecha.mes, fecha.dia) },
            )
        }
    }

    RuedaDeFecha(columnas = columnas, habilitada = habilitado)

    if (borrador.nacimiento == null) {
        Nota(
            texto = stringResource(R.string.perf_nacimiento_sin_elegir),
            icono = { c, m -> Iconos.Aviso(c, m) },
            tono = Tema.color.acento,
            estilo = Tema.texto.cuerpoSecundario,
        )
    }

    // `map` es inline y `joinToString` no: un `stringResource` adentro del segundo
    // no compila. Por eso son dos pasos y no uno.
    val nombresDelOrden = orden.map {
        stringResource(
            when (it) {
                ParteDeFecha.DIA -> R.string.perf_parte_dia
                ParteDeFecha.MES -> R.string.perf_parte_mes
                ParteDeFecha.ANIO -> R.string.perf_parte_anio
            },
        )
    }.joinToString(" · ")
    Text(
        text = stringResource(R.string.perf_nacimiento_orden, idioma.toLanguageTag(), nombresDelOrden),
        style = Tema.texto.nota,
        color = Tema.color.textoTerciario,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}

private const val MESES_DEL_ANIO = 12
private const val EDAD_INICIAL_DE_LA_RUEDA = 30L

// -------------------------------------------------------------- objetivo

/** El calendario del mes, con la fecha de la carrera. Se puede seguir sin fecha. */
@Composable
private fun CalendarioDelObjetivo(
    borrador: BorradorDePerfil,
    onBorrador: (BorradorDePerfil) -> Unit,
    habilitado: Boolean,
) {
    val idioma = idiomaActual()
    val hoy = remember { LocalDate.now() }
    val mesDeHoy = remember(hoy) { YearMonth.from(hoy) }
    var mesVisible by remember {
        mutableStateOf(
            borrador.fechaDelObjetivo
                ?.let { YearMonth.of(it.anio, it.mes) }
                ?: mesDeHoy,
        )
    }

    val celdas = buildList {
        val primero = mesVisible.atDay(1)
        // ISO: lunes = 1. La semana del diseño empieza el lunes, así que los huecos
        // de adelante son exactamente `dayOfWeek - 1`.
        repeat(primero.dayOfWeek.value - 1) { add(DiaDelCalendario(null, null, false, false)) }
        for (dia in 1..mesVisible.lengthOfMonth()) {
            val fecha = mesVisible.atDay(dia)
            val simple = FechaSimple.de(fecha)
            add(
                DiaDelCalendario(
                    dia = dia,
                    fecha = simple,
                    elegido = borrador.fechaDelObjetivo == simple,
                    pasado = fecha.isBefore(hoy),
                ),
            )
        }
    }

    val nombreDelMes = mesVisible.month
        .getDisplayName(java.time.format.TextStyle.FULL, idioma)
        .replaceFirstChar { it.titlecase(idioma) }

    CalendarioMensual(
        titulo = "$nombreDelMes ${mesVisible.year}",
        nombresDeDias = (1..DIAS_DE_LA_SEMANA).map {
            DayOfWeek.of(it).getDisplayName(java.time.format.TextStyle.NARROW, idioma)
        },
        celdas = celdas,
        etiquetaMesAnterior = stringResource(R.string.perf_cal_anterior),
        etiquetaMesSiguiente = stringResource(R.string.perf_cal_siguiente),
        onMesAnterior = { if (mesVisible.isAfter(mesDeHoy)) mesVisible = mesVisible.minusMonths(1) },
        onMesSiguiente = { mesVisible = mesVisible.plusMonths(1) },
        onElegir = { onBorrador(borrador.copy(fechaDelObjetivo = it)) },
        modifier = Modifier.fillMaxWidth(),
        // Para atrás del mes de hoy no hay nada que elegir: sólo días apagados.
        hayMesAnterior = mesVisible.isAfter(mesDeHoy),
        habilitado = habilitado,
    )

    val fecha = borrador.fechaDelObjetivo?.aLocalDateONull()
    if (fecha == null) {
        Text(
            text = stringResource(R.string.perf_objetivo_sin_fecha),
            style = Tema.texto.nota,
            color = Tema.color.textoTerciario,
        )
    } else {
        val semanas = ChronoUnit.WEEKS.between(hoy, fecha).toInt().coerceAtLeast(0)
        val formato = remember(idioma) {
            DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(idioma)
        }
        val comoQueda = fecha.format(formato)
        Text(
            // Menos de siete días redondean a cero semanas, y "faltan 0 semanas" no
            // se le dice a nadie. El plural del español y el del inglés no tienen
            // categoría `zero`, así que ese caso es un string aparte y no un ítem.
            text = if (semanas == 0) {
                stringResource(R.string.perf_objetivo_esta_semana, comoQueda)
            } else {
                pluralStringResource(R.plurals.perf_objetivo_con_fecha, semanas, comoQueda, semanas)
            },
            style = Tema.texto.nota,
            color = Tema.color.acento,
        )
        BotonDeTexto(
            texto = stringResource(R.string.perf_objetivo_quitar_fecha),
            onClick = { if (habilitado) onBorrador(borrador.copy(fechaDelObjetivo = null)) },
            enfasis = false,
        )
    }
}

// ------------------------------------------------------------------- días

/** Los siete chips y, debajo, una fila por día elegido con su hora. */
@Composable
private fun DiasYHorarios(
    borrador: BorradorDePerfil,
    onBorrador: (BorradorDePerfil) -> Unit,
    habilitado: Boolean,
) {
    val idioma = idiomaActual()
    val cortos = remember(idioma) {
        (1..DIAS_DE_LA_SEMANA).map {
            DayOfWeek.of(it).getDisplayName(java.time.format.TextStyle.SHORT, idioma)
                .removeSuffix(".")
                .replaceFirstChar { c -> c.titlecase(idioma) }
        }
    }
    val largos = remember(idioma) {
        (1..DIAS_DE_LA_SEMANA).map {
            DayOfWeek.of(it).getDisplayName(java.time.format.TextStyle.FULL, idioma)
                .replaceFirstChar { c -> c.titlecase(idioma) }
        }
    }

    ChipsDeDias(
        nombresCortos = cortos,
        nombresLargos = largos,
        elegidos = borrador.dias.keys,
        onAlternar = { dia ->
            if (habilitado) {
                val nuevos = borrador.dias.toMutableMap()
                if (nuevos.remove(dia) == null) nuevos[dia] = HORA_POR_DEFECTO
                onBorrador(borrador.copy(dias = nuevos))
            }
        },
    )

    borrador.dias.keys.sorted().forEach { dia ->
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = largos[dia - 1],
                style = Tema.texto.tituloCard,
                color = Tema.color.textoPrimario,
            )
            SelectorDeHora(
                minutoDelDia = borrador.dias[dia] ?: HORA_POR_DEFECTO,
                opciones = HORAS_DEL_DISENO,
                etiqueta = largos[dia - 1],
                onElegir = { minuto ->
                    if (habilitado) onBorrador(borrador.copy(dias = borrador.dias + (dia to minuto)))
                },
            )
        }
    }

    Nota(
        texto = if (borrador.dias.isEmpty()) {
            stringResource(R.string.perf_dias_sin_dias)
        } else {
            pluralStringResource(
                R.plurals.perf_dias_avisos,
                borrador.dias.size,
                borrador.dias.size,
                MINUTOS_DE_ANTICIPACION,
            )
        },
        icono = { c, m -> Iconos.Punto(c, m) },
        tono = if (borrador.dias.isEmpty()) Tema.color.textoTerciario else Tema.color.acento,
        estilo = Tema.texto.cuerpoSecundario,
    )
}

/**
 * Las siete horas que ofrece el diseño, en minutos desde la medianoche.
 * 06:00 · 07:00 · 08:00 · 12:00 · 17:00 · 18:30 · 20:00.
 */
private val HORAS_DEL_DISENO = listOf(360, 420, 480, 720, 1020, 1110, 1200)

/** 18:30, la que el diseño trae puesta en los tres días de ejemplo. */
private const val HORA_POR_DEFECTO = 1110

/**
 * 🛑 Los 45 minutos son del diseño ("Te escribimos 45 minutos antes"). Cuando el
 * aviso exista de verdad, el número tiene que salir de un solo lado: hoy no hay
 * avisos, así que está acá y dicho.
 */
private const val MINUTOS_DE_ANTICIPACION = 45

// ---------------------------------------------------------------- resumen

/** Las cinco filas de `regDone`. Lo que no se cargó dice "—", no miente. */
@Composable
private fun ResumenDelPerfil(borrador: BorradorDePerfil) {
    val idioma = idiomaActual()
    val vacio = stringResource(R.string.perf_listo_vacio)
    val formatoCorto = remember(idioma) {
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(idioma)
    }
    val filas = listOf(
        stringResource(R.string.perf_listo_nacimiento) to
            (borrador.nacimiento?.aLocalDateONull()?.format(formatoCorto) ?: vacio),
        stringResource(R.string.perf_listo_deporte) to
            (borrador.deporte?.let { stringResource(etiquetaDeDeporte(it)) } ?: vacio),
        stringResource(R.string.perf_listo_nivel) to
            (borrador.nivel?.let { stringResource(etiquetaDeNivel(it)) } ?: vacio),
        stringResource(R.string.perf_listo_dias) to
            (
                borrador.dias.keys.sorted().joinToString(", ") { dia ->
                    DayOfWeek.of(dia)
                        .getDisplayName(java.time.format.TextStyle.SHORT, idioma)
                        .removeSuffix(".")
                        .replaceFirstChar { it.titlecase(idioma) }
                }.ifEmpty { vacio }
                ),
        stringResource(R.string.perf_listo_objetivo) to
            (borrador.objetivo?.let { stringResource(etiquetaDeObjetivo(it)) } ?: vacio),
    )

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(Tema.aire.e9)) {
            filas.forEach { (rotulo, valor) ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = rotulo,
                        style = Tema.texto.cuerpoSecundario,
                        color = Tema.color.textoSecundario,
                    )
                    Box(modifier = Modifier.weight(1f))
                    Text(
                        text = valor,
                        style = Tema.texto.valorFila,
                        color = Tema.color.textoPrimario,
                        textAlign = TextAlign.End,
                    )
                }
            }
        }
    }
}

private fun etiquetaDeDeporte(deporte: Deporte): Int = when (deporte) {
    Deporte.RUNNING -> R.string.perf_deporte_running
    Deporte.CICLISMO -> R.string.perf_deporte_ciclismo
    Deporte.TREKKING -> R.string.perf_deporte_trekking
    Deporte.TRIATLON -> R.string.perf_deporte_triatlon
}

private fun etiquetaDeNivel(nivel: Nivel): Int = when (nivel) {
    Nivel.PRINCIPIANTE -> R.string.perf_nivel_principiante
    Nivel.INTERMEDIO -> R.string.perf_nivel_intermedio
    Nivel.AVANZADO -> R.string.perf_nivel_avanzado
}

private fun etiquetaDeObjetivo(objetivo: Objetivo): Int = when (objetivo) {
    Objetivo.C5K -> R.string.perf_obj_5k
    Objetivo.C10K -> R.string.perf_obj_10k
    Objetivo.MEDIA_MARATON -> R.string.perf_obj_media
    Objetivo.MARATON -> R.string.perf_obj_maraton
    Objetivo.TRAIL_MONTANA -> R.string.perf_obj_trail
    Objetivo.TRIATLON_OLIMPICO -> R.string.perf_obj_triatlon
    Objetivo.VOLVER_SIN_LESIONES -> R.string.perf_obj_volver
}
