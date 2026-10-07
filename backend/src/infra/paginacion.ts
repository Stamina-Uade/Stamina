/**
 * infra/paginacion.ts — el cursor opaco de docs/API.md §1.
 *
 * Keyset, nunca OFFSET: un historial crece mientras se pagina, y con OFFSET se
 * repiten filas y se saltean otras. El cursor lleva la clave de orden de la última
 * fila entregada, con la PK como desempate.
 *
 * "Opaco" es para el cliente, no para la seguridad: adentro va JSON en base64url.
 * Que alguien lo edite a mano no abre nada, porque TODA consulta filtra por dueño
 * en el mismo SQL (AGENTS.md §12): lo peor que consigue es saltearse sus propias
 * filas. Lo que sí se hace es validar la forma, para que un cursor roto sea un 400
 * y no un 500.
 */
import { ErrorApi } from "./errores.js";

export const LIMITE_POR_DEFECTO = 50;
export const LIMITE_MAXIMO = 200;

/** Casteado y clampeado en el servidor (§12): un `limit=100000` no es un error, es un tope. */
export function limiteDe(crudo: unknown): number {
  const n = typeof crudo === "number" ? crudo : Number.parseInt(String(crudo ?? ""), 10);
  if (!Number.isInteger(n)) return LIMITE_POR_DEFECTO;
  return Math.min(Math.max(n, 1), LIMITE_MAXIMO);
}

type Valor = string | number;

export function codificarCursor(valores: readonly Valor[]): string {
  return Buffer.from(JSON.stringify(valores), "utf8").toString("base64url");
}

/**
 * @param forma el tipo de cada posición, en orden.
 * @returns `null` si no vino cursor (primera página).
 */
export function decodificarCursor(
  cursor: string | undefined,
  forma: ReadonlyArray<"string" | "number">
): Valor[] | null {
  if (cursor === undefined || cursor === "") return null;
  let valores: unknown;
  try {
    valores = JSON.parse(Buffer.from(cursor, "base64url").toString("utf8"));
  } catch {
    throw new ErrorApi("bad_request", "Cursor is not valid");
  }
  const bienFormado =
    Array.isArray(valores) &&
    valores.length === forma.length &&
    valores.every((v, i) => typeof v === forma[i] && (typeof v !== "number" || Number.isFinite(v)));
  if (!bienFormado) throw new ErrorApi("bad_request", "Cursor is not valid");
  return valores as Valor[];
}

export interface Pagina<R> {
  data: R[];
  pagination: { next_cursor?: string; has_more: boolean };
}

/**
 * Arma el sobre de una lista. Quien consulta pide `limite + 1` filas: la de más
 * es la que dice si hay otra página, y no se entrega.
 */
export function pagina<F, R>(
  filas: readonly F[],
  limite: number,
  claveDe: (fila: F) => readonly Valor[],
  aApi: (fila: F) => R
): Pagina<R> {
  const hayMas = filas.length > limite;
  const entregadas = hayMas ? filas.slice(0, limite) : filas;
  const ultima = entregadas.at(-1);
  return {
    data: entregadas.map(aApi),
    pagination:
      hayMas && ultima !== undefined
        ? { next_cursor: codificarCursor(claveDe(ultima)), has_more: true }
        : { has_more: false },
  };
}
