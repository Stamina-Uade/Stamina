/**
 * Tests del guardián de tokens.
 *
 * Un lint que nunca se demostró que falla no es un guardián: es un archivo. Esto
 * prueba las dos mitades — que agarra lo que tiene que agarrar, y que NO grita por
 * lo que está bien, que es lo que hace que la gente no lo apague.
 *
 * Correr:  node --test scripts/test/
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { revisarTexto, revisarColoresDeAndroid } from "../verificar-tokens.mjs";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const GUARDIAN = join(RAIZ, "scripts/verificar-tokens.mjs");

const ids = (texto) => revisarTexto(texto).map((h) => h.regla);

describe("agarra lo que tiene que agarrar", () => {
  test("un color hex en Compose", () => {
    assert.deepEqual(ids(`Text(color = Color(0xFF7CF03D))`), ["color-a-mano"]);
  });

  test("un color hex en SwiftUI", () => {
    assert.ok(ids(`let c = Color(hex: "#7CF03D")`).includes("color-a-mano"));
  });

  test("un tamaño en dp", () => {
    assert.deepEqual(ids(`Modifier.padding(12.dp)`), ["tamano-a-mano"]);
  });

  test("un tamaño en sp, con decimales", () => {
    assert.deepEqual(ids(`fontSize = 13.5.sp`), ["tamano-a-mano"]);
  });

  test("una familia tipográfica a mano", () => {
    assert.ok(ids(`fontFamily = FontFamily(Font(R.font.archivo))`).includes("fuente-a-mano"));
  });

  test("un peso tipográfico a mano", () => {
    assert.deepEqual(ids(`fontWeight = FontWeight(600)`), ["peso-a-mano"]);
  });

  test("un objetivo táctil a mano", () => {
    assert.ok(ids(`Modifier.defaultMinSize(36.dp)`).includes("objetivo-tactil"));
  });

  test("varias violaciones en la misma línea se reportan todas", () => {
    const h = revisarTexto(`Box(Modifier.padding(8.dp).background(Color(0xFF131511)))`);
    assert.equal(h.length, 2);
    assert.deepEqual(h.map((x) => x.regla).sort(), ["color-a-mano", "tamano-a-mano"]);
  });

  test("reporta el número de línea correcto", () => {
    const h = revisarTexto(`val a = 1\nval b = 2\nval c = Color(0xFF000000)`);
    assert.equal(h.length, 1);
    assert.equal(h[0].linea, 3);
  });
});

describe("NO grita por lo que está bien", () => {
  test("un token de color", () => {
    assert.deepEqual(ids(`Text(color = TokensColor.telefonoTextoPrimario)`), []);
  });

  test("un token de espaciado", () => {
    assert.deepEqual(ids(`Modifier.padding(TokensEspaciado.e12)`), []);
  });

  test("un token de tamaño táctil", () => {
    assert.deepEqual(ids(`Modifier.size(TokensTamano.objetivoTactilMinimo)`), []);
  });

  test("una variable con .dp no es un literal con .dp", () => {
    assert.deepEqual(ids(`val alto = medida.dp`), []);
  });

  test("un hex EN UN COMENTARIO es documentación, no UI", () => {
    assert.deepEqual(ids(`// el acento es #7CF03D, ver tokens.json`), []);
    assert.deepEqual(ids(`/* Color(0xFF7CF03D) */`), []);
  });

  test("una línea vacía o de import no dispara nada", () => {
    assert.deepEqual(ids(`\nimport androidx.compose.ui.graphics.Color\n`), []);
  });
});

describe("la única puerta abierta: colors.xml de Android", () => {
  // 🛑 La decisión 0009 dejó UN color escrito a mano en Android —el acento— para
  // que cambiarlo sea editar un hex y correr la app. Eso abre una puerta que este
  // guardián tenía cerrada, y una puerta abierta sin vigilar es por donde entra el
  // basurero de colores sueltos que §10.1 existe para evitar. Estos cuatro tests
  // son la vigilancia.
  const CON_LOS_DOS =
    '<resources>' +
    '<color name="acento">#7CF03D</color>' +
    '<color name="fondo_de_ventana">#0B0C0A</color>' +
    "</resources>";

  const reglas = (xml) => revisarColoresDeAndroid(xml).map((h) => h.regla);

  test("los dos colores permitidos no molestan a nadie", () => {
    assert.deepEqual(reglas(CON_LOS_DOS), []);
  });

  test("un color de más es un error", () => {
    const conBasura = CON_LOS_DOS.replace(
      "</resources>",
      '<color name="brand_orange">#FF6B35</color></resources>'
    );
    assert.deepEqual(reglas(conBasura), ["color-suelto-en-android"]);
  });

  test("un hex sin numeral es un error", () => {
    // `7CF03D` sin `#` compila el XML igual y pinta cualquier cosa.
    assert.deepEqual(reglas(CON_LOS_DOS.replace("#7CF03D", "7CF03D")), ["color-mal-escrito"]);
  });

  test("borrar uno de los dos es un error", () => {
    const sinFondo = CON_LOS_DOS.replace('<color name="fondo_de_ventana">#0B0C0A</color>', "");
    assert.deepEqual(reglas(sinFondo), ["color-que-falta"]);
  });

  test("el colors.xml de verdad pasa, y el acento sigue estando", () => {
    const real = readFileSync(
      join(RAIZ, "android/app/src/main/res/values/colors.xml"),
      "utf8"
    );
    assert.deepEqual(revisarColoresDeAndroid(real), []);
    assert.match(real, /<color name="acento">#[0-9A-Fa-f]{6}<\/color>/);
  });
});

