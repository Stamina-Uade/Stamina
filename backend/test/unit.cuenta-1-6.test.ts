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
import type { FastifyRequest } from "fastify";
import { idiomaDeCorreo } from "../src/infra/idioma.js";
import {
  correoDeCodigo, correoDeIntentoDeRegistro, correoDeNuevoInicio, correoDeVinculacion, saludo,
} from "../src/infra/plantillas-correo.js";

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
  const avisos: Array<{ destino: string; idioma: string }> = [];
  const ctx: Contexto = {
    config: CONFIG_PRUEBA,
    db: dbFalsa(usuario),
    cache: crearCacheEnMemoria(() => ahora),
    correo: {
      async enviarCodigo(_d, codigo) { codigos.push(codigo); },
      async avisarIntentoDeRegistro() {},
      async avisarVinculacion() {},
      async avisarNuevoInicio(destino, aviso) {
        avisos.push({ destino, idioma: aviso.idioma });
      },
    },
    ahoraMs: () => ahora,
  };
  return { auth: crearServicioAuth(ctx), codigos, avisos, avanzar: (ms: number) => { ahora += ms; } };
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

describe("cambiar la contraseña ya no avisa por correo (1.7.0)", () => {
  const FILA = {
    id: "u-1", usuario_id: "u-1", familia_id: "f-1", vence_en_ms: 1_900_000_000_000,
    email: "a@b.co", password_hash: "x", creado_en_ms: 0, actualizado_en_ms: 0,
    desactivada_en_ms: null, borrar_en_ms: null,
  };

  test("recuperar devuelve la sesión y no manda ningún aviso", async () => {
    const a = armar(FILA);
    await a.auth.recuperacionInicio("a@b.co");
    const { reset_token } = await a.auth.recuperacionVerificar("a@b.co", a.codigos.at(-1)!);
    const sesion = await a.auth.recuperacionAplicar(reset_token, "Caballo-bateria-9", { ip: "10.0.0.1", idioma: "fr" });
    assert.equal(sesion.user_id, "u-1");
    assert.deepEqual(a.avisos, []);
  });

  test("el idioma sale del Accept-Language: inglés, francés, y si no, español", () => {
    const pedido = (h?: string) => ({ headers: h === undefined ? {} : { "accept-language": h } }) as unknown as FastifyRequest;
    assert.equal(idiomaDeCorreo(pedido("en-US,en;q=0.9")), "en");
    assert.equal(idiomaDeCorreo(pedido("fr-FR")), "fr");
    assert.equal(idiomaDeCorreo(pedido("es-AR")), "es");
    assert.equal(idiomaDeCorreo(pedido("de-DE")), "es");
    assert.equal(idiomaDeCorreo(pedido()), "es");
  });

  test("cada correo sale en su idioma, con el lang del HTML y el texto plano sin entidades", () => {
    const aviso = { nombre: null, ip: "203.0.113.7", dispositivo: "iPhone 16 · iOS 26.5", ahoraMs: 0 };
    const es = correoDeNuevoInicio({ ...aviso, idioma: "es" });
    assert.ok(es.html.includes('<html lang="es">'));
    const en = correoDeNuevoInicio({ ...aviso, idioma: "en" });
    assert.equal(en.asunto, "New sign-in to your Stamina account");
    assert.ok(en.texto.includes("If it wasn't you"), en.texto);
    assert.ok(en.html.includes('<html lang="en">') && en.html.includes("does not receive replies"));
    const fr = correoDeCodigo({ codigo: "K7Q2MB", proposito: "registro", nombre: "Iván", idioma: "fr", vidaMin: 15 });
    assert.equal(fr.asunto, "K7Q2MB est ton code de vérification Stamina");
    assert.ok(fr.texto.startsWith("Bonjour Iván,"), fr.texto);
    assert.ok(fr.texto.includes("Tu y es presque. Saisis ce code dans l'app"), fr.texto);
    assert.ok(!/\bvous\b/i.test(fr.texto + fr.html), "en francés se tutea");
  });
});

