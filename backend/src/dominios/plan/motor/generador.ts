/**
 * dominios/plan/motor/generador.ts — el plan periodizado, día por día.
 *
 * PORT LITERAL de TrainingPlanGenerator.kt — constantes SIN VERIFICAR contra sus fuentes
 * (docs/PROPUESTA-MOTOR.md §2).
 *
 * Lo que hace, igual que el Kotlin:
 *  - Periodización clásica: base → construcción → pico → afinamiento, y el día del evento.
 *  - Progresión lineal desde el 55 % del volumen pico, con descarga cada 4 semanas (al 72 %).
 *  - El volumen de cada semana se reparte según el papel de cada día: fondo, calidad, suave…
 *  - Una sesión de fuerza por semana desde los 4 días.
 *
 * Lo que cambia, cada cosa explicada donde pasa:
 *  a) Las fechas, sin java.time (fechas.ts).
 *  b) El tope de semanas, y las fechas pasadas o demasiado lejanas (generarPlan, macrociclo).
 *  c) Los textos: el generador devuelve datos y códigos de motivo; las palabras, en textos.ts.
 *  f) La distancia, en metros enteros (decimasDeKm).
 * Donde el Kotlin hace algo raro y no está en esa lista, el port hace lo mismo y lo marca con ⚠️:
 * arreglarlo es trabajo del commit que verifique, no del que traduce.
 */
import { intensidadDe, kcalDeSesion, kcalPlanificadas } from "./energia.js";
import { aDia, aTexto, diaDeLaSemana } from "./fechas.js";
import { avituallamientoDe, planDeHidratacion, type PerfilDeHidratacion } from "./hidratacion.js";
import { perfilDelMotor } from "./objetivos.js";
import {
  minutosDelEvento,
  rangoDeRitmo,
  ritmoDeCarreraSegPorKm,
  ritmoPrevistoSegPorKm,
  velocidadEnBiciKmh,
  velocidadEnTrekkingKmh,
  type RangoDeRitmo,
} from "./ritmos.js";
import {
  CLIMA_POR_DEFECTO,
  MVP_SOLO_RUNNING,
  TIPOS,
  ZONAS,
  acotar,
  redondearAlPar,
  type CodigoDeMotivo,
  type Deporte,
  type DeporteDeSesion,
  type DiaPlanificado,
  type EntradaDelMotor,
  type Fase,
  type GoalTypeKotlin,
  type Nivel,
  type Objetivo,
  type OpcionesDelMotor,
  type PerfilDelMotor,
  type PlanGenerado,
  type SemanaPlanificada,
  type TipoDeSesion,
  type TramoDeFase,
  type Zona,
} from "./tipos.js";

/**
 * Se guarda con cada plan (docs/PROPUESTA-MOTOR.md §1, "versionado"). Cambiar una regla o un
 * número del motor es cambiar esta versión: si no, el historial deja de significar lo mismo.
 */
export const MOTOR_VERSION: string = "1.1.0";

/** Excepción b). El Kotlin topaba en 26: ver macrociclo(). */
export const SEMANAS_MAXIMAS = 52;
/** Sin fecha, el Kotlin planificaba hasta el inicio más 8 semanas (startDate.plusWeeks(8)). */
export const SEMANAS_DEL_BLOQUE_GENERICO = 8;
/** Cada cuántas semanas hay descarga, sólo en base y construcción. */
export const SEMANAS_ENTRE_DESCARGAS = 4;
/** A qué fracción del volumen baja la semana de descarga. */
const FACTOR_DE_DESCARGA = 0.72;
/** La primera semana arranca en esta fracción del volumen pico. */
const FRACCION_DEL_PICO_AL_EMPEZAR = 0.55;
const MINUTOS_DE_FUERZA = 35;
const MINUTOS_MINIMOS_POR_SESION = 25;
const MINUTOS_MAXIMOS_POR_SESION = 240;
const SABADO = 6;
const DOMINGO = 7;

/** peakWeeklyMinutes: volumen semanal pico (min) por objetivo, antes del factor de nivel. */
const MINUTOS_PICO_POR_OBJETIVO: Readonly<Record<GoalTypeKotlin, number>> = {
  RACE_5K: 150,
  RACE_10K: 180,
  RACE_21K: 240,
  RACE_42K: 300,
  TREKKING_LONG: 260,
  TRIATHLON_OLYMPIC: 320,
  GENERAL_FITNESS: 150,
};

