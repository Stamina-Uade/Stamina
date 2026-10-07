/**
 * dominios/perfil — GET y PATCH /v1/me
 *
 * 🛑 No existe `GET /users/{id}`. El único perfil que se puede pedir es el del
 * dueño del token, y el id sale del token, nunca de la ruta ni del cuerpo: es la
 * forma más simple de no tener un IDOR (AGENTS.md §12).
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearRepoPerfil, type PerfilFila } from "./repositorio.js";
import { cuerpo } from "../../infra/esquemas.js";
import { ErrorApi } from "../../infra/errores.js";
import { crearIdempotencia, conIdempotencia } from "../../infra/idempotencia.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";

export function perfilAApi(f: PerfilFila): Record<string, unknown> {
  const salida: Record<string, unknown> = {
    id: f.usuario_id,
    email: f.email,
    created_at_ms: f.creado_en_ms,
    updated_at_ms: f.actualizado_en_ms,
    training_days: Array.isArray(f.dias_entrenamiento) ? f.dias_entrenamiento : [],
  };
  const opcionales: ReadonlyArray<readonly [string, unknown]> = [
    ["first_name", f.nombre],
    ["last_name", f.apellido],
    ["birthdate_ms", f.nacimiento_ms],
    ["biological_sex", f.sexo_biologico],
    ["weight_g", f.peso_g],
    ["height_mm", f.altura_mm],
    ["sport", f.deporte],
    ["level", f.nivel],
    ["goal", f.objetivo],
    ["timezone", f.zona_horaria],
    ["unit_system", f.sistema_unidades],
    ["equipment", Array.isArray(f.equipamiento) ? f.equipamiento : null],
    ["pregnant_or_breastfeeding", f.embarazo_o_lactancia],
  ];
  // Un campo que no está se OMITE; no se manda null (docs/API.md §7).
  for (const [k, v] of opcionales) if (v !== null && v !== undefined) salida[k] = v;

  // Estos dos sí pueden ser null a propósito: "está y vale nada".
  salida["goal_date_ms"] = f.objetivo_fecha_ms;
  salida["medical_disclaimer_accepted_at_ms"] = f.descargo_medico_aceptado_en_ms;
  return salida;
}

export async function rutasPerfil(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const repo = crearRepoPerfil(ctx.db);
  // La guardia verifica el token Y que la sesión siga viva: un access vive 30
  // minutos y "cerrar sesión" tiene que significar algo antes de que venza.
  const guardia = crearGuardia(ctx);
  const idem = crearIdempotencia(ctx.db, ctx.ahoraMs);

  app.get("/me", { preHandler: guardia }, async (req) => {
    const fila = await repo.leer(usuarioDe(req));
    if (fila === null) throw new ErrorApi("not_found", "Profile not found");
    return { data: perfilAApi(fila) };
  });

  /**
   * Envuelto en `conIdempotencia` (AGENTS.md §5.2). Con `Idempotency-Key`, un
   * reintento devuelve la MISMA respuesta en vez de volver a escribir.
   *
   * Un PATCH de perfil es idempotente por naturaleza, así que acá se nota poco.
   * Está igual, y a propósito: fue la primera mutación autenticada de la API, y es
   * donde se probó de punta a punta el mecanismo que ahora protege lo que sí duele:
   * las series, las actividades y las comidas.
   */
  app.patch(
    "/me",
    { preHandler: guardia, schema: { body: cuerpo("updateMe") } },
    conIdempotencia(idem, async (req) => {
      const usuarioId = usuarioDe(req);
      await repo.guardar(usuarioId, req.body as Record<string, unknown>, ctx.ahoraMs());
      const fila = await repo.leer(usuarioId);
      if (fila === null) throw new ErrorApi("not_found", "Profile not found");
      return { data: perfilAApi(fila) };
    })
  );
}
