/**
 * dominios/plan/motor/tipos.ts — lo que entra al motor, lo que sale, y las tablas del modelo.
 *
 * PORT LITERAL de Training.kt, Profile.kt, Hydration.kt y Session.kt — constantes SIN VERIFICAR
 * contra sus fuentes (docs/PROPUESTA-MOTOR.md §2).
 *
 * El motor es puro (docs/PROPUESTA-MOTOR.md §1): ni HTTP, ni SQL, ni reloj. Todo lo que necesita
 * entra en `EntradaDelMotor`, y cada día sale con los CÓDIGOS de por qué es así
 * (`CodigoDeMotivo`), nunca con textos: los arma `textos.ts`, en el idioma que se pida.
 *
 * La interfaz pública ya la consume otro módulo: se cambia sólo agregando.
 */

// ─── La puerta del MVP ──────────────────────────────────────────────────────────────────────

/**
 * 🛑 MVP 100 % running (pedido de producto, 2026-10-19). Con esto en `true` el motor planifica
 * SIEMPRE corriendo, sea cual sea el deporte del perfil:
 *  - ciclismo, trekking y triatlón en el perfil se planifican como running (el dato guardado no se
 *    toca: apagar la puerta devuelve el plan multideporte sin migrar nada);
 *  - el objetivo `triatlon_olimpico` se planifica como su tramo a pie, un 10K
 *    (`OBJETIVO_SOLO_RUNNING`); el objetivo guardado y el `goal` del plan siguen siendo el elegido;
 *  - la fuerza (gimnasio) se queda: es parte de un plan de running, y la rutina sale de ahí;
 *  - el descanso sigue siendo `otro`: no es una sesión.
 * El port literal del Kotlin sigue entero detrás de `generarPlan(entrada, { soloRunning: false })`,
 * que es lo que usan los casos de oro.
 */
export const MVP_SOLO_RUNNING = true;

/** Cómo se planifica cada objetivo con la puerta prendida: todos a pie. */
export const OBJETIVO_SOLO_RUNNING: Readonly<Partial<Record<Objetivo, Objetivo>>> = {
  triatlon_olimpico: "c10k",
};

export interface OpcionesDelMotor {
  /** Por defecto, `MVP_SOLO_RUNNING`. */
  readonly soloRunning?: boolean;
}

// ─── La interfaz pública ────────────────────────────────────────────────────────────────────

export type Nivel = "principiante" | "intermedio" | "avanzado";
export type SexoBiologico = "femenino" | "masculino" | "sin_declarar";
export type Objetivo =
  | "c5k"
  | "c10k"
  | "media_maraton"
  | "maraton"
  | "trail_montana"
  | "triatlon_olimpico"
  | "volver_sin_lesiones";
export type DeportePerfil = "running" | "ciclismo" | "trekking" | "triatlon";
export type Fase = "base" | "construccion" | "pico" | "afinamiento" | "carrera";
export type TipoDeSesion =
  | "descanso"
  | "regenerativo"
  | "suave"
  | "fondo"
  | "tempo"
  | "umbral"
  | "series"
  | "cuestas"
  | "fartlek"
  | "ritmo_carrera"
  | "fuerza"
  | "carrera";
export type DeporteDeSesion = "running" | "ciclismo" | "natacion" | "trekking" | "fuerza" | "otro";
export type Zona = "z1" | "z2" | "z3" | "z4" | "z5";
export type Locale = "es-AR" | "en-US";

/** ISO-8601: 1 = lunes … 7 = domingo. `minuteOfDay` va de 0 a 1439, en la hora local de la persona. */
export interface DiaDeEntrenamiento {
  weekday: number;
  minuteOfDay: number;
}

export interface EntradaDelMotor {
  objetivo: Objetivo;
  nivel: Nivel;
  deporte: DeportePerfil;
  /** Puede venir desordenado o con un weekday repetido: se normaliza, y gana el primero. */
  dias: readonly DiaDeEntrenamiento[];
  /** "YYYY-MM-DD", fecha local. Es el "hoy" del plan: el motor no lee el reloj. */
  inicio: string;
  /** "YYYY-MM-DD", fecha local. */
  fechaEvento: string | null;
  pesoG: number | null;
  edad: number | null;
  sexo: SexoBiologico | null;
}

/**
 * Por qué un día es como es. Unión CERRADA: cada código tiene su texto en cada idioma, y el
 * compilador no deja agregar uno sin escribirlo (textos.ts).
 */
