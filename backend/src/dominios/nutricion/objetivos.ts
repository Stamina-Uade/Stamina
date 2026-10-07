/**
 * dominios/nutricion/objetivos.ts — los objetivos nutricionales de UN día.
 *
 * Port de la FORMA de android/app/.../domain/logic/NutritionCalculator.kt, con
 * los números afuera, en shared/datos/nutricion-parametros.json, todos
 * provisionales. El orden importa y es la regla de este archivo:
 *
 *   1. PRIMERO los caminos que no son de este flujo (AGENTS.md §9.2): menores,
 *      embarazo y lactancia —y quien no respondió si lo está—. Se deciden ANTES de
 *      calcular nada, así que no hay un número que se escape por un costado.
 *   2. Después el cálculo: Mifflin-St Jeor, actividad del día, entrenamiento.
 *   3. Y al final la ÚLTIMA PUERTA: `guardarrailes.aplicar`, que nunca devuelve un
 *      número bajo el piso. Los macros se reparten sobre lo que sale de la puerta.
 *
 * Nada de acá decide un déficit: el contrato no tiene un objetivo corporal todavía
 * (bajar grasa, ganar masa), así que el objetivo es el mantenimiento. El día que
 * exista, el déficit entra por `aplicar`, que ya sabe recortarlo.
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { aplicar, cargar as cargarGuardarrailes, provisionales as guardarrailesProvisionales } from "./guardarrailes.js";

export type CargaDelDia = "descanso" | "baja" | "moderada" | "alta" | "competencia";

export type MotivoSinObjetivos =
  | "perfil_incompleto"
  | "menor_de_edad"
  | "sexo_sin_declarar"
  | "falta_embarazo_o_lactancia"
  | "embarazo_o_lactancia";

export interface PersonaParaNutricion {
  pesoG: number | null;
  alturaMm: number | null;
  /** Años cumplidos ese día. */
  edad: number | null;
  sexo: "femenino" | "masculino" | "sin_declarar" | null;
  embarazoOLactancia: boolean | null;
  nivel: "principiante" | "intermedio" | "avanzado" | null;
}

/** Lo que el plan dice de ese día. `null` = no hay sesión (descanso). */
export interface SesionParaNutricion {
  duracionMin: number;
  kcal: number | null;
  esCalidad: boolean;
  esCarrera: boolean;
}

export interface Objetivos {
  kcal: number;
  carbohidratosG: number;
  proteinaG: number;
  grasaG: number;
  aguaMl: number;
  sodioMg: number;
  carga: CargaDelDia;
  /** `true` si la última puerta subió el número (piso o techo de déficit). */
  ajustado: boolean;
  motivoDelAjuste: string | null;
  /** `true` mientras quede UN valor sin revisar, acá o en los guardarraíles. */
  provisional: boolean;
}

export type Resultado = { ok: true; objetivos: Objetivos } | { ok: false; motivo: MotivoSinObjetivos };

// --------------------------------------------------------------- parámetros --

interface Valor {
  valor: number;
  estado: "provisional" | "revisado";
}

function buscarArchivo(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 8; i++) {
    const c = join(dir, "shared/datos/nutricion-parametros.json");
    if (existsSync(c)) return c;
    const arriba = dirname(dir);
    if (arriba === dir) break;
    dir = arriba;
  }
  throw new Error("nutricion: no encontré shared/datos/nutricion-parametros.json");
}

let cache: Record<string, Valor> | null = null;
function valores(): Record<string, Valor> {
  if (cache === null) {
    cache = (JSON.parse(readFileSync(buscarArchivo(), "utf8")) as { valores: Record<string, Valor> }).valores;
  }
  return cache;
}

function num(clave: string): number {
  const v = valores()[clave];
  if (v === undefined || typeof v.valor !== "number") throw new Error(`nutricion: falta el parámetro "${clave}"`);
  return v.valor;
}

/** La edad mínima vive en los guardarraíles: se lee de ahí para no tener dos. */
function edadMinima(): number {
  const v = cargarGuardarrailes().valores["edad_minima"]?.valor;
  if (typeof v !== "number") throw new Error("nutricion: guardarrailes-nutricion.json no tiene edad_minima");
  return v;
}

export function parametrosProvisionales(): string[] {
  return Object.entries(valores())
    .filter(([, v]) => v.estado !== "revisado")
    .map(([k]) => k);
}

/**
 * 🛑 Igual que los guardarraíles: en producción, con un parámetro provisional, el
 * proceso no levanta. En staging y en desarrollo arranca y avisa.
 */
export function verificarParametrosParaProduccion(esProduccion: boolean, avisar: (m: string) => void): void {
  const pendientes = parametrosProvisionales();
  if (pendientes.length === 0) return;
  const mensaje =
    `${pendientes.length} parámetro(s) de nutrición SIN REVISAR en shared/datos/nutricion-parametros.json: ` +
    pendientes.join(", ");
  if (esProduccion) {
    throw new Error(
      `🛑 No arranco en producción: ${mensaje}. Se arregla editando ese archivo —valor, estado "revisado", ` +
        "quién y la fuente—; no hay que tocar código."
    );
  }
  avisar(`⚠️  ${mensaje}. Arranca igual porque no es producción.`);
}

// ----------------------------------------------------------------- el cálculo --

