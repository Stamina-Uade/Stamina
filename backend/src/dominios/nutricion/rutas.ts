/**
 * dominios/nutricion — el día de nutrición y las comidas.
 *
 *   GET    /v1/nutrition/day?date_ms=   objetivos del día y lo que se comió
 *   PUT    /v1/meals/{meal_id}          guardar una comida (idempotente por id)
 *   DELETE /v1/meals/{meal_id}          borrarla (soft, idempotente)
 *
 * 🛑 Los objetivos los calcula el servidor y pasan por la última puerta de
 * AGENTS.md §9.2 (objetivos.ts). El cliente no los recalcula ni los ajusta: los
 * muestra, o muestra por qué no hay.
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";
import { crearRepoComidas, type ComidaFila } from "./repositorio.js";
import { objetivosDelDia, type PersonaParaNutricion, type SesionParaNutricion } from "./objetivos.js";
import { calcularPlan } from "../plan/servicio.js";
import { crearRepoPerfil } from "../perfil/repositorio.js";
import { cuerpo, parametros } from "../../infra/esquemas.js";
import { ErrorApi } from "../../infra/errores.js";
import { diasEntre, edadEn, fechaLocal, inicioDelDiaMs, sumarDias, zonaValida } from "../../infra/fechas.js";

/** Los tipos que el plan viejo marcaba `isQuality` (Training.kt), en el vocabulario del contrato. */
const DE_CALIDAD = new Set(["tempo", "umbral", "series", "cuestas", "fartlek", "ritmo_carrera", "carrera"]);

export function comidaAApi(f: ComidaFila) {
  return {
    id: f.id,
    eaten_at_ms: f.comida_en_ms,
    name: f.nombre,
    kcal: f.kcal,
    carbs_g: f.carbohidratos_g,
    protein_g: f.proteina_g,
    fat_g: f.grasa_g,
    created_at_ms: f.creada_en_ms,
    updated_at_ms: f.actualizada_en_ms,
  };
}

interface ComidaEntrada {
  eaten_at_ms: number;
  name: string;
  kcal: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
}

export async function rutasNutricion(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const comidas = crearRepoComidas(ctx.db);
  const perfiles = crearRepoPerfil(ctx.db);

  app.get("/nutrition/day", { preHandler: guardia, schema: parametros("getNutritionDay") }, async (req) => {
    const usuarioId = usuarioDe(req);
    const { date_ms } = req.query as { date_ms: number };

    const perfil = await perfiles.leer(usuarioId);
    if (perfil === null) throw new ErrorApi("not_found", "Profile not found");
    const zona = perfil.zona_horaria;
    // Sin zona no hay "hoy": las 23:30 de alguien son el día siguiente de otro.
    if (zona === null || !zonaValida(zona)) {
      throw new ErrorApi("profile_incomplete", "Nutrition needs the profile timezone");
    }
    const fecha = fechaLocal(date_ms, zona);
    const desde = inicioDelDiaMs(fecha, zona);
    const hasta = inicioDelDiaMs(sumarDias(fecha, 1), zona);

    // Lo que el plan dice de ese día. Sin plan —perfil incompleto para el plan— el
    // día cuenta como descanso: los objetivos pueden salir igual.
    let sesion: SesionParaNutricion | null = null;
    let diasHastaEvento: number | null = null;
    let minutosDelEvento: number | null = null;
    try {
      const { plan } = await calcularPlan(ctx, usuarioId);
      const dia = plan.dias.find((d) => d.fecha === fecha);
      if (dia !== undefined && dia.tipo !== "descanso") {
        sesion = {
          duracionMin: dia.duracionMin,
          kcal: dia.kcal,
          esCalidad: DE_CALIDAD.has(dia.tipo),
          esCarrera: dia.tipo === "carrera",
        };
      }
      if (plan.fechaEvento !== null) {
        diasHastaEvento = diasEntre(fecha, plan.fechaEvento);
        minutosDelEvento = plan.dias.find((d) => d.tipo === "carrera")?.duracionMin ?? null;
      }
    } catch (e) {
      if (!(e instanceof ErrorApi && e.codigo === "profile_incomplete")) throw e;
    }

    const persona: PersonaParaNutricion = {
      pesoG: perfil.peso_g,
      alturaMm: perfil.altura_mm,
      edad: perfil.nacimiento_ms === null ? null : edadEn(perfil.nacimiento_ms, fecha),
      sexo: perfil.sexo_biologico as PersonaParaNutricion["sexo"],
      embarazoOLactancia: perfil.embarazo_o_lactancia,
      nivel: perfil.nivel as PersonaParaNutricion["nivel"],
    };
    const resultado = objetivosDelDia(persona, sesion, diasHastaEvento, minutosDelEvento);

    const delDia = await comidas.delDia(usuarioId, desde, hasta);
    const consumido = delDia.reduce(
      (t, c) => ({
        kcal: t.kcal + c.kcal,
        carbs_g: t.carbs_g + c.carbohidratos_g,
        protein_g: t.protein_g + c.proteina_g,
        fat_g: t.fat_g + c.grasa_g,
      }),
      { kcal: 0, carbs_g: 0, protein_g: 0, fat_g: 0 }
    );

    const data: Record<string, unknown> = { date_ms: desde, consumed: consumido, meals: delDia.map(comidaAApi) };
    if (resultado.ok) {
      const o = resultado.objetivos;
      const targets: Record<string, unknown> = {
        kcal: o.kcal,
        carbs_g: o.carbohidratosG,
        protein_g: o.proteinaG,
        fat_g: o.grasaG,
        water_ml: o.aguaMl,
        sodium_mg: o.sodioMg,
        day_load: o.carga,
        adjusted: o.ajustado,
        provisional: o.provisional,
      };
      if (o.motivoDelAjuste !== null) targets["adjustment_reason"] = o.motivoDelAjuste;
      data["targets"] = targets;
    } else {
      data["unavailable_reason"] = resultado.motivo;
    }
    return { data };
  });

  app.put(
    "/meals/:meal_id",
    { preHandler: guardia, schema: { ...parametros("putMeal"), body: cuerpo("putMeal") } },
    async (req) => {
      const usuarioId = usuarioDe(req);
      const { meal_id } = req.params as { meal_id: string };
      const b = req.body as ComidaEntrada;
      const fila = await comidas.guardar(
        usuarioId,
        meal_id,
        {
          comidaEnMs: b.eaten_at_ms,
          nombre: b.name,
          kcal: b.kcal,
          carbohidratosG: b.carbs_g,
          proteinaG: b.protein_g,
          grasaG: b.fat_g,
        },
        ctx.ahoraMs()
      );
      if (fila === null) throw new ErrorApi("not_found", "Meal was deleted");
      return { data: comidaAApi(fila) };
    }
  );

  app.delete("/meals/:meal_id", { preHandler: guardia, schema: parametros("deleteMeal") }, async (req, res) => {
    const usuarioId = usuarioDe(req);
    const { meal_id } = req.params as { meal_id: string };
    await comidas.borrar(usuarioId, meal_id, ctx.ahoraMs());
    res.code(204);
    return null;
  });
}
