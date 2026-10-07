package com.tecladus.trainer.core.red

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.serialization.json.Json

/**
 * La sesión guardada en el teléfono, cifrada con una llave del Android Keystore.
 *
 * Cómo queda en el disco: un `SharedPreferences` privado de la app, con UNA clave
 * cuyo valor es `Base64(iv + cifrado)`, donde `cifrado` es el JSON de [Sesion]
 * pasado por AES-256-GCM. GCM autentica además de cifrar: un byte tocado no
 * descifra a basura, falla — y una falla se trata igual que no tener nada.
 *
 * - **La llave no sale del Keystore.** Se crea la primera vez que se guarda, con
 *   alias propio, y la app sólo la usa por referencia: no hay bytes de la llave en
 *   la memoria del proceso ni en el disco. Desinstalar la app la borra.
 * - **Sin autenticación de usuario.** La llave no pide huella ni PIN: la sesión
 *   tiene que poder renovarse con la pantalla apagada y el teléfono en el bolsillo,
 *   que es como se usa en el gimnasio. Lo que protege es que la llave no se puede
 *   exportar, no que haya que desbloquear para usarla.
 * - **Sin dependencias.** `androidx.security:security-crypto`
 *   (`EncryptedSharedPreferences`) está deprecado, y lo que hacía para esto es este
 *   archivo.
 * - **El IV lo elige el cifrador**, uno nuevo en cada guardado. La llave exige
 *   cifrado aleatorizado y no acepta un IV propio, que es justo lo que evita el
 *   error clásico de GCM: repetir IV con la misma llave.
 *
 * Si descifrar falla por lo que sea —datos tocados, la llave ya no existe, un
 * Keystore roto de fábrica, el JSON de una versión vieja—, se borra lo guardado y
 * [leer] devuelve `null`: hay que entrar de nuevo. Lo que pasa si falla guardar está
 * en [AlmacenDeSesion]; si falla borrar, en [borrar]; y si la llave quedó inservible,
 * en [cifrarOCambiarDeLlave].
 *
 * El archivo queda afuera del backup del sistema (`backup_rules.xml` y
 * `data_extraction_rules.xml` de `:app`): restaurado en otro teléfono no descifra,
 * porque la llave no viaja.
 */
