/**
 * dominios/plan/motor/textos.ts — el título, el detalle y los porqués de un día, en dos idiomas.
 *
 * PORT LITERAL de los textos de TrainingPlanGenerator.kt (titleFor, descriptionFor, restWorkout,
 * raceWorkout y los consejos de combustible) y de las etiquetas de Training.kt y Profile.kt —
 * constantes SIN VERIFICAR contra sus fuentes (docs/PROPUESTA-MOTOR.md §2).
 *
 * Excepción c) del port: en el Kotlin el generador escribía en castellano. Acá devuelve datos y
 * códigos, y este archivo los vuelve palabras. es-AR son los textos del Kotlin letra por letra
 * —con su "usála"—; en-US es su traducción. El detalle es la descripción del Kotlin, y en su
 * última línea, el consejo de combustible.
 *
 * Lo que NO viene del Kotlin, y nadie revisó todavía: los textos de los motivos (el Kotlin no
 * explicaba nada), los consejos sin peso y la zona sin pulsaciones —cuando falta el dato se dice
 * lo mismo sin el número—, y toda la traducción al inglés.
 *
 * 🛑 El tono nunca es punitivo (AGENTS.md §9.2): ningún texto reta, compara ni cuenta lo que
 * faltó. Vale para cada string que se agregue acá.
 */
import { SEMANAS_DEL_BLOQUE_GENERICO, SEMANAS_ENTRE_DESCARGAS, SEMANAS_MAXIMAS } from "./generador.js";
import {
  acotar,
  type Avituallamiento,
  type CodigoDeMotivo,
  type DeporteDeSesion,
  type DiaPlanificado,
  type Locale,
  type Objetivo,
  type TipoDeSesion,
  type Zona,
} from "./tipos.js";

interface Diccionario {
  /** Sport.label */
  readonly deporte: Readonly<Record<DeporteDeSesion, string>>;
  /** WorkoutType.label */
  readonly tipo: Readonly<Record<TipoDeSesion, string>>;
  /** HrZone.label */
  readonly zona: Readonly<Record<Zona, string>>;
  /** GoalType.label, salvo trail y volver (ver OBJETIVO_ES). */
  readonly objetivo: Readonly<Record<Objetivo, string>>;
  readonly objetivoDesconocido: string;
  readonly motivo: Readonly<Record<CodigoDeMotivo, string>>;
  readonly titulo: {
    readonly descanso: string;
    readonly evento: (objetivo: string) => string;
    readonly fuerza: (min: number) => string;
    readonly fondo: (deporte: DeporteDeSesion, min: number) => string;
    readonly regenerativo: (min: number) => string;
    readonly suave: (deporte: DeporteDeSesion, min: number) => string;
    readonly calidad: (tipo: TipoDeSesion, deporte: DeporteDeSesion, min: number) => string;
  };
  readonly cuerpo: {
    readonly descanso: string;
    readonly evento: (objetivo: string, ritmo: string, horas: number, minutos: number) => string;
    readonly suave: string;
    readonly regenerativo: string;
    readonly fondo: string;
    readonly tempo: (bloqueMin: number) => string;
    readonly umbral: (repeticiones: number) => string;
    readonly series: (repeticiones: number) => string;
    readonly cuestas: (repeticiones: number) => string;
    readonly fartlek: string;
    readonly ritmoCarrera: (bloqueMin: number) => string;
    readonly fuerza: string;
  };
  readonly zonaYRitmo: (zona: Zona, fc: readonly [number, number] | null, ritmo: readonly [string, string] | null) => string;
  /** El fuelingTip del Kotlin. */
  readonly consejo: {
    readonly descanso: string;
    readonly evento: (a: Avituallamiento | null) => string;
    readonly fuerza: (a: Avituallamiento | null) => string;
    readonly corta: (a: Avituallamiento | null) => string;
    readonly larga: (a: Avituallamiento | null) => string;
  };
}