const FACTOR_DE_NIVEL: Readonly<Record<Nivel, number>> = { principiante: 1.0, intermedio: 1.45, avanzado: 1.9 };

/** Slot: el papel de un día de entrenamiento dentro de la semana. */
type Ranura = "fondo" | "calidad" | "calidad2" | "suave" | "regenerativo" | "fuerza";

/** slotWeights: qué parte del volumen semanal se lleva cada papel. La fuerza tiene duración fija. */
const PESO_DE_RANURA: Readonly<Record<Ranura, number>> = {
  fondo: 0.32,
  calidad: 0.17,
  calidad2: 0.15,
  suave: 0.18,
  regenerativo: 0.1,
  fuerza: 0.0,
};

type FaseDeEntrenamiento = Exclude<Fase, "carrera">;

const MOTIVO_DE_FASE: Readonly<Record<FaseDeEntrenamiento, CodigoDeMotivo>> = {
  base: "fase_base",
  construccion: "fase_construccion",
  pico: "fase_pico",
  afinamiento: "fase_afinamiento",
};

const MOTIVO_DE_OBJETIVO: Readonly<Record<Objetivo, CodigoDeMotivo>> = {
  c5k: "objetivo_c5k",
  c10k: "objetivo_c10k",
  media_maraton: "objetivo_media_maraton",
  maraton: "objetivo_maraton",
  trail_montana: "objetivo_trail_montana",
  triatlon_olimpico: "objetivo_triatlon_olimpico",
  volver_sin_lesiones: "objetivo_volver_sin_lesiones",
};

/** typeFor, QUALITY2: la segunda calidad según la fase. En el afinamiento deja de ser calidad. */
const SEGUNDA_CALIDAD: Readonly<Record<FaseDeEntrenamiento, TipoDeSesion>> = {
  base: "tempo",
  construccion: "umbral",
  pico: "series",
  afinamiento: "suave",
};

/** sportFor, en triatlón: se rotan los deportes según el papel del día. */
const DEPORTE_DE_TRIATLON: Readonly<Record<Ranura, DeporteDeSesion>> = {
  calidad: "ciclismo",
  calidad2: "natacion",
  suave: "running",
  regenerativo: "running",
  fondo: "ciclismo",
  fuerza: "fuerza",
};

/** Cuántas semanas tiene el plan y cuántas le tocan a cada fase. */
interface Macrociclo {
  readonly semanas: number;
  readonly base: number;
  readonly construccion: number;
  readonly pico: number;
  readonly afinamiento: number;
}

/** Lo que es igual para todos los días de un plan. */
interface Contexto {
  readonly perfil: PerfilDelMotor;
  readonly hidratacion: PerfilDeHidratacion | null;
  readonly ranuras: ReadonlyMap<number, Ranura>;
  readonly pesosUsados: number;
  readonly motivoDelFondo: CodigoDeMotivo;
  readonly motivoDeLaFecha: CodigoDeMotivo | null;
  /** El deporte que manda en sportFor: el principal, o el del objetivo si el principal es OTHER. */
  readonly deporteBase: Deporte;
}

/** Lo que cada día sabe de dónde cae. */
interface Lugar {
  readonly fecha: string;
  readonly indice: number;
  readonly weekday: number;
  readonly semana: number;
  readonly esSemanaDeDescarga: boolean;
}

/**
 * generate. `entrada.inicio` es el "hoy" del plan: el motor no lee el reloj.
 *
 * 1.1.0: la puerta del MVP (tipos.ts, MVP_SOLO_RUNNING) planifica todo corriendo. Con
 * `{ soloRunning: false }` sale el port literal del Kotlin, multideporte.
 */
