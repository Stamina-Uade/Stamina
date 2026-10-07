/**
 * dominios/version — GET /v1/version
 *
 * 🛑 AGENTS.md §5.1: esto existe ANTES de publicar la v1, o no existe nunca.
 *
 * El mínimo se cambia SIN DESPLEGAR porque sale de la tabla `app_version_gate`.
 * Cambiar el mínimo es un UPDATE de una fila.
 *
 * La lectura va cacheada en Redis con TTL de 60 s: el endpoint lo pega toda la
 * base instalada al arrancar, así que sin caché es una consulta por app abierta.
 * El TTL no es opcional — ese Redis no tiene techo de memoria (§2.3.2).
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { ErrorApi } from "../../infra/errores.js";

const PLATAFORMAS = ["android", "ios", "wear", "watchos"] as const;
type Plataforma = (typeof PLATAFORMAS)[number];

const TTL_CACHE_S = 60;

interface FilaGate {
  plataforma: string;
  minimo_build: number;
  recomendado_build: number;
  codigo_mensaje: string | null;
  mensaje: string | null;
  store_url: string | null;
}

async function leerGate(ctx: Contexto, plataforma: Plataforma): Promise<FilaGate | null> {
  const clave = `gate:${plataforma}`;

  const cacheado = await ctx.cache.obtener(clave).catch(() => null);
  if (cacheado !== null) {
    try {
      return JSON.parse(cacheado) as FilaGate;
    } catch {
      // Caché corrupta: se ignora y se lee de la base. Nunca se rompe por esto.
    }
  }

  const fila = await ctx.db.unaFila<FilaGate>(
    `select plataforma, minimo_build, recomendado_build, codigo_mensaje, mensaje, store_url
       from app_version_gate
      where plataforma = $1`,
    [plataforma]
  );
  if (fila === null) return null;

  await ctx.cache.poner(clave, JSON.stringify(fila), TTL_CACHE_S).catch(() => {});
  return fila;
}

export async function rutasVersion(app: FastifyInstance, ctx: Contexto): Promise<void> {
  app.get(
    "/version",
    {
      schema: {
        querystring: {
          type: "object",
          required: ["platform"],
          additionalProperties: false,
          properties: {
            platform: { type: "string", enum: [...PLATAFORMAS] },
            build: { type: "integer", minimum: 1 },
          },
        },
      },
    },
    async (req) => {
      const q = req.query as { platform: Plataforma; build?: number };

      let fila: FilaGate | null;
      try {
        fila = await leerGate(ctx, q.platform);
      } catch {
        // 🛑 Degradación decidida (docs/API.md §4): si no se puede leer, se
        // responde 503 y el cliente DEJA PASAR. Una puerta de versión que se rompe
        // no puede dejar a todo el mundo afuera de la app.
        throw new ErrorApi("service_unavailable", "Version gate is not readable");
      }
      if (fila === null) throw new ErrorApi("service_unavailable", "Version gate is not configured");

      let action: "ok" | "update_recommended" | "update_required" = "ok";
      if (q.build !== undefined) {
        if (q.build < fila.minimo_build) action = "update_required";
        else if (q.build < fila.recomendado_build) action = "update_recommended";
      }

      const data: Record<string, unknown> = {
        platform: fila.plataforma,
        minimum_build: fila.minimo_build,
        recommended_build: fila.recomendado_build,
        action,
      };
      if (fila.codigo_mensaje !== null) data["code"] = fila.codigo_mensaje;
      if (fila.mensaje !== null) data["message"] = fila.mensaje;
      if (fila.store_url !== null) data["store_url"] = fila.store_url;

      return { data };
    }
  );
}
