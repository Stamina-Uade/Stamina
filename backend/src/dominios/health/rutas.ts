/**
 * dominios/health — GET /v1/health
 *
 * AGENTS.md §2.5 pide un /health que diga versión, base y Redis. Es público y está
 * en una máquina de producción ajena, así que NO expone nada más: ni host, ni
 * versión de Postgres, ni conteos, ni nombres de base.
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";

export async function rutasHealth(app: FastifyInstance, ctx: Contexto): Promise<void> {
  app.get("/health", { config: { rateLimit: false } }, async (_req, res) => {
    const db = await ctx.db.vivo();

    // `disabled` no es una falla: es `REDIS_URL=disabled`, declarado a propósito
    // (decisión 0011). Decir "down" ahí haría sonar una alarma todos los días, y
    // decir "ok" sería mentir sobre qué hay detrás.
    const redis = ctx.cache.modo === "memoria" ? "disabled" : (await ctx.cache.vivo()) ? "ok" : "down";

    // Sin base no hay servicio. Sin un Redis que se declaró, hay servicio
    // degradado: Redis es caché y rate limit, y la fuente de verdad es Postgres.
    const status = !db ? "down" : redis === "down" ? "degraded" : "ok";

    if (status === "down") res.code(503);

    return {
      data: {
        status,
        version: ctx.config.version,
        dependencies: {
          database: db ? "ok" : "down",
          redis,
        },
      },
    };
  });
}
