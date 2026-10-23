/**
 * dominios/plan/servicio.ts — del perfil al motor, y del motor a lo que se ve.
 *
 * El motor (motor/) es PURO: no lee la base ni el reloj (docs/PROPUESTA-MOTOR.md
 * §1). Este archivo es el que lo alimenta —el perfil de la persona y el ancla del
 * bloque— y el que junta lo que el motor no sabe: qué días ya se entrenaron.
 */
import { createHash } from "node:crypto";
import type { Contexto } from "../../contexto.js";
import { ErrorApi } from "../../infra/errores.js";
import { edadEn, fechaLocal, fechaUTC, inicioDelDiaMs, sumarDias, zonaValida } from "../../infra/fechas.js";
import { crearRepoPerfil, type PerfilFila } from "../perfil/repositorio.js";
import { crearRepoActividades } from "../actividades/repositorio.js";
import { crearRepoGimnasio } from "../gimnasio/repositorio.js";
import { crearRepoPlan, type PlanFila } from "./repositorio.js";
import { crearRepoObjetivos } from "../objetivos/repositorio.js";
import { crearRepoHechosAMano } from "./hechos-a-mano.js";
import { generarPlan, MOTOR_VERSION } from "./motor/generador.js";
import type {
  DeportePerfil,
  DiaDeEntrenamiento,
  DiaPlanificado,
  EntradaDelMotor,
  Nivel,
  Objetivo,
  PlanGenerado,
  SexoBiologico,
} from "./motor/tipos.js";

export interface PlanCalculado {
  plan: PlanGenerado;
  ancla: PlanFila;
  entrada: EntradaDelMotor;
  zona: string;
  perfil: PerfilFila;
  /** Hash de TODO lo que entró al cálculo, con la versión del motor. */
  hashEntrada: string;
}

export interface HechoDelDia {
  /** Actividades o días de gimnasio REGISTRADOS. Es lo único que cuenta para la racha. */
  sesiones: number;
  metros: number;
  /**
   * La persona lo marcó como hecho sin una salida registrada (contrato 1.7.0). El
   * día cuenta como hecho y como sesión de su semana, sin metros y sin racha.
   */
  aMano?: boolean;
}

/** Hecho para el plan y la semana: registrado, o marcado a mano. */
export function diaHecho(h: HechoDelDia | undefined): boolean {
  return h !== undefined && (h.sesiones > 0 || h.aMano === true);
}

function sha256(texto: string): string {
  return createHash("sha256").update(texto).digest("hex");
}

function diasDelPerfil(crudo: unknown): DiaDeEntrenamiento[] {
  if (!Array.isArray(crudo)) return [];
  return crudo.flatMap((d: { weekday?: unknown; minute_of_day?: unknown }) =>
    typeof d?.weekday === "number" && typeof d?.minute_of_day === "number"
      ? [{ weekday: d.weekday, minuteOfDay: d.minute_of_day }]
      : []
  );
}

/**
 * Lo ESTRUCTURAL: lo que, si cambia, obliga a un bloque nuevo desde ese día.
 *
 * La hora de cada día no está: cambiar el martes de las 7 a las 19 corre la sesión,
 * no el bloque. El peso y la edad tampoco: cambian kcal, pulso y avituallamiento,
 * que se recalculan sobre el mismo ancla (005_plan.sql).
 */
export function hashEstructural(e: {
  objetivo: string;
  nivel: string;
  deporte: string;
  zona: string;
  fechaEvento: string | null;
  weekdays: readonly number[];
}): string {
  const weekdays = [...new Set(e.weekdays)].sort((a, b) => a - b);
  return sha256(JSON.stringify([e.objetivo, e.nivel, e.deporte, e.zona, e.fechaEvento, weekdays]));
}

