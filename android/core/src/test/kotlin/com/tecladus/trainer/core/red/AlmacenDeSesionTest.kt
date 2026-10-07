package com.tecladus.trainer.core.red

import android.content.SharedPreferences
import java.util.Base64
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * El almacén de la sesión: el doble en memoria, y el cifrado con una llave AES de
 * software.
 *
 * 🛑 Lo que esto NO prueba es el Keystore: la JVM de los tests no tiene
 * `AndroidKeyStore`. Prueba todo lo demás —el formato `Base64(iv + cifrado)`, que en
 * el disco no quede un token legible, que el IV no se repita y, sobre todo, que lo
 * que no descifra se BORRE—, que es la misma cuenta con otra llave.
 */
class AlmacenDeSesionTest {

    private val sesion = Sesion("acceso-secreto", AHORA, "refresco-secreto", AHORA + 1, "u_1")

    private fun llaveDeSoftware(): SecretKey =
        KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    @Test
    fun `el doble en memoria guarda, lee y borra`() {
        val almacen = AlmacenDeSesionEnMemoria()
        assertNull(almacen.leer())
        almacen.guardar(sesion)
        assertEquals(sesion, almacen.leer())
        almacen.borrar()
        assertNull(almacen.leer())
    }

    @Test
    fun `lo cifrado vuelve igual, y en el disco no se lee ningun token`() {
        val preferencias = PreferenciasEnMemoria()
        val llave = llaveDeSoftware()

        AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { llave }.guardar(sesion)

        val enDisco = preferencias.valores.values.single()
        val crudo = String(Base64.getDecoder().decode(enDisco), Charsets.ISO_8859_1)
        assertFalse("hay un token legible en el disco", enDisco.contains("secreto"))
        assertFalse("hay un token en claro adentro del Base64", crudo.contains("secreto"))
        // Otro almacén sobre el mismo disco y la misma llave: volver a abrir la app.
        assertEquals(sesion, AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { llave }.leer())
    }

    @Test
    fun `cada guardado usa un IV nuevo`() {
        val preferencias = PreferenciasEnMemoria()
        val llave = llaveDeSoftware()
        val almacen = AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { llave }

        almacen.guardar(sesion)
        val primero = Base64.getDecoder().decode(preferencias.valores.values.single())
        almacen.guardar(sesion)
        val segundo = Base64.getDecoder().decode(preferencias.valores.values.single())

        assertFalse(
            "misma llave y mismo IV: en GCM eso rompe el cifrado",
            primero.copyOfRange(0, 12).contentEquals(segundo.copyOfRange(0, 12)),
        )
        assertNotEquals(primero.toList(), segundo.toList())
    }

    @Test
    fun `lo que no se puede descifrar se borra, y hay que entrar de nuevo`() {
        val llave = llaveDeSoftware()
        val formasDeRomperlo = mapOf<String, (String) -> String>(
            "no es Base64" to { _ -> "esto no es base64 !!" },
            "más corto que un IV" to { _ -> Base64.getEncoder().encodeToString(ByteArray(5)) },
            "un byte tocado" to { guardado ->
                val bytes = Base64.getDecoder().decode(guardado)
                bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 1).toByte()
                Base64.getEncoder().encodeToString(bytes)
            },
        )
        for ((caso, romper) in formasDeRomperlo) {
            val preferencias = PreferenciasEnMemoria()
            val almacen = AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { llave }
            almacen.guardar(sesion)
            val clave = preferencias.valores.keys.single()
            preferencias.valores[clave] = romper(preferencias.valores.getValue(clave))

            assertNull("[$caso] devolvió una sesión", almacen.leer())
            assertTrue("[$caso] lo ilegible quedó guardado", preferencias.valores.isEmpty())
        }
    }

    @Test
    fun `con otra llave, como despues de reinstalar, no abre y se borra`() {
        val preferencias = PreferenciasEnMemoria()
        val llave = llaveDeSoftware()
        AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { llave }.guardar(sesion)

        val otra = llaveDeSoftware()
        assertNull(AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { otra }.leer())
        assertTrue(preferencias.valores.isEmpty())
    }

    @Test
    fun `si no se puede cifrar, no queda guardada la sesion anterior`() {
        val preferencias = PreferenciasEnMemoria()
        val llave = llaveDeSoftware()
        AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { llave }.guardar(sesion)
        assertEquals(1, preferencias.valores.size)

        // El Keystore se rompió entre una renovación y la siguiente.
        val roto = AlmacenDeSesionCifrado(preferencias, destruirLlave = {}) { throw IllegalStateException("Keystore roto") }
        roto.guardar(sesion.copy(accessToken = "acceso-nuevo", refreshToken = "refresco-nuevo"))

        assertTrue("quedó guardado un refresh que el servidor ya rotó", preferencias.valores.isEmpty())
    }

    @Test
    fun `si el disco no deja borrar, se destruye la llave y lo que quedo no abre nunca mas`() {
        val disco = PreferenciasEnMemoria()
        val conLimite = DiscoQueSeLlena(disco)
        val keystore = KeystoreDeMentira()
        val almacen = AlmacenDeSesionCifrado(conLimite, keystore::destruir, keystore::llave)
        almacen.guardar(sesion)

        // Disco lleno: `commit` devuelve false, y lo de antes queda donde estaba.
        conLimite.lleno = true
        almacen.borrar()
        assertEquals("lo cifrado tiene que seguir en el disco: es el caso que se prueba", 1, disco.valores.size)

        // Próximo arranque, sobre el mismo disco y el mismo Keystore.
        val despues = AlmacenDeSesionCifrado(disco, keystore::destruir, keystore::llave)
        assertNull("volvió la sesión que se había borrado", despues.leer())
        assertTrue("y lo que no abre se borra", disco.valores.isEmpty())
    }

    @Test
    fun `una llave inservible se reemplaza una vez, y la sesion se guarda igual`() {
        val preferencias = PreferenciasEnMemoria()
        val keystore = KeystoreDeMentira(inservible = true)
        val almacen = AlmacenDeSesionCifrado(preferencias, keystore::destruir, keystore::llave)

        almacen.guardar(sesion)

        assertEquals("el alias roto se tenía que borrar, una vez", 1, keystore.destruidas)
        assertEquals("con la llave nueva la sesión tenía que quedar guardada", sesion, almacen.leer())
    }

    @Test
    fun `si la llave nueva tampoco sirve, no se insiste y no queda nada guardado`() {
        val preferencias = PreferenciasEnMemoria()
        var destruidas = 0
        val almacen = AlmacenDeSesionCifrado(preferencias, destruirLlave = { destruidas++ }) {
            throw java.security.KeyStoreException("Keystore roto de fábrica")
        }

        almacen.guardar(sesion)

        assertEquals("una sola vez: con el Keystore roto, probar de nuevo no lo arregla", 1, destruidas)
        assertTrue(preferencias.valores.isEmpty())
    }
}

