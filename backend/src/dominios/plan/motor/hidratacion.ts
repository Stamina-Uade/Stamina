/**
 * dominios/plan/motor/hidratacion.ts — cuánto tomar, cuánto sodio y cuántos hidratos.
 *
 * PORT LITERAL de HydrationCalculator.kt — constantes SIN VERIFICAR contra sus fuentes
 * (docs/PROPUESTA-MOTOR.md §2). El Kotlin dice apoyarse en el "consenso ACSM / ISSN"; nadie lo
 * comprobó, y "portar no es verificar".
 *
 * Dos cambios de forma, ninguno de números:
 *  d) Las `notes` del Kotlin eran frases en castellano armadas con String.format. Acá son
 *     códigos con sus números (`NotaDeHidratacion`): el cálculo no escribe textos, y así el
 *     número no se redondea distinto según el idioma. Por lo mismo, la agenda de avisos no trae
 *     `message`: el tipo y la cantidad son todo lo que ese texto decía.
 *  e) `geles` no existía en el Kotlin: ver GRAMOS_DE_HIDRATOS_POR_GEL.
 */
import {
  FACTOR_DE_INTENSIDAD,
  SODIO_MG_POR_LITRO,
  acotar,
  type Avituallamiento,
  type Clima,
  type Deporte,
  type Intensidad,
  type SalinidadDelSudor,
  type SexoBiologico,
} from "./tipos.js";

/** Límite de vaciado gástrico: tomar más no se absorbe y arriesga hiponatremia. */
const LIQUIDO_MAXIMO_ML_POR_HORA = 800;
const LIQUIDO_MINIMO_ML_POR_HORA = 300;
/** Se repone entre el 70 y el 80 % de lo que se pierde por sudor. */
const PROPORCION_DE_REPOSICION = 0.78;

/**
 * 🆕 NUEVO, no está en el Kotlin (excepción e del port): cuántos gramos de hidratos cuenta un gel.
 * SIN VERIFICAR, como todo este archivo. Se redondea para arriba: si faltan 26 g, un gel no alcanza.
 */
export const GRAMOS_DE_HIDRATOS_POR_GEL = 25;

/** Lo que el cálculo lee de la persona. A diferencia del plan, acá el peso es obligatorio. */
export interface PerfilDeHidratacion {
  readonly pesoKg: number;
  readonly sexo: SexoBiologico | null;
  readonly salinidad: SalinidadDelSudor;
  /** 1 = estómago sensible, 2 = normal, 3 = intestino entrenado (tolera 90 g/h). */
  readonly nivelIntestinal: number;
  /** L/h medidos con el protocolo de pesarse antes y después. Si está, manda sobre la estimación. */
  readonly tasaDeSudorMedidaLh: number | null;
}

/** Las `notes` del Kotlin, en el mismo orden y con los mismos umbrales. */
export type NotaDeHidratacion =
  | { readonly codigo: "sudor_estimado"; readonly litros: number; readonly minutos: number }
  | { readonly codigo: "perdida_de_peso_sin_reponer"; readonly porcentajeDelPeso: number }
  | { readonly codigo: "calor_alto" }
  | { readonly codigo: "sesion_larga_sodio_desde_el_inicio" }
  | { readonly codigo: "mezcla_glucosa_fructosa" }
  | { readonly codigo: "sesion_corta_alcanza_con_agua" }
  | { readonly codigo: "entrenar_el_intestino" };

