/**
 * dominios/actividades — lo que se entrenó afuera del gimnasio.
 *
 *   GET    /v1/activities                  historial, paginado
 *   PUT    /v1/activities/{activity_id}    guardar (idempotente por id del cliente)
 *   DELETE /v1/activities/{activity_id}    borrar (soft, idempotente)
 *
 * El id lo genera el cliente porque la actividad nace sin señal: con un PUT al
 * mismo id, reintentar no puede crear dos (AGENTS.md §5.2).
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";
import { crearRepoActividades, type ActividadFila, type PuntoDeRecorrido } from "./repositorio.js";
import { cuerpo, parametros } from "../../infra/esquemas.js";
import { ErrorApi } from "../../infra/errores.js";
import { decodificarCursor, limiteDe, pagina } from "../../infra/paginacion.js";

interface ActividadEntrada {
  sport: string;
  started_at_ms: number;
  duration_s: number;
  distance_m?: number;
  elevation_gain_m?: number;
  avg_hr_bpm?: number;
  max_hr_bpm?: number;
  kcal?: number;
  device: string;
}

export function actividadAApi(f: ActividadFila) {
  const salida: Record<string, unknown> = {
    id: f.id,
    sport: f.deporte,
    started_at_ms: f.inicio_ms,
    duration_s: f.duracion_s,
    device: f.dispositivo,
    created_at_ms: f.creada_en_ms,
    updated_at_ms: f.actualizada_en_ms,
  };
  const opcionales: ReadonlyArray<readonly [string, number | null]> = [
    ["distance_m", f.distancia_m],
    ["elevation_gain_m", f.desnivel_m],
    ["avg_hr_bpm", f.fc_media_lpm],
    ["max_hr_bpm", f.fc_max_lpm],
    ["kcal", f.kcal],
  ];
  for (const [k, v] of opcionales) if (v !== null) salida[k] = v;
  return salida;
}

export async function rutasActividades(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const repo = crearRepoActividades(ctx.db);

  const parametrosRecorrido = {
    type: "object", required: ["activity_id"], additionalProperties: false,
    properties: { activity_id: { type: "string", pattern: "^[A-Za-z0-9-]{8,64}$" } },
  } as const;
  const esquemaPuntos = {
    type: "array", minItems: 1, maxItems: 10000,
    items: {
      type: "object", required: ["lat", "lon", "at_ms"], additionalProperties: false,
      properties: {
        lat: { type: "number", minimum: -90, maximum: 90 },
        lon: { type: "number", minimum: -180, maximum: 180 },
        at_ms: { type: "integer", minimum: 0 },
      },
    },
  } as const;

  app.get("/activities", { preHandler: guardia, schema: parametros("listActivities") }, async (req) => {
    const usuarioId = usuarioDe(req);
    const q = req.query as { cursor?: string; limit?: number };
    const limite = limiteDe(q.limit);
    const cursor = decodificarCursor(q.cursor, ["number", "string"]);
    const despues = cursor === null ? null : { inicioMs: Number(cursor[0]), id: String(cursor[1]) };
    const filas = await repo.listar(usuarioId, despues, limite);
    return pagina(filas, limite, (f) => [f.inicio_ms, f.id], actividadAApi);
  });

  app.put(
    "/activities/:activity_id",
    { preHandler: guardia, schema: { ...parametros("putActivity"), body: cuerpo("putActivity") } },
    async (req) => {
      const usuarioId = usuarioDe(req);
      const { activity_id } = req.params as { activity_id: string };
      const b = req.body as ActividadEntrada;
      if (b.avg_hr_bpm !== undefined && b.max_hr_bpm !== undefined && b.avg_hr_bpm > b.max_hr_bpm) {
        throw new ErrorApi("bad_request", "Average heart rate is above the maximum");
      }
      const fila = await repo.guardar(
        usuarioId,
        activity_id,
        {
          deporte: b.sport,
          inicioMs: b.started_at_ms,
          duracionS: b.duration_s,
          distanciaM: b.distance_m ?? null,
          desnivelM: b.elevation_gain_m ?? null,
          fcMediaLpm: b.avg_hr_bpm ?? null,
          fcMaxLpm: b.max_hr_bpm ?? null,
          kcal: b.kcal ?? null,
          dispositivo: b.device,
        },
        ctx.ahoraMs()
      );
      if (fila === null) throw new ErrorApi("not_found", "Activity was deleted");
      return { data: actividadAApi(fila) };
    }
  );

  app.delete("/activities/:activity_id", { preHandler: guardia, schema: parametros("deleteActivity") }, async (req, res) => {
    const usuarioId = usuarioDe(req);
    const { activity_id } = req.params as { activity_id: string };
    await repo.borrar(usuarioId, activity_id, ctx.ahoraMs());
    res.code(204);
    return null;
  });

  app.put("/activities/:activity_id/route", {
    preHandler: guardia,
    schema: { params: parametrosRecorrido, body: { type: "object", required: ["points"], additionalProperties: false,
      properties: { points: esquemaPuntos } } },
  }, async (req) => {
    const usuarioId = usuarioDe(req);
    const { activity_id } = req.params as { activity_id: string };
    const { points } = req.body as { points: PuntoDeRecorrido[] };
    if (points.some((p, i) => i > 0 && p.at_ms <= points[i - 1]!.at_ms)) {
      throw new ErrorApi("bad_request", "Route points must be ordered");
    }
    if (!await repo.guardarRecorrido(usuarioId, activity_id, points, ctx.ahoraMs())) {
      throw new ErrorApi("not_found", "Activity not found");
    }
    return { data: { points } };
  });

  app.get("/activities/:activity_id/route", { preHandler: guardia, schema: { params: parametrosRecorrido } }, async (req) => {
    const usuarioId = usuarioDe(req);
    const { activity_id } = req.params as { activity_id: string };
    const points = await repo.recorrido(usuarioId, activity_id);
    if (points === null) throw new ErrorApi("not_found", "Route not found");
    return { data: { points } };
  });
}
