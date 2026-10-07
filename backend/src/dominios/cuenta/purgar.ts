/**
 * dominios/cuenta/purgar.ts — la tarea programada que borra DE VERDAD.
 *
 * Tres podas, cada una con su motivo:
 *
 *   1. El historial de series de más de 90 días (decisión 0006, "Lo que se
 *      cerró"): la última versión de cada serie sigue en `series_gimnasio`, que es
 *      lo que usa el motor; lo que se va es la cadena de correcciones.
 *   2. Material efímero vencido hace más de un día: claves de idempotencia
 *      y sesiones. No son entidades de usuario
 *      (001_auth.sql) y en un disco compartido no se acumulan (§2.4).
 *
 * Se corre una vez por día con el timer de backend/deploy/systemd/.
 */
import type { Db } from "../../infra/db.js";

const DIA_MS = 24 * 60 * 60 * 1000;
export const VIDA_HISTORIAL_SERIES_MS = 90 * DIA_MS;
const MARGEN_EFIMERO_MS = DIA_MS;

export async function purgar(db: Db, ahoraMs: number): Promise<Record<string, number>> {
  const contar = async (sql: string, valores: unknown[]): Promise<number> =>
    (await db.consultar<{ uno: number }>(`${sql} returning 1 as uno`, valores)).length;

  return {
    historial_series: await contar(`delete from series_gimnasio_historial where recibida_en_servidor_ms < $1`, [
      ahoraMs - VIDA_HISTORIAL_SERIES_MS,
    ]),
    idempotencia: await contar(`delete from idempotencia where vence_en_ms < $1`, [ahoraMs - MARGEN_EFIMERO_MS]),
    sesiones: await contar(`delete from sesiones where vence_en_ms < $1`, [ahoraMs - MARGEN_EFIMERO_MS]),
  };
}

// Sólo cuando se ejecuta como comando (`npm run purgar`), no cuando lo importa un test.
if (process.argv[1] && process.argv[1].endsWith("purgar.js")) {
  const { cargarConfigConSecretos } = await import("../../infra/secretos-aws.js");
  const { crearDb } = await import("../../infra/db.js");
  const config = await cargarConfigConSecretos();
  const db = crearDb(config);
  try {
    const r = await purgar(db, Date.now());
    // Sólo conteos: ni un id ni un correo (AGENTS.md §8).
    console.log(`purgar: ${Object.entries(r).map(([k, v]) => `${k}=${v}`).join(" ")}`);
  } catch (e) {
    console.error("purgar: FALLÓ —", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  } finally {
    await db.cerrar();
  }
}