/** HydrationPlan de Hydration.kt. Lo que es "por hora" lo dice el nombre; el resto es por toma. */
export interface PlanDeHidratacion {
  readonly deporte: Deporte;
  readonly intensidad: Intensidad;
  readonly clima: Clima;
  readonly duracionMin: number;
  readonly tasaDeSudorLh: number;
  readonly liquidoMlPorHora: number;
  readonly liquidoPorTomaMl: number;
  readonly liquidoCadaMin: number;
  readonly sodioMgPorHora: number;
  readonly sodioPorTomaMg: number;
  readonly sodioCadaMin: number;
  readonly carbohidratosGPorHora: number;
  readonly carbohidratosPorTomaG: number;
  readonly carbohidratosCadaMin: number;
  readonly preLiquidoMl: number;
  readonly preCarbohidratosG: number;
  readonly postLiquidoMl: number;
  readonly postCarbohidratosG: number;
  readonly postProteinaG: number;
  /** Los getters totalFluidMl, totalSodiumMg y totalCarbsG, truncados como en el Kotlin. */
  readonly liquidoTotalMl: number;
  readonly sodioTotalMg: number;
  readonly carbohidratosTotalG: number;
  readonly notas: readonly NotaDeHidratacion[];
}

/** IntakeType de Session.kt: los tres que arma la agenda (WATER, SALT, GEL). */
export type TipoDeToma = "agua" | "sales" | "gel";

/** FuelScheduleItem de Hydration.kt, sin `message` (ver la cabecera). */
export interface AvisoDeAvituallamiento {
  readonly minuto: number;
  readonly tipo: TipoDeToma;
  readonly liquidoMl: number;
  readonly sodioMg: number;
  readonly carbohidratosG: number;
}

/** baseSweatRate: L/h para 70 kg, a 18 °C y esfuerzo moderado. */
const SUDOR_BASE_LH: Readonly<Record<Deporte, number>> = {
  running: 0.95,
  triatlon: 0.9,
  ciclismo: 0.75,
  trekking: 0.6,
  natacion: 0.4,
  fuerza: 0.5,
  otro: 0.7,
};

/**
 * sweatRateLh: tasa de sudoración estimada, o la medida si la hay.
 *
 * Sexo: el Kotlin sólo distinguía FEMALE (0,85) de todo lo demás (1,0), y su valor por defecto era
 * MALE. `sin_declarar` y null caen en 1,0: no existe un factor neutro que usar, y 1,0 es el que no
 * le descuenta sudor a nadie. El tope de 800 ml/h de reposición vale igual.
 */
export function tasaDeSudoracionLh(
  perfil: PerfilDeHidratacion,
  deporte: Deporte,
  intensidad: Intensidad,
  clima: Clima
): number {
  const medida = perfil.tasaDeSudorMedidaLh;
  const base = medida ?? SUDOR_BASE_LH[deporte];
  const factorPeso = medida !== null ? 1.0 : perfil.pesoKg / 70.0;
  const factorSexo = medida !== null ? 1.0 : perfil.sexo === "femenino" ? 0.85 : 1.0;
  // Cada grado por encima de 18 °C suma ~3,5 % de sudoración; por debajo, resta.
  const factorTemperatura = acotar(1.0 + 0.035 * (clima.temperaturaC - 18.0), 0.65, 1.9);
  // La humedad alta impide la evaporación y aumenta la pérdida.
  const factorHumedad = acotar(1.0 + 0.004 * (clima.humedadPct - 50.0), 0.9, 1.3);
  const factorSol = clima.bajoElSol && clima.temperaturaC > 22 ? 1.08 : 1.0;
  return acotar(
    base * factorPeso * factorSexo * FACTOR_DE_INTENSIDAD[intensidad] * factorTemperatura * factorHumedad * factorSol,
    0.25,
    2.6
  );
}

/** carbsPerHour: nada hasta 45 min, y siempre limitado por lo que tolera el intestino. */
export function carbohidratosPorHora(duracionMin: number, nivelIntestinal: number): number {
  const crudo = duracionMin < 45 ? 0 : duracionMin < 75 ? 25 : duracionMin < 150 ? 50 : duracionMin < 240 ? 75 : 90;
  const tope = nivelIntestinal === 1 ? 45 : nivelIntestinal === 2 ? 70 : 95;
  return Math.min(crudo, tope);
}

