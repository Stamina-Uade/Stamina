import type { Db } from "../../infra/db.js";
import { ErrorApi } from "../../infra/errores.js";

export interface ObjetivoActivo {
  id: string;
  goal: string;
  goal_date_ms: number | null;
}

export function crearRepoObjetivos(db: Db) {
  async function listar(usuarioId: string): Promise<ObjetivoActivo[]> {
    const principal = await db.unaFila<{ objetivo: string | null; objetivo_fecha_ms: number | null }>(
      `select p.objetivo, p.objetivo_fecha_ms from usuarios u
         left join perfiles p on p.usuario_id = u.id
        where u.id = $1`, [usuarioId]);
    if (principal === null) throw new ErrorApi("not_found", "Profile not found");
    const adicionales = await db.consultar<{ id: string; objetivo: string; objetivo_fecha_ms: number | null }>(
      `select o.id, o.objetivo, o.objetivo_fecha_ms from objetivos_usuario o
         join usuarios u on u.id = o.usuario_id
        where o.usuario_id = $1 and o.completado_en_ms is null
        order by o.orden, o.creado_en_ms`, [usuarioId]);
    return [
      ...(principal.objetivo === null ? [] : [{ id: "principal", goal: principal.objetivo,
                                               goal_date_ms: principal.objetivo_fecha_ms }]),
      ...adicionales.map((o) => ({ id: o.id, goal: o.objetivo, goal_date_ms: o.objetivo_fecha_ms })),
    ];
  }

  async function reemplazar(usuarioId: string, objetivos: ObjetivoActivo[], ahoraMs: number): Promise<ObjetivoActivo[]> {
    return db.enTransaccion(async (tx) => {
      const principal = objetivos[0];
      const vivo = await tx.unaFila<{ id: string }>(
        `select id from usuarios where id = $1 for update`, [usuarioId]);
      if (vivo === null) throw new ErrorApi("not_found", "Profile not found");
      await tx.consultar(
        `insert into perfiles(usuario_id, objetivo, objetivo_fecha_ms, actualizado_en_ms)
           values($1, $2, $3, $4)
         on conflict(usuario_id) do update
           set objetivo = excluded.objetivo,
               objetivo_fecha_ms = excluded.objetivo_fecha_ms,
               actualizado_en_ms = excluded.actualizado_en_ms`,
        [usuarioId, principal?.goal ?? null, principal?.goal_date_ms ?? null, ahoraMs]);
      if (principal === undefined) {
        await tx.consultar(
          `update planes set reemplazado_en_ms = $2
            where usuario_id = $1 and objetivo_id is null and reemplazado_en_ms is null`,
          [usuarioId, ahoraMs]);
      }

      const activos = await tx.consultar<{ id: string; objetivo: string; objetivo_fecha_ms: number | null }>(
        `select id, objetivo, objetivo_fecha_ms from objetivos_usuario
          where usuario_id = $1 and completado_en_ms is null for update`, [usuarioId]);
      const conservar: string[] = [];
      for (const [indice, objetivo] of objetivos.slice(1).entries()) {
        let id = objetivo.id ?? "";
        if (id === "") {
          const igual = activos.find((fila) => !conservar.includes(fila.id) &&
            fila.objetivo === objetivo.goal && fila.objetivo_fecha_ms === objetivo.goal_date_ms);
          id = igual?.id ?? "";
        }
        if (id) {
          const actualizado = await tx.unaFila<{ id: string }>(
            `update objetivos_usuario set objetivo = $3, objetivo_fecha_ms = $4,
                   orden = $5, actualizado_en_ms = $6
              where id = $1 and usuario_id = $2 and completado_en_ms is null returning id`,
            [id, usuarioId, objetivo.goal, objetivo.goal_date_ms, indice + 1, ahoraMs]);
          if (actualizado === null) throw new ErrorApi("not_found", "Goal not found");
        } else {
          const creado = await tx.unaFila<{ id: string }>(
            `insert into objetivos_usuario(usuario_id, objetivo, objetivo_fecha_ms, orden,
                                          creado_en_ms, actualizado_en_ms)
              values($1, $2, $3, $4, $5, $5) returning id`,
            [usuarioId, objetivo.goal, objetivo.goal_date_ms, indice + 1, ahoraMs]);
          if (creado === null) throw new Error("No se creó el objetivo adicional");
          id = creado.id;
        }
        conservar.push(id);
      }
      await tx.consultar(
        `update objetivos_usuario set completado_en_ms = $2, actualizado_en_ms = $2
          where usuario_id = $1 and completado_en_ms is null
            and not (id = any($3::uuid[]))`, [usuarioId, ahoraMs, conservar]);
      await tx.consultar(
        `update planes set reemplazado_en_ms = $2
          where usuario_id = $1 and reemplazado_en_ms is null
            and objetivo_id is not null and not (objetivo_id = any($3::uuid[]))`, [usuarioId, ahoraMs, conservar]);
      return [
        ...(principal === undefined ? [] : [{ ...principal, id: "principal" }]),
        ...objetivos.slice(1).map((o, i) => ({ ...o, id: conservar[i]! })),
      ];
    });
  }

  async function adicional(usuarioId: string, objetivoId: string): Promise<ObjetivoActivo | null> {
    const fila = await db.unaFila<{ id: string; objetivo: string; objetivo_fecha_ms: number | null }>(
      `select o.id, o.objetivo, o.objetivo_fecha_ms from objetivos_usuario o
         join usuarios u on u.id = o.usuario_id
        where o.usuario_id = $1 and o.id = $2 and o.completado_en_ms is null`,
      [usuarioId, objetivoId]);
    return fila === null ? null : { id: fila.id, goal: fila.objetivo, goal_date_ms: fila.objetivo_fecha_ms };
  }

  return { listar, reemplazar, adicional };
}
