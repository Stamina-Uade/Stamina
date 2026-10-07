#!/usr/bin/env node
/**
 * scripts/generar-modelos.mjs
 *
 * AGENTS.md §4.2: los modelos SE GENERAN desde el contrato, no se escriben a
 * mano. Un `data class` tipeado a mano en Android y un `openapi.yaml` divergen,
 * y divergen en silencio: el campo que el servidor renombró sigue compilando en
 * el cliente y llega null en producción.
 *
 * Lee    shared/api/openapi.yaml
 * Escribe android/core/src/main/kotlin/com/tecladus/trainer/core/red/ModelosGenerados.kt
 *
 * Cubre lo que el contrato usa hoy y NADA más: objetos, enums de strings, arrays,
 * $ref y los tipos primitivos. Si aparece un `oneOf`, un `allOf` o un
 * `additionalProperties` tipado, este generador **falla ruidosamente** en vez de
 * emitir algo aproximado. Un generador que adivina es peor que no tenerlo.
 *
 * Se corre con `npm run generar:modelos`. El archivo generado SÍ se commitea, y
 * `npm run verificar:modelos` falla si lo commiteado no coincide.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const entrada = resolve(raiz, "shared/api/openapi.yaml");
const salida = resolve(
  raiz,
  "android/core/src/main/kotlin/com/tecladus/trainer/core/red/ModelosGenerados.kt",
);

const doc = parse(readFileSync(entrada, "utf8"));
const esquemas = doc?.components?.schemas;
if (!esquemas) {
  console.error("[generar-modelos] no encontré components.schemas en", entrada);
  process.exit(1);
}

const problemas = [];

/** snake_case -> camelCase. El JSON sigue en snake_case: lo dice @SerialName. */
function aCamel(nombre) {
  return nombre.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
}
/** kebab o snake -> PascalCase, para nombres de tipo. */
function aPascal(nombre) {
  return nombre.replace(/(^|[_-])([a-zA-Z0-9])/g, (_, __, c) => c.toUpperCase());
}
/** UPPER_SNAKE, para constantes de enum. */
function aConstante(valor) {
  return valor.replace(/[- ]/g, "_").toUpperCase();
}

function nombreDeRef(ref) {
  const m = /^#\/components\/schemas\/(.+)$/.exec(ref || "");
  if (!m) {
    problemas.push(`$ref que no apunta a components.schemas: ${ref}`);
    return "String";
  }
  return m[1];
}

/** Los que son un primitivo con nombre: se aplanan al tipo de Kotlin. */
const ALIAS = {};

/** Las clases anidadas que hubo que inventar para objetos sin nombre en el contrato. */
const anidadas = [];

/** ¿El contrato deja que este campo llegue en null? Una rama `{type: "null"}` en oneOf/anyOf, o "null" en `type`. */
function esAnulable(esquema) {
  if (!esquema) return false;
  const esNull = (x) => x && (x.type === "null" || (Array.isArray(x.type) && x.type.includes("null")));
  if (esNull(esquema)) return true;
  const union = esquema.oneOf || esquema.anyOf;
  return Array.isArray(union) && union.some(esNull);
}

function tipoKotlin(esquema, contexto, nombreSugerido) {
  if (!esquema) return "String";
  if (esquema.$ref) {
    const n = nombreDeRef(esquema.$ref);
    return ALIAS[n] || n;
  }
  // OpenAPI 3.1 escribe "puede ser null" como oneOf:[X, {type:"null"}]. Eso NO es
  // una union: acá se devuelve el tipo de X, y el "?" lo pone emitirClase —también
  // cuando el campo es REQUERIDO, que no quiere decir "nunca null"—. Cualquier otro
  // oneOf sí es una union y este generador no la adivina.
  const union = esquema.oneOf || esquema.anyOf;
  if (union) {
    const sinNull = union.filter((x) => x && x.type !== "null");
    const hayNull = union.length !== sinNull.length;
    if (hayNull && sinNull.length === 1) return tipoKotlin(sinNull[0], contexto, nombreSugerido);
    problemas.push(`${contexto}: oneOf/anyOf de verdad (${union.length} ramas) no está soportado y no se adivina`);
    return "String";
  }
  if (esquema.allOf) {
    problemas.push(`${contexto}: allOf no está soportado y no se adivina`);
    return "String";
  }
  switch (esquema.type) {
    case "string":
      return "String";
    case "boolean":
      return "Boolean";
    case "integer":
      return esquema.format === "int64" ? "Long" : "Int";
    case "number":
      return "Double";
    case "array":
      return `List<${tipoKotlin(esquema.items, contexto + "[]")}>`;
    case "object": {
      if (esquema.additionalProperties && esquema.additionalProperties !== true) {
        problemas.push(`${contexto}: additionalProperties tipado no está soportado`);
        return "String";
      }
      if (!esquema.properties) {
        problemas.push(`${contexto}: objeto sin properties`);
        return "String";
      }
      // Objeto anónimo dentro de otro: se le arma una clase con el nombre del
      // padre y el de la propiedad. Es fea, y a propósito: si aparece mucho, la
      // señal es que ese objeto merece su lugar en components.schemas.
      if (!nombreSugerido) {
        problemas.push(`${contexto}: objeto anónimo sin nombre sugerido`);
        return "String";
      }
      anidadas.push({ nombre: nombreSugerido, esquema, contexto });
      return nombreSugerido;
    }
    default:
      problemas.push(`${contexto}: tipo desconocido "${esquema.type}"`);
      return "String";
  }
}

