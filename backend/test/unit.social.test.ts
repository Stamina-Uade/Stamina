/**
 * "Continuar con Google / Apple": la verificación del id_token, el permiso de alta
 * social y el correo nuevo. Sin red: las claves del "proveedor" se generan acá.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPair, exportJWK, SignJWT, createLocalJWKSet, type JWK } from "jose";
import {
  crearVerificadorDeProveedores, proveedorEsDuenoDelCorreo, sha256Hex, type IdentidadVerificada,
} from "../src/infra/proveedores.js";
import { firmarAltaSocial, leerAltaSocial } from "../src/infra/cripto.js";
import { correoDeCodigo, escaparHtml } from "../src/infra/plantillas-correo.js";
import { remitente } from "../src/infra/correo.js";

const NONCE = "un-nonce-al-azar-de-prueba-1234567890";

async function proveedorFalso() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const jwk: JWK = { ...(await exportJWK(publicKey)), kid: "k1", alg: "RS256", use: "sig" };
  const claves = createLocalJWKSet({ keys: [jwk] });
  async function firmar(claims: Record<string, unknown>, opciones: { iss: string; aud: string; vence?: string }) {
    return new SignJWT(claims)
      .setProtectedHeader({ alg: "RS256", kid: "k1" })
      .setIssuer(opciones.iss)
      .setAudience(opciones.aud)
      .setSubject("000123.persona")
      .setIssuedAt()
      .setExpirationTime(opciones.vence ?? "10m")
      .sign(privateKey);
  }
  return { claves, firmar };
}

test("un id_token de Google bien firmado, para nuestra app y con el nonce, se acepta", async () => {
  const g = await proveedorFalso();
  const v = crearVerificadorDeProveedores({
    clientIds: { google: ["ios.apps.googleusercontent.com"], apple: [] },
    claves: { google: g.claves },
  });
  const token = await g.firmar({ nonce: NONCE, email: "Emma@Gmail.com", email_verified: true },
    { iss: "https://accounts.google.com", aud: "ios.apps.googleusercontent.com" });
  const r = await v.verificar("google", token, NONCE);
  assert.equal(r?.sujeto, "000123.persona");
  assert.equal(r?.email, "emma@gmail.com");
  assert.equal(r?.emailVerificado, true);
  assert.equal(r?.dominioGestionado, null);
  assert.ok((r?.venceMs ?? 0) > Date.now());
});

test("Apple compara el SHA-256 del nonce y acepta email_verified como texto", async () => {
  const a = await proveedorFalso();
  const v = crearVerificadorDeProveedores({ clientIds: { google: [], apple: ["com.tecladus.Trainer"] }, claves: { apple: a.claves } });
  const token = await a.firmar({ nonce: sha256Hex(NONCE), email: "x@privaterelay.appleid.com", email_verified: "true" },
    { iss: "https://appleid.apple.com", aud: "com.tecladus.Trainer" });
  const r = await v.verificar("apple", token, NONCE);
  assert.equal(r?.emailVerificado, true);
  // El claro no es lo que Apple pone en el token.
  const otro = await a.firmar({ nonce: NONCE }, { iss: "https://appleid.apple.com", aud: "com.tecladus.Trainer" });
  assert.equal(await v.verificar("apple", otro, NONCE), null);
});

test("se rechaza: otra audiencia, otro emisor, otro nonce, vencido, o firmado por otra clave", async () => {
  const g = await proveedorFalso();
  const intruso = await proveedorFalso();
  const v = crearVerificadorDeProveedores({ clientIds: { google: ["nuestra"], apple: [] }, claves: { google: g.claves } });
  const base = { iss: "https://accounts.google.com", aud: "nuestra" };
  assert.equal(await v.verificar("google", await g.firmar({ nonce: NONCE }, { ...base, aud: "otra-app" }), NONCE), null);
  assert.equal(await v.verificar("google", await g.firmar({ nonce: NONCE }, { ...base, iss: "https://malo.example" }), NONCE), null);
  assert.equal(await v.verificar("google", await g.firmar({ nonce: "otro-nonce-de-dieciseis" }, base), NONCE), null);
  assert.equal(await v.verificar("google", await g.firmar({ nonce: NONCE }, { ...base, vence: "-5m" }), NONCE), null);
  assert.equal(await v.verificar("google", await intruso.firmar({ nonce: NONCE }, base), NONCE), null);
  assert.equal(await v.verificar("google", "no-es-un-jwt", NONCE), null);
});

test("un correo sin email_verified no cuenta como verificado", async () => {
  const g = await proveedorFalso();
  const v = crearVerificadorDeProveedores({ clientIds: { google: ["nuestra"], apple: [] }, claves: { google: g.claves } });
  const r = await v.verificar("google", await g.firmar({ nonce: NONCE, email: "a@b.com" },
    { iss: "accounts.google.com", aud: "nuestra" }), NONCE);
  assert.equal(r?.emailVerificado, false);
});

test("sin client id el proveedor no está configurado y nada se acepta", async () => {
  const v = crearVerificadorDeProveedores({ clientIds: { google: [], apple: [] } });
  assert.equal(v.configurado("google"), false);
  assert.equal(await v.verificar("google", "x.y.z", NONCE), null);
});

test("el permiso de alta social ida y vuelta, y vencido no sirve", async () => {
  const config = { jwtSecret: new TextEncoder().encode("un-secreto-de-prueba-de-mas-de-32-bytes-largo") };
  const ahora = Date.now();
  const t = await firmarAltaSocial(config, { proveedor: "apple", sujeto: "s-1", email: null, emailVerificado: true }, ahora, 60_000);
  // Sin correo no hay correo verificado, diga lo que diga el permiso.
  assert.deepEqual(await leerAltaSocial(config, t, ahora + 1_000),
    { proveedor: "apple", sujeto: "s-1", email: null, emailVerificado: false });
  const conCorreo = await firmarAltaSocial(config,
    { proveedor: "google", sujeto: "s-2", email: "a@gmail.com", emailVerificado: true }, ahora, 60_000);
  assert.equal((await leerAltaSocial(config, conCorreo, ahora))?.emailVerificado, true);
  assert.equal(await leerAltaSocial(config, t, ahora + 120_000), null);
  const otro = { jwtSecret: new TextEncoder().encode("otro-secreto-de-prueba-de-mas-de-32-bytes-largo") };
  assert.equal(await leerAltaSocial(otro, t, ahora), null);
});

test("el correo del código escapa el nombre y lleva el código en HTML y en texto", () => {
  const c = correoDeCodigo({ codigo: "K7P4XM", proposito: "registro", destino: "a@b.com",
    nombre: "<a href=x>Emma</a>", ahoraMs: 0, vidaMin: 15 });
  assert.ok(!c.html.includes("<a href=x>"));
  assert.ok(c.html.includes(escaparHtml("<a href=x>Emma</a>")));
  assert.ok(c.html.includes("K7P4XM") && c.texto.includes("K7P4XM"));
  assert.ok(c.html.includes("cid:"));
  assert.match(c.asunto, /K7P4XM/);
});

test("el remitente lleva el nombre de la marca si no trae uno", () => {
  assert.equal(remitente("no-reply@stamina.com.ar"), '"Stamina" <no-reply@stamina.com.ar>');
  assert.equal(remitente("Otro <x@y.z>"), "Otro <x@y.z>");
});

test("Google sólo es dueño de @gmail.com y de los dominios de Workspace", () => {
  const base: IdentidadVerificada = {
    proveedor: "google", sujeto: "s", email: "a@gmail.com", emailVerificado: true, dominioGestionado: null, venceMs: 0,
  };
  assert.equal(proveedorEsDuenoDelCorreo(base), true);
  assert.equal(proveedorEsDuenoDelCorreo({ ...base, email: "a@hotmail.com" }), false);
  assert.equal(proveedorEsDuenoDelCorreo({ ...base, email: "a@empresa.com", dominioGestionado: "empresa.com" }), true);
  assert.equal(proveedorEsDuenoDelCorreo({ ...base, emailVerificado: false }), false);
  assert.equal(proveedorEsDuenoDelCorreo({ ...base, proveedor: "apple", email: "a@icloud.com" }), true);
});
