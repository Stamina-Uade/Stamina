/**
 * test/unit.mvp-running.test.ts — el MVP es 100 % running, y el plan sale del objetivo GUARDADO.
 *
 * Dos cosas, sin Postgres ni Redis:
 *  1. La puerta del motor (motor/tipos.ts, MVP_SOLO_RUNNING): con cualquier deporte en el perfil y
 *     cualquier objetivo, cada sesión es de running —o de fuerza, que es parte del plan de un
 *     corredor—; el descanso no es una sesión.
 *  2. `calcularPlan` (dominios/plan/servicio.ts) contra una base en memoria: planifica el objetivo
 *     que quedó en `perfiles` (o el adicional pedido), arranca un bloque nuevo cuando el objetivo
 *     cambia, y también cuando el bloque terminó y el objetivo sigue vigente.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { generarPlan } from "../src/dominios/plan/motor/generador.js";
import { textosDelDia } from "../src/dominios/plan/motor/textos.js";
import { MVP_SOLO_RUNNING } from "../src/dominios/plan/motor/tipos.js";
import type { DeportePerfil, EntradaDelMotor, Nivel, Objetivo, PlanGenerado } from "../src/dominios/plan/motor/tipos.js";
import { calcularPlan } from "../src/dominios/plan/servicio.js";
import type { Contexto } from "../src/contexto.js";
import type { Db, Fila } from "../src/infra/db.js";
import Fastify from "fastify";
import { cuerpo } from "../src/infra/esquemas.js";

const OBJETIVOS: readonly Objetivo[] = ["c5k", "c10k", "media_maraton", "maraton", "trail_montana", "triatlon_olimpico", "volver_sin_lesiones"];
const NIVELES: readonly Nivel[] = ["principiante", "intermedio", "avanzado"];
const DEPORTES: readonly DeportePerfil[] = ["running", "ciclismo", "trekking", "triatlon"];
const AGENDAS: readonly (readonly number[])[] = [[7], [2, 4], [1, 3, 6], [2, 4, 5, 7], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5, 6], [1, 2, 3, 4, 5, 6, 7]];
const INICIO = "2026-10-19";

function sumarDias(fecha: string, dias: number): string {
  const d = new Date(`${fecha}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + dias);
  return d.toISOString().slice(0, 10);
}

function entrada(o: Partial<EntradaDelMotor> = {}): EntradaDelMotor {
  return {
    objetivo: "c10k",
    nivel: "intermedio",
    deporte: "running",
    dias: [2, 4, 5, 7].map((weekday) => ({ weekday, minuteOfDay: 420 })),
    inicio: INICIO,
    fechaEvento: sumarDias(INICIO, 12 * 7),
    pesoG: 72_000,
    edad: 30,
    sexo: "masculino",
    ...o,
  };
}

/** Lo que el MVP deja planificar: running, y la fuerza del corredor. */
function soloRunning(plan: PlanGenerado, id: string): void {
  for (const d of plan.dias) {
    if (d.tipo === "descanso") continue;
    if (d.tipo === "fuerza") {
      assert.equal(d.deporte, "fuerza", `${id} ${d.fecha}`);
      continue;
    }
    assert.equal(d.deporte, "running", `${id} ${d.fecha}: ${d.tipo} en ${d.deporte}`);
    assert.ok(!d.motivos.includes("triatlon_rota_deportes"), `${id} ${d.fecha}`);
  }
}

// ─── 1. La puerta del motor ─────────────────────────────────────────────────────────────────