/** buildPlan. */
export function planDeHidratacion(
  perfil: PerfilDeHidratacion,
  deporte: Deporte,
  intensidad: Intensidad,
  clima: Clima,
  duracionMin: number
): PlanDeHidratacion {
  const tasa = tasaDeSudoracionLh(perfil, deporte, intensidad, clima);
  const liquidoMlPorHora = acotar(
    Math.round(tasa * 1000 * PROPORCION_DE_REPOSICION),
    LIQUIDO_MINIMO_ML_POR_HORA,
    LIQUIDO_MAXIMO_ML_POR_HORA
  );

  // Con mucho calor conviene tomar más seguido y de a menos volumen.
  const liquidoCadaMin = duracionMin < 40 ? 20 : tasa > 1.4 ? 10 : tasa > 1.0 ? 15 : 20;
  const liquidoPorTomaMl = Math.round((liquidoMlPorHora * liquidoCadaMin) / 60.0);

  const sodioPorLitro = SODIO_MG_POR_LITRO[perfil.salinidad];
  // Se repone entre el 60 y el 80 % del sodio perdido; más si la sesión es larga.
  const reposicionDeSodio = duracionMin >= 120 ? 0.8 : 0.6;
  // Tope de 1500 mg/h: según el Kotlin, por encima cae la tolerancia gástrica sin beneficio extra.
  const sodioMgPorHora = duracionMin < 60 ? 0 : Math.min(Math.round(tasa * sodioPorLitro * reposicionDeSodio), 1500);
  const sodioCadaMin = sodioMgPorHora === 0 ? 0 : tasa > 1.3 ? 30 : 45;
  const sodioPorTomaMg = sodioCadaMin === 0 ? 0 : Math.round((sodioMgPorHora * sodioCadaMin) / 60.0);

  const carbohidratosGPorHora = carbohidratosPorHora(duracionMin, perfil.nivelIntestinal);
  const carbohidratosCadaMin =
    carbohidratosGPorHora === 0 ? 0 : carbohidratosGPorHora >= 75 ? 20 : carbohidratosGPorHora >= 50 ? 25 : 30;
  const carbohidratosPorTomaG =
    carbohidratosCadaMin === 0 ? 0 : Math.round((carbohidratosGPorHora * carbohidratosCadaMin) / 60.0);

  // Antes: 5-7 ml/kg entre 2 y 4 horas antes.
  const preLiquidoMl = Math.round(perfil.pesoKg * 6);
  const preCarbohidratosG =
    duracionMin < 60
      ? Math.round(perfil.pesoKg * 0.5)
      : duracionMin < 150
        ? Math.round(perfil.pesoKg * 1.2)
        : Math.round(perfil.pesoKg * 2.0);
  // Después: 150 % del líquido perdido, y 1 g/kg de hidratos + 0,3 g/kg de proteína.
  const perdidaMl = (tasa * 1000 * duracionMin) / 60.0;
  const postLiquidoMl = Math.round(Math.max(perdidaMl * 1.5 - (liquidoMlPorHora * duracionMin) / 60.0, 300.0));
  const postCarbohidratosG = Math.round(perfil.pesoKg * 1.0);
  const postProteinaG = Math.round(perfil.pesoKg * 0.3);

  const notas: NotaDeHidratacion[] = [{ codigo: "sudor_estimado", litros: perdidaMl / 1000.0, minutos: duracionMin }];
  const deshidratacion = perfil.pesoKg > 0 ? perdidaMl / 10.0 / perfil.pesoKg : 0.0;
  // Más de un 2 % del peso corporal sin reponer ya baja el rendimiento.
  if (deshidratacion >= 2.0) notas.push({ codigo: "perdida_de_peso_sin_reponer", porcentajeDelPeso: deshidratacion });
  if (clima.temperaturaC >= 28) notas.push({ codigo: "calor_alto" });
  if (duracionMin >= 90) notas.push({ codigo: "sesion_larga_sodio_desde_el_inicio" });
  if (carbohidratosGPorHora >= 60) notas.push({ codigo: "mezcla_glucosa_fructosa" });
  if (duracionMin < 60) notas.push({ codigo: "sesion_corta_alcanza_con_agua" });
  if (perfil.nivelIntestinal === 1) notas.push({ codigo: "entrenar_el_intestino" });

  return {
    deporte,
    intensidad,
    clima,
    duracionMin,
    tasaDeSudorLh: tasa,
    liquidoMlPorHora,
    liquidoPorTomaMl,
    liquidoCadaMin,
    sodioMgPorHora,
    sodioPorTomaMg,
    sodioCadaMin,
    carbohidratosGPorHora,
    carbohidratosPorTomaG,
    carbohidratosCadaMin,
    preLiquidoMl,
    preCarbohidratosG,
    postLiquidoMl,
    postCarbohidratosG,
    postProteinaG,
    liquidoTotalMl: Math.trunc((liquidoMlPorHora * duracionMin) / 60.0),
    sodioTotalMg: Math.trunc((sodioMgPorHora * duracionMin) / 60.0),
    carbohidratosTotalG: Math.trunc((carbohidratosGPorHora * duracionMin) / 60.0),
    notas,
  };
}

