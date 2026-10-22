/**
 * Contrato 1.6.0 ("Entrar y registrarse"): las piezas que no necesitan base ni
 * Redis. Los recorridos de punta a punta están en integracion.cuenta-1-6.test.ts.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { CODIGOS, ErrorApi, aCuerpo } from "../src/infra/errores.js";
import { crearCacheEnMemoria } from "../src/infra/redis.js";
import { crearServicioAuth } from "../src/dominios/auth/servicio.js";
import { versionLegal } from "../src/dominios/legal/textos.js";
import { crearTopeDeIntentos } from "../src/dominios/auth/intentos.js";
import {
  firmarReactivacion, firmarVinculo, hashearPassword, leerReactivacion, leerVinculo,
} from "../src/infra/cripto.js";
import type { Config } from "../src/config.js";
import type { Contexto } from "../src/contexto.js";
import type { Db } from "../src/infra/db.js";

describe("el sobre de error con details (1.6.0)", () => {
  test("los códigos nuevos están registrados con su status", () => {
    assert.equal(CODIGOS.too_many_attempts, 429);
    assert.equal(CODIGOS.code_attempts_exceeded, 400);
    assert.equal(CODIGOS.account_link_available, 409);
    assert.equal(CODIGOS.invalid_link_token, 401);
    assert.equal(CODIGOS.account_deactivated, 403);
    assert.equal(CODIGOS.account_pending_deletion, 403);
    assert.equal(CODIGOS.invalid_reactivation_token, 401);
  });

  test("sin details el sobre es el de siempre; con details, sale en error.details", () => {
    assert.deepEqual(aCuerpo(new ErrorApi("wrong_password", "x")), { error: { code: "wrong_password", message: "x" } });
    const e = new ErrorApi("account_pending_deletion", "y", undefined, { reactivation_token: "t", days_remaining: 3 });
    assert.equal(e.http, 403);
    assert.deepEqual(aCuerpo(e), {
      error: { code: "account_pending_deletion", message: "y", details: { reactivation_token: "t", days_remaining: 3 } },
    });
  });
});

// ------------------------------------------------- servicio con dobles --
// El servicio de auth con la caché en memoria y un reloj que se mueve a mano. La
// base es un doble que contesta siempre la misma fila de `usuarios` (o ninguna):
// alcanza para los caminos que no escriben, que son los de los códigos.

const CONFIG_PRUEBA = {
  jwtSecret: new TextEncoder().encode("un-secreto-de-prueba-de-mas-de-32-bytes-largo"),
  registroPermitido: null,
  accessTtlS: 900,
  refreshTtlS: 86_400,
  proveedores: { google: [], apple: [] },
} as unknown as Config;

function dbFalsa(usuario: object | null): Db {
  const db: Db = {
    async consultar() { return []; },
    async unaFila<T>() { return usuario as T | null; },
    async enTransaccion(fn) { return fn(db); },
    async vivo() { return true; },
    async cerrar() {},
  };
  return db;
}

function armar(usuario: object | null = null) {
  let ahora = 1_800_000_000_000;
  const codigos: string[] = [];
  const ctx: Contexto = {
    config: CONFIG_PRUEBA,
    db: dbFalsa(usuario),
    cache: crearCacheEnMemoria(() => ahora),
    correo: {
      async enviarCodigo(_d, codigo) { codigos.push(codigo); },
      async avisarIntentoDeRegistro() {},
      async avisarVinculacion() {},
    },
    ahoraMs: () => ahora,
  };
  return { auth: crearServicioAuth(ctx), codigos, avanzar: (ms: number) => { ahora += ms; } };
}

async function codigoDeError(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (e) {
    if (e instanceof ErrorApi) return e.codigo;
    throw e;
  }
  return "sin error";
}

describe("códigos por correo (1.6.0)", () => {
  test("a los 5 equivocados el código se invalida con code_attempts_exceeded, y el correcto ya no sirve", async () => {
    const { auth, codigos } = armar();
    await auth.registroInicio("a@b.co");
    for (let i = 1; i <= 4; i++) assert.equal(await codigoDeError(auth.registroVerificar("a@b.co", "ZZZZZZ")), "invalid_code");
    assert.equal(await codigoDeError(auth.registroVerificar("a@b.co", "ZZZZZZ")), "code_attempts_exceeded");
    assert.equal(await codigoDeError(auth.registroVerificar("a@b.co", codigos.at(-1)!)), "code_attempts_exceeded");
  });

  test("🛑 pasados los 15 minutos es code_expired, no invalid_code", async () => {
    const { auth, codigos, avanzar } = armar();
    await auth.registroInicio("a@b.co");
    avanzar(15 * 60_000 + 1_000);
    assert.equal(await codigoDeError(auth.registroVerificar("a@b.co", codigos.at(-1)!)), "code_expired");
    avanzar(30 * 60_000);
    assert.equal(await codigoDeError(auth.registroVerificar("a@b.co", "ZZZZZZ")), "code_expired");
  });

  test("pedir otro invalida el anterior, y el nuevo es distinto", async () => {
    const { auth, codigos, avanzar } = armar();
    await auth.registroInicio("a@b.co");
    avanzar(61_000);
    await auth.registroInicio("a@b.co");
    const [viejo, nuevo] = codigos;
    assert.notEqual(viejo, nuevo);
    assert.equal(await codigoDeError(auth.registroVerificar("a@b.co", viejo!)), "invalid_code");
    assert.ok((await auth.registroVerificar("a@b.co", nuevo!)).registration_token.length > 20);
  });

  test("después de agotar uno, el código nuevo vuelve a valer", async () => {
    const { auth, codigos, avanzar } = armar();
    await auth.registroInicio("a@b.co");
    for (let i = 1; i <= 5; i++) await codigoDeError(auth.registroVerificar("a@b.co", "ZZZZZZ"));
    avanzar(61_000);
    await auth.registroInicio("a@b.co");
    assert.ok((await auth.registroVerificar("a@b.co", codigos.at(-1)!)).registration_token);
  });

  test("con el registration_token vencido no se crea nada", async () => {
    const { auth, codigos, avanzar } = armar();
    await auth.registroInicio("a@b.co");
    const { registration_token } = await auth.registroVerificar("a@b.co", codigos.at(-1)!);
    avanzar(10 * 60_000 + 1_000);
    assert.equal(
      await codigoDeError(auth.registroCompletar(registration_token, { password: "Caballo-bateria-9" },
        { version: versionLegal(), accepted: true })),
      "invalid_registration_token",
    );
  });

  test("con el reset_token vencido no se cambia nada", async () => {
    const { auth, codigos, avanzar } = armar({ id: "u-1", email: "a@b.co", password_hash: "x", creado_en_ms: 0, actualizado_en_ms: 0 });
    await auth.recuperacionInicio("a@b.co");
    const { reset_token } = await auth.recuperacionVerificar("a@b.co", codigos.at(-1)!);
    avanzar(10 * 60_000 + 1_000);
    assert.equal(await codigoDeError(auth.recuperacionAplicar(reset_token, "Caballo-bateria-9")), "invalid_reset_token");
  });
});

describe("el tope de contraseñas equivocadas (1.6.0)", () => {
  function tope() {
    let ahora = 1_800_000_000_000;
    const t = crearTopeDeIntentos(crearCacheEnMemoria(() => ahora), () => ahora);
    return { t, avanzar: (ms: number) => { ahora += ms; } };
  }

  test("5 seguidas bloquean el correo 15 minutos, desde cualquier IP, y después se libera", async () => {
    const { t, avanzar } = tope();
    for (let i = 1; i <= 4; i++) assert.equal(await t.fallo("a@b.co", `10.0.0.${i}`), null);
    assert.equal(await t.fallo("a@b.co", "10.0.0.9"), 900);
    assert.equal(await t.bloqueoDeCorreo("a@b.co"), 900);
    assert.equal(await t.bloqueoDeCorreo("otro@b.co"), null);
    avanzar(14 * 60_000);
    assert.equal(await t.bloqueoDeCorreo("a@b.co"), 60);
    avanzar(60_001);
    assert.equal(await t.bloqueoDeCorreo("a@b.co"), null);
  });

  test("entrar bien (o cambiar la contraseña) reinicia la racha", async () => {
    const { t } = tope();
    for (let i = 1; i <= 4; i++) await t.fallo("a@b.co", "10.0.0.1");
    await t.reiniciar("a@b.co");
    for (let i = 1; i <= 4; i++) assert.equal(await t.fallo("a@b.co", "10.0.0.1"), null);
  });

  test("20 fallos de una IP entre muchos correos la frenan, sin bloquear esos correos", async () => {
    const { t, avanzar } = tope();
    for (let i = 0; i < 19; i++) await t.fallo(i % 2 === 0 ? `c${i}@b.co` : null, "10.0.0.1");
    assert.equal(await t.bloqueoDeIp("10.0.0.1"), null);
    await t.fallo(null, "10.0.0.1");
    assert.equal(await t.bloqueoDeIp("10.0.0.1"), 900);
    assert.equal(await t.bloqueoDeIp("10.0.0.2"), null);
    assert.equal(await t.bloqueoDeCorreo("c0@b.co"), null);
    avanzar(15 * 60_000 + 1);
    assert.equal(await t.bloqueoDeIp("10.0.0.1"), null);
  });

  test("login: el quinto fallo ya contesta too_many_attempts, y bloqueado ni la correcta entra", async () => {
    const hash = await hashearPassword("Caballo-bateria-9");
    const { auth } = armar({ id: "u-1", email: "a@b.co", password_hash: hash, creado_en_ms: 0, actualizado_en_ms: 0 });
    for (let i = 1; i <= 4; i++) {
      assert.equal(await codigoDeError(auth.login("a@b.co", "Otra-clave-1", `10.0.0.${i}`)), "wrong_password");
    }
    let bloqueo: unknown;
    try { await auth.login("A@B.co ", "Otra-clave-1", "10.0.0.5"); } catch (e) { bloqueo = e; }
    assert.ok(bloqueo instanceof ErrorApi && bloqueo.codigo === "too_many_attempts" && bloqueo.http === 429);
    assert.equal(bloqueo.reintentarEnS, 900, "Retry-After con los segundos que faltan");
    assert.equal(await codigoDeError(auth.login("a@b.co", "Caballo-bateria-9", "10.0.0.6")), "too_many_attempts");
  });

  test("password_not_set dice con qué proveedor nació la cuenta", async () => {
    // El doble de la base contesta la misma fila a todo: sirve de usuario y de identidad.
    const { auth } = armar({ id: "u-1", email: "a@b.co", password_hash: null, proveedor: "apple" });
    try {
      await auth.login("a@b.co", "Caballo-bateria-9", "10.0.0.1");
      assert.fail("tenía que fallar");
    } catch (e) {
      assert.ok(e instanceof ErrorApi);
      assert.deepEqual(aCuerpo(e).error, {
        code: "password_not_set", message: "This account signs in with Google or Apple", details: { provider: "apple" },
      });
    }
  });
});

describe("desactivar, borrar con gracia y reactivar (1.6.0)", () => {
  const DIA = 86_400_000;

  async function cuenta(estado: { desactivada_en_ms?: number | null; borrar_en_ms?: number | null }) {
    const hash = await hashearPassword("Caballo-bateria-9");
    // La misma fila sirve de usuario, de sesión creada y de cuenta reactivada.
    return armar({
      id: "u-1", usuario_id: "u-1", familia_id: "f-1", vence_en_ms: 1_900_000_000_000,
      email: "a@b.co", password_hash: hash, creado_en_ms: 0, actualizado_en_ms: 0,
      desactivada_en_ms: null, borrar_en_ms: null, ...estado,
    });
  }

  async function error(p: Promise<unknown>): Promise<ErrorApi> {
    try { await p; } catch (e) { if (e instanceof ErrorApi) return e; throw e; }
    assert.fail("tenía que fallar");
  }

  test("con la contraseña correcta, una cuenta desactivada contesta account_deactivated con su permiso", async () => {
    const { auth } = await cuenta({ desactivada_en_ms: 1 });
    const e = await error(auth.login("a@b.co", "Caballo-bateria-9", "10.0.0.1"));
    assert.equal(e.codigo, "account_deactivated");
    assert.equal(e.http, 403);
    assert.deepEqual(Object.keys(e.detalles ?? {}), ["reactivation_token"]);
  });

  test("🛑 con la contraseña equivocada sigue siendo wrong_password: el estado no se le dice a quien no la sabe", async () => {
    const { auth } = await cuenta({ desactivada_en_ms: 1, borrar_en_ms: 1_800_000_000_000 + DIA });
    const e = await error(auth.login("a@b.co", "Otra-clave-1", "10.0.0.1"));
    assert.equal(e.codigo, "wrong_password");
    assert.equal(e.detalles, undefined);
  });

  test("por borrarse: account_pending_deletion con los días que faltan, redondeados para arriba", async () => {
    const { auth, avanzar } = await cuenta({ borrar_en_ms: 1_800_000_000_000 + 30 * DIA });
    avanzar(Math.round(0.8 * DIA));
    const e = await error(auth.login("a@b.co", "Caballo-bateria-9", "10.0.0.1"));
    assert.equal(e.codigo, "account_pending_deletion");
    assert.equal(e.detalles?.days_remaining, 30);
    assert.ok(e.detalles?.reactivation_token);
  });

  test("el permiso de reactivar abre la sesión UNA vez, y vencido no sirve", async () => {
    const { auth, avanzar } = await cuenta({ desactivada_en_ms: 1 });
    const token = (await error(auth.login("a@b.co", "Caballo-bateria-9", "10.0.0.1"))).detalles!.reactivation_token!;
    assert.equal((await auth.reactivar(token)).user_id, "u-1");
    assert.equal((await error(auth.reactivar(token))).codigo, "invalid_reactivation_token");
    const otro = (await error(auth.login("a@b.co", "Caballo-bateria-9", "10.0.0.1"))).detalles!.reactivation_token!;
    avanzar(10 * 60_000 + 1_000);
    assert.equal((await error(auth.reactivar(otro))).codigo, "invalid_reactivation_token");
    assert.equal((await error(auth.reactivar("no-es-un-jwt"))).codigo, "invalid_reactivation_token");
  });

  test("los permisos de vincular y de reactivar no se cruzan", async () => {
    const config = { jwtSecret: CONFIG_PRUEBA.jwtSecret };
    const ahora = Date.now();
    const v = await firmarVinculo(config, { usuarioId: "u", proveedor: "google", sujeto: "s", email: null, requierePassword: true }, ahora, 60_000);
    const r = await firmarReactivacion(config, "u", ahora, 60_000);
    assert.equal((await leerVinculo(config, v, ahora))?.requierePassword, true);
    assert.equal((await leerReactivacion(config, r, ahora))?.usuarioId, "u");
    assert.equal(await leerVinculo(config, r, ahora), null);
    assert.equal(await leerReactivacion(config, v, ahora), null);
    assert.equal(await leerVinculo(config, v, ahora + 120_000), null);
  });
});
