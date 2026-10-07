/**
 * Tests del motor de plan (dominios/plan/motor).
 *
 * En cuatro partes:
 *  1. Los 11 tests de TrainingPlanGeneratorTest.kt, portados uno a uno: la especificación
 *     ejecutable de lo que el port tiene que seguir haciendo (docs/PROPUESTA-MOTOR.md §5.4).
 *  2. Casos de oro (§5.2): días copiados de lo que devolvió el Kotlin original, compilado, con sus
 *     números y sus textos. Si uno cambia, cambió el motor: es para mirarlo, no para pisar el
 *     valor esperado.
 *  3. Las propiedades de §5.3, sobre miles de perfiles.
 *  4. Lo que el port cambió a propósito (excepción b, peso y edad sin dato, la entrada, los textos)
 *     y las rarezas del Kotlin que se portaron tal cual: así arreglarlas es una decisión que se ve
 *     en un diff, y no un accidente.
 *
 * Portar no es verificar (§2): que esto pase dice que el port hace lo mismo que el Kotlin, no que
 * el Kotlin tenga razón.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { generarPlan, MOTOR_VERSION } from "../src/dominios/plan/motor/generador.js";
import { textosDelDia } from "../src/dominios/plan/motor/textos.js";
import { aDia, aTexto, diaDeLaSemana } from "../src/dominios/plan/motor/fechas.js";
import {
  CODIGOS_DE_MOTIVO,
  type Avituallamiento,
  type CodigoDeMotivo,
  type DeportePerfil,
  type DiaDeEntrenamiento,
  type DiaPlanificado,
  type EntradaDelMotor,
  type Locale,
  type Nivel,
  type Objetivo,
  type PlanGenerado,
} from "../src/dominios/plan/motor/tipos.js";

const LOCALES: readonly Locale[] = ["es-AR", "en-US"];
const sumarDias = (fecha: string, dias: number): string => aTexto(aDia(fecha) + dias);
const semanaDe = (plan: PlanGenerado, numero: number): DiaPlanificado[] => plan.dias.filter((d) => d.semana === numero);
const TODOS_LOS_DIAS: DiaDeEntrenamiento[] = [1, 2, 3, 4, 5, 6, 7].map((weekday) => ({ weekday, minuteOfDay: 420 }));

/** Los días de cada semana, en una pasada. */
function porSemana(plan: PlanGenerado): DiaPlanificado[][] {
  const semanas: DiaPlanificado[][] = [];
  for (const d of plan.dias) (semanas[d.semana - 1] ??= []).push(d);
  return semanas;
}

const inicio = "2026-03-02"; // lunes

/** El perfil de TrainingPlanGeneratorTest.kt. Edad y sexo: los valores por defecto de UserProfile. */
const perfil: EntradaDelMotor = {
  objetivo: "media_maraton",
  nivel: "intermedio",
  deporte: "running",
  dias: [
    { weekday: 2, minuteOfDay: 19 * 60 },
    { weekday: 4, minuteOfDay: 19 * 60 },
    { weekday: 5, minuteOfDay: 7 * 60 },
    { weekday: 7, minuteOfDay: 8 * 60 + 30 },
  ],
  inicio,
  fechaEvento: sumarDias(inicio, 12 * 7),
  pesoG: 72_000,
  edad: 30,
  sexo: "masculino",
};

// Las entradas de los casos de oro: las mismas que se le pasaron al Kotlin.
const corredora: EntradaDelMotor = {
  objetivo: "media_maraton",
  nivel: "principiante",
  deporte: "running",
  dias: [1, 2, 4, 5].map((weekday) => ({ weekday, minuteOfDay: 360 })).concat({ weekday: 6, minuteOfDay: 600 }),
  inicio: "2027-01-01",
  fechaEvento: "2027-01-14",
  pesoG: 76_000,
  edad: 35,
  sexo: "femenino",
};
const triatleta: EntradaDelMotor = {
  objetivo: "c5k",
  nivel: "principiante",
  deporte: "triatlon",
  dias: [1, 2, 3, 4, 5].map((weekday) => ({ weekday, minuteOfDay: 360 })).concat({ weekday: 6, minuteOfDay: 600 }),
  inicio: "2026-09-10",
  fechaEvento: "2027-02-07",
  pesoG: 76_500,
  edad: 26,
  sexo: "sin_declarar",
};
const caminante: EntradaDelMotor = {
  objetivo: "c5k",
  nivel: "intermedio",
  deporte: "trekking",
  dias: [3, 4, 6, 7].map((weekday) => ({ weekday, minuteOfDay: 600 })),
  inicio: "2027-01-01",
  fechaEvento: "2027-01-07",
  pesoG: 80_000,
  edad: 33,
  sexo: "femenino",
};

// ─── 1. TrainingPlanGeneratorTest.kt ────────────────────────────────────────────────────────