// ─── es-AR: los textos del Kotlin ───────────────────────────────────────────────────────────

const DEPORTE_ES: Readonly<Record<DeporteDeSesion, string>> = {
  running: "Running",
  ciclismo: "Ciclismo",
  trekking: "Trekking",
  natacion: "Natación",
  fuerza: "Fuerza",
  otro: "Otro",
};

const TIPO_ES: Readonly<Record<TipoDeSesion, string>> = {
  descanso: "Descanso",
  regenerativo: "Regenerativo",
  suave: "Rodaje suave",
  fondo: "Fondo largo",
  tempo: "Tempo",
  umbral: "Umbral",
  series: "Series / VO2",
  cuestas: "Cuestas",
  fartlek: "Fartlek",
  ritmo_carrera: "Ritmo de carrera",
  fuerza: "Fuerza",
  carrera: "Competencia",
};

/**
 * Los cinco primeros y el triatlón son GoalType.label. Trail y volver no: sus GoalType se
 * llamaban "Trekking de montaña" y "Estado físico general", que no son lo que la persona eligió.
 * Van con el nombre de la pantalla de objetivo (strings_acceso.xml, perf_obj_trail y
 * perf_obj_volver).
 */
const OBJETIVO_ES: Readonly<Record<Objetivo, string>> = {
  c5k: "5K",
  c10k: "10K",
  media_maraton: "Media maratón",
  maraton: "Maratón",
  trail_montana: "Trail de montaña",
  triatlon_olimpico: "Triatlón olímpico",
  volver_sin_lesiones: "Volver a entrenar sin lesiones",
};

const ZONA_ES: Readonly<Record<Zona, string>> = {
  z1: "Z1 Recuperación",
  z2: "Z2 Base aeróbica",
  z3: "Z3 Tempo",
  z4: "Z4 Umbral",
  z5: "Z5 VO2 máx",
};