export function generarPlan(entrada: EntradaDelMotor, opciones: OpcionesDelMotor = {}): PlanGenerado {
  const perfil = perfilDelMotor(entrada, opciones.soloRunning ?? MVP_SOLO_RUNNING);
  const inicio = aDia(entrada.inicio);
  const pedida = entrada.fechaEvento === null ? null : aDia(entrada.fechaEvento);

  // Excepción b). Con una fecha pasada el Kotlin devolvía un plan VACÍO —el while no llegaba a
  // entrar—, y con una a más de 26 semanas, semanas y semanas de afinamiento (ver macrociclo). Las
  // dos se tratan como sin fecha, y cada día lo dice, para que la persona sepa por qué no ve su
  // evento.
  const fueraDeRango = pedida !== null && (pedida < inicio || pedida - inicio > SEMANAS_MAXIMAS * 7);
  const evento = pedida === null || fueraDeRango ? null : pedida;
  const motivoDeLaFecha: CodigoDeMotivo | null =
    pedida === null ? "sin_fecha_bloque_generico" : fueraDeRango ? "fecha_objetivo_fuera_de_rango" : null;

  // eventDate ?: startDate.plusWeeks(8), y el while incluye ese último día. Con evento, ese día
  // es la carrera. ⚠️ Rareza del Kotlin, portada tal cual: sin evento también entra, y el bloque
  // de 8 semanas termina con un día suelto en una semana 9.
  const ultimo = evento ?? inicio + SEMANAS_DEL_BLOQUE_GENERICO * 7;
  const m = macrociclo(ultimo - inicio);
  const minutosPico = Math.round(MINUTOS_PICO_POR_OBJETIVO[perfil.meta.goalType] * FACTOR_DE_NIVEL[perfil.nivel]);
  const minutosAlEmpezar = Math.round(minutosPico * FRACCION_DEL_PICO_AL_EMPEZAR);

  const diasElegidos = [...perfil.agenda.keys()];
  const ranuras = repartirRanuras(diasElegidos);
  // sumOf recorre el linkedMapOf en su orden de inserción, y repartirRanuras respeta ese orden.
  let pesosUsados = 0.0;
  for (const ranura of ranuras.values()) pesosUsados += PESO_DE_RANURA[ranura];

  const { pesoKg } = perfil;
  const contexto: Contexto = {
    perfil,
    hidratacion:
      pesoKg === null
        ? null
        : {
            pesoKg,
            sexo: perfil.sexo,
            salinidad: perfil.salinidad,
            nivelIntestinal: perfil.nivelIntestinal,
            tasaDeSudorMedidaLh: perfil.tasaDeSudorMedidaLh,
          },
    ranuras,
    pesosUsados,
    motivoDelFondo: motivoDelFondo(diasElegidos),
    motivoDeLaFecha,
    deporteBase: perfil.deportePrincipal === "otro" ? perfil.meta.deporte : perfil.deportePrincipal,
  };

  const dias: DiaPlanificado[] = [];
  for (let dia = inicio; dia <= ultimo; dia++) {
    const indice = dia - inicio;
    const iSemana = Math.trunc(indice / 7);
    const lugar: Lugar = {
      fecha: aTexto(dia),
      indice,
      weekday: diaDeLaSemana(dia),
      semana: iSemana + 1,
      esSemanaDeDescarga: esSemanaDeDescarga(iSemana, m),
    };
    if (dia === evento) {
      dias.push(diaDelEvento(contexto, lugar));
      continue;
    }
    const fase = faseDeLaSemana(iSemana, m);
    const ranura = ranuras.get(lugar.weekday);
    dias.push(
      ranura === undefined
        ? diaDeDescanso(contexto, lugar, fase)
        : diaDeEntrenamiento(contexto, lugar, fase, ranura, minutosDeLaSemana(iSemana, m, minutosAlEmpezar, minutosPico))
    );
  }

  const semanas = resumirSemanas(dias);
  return {
    version: MOTOR_VERSION,
    totalSemanas: semanas.length,
    fechaEvento: evento === null ? null : aTexto(evento),
    dias,
    semanas,
    fases: tramosDeFase(semanas),
  };
}

// ─── El macrociclo ───────────────────────────────────────────────────────────────────────────

function macrociclo(diasHastaElUltimo: number): Macrociclo {
  const totalDias = Math.max(diasHastaElUltimo, 13);
  // Excepción b). El Kotlin hacía coerceIn(2, 26), pero su while recorría igual hasta la fecha del
  // evento: con un evento a 40 semanas, phaseFor devolvía afinamiento de la semana 25 a la 40
  // —16 semanas, 15 de ellas al 45 % del pico—, medido en el Kotlin compilado. Acá el tope es 52 y
  // generarPlan ya descartó las fechas más lejanas, así que el while nunca se pasa del macrociclo.
  const semanas = acotar(Math.ceil(totalDias / 7.0), 2, SEMANAS_MAXIMAS);
  const afinamiento = semanas >= 12 ? 2 : 1;
  const pico = semanas >= 10 ? 2 : 1;
  const resto = Math.max(semanas - afinamiento - pico, 1);
  const base = Math.max(Math.ceil(resto * 0.6), 1);
  const construccion = Math.max(resto - base, 0);
  return { semanas, base, construccion, pico, afinamiento };
}

