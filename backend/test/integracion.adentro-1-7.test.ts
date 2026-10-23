/**
 * test/integracion.adentro-1-7.test.ts — el contrato 1.7.0 ("Adentro de la app")
 * de punta a punta, contra Postgres y Redis de verdad: marcar a mano un día del
 * plan, los dispositivos conocidos y el correo de un inicio de sesión nuevo.
 *
 * El armado es el de integracion.cuenta-1-6.test.ts, con un correo doble que anota
 * lo que se mandó. Necesita DATABASE_URL y REDIS_URL apuntando a una base
 * DESCARTABLE. Si no están, los tests se saltean.
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
import type { DatosDeAviso } from "../src/infra/correo.js";
import type { IdentidadVerificada, NombreDeProveedor } from "../src/infra/proveedores.js";
import type { Contexto } from "../src/contexto.js";

const HAY_SERVICIOS = Boolean(process.env["DATABASE_URL"] && process.env["REDIS_URL"]);
const SIN_SERVICIOS = !HAY_SERVICIOS ? "faltan DATABASE_URL y REDIS_URL" : false;

let app: FastifyInstance;
let db: Db;
let cache: Cache;

const enviados = {
  codigos: [] as Array<{ destino: string; codigo: string }>,
  nuevosInicios: [] as Array<{ destino: string; aviso: DatosDeAviso }>,
  vinculaciones: [] as Array<{ destino: string; aviso: DatosDeAviso | undefined }>,
};

const PASSWORD = "Caballo-bateria-grapa-9";

before(async () => {
  if (!HAY_SERVICIOS) return;
  // Detrás de un proxy de confianza, como en el servidor: si no, los headers de
  // ubicación de Cloudflare no se leen (infra/ubicacion.ts).
  process.env["TRUST_PROXY"] = "true";
  const config = cargarConfig();
  db = crearDb(config);
  cache = crearCache(config);
  await migrar(db, () => {});
  await prepararHashDummy();
  const ctx: Contexto = {
    config,
    db,
    cache,
    correo: {
      async enviarCodigo(destino, codigo) { enviados.codigos.push({ destino, codigo }); },
      async avisarIntentoDeRegistro() {},
      async avisarVinculacion(destino, _proveedor, aviso) { enviados.vinculaciones.push({ destino, aviso }); },
      async avisarNuevoInicio(destino, aviso) { enviados.nuevosInicios.push({ destino, aviso }); },
    },
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
  return `a17-${Date.now()}${randomInt(1e6)}@${dominio}`;
}

let ipContador = randomInt(1_000_000);
function ipDePrueba(): string {
  ipContador += 1;
  return `10.${17 + (Math.floor(ipContador / 62_500) % 16)}.${Math.floor(ipContador / 250) % 250}.${(ipContador % 250) + 1}`;
}

async function pedir(
  metodo: "GET" | "POST" | "PUT", url: string, cuerpo?: unknown, token?: string, extra: Record<string, string> = {},
) {
  const res = await app.inject({
    method: metodo,
    url,
    payload: cuerpo as object | undefined,
    remoteAddress: ipDePrueba(),
    headers: { ...(token !== undefined ? { authorization: `Bearer ${token}` } : {}), ...extra },
  });
  let json: any = null;
  try { json = res.body === "" ? null : JSON.parse(res.body); } catch { json = res.body; }
  return { status: res.statusCode, json };
}

function ultimoCodigo(email: string): string {
  const c = [...enviados.codigos].reverse().find((x) => x.destino === email);
  assert.ok(c, `no se mandó ningún código a ${email}`);
  return c.codigo;
}

const IPHONE = { id: `inst-${randomUUID()}`, model: "iPhone 16", os: "iOS 26.5" };

const PERFIL = {
  first_name: "Iván",
  sport: "running",
  level: "intermedio",
  goal: "media_maraton",
  timezone: "America/Argentina/Buenos_Aires",
  // Todos los días, para que haya días de entrenamiento en el pasado.
  training_days: [1, 2, 3, 4, 5, 6, 7].map((weekday) => ({ weekday, minute_of_day: 1110 })),
};

/** `null`: un alta sin `device` (pasar `undefined` cae en el default). */
async function registrar(device: object | null = IPHONE, email = nuevoEmail()) {
  assert.equal((await pedir("POST", "/v1/auth/register", { email })).status, 202);
  const v = await pedir("POST", "/v1/auth/register/verify", { email, code: ultimoCodigo(email) });
  assert.equal(v.status, 200, JSON.stringify(v.json));
  const r = await pedir("POST", "/v1/auth/register/complete", {
    registration_token: v.json.data.registration_token,
    password: PASSWORD,
    profile: PERFIL,
    legal: { version: versionLegal(), accepted: true },
    ...(device === null ? {} : { device }),
  });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  return { email, sesion: r.json.data as { access_token: string; user_id: string } };
}

