/**
 * dominios/auth/rutas.ts — la capa web de auth. Sin SQL adentro (§4.4).
 *
 * La validación de cada cuerpo sale del CONTRATO: `esquemas.cuerpos[operationId]`
 * lo genera `scripts/generar-esquemas.mjs` desde shared/api/openapi.yaml. No hay
 * un esquema escrito a mano que pueda divergir del contrato (§4.2).
 */
import { isIP } from "node:net";
import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearServicioAuth, type Acceso } from "./servicio.js";
import type { Dispositivo } from "./dispositivos.js";
import { cuerpo } from "../../infra/esquemas.js";
import { crearHookAuth } from "../../infra/autenticacion.js";
import { ErrorApi } from "../../infra/errores.js";
import { crearRepoPerfil } from "../perfil/repositorio.js";
import { crearGuardia } from "./guardia.js";
import { idiomaDeCorreo } from "../../infra/idioma.js";
import { ubicacionDeCloudflare } from "../../infra/ubicacion.js";

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

/**
 * La IP que va en los correos de acceso. stamina.com.ar pasa por Cloudflare y
 * después por Apache: con `TRUST_PROXY=127.0.0.1`, `req.ip` es la del borde de
 * Cloudflare, no la de la persona. Cloudflare la manda en `cf-connecting-ip`, y
 * sólo se le cree detrás de un proxy de confianza (infra/ubicacion.ts). Es nada
 * más para mostrar: el rate limit sigue con `req.ip`.
 */
function ipDeLaPersona(req: FastifyRequest, detrasDeProxy: boolean): string {
  if (!detrasDeProxy) return req.ip;
  const crudo = req.headers["cf-connecting-ip"];
  const ip = (Array.isArray(crudo) ? crudo[0] : crudo)?.trim() ?? "";
  return isIP(ip) !== 0 ? ip : req.ip;
}

/**
 * Desde dónde se entra (contrato 1.7.0). `req.ip` ya respeta `TRUST_PROXY`
 * (servidor.ts): detrás del proxy es la IP de la persona, no la del proxy. La
 * ubicación sale de los headers de Cloudflare, y sólo detrás de un proxy de
 * confianza (infra/ubicacion.ts).
 */
function accesoDe(req: FastifyRequest, dispositivo: Dispositivo | undefined, detrasDeProxy: boolean): Acceso {
  const idioma = idiomaDeCorreo(req);
  return {
    ip: ipDeLaPersona(req, detrasDeProxy),
    idioma,
    ubicacion: ubicacionDeCloudflare(req.headers, idioma, detrasDeProxy),
    dispositivo: dispositivo ?? null,
  };
}

export async function rutasAuth(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const auth = crearServicioAuth(ctx);
  const perfiles = crearRepoPerfil(ctx.db);
  const requiereAuth = crearHookAuth(ctx.config);
  const guardia = crearGuardia(ctx);
  const detrasDeProxy = ctx.config.trustProxy !== false;

  // ------------------------------------------------------------- registro --
  app.post("/auth/register", { config: ESTRICTO, schema: { body: cuerpo("registerStart") } }, async (req, res) => {
    const b = req.body as { email: string; first_name?: string; last_name?: string };
    const r = await auth.registroInicio(b.email, b.first_name, b.last_name, idiomaDeCorreo(req));
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
      device?: Dispositivo;
    };
    // Una de las dos credenciales, nunca las dos ni ninguna (contrato 1.4.0).
    if ((b.password === undefined) === (b.social_token === undefined)) {
      throw new ErrorApi("bad_request", "Send exactly one of password or social_token");
    }
    if (b.password !== undefined && b.registration_token === undefined) {
      throw new ErrorApi("invalid_registration_token", "Registration token is required");
    }
    const credencial = b.password !== undefined ? { password: b.password } : { socialToken: b.social_token as string };
    const { sesion, usuarioId } = await auth.registroCompletar(
      b.registration_token, credencial, b.legal, accesoDe(req, b.device, detrasDeProxy));
    // El perfil se guarda en la misma operación: una cuenta sin perfil no le
    // sirve al motor del plan (AGENTS.md §9.1).
    await perfiles.guardar(usuarioId, b.profile, ctx.ahoraMs());
    res.code(201);
    return { data: sesion };
  });

  // ---------------------------------------------------------------- login --
  app.post("/auth/login", { config: ESTRICTO, schema: { body: cuerpo("login") } }, async (req) => {
    const b = req.body as { email: string; password: string; device?: Dispositivo };
    // La IP del pedido, para el tope de fallos por IP entre todos los correos.
    return { data: await auth.login(b.email, b.password, req.ip, accesoDe(req, b.device, detrasDeProxy)) };
  });

  // ------------------------------------------------------- Google y Apple --
  app.post("/auth/social", { config: ESTRICTO, schema: { body: cuerpo("socialSignIn") } }, async (req) => {
    const b = req.body as { provider: "google" | "apple"; id_token: string; nonce: string; device?: Dispositivo };
    return { data: await auth.entrarConProveedor(b.provider, b.id_token, b.nonce, accesoDe(req, b.device, detrasDeProxy)) };
  });

  // 1.6.0: vincular Google o Apple a una cuenta con contraseña (`account_link_available`).
  app.post("/auth/social/link", { config: ESTRICTO, schema: { body: cuerpo("socialLink") } }, async (req) => {
    const b = req.body as { link_token: string; password?: string; device?: Dispositivo };
    return { data: await auth.vincularConPassword(b.link_token, b.password, req.ip, accesoDe(req, b.device, detrasDeProxy)) };
  });

  // 1.6.0: volver a una cuenta desactivada o por borrarse.
  app.post("/auth/reactivate", { config: ESTRICTO, schema: { body: cuerpo("reactivateAccount") } }, async (req) => {
    const b = req.body as { reactivation_token: string; device?: Dispositivo };
    return { data: await auth.reactivar(b.reactivation_token, accesoDe(req, b.device, detrasDeProxy)) };
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

  // 1.6.0: cerrar las otras sesiones. Con la guardia completa (sesión viva): una
  // sesión ya revocada no decide cuáles quedan abiertas.
  app.post("/auth/logout/others", { preHandler: guardia }, async (req, res) => {
    const u = req.usuario;
    if (u === undefined) throw new ErrorApi("unauthorized", "Missing bearer token");
    await auth.cerrarOtrasSesiones(u.id, u.sesionId);
    res.code(204);
    return null;
  });

  // ---------------------------------------------------------- recuperación --
  app.post("/auth/password/forgot", { config: ESTRICTO, schema: { body: cuerpo("passwordForgot") } }, async (req, res) => {
    const b = req.body as { email: string };
    const r = await auth.recuperacionInicio(b.email, idiomaDeCorreo(req));
    res.code(202);
    return { data: r };
  });

  app.post("/auth/password/verify", { config: ESTRICTO, schema: { body: cuerpo("passwordVerify") } }, async (req) => {
    const b = req.body as { email: string; code: string };
    return { data: await auth.recuperacionVerificar(b.email, b.code) };
  });

  app.post("/auth/password/reset", { schema: { body: cuerpo("passwordReset") } }, async (req) => {
    const b = req.body as { reset_token: string; password: string; device?: Dispositivo };
    return { data: await auth.recuperacionAplicar(b.reset_token, b.password, accesoDe(req, b.device, detrasDeProxy)) };
  });
}