export async function calcularPlan(ctx: Contexto, usuarioId: string, objetivoId: string | null = null): Promise<PlanCalculado> {
  const perfil = await crearRepoPerfil(ctx.db).leer(usuarioId);
  if (perfil === null) throw new ErrorApi("not_found", "Profile not found");
  if (objetivoId !== null) {
    const adicional = await crearRepoObjetivos(ctx.db).adicional(usuarioId, objetivoId);
    if (adicional === null) throw new ErrorApi("not_found", "Goal not found");
    perfil.objetivo = adicional.goal;
    perfil.objetivo_fecha_ms = adicional.goal_date_ms;
  }

  const zona = perfil.zona_horaria;
  const dias = diasDelPerfil(perfil.dias_entrenamiento);
  if (
    perfil.objetivo === null ||
    perfil.nivel === null ||
    perfil.deporte === null ||
    zona === null ||
    !zonaValida(zona) ||
    dias.length === 0
  ) {
    throw new ErrorApi(
      "profile_incomplete",
      "The plan needs goal, level, sport, timezone and at least one training day"
    );
  }

  const ahora = ctx.ahoraMs();
  // La fecha de la carrera es una fecha SIN HORA: se lee en UTC (infra/fechas.ts, fechaUTC).
  const fechaEvento = perfil.objetivo_fecha_ms === null ? null : fechaUTC(perfil.objetivo_fecha_ms);
  const estructural = hashEstructural({
    objetivo: perfil.objetivo,
    nivel: perfil.nivel,
    deporte: perfil.deporte,
    zona,
    fechaEvento,
    weekdays: dias.map((d) => d.weekday),
  });

  const repo = crearRepoPlan(ctx.db);
  let ancla = await repo.vigente(usuarioId, objetivoId);
  if (ancla === null || ancla.entrada_hash !== estructural) {
    ancla = await repo.anclar(usuarioId, MOTOR_VERSION, estructural, fechaLocal(ahora, zona), zona, ahora, objetivoId);
  }

  const entradaDesde = (inicio: string): EntradaDelMotor => ({
    objetivo: perfil.objetivo as Objetivo,
    nivel: perfil.nivel as Nivel,
    deporte: perfil.deporte as DeportePerfil,
    dias,
    inicio,
    fechaEvento,
    pesoG: perfil.peso_g,
    // La edad al empezar el bloque: si cumple años a mitad, el bloque no cambia.
    edad: perfil.nacimiento_ms === null ? null : edadEn(perfil.nacimiento_ms, inicio),
    sexo: perfil.sexo_biologico as SexoBiologico | null,
  });

  let entrada = entradaDesde(ancla.inicio_fecha);
  let plan = generarPlan(entrada);

  // Un bloque que ya terminó y cuyo objetivo sigue vigente —sin fecha, o con la fecha todavía por
  // delante— arranca de nuevo HOY. Sin esto, volver a elegir el mismo objetivo (el mismo hash
  // estructural) dejaba el ancla vieja, y el plan seguía entero en el pasado: la app mostraba
  // "tu plan terminó" una y otra vez, como si la meta no se hubiera guardado. Si la fecha del
  // evento ya pasó, el bloque terminado se conserva: es la carrera hecha, y la app ofrece otra meta.
  const hoy = fechaLocal(ahora, zona);
  const ultimoDia = plan.dias.at(-1)?.fecha;
  if (ultimoDia !== undefined && ultimoDia < hoy && (fechaEvento === null || fechaEvento >= hoy)) {
    ancla = await repo.renovar(usuarioId, ancla.id, MOTOR_VERSION, estructural, hoy, zona, ahora, objetivoId);
    entrada = entradaDesde(ancla.inicio_fecha);
    plan = generarPlan(entrada);
  }

  return {
    plan,
    ancla,
    entrada,
    zona,
    perfil,
    hashEntrada: sha256(JSON.stringify({ motor: plan.version, entrada })),
  };
}

/**
 * Qué días del bloque ya tienen algo registrado: una actividad, o series de
 * gimnasio hechas. Es lo que el motor no puede saber y la pantalla sí muestra.
 * Los días marcados a mano (1.7.0) entran con `aMano` y CERO sesiones: así la
 * racha, que mira `sesiones`, no los cuenta.
 */