describe("MVP 100 % running: la puerta del motor", () => {
  test("la puerta está prendida", () => {
    assert.equal(MVP_SOLO_RUNNING, true);
  });

  test("ningún deporte de perfil ni objetivo produce bici, natación o trekking", () => {
    let casos = 0;
    for (const objetivo of OBJETIVOS) {
      for (const deporte of DEPORTES) {
        for (const nivel of NIVELES) {
          for (const agenda of AGENDAS) {
            for (const dias of [null, 10, 84, 140]) {
              const e = entrada({
                objetivo,
                deporte,
                nivel,
                dias: agenda.map((weekday) => ({ weekday, minuteOfDay: 360 })),
                fechaEvento: dias === null ? null : sumarDias(INICIO, dias),
              });
              const id = `${objetivo}/${deporte}/${nivel} [${agenda.join(",")}] evento ${e.fechaEvento}`;
              soloRunning(generarPlan(e), id);
              casos++;
            }
          }
        }
      }
    }
    assert.equal(casos, OBJETIVOS.length * DEPORTES.length * NIVELES.length * AGENDAS.length * 4);
  });

  test("con ciclismo o triatlón en el perfil, el plan es EL MISMO que con running", () => {
    for (const objetivo of OBJETIVOS) {
      const corriendo = JSON.stringify(generarPlan(entrada({ objetivo, deporte: "running" })));
      for (const deporte of ["ciclismo", "triatlon", "trekking"] as const) {
        assert.equal(JSON.stringify(generarPlan(entrada({ objetivo, deporte }))), corriendo, `${objetivo}/${deporte}`);
      }
    }
  });

  test("la fuerza se queda: con 4 días hay gimnasio, y es 'para corredores'", () => {
    const plan = generarPlan(entrada({ deporte: "ciclismo" }));
    const fuerza = plan.dias.filter((d) => d.tipo === "fuerza");
    assert.ok(fuerza.length > 0);
    assert.equal(textosDelDia(fuerza[0]!, "es-AR").titulo, "Fuerza para corredores (35 min)");
  });

  test("el triatlón olímpico se planifica como su tramo a pie: un 10K corriendo", () => {
    const plan = generarPlan(entrada({ objetivo: "triatlon_olimpico", deporte: "triatlon" }));
    const evento = plan.dias.at(-1);
    assert.equal(evento?.tipo, "carrera");
    assert.equal(evento?.deporte, "running");
    assert.equal(evento?.distanciaM, 10_000);
    assert.ok(evento?.motivos.includes("objetivo_c10k"));
    assert.deepEqual(plan, generarPlan(entrada({ objetivo: "c10k" })));
  });

  test("el 10K elegido es un 10K: el día del evento son 10 000 m a pie", () => {
    for (const deporte of DEPORTES) {
      const evento = generarPlan(entrada({ objetivo: "c10k", deporte })).dias.at(-1);
      assert.equal(evento?.tipo, "carrera", deporte);
      assert.equal(evento?.deporte, "running", deporte);
      assert.equal(evento?.distanciaM, 10_000, deporte);
      assert.equal(evento?.fecha, sumarDias(INICIO, 12 * 7), deporte);
    }
  });

  test("con la puerta apagada sigue el port literal multideporte (y por eso hacía falta)", () => {
    const multideporte = generarPlan(entrada({ deporte: "triatlon", dias: [1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, minuteOfDay: 360 })) }), { soloRunning: false });
    const deportes = new Set(multideporte.dias.map((d) => d.deporte));
    assert.ok(deportes.has("ciclismo") && deportes.has("natacion"));
    const ciclista = generarPlan(entrada({ deporte: "ciclismo" }), { soloRunning: false });
    assert.ok(ciclista.dias.some((d) => d.deporte === "ciclismo"));
  });

  test("un objetivo inválido sigue fallando con la puerta prendida", () => {
    assert.throws(() => generarPlan(entrada({ objetivo: "ultra" as Objetivo })), RangeError);
    assert.throws(() => generarPlan(entrada({ deporte: "remo" as DeportePerfil })), RangeError);
  });
});

// ─── 2. calcularPlan: el objetivo guardado ──────────────────────────────────────────────────

interface FilaPlan {
  id: string;
  usuario_id: string;
  objetivo_id: string | null;
  motor_version: string;
  entrada_hash: string;
  inicio_fecha: string;
  zona_horaria: string;
  creado_en_ms: number;
  reemplazado_en_ms: number | null;
}

const USUARIO = "00000000-0000-4000-8000-000000000001";
const ADICIONAL = "00000000-0000-4000-8000-0000000000aa";
const ZONA = "America/Argentina/Buenos_Aires";
const DIA_MS = 86_400_000;
/** 2026-10-19 12:00 en Buenos Aires. */
const AHORA = Date.UTC(2026, 9, 19, 15, 0, 0);

