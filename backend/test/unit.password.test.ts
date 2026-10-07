import { test } from "node:test";
import assert from "node:assert/strict";
import { validarPassword, LARGO_MINIMO, LARGO_MAXIMO } from "../src/infra/password.js";

test("acepta una contraseña razonable", () => {
  assert.deepEqual(validarPassword("Caballo-bateria-grapa1"), { ok: true });
});

test("rechaza por corta, justo en el borde", () => {
  // Con mayúscula y número, para que lo único que falle sea el largo.
  const base = "Ab1cdefghijklm";
  assert.deepEqual(validarPassword(base.slice(0, LARGO_MINIMO - 1)), { ok: false, motivo: "corta" });
  assert.deepEqual(validarPassword(base.slice(0, LARGO_MINIMO)), { ok: true });
});

test("rechaza por larga: argon2 sobre una entrada gigante es CPU regalada", () => {
  const larga = "Correcta1!".repeat(100);
  assert.ok(larga.length > LARGO_MAXIMO);
  assert.deepEqual(validarPassword(larga), { ok: false, motivo: "larga" });
});

test("exige una mayúscula y un número", () => {
  assert.deepEqual(validarPassword("caballobateria1"), { ok: false, motivo: "sin_mayuscula" });
  assert.deepEqual(validarPassword("Caballobateria"), { ok: false, motivo: "sin_numero" });
});

/**
 * Este test existe por una razón concreta: un `[A-Z]` pelado le diría a alguien
 * que escribió `Ángela-corre-2026` que le falta una mayúscula. Ese es justo el
 * error que hace que la gente termine poniendo `Password1`.
 */
test("una mayúscula con acento o la Ñ cuentan como mayúscula", () => {
  assert.deepEqual(validarPassword("Ángela-corre-2026"), { ok: true });
  assert.deepEqual(validarPassword("Ñandu-en-la-ruta-9"), { ok: true });
});

test("rechaza contraseñas conocidas, sin importar mayúsculas", () => {
  assert.deepEqual(validarPassword("Trainer2026"), { ok: false, motivo: "conocida" });
  assert.deepEqual(validarPassword("TRAINER2026"), { ok: false, motivo: "conocida" });
});

/**
 * 🛑 La lista de conocidas tiene que estar toda en minúscula, porque se compara
 * contra `claro.toLowerCase()`. Una entrada con mayúsculas no se compara nunca y
 * es una regla apagada que parece prendida. Este test lo detecta leyendo el
 * archivo, que es la única forma: la constante no se exporta.
 */
test("todas las conocidas están en minúscula y pasan el resto de las reglas", async () => {
  const { readFileSync, existsSync } = await import("node:fs");
  const { fileURLToPath } = await import("node:url");
  const { dirname, resolve } = await import("node:path");

  // Este test corre desde `dist/test/`, no desde `test/`, asi que la ruta
  // relativa al fuente cambia segun como se lo invoque. En vez de adivinarla,
  // sube hasta encontrar el archivo. Si algun dia se mueve, falla diciendo eso.
  const RELATIVA = "src/infra/password.ts";
  let dir = dirname(fileURLToPath(import.meta.url));
  let ruta = "";
  for (let i = 0; i < 6; i++) {
    const intento = resolve(dir, RELATIVA);
    if (existsSync(intento)) { ruta = intento; break; }
    dir = resolve(dir, "..");
  }
  assert.ok(ruta, `no encontre ${RELATIVA} subiendo desde el test`);
  const fuente = readFileSync(ruta, "utf8");
  const bloque = /const CONOCIDAS = new Set\(\[([\s\S]*?)\]\);/.exec(fuente);
  assert.ok(bloque, "no encontré la lista CONOCIDAS");

  const entradas = [...(bloque[1] ?? "").matchAll(/"([^"]+)"/g)]
    .map((m) => m[1])
    .filter((x): x is string => typeof x === "string");
  assert.ok(entradas.length > 0, "la lista quedó vacía");

  for (const e of entradas) {
    assert.equal(e, e.toLowerCase(), `"${e}" tiene mayúsculas: no se compara nunca`);
    assert.ok(e.length >= LARGO_MINIMO, `"${e}" es más corta que el mínimo: la corta el largo antes`);
  }
});

test("rechaza las que tienen largo, mayúscula y número pero no entropía", () => {
  assert.deepEqual(validarPassword("Aaaaaaaaa1"), { ok: false, motivo: "repetitiva" });
  assert.deepEqual(validarPassword("Ababababab1"), { ok: false, motivo: "repetitiva" });
});
