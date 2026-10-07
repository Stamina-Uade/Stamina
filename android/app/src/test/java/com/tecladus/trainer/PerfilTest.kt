package com.tecladus.trainer

import com.tecladus.trainer.core.red.Deporte
import com.tecladus.trainer.core.red.Nivel
import com.tecladus.trainer.core.red.Objetivo
import com.tecladus.trainer.core.red.SexoBiologico
import com.tecladus.trainer.pantallas.acceso.ALTURA_MAXIMA_MM
import com.tecladus.trainer.pantallas.acceso.ALTURA_MINIMA_MM
import com.tecladus.trainer.pantallas.acceso.BorradorDePerfil
import com.tecladus.trainer.pantallas.acceso.FechaSimple
import com.tecladus.trainer.pantallas.acceso.PESO_MAXIMO_G
import com.tecladus.trainer.pantallas.acceso.PESO_MINIMO_G
import com.tecladus.trainer.pantallas.acceso.PasoDePerfil
import com.tecladus.trainer.pantallas.acceso.ParteDeFecha
import com.tecladus.trainer.pantallas.acceso.alturaAMilimetros
import com.tecladus.trainer.pantallas.acceso.aEnteroEscalado
import com.tecladus.trainer.pantallas.acceso.diasDelMes
import com.tecladus.trainer.pantallas.acceso.horaDelDia
import com.tecladus.trainer.pantallas.acceso.ordenDeLaFecha
import com.tecladus.trainer.pantallas.acceso.pesoAGramos
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale
import java.util.TimeZone

/**
 * Lo que las once pantallas de perfil pueden equivocarse sin que se note.
 *
 * Corre en la JVM, sin emulador. Es todo lo que `DatosDePerfil.kt` hace: convertir
 * kilos a gramos, centímetros a milímetros, una fecha del calendario a los
 * milisegundos que guarda el contrato, y decidir qué manda cada paso. Ninguna de
 * esas cuatro cosas se ve mal en una captura de pantalla: se ven mal seis meses
 * después, en el peso de alguien.
 */
class PerfilTest {

    // ------------------------------------------------------------- números

    @Test
    fun `los kilos se guardan en gramos enteros`() {
        assertEquals(72_000, pesoAGramos("72"))
        assertEquals(72_500, pesoAGramos("72,5"))
        assertEquals(72_500, pesoAGramos("72.5"))
        assertEquals(72_500, pesoAGramos("  72,5  "))
    }

    @Test
    fun `la altura se guarda en milimetros enteros`() {
        assertEquals(1_780, alturaAMilimetros("178"))
        assertEquals(1_785, alturaAMilimetros("178,5"))
    }

    @Test
    fun `un peso fuera del rango del contrato no pasa`() {
        // Los dos extremos entran; uno más allá, no. El rango es el del contrato y
        // `perfil-contrato.test.mjs` lo ata a `openapi.yaml`.
        assertEquals(PESO_MINIMO_G, pesoAGramos((PESO_MINIMO_G / 1000).toString()))
        assertEquals(PESO_MAXIMO_G, pesoAGramos((PESO_MAXIMO_G / 1000).toString()))
        assertNull(pesoAGramos("19"))
        assertNull(pesoAGramos("401"))
        assertNull(alturaAMilimetros(((ALTURA_MINIMA_MM / 10) - 1).toString()))
        assertNull(alturaAMilimetros(((ALTURA_MAXIMA_MM / 10) + 1).toString()))
    }

    @Test
    fun `lo que no es un numero devuelve null y no cero`() {
        // Cero sería peor que null: un peso de 0 g es un dato, y un dato falso
        // viaja al servidor sin que nadie lo mire.
        assertNull(pesoAGramos(""))
        assertNull(pesoAGramos("setenta"))
        assertNull(pesoAGramos("72 kg"))
        assertNull(pesoAGramos("-72"))
        assertNull(pesoAGramos("7,2,5"))
    }

    @Test
    fun `los decimales de mas se redondean en vez de rechazarse`() {
        // 178,55 cm son 1785,5 mm: se redondea, no se discute un décimo de milímetro.
        assertEquals(1_786, alturaAMilimetros("178,55"))
        assertEquals(1_785, alturaAMilimetros("178,54"))
        // Y el redondeo arrastra bien: 9,96 con un decimal es 10,0.
        assertEquals(100, aEnteroEscalado("9,96", 10))
    }

    @Test
    fun `la hora del dia se muestra con dos digitos`() {
        assertEquals("00:00", horaDelDia(0))
        assertEquals("06:00", horaDelDia(360))
        assertEquals("18:30", horaDelDia(1110))
        assertEquals("23:59", horaDelDia(1439))
    }

    // -------------------------------------------------------------- fechas