export const CODIGOS_DE_MOTIVO = [
  // La fase del macrociclo: explica el tipo de sesión.
  "fase_base",
  "fase_construccion",
  "fase_pico",
  "fase_afinamiento",
  // El día del evento, y cuál es el evento: el título de ese día lo necesita, y DiaPlanificado
  // no trae el objetivo.
  "dia_del_evento",
  "objetivo_c5k",
  "objetivo_c10k",
  "objetivo_media_maraton",
  "objetivo_maraton",
  "objetivo_trail_montana",
  "objetivo_triatlon_olimpico",
  "objetivo_volver_sin_lesiones",
  // El volumen.
  "semana_de_descarga",
  // El reparto de la semana: qué regla le dio a cada día su papel.
  "fondo_en_fin_de_semana",
  "fondo_en_el_ultimo_dia_elegido",
  "fondo_unico_dia_elegido",
  "calidad_con_mas_descanso_previo",
  "segunda_calidad_lejos_de_la_primera",
  "segunda_calidad_suave_en_afinamiento",
  "regenerativo_despues_del_fondo",
  "fuerza_antes_del_fondo",
  "suave_en_los_dias_restantes",
  "triatlon_rota_deportes",
  "dia_no_elegido",
  // La fecha del objetivo.
  "sin_fecha_bloque_generico",
  "fecha_objetivo_fuera_de_rango",
] as const;
export type CodigoDeMotivo = (typeof CODIGOS_DE_MOTIVO)[number];

export interface Avituallamiento {
  liquidoMlPorHora: number;
  liquidoTotalMl: number;
  sodioMgPorHora: number;
  sodioTotalMg: number;
  carbohidratosGPorHora: number;
  carbohidratosTotalG: number;
  geles: number;
  preLiquidoMl: number;
  preCarbohidratosG: number;
  postLiquidoMl: number;
  postCarbohidratosG: number;
  postProteinaG: number;
}

export interface DiaPlanificado {
  fecha: string;
  /** Días desde `inicio`: 0 es el primero. Es también su posición en `PlanGenerado.dias`. */
  indice: number;
  weekday: number;
  /** 1 es la primera semana. */
  semana: number;
  fase: Fase;
  tipo: TipoDeSesion;
  deporte: DeporteDeSesion;
  minutoDelDia: number | null;
  duracionMin: number;
  distanciaM: number | null;
  zona: Zona | null;
  fcMinLpm: number | null;
  fcMaxLpm: number | null;
  ritmoMinSegKm: number | null;
  ritmoMaxSegKm: number | null;
  kcal: number | null;
  avituallamiento: Avituallamiento | null;
  esSemanaDeDescarga: boolean;
  motivos: CodigoDeMotivo[];
}

/** PlanWeek de Training.kt: la fase es la del primer día de la semana, y los totales suman sus días. */
export interface SemanaPlanificada {
  numero: number;
  fase: Fase;
  inicio: string;
  esDescarga: boolean;
  minutosPrevistos: number;
  metrosPrevistos: number;
}

export interface TramoDeFase {
  fase: Fase;
  primeraSemana: number;
  ultimaSemana: number;
}

export interface PlanGenerado {
  version: string;
  /** Siempre igual a `semanas.length`. */
  totalSemanas: number;
  /** La fecha que se usó. Null sin fecha, o si la pedida quedó fuera de rango. */
  fechaEvento: string | null;
  dias: DiaPlanificado[];
  semanas: SemanaPlanificada[];
  fases: TramoDeFase[];
}

// ─── El modelo del Kotlin, por dentro ───────────────────────────────────────────────────────

/**
 * Sport de Profile.kt, con los valores del contrato donde coinciden: running = RUNNING,
 * ciclismo = CYCLING, trekking = TREKKING, triatlon = TRIATHLON, natacion = SWIMMING,
 * fuerza = STRENGTH, otro = OTHER.
 */
export type Deporte = "running" | "ciclismo" | "trekking" | "triatlon" | "natacion" | "fuerza" | "otro";

/** EffortIntensity de Hydration.kt: suave = EASY, moderada = MODERATE, fuerte = HARD, competencia = RACE. */
export type Intensidad = "suave" | "moderada" | "fuerte" | "competencia";

export const FACTOR_DE_INTENSIDAD: Readonly<Record<Intensidad, number>> = {
  suave: 0.78,
  moderada: 1.0,
  fuerte: 1.25,
  competencia: 1.4,
};

/** WeatherConditions de Hydration.kt. */
export interface Clima {
  readonly temperaturaC: number;
  readonly humedadPct: number;
  readonly bajoElSol: boolean;
}

/** Los valores por defecto de WeatherConditions(): el plan no conoce el clima del día. */
export const CLIMA_POR_DEFECTO: Clima = { temperaturaC: 22.0, humedadPct: 55.0, bajoElSol: true };

/** SweatSaltiness de Profile.kt: mg de sodio por litro de sudor. */
export type SalinidadDelSudor = "baja" | "media" | "alta";

