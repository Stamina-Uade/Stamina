/**
 * dominios/nutricion/guardarrailes.ts — la última puerta.
 *
 * 🛑 AGENTS.md §9.2: "Una app que le dice a alguien cuánto comer puede hacer daño
 * real. Estos límites son de código, no de copy, y SE HACEN CUMPLIR EN EL
 * SERVIDOR."
 *
 * Este módulo es la única puerta por la que pasa un objetivo calórico antes de
 * guardarse o de mostrarse. No es un `if` adentro del cálculo — ahí es donde se
 * olvida — es una función aparte, con sus tests, y sin ningún camino que la
 * esquive.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * LOS NÚMEROS NO ESTÁN ACÁ. Están en shared/datos/guardarrailes-nutricion.json,
 * y hoy están TODOS EN "provisional": los puso un agente para no quedar
 * bloqueado, con el criterio de errar para el lado seguro. Nadie con formación
 * los miró.
 *
 * Por eso `verificarParaProduccion()` HACE FALLAR EL ARRANQUE en producción
 * mientras quede uno sin revisar. Se puede construir y probar todo hoy; no se
 * puede publicar sin querer.
 * ────────────────────────────────────────────────────────────────────────────
 */
import { readFileSync } from "node:fs";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export type Estado = "provisional" | "revisado";

interface ValorGuardado {
  valor: number | string;
  estado: Estado;
  por_que_este_numero: string;
  fuente: string | null;
  revisado_por: string | null;
  revisado_en: string | null;
}

interface Archivo {
  valores: Record<string, ValorGuardado>;
  recursos_de_ayuda: { por_pais: Record<string, unknown> };
}

/** Igual que en migrar.ts: se busca subiendo, porque el compilado queda en dist/src/… */
function buscarArchivo(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 8; i++) {
    const c = join(dir, "shared/datos/guardarrailes-nutricion.json");
    if (existsSync(c)) return c;
    const arriba = dirname(dir);
    if (arriba === dir) break;
    dir = arriba;
  }
  throw new Error("guardarrailes: no encontré shared/datos/guardarrailes-nutricion.json");
}

let cache: Archivo | null = null;
export function cargar(): Archivo {
  if (cache === null) cache = JSON.parse(readFileSync(buscarArchivo(), "utf8")) as Archivo;
  return cache;
}

function num(clave: string): number {
  const v = cargar().valores[clave];
  if (v === undefined) throw new Error(`guardarrailes: falta el valor "${clave}"`);
  if (typeof v.valor !== "number") throw new Error(`guardarrailes: "${clave}" no es un número`);
  return v.valor;
}

/** Los que todavía nadie con formación revisó. */
export function provisionales(): string[] {
  return Object.entries(cargar().valores)
    .filter(([, v]) => v.estado !== "revisado")
    .map(([k]) => k);
}

/**
 * 🛑 Se llama AL ARRANCAR. En producción, con un solo valor provisional, el
 * proceso no levanta.
 *
 * Es a propósito y es lo que hace que este archivo sea seguro: los números
 * provisionales existen para poder construir, no para llegarle a nadie.
 */
export function verificarParaProduccion(esProduccion: boolean, avisar: (m: string) => void): void {
  const pendientes = provisionales();
  const sinRecursos = Object.keys(cargar().recursos_de_ayuda.por_pais).length === 0;

  if (!esProduccion) {
    if (pendientes.length > 0) {
      avisar(
        `⚠️  ${pendientes.length} guardarrail(es) de nutrición SIN REVISAR: ${pendientes.join(", ")}. ` +
          `Arranca igual porque no es producción. En producción, no.`
      );
    }
    if (sinRecursos) avisar("⚠️  No hay recursos de ayuda cargados (AGENTS.md §9.2).");
    return;
  }

  const problemas: string[] = [];
  if (pendientes.length > 0) {
    problemas.push(
      `hay ${pendientes.length} valor(es) en "provisional": ${pendientes.join(", ")}. ` +
        `Los puso un agente para no quedar bloqueado; NADIE CON FORMACIÓN LOS REVISÓ.`
    );
  }
  if (sinRecursos) {
    problemas.push(
      `recursos_de_ayuda.por_pais está vacío. §9.2 exige mostrar recursos cuando la app no obedece ` +
        `un objetivo, y un teléfono de ayuda equivocado es peor que ninguno.`
    );
  }
  if (problemas.length === 0) return;

  throw new Error(
    "🛑 No arranco en producción con los guardarraíles de nutrición sin revisar.\n" +
      problemas.map((p) => `   · ${p}`).join("\n") +
      "\n   Se arregla editando shared/datos/guardarrailes-nutricion.json: poné el valor, " +
      "estado \"revisado\", quién lo revisó y la fuente. No hay que tocar código."
  );
}

// ---------------------------------------------------------------- la puerta --

export interface PerfilNutricion {
  edad: number;
  peso_g: number;
  altura_mm: number;
  /** Metabolismo basal ya calculado, en kcal. */
  bmr: number;
  embarazo_o_lactancia?: boolean;
}

