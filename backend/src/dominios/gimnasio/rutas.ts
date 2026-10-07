/**
 * dominios/gimnasio — las sesiones de gimnasio y sus series.
 *
 *   GET  /v1/gym/sessions                        historial, paginado
 *   GET  /v1/gym/sessions/{session_id}           una sesión con sus series
 *   POST /v1/gym/sessions/{session_id}/sets      sincronizar un lote (decisión 0006)
 *
 * El POST no es "crear": es "esto es lo que tengo". El servidor lo fusiona con lo
 * que ya tenía y devuelve la sesión entera, con la hora de llegada puesta, para que
 * el dispositivo la fusione a su vez con lo suyo. Mandar dos veces lo mismo es
 * inocuo por construcción, y además va envuelto en `conIdempotencia` (§5.2).
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";
import { crearRepoGimnasio, filaASerie, type ResumenFila, type SesionFila } from "./repositorio.js";
import { sincronizarSeries } from "./servicio.js";
import type { Dispositivo, Serie } from "./fusion.js";
import { cuerpo, parametros } from "../../infra/esquemas.js";
import { ErrorApi } from "../../infra/errores.js";
import { crearIdempotencia, conIdempotencia } from "../../infra/idempotencia.js";
import { decodificarCursor, limiteDe, pagina } from "../../infra/paginacion.js";
import { inicioDelDiaMs } from "../../infra/fechas.js";
import { crearRepoPerfil } from "../perfil/repositorio.js";

interface SerieEntrada {
  exercise_id: string;
  number: number;
  done: boolean;
  reps: number;
  weight_g?: number;
  skipped: boolean;
  is_extra: boolean;
  recorded_at_ms: number;
  device: Dispositivo;
}

export function serieAApi(s: Serie) {
  const salida: Record<string, unknown> = {
    exercise_id: s.ejercicioId,
    number: s.numero,
    done: s.hecha,
    reps: s.repeticiones,
    skipped: s.salteada,
    is_extra: s.esExtra,
    recorded_at_ms: s.registradaLocalMs,
    received_at_ms: s.recibidaEnServidorMs,
    device: s.dispositivo,
  };
  // Un campo que no está se omite (docs/API.md §7): sin peso es peso corporal.
  if (s.pesoG !== null) salida["weight_g"] = s.pesoG;
  return salida;
}

/** `date_ms` sólo si el id dice la fecha y el perfil dice la zona: nada inventado. */
function conFecha(salida: Record<string, unknown>, fila: SesionFila, zona: string | null) {
  if (fila.fecha !== null && zona !== null) salida["date_ms"] = inicioDelDiaMs(fila.fecha, zona);
  return salida;
}

export async function rutasGimnasio(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const repo = crearRepoGimnasio(ctx.db);
  const perfiles = crearRepoPerfil(ctx.db);
  const idem = crearIdempotencia(ctx.db, ctx.ahoraMs);

  async function zonaDe(usuarioId: string): Promise<string | null> {
    return (await perfiles.leer(usuarioId))?.zona_horaria ?? null;
  }

  app.get("/gym/sessions", { preHandler: guardia, schema: parametros("listGymSessions") }, async (req) => {
    const usuarioId = usuarioDe(req);
    const q = req.query as { cursor?: string; limit?: number };
    const limite = limiteDe(q.limit);
    const cursor = decodificarCursor(q.cursor, ["number", "string"]);
    const despues = cursor === null ? null : { creadaEnMs: Number(cursor[0]), sesionId: String(cursor[1]) };
    const [filas, zona] = await Promise.all([repo.listar(usuarioId, despues, limite), zonaDe(usuarioId)]);
    return pagina(
      filas,
      limite,
      (f: ResumenFila) => [f.creada_en_ms, f.sesion_id],
      (f: ResumenFila) =>
        conFecha(
          {
            session_id: f.sesion_id,
            updated_at_ms: f.actualizada_en_ms,
            sets_done: f.series_hechas,
            exercises: f.ejercicios,
          },
          f,
          zona
        )
    );
  });

  app.get("/gym/sessions/:session_id", { preHandler: guardia, schema: parametros("getGymSession") }, async (req) => {
    const usuarioId = usuarioDe(req);
    const { session_id } = req.params as { session_id: string };
    const sesion = await repo.sesion(usuarioId, session_id);
    // 404 para lo que no existe Y para lo ajeno, que acá son el mismo caso: la
    // consulta filtra por dueño (docs/API.md §2).
    if (sesion === null) throw new ErrorApi("not_found", "Gym session not found");
    const [series, zona] = await Promise.all([repo.series(usuarioId, session_id), zonaDe(usuarioId)]);
    return {
      data: conFecha(
        { session_id: sesion.sesion_id, updated_at_ms: sesion.actualizada_en_ms, sets: series.map(filaASerie).map(serieAApi) },
        sesion,
        zona
      ),
    };
  });

  app.post(
    "/gym/sessions/:session_id/sets",
    {
      preHandler: guardia,
      schema: { ...parametros("syncGymSets"), body: cuerpo("syncGymSets") },
      // Un lote por serie marcada, de dos dispositivos, es tráfico normal en una
      // sesión de gimnasio: el límite general de 60/min se quedaría corto.
      config: { rateLimit: { max: 120, timeWindow: "1 minute" } },
    },
    conIdempotencia(idem, async (req) => {
      const usuarioId = usuarioDe(req);
      const { session_id } = req.params as { session_id: string };
      const { sets } = req.body as { sets: SerieEntrada[] };
      const ahora = ctx.ahoraMs();

      const entrantes: Serie[] = sets.map((e) => ({
        ejercicioId: e.exercise_id,
        numero: e.number,
        hecha: e.done,
        repeticiones: e.reps,
        pesoG: e.weight_g ?? null,
        salteada: e.skipped,
        esExtra: e.is_extra,
        registradaLocalMs: e.recorded_at_ms,
        // 🛑 La hora de llegada la pone el SERVIDOR, siempre. La del cliente no
        // ordena nada entre dos dispositivos que estuvieron sin red (0006, regla 3).
        recibidaEnServidorMs: ahora,
        dispositivo: e.device,
      }));

      const { sesion, series } = await sincronizarSeries(ctx.db, usuarioId, session_id, entrantes, ahora);
      const zona = await zonaDe(usuarioId);
      return {
        data: conFecha(
          { session_id: sesion.sesion_id, updated_at_ms: sesion.actualizada_en_ms, sets: series.map(serieAApi) },
          sesion,
          zona
        ),
      };
    })
  );
}
