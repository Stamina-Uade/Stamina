/**
 * scripts/test/disparadores-de-diseno.test.mjs
 *
 * El workflow `diseno` (.github/workflows/diseno.yml) corre SÓLO cuando cambia algo
 * de su lista de `paths`, y los tests del guardián leen archivos de medio
 * repositorio. Si un test lee un archivo que esa lista no nombra, un cambio en ese
 * archivo puede romper el test sin que el workflow corra: el rojo aparece después,
 * en el push de otra persona, y parece culpa suya.
 *
 * Pasó el 2026-09-10: los tests leían el contrato, siete archivos del backend y
 * docs/CORRER-LOCAL.md, y ninguna de esas rutas disparaba el workflow.
 *
 * Mira las rutas que los tests —y los scripts que importan— nombran ENTRE COMILLAS.
 * Una ruta armada por pedazos, del estilo resolve(raiz, "backend", "src"), no la ve:
 * escribila entera.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
// Con barras normales también en Windows, donde también se trabaja este repositorio.
const ESTE_ARCHIVO = relative(raiz, fileURLToPath(import.meta.url)).replaceAll("\\", "/");
const RUTA_WORKFLOW = ".github/workflows/diseno.yml";
const workflow = parse(readFileSync(resolve(raiz, RUTA_WORKFLOW), "utf8"));
const disparadores = workflow.on.push.paths;

/** Un glob de `paths` de GitHub Actions como expresión regular: `**` cruza carpetas, `*` no. */
function comoRegex(glob) {
  const cuerpo = glob
    .split("**")
    .map((pedazo) =>
      pedazo
        .split("*")
        .map((literal) => literal.replace(/[.+?^${}()|[\]\\]/g, "\\$&"))
        .join("[^/]*"),
    )
    .join(".*");
  return new RegExp(`^${cuerpo}$`);
}

/** Una carpeta nombrada con o sin la barra final queda cubierta si lo que tiene adentro lo está. */
function cubierta(regexes, ruta) {
  const adentro = `${ruta.replace(/\/$/, "")}/x`;
  return regexes.some((r) => r.test(ruta) || r.test(adentro));
}

/** Las rutas del repositorio que un archivo nombra entre comillas. */
function rutasNombradas(texto) {
  const patron = /["'`]((?:android|ios|backend|shared|docs|design|scripts|\.github)\/[^"'`\s]+)["'`]/g;
  // `${idioma}` adentro de una ruta es una carpeta cualquiera.
  return [...texto.matchAll(patron)].map((m) => m[1].replace(/\$\{[^}]+\}/g, "x"));
}

/** Lo que corre el paso «Tests del guardián»: los tests, y los scripts que importan. */
function archivosDelGuardian() {
  const tests = readdirSync(resolve(raiz, "scripts", "test"))
    .filter((nombre) => nombre.endsWith(".test.mjs"))
    .map((nombre) => `scripts/test/${nombre}`);
  const importados = new Set();
  for (const archivo of tests) {
    const texto = readFileSync(resolve(raiz, archivo), "utf8");
    for (const m of texto.matchAll(/from\s+["']\.\.\/([^"']+\.mjs)["']/g)) {
      importados.add(`scripts/${m[1]}`);
    }
  }
  return [...tests, ...importados];
}

test("push y pull_request se disparan con la misma lista", () => {
  assert.deepEqual(workflow.on.pull_request.paths, disparadores);
});

test("cada archivo que leen los tests del guardián dispara el workflow", () => {
  const regexes = disparadores.map(comoRegex);
  const faltan = new Set();
  for (const archivo of archivosDelGuardian()) {
    const texto = readFileSync(resolve(raiz, archivo), "utf8");
    // Este archivo no se mira a sí mismo: sus rutas son ejemplos del chequeo, no
    // archivos que lea.
    const nombradas = archivo === ESTE_ARCHIVO ? [] : rutasNombradas(texto);
    for (const ruta of [archivo, ...nombradas]) {
      if (!cubierta(regexes, ruta)) faltan.add(`${ruta} (la nombra ${archivo})`);
    }
  }
  assert.deepEqual(
    [...faltan],
    [],
    `Estas rutas no disparan ${RUTA_WORKFLOW}: un cambio ahí puede romper el guardián sin que ` +
      "el workflow corra. Sumalas a on.push.paths y a on.pull_request.paths.",
  );
});

test("el propio chequeo reconoce lo que cubre un glob y lo que no", () => {
  // Un guardián que nunca se demostró que falla no es un guardián.
  const regexes = ["backend/**", "README.md", "scripts/*.mjs"].map(comoRegex);
  assert.ok(cubierta(regexes, "backend/src/servidor.ts"));
  assert.ok(cubierta(regexes, "backend/src/"));
  assert.ok(cubierta(regexes, "README.md"));
  assert.ok(cubierta(regexes, "scripts/verificar-tokens.mjs"));
  assert.ok(!cubierta(regexes, "shared/datos/nutricion-parametros.json"));
  assert.ok(!cubierta(regexes, "scripts/test/otro.test.mjs"), "un * no cruza carpetas");
  assert.ok(!cubierta(regexes, "shared/api/openapi.yaml"));
});
