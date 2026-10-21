/**
 * test/integracion.api.test.ts — la API entera contra Postgres y Redis de verdad.
 *
 * AGENTS.md §14.1 pide un test que falle sin el cambio. Acá hay uno por camino
 * feliz y uno por cada camino de error que importa, con foco en §12:
 * anti-enumeración, rotación de refresh, revocación al cambiar la contraseña,
 * IDOR y topes. Desde la 1.1.0 del contrato, también el motor: catálogo, plan,
 * rutina, sincronización de series (decisión 0006), actividades, nutrición detrás
 * de los guardarraíles (§9.2), y exportar y borrar la cuenta (§8).
 *
 * Necesita DATABASE_URL y REDIS_URL apuntando a una base DESCARTABLE. Si no están,
 * los tests se saltean con un aviso en vez de fallar: quien corre `npm test` sin
 * docker-compose levantado no tiene por qué ver rojo.
 */
import { test, before, after, describe } from "node:test";
import assert from "node:assert/strict";
import type { FastifyInstance } from "fastify";
import { cargarConfig } from "../src/config.js";
import { crearDb, type Db } from "../src/infra/db.js";
import { crearCache, crearCacheEnMemoria, type Cache } from "../src/infra/redis.js";
import { crearServidor } from "../src/servidor.js";
import { migrar } from "../src/infra/migrar.js";
import { prepararHashDummy } from "../src/infra/cripto.js";
import { sembrarCatalogo } from "../src/dominios/catalogo/sembrar.js";
import { versionLegal } from "../src/dominios/legal/textos.js";
import { fechaLocal } from "../src/infra/fechas.js";
import type { Contexto } from "../src/contexto.js";

const HAY_SERVICIOS = Boolean(process.env["DATABASE_URL"] && process.env["REDIS_URL"]);
const SIN_SERVICIOS = !HAY_SERVICIOS ? "faltan DATABASE_URL y REDIS_URL" : false;

let app: FastifyInstance;
let db: Db;
let cache: Cache;
let ctx: Contexto;
/** Los códigos que "manda" el correo, para poder seguir el flujo. */
const codigos: string[] = [];

const PASSWORD = "caballo-bateria-grapa-9Z";
const DIA_MS = 86_400_000;
const ZONA = "America/Argentina/Buenos_Aires";

before(async () => {
  if (!HAY_SERVICIOS) return;
  const config = cargarConfig();
  db = crearDb(config);
  cache = crearCache(config);
  await migrar(db, () => {});
  await sembrarCatalogo(db, Date.now());
  await prepararHashDummy();

  ctx = {
    config,
    db,
    cache,
    correo: {
      async enviarCodigo(_d, codigo) {
        codigos.push(codigo);
      },
      async avisarIntentoDeRegistro() {},
      async avisarVinculacion() {},
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

function nuevoEmail(): string {
  return `t${Date.now()}${Math.floor(Math.random() * 1e6)}@ejemplo.invalid`;
}

function idDelCliente(): string {
  return crypto.randomUUID();
}

/**
 * Cada llamada usa una IP distinta salvo que se le pase una.
 *
 * El bucket del rate limit es PATH + IP, así que sin esto todos los tests
 * comparten el mismo bucket y el octavo `registrar()` de la suite empieza a comer
 * 429 — que es correcto en producción y ruido acá. El test que SÍ prueba el rate
 * limit fija su IP a propósito.
 */
let ipContador = 0;
function ipDePrueba(): string {
  ipContador += 1;
  return `10.${Math.floor(ipContador / 62_500) % 250}.${Math.floor(ipContador / 250) % 250}.${(ipContador % 250) + 1}`;
}

type Metodo = "GET" | "POST" | "PATCH" | "PUT" | "DELETE";

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

/** Registra una cuenta nueva y devuelve su sesión. */
async function registrar(email = nuevoEmail(), profile: Record<string, unknown> = {
  first_name: "Iván",
  weight_g: 74500,
  height_mm: 1780,
  sport: "running",
  level: "intermedio",
}) {
  const r1 = await pedir("POST", "/v1/auth/register", { email });
  assert.equal(r1.status, 202, JSON.stringify(r1.json));
  const codigo = codigos.at(-1)!;
  const r2 = await pedir("POST", "/v1/auth/register/verify", { email, code: codigo });
  assert.equal(r2.status, 200, JSON.stringify(r2.json));
  const r3 = await pedir("POST", "/v1/auth/register/complete", {
    registration_token: r2.json.data.registration_token,
    password: PASSWORD,
    profile,
    legal: LEGAL(),
  });
  assert.equal(r3.status, 201, JSON.stringify(r3.json));
  return { email, sesion: r3.json.data as { access_token: string; refresh_token: string; user_id: string } };
}

/** Todo lo que el plan necesita, y lo que la nutrición necesita de un hombre. */
function perfilCompleto(extra: Record<string, unknown> = {}) {
  return {
    first_name: "Iván",
    weight_g: 74500,
    height_mm: 1780,
    sport: "running",
    level: "intermedio",
    goal: "media_maraton",
    goal_date_ms: Date.now() + 84 * DIA_MS,
    biological_sex: "masculino",
    birthdate_ms: Date.UTC(1992, 5, 1),
    timezone: ZONA,
    training_days: [
      { weekday: 2, minute_of_day: 1140 },
      { weekday: 4, minute_of_day: 1140 },
      { weekday: 5, minute_of_day: 420 },
      { weekday: 7, minute_of_day: 510 },
    ],
    ...extra,
  };
}

function serie(numero: number, o: Record<string, unknown> = {}) {
  return {
    exercise_id: "press-banca-barra",
    number: numero,
    done: true,
    reps: 8,
    weight_g: 45_000,
    skipped: false,
    is_extra: false,
    recorded_at_ms: Date.now(),
    device: "telefono",
    ...o,
  };
}

describe("servicio", { skip: SIN_SERVICIOS }, () => {
  test("GET /v1/health dice versión y dependencias, y nada más", async () => {
    const r = await pedir("GET", "/v1/health");
    assert.equal(r.status, 200);
    assert.equal(r.json.data.status, "ok");
    assert.deepEqual(r.json.data.dependencies, { database: "ok", redis: "ok" });
    // No filtra nada de la máquina compartida (§2).
    assert.deepEqual(Object.keys(r.json.data).sort(), ["dependencies", "status", "version"]);
  });

  test("sin Redis declarado, /v1/health dice `disabled` y el servicio sigue ok (decisión 0011)", async () => {
    const sinRedis = await crearServidor({ ...ctx, cache: crearCacheEnMemoria() });
    try {
      const r = await sinRedis.inject({ method: "GET", url: "/v1/health" });
      const json = JSON.parse(r.body);
      assert.equal(r.statusCode, 200);
      assert.equal(json.data.status, "ok");
      assert.equal(json.data.dependencies.redis, "disabled");
    } finally {
      await sinRedis.close();
    }
  });

  test("GET /v1/version resuelve la acción cuando el cliente manda su build", async () => {
    const r = await pedir("GET", "/v1/version?platform=android&build=1");
    assert.equal(r.status, 200);
    assert.equal(r.json.data.platform, "android");
    assert.equal(r.json.data.action, "ok");
    assert.equal(typeof r.json.data.minimum_build, "number");
  });

  test("GET /v1/version rechaza una plataforma inventada", async () => {
    const r = await pedir("GET", "/v1/version?platform=blackberry");
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "bad_request");
  });

  test("una ruta que no existe devuelve el envelope de error, no un HTML", async () => {
    const r = await pedir("GET", "/v1/no-existe");
    assert.equal(r.status, 404);
    assert.equal(r.json.error.code, "not_found");
  });
});

describe("registro", { skip: SIN_SERVICIOS }, () => {
  test("camino feliz: correo, código, perfil y sesión", async () => {
    const { sesion } = await registrar();
    assert.ok(sesion.access_token.length > 20);
    assert.ok(sesion.refresh_token.length > 20);
    assert.match(sesion.user_id, /^[0-9a-f-]{36}$/);
  });

  test("registrar un correo QUE YA EXISTE lo dice (decisión 2026-10-21)", async () => {
    const { email } = await registrar();
    const r = await pedir("POST", "/v1/auth/register", { email });
    assert.equal(r.status, 409);
    assert.equal(r.json.error.code, "email_already_registered");
  });

  test("un código equivocado no sirve", async () => {
    const email = nuevoEmail();
    await pedir("POST", "/v1/auth/register", { email });
    const r = await pedir("POST", "/v1/auth/register/verify", { email, code: "ZZZZZZ" });
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "invalid_code");
  });

  test("al tercer código equivocado el desafío expira", async () => {
    const email = nuevoEmail();
    await pedir("POST", "/v1/auth/register", { email });
    for (let intento = 1; intento <= 3; intento++) {
      const r = await pedir("POST", "/v1/auth/register/verify", { email, code: "ZZZZZZ" });
      assert.equal(r.status, 400);
      assert.equal(r.json.error.code, intento === 3 ? "code_expired" : "invalid_code");
    }
    const correcto = await pedir("POST", "/v1/auth/register/verify", { email, code: codigos.at(-1)! });
    assert.notEqual(correcto.status, 200);
  });

  test("el token de registro es de UN SOLO USO", async () => {
    const email = nuevoEmail();
    await pedir("POST", "/v1/auth/register", { email });
    const v = await pedir("POST", "/v1/auth/register/verify", { email, code: codigos.at(-1)! });
    const cuerpo = { registration_token: v.json.data.registration_token, password: PASSWORD, profile: {}, legal: LEGAL() };
    assert.equal((await pedir("POST", "/v1/auth/register/complete", cuerpo)).status, 201);
    const segundo = await pedir("POST", "/v1/auth/register/complete", cuerpo);
    assert.equal(segundo.status, 401);
    assert.equal(segundo.json.error.code, "invalid_registration_token");
  });

  test("la política de contraseñas se hace cumplir EN EL SERVIDOR", async () => {
    const email = nuevoEmail();
    await pedir("POST", "/v1/auth/register", { email });
    const v = await pedir("POST", "/v1/auth/register/verify", { email, code: codigos.at(-1)! });
    const r = await pedir("POST", "/v1/auth/register/complete", {
      registration_token: v.json.data.registration_token,
      password: "corta",
      profile: {},
      legal: LEGAL(),
    });
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "weak_password");
  });

  test("una clave que el contrato no declara se rechaza (additionalProperties: false)", async () => {
    const r = await pedir("POST", "/v1/auth/register", { email: nuevoEmail(), es_admin: true });
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "bad_request");
  });
});