    @Test
    fun `una fecha de nacimiento no cambia con el huso horario`() {
        // 🛑 El caso que rompe: un huso al oeste de Greenwich. Si la conversión
        // usara la medianoche LOCAL, el 24 de mayo en Buenos Aires guardaría el
        // instante que en UTC es el 24 a las 3 de la mañana, y al leerlo en Tokio
        // aparecería el 24 — pero al revés, con un huso al este, se corre un día.
        // Con medianoche UTC, la misma fecha da el mismo número en todas partes.
        val original = TimeZone.getDefault()
        try {
            val fecha = FechaSimple(1990, 5, 24)
            TimeZone.setDefault(TimeZone.getTimeZone("America/Argentina/Buenos_Aires"))
            val enBuenosAires = fecha.aEpocaMs()
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Tokyo"))
            val enTokio = fecha.aEpocaMs()
            assertEquals(enBuenosAires, enTokio)
            // Y es exactamente la medianoche UTC de ese día.
            assertEquals(643_507_200_000L, enBuenosAires)
        } finally {
            TimeZone.setDefault(original)
        }
    }

    @Test
    fun `una fecha que no existe devuelve null`() {
        assertNull(FechaSimple(2026, 2, 30).aEpocaMs())
        assertNull(FechaSimple(2025, 2, 29).aEpocaMs())
        // 2024 sí es bisiesto.
        assertTrue(FechaSimple(2024, 2, 29).aEpocaMs() != null)
    }

    @Test
    fun `los dias del mes salen del calendario y no de una tabla`() {
        assertEquals(29, diasDelMes(2024, 2))
        assertEquals(28, diasDelMes(2025, 2))
        assertEquals(31, diasDelMes(2026, 1))
        assertEquals(30, diasDelMes(2026, 4))
    }

    @Test
    fun `el orden de la rueda depende del idioma`() {
        assertEquals(
            listOf(ParteDeFecha.DIA, ParteDeFecha.MES, ParteDeFecha.ANIO),
            ordenDeLaFecha(Locale.forLanguageTag("es-AR")),
        )
        assertEquals(
            listOf(ParteDeFecha.MES, ParteDeFecha.DIA, ParteDeFecha.ANIO),
            ordenDeLaFecha(Locale.US),
        )
        assertEquals(
            listOf(ParteDeFecha.ANIO, ParteDeFecha.MES, ParteDeFecha.DIA),
            ordenDeLaFecha(Locale.forLanguageTag("ja-JP")),
        )
    }

    // ------------------------------------------------------- qué manda cada paso

    private val completo = BorradorDePerfil(
        nombre = "  Iván  ",
        apellido = "Benítez",
        nacimiento = FechaSimple(1990, 5, 24),
        sexo = SexoBiologico.MASCULINO,
        pesoEscrito = "72,5",
        alturaEscrita = "178",
        deporte = Deporte.RUNNING,
        nivel = Nivel.INTERMEDIO,
        objetivo = Objetivo.MARATON,
        fechaDelObjetivo = FechaSimple(2026, 11, 8),
        descargoAceptado = true,
        dias = mapOf(4 to 1110, 2 to 1110, 6 to 420),
    )

    private val zona = "America/Argentina/Buenos_Aires"

    @Test
    fun `cada paso manda lo suyo y nada mas`() {
        // 🛑 Es la garantía de que un paso no pise lo que guardó otro: el cliente
        // serializa sin nulls, así que un pedido que sólo trae `sport` no puede
        // borrar el nombre.
        val nombre = completo.loQueGuarda(PasoDePerfil.NOMBRE, zona)!!
        assertEquals("Iván", nombre.firstName)
        assertEquals("Benítez", nombre.lastName)
        assertNull(nombre.sport)
        assertNull(nombre.weightG)

        val cuerpo = completo.loQueGuarda(PasoDePerfil.CUERPO, zona)!!
        assertEquals(72_500, cuerpo.weightG)
        assertEquals(1_780, cuerpo.heightMm)
        assertNull(cuerpo.firstName)
    }

    @Test
    fun `un apellido vacio no viaja`() {
        // El contrato pide minLength 1: mandar "" es un 400 que se puede evitar.
        val sinApellido = completo.copy(apellido = "   ")
        assertNull(sinApellido.loQueGuarda(PasoDePerfil.NOMBRE, zona)!!.lastName)
    }

