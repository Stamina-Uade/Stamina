/**
 * Un campo REQUERIDO que puede llegar en null sale anulable en los dos clientes.
 *
 * Existe por un bug de verdad (2026-09-10): `Plan.event_date_ms` —un plan sin fecha de carrera— salía
 * como `Long` en Kotlin, y Android no podía leer ese plan. En Swift ya salía `Int64?`. El test recorre
 * el contrato entero, así que el próximo campo así tampoco se escapa.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const contrato = parse(readFileSync(resolve(raiz, "shared/api/openapi.yaml"), "utf8"));
const kotlin = readFileSync(
  resolve(raiz, "android/core/src/main/kotlin/com/tecladus/trainer/core/red/ModelosGenerados.kt"),
  "utf8"
);
const swift = readFileSync(resolve(raiz, "ios/TrainerCore/Sources/TrainerCore/Red/ModelosGenerados.swift"), "utf8");

const esNull = (x) => x && (x.type === "null" || (Array.isArray(x.type) && x.type.includes("null")));
const anulable = (s) => Boolean(s) && (esNull(s) || [s.oneOf, s.anyOf].some((u) => Array.isArray(u) && u.some(esNull)));
const aCamel = (s) => s.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());

const casos = [];
for (const [nombre, esquema] of Object.entries(contrato.components.schemas)) {
  const requeridos = new Set(esquema.required ?? []);
  for (const [prop, sub] of Object.entries(esquema.properties ?? {})) {
    if (requeridos.has(prop) && anulable(sub)) casos.push({ nombre, prop });
  }
}

test("el contrato tiene al menos un campo requerido y anulable (si no, este archivo no prueba nada)", () => {
  assert.ok(casos.length > 0);
});

for (const { nombre, prop } of casos) {
  test(`${nombre}.${prop}: requerido y anulable, sale con "?" en Kotlin y en Swift`, () => {
    const camel = aCamel(prop);

    const clase = kotlin.slice(kotlin.indexOf(`data class ${nombre}(`));
    const lineaKotlin = clase.split("\n").find((l) => l.trim().startsWith(`val ${camel}:`));
    assert.ok(lineaKotlin, `no encontré val ${camel} en data class ${nombre}`);
    assert.match(lineaKotlin.trim(), /\?,$/, `Kotlin: "${lineaKotlin.trim()}" tiene que terminar en "?," y sin "= null"`);

    const estructura = swift.slice(swift.indexOf(`public struct ${nombre}:`));
    const lineaSwift = estructura.split("\n").find((l) => l.trim().startsWith(`public let ${camel}:`));
    assert.ok(lineaSwift, `no encontré let ${camel} en struct ${nombre}`);
    assert.match(lineaSwift.trim(), /\?$/, `Swift: "${lineaSwift.trim()}"`);
  });
}
