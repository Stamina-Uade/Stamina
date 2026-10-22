/**
 * test/integracion.cuenta-1-6.test.ts — el contrato 1.6.0 ("Entrar y
 * registrarse") de punta a punta, contra Postgres y Redis de verdad.
 *
 * El armado es el de integracion.api.test.ts. Va en un archivo aparte para no
 * mezclarse con esa suite: acá el correo y los proveedores son dobles que anotan
 * lo que se mandó, y Google/Apple se reemplazan por un verificador que cree lo
 * que dice el token (la verificación de la firma ya la prueba unit.social).
 *
 * Necesita DATABASE_URL y REDIS_URL apuntando a una base DESCARTABLE. Si no están,
 * los tests se saltean.
 */
import { test, before, after, describe } from "node:test";
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { cargarConfig } from "../src/config.js";
import { crearDb, type Db } from "../src/infra/db.js";
import { crearCache, type Cache } from "../src/infra/redis.js";
import { crearServidor } from "../src/servidor.js";
import { migrar } from "../src/infra/migrar.js";
import { prepararHashDummy } from "../src/infra/cripto.js";
import { versionLegal } from "../src/dominios/legal/textos.js";
import { crearTopeDeIntentos } from "../src/dominios/auth/intentos.js";
import type { IdentidadVerificada, NombreDeProveedor } from "../src/infra/proveedores.js";
import type { Contexto } from "../src/contexto.js";

const HAY_SERVICIOS = Boolean(process.env["DATABASE_URL"] && process.env["REDIS_URL"]);
const SIN_SERVICIOS = !HAY_SERVICIOS ? "faltan DATABASE_URL y REDIS_URL" : false;

let app: FastifyInstance;
let db: Db;
let cache: Cache;
let ctx: Contexto;

/** Lo que "mandó" el correo, para seguir los flujos y comprobar los avisos. */
const enviados = {
  codigos: [] as Array<{ destino: string; codigo: string }>,
  vinculaciones: [] as Array<{ destino: string; proveedor: string }>,
};

const PASSWORD = "Caballo-bateria-grapa-9";

before(async () => {
  if (!HAY_SERVICIOS) return;
  const config = cargarConfig();
  db = crearDb(config);
  cache = crearCache(config);
  await migrar(db, () => {});
  await prepararHashDummy();

  ctx = {
    config,
    db,
    cache,
    correo: {
      async enviarCodigo(destino, codigo) {
        enviados.codigos.push({ destino, codigo });
      },
      async avisarIntentoDeRegistro() {},
      async avisarVinculacion(destino, proveedor) {
        enviados.vinculaciones.push({ destino, proveedor });
      },
    },
    // El id_token de prueba es la identidad en JSON. El servidor igual exige que
    // cada id_token sirva una vez, por eso cada uno lleva un `jti` al azar.
    proveedores: {
      configurado: () => true,
      async verificar(proveedor: NombreDeProveedor, idToken: string) {
        const id = JSON.parse(idToken) as Omit<IdentidadVerificada, "proveedor" | "venceMs">;
        return { ...id, proveedor, venceMs: Date.now() + 600_000 };
      },
    },
    ahoraMs: () => Date.now(),
  };
  app = await crearServidor(ctx);
  await app.ready();
});

after(async () => {
  if (!HAY_SERVICIOS) return;
  await app?.close();
  await db?.cerrar();
  await cache?.cerrar();
});

function nuevoEmail(dominio = "ejemplo.invalid"): string {
  return `c16-${Date.now()}${randomInt(1e6)}@${dominio}`;
}

/**
 * Una IP distinta por pedido, de un rango propio y con un comienzo al azar: los
 * contadores por IP viven 15 minutos en Redis y esta suite se corre más de una vez.
 */
let ipContador = randomInt(1_000_000);
function ipDePrueba(): string {
  ipContador += 1;
  return `172.${16 + (Math.floor(ipContador / 62_500) % 16)}.${Math.floor(ipContador / 250) % 250}.${(ipContador % 250) + 1}`;
}