describe("login y sesión", { skip: SIN_SERVICIOS }, () => {
  test("camino feliz", async () => {
    const { email } = await registrar();
    const r = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD });
    assert.equal(r.status, 200);
    assert.ok(r.json.data.access_token);
  });

  test("contraseña mala y cuenta inexistente dicen cada una lo suyo (decisión 2026-10-21)", async () => {
    const { email } = await registrar();
    const mala = await pedir("POST", "/v1/auth/login", { email, password: "otra-cosa-larga-1" });
    const inexistente = await pedir("POST", "/v1/auth/login", { email: "nadie" + nuevoEmail(), password: "otra-cosa-larga-1" });
    assert.equal(mala.status, 401);
    assert.equal(mala.json.error.code, "wrong_password");
    assert.equal(inexistente.status, 404);
    assert.equal(inexistente.json.error.code, "user_not_found");
  });

  test("refresh rota el token, y reusar el viejo con el nuevo ya usado revoca la familia", async () => {
    const { sesion } = await registrar();
    const r1 = await pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token });
    assert.equal(r1.status, 200);
    assert.notEqual(r1.json.data.refresh_token, sesion.refresh_token);

    // El nuevo se usa: desde acá, presentar el viejo ya no puede ser un reintento.
    const r2 = await pedir("POST", "/v1/auth/refresh", { refresh_token: r1.json.data.refresh_token });
    assert.equal(r2.status, 200);

    // 🛑 Reusar el viejo revoca la FAMILIA entera: es la señal de que lo copiaron.
    const reuso = await pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token });
    assert.equal(reuso.status, 401);
    assert.equal(reuso.json.error.code, "session_revoked");

    const despues = await pedir("POST", "/v1/auth/refresh", { refresh_token: r2.json.data.refresh_token });
    assert.equal(despues.status, 401, "el refresh más nuevo también tiene que caer con la familia");
    const me = await pedir("GET", "/v1/me", undefined, r2.json.data.access_token);
    assert.equal(me.json.error.code, "session_revoked", "y el access de la última rotación también");
  });

  test("decisión 0013: reintentar un refresh cuya respuesta se perdió devuelve LA MISMA sucesora", async () => {
    const { sesion } = await registrar();
    const perdida = await pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token });
    assert.equal(perdida.status, 200);
    const reintento = await pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token });
    assert.equal(reintento.status, 200);
    assert.equal(reintento.json.data.refresh_token, perdida.json.data.refresh_token);
    assert.equal(reintento.json.data.refresh_expires_at_ms, perdida.json.data.refresh_expires_at_ms);

    // La sucesora anda, y una vez usada, el viejo ya es reuso.
    const siguiente = await pedir("POST", "/v1/auth/refresh", { refresh_token: reintento.json.data.refresh_token });
    assert.equal(siguiente.status, 200);
    assert.equal((await pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token })).status, 401);
  });

  test("decisión 0013: dos canjes simultáneos del mismo refresh dan la misma sucesora", async () => {
    const { sesion } = await registrar();
    const [a, b] = await Promise.all([
      pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token }),
      pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token }),
    ]);
    assert.equal(a.status, 200, JSON.stringify(a.json));
    assert.equal(b.status, 200, JSON.stringify(b.json));
    assert.equal(a.json.data.refresh_token, b.json.data.refresh_token);
    assert.equal((await pedir("POST", "/v1/auth/refresh", { refresh_token: a.json.data.refresh_token })).status, 200);
  });

  test("decisión 0013: pasada la ventana de reintento, presentar el refresh viejo es reuso", async () => {
    const { sesion } = await registrar();
    let desfaseMs = 0;
    const conReloj = await crearServidor({ ...ctx, ahoraMs: () => Date.now() + desfaseMs });
    try {
      const refrescar = async (token: string) => {
        const r = await conReloj.inject({
          method: "POST",
          url: "/v1/auth/refresh",
          payload: { refresh_token: token },
          remoteAddress: ipDePrueba(),
        });
        return { status: r.statusCode, json: JSON.parse(r.body) };
      };
      const r1 = await refrescar(sesion.refresh_token);
      assert.equal(r1.status, 200);

      desfaseMs = 3 * 60 * 1000;
      const tarde = await refrescar(sesion.refresh_token);
      assert.equal(tarde.status, 401);
      assert.equal(tarde.json.error.code, "session_revoked");
      assert.equal((await refrescar(r1.json.data.refresh_token)).status, 401, "la sucesora cae con la familia");
    } finally {
      await conReloj.close();
    }
  });

  test("decisión 0013: rotar no mata los access que ya salieron; el logout sí", async () => {
    const { sesion } = await registrar();
    const r1 = await pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token });
    assert.equal(r1.status, 200);
    // El pedido que viajaba con el access viejo mientras otro renovaba.
    assert.equal((await pedir("GET", "/v1/me", undefined, sesion.access_token)).status, 200);

    // Logout con el access nuevo y sin refresh en el cuerpo: cae toda la cadena de ese login.
    assert.equal((await pedir("POST", "/v1/auth/logout", {}, r1.json.data.access_token)).status, 204);
    const viejo = await pedir("GET", "/v1/me", undefined, sesion.access_token);
    assert.equal(viejo.status, 401);
    assert.equal(viejo.json.error.code, "session_revoked");
  });

  test("logout revoca la sesión y GET /v1/me deja de funcionar", async () => {
    const { sesion } = await registrar();
    assert.equal((await pedir("GET", "/v1/me", undefined, sesion.access_token)).status, 200);
    assert.equal((await pedir("POST", "/v1/auth/logout", {}, sesion.access_token)).status, 204);
    const despues = await pedir("GET", "/v1/me", undefined, sesion.access_token);
    assert.equal(despues.status, 401);
    assert.equal(despues.json.error.code, "session_revoked");
  });

  test("logout es idempotente: repetirlo sigue dando 204", async () => {
    const { sesion } = await registrar();
    assert.equal((await pedir("POST", "/v1/auth/logout", {}, sesion.access_token)).status, 204);
    assert.equal((await pedir("POST", "/v1/auth/logout", {}, sesion.access_token)).status, 204);
  });
});

