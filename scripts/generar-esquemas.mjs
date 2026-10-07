#!/usr/bin/env node
/**
 * scripts/generar-esquemas.mjs
 *
 * AGENTS.md §4.2: los modelos y la validación SE GENERAN desde el contrato, no se
 * escriben a mano. Un esquema tipeado a mano en el servidor y un contrato en
 * OpenAPI divergen, y divergen en silencio.
 *
 * Lee  shared/api/openapi.yaml
 * Escribe backend/src/generado/esquemas.ts
 *
 * OpenAPI 3.1 usa JSON Schema 2020-12 tal cual, así que los esquemas se pueden
 * pasar a Ajv sin traducir. Lo único que hay que reescribir son los $ref:
 * "#/components/schemas/X"  ->  "#/$defs/X".
 *
 * Se corre con `npm run generar`, y `npm run build` lo corre solo. El archivo
 * generado NO se commitea (backend/.gitignore).
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const aca = dirname(fileURLToPath(import.meta.url));
const raizRepo = resolve(aca, "..");
const entrada = resolve(raizRepo, "shared/api/openapi.yaml");
const salida = resolve(raizRepo, "backend/src/generado/esquemas.ts");

const doc = parse(readFileSync(entrada, "utf8"));

if (!doc?.components?.schemas) {
  console.error("[generar-esquemas] no encontré components.schemas en", entrada);
  process.exit(1);
}

/** Reescribe los $ref de OpenAPI a $defs, en profundidad. */
function reapuntar(nodo) {
  if (Array.isArray(nodo)) return nodo.map(reapuntar);
  if (nodo && typeof nodo === "object") {
    const salida = {};
    for (const [k, v] of Object.entries(nodo)) {
      if (k === "$ref" && typeof v === "string") {
        salida[k] = v.replace("#/components/schemas/", "#/$defs/");
      } else if (k === "oneOf" && Array.isArray(v) && v.some((x) => x && x.type === "null")) {
        // 🛑 Un nullable del contrato (`oneOf: [X, {type: null}]`) se valida con anyOf.
        // Fastify valida con `coerceTypes`, y con coerción `false`, `0` y `""` también
        // "son" null: con oneOf coincidían las DOS ramas y un
        // `pregnant_or_breastfeeding: false` legítimo daba 400. Sin coerción las ramas
        // son disjuntas, así que anyOf dice lo mismo que el contrato. Lo agarró el test
        // "PATCH /v1/me guarda y vacía los dos campos de la 1.1.0". Los generadores de
        // los clientes siguen leyendo el oneOf del YAML, que no cambia.
        salida["anyOf"] = reapuntar(v);
      } else if (k === "examples" && Array.isArray(v)) {
        // Ajv 8 no conoce "examples" como array (es de OpenAPI). Se descarta:
        // es documentación, no validación.
        continue;
      } else {
        salida[k] = reapuntar(v);
      }
    }
    return salida;
  }
  return nodo;
}

const defs = reapuntar(doc.components.schemas);

/**
 * Los cuerpos de entrada de cada operación. Fastify valida con esto, así que la
 * validación del servidor sale LITERALMENTE del contrato (AGENTS.md §14.1).
 */
const cuerpos = {};
for (const [ruta, ops] of Object.entries(doc.paths ?? {})) {
  for (const [metodo, op] of Object.entries(ops)) {
    const esquema = op?.requestBody?.content?.["application/json"]?.schema;
    if (!esquema || !op.operationId) continue;
    cuerpos[op.operationId] = reapuntar(esquema);
  }
}

/**
 * Los parámetros de ruta y de query de cada operación, como esquemas de objeto.
 *
 * Existen desde la 1.1.0 del contrato, que trae las primeras rutas con ids en el
 * path (`/gym/sessions/{session_id}`) y las primeras listas con `cursor` y `limit`.
 * Sin esto habría que escribir esos esquemas a mano en cada ruta, y un patrón de id
 * escrito dos veces es un patrón que diverge. Los headers (Idempotency-Key) no van
 * acá: los lee el servidor a mano, con su propio tope.
 */
const compartidos = doc.components?.parameters ?? {};
function resolverParametro(p) {
  if (!p?.$ref) return p;
  const nombre = p.$ref.replace("#/components/parameters/", "");
  const encontrado = compartidos[nombre];
  if (!encontrado) {
    console.error(`[generar-esquemas] parámetro inexistente: ${p.$ref}`);
    process.exit(1);
  }
  return encontrado;
}

const parametros = {};
for (const ops of Object.values(doc.paths ?? {})) {
  const deLaRuta = ops.parameters ?? [];
  for (const [metodo, op] of Object.entries(ops)) {
    if (metodo === "parameters" || !op?.operationId) continue;
    const porLugar = { path: {}, query: {} };
    const requeridos = { path: [], query: [] };
    for (const p of [...deLaRuta, ...(op.parameters ?? [])].map(resolverParametro)) {
      if (p.in !== "path" && p.in !== "query") continue;
      porLugar[p.in][p.name] = reapuntar(p.schema ?? {});
      if (p.required) requeridos[p.in].push(p.name);
    }
    const salidaOp = {};
    for (const lugar of ["path", "query"]) {
      if (Object.keys(porLugar[lugar]).length === 0) continue;
      salidaOp[lugar] = {
        type: "object",
        // Un parámetro que el contrato no declara se rechaza, igual que una clave
        // de más en un cuerpo (docs/API.md §7).
        additionalProperties: false,
        properties: porLugar[lugar],
        required: requeridos[lugar],
      };
    }
    if (Object.keys(salidaOp).length > 0) parametros[op.operationId] = salidaOp;
  }
}

const generado = {
  _generado_por: "scripts/generar-esquemas.mjs — NO EDITAR A MANO",
  _fuente: "shared/api/openapi.yaml",
  _version_contrato: doc.info?.version ?? null,
  $defs: defs,
  cuerpos,
  parametros,
};

// Se emite un .ts y no un .json a propósito: tsc lo compila como cualquier otro
// módulo, así que no hace falta copiar archivos al `dist/` con un comando que en
// Windows y en macOS se escribe distinto (AGENTS.md §10.3).
const ts =
  "/* GENERADO por scripts/generar-esquemas.mjs desde shared/api/openapi.yaml.\n" +
  " * NO EDITAR A MANO: se reescribe en cada `npm run build`.\n" +
  " * No se commitea (backend/.gitignore): si el contrato cambia y nadie regenera,\n" +
  " * el build falla en vez de servir un esquema viejo. */\n" +
  "export const ESQUEMAS = " +
  JSON.stringify(generado, null, 2) +
  " as const;\n";

mkdirSync(dirname(salida), { recursive: true });
writeFileSync(salida, ts, "utf8");

console.log(
  `[generar-esquemas] ${Object.keys(defs).length} esquemas y ${Object.keys(cuerpos).length} cuerpos -> backend/src/generado/esquemas.ts`
);
