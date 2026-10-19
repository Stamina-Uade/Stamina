import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { ErrorApi } from "../../infra/errores.js";
import { cuerpo } from "../../infra/esquemas.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";
import { crearRepoObjetivos, type ObjetivoActivo } from "./repositorio.js";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function rutasObjetivos(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const repo = crearRepoObjetivos(ctx.db);
  const guardia = crearGuardia(ctx);
  app.get("/me/goals", { preHandler: guardia }, async (req) => ({
    data: await repo.listar(usuarioDe(req)),
  }));
  app.put("/me/goals", { preHandler: guardia, schema: { body: cuerpo("replaceGoals") } }, async (req) => {
    // `goal_date_ms` ausente es "sin fecha", igual que `null`: hasta la 1.2.0 el contrato lo exigía
    // y la app de iPhone lo omitía cuando no había fecha (Codable no escribe los nil), así que
    // cada "sin fecha" —y cada objetivo adicional del alta— volvía con un 400 y no se guardaba.
    const crudos = (req.body as { goals: Array<Omit<ObjetivoActivo, "goal_date_ms"> & { goal_date_ms?: number | null }> }).goals;
    const goals: ObjetivoActivo[] = crudos.map((g) => ({ ...g, goal_date_ms: g.goal_date_ms ?? null }));
    const ids = new Set<string>();
    for (const [i, goal] of goals.entries()) {
      const id = goal.id ?? "";
      if ((i === 0 && id !== "" && id !== "principal") ||
          (i > 0 && id !== "" && !UUID.test(id)) ||
          (id !== "" && ids.has(id))) {
        throw new ErrorApi("bad_request", "Invalid goal identifier");
      }
      if (id !== "") ids.add(id);
    }
    return { data: await repo.reemplazar(usuarioDe(req), goals, ctx.ahoraMs()) };
  });
}
