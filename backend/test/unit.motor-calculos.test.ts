/**
 * Tests de los cálculos del motor: hidratación, redondeo y fechas.
 *
 * Los seis primeros son HydrationCalculatorTest.kt portado uno a uno: la especificación ejecutable
 * de lo que el port tiene que seguir haciendo (docs/PROPUESTA-MOTOR.md §5.4). El resto fija lo que
 * el port cambió de forma —notas como códigos, agenda sin mensajes, geles— y la aritmética de
 * Kotlin que JavaScript no trae igual.
 *
 * Portar no es verificar (§2): que esto pase dice que el port hace lo mismo que el Kotlin, no que
 * los números del Kotlin estén bien.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  agendaDeAvisos,
  avituallamientoDe,
  carbohidratosPorHora,
  planDeHidratacion,
  tasaDeSudoracionLh,
  tasaDeSudoracionMedida,
  GRAMOS_DE_HIDRATOS_POR_GEL,
  type PerfilDeHidratacion,
} from "../src/dominios/plan/motor/hidratacion.js";
import { ritmoPrevistoSegPorKm } from "../src/dominios/plan/motor/ritmos.js";
import { aDia, aTexto, diaDeLaSemana } from "../src/dominios/plan/motor/fechas.js";
import { CLIMA_POR_DEFECTO, redondearAlPar } from "../src/dominios/plan/motor/tipos.js";

// UserProfile(weightKg = 70.0, sweatSaltiness = MEDIUM): el resto, los valores por defecto del
// Kotlin (MALE, intestino 2, sin tasa medida).
const perfil: PerfilDeHidratacion = {
  pesoKg: 70.0,
  sexo: "masculino",
  salinidad: "media",
  nivelIntestinal: 2,
  tasaDeSudorMedidaLh: null,
};

describe("HydrationCalculatorTest.kt, portado", () => {
  test("el calor aumenta la tasa de sudoración", () => {
    const fresco = tasaDeSudoracionLh(perfil, "running", "moderada", { temperaturaC: 12.0, humedadPct: 50.0, bajoElSol: false });
    const calor = tasaDeSudoracionLh(perfil, "running", "moderada", { temperaturaC: 32.0, humedadPct: 70.0, bajoElSol: true });
    assert.ok(calor > fresco * 1.4, "con calor se tiene que sudar más");
  });

  test("la reposición nunca supera el límite de vaciado gástrico", () => {
    const plan = planDeHidratacion(
      { ...perfil, pesoKg: 95.0 },
      "running",
      "competencia",
      { temperaturaC: 38.0, humedadPct: 85.0, bajoElSol: true },
      180
    );
    assert.ok(plan.liquidoMlPorHora <= 800, "máximo 800 ml/h");
    assert.ok(plan.liquidoMlPorHora >= 300, "mínimo 300 ml/h");
  });

  test("las sesiones cortas no llevan geles ni sales", () => {
    const plan = planDeHidratacion(perfil, "running", "moderada", CLIMA_POR_DEFECTO, 40);
    assert.equal(plan.carbohidratosGPorHora, 0);
    assert.equal(plan.sodioMgPorHora, 0);
  });

  test("las sesiones largas respetan el techo del intestino", () => {
    assert.equal(carbohidratosPorHora(300, 1), 45);
    assert.equal(carbohidratosPorHora(300, 3), 90);
  });

  test("la agenda de avisos se ordena por minuto", () => {
    const plan = planDeHidratacion(perfil, "running", "moderada", { temperaturaC: 28.0, humedadPct: 60.0, bajoElSol: true }, 180);
    const agenda = agendaDeAvisos(plan);
    assert.ok(agenda.length > 0);
    const minutos = agenda.map((a) => a.minuto);
    assert.deepEqual(minutos, [...minutos].sort((a, b) => a - b));
    assert.ok(agenda.every((a) => a.minuto <= 180), "ningún aviso después del final");
  });

  test("la tasa medida usa el protocolo de peso", () => {
    // 1 kg perdido + 500 ml tomados en 1 hora = 1,5 L/h
    const tasa = tasaDeSudoracionMedida(70.0, 69.0, 500, 60);
    assert.ok(Math.abs(tasa - 1.5) <= 0.01, `dio ${tasa}`);
  });
});

describe("lo que el port cambió de forma (excepciones d y e)", () => {
  // 70 kg corriendo fuerte 2 h a 30 °C: suda ~1,9 L/h, y eso dispara casi todas las notas.
  const plan = planDeHidratacion(perfil, "running", "fuerte", { temperaturaC: 30.0, humedadPct: 60.0, bajoElSol: true }, 120);

  test("las notas son códigos con sus números, en el orden del Kotlin", () => {
    assert.deepEqual(
      plan.notas.map((n) => n.codigo),
      ["sudor_estimado", "perdida_de_peso_sin_reponer", "calor_alto", "sesion_larga_sodio_desde_el_inicio"]
    );
    const [sudor, perdida] = plan.notas;
    assert.ok(sudor?.codigo === "sudor_estimado");
    assert.equal(sudor.minutos, 120);
    // Sin redondear: el Kotlin lo formateaba con "%.1f", que depende del idioma. Ahora se formatea
    // al mostrarlo, en el idioma de quien lo lee.
    assert.equal(sudor.litros, (plan.tasaDeSudorLh * 1000 * 120) / 60 / 1000);
    assert.ok(perdida?.codigo === "perdida_de_peso_sin_reponer");
    assert.ok(perdida.porcentajeDelPeso >= 2.0);
  });

  test("la agenda no trae mensajes: el tipo y la cantidad dicen lo mismo", () => {
    const agenda = agendaDeAvisos(plan);
    for (const aviso of agenda) {
      assert.deepEqual(Object.keys(aviso).sort(), ["carbohidratosG", "liquidoMl", "minuto", "sodioMg", "tipo"]);
    }
    // Agua cada 10 min, sales cada 30 y el primer gel al 30: a igual minuto queda el orden en que
    // el Kotlin los agregaba, porque sortedBy es estable y Array.prototype.sort también.
    assert.deepEqual(
      agenda.filter((a) => a.minuto === 30).map((a) => a.tipo),
      ["agua", "sales", "gel"]
    );
  });

  test("geles: los hidratos del total, de a 25 g y redondeando para arriba", () => {
    assert.equal(GRAMOS_DE_HIDRATOS_POR_GEL, 25);
    const geles = (duracionMin: number) =>
      avituallamientoDe(planDeHidratacion(perfil, "running", "moderada", CLIMA_POR_DEFECTO, duracionMin)).geles;
    assert.equal(geles(40), 0); // 0 g
    assert.equal(geles(120), 4); // 50 g/h × 2 h = 100 g
    assert.equal(geles(180), 9); // 70 g/h (techo del intestino 2) × 3 h = 210 g: 8,4 geles
  });

  test("sin_declarar y sin dato sudan como masculino; femenino, un 15 % menos", () => {
    const tasa = (sexo: PerfilDeHidratacion["sexo"]) =>
      tasaDeSudoracionLh({ ...perfil, sexo }, "running", "moderada", CLIMA_POR_DEFECTO);
    assert.equal(tasa("sin_declarar"), tasa("masculino"));
    assert.equal(tasa(null), tasa("masculino"));
    assert.ok(Math.abs(tasa("femenino") - tasa("masculino") * 0.85) < 1e-12);
  });
});

describe("Riegel: los ritmos que dio PaceCalculator.kt compilado", () => {
  test("sin marca, la referencia es el 10K del nivel", () => {
    const ritmos = (["principiante", "intermedio", "avanzado"] as const).map((nivel) =>
      [10.0, 5.0, 42.195].map((km) => ritmoPrevistoSegPorKm({ nivel, marca: null }, km))
    );
    assert.deepEqual(ritmos, [
      [420, 402, 457],
      [330, 316, 359],
      [258, 247, 281],
    ]);
  });

  test("con marca, manda la marca y no el nivel (el contrato todavía no la guarda)", () => {
    const marca = { distanciaKm: 10.0, tiempoMin: 52.5 };
    for (const nivel of ["principiante", "intermedio", "avanzado"] as const) {
      assert.equal(ritmoPrevistoSegPorKm({ nivel, marca }, 5.0), 302);
      assert.equal(ritmoPrevistoSegPorKm({ nivel, marca }, 42.195), 343);
    }
  });
});

describe("la aritmética de Kotlin que JavaScript no trae igual", () => {
  test("kotlin.math.round desempata al par; Math.round, para arriba", () => {
    // 90 min de trekking a 3,5 km/h son 5,25 km: el Kotlin muestra 5,2.
    assert.equal(redondearAlPar(52.5), 52);
    assert.equal(redondearAlPar(53.5), 54);
    assert.equal(redondearAlPar(38.5), 38);
    assert.equal(redondearAlPar(52.49), 52);
    assert.equal(redondearAlPar(52.51), 53);
    assert.equal(redondearAlPar(0.5), 0);
  });
});

describe("fechas sin reloj (excepción a)", () => {
  test("un día es un entero, y la vuelta da el mismo texto", () => {
    assert.equal(aDia("1970-01-01"), 0);
    assert.equal(aTexto(aDia("2026-03-02") + 7), "2026-03-09");
    assert.equal(aTexto(aDia("2024-02-28") + 1), "2024-02-29");
    assert.equal(aTexto(aDia("2026-12-31") + 1), "2027-01-01");
  });

  test("el día de la semana es ISO: 1 es lunes y 7 es domingo", () => {
    assert.equal(diaDeLaSemana(aDia("2026-03-02")), 1);
    assert.equal(diaDeLaSemana(aDia("2026-03-08")), 7);
    assert.equal(diaDeLaSemana(aDia("1970-01-01")), 4);
    assert.equal(diaDeLaSemana(aDia("1969-12-31")), 3);
  });

  test("una fecha que no existe no se corre en silencio", () => {
    for (const mala of ["2026-02-30", "2025-02-29", "2026-13-01", "2026-3-2", "0050-01-01", "hoy"]) {
      assert.throws(() => aDia(mala), RangeError, mala);
    }
    assert.equal(aTexto(aDia("2024-02-29")), "2024-02-29");
  });
});
