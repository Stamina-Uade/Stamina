/**
 * dominios/plan/hechos-a-mano.ts — los días del plan que la persona marcó como
 * hechos sin una salida registrada (020_dias_hechos_a_mano.sql, contrato 1.7.0).
 *
 * 🛑 AGENTS.md §12: cada consulta filtra por `usuario_id` en el mismo SQL.
 *
 * La fecha sale con `to_char` y no como `date`, por lo mismo que los pasos
 * (pasos/repositorio.ts): el driver correría el día en un servidor que no esté en UTC.
 */
import type { Db } from "../../infra/db.js";

export function crearRepoHechosAMano(db: Db) {
  return {
    /** Idempotente: marcar dos veces el mismo día deja la primera fecha. */
    async marcar(usuarioId: string, fecha: string, ahoraMs: number): Promise<void> {
      await db.consultar(
        `insert into dias_hechos_a_mano (usuario_id, fecha, creado_en_ms)
              values ($1, $2::date, $3)
         on conflict (usuario_id, fecha) do nothing`,
        [usuarioId, fecha, ahoraMs]
      );
    },

    async enRango(usuarioId: string, desde: string, hasta: string): Promise<string[]> {
      const filas = await db.consultar<{ fecha: string }>(
        `select to_char(fecha, 'YYYY-MM-DD') as fecha from dias_hechos_a_mano
          where usuario_id = $1 and fecha between $2::date and $3::date`,
        [usuarioId, desde, hasta]
      );
      return filas.map((f) => f.fecha);
    },

    /** Todo, para la exportación (AGENTS.md §8). */
    async todos(usuarioId: string): Promise<Array<{ fecha: string; creado_en_ms: number }>> {
      return db.consultar<{ fecha: string; creado_en_ms: number }>(
        `select to_char(fecha, 'YYYY-MM-DD') as fecha, creado_en_ms from dias_hechos_a_mano
          where usuario_id = $1 order by fecha`,
        [usuarioId]
      );
    },
  };
}