describe("como comando", () => {

  test("🛑 sale con código 1 y nombra el archivo cuando hay una violación", () => {
    const dir = mkdtempSync(join(tmpdir(), "guardian-"));
    mkdirSync(join(dir, "pantallas"), { recursive: true });
    const malo = join(dir, "pantallas", "Malo.kt");
    writeFileSync(malo, `@Composable fun X() { Box(Modifier.padding(9.dp).background(Color(0xFFAABBCC))) }\n`);

    let fallo = false;
    let salida = "";
    try {
      salida = execFileSync(process.execPath, [GUARDIAN, malo], { encoding: "utf8" });
    } catch (e) {
      fallo = true;
      salida = String(e.stdout ?? "");
    }
    assert.ok(fallo, "el guardián tenía que salir con código != 0");
    assert.match(salida, /color-a-mano/);
    assert.match(salida, /tamano-a-mano/);
    assert.match(salida, /Malo\.kt/);
    assert.match(salida, /2 error\(es\)/);
  });

  test("sale con código 0 cuando el archivo usa tokens", () => {
    const dir = mkdtempSync(join(tmpdir(), "guardian-"));
    const bueno = join(dir, "Bueno.kt");
    writeFileSync(
      bueno,
      `@Composable fun X() { Box(Modifier.padding(TokensEspaciado.e12).background(TokensColor.telefonoSuperficie)) }\n`
    );
    const salida = execFileSync(process.execPath, [GUARDIAN, bueno], { encoding: "utf8" });
    assert.match(salida, /0 error\(es\)/);
  });

  test("🛑 el archivo GENERADO está excluido: es el único que puede tener valores", () => {
    const generado = join(RAIZ, "android/core/src/main/kotlin/com/tecladus/trainer/core/tema/TokensGenerados.kt");
    const salida = execFileSync(process.execPath, [GUARDIAN, generado], { encoding: "utf8" });
    assert.match(salida, /0 error\(es\)/);
    assert.match(salida, /salteado/);
  });

  test("el repo entero pasa hoy", () => {
    const salida = execFileSync(process.execPath, [GUARDIAN], { encoding: "utf8" });
    assert.match(salida, /0 error\(es\)/);
  });
});
