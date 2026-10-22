/**
 * dominios/cuenta — POST /v1/me/delete, POST /v1/me/deactivate y GET /v1/me/export
 *
 * AGENTS.md §8: "Exportar y borrar son features, no favores." Las dos bloqueaban
 * la publicación (docs/API.md §8) y las dos viven detrás de la guardia de sesión.
 *
 * Desde la 1.6.0 borrar deja 30 días de gracia: la cuenta queda marcada, se
 * cierran sus sesiones y la purga diaria la borra de verdad cuando vence el plazo.
 * Mientras tanto, entrar contesta `account_pending_deletion` y se puede recuperar.
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";
import { crearRepoCuenta } from "./repositorio.js";
import { cuerpo } from "../../infra/esquemas.js";
import { ErrorApi } from "../../infra/errores.js";
import { verificarDummy, verificarPassword } from "../../infra/cripto.js";
import { inicioDelDiaMs } from "../../infra/fechas.js";
import { crearRepoPerfil } from "../perfil/repositorio.js";
import { perfilAApi } from "../perfil/rutas.js";
import { filaASerie } from "../gimnasio/repositorio.js";
import { serieAApi } from "../gimnasio/rutas.js";
import { actividadAApi } from "../actividades/rutas.js";
import { comidaAApi } from "../nutricion/rutas.js";
import { crearRepoPasos, pasosAApi } from "../pasos/repositorio.js";

/** Contrato 1.6.0: cuánto espera una cuenta marcada antes de borrarse de verdad. */
export const GRACIA_BORRADO_MS = 30 * 24 * 60 * 60 * 1000;

export async function rutasCuenta(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const repo = crearRepoCuenta(ctx.db);
  const perfiles = crearRepoPerfil(ctx.db);
  const pasos = crearRepoPasos(ctx.db);

  app.post(
    "/me/delete",
    {
      preHandler: guardia,
      schema: { body: cuerpo("deleteMe") },
      // Es un chequeo de contraseña: el mismo límite estricto que el login.
      config: { rateLimit: { max: 8, timeWindow: "1 minute" } },
    },
    async (req, res) => {
      const usuarioId = usuarioDe(req);
      const { password } = (req.body ?? {}) as { password?: string };
      const hash = await repo.hashDePassword(usuarioId);
      if (hash === undefined) {
        // La cuenta ya no está. Se gasta lo mismo que en la rama buena (§12).
        await verificarDummy(password ?? "");
        throw new ErrorApi("invalid_credentials", "Password is not valid");
      }
      // Con contraseña, se pide: un access token robado no alcanza para borrar.
      if (hash !== null && (password === undefined || password.length === 0)) {
        await verificarDummy("");
        throw new ErrorApi("invalid_credentials", "Password is required");
      }
      // Una cuenta que nació con Google o Apple no tiene contraseña que pedir: la
      // sesión abierta es la prueba. Sin esto, esas cuentas no se podían borrar
      // (y la App Store exige poder borrarlas).
      if (hash !== null && !(await verificarPassword(password as string, hash))) {
        throw new ErrorApi("invalid_credentials", "Password is not valid");
      }
      const ahora = ctx.ahoraMs();
      await repo.marcarParaBorrar(usuarioId, ahora, ahora + GRACIA_BORRADO_MS);
      res.code(204);
      return null;
    }
  );

  /**
   * 1.6.0. No pide contraseña: no borra nada, y volver pide entrar de nuevo (con
   * contraseña o proveedor). Cierra TODAS las sesiones, la que pide incluida.
   */
  app.post("/me/deactivate", { preHandler: guardia }, async (req, res) => {
    await repo.desactivar(usuarioDe(req), ctx.ahoraMs());
    res.code(204);
    return null;
  });

  app.get(
    "/me/export",
    {
      preHandler: guardia,
      // Junta todo lo de la persona: es la consulta más cara de la API, y en una
      // máquina compartida no se deja repetir en bucle.
      config: { rateLimit: { max: 3, timeWindow: "1 minute" } },
    },
    async (req) => {
      const usuarioId = usuarioDe(req);
      const [perfil, legales, planes, objetivos, sesiones, series, actividades, comidas, diasDePasos] = await Promise.all([
        perfiles.leer(usuarioId),
        repo.aceptacionesLegales(usuarioId),
        repo.planes(usuarioId),
        repo.objetivos(usuarioId),
        repo.sesionesDeGimnasio(usuarioId),
        repo.seriesDeGimnasio(usuarioId),
        repo.actividades(usuarioId),
        repo.comidas(usuarioId),
        pasos.todos(usuarioId),
      ]);
      if (perfil === null) throw new ErrorApi("not_found", "Profile not found");

      const seriesPorSesion = new Map<string, ReturnType<typeof serieAApi>[]>();
      for (const s of series) {
        const lista = seriesPorSesion.get(s.sesion_id) ?? [];
        lista.push(serieAApi(filaASerie(s)));
        seriesPorSesion.set(s.sesion_id, lista);
      }

      return {
        data: {
          exported_at_ms: ctx.ahoraMs(),
          profile: perfilAApi(perfil),
          goals: objetivos.map((o) => ({
            id: o.id, goal: o.objetivo, goal_date_ms: o.objetivo_fecha_ms,
            order: o.orden, created_at_ms: o.creado_en_ms, completed_at_ms: o.completado_en_ms,
          })),
          legal_acceptances: legales.map((l) => ({ version: l.version, accepted_at_ms: l.aceptado_en_ms, reason: l.motivo })),
          plans: planes.map((p) => {
            const salida: Record<string, unknown> = {
              motor_version: p.motor_version,
              start_date_ms: inicioDelDiaMs(p.inicio_fecha, p.zona_horaria),
              timezone: p.zona_horaria,
              created_at_ms: p.creado_en_ms,
            };
            if (p.objetivo_id !== null) salida["goal_id"] = p.objetivo_id;
            if (p.reemplazado_en_ms !== null) salida["replaced_at_ms"] = p.reemplazado_en_ms;
            return salida;
          }),
          gym_sessions: sesiones.map((s) => ({
            session_id: s.sesion_id,
            updated_at_ms: s.actualizada_en_ms,
            sets: seriesPorSesion.get(s.sesion_id) ?? [],
          })),
          activities: actividades.map(actividadAApi),
          meals: comidas.map(comidaAApi),
          steps: diasDePasos.map(pasosAApi),
        },
      };
    }
  );
}