const ES_AR: Diccionario = {
  deporte: DEPORTE_ES,
  tipo: TIPO_ES,
  zona: ZONA_ES,
  objetivo: OBJETIVO_ES,
  objetivoDesconocido: "tu evento",
  motivo: {
    fase_base: "Fase de base: construir volumen aeróbico y resistir sin fatiga.",
    fase_construccion: "Fase de construcción: sumar calidad con umbral, series y ritmo objetivo.",
    fase_pico: "Fase de pico: la carga más específica del evento.",
    fase_afinamiento: "Afinamiento: bajar el volumen, mantener la intensidad y llegar fresco.",
    dia_del_evento: "Es la fecha que elegiste para tu evento.",
    objetivo_c5k: "Tu objetivo: 5K.",
    objetivo_c10k: "Tu objetivo: 10K.",
    objetivo_media_maraton: "Tu objetivo: media maratón.",
    objetivo_maraton: "Tu objetivo: maratón.",
    objetivo_trail_montana: "Tu objetivo: trail de montaña.",
    objetivo_triatlon_olimpico: "Tu objetivo: triatlón olímpico.",
    objetivo_volver_sin_lesiones: "Tu objetivo: volver a entrenar sin lesiones.",
    semana_de_descarga: `Semana de descarga: cada ${SEMANAS_ENTRE_DESCARGAS} semanas baja el volumen, para que el cuerpo asimile lo entrenado.`,
    fondo_en_fin_de_semana: "El fondo largo va al fin de semana.",
    fondo_en_el_ultimo_dia_elegido: "Tu semana no tiene sábado ni domingo, así que el fondo largo va a tu último día.",
    fondo_unico_dia_elegido: "Con un solo día por semana, ese día es el fondo largo.",
    calidad_con_mas_descanso_previo: "La sesión de calidad va al día con más descanso antes.",
    segunda_calidad_lejos_de_la_primera: "La segunda sesión de calidad va lo más lejos posible de la primera y del fondo.",
    segunda_calidad_suave_en_afinamiento: "En el afinamiento, la segunda sesión de calidad pasa a ser suave.",
    regenerativo_despues_del_fondo: "El día después del fondo es regenerativo.",
    fuerza_antes_del_fondo: "La fuerza va al día libre más cercano antes del fondo.",
    suave_en_los_dias_restantes: "Tus otros días son suaves: la mayor parte del volumen va en zona aeróbica.",
    triatlon_rota_deportes:
      "En triatlón se rotan los deportes: fondo y calidad en bici, la segunda calidad nadando, y los días suaves corriendo.",
    dia_no_elegido: "No es uno de los días que elegiste para entrenar: toca descansar.",
    sin_fecha_bloque_generico: `Sin fecha de evento, el plan es un bloque de ${SEMANAS_DEL_BLOQUE_GENERICO} semanas.`,
    fecha_objetivo_fuera_de_rango: `La fecha de tu objetivo ya pasó o está a más de ${SEMANAS_MAXIMAS} semanas, así que por ahora el plan es un bloque de ${SEMANAS_DEL_BLOQUE_GENERICO} semanas.`,
  },
  titulo: {
    descanso: "Descanso",
    evento: (objetivo) => objetivo,
    fuerza: (min) => `Fuerza para corredores (${min} min)`,
    fondo: (deporte, min) => `${DEPORTE_ES[deporte]}: fondo largo (${min} min)`,
    regenerativo: (min) => `Regenerativo suave (${min} min)`,
    suave: (deporte, min) => `${DEPORTE_ES[deporte]} suave (${min} min)`,
    calidad: (tipo, deporte, min) => `${TIPO_ES[tipo]} · ${DEPORTE_ES[deporte]} (${min} min)`,
  },
  cuerpo: {
    descanso:
      "Día libre. Movilidad suave, elongación y buen descanso nocturno: la adaptación ocurre cuando descansás, no mientras entrenás.",
    evento: (objetivo, ritmo, horas, minutos) =>
      `Objetivo: ${objetivo}. Ritmo estimado ${ritmo} min/km para un tiempo aproximado de ${horas} h ${minutos} min. ` +
      "Salí conservador los primeros kilómetros y respetá el plan de hidratación desde el minuto uno.",
    suave:
      "Rodaje continuo en zona aeróbica. Deberías poder mantener una conversación completa. Cerrá con 4 progresiones de 20 segundos.",
    regenerativo: "Trote muy suave o bici liviana. El objetivo es mover la sangre, no entrenar.",
    fondo:
      "Fondo continuo a ritmo cómodo. Es la sesión clave de la semana: usála también para ensayar tu estrategia de hidratación y geles tal como la usarías en carrera.",
    tempo: (bloque) => `15 min de entrada en calor + ${bloque} min continuos a ritmo tempo + 10 min de vuelta a la calma.`,
    umbral: (reps) => `15 min de entrada en calor + ${reps} x 8 min a ritmo umbral con 2 min de trote + 10 min suaves.`,
    series: (reps) =>
      `15 min de entrada en calor + ${reps} x 3 min fuertes con 2 min de trote de recuperación + 10 min de vuelta a la calma.`,
    cuestas: (reps) =>
      `15 min de entrada en calor + ${reps} x 60 seg en subida al 5-8% bajando trotando + 10 min suaves. ` +
      "Trabaja fuerza específica sin impacto excesivo.",
    fartlek: "15 min suaves + 20 min de juego de ritmos (1 min fuerte / 2 min suave) + 10 min de vuelta a la calma.",
    ritmoCarrera: (bloque) =>
      `15 min de entrada en calor + ${bloque} min a ritmo objetivo de carrera + 10 min suaves. ` +
      "Ensayá con la ropa y los geles que vas a usar el día del evento.",
    fuerza:
      "Circuito de fuerza: sentadillas, estocadas, puente de glúteo, plancha y trabajo excéntrico de gemelos e isquiotibiales. " +
      "3 series x 10-12 repeticiones. Reduce el riesgo de lesión por sobrecarga.",
  },
  zonaYRitmo: (zona, fc, ritmo) =>
    `Zona ${ZONA_ES[zona]}${fc === null ? "" : ` (${fc[0]}-${fc[1]} ppm)`}` +
    (ritmo === null ? "" : ` · Ritmo ${ritmo[0]} - ${ritmo[1]} min/km`),
  consejo: {
    // ⚠️ Es un consejo de nutrición del Kotlin, sin números pero sin revisar (AGENTS.md §9.2).
    descanso: "Día de menor carga: bajá los hidratos y sostené la proteína e hidratación.",
    evento: (a) =>
      a === null
        ? "En carrera: tomá desde el minuto uno y sumá sodio e hidratos. Desayuná con hidratos 3 h antes."
        : `En carrera: ${a.liquidoMlPorHora} ml/h, ${a.sodioMgPorHora} mg de sodio/h y ${a.carbohidratosGPorHora} g de hidratos/h. ` +
          `Desayuno 3 h antes con ${a.preCarbohidratosG} g de hidratos.`,
    fuerza: (a) =>
      a === null ? "Proteína dentro de la hora posterior." : `Proteína dentro de la hora posterior (${a.postProteinaG} g).`,
    corta: (a) =>
      a === null ? "Agua a demanda. No hacen falta geles." : `Agua a demanda (${a.liquidoMlPorHora} ml/h). No hacen falta geles.`,
    larga: (a) =>
      a === null
        ? "Llevá agua, hidratos y sodio."
        : `Llevá ${a.liquidoTotalMl} ml, ${a.carbohidratosTotalG} g de hidratos y ${a.sodioTotalMg} mg de sodio.`,
  },
};

