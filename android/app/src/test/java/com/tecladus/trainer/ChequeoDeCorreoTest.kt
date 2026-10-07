package com.tecladus.trainer

import com.tecladus.trainer.pantallas.acceso.ChequeoDeCorreo
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Cuándo aparece el error del correo: recién al tocar el botón, y se va con la
 * primera edición.
 *
 * Corre en la JVM, sin emulador. Es la regla que comparten el registro, recuperar
 * la contraseña y el login. Lo que cada pantalla dibuja con ella —el texto debajo
 * del campo, el botón prendido apenas hay texto— no se prueba acá.
 */
class ChequeoDeCorreoTest {

    @Test
    fun `sin tocar el boton no hay error`() {
        assertFalse(ChequeoDeCorreo().rechazado)
    }

    @Test
    fun `el error aparece al tocar y se va al editar`() {
        val chequeo = ChequeoDeCorreo()

        // Escribió "ana": mientras escribe no hay mensaje.
        chequeo.alEditar()
        assertFalse(chequeo.rechazado)
        assertFalse(chequeo.alTocar("ana"))
        assertTrue(chequeo.rechazado)

        // Agregó "@mail": la primera tecla borra el error.
        chequeo.alEditar()
        assertFalse(chequeo.rechazado)
        assertFalse(chequeo.alTocar("ana@mail"))
        assertTrue(chequeo.rechazado)

        // Agregó ".com": ahora pasa y el error no vuelve.
        chequeo.alEditar()
        assertFalse(chequeo.rechazado)
        assertTrue(chequeo.alTocar("ana@mail.com"))
        assertFalse(chequeo.rechazado)
    }

    @Test
    fun `tocar con un correo que no parece lo rechaza y no deja seguir`() {
        val malos = listOf(
            "ana",
            "ana@",
            "@mail.com",
            "ana@mail",
            "ana@mail.",
            "ana@.com",
            "ana @mail.com",
            "ana@@mail.com",
        )
        for (correo in malos) {
            val chequeo = ChequeoDeCorreo()
            assertFalse("«$correo» no debería dejar seguir", chequeo.alTocar(correo))
            assertTrue("«$correo» debería dejar el error puesto", chequeo.rechazado)
        }
    }

    @Test
    fun `tocar con un correo que parece deja seguir sin error`() {
        val buenos = listOf(
            "ana@mail.com",
            "  ana@mail.com  ",
            "ana.perez+trainer@sub.dominio.com.ar",
        )
        for (correo in buenos) {
            val chequeo = ChequeoDeCorreo()
            assertTrue("«$correo» debería dejar seguir", chequeo.alTocar(correo))
            assertFalse("«$correo» no debería dejar error", chequeo.rechazado)
        }
    }

    @Test
    fun `volver a tocar sin corregir deja el error puesto`() {
        val chequeo = ChequeoDeCorreo()
        assertFalse(chequeo.alTocar("ana@mail"))
        assertFalse(chequeo.alTocar("ana@mail"))
        assertTrue(chequeo.rechazado)
    }
}
