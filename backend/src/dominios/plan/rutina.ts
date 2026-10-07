/**
 * dominios/plan/rutina.ts — la rutina de fuerza de un día.
 *
 * Es motor NUEVO: la app vieja no tenía gimnasio, así que no hay de dónde portarlo
 * (AGENTS.md §1.2). Sigue docs/PROPUESTA-MOTOR.md §4.4 al pie de la letra:
 *
 *   1. Filtro duro por EQUIPAMIENTO: lo que la persona no tiene, no existe. Sin
 *      equipamiento declarado se asume "ninguno" (§4.3).
 *   2. Lesiones: NO filtra. El mapeo lesión → articulación → exclusión es un
 *      criterio clínico que nadie definió, y un filtro con un criterio inventado es
 *      peor que ninguno (§4.4).
 *   3. Selección por PATRÓN de movimiento: la sesión pide un patrón y el patrón
 *      elige el ejercicio disponible. "No tengo mancuernas" cambia el ejercicio, no
 *      la forma de la sesión.
 *
 * Puro y determinístico: mismo catálogo, mismo equipamiento y mismo nivel, misma
 * rutina. Y 🛑 NO PRESCRIBE PESO: sin historial el motor no sabe qué carga es la
 * correcta, y adivinarla es la clase de número que lesiona. La carga la decide la
 * persona mirando la columna PREVIA.
 */
import type { EjercicioFila } from "../catalogo/repositorio.js";
import type { Nivel } from "./motor/tipos.js";
import type { Locale } from "../../infra/idioma.js";

export type Etiqueta = "para_correr" | "general";

export interface Hueco {
  patron: string;
  etiqueta: Etiqueta;
  motivo: "unilateral" | "cadena_posterior" | "tobillo" | "core" | "empuje" | "traccion";
}

/**
 * La forma de la sesión, en orden. Primero lo que protege al corredor —la
 * decisión de `HomeB.dc.html` de separar "Para correr" de "General"—, después lo
 * general. SIN VERIFICAR: es una propuesta de estructura, no una prescripción
 * revisada.
 */
export const HUECOS: readonly Hueco[] = [
  { patron: "rodilla-unilateral", etiqueta: "para_correr", motivo: "unilateral" },
  { patron: "cadera", etiqueta: "para_correr", motivo: "cadena_posterior" },
  { patron: "tobillo", etiqueta: "para_correr", motivo: "tobillo" },
  { patron: "antiextension", etiqueta: "para_correr", motivo: "core" },
  { patron: "empuje-horizontal", etiqueta: "general", motivo: "empuje" },
  { patron: "traccion-horizontal", etiqueta: "general", motivo: "traccion" },
];

/**
 * Series, repeticiones (o segundos) y descanso por nivel. SIN VERIFICAR: salen del
 * "3 series x 10-12 repeticiones" que la app vieja usaba para TODOS, abierto por
 * nivel hacia el lado prudente. Un solo lugar para cambiarlos.
 */
export const PRESCRIPCION: Readonly<Record<Nivel, { series: number; reps: number; segundos: number; descansoS: number }>> = {
  principiante: { series: 2, reps: 12, segundos: 30, descansoS: 60 },
  intermedio: { series: 3, reps: 10, segundos: 40, descansoS: 75 },
  avanzado: { series: 3, reps: 8, segundos: 45, descansoS: 90 },
};

export interface EjercicioElegido {
  ejercicio: EjercicioFila;
  hueco: Hueco;
  descansoS: number;
  series: Array<{ numero: number; reps: number }>;
}

export function elegirRutina(
  catalogo: readonly EjercicioFila[],
  equipamientoDeclarado: readonly string[] | null,
  nivel: Nivel
): { equipamientoAsumido: string[]; ejercicios: EjercicioElegido[] } {
  const declarado = (equipamientoDeclarado ?? []).filter((e) => e !== "ninguno");
  // "ninguno" siempre está: el peso corporal no hay que tenerlo.
  const permitido = new Set([...declarado, "ninguno"]);
  const usados = new Set<string>();
  const p = PRESCRIPCION[nivel];
  const ejercicios: EjercicioElegido[] = [];

  for (const hueco of HUECOS) {
    const elegido = catalogo
      .filter((e) => e.patron === hueco.patron && permitido.has(e.equipamiento) && !usados.has(e.id))
      // Con equipamiento declarado se usa ese; el peso corporal queda de respaldo.
      // Después, por id: el orden tiene que ser total para que la rutina no cambie sola.
      .sort((a, b) => rango(a) - rango(b) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))[0];
    // Un patrón sin ejercicio posible se saltea: una rutina más corta es mejor que
    // un ejercicio que la persona no puede hacer.
    if (elegido === undefined) continue;
    usados.add(elegido.id);
    const cantidad = elegido.unidad === "tiempo" ? p.segundos : p.reps;
    ejercicios.push({
      ejercicio: elegido,
      hueco,
      descansoS: p.descansoS,
      series: Array.from({ length: p.series }, (_, i) => ({ numero: i + 1, reps: cantidad })),
    });
  }

  return {
    equipamientoAsumido: declarado.length === 0 ? ["ninguno"] : [...declarado, "ninguno"],
    ejercicios,
  };
}

function rango(e: EjercicioFila): number {
  return e.equipamiento === "ninguno" ? 1 : 0;
}

// ------------------------------------------------------------------ textos --
// Contenido que arma el servidor, en los dos idiomas que se publican. Tono nunca
// punitivo (AGENTS.md §9.2): dice para qué sirve, no qué pasa si no se hace.

const ETIQUETAS: Record<Locale, Record<Etiqueta, string>> = {
  "es-AR": { para_correr: "Para correr", general: "General" },
  "en-US": { para_correr: "For running", general: "General" },
};

const MOTIVOS: Record<Locale, Record<Hueco["motivo"], string>> = {
  "es-AR": {
    unilateral: "Fuerza de a una pierna: menos desequilibrios, que es donde empiezan muchas molestias.",
    cadena_posterior: "Glúteos e isquiotibiales: son los que empujan en cada zancada.",
    tobillo: "Gemelos y sóleo: sostienen el tendón de Aquiles en las salidas largas.",
    core: "Un tronco estable gasta menos energía cuando llega el cansancio.",
    empuje: "Fuerza general de empuje, para equilibrar el cuerpo.",
    traccion: "Espalda alta: ayuda a sostener la postura al final de una salida.",
  },
  "en-US": {
    unilateral: "Single-leg strength: fewer imbalances, which is where many aches start.",
    cadena_posterior: "Glutes and hamstrings: they drive every stride.",
    tobillo: "Calves and soleus: they support the Achilles tendon on long runs.",
    core: "A stable trunk spends less energy when fatigue sets in.",
    empuje: "General pushing strength, to keep the body balanced.",
    traccion: "Upper back: helps you hold your posture late in a run.",
  },
};

export function textosDelHueco(hueco: Hueco, locale: Locale): { etiqueta: string; motivo: string } {
  return { etiqueta: ETIQUETAS[locale][hueco.etiqueta], motivo: MOTIVOS[locale][hueco.motivo] };
}