/** Mifflin-St Jeor. Los coeficientes son los de la ecuación publicada, no nuestros. */
export function metabolismoBasal(pesoKg: number, alturaCm: number, edad: number, sexo: "femenino" | "masculino"): number {
  const base = 10 * pesoKg + 6.25 * alturaCm - 5 * edad;
  return sexo === "masculino" ? base + 5 : base - 161;
}

/** `classifyDay` del Kotlin, con los umbrales en el archivo de parámetros. */
export function clasificarDia(
  sesion: SesionParaNutricion | null,
  diasHastaEvento: number | null,
  minutosDelEvento: number | null
): CargaDelDia {
  if (
    diasHastaEvento !== null &&
    minutosDelEvento !== null &&
    minutosDelEvento >= num("minutos_evento_para_carga_de_competencia") &&
    diasHastaEvento >= 0 &&
    diasHastaEvento <= 1
  ) {
    return "competencia";
  }
  if (sesion === null) return "descanso";
  if (sesion.esCarrera) return "competencia";
  const m = sesion.duracionMin;
  if (m >= num("minutos_carga_alta") || (sesion.esCalidad && m >= num("minutos_calidad_carga_alta"))) return "alta";
  if (m >= num("minutos_carga_moderada")) return "moderada";
  return "baja";
}

export function objetivosDelDia(
  persona: PersonaParaNutricion,
  sesion: SesionParaNutricion | null,
  diasHastaEvento: number | null,
  minutosDelEvento: number | null
): Resultado {
  // 1. Lo que no es de este flujo, ANTES de cualquier número (§9.2).
  if (persona.edad === null) return { ok: false, motivo: "perfil_incompleto" };
  if (persona.edad < edadMinima()) return { ok: false, motivo: "menor_de_edad" };
  // Mifflin-St Jeor necesita el sexo biológico. Promediar las dos ecuaciones sería
  // inventar un número para quien eligió no decirlo: no se da objetivo.
  if (persona.sexo === null || persona.sexo === "sin_declarar") return { ok: false, motivo: "sexo_sin_declarar" };
  if (persona.sexo === "femenino") {
    if (persona.embarazoOLactancia === null) return { ok: false, motivo: "falta_embarazo_o_lactancia" };
    if (persona.embarazoOLactancia) return { ok: false, motivo: "embarazo_o_lactancia" };
  }
  if (persona.pesoG === null || persona.alturaMm === null) return { ok: false, motivo: "perfil_incompleto" };

  // 2. El cálculo.
  const pesoKg = persona.pesoG / 1000;
  const bmr = metabolismoBasal(pesoKg, persona.alturaMm / 10, persona.edad, persona.sexo);
  const carga = clasificarDia(sesion, diasHastaEvento, minutosDelEvento);
  const mantenimiento = bmr * num("factor_actividad_no_deportiva") + (sesion?.kcal ?? 0);

  // 3. La última puerta. Sin objetivo corporal, lo que se pide es el mantenimiento.
  const veredicto = aplicar(mantenimiento, mantenimiento, {
    edad: persona.edad,
    peso_g: persona.pesoG,
    altura_mm: persona.alturaMm,
    bmr,
    embarazo_o_lactancia: persona.embarazoOLactancia === true,
  });
  if (!veredicto.permitido) {
    // No debería pasar —el paso 1 ya sacó esos casos—, pero si la puerta dice que
    // no, es que no. Nunca se sigue con un número.
    return { ok: false, motivo: veredicto.motivo === "menor_de_edad" ? "menor_de_edad" : "embarazo_o_lactancia" };
  }
  const kcal = veredicto.kcal;

  // Los macros, sobre lo que salió de la puerta.
  let carbosPorKg = num(`carbohidratos_g_kg_${carga}`);
  if (persona.nivel === "principiante" && carga === "alta") {
    carbosPorKg *= num("factor_carbohidratos_principiante_carga_alta");
  }
  const proteinaPorKg =
    carga === "alta" || carga === "competencia" ? num("proteina_g_kg_carga_alta") : num("proteina_g_kg_base");

  let carbohidratosG = Math.round(carbosPorKg * pesoKg);
  const proteinaG = Math.round(proteinaPorKg * pesoKg);
  const grasaMinimaG = Math.round(num("grasa_minima_g_kg") * pesoKg);
  let grasaG = Math.round((kcal - (carbohidratosG * 4 + proteinaG * 4)) / 9);
  if (grasaG < grasaMinimaG) {
    // Si no entra la grasa mínima, se recortan hidratos. Nunca proteína.
    grasaG = grasaMinimaG;
    carbohidratosG = Math.max(Math.round((kcal - (proteinaG * 4 + grasaG * 9)) / 4), num("carbohidratos_minimos_g"));
  }

  const sudorMl =
    sesion === null ? 0 : Math.min(sesion.duracionMin * num("agua_ml_por_minuto_de_sesion"), num("agua_tope_sesion_ml"));

  return {
    ok: true,
    objetivos: {
      kcal,
      carbohidratosG,
      proteinaG,
      grasaG,
      aguaMl: Math.round(num("agua_ml_kg") * pesoKg) + sudorMl,
      sodioMg: num("sodio_base_mg") + Math.round((sudorMl * num("sodio_mg_por_litro_de_sudor")) / 1000),
      carga,
      ajustado: veredicto.ajustado,
      motivoDelAjuste: veredicto.motivo,
      provisional: parametrosProvisionales().length > 0 || guardarrailesProvisionales().length > 0,
    },
  };
}