describe("fechas sin hora (docs/API.md §5)", { skip: SIN_SERVICIOS }, () => {
  test("la carrera viaja como medianoche UTC y el plan la pone ESE día, no el anterior", async () => {
    // Así la mandan las dos apps. Leída en la zona de Buenos Aires, la medianoche UTC
    // del día D es el día D-1 a las 21:00: el plan terminaba con la carrera un día antes.
    const [a, m, d] = fechaLocal(Date.now(), ZONA).split("-").map(Number) as [number, number, number];
    const carrera = Date.UTC(a, m - 1, d + 60);
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto({ goal_date_ms: carrera }));
    const r = await pedir("GET", "/v1/plan", undefined, sesion.access_token);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    const ultimo = r.json.data.days.at(-1);
    assert.equal(ultimo.type, "carrera");
    assert.equal(fechaLocal(ultimo.date_ms, ZONA), new Date(carrera).toISOString().slice(0, 10));
  });
});

describe("recuperación de contraseña", { skip: SIN_SERVICIOS }, () => {
  test("pedir la recuperación de una cuenta que no existe lo dice (decisión 2026-10-21)", async () => {
    const r = await pedir("POST", "/v1/auth/password/forgot", { email: nuevoEmail() });
    assert.equal(r.status, 404);
    assert.equal(r.json.error.code, "user_not_found");
  });

  test("🛑 cambiar la contraseña REVOCA las demás sesiones", async () => {
    const { email, sesion } = await registrar();
    const otra = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD });
    assert.equal(otra.status, 200);

    await pedir("POST", "/v1/auth/password/forgot", { email });
    const v = await pedir("POST", "/v1/auth/password/verify", { email, code: codigos.at(-1)! });
    assert.equal(v.status, 200);
    const nueva = "Otra-clave-larga-y-buena-7";
    const reset = await pedir("POST", "/v1/auth/password/reset", { reset_token: v.json.data.reset_token, password: nueva });
    assert.equal(reset.status, 200);

    assert.equal((await pedir("GET", "/v1/me", undefined, sesion.access_token)).status, 401);
    assert.equal((await pedir("GET", "/v1/me", undefined, otra.json.data.access_token)).status, 401);
    assert.equal((await pedir("GET", "/v1/me", undefined, reset.json.data.access_token)).status, 200);
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: PASSWORD })).status, 401);
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: nueva })).status, 200);
  });
});

describe("perfil", { skip: SIN_SERVICIOS }, () => {
  test("GET /v1/me devuelve lo que se guardó en el registro", async () => {
    const { email, sesion } = await registrar();
    const r = await pedir("GET", "/v1/me", undefined, sesion.access_token);
    assert.equal(r.status, 200);
    assert.equal(r.json.data.email, email);
    assert.equal(r.json.data.weight_g, 74500);
    assert.equal(r.json.data.sport, "running");
    const texto = JSON.stringify(r.json);
    assert.ok(!texto.includes("argon2"), "se filtró el hash de la contraseña");
    assert.ok(!texto.includes("password"), "se filtró algo de contraseña");
  });

  test("PATCH /v1/me es parcial: no borra lo que no se manda", async () => {
    const { sesion } = await registrar();
    const r = await pedir("PATCH", "/v1/me", { weight_g: 73000 }, sesion.access_token);
    assert.equal(r.status, 200);
    assert.equal(r.json.data.weight_g, 73000);
    assert.equal(r.json.data.sport, "running", "PATCH parcial no puede pisar los otros campos");
  });

  test("PATCH /v1/me guarda y vacía los dos campos de la 1.1.0", async () => {
    const { sesion } = await registrar();
    const r = await pedir("PATCH", "/v1/me", { equipment: ["mancuernas"], pregnant_or_breastfeeding: false }, sesion.access_token);
    assert.equal(r.status, 200);
    assert.deepEqual(r.json.data.equipment, ["mancuernas"]);
    assert.equal(r.json.data.pregnant_or_breastfeeding, false);
    const vacio = await pedir("PATCH", "/v1/me", { equipment: null }, sesion.access_token);
    assert.equal(vacio.json.data.equipment, undefined, "null vacía el campo y el campo vacío se omite");
  });

  test("PATCH /v1/me valida contra el contrato: un peso imposible se rechaza", async () => {
    const { sesion } = await registrar();
    const r = await pedir("PATCH", "/v1/me", { weight_g: 5 }, sesion.access_token);
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "bad_request");
  });

  test("🛑 IDOR: dos cuentas no se ven entre sí", async () => {
    const a = await registrar();
    const b = await registrar();
    const rb = await pedir("GET", "/v1/me", undefined, b.sesion.access_token);
    assert.equal(rb.json.data.email, b.email);
    assert.notEqual(rb.json.data.id, a.sesion.user_id);
    assert.equal((await pedir("GET", `/v1/users/${a.sesion.user_id}`, undefined, b.sesion.access_token)).status, 404);
  });

  test("sin token, /v1/me es 401; con basura, 401 y no 500", async () => {
    assert.equal((await pedir("GET", "/v1/me")).status, 401);
    assert.equal((await pedir("GET", "/v1/me", undefined, "no.es.un.jwt")).status, 401);
  });
});

describe("topes y rate limit", { skip: SIN_SERVICIOS }, () => {
  test("🛑 un cuerpo gigante se corta: tope server-side", async () => {
    const r = await pedir("POST", "/v1/auth/login", { email: "a@b.co", password: "x".repeat(200_000) });
    assert.ok(r.status === 413 || r.status === 400, `esperaba 413 o 400, vino ${r.status}`);
  });

  test("🛑 el rate limit de login corta, y el bucket sale del PATH", async () => {
    const email = nuevoEmail();
    const ip = "203.0.113.7";
    let corto = 0;
    for (let i = 0; i < 12; i++) {
      const r = await pedir("POST", "/v1/auth/login", { email, password: "clave-mala-larga-1" }, undefined, ip);
      if (r.status === 429) {
        corto++;
        assert.equal(r.json.error.code, "rate_limited");
        assert.ok(r.headers["retry-after"] !== undefined, "falta Retry-After");
      }
    }
    assert.ok(corto > 0, "el rate limit nunca cortó");
    const otra = await pedir("POST", "/v1/auth/login", { email, password: "clave-mala-larga-1" }, undefined, "203.0.113.8");
    assert.equal(otra.status, 401, "otra IP no puede estar limitada por el bucket de la primera");
  });
});

