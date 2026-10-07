/**
 * Tests de los guardarraíles de nutrición (AGENTS.md §9.2).
 *
 * Son la parte más importante del backend: es lo único que separa "una app que
 * sugiere comer" de "una app que puede hacer daño". Los números son provisionales;
 * las REGLAS no, y estos tests son las reglas.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  aplicar,
  pisoEfectivo,
  provisionales,
  verificarParaProduccion,
  pesoObjetivoBajoElMinimo,
  revisarPedidoDeLaPersona,
  perdidaMaximaSemanalG,
  cargar,
  type PerfilNutricion,
} from "../src/dominios/nutricion/guardarrailes.js";

const adulto: PerfilNutricion = { edad: 34, peso_g: 74_500, altura_mm: 1780, bmr: 1700 };

describe("🛑 el arranque en producción", () => {
  test("FALLA mientras haya un valor provisional", () => {
    assert.ok(provisionales().length > 0, "hoy todos tienen que estar provisionales");
    assert.throws(
      () => verificarParaProduccion(true, () => {}),
      /No arranco en producción/,
      "en producción, un guardarrail sin revisar tiene que impedir el arranque"
    );
  });

  test("en desarrollo arranca, pero avisa", () => {
    const avisos: string[] = [];
    verificarParaProduccion(false, (m) => avisos.push(m));
    assert.ok(avisos.length > 0, "tiene que avisar aunque deje arrancar");
    assert.ok(avisos.some((a) => a.includes("SIN REVISAR")));
  });

  test("el mensaje de error dice CÓMO se arregla, sin tocar código", () => {
    try {
      verificarParaProduccion(true, () => {});
      assert.fail("tenía que tirar");
    } catch (e) {
      const m = String(e);
      assert.match(m, /guardarrailes-nutricion\.json/);
      assert.match(m, /No hay que tocar código/);
    }
  });

  test("los recursos de ayuda están vacíos y eso también bloquea", () => {
    assert.equal(Object.keys(cargar().recursos_de_ayuda.por_pais).length, 0);
  });
});

describe("el piso calórico", () => {
  test("es el MAYOR entre el absoluto y el relativo al basal", () => {
    // Basal bajo: manda el piso absoluto. Es el caso que un piso relativo solo
    // NO protege, y es justo el que §9.2 quiere cubrir.
    assert.equal(pisoEfectivo(1000), 1500);
    // Basal alto: manda el relativo.
    assert.ok(pisoEfectivo(2000) > 1500);
  });

  test("🛑 nunca devuelve un objetivo por debajo del piso", () => {
    for (const bmr of [900, 1200, 1500, 1800, 2200]) {
      const p = { ...adulto, bmr };
      const r = aplicar(500, 2600, p); // objetivo absurdo
      if (r.permitido) assert.ok(r.kcal >= pisoEfectivo(bmr), `${r.kcal} < piso con bmr ${bmr}`);
    }
  });

  test("un objetivo calculado bajo SE RECORTA, no se rechaza", () => {
    // Que el motor calcule bajo no es lo mismo que que la persona pida bajo.
    // Rechazar acá dejaría sin plan a alguien que no pidió nada raro.
    const r = aplicar(600, 2600, adulto);
    assert.equal(r.permitido, true);
    if (r.permitido) {
      assert.ok(r.ajustado);
      assert.ok(r.kcal >= pisoEfectivo(adulto.bmr), "nunca por debajo del piso");
      // Con mantenimiento 2600 el 10 % son 260 kcal, que ata más corto que el
      // piso (2040). Gana el límite MÁS restrictivo de los dos, que es el punto.
      assert.equal(r.kcal, 2340);
      assert.equal(r.motivo, "techo_de_deficit");
    }
  });
});

describe("🛑 cuando la app NO obedece (§9.2)", () => {
  test("la persona pide menos kcal que el piso", () => {
    const r = revisarPedidoDeLaPersona({ kcalPedidas: 900 }, adulto);
    assert.equal(r.obedece, false);
    if (!r.obedece) assert.equal(r.senal, "kcal_bajo_el_piso");
  });

  test("la persona pide un peso objetivo por debajo del IMC mínimo", () => {
    const r = revisarPedidoDeLaPersona({ pesoObjetivoG: 52_000 }, adulto);
    assert.equal(r.obedece, false);
    if (!r.obedece) assert.equal(r.senal, "peso_objetivo_bajo_el_imc_minimo");
  });

  test("un pedido razonable se obedece", () => {
    assert.deepEqual(revisarPedidoDeLaPersona({ kcalPedidas: 2300, pesoObjetivoG: 70_000 }, adulto), {
      obedece: true,
    });
  });

  test("un pedido vacío no dispara nada", () => {
    assert.deepEqual(revisarPedidoDeLaPersona({}, adulto), { obedece: true });
  });
});

describe("el techo de déficit", () => {
  test("recorta un déficit demasiado agresivo", () => {
    const mantenimiento = 2600;
    const flaco = { ...adulto, bmr: 1400 }; // piso = max(1500, 1680) = 1680
    const r = aplicar(1800, mantenimiento, flaco); // calculado -800
    assert.equal(r.permitido, true);
    if (r.permitido) {
      assert.ok(r.ajustado, "tenía que ajustarse");
      assert.ok(mantenimiento - r.kcal <= 400, `déficit de ${mantenimiento - r.kcal}, tope 400`);
    }
  });

  test("un objetivo razonable pasa sin tocarse", () => {
    const r = aplicar(2400, 2600, adulto);
    assert.equal(r.permitido, true);
    if (r.permitido) {
      assert.equal(r.ajustado, false);
      assert.equal(r.kcal, 2400);
    }
  });

  test("se aplica el MENOR de los dos límites (kcal y porcentaje)", () => {
    // Con mantenimiento 2000 y basal 1200, el piso es max(1500, 1440) = 1500, así
    // que el techo de déficit (200) es el que manda y no lo tapa el piso.
    const r = aplicar(1000, 2000, { ...adulto, bmr: 1200 });
    assert.equal(r.permitido, true);
    if (r.permitido) assert.equal(r.kcal, 1800, "con mantenimiento 2000, el déficit tope es 200");
  });
});

describe("🛑 los caminos que NO son de este flujo", () => {
  test("un menor de edad no recibe un objetivo recortado: queda afuera", () => {
    const r = aplicar(2200, 2600, { ...adulto, edad: 16 });
    assert.equal(r.permitido, false);
    if (!r.permitido) assert.equal(r.motivo, "menor_de_edad");
  });

  test("embarazo o lactancia, igual", () => {
    const r = aplicar(2200, 2600, { ...adulto, embarazo_o_lactancia: true });
    assert.equal(r.permitido, false);
    if (!r.permitido) assert.equal(r.motivo, "embarazo_o_lactancia");
  });

  test("se comprueban ANTES que cualquier cálculo, no después", () => {
    // Aunque el objetivo sea perfecto, un menor sigue quedando afuera.
    const r = aplicar(2600, 2600, { ...adulto, edad: 12 });
    assert.equal(r.permitido, false);
  });
});

describe("señales de §9.2", () => {
  test("detecta un peso objetivo por debajo del IMC mínimo", () => {
    // 1,78 m: 18,5 de IMC son ~58,6 kg.
    assert.equal(pesoObjetivoBajoElMinimo(52_000, 1780), true);
    assert.equal(pesoObjetivoBajoElMinimo(70_000, 1780), false);
  });

  test("el ritmo máximo de pérdida sale del archivo, no del código", () => {
    assert.equal(perdidaMaximaSemanalG(80_000), 400); // 0,5 % de 80 kg
  });
});

describe("la propiedad que tiene que valer siempre", () => {
  test("🛑 con CUALQUIER entrada, o no permite, o devuelve algo sobre el piso", () => {
    for (const objetivo of [0, 100, 800, 1200, 1500, 2000, 2600, 5000]) {
      for (const mantenimiento of [1400, 1800, 2200, 2600, 3500]) {
        for (const bmr of [900, 1300, 1700, 2100]) {
          const r = aplicar(objetivo, mantenimiento, { ...adulto, bmr });
          if (r.permitido) {
            assert.ok(
              r.kcal >= pisoEfectivo(bmr),
              `objetivo ${objetivo}, mant ${mantenimiento}, bmr ${bmr} -> ${r.kcal} < piso`
            );
          }
        }
      }
    }
  });
});
