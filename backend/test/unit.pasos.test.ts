/**
 * test/unit.pasos.test.ts — los pasos diarios (contrato 1.3.0), sin Postgres.
 *
 * Tres cosas:
 *  1. La validación que el esquema no puede hacer: días que existen, nada del
 *     futuro, sin repetidos, la hora de cada escritura y el tope del rango.
 *  2. Que el esquema del contrato, tal cual lo usa Fastify, corte lo que tiene que
 *     cortar: más de 60 días, un número fuera de rango, una fuente inventada.
 *  3. Que el repositorio mande el lote en una sola sentencia y filtre por usuario.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import Fastify from "fastify";
import { cuerpo, parametros } from "../src/infra/esquemas.js";
import { ErrorApi } from "../src/infra/errores.js";
import type { Db, Fila } from "../src/infra/db.js";
import {
  esFechaDeCalendario,
  normalizarLote,
  ultimoDiaAceptado,
  validarRango,
  MAX_DIAS_DEL_RANGO,
  type DiaDePasosEntrada,
} from "../src/dominios/pasos/validacion.js";
import { crearRepoPasos, pasosAApi } from "../src/dominios/pasos/repositorio.js";

/** 2026-10-19 15:00 UTC. */
const AHORA = Date.UTC(2026, 9, 19, 15, 0, 0);

const dia = (date: string, o: Partial<DiaDePasosEntrada> = {}): DiaDePasosEntrada => ({
  date,
  steps: 8_000,
  source: "healthkit",
  ...o,
});

const esBadRequest = (e: unknown) => e instanceof ErrorApi && e.codigo === "bad_request";

describe("qué es un día de calendario", () => {
  test("acepta días que existen, bisiestos incluidos", () => {
    for (const f of ["2026-10-19", "2024-02-29", "2000-01-01", "2026-12-31"]) {
      assert.ok(esFechaDeCalendario(f), f);
    }
  });

  test("rechaza días con la forma pero que no existen, y otras formas", () => {
    for (const f of ["2026-02-29", "2026-02-30", "2026-13-01", "2026-00-10", "2026-10-00", "1999-12-31",
                     "2026-1-19", "26-10-19", "2026/10/19", "2026-10-19T00:00:00Z", ""]) {
      assert.ok(!esFechaDeCalendario(f), f);
    }
  });
});

describe("un lote de PUT /me/steps", () => {
  test("se ordena por fecha y la hora ausente vale 'ahora'", () => {
    const lote = normalizarLote([dia("2026-10-18"), dia("2026-10-17", { updated_at_ms: AHORA - 1_000 })], AHORA);
    assert.deepEqual(lote, [
      { fecha: "2026-10-17", pasos: 8_000, fuente: "healthkit", actualizadoMs: AHORA - 1_000 },
      { fecha: "2026-10-18", pasos: 8_000, fuente: "healthkit", actualizadoMs: AHORA },
    ]);
  });

  test("🛑 una hora del futuro se baja a 'ahora': un reloj adelantado no traba el día", () => {
    const [d] = normalizarLote([dia("2026-10-19", { updated_at_ms: AHORA + 86_400_000 })], AHORA);
    assert.equal(d?.actualizadoMs, AHORA);
  });

  test("mañana en UTC se acepta (UTC+14), pasado mañana no", () => {
    assert.equal(ultimoDiaAceptado(AHORA), "2026-10-20");
    assert.equal(normalizarLote([dia("2026-10-20")], AHORA).length, 1);
    assert.throws(() => normalizarLote([dia("2026-10-21")], AHORA), esBadRequest);
  });

  test("un día repetido o inexistente es 400, no una fila pisada", () => {
    assert.throws(() => normalizarLote([dia("2026-10-18"), dia("2026-10-18", { steps: 1 })], AHORA), esBadRequest);
    assert.throws(() => normalizarLote([dia("2026-02-30")], AHORA), esBadRequest);
  });

  test("vacío o con más de 60 días es 400 aunque el esquema no corriera", () => {
    assert.throws(() => normalizarLote([], AHORA), esBadRequest);
    const muchos = Array.from({ length: 61 }, (_, i) => dia(`2026-08-${String((i % 28) + 1).padStart(2, "0")}`));
    assert.throws(() => normalizarLote(muchos, AHORA), esBadRequest);
  });
});

describe("el rango de GET /me/steps", () => {
  test("incluye las dos puntas: 366 días entran, 367 no", () => {
    assert.equal(MAX_DIAS_DEL_RANGO, 366);
    assert.deepEqual(validarRango("2025-10-19", "2026-10-19"), { desde: "2025-10-19", hasta: "2026-10-19" });
    assert.throws(() => validarRango("2025-10-18", "2026-10-19"), esBadRequest);
  });

  test("un solo día vale; al revés o con un día inexistente, 400", () => {
    assert.ok(validarRango("2026-10-19", "2026-10-19"));
    assert.throws(() => validarRango("2026-10-20", "2026-10-19"), esBadRequest);
    assert.throws(() => validarRango("2026-02-30", "2026-03-01"), esBadRequest);
  });
});