// ─── en-US: la traducción ───────────────────────────────────────────────────────────────────

const DEPORTE_EN: Readonly<Record<DeporteDeSesion, string>> = {
  running: "Running",
  ciclismo: "Cycling",
  trekking: "Trekking",
  natacion: "Swimming",
  fuerza: "Strength",
  otro: "Other",
};

const TIPO_EN: Readonly<Record<TipoDeSesion, string>> = {
  descanso: "Rest",
  regenerativo: "Recovery",
  suave: "Easy run",
  fondo: "Long run",
  tempo: "Tempo",
  umbral: "Threshold",
  series: "Intervals / VO2",
  cuestas: "Hills",
  fartlek: "Fartlek",
  ritmo_carrera: "Race pace",
  fuerza: "Strength",
  carrera: "Race",
};

const ZONA_EN: Readonly<Record<Zona, string>> = {
  z1: "Z1 Recovery",
  z2: "Z2 Aerobic base",
  z3: "Z3 Tempo",
  z4: "Z4 Threshold",
  z5: "Z5 VO2 max",
};

const EN_US: Diccionario = {
  deporte: DEPORTE_EN,
  tipo: TIPO_EN,
  zona: ZONA_EN,
  objetivo: {
    c5k: "5K",
    c10k: "10K",
    media_maraton: "Half marathon",
    maraton: "Marathon",
    trail_montana: "Mountain trail",
    triatlon_olimpico: "Olympic triathlon",
    volver_sin_lesiones: "Get back to training injury-free",
  },
  objetivoDesconocido: "your event",
  motivo: {
    fase_base: "Base phase: build aerobic volume and endurance without fatigue.",
    fase_construccion: "Build phase: add quality with threshold work, intervals and goal pace.",
    fase_pico: "Peak phase: the most event-specific load.",
    fase_afinamiento: "Taper: less volume, the same intensity, so you arrive fresh.",
    dia_del_evento: "This is the date you chose for your event.",
    objetivo_c5k: "Your goal: 5K.",
    objetivo_c10k: "Your goal: 10K.",
    objetivo_media_maraton: "Your goal: half marathon.",
    objetivo_maraton: "Your goal: marathon.",
    objetivo_trail_montana: "Your goal: mountain trail.",
    objetivo_triatlon_olimpico: "Your goal: Olympic triathlon.",
    objetivo_volver_sin_lesiones: "Your goal: get back to training injury-free.",
    semana_de_descarga: `Recovery week: every ${SEMANAS_ENTRE_DESCARGAS} weeks the volume drops, so your body can absorb the training.`,
    fondo_en_fin_de_semana: "The long session goes on the weekend.",
    fondo_en_el_ultimo_dia_elegido: "Your week has no Saturday or Sunday, so the long session goes on your last day.",
    fondo_unico_dia_elegido: "With one day a week, that day is the long session.",
    calidad_con_mas_descanso_previo: "The quality session goes on the day with the most rest before it.",
    segunda_calidad_lejos_de_la_primera:
      "The second quality session goes as far as possible from the first one and from the long session.",
    segunda_calidad_suave_en_afinamiento: "During the taper, the second quality session becomes an easy one.",
    regenerativo_despues_del_fondo: "The day after the long session is for recovery.",
    fuerza_antes_del_fondo: "Strength goes on the closest free day before the long session.",
    suave_en_los_dias_restantes: "Your other days are easy: most of the volume stays in the aerobic zone.",
    triatlon_rota_deportes:
      "Triathlon rotates sports: long and quality sessions on the bike, the second quality session swimming, and easy days running.",
    dia_no_elegido: "This isn't one of the days you chose to train: time to rest.",
    sin_fecha_bloque_generico: `With no event date, the plan is a block of ${SEMANAS_DEL_BLOQUE_GENERICO} weeks.`,
    fecha_objetivo_fuera_de_rango: `Your goal date has passed or is more than ${SEMANAS_MAXIMAS} weeks away, so for now the plan is a block of ${SEMANAS_DEL_BLOQUE_GENERICO} weeks.`,
  },
  titulo: {
    descanso: "Rest",
    evento: (objetivo) => objetivo,
    fuerza: (min) => `Strength for runners (${min} min)`,
    fondo: (deporte, min) => `${DEPORTE_EN[deporte]}: long session (${min} min)`,
    regenerativo: (min) => `Easy recovery (${min} min)`,
    suave: (deporte, min) => `Easy ${DEPORTE_EN[deporte].toLowerCase()} (${min} min)`,
    calidad: (tipo, deporte, min) => `${TIPO_EN[tipo]} · ${DEPORTE_EN[deporte]} (${min} min)`,
  },
  cuerpo: {
    descanso:
      "Day off. Gentle mobility, stretching and a good night's sleep: adaptation happens while you rest, not while you train.",
    evento: (objetivo, ritmo, horas, minutos) =>
      `Goal: ${objetivo}. Estimated pace ${ritmo} min/km, for a time of about ${horas} h ${minutos} min. ` +
      "Start conservatively over the first kilometers and follow your hydration plan from minute one.",
    suave:
      "Continuous easy run in the aerobic zone. You should be able to hold a full conversation. Finish with 4 x 20-second strides.",
    regenerativo: "Very easy jog or a light spin on the bike. The goal is to get the blood moving, not to train.",
    fondo:
      "Continuous long session at a comfortable pace. It's the key session of the week: also use it to rehearse your hydration and gel strategy just as you would on race day.",
    tempo: (bloque) => `15 min warm-up + ${bloque} min continuous at tempo pace + 10 min cool-down.`,
    umbral: (reps) => `15 min warm-up + ${reps} x 8 min at threshold pace with 2 min jogging + 10 min easy.`,
    series: (reps) => `15 min warm-up + ${reps} x 3 min hard with 2 min recovery jog + 10 min cool-down.`,
    cuestas: (reps) =>
      `15 min warm-up + ${reps} x 60 s uphill at 5-8%, jogging back down + 10 min easy. ` +
      "Builds specific strength without excessive impact.",
    fartlek: "15 min easy + 20 min of speed play (1 min hard / 2 min easy) + 10 min cool-down.",
    ritmoCarrera: (bloque) =>
      `15 min warm-up + ${bloque} min at goal race pace + 10 min easy. ` +
      "Rehearse with the clothes and gels you'll use on event day.",
    fuerza:
      "Strength circuit: squats, lunges, glute bridges, plank and eccentric calf and hamstring work. " +
      "3 sets x 10-12 reps. Lowers the risk of overuse injury.",
  },
  zonaYRitmo: (zona, fc, ritmo) =>
    `Zone ${ZONA_EN[zona]}${fc === null ? "" : ` (${fc[0]}-${fc[1]} bpm)`}` +
    (ritmo === null ? "" : ` · Pace ${ritmo[0]} - ${ritmo[1]} min/km`),
  consejo: {
    descanso: "Lighter day: ease off the carbs and keep up your protein and hydration.",
    evento: (a) =>
      a === null
        ? "During the race: drink from minute one and add sodium and carbs. Have a carb breakfast 3 h before."
        : `During the race: ${a.liquidoMlPorHora} ml/h, ${a.sodioMgPorHora} mg of sodium/h and ${a.carbohidratosGPorHora} g of carbs/h. ` +
          `Breakfast 3 h before with ${a.preCarbohidratosG} g of carbs.`,
    fuerza: (a) => (a === null ? "Protein within the hour after." : `Protein within the hour after (${a.postProteinaG} g).`),
    corta: (a) => (a === null ? "Water as needed. No gels needed." : `Water as needed (${a.liquidoMlPorHora} ml/h). No gels needed.`),
    larga: (a) =>
      a === null
        ? "Carry water, carbs and sodium."
        : `Carry ${a.liquidoTotalMl} ml, ${a.carbohidratosTotalG} g of carbs and ${a.sodioTotalMg} mg of sodium.`,
  },
};

