/**
 * dominios/auth/rutas.ts — la capa web de auth. Sin SQL adentro (§4.4).
 *
 * La validación de cada cuerpo sale del CONTRATO: `esquemas.cuerpos[operationId]`
 * lo genera `scripts/generar-esquemas.mjs` desde shared/api/openapi.yaml. No hay
 * un esquema escrito a mano que pueda divergir del contrato (§4.2).
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearServicioAuth } from "./servicio.js";
import { cuerpo } from "../../infra/esquemas.js";
import { crearHookAuth } from "../../infra/autenticacion.js";
import { ErrorApi } from "../../infra/errores.js";
import { crearRepoPerfil } from "../perfil/repositorio.js";

/**
 * 🛑 Rate limit estricto donde duele. AGENTS.md §12 lo pide "en login, registro,
 * recuperación y en los endpoints de importación".
 *
 * Va en la definición de cada ruta y NO en un hook `onRoute` de servidor.ts: el
 * plugin de rate limit lee `config.rateLimit` en SU propio `onRoute`, que corre
 * antes que uno agregado después de registrarlo, así que por esa vía la
 * configuración llegaba tarde y el límite estricto no se aplicaba nunca. Lo
 * agarró el test "el rate limit de login corta".
 */
const ESTRICTO = { rateLimit: { max: 8, timeWindow: "1 minute" } } as const;

export async function rutasAuth(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const auth = crearServicioAuth(ctx);
  const perfiles = crearRepoPerfil(ctx.db);
  const requiereAuth = crearHookAuth(ctx.config);

  // ------------------------------------------------------------- registro --
  app.post("/auth/register", { config: ESTRICTO, schema: { body: cuerpo("registerStart") } }, async (req, res) => {
    const b = req.body as { email: string; first_name?: string; last_name?: string };
    const r = await auth.registroInicio(b.email, b.first_name, b.last_name);
    res.code(202);
    return { data: r };
  });

  app.post("/auth/register/verify", { config: ESTRICTO, schema: { body: cuerpo("registerVerify") } }, async (req) => {
    const b = req.body as { email: string; code: string };
    return { data: await auth.registroVerificar(b.email, b.code) };
  });

  app.post("/auth/register/complete", { schema: { body: cuerpo("registerComplete") } }, async (req, res) => {
    const b = req.body as {
      registration_token?: string;
      password?: string;
      social_token?: string;
      profile: Record<string, unknown>;
      legal: { version: string; accepted: boolean };
    };
    // Una de las dos credenciales, nunca las dos ni ninguna (contrato 1.4.0).
    if ((b.password === undefined) === (b.social_token === undefined)) {
      throw new ErrorApi("bad_request", "Send exactly one of password or social_token");
    }
    if (b.password !== undefined && b.registration_token === undefined) {
      throw new ErrorApi("invalid_registration_token", "Registration token is required");
    }
    const credencial = b.password !== undefined ? { password: b.password } : { socialToken: b.social_token as string };
    const { sesion, usuarioId } = await auth.registroCompletar(b.registration_token, credencial, b.legal);
    // El perfil se guarda en la misma operación: una cuenta sin perfil no le
    // sirve al motor del plan (AGENTS.md §9.1).
    await perfiles.guardar(usuarioId, b.profile, ctx.ahoraMs());
    res.code(201);
    return { data: sesion };
  });

  // ---------------------------------------------------------------- login --
  app.post("/auth/login", { config: ESTRICTO, schema: { body: cuerpo("login") } }, async (req) => {
    const b = req.body as { email: string; password: string };
    // La IP del pedido, para el tope de fallos por IP entre todos los correos.
    return { data: await auth.login(b.email, b.password, req.ip) };
  });

  // ------------------------------------------------------- Google y Apple --
  app.post("/auth/social", { config: ESTRICTO, schema: { body: cuerpo("socialSignIn") } }, async (req) => {
    const b = req.body as { provider: "google" | "apple"; id_token: string; nonce: string };
    return { data: await auth.entrarConProveedor(b.provider, b.id_token, b.nonce) };
  });

  // 1.6.0: vincular Google o Apple a una cuenta con contraseña (`account_link_available`).
  app.post("/auth/social/link", { config: ESTRICTO, schema: { body: cuerpo("socialLink") } }, async (req) => {
    const b = req.body as { link_token: string; password?: string };
    return { data: await auth.vincularConPassword(b.link_token, b.password, req.ip) };
  });

  // 1.6.0: volver a una cuenta desactivada o por borrarse.
  app.post("/auth/reactivate", { config: ESTRICTO, schema: { body: cuerpo("reactivateAccount") } }, async (req) => {
    const b = req.body as { reactivation_token: string };
    return { data: await auth.reactivar(b.reactivation_token) };
  });

  app.post("/auth/refresh", { schema: { body: cuerpo("refresh") } }, async (req) => {
    const b = req.body as { refresh_token: string };
    return { data: await auth.refrescar(b.refresh_token) };
  });

  app.post(
    "/auth/logout",
    { preHandler: requiereAuth, schema: { body: cuerpo("logout") } },
    async (req, res) => {
      const b = (req.body ?? {}) as { refresh_token?: string; all?: boolean };
      const u = req.usuario;
      if (u === undefined) throw new ErrorApi("unauthorized", "Missing bearer token");
      await auth.logout(u.id, u.sesionId, b.refresh_token, b.all);
      res.code(204);
      return null;
    }
  );

  // ---------------------------------------------------------- recuperación --
  app.post("/auth/password/forgot", { config: ESTRICTO, schema: { body: cuerpo("passwordForgot") } }, async (req, res) => {
    const b = req.body as { email: string };
    const r = await auth.recuperacionInicio(b.email);
    res.code(202);
    return { data: r };
  });

  app.post("/auth/password/verify", { config: ESTRICTO, schema: { body: cuerpo("passwordVerify") } }, async (req) => {
    const b = req.body as { email: string; code: string };
    return { data: await auth.recuperacionVerificar(b.email, b.code) };
  });

  app.post("/auth/password/reset", { schema: { body: cuerpo("passwordReset") } }, async (req) => {
    const b = req.body as { reset_token: string; password: string };
    return { data: await auth.recuperacionAplicar(b.reset_token, b.password) };
  });
}