/** phaseFor. `i` es el índice de la semana: 0 es la primera. */
function faseDeLaSemana(i: number, m: Macrociclo): FaseDeEntrenamiento {
  if (i >= m.semanas - m.afinamiento) return "afinamiento";
  if (i >= m.semanas - m.afinamiento - m.pico) return "pico";
  if (i >= m.base) return "construccion";
  return "base";
}

/** La descarga de weeklyVolume: sólo antes del pico, cada 4 semanas. */
function esSemanaDeDescarga(i: number, m: Macrociclo): boolean {
  return i < m.semanas - m.afinamiento - m.pico && (i + 1) % SEMANAS_ENTRE_DESCARGAS === 0;
}

/** weeklyVolume: los minutos objetivo de la semana `i`. */
function minutosDeLaSemana(i: number, m: Macrociclo, minutosAlEmpezar: number, minutosPico: number): number {
  if (i >= m.semanas - m.afinamiento) {
    const iAfinamiento = i - (m.semanas - m.afinamiento);
    const factor = m.afinamiento === 1 ? 0.5 : iAfinamiento === 0 ? 0.65 : 0.45;
    return Math.round(minutosPico * factor);
  }
  if (i >= m.semanas - m.afinamiento - m.pico) {
    const iPico = i - (m.semanas - m.afinamiento - m.pico);
    return Math.round(minutosPico * (iPico === 0 ? 1.0 : 0.95));
  }
  const semanasDeProgresion = Math.max(m.base + m.construccion, 1);
  const progreso = i / semanasDeProgresion;
  const volumen = minutosAlEmpezar + (minutosPico - minutosAlEmpezar) * progreso;
  // Semana de descarga para consolidar adaptaciones: un motor que sólo sube, lesiona (AGENTS.md §9.1).
  return Math.round(volumen * (esSemanaDeDescarga(i, m) ? FACTOR_DE_DESCARGA : 1.0));
}

// ─── La semana ──────────────────────────────────────────────────────────────────────────────

/**
 * assignSlots: reparte los papeles sobre los días que la persona puede entrenar. El fondo va al
 * fin de semana si hay; la calidad, al día con más descanso antes; la segunda calidad, lo más
 * lejos posible de la primera y del fondo; el regenerativo, al día siguiente del fondo; la
 * fuerza, al día libre más cercano antes del fondo; el resto, suaves.
 *
 * El Map guarda el orden de inserción del linkedMapOf del Kotlin, y ese orden importa: los pesos
 * se suman en ese orden, y sumar doubles en otro orden puede cambiar el último bit.
 */
function repartirRanuras(ordenados: readonly number[]): Map<number, Ranura> {
  const ranuras = new Map<number, Ranura>();
  const ultimo = ordenados[ordenados.length - 1];
  if (ultimo === undefined) return ranuras;
  if (ordenados.length === 1) {
    ranuras.set(ultimo, "fondo");
    return ranuras;
  }

  const fondo = ordenados.includes(DOMINGO) ? DOMINGO : ordenados.includes(SABADO) ? SABADO : ultimo;
  ranuras.set(fondo, "fondo");
  const libres = ordenados.filter((d) => d !== fondo);
  const asignar = (dia: number | undefined, ranura: Ranura): void => {
    if (dia === undefined) return;
    ranuras.set(dia, ranura);
    libres.splice(libres.indexOf(dia), 1);
  };

  // Días de descanso desde la sesión anterior, dando la vuelta a la semana.
  const descansoPrevio = (dia: number): number =>
    Math.min(...ordenados.filter((otro) => otro !== dia).map((otro) => (dia - otro + 7) % 7));
  const distancia = (a: number, b: number): number => {
    const adelante = (a - b + 7) % 7;
    return Math.min(adelante, 7 - adelante);
  };

  const calidad = primeroConMaximo(libres, descansoPrevio);
  // No pasa: con dos días o más, siempre queda uno libre después del fondo.
  if (calidad === undefined) return ranuras;
  asignar(calidad, "calidad");

  if (ordenados.length >= 5 && libres.length > 0) {
    asignar(
      primeroConMaximo(libres, (d) => Math.min(distancia(d, calidad), distancia(d, fondo))),
      "calidad2"
    );
  }
  if (ordenados.length >= 6) {
    asignar(
      libres.find((d) => (d - fondo + 7) % 7 === 1),
      "regenerativo"
    );
  }
  if (ordenados.length >= 4 && libres.length > 0) {
    asignar(
      primeroConMinimo(libres, (d) => (fondo - d + 7) % 7),
      "fuerza"
    );
  }
  for (const d of libres) ranuras.set(d, "suave");
  return ranuras;
}