export const SODIO_MG_POR_LITRO: Readonly<Record<SalinidadDelSudor, number>> = {
  baja: 400,
  media: 700,
  alta: 1100,
};

/** HrZone de Training.kt: fracción de la FC máxima. */
export const ZONAS: Readonly<Record<Zona, { readonly bajo: number; readonly alto: number }>> = {
  z1: { bajo: 0.5, alto: 0.6 },
  z2: { bajo: 0.6, alto: 0.7 },
  z3: { bajo: 0.7, alto: 0.8 },
  z4: { bajo: 0.8, alto: 0.9 },
  z5: { bajo: 0.9, alto: 1.0 },
};

/**
 * WorkoutType de Training.kt: su zona y si es de calidad. BRICK, SWIM y CROSS no están: el
 * generador nunca los produce. `loadFactor` tampoco: es de TrainingLoadCalculator, que no se portó.
 */
export const TIPOS: Readonly<Record<TipoDeSesion, { readonly zona: Zona; readonly esCalidad: boolean }>> = {
  descanso: { zona: "z1", esCalidad: false },
  regenerativo: { zona: "z1", esCalidad: false },
  suave: { zona: "z2", esCalidad: false },
  fondo: { zona: "z2", esCalidad: false },
  tempo: { zona: "z3", esCalidad: true },
  umbral: { zona: "z4", esCalidad: true },
  series: { zona: "z5", esCalidad: true },
  cuestas: { zona: "z4", esCalidad: true },
  fartlek: { zona: "z3", esCalidad: true },
  ritmo_carrera: { zona: "z3", esCalidad: true },
  fuerza: { zona: "z2", esCalidad: false },
  carrera: { zona: "z4", esCalidad: true },
};

/** Los GoalType del Kotlin a los que llega algún objetivo del contrato (objetivos.ts). */
export type GoalTypeKotlin =
  | "RACE_5K"
  | "RACE_10K"
  | "RACE_21K"
  | "RACE_42K"
  | "TREKKING_LONG"
  | "TRIATHLON_OLYMPIC"
  | "GENERAL_FITNESS";

/** GoalType de Profile.kt, ya resuelto para una persona (el trail depende de su deporte). */
export interface MetaDelMotor {
  readonly goalType: GoalTypeKotlin;
  readonly deporte: Deporte;
  readonly distanciaKm: number;
  /** GoalType.estimatedEventMinutes. */
  readonly minutosDelEvento: Readonly<Record<Nivel, number>>;
}

/** Marca previa para Riegel (UserProfile.referenceDistanceKm / referenceTimeMinutes). */
export interface MarcaDeReferencia {
  readonly distanciaKm: number;
  readonly tiempoMin: number;
}

/** UserProfile de Profile.kt: lo que el motor lee de la persona. */
export interface PerfilDelMotor {
  readonly objetivo: Objetivo;
  readonly meta: MetaDelMotor;
  readonly nivel: Nivel;
  /** primarySport. Es `Deporte` y no `DeportePerfil` porque el Kotlin compara contra SWIMMING y OTHER. */
  readonly deportePrincipal: Deporte;
  readonly pesoKg: number | null;
  readonly fcMaxima: number | null;
  readonly sexo: SexoBiologico | null;
  readonly salinidad: SalinidadDelSudor;
  readonly nivelIntestinal: number;
  readonly tasaDeSudorMedidaLh: number | null;
  readonly marca: MarcaDeReferencia | null;
  /** trainingSchedule: weekday ISO → minuto del día, ordenado de lunes a domingo y sin repetidos. */
  readonly agenda: ReadonlyMap<number, number>;
}

// ─── La aritmética de Kotlin que JavaScript no trae igual ───────────────────────────────────
//
// Double.roundToInt() es Math.round de Java: el entero más cercano y, en el empate, hacia +∞.
// Math.round de JavaScript está definido igual, así que se usa tal cual. Double.toInt() trunca
// hacia cero, como Math.trunc, y la división entera de Int también. Las dos que faltan:

/** coerceIn(min, max). */
export function acotar(valor: number, min: number, max: number): number {
  return valor < min ? min : valor > max ? max : valor;
}

/**
 * kotlin.math.round(Double), que es Math.rint de Java: el empate va al PAR, no hacia arriba.
 * No es un detalle: 90 min de trekking a 3,5 km/h son 5,25 km, y el Kotlin muestra 5,2 donde
 * Math.round daría 5,3.
 */
export function redondearAlPar(valor: number): number {
  const piso = Math.floor(valor);
  const resto = valor - piso;
  if (resto < 0.5) return piso;
  if (resto > 0.5) return piso + 1;
  return piso % 2 === 0 ? piso : piso + 1;
}