export type Veredicto =
  | { permitido: true; kcal: number; ajustado: boolean; motivo: string | null }
  | { permitido: false; motivo: "menor_de_edad" | "embarazo_o_lactancia"; mensaje: string };

/**
 * Lo que la PERSONA pidió, que es otra cosa que lo que el motor calculó.
 *
 * 🛑 La distinción importa y me la marcó un test que falló. §9.2 dice: "si la
 * persona PIDE un objetivo por debajo del piso, un IMC objetivo por debajo del
 * rango, o registra ayunos sostenidos, LA APP NO OBEDECE".
 *
 * Que el motor CALCULE un número bajo es otra cosa: ahí se recorta y se explica.
 * Negarse ahí sería dejar sin plan a alguien que no pidió nada raro.
 */
export type RespuestaAPedido =
  | { obedece: true }
  | { obedece: false; senal: "kcal_bajo_el_piso" | "peso_objetivo_bajo_el_imc_minimo"; piso: number };

/**
 * El piso efectivo: el MAYOR entre el absoluto y el relativo al basal.
 *
 * Los dos hacen falta. El relativo solo no protege a quien tiene un basal bajo
 * —que es justo el caso que §9.2 quiere cubrir— y el absoluto solo no acompaña a
 * quien tiene un basal alto.
 */
export function pisoEfectivo(bmr: number): number {
  return Math.max(num("piso_calorico_absoluto_kcal"), bmr * num("piso_calorico_relativo_bmr"));
}

/**
 * Aplica los guardarraíles a un objetivo ya calculado.
 *
 * NUNCA devuelve un número por debajo del piso. Si el objetivo pedido cae abajo,
 * **la app no obedece** (§9.2): devuelve `permitido: false` y el llamador muestra
 * apoyo y recursos, no el número.
 */
export function aplicar(objetivoKcal: number, mantenimientoKcal: number, perfil: PerfilNutricion): Veredicto {
  // 1. Los caminos que no son de este flujo. Van primero: no se les recorta un
  //    objetivo, se los saca del flujo genérico entero.
  if (perfil.edad < num("edad_minima")) {
    return {
      permitido: false,
      motivo: "menor_de_edad",
      mensaje: "menor de la edad mínima: fuera del alcance del flujo genérico (§9.2)",
    };
  }
  if (perfil.embarazo_o_lactancia === true) {
    return {
      permitido: false,
      motivo: "embarazo_o_lactancia",
      mensaje: "embarazo o lactancia: fuera del alcance del flujo genérico (§9.2)",
    };
  }

  const piso = pisoEfectivo(perfil.bmr);

  // 2. Techo de déficit: el MENOR de los dos límites.
  const deficitMaximo = Math.min(num("techo_deficit_kcal"), mantenimientoKcal * num("techo_deficit_pct"));
  const porDeficit = mantenimientoKcal - deficitMaximo;

  let kcal = objetivoKcal;
  let ajustado = false;
  let motivo: string | null = null;

  if (kcal < porDeficit) {
    kcal = porDeficit;
    ajustado = true;
    motivo = "techo_de_deficit";
  }

  // 3. El piso manda sobre todo lo anterior.
  if (kcal < piso) {
    kcal = piso;
    ajustado = true;
    motivo = "piso_calorico";
  }

  return { permitido: true, kcal: Math.round(kcal), ajustado, motivo };
}

/**
 * 🛑 La app no obedece.
 *
 * Se llama con lo que la PERSONA pidió, no con lo que el motor calculó. Si
 * devuelve `obedece: false`, el llamador **no muestra un número recortado**:
 * muestra el mensaje de apoyo y los recursos (§9.2).
 *
 * Los recursos salen del mismo archivo de datos y hoy están vacíos a propósito —
 * un teléfono de ayuda equivocado es peor que ninguno—, y por eso el arranque en
 * producción también falla por eso.
 */
export function revisarPedidoDeLaPersona(
  pedido: { kcalPedidas?: number; pesoObjetivoG?: number },
  perfil: PerfilNutricion
): RespuestaAPedido {
  const piso = pisoEfectivo(perfil.bmr);

  if (pedido.kcalPedidas !== undefined && pedido.kcalPedidas < piso) {
    return { obedece: false, senal: "kcal_bajo_el_piso", piso };
  }
  if (pedido.pesoObjetivoG !== undefined && pesoObjetivoBajoElMinimo(pedido.pesoObjetivoG, perfil.altura_mm)) {
    return { obedece: false, senal: "peso_objetivo_bajo_el_imc_minimo", piso };
  }
  return { obedece: true };
}

/** ¿El peso objetivo cae por debajo del IMC mínimo? Señal de §9.2. */
export function pesoObjetivoBajoElMinimo(pesoObjetivoG: number, alturaMm: number): boolean {
  const m = alturaMm / 1000;
  if (m <= 0) return false;
  const imc = pesoObjetivoG / 1000 / (m * m);
  return imc < num("imc_objetivo_minimo");
}

/** Ritmo de pérdida semanal máximo, en gramos, para un peso dado. */
export function perdidaMaximaSemanalG(pesoActualG: number): number {
  return Math.round(pesoActualG * num("ritmo_max_perdida_pct_semana"));
}
