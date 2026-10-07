package com.tecladus.trainer.core.gimnasio

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.serialization.json.Json

/**
 * El diario del gimnasio en el disco, cifrado con una llave del Android Keystore.
 *
 * Son datos de salud (AGENTS.md §8): cuánto levanta alguien y cuándo entrena. §12.1 no deja
 * datos sensibles en un archivo en claro, así que van como la sesión
 * (`AlmacenDeSesionCifrado`): AES-256-GCM con una llave que no sale del Keystore, un IV
 * nuevo en cada guardado que elige el cifrador, y cualquier falla al descifrar se trata
 * como no tener nada. Sin dependencias.
 *
 * En qué se diferencia de la sesión, y por qué:
 *
 * - **Un archivo y no `SharedPreferences`.** La rutina con sus series pesa kilobytes y se
 *   reescribe en cada serie. Se escribe a un temporal y se renombra: si el proceso muere a
 *   mitad de escritura queda el diario anterior entero, no uno roto.
 * - **Otra llave.** Si una se vuelve inservible y hay que destruirla, la otra no cae con ella:
 *   perder el diario no puede cerrar la sesión, ni al revés.
 *
 * La carpeta queda afuera del backup (`backup_rules.xml` y `data_extraction_rules.xml` de
 * `:app`): restaurada en otro teléfono no descifra, y además sería de una cuenta que en ese
 * teléfono todavía no entró.
 */
