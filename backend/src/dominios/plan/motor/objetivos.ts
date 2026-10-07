/**
 * dominios/plan/motor/objetivos.ts — del contrato a la persona que leía el Kotlin.
 *
 * PORT LITERAL de GoalType, FitnessLevel, Sport y UserProfile (Profile.kt) — constantes SIN
 * VERIFICAR contra sus fuentes (docs/PROPUESTA-MOTOR.md §2).
 *
 * Es el único lugar donde se cruzan los 7 objetivos cerrados del contrato
 * (shared/api/openapi.yaml, `Objetivo`) con los 10 GoalType del Kotlin:
 *
 *   c5k → RACE_5K · c10k → RACE_10K · media_maraton → RACE_21K · maraton → RACE_42K ·
 *   triatlon_olimpico → TRIATHLON_OLYMPIC · volver_sin_lesiones → GENERAL_FITNESS ·
 *   trail_montana → TREKKING_LONG, con otra distancia y otro deporte (DISTANCIA_TRAIL_KM).
 *
 * CYCLING_100K, CYCLING_GRANFONDO y TRIATHLON_SPRINT no tienen objetivo en el contrato, así que
 * no están. GoalType.minWeeks tampoco: el generador nunca lo leyó.
 *
 * Nivel: principiante / intermedio / avanzado = BEGINNER / INTERMEDIATE / ADVANCED.
 * Deporte: running / ciclismo / trekking / triatlon = RUNNING / CYCLING / TREKKING / TRIATHLON.
 * Las tablas del motor van indexadas directo por esos valores del contrato.
 */
import type {
  DiaDeEntrenamiento,
  DeportePerfil,
  EntradaDelMotor,
  GoalTypeKotlin,
  MetaDelMotor,
  Nivel,
  Objetivo,
  PerfilDelMotor,
} from "./tipos.js";

/** GoalType de Profile.kt: deporte, distancia y estimatedEventMinutes por nivel. */
const GOAL_TYPES: Readonly<Record<GoalTypeKotlin, Omit<MetaDelMotor, "goalType">>> = {
  RACE_5K: { deporte: "running", distanciaKm: 5.0, minutosDelEvento: { principiante: 35, intermedio: 27, avanzado: 21 } },
  RACE_10K: { deporte: "running", distanciaKm: 10.0, minutosDelEvento: { principiante: 72, intermedio: 55, avanzado: 43 } },
  RACE_21K: { deporte: "running", distanciaKm: 21.097, minutosDelEvento: { principiante: 160, intermedio: 122, avanzado: 95 } },
  RACE_42K: { deporte: "running", distanciaKm: 42.195, minutosDelEvento: { principiante: 330, intermedio: 255, avanzado: 200 } },
  TREKKING_LONG: { deporte: "trekking", distanciaKm: 20.0, minutosDelEvento: { principiante: 360, intermedio: 300, avanzado: 240 } },
  TRIATHLON_OLYMPIC: { deporte: "triatlon", distanciaKm: 51.5, minutosDelEvento: { principiante: 200, intermedio: 165, avanzado: 130 } },
  GENERAL_FITNESS: { deporte: "running", distanciaKm: 10.0, minutosDelEvento: { principiante: 60, intermedio: 60, avanzado: 60 } },
};

const GOAL_TYPE_DEL_OBJETIVO: Readonly<Record<Objetivo, GoalTypeKotlin>> = {
  c5k: "RACE_5K",
  c10k: "RACE_10K",
  media_maraton: "RACE_21K",
  maraton: "RACE_42K",
  trail_montana: "TREKKING_LONG",
  triatlon_olimpico: "TRIATHLON_OLYMPIC",
  volver_sin_lesiones: "GENERAL_FITNESS",
};

/**
 * 🆕 Decisión NUEVA, no está en el Kotlin (tomada en el pedido del port, 2026-09-10): el trail
 * de montaña se planifica como TREKKING_LONG —su volumen pico y sus minutos de evento por nivel—
 * pero a 21 km en vez de 20, y en el deporte del PERFIL en vez de TREKKING: quien eligió running
 * corre el trail, no lo camina.
 *
 * ⚠️ La pantalla de objetivo de la app le muestra a la persona "25-50 km" para el trail
 * (android/app/src/main/res/values/strings_acceso.xml, perf_obj_trail_dist). Uno de los dos
 * números está mal, y no le toca decidirlo a un port.
 */
