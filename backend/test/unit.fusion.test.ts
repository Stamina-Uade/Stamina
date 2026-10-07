/**
 * Tests de la fusión de series (decisión 0006), del lado del servidor.
 *
 * Son los mismos casos que ios/TrainerCore/Tests/TrainerCoreTests/FusionDeSeriesTests.swift,
 * y es a propósito: teléfono, reloj y servidor corren la misma regla, y si uno
 * fusionara distinto divergirían en silencio. Al final van los casos que sólo
 * existen acá, porque el servidor es el que pone la hora de llegada.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { fusionar, unir, type Dispositivo, type Serie } from "../src/dominios/gimnasio/fusion.js";

interface Opciones {
  ejercicio: string;
  hecha: boolean;
  reps: number;
  kg: number | null;
  servidor: number | null;
  local: number;
  de: Dispositivo;
  extra: boolean;
}

function serie(numero: number, o: Partial<Opciones> = {}): Serie {
  return {
    ejercicioId: o.ejercicio ?? "press-banca",
    numero,
    hecha: o.hecha ?? true,
    repeticiones: o.reps ?? 8,
    pesoG: o.kg === undefined ? 45_000 : o.kg === null ? null : o.kg * 1000,
    salteada: false,
    esExtra: o.extra ?? false,
    registradaLocalMs: o.local ?? 1_000,
    recibidaEnServidorMs: o.servidor ?? null,
    dispositivo: o.de ?? "telefono",
  };
}

describe("lo que pidió Iván, al pie de la letra", () => {
  test("la misma serie en los dos dispositivos queda como una sola", () => {
    const unidas = unir([serie(2, { local: 2_000, de: "reloj" })], [serie(2, { local: 1_000 })]);
    assert.equal(unidas.length, 1, "la misma serie física no puede quedar duplicada");
    assert.equal(unidas[0]?.hecha, true);
  });

  test("series distintas se unen", () => {
    const unidas = unir([serie(2, { de: "reloj" })], [serie(3)]);
    assert.deepEqual(unidas.map((s) => s.numero), [2, 3]);
  });

  test("lo que registró el reloj aparece en el teléfono", () => {
    const unidas = unir([], [serie(1, { de: "reloj" }), serie(2, { de: "reloj" })]);
    assert.equal(unidas.length, 2);
    assert.ok(unidas.every((s) => s.hecha));
  });
});

describe("las tres reglas del modelo", () => {
  test("🛑 regla 2: ninguna sincronización desmarca una serie", () => {
    const sinMarcar = serie(2, { hecha: false, local: 9_000 });
    const marcada = serie(2, { hecha: true, local: 1_000, de: "reloj" });
    assert.equal(fusionar(sinMarcar, marcada).hecha, true);
  });

  test("🛑 regla 3: nunca se mezclan los campos de dos versiones", () => {
    const delReloj = serie(2, { reps: 8, kg: 45, local: 2_000, de: "reloj" });
    const delTelefono = serie(2, { reps: 6, kg: 40, local: 1_000 });
    const f = fusionar(delReloj, delTelefono);
    // Gana el reloj ENTERO: 8 × 45. Nunca 8 × 40 ni 6 × 45.
    assert.equal(f.repeticiones, 8);
    assert.equal(f.pesoG, 45_000);
  });

  test("lo que llegó al servidor le gana a lo que no llegó, aunque el reloj local sea más nuevo", () => {
    const llego = serie(2, { reps: 6, servidor: 500, local: 1 });
    const soloLocal = serie(2, { reps: 9, servidor: null, local: 999_999, de: "reloj" });
    assert.equal(fusionar(llego, soloLocal).repeticiones, 6);
  });

  test("entre dos que llegaron al servidor gana la más nueva", () => {
    const vieja = serie(2, { reps: 6, servidor: 100 });
    const nueva = serie(2, { reps: 9, servidor: 200, de: "reloj" });
    assert.equal(fusionar(vieja, nueva).repeticiones, 9);
  });
});

describe("🛑 las propiedades que hacen que no diverjan", () => {
  test("es conmutativa, incluso con el mismo momento exacto", () => {
    const a = serie(2, { reps: 8, local: 1_000, de: "reloj" });
    const b = serie(2, { reps: 6, local: 1_000, de: "telefono" });
    assert.deepEqual(fusionar(a, b), fusionar(b, a));
  });

  test("es idempotente", () => {
    const a = serie(2, { reps: 8, de: "reloj" });
    assert.deepEqual(fusionar(a, a), a);
    const unaVez = unir([a], []);
    assert.deepEqual(unir(unaVez, unaVez), unaVez);
  });

  test("es asociativa", () => {
    const a = serie(2, { reps: 8, local: 3_000, de: "reloj" });
    const b = serie(2, { reps: 6, local: 2_000 });
    const c = serie(2, { reps: 7, servidor: 50, local: 1_000 });
    assert.deepEqual(fusionar(fusionar(a, b), c), fusionar(a, fusionar(b, c)));
  });

  test("los dos dispositivos llegan al mismo resultado", () => {
    const enElReloj = [serie(1, { de: "reloj" }), serie(2, { reps: 8, local: 5_000, de: "reloj" })];
    const enElTelefono = [serie(2, { reps: 6, local: 4_000 }), serie(3)];
    const comoLoVeElReloj = unir(enElReloj, enElTelefono);
    assert.deepEqual(comoLoVeElReloj, unir(enElTelefono, enElReloj));
    assert.equal(comoLoVeElReloj.length, 3);
  });
});

describe("lo que sólo pasa en el servidor", () => {
  test("una escritura nueva llega con hora de servidor y reemplaza la fila entera, sin desmarcar", () => {
    const guardada = serie(2, { reps: 8, kg: 45, servidor: 100, de: "reloj" });
    const entrante = serie(2, { reps: 6, kg: 40, hecha: false, servidor: 200, local: 1 });
    const f = fusionar(guardada, entrante);
    assert.equal(f.repeticiones, 6, "gana la última en llegar, aunque su reloj local sea viejo");
    assert.equal(f.pesoG, 40_000);
    assert.equal(f.hecha, true, "y aun así no se desmarca");
  });

  test("la misma serie dos veces en un lote: con la misma llegada, ordena el momento local", () => {
    const antes = serie(4, { reps: 5, servidor: 300, local: 10 });
    const despues = serie(4, { reps: 7, servidor: 300, local: 20 });
    assert.equal(unir([], [despues, antes])[0]?.repeticiones, 7);
    assert.equal(unir([], [antes, despues])[0]?.repeticiones, 7);
  });

  test("una sincronización de un ejercicio no toca las series de otro", () => {
    const guardadas = [serie(1, { ejercicio: "dominadas", servidor: 10 }), serie(1, { servidor: 10 })];
    const unidas = unir(guardadas, [serie(1, { reps: 3, servidor: 20 })]);
    assert.equal(unidas.length, 2);
    assert.equal(unidas.find((s) => s.ejercicioId === "dominadas")?.repeticiones, 8);
  });

  test("fusionar dos series distintas es un error de programación, no un dato", () => {
    assert.throws(() => fusionar(serie(1), serie(2)));
  });
});