/** Una base en memoria que entiende las consultas de perfil, objetivos y planes. Nada más. */
function baseEnMemoria(perfil: Record<string, unknown>, adicionales: Array<{ id: string; objetivo: string; objetivo_fecha_ms: number | null }> = []) {
  const planes: FilaPlan[] = [];
  let siguiente = 1;
  const columnas = (p: FilaPlan) => ({
    id: p.id, motor_version: p.motor_version, entrada_hash: p.entrada_hash,
    inicio_fecha: p.inicio_fecha, zona_horaria: p.zona_horaria, creado_en_ms: p.creado_en_ms,
  });
  const vigente = (usuario: unknown, objetivo: unknown) =>
    planes.find((p) => p.usuario_id === usuario && p.objetivo_id === (objetivo ?? null) && p.reemplazado_en_ms === null);

  async function consultar<T extends Fila = Fila>(sql: string, v: readonly unknown[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();
    if (s.includes("left join perfiles p")) {
      return [{ usuario_id: USUARIO, email: "a@b.c", creado_en_ms: 0, actualizado_en_ms: 0, ...perfil } as T];
    }
    if (s.includes("from objetivos_usuario o") && s.includes("o.id = $2")) {
      return adicionales.filter((a) => a.id === v[1]) as T[];
    }
    if (s.startsWith("update planes set reemplazado_en_ms") && s.includes("entrada_hash <> $3")) {
      for (const p of planes) {
        if (p.usuario_id === v[0] && p.objetivo_id === (v[3] ?? null) && p.reemplazado_en_ms === null && p.entrada_hash !== v[2]) {
          p.reemplazado_en_ms = v[1] as number;
        }
      }
      return [];
    }
    if (s.startsWith("update planes set reemplazado_en_ms") && s.includes("where id = $1")) {
      for (const p of planes) if (p.id === v[0] && p.usuario_id === v[1] && p.reemplazado_en_ms === null) p.reemplazado_en_ms = v[2] as number;
      return [];
    }
    if (s.startsWith("insert into planes")) {
      if (vigente(v[0], v[6]) !== undefined) return []; // el índice único parcial
      const fila: FilaPlan = {
        id: `plan-${siguiente++}`, usuario_id: v[0] as string, motor_version: v[1] as string,
        entrada_hash: v[2] as string, inicio_fecha: v[3] as string, zona_horaria: v[4] as string,
        creado_en_ms: v[5] as number, objetivo_id: (v[6] as string | null) ?? null, reemplazado_en_ms: null,
      };
      planes.push(fila);
      return [columnas(fila) as T];
    }
    if (s.startsWith("select") && s.includes("from planes")) {
      const p = vigente(v[0], v[1]);
      return p === undefined ? [] : [columnas(p) as T];
    }
    throw new Error(`consulta no prevista en el test: ${s}`);
  }
  const db: Db = {
    consultar,
    async unaFila<T extends Fila = Fila>(sql: string, v?: readonly unknown[]) {
      return (await consultar<T>(sql, v))[0] ?? null;
    },
    async enTransaccion(fn) {
      return fn(db);
    },
    async vivo() {
      return true;
    },
    async cerrar() {},
  };
  return { db, planes, perfil };
}

function perfilGuardado(o: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    nombre: "Iván", apellido: null, nacimiento_ms: Date.UTC(1992, 5, 1), sexo_biologico: "masculino",
    peso_g: 74_500, altura_mm: 1_780, deporte: "running", nivel: "intermedio",
    objetivo: "c10k", objetivo_fecha_ms: Date.UTC(2027, 0, 10),
    dias_entrenamiento: [2, 4, 5, 7].map((weekday) => ({ weekday, minute_of_day: 1_140 })),
    zona_horaria: ZONA, sistema_unidades: "metrico", descargo_medico_aceptado_en_ms: 0,
    equipamiento: null, embarazo_o_lactancia: null,
    ...o,
  };
}

function contexto(db: Db, ahora: () => number = () => AHORA): Contexto {
  return { db, ahoraMs: ahora } as unknown as Contexto;
}

