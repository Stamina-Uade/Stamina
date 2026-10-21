import { test } from "node:test";
import assert from "node:assert/strict";
import {
  borradores,
  cargar,
  huecosSinCompletar,
  IDIOMAS_LEGALES,
  olvidarCache,
  verificarParaProduccion,
  versionLegal,
} from "../src/dominios/legal/textos.js";
import { idiomaLegal } from "../src/dominios/legal/rutas.js";

test("hay una version y no esta vacia", () => {
  olvidarCache();
  assert.match(versionLegal(), /^\d+\.\d+\.\d+$/);
});

/**
 * Este test esta escrito para FALLAR el dia que alguien revise los textos, y eso
 * es a proposito: el que los revise tiene que venir aca, borrar este test y
 * escribir el de al lado. Un test que dice "estan sin revisar" y sigue pasando
 * despues de revisarlos no sirve para nada.
 */
test("hoy los tres textos siguen en borrador", () => {
  olvidarCache();
  assert.deepEqual(borradores().sort(), ["aviso_de_salud", "privacidad", "terminos"]);
});

test("ya no quedan huecos sin completar (titular y contacto, 2026-10-21)", () => {
  olvidarCache();
  assert.deepEqual(huecosSinCompletar(), []);
});

test("en desarrollo arranca, pero avisa por los borradores", () => {
  olvidarCache();
  const avisos: string[] = [];
  verificarParaProduccion(false, (m) => avisos.push(m));
  assert.equal(avisos.length, 1, "esperaba un aviso por borradores");
});

test("cada texto está en los tres idiomas, con las mismas secciones y sin campos vacíos", () => {
  olvidarCache();
  for (const [nombre, texto] of Object.entries(cargar().textos)) {
    const cuentas = IDIOMAS_LEGALES.map((idioma) => {
      const c = texto[idioma];
      assert.ok(c, `${nombre} no está en ${idioma}`);
      for (const campo of ["titulo", "resumen", "aceptacion"] as const) {
        assert.ok(c[campo]?.trim().length > 0, `${nombre}.${idioma}.${campo} vacío`);
      }
      const partes = c.puntos ?? c.secciones ?? [];
      for (const p of partes) assert.ok(p.titulo.trim() && p.cuerpo.trim(), `${nombre}.${idioma}: sección vacía`);
      return partes.length;
    });
    assert.equal(new Set(cuentas).size, 1, `${nombre}: los idiomas no tienen las mismas secciones (${cuentas})`);
    assert.ok(cuentas[0]! <= 40, `${nombre}: más de 40 secciones (el contrato no lo deja)`);
  }
});

test("el idioma sale de Accept-Language: es, fr, y si no inglés", () => {
  const con = (v?: string) => idiomaLegal({ headers: v === undefined ? {} : { "accept-language": v } });
  assert.equal(con("es-AR,es;q=0.9"), "es");
  assert.equal(con("fr-FR"), "fr");
  assert.equal(con("en-US"), "en");
  assert.equal(con("de-DE"), "en");
  assert.equal(con(undefined), "en");
});

/**
 * El que importa: con un texto en borrador o un hueco sin completar, el proceso
 * NO levanta en produccion. Es lo que hace que un aviso legal que nadie reviso no
 * pueda llegarle a una persona por descuido.
 */
test("en produccion NO arranca mientras haya un borrador o un hueco", () => {
  olvidarCache();
  assert.throws(
    () => verificarParaProduccion(true, () => {}),
    /No arranco en produccion|No arranco en producción/,
  );
});
