/**
 * Tests del validador del catálogo.
 *
 * El catálogo es dato que se agrega SIN DESPLEGAR (AGENTS.md §9.1). O sea: nadie lo
 * compila. Estos tests prueban que el validador agarra lo que va a pasar de verdad
 * cuando alguien agregue un ejercicio a mano un martes.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { verificar, RUTA } from "../verificar-catalogo.mjs";

const real = JSON.parse(readFileSync(RUTA, "utf8"));
/** Copia profunda del catálogo real, para romperla a propósito. */
const copia = () => JSON.parse(JSON.stringify(real));
const errores = (doc) => verificar(doc).errores;

test("el catálogo que está commiteado no tiene errores", () => {
  assert.deepEqual(verificar(real).errores, []);
});

test("tiene los patrones de movimiento que el motor va a necesitar", () => {
  const p = Object.keys(real.diccionarios.patrones);
  for (const necesario of [
    "empuje-horizontal",
    "empuje-vertical",
    "traccion-vertical",
    "traccion-horizontal",
    "rodilla-bilateral",
    "rodilla-unilateral",
    "cadera",
    "tobillo",
  ]) {
    assert.ok(p.includes(necesario), `falta el patrón ${necesario}`);
  }
});

test("hay ejercicios sin equipamiento para cada patrón grande", () => {
  // Si alguien entrena en casa, el motor tiene que poder armarle algo.
  for (const patron of ["empuje-horizontal", "rodilla-unilateral", "cadera", "tobillo", "antiextension"]) {
    const hay = real.ejercicios.some((e) => e.patron === patron && e.equipamiento === "ninguno");
    assert.ok(hay, `no hay ningún ejercicio sin equipo para "${patron}"`);
  }
});

test("los seis ejercicios de la rutina del diseño están en el catálogo", () => {
  // design/nuevo/gimnasio.dc.html y HomeB usan estos.
  for (const id of [
    "press-banca-barra",
    "dominadas",
    "remo-barra",
    "sentadilla-bulgara",
    "elevacion-talones-pie",
    "plancha-frontal",
  ]) {
    assert.ok(real.ejercicios.some((e) => e.id === id), `falta ${id}`);
  }
});

describe("el validador agarra lo que se va a romper", () => {
  test("un id repetido", () => {
    const d = copia();
    d.ejercicios.push({ ...d.ejercicios[0] });
    assert.ok(errores(d).some((e) => e.includes("id repetido")));
  });

  test("un sustituto que no existe", () => {
    const d = copia();
    d.ejercicios[0].sustitutos.push({ id: "ejercicio-que-no-existe", tipo: "mismo-patron" });
    assert.ok(errores(d).some((e) => e.includes("no existe en el catálogo")));
  });

  test("un ejercicio que se lista a sí mismo como sustituto", () => {
    const d = copia();
    d.ejercicios[0].sustitutos.push({ id: d.ejercicios[0].id, tipo: "mismo-patron" });
    assert.ok(errores(d).some((e) => e.includes("a sí mismo")));
  });

  test("🛑 un sustituto marcado mismo-patron que en realidad cambia de patrón", () => {
    const d = copia();
    const otro = d.ejercicios.find((x) => x.patron !== d.ejercicios[0].patron);
    d.ejercicios[0].sustitutos.push({ id: otro.id, tipo: "mismo-patron" });
    assert.ok(errores(d).some((e) => e.includes("está marcado mismo-patron")));
  });

  test("un ejercicio sin ningún sustituto", () => {
    const d = copia();
    d.ejercicios[0].sustitutos = [];
    assert.ok(errores(d).some((e) => e.includes("sin sustitutos")));
  });

  test("un músculo que no está en el diccionario", () => {
    const d = copia();
    d.ejercicios[0].musculos.push({ id: "musculo-inventado", rol: "principal" });
    assert.ok(errores(d).some((e) => e.includes("músculo desconocido")));
  });

  test("un patrón que no está en el diccionario", () => {
    const d = copia();
    d.ejercicios[0].patron = "levitacion";
    assert.ok(errores(d).some((e) => e.includes("patrón desconocido")));
  });

  test("un ejercicio sin ningún músculo principal", () => {
    const d = copia();
    d.ejercicios[0].musculos = d.ejercicios[0].musculos.map((m) => ({ ...m, rol: "secundario" }));
    assert.ok(errores(d).some((e) => e.includes("músculo principal")));
  });

  test("falta el nombre en un idioma OBLIGATORIO", () => {
    const d = copia();
    d.ejercicios[0].nombre["es-AR"] = "";
    assert.ok(errores(d).some((e) => e.includes("es-AR")));
  });

  test("falta el nombre en un idioma opcional: es aviso, NO error", () => {
    const d = copia();
    d.ejercicios[0].nombre["pt-BR"] = null;
    const { errores: err, avisos } = verificar(d);
    assert.equal(err.length, 0);
    assert.ok(avisos.some((a) => a.includes("pt-BR")));
  });

  test("una unidad inventada", () => {
    const d = copia();
    d.ejercicios[0].unidad = "kilometros";
    assert.ok(errores(d).some((e) => e.includes("unidad inválida")));
  });
});

describe("los sustitutos tienen sentido", () => {
  test("todo ejercicio tiene al menos un sustituto", () => {
    const sin = real.ejercicios.filter((e) => (e.sustitutos ?? []).length === 0).map((e) => e.id);
    assert.deepEqual(sin, [], "sin sustituto no se puede resolver «no tengo ese equipo»");
  });

  test("todo ejercicio tiene al menos un sustituto DEL MISMO PATRÓN", () => {
    // Es la promesa de la pantalla de sustitutos: "mismo patrón de movimiento, con
    // lo que tengas a mano. El plan no cambia de forma." Un ejercicio cuyo único
    // sustituto cambia de patrón no puede cumplirla.
    const sin = real.ejercicios
      .filter((e) => !(e.sustitutos ?? []).some((s) => s.tipo === "mismo-patron"))
      .map((e) => e.id);
    assert.deepEqual(sin, []);
  });

  test("el tipo declarado coincide con el patrón real, en los 46", () => {
    assert.deepEqual(verificar(real).errores, []);
  });
});
