package com.tecladus.trainer.pantallas.acceso

import com.tecladus.trainer.core.red.Deporte
import com.tecladus.trainer.core.red.DiaEntrenamiento
import com.tecladus.trainer.core.red.Nivel
import com.tecladus.trainer.core.red.Objetivo
import com.tecladus.trainer.core.red.PerfilEntrada
import com.tecladus.trainer.core.red.SexoBiologico
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * Lo que las once pantallas de perfil juntan, y cómo se convierte en lo que el
 * contrato guarda.
 *
 * Es un archivo SIN Compose a propósito: acá vive todo lo que se puede equivocar
 * —kilos a gramos, centímetros a milímetros, una fecha a milisegundos, un día de
 * la semana a un entero ISO— y todo eso se prueba en `PerfilTest` sin levantar una
 * pantalla ni un emulador. Una conversión de unidades adentro de un `@Composable`
 * es una conversión que nadie prueba.
 *
 * 🛑 **Las unidades no se eligen acá: las manda `shared/api/openapi.yaml`.** El
 * peso viaja en gramos enteros y la altura en milímetros enteros, con sus topes.
 * Los cuatro números están abajo como constantes y `scripts/test/perfil-contrato.test.mjs`
 * los compara contra el contrato: si el contrato cambia el rango y esto no, el
 * test falla acá y no en el teléfono de alguien.
 */

// ------------------------------------------------------------------ unidades

/** `PerfilEntrada.weight_g.minimum` del contrato. */
const val PESO_MINIMO_G = 20_000

/** `PerfilEntrada.weight_g.maximum` del contrato. */
const val PESO_MAXIMO_G = 400_000

/** `PerfilEntrada.height_mm.minimum` del contrato. */
const val ALTURA_MINIMA_MM = 500

/** `PerfilEntrada.height_mm.maximum` del contrato. */
const val ALTURA_MAXIMA_MM = 2_600

/** Un kilo son mil gramos. Está nombrado para que no aparezca un 1000 suelto. */
const val GRAMOS_POR_KILO = 1_000

/** Un centímetro son diez milímetros. */
const val MILIMETROS_POR_CENTIMETRO = 10

/** `DiaEntrenamiento.minute_of_day.maximum` del contrato. */
const val ULTIMO_MINUTO_DEL_DIA = 1_439

const val MINUTOS_POR_HORA = 60

/**
 * Los años del diseño: la rueda de `regBirth` va de 1945 a "hoy menos doce".
 *
 * 🛑 El doce **no es una decisión de producto tomada**: es el número que el
 * diseño dibujó. AGENTS.md §9.2 tiene "menores" en la lista de lo que decide una
 * persona con formación, no un agente, y hasta que eso pase el cliente no puede
 * inventar otra edad mínima. Está acá con nombre para que se pueda cambiar en un
 * solo lugar el día que se decida.
 */
const val PRIMER_ANIO_DE_NACIMIENTO = 1945
const val EDAD_MINIMA_DEL_DISENO = 12

/**
 * Cuántos caracteres acepta el nombre y el apellido.
 * `PerfilEntrada.first_name.maxLength` del contrato.
 */
const val LARGO_MAXIMO_DEL_NOMBRE = 80

// --------------------------------------------------------------------- fecha

/**
 * Una fecha del calendario: año, mes (1-12) y día. No es un instante.
 *
 * Existe en vez de un `Long` porque las tres pantallas que la usan —la rueda de
 * nacimiento y el calendario del objetivo— trabajan con las tres partes por
 * separado, y convertirlas a milisegundos y de vuelta en cada recomposición es la
 * forma más simple de perder un día por el huso horario.
 */
data class FechaSimple(val anio: Int, val mes: Int, val dia: Int) {

    /** `null` si el día no existe en ese mes (31 de febrero). */
    fun aLocalDateONull(): LocalDate? = try {
        LocalDate.of(anio, mes, dia)
    } catch (e: java.time.DateTimeException) {
        null
    }

    /**
     * Los milisegundos que el contrato guarda.
     *
     * 🛑 **Medianoche UTC, no medianoche local.** Un nacimiento y una fecha de
     * carrera son fechas del calendario, no momentos: el 24 de mayo es el 24 de
     * mayo en Ushuaia y en Tokio. Si se convirtiera con el huso del teléfono, la
     * misma persona guardaría un número distinto según dónde esté parada, y al
     * volver a mostrarlo en otro huso aparecería el día anterior. Es el error
     * clásico de fechas de nacimiento y por eso está escrito.
     */
    fun aEpocaMs(): Long? =
        aLocalDateONull()?.atStartOfDay(ZoneOffset.UTC)?.toInstant()?.toEpochMilli()

    companion object {
        fun de(fecha: LocalDate) = FechaSimple(fecha.year, fecha.monthValue, fecha.dayOfMonth)
    }
}