describe("idempotencia (AGENTS.md §5.2)", { skip: SIN_SERVICIOS }, () => {
  const conClave = (url: string, cuerpo: unknown, token: string, clave: string) =>
    pedir("PATCH", url, cuerpo, token, undefined, { "idempotency-key": clave });

  test("🛑 el mismo pedido dos veces devuelve la MISMA respuesta, sin volver a escribir", async () => {
    const { sesion } = await registrar();
    const clave = `k-${idDelCliente()}`;
    const a = await conClave("/v1/me", { weight_g: 71000 }, sesion.access_token, clave);
    assert.equal(a.status, 200);
    assert.equal(a.headers["idempotency-replayed"], undefined);
    await pedir("PATCH", "/v1/me", { weight_g: 99000 }, sesion.access_token);
    const b = await conClave("/v1/me", { weight_g: 71000 }, sesion.access_token, clave);
    assert.equal(b.headers["idempotency-replayed"], "true");
    assert.deepEqual(b.json, a.json);
  });

  test("🛑 la misma clave con OTRO cuerpo es 409", async () => {
    const { sesion } = await registrar();
    const clave = `k-${idDelCliente()}`;
    await conClave("/v1/me", { weight_g: 71000 }, sesion.access_token, clave);
    const otro = await conClave("/v1/me", { weight_g: 72000 }, sesion.access_token, clave);
    assert.equal(otro.status, 409);
    assert.equal(otro.json.error.code, "conflict");
  });

  test("la misma clave de DOS personas distintas son cosas distintas", async () => {
    const a = await registrar();
    const b = await registrar();
    const clave = `compartida-${idDelCliente()}`;
    assert.equal((await conClave("/v1/me", { weight_g: 71000 }, a.sesion.access_token, clave)).status, 200);
    const rb = await conClave("/v1/me", { weight_g: 88000 }, b.sesion.access_token, clave);
    assert.equal(rb.status, 200);
    assert.equal(rb.json.data.weight_g, 88000);
  });

  test("el orden de las claves del cuerpo no cambia el hash", async () => {
    const { sesion } = await registrar();
    const clave = `k-${idDelCliente()}`;
    await conClave("/v1/me", { weight_g: 71000, height_mm: 1780 }, sesion.access_token, clave);
    const b = await conClave("/v1/me", { height_mm: 1780, weight_g: 71000 }, sesion.access_token, clave);
    assert.equal(b.headers["idempotency-replayed"], "true");
  });

  test("🛑 un pedido que FALLA no se cachea: se tiene que poder reintentar", async () => {
    const { sesion } = await registrar();
    const clave = `k-${idDelCliente()}`;
    assert.equal((await conClave("/v1/me", { weight_g: 5 }, sesion.access_token, clave)).status, 400);
    assert.equal((await conClave("/v1/me", { weight_g: 71000 }, sesion.access_token, clave)).status, 200);
  });
});

// =============================================================================
// El motor (contrato 1.1.0)
// =============================================================================

describe("catálogo", { skip: SIN_SERVICIOS }, () => {
  test("se pagina entero por cursor, sin repetir ni saltear", async () => {
    const { sesion } = await registrar();
    const ids: string[] = [];
    let cursor: string | undefined;
    for (let vuelta = 0; vuelta < 20; vuelta++) {
      const url = `/v1/exercises?limit=50${cursor ? `&cursor=${cursor}` : ""}`;
      const r = await pedir("GET", url, undefined, sesion.access_token);
      assert.equal(r.status, 200, JSON.stringify(r.json));
      ids.push(...r.json.data.map((e: { id: string }) => e.id));
      if (!r.json.pagination.has_more) break;
      cursor = r.json.pagination.next_cursor;
    }
    const total = await db.unaFila<{ n: number }>("select count(*)::int as n from ejercicios where retirado_en_ms is null");
    assert.equal(ids.length, total?.n);
    assert.equal(new Set(ids).size, ids.length, "un id repetido es un cursor mal hecho");
  });

  test("los nombres salen en el idioma pedido y los sustitutos en snake_case", async () => {
    const { sesion } = await registrar();
    const en = await pedir("GET", "/v1/exercises?limit=200", undefined, sesion.access_token, undefined, { "accept-language": "en-US" });
    const press = en.json.data.find((e: { id: string }) => e.id === "press-banca-barra");
    assert.equal(press.name, "Barbell bench press");
    assert.ok(press.substitutes.every((s: { kind: string }) => s.kind === "mismo_patron" || s.kind === "mismo_musculo"));
    const dicc = await pedir("GET", "/v1/exercises/dictionary", undefined, sesion.access_token);
    assert.ok(dicc.json.data.equipment.some((e: { id: string }) => e.id === "ninguno"));
  });

  test("un cursor roto es 400 y sin token es 401", async () => {
    const { sesion } = await registrar();
    assert.equal((await pedir("GET", "/v1/exercises?cursor=%25%25", undefined, sesion.access_token)).status, 400);
    assert.equal((await pedir("GET", "/v1/exercises")).status, 401);
  });

  test("sembrar dos veces no reescribe nada", async () => {
    const r = await sembrarCatalogo(db, Date.now());
    assert.equal(r.cambiados, 0);
    assert.equal(r.retirados, 0);
  });
});