describe("TrainingPlanGeneratorTest.kt, portado", () => {
  const plan = generarPlan(perfil);

  test("el plan cubre todos los días hasta el evento", () => {
    const fechas = [...new Set(plan.dias.map((d) => d.fecha))];
    assert.equal(fechas.length, 85); // 12 semanas + el día del evento
    assert.equal(fechas[0], inicio);
    assert.equal(fechas.at(-1), perfil.fechaEvento);
  });

  test("el último día es la competencia", () => {
    assert.equal(plan.dias.at(-1)?.tipo, "carrera");
    assert.equal(plan.dias.at(-1)?.fase, "carrera");
  });

  test("respeta la cantidad de días de entrenamiento por semana", () => {
    assert.equal(semanaDe(plan, 2).filter((d) => d.tipo !== "descanso").length, perfil.dias.length);
  });

  test("el afinamiento baja el volumen antes del evento", () => {
    const porSemanaMin = new Map<number, number>();
    for (const d of plan.dias) porSemanaMin.set(d.semana, (porSemanaMin.get(d.semana) ?? 0) + d.duracionMin);
    const pico = Math.max(...porSemanaMin.values());
    const ultimaSemanaCompleta = porSemanaMin.get(Math.max(...porSemanaMin.keys()) - 1) ?? 0;
    assert.ok(ultimaSemanaCompleta < pico, "el afinamiento tiene que bajar el volumen");
  });

  test("las fases van de base a afinamiento", () => {
    const fases = new Set(plan.dias.map((d) => d.fase));
    for (const fase of ["base", "construccion", "pico", "afinamiento"] as const) assert.ok(fases.has(fase), fase);
  });

  test("todas las sesiones tienen consejo de combustible", () => {
    // En el Kotlin era `fuelingTip`. Acá es la última línea del detalle, en cada idioma.
    for (const d of plan.dias) {
      for (const locale of LOCALES) {
        const consejo = textosDelDia(d, locale).detalle.split("\n").at(-1) ?? "";
        assert.ok(consejo.trim().length > 0, `${d.fecha} ${locale}`);
      }
    }
  });

  test("el fondo largo cae el domingo si está disponible", () => {
    const fondos = plan.dias.filter((d) => d.tipo === "fondo");
    assert.ok(fondos.length > 0);
    assert.ok(fondos.every((d) => d.weekday === 7), "todos los fondos tienen que caer domingo");
  });

  test("las sesiones heredan el horario elegido", () => {
    const martes = plan.dias.find((d) => d.weekday === 2 && d.tipo !== "descanso");
    const domingo = plan.dias.find((d) => d.weekday === 7 && d.tipo === "fondo");
    assert.equal(martes?.minutoDelDia, 19 * 60);
    assert.equal(domingo?.minutoDelDia, 8 * 60 + 30);
  });

  test("sólo se entrena en los días elegidos", () => {
    const entrenados = new Set(plan.dias.filter((d) => d.tipo !== "descanso" && d.tipo !== "carrera").map((d) => d.weekday));
    assert.deepEqual(
      [...entrenados].sort((a, b) => a - b),
      perfil.dias.map((d) => d.weekday).sort((a, b) => a - b)
    );
  });

  test("una agenda de tres días no genera dobles sesiones", () => {
    const tresDias = generarPlan({
      ...perfil,
      dias: [
        { weekday: 1, minuteOfDay: 7 * 60 },
        { weekday: 3, minuteOfDay: 7 * 60 },
        { weekday: 6, minuteOfDay: 9 * 60 },
      ],
    });
    const semana = semanaDe(tresDias, 3);
    assert.equal(semana.filter((d) => d.tipo !== "descanso").length, 3);
    assert.equal(semana.filter((d) => d.tipo === "fondo").length, 1);
  });

  test("sin fecha de evento genera 8 semanas", () => {
    const sinEvento = generarPlan({ ...perfil, fechaEvento: null });
    assert.ok(Math.max(...sinEvento.dias.map((d) => d.semana)) >= 8);
  });
});

// ─── 2. Casos de oro ────────────────────────────────────────────────────────────────────────

interface DiaDeOro {
  readonly entrada: EntradaDelMotor;
  readonly fecha: string;
  readonly datos: Omit<DiaPlanificado, "fecha" | "indice" | "weekday" | "semana" | "esSemanaDeDescarga" | "avituallamiento" | "motivos">;
  readonly avituallamiento: Avituallamiento | null;
  /** Los motivos no existían en el Kotlin: salen de aplicar a mano sus reglas de assignSlots. */
  readonly motivos: readonly CodigoDeMotivo[];
  readonly titulo: string;
  /** La description del Kotlin, un salto de línea, y su fuelingTip. */
  readonly detalle: string;
}

