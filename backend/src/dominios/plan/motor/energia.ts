/**
 * dominios/plan/motor/energia.ts — gasto energético de las sesiones.
 *
 * PORT LITERAL de EnergyCalculator.kt — constantes SIN VERIFICAR contra sus fuentes
 * (docs/PROPUESTA-MOTOR.md §2).
 *
 * Correr: ~1,036 kcal por kg y por km, casi independiente del ritmo. El resto: METs,
 * kcal/min = MET × 3,5 × kg / 200. El desnivel suma aparte, como trabajo vertical.
 *
 * ⚠️ Rareza del Kotlin, portada tal cual: su comentario dice que el costo por kilómetro es "para
 * correr", pero el código se lo aplica también al trekking.
 */
import { TIPOS, type Deporte, type Intensidad, type TipoDeSesion } from "./tipos.js";

const KCAL_POR_KG_Y_KM_CORRIENDO = 1.036;

/** metFor. En fuerza y "otro" la intensidad no cambia el MET; natación y triatlón comparten fila. */
const METS: Readonly<Record<Deporte, Readonly<Record<Intensidad, number>>>> = {
  running: { suave: 8.3, moderada: 10.0, fuerte: 12.8, competencia: 14.5 },
  ciclismo: { suave: 6.0, moderada: 8.5, fuerte: 11.0, competencia: 13.0 },
  trekking: { suave: 4.5, moderada: 6.0, fuerte: 7.5, competencia: 8.5 },
  natacion: { suave: 6.0, moderada: 8.3, fuerte: 10.0, competencia: 11.5 },
  triatlon: { suave: 6.0, moderada: 8.3, fuerte: 10.0, competencia: 11.5 },
  fuerza: { suave: 5.0, moderada: 5.0, fuerte: 5.0, competencia: 5.0 },
  otro: { suave: 6.0, moderada: 6.0, fuerte: 6.0, competencia: 6.0 },
};

export function metDe(deporte: Deporte, intensidad: Intensidad): number {
  return METS[deporte][intensidad];
}

/** kcalPerMinute. */
export function kcalPorMinuto(met: number, pesoKg: number): number {
  return (met * 3.5 * pesoKg) / 200.0;
}

/** sessionKcal: gasto de una sesión con distancia conocida (truncado). */
export function kcalDeSesion(
  deporte: Deporte,
  pesoKg: number,
  distanciaM: number,
  duracionSeg: number,
  desnivelM: number,
  intensidad: Intensidad = "moderada"
): number {
  const minutos = duracionSeg / 60.0;
  const km = distanciaM / 1000.0;
  const base =
    deporte === "running" || deporte === "trekking"
      ? KCAL_POR_KG_Y_KM_CORRIENDO * pesoKg * km
      : kcalPorMinuto(metDe(deporte, intensidad), pesoKg) * minutos;
  // Trabajo vertical: m·g·h con 23 % de eficiencia metabólica.
  const vertical = pesoKg * desnivelM * 0.0102;
  const piso = kcalPorMinuto(3.0, pesoKg) * minutos;
  return Math.trunc(Math.max(base + vertical, piso));
}

/**
 * plannedKcal: gasto estimado de una sesión planificada. Con distancia ya estimada, corriendo o
 * caminando usa el costo por km, que el Kotlin considera más preciso que un MET de ritmo fijo.
 */
export function kcalPlanificadas(
  deporte: Deporte,
  pesoKg: number,
  duracionMin: number,
  tipo: TipoDeSesion,
  distanciaKm: number | null = null
): number {
  if (tipo === "descanso") return 0;
  const intensidad: Intensidad = TIPOS[tipo].esCalidad ? "fuerte" : tipo === "regenerativo" ? "suave" : "moderada";
  const deporteEfectivo: Deporte = tipo === "fuerza" ? "fuerza" : deporte;
  if (distanciaKm !== null && distanciaKm > 0 && (deporteEfectivo === "running" || deporteEfectivo === "trekking")) {
    return kcalDeSesion(deporteEfectivo, pesoKg, distanciaKm * 1000, duracionMin * 60, 0.0, intensidad);
  }
  return Math.trunc(kcalPorMinuto(metDe(deporteEfectivo, intensidad), pesoKg) * duracionMin);
}

/** intensityFor: la intensidad de un tipo de sesión, para el plan de hidratación. */
export function intensidadDe(tipo: TipoDeSesion): Intensidad {
  switch (tipo) {
    case "regenerativo":
    case "descanso":
      return "suave";
    case "suave":
    case "fondo":
    case "fuerza":
      return "moderada";
    case "carrera":
      return "competencia";
    default:
      return "fuerte";
  }
}