type Metodo = "GET" | "POST";

async function pedir(metodo: Metodo, url: string, cuerpo?: unknown, token?: string, ip?: string, extra: Record<string, string> = {}) {
  const res = await app.inject({
    method: metodo,
    url,
    payload: cuerpo as object | undefined,
    remoteAddress: ip ?? ipDePrueba(),
    headers: { ...(token !== undefined ? { authorization: `Bearer ${token}` } : {}), ...extra },
  });
  let json: any = null;
  try {
    json = res.body === "" ? null : JSON.parse(res.body);
  } catch {
    json = res.body;
  }
  return { status: res.statusCode, json, headers: res.headers };
}

const LEGAL = () => ({ version: versionLegal(), accepted: true });

function ultimoCodigo(email: string): string {
  const c = [...enviados.codigos].reverse().find((x) => x.destino === email);
  assert.ok(c, `no se mandó ningún código a ${email}`);
  return c.codigo;
}

type SesionApi = { access_token: string; refresh_token: string; user_id: string };

/** Registra una cuenta con contraseña y devuelve su sesión. */
async function registrar(email = nuevoEmail()) {
  assert.equal((await pedir("POST", "/v1/auth/register", { email })).status, 202);
  const v = await pedir("POST", "/v1/auth/register/verify", { email, code: ultimoCodigo(email) });
  assert.equal(v.status, 200, JSON.stringify(v.json));
  const r = await pedir("POST", "/v1/auth/register/complete", {
    registration_token: v.json.data.registration_token,
    password: PASSWORD,
    profile: { first_name: "Emma" },
    legal: LEGAL(),
  });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  return { email, sesion: r.json.data as SesionApi };
}

/** Un id_token de prueba para `proveedores.verificar`. */
function idToken(o: { sujeto?: string; email: string | null; verificado?: boolean; dominio?: string | null }): string {
  return JSON.stringify({
    sujeto: o.sujeto ?? `suj-${randomUUID()}`,
    email: o.email,
    emailVerificado: o.verificado ?? true,
    dominioGestionado: o.dominio ?? null,
    jti: randomUUID(),
  });
}

const NONCE = "un-nonce-de-prueba-largo-1234";

async function social(proveedor: NombreDeProveedor, token: string, ip?: string) {
  return pedir("POST", "/v1/auth/social", { provider: proveedor, id_token: token, nonce: NONCE }, undefined, ip);
}

/** Una cuenta que nace con Google o Apple, sin contraseña. */
async function registrarConProveedor(proveedor: NombreDeProveedor, email = nuevoEmail("gmail.com")) {
  const sujeto = `suj-${randomUUID()}`;
  const s = await social(proveedor, idToken({ sujeto, email }));
  assert.equal(s.status, 200, JSON.stringify(s.json));
  assert.equal(s.json.data.status, "signup_required");
  const r = await pedir("POST", "/v1/auth/register/complete", {
    social_token: s.json.data.signup.signup_token,
    profile: { first_name: "Emma" },
    legal: LEGAL(),
  });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  return { email, sujeto, sesion: r.json.data as SesionApi };
}

async function recuperar(email: string, password: string, extra: Record<string, string> = {}) {
  assert.equal((await pedir("POST", "/v1/auth/password/forgot", { email })).status, 202);
  const v = await pedir("POST", "/v1/auth/password/verify", { email, code: ultimoCodigo(email) });
  assert.equal(v.status, 200, JSON.stringify(v.json));
  return pedir("POST", "/v1/auth/password/reset", { reset_token: v.json.data.reset_token, password }, undefined, undefined, extra);
}

// ----------------------------------------------------------------- tests --

