/**
 * dominios/auth/dispositivos.ts — los dispositivos que ya estuvieron en cada cuenta
 * (021_dispositivos_conocidos.sql, contrato 1.7.0), para el correo "Nuevo inicio
 * de sesión".
 *
 * 🛑 AGENTS.md §12: cada consulta filtra por `usuario_id` en el mismo SQL.
 *
 * Sin ubicación: la ciudad y el país saldrían de la IP, y no hay cómo sacarlos sin
 * un servicio pago, sin mandar la IP a un tercero o sin sumar una base de GeoIP al
 * servidor. Queda para cuando se decida (docs/REDISENO-IOS-2026-10.md, octava ronda).
 */
import type { Db } from "../../infra/db.js";
import { hashearToken } from "../../infra/cripto.js";

/** El `Dispositivo` del contrato. */
export interface Dispositivo {
  id: string;
  model?: string;
  os?: string;
}

/** "iPhone 16 · iOS 26.5", lo que haya, o null. */
export function dispositivoLegible(d: Dispositivo | null | undefined): string | null {
  if (d === null || d === undefined) return null;
  const partes = [d.model, d.os].map((x) => x?.trim()).filter((x): x is string => x !== undefined && x !== "");
  return partes.length === 0 ? null : partes.join(" · ");
}

export function crearRepoDispositivos(db: Db) {
  return {
    /**
     * Lo deja conocido (o actualiza cuándo se lo vio por última vez) y dice si es
     * la PRIMERA vez que esa cuenta lo ve. Una sola sentencia: dos entradas a la vez
     * desde el mismo dispositivo nuevo no mandan dos correos (`xmax = 0` sólo es
     * verdad para la fila que se insertó).
     */
    async registrar(usuarioId: string, d: Dispositivo, ahoraMs: number): Promise<boolean> {
      const fila = await db.unaFila<{ nuevo: boolean }>(
        `insert into dispositivos_conocidos (usuario_id, dispositivo_hash, modelo, sistema, primera_vez_ms, ultima_vez_ms)
              values ($1, $2, $3, $4, $5, $5)
         on conflict (usuario_id, dispositivo_hash) do update
           set ultima_vez_ms = excluded.ultima_vez_ms,
               modelo = coalesce(excluded.modelo, dispositivos_conocidos.modelo),
               sistema = coalesce(excluded.sistema, dispositivos_conocidos.sistema)
         returning (xmax = 0) as nuevo`,
        [usuarioId, hashearToken(d.id), d.model ?? null, d.os ?? null, ahoraMs]
      );
      return fila?.nuevo === true;
    },

    /** Para la exportación (AGENTS.md §8). Sin el hash. */
    async todos(usuarioId: string) {
      return db.consultar<{ modelo: string | null; sistema: string | null; primera_vez_ms: number; ultima_vez_ms: number }>(
        `select modelo, sistema, primera_vez_ms, ultima_vez_ms from dispositivos_conocidos
          where usuario_id = $1 order by primera_vez_ms`,
        [usuarioId]
      );
    },
  };
}