function avisosA(email: string) {
  return enviados.nuevosInicios.filter((x) => x.destino === email);
}

describe("nuevo inicio de sesión desde un dispositivo nuevo (1.7.0)", { skip: SIN_SERVICIOS }, () => {
  test("el dispositivo del alta nace conocido; uno nuevo avisa una vez, en el idioma del pedido", async () => {
    const { email } = await registrar();
    assert.equal(avisosA(email).length, 0, "registrarse no avisa");

    const mismo = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: IPHONE });
    assert.equal(mismo.status, 200);
    assert.equal(avisosA(email).length, 0, "el del alta ya es conocido");

    const otro = { id: `inst-${randomUUID()}`, model: "iPad Air", os: "iPadOS 26.1" };
    const r = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: otro }, undefined, {
      "accept-language": "en-US,en;q=0.9",
    });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    const avisos = avisosA(email);
    assert.equal(avisos.length, 1);
    assert.equal(avisos[0]!.aviso.idioma, "en");
    assert.equal(avisos[0]!.aviso.nombre, "Iván");
    assert.equal(avisos[0]!.aviso.dispositivo, "iPad Air · iPadOS 26.1");
    assert.match(avisos[0]!.aviso.ip, /^10\./);

    await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: otro });
    assert.equal(avisosA(email).length, 1, "la segunda vez ya es conocido");
  });

  test("sin device (un cliente que no lo manda) no se sabe si es nuevo y no avisa", async () => {
    const { email } = await registrar(null);
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: PASSWORD })).status, 200);
    assert.equal(avisosA(email).length, 0);
  });

  test("una cuenta sin dispositivos anotados (de antes de 1.7.0): el primero entra callado, el segundo avisa", async () => {
    const { email } = await registrar(null);
    const suTelefono = { id: `inst-${randomUUID()}`, model: "iPhone 13", os: "iOS 26.5" };
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: suTelefono })).status, 200);
    assert.equal(avisosA(email).length, 0, "la primera entrada con la app nueva no es un dispositivo extraño");

    const otro = { id: `inst-${randomUUID()}`, model: "Pixel 9", os: "Android 16" };
    assert.equal((await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: otro })).status, 200);
    assert.equal(avisosA(email).length, 1);
    assert.equal(avisosA(email)[0]!.aviso.dispositivo, "Pixel 9 · Android 16");
  });

  test("la ubicación sale de los headers de Cloudflare, en el idioma del correo", async () => {
    const { email } = await registrar();
    const otro = { id: `inst-${randomUUID()}`, model: "iPad Air", os: "iPadOS 26.1" };
    const r = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: otro }, undefined, {
      "cf-ipcountry": "AR",
      "cf-ipcity": "C%C3%B3rdoba",
      "cf-connecting-ip": "181.93.48.185",
    });
    assert.equal(r.status, 200, JSON.stringify(r.json));
    assert.equal(avisosA(email)[0]!.aviso.ubicacion, "Córdoba, Argentina");
    assert.equal(avisosA(email)[0]!.aviso.ip, "181.93.48.185", "la IP de la persona, no la del borde de Cloudflare");

    const tercero = { id: `inst-${randomUUID()}`, model: "Pixel 9", os: "Android 16" };
    await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: tercero }, undefined, { "cf-connecting-ip": "no-es-una-ip" });
    assert.match(avisosA(email)[1]!.aviso.ip, /^10\./, "si no es una IP, queda la del pedido");
  });

  test("entrar con Google ya vinculado desde un dispositivo nuevo avisa; vincular no manda los dos correos", async () => {
    const { email } = await registrar(IPHONE, nuevoEmail("gmail.com"));
    const sujeto = `suj-${randomUUID()}`;
    const idToken = () => JSON.stringify({ sujeto, email, emailVerificado: true, dominioGestionado: null, jti: randomUUID() });
    const nonce = "un-nonce-de-prueba-largo-1234";
    const oferta = await pedir("POST", "/v1/auth/social", { provider: "google", id_token: idToken(), nonce });
    assert.equal(oferta.json.error.code, "account_link_available");
    const nuevo = { id: `inst-${randomUUID()}`, model: "iPhone 15", os: "iOS 26.0" };
    const v = await pedir("POST", "/v1/auth/social/link", { link_token: oferta.json.error.details.link_token, device: nuevo });
    assert.equal(v.status, 200, JSON.stringify(v.json));
    const vinculo = enviados.vinculaciones.filter((x) => x.destino === email);
    assert.equal(vinculo.length, 1);
    assert.equal(vinculo[0]!.aviso?.dispositivo, "iPhone 15 · iOS 26.0");
    assert.equal(avisosA(email).length, 0, "el vínculo ya avisó: no va además el de inicio nuevo");

    const tercero = { id: `inst-${randomUUID()}` };
    const s = await pedir("POST", "/v1/auth/social", { provider: "google", id_token: idToken(), nonce, device: tercero });
    assert.equal(s.json.data.status, "signed_in");
    assert.equal(avisosA(email).length, 1);
    assert.equal(avisosA(email)[0]!.aviso.dispositivo, null, "sin modelo ni sistema, sin fila de dispositivo");
  });

  test("el contrato rechaza un device sin id", async () => {
    const { email } = await registrar();
    const r = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: { model: "iPhone" } });
    assert.equal(r.status, 400);
  });
});