/**
 * Las tres partes de una fecha, en el orden en que se muestran.
 *
 * Existe porque `regBirth` del diseño **no tiene un orden fijo**: lo saca del
 * `locale` con `Intl`, y por eso en es-AR la rueda es día · mes · año y en en-US
 * es mes · día · año. Copiar el orden de un país al otro no rompe nada visible:
 * simplemente hace que la gente cargue el 3 de abril como el 4 de marzo.
 */
enum class ParteDeFecha { DIA, MES, ANIO }

/**
 * En qué orden muestra las tres partes ese idioma.
 *
 * Es el equivalente de `Intl.DateTimeFormat(loc).formatToParts(...)` del diseño:
 * se le pide a Java el patrón corto del idioma y se lee el orden de sus letras.
 * Los textos entre comillas del patrón se sacan primero, porque un `'de'` tiene
 * una `d` que no es el día.
 */
fun ordenDeLaFecha(idioma: java.util.Locale): List<ParteDeFecha> {
    val patron = java.time.format.DateTimeFormatterBuilder
        .getLocalizedDateTimePattern(
            java.time.format.FormatStyle.SHORT,
            null,
            java.time.chrono.IsoChronology.INSTANCE,
            idioma,
        )
        .replace(Regex("'[^']*'"), "")
    val orden = mutableListOf<ParteDeFecha>()
    for (letra in patron) {
        val parte = when (letra) {
            'd' -> ParteDeFecha.DIA
            'M', 'L' -> ParteDeFecha.MES
            'y', 'u' -> ParteDeFecha.ANIO
            else -> null
        }
        if (parte != null && parte !in orden) orden += parte
    }
    // Si el idioma trae un patrón raro, se cae al orden más común. Tres columnas en
    // un orden discutible son mejores que una pantalla con dos.
    return if (orden.size == PARTES_DE_UNA_FECHA) orden else ORDEN_POR_DEFECTO
}

private const val PARTES_DE_UNA_FECHA = 3
private val ORDEN_POR_DEFECTO =
    listOf(ParteDeFecha.DIA, ParteDeFecha.MES, ParteDeFecha.ANIO)

/** Cuántos días tiene ese mes. Lo usan la rueda y el calendario. */
fun diasDelMes(anio: Int, mes: Int): Int = java.time.YearMonth.of(anio, mes).lengthOfMonth()

// -------------------------------------------------------------------- número

/**
 * "72,5" con [factor] 1000 devuelve 72500. Coma o punto, da igual.
 *
 * Devuelve `null` si no es un número que se pueda leer; **no** si está fuera de
 * rango. El rango lo chequea quien llama, porque el mensaje que hay que mostrar
 * es distinto: "eso no es un número" y "ese peso no puede ser" no se arreglan
 * igual.
 *
 * Redondea al último dígito que el factor puede guardar en vez de rechazar: quien
 * escribe "178,55" cm no quiere que la pantalla le discuta un décimo de milímetro.
 */
fun aEnteroEscalado(texto: String, factor: Int): Int? {
    val limpio = texto.trim().replace(',', '.')
    val partido = FORMA_DEL_NUMERO.matchEntire(limpio) ?: return null
    val entera = partido.groupValues[1].toLong()
    val digitos = factor.toString().length - 1

    // Un dígito de más que los que entran: es el que decide el redondeo.
    val decimales = partido.groupValues[2].padEnd(digitos + 1, '0')
    val guardados = if (digitos == 0) 0L else decimales.take(digitos).toLong()
    val siguiente = decimales[digitos].digitToInt()
    val decimal = if (siguiente >= REDONDEA_PARA_ARRIBA) guardados + 1 else guardados

    val total = entera * factor + decimal
    return if (total > Int.MAX_VALUE) null else total.toInt()
}

private val FORMA_DEL_NUMERO = Regex("""^(\d{1,4})(?:\.(\d{1,4}))?$""")
private const val REDONDEA_PARA_ARRIBA = 5

/** Kilos escritos a mano a los gramos del contrato, ya validados contra el rango. */
fun pesoAGramos(texto: String): Int? =
    aEnteroEscalado(texto, GRAMOS_POR_KILO)?.takeIf { it in PESO_MINIMO_G..PESO_MAXIMO_G }

/** Centímetros escritos a mano a los milímetros del contrato. */
fun alturaAMilimetros(texto: String): Int? =
    aEnteroEscalado(texto, MILIMETROS_POR_CENTIMETRO)
        ?.takeIf { it in ALTURA_MINIMA_MM..ALTURA_MAXIMA_MM }