const DICCIONARIOS: Readonly<Record<Locale, Diccionario>> = { "es-AR": ES_AR, "en-US": EN_US };

const OBJETIVO_DEL_MOTIVO: Readonly<Partial<Record<CodigoDeMotivo, Objetivo>>> = {
  objetivo_c5k: "c5k",
  objetivo_c10k: "c10k",
  objetivo_media_maraton: "media_maraton",
  objetivo_maraton: "maraton",
  objetivo_trail_montana: "trail_montana",
  objetivo_triatlon_olimpico: "triatlon_olimpico",
  objetivo_volver_sin_lesiones: "volver_sin_lesiones",
};

/** Título, detalle (descripción + consejo de combustible) y un texto por motivo, en su orden. */
export function textosDelDia(dia: DiaPlanificado, locale: Locale): { titulo: string; detalle: string; motivos: string[] } {
  const t = DICCIONARIOS[locale];
  if (t === undefined) throw new RangeError(`locale desconocido: "${locale}"`);
  return {
    titulo: titulo(dia, t),
    detalle: `${descripcion(dia, t)}\n${consejo(dia, t)}`,
    motivos: dia.motivos.map((codigo) => t.motivo[codigo]),
  };
}

/** titleFor, más los títulos de restWorkout y raceWorkout. */
function titulo(dia: DiaPlanificado, t: Diccionario): string {
  const min = dia.duracionMin;
  switch (dia.tipo) {
    case "descanso":
      return t.titulo.descanso;
    case "carrera":
      return t.titulo.evento(nombreDelObjetivo(dia, t));
    case "fuerza":
      return t.titulo.fuerza(min);
    case "fondo":
      return t.titulo.fondo(dia.deporte, min);
    case "regenerativo":
      return t.titulo.regenerativo(min);
    case "suave":
      return t.titulo.suave(dia.deporte, min);
    default:
      return t.titulo.calidad(dia.tipo, dia.deporte, min);
  }
}

