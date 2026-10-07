/**
 * dominios/plan — GET /v1/plan y GET /v1/plan/routine
 *
 * El plan lo calcula el SERVIDOR (AGENTS.md §9.1 y §10) y el cliente lo muestra.
 * Esta capa sólo traduce: del plan del motor —fechas locales, nombres en
 * castellano— al contrato —milisegundos epoch, snake_case, textos traducidos—.
 */
import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { crearGuardia, usuarioDe } from "../auth/guardia.js";
import { calcularPlan, hechosDelBloque, calcularRacha, type HechoDelDia, type PlanCalculado } from "./servicio.js";
import { elegirRutina, textosDelHueco } from "./rutina.js";
import { textosDelDia } from "./motor/textos.js";
import type { DiaPlanificado } from "./motor/tipos.js";
import { crearRepoCatalogo } from "../catalogo/repositorio.js";
import { crearRepoGimnasio } from "../gimnasio/repositorio.js";
import { crearRepoObjetivos } from "../objetivos/repositorio.js";
import { parametros } from "../../infra/esquemas.js";
import { fechaLocal, inicioDelDiaMs } from "../../infra/fechas.js";
import { localeDe, nombreEn, type Locale } from "../../infra/idioma.js";

function diaAApi(d: DiaPlanificado, zona: string, locale: Locale, hecho: HechoDelDia | undefined) {
  const textos = textosDelDia(d, locale);
  const salida: Record<string, unknown> = {
    date_ms: inicioDelDiaMs(d.fecha, zona),
    day_index: d.indice,
    weekday: d.weekday,
    week_number: d.semana,
    phase: d.fase,
    type: d.tipo,
    sport: d.deporte,
    duration_min: d.duracionMin,
    is_deload_week: d.esSemanaDeDescarga,
    title: textos.titulo,
    detail: textos.detalle,
    reasons: d.motivos.map((code, i) => ({ code, text: textos.motivos[i] ?? "" })),
    done: d.tipo !== "descanso" && (hecho?.sesiones ?? 0) > 0,
  };
  // Lo que falta se omite (docs/API.md §7): sin peso no hay kcal, sin edad no hay pulso.
  const opcionales: ReadonlyArray<readonly [string, number | string | null]> = [
    ["scheduled_minute_of_day", d.minutoDelDia],
    ["distance_m", d.distanciaM],
    ["zone", d.zona],
    ["hr_low_bpm", d.fcMinLpm],
    ["hr_high_bpm", d.fcMaxLpm],
    ["pace_low_s_per_km", d.ritmoMinSegKm],
    ["pace_high_s_per_km", d.ritmoMaxSegKm],
    ["estimated_kcal", d.kcal],
  ];
  for (const [k, v] of opcionales) if (v !== null) salida[k] = v;
  const a = d.avituallamiento;
  if (a !== null) {
    salida["fueling"] = {
      fluid_ml_per_hour: a.liquidoMlPorHora,
      fluid_total_ml: a.liquidoTotalMl,
      sodium_mg_per_hour: a.sodioMgPorHora,
      sodium_total_mg: a.sodioTotalMg,
      carbs_g_per_hour: a.carbohidratosGPorHora,
      carbs_total_g: a.carbohidratosTotalG,
      gels: a.geles,
      pre_fluid_ml: a.preLiquidoMl,
      pre_carbs_g: a.preCarbohidratosG,
      post_fluid_ml: a.postLiquidoMl,
      post_carbs_g: a.postCarbohidratosG,
      post_protein_g: a.postProteinaG,
    };
  }
  return salida;
}