/** maxByOrNull: ante un empate gana el PRIMERO, y eso decide, por ejemplo, qué día es la calidad. */
function primeroConMaximo(dias: readonly number[], criterio: (dia: number) => number): number | undefined {
  let elegido: number | undefined;
  let mejor = 0;
  for (const dia of dias) {
    const valor = criterio(dia);
    if (elegido === undefined || valor > mejor) {
      elegido = dia;
      mejor = valor;
    }
  }
  return elegido;
}

/** minByOrNull: también gana el primero. */
function primeroConMinimo(dias: readonly number[], criterio: (dia: number) => number): number | undefined {
  return primeroConMaximo(dias, (d) => -criterio(d));
}

/** Qué regla de assignSlots eligió el día del fondo. */
function motivoDelFondo(ordenados: readonly number[]): CodigoDeMotivo {
  if (ordenados.length === 1) return "fondo_unico_dia_elegido";
  return ordenados.includes(DOMINGO) || ordenados.includes(SABADO)
    ? "fondo_en_fin_de_semana"
    : "fondo_en_el_ultimo_dia_elegido";
}

// ─── Los días ───────────────────────────────────────────────────────────────────────────────

/** restWorkout. */
function diaDeDescanso(c: Contexto, lugar: Lugar, fase: FaseDeEntrenamiento): DiaPlanificado {
  return {
    fecha: lugar.fecha,
    indice: lugar.indice,
    weekday: lugar.weekday,
    semana: lugar.semana,
    fase,
    tipo: "descanso",
    deporte: "otro",
    minutoDelDia: null,
    duracionMin: 0,
    distanciaM: null,
    // El tipo REST del Kotlin tenía zona Z1, pero el descanso no la mostraba: un día sin sesión no
    // tiene pulsaciones que cuidar.
    zona: null,
    fcMinLpm: null,
    fcMaxLpm: null,
    ritmoMinSegKm: null,
    ritmoMaxSegKm: null,
    // estimatedKcal = 0 en el Kotlin. Sin peso, null como en el resto de los días.
    kcal: c.perfil.pesoKg === null ? null : 0,
    avituallamiento: null,
    esSemanaDeDescarga: lugar.esSemanaDeDescarga,
    motivos: motivos(c, lugar, "dia_no_elegido", fase),
  };
}

/** raceWorkout. */
function diaDelEvento(c: Contexto, lugar: Lugar): DiaPlanificado {
  const { perfil, hidratacion } = c;
  const { meta } = perfil;
  const minutos = minutosDelEvento(perfil);
  const ritmo = ritmoDeCarreraSegPorKm(perfil);
  const zona = TIPOS.carrera.zona;
  return {
    fecha: lugar.fecha,
    indice: lugar.indice,
    weekday: lugar.weekday,
    semana: lugar.semana,
    fase: "carrera",
    tipo: "carrera",
    // Es goal.sport, que puede ser TRIATHLON; DeporteDeSesion no tiene triatlón, porque una
    // sesión es de un solo deporte. El evento de triatlón sale como "otro".
    deporte: meta.deporte === "triatlon" ? "otro" : meta.deporte,
    minutoDelDia: perfil.agenda.get(lugar.weekday) ?? null,
    duracionMin: minutos,
    // Acá el Kotlin usa la distancia del objetivo tal cual, sin redondear a un decimal: 21,097 km
    // son 21 097 m.
    distanciaM: Math.round(meta.distanciaKm * 1000),
    zona,
    ...pulsaciones(zona, perfil.fcMaxima),
    ritmoMinSegKm: ritmo - 8,
    ritmoMaxSegKm: ritmo + 8,
    kcal:
      hidratacion === null
        ? null
        : kcalDeSesion(meta.deporte, hidratacion.pesoKg, meta.distanciaKm * 1000, minutos * 60, 0.0, "competencia"),
    avituallamiento:
      hidratacion === null
        ? null
        : avituallamientoDe(planDeHidratacion(hidratacion, meta.deporte, "competencia", CLIMA_POR_DEFECTO, minutos)),
    esSemanaDeDescarga: lugar.esSemanaDeDescarga,
    motivos: ["dia_del_evento", MOTIVO_DE_OBJETIVO[perfil.objetivo]],
  };
}