    @Test
    fun `borrar el apellido o la fecha manda un null explicito`() {
        // 🛑 `PATCH /me` es parcial: una clave ausente significa "no lo toques". Los
        // dos campos que se pueden vaciar tienen que viajar en null, o "Seguir sin
        // fecha" deja la carrera puesta y borrar el apellido no borra nada.
        assertTrue(completo.camposEnNull(PasoDePerfil.NOMBRE).isEmpty())
        assertEquals(
            setOf("last_name"),
            completo.copy(apellido = "  ").camposEnNull(PasoDePerfil.NOMBRE),
        )
        assertTrue(completo.camposEnNull(PasoDePerfil.OBJETIVO).isEmpty())
        assertEquals(
            setOf("goal_date_ms"),
            completo.copy(fechaDelObjetivo = null).camposEnNull(PasoDePerfil.OBJETIVO),
        )
        // Ningún otro paso borra nada.
        PasoDePerfil.entries
            .filter { it != PasoDePerfil.NOMBRE && it != PasoDePerfil.OBJETIVO }
            .forEach { assertTrue("$it", completo.camposEnNull(it).isEmpty()) }
    }

    @Test
    fun `el objetivo puede ir sin fecha`() {
        val conFecha = completo.loQueGuarda(PasoDePerfil.OBJETIVO, zona)!!
        assertEquals(Objetivo.MARATON, conFecha.goal)
        assertTrue(conFecha.goalDateMs != null)

        val sinFecha = completo.copy(fechaDelObjetivo = null)
            .loQueGuarda(PasoDePerfil.OBJETIVO, zona)!!
        assertEquals(Objetivo.MARATON, sinFecha.goal)
        assertNull(sinFecha.goalDateMs)
    }

    @Test
    fun `los dias viajan ordenados de lunes a domingo y con la zona`() {
        val dias = completo.loQueGuarda(PasoDePerfil.DIAS, zona)!!
        assertEquals(listOf(2, 4, 6), dias.trainingDays!!.map { it.weekday })
        assertEquals(listOf(1110, 1110, 420), dias.trainingDays!!.map { it.minuteOfDay })
        assertEquals(zona, dias.timezone)
    }

    @Test
    fun `la medicion no manda nada porque el contrato no tiene donde`() {
        // 🛑 B-006. Si algún día esto deja de ser null, es porque alguien agregó el
        // campo — y entonces `perfil-contrato.test.mjs` también tiene algo que decir.
        assertNull(completo.loQueGuarda(PasoDePerfil.MEDICION, zona))
        assertNull(completo.loQueGuarda(PasoDePerfil.LISTO, zona))
    }

    @Test
    fun `el descargo medico no se manda si no se tildo`() {
        assertNull(completo.copy(descargoAceptado = false).loQueGuarda(PasoDePerfil.SALUD, zona))
        assertEquals(
            true,
            completo.loQueGuarda(PasoDePerfil.SALUD, zona)!!.medicalDisclaimerAccepted,
        )
    }

    // ------------------------------------------------------------ el botón

    @Test
    fun `un borrador vacio no deja seguir en ningun paso que pida un dato`() {
        val vacio = BorradorDePerfil()
        val quePiden = listOf(
            PasoDePerfil.NOMBRE,
            PasoDePerfil.NACIMIENTO,
            PasoDePerfil.SEXO,
            PasoDePerfil.CUERPO,
            PasoDePerfil.DEPORTE,
            PasoDePerfil.NIVEL,
            PasoDePerfil.OBJETIVO,
            PasoDePerfil.SALUD,
            PasoDePerfil.DIAS,
        )
        quePiden.forEach { assertFalse("$it deja seguir sin dato", vacio.puedeSeguir(it)) }
        // Los dos que sí: la medición es "Ahora no" y el resumen no pide nada.
        assertTrue(vacio.puedeSeguir(PasoDePerfil.MEDICION))
        assertTrue(vacio.puedeSeguir(PasoDePerfil.LISTO))
    }

    @Test
    fun `un borrador completo deja seguir en los once`() {
        PasoDePerfil.entries.forEach {
            assertTrue("$it no deja seguir con todo cargado", completo.puedeSeguir(it))
        }
    }

    @Test
    fun `un peso mal escrito no habilita el boton`() {
        assertFalse(completo.copy(pesoEscrito = "setenta").puedeSeguir(PasoDePerfil.CUERPO))
        assertFalse(completo.copy(alturaEscrita = "").puedeSeguir(PasoDePerfil.CUERPO))
    }

    // ------------------------------------------------------------ los pasos

    @Test
    fun `los once pasos numeran del 5 al 15 en orden`() {
        assertEquals(11, PasoDePerfil.entries.size)
        assertEquals((5..15).toList(), PasoDePerfil.entries.map { it.pasoDelRegistro })
    }

    @Test
    fun `del primer paso de perfil no se vuelve y del ultimo no se sigue`() {
        // La cuenta ya existe cuando empieza el perfil: atrás no hay nada.
        assertNull(PasoDePerfil.NOMBRE.anterior())
        assertNull(PasoDePerfil.LISTO.siguiente())
        assertEquals(PasoDePerfil.NACIMIENTO, PasoDePerfil.NOMBRE.siguiente())
        assertEquals(PasoDePerfil.NOMBRE, PasoDePerfil.NACIMIENTO.anterior())
    }
}