const ORO: readonly DiaDeOro[] = [
  {
    entrada: corredora,
    fecha: "2027-01-01",
    datos: { fase: "pico", tipo: "fuerza", deporte: "fuerza", minutoDelDia: 360, duracionMin: 35, distanciaM: null, zona: "z2", fcMinLpm: 109, fcMaxLpm: 128, ritmoMinSegKm: null, ritmoMaxSegKm: null, kcal: 232 },
    avituallamiento: { liquidoMlPorHora: 419, liquidoTotalMl: 244, sodioMgPorHora: 0, sodioTotalMg: 0, carbohidratosGPorHora: 0, carbohidratosTotalG: 0, geles: 0, preLiquidoMl: 456, preCarbohidratosG: 38, postLiquidoMl: 300, postCarbohidratosG: 76, postProteinaG: 23 },
    motivos: ["fuerza_antes_del_fondo", "fase_pico"],
    titulo: "Fuerza para corredores (35 min)",
    detalle:
      "Circuito de fuerza: sentadillas, estocadas, puente de glúteo, plancha y trabajo excéntrico de gemelos e isquiotibiales. 3 series x 10-12 repeticiones. Reduce el riesgo de lesión por sobrecarga.\n" +
      "Zona Z2 Base aeróbica (109-128 ppm)\n" +
      "Proteína dentro de la hora posterior (23 g).",
  },
  {
    entrada: corredora,
    fecha: "2027-01-02",
    datos: { fase: "pico", tipo: "fondo", deporte: "running", minutoDelDia: 600, duracionMin: 94, distanciaM: 11_000, zona: "z2", fcMinLpm: 109, fcMaxLpm: 128, ritmoMinSegKm: 492, ritmoMaxSegKm: 537, kcal: 866 },
    avituallamiento: { liquidoMlPorHora: 795, liquidoTotalMl: 1245, sodioMgPorHora: 428, sodioTotalMg: 670, carbohidratosGPorHora: 50, carbohidratosTotalG: 78, geles: 4, preLiquidoMl: 456, preCarbohidratosG: 91, postLiquidoMl: 1150, postCarbohidratosG: 76, postProteinaG: 23 },
    motivos: ["fondo_en_fin_de_semana", "fase_pico"],
    titulo: "Running: fondo largo (94 min)",
    detalle:
      "Fondo continuo a ritmo cómodo. Es la sesión clave de la semana: usála también para ensayar tu estrategia de hidratación y geles tal como la usarías en carrera.\n" +
      "Zona Z2 Base aeróbica (109-128 ppm) · Ritmo 8:12 - 8:57 min/km\n" +
      "Llevá 1245 ml, 78 g de hidratos y 670 mg de sodio.",
  },
  {
    entrada: corredora,
    fecha: "2027-01-03",
    datos: { fase: "pico", tipo: "descanso", deporte: "otro", minutoDelDia: null, duracionMin: 0, distanciaM: null, zona: null, fcMinLpm: null, fcMaxLpm: null, ritmoMinSegKm: null, ritmoMaxSegKm: null, kcal: 0 },
    avituallamiento: null,
    motivos: ["dia_no_elegido", "fase_pico"],
    titulo: "Descanso",
    detalle:
      "Día libre. Movilidad suave, elongación y buen descanso nocturno: la adaptación ocurre cuando descansás, no mientras entrenás.\n" +
      "Día de menor carga: bajá los hidratos y sostené la proteína e hidratación.",
  },
  {
    entrada: corredora,
    fecha: "2027-01-04",
    datos: { fase: "pico", tipo: "ritmo_carrera", deporte: "running", minutoDelDia: 360, duracionMin: 50, distanciaM: 6_800, zona: "z3", fcMinLpm: 128, fcMaxLpm: 146, ritmoMinSegKm: 431, ritmoMaxSegKm: 447, kcal: 535 },
    avituallamiento: { liquidoMlPorHora: 800, liquidoTotalMl: 666, sodioMgPorHora: 0, sodioTotalMg: 0, carbohidratosGPorHora: 25, carbohidratosTotalG: 20, geles: 1, preLiquidoMl: 456, preCarbohidratosG: 38, postLiquidoMl: 926, postCarbohidratosG: 76, postProteinaG: 23 },
    motivos: ["calidad_con_mas_descanso_previo", "fase_pico"],
    titulo: "Ritmo de carrera · Running (50 min)",
    detalle:
      "15 min de entrada en calor + 20 min a ritmo objetivo de carrera + 10 min suaves. Ensayá con la ropa y los geles que vas a usar el día del evento.\n" +
      "Zona Z3 Tempo (128-146 ppm) · Ritmo 7:11 - 7:27 min/km\n" +
      "Agua a demanda (800 ml/h). No hacen falta geles.",
  },
  {
    entrada: corredora,
    fecha: "2027-01-14",
    datos: { fase: "carrera", tipo: "carrera", deporte: "running", minutoDelDia: 360, duracionMin: 154, distanciaM: 21_097, zona: "z4", fcMinLpm: 146, fcMaxLpm: 164, ritmoMinSegKm: 431, ritmoMaxSegKm: 447, kcal: 1661 },
    avituallamiento: { liquidoMlPorHora: 800, liquidoTotalMl: 2053, sodioMgPorHora: 799, sodioTotalMg: 2050, carbohidratosGPorHora: 70, carbohidratosTotalG: 179, geles: 8, preLiquidoMl: 456, preCarbohidratosG: 152, postLiquidoMl: 3441, postCarbohidratosG: 76, postProteinaG: 23 },
    motivos: ["dia_del_evento", "objetivo_media_maraton"],
    titulo: "Media maratón",
    detalle:
      "Objetivo: Media maratón. Ritmo estimado 7:19 min/km para un tiempo aproximado de 2 h 34 min. Salí conservador los primeros kilómetros y respetá el plan de hidratación desde el minuto uno.\n" +
      "En carrera: 800 ml/h, 799 mg de sodio/h y 70 g de hidratos/h. Desayuno 3 h antes con 152 g de hidratos.",
  },
  {
    // Triatlón: la segunda calidad se nada. Y con ritmo a pie: ver las rarezas.
    entrada: triatleta,
    fecha: "2026-09-16",
    datos: { fase: "base", tipo: "tempo", deporte: "natacion", minutoDelDia: 360, duracionMin: 25, distanciaM: 1_100, zona: "z3", fcMinLpm: 132, fcMaxLpm: 151, ritmoMinSegKm: 440, ritmoMaxSegKm: 460, kcal: 334 },
    avituallamiento: { liquidoMlPorHora: 496, liquidoTotalMl: 206, sodioMgPorHora: 0, sodioTotalMg: 0, carbohidratosGPorHora: 0, carbohidratosTotalG: 0, geles: 0, preLiquidoMl: 459, preCarbohidratosG: 38, postLiquidoMl: 300, postCarbohidratosG: 77, postProteinaG: 23 },
    motivos: ["segunda_calidad_lejos_de_la_primera", "fase_base", "triatlon_rota_deportes"],
    titulo: "Tempo · Natación (25 min)",
    detalle:
      "15 min de entrada en calor + 11 min continuos a ritmo tempo + 10 min de vuelta a la calma.\n" +
      "Zona Z3 Tempo (132-151 ppm) · Ritmo 7:20 - 7:40 min/km\n" +
      "Agua a demanda (496 ml/h). No hacen falta geles.",
  },
  {
    // 55 min a 4,2 km/h son 3,85 km: el Kotlin desempata al par y da 3,8. Con Math.round serían
    // 3900 m y 323 kcal.
    entrada: caminante,
    fecha: "2027-01-06",
    datos: { fase: "pico", tipo: "ritmo_carrera", deporte: "trekking", minutoDelDia: 600, duracionMin: 55, distanciaM: 3_800, zona: "z3", fcMinLpm: 128, fcMaxLpm: 147, ritmoMinSegKm: 308, ritmoMaxSegKm: 324, kcal: 314 },
    avituallamiento: { liquidoMlPorHora: 661, liquidoTotalMl: 605, sodioMgPorHora: 0, sodioTotalMg: 0, carbohidratosGPorHora: 25, carbohidratosTotalG: 22, geles: 1, preLiquidoMl: 480, preCarbohidratosG: 40, postLiquidoMl: 559, postCarbohidratosG: 80, postProteinaG: 24 },
    motivos: ["calidad_con_mas_descanso_previo", "fase_pico"],
    titulo: "Ritmo de carrera · Trekking (55 min)",
    detalle:
      "15 min de entrada en calor + 22 min a ritmo objetivo de carrera + 10 min suaves. Ensayá con la ropa y los geles que vas a usar el día del evento.\n" +
      "Zona Z3 Tempo (128-147 ppm) · Ritmo 5:08 - 5:24 min/km\n" +
      "Agua a demanda (661 ml/h). No hacen falta geles.",
  },
];