describe("plan", { skip: SIN_SERVICIOS }, () => {
  test("el pronóstico exige sesión y coordenadas válidas", async () => {
    const sinSesion = await pedir("POST", "/v1/weather/forecast", { lat: -34.6, lon: -58.4 });
    assert.equal(sinSesion.status, 401);
    const { sesion } = await registrar();
    const invalida = await pedir("POST", "/v1/weather/forecast", { lat: 120, lon: -58.4 }, sesion.access_token);
    assert.equal(invalida.status, 400);
  });
  test("dos objetivos generan planes independientes y quitarlos no borra el historial", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const token = sesion.access_token;
    const principal = { id: "principal", goal: "media_maraton", goal_date_ms: null };
    const adicional = { goal: "c10k", goal_date_ms: null };
    const guardar = await pedir("PUT", "/v1/me/goals", { goals: [principal, adicional] }, token);
    assert.equal(guardar.status, 200, JSON.stringify(guardar.json));
    assert.equal(guardar.json.data.length, 2);
    const id = guardar.json.data[1].id;
    assert.match(id, /^[0-9a-f-]{36}$/);
    const planes = await pedir("GET", "/v1/plans", undefined, token);
    assert.equal(planes.status, 200, JSON.stringify(planes.json));
    assert.deepEqual(planes.json.data.map((p: { goal_id: string }) => p.goal_id), ["principal", id]);
    assert.deepEqual(planes.json.data.map((p: { plan: { goal: string } }) => p.plan.goal), ["media_maraton", "c10k"]);
    const repetido = await pedir("PUT", "/v1/me/goals", { goals: [principal, adicional] }, token);
    assert.equal(repetido.json.data[1].id, id, "reintentar no crea otro objetivo");
    const vaciar = await pedir("PUT", "/v1/me/goals", { goals: [] }, token);
    assert.equal(vaciar.status, 200);
    assert.deepEqual((await pedir("GET", "/v1/plans", undefined, token)).json.data, []);
    const historico = await db.unaFila<{ total: number }>(
      `select count(*)::integer as total from planes where usuario_id = $1 and objetivo_id is not null and reemplazado_en_ms is not null`,
      [sesion.user_id]);
    assert.equal(historico?.total, 1);
  });

  test("el 10K elegido SIN fecha y sin goal_date_ms se guarda, y el plan es ese 10K", async () => {
    // Así lo mandaba la app de iPhone: Codable omite los nil, y el contrato 1.2.0 exigía la clave.
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const token = sesion.access_token;
    const guardar = await pedir("PUT", "/v1/me/goals", { goals: [{ id: "principal", goal: "c10k" }, { id: "", goal: "c5k" }] }, token);
    assert.equal(guardar.status, 200, JSON.stringify(guardar.json));
    assert.deepEqual(guardar.json.data.map((g: { goal: string; goal_date_ms: number | null }) => [g.goal, g.goal_date_ms]),
      [["c10k", null], ["c5k", null]]);
    const yo = (await pedir("GET", "/v1/me", undefined, token)).json.data;
    assert.equal(yo.goal, "c10k");
    assert.equal(yo.goal_date_ms, null);
    const plan = (await pedir("GET", "/v1/plan", undefined, token)).json.data;
    assert.equal(plan.goal, "c10k");
  });

  test("MVP 100 % running: con ciclismo o triatlón en el perfil, todas las sesiones son a pie", async () => {
    for (const [sport, goal] of [["ciclismo", "c10k"], ["triatlon", "triatlon_olimpico"]] as const) {
      const { sesion } = await registrar(nuevoEmail(), perfilCompleto({ sport, goal }));
      const r = await pedir("GET", "/v1/plan", undefined, sesion.access_token);
      assert.equal(r.status, 200, JSON.stringify(r.json));
      assert.equal(r.json.data.goal, goal, "el objetivo es el guardado");
      for (const d of r.json.data.days as Array<{ type: string; sport: string }>) {
        if (d.type === "descanso") continue;
        assert.ok(d.sport === "running" || (d.type === "fuerza" && d.sport === "fuerza"), `${sport}: ${d.type} en ${d.sport}`);
      }
      assert.equal(r.json.data.days.at(-1).distance_m, 10_000);
    }
  });

  test("un bloque sin fecha que ya terminó arranca de nuevo hoy, con el mismo objetivo", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto({ goal: "c10k", goal_date_ms: null }));
    const token = sesion.access_token;
    const antes = (await pedir("GET", "/v1/plan", undefined, token)).json.data;
    // Se envejece el ancla: el bloque de 8 semanas queda entero en el pasado.
    await db.consultar(`update planes set inicio_fecha = $2 where usuario_id = $1 and reemplazado_en_ms is null`,
      [sesion.user_id, fechaLocal(Date.now() - 80 * DIA_MS, ZONA)]);
    await pedir("PUT", "/v1/me/goals", { goals: [{ id: "principal", goal: "c10k", goal_date_ms: null }] }, token);
    const despues = (await pedir("GET", "/v1/plan", undefined, token)).json.data;
    assert.equal(despues.goal, "c10k");
    assert.ok(despues.generated_at_ms >= antes.generated_at_ms);
    const hoy = fechaLocal(Date.now(), ZONA);
    assert.ok(despues.days.some((d: { date_ms: number }) => fechaLocal(d.date_ms, ZONA) >= hoy), "el plan llega a hoy");
  });

  test("con el perfil incompleto, profile_incomplete", async () => {
    const { sesion } = await registrar();
    const r = await pedir("GET", "/v1/plan", undefined, sesion.access_token);
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "profile_incomplete");
  });

  test("con el perfil completo sale el bloque, termina en la carrera, y es determinístico", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const a = await pedir("GET", "/v1/plan", undefined, sesion.access_token);
    assert.equal(a.status, 200, JSON.stringify(a.json));
    const plan = a.json.data;
    assert.ok(plan.days.length > 70);
    assert.equal(plan.days.at(-1).type, "carrera");
    assert.ok(plan.phases.length >= 3);
    assert.ok(plan.days.every((d: { title: string }) => d.title.length > 0));
    assert.ok(plan.days.some((d: { fueling?: unknown }) => d.fueling !== undefined), "con peso, hay avituallamiento");

    const b = await pedir("GET", "/v1/plan", undefined, sesion.access_token);
    assert.equal(b.json.data.input_hash, plan.input_hash);
    assert.deepEqual(b.json.data.days, plan.days, "mismo perfil, mismo plan");
  });

  test("cambiar el peso NO mueve el bloque; cambiar los días SÍ", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const antes = (await pedir("GET", "/v1/plan", undefined, sesion.access_token)).json.data;

    await pedir("PATCH", "/v1/me", { weight_g: 70000 }, sesion.access_token);
    const conOtroPeso = (await pedir("GET", "/v1/plan", undefined, sesion.access_token)).json.data;
    assert.equal(conOtroPeso.generated_at_ms, antes.generated_at_ms);
    assert.notEqual(conOtroPeso.input_hash, antes.input_hash, "el peso entra al cálculo");

    await pedir("PATCH", "/v1/me", { training_days: [{ weekday: 1, minute_of_day: 420 }, { weekday: 6, minute_of_day: 540 }] }, sesion.access_token);
    const conOtrosDias = (await pedir("GET", "/v1/plan", undefined, sesion.access_token)).json.data;
    assert.ok(conOtrosDias.generated_at_ms >= antes.generated_at_ms);
    assert.notEqual(conOtrosDias.input_hash, antes.input_hash);
    const entrenados = new Set(
      conOtrosDias.days.filter((d: { type: string }) => d.type !== "descanso" && d.type !== "carrera").map((d: { weekday: number }) => d.weekday)
    );
    assert.deepEqual([...entrenados].sort(), [1, 6]);
  });

  test("los textos vienen en el idioma pedido", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const es = (await pedir("GET", "/v1/plan", undefined, sesion.access_token)).json.data;
    const en = (await pedir("GET", "/v1/plan", undefined, sesion.access_token, undefined, { "accept-language": "en" })).json.data;
    assert.equal(en.locale, "en-US");
    assert.equal(en.input_hash, es.input_hash, "el idioma no cambia el plan");
    assert.ok(en.days.some((d: { title: string; detail: string }, i: number) =>
      d.title !== es.days[i].title || d.detail !== es.days[i].detail),
    "algún texto del plan debe estar traducido; un título como Fartlek puede coincidir");
  });
});

describe("rutina", { skip: SIN_SERVICIOS }, () => {
  test("sin equipamiento declarado, todo es sin equipo y no se prescribe peso", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const ahora = Date.now();
    const r = await pedir("GET", `/v1/plan/routine?date_ms=${ahora}`, undefined, sesion.access_token);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    const rutina = r.json.data;
    assert.equal(rutina.session_id, `gym-${fechaLocal(ahora, ZONA)}`);
    assert.deepEqual(rutina.equipment_assumed, ["ninguno"]);
    assert.ok(rutina.exercises.length > 0);
    assert.ok(rutina.exercises.every((e: { equipment: string }) => e.equipment === "ninguno"));
    assert.ok(
      rutina.exercises.every((e: { sets: Array<{ weight_g?: number }> }) => e.sets.every((s) => s.weight_g === undefined)),
      "🛑 el motor no inventa cargas"
    );
  });

  test("con equipamiento, lo usa; y la columna PREVIA sale de la última sesión", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto({ equipment: ["mancuernas", "barra", "banco"] }));
    const hoy = Date.now();
    const primera = (await pedir("GET", `/v1/plan/routine?date_ms=${hoy}`, undefined, sesion.access_token)).json.data;
    assert.ok(primera.exercises.some((e: { equipment: string }) => e.equipment !== "ninguno"));

    const ejercicio = primera.exercises[0].exercise_id;
    const ayer = fechaLocal(hoy - DIA_MS, ZONA);
    const s = await pedir("POST", `/v1/gym/sessions/gym-${ayer}/sets`, { sets: [serie(1, { exercise_id: ejercicio, reps: 9, weight_g: 20_000 })] }, sesion.access_token);
    assert.equal(s.status, 200, JSON.stringify(s.json));

    const segunda = (await pedir("GET", `/v1/plan/routine?date_ms=${hoy}`, undefined, sesion.access_token)).json.data;
    const conPrevia = segunda.exercises.find((e: { exercise_id: string }) => e.exercise_id === ejercicio);
    assert.deepEqual(conPrevia.previous_sets, [{ number: 1, reps: 9, weight_g: 20_000, skipped: false }]);
  });
});

