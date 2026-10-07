/**
 * dominios/gimnasio/repositorio.ts — el SQL de sesiones y series.
 *
 * 🛑 AGENTS.md §12 (IDOR): toda consulta lleva `usuario_id` y ese id sale del
 * token. El `session_id` de la ruta es un nombre DENTRO del espacio de la persona:
 * dos personas pueden tener "gym-2026-09-10" y son dos filas distintas.
 *
 * Este archivo no decide quién gana una fusión: eso es fusion.ts. Acá sólo se lee
 * y se escribe lo que ya está decidido.
 */
import type { Db } from "../../infra/db.js";
import type { Dispositivo, Serie } from "./fusion.js";

export interface SerieFila {
  ejercicio_id: string;
  numero: number;
  hecha: boolean;
  repeticiones: number;
  peso_g: number | null;
  salteada: boolean;
  es_extra: boolean;
  registrada_local_ms: number;
  recibida_en_servidor_ms: number;
  dispositivo: Dispositivo;
}

export interface SesionFila {
  sesion_id: string;
  fecha: string | null;
  creada_en_ms: number;
  actualizada_en_ms: number;
}

export interface ResumenFila extends SesionFila {
  series_hechas: number;
  ejercicios: number;
}

const COLUMNAS_SERIE =
  "ejercicio_id, numero, hecha, repeticiones, peso_g, salteada, es_extra, registrada_local_ms, recibida_en_servidor_ms, dispositivo";

export function filaASerie(f: SerieFila): Serie {
  return {
    ejercicioId: f.ejercicio_id,
    numero: f.numero,
    hecha: f.hecha,
    repeticiones: f.repeticiones,
    pesoG: f.peso_g,
    salteada: f.salteada,
    esExtra: f.es_extra,
    registradaLocalMs: f.registrada_local_ms,
    recibidaEnServidorMs: f.recibida_en_servidor_ms,
    dispositivo: f.dispositivo,
  };
}

/** Las columnas de un lote, en el orden en que las espera `unnest`. */
function columnas(series: readonly Serie[]) {
  return [
    series.map((s) => s.ejercicioId),
    series.map((s) => s.numero),
    series.map((s) => s.hecha),
    series.map((s) => s.repeticiones),
    series.map((s) => s.pesoG),
    series.map((s) => s.salteada),
    series.map((s) => s.esExtra),
    series.map((s) => s.registradaLocalMs),
    series.map((s) => s.recibidaEnServidorMs),
    series.map((s) => s.dispositivo),
  ];
}

const UNNEST = `unnest($3::text[], $4::int[], $5::bool[], $6::int[], $7::int[], $8::bool[], $9::bool[],
                      $10::bigint[], $11::bigint[], $12::text[])
                as t(ejercicio_id, numero, hecha, repeticiones, peso_g, salteada, es_extra,
                     registrada_local_ms, recibida_en_servidor_ms, dispositivo)`;