describe("casos de oro: lo que devolvió el Kotlin original, compilado", () => {
  for (const oro of ORO) {
    test(`${oro.entrada.objetivo}/${oro.entrada.deporte} ${oro.fecha}: ${oro.titulo}`, () => {
      const d = generarPlan(oro.entrada).dias.find((x) => x.fecha === oro.fecha);
      assert.ok(d, oro.fecha);
      const { fecha: _f, indice: _i, weekday: _w, semana: _s, esSemanaDeDescarga: _e, avituallamiento, motivos, ...datos } = d;
      assert.deepEqual(datos, oro.datos);
      assert.deepEqual(avituallamiento, oro.avituallamiento);
      assert.deepEqual(motivos, oro.motivos);
      const textos = textosDelDia(d, "es-AR");
      assert.equal(textos.titulo, oro.titulo);
      assert.equal(textos.detalle, oro.detalle);
    });
  }
});

// ─── 3. Propiedades (§5.3) ──────────────────────────────────────────────────────────────────

const OBJETIVOS: readonly Objetivo[] = ["c5k", "c10k", "media_maraton", "maraton", "trail_montana", "triatlon_olimpico", "volver_sin_lesiones"];
const NIVELES: readonly Nivel[] = ["principiante", "intermedio", "avanzado"];
const DEPORTES: readonly DeportePerfil[] = ["running", "ciclismo", "trekking", "triatlon"];
const AGENDAS: readonly (readonly number[])[] = [[7], [2, 4], [1, 3, 6], [2, 4, 5, 7], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5, 6], [1, 2, 3, 4, 5, 6, 7]];
/** Sin fecha, hoy, a 10 días, y a 12, 20 y 40 semanas. */
const DIAS_AL_EVENTO: readonly (number | null)[] = [null, 0, 10, 84, 140, 280];
/** Lunes, jueves y domingo: la semana del plan arranca el día de inicio, no el lunes. */
const INICIOS = ["2026-03-02", "2026-09-10", "2028-02-27"] as const;
const SEXOS = ["femenino", "masculino", "sin_declarar", null] as const;
const TOTAL_DE_PERFILES = OBJETIVOS.length * NIVELES.length * DEPORTES.length * AGENDAS.length * DIAS_AL_EVENTO.length;

interface Caso {
  readonly id: string;
  readonly entrada: EntradaDelMotor;
  readonly plan: PlanGenerado;
}

/** Se generan de a uno: guardarlos todos serían cientos de miles de días en memoria. */
function* perfiles(): Generator<Caso> {
  let i = 0;
  for (const objetivo of OBJETIVOS) {
    for (const nivel of NIVELES) {
      for (const deporte of DEPORTES) {
        for (const agenda of AGENDAS) {
          for (const dias of DIAS_AL_EVENTO) {
            i++;
            const desde = INICIOS[i % INICIOS.length] ?? inicio;
            const entrada: EntradaDelMotor = {
              objetivo,
              nivel,
              deporte,
              dias: agenda.map((weekday) => ({ weekday, minuteOfDay: 360 + weekday })),
              inicio: desde,
              fechaEvento: dias === null ? null : sumarDias(desde, dias),
              pesoG: i % 5 === 0 ? null : 50_000 + (i % 7) * 5_000,
              edad: i % 6 === 0 ? null : 18 + (i % 60),
              sexo: SEXOS[i % SEXOS.length] ?? null,
            };
            const id = `${objetivo}/${nivel}/${deporte} días [${agenda.join(",")}] desde ${desde} evento ${entrada.fechaEvento}`;
            yield { id, entrada, plan: generarPlan(entrada) };
          }
        }
      }
    }
  }
}

