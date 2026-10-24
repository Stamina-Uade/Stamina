/**
 * test/unit.ubicacion.test.ts — "Ciudad, País" de los headers de Cloudflare para
 * los correos de acceso (infra/ubicacion.ts).
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { ubicacionDeCloudflare, nombreDePais } from "../src/infra/ubicacion.js";

test("ciudad y país, con el país en el idioma del correo", () => {
  const h = { "cf-ipcity": "Buenos Aires", "cf-ipcountry": "AR" };
  assert.equal(ubicacionDeCloudflare(h, "es", true), "Buenos Aires, Argentina");
  assert.equal(ubicacionDeCloudflare({ "cf-ipcity": "Madrid", "cf-ipcountry": "ES" }, "en", true), "Madrid, Spain");
  assert.equal(ubicacionDeCloudflare({ "cf-ipcity": "Madrid", "cf-ipcountry": "ES" }, "fr", true), "Madrid, Espagne");
});

test("sin ciudad usa la provincia; sin nada, sólo el país", () => {
  assert.equal(ubicacionDeCloudflare({ "cf-region": "Córdoba", "cf-ipcountry": "AR" }, "es", true), "Córdoba, Argentina");
  assert.equal(ubicacionDeCloudflare({ "cf-ipcountry": "UY" }, "es", true), "Uruguay");
});

test("ciudad codificada con % se decodifica", () => {
  assert.equal(ubicacionDeCloudflare({ "cf-ipcity": "S%C3%A3o%20Paulo", "cf-ipcountry": "BR" }, "es", true), "São Paulo, Brasil");
});

test("XX y Tor no son países; sin datos, null", () => {
  assert.equal(ubicacionDeCloudflare({ "cf-ipcountry": "XX" }, "es", true), null);
  assert.equal(ubicacionDeCloudflare({ "cf-ipcountry": "T1" }, "es", true), null);
  assert.equal(ubicacionDeCloudflare({}, "es", true), null);
});

test("sin proxy de confianza no se leen: cualquiera los podría inventar", () => {
  assert.equal(ubicacionDeCloudflare({ "cf-ipcity": "Buenos Aires", "cf-ipcountry": "AR" }, "es", false), null);
});

test("ciudad y país con el mismo nombre van una sola vez", () => {
  assert.equal(ubicacionDeCloudflare({ "cf-ipcity": "Singapore", "cf-ipcountry": "SG" }, "en", true), "Singapore");
});

test("sin caracteres de control y con tope de largo", () => {
  const u = ubicacionDeCloudflare({ "cf-ipcity": "A\r\nB" + "x".repeat(200), "cf-ipcountry": "AR" }, "es", true);
  assert.ok(u !== null && !/[\r\n]/.test(u));
  assert.ok(u.length <= 80 + ", Argentina".length);
});

test("un código que no es de dos letras queda como vino", () => {
  assert.equal(nombreDePais("ZZZ", "es"), "ZZZ");
});
