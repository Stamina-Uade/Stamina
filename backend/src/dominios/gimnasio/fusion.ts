/**
 * dominios/gimnasio/fusion.ts — cómo se fusionan dos versiones de la misma serie.
 *
 * Es la decisión 0006 del lado del servidor, y es a propósito LA MISMA FUNCIÓN que
 * ios/TrainerCore/Sources/TrainerCore/Sincronizacion/SerieRegistrada.swift
 * (`SerieRegistrada.fusionar`), caso por caso. Si el teléfono, el reloj y el
 * servidor fusionaran distinto, divergirían en silencio.
 *
 *   1. La identidad es determinística: (sesión, ejercicio, número).
 *   2. `hecha` es monotónica: al fusionar sólo va de false a true.
 *   3. La fusión es por FILA COMPLETA, nunca por campo. Gana, en este orden:
 *      lo que llegó al servidor sobre lo que no llegó; entre dos que llegaron, la
 *      que llegó después; si no, el momento local; y en empate exacto, el
 *      dispositivo — no porque uno sea mejor, sino para que el orden sea TOTAL.
 *
 * 🛑 Tiene que ser conmutativa, asociativa e idempotente. Los tests lo verifican.
 */

export type Dispositivo = "telefono" | "reloj";

export interface Serie {
  ejercicioId: string;
  numero: number;
  hecha: boolean;
  repeticiones: number;
  /** Gramos. `null` = peso corporal. */
  pesoG: number | null;
  salteada: boolean;
  esExtra: boolean;
  registradaLocalMs: number;
  /** `null` mientras no llegó al servidor. */
  recibidaEnServidorMs: number | null;
  dispositivo: Dispositivo;
}

export function claveDe(s: Pick<Serie, "ejercicioId" | "numero">): string {
  return `${s.ejercicioId}#${s.numero}`;
}

/** ¿Gana `a` sobre `b`? El orden es total y determinístico. */
function gana(a: Serie, b: Serie): boolean {
  const ta = a.recibidaEnServidorMs;
  const tb = b.recibidaEnServidorMs;
  if (ta !== null && tb !== null && ta !== tb) return ta > tb;
  if (ta !== null && tb === null) return true;
  if (ta === null && tb !== null) return false;

  if (a.registradaLocalMs !== b.registradaLocalMs) return a.registradaLocalMs > b.registradaLocalMs;

  // Mismo criterio que `Dispositivo: Comparable` en Swift: por el nombre crudo.
  return a.dispositivo > b.dispositivo;
}

/** Fusiona dos versiones de LA MISMA serie. */
export function fusionar(a: Serie, b: Serie): Serie {
  if (claveDe(a) !== claveDe(b)) {
    throw new Error("fusion: sólo se fusionan versiones de la misma serie");
  }
  const ganadora = gana(a, b) ? a : b;
  // La fila entera viene de quien ganó (regla 3); `hecha` es la excepción (regla 2).
  return { ...ganadora, hecha: a.hecha || b.hecha };
}

/** Une dos conjuntos: misma clave se fusiona, clave distinta se agrega. */
export function unir(unas: readonly Serie[], otras: readonly Serie[]): Serie[] {
  const porClave = new Map<string, Serie>();
  for (const s of [...unas, ...otras]) {
    const previa = porClave.get(claveDe(s));
    porClave.set(claveDe(s), previa === undefined ? s : fusionar(previa, s));
  }
  // El orden de pantalla: por ejercicio y número. Igual que en Swift.
  return [...porClave.values()].sort((x, y) =>
    x.ejercicioId === y.ejercicioId ? x.numero - y.numero : x.ejercicioId < y.ejercicioId ? -1 : 1
  );
}
