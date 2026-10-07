package com.tecladus.trainer

import com.tecladus.trainer.core.red.ClienteApi
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

/**
 * A dónde habla la app, y con quién puede hablar en claro.
 *
 * Nada de esto se ve en el emulador de quien lo escribe: un release que acepta
 * `http://`, o un debug sin el `/v1`, andan perfecto hasta el día que no. Por eso se
 * mira el archivo y no el comportamiento.
 */
class ConfiguracionDeRedTest {

    private val app: File by lazy {
        val desde: String = System.getProperty("user.dir") ?: error("el runner no expuso user.dir")
        var d: File? = File(desde).absoluteFile
        while (d != null && !File(d, "AGENTS.md").isFile) d = d.parentFile
        File(requireNotNull(d) { "no encontré la raíz del repo desde $desde" }, "android/app")
    }

    @Test
    fun `la base de la API lleva el prefijo del contrato`() {
        assertTrue(
            "API_BASE=${BuildConfig.API_BASE} no termina en ${ClienteApi.PREFIJO_DEL_CONTRATO}: todo daría 404",
            BuildConfig.API_BASE.endsWith(ClienteApi.PREFIJO_DEL_CONTRATO),
        )
    }

    @Test
    fun `el release no habla en claro con nadie`() {
        val raiz = leer("src/main/res/xml/seguridad_de_red.xml")
        assertEquals("false", raiz.primero("base-config").getAttribute("cleartextTrafficPermitted"))
        assertEquals("el release permite tráfico en claro", emptyList<String>(), dominiosEnClaro(raiz))
    }

    @Test
    fun `el debug habla en claro solo con 10_0_2_2`() {
        val raiz = leer("src/debug/res/xml/seguridad_de_red.xml")
        assertEquals("false", raiz.primero("base-config").getAttribute("cleartextTrafficPermitted"))
        assertEquals(listOf("10.0.2.2"), dominiosEnClaro(raiz))
    }

    @Test
    fun `el manifiesto usa esa configuracion`() {
        val manifiesto = File(app, "src/main/AndroidManifest.xml").readText()
        assertTrue(manifiesto.contains("""android:networkSecurityConfig="@xml/seguridad_de_red""""))
    }

    private fun leer(ruta: String): Element {
        val archivo = File(app, ruta)
        assertTrue("falta ${archivo.path}", archivo.isFile)
        return DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(archivo).documentElement
    }

    private fun Element.primero(etiqueta: String): Element =
        requireNotNull(getElementsByTagName(etiqueta).item(0) as? Element) { "no hay <$etiqueta>" }

    /** Los dominios de todo `<domain-config cleartextTrafficPermitted="true">`. */
    private fun dominiosEnClaro(raiz: Element): List<String> {
        val configs = raiz.getElementsByTagName("domain-config")
        return (0 until configs.length)
            .map { configs.item(it) as Element }
            .filter { it.getAttribute("cleartextTrafficPermitted") == "true" }
            .flatMap { config ->
                val dominios = config.getElementsByTagName("domain")
                (0 until dominios.length).map { dominios.item(it).textContent.trim() }
            }
    }
}