/** descriptionFor, más las descripciones de restWorkout y raceWorkout. */
function descripcion(dia: DiaPlanificado, t: Diccionario): string {
  const min = dia.duracionMin;
  let cuerpo: string;
  switch (dia.tipo) {
    case "descanso":
      return t.cuerpo.descanso;
    case "carrera": {
      // raceWorkout guarda pace − 8 … pace + 8: el ritmo del evento es el centro del rango.
      const ritmo = dia.ritmoMinSegKm === null ? 0 : dia.ritmoMinSegKm + 8;
      return t.cuerpo.evento(nombreDelObjetivo(dia, t), formatearRitmo(ritmo), Math.trunc(min / 60), min % 60);
    }
    case "suave":
      cuerpo = t.cuerpo.suave;
      break;
    case "regenerativo":
      cuerpo = t.cuerpo.regenerativo;
      break;
    case "fondo":
      cuerpo = t.cuerpo.fondo;
      break;
    case "tempo":
      cuerpo = t.cuerpo.tempo(Math.round(min * 0.45));
      break;
    case "umbral":
      cuerpo = t.cuerpo.umbral(acotar(Math.trunc((min - 25) / 12), 2, 5));
      break;
    case "series":
      cuerpo = t.cuerpo.series(acotar(Math.trunc((min - 25) / 5), 4, 10));
      break;
    case "cuestas":
      cuerpo = t.cuerpo.cuestas(acotar(Math.trunc((min - 25) / 4), 6, 12));
      break;
    case "fartlek":
      cuerpo = t.cuerpo.fartlek;
      break;
    case "ritmo_carrera":
      cuerpo = t.cuerpo.ritmoCarrera(Math.round(min * 0.4));
      break;
    case "fuerza":
      cuerpo = t.cuerpo.fuerza;
      break;
  }
  if (dia.zona === null) return cuerpo;
  const fc = dia.fcMinLpm !== null && dia.fcMaxLpm !== null ? ([dia.fcMinLpm, dia.fcMaxLpm] as const) : null;
  const ritmo =
    dia.ritmoMinSegKm !== null && dia.ritmoMaxSegKm !== null
      ? ([formatearRitmo(dia.ritmoMinSegKm), formatearRitmo(dia.ritmoMaxSegKm)] as const)
      : null;
  return `${cuerpo}\n${t.zonaYRitmo(dia.zona, fc, ritmo)}`;
}

