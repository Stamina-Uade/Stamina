package com.tecladus.trainer.core.gimnasio

import com.tecladus.trainer.core.red.DispositivoDeOrigen
import java.io.File
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * El diario del gimnasio en el disco: que sobreviva a la muerte del proceso, que no se lea
 * en claro, y que lo borrado —y lo que vuelve de la red después de borrar— no vuelva.
 *
 * Corre en la JVM sobre una carpeta temporal. El Keystore se reemplaza por una llave AES de
 * software, igual que en `AlmacenDeSesionTest`: lo que se prueba es lo que va encima.
 */
class DiarioDeGimnasioTest {

    @get:Rule
    val temporal = TemporaryFolder()

    private val llave: SecretKey = llaveDeSoftware()
    private var llavesDestruidas = 0

    private fun llaveDeSoftware(): SecretKey = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    private fun almacen(carpeta: File, conLlave: SecretKey = llave) =
        AlmacenDeGimnasioCifrado(carpeta, { llavesDestruidas++ }) { conLlave }

    private fun contenidoDePrueba() = ContenidoDelDiario(
        zona = "America/Argentina/Buenos_Aires",
        zonaConsultada = true,
        sesiones = mapOf(
            "gym-2026-09-10" to SeriesDeSesion(
                series = listOf(
                    SerieRegistrada(
                        ejercicioId = "estocada-deficit",
                        numero = 1,
                        hecha = true,
                        repeticiones = 10,
                        pesoG = 12_000,
                        salteada = false,
                        esExtra = false,
                        registradaLocalMs = 1_789_033_482_979,
                        recibidaEnServidorMs = null,
                        dispositivo = DispositivoDeOrigen.TELEFONO,
                    ),
                ),
                envio = EnvioEnCurso("intento-1", emptyList()),
            ),
        ),
    )

    private var carpetaBloqueada: File? = null

    @After
    fun despues() {
        carpetaBloqueada?.setWritable(true)
    }

    @Test
    fun `lo guardado sobrevive a que el sistema mate la app`() {
        val carpeta = temporal.newFolder("gimnasio")
        val antes = DiarioDeGimnasio(almacen(carpeta))
        assertTrue(antes.cambiar(antes.leer().generacion) { contenidoDePrueba() })

        // Otro proceso: otro diario y otro almacén, sobre el mismo disco.
        val despues = DiarioDeGimnasio(almacen(carpeta))

        assertEquals(contenidoDePrueba(), despues.leer().contenido)
    }

    @Test
    fun `en el disco no se lee nada en claro`() {
        val carpeta = temporal.newFolder("gimnasio")
        almacen(carpeta).guardar(contenidoDePrueba())

        val crudo = String(File(carpeta, AlmacenDeGimnasioCifrado.ARCHIVO).readBytes(), Charsets.ISO_8859_1)

        assertFalse(crudo.contains("estocada-deficit"))
        assertFalse(crudo.contains("12000"))
        assertFalse(crudo.contains("Buenos_Aires"))
    }

    @Test
    fun `lo que no se puede descifrar se borra y el diario arranca vacio`() {
        val carpeta = temporal.newFolder("gimnasio")
        almacen(carpeta).guardar(contenidoDePrueba())
        val archivo = File(carpeta, AlmacenDeGimnasioCifrado.ARCHIVO)
        val bytes = archivo.readBytes()
        bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 1).toByte()
        archivo.writeBytes(bytes)

        assertNull(almacen(carpeta).leer())
        assertFalse("y no se vuelve a intentar en cada apertura", archivo.exists())
        assertEquals(ContenidoDelDiario(), DiarioDeGimnasio(almacen(carpeta)).leer().contenido)
    }

    @Test
    fun `con otra llave, como despues de reinstalar, no abre y se borra`() {
        val carpeta = temporal.newFolder("gimnasio")
        almacen(carpeta).guardar(contenidoDePrueba())

        assertNull(almacen(carpeta, conLlave = llaveDeSoftware()).leer())
        assertFalse(File(carpeta, AlmacenDeGimnasioCifrado.ARCHIVO).exists())
    }

    @Test
    fun `si el disco no deja borrar, se destruye la llave`() {
        val carpeta = temporal.newFolder("gimnasio")
        almacen(carpeta).guardar(contenidoDePrueba())
        carpeta.setWritable(false)
        carpetaBloqueada = carpeta

        almacen(carpeta).borrar()

        assertTrue("el archivo sigue ahí", File(carpeta, AlmacenDeGimnasioCifrado.ARCHIVO).exists())
        assertEquals("pero sin la llave no se descifra nunca más", 1, llavesDestruidas)
    }

    @Test
    fun `cerrar sesion borra el disco aunque el diario nunca se haya leido`() {
        val carpeta = temporal.newFolder("gimnasio")
        almacen(carpeta).guardar(contenidoDePrueba())

        DiarioDeGimnasio(almacen(carpeta)).olvidarTodo()

        assertNull(almacen(carpeta).leer())
    }

    @Test
    fun `lo que vuelve de la red despues de cerrar sesion no escribe nada`() {
        val enMemoria = AlmacenDeGimnasioEnMemoria()
        val diario = DiarioDeGimnasio(enMemoria)
        val alSalir = diario.leer().generacion

        diario.olvidarTodo()
        val escribio = diario.cambiar(alSalir) { contenidoDePrueba() }

        assertFalse(escribio)
        assertEquals(ContenidoDelDiario(), diario.leer().contenido)
        assertNull("y el disco quedó vacío", enMemoria.guardado)
    }
}
