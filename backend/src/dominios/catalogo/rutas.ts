/**
 * dominios/catalogo — GET /v1/exercises y GET /v1/exercises/dictionary
 *
 * El catálogo lo sirve el servidor para que agregar el ejercicio 200 sea una fila
 * en una tabla y no una versión nueva en la tienda (AGENTS.md §9.1). Las apps traen
 * una copia de la semilla para abrir sin señal, pero lo que manda es esto.
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearGuardia } from "../auth/guardia.js";
import { crearRepoCatalogo, type EjercicioFila } from "./repositorio.js";
import { parametros } from "../../infra/esquemas.js";
import { decodificarCursor, limiteDe, pagina } from "../../infra/paginacion.js";
import { localeDe, nombreEn, type Locale } from "../../infra/idioma.js";

/**
 * Los tipos de sustituto viajan en snake_case: la semilla los escribe con guion
 * (`mismo-patron`) y un guion no es un nombre de caso válido en Swift ni en Kotlin.
 */
function tipoDeSustituto(tipo: string): string {
  return tipo.replace(/-/g, "_");
}

export function ejercicioAApi(f: EjercicioFila, locale: Locale) {
  return {
    id: f.id,
    name: nombreEn(f.nombres, locale, f.id),
    pattern: f.patron,
    equipment: f.equipamiento,
    side: f.lado,
    unit: f.unidad,
    muscles: f.musculos.map((m) => ({ id: m.id, role: m.rol })),
    substitutes: f.sustitutos.map((s) => ({ id: s.id, kind: tipoDeSustituto(s.tipo) })),
    joints: f.articulaciones,
  };
}

export async function rutasCatalogo(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const repo = crearRepoCatalogo(ctx.db);

  app.get("/exercises", { preHandler: guardia, schema: parametros("listExercises") }, async (req) => {
    const q = req.query as { cursor?: string; limit?: number };
    const limite = limiteDe(q.limit);
    const cursor = decodificarCursor(q.cursor, ["string"]);
    const filas = await repo.pagina(cursor === null ? null : String(cursor[0]), limite);
    const locale = localeDe(req);
    return pagina(filas, limite, (f) => [f.id], (f) => ejercicioAApi(f, locale));
  });

  app.get("/exercises/dictionary", { preHandler: guardia }, async (req) => {
    const locale = localeDe(req);
    const grupos: Record<"patron" | "equipamiento" | "musculo" | "articulacion", Array<{ id: string; name: string }>> = {
      patron: [],
      equipamiento: [],
      musculo: [],
      articulacion: [],
    };
    for (const e of await repo.diccionario()) {
      grupos[e.tipo].push({ id: e.id, name: nombreEn(e.nombres, locale, e.id) });
    }
    return {
      data: {
        patterns: grupos.patron,
        equipment: grupos.equipamiento,
        muscles: grupos.musculo,
        joints: grupos.articulacion,
      },
    };
  });
}