describe("calcularPlan planifica el objetivo GUARDADO", () => {
  test("el 10K guardado en el perfil es el objetivo del plan, y termina en 10 km a pie", async () => {
    const { db } = baseEnMemoria(perfilGuardado({ objetivo: "c10k", deporte: "ciclismo" }));
    const c = await calcularPlan(contexto(db), USUARIO);
    assert.equal(c.entrada.objetivo, "c10k");
    assert.equal(c.plan.fechaEvento, "2027-01-10");
    const evento = c.plan.dias.at(-1);
    assert.equal(evento?.tipo, "carrera");
    assert.equal(evento?.distanciaM, 10_000);
    soloRunning(c.plan, "perfil ciclismo");
  });

  test("cambiar el objetivo guardado cambia el plan y arranca un bloque nuevo", async () => {
    const base = baseEnMemoria(perfilGuardado({ objetivo: "media_maraton" }));
    const antes = await calcularPlan(contexto(base.db), USUARIO);
    assert.equal(antes.entrada.objetivo, "media_maraton");
    base.perfil["objetivo"] = "c10k";
    const despues = await calcularPlan(contexto(base.db, () => AHORA + 3 * DIA_MS), USUARIO);
    assert.equal(despues.entrada.objetivo, "c10k");
    assert.notEqual(despues.ancla.id, antes.ancla.id);
    assert.equal(despues.ancla.inicio_fecha, "2026-10-22");
    assert.equal(base.planes.filter((p) => p.reemplazado_en_ms === null).length, 1);
  });

  test("un objetivo adicional se planifica con SU objetivo, no con el del perfil", async () => {
    const { db } = baseEnMemoria(perfilGuardado({ objetivo: "maraton" }), [
      { id: ADICIONAL, objetivo: "c10k", objetivo_fecha_ms: null },
    ]);
    const c = await calcularPlan(contexto(db), USUARIO, ADICIONAL);
    assert.equal(c.entrada.objetivo, "c10k");
    assert.equal(c.plan.fechaEvento, null);
  });

  test("el mismo objetivo sin fecha, con el bloque terminado, arranca de nuevo hoy", async () => {
    // Antes: volver a elegir el mismo objetivo daba el mismo hash, el ancla vieja seguía vigente y
    // el plan entero quedaba en el pasado ("tu plan terminó", una y otra vez).
    const base = baseEnMemoria(perfilGuardado({ objetivo: "c10k", objetivo_fecha_ms: null }));
    const primero = await calcularPlan(contexto(base.db), USUARIO);
    assert.equal(primero.ancla.inicio_fecha, "2026-10-19");
    const ultimoDia = primero.plan.dias.at(-1)!.fecha;

    const mismoBloque = await calcularPlan(contexto(base.db, () => AHORA + 20 * DIA_MS), USUARIO);
    assert.equal(mismoBloque.ancla.id, primero.ancla.id, "mientras dura, el bloque no se mueve");

    const despues = await calcularPlan(contexto(base.db, () => AHORA + 70 * DIA_MS), USUARIO);
    assert.notEqual(despues.ancla.id, primero.ancla.id);
    assert.equal(despues.ancla.inicio_fecha, "2026-12-28");
    assert.ok(despues.plan.dias.at(-1)!.fecha > ultimoDia);
    assert.equal(despues.entrada.objetivo, "c10k");
    assert.equal(base.planes.filter((p) => p.reemplazado_en_ms === null).length, 1);
  });

  test("con la carrera ya corrida, el bloque terminado se conserva", async () => {
    const base = baseEnMemoria(perfilGuardado({ objetivo: "c10k", objetivo_fecha_ms: Date.UTC(2026, 10, 15) }));
    const primero = await calcularPlan(contexto(base.db), USUARIO);
    assert.equal(primero.plan.fechaEvento, "2026-11-15");
    const despues = await calcularPlan(contexto(base.db, () => AHORA + 40 * DIA_MS), USUARIO);
    assert.equal(despues.ancla.id, primero.ancla.id);
    assert.equal(despues.plan.dias.at(-1)?.tipo, "carrera");
  });
});

// ─── 3. El contrato: "sin fecha" puede venir sin la clave ───────────────────────────────────

describe("PUT /me/goals: goal_date_ms ausente es 'sin fecha' (contrato 1.2.1)", () => {
  test("el esquema del cuerpo acepta un objetivo sin goal_date_ms, como lo manda la app de iPhone", async () => {
    // Mismas opciones de Ajv que servidor.ts; la ruta de verdad pide sesión, así que acá sólo se
    // prueba la validación que sale del contrato.
    const app = Fastify({ ajv: { customOptions: { removeAdditional: false, allErrors: false, strict: false } } });
    app.put("/goals", { schema: { body: cuerpo("replaceGoals") } }, async (req) => req.body);
    await app.ready();
    try {
      const sinClave = await app.inject({ method: "PUT", url: "/goals", payload: { goals: [{ id: "principal", goal: "c10k" }, { id: "", goal: "c5k" }] } });
      assert.equal(sinClave.statusCode, 200, sinClave.body);
      const conNull = await app.inject({ method: "PUT", url: "/goals", payload: { goals: [{ id: "principal", goal: "c10k", goal_date_ms: null }] } });
      assert.equal(conNull.statusCode, 200, conNull.body);
      const sinObjetivo = await app.inject({ method: "PUT", url: "/goals", payload: { goals: [{ id: "principal", goal_date_ms: null }] } });
      assert.equal(sinObjetivo.statusCode, 400);
      const desconocido = await app.inject({ method: "PUT", url: "/goals", payload: { goals: [{ goal: "10k" }] } });
      assert.equal(desconocido.statusCode, 400);
    } finally {
      await app.close();
    }
  });
});
