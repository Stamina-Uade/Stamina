/**
 * dominios/pasos/repositorio.ts — la tabla `pasos_diarios`.
 *
 * 🛑 AGENTS.md §12: cada consulta filtra por `usuario_id` en el mismo SQL.
 *
 * La fecha sale con `to_char` y no como `date`: el driver convierte un DATE en un
 * `Date` de JavaScript a la medianoche de la zona del PROCESO, y en un servidor
 * que no esté en UTC eso corre el día.
 */
import type { Db } from "../../infra/db.js";
import type { DiaDePasosNormalizado, FuenteDePasos } from "./validacion.js";

export interface PasosFila {
  fecha: string;
  pasos: number;
  fuente: FuenteDePasos;
  actualizado_ms: number;
}

export function pasosAApi(f: PasosFila) {
  return { date: f.fecha, steps: f.pasos, source: f.fuente, updated_at_ms: f.actualizado_ms };
}

const COLUMNAS = `to_char(fecha, 'YYYY-MM-DD') as fecha, pasos, fuente, actualizado_ms`;

export function crearRepoPasos(db: Db) {
  return {
    /**
     * Guarda el lote en UNA sentencia y devuelve cómo quedó cada día mandado.
     *
     * Gana el `actualizado_ms` más nuevo (`>=`: con la misma hora, el último que
     * llega). Lo que perdió no se escribe, y la respuesta lo muestra: el cliente
     * se entera de que había algo más nuevo y se queda con eso.
     */
    async guardar(usuarioId: string, dias: readonly DiaDePasosNormalizado[]): Promise<PasosFila[]> {
      if (dias.length === 0) return [];
      const fechas = dias.map((d) => d.fecha);
      await db.consultar(
        `insert into pasos_diarios (usuario_id, fecha, pasos, fuente, actualizado_ms)
         select $1, d.fecha::date, d.pasos, d.fuente, d.actualizado_ms
           from unnest($2::text[], $3::int[], $4::text[], $5::bigint[])
                as d(fecha, pasos, fuente, actualizado_ms)
         on conflict (usuario_id, fecha) do update
           set pasos = excluded.pasos,
               fuente = excluded.fuente,
               actualizado_ms = excluded.actualizado_ms
         where excluded.actualizado_ms >= pasos_diarios.actualizado_ms`,
        [usuarioId, fechas, dias.map((d) => d.pasos), dias.map((d) => d.fuente), dias.map((d) => d.actualizadoMs)]
      );
      return db.consultar<PasosFila>(
        `select ${COLUMNAS} from pasos_diarios
          where usuario_id = $1 and fecha = any($2::date[])
          order by fecha`,
        [usuarioId, fechas]
      );
    },

    async delRango(usuarioId: string, desde: string, hasta: string): Promise<PasosFila[]> {
      return db.consultar<PasosFila>(
        `select ${COLUMNAS} from pasos_diarios
          where usuario_id = $1 and fecha between $2::date and $3::date
          order by fecha`,
        [usuarioId, desde, hasta]
      );
    },

    /** Todo, para la exportación (AGENTS.md §8). */
    async todos(usuarioId: string): Promise<PasosFila[]> {
      return db.consultar<PasosFila>(
        `select ${COLUMNAS} from pasos_diarios where usuario_id = $1 order by fecha`,
        [usuarioId]
      );
    },
  };
}
