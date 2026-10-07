/**
 * dominios/nutricion/repositorio.ts — las comidas.
 *
 * 🛑 AGENTS.md §12: toda consulta filtra por `usuario_id` en el mismo SQL, y toda
 * lectura por `borrada_en_ms is null` (§11).
 * §8: lo que alguien come es un dato de salud. No sale en un error ni en un log.
 */
import type { Db } from "../../infra/db.js";

export interface ComidaFila {
  id: string;
  comida_en_ms: number;
  nombre: string;
  kcal: number;
  carbohidratos_g: number;
  proteina_g: number;
  grasa_g: number;
  creada_en_ms: number;
  actualizada_en_ms: number;
}

export interface ComidaNueva {
  comidaEnMs: number;
  nombre: string;
  kcal: number;
  carbohidratosG: number;
  proteinaG: number;
  grasaG: number;
}

const COLUMNAS = "id, comida_en_ms, nombre, kcal, carbohidratos_g, proteina_g, grasa_g, creada_en_ms, actualizada_en_ms";

export function crearRepoComidas(db: Db) {
  return {
    /** PUT idempotente por id. `null` si ese id se borró: borrar gana (igual que en actividades). */
    async guardar(usuarioId: string, id: string, c: ComidaNueva, ahoraMs: number): Promise<ComidaFila | null> {
      return db.unaFila<ComidaFila>(
        `insert into comidas
           (usuario_id, id, comida_en_ms, nombre, kcal, carbohidratos_g, proteina_g, grasa_g, creada_en_ms, actualizada_en_ms)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)
         on conflict (usuario_id, id) do update set
           comida_en_ms = excluded.comida_en_ms, nombre = excluded.nombre, kcal = excluded.kcal,
           carbohidratos_g = excluded.carbohidratos_g, proteina_g = excluded.proteina_g,
           grasa_g = excluded.grasa_g, actualizada_en_ms = excluded.actualizada_en_ms
          where comidas.borrada_en_ms is null
         returning ${COLUMNAS}`,
        [usuarioId, id, c.comidaEnMs, c.nombre, c.kcal, c.carbohidratosG, c.proteinaG, c.grasaG, ahoraMs]
      );
    },

    async borrar(usuarioId: string, id: string, ahoraMs: number): Promise<void> {
      await db.consultar(
        `update comidas set borrada_en_ms = $3 where usuario_id = $1 and id = $2 and borrada_en_ms is null`,
        [usuarioId, id, ahoraMs]
      );
    },

    /** Las comidas de [desdeMs, hastaMs): un día local de la persona. */
    async delDia(usuarioId: string, desdeMs: number, hastaMs: number): Promise<ComidaFila[]> {
      return db.consultar<ComidaFila>(
        `select ${COLUMNAS}
           from comidas
          where usuario_id = $1 and borrada_en_ms is null and comida_en_ms >= $2 and comida_en_ms < $3
          order by comida_en_ms, id`,
        [usuarioId, desdeMs, hastaMs]
      );
    },
  };
}
