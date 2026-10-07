/**
 * dominios/actividades/repositorio.ts — lo que se entrenó afuera del gimnasio.
 *
 * 🛑 AGENTS.md §12: toda consulta filtra por `usuario_id` en el mismo SQL, y toda
 * lectura por `borrada_en_ms is null` (§11, soft-delete).
 * §8: el pulso de una salida es un dato de salud. No sale en un error ni en un log.
 */
import type { Db } from "../../infra/db.js";

export interface ActividadFila {
  id: string;
  deporte: string;
  inicio_ms: number;
  duracion_s: number;
  distancia_m: number | null;
  desnivel_m: number | null;
  fc_media_lpm: number | null;
  fc_max_lpm: number | null;
  kcal: number | null;
  dispositivo: string;
  creada_en_ms: number;
  actualizada_en_ms: number;
}

export interface ActividadNueva {
  deporte: string;
  inicioMs: number;
  duracionS: number;
  distanciaM: number | null;
  desnivelM: number | null;
  fcMediaLpm: number | null;
  fcMaxLpm: number | null;
  kcal: number | null;
  dispositivo: string;
}

export interface PuntoDeRecorrido {
  lat: number;
  lon: number;
  at_ms: number;
}

const COLUMNAS =
  "id, deporte, inicio_ms, duracion_s, distancia_m, desnivel_m, fc_media_lpm, fc_max_lpm, kcal, dispositivo, creada_en_ms, actualizada_en_ms";

export function crearRepoActividades(db: Db) {
  return {
    /**
     * PUT idempotente por id. Devuelve `null` si ese id ya existió y se BORRÓ.
     *
     * 🛑 Un PUT viejo que llega tarde —el teléfono estuvo sin señal y la persona ya
     * borró esa actividad desde el reloj— no puede resucitarla. Borrar gana.
     */
    async guardar(usuarioId: string, id: string, a: ActividadNueva, ahoraMs: number): Promise<ActividadFila | null> {
      return db.unaFila<ActividadFila>(
        `insert into actividades
           (usuario_id, id, deporte, inicio_ms, duracion_s, distancia_m, desnivel_m, fc_media_lpm, fc_max_lpm,
            kcal, dispositivo, creada_en_ms, actualizada_en_ms)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $12)
         on conflict (usuario_id, id) do update set
           deporte = excluded.deporte, inicio_ms = excluded.inicio_ms, duracion_s = excluded.duracion_s,
           distancia_m = excluded.distancia_m, desnivel_m = excluded.desnivel_m,
           fc_media_lpm = excluded.fc_media_lpm, fc_max_lpm = excluded.fc_max_lpm, kcal = excluded.kcal,
           dispositivo = excluded.dispositivo, actualizada_en_ms = excluded.actualizada_en_ms
          where actividades.borrada_en_ms is null
         returning ${COLUMNAS}`,
        [
          usuarioId,
          id,
          a.deporte,
          a.inicioMs,
          a.duracionS,
          a.distanciaM,
          a.desnivelM,
          a.fcMediaLpm,
          a.fcMaxLpm,
          a.kcal,
          a.dispositivo,
          ahoraMs,
        ]
      );
    },

    async listar(usuarioId: string, despues: { inicioMs: number; id: string } | null, limite: number): Promise<ActividadFila[]> {
      return db.consultar<ActividadFila>(
        `select ${COLUMNAS}
           from actividades
          where usuario_id = $1 and borrada_en_ms is null
            and ($2::bigint is null or (inicio_ms, id) < ($2::bigint, $3::text))
          order by inicio_ms desc, id desc
          limit $4`,
        [usuarioId, despues?.inicioMs ?? null, despues?.id ?? null, limite + 1]
      );
    },

    /** Idempotente: borrar lo ya borrado, o lo que no existe, no es un error. */
    async borrar(usuarioId: string, id: string, ahoraMs: number): Promise<void> {
      await db.consultar(
        `update actividades set borrada_en_ms = $3
          where usuario_id = $1 and id = $2 and borrada_en_ms is null`,
        [usuarioId, id, ahoraMs]
      );
    },

    async guardarRecorrido(usuarioId: string, id: string, puntos: PuntoDeRecorrido[], ahoraMs: number): Promise<boolean> {
      const filas = await db.consultar(
        `insert into recorridos_actividades (usuario_id, actividad_id, puntos, actualizada_en_ms)
         select usuario_id, id, $3::jsonb, $4 from actividades
          where usuario_id = $1 and id = $2 and borrada_en_ms is null
         on conflict (usuario_id, actividad_id) do update set
           puntos = excluded.puntos, actualizada_en_ms = excluded.actualizada_en_ms
         returning actividad_id`,
        [usuarioId, id, JSON.stringify(puntos), ahoraMs]
      );
      return filas.length > 0;
    },

    async recorrido(usuarioId: string, id: string): Promise<PuntoDeRecorrido[] | null> {
      const fila = await db.unaFila<{ puntos: PuntoDeRecorrido[] }>(
        `select r.puntos from recorridos_actividades r
         join actividades a on a.usuario_id = r.usuario_id and a.id = r.actividad_id
         where r.usuario_id = $1 and r.actividad_id = $2 and a.borrada_en_ms is null`,
        [usuarioId, id]
      );
      return fila?.puntos ?? null;
    },

    /** Actividades que empiezan en [desdeMs, hastaMs). Para el plan y la nutrición del día. */
    async enRango(usuarioId: string, desdeMs: number, hastaMs: number): Promise<ActividadFila[]> {
      return db.consultar<ActividadFila>(
        `select ${COLUMNAS}
           from actividades
          where usuario_id = $1 and borrada_en_ms is null and inicio_ms >= $2 and inicio_ms < $3
          order by inicio_ms`,
        [usuarioId, desdeMs, hastaMs]
      );
    },
  };
}

export type RepoActividades = ReturnType<typeof crearRepoActividades>;
