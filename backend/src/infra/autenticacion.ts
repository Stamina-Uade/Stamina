/**
 * infra/autenticacion.ts — el hook que resuelve quién pide.
 *
 * AGENTS.md §12: el algoritmo del JWT está fijado en código (ver cripto.ts) y la
 * pertenencia se valida en la MISMA query que lee el recurso. Este módulo sólo
 * dice QUIÉN es; el filtro por dueño lo hace cada repositorio, en su SQL.
 */
import type { FastifyReply, FastifyRequest } from "fastify";
import type { Config } from "../config.js";
import { verificarAcceso } from "./cripto.js";
import { ErrorApi } from "./errores.js";

declare module "fastify" {
  interface FastifyRequest {
    /** Presente sólo en rutas autenticadas. */
    usuario?: { id: string; sesionId: string };
  }
}

export function crearHookAuth(config: Config) {
  return async function requiereAuth(req: FastifyRequest, _res: FastifyReply): Promise<void> {
    const header = req.headers.authorization;
    if (typeof header !== "string" || !header.startsWith("Bearer ")) {
      throw new ErrorApi("unauthorized", "Missing bearer token");
    }
    const token = header.slice("Bearer ".length).trim();
    const claims = await verificarAcceso(config, token);
    if (claims === null) {
      throw new ErrorApi("unauthorized", "Token is not valid");
    }
    req.usuario = { id: claims.sub, sesionId: claims.sid };
  };
}