describe("gimnasio: la decisión 0006 en el servidor", { skip: SIN_SERVICIOS }, () => {
  test("sincronizar crea la sesión y devuelve la hora de llegada y la fecha", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const r = await pedir("POST", "/v1/gym/sessions/gym-2026-09-10/sets", { sets: [serie(1), serie(2)] }, sesion.access_token);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(r.json.data.sets.length, 2);
    assert.ok(r.json.data.sets.every((s: { received_at_ms: number }) => typeof s.received_at_ms === "number"));
    assert.equal(typeof r.json.data.date_ms, "number");
  });

  test("🛑 la misma serie desde el reloj y desde el teléfono queda UNA, y no se desmarca", async () => {
    const { sesion } = await registrar();
    const url = "/v1/gym/sessions/gym-2026-09-11/sets";
    await pedir("POST", url, { sets: [serie(2, { device: "reloj", reps: 8 })] }, sesion.access_token);
    const r = await pedir("POST", url, { sets: [serie(2, { device: "telefono", reps: 6, done: false })] }, sesion.access_token);
    assert.equal(r.json.data.sets.length, 1, "la misma serie física no puede quedar duplicada");
    const s = r.json.data.sets[0];
    assert.equal(s.reps, 6, "fila completa: gana la última en llegar");
    assert.equal(s.device, "telefono");
    assert.equal(s.done, true, "🛑 una sincronización no desmarca");
  });

  test("un reintento con la misma Idempotency-Key no vuelve a escribir", async () => {
    const { sesion } = await registrar();
    const url = "/v1/gym/sessions/gym-2026-09-12/sets";
    const clave = idDelCliente();
    // El MISMO cuerpo: `serie()` pone la hora local, y dos llamadas darían dos
    // cuerpos distintos, que con la misma clave son un 409 y no un reintento.
    const cuerpo = { sets: [serie(1)] };
    const a = await pedir("POST", url, cuerpo, sesion.access_token, undefined, { "idempotency-key": clave });
    const b = await pedir("POST", url, cuerpo, sesion.access_token, undefined, { "idempotency-key": clave });
    assert.equal(a.status, 200);
    assert.equal(b.headers["idempotency-replayed"], "true");
    assert.deepEqual(b.json, a.json);
  });

  test("🛑 IDOR: la sesión de otra persona es 404, y el mismo id es de cada una", async () => {
    const a = await registrar();
    const b = await registrar();
    const id = "gym-2026-09-13";
    await pedir("POST", `/v1/gym/sessions/${id}/sets`, { sets: [serie(1, { reps: 5 })] }, a.sesion.access_token);
    assert.equal((await pedir("GET", `/v1/gym/sessions/${id}`, undefined, b.sesion.access_token)).status, 404);
    await pedir("POST", `/v1/gym/sessions/${id}/sets`, { sets: [serie(1, { reps: 12 })] }, b.sesion.access_token);
    const deA = await pedir("GET", `/v1/gym/sessions/${id}`, undefined, a.sesion.access_token);
    assert.equal(deA.json.data.sets[0].reps, 5, "lo de B no puede tocar lo de A");
  });

  test("🛑 topes: más de 200 series es 400, y un id con mayúsculas también", async () => {
    const { sesion } = await registrar();
    const muchas = Array.from({ length: 201 }, (_, i) => serie((i % 50) + 1, { exercise_id: `e${i}` }));
    assert.equal((await pedir("POST", "/v1/gym/sessions/gym-2026-09-14/sets", { sets: muchas }, sesion.access_token)).status, 400);
    assert.equal((await pedir("POST", "/v1/gym/sessions/GYM-X/sets", { sets: [serie(1)] }, sesion.access_token)).status, 400);
  });

  test("el historial se pagina", async () => {
    const { sesion } = await registrar();
    for (const d of ["01", "02", "03"]) {
      await pedir("POST", `/v1/gym/sessions/gym-2026-08-${d}/sets`, { sets: [serie(1)] }, sesion.access_token);
    }
    const p1 = await pedir("GET", "/v1/gym/sessions?limit=2", undefined, sesion.access_token);
    assert.equal(p1.json.data.length, 2);
    assert.equal(p1.json.pagination.has_more, true);
    const p2 = await pedir("GET", `/v1/gym/sessions?limit=2&cursor=${p1.json.pagination.next_cursor}`, undefined, sesion.access_token);
    assert.equal(p2.json.data.length, 1);
    assert.equal(p2.json.pagination.has_more, false);
  });
});

describe("actividades", { skip: SIN_SERVICIOS }, () => {
  const salida = { sport: "running", started_at_ms: Date.now() - 3_600_000, duration_s: 3000, distance_m: 10_000, device: "reloj" };

  test("el PUT es idempotente por id: dos veces, una actividad", async () => {
    const { sesion } = await registrar();
    const id = idDelCliente();
    assert.equal((await pedir("PUT", `/v1/activities/${id}`, salida, sesion.access_token)).status, 200);
    assert.equal((await pedir("PUT", `/v1/activities/${id}`, { ...salida, duration_s: 3100 }, sesion.access_token)).status, 200);
    const lista = await pedir("GET", "/v1/activities", undefined, sesion.access_token);
    assert.equal(lista.json.data.length, 1);
    assert.equal(lista.json.data[0].duration_s, 3100);
  });

  test("triatlón conserva su deporte en el historial", async () => {
    const { sesion } = await registrar();
    const id = idDelCliente();
    const creada = await pedir("PUT", `/v1/activities/${id}`,
      { ...salida, sport: "triatlon" }, sesion.access_token);
    assert.equal(creada.status, 200);
    const lista = await pedir("GET", "/v1/activities", undefined, sesion.access_token);
    assert.equal(lista.json.data[0].sport, "triatlon");
  });

  test("🛑 lo borrado no resucita con un PUT viejo", async () => {
    const { sesion } = await registrar();
    const id = idDelCliente();
    await pedir("PUT", `/v1/activities/${id}`, salida, sesion.access_token);
    assert.equal((await pedir("DELETE", `/v1/activities/${id}`, undefined, sesion.access_token)).status, 204);
    const tarde = await pedir("PUT", `/v1/activities/${id}`, salida, sesion.access_token);
    assert.equal(tarde.status, 404);
    assert.equal((await pedir("GET", "/v1/activities", undefined, sesion.access_token)).json.data.length, 0);
  });

  test("el pulso medio no puede ser mayor que el máximo", async () => {
    const { sesion } = await registrar();
    const r = await pedir("PUT", `/v1/activities/${idDelCliente()}`, { ...salida, avg_hr_bpm: 170, max_hr_bpm: 160 }, sesion.access_token);
    assert.equal(r.status, 400);
  });

  test("🛑 IDOR: B no ve ni borra lo de A", async () => {
    const a = await registrar();
    const b = await registrar();
    const id = idDelCliente();
    await pedir("PUT", `/v1/activities/${id}`, salida, a.sesion.access_token);
    assert.equal((await pedir("GET", "/v1/activities", undefined, b.sesion.access_token)).json.data.length, 0);
    assert.equal((await pedir("DELETE", `/v1/activities/${id}`, undefined, b.sesion.access_token)).status, 204);
    assert.equal((await pedir("GET", "/v1/activities", undefined, a.sesion.access_token)).json.data.length, 1);
  });

  test("el recorrido se guarda, se lee sólo con la cuenta propia y desaparece al borrar", async () => {
    const a = await registrar();
    const b = await registrar();
    const id = idDelCliente();
    const ruta = `/v1/activities/${id}/route`;
    const points = [
      { lat: -34.6037, lon: -58.3816, at_ms: 1_789_000_000_000 },
      { lat: -34.6038, lon: -58.3817, at_ms: 1_789_000_005_000 },
    ];
    assert.equal((await pedir("PUT", `/v1/activities/${id}`, salida, a.sesion.access_token)).status, 200);
    assert.equal((await pedir("PUT", ruta, { points }, a.sesion.access_token)).status, 200);
    assert.deepEqual((await pedir("GET", ruta, undefined, a.sesion.access_token)).json.data.points, points);
    assert.equal((await pedir("GET", ruta, undefined, b.sesion.access_token)).status, 404);
    assert.equal((await pedir("PUT", ruta, { points }, b.sesion.access_token)).status, 404);
    assert.equal((await pedir("PUT", ruta, { points: points.slice().reverse() }, a.sesion.access_token)).status, 400);
    await pedir("DELETE", `/v1/activities/${id}`, undefined, a.sesion.access_token);
    assert.equal((await pedir("GET", ruta, undefined, a.sesion.access_token)).status, 404);
    assert.equal((await pedir("PUT", ruta, { points }, a.sesion.access_token)).status, 404);
  });
});