/** buildWorkout. */
function diaDeEntrenamiento(
  c: Contexto,
  lugar: Lugar,
  fase: FaseDeEntrenamiento,
  ranura: Ranura,
  minutosDeLaSemana: number
): DiaPlanificado {
  const { perfil, hidratacion } = c;
  const peso = PESO_DE_RANURA[ranura] / (c.pesosUsados > 0 ? c.pesosUsados : 1.0);
  const tipo = tipoDeSesion(ranura, fase, lugar.semana);
  const deporte = deporteDeLaSesion(c.deporteBase, ranura, tipo);
  const duracionMin =
    tipo === "fuerza"
      ? MINUTOS_DE_FUERZA
      : acotar(Math.round(minutosDeLaSemana * peso), MINUTOS_MINIMOS_POR_SESION, MINUTOS_MAXIMOS_POR_SESION);
  const rango = rangoDeRitmo(perfil, tipo);
  const decimas = decimasDeKm(perfil, deporte, tipo, duracionMin, rango);
  const zona = TIPOS[tipo].zona;

  const extras: CodigoDeMotivo[] = [];
  if (ranura === "calidad2" && tipo === "suave") extras.push("segunda_calidad_suave_en_afinamiento");
  if (c.deporteBase === "triatlon" && tipo !== "fuerza") extras.push("triatlon_rota_deportes");

  return {
    fecha: lugar.fecha,
    indice: lugar.indice,
    weekday: lugar.weekday,
    semana: lugar.semana,
    fase,
    tipo,
    deporte,
    minutoDelDia: perfil.agenda.get(lugar.weekday) ?? null,
    duracionMin,
    distanciaM: decimas === null ? null : decimas * 100,
    zona,
    ...pulsaciones(zona, perfil.fcMaxima),
    ritmoMinSegKm: rango === null ? null : rango.bajo,
    ritmoMaxSegKm: rango === null ? null : rango.alto,
    kcal:
      hidratacion === null
        ? null
        : kcalPlanificadas(deporte, hidratacion.pesoKg, duracionMin, tipo, decimas === null ? null : decimas / 10.0),
    avituallamiento:
      hidratacion === null
        ? null
        : avituallamientoDe(planDeHidratacion(hidratacion, deporte, intensidadDe(tipo), CLIMA_POR_DEFECTO, duracionMin)),
    esSemanaDeDescarga: lugar.esSemanaDeDescarga,
    motivos: [...motivos(c, lugar, motivoDeRanura(c, ranura), fase), ...extras],
  };
}

/** Los motivos de todo día que no es el evento, siempre en este orden. */
function motivos(c: Contexto, lugar: Lugar, papel: CodigoDeMotivo, fase: FaseDeEntrenamiento): CodigoDeMotivo[] {
  const lista: CodigoDeMotivo[] = [];
  if (c.motivoDeLaFecha !== null) lista.push(c.motivoDeLaFecha);
  lista.push(papel, MOTIVO_DE_FASE[fase]);
  if (lugar.esSemanaDeDescarga) lista.push("semana_de_descarga");
  return lista;
}

function motivoDeRanura(c: Contexto, ranura: Ranura): CodigoDeMotivo {
  switch (ranura) {
    case "fondo":
      return c.motivoDelFondo;
    case "calidad":
      return "calidad_con_mas_descanso_previo";
    case "calidad2":
      return "segunda_calidad_lejos_de_la_primera";
    case "regenerativo":
      return "regenerativo_despues_del_fondo";
    case "fuerza":
      return "fuerza_antes_del_fondo";
    case "suave":
      return "suave_en_los_dias_restantes";
  }
}

