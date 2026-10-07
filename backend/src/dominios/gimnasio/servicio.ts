/**
 * dominios/gimnasio/servicio.ts — sincronizar series con el servidor.
 *
 * La regla de quién gana está en fusion.ts; acá está el ORDEN de las operaciones,
 * que es lo que hace que la regla valga con dos pedidos a la vez:
 *
 *   1. tomar la sesión (y con eso su lock)
 *   2. leer lo guardado
 *   3. fusionar en memoria, con la hora de llegada que pone el servidor
 *   4. escribir sólo lo que el lote tocó, y todo lo que llegó al historial
 *
 * Todo en una transacción: o entra el lote entero o no entra nada.
 */
import type { Db } from "../../infra/db.js";
import { claveDe, unir, type Serie } from "./fusion.js";
import { crearRepoGimnasio, filaASerie, type SesionFila } from "./repositorio.js";

const PATRON_FECHA = /^gym-(\d{4}-\d{2}-\d{2})$/;

/**
 * La fecha de una sesión cuyo id es `gym-YYYY-MM-DD` —el que derivan los dos
 * dispositivos en `ClaveDeSerie.sesionDeGimnasio`—. Con cualquier otro id, `null`:
 * el servidor no le inventa una fecha a lo que no la dice.
 */
export function fechaDeSesion(sesionId: string): string | null {
  const fecha = PATRON_FECHA.exec(sesionId)?.[1];
  if (fecha === undefined) return null;
  const d = new Date(`${fecha}T00:00:00Z`);
  // `2026-02-30` no es una fecha: si el round-trip no devuelve lo mismo, no se acepta.
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === fecha ? fecha : null;
}

export async function sincronizarSeries(
  db: Db,
  usuarioId: string,
  sesionId: string,
  entrantes: readonly Serie[],
  ahoraMs: number
): Promise<{ sesion: SesionFila; series: Serie[] }> {
  return db.enTransaccion(async (tx) => {
    const repo = crearRepoGimnasio(tx);
    const sesion = await repo.tomarSesion(usuarioId, sesionId, fechaDeSesion(sesionId), ahoraMs);
    const guardadas = (await repo.series(usuarioId, sesionId)).map(filaASerie);

    const todas = unir(guardadas, entrantes);
    const tocadas = new Set(entrantes.map(claveDe));

    await repo.guardar(usuarioId, sesionId, todas.filter((s) => tocadas.has(claveDe(s))));
    await repo.agregarAlHistorial(usuarioId, sesionId, entrantes);
    return { sesion, series: todas };
  });
}