describe("nutrición: los guardarraíles de §9.2 de punta a punta", { skip: SIN_SERVICIOS }, () => {
  test("un hombre con perfil completo tiene objetivos, marcados como provisionales", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto());
    const r = await pedir("GET", `/v1/nutrition/day?date_ms=${Date.now()}`, undefined, sesion.access_token);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.ok(r.json.data.targets.kcal >= 1500, "nunca bajo el piso absoluto");
    assert.equal(r.json.data.targets.provisional, true);
    assert.equal(r.json.data.unavailable_reason, undefined);
  });

  test("🛑 una mujer que no respondió embarazo o lactancia NO recibe un número", async () => {
    const { sesion } = await registrar(nuevoEmail(), perfilCompleto({ biological_sex: "femenino" }));
    const sin = await pedir("GET", `/v1/nutrition/day?date_ms=${Date.now()}`, undefined, sesion.access_token);
    assert.equal(sin.json.data.targets, undefined);
    assert.equal(sin.json.data.unavailable_reason, "falta_embarazo_o_lactancia");

    await pedir("PATCH", "/v1/me", { pregnant_or_breastfeeding: true }, sesion.access_token);
    const embarazada = await pedir("GET", `/v1/nutrition/day?date_ms=${Date.now()}`, undefined, sesion.access_token);
    assert.equal(embarazada.json.data.unavailable_reason, "embarazo_o_lactancia");

    await pedir("PATCH", "/v1/me", { pregnant_or_breastfeeding: false }, sesion.access_token);
    const no = await pedir("GET", `/v1/nutrition/day?date_ms=${Date.now()}`, undefined, sesion.access_token);
    assert.ok(no.json.data.targets.kcal > 0);
  });

  test("sin zona horaria no hay día", async () => {
    const { sesion } = await registrar();
    const r = await pedir("GET", `/v1/nutrition/day?date_ms=${Date.now()}`, undefined, sesion.access_token);
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "profile_incomplete");
  });

  test("las comidas suman al día, se borran, y no se ven entre cuentas", async () => {
    const a = await registrar(nuevoEmail(), perfilCompleto());
    const b = await registrar(nuevoEmail(), perfilCompleto());
    const ahora = Date.now();
    const id = idDelCliente();
    const comida = { eaten_at_ms: ahora, name: "Avena con banana", kcal: 420, carbs_g: 72, protein_g: 12, fat_g: 9 };
    assert.equal((await pedir("PUT", `/v1/meals/${id}`, comida, a.sesion.access_token)).status, 200);

    const dia = await pedir("GET", `/v1/nutrition/day?date_ms=${ahora}`, undefined, a.sesion.access_token);
    assert.deepEqual(dia.json.data.consumed, { kcal: 420, carbs_g: 72, protein_g: 12, fat_g: 9 });
    const deB = await pedir("GET", `/v1/nutrition/day?date_ms=${ahora}`, undefined, b.sesion.access_token);
    assert.equal(deB.json.data.meals.length, 0, "🛑 IDOR");

    assert.equal((await pedir("DELETE", `/v1/meals/${id}`, undefined, a.sesion.access_token)).status, 204);
    const despues = await pedir("GET", `/v1/nutrition/day?date_ms=${ahora}`, undefined, a.sesion.access_token);
    assert.equal(despues.json.data.meals.length, 0);
  });
});

describe("pasos diarios (contrato 1.3.0)", { skip: SIN_SERVICIOS }, () => {
  const hoy = () => new Date().toISOString().slice(0, 10);
  const haceDias = (n: number) => new Date(Date.now() - n * DIA_MS).toISOString().slice(0, 10);

  test("se guardan de a lote y se leen por rango, del más viejo al más nuevo", async () => {
    const { sesion } = await registrar();
    const r = await pedir("PUT", "/v1/me/steps", { days: [
      { date: haceDias(1), steps: 9_500, source: "healthkit" },
      { date: haceDias(3), steps: 4_200, source: "manual" },
    ] }, sesion.access_token);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.deepEqual(r.json.data.map((d: any) => d.date), [haceDias(3), haceDias(1)]);

    const g = await pedir("GET", `/v1/me/steps?from=${haceDias(10)}&to=${hoy()}`, undefined, sesion.access_token);
    assert.equal(g.status, 200);
    assert.deepEqual(g.json.data.map((d: any) => [d.date, d.steps, d.source]),
                     [[haceDias(3), 4_200, "manual"], [haceDias(1), 9_500, "healthkit"]]);
    const fuera = await pedir("GET", `/v1/me/steps?from=${haceDias(2)}&to=${haceDias(2)}`, undefined, sesion.access_token);
    assert.equal(fuera.json.data.length, 0, "un día sin fila no se inventa en cero");
  });

  test("🛑 gana el más nuevo: un reintento viejo no pisa una corrección", async () => {
    const { sesion } = await registrar();
    const ahora = Date.now();
    const nuevo = { date: haceDias(1), steps: 11_000, source: "healthkit", updated_at_ms: ahora };
    const viejo = { date: haceDias(1), steps: 3_000, source: "manual", updated_at_ms: ahora - 3_600_000 };
    assert.equal((await pedir("PUT", "/v1/me/steps", { days: [nuevo] }, sesion.access_token)).status, 200);
    const tarde = await pedir("PUT", "/v1/me/steps", { days: [viejo] }, sesion.access_token);
    assert.equal(tarde.status, 200);
    assert.equal(tarde.json.data[0].steps, 11_000, "la respuesta dice lo que quedó");

    const masNuevo = { ...viejo, steps: 12_345, updated_at_ms: ahora + 1 };
    const r = await pedir("PUT", "/v1/me/steps", { days: [masNuevo] }, sesion.access_token);
    assert.equal(r.json.data[0].steps, 12_345);
    assert.equal(r.json.data[0].source, "manual");
  });

  test("la misma Idempotency-Key devuelve la misma respuesta", async () => {
    const { sesion } = await registrar();
    const clave = { "idempotency-key": idDelCliente() };
    const cuerpo = { days: [{ date: haceDias(2), steps: 5_000, source: "manual" }] };
    const a = await pedir("PUT", "/v1/me/steps", cuerpo, sesion.access_token, undefined, clave);
    const b = await pedir("PUT", "/v1/me/steps", cuerpo, sesion.access_token, undefined, clave);
    assert.equal(b.status, 200);
    assert.equal(b.headers["idempotency-replayed"], "true");
    assert.deepEqual(b.json, a.json);
  });

  test("🛑 topes: del futuro, repetidos, 61 días o un rango de más de 366 días son 400", async () => {
    const { sesion } = await registrar();
    const t = sesion.access_token;
    const futuro = new Date(Date.now() + 3 * DIA_MS).toISOString().slice(0, 10);
    assert.equal((await pedir("PUT", "/v1/me/steps", { days: [{ date: futuro, steps: 1, source: "manual" }] }, t)).status, 400);
    assert.equal((await pedir("PUT", "/v1/me/steps", { days: [
      { date: haceDias(1), steps: 1, source: "manual" }, { date: haceDias(1), steps: 2, source: "manual" },
    ] }, t)).status, 400);
    const muchos = Array.from({ length: 61 }, (_, i) => ({ date: haceDias(i + 1), steps: 1, source: "manual" }));
    assert.equal((await pedir("PUT", "/v1/me/steps", { days: muchos }, t)).status, 400);
    assert.equal((await pedir("GET", `/v1/me/steps?from=${haceDias(400)}&to=${hoy()}`, undefined, t)).status, 400);
    assert.equal((await pedir("GET", `/v1/me/steps?from=${hoy()}&to=${haceDias(1)}`, undefined, t)).status, 400);
  });

  test("🛑 IDOR: B no ve los pasos de A, y sin token es 401", async () => {
    const a = await registrar();
    const b = await registrar();
    await pedir("PUT", "/v1/me/steps", { days: [{ date: haceDias(1), steps: 7_000, source: "healthkit" }] }, a.sesion.access_token);
    const deB = await pedir("GET", `/v1/me/steps?from=${haceDias(5)}&to=${hoy()}`, undefined, b.sesion.access_token);
    assert.equal(deB.json.data.length, 0);
    assert.equal((await pedir("GET", `/v1/me/steps?from=${haceDias(5)}&to=${hoy()}`)).status, 401);
  });
});