/** typeFor. */
function tipoDeSesion(ranura: Ranura, fase: FaseDeEntrenamiento, semana: number): TipoDeSesion {
  if (ranura === "calidad") {
    if (fase === "base") return semana % 2 === 0 ? "cuestas" : "fartlek";
    return fase === "construccion" ? "series" : "ritmo_carrera";
  }
  if (ranura === "calidad2") return SEGUNDA_CALIDAD[fase];
  // Fondo, suave, regenerativo y fuerza no dependen de la fase, y se llaman igual que su tipo.
  return ranura;
}

/** sportFor: en triatlón se rotan los deportes; en el resto se entrena el deporte principal. */
function deporteDeLaSesion(deporteBase: Deporte, ranura: Ranura, tipo: TipoDeSesion): DeporteDeSesion {
  if (tipo === "fuerza") return "fuerza";
  if (deporteBase !== "triatlon") return deporteBase;
  return DEPORTE_DE_TRIATLON[ranura];
}

/**
 * estimateDistance, en décimas de kilómetro. El Kotlin redondeaba los km a un decimal con
 * kotlin.math.round, que desempata al par (tipos.ts, redondearAlPar). Excepción f): contar en
 * décimas deja los metros exactos —décimas × 100— sin arrastrar el error de 8,3 × 1000.
 */
function decimasDeKm(
  perfil: PerfilDelMotor,
  deporte: DeporteDeSesion,
  tipo: TipoDeSesion,
  duracionMin: number,
  rango: RangoDeRitmo | null
): number | null {
  let km: number | null;
  switch (deporte) {
    case "running": {
      const ritmo = rango !== null ? Math.trunc((rango.bajo + rango.alto) / 2) : ritmoPrevistoSegPorKm(perfil, 10.0);
      km = ritmo > 0 ? (duracionMin * 60.0) / ritmo : null;
      break;
    }
    case "ciclismo":
      km = (duracionMin / 60.0) * velocidadEnBiciKmh(perfil.nivel) * (TIPOS[tipo].esCalidad ? 1.05 : 0.95);
      break;
    case "trekking":
      km = (duracionMin / 60.0) * velocidadEnTrekkingKmh(perfil.nivel);
      break;
    case "natacion":
      km = (duracionMin / 60.0) * 2.6;
      break;
    case "fuerza":
    case "otro":
      km = null;
      break;
  }
  return km === null ? null : redondearAlPar(km * 10);
}

/** HrZone.bpmRange(maxHr). Sin edad no hay FC máxima, y sin FC máxima no hay pulsaciones. */
function pulsaciones(zona: Zona, fcMaxima: number | null): { fcMinLpm: number | null; fcMaxLpm: number | null } {
  if (fcMaxima === null) return { fcMinLpm: null, fcMaxLpm: null };
  return {
    fcMinLpm: Math.trunc(ZONAS[zona].bajo * fcMaxima),
    fcMaxLpm: Math.trunc(ZONAS[zona].alto * fcMaxima),
  };
}

// ─── Los resúmenes ──────────────────────────────────────────────────────────────────────────

/**
 * PlanWeek de Training.kt: la fase es la del primer día de la semana y los totales suman sus días.
 * Como el evento es siempre el último día del plan, una semana sólo tiene fase "carrera" cuando
 * el evento es su único día.
 */
function resumirSemanas(dias: readonly DiaPlanificado[]): SemanaPlanificada[] {
  const semanas: SemanaPlanificada[] = [];
  for (const dia of dias) {
    let semana = semanas[dia.semana - 1];
    if (semana === undefined) {
      semana = {
        numero: dia.semana,
        fase: dia.fase,
        inicio: dia.fecha,
        esDescarga: dia.esSemanaDeDescarga,
        minutosPrevistos: 0,
        metrosPrevistos: 0,
      };
      semanas.push(semana);
    }
    semana.minutosPrevistos += dia.duracionMin;
    semana.metrosPrevistos += dia.distanciaM ?? 0;
  }
  return semanas;
}

/** Las semanas seguidas con la misma fase. Cubren del 1 a la última, sin huecos ni solapes. */
function tramosDeFase(semanas: readonly SemanaPlanificada[]): TramoDeFase[] {
  const tramos: TramoDeFase[] = [];
  for (const semana of semanas) {
    const actual = tramos[tramos.length - 1];
    if (actual !== undefined && actual.fase === semana.fase) actual.ultimaSemana = semana.numero;
    else tramos.push({ fase: semana.fase, primeraSemana: semana.numero, ultimaSemana: semana.numero });
  }
  return tramos;
}