export const DISTANCIA_TRAIL_KM = 21;

const NIVELES: readonly string[] = ["principiante", "intermedio", "avanzado"] satisfies Nivel[];
const DEPORTES: readonly string[] = ["running", "ciclismo", "trekking", "triatlon"] satisfies DeportePerfil[];

/** El GoalType de un objetivo del contrato, ya resuelto para el deporte de la persona. */
export function metaDelObjetivo(objetivo: Objetivo, deporte: DeportePerfil): MetaDelMotor {
  const goalType = GOAL_TYPE_DEL_OBJETIVO[objetivo];
  // Fuera de la unión sólo se llega desde JavaScript sin tipos: mejor fallar acá que devolver un
  // plan lleno de NaN.
  if (goalType === undefined) throw new RangeError(`objetivo desconocido: "${objetivo}"`);
  const datos = GOAL_TYPES[goalType];
  if (objetivo === "trail_montana") return { goalType, ...datos, deporte, distanciaKm: DISTANCIA_TRAIL_KM };
  return { goalType, ...datos };
}

/**
 * UserProfile.maxHr: Tanaka, 208 − 0,7 × edad, truncado. El contrato no tiene maxHrOverride.
 * Sin edad no hay nada que estimar: null, y el plan sale sin pulsaciones.
 */
export function fcMaximaEstimada(edad: number | null): number | null {
  return edad === null ? null : Math.trunc(208 - 0.7 * edad);
}

/**
 * trainingSchedule era un Map<DayOfWeek, Int>: no podía traer un día dos veces, y
 * `trainingDays` lo recorría de lunes a domingo. La lista del contrato sí puede venir repetida o
 * desordenada, así que se normaliza a lo mismo: gana la primera aparición de cada día.
 */
function normalizarAgenda(dias: readonly DiaDeEntrenamiento[]): Map<number, number> {
  const primeros = new Map<number, number>();
  for (const { weekday, minuteOfDay } of dias) {
    if (!Number.isInteger(weekday) || weekday < 1 || weekday > 7) {
      throw new RangeError(`weekday fuera de rango: ${weekday} (ISO, 1 a 7)`);
    }
    if (!Number.isInteger(minuteOfDay) || minuteOfDay < 0 || minuteOfDay > 1439) {
      throw new RangeError(`minuteOfDay fuera de rango: ${minuteOfDay} (0 a 1439)`);
    }
    if (!primeros.has(weekday)) primeros.set(weekday, minuteOfDay);
  }
  return new Map([...primeros].sort(([a], [b]) => a - b));
}

/** La entrada del contrato, como UserProfile. */
export function perfilDelMotor(entrada: EntradaDelMotor): PerfilDelMotor {
  if (!NIVELES.includes(entrada.nivel)) throw new RangeError(`nivel desconocido: "${entrada.nivel}"`);
  if (!DEPORTES.includes(entrada.deporte)) throw new RangeError(`deporte desconocido: "${entrada.deporte}"`);
  const { pesoG, edad } = entrada;
  if (pesoG !== null && !(Number.isFinite(pesoG) && pesoG > 0)) throw new RangeError(`pesoG inválido: ${pesoG}`);
  if (edad !== null && !(Number.isInteger(edad) && edad >= 0)) throw new RangeError(`edad inválida: ${edad}`);
  return {
    objetivo: entrada.objetivo,
    meta: metaDelObjetivo(entrada.objetivo, entrada.deporte),
    nivel: entrada.nivel,
    deportePrincipal: entrada.deporte,
    // Sin peso, el plan de entrenamiento sale igual; lo que no sale es lo que se calcula por kilo
    // (kcal y avituallamiento). docs/PROPUESTA-MOTOR.md §4.3.
    pesoKg: pesoG === null ? null : pesoG / 1000,
    fcMaxima: fcMaximaEstimada(edad),
    sexo: entrada.sexo,
    // El contrato no tiene dónde guardar estos cuatro: van los valores por defecto de UserProfile
    // (sudor MEDIUM, intestino 2, sin tasa de sudor medida, sin marca de referencia).
    salinidad: "media",
    nivelIntestinal: 2,
    tasaDeSudorMedidaLh: null,
    marca: null,
    agenda: normalizarAgenda(entrada.dias),
  };
}
