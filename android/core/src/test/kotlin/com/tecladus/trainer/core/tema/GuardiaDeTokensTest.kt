package com.tecladus.trainer.core.tema

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 🛑 AGENTS.md §10.1, hecho fallar. Fase 6d.
 *
 * > "ningún color, tamaño, radio ni fuente se escribe a mano en una pantalla. Todo
 * >  sale de los tokens."
 *
 * Esa regla, sin algo que la rompa, dura hasta el primer viernes a las siete de la
 * tarde. `scripts/verificar-tokens.mjs` ya la hace fallar en CI y cubre además
 * `ios/`. Este test la hace fallar **en la compilación de Android**, que es donde
 * está la persona en el momento de escribir el valor a mano: `./gradlew :core:test`,
 * o el botón de correr tests del IDE, sin depender de que haya Node instalado.
 *
 * Son dos implementaciones de la misma regla, y eso se paga: pueden separarse. Por
 * eso [las reglas de los dos archivos tienen que coincidir][mismosIdsQueElScriptDeNode],
 * y ese test falla si alguien agrega una regla de un lado y no del otro.
 */
class GuardiaDeTokensTest {

    private data class Regla(val id: String, val patron: Regex, val mensaje: String)

    private val reglas = listOf(
        Regla(
            "color-a-mano",
            Regex("""(?:#[0-9A-Fa-f]{3,8}\b|\bColor\s*\(\s*0x[0-9A-Fa-f]{6,8}\b)"""),
            "color escrito a mano. Sale de TokensColor.",
        ),
        Regla(
            "tamano-a-mano",
            Regex("""(?<![A-Za-z0-9_.])\d+(?:\.\d+)?\.(?:dp|sp)\b"""),
            "tamano escrito a mano. Sale de TokensEspaciado, TokensRadio, TokensTamano o TokensTipografia.",
        ),
        Regla(
            "fuente-a-mano",
            Regex("""\b(?:FontFamily\s*\(|Font\s*\(\s*name\s*:|\.font\s*\(\s*\.custom\s*\()"""),
            "familia tipografica a mano. Sale de los tokens.",
        ),
        Regla(
            "peso-a-mano",
            Regex("""\bFontWeight\s*\(\s*\d+\s*\)"""),
            "peso tipografico a mano. Sale de TokensTipografia.",
        ),
        Regla(
            "objetivo-tactil",
            Regex("""\b(?:minimumInteractiveComponentSize|defaultMinSize)\s*\(\s*\d"""),
            "objetivo tactil a mano. Es TokensTamano.objetivoTactilMinimo, sin excepciones.",
        ),
    )

    /**
     * Lo que queda afuera, con el motivo escrito. Una exclusión sin motivo es una
     * regla apagada que nadie va a volver a prender. Tiene que decir lo mismo que
     * `EXCLUIDOS` en el script de Node.
     *
     * Este archivo NO se excluye a sí mismo, aunque contenga los patrones: escritos
     * como `Regex("""...""")` no se parecen a una llamada real, y una exclusión que
     * no hace falta es un lugar más donde puede esconderse una violación de verdad.
     * Si algún día un patrón nuevo se auto-detecta, este test falla y hay que
     * reescribirlo — que es mejor que apagarlo.
     */
    private val excluidos = listOf(
        "TokensGenerados" to "es el archivo GENERADO desde tokens.json: el unico lugar donde los valores pueden estar escritos",
        "app/src/main/java/" to "la UI Android original, que se descarta entera en la fase 6",
        "app/src/test/" to "tests unitarios de la logica de dominio original: no pintan nada",
        "app/src/androidTest/" to "test instrumentado heredado del template",
        "/build/" to "artefactos de compilacion",
        "/.gradle/" to "artefactos de Gradle",
    )

    private val raiz: File by lazy {
        // `System.getProperty` devuelve un tipo de plataforma (puede ser null): se
        // resuelve acá y no se arrastra, que es lo que avisaba el compilador.
        val desde: String = System.getProperty("user.dir")
            ?: error("el runner de tests no expuso user.dir")
        var d: File? = File(desde).absoluteFile
        while (d != null && !File(d, "AGENTS.md").isFile) d = d.parentFile
        requireNotNull(d) { "no encontre la raiz del repo (busque AGENTS.md hacia arriba desde $desde)" }
    }

    /** Comentario de una línea y comentario de bloque en una línea: ahí un hex es documentación. */
    private fun despejar(linea: String): String =
        linea.replace(Regex("""//.*$"""), "").replace(Regex("""/\*.*?\*/"""), "")

    @Test
    fun `ninguna pantalla escribe un color, un tamano, una fuente o un peso a mano`() {
        val dir = File(raiz, "android")
        assertTrue("no existe ${dir.path}", dir.isDirectory)

        val hallazgos = mutableListOf<String>()
        var revisados = 0

        dir.walkTopDown()
            .filter { it.isFile && (it.extension == "kt" || it.extension == "kts") }
            .forEach { archivo ->
                val relativa = archivo.relativeTo(raiz).path.replace('\\', '/')
                if (excluidos.any { (patron, _) -> relativa.contains(patron) }) return@forEach
                revisados++
                archivo.readLines().forEachIndexed { i, linea ->
                    val limpia = despejar(linea)
                    for (regla in reglas) {
                        val m = regla.patron.find(limpia) ?: continue
                        hallazgos += "$relativa:${i + 1}  [${regla.id}] «${m.value}» — ${regla.mensaje}"
                    }
                }
            }

        assertTrue(
            "el guardian no reviso ni un archivo: las exclusiones se comieron todo",
            revisados > 0,
        )
        assertTrue(
            "AGENTS.md 10.1 — ${hallazgos.size} valor(es) a mano:\n" + hallazgos.joinToString("\n"),
            hallazgos.isEmpty(),
        )
    }

    /**
     * Las dos implementaciones tienen que cubrir lo mismo. Si alguien agrega una
     * regla al script de Node y se olvida de acá, el build de Android deja de
     * verla — y al revés. Este test es lo único que impide esa divergencia.
     */
    @Test
    fun mismosIdsQueElScriptDeNode() {
        val script = File(raiz, "scripts/verificar-tokens.mjs")
        assertTrue("falta ${script.path}", script.isFile)
        val idsEnNode = Regex("""id:\s*"([a-z-]+)"""")
            .findAll(script.readText())
            .map { it.groupValues[1] }
            .toSortedSet()
        assertEquals(
            "las reglas de scripts/verificar-tokens.mjs y las de este test se separaron",
            idsEnNode,
            reglas.map { it.id }.toSortedSet(),
        )
    }
}