describe("los correos de la 1.7.0", () => {
  const aviso = { nombre: "Iván", idioma: "es" as const, ip: "203.0.113.7", dispositivo: "iPhone 16 · iOS 26.5", ahoraMs: 0 };

  test("todos empiezan con Hola y el nombre, o con ¡Hola! sin nombre", () => {
    assert.equal(saludo("Iván"), "Hola Iván,");
    assert.equal(saludo(null), "¡Hola!");
    assert.equal(saludo("Emma", "en"), "Hi Emma,");
    assert.equal(saludo(null, "fr"), "Bonjour !");
    for (const c of [
      correoDeCodigo({ codigo: "K7Q2MB", proposito: "registro", nombre: "Iván", vidaMin: 15 }),
      correoDeCodigo({ codigo: "K7Q2MB", proposito: "recuperacion", nombre: "Iván", vidaMin: 15 }),
      correoDeNuevoInicio(aviso),
      correoDeVinculacion({ ...aviso, proveedor: "google" }),
    ]) assert.ok(c.texto.startsWith("Hola Iván,"), c.texto);
  });

  test("el código: asunto nuevo, sólo el código en el recuadro y el vencimiento en el párrafo", () => {
    const alta = correoDeCodigo({ codigo: "K7Q2MB", proposito: "registro", nombre: null, vidaMin: 15 });
    assert.equal(alta.asunto, "K7Q2MB es tu código de verificación de Stamina");
    assert.ok(alta.texto.includes("crear tu cuenta de Stamina. Vence en 15 minutos."), alta.texto);
    for (const fuera of ["Tu código de verificación", "Correo:", "Vence:", "Pedido:"]) {
      assert.ok(!alta.texto.includes(fuera), `no va «${fuera}»`);
    }
    assert.ok(alta.html.includes('align="center"') && alta.html.includes("K7Q2MB"));
    assert.ok(alta.texto.includes("Si no fuiste tú, puedes ignorar este mensaje"));
    assert.ok(alta.texto.includes("Nunca te vamos a pedir este código"));
    const clave = correoDeCodigo({ codigo: "K7Q2MB", proposito: "recuperacion", nombre: null, vidaMin: 15 });
    assert.equal(clave.asunto, "K7Q2MB es tu código para cambiar la contraseña de Stamina");
    assert.ok(!clave.texto.includes("Tu código para cambiar la contraseña"));
  });

  test("nuevo inicio de sesión: el recuadro con IP, dispositivo y hora, y sin ubicación si no se sabe", () => {
    const c = correoDeNuevoInicio(aviso);
    assert.equal(c.asunto, "Nuevo inicio de sesión en tu cuenta de Stamina");
    assert.ok(c.texto.includes("Detectamos un inicio de sesión en tu cuenta de Stamina desde un dispositivo nuevo."));
    for (const fila of ["Nuevo inicio de sesión", "Dirección IP: 203.0.113.7", "Dispositivo: iPhone 16 · iOS 26.5", "Hora: "]) {
      assert.ok(c.texto.includes(fila), fila);
    }
    assert.ok(!c.texto.includes("Ubicación"));
    assert.ok(c.texto.includes("Si fuiste tú, no hace falta que hagas nada."));
    assert.ok(c.texto.includes("al terminar, te ofrece cerrar las otras sesiones."));
    assert.ok(correoDeNuevoInicio({ ...aviso, ubicacion: "Rosario, Argentina" }).texto.includes("Ubicación: Rosario, Argentina"));
  });

  test("vinculación: el mismo recuadro, titulado con el proveedor", () => {
    const g = correoDeVinculacion({ ...aviso, proveedor: "google" });
    assert.equal(g.asunto, "Tu cuenta de Stamina se conectó con Google");
    assert.ok(g.texto.includes("Tu cuenta de Stamina se conectó con Google con éxito."));
    assert.ok(g.texto.includes("Cuenta conectada con Google") && g.texto.includes("Dirección IP: 203.0.113.7"));
    assert.ok(g.texto.includes("cambia ya la contraseña de tu cuenta de Google y la de Stamina"));
    assert.equal(correoDeVinculacion({ ...aviso, proveedor: "apple" }).asunto, "Tu cuenta de Stamina se conectó con Apple");
  });

  test("el nombre se escapa en el HTML", () => {
    const c = correoDeNuevoInicio({ ...aviso, nombre: "<b>Iván</b>" });
    assert.ok(!c.html.includes("<b>Iván</b>"));
  });
});

describe("los correos en español van de tú (1.6.0)", () => {
  // Las formas del voseo que tenían los correos, y las que podrían volver.
  // Con \p{L} y no \b: para \b la "á" final no es letra, y «Ingresá» pasaría.
  const VOSEO = /(?<!\p{L})(vos|sos|podés|tenés|querés|sabés|entrás|ingresá|tocá|entrá|cambiá|escribinos|escribí|revisá)(?!\p{L})/iu;

  test("ningún correo en español vosea", () => {
    const correos = [
      correoDeCodigo({ codigo: "K7P4XM", proposito: "registro", nombre: "Emma", vidaMin: 15 }),
      correoDeCodigo({ codigo: "K7P4XM", proposito: "recuperacion", nombre: null, vidaMin: 15 }),
      correoDeIntentoDeRegistro({ destino: "a@b.co", ahoraMs: 0 }),
      correoDeVinculacion({ nombre: null, idioma: "es", ip: "203.0.113.7", dispositivo: null, ahoraMs: 0, proveedor: "google" }),
      correoDeVinculacion({ nombre: null, idioma: "es", ip: "203.0.113.7", dispositivo: null, ahoraMs: 0, proveedor: "apple" }),
      correoDeNuevoInicio({ nombre: null, idioma: "es", ip: "203.0.113.7", dispositivo: null, ahoraMs: 0 }),
    ];
    for (const c of correos) {
      for (const parte of [c.asunto, c.texto, c.html]) {
        const m = VOSEO.exec(parte);
        assert.equal(m, null, `voseo en «${m?.[0]}»: ${c.asunto}`);
      }
    }
    assert.ok(correos[0]!.texto.includes("Ingresa este código"));
    assert.ok(correos[0]!.texto.includes("Si no fuiste tú, puedes ignorar"));
    assert.ok(correos[3]!.asunto.startsWith("Tu cuenta de Stamina se conectó"));
  });
});
