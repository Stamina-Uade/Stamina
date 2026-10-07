import { test } from "node:test";
import assert from "node:assert/strict";
import {
  generarCodigo,
  generarTokenOpaco,
  hashearToken,
  igualSeguro,
  hashearPassword,
  verificarPassword,
  firmarAcceso,
  verificarAcceso,
  firmarPasoDeCorreo,
  verificarPasoDeCorreo,
} from "../src/infra/cripto.js";
import type { Config } from "../src/config.js";

const config = {
  jwtSecret: new TextEncoder().encode("un-secreto-de-prueba-de-mas-de-32-bytes-largo"),
  accessTtlS: 900,
} as unknown as Config;

test("el código es de 6 caracteres del alfabeto sin ambigüedades", () => {
  for (let i = 0; i < 200; i++) {
    const c = generarCodigo();
    assert.match(c, /^[A-HJ-NP-Z2-9]{6}$/, `código inesperado: ${c}`);
  }
});

test("dos códigos seguidos no son iguales (generador aleatorio, no contador)", () => {
  const vistos = new Set<string>();
  for (let i = 0; i < 200; i++) vistos.add(generarCodigo());
  assert.ok(vistos.size > 190, `demasiadas repeticiones: ${vistos.size}/200`);
});

test("el token opaco es de 32 bytes en base64url", () => {
  const t = generarTokenOpaco();
  assert.match(t, /^[A-Za-z0-9_-]+$/);
  assert.equal(Buffer.from(t, "base64url").length, 32);
});

test("hashearToken es estable y no devuelve el token", () => {
  const t = generarTokenOpaco();
  assert.equal(hashearToken(t), hashearToken(t));
  assert.notEqual(hashearToken(t), t);
  assert.equal(hashearToken(t).length, 64);
});

test("igualSeguro no explota con largos distintos", () => {
  assert.equal(igualSeguro("abc", "abcd"), false);
  assert.equal(igualSeguro("abc", "abc"), true);
  assert.equal(igualSeguro("", ""), true);
});

test("argon2id: verifica la correcta y rechaza la equivocada", async () => {
  const hash = await hashearPassword("caballo-bateria-grapa");
  assert.ok(hash.startsWith("$argon2id$"), `no es argon2id: ${hash.slice(0, 20)}`);
  assert.equal(await verificarPassword("caballo-bateria-grapa", hash), true);
  assert.equal(await verificarPassword("caballo-bateria-grapo", hash), false);
});

test("el mismo texto da hashes distintos (hay sal)", async () => {
  const a = await hashearPassword("caballo-bateria-grapa");
  const b = await hashearPassword("caballo-bateria-grapa");
  assert.notEqual(a, b);
});

test("el access token se firma y se verifica", async () => {
  const { token, venceMs } = await firmarAcceso(config, { sub: "u1", sid: "s1" });
  assert.ok(venceMs > Date.now());
  assert.deepEqual(await verificarAcceso(config, token), { sub: "u1", sid: "s1" });
});

test("🛑 el algoritmo está fijado: un token con alg:none se rechaza", async () => {
  const cabecera = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString("base64url");
  const cuerpo = Buffer.from(
    JSON.stringify({ sub: "u1", sid: "s1", iss: "trainer", aud: "trainer-app", exp: Math.floor(Date.now() / 1000) + 600 })
  ).toString("base64url");
  assert.equal(await verificarAcceso(config, `${cabecera}.${cuerpo}.`), null);
});

test("🛑 un token firmado con OTRO secreto se rechaza", async () => {
  const otro = { ...config, jwtSecret: new TextEncoder().encode("otro-secreto-distinto-de-mas-de-32-bytes!!") } as Config;
  const { token } = await firmarAcceso(otro, { sub: "u1", sid: "s1" });
  assert.equal(await verificarAcceso(config, token), null);
});

test("un token vencido se rechaza", async () => {
  const vencido = { ...config, accessTtlS: -10 } as unknown as Config;
  const { token } = await firmarAcceso(vencido, { sub: "u1", sid: "s1" });
  assert.equal(await verificarAcceso(config, token), null);
});

test("el paso de correo exige firma, propósito y vencimiento", async () => {
  const ahora = Date.now();
  const token = await firmarPasoDeCorreo(config, "persona@example.com", "registro", ahora, 600_000);
  assert.equal(await verificarPasoDeCorreo(config, token, "registro", ahora), true);
  assert.equal(await verificarPasoDeCorreo(config, token, "recuperacion", ahora), false);
  const [header, payload, signature] = token.split(".");
  assert.equal(await verificarPasoDeCorreo(config, `${header}.${payload}.${signature?.[0] === "a" ? "b" : "a"}${signature?.slice(1)}`, "registro", ahora), false);
  assert.equal(await verificarPasoDeCorreo(config, token, "registro", ahora + 601_000), false);
});