// Primera pasada: los esquemas que son un primitivo con nombre se vuelven alias.
for (const [nombre, esq] of Object.entries(esquemas)) {
  if (!esq.properties && !esq.enum && esq.type && esq.type !== "object" && esq.type !== "array") {
    ALIAS[nombre] = tipoKotlin(esq, nombre);
  }
}

const lineas = [];
lineas.push(`// =============================================================================
// GENERADO por scripts/generar-modelos.mjs desde shared/api/openapi.yaml
// NO EDITAR A MANO: se reescribe con \`npm run generar:modelos\` y el CI falla si
// lo commiteado no coincide.
//
// contrato: ${doc.info?.title || "?"} v${doc.info?.version || "?"}
//
// AGENTS.md §5: el JSON va en snake_case, los tiempos son enteros de milisegundos
// desde epoch y todo viaja en un sobre {"data": …} o {"error": {…}}. Los nombres
// de Kotlin están en camelCase y @SerialName guarda el nombre real del contrato:
// cambiar uno sin cambiar el otro rompe la deserialización y no el compilador.
// =============================================================================

package com.tecladus.trainer.core.red

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
`);

// Los alias, escritos como comentario: en Kotlin no hacen falta typealias para esto.
const listaAlias = Object.entries(ALIAS);
if (listaAlias.length) {
  lineas.push("/**");
  lineas.push(" * Tipos del contrato que son un primitivo con nombre. Se aplanan:");
  for (const [n, t] of listaAlias) lineas.push(` *  - ${n} -> ${t}`);
  lineas.push(" */");
  lineas.push("");
}

for (const [nombre, esq] of Object.entries(esquemas)) {
  if (ALIAS[nombre]) continue;

  const doc1 = (esq.description || "").split("\n")[0].trim();

  if (esq.enum) {
    if (esq.type !== "string") problemas.push(`${nombre}: enum que no es de strings`);
    lineas.push(`/** ${doc1 || nombre} */`);
    lineas.push("@Serializable");
    lineas.push(`enum class ${aPascal(nombre)} {`);
    for (const v of esq.enum) {
      lineas.push(`    @SerialName("${v}")`);
      lineas.push(`    ${aConstante(v)},`);
      lineas.push("");
    }
    lineas.push("}");
    lineas.push("");
    continue;
  }

  if (!esq.properties) {
    problemas.push(`${nombre}: no es enum ni tiene properties`);
    continue;
  }

  emitirClase(aPascal(nombre), esq, doc1, nombre);
}

/* Las clases que salieron de objetos anónimos se emiten al final, y también sus
   enums anónimos, para que el archivo no dependa del orden de aparición. */
while (anidadas.length) {
  const { nombre, esquema, contexto } = anidadas.shift();
  emitirClase(nombre, esquema, `Parte de ${contexto.split(".")[0]}. No tiene nombre en el contrato.`, nombre);
}

function emitirClase(nombreClase, esq, doc1, prefijo) {
  const requeridos = new Set(esq.required || []);
  lineas.push(`/** ${doc1 || nombreClase} */`);
  lineas.push("@Serializable");
  lineas.push(`data class ${nombreClase}(`);
  for (const [prop, sub] of Object.entries(esq.properties)) {
    // Un enum anónimo de strings se aplana a String: inventarle un tipo a
    // "ok"/"down" que el contrato no nombró es adivinar.
    const tipo = tipoKotlin(sub, `${prefijo}.${prop}`, aPascal(prefijo) + aPascal(prop));
    const obligatorio = requeridos.has(prop);
    // 🛑 Requerido y anulable: la clave viene SIEMPRE, y a veces con null.
    // `Plan.event_date_ms` es así —un plan sin fecha de carrera—, y salía como
    // `Long` sin "?": Android no podía leer un plan sin fecha. Swift ya lo hacía bien.
    const anulable = esAnulable(sub);
    const camel = aCamel(prop);
    const desc = (sub.description || "").split("\n")[0].trim();
    if (desc) lineas.push(`    /** ${desc.replace(/\*\//g, "*\\/")} */`);
    if (camel !== prop) lineas.push(`    @SerialName("${prop}")`);
    const sufijo = !obligatorio ? "? = null" : anulable ? "?" : "";
    lineas.push(`    val ${camel}: ${tipo}${sufijo},`);
  }
  lineas.push(")");
  lineas.push("");
}

if (problemas.length) {
  console.error("[generar-modelos] el contrato usa cosas que este generador NO cubre:");
  for (const p of problemas) console.error("  -", p);
  console.error("  No se escribió nada. Agregá el caso al generador o simplificá el contrato.");
  process.exit(1);
}

mkdirSync(dirname(salida), { recursive: true });
writeFileSync(salida, lineas.join("\n").replace(/\n{3,}/g, "\n\n"), "utf8");

const cuantos = Object.keys(esquemas).length - listaAlias.length;
console.log(`[generar-modelos] ${cuantos} modelos y ${listaAlias.length} alias desde ${doc.info?.title}`);
console.log(`[generar-modelos]   -> ${salida.replace(raiz + "/", "")}`);