describe("el contrato, como lo valida Fastify", () => {
  async function servidor() {
    // Mismas opciones de Ajv que servidor.ts.
    const app = Fastify({ ajv: { customOptions: { removeAdditional: false, allErrors: false, strict: false } } });
    app.put("/steps", { schema: { body: cuerpo("putSteps") } }, async (req) => req.body);
    app.get("/steps", { schema: parametros("getSteps") }, async (req) => req.query);
    await app.ready();
    return app;
  }

  test("el PUT acepta lo que manda la app y corta lo que no entra", async () => {
    const app = await servidor();
    try {
      const put = (payload: unknown) => app.inject({ method: "PUT", url: "/steps", payload: payload as object });
      assert.equal((await put({ days: [dia("2026-10-19")] })).statusCode, 200, "sin updated_at_ms");
      assert.equal((await put({ days: [dia("2026-10-19", { updated_at_ms: AHORA, source: "manual" })] })).statusCode, 200);
      assert.equal((await put({ days: [dia("2026-10-19", { source: "health_connect" })] })).statusCode, 200);

      assert.equal((await put({ days: [] })).statusCode, 400, "vacío");
      assert.equal((await put({ days: Array.from({ length: 61 }, () => dia("2026-10-19")) })).statusCode, 400, "61 días");
      assert.equal((await put({ days: [dia("2026-10-19", { steps: 200_001 })] })).statusCode, 400, "tope de pasos");
      assert.equal((await put({ days: [dia("2026-10-19", { steps: -1 })] })).statusCode, 400, "negativo");
      assert.equal((await put({ days: [dia("2026-10-19", { source: "fitbit" as never })] })).statusCode, 400, "fuente");
      assert.equal((await put({ days: [dia("19/10/2026")] })).statusCode, 400, "forma de la fecha");
      assert.equal((await put({ days: [{ ...dia("2026-10-19"), extra: 1 }] })).statusCode, 400, "clave de más");
      assert.equal((await put({ days: [dia("2026-10-19")], user_id: "x" })).statusCode, 400, "🛑 ni un id en el cuerpo");
    } finally {
      await app.close();
    }
  });

  test("el GET exige las dos puntas con forma de día", async () => {
    const app = await servidor();
    try {
      const get = (q: string) => app.inject({ method: "GET", url: `/steps${q}` });
      assert.equal((await get("?from=2026-10-01&to=2026-10-19")).statusCode, 200);
      assert.equal((await get("?from=2026-10-01")).statusCode, 400);
      assert.equal((await get("?from=1760000000000&to=2026-10-19")).statusCode, 400);
      assert.equal((await get("?from=2026-10-01&to=2026-10-19&user=x")).statusCode, 400);
    } finally {
      await app.close();
    }
  });
});

describe("el repositorio", () => {
  function baseQueAnota(respuesta: Fila[] = []) {
    const consultas: Array<{ sql: string; valores: readonly unknown[] }> = [];
    const db: Db = {
      async consultar<T extends Fila = Fila>(sql: string, valores: readonly unknown[] = []) {
        consultas.push({ sql, valores });
        return (sql.trimStart().startsWith("select") ? respuesta : []) as T[];
      },
      async unaFila() { return null; },
      async enTransaccion(fn) { return fn(db); },
      async vivo() { return true; },
      async cerrar() {},
    };
    return { db, consultas };
  }

  test("el lote viaja en UNA escritura, gana el más nuevo, y todo filtra por usuario", async () => {
    const fila = { fecha: "2026-10-18", pasos: 9_000, fuente: "manual", actualizado_ms: AHORA };
    const { db, consultas } = baseQueAnota([fila]);
    const repo = crearRepoPasos(db);
    const lote = normalizarLote([dia("2026-10-18"), dia("2026-10-17", { steps: 4_000 })], AHORA);
    const filas = await repo.guardar("usuario-a", lote);

    assert.equal(consultas.length, 2, "un insert y un select, no uno por día");
    const [insert, select] = consultas as [typeof consultas[number], typeof consultas[number]];
    assert.match(insert.sql, /on conflict \(usuario_id, fecha\) do update/);
    assert.match(insert.sql, /where excluded\.actualizado_ms >= pasos_diarios\.actualizado_ms/);
    assert.deepEqual(insert.valores, ["usuario-a", ["2026-10-17", "2026-10-18"], [4_000, 8_000],
                                      ["healthkit", "healthkit"], [AHORA, AHORA]]);
    assert.match(select.sql, /where usuario_id = \$1/);
    assert.equal(select.valores[0], "usuario-a");
    assert.deepEqual(filas.map(pasosAApi), [{ date: "2026-10-18", steps: 9_000, source: "manual", updated_at_ms: AHORA }],
                     "devuelve lo que quedó, no lo que se mandó");
  });

  test("🛑 la fecha sale como texto: un DATE convertido a Date correría el día", async () => {
    const { db, consultas } = baseQueAnota();
    const repo = crearRepoPasos(db);
    await repo.delRango("usuario-a", "2026-10-01", "2026-10-19");
    await repo.todos("usuario-a");
    for (const c of consultas) {
      assert.match(c.sql, /to_char\(fecha, 'YYYY-MM-DD'\) as fecha/);
      assert.equal(c.valores[0], "usuario-a");
    }
  });
});