describe(`docs/PROPUESTA-MOTOR.md §5.3: propiedades, sobre ${TOTAL_DE_PERFILES} perfiles`, () => {
  test("nunca sale vacío", () => {
    for (const { id, plan } of perfiles()) {
      assert.ok(plan.dias.length > 0 && plan.semanas.length > 0 && plan.fases.length > 0, id);
    }
  });

  test("días, semanas y fases cuentan la misma historia, sin huecos", () => {
    for (const { id, entrada, plan } of perfiles()) {
      const primero = aDia(entrada.inicio);
      const diaMal = plan.dias.find(
        (d, i) =>
          d.indice !== i ||
          d.fecha !== aTexto(primero + i) ||
          d.weekday !== diaDeLaSemana(primero + i) ||
          d.semana !== Math.trunc(i / 7) + 1
      );
      assert.equal(diaMal, undefined, id);

      assert.equal(plan.totalSemanas, plan.semanas.length, id);
      porSemana(plan).forEach((suyos, j) => {
        const s = plan.semanas[j];
        const primerDia = suyos[0];
        assert.ok(s && primerDia, id);
        assert.deepEqual(
          [s.numero, s.inicio, s.fase, s.esDescarga, s.minutosPrevistos, s.metrosPrevistos],
          [
            j + 1,
            primerDia.fecha,
            primerDia.fase,
            primerDia.esSemanaDeDescarga,
            suyos.reduce((total, d) => total + d.duracionMin, 0),
            suyos.reduce((total, d) => total + (d.distanciaM ?? 0), 0),
          ],
          `${id} semana ${j + 1}`
        );
      });

      let siguiente = 1;
      plan.fases.forEach((tramo, k) => {
        assert.equal(tramo.primeraSemana, siguiente, id);
        assert.ok(tramo.ultimaSemana >= tramo.primeraSemana, id);
        assert.notEqual(tramo.fase, plan.fases[k - 1]?.fase, id);
        const ajena = plan.semanas.slice(tramo.primeraSemana - 1, tramo.ultimaSemana).find((s) => s.fase !== tramo.fase);
        assert.equal(ajena, undefined, id);
        siguiente = tramo.ultimaSemana + 1;
      });
      assert.equal(siguiente, plan.totalSemanas + 1, id);
    }
  });

  test("sólo se entrena en los días elegidos, salvo el día del evento", () => {
    for (const { id, entrada, plan } of perfiles()) {
      const elegidos = new Set(entrada.dias.map((d) => d.weekday));
      const fuera = plan.dias.find(
        (d) => d.tipo !== "descanso" && (d.tipo === "carrera" ? d.fecha !== plan.fechaEvento : !elegidos.has(d.weekday))
      );
      assert.equal(fuera, undefined, id);
      assert.equal(plan.dias.filter((d) => d.tipo === "carrera").length, plan.fechaEvento === null ? 0 : 1, id);
      // Y en cada semana entera sin evento, se entrenan todos los días elegidos.
      for (const semana of porSemana(plan)) {
        if (semana.length === 7 && !semana.some((d) => d.tipo === "carrera")) {
          assert.equal(semana.filter((d) => d.tipo !== "descanso").length, elegidos.size, id);
        }
      }
    }
  });

  test("hay descarga cada 4 semanas en base y construcción, y en ningún otro lado", () => {
    let descargas = 0;
    for (const { id, plan } of perfiles()) {
      for (const s of plan.semanas) {
        const antesDelPico = s.fase === "base" || s.fase === "construccion";
        assert.equal(s.esDescarga, antesDelPico && s.numero % 4 === 0, `${id} semana ${s.numero} (${s.fase})`);
        if (s.esDescarga) descargas++;
      }
      const malMarcado = plan.dias.find(
        (d) =>
          d.esSemanaDeDescarga !== plan.semanas[d.semana - 1]?.esDescarga ||
          d.motivos.includes("semana_de_descarga") !== d.esSemanaDeDescarga
      );
      assert.equal(malMarcado, undefined, id);
    }
    assert.ok(descargas > 0, "la grilla tiene que incluir semanas de descarga");
  });

  test("la descarga nunca suma más minutos que la semana anterior, y suma menos si alguna sesión podía bajar", () => {
    for (const { id, plan } of perfiles()) {
      const semanas = porSemana(plan);
      for (const s of plan.semanas.filter((x) => x.esDescarga)) {
        const anterior = plan.semanas[s.numero - 2];
        assert.ok(anterior, id);
        assert.ok(s.minutosPrevistos <= anterior.minutosPrevistos, `${id} semana ${s.numero}`);
        // Una sesión que ya estaba en el piso de 25 min o en el techo de 240 no tiene cómo bajar
        // (ver las rarezas). Si alguna de la semana anterior estaba en el medio, la descarga se nota.
        const podiaBajar = (semanas[anterior.numero - 1] ?? []).some(
          (d) => d.tipo !== "descanso" && d.tipo !== "fuerza" && d.duracionMin > 25 && d.duracionMin < 240
        );
        if (podiaBajar) assert.ok(s.minutosPrevistos < anterior.minutosPrevistos, `${id} semana ${s.numero}`);
      }
    }
  });
});

// ─── 4. Lo que el port cambió, y lo que no ──────────────────────────────────────────────────