class AlmacenDeSesionCifrado internal constructor(
    private val preferencias: SharedPreferences,
    /**
     * Borra la llave del Keystore. Va antes que [llave] para que los tests puedan seguir
     * pasando la llave como lambda al final.
     */
    private val destruirLlave: () -> Unit,
    /** De dónde sale la llave. En el teléfono, el Keystore; en los tests, una AES de software. */
    private val llave: () -> SecretKey,
) : AlmacenDeSesion {

    constructor(contexto: Context) : this(
        contexto.applicationContext.getSharedPreferences(ARCHIVO, Context.MODE_PRIVATE),
        ::destruirLlaveDelKeystore,
        ::llaveDelKeystore,
    )

    private val json = Json { ignoreUnknownKeys = true }

    override fun leer(): Sesion? {
        val guardado = preferencias.getString(CLAVE, null) ?: return null
        return try {
            descifrar(guardado)
        } catch (e: Exception) {
            // 🛑 Cualquier falla, sin distinguir y sin loguear nada de lo guardado.
            // El Keystore tira excepciones de todo tipo según el fabricante —varias
            // son RuntimeException— y para quien usa la app todas significan lo
            // mismo: esta sesión no se puede leer y hay que entrar de nuevo.
            borrar()
            null
        }
    }

    override fun guardar(sesion: Sesion) {
        val cifrado = cifrarOCambiarDeLlave(sesion)
        // `commit` y no `apply`: el refresh rota en cada renovación, y un `apply` que
        // no llegó al disco antes de que el sistema mate el proceso deja guardado un
        // refresh ya canjeado. Quien llama ya está fuera del hilo principal.
        val escrito = cifrado != null && preferencias.edit().putString(CLAVE, cifrado).commit()
        if (!escrito) borrar()
    }

    /**
     * 🛑 **Si el disco no deja borrar, se destruye la llave.** Con el disco lleno
     * `commit` devuelve `false`, y `SharedPreferences` vuelve a poner el archivo de antes
     * desde su `.bak` en el próximo arranque. Lo cifrado seguiría ahí: un refresh ya
     * canjeado que vuelve, o la sesión de la que alguien salió sin señal que reaparece
     * adentro de la cuenta. Sin la llave no se descifra nunca más; [leer] lo trata como
     * ilegible y lo vuelve a intentar borrar.
     */
    override fun borrar() {
        val borrado = try {
            preferencias.edit().remove(CLAVE).commit()
        } catch (e: Exception) {
            false
        }
        if (borrado) return
        try {
            destruirLlave()
        } catch (e: Exception) {
            // Ni el disco ni el Keystore responden: de este lado no queda nada por hacer.
        }
    }

    /**
     * Cifra, y si no se puede, borra la llave y prueba UNA vez más con una nueva.
     *
     * 🛑 Un alias puede quedar inservible —una entrada corrupta, o lo que hacen algunos
     * fabricantes después de cambiar el bloqueo de pantalla— y tirar en cada `getKey` o
     * en cada `init`. Sin esto tiraría en todos los guardados, para siempre: la sesión
     * nunca llegaría al disco y habría que entrar de nuevo cada vez que se abre la app.
     * Borrar esa llave no pierde nada, porque lo cifrado con ella se reemplaza o se borra
     * enseguida. Una sola vez: si con una llave nueva tampoco anda, el Keystore está roto
     * de verdad, y probar de nuevo no lo arregla.
     */
    private fun cifrarOCambiarDeLlave(sesion: Sesion): String? {
        try {
            return cifrar(sesion)
        } catch (e: Exception) {
            // Sigue abajo, con otra llave.
        }
        return try {
            destruirLlave()
            cifrar(sesion)
        } catch (e: Exception) {
            null
        }
    }

    private fun cifrar(sesion: Sesion): String {
        val cifrador = Cipher.getInstance(TRANSFORMACION)
        cifrador.init(Cipher.ENCRYPT_MODE, llave())
        val iv: ByteArray? = cifrador.iv
        check(iv != null && iv.size == LARGO_DEL_IV) { "el cifrador no dio un IV de $LARGO_DEL_IV bytes" }
        val claro = json.encodeToString(Sesion.serializer(), sesion).toByteArray(Charsets.UTF_8)
        return Base64.getEncoder().encodeToString(iv + cifrador.doFinal(claro))
    }

    private fun descifrar(guardado: String): Sesion {
        val bytes = Base64.getDecoder().decode(guardado)
        require(bytes.size > LARGO_DEL_IV) { "lo guardado es más corto que un IV" }
        val cifrador = Cipher.getInstance(TRANSFORMACION)
        cifrador.init(
            Cipher.DECRYPT_MODE,
            llave(),
            GCMParameterSpec(BITS_DE_ETIQUETA, bytes, 0, LARGO_DEL_IV),
        )
        val claro = cifrador.doFinal(bytes, LARGO_DEL_IV, bytes.size - LARGO_DEL_IV)
        return json.decodeFromString(Sesion.serializer(), String(claro, Charsets.UTF_8))
    }

    internal companion object {
        /**
         * El archivo de preferencias. 🛑 Si cambia, cambia también en las reglas de
         * backup de `:app`, o el archivo nuevo empieza a viajar al backup.
         */
        const val ARCHIVO = "sesion_cifrada"
        const val CLAVE = "sesion"
        const val ALIAS = "trainer_sesion_v1"
        const val PROVEEDOR = "AndroidKeyStore"
        const val TRANSFORMACION = "AES/GCM/NoPadding"
        const val LARGO_DEL_IV = 12
        const val BITS_DE_ETIQUETA = 128
        const val BITS_DE_LLAVE = 256
    }
}

/**
 * Un solo hilo a la vez busca, crea o borra la llave: dos creándola juntos se pisan, y
 * lo que se cifró con la primera ya no abre.
 */
private val candadoDeLaLlave = Any()

private fun llaveDelKeystore(): SecretKey = synchronized(candadoDeLaLlave) {
    val keystore = KeyStore.getInstance(AlmacenDeSesionCifrado.PROVEEDOR).apply { load(null) }
    (keystore.getKey(AlmacenDeSesionCifrado.ALIAS, null) as? SecretKey)?.let { return it }

    val generador = KeyGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_AES,
        AlmacenDeSesionCifrado.PROVEEDOR,
    )
    generador.init(
        KeyGenParameterSpec.Builder(
            AlmacenDeSesionCifrado.ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(AlmacenDeSesionCifrado.BITS_DE_LLAVE)
            .setUserAuthenticationRequired(false)
            .build(),
    )
    generador.generateKey()
}

/** Borra la llave del alias. La próxima vez que se pida, [llaveDelKeystore] crea otra. */
private fun destruirLlaveDelKeystore(): Unit = synchronized(candadoDeLaLlave) {
    KeyStore.getInstance(AlmacenDeSesionCifrado.PROVEEDOR).apply { load(null) }
        .deleteEntry(AlmacenDeSesionCifrado.ALIAS)
}
