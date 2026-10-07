/**
 * dominios/plan/repositorio.ts — el ancla del bloque (005_plan.sql).
 *
 * 🛑 AGENTS.md §12: toda consulta filtra por `usuario_id` en el mismo SQL.
 */
import type { Db } from "../../infra/db.js";

export interface PlanFila {
  id: string;
  motor_version: string;
  entrada_hash: string;
  inicio_fecha: string;
  zona_horaria: string;
  creado_en_ms: number;
}

const COLUMNAS = "id, motor_version, entrada_hash, inicio_fecha, zona_horaria, creado_en_ms";

export function crearRepoPlan(db: Db) {
  return {
    async vigente(usuarioId: string, objetivoId: string | null = null): Promise<PlanFila | null> {
      return db.unaFila<PlanFila>(
        `select ${COLUMNAS} from planes
          where usuario_id = $1 and objetivo_id is not distinct from $2::uuid
            and reemplazado_en_ms is null`,
        [usuarioId, objetivoId]
      );
    },

    /**
     * Deja vigente un ancla para ese hash estructural.
     *
     * Si la vigente tiene OTRO hash, se marca reemplazada y nace una nueva desde
     * `inicioFecha`. Si dos pedidos llegan a la vez, el índice único parcial
     * `planes_vigente` deja entrar a uno solo y el otro lee lo que quedó: la carrera
     * la resuelve la base, no un select previo.
     */
    async anclar(
      usuarioId: string,
      motorVersion: string,
      entradaHash: string,
      inicioFecha: string,
      zona: string,
      ahoraMs: number,
      objetivoId: string | null = null
    ): Promise<PlanFila> {
      return db.enTransaccion(async (tx) => {
        await tx.consultar(
          `update planes set reemplazado_en_ms = $2
            where usuario_id = $1 and objetivo_id is not distinct from $4::uuid
              and reemplazado_en_ms is null and entrada_hash <> $3`,
          [usuarioId, ahoraMs, entradaHash, objetivoId]
        );
        const nueva = await tx.unaFila<PlanFila>(
          `insert into planes (usuario_id, motor_version, entrada_hash, inicio_fecha, zona_horaria, creado_en_ms, objetivo_id)
                values ($1, $2, $3, $4, $5, $6, $7)
           on conflict do nothing
           returning ${COLUMNAS}`,
          [usuarioId, motorVersion, entradaHash, inicioFecha, zona, ahoraMs, objetivoId]
        );
        if (nueva !== null) return nueva;
        const quedo = await tx.unaFila<PlanFila>(
          `select ${COLUMNAS} from planes
            where usuario_id = $1 and objetivo_id is not distinct from $2::uuid
              and reemplazado_en_ms is null`,
          [usuarioId, objetivoId]
        );
        if (quedo === null) throw new Error("anclar: no quedó ningún plan vigente");
        return quedo;
      });
    },
  };
}
