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

/**
 * Contrato 1.6.0: las tres reglas visibles son las únicas. Una contraseña que
 * cumple las tres barras de la pantalla no se puede rechazar por algo que la
 * persona no veía venir (antes: lista de conocidas y "repetitiva").
 */
test("cumpliendo las tres reglas, no se rechaza por conocida ni por repetitiva", () => {
  assert.deepEqual(validarPassword("Trainer2026"), { ok: true });
  assert.deepEqual(validarPassword("Password123"), { ok: true });
  assert.deepEqual(validarPassword("Aaaaaaaaa1"), { ok: true });
  assert.deepEqual(validarPassword("Ababababab1"), { ok: true });
});

test("los motivos de rechazo son sólo los de las reglas y el tope", async () => {
  const motivos = new Set<string>();
  for (const p of ["corta", "x".repeat(LARGO_MAXIMO + 1), "caballobateria1", "Caballobateria"]) {
    const r = validarPassword(p);
    if (!r.ok) motivos.add(r.motivo);
  }
  assert.deepEqual([...motivos].sort(), ["corta", "larga", "sin_mayuscula", "sin_numero"]);
});
