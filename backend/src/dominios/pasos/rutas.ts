/**
 * dominios/pasos — los pasos de cada día (contrato 1.3.0).
 *
 *   GET /v1/me/steps?from=YYYY-MM-DD&to=YYYY-MM-DD   los días con pasos del rango
 *   PUT /v1/me/steps                                  hasta 60 días, gana el más nuevo
 *
 * El teléfono los lee de Apple Salud (o Health Connect) y los sube; si no hay
 * permiso, los carga la persona a mano. Guardarlos acá deja ver el historial en
 * un teléfono nuevo, donde Salud todavía no tiene nada.
 *
 * Por qué "gana el más nuevo" y no "Salud le gana a lo manual": con permiso, la
 * app ya no deja editar a mano, así que una carga manual más nueva que la lectura
 * de Salud es una corrección deliberada —o de otro teléfono sin permiso— y no
 * hay por qué tirarla. Y la cuenta de hoy crece durante el día: cada lectura
 * nueva tiene que poder pisar a la anterior, venga de la fuente que venga.
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";
import { cuerpo, parametros } from "../../infra/esquemas.js";
import { crearIdempotencia, conIdempotencia } from "../../infra/idempotencia.js";
import { crearRepoPasos, pasosAApi } from "./repositorio.js";
import { normalizarLote, validarRango, type DiaDePasosEntrada } from "./validacion.js";

export async function rutasPasos(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const repo = crearRepoPasos(ctx.db);
  const idem = crearIdempotencia(ctx.db, ctx.ahoraMs);

  app.get("/me/steps", { preHandler: guardia, schema: parametros("getSteps") }, async (req) => {
    const { from, to } = req.query as { from: string; to: string };
    const { desde, hasta } = validarRango(from, to);
    const filas = await repo.delRango(usuarioDe(req), desde, hasta);
    return { data: filas.map(pasosAApi) };
  });

  app.put(
    "/me/steps",
    { preHandler: guardia, schema: { body: cuerpo("putSteps") } },
    conIdempotencia(idem, async (req) => {
      const { days } = req.body as { days: DiaDePasosEntrada[] };
      const lote = normalizarLote(days, ctx.ahoraMs());
      const filas = await repo.guardar(usuarioDe(req), lote);
      return { data: filas.map(pasosAApi) };
    })
  );
}