/** buildSchedule: la agenda de avisos minuto a minuto, ordenada por minuto. */
export function agendaDeAvisos(plan: PlanDeHidratacion): AvisoDeAvituallamiento[] {
  const avisos: AvisoDeAvituallamiento[] = [];
  const duracion = plan.duracionMin;
  if (plan.liquidoCadaMin > 0) {
    for (let t = plan.liquidoCadaMin; t <= duracion; t += plan.liquidoCadaMin) {
      avisos.push({ minuto: t, tipo: "agua", liquidoMl: plan.liquidoPorTomaMl, sodioMg: 0, carbohidratosG: 0 });
    }
  }
  if (plan.sodioCadaMin > 0) {
    for (let t = plan.sodioCadaMin; t <= duracion; t += plan.sodioCadaMin) {
      avisos.push({ minuto: t, tipo: "sales", liquidoMl: 0, sodioMg: plan.sodioPorTomaMg, carbohidratosG: 0 });
    }
  }
  if (plan.carbohidratosCadaMin > 0) {
    // El primer gel nunca antes del minuto 30.
    for (let t = Math.max(plan.carbohidratosCadaMin, 30); t <= duracion; t += plan.carbohidratosCadaMin) {
      avisos.push({ minuto: t, tipo: "gel", liquidoMl: 0, sodioMg: 0, carbohidratosG: plan.carbohidratosPorTomaG });
    }
  }
  // sortedBy es estable, y Array.prototype.sort también: a igual minuto queda agua, sales, gel.
  return avisos.sort((a, b) => a.minuto - b.minuto);
}

/** measuredSweatRate: (peso antes − peso después + líquido tomado) / horas, entre 0 y 3,5 L/h. */
export function tasaDeSudoracionMedida(
  pesoAntesKg: number,
  pesoDespuesKg: number,
  liquidoTomadoMl: number,
  duracionMin: number
): number {
  if (duracionMin <= 0) return 0.0;
  const perdidaLitros = pesoAntesKg - pesoDespuesKg + liquidoTomadoMl / 1000.0;
  return acotar(perdidaLitros / (duracionMin / 60.0), 0.0, 3.5);
}

/** Lo que el plan publica de un PlanDeHidratacion (DiaPlanificado.avituallamiento). */
export function avituallamientoDe(plan: PlanDeHidratacion): Avituallamiento {
  return {
    liquidoMlPorHora: plan.liquidoMlPorHora,
    liquidoTotalMl: plan.liquidoTotalMl,
    sodioMgPorHora: plan.sodioMgPorHora,
    sodioTotalMg: plan.sodioTotalMg,
    carbohidratosGPorHora: plan.carbohidratosGPorHora,
    carbohidratosTotalG: plan.carbohidratosTotalG,
    geles: Math.ceil(plan.carbohidratosTotalG / GRAMOS_DE_HIDRATOS_POR_GEL),
    preLiquidoMl: plan.preLiquidoMl,
    preCarbohidratosG: plan.preCarbohidratosG,
    postLiquidoMl: plan.postLiquidoMl,
    postCarbohidratosG: plan.postCarbohidratosG,
    postProteinaG: plan.postProteinaG,
  };
}
