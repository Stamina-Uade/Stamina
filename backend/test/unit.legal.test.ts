import { test } from "node:test";
import assert from "node:assert/strict";
import {
  borradores,
  huecosSinCompletar,
  olvidarCache,
  verificarParaProduccion,
  versionLegal,
} from "../src/dominios/legal/textos.js";

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
test("hoy los dos textos siguen en borrador", () => {
  olvidarCache();
  assert.deepEqual(borradores().sort(), ["aviso_de_salud", "terminos"]);
});

test("los huecos sin completar estan declarados y no se inventaron", () => {
  olvidarCache();
  const huecos = huecosSinCompletar().sort();
  assert.deepEqual(huecos, ["CORREO_CONTACTO", "DOMICILIO", "EMPRESA", "JURISDICCION"]);
});

test("en desarrollo arranca, pero avisa una vez por problema", () => {
  olvidarCache();
  const avisos: string[] = [];
  verificarParaProduccion(false, (m) => avisos.push(m));
  assert.equal(avisos.length, 2, "esperaba un aviso por borradores y otro por huecos");
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
