/**
 * infra/idioma.ts — en qué idioma van los textos que arma el servidor.
 *
 * Casi todo lo que ve la persona lo traduce el CLIENTE a partir de códigos
 * (AGENTS.md §10). Lo que no se puede traducir en el cliente es el contenido que
 * arma el servidor —el título de una sesión del plan, el nombre de un ejercicio
 * del catálogo—, y eso sale en el idioma que pide `Accept-Language`.
 *
 * Se publican dos (decisión 0010): es-AR y en-US. Cualquier otra cosa cae en es-AR,
 * que es el idioma en el que está escrito todo lo demás.
 */
import type { FastifyRequest } from "fastify";

export type Locale = "es-AR" | "en-US";

export function localeDe(req: FastifyRequest): Locale {
  const header = req.headers["accept-language"];
  const primero = (Array.isArray(header) ? header[0] : header)?.split(",")[0]?.trim().toLowerCase() ?? "";
  return primero.startsWith("en") ? "en-US" : "es-AR";
}

/** El nombre en ese idioma, o el castellano, o el id: nunca un hueco. */
export function nombreEn(nombres: Record<string, string | null | undefined>, locale: Locale, respaldo: string): string {
  return nombres[locale] ?? nombres["es-AR"] ?? respaldo;
}