describe("determinístico (§1 y §5.1)", () => {
  test("la misma entrada da el mismo plan y los mismos textos, byte a byte", () => {
    for (const entrada of [perfil, corredora, triatleta, caminante, { ...perfil, fechaEvento: null }]) {
      const uno = generarPlan(entrada);
      const otro = generarPlan(structuredClone(entrada));
      assert.equal(JSON.stringify(otro), JSON.stringify(uno));
      for (const locale of LOCALES) {
        assert.equal(
          JSON.stringify(otro.dias.map((d) => textosDelDia(d, locale))),
          JSON.stringify(uno.dias.map((d) => textosDelDia(d, locale)))
        );
      }
    }
  });

  test("el orden de los días de la entrada no cambia el plan, y en un día repetido gana el primero", () => {
    const desordenado = generarPlan({
      ...perfil,
      dias: [
        { weekday: 7, minuteOfDay: 8 * 60 + 30 },
        { weekday: 5, minuteOfDay: 7 * 60 },
        { weekday: 2, minuteOfDay: 19 * 60 },
        { weekday: 4, minuteOfDay: 19 * 60 },
        { weekday: 2, minuteOfDay: 6 * 60 },
      ],
    });
    assert.equal(JSON.stringify(desordenado), JSON.stringify(generarPlan(perfil)));
  });

  test("no lee el reloj ni el azar", () => {
    // Si alguien mete un Date.now() o un Math.random() en el cálculo, esto revienta.
    const DateOriginal = globalThis.Date;
    const nowOriginal = Date.now;
    const randomOriginal = Math.random;
    try {
      Math.random = () => {
        throw new Error("Math.random() adentro del motor");
      };
      Date.now = () => {
        throw new Error("Date.now() adentro del motor");
      };
      globalThis.Date = new Proxy(DateOriginal, {
        construct(objetivo, argumentos, nuevo) {
          if (argumentos.length === 0) throw new Error("new Date() sin argumentos adentro del motor");
          return Reflect.construct(objetivo, argumentos, nuevo);
        },
        apply() {
          throw new Error("Date() adentro del motor");
        },
      });
      for (const entrada of [perfil, triatleta, { ...perfil, fechaEvento: null, pesoG: null, edad: null }]) {
        for (const d of generarPlan(entrada).dias) for (const locale of LOCALES) textosDelDia(d, locale);
      }
    } finally {
      globalThis.Date = DateOriginal;
      Date.now = nowOriginal;
      Math.random = randomOriginal;
    }
  });

  test("cada plan dice con qué versión del motor salió", () => {
    assert.equal(generarPlan(perfil).version, MOTOR_VERSION);
  });
});

/** Fuera de rango o sin fecha: el mismo bloque de 8 semanas, con el motivo primero en cada día. */
function esElBloqueGenerico(plan: PlanGenerado, motivo: CodigoDeMotivo): void {
  const sinFecha = generarPlan({ ...perfil, fechaEvento: null });
  assert.equal(plan.fechaEvento, null);
  assert.ok(plan.dias.every((d) => d.motivos[0] === motivo), `cada día tiene que decir ${motivo}`);
  assert.ok(plan.dias.every((d) => d.tipo !== "carrera"));
  const sinElMotivo = (p: PlanGenerado) => JSON.stringify(p.dias.map((d) => ({ ...d, motivos: d.motivos.slice(1) })));
  assert.equal(sinElMotivo(plan), sinElMotivo(sinFecha));
  assert.deepEqual(plan.semanas, sinFecha.semanas);
}

describe("excepción b): el tope de 52 semanas y las fechas fuera de rango", () => {
  test("un evento a 40 semanas tiene sólo sus 2 semanas de afinamiento (el Kotlin topaba en 26 y le daba 16)", () => {
    const plan = generarPlan({ ...perfil, fechaEvento: sumarDias(inicio, 40 * 7) });
    assert.equal(plan.fechaEvento, sumarDias(inicio, 40 * 7));
    assert.deepEqual(
      plan.fases.map((t) => [t.fase, t.primeraSemana, t.ultimaSemana]),
      [
        ["base", 1, 22],
        ["construccion", 23, 36],
        ["pico", 37, 38],
        ["afinamiento", 39, 40],
        ["carrera", 41, 41],
      ]
    );
  });

  test("a 52 semanas justas el evento vale; un día más, y es el bloque sin fecha", () => {
    const justo = generarPlan({ ...perfil, fechaEvento: sumarDias(inicio, 52 * 7) });
    assert.equal(justo.fechaEvento, sumarDias(inicio, 52 * 7));
    assert.equal(justo.dias.at(-1)?.tipo, "carrera");
    assert.ok(justo.dias.every((d) => !d.motivos.includes("fecha_objetivo_fuera_de_rango")));

    esElBloqueGenerico(generarPlan({ ...perfil, fechaEvento: sumarDias(inicio, 52 * 7 + 1) }), "fecha_objetivo_fuera_de_rango");
  });

  test("una fecha pasada, igual (el Kotlin devolvía un plan vacío)", () => {
    esElBloqueGenerico(generarPlan({ ...perfil, fechaEvento: sumarDias(inicio, -1) }), "fecha_objetivo_fuera_de_rango");
  });

  test("sin fecha, cada día dice que es el bloque genérico", () => {
    esElBloqueGenerico(generarPlan({ ...perfil, fechaEvento: null }), "sin_fecha_bloque_generico");
  });

  test("con el evento hoy, el plan es ese día", () => {
    assert.deepEqual(
      generarPlan({ ...perfil, fechaEvento: inicio }).dias.map((d) => d.tipo),
      ["carrera"]
    );
  });
});

describe("sin peso o sin edad, el plan sale igual (§4.3)", () => {
  const conTodo = generarPlan(perfil);
  /** El día como JSON, con esos campos en null. */
  const sinCampos = (d: DiaPlanificado | undefined, ...campos: (keyof DiaPlanificado)[]): string =>
    JSON.stringify({ ...d, ...Object.fromEntries(campos.map((c) => [c, null])) });

  test("sin peso: ni kcal ni avituallamiento, todo lo demás idéntico, y los textos sin números inventados", () => {
    const sinPeso = generarPlan({ ...perfil, pesoG: null });
    assert.equal(sinPeso.dias.length, conTodo.dias.length);
    sinPeso.dias.forEach((d, i) => {
      assert.equal(d.kcal, null);
      assert.equal(d.avituallamiento, null);
      assert.equal(sinCampos(d, "kcal", "avituallamiento"), sinCampos(conTodo.dias[i], "kcal", "avituallamiento"));
      for (const locale of LOCALES) {
        const { titulo, detalle } = textosDelDia(d, locale);
        assert.ok(titulo.length > 0 && detalle.length > 0);
        assert.doesNotMatch(detalle.split("\n").at(-1) ?? "", /\d+ (ml|g|mg)\b/, `${d.fecha} ${locale}`);
      }
    });
  });

  test("sin edad: sin pulsaciones, y todo lo demás idéntico", () => {
    const sinEdad = generarPlan({ ...perfil, edad: null });
    sinEdad.dias.forEach((d, i) => {
      assert.equal(d.fcMinLpm, null);
      assert.equal(d.fcMaxLpm, null);
      assert.equal(sinCampos(d, "fcMinLpm", "fcMaxLpm"), sinCampos(conTodo.dias[i], "fcMinLpm", "fcMaxLpm"));
    });
    const detalles = sinEdad.dias.map((d) => textosDelDia(d, "es-AR").detalle).join("\n");
    assert.doesNotMatch(detalles, /ppm/);
    assert.match(detalles, /Zona Z2 Base aeróbica/);
  });

  test("con peso, el descanso cuenta 0 kcal, sin zona ni avituallamiento", () => {
    const descansos = conTodo.dias.filter((d) => d.tipo === "descanso");
    assert.ok(descansos.length > 0);
    assert.ok(descansos.every((d) => d.kcal === 0 && d.avituallamiento === null && d.zona === null));
  });
});