export async function hechosDelBloque(
  ctx: Contexto,
  usuarioId: string,
  calculado: PlanCalculado
): Promise<Map<string, HechoDelDia>> {
  const { plan, zona } = calculado;
  const primero = plan.dias[0]?.fecha;
  const ultimo = plan.dias.at(-1)?.fecha;
  const porFecha = new Map<string, HechoDelDia>();
  if (primero === undefined || ultimo === undefined) return porFecha;

  const [actividades, conSeries, aMano] = await Promise.all([
    crearRepoActividades(ctx.db).enRango(
      usuarioId,
      inicioDelDiaMs(primero, zona),
      inicioDelDiaMs(sumarDias(ultimo, 1), zona)
    ),
    crearRepoGimnasio(ctx.db).fechasConSeries(usuarioId, primero, ultimo),
    crearRepoHechosAMano(ctx.db).enRango(usuarioId, primero, ultimo),
  ]);

  const sumar = (fecha: string, metros: number) => {
    const previo = porFecha.get(fecha) ?? { sesiones: 0, metros: 0 };
    porFecha.set(fecha, { sesiones: previo.sesiones + 1, metros: previo.metros + metros });
  };
  for (const a of actividades) sumar(fechaLocal(a.inicio_ms, zona), a.distancia_m ?? 0);
  for (const fecha of conSeries) sumar(fecha, 0);
  for (const fecha of aMano) {
    porFecha.set(fecha, { ...(porFecha.get(fecha) ?? { sesiones: 0, metros: 0 }), aMano: true });
  }
  return porFecha;
}

export interface Racha {
  dias: number;
  activa_hoy: boolean;
  entrenado_hoy: boolean;
  toca_hoy: boolean;
}

/**
 * Racha (fueguitos) estilo Duolingo:
 * - Cuenta días de entrenamiento completados consecutivos.
 * - Los días de descanso NO rompen la racha ni requieren entrenar.
 * - Si un día que tocaba entrenar pasa sin registrarse, la racha se pierde (0).
 *   Marcarlo después como hecho a mano (1.7.0) NO la devuelve: acá sólo cuentan
 *   las `sesiones` registradas, nunca `aMano`.
 * - En el día actual: si toca entrenar y se entrena, se enciende el fueguito;
 *   si no se entrenó aún, el fueguito espera sin romperse hasta que pase el día.
 */
export function calcularRacha(
  dias: DiaPlanificado[],
  hechos: Map<string, HechoDelDia>,
  hoyFecha: string
): Racha {
  const diaHoy = dias.find((d) => d.fecha === hoyFecha);
  const hechoHoy = hechos.get(hoyFecha);
  const entrenadoHoy = (hechoHoy?.sesiones ?? 0) > 0;
  const tocaHoy = diaHoy !== undefined && diaHoy.tipo !== "descanso";

  const pasadosEntrenamiento = dias
    .filter((d) => d.fecha < hoyFecha && d.tipo !== "descanso")
    .sort((a, b) => a.fecha.localeCompare(b.fecha));

  let rachaPasada = 0;
  let rachaRota = false;

  for (let i = pasadosEntrenamiento.length - 1; i >= 0; i--) {
    const dia = pasadosEntrenamiento[i]!;
    const hecho = (hechos.get(dia.fecha)?.sesiones ?? 0) > 0;
    if (hecho) {
      if (!rachaRota) {
        rachaPasada++;
      }
    } else {
      rachaRota = true;
      break;
    }
  }

  if (tocaHoy) {
    if (entrenadoHoy) {
      const diasRacha = rachaRota && pasadosEntrenamiento.length > 0 && !((hechos.get(pasadosEntrenamiento[pasadosEntrenamiento.length - 1]!.fecha)?.sesiones ?? 0) > 0)
        ? 1
        : rachaPasada + 1;
      return {
        dias: diasRacha,
        activa_hoy: true,
        entrenado_hoy: true,
        toca_hoy: true,
      };
    } else {
      const ultimoPasado = pasadosEntrenamiento[pasadosEntrenamiento.length - 1];
      const ultimoPasadoHecho = ultimoPasado ? (hechos.get(ultimoPasado.fecha)?.sesiones ?? 0) > 0 : true;
      const diasRacha = ultimoPasadoHecho ? rachaPasada : 0;
      return {
        dias: diasRacha,
        activa_hoy: false,
        entrenado_hoy: false,
        toca_hoy: true,
      };
    }
  } else {
    const ultimoPasado = pasadosEntrenamiento[pasadosEntrenamiento.length - 1];
    const ultimoPasadoHecho = ultimoPasado ? (hechos.get(ultimoPasado.fecha)?.sesiones ?? 0) > 0 : true;
    const diasRacha = ultimoPasadoHecho ? rachaPasada : 0;
    return {
      dias: diasRacha,
      activa_hoy: diasRacha > 0,
      entrenado_hoy: entrenadoHoy,
      toca_hoy: false,
    };
  }
}
