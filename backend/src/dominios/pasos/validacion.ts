/**
 * dominios/pasos/validacion.ts — lo que el contrato no puede decir con un esquema.
 *
 * El esquema ya exige "YYYY-MM-DD", el tope de 60 días por lote y los rangos de
 * cada número. Acá queda lo que depende del calendario o de la hora del servidor:
 * que el día exista, que no sea del futuro, que no venga repetido, y el tope del
 * rango de lectura. Son funciones puras para poder probarlas sin base.
 */
import { ErrorApi } from "../../infra/errores.js";
import { diasEntre, fechaUTC, sumarDias } from "../../infra/fechas.js";

export type FuenteDePasos = "healthkit" | "manual" | "health_connect";

export interface DiaDePasosEntrada {
  date: string;
  steps: number;
  source: FuenteDePasos;
  updated_at_ms?: number;
}

/** Un día listo para guardar: con la hora de la escritura ya resuelta. */
export interface DiaDePasosNormalizado {
  fecha: string;
  pasos: number;
  fuente: FuenteDePasos;
  actualizadoMs: number;
}

/** Cuántos días puede pedir un GET, contando las dos puntas. */
export const MAX_DIAS_DEL_RANGO = 366;

/** Cuántos días entran en un PUT. El contrato dice lo mismo (`maxItems`). */
export const MAX_DIAS_POR_LOTE = 60;

const FORMA = /^(\d{4})-(\d{2})-(\d{2})$/;

/** ¿"YYYY-MM-DD" es un día que existe? "2026-02-30" tiene la forma y no existe. */
export function esFechaDeCalendario(fecha: string): boolean {
  const m = FORMA.exec(fecha);
  if (m === null) return false;
  const [anio, mes, dia] = [Number(m[1]), Number(m[2]), Number(m[3])];
  if (anio < 2000 || mes < 1 || mes > 12 || dia < 1) return false;
  const d = new Date(Date.UTC(anio, mes - 1, dia));
  return d.getUTCFullYear() === anio && d.getUTCMonth() === mes - 1 && d.getUTCDate() === dia;
}

/**
 * El último día que se acepta: mañana en UTC.
 *
 * El servidor no sabe la zona del teléfono, y en Kiritimati (UTC+14) ya es
 * "mañana" cuando en UTC todavía es hoy. Más allá de eso, un día del futuro no
 * puede tener pasos contados.
 */
export function ultimoDiaAceptado(ahoraMs: number): string {
  return sumarDias(fechaUTC(ahoraMs), 1);
}

/**
 * Valida un lote y le resuelve la hora a cada día.
 *
 * `updated_at_ms` ausente vale "ahora". Uno del futuro también se baja a "ahora":
 * un reloj adelantado no puede dejar un día trabado, ganándole a todo lo que
 * llegue después.
 */
export function normalizarLote(dias: readonly DiaDePasosEntrada[], ahoraMs: number): DiaDePasosNormalizado[] {
  if (dias.length === 0 || dias.length > MAX_DIAS_POR_LOTE) {
    throw new ErrorApi("bad_request", `Between 1 and ${MAX_DIAS_POR_LOTE} days per request`);
  }
  const tope = ultimoDiaAceptado(ahoraMs);
  const vistos = new Set<string>();
  const salida: DiaDePasosNormalizado[] = [];
  for (const d of dias) {
    if (!esFechaDeCalendario(d.date)) throw new ErrorApi("bad_request", "Invalid calendar date");
    if (d.date > tope) throw new ErrorApi("bad_request", "Steps cannot be from the future");
    if (vistos.has(d.date)) throw new ErrorApi("bad_request", "Repeated date in the same request");
    vistos.add(d.date);
    const actualizadoMs = Math.min(d.updated_at_ms ?? ahoraMs, ahoraMs);
    salida.push({ fecha: d.date, pasos: d.steps, fuente: d.source, actualizadoMs });
  }
  return salida.sort((a, b) => (a.fecha < b.fecha ? -1 : a.fecha > b.fecha ? 1 : 0));
}

/** Valida `from`/`to` de un GET. Las dos puntas cuentan. */
export function validarRango(desde: string, hasta: string): { desde: string; hasta: string } {
  if (!esFechaDeCalendario(desde) || !esFechaDeCalendario(hasta)) {
    throw new ErrorApi("bad_request", "Invalid calendar date");
  }
  const dias = diasEntre(desde, hasta);
  if (dias < 0) throw new ErrorApi("bad_request", "`from` is after `to`");
  if (dias + 1 > MAX_DIAS_DEL_RANGO) {
    throw new ErrorApi("bad_request", `At most ${MAX_DIAS_DEL_RANGO} days per request`);
  }
  return { desde, hasta };
}