/**
 * El Keystore, en chico: un alias cuya llave se crea la primera vez que se pide y se
 * puede borrar. [inservible] es la entrada corrupta: hay llave, pero `init` la rechaza
 * hasta que alguien la borra.
 */
private class KeystoreDeMentira(private var inservible: Boolean = false) {

    private var actual: SecretKey? = null

    var destruidas = 0
        private set

    fun llave(): SecretKey {
        if (inservible) return javax.crypto.spec.SecretKeySpec(ByteArray(3), "AES")
        return actual ?: KeyGenerator.getInstance("AES").apply { init(256) }.generateKey().also { actual = it }
    }

    fun destruir() {
        destruidas++
        inservible = false
        actual = null
    }
}

/**
 * Un disco que se puede llenar: con [lleno], `commit` devuelve `false` y no escribe
 * nada, que es lo que ve el almacén cuando `SharedPreferences` no llega a guardar y
 * vuelve al archivo de antes.
 */
private class DiscoQueSeLlena(private val adentro: SharedPreferences) : SharedPreferences by adentro {

    var lleno = false

    override fun edit(): SharedPreferences.Editor = if (lleno) SinLugar(adentro.edit()) else adentro.edit()

    private class SinLugar(edicion: SharedPreferences.Editor) : SharedPreferences.Editor by edicion {
        // 🛑 Los que encadenan devuelven ÉSTA y no la de adentro: si no, el `commit` del
        // almacén termina en la edición de verdad y escribe igual.
        override fun putString(key: String?, value: String?): SharedPreferences.Editor = this

        override fun remove(key: String?): SharedPreferences.Editor = this

        override fun clear(): SharedPreferences.Editor = this

        override fun commit(): Boolean = false

        override fun apply() = Unit
    }
}

/** Un `SharedPreferences` de mentira: sólo strings, que es lo único que usa el almacén. */
private class PreferenciasEnMemoria : SharedPreferences {

    val valores = mutableMapOf<String, String>()

    override fun getAll(): MutableMap<String, *> = valores.toMutableMap()

    override fun getString(key: String?, defValue: String?): String? = key?.let { valores[it] } ?: defValue

    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? = defValues

    override fun getInt(key: String?, defValue: Int): Int = defValue

    override fun getLong(key: String?, defValue: Long): Long = defValue

    override fun getFloat(key: String?, defValue: Float): Float = defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean = defValue

    override fun contains(key: String?): Boolean = key != null && valores.containsKey(key)

    override fun edit(): SharedPreferences.Editor = Edicion()

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    private inner class Edicion : SharedPreferences.Editor {
        private val poner = mutableMapOf<String, String>()
        private val sacar = mutableSetOf<String>()

        override fun putString(key: String?, value: String?): SharedPreferences.Editor {
            if (key != null && value != null) poner[key] = value
            return this
        }

        override fun putStringSet(key: String?, values: MutableSet<String>?): SharedPreferences.Editor = this

        override fun putInt(key: String?, value: Int): SharedPreferences.Editor = this

        override fun putLong(key: String?, value: Long): SharedPreferences.Editor = this

        override fun putFloat(key: String?, value: Float): SharedPreferences.Editor = this

        override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor = this

        override fun remove(key: String?): SharedPreferences.Editor {
            if (key != null) sacar += key
            return this
        }

        override fun clear(): SharedPreferences.Editor {
            sacar += valores.keys
            return this
        }

        override fun commit(): Boolean {
            sacar.forEach { valores.remove(it) }
            valores.putAll(poner)
            return true
        }

        override fun apply() {
            commit()
        }
    }
}