describe("cuenta: exportar y borrar (§8)", { skip: SIN_SERVICIOS }, () => {
  test("exportar trae todo lo de la persona y nada secreto", async () => {
    const { email, sesion } = await registrar(nuevoEmail(), perfilCompleto());
    await pedir("POST", "/v1/gym/sessions/gym-2026-09-15/sets", { sets: [serie(1)] }, sesion.access_token);
    await pedir("PUT", `/v1/activities/${idDelCliente()}`, { sport: "running", started_at_ms: Date.now(), duration_s: 60, device: "telefono" }, sesion.access_token);
    await pedir("GET", "/v1/plan", undefined, sesion.access_token);
    const ayer = new Date(Date.now() - DIA_MS).toISOString().slice(0, 10);
    await pedir("PUT", "/v1/me/steps", { days: [{ date: ayer, steps: 6_543, source: "healthkit" }] }, sesion.access_token);

    const r = await pedir("GET", "/v1/me/export", undefined, sesion.access_token);
    assert.equal(r.status, 200, JSON.stringify(r.json));
    const d = r.json.data;
    assert.equal(d.profile.email, email);
    assert.equal(d.legal_acceptances.length, 1);
    assert.equal(d.plans.length, 1);
    assert.equal(d.gym_sessions[0].sets.length, 1);
    assert.equal(d.activities.length, 1);
    assert.deepEqual(d.steps.map((p: any) => [p.date, p.steps, p.source]), [[ayer, 6_543, "healthkit"]]);
    const texto = JSON.stringify(d);
    assert.ok(!texto.includes("argon2") && !texto.includes("refresh"), "🛑 ni hashes ni tokens");
  });

  test("🛑 borrar pide la contraseña, cierra todo, y deja volver a registrarse", async () => {
    const { email, sesion } = await registrar(nuevoEmail(), perfilCompleto());
    await pedir("GET", "/v1/plan", undefined, sesion.access_token);
    await pedir("POST", "/v1/gym/sessions/gym-2026-10-06/sets", { sets: [serie(1)] }, sesion.access_token);
    await pedir("PUT", `/v1/activities/${idDelCliente()}`, {
      sport: "running", started_at_ms: Date.now(), duration_s: 60, device: "telefono",
    }, sesion.access_token);
    await pedir("PUT", "/v1/me/steps", {
      days: [{ date: new Date(Date.now() - DIA_MS).toISOString().slice(0, 10), steps: 1_000, source: "manual" }],
    }, sesion.access_token);
    // Con contraseña, mandarla es obligatorio: el cuerpo vacío es para Google/Apple.
    const sinClave = await pedir("POST", "/v1/me/delete", {}, sesion.access_token);
    assert.equal(sinClave.status, 401);
    assert.equal(sinClave.json.error.code, "invalid_credentials");
    const perfilAntes = await pedir("GET", "/v1/me", undefined, sesion.access_token);
    assert.equal(perfilAntes.json.data.has_password, true);

    const mala = await pedir("POST", "/v1/me/delete", { password: "No-es-la-clave-1" }, sesion.access_token);
    assert.equal(mala.status, 401);
    assert.equal(mala.json.error.code, "invalid_credentials");

    assert.equal((await pedir("POST", "/v1/me/delete", { password: PASSWORD }, sesion.access_token)).status, 204);
    const restos = await db.unaFila<{ total: number }>(
      `select (select count(*) from usuarios where id = $1) +
              (select count(*) from perfiles where usuario_id = $1) +
              (select count(*) from sesiones where usuario_id = $1) +
              (select count(*) from planes where usuario_id = $1) +
              (select count(*) from sesiones_gimnasio where usuario_id = $1) +
              (select count(*) from series_gimnasio where usuario_id = $1) +
              (select count(*) from series_gimnasio_historial where usuario_id = $1) +
              (select count(*) from actividades where usuario_id = $1) +
              (select count(*) from pasos_diarios where usuario_id = $1) +
              (select count(*) from aceptaciones_legales where usuario_id = $1) as total`,
      [sesion.user_id]
    );
    assert.equal(restos?.total, 0, "la cuenta y sus datos se borran físicamente en cascada");
    const me = await pedir("GET", "/v1/me", undefined, sesion.access_token);
    assert.equal(me.status, 401);
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: PASSWORD })).status, 401);
    assert.equal((await pedir("POST", "/v1/auth/refresh", { refresh_token: sesion.refresh_token })).status, 401);

    // El correo quedó libre: la cuenta vieja no existe para ninguna lectura.
    const otraVez = await registrar(email);
    assert.notEqual(otraVez.sesion.user_id, sesion.user_id);
  });
});

test("staging sólo admite el correo autorizado y no envía códigos a terceros", { skip: SIN_SERVICIOS }, async () => {
  const cerrado = await crearServidor({
    ...ctx,
    config: { ...ctx.config, entorno: "staging", registroPermitido: "karkoszkaivan@gmail.com" },
  });
  try {
    const ajeno = nuevoEmail();
    const antes = codigos.length;
    const inicio = await cerrado.inject({
      method: "POST", url: "/v1/auth/register", payload: { email: ajeno }, remoteAddress: ipDePrueba(),
    });
    assert.equal(inicio.statusCode, 202);
    assert.equal(codigos.length, antes, "no se envía un correo a la cuenta ajena");
    const verificar = await cerrado.inject({
      method: "POST", url: "/v1/auth/register/verify",
      payload: { email: ajeno, code: "AAAAAA" }, remoteAddress: ipDePrueba(),
    });
    assert.equal(verificar.statusCode, 400);
  } finally {
    await cerrado.close();
  }
});