describe("tope de contraseñas por correo y por IP", { skip: SIN_SERVICIOS }, () => {
  test("5 equivocadas desde IPs distintas bloquean el correo con too_many_attempts y Retry-After", async () => {
    const { email } = await registrar();
    for (let i = 1; i <= 4; i++) {
      const r = await pedir("POST", "/v1/auth/login", { email, password: "Otra-clave-larga-1" });
      assert.equal(r.json.error.code, "wrong_password");
    }
    const quinta = await pedir("POST", "/v1/auth/login", { email, password: "Otra-clave-larga-1" });
    assert.equal(quinta.status, 429);
    assert.equal(quinta.json.error.code, "too_many_attempts");
    assert.ok(Number(quinta.headers["retry-after"]) > 800, "Retry-After con los segundos que faltan");
    // Bloqueado, ni la correcta entra, y el correo escrito distinto es el mismo correo.
    const correcta = await pedir("POST", "/v1/auth/login", { email: email.toUpperCase(), password: PASSWORD });
    assert.equal(correcta.status, 429);
    assert.equal(correcta.json.error.code, "too_many_attempts");
  });

  test("entrar bien reinicia la racha; cambiar la contraseña también, y desbloquea", async () => {
    const { email } = await registrar();
    for (let i = 1; i <= 4; i++) await pedir("POST", "/v1/auth/login", { email, password: "Otra-clave-larga-1" });
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: PASSWORD })).status, 200);
    for (let i = 1; i <= 4; i++) {
      assert.equal((await pedir("POST", "/v1/auth/login", { email, password: "Otra-clave-larga-1" })).json.error.code, "wrong_password");
    }
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: "Otra-clave-larga-1" })).status, 429);
    const nueva = "Clave-nueva-de-prueba-4";
    assert.equal((await recuperar(email, nueva)).status, 200);
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: nueva })).status, 200);
  });

  test("una IP con 20 fallos entre muchos correos recibe rate_limited, aunque la contraseña sea buena", async () => {
    // Los 20 fallos se cargan directo en el tope: por la ruta, el rate limit de
    // 8 por minuto corta antes y no se vería este tope sino aquél.
    const { email } = await registrar();
    const ip = ipDePrueba();
    const tope = crearTopeDeIntentos(cache, () => Date.now());
    for (let i = 0; i < 20; i++) await tope.fallo(i % 2 === 0 ? nuevoEmail() : null, ip);
    const r = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD }, undefined, ip);
    assert.equal(r.status, 429);
    assert.equal(r.json.error.code, "rate_limited");
    assert.ok(Number(r.headers["retry-after"]) > 800);
    // Desde otra IP, el mismo correo entra: el tope era de la IP, no de la cuenta.
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: PASSWORD })).status, 200);
  });

  test("password_not_set trae el proveedor con el que nació la cuenta", async () => {
    const { email } = await registrarConProveedor("apple", nuevoEmail("icloud.com"));
    const r = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD });
    assert.equal(r.status, 409);
    assert.deepEqual(r.json.error.details, { provider: "apple" });
  });
});

describe("códigos por correo", { skip: SIN_SERVICIOS }, () => {
  test("al quinto código equivocado: code_attempts_exceeded, y el correcto ya no sirve", async () => {
    const email = nuevoEmail();
    await pedir("POST", "/v1/auth/register", { email });
    for (let i = 1; i <= 5; i++) {
      const r = await pedir("POST", "/v1/auth/register/verify", { email, code: "ZZZZZZ" });
      assert.equal(r.status, 400);
      assert.equal(r.json.error.code, i === 5 ? "code_attempts_exceeded" : "invalid_code");
    }
    const correcto = await pedir("POST", "/v1/auth/register/verify", { email, code: ultimoCodigo(email) });
    assert.equal(correcto.json.error.code, "code_attempts_exceeded");
  });

  test("recuperar también: 5 equivocados agotan el código", async () => {
    const { email } = await registrar();
    await pedir("POST", "/v1/auth/password/forgot", { email });
    for (let i = 1; i <= 5; i++) await pedir("POST", "/v1/auth/password/verify", { email, code: "ZZZZZZ" });
    const r = await pedir("POST", "/v1/auth/password/verify", { email, code: ultimoCodigo(email) });
    assert.equal(r.json.error.code, "code_attempts_exceeded");
  });
});