/** Corre el bloque `dias` días hacia atrás, para tener días pasados que marcar. */
async function correrElBloque(usuarioId: string, dias: number): Promise<void> {
  await db.consultar(
    `update planes set inicio_fecha = to_char(inicio_fecha::date - $2::int, 'YYYY-MM-DD') where usuario_id = $1 and reemplazado_en_ms is null`,
    [usuarioId, dias]
  );
}

type DiaApi = { date_ms: number; type: string; done: boolean; manually_done?: boolean; week_number: number };
type PlanApi = {
  days: DiaApi[];
  weeks: Array<{ number: number; done_sessions: number; done_distance_m: number }>;
  streak: { current: number };
};

async function plan(token: string): Promise<PlanApi> {
  const r = await pedir("GET", "/v1/plans", undefined, token);
  assert.equal(r.status, 200, JSON.stringify(r.json));
  return r.json.data[0].plan as PlanApi;
}

describe("marcar a mano un día que pasó sin salida (1.7.0)", { skip: SIN_SERVICIOS }, () => {
  test("queda hecho y cuenta para la semana, sin metros y sin devolver la racha; se ve igual desde otra sesión", async () => {
    const { email, sesion } = await registrar();
    await plan(sesion.access_token);
    await correrElBloque(sesion.user_id, 3);
    const antes = await plan(sesion.access_token);
    const hoy = Date.now();
    const perdido = antes.days.find((d) => d.date_ms < hoy - 24 * 3600 * 1000 && d.type !== "descanso" && !d.done);
    assert.ok(perdido, "hace falta un día de entrenamiento pasado sin hacer");
    assert.equal(antes.streak.current, 0, "un día sin hacer apaga el fueguito");
    const semanaAntes = antes.weeks.find((w) => w.number === perdido.week_number)!;

    const r = await pedir("PUT", "/v1/plan/days/done", { date_ms: perdido.date_ms + 3_600_000 }, sesion.access_token);
    assert.equal(r.status, 204, JSON.stringify(r.json));
    assert.equal((await pedir("PUT", "/v1/plan/days/done", { date_ms: perdido.date_ms }, sesion.access_token)).status, 204,
      "idempotente");

    // Otra sesión, como otro dispositivo de la misma cuenta.
    const otra = await pedir("POST", "/v1/auth/login", { email, password: PASSWORD, device: IPHONE });
    const despues = await plan(otra.json.data.access_token);
    const dia = despues.days.find((d) => d.date_ms === perdido.date_ms)!;
    assert.equal(dia.done, true);
    assert.equal(dia.manually_done, true);
    const semana = despues.weeks.find((w) => w.number === perdido.week_number)!;
    assert.equal(semana.done_sessions, semanaAntes.done_sessions + 1);
    assert.equal(semana.done_distance_m, semanaAntes.done_distance_m, "un día marcado no suma metros");
    assert.equal(despues.streak.current, 0, "el fueguito no vuelve");

    const exportado = await pedir("GET", "/v1/me/export", undefined, sesion.access_token);
    assert.equal(exportado.status, 200);
    assert.equal(exportado.json.data.manual_done_days.length, 1);
    assert.match(exportado.json.data.manual_done_days[0].date, /^\d{4}-\d{2}-\d{2}$/);
    assert.deepEqual(exportado.json.data.known_devices.map((d: { model: string }) => d.model), ["iPhone 16"]);
    assert.ok(!JSON.stringify(exportado.json.data.known_devices).includes(IPHONE.id), "sin el identificador");
  });

  test("hoy, un día que viene y un día fuera del plan no se pueden marcar", async () => {
    const { sesion } = await registrar();
    const p = await plan(sesion.access_token);
    const hoy = Date.now();
    for (const date_ms of [hoy, hoy + 2 * 24 * 3600 * 1000, p.days[0]!.date_ms - 30 * 24 * 3600 * 1000]) {
      const r = await pedir("PUT", "/v1/plan/days/done", { date_ms }, sesion.access_token);
      assert.equal(r.status, 400, `date_ms ${date_ms}: ${JSON.stringify(r.json)}`);
      assert.equal(r.json.error.code, "bad_request");
    }
    assert.equal((await plan(sesion.access_token)).days.some((d) => d.manually_done === true), false);
  });
});