class AlmacenDeGimnasioCifrado internal constructor(
    private val carpeta: File,
    /** Borra la llave del Keystore. Antes que [llave], para que los tests la pasen como lambda final. */
    private val destruirLlave: () -> Unit,
    /** De dónde sale la llave. En el teléfono, el Keystore; en los tests, una AES de software. */
    private val llave: () -> SecretKey,
) : AlmacenDeGimnasio {

    constructor(contexto: Context) : this(
        File(contexto.applicationContext.filesDir, CARPETA),
        ::destruirLlaveDelGimnasio,
        ::llaveDelGimnasio,
    )

    private val json = Json { ignoreUnknownKeys = true }

    private val archivo: File
        get() = File(carpeta, ARCHIVO)

    private val temporal: File
        get() = File(carpeta, "$ARCHIVO.tmp")

    override fun leer(): ContenidoDelDiario? {
        if (!archivo.isFile) return null
        return try {
            descifrar(archivo.readBytes())
        } catch (e: Exception) {
            // 🛑 Cualquier falla, sin distinguir y sin loguear nada de lo guardado: datos
            // tocados, una llave que ya no está, el JSON de una versión vieja. Un diario que
            // no se puede leer no se arregla reintentando, y dejarlo es fallar en cada apertura.
            borrar()
            null
        }
    }

    override fun guardar(contenido: ContenidoDelDiario) {
        val cifrado = cifrarOCambiarDeLlave(contenido) ?: return
        try {
            carpeta.mkdirs()
            temporal.writeBytes(cifrado)
            // Renombrar dentro de la misma carpeta reemplaza de una: o queda el anterior, o
            // el nuevo, nunca la mitad de cada uno.
            if (!temporal.renameTo(archivo)) temporal.delete()
        } catch (e: Exception) {
            // Sin lugar o sin permiso: queda el anterior, entero, y lo nuevo sigue en memoria
            // para el próximo guardado.
            try {
                temporal.delete()
            } catch (ignorada: Exception) {
                // Si ni eso se puede, lo que quedó está cifrado y [borrar] se encarga.
            }
        }
    }

    /**
     * 🛑 **Si el disco no deja borrar, se destruye la llave.** Lo que haya quedado está
     * cifrado con ella, y sin ella no se descifra nunca más: una cuenta que se fue no puede
     * reaparecer en el diario de la siguiente.
     */
    override fun borrar() {
        val borrado = try {
            (!temporal.exists() || temporal.delete()) && (!archivo.exists() || archivo.delete())
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
     * Cifra, y si no se puede, borra la llave y prueba UNA vez más con una nueva. Es la misma
     * razón que en `AlmacenDeSesionCifrado.cifrarOCambiarDeLlave`: un alias que quedó
     * inservible tiraría en todos los guardados, para siempre. Lo que estaba cifrado con la
     * vieja se pierde, y se reemplaza enseguida con lo que se está guardando.
     */
    private fun cifrarOCambiarDeLlave(contenido: ContenidoDelDiario): ByteArray? {
        try {
            return cifrar(contenido)
        } catch (e: Exception) {
            // Sigue abajo, con otra llave.
        }
        return try {
            destruirLlave()
            cifrar(contenido)
        } catch (e: Exception) {
            null
        }
    }

    private fun cifrar(contenido: ContenidoDelDiario): ByteArray {
        val cifrador = Cipher.getInstance(TRANSFORMACION)
        cifrador.init(Cipher.ENCRYPT_MODE, llave())
        val iv: ByteArray? = cifrador.iv
        check(iv != null && iv.size == LARGO_DEL_IV) { "el cifrador no dio un IV de $LARGO_DEL_IV bytes" }
        val claro = json.encodeToString(ContenidoDelDiario.serializer(), contenido).toByteArray(Charsets.UTF_8)
        return iv + cifrador.doFinal(claro)
    }

    private fun descifrar(bytes: ByteArray): ContenidoDelDiario {
        require(bytes.size > LARGO_DEL_IV) { "lo guardado es más corto que un IV" }
        val cifrador = Cipher.getInstance(TRANSFORMACION)
        cifrador.init(Cipher.DECRYPT_MODE, llave(), GCMParameterSpec(BITS_DE_ETIQUETA, bytes, 0, LARGO_DEL_IV))
        val claro = cifrador.doFinal(bytes, LARGO_DEL_IV, bytes.size - LARGO_DEL_IV)
        return json.decodeFromString(ContenidoDelDiario.serializer(), String(claro, Charsets.UTF_8))
    }

    internal companion object {
        /**
         * La carpeta dentro de `filesDir`. 🛑 Si cambia, cambia también en las reglas de
         * backup de `:app`, o la nueva empieza a viajar al backup.
         */
        const val CARPETA = "gimnasio"
        const val ARCHIVO = "diario.cifrado"
        const val ALIAS = "trainer_gimnasio_v1"
        const val PROVEEDOR = "AndroidKeyStore"
        const val TRANSFORMACION = "AES/GCM/NoPadding"
        const val LARGO_DEL_IV = 12
        const val BITS_DE_ETIQUETA = 128
        const val BITS_DE_LLAVE = 256
    }
}

/** Un solo hilo a la vez busca, crea o borra la llave: dos creándola juntos se pisan. */
private val candadoDeLaLlave = Any()

private fun llaveDelGimnasio(): SecretKey = synchronized(candadoDeLaLlave) {
    val keystore = KeyStore.getInstance(AlmacenDeGimnasioCifrado.PROVEEDOR).apply { load(null) }
    (keystore.getKey(AlmacenDeGimnasioCifrado.ALIAS, null) as? SecretKey)?.let { return it }

    val generador = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, AlmacenDeGimnasioCifrado.PROVEEDOR)
    generador.init(
        KeyGenParameterSpec.Builder(
            AlmacenDeGimnasioCifrado.ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(AlmacenDeGimnasioCifrado.BITS_DE_LLAVE)
            // Sin huella ni PIN: las series se guardan con la pantalla apagada, entre serie y serie.
            .setUserAuthenticationRequired(false)
            .build(),
    )
    generador.generateKey()
}

private fun destruirLlaveDelGimnasio(): Unit = synchronized(candadoDeLaLlave) {
    KeyStore.getInstance(AlmacenDeGimnasioCifrado.PROVEEDOR).apply { load(null) }
        .deleteEntry(AlmacenDeGimnasioCifrado.ALIAS)
}