describe("la entrada", () => {
  test("lo que no puede ser se rechaza con RangeError, en vez de devolver un plan con NaN", () => {
    const malas: EntradaDelMotor[] = [
      { ...perfil, inicio: "2026-02-30" },
      { ...perfil, fechaEvento: "2026-13-01" },
      { ...perfil, dias: [{ weekday: 8, minuteOfDay: 600 }] },
      { ...perfil, dias: [{ weekday: 2, minuteOfDay: 1440 }] },
      { ...perfil, pesoG: 0 },
      { ...perfil, edad: -1 },
      { ...perfil, objetivo: "ultramaraton" as Objetivo },
    ];
    for (const entrada of malas) assert.throws(() => generarPlan(entrada), RangeError, JSON.stringify(entrada));
  });

  test("sin días elegidos, el plan son descansos: el mínimo de días es decisión de producto (§4.3)", () => {
    const plan = generarPlan({ ...perfil, dias: [] });
    assert.ok(plan.dias.length > 0);
    assert.deepEqual([...new Set(plan.dias.map((d) => d.tipo))], ["descanso", "carrera"]);
  });
});

describe("textos (excepción c)", () => {
  test("cada motivo tiene su texto en los dos idiomas, y no es el mismo", () => {
    const dia = generarPlan(perfil).dias[0];
    assert.ok(dia);
    for (const codigo of CODIGOS_DE_MOTIVO) {
      const [es, en] = LOCALES.map((locale) => textosDelDia({ ...dia, motivos: [codigo] }, locale).motivos[0]);
      assert.ok(es && en && es !== en, codigo);
    }
  });

  test("en-US está traducido: ningún detalle queda igual que en castellano", () => {
    for (const d of generarPlan(triatleta).dias) {
      assert.notEqual(textosDelDia(d, "en-US").detalle, textosDelDia(d, "es-AR").detalle, d.fecha);
    }
  });

  test("el objetivo del día del evento viaja como motivo, y el título lo dice en cada idioma", () => {
    const evento = generarPlan(perfil).dias.at(-1);
    assert.ok(evento);
    assert.equal(textosDelDia(evento, "es-AR").titulo, "Media maratón");
    assert.equal(textosDelDia(evento, "en-US").titulo, "Half marathon");
  });

  test("el tono nunca es punitivo (AGENTS.md §9.2)", () => {
    const PUNITIVO = /fallaste|salteaste|te perdiste|no cumpliste|deberías haber|failed|missed|skipped|should have/i;
    const entradas = [perfil, triatleta, { ...perfil, fechaEvento: null }, { ...perfil, fechaEvento: sumarDias(inicio, -1), pesoG: null }];
    for (const entrada of entradas) {
      for (const d of generarPlan(entrada).dias) {
        for (const locale of LOCALES) {
          const { titulo, detalle, motivos } = textosDelDia(d, locale);
          assert.doesNotMatch([titulo, detalle, ...motivos].join("\n"), PUNITIVO, `${d.fecha} ${locale}`);
        }
      }
    }
  });
});