export function crearRepoGimnasio(db: Db) {
  return {
    /**
     * Crea la sesión si no existe y BLOQUEA su fila hasta el final de la
     * transacción (el `on conflict do update` toma el lock).
     *
     * 🛑 Es lo que hace segura la fusión: sin este lock, dos sincronizaciones de la
     * misma sesión que llegan a la vez leerían el mismo estado, fusionarían cada una
     * por su lado y la segunda pisaría a la primera sin fusionar — podría hasta
     * desmarcar una serie, que es lo único que la regla 2 prohíbe.
     */
    async tomarSesion(usuarioId: string, sesionId: string, fecha: string | null, ahoraMs: number): Promise<SesionFila> {
      const f = await db.unaFila<SesionFila>(
        `insert into sesiones_gimnasio (usuario_id, sesion_id, fecha, creada_en_ms, actualizada_en_ms)
              values ($1, $2, $3, $4, $4)
         on conflict (usuario_id, sesion_id) do update set actualizada_en_ms = excluded.actualizada_en_ms
         returning sesion_id, fecha, creada_en_ms, actualizada_en_ms`,
        [usuarioId, sesionId, fecha, ahoraMs]
      );
      if (f === null) throw new Error("tomarSesion: upsert sin filas");
      return f;
    },

    async sesion(usuarioId: string, sesionId: string): Promise<SesionFila | null> {
      return db.unaFila<SesionFila>(
        `select sesion_id, fecha, creada_en_ms, actualizada_en_ms
           from sesiones_gimnasio
          where usuario_id = $1 and sesion_id = $2`,
        [usuarioId, sesionId]
      );
    },

    async series(usuarioId: string, sesionId: string): Promise<SerieFila[]> {
      return db.consultar<SerieFila>(
        `select ${COLUMNAS_SERIE}
           from series_gimnasio
          where usuario_id = $1 and sesion_id = $2
          order by ejercicio_id, numero`,
        [usuarioId, sesionId]
      );
    },

    /** Escribe el resultado YA FUSIONADO de un lote. Un solo viaje a la base. */
    async guardar(usuarioId: string, sesionId: string, series: readonly Serie[]): Promise<void> {
      if (series.length === 0) return;
      await db.consultar(
        `insert into series_gimnasio (usuario_id, sesion_id, ${COLUMNAS_SERIE})
         select $1, $2, t.* from ${UNNEST}
         on conflict (usuario_id, sesion_id, ejercicio_id, numero) do update set
           hecha = excluded.hecha, repeticiones = excluded.repeticiones, peso_g = excluded.peso_g,
           salteada = excluded.salteada, es_extra = excluded.es_extra,
           registrada_local_ms = excluded.registrada_local_ms,
           recibida_en_servidor_ms = excluded.recibida_en_servidor_ms,
           dispositivo = excluded.dispositivo`,
        [usuarioId, sesionId, ...columnas(series)]
      );
    },

    /** Append-only: todo lo que llegó, tal como llegó (decisión 0006 §2). */
    async agregarAlHistorial(usuarioId: string, sesionId: string, series: readonly Serie[]): Promise<void> {
      if (series.length === 0) return;
      await db.consultar(
        `insert into series_gimnasio_historial (usuario_id, sesion_id, ${COLUMNAS_SERIE})
         select $1, $2, t.* from ${UNNEST}`,
        [usuarioId, sesionId, ...columnas(series)]
      );
    },

    /**
     * Keyset por (creada, id) descendente: una sesión que se sigue editando no
     * cambia de lugar mientras alguien pagina.
     */
    async listar(
      usuarioId: string,
      despues: { creadaEnMs: number; sesionId: string } | null,
      limite: number
    ): Promise<ResumenFila[]> {
      return db.consultar<ResumenFila>(
        `select s.sesion_id, s.fecha, s.creada_en_ms, s.actualizada_en_ms,
                count(se.ejercicio_id) filter (where se.hecha and not se.salteada)::int as series_hechas,
                count(distinct se.ejercicio_id)::int as ejercicios
           from sesiones_gimnasio s
           left join series_gimnasio se
             on se.usuario_id = s.usuario_id and se.sesion_id = s.sesion_id
          where s.usuario_id = $1
            and ($2::bigint is null or (s.creada_en_ms, s.sesion_id) < ($2::bigint, $3::text))
          group by s.usuario_id, s.sesion_id
          order by s.creada_en_ms desc, s.sesion_id desc
          limit $4`,
        [usuarioId, despues?.creadaEnMs ?? null, despues?.sesionId ?? null, limite + 1]
      );
    },

    /**
     * La columna PREVIA de la rutina: para cada ejercicio, las series de la última
     * sesión —distinta de la de hoy— en la que la persona hizo al menos una.
     */
    async ultimasSeriesPorEjercicio(
      usuarioId: string,
      ejercicioIds: readonly string[],
      excluirSesionId: string
    ): Promise<SerieFila[]> {
      if (ejercicioIds.length === 0) return [];
      return db.consultar<SerieFila>(
        `with ultima as (
           select distinct on (ejercicio_id) ejercicio_id, sesion_id
             from series_gimnasio
            where usuario_id = $1 and ejercicio_id = any($2::text[]) and sesion_id <> $3 and hecha
            order by ejercicio_id, recibida_en_servidor_ms desc
         )
         select ${COLUMNAS_SERIE.split(", ").map((c) => `s.${c}`).join(", ")}
           from series_gimnasio s
           join ultima u on u.ejercicio_id = s.ejercicio_id and u.sesion_id = s.sesion_id
          where s.usuario_id = $1
          order by s.ejercicio_id, s.numero`,
        [usuarioId, ejercicioIds, excluirSesionId]
      );
    },

    /** Las fechas (YYYY-MM-DD) con alguna serie hecha. Para marcar días hechos en el plan. */
    async fechasConSeries(usuarioId: string, desde: string, hasta: string): Promise<string[]> {
      const filas = await db.consultar<{ fecha: string }>(
        `select distinct s.fecha
           from sesiones_gimnasio s
           join series_gimnasio se on se.usuario_id = s.usuario_id and se.sesion_id = s.sesion_id
          where s.usuario_id = $1 and s.fecha between $2 and $3 and se.hecha and not se.salteada`,
        [usuarioId, desde, hasta]
      );
      return filas.map((f) => f.fecha);
    },
  };
}

export type RepoGimnasio = ReturnType<typeof crearRepoGimnasio>;
