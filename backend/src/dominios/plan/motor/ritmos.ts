/**
 * dominios/plan/motor/ritmos.ts — ritmos y tiempos previstos.
 *
 * PORT LITERAL de PaceCalculator.kt — constantes SIN VERIFICAR contra sus fuentes
 * (docs/PROPUESTA-MOTOR.md §2).
 *
 * Riegel: T2 = T1 × (D2 / D1)^1,06. Sin marca previa —el contrato no tiene dónde guardarla— la
 * referencia es un 10K por nivel. formatPace y formatPaceRange viven en textos.ts, porque son
 * presentación; goalTypeFor no se portó, porque nada del motor lo llama.
 */
import type { Deporte, MarcaDeReferencia, MetaDelMotor, Nivel, TipoDeSesion } from "./tipos.js";

export const EXPONENTE_DE_RIEGEL = 1.06;

/** Ritmo de 10K (seg/km) cuando no hay marca: 7:00, 5:30 y 4:18. */
const RITMO_10K_SIN_MARCA: Readonly<Record<Nivel, number>> = {
  principiante: 420,
  intermedio: 330,
  avanzado: 258,
};

interface PerfilDeRitmo {
  readonly nivel: Nivel;
  readonly marca: MarcaDeReferencia | null;
}

interface PerfilDeCarrera extends PerfilDeRitmo {
  readonly meta: MetaDelMotor;
}

interface PerfilDeRango extends PerfilDeCarrera {
  readonly deportePrincipal: Deporte;
}

export interface RangoDeRitmo {
  readonly bajo: number;
  readonly alto: number;
}

/** predictTimeSec: segundos previstos para `objetivoKm` a partir de una marca. */
export function tiempoPrevistoSeg(distanciaRefKm: number, tiempoRefSeg: number, objetivoKm: number): number {
  return tiempoRefSeg * Math.pow(objetivoKm / distanciaRefKm, EXPONENTE_DE_RIEGEL);
}

/** predictedPaceSecPerKm: ritmo previsto (seg/km, truncado) para una distancia. */
export function ritmoPrevistoSegPorKm(perfil: PerfilDeRitmo, objetivoKm: number): number {
  const marca = perfil.marca;
  if (marca !== null && marca.distanciaKm > 0.5 && marca.tiempoMin > 1) {
    return Math.trunc(tiempoPrevistoSeg(marca.distanciaKm, marca.tiempoMin * 60.0, objetivoKm) / objetivoKm);
  }
  const base10k = RITMO_10K_SIN_MARCA[perfil.nivel];
  return Math.trunc(tiempoPrevistoSeg(10.0, base10k * 10.0, objetivoKm) / objetivoKm);
}

/**
 * goalRacePace: el ritmo del evento, sobre su distancia (con piso de 1 km).
 * ⚠️ Rareza del Kotlin, portada tal cual: es ritmo a pie aunque el evento sea de bici, de
 * trekking o un triatlón.
 */
export function ritmoDeCarreraSegPorKm(perfil: PerfilDeCarrera): number {
  return ritmoPrevistoSegPorKm(perfil, Math.max(perfil.meta.distanciaKm, 1.0));
}

/**
 * paceRangeFor: el rango de cada tipo de sesión, colgado de los ritmos equivalentes de maratón,
 * 10K y 5K (referencia de los sistemas tipo VDOT, según el Kotlin).
 *
 * ⚠️ Rareza del Kotlin, portada tal cual: decide por el deporte PRINCIPAL y no por el de la
 * sesión. Por eso sólo el ciclismo se queda sin ritmo, mientras que un trekking —y la natación o
 * la bici de un triatlón— salen con ritmo de carrera a pie.
 */
export function rangoDeRitmo(perfil: PerfilDeRango, tipo: TipoDeSesion): RangoDeRitmo | null {
  if (perfil.deportePrincipal === "ciclismo" || perfil.deportePrincipal === "natacion") return null;
  const maraton = ritmoPrevistoSegPorKm(perfil, 42.195);
  const diezK = ritmoPrevistoSegPorKm(perfil, 10.0);
  const cincoK = ritmoPrevistoSegPorKm(perfil, 5.0);
  switch (tipo) {
    case "regenerativo":
      return { bajo: maraton + 90, alto: maraton + 130 };
    case "suave":
      return { bajo: maraton + 55, alto: maraton + 95 };
    case "fondo":
      return { bajo: maraton + 35, alto: maraton + 80 };
    case "tempo":
      return { bajo: diezK + 20, alto: diezK + 40 };
    case "umbral":
      return { bajo: diezK + 5, alto: diezK + 20 };
    case "series":
      return { bajo: cincoK - 10, alto: cincoK + 8 };
    case "cuestas":
      return { bajo: cincoK + 10, alto: cincoK + 40 };
    case "fartlek":
      return { bajo: diezK, alto: diezK + 45 };
    case "ritmo_carrera":
    case "carrera": {
      const objetivo = ritmoDeCarreraSegPorKm(perfil);
      return { bajo: objetivo - 8, alto: objetivo + 8 };
    }
    case "descanso":
    case "fuerza":
      return null;
  }
}

/** cyclingSpeedKmh: velocidad media en bici por nivel, para dimensionar el plan. */
export function velocidadEnBiciKmh(nivel: Nivel): number {
  return { principiante: 23.0, intermedio: 28.0, avanzado: 32.0 }[nivel];
}

/** trekkingSpeedKmh: velocidad media caminando en montaña por nivel. */
export function velocidadEnTrekkingKmh(nivel: Nivel): number {
  return { principiante: 3.5, intermedio: 4.2, avanzado: 5.0 }[nivel];
}

/** estimatedGoalTimeMinutes: minutos estimados del evento (truncados). */
export function minutosDelEvento(perfil: PerfilDeCarrera): number {
  const { meta, nivel } = perfil;
  switch (meta.deporte) {
    case "running":
      return Math.trunc((ritmoDeCarreraSegPorKm(perfil) * meta.distanciaKm) / 60.0);
    case "ciclismo":
      return Math.trunc((meta.distanciaKm / velocidadEnBiciKmh(nivel)) * 60);
    case "trekking":
      return Math.trunc((meta.distanciaKm / velocidadEnTrekkingKmh(nivel)) * 60);
    default:
      return meta.minutosDelEvento[nivel];
  }
}