/** El fuelingTip de buildWorkout, restWorkout y raceWorkout, en el mismo orden de decisión. */
function consejo(dia: DiaPlanificado, t: Diccionario): string {
  const a = dia.avituallamiento;
  switch (dia.tipo) {
    case "descanso":
      return t.consejo.descanso;
    case "carrera":
      return t.consejo.evento(a);
    case "fuerza":
      return t.consejo.fuerza(a);
    default:
      return dia.duracionMin < 60 ? t.consejo.corta(a) : t.consejo.larga(a);
  }
}

/** El objetivo viaja como motivo del día del evento: DiaPlanificado no tiene otro lugar. */
function nombreDelObjetivo(dia: DiaPlanificado, t: Diccionario): string {
  for (const codigo of dia.motivos) {
    const objetivo = OBJETIVO_DEL_MOTIVO[codigo];
    if (objetivo !== undefined) {
      if (dia.motivos.includes("triatlon_rota_deportes") || dia.deporte === "otro") {
        if (objetivo === "media_maraton") return t === ES_AR ? "Triatlón media distancia" : "Middle distance triathlon";
        if (objetivo === "maraton") return t === ES_AR ? "Triatlón larga distancia" : "Long distance triathlon";
      }
      return t.objetivo[objetivo];
    }
  }
  return t.objetivoDesconocido;
}

/** formatPace: segundos por km como "m:ss". */
function formatearRitmo(segPorKm: number): string {
  if (segPorKm <= 0) return "--:--";
  return `${Math.trunc(segPorKm / 60)}:${String(segPorKm % 60).padStart(2, "0")}`;
}