describe("⚠️ rarezas del Kotlin portadas tal cual: arreglarlas es una decisión, no un detalle del port", () => {
  test("sin fecha, el bloque de 8 semanas termina con un día suelto en una semana 9", () => {
    const plan = generarPlan({ ...perfil, fechaEvento: null });
    assert.equal(plan.dias.length, 8 * 7 + 1);
    assert.equal(plan.totalSemanas, 9);
    assert.equal(semanaDe(plan, 9).length, 1);
  });

  test("el piso de 25 min por sesión se come la descarga, y en metros hasta sube", () => {
    // 5K, principiante, los 7 días: todas las sesiones quedan en el piso. La semana 4 descarga y
    // suma lo mismo que la 3, y 100 m más: la calidad de las semanas pares son cuestas, con un
    // ritmo de referencia más rápido que el del fartlek de las impares.
    const plan = generarPlan({ ...perfil, objetivo: "c5k", nivel: "principiante", dias: TODOS_LOS_DIAS, fechaEvento: sumarDias(inicio, 20 * 7) });
    const [tercera, cuarta] = [plan.semanas[2], plan.semanas[3]];
    assert.ok(tercera && cuarta);
    assert.equal(cuarta.esDescarga, true);
    assert.equal(cuarta.minutosPrevistos, tercera.minutosPrevistos);
    assert.equal(cuarta.metrosPrevistos - tercera.metrosPrevistos, 100);
  });

  test("el techo de 240 min por sesión también: con un solo día, el fondo no baja en ninguna descarga", () => {
    const plan = generarPlan({
      ...perfil,
      objetivo: "maraton",
      nivel: "avanzado",
      dias: [{ weekday: 7, minuteOfDay: 540 }],
      fechaEvento: sumarDias(inicio, 20 * 7),
    });
    for (const numero of [4, 8, 12, 16]) {
      const descarga = plan.semanas[numero - 1];
      const anterior = plan.semanas[numero - 2];
      assert.ok(descarga?.esDescarga && anterior, `semana ${numero}`);
      assert.deepEqual([anterior.minutosPrevistos, descarga.minutosPrevistos], [240, 240], `semana ${numero}`);
    }
  });

  test("el ritmo sale del deporte principal: la natación de un triatlón trae ritmo a pie", () => {
    const nado = generarPlan(triatleta).dias.find((d) => d.deporte === "natacion");
    assert.equal(nado?.ritmoMinSegKm, 440); // 7:20 min/km, en el agua
  });

  test("volver a entrenar sin lesiones, con fecha, termina en un día de carrera de 10 km", () => {
    const evento = generarPlan({ ...perfil, objetivo: "volver_sin_lesiones" }).dias.at(-1);
    assert.equal(evento?.tipo, "carrera");
    assert.equal(evento?.distanciaM, 10_000);
  });

  test("entre 45 y 59 min, el consejo dice que no hacen falta geles y el avituallamiento cuenta uno", () => {
    // Los hidratos arrancan a los 45 min (carbsPerHour) y el consejo corta en 60 (buildWorkout).
    // `geles` es nuevo (excepción e), pero los 20 g ya los pedía el Kotlin.
    const d = generarPlan(corredora).dias.find((x) => x.fecha === "2027-01-04");
    assert.ok(d);
    assert.equal(d.avituallamiento?.carbohidratosTotalG, 20);
    assert.equal(d.avituallamiento?.geles, 1);
    assert.ok(textosDelDia(d, "es-AR").detalle.endsWith("No hacen falta geles."));
  });

  test("la fuerza es 'para corredores' aunque la persona pedalee", () => {
    const fuerza = generarPlan({ ...perfil, deporte: "ciclismo" }).dias.find((d) => d.tipo === "fuerza");
    assert.ok(fuerza);
    assert.equal(textosDelDia(fuerza, "es-AR").titulo, "Fuerza para corredores (35 min)");
  });
});

describe("calcularRacha (fueguitos estilo Duolingo)", async () => {
  const { calcularRacha } = await import("../src/dominios/plan/servicio.js");

  const crearDia = (fecha: string, tipo: "fondo" | "descanso"): DiaPlanificado => ({
    indice: 0,
    fecha,
    semana: 1,
    weekday: 1,
    fase: "base",
    tipo,
    deporte: "running",
    duracionMin: 45,
    distanciaM: 5000,
    zona: "z2",
    fcMinLpm: null,
    fcMaxLpm: null,
    ritmoMinSegKm: null,
    ritmoMaxSegKm: null,
    kcal: null,
    avituallamiento: null,
    minutoDelDia: 480,
    esSemanaDeDescarga: false,
    motivos: [],
  });

  test("sin días entrenados la racha es 0", () => {
    const dias = [crearDia("2026-03-02", "fondo"), crearDia("2026-03-03", "descanso")];
    const hechos = new Map();
    const r = calcularRacha(dias, hechos, "2026-03-02");
    assert.equal(r.dias, 0);
    assert.equal(r.activa_hoy, false);
    assert.equal(r.entrenado_hoy, false);
    assert.equal(r.toca_hoy, true);
  });

  test("completar el entrenamiento de hoy enciende el fueguito", () => {
    const dias = [crearDia("2026-03-02", "fondo")];
    const hechos = new Map([["2026-03-02", { sesiones: 1, metros: 5000 }]]);
    const r = calcularRacha(dias, hechos, "2026-03-02");
    assert.equal(r.dias, 1);
    assert.equal(r.activa_hoy, true);
    assert.equal(r.entrenado_hoy, true);
  });

  test("el día de descanso no rompe la racha", () => {
    const dias = [
      crearDia("2026-03-02", "fondo"),
      crearDia("2026-03-03", "descanso"),
    ];
    const hechos = new Map([["2026-03-02", { sesiones: 1, metros: 5000 }]]);
    const r = calcularRacha(dias, hechos, "2026-03-03");
    assert.equal(r.dias, 1);
    assert.equal(r.activa_hoy, true);
    assert.equal(r.toca_hoy, false);
  });

  test("un día programado no entrenado hace perder la racha (0)", () => {
    const dias = [
      crearDia("2026-03-02", "fondo"),
      crearDia("2026-03-03", "fondo"), // no entrenó
      crearDia("2026-03-04", "fondo"), // hoy
    ];
    const hechos = new Map([["2026-03-02", { sesiones: 1, metros: 5000 }]]);
    const r = calcularRacha(dias, hechos, "2026-03-04");
    assert.equal(r.dias, 0);
    assert.equal(r.activa_hoy, false);
  });

  test("consecutivos con descansos intermedios acumulan racha", () => {
    const dias = [
      crearDia("2026-03-02", "fondo"),
      crearDia("2026-03-03", "descanso"),
      crearDia("2026-03-04", "fondo"),
      crearDia("2026-03-05", "fondo"),
    ];
    const hechos = new Map([
      ["2026-03-02", { sesiones: 1, metros: 5000 }],
      ["2026-03-04", { sesiones: 1, metros: 5000 }],
      ["2026-03-05", { sesiones: 1, metros: 5000 }],
    ]);
    const r = calcularRacha(dias, hechos, "2026-03-05");
    assert.equal(r.dias, 3);
    assert.equal(r.activa_hoy, true);
  });
});
