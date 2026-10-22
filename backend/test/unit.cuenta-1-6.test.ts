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
