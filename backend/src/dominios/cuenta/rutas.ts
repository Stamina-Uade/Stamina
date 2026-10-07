/**
 * dominios/cuenta — POST /v1/me/delete y GET /v1/me/export
 *
 * AGENTS.md §8: "Exportar y borrar son features, no favores." Las dos bloqueaban
 * la publicación (docs/API.md §8) y las dos viven detrás de la guardia de sesión.
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

export async function rutasCuenta(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const repo = crearRepoCuenta(ctx.db);
  const perfiles = crearRepoPerfil(ctx.db);

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
      const { password } = req.body as { password: string };
      const hash = await repo.hashDePassword(usuarioId);
      if (hash === null) {
        // La cuenta ya no está. Se gasta lo mismo que en la rama buena (§12).
        await verificarDummy(password);
        throw new ErrorApi("invalid_credentials", "Password is not valid");
      }
      if (!(await verificarPassword(password, hash))) {
        throw new ErrorApi("invalid_credentials", "Password is not valid");
      }
      await repo.borrar(usuarioId, ctx.ahoraMs());
      res.code(204);
      return null;
    }
  );

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
      const [perfil, legales, planes, objetivos, sesiones, series, actividades, comidas] = await Promise.all([
        perfiles.leer(usuarioId),
        repo.aceptacionesLegales(usuarioId),
        repo.planes(usuarioId),
        repo.objetivos(usuarioId),
        repo.sesionesDeGimnasio(usuarioId),
        repo.seriesDeGimnasio(usuarioId),
        repo.actividades(usuarioId),
        repo.comidas(usuarioId),
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
        },
      };
    }
  );
}
