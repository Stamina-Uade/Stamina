/**
 * dominios/auth/guardia.ts — el preHandler de toda ruta autenticada.
 *
 * Dos comprobaciones, en este orden, y las dos hacen falta:
 *   1. el access token verifica: firma, algoritmo fijado en código, vencimiento
 *   2. la SESIÓN de ese token sigue viva, y su cuenta no está desactivada ni por
 *      borrarse (contrato 1.6.0)
 *
 * La 2 existe porque un access vive 15 minutos: sin mirarla, "cerrar sesión",
 * "cerrar las otras sesiones", desactivar o borrar la cuenta —que revocan
 * sesiones— no significarían nada durante ese rato. Es una consulta por request,
 * y es el precio. (Desde la 1.6.0 cambiar la contraseña ya no revoca las demás.)
 *
 * Vive en el dominio de auth y no en infra/ porque consulta la tabla de sesiones, y
 * la infraestructura no conoce el negocio (§4.4).
 */
import type { FastifyReply, FastifyRequest } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearHookAuth } from "../../infra/autenticacion.js";
import { ErrorApi } from "../../infra/errores.js";
import { crearServicioAuth } from "./servicio.js";

export function crearGuardia(ctx: Contexto) {
  const verificarToken = crearHookAuth(ctx.config);
  const auth = crearServicioAuth(ctx);

  return async function guardia(req: FastifyRequest, res: FastifyReply): Promise<void> {
    await verificarToken(req, res);
    const u = req.usuario;
    if (u === undefined) throw new ErrorApi("unauthorized", "Missing bearer token");
    if (!(await auth.sesionVigente(u.sesionId))) {
      throw new ErrorApi("session_revoked", "Session was revoked");
    }
  };
}

/**
 * El id de quien pide, sacado del token. Sólo tiene sentido detrás de la guardia.
 *
 * 🛑 Es la ÚNICA fuente del id de usuario en las rutas: nunca la ruta, nunca el
 * cuerpo (AGENTS.md §12, IDOR).
 */
export function usuarioDe(req: FastifyRequest): string {
  const u = req.usuario;
  if (u === undefined) throw new ErrorApi("unauthorized", "Missing bearer token");
  return u.id;
}