/** "18:30" para mostrar. Con dos dígitos siempre, y sin depender del `locale`. */
fun horaDelDia(minutoDelDia: Int): String {
    val m = minutoDelDia.coerceIn(0, ULTIMO_MINUTO_DEL_DIA)
    return (m / MINUTOS_POR_HORA).toString().padStart(2, '0') +
        ":" + (m % MINUTOS_POR_HORA).toString().padStart(2, '0')
}

// ------------------------------------------------------------------ borrador

/**
 * Con qué mide sus salidas. Es `regWatch` del diseño.
 *
 * 🛑 **No tiene dónde guardarse.** `PerfilEntrada` del contrato no tiene ningún
 * campo para esto: la pantalla está dibujada y el contrato no la acompaña. Es el
 * hueco simétrico al de la contraseña (B-004) y está anotado como **B-006**. La
 * pantalla se construyó igual, y lo dice en la pantalla: un paso que pregunta algo
 * y lo tira sin avisar es peor que no preguntarlo.
 */
enum class FuenteDeMedicion { GPS, GARMIN, APPLE, MANUAL }

/**
 * Lo que se juntó hasta ahora. Vive en memoria mientras dura el flujo.
 *
 * 🛑 Cada paso lo guarda en el servidor apenas se toca "Continuar" ([loQueGuarda]),
 * así que esto es un espejo de lo guardado y no la única copia. Es justamente el
 * motivo por el que el perfil va DESPUÉS de crear la cuenta
 * (`docs/decisiones/0008`): si Android mata el proceso en el paso 8, los siete
 * anteriores ya están del otro lado.
 */
data class BorradorDePerfil(
    val nombre: String = "",
    val apellido: String = "",
    val nacimiento: FechaSimple? = null,
    val sexo: SexoBiologico? = null,
    val pesoEscrito: String = "",
    val alturaEscrita: String = "",
    val deporte: Deporte? = null,
    val nivel: Nivel? = null,
    val objetivo: Objetivo? = null,
    val objetivosAdicionales: List<Objetivo> = emptyList(),
    val fechaDelObjetivo: FechaSimple? = null,
    val descargoAceptado: Boolean = false,
    val medicion: FuenteDeMedicion? = null,
    /** ISO-8601: 1 = lunes. El valor son minutos desde la medianoche local. */
    val dias: Map<Int, Int> = emptyMap(),
) {

    /**
     * Lo que ESE paso manda a `PATCH /me`, y nada más.
     *
     * Manda sólo lo suyo por dos motivos. Uno: `PerfilEntrada` tiene todo opcional
     * y el cliente serializa sin nulls, así que un pedido chico no borra lo que ya
     * está. Dos: si el paso 9 falla, lo que falló es el paso 9 y se ve dónde.
     *
     * `null` significa "este paso no guarda nada" — el resumen, y la medición, que
     * no tiene campo (ver [FuenteDeMedicion]).
     */
    fun loQueGuarda(paso: PasoDePerfil, zonaHoraria: String): PerfilEntrada? = when (paso) {
        PasoDePerfil.NOMBRE -> PerfilEntrada(
            firstName = nombre.trim().take(LARGO_MAXIMO_DEL_NOMBRE),
            // El apellido es opcional. Vacío no se manda como `""` —el contrato
            // pide minLength 1— sino como null EXPLÍCITO, que es lo que lo borra;
            // ver [camposEnNull].
            lastName = apellido.trim().take(LARGO_MAXIMO_DEL_NOMBRE).ifBlank { null },
        )
        PasoDePerfil.NACIMIENTO -> nacimiento?.aEpocaMs()?.let { PerfilEntrada(birthdateMs = it) }
        PasoDePerfil.SEXO -> sexo?.let { PerfilEntrada(biologicalSex = it) }
        PasoDePerfil.CUERPO -> PerfilEntrada(
            weightG = pesoAGramos(pesoEscrito),
            heightMm = alturaAMilimetros(alturaEscrita),
        )
        PasoDePerfil.DEPORTE -> deporte?.let { PerfilEntrada(sport = it) }
        PasoDePerfil.NIVEL -> nivel?.let { PerfilEntrada(level = it) }
        // 🛑 La fecha viaja SIEMPRE, incluso sin fecha: el diseño deja seguir sin
        // ella y el contrato modela ese null a propósito ("está y vale nada"). Que
        // llegue como null y no como ausencia lo resuelve [camposEnNull]: acá un
        // `goalDateMs = null` no se serializa, y sin eso "Seguir sin fecha" no
        // borraría la fecha que ya estaba guardada.
        PasoDePerfil.OBJETIVO -> objetivo?.let {
            PerfilEntrada(goal = it, goalDateMs = fechaDelObjetivo?.aEpocaMs())
        }
        PasoDePerfil.SALUD ->
            if (descargoAceptado) PerfilEntrada(medicalDisclaimerAccepted = true) else null
        PasoDePerfil.MEDICION -> null
        PasoDePerfil.DIAS -> PerfilEntrada(
            trainingDays = diasDeEntrenamiento(),
            // La zona va CON los días y no antes: un "18:30" sin zona no es una
            // hora, y el aviso de preparación se dispara con las dos cosas.
            timezone = zonaHoraria.take(LARGO_MAXIMO_DE_ZONA),
        )
        PasoDePerfil.LISTO -> null
    }

    /**
     * Los campos que ese paso manda como `null` EXPLÍCITO, con el nombre del
     * contrato.
     *
     * 🛑 Es la diferencia entre "no lo toques" y "borralo". `PATCH /me` es parcial:
     * una clave ausente deja el valor viejo. Los dos campos que se pueden vaciar
     * —el apellido y la fecha de la carrera— necesitan viajar en null, y el JSON
     * del cliente no serializa nulls. Ver `ApiTrainer.guardarPerfil`.
     */
    fun camposEnNull(paso: PasoDePerfil): Set<String> = when (paso) {
        PasoDePerfil.NOMBRE ->
            if (apellido.isBlank()) setOf("last_name") else emptySet()
        PasoDePerfil.OBJETIVO ->
            if (fechaDelObjetivo?.aEpocaMs() == null) setOf("goal_date_ms") else emptySet()
        else -> emptySet()
    }

    /** Los días elegidos, ordenados de lunes a domingo como los pide el contrato. */
    fun diasDeEntrenamiento(): List<DiaEntrenamiento> = dias.entries
        .filter { it.key in 1..DIAS_DE_LA_SEMANA && it.value in 0..ULTIMO_MINUTO_DEL_DIA }
        .sortedBy { it.key }
        .map { DiaEntrenamiento(weekday = it.key, minuteOfDay = it.value) }

    /**
     * Si ese paso puede seguir. Es lo que habilita el botón.
     *
     * Los pasos de elegir-uno arrancan **sin nada elegido** y por eso pueden estar
     * en `false`: el diseño los dibuja con una opción ya marcada, y una opción
     * marcada de fábrica es un dato que alguien no eligió. Para el sexo biológico y
     * el nivel eso no es cosmético — de ahí salen la sudoración estimada y el
     * volumen inicial del plan.
     */
    fun puedeSeguir(paso: PasoDePerfil): Boolean = when (paso) {
        PasoDePerfil.NOMBRE -> nombre.isNotBlank()
        PasoDePerfil.NACIMIENTO -> nacimiento?.aEpocaMs() != null
        PasoDePerfil.SEXO -> sexo != null
        PasoDePerfil.CUERPO ->
            pesoAGramos(pesoEscrito) != null && alturaAMilimetros(alturaEscrita) != null
        PasoDePerfil.DEPORTE -> deporte != null
        PasoDePerfil.NIVEL -> nivel != null
        PasoDePerfil.OBJETIVO -> objetivo != null
        PasoDePerfil.SALUD -> descargoAceptado
        // "Ahora no" del diseño: se puede seguir sin elegir nada.
        PasoDePerfil.MEDICION -> true
        PasoDePerfil.DIAS -> dias.isNotEmpty()
        PasoDePerfil.LISTO -> true
    }
}

