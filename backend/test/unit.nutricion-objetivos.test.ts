/**
 * Tests de los objetivos nutricionales del día.
 *
 * El orden de este archivo es el orden de la regla: primero lo que NO puede dar un
 * número (AGENTS.md §9.2), después el cálculo, y al final la última puerta. Los
 * casos del cálculo son los de NutritionCalculatorTest.kt de la app vieja.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  clasificarDia,
  metabolismoBasal,
  objetivosDelDia,
  parametrosProvisionales,
  verificarParametrosParaProduccion,
  type PersonaParaNutricion,
  type SesionParaNutricion,
} from "../src/dominios/nutricion/objetivos.js";
import { pisoEfectivo } from "../src/dominios/nutricion/guardarrailes.js";

const hombre: PersonaParaNutricion = {
  pesoG: 70_000,
  alturaMm: 1750,
  edad: 30,
  sexo: "masculino",
  embarazoOLactancia: null,
  nivel: "intermedio",
};

const mujer: PersonaParaNutricion = { ...hombre, sexo: "femenino", embarazoOLactancia: false };

const fondo: SesionParaNutricion = { duracionMin: 120, kcal: 900, esCalidad: false, esCarrera: false };

function objetivos(persona: PersonaParaNutricion, sesion: SesionParaNutricion | null = null) {
  const r = objetivosDelDia(persona, sesion, null, null);
  assert.ok(r.ok, `esperaba objetivos y vino ${JSON.stringify(r)}`);
  return r.objetivos;
}

describe("🛑 lo que NO tiene objetivos, y se decide antes de calcular", () => {
  test("una mujer que no respondió si está embarazada o en lactancia", () => {
    assert.deepEqual(objetivosDelDia({ ...mujer, embarazoOLactancia: null }, null, null, null), {
      ok: false,
      motivo: "falta_embarazo_o_lactancia",
    });
  });

  test("embarazo o lactancia: fuera del flujo genérico", () => {
    assert.deepEqual(objetivosDelDia({ ...mujer, embarazoOLactancia: true }, fondo, null, null), {
      ok: false,
      motivo: "embarazo_o_lactancia",
    });
  });

  test("menor de edad, aunque falten otros datos", () => {
    assert.deepEqual(objetivosDelDia({ ...hombre, edad: 17, pesoG: null }, null, null, null), {
      ok: false,
      motivo: "menor_de_edad",
    });
  });

  test("sexo sin declarar: no se promedian las ecuaciones", () => {
    assert.deepEqual(objetivosDelDia({ ...hombre, sexo: "sin_declarar" }, null, null, null), {
      ok: false,
      motivo: "sexo_sin_declarar",
    });
  });

  test("sin edad, peso o altura: perfil incompleto", () => {
    for (const faltante of [{ edad: null }, { pesoG: null }, { alturaMm: null }]) {
      const r = objetivosDelDia({ ...hombre, ...faltante }, null, null, null);
      assert.deepEqual(r, { ok: false, motivo: "perfil_incompleto" });
    }
  });

  test("una mujer que respondió que no, sí tiene objetivos", () => {
    assert.ok(objetivosDelDia(mujer, null, null, null).ok);
  });
});

describe("el cálculo", () => {
  test("Mifflin-St Jeor para un hombre de 70 kg", () => {
    // 10*70 + 6.25*175 - 5*30 + 5 = 1648,75
    assert.equal(metabolismoBasal(70, 175, 30, "masculino"), 1648.75);
  });

  test("los hidratos se periodizan según la carga del día", () => {
    const descanso = objetivos(hombre);
    const largo = objetivos(hombre, fondo);
    assert.equal(descanso.carga, "descanso");
    assert.equal(largo.carga, "alta");
    assert.ok(largo.carbohidratosG > descanso.carbohidratosG, "más carga, más hidratos");
    assert.ok(largo.kcal > descanso.kcal, "más carga, más calorías");
  });

  test("los macros cierran contra las calorías", () => {
    const o = objetivos(hombre, { duracionMin: 50, kcal: 450, esCalidad: false, esCarrera: false });
    const deLosMacros = o.carbohidratosG * 4 + o.proteinaG * 4 + o.grasaG * 9;
    assert.ok(Math.abs(deLosMacros - o.kcal) < o.kcal * 0.06);
  });

  test("si la grasa mínima no entra, se recortan hidratos y nunca proteína", () => {
    const chica: PersonaParaNutricion = { ...mujer, pesoG: 45_000, alturaMm: 1500, edad: 60 };
    const o = objetivos(chica, { duracionMin: 30, kcal: 100, esCalidad: false, esCarrera: true });
    assert.equal(o.grasaG, 36, "0,8 g/kg de 45 kg");
    assert.equal(o.proteinaG, 81, "la proteína de carga alta no se toca: 1,8 g/kg");
    assert.ok(o.carbohidratosG < Math.round(9.5 * 45), "los hidratos se recortaron");
  });

  test("clasificar el día", () => {
    const sesion = (duracionMin: number, esCalidad = false): SesionParaNutricion => ({
      duracionMin,
      kcal: null,
      esCalidad,
      esCarrera: false,
    });
    assert.equal(clasificarDia(null, null, null), "descanso");
    assert.equal(clasificarDia(sesion(30), null, null), "baja");
    assert.equal(clasificarDia(sesion(60), null, null), "moderada");
    assert.equal(clasificarDia(sesion(80, true), null, null), "alta");
    assert.equal(clasificarDia(sesion(100), null, null), "alta");
    assert.equal(clasificarDia({ ...sesion(30), esCarrera: true }, null, null), "competencia");
    assert.equal(clasificarDia(null, 1, 120), "competencia", "el día antes de un evento largo");
    assert.equal(clasificarDia(null, 1, 45), "descanso", "un evento corto no carga hidratos");
  });
});

describe("🛑 la última puerta", () => {
  test("nunca sale un número bajo el piso, y lo dice", () => {
    const chica: PersonaParaNutricion = { ...mujer, pesoG: 45_000, alturaMm: 1500, edad: 60 };
    const o = objetivos(chica);
    const bmr = metabolismoBasal(45, 150, 60, "femenino");
    assert.ok(o.kcal >= pisoEfectivo(bmr), `${o.kcal} quedó bajo el piso ${pisoEfectivo(bmr)}`);
    assert.equal(o.ajustado, true);
    assert.equal(o.motivoDelAjuste, "piso_calorico");
  });

  test("mientras haya un valor sin revisar, los objetivos dicen que son provisionales", () => {
    assert.ok(parametrosProvisionales().length > 0);
    assert.equal(objetivos(hombre).provisional, true);
  });

  test("en producción no arranca con parámetros provisionales; fuera de producción avisa", () => {
    assert.throws(() => verificarParametrosParaProduccion(true, () => {}), /No arranco en producción/);
    const avisos: string[] = [];
    verificarParametrosParaProduccion(false, (m) => avisos.push(m));
    assert.equal(avisos.length, 1);
  });
});