function planAApi(c: PlanCalculado, hechos: Map<string, HechoDelDia>, locale: Locale, hoyFecha: string) {
  const { plan, zona } = c;
  const streak = calcularRacha(plan.dias, hechos, hoyFecha);
  const semanaDe = new Map<number, { sesiones: number; metros: number }>();
  for (const d of plan.dias) {
    const h = hechos.get(d.fecha);
    if (h === undefined || d.tipo === "descanso") continue;
    const previo = semanaDe.get(d.semana) ?? { sesiones: 0, metros: 0 };
    semanaDe.set(d.semana, { sesiones: previo.sesiones + 1, metros: previo.metros + h.metros });
  }
  return {
    motor_version: plan.version,
    input_hash: c.hashEntrada,
    generated_at_ms: c.ancla.creado_en_ms,
    timezone: zona,
    locale,
    start_date_ms: inicioDelDiaMs(c.ancla.inicio_fecha, zona),
    event_date_ms: plan.fechaEvento === null ? null : inicioDelDiaMs(plan.fechaEvento, zona),
    total_weeks: plan.totalSemanas,
    goal: c.entrada.objetivo,
    phases: plan.fases.map((f) => ({ phase: f.fase, first_week: f.primeraSemana, last_week: f.ultimaSemana })),
    weeks: plan.semanas.map((s) => ({
      number: s.numero,
      phase: s.fase,
      start_date_ms: inicioDelDiaMs(s.inicio, zona),
      is_deload: s.esDescarga,
      planned_duration_min: s.minutosPrevistos,
      planned_distance_m: s.metrosPrevistos,
      done_sessions: semanaDe.get(s.numero)?.sesiones ?? 0,
      done_distance_m: semanaDe.get(s.numero)?.metros ?? 0,
    })),
    streak: {
      current: streak.dias,
      active_today: streak.activa_hoy,
      trained_today: streak.entrenado_hoy,
      scheduled_today: streak.toca_hoy,
    },
    days: plan.dias.map((d) => diaAApi(d, zona, locale, hechos.get(d.fecha))),
  };
}

export async function rutasPlan(app: FastifyInstance, ctx: Contexto): Promise<void> {
  const guardia = crearGuardia(ctx);
  const catalogo = crearRepoCatalogo(ctx.db);
  const gimnasio = crearRepoGimnasio(ctx.db);

  app.get("/plan", { preHandler: guardia }, async (req) => {
    const usuarioId = usuarioDe(req);
    const calculado = await calcularPlan(ctx, usuarioId);
    const hechos = await hechosDelBloque(ctx, usuarioId, calculado);
    const hoyFecha = fechaLocal(ctx.ahoraMs(), calculado.zona);
    return { data: planAApi(calculado, hechos, localeDe(req), hoyFecha) };
  });

  app.get("/plans", { preHandler: guardia }, async (req) => {
    const usuarioId = usuarioDe(req);
    const objetivos = await crearRepoObjetivos(ctx.db).listar(usuarioId);
    const data = [];
    for (const objetivo of objetivos) {
      const calculado = await calcularPlan(ctx, usuarioId, objetivo.id === "principal" ? null : objetivo.id);
      const hechos = await hechosDelBloque(ctx, usuarioId, calculado);
      data.push({
        goal_id: objetivo.id,
        plan: planAApi(calculado, hechos, localeDe(req), fechaLocal(ctx.ahoraMs(), calculado.zona)),
      });
    }
    return { data };
  });

  app.get("/plan/routine", { preHandler: guardia, schema: parametros("getRoutine") }, async (req) => {
    const usuarioId = usuarioDe(req);
    const { date_ms } = req.query as { date_ms: number };
    const locale = localeDe(req);

    const calculado = await calcularPlan(ctx, usuarioId);
    const { zona, perfil, plan } = calculado;
    const fecha = fechaLocal(date_ms, zona);
    const sesionId = `gym-${fecha}`;

    const equipamiento = Array.isArray(perfil.equipamiento)
      ? perfil.equipamiento.filter((e): e is string => typeof e === "string")
      : null;
    const { equipamientoAsumido, ejercicios } = elegirRutina(
      await catalogo.vigentes(),
      equipamiento,
      calculado.entrada.nivel
    );

    const previas = await gimnasio.ultimasSeriesPorEjercicio(
      usuarioId,
      ejercicios.map((e) => e.ejercicio.id),
      sesionId
    );

    return {
      data: {
        date_ms: inicioDelDiaMs(fecha, zona),
        session_id: sesionId,
        planned: plan.dias.find((d) => d.fecha === fecha)?.tipo === "fuerza",
        equipment_assumed: equipamientoAsumido,
        exercises: ejercicios.map((e) => {
          const textos = textosDelHueco(e.hueco, locale);
          return {
            exercise_id: e.ejercicio.id,
            name: nombreEn(e.ejercicio.nombres, locale, e.ejercicio.id),
            pattern: e.ejercicio.patron,
            equipment: e.ejercicio.equipamiento,
            unit: e.ejercicio.unidad,
            label: textos.etiqueta,
            reason: textos.motivo,
            rest_s: e.descansoS,
            sets: e.series.map((s) => ({ number: s.numero, reps: s.reps })),
            previous_sets: previas
              .filter((p) => p.ejercicio_id === e.ejercicio.id)
              .map((p) => {
                const salida: Record<string, unknown> = { number: p.numero, reps: p.repeticiones, skipped: p.salteada };
                if (p.peso_g !== null) salida["weight_g"] = p.peso_g;
                return salida;
              }),
          };
        }),
      },
    };
  });
}