const val DIAS_DE_LA_SEMANA = 7

/** `PerfilEntrada.timezone.maxLength` del contrato. */
const val LARGO_MAXIMO_DE_ZONA = 64

/**
 * Los once pasos históricos del perfil siguen disponibles, pero el alta nueva
 * carga el nombre antes del correo y empieza acá en NACIMIENTO.
 *
 * [pasoDelRegistro] es el número que muestra la barra, y sigue el de
 * [PasoDeAcceso]: el nombre es 1 y el resumen es 15. La cuenta ya existe desde el
 * paso 5, pero la barra no se reinicia — para quien lo está usando esto es un solo
 * trámite, y una barra que vuelve a cero a la mitad se lee como "empezá de nuevo".
 */
enum class PasoDePerfil(val pasoDelRegistro: Int) {
    NOMBRE(5),
    NACIMIENTO(6),
    SEXO(7),
    CUERPO(8),
    DEPORTE(9),
    NIVEL(10),
    OBJETIVO(11),

    /** `regHealth` del diseño. NO es el aviso de salud de [PasoDeAcceso.REG_AVISO]. */
    SALUD(12),

    /** 🛑 No tiene campo en el contrato. Ver [FuenteDeMedicion] y B-006. */
    MEDICION(13),
    DIAS(14),
    LISTO(15),
    ;

    /** El siguiente, o `null` si es el último. */
    fun siguiente(): PasoDePerfil? = PasoDePerfil.entries.getOrNull(ordinal + 1)

    /** El anterior, o `null` si es el primero: del primero NO se vuelve. */
    fun anterior(): PasoDePerfil? = PasoDePerfil.entries.getOrNull(ordinal - 1)
}
