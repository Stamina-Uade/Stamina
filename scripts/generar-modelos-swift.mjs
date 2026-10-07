#!/usr/bin/env node
/**
 * scripts/generar-modelos-swift.mjs
 *
 * AGENTS.md §4.2: los modelos de red de los cuatro clientes SE GENERAN desde el
 * contrato. Un modelo escrito a mano y un contrato en OpenAPI divergen, y
 * divergen en silencio: el compilador de Swift no sabe qué dice el YAML.
 *
 * Lee     shared/api/openapi.yaml
 * Escribe ios/TrainerCore/Sources/TrainerCore/Red/ModelosGenerados.swift
 *
 * Esto llena la mitad de Swift de `tokens.json` → `pendientes[generador]`, que
 * decía: "Falta el generador de MODELOS DE RED desde shared/api/openapi.yaml
 * para Kotlin y Swift". Kotlin sigue pendiente y se hace en la fase 6.
 *
 * 🛑 ALCANCE DELIBERADO. Esto NO es un generador de OpenAPI de propósito general:
 * cubre exactamente las formas que el contrato v1 usa, y **falla ruidosamente**
 * ante cualquier otra. Un generador que adivina lo que no entiende produce
 * modelos plausibles y equivocados, que es el peor resultado posible.
 *
 * Igual que el tema (§10.1), el archivo generado SÍ se commitea: una Mac que
 * compila iOS no tiene por qué necesitar Node. El CI verifica que regenerar no
 * produzca diff.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const aca = dirname(fileURLToPath(import.meta.url));
const raizRepo = resolve(aca, "..");
const entrada = resolve(raizRepo, "shared/api/openapi.yaml");
const salida = resolve(
  raizRepo,
  "ios/TrainerCore/Sources/TrainerCore/Red/ModelosGenerados.swift"
);

const doc = parse(readFileSync(entrada, "utf8"));
const esquemas = doc?.components?.schemas;
if (!esquemas) {
  console.error("[generar-modelos-swift] no encontré components.schemas en", entrada);
  process.exit(1);
}

/**
 * Tipos base del contrato que en Swift son un alias y no una struct.
 * AGENTS.md §5: los IDs viajan como string y los tiempos como milisegundos
 * epoch ENTEROS. Que `EpochMs` sea `Int64` y no `Date` es a propósito: el
 * decoder no inventa zonas horarias.
 */
const ALIAS = {
  EpochMs: "Int64",
  Id: "String",
  Email: "String",
  Password: "String",
  CodigoVerificacion: "String",
};

const problemas = [];
function rendirse(donde, motivo) {
  problemas.push(`${donde}: ${motivo}`);
  return "AlgoQueNoEntiendo";
}

const aCamel = (s) =>
  s.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase()).replace(/^([A-Z])/, (m) => m.toLowerCase());
const aPascal = (s) => {
  const c = aCamel(s);
  return c.charAt(0).toUpperCase() + c.slice(1);
};

/** Palabras que en Swift no se pueden usar como nombre sin comillas invertidas. */
const RESERVADAS = new Set(["default", "protocol", "extension", "class", "static", "internal", "operator", "where", "repeat"]);
const nombreSeguro = (s) => (RESERVADAS.has(s) ? `\`${s}\`` : s);

/**
 * Nombres del contrato que en Swift NO se pueden usar tal cual.
 *
 * `Error` es el caso: declarar `struct Error` dentro del módulo TAPA el
 * protocolo `Error` de Swift, y a partir de ahí `Result<T, Error>` o un
 * `catch ... as Error` dejan de significar lo que parecen. El contrato no
 * cambia; cambia sólo cómo se llama el tipo en este cliente.
 */
const RENOMBRES = { Error: "ErrorAPI" };
const enSwift = (n) => RENOMBRES[n] ?? n;

const nombreRef = (ref) => ref.replace("#/components/schemas/", "");

/** Un `oneOf` de [algo, null] es, en Swift, un opcional. Nada más. */
function desenvolverNulo(esq) {
  if (!Array.isArray(esq?.oneOf)) return { esquema: esq, anulable: false };
  const sinNulo = esq.oneOf.filter((o) => o?.type !== "null");
  const teniaNulo = sinNulo.length !== esq.oneOf.length;
  if (sinNulo.length !== 1) return { esquema: esq, anulable: teniaNulo };
  return { esquema: sinNulo[0], anulable: teniaNulo };
}

const enumsAnonimos = [];

/**
 * Traduce un esquema a un tipo de Swift. `contexto` sólo se usa para nombrar los
 * tipos que el contrato declara en línea, sin ponerles nombre.
 */
function tipoSwift(esq, contexto) {
  const { esquema, anulable } = desenvolverNulo(esq);
  const sufijo = anulable ? "?" : "";

  if (esquema?.$ref) {
    const n = nombreRef(esquema.$ref);
    return (ALIAS[n] ?? enSwift(n)) + sufijo;
  }
  if (Array.isArray(esquema?.enum)) {
    if (esquema.type !== "string") return rendirse(contexto, "enum que no es de strings");
    // Un enum sin nombre en el contrato igual necesita un tipo en Swift.
    enumsAnonimos.push({ nombre: contexto, valores: esquema.enum });
    return contexto + sufijo;
  }
  switch (esquema?.type) {
    case "string":
      return "String" + sufijo;
    case "boolean":
      return "Bool" + sufijo;
    case "integer":
      return "Int64" + sufijo;
    case "number":
      return "Double" + sufijo;
    case "array": {
      if (!esquema.items) return rendirse(contexto, "array sin items");
      return `[${tipoSwift(esquema.items, contexto + "Item")}]` + sufijo;
    }
    case "object":
      if (esquema.properties) {
        estructurasAnidadas.push({ nombre: contexto, esquema });
        return contexto + sufijo;
      }
      return rendirse(contexto, "object sin properties");
    default:
      return rendirse(contexto, `type no soportado: ${JSON.stringify(esquema?.type)}`);
  }
}

let estructurasAnidadas = [];

function comentario(texto, sangria) {
  if (!texto) return [];
  return String(texto)
    .trim()
    .split("\n")
    .map((l) => `${sangria}/// ${l.trim()}`);
}

function emitirEnum(nombre, valores, descripcion, sangria = "") {
  const l = [];
  l.push(...comentario(descripcion, sangria));
  l.push(`${sangria}public enum ${nombre}: String, Codable, CaseIterable, Sendable {`);
  for (const v of valores) l.push(`${sangria}    case ${nombreSeguro(aCamel(v))} = "${v}"`);
  l.push(`${sangria}}`);
  return l;
}

function emitirStruct(nombre, esq, sangria = "") {
  const propiedades = esq.properties ?? {};
  const obligatorias = new Set(esq.required ?? []);
  const anidadasAntes = estructurasAnidadas;
  estructurasAnidadas = [];
  const enumsAntes = enumsAnonimos.length;

  const campos = Object.entries(propiedades).map(([clave, sub]) => {
    const swiftNombre = aCamel(clave);
    let contexto = aPascal(clave);
    // Un tipo anidado se llama como su propiedad. Se desambigua en dos casos:
    // si choca con el que lo contiene, y si el nombre es uno de los prohibidos
    // (`Error` anidado seguiría tapando el `Error` de Swift dentro del tipo).
    if (contexto === nombre || enSwift(contexto) !== contexto) contexto += "Detalle";
    let tipo = tipoSwift(sub, contexto);
    // Lo que el contrato no marca obligatorio puede faltar: es opcional, y el
    // cliente tiene que aguantarlo sin romperse (AGENTS.md §12.1).
    if (!obligatorias.has(clave) && !tipo.endsWith("?")) tipo += "?";
    return { clave, swiftNombre, tipo, descripcion: sub?.description };
  });

  const anidadas = estructurasAnidadas;
  const nuevosEnums = enumsAnonimos.splice(enumsAntes);
  estructurasAnidadas = anidadasAntes;

  const l = [];
  l.push("");
  l.push(...comentario(esq.description, sangria));
  l.push(`${sangria}public struct ${nombre}: Codable, Equatable, Sendable {`);

  for (const { nombre: n, valores } of nuevosEnums) {
    l.push(...emitirEnum(n, valores, null, sangria + "    "));
    l.push("");
  }
  for (const { nombre: n, esquema: e } of anidadas) {
    l.push(...emitirStruct(n, e, sangria + "    ").slice(1));
    l.push("");
  }

  for (const c of campos) {
    l.push(...comentario(c.descripcion, sangria + "    "));
    l.push(`${sangria}    public let ${nombreSeguro(c.swiftNombre)}: ${c.tipo}`);
  }

  // El contrato es snake_case y Swift es camelCase (AGENTS.md §5). Las claves se
  // escriben explícitas en vez de usar la estrategia global de conversión: así
  // el mapeo se puede leer y `grep`ear desde el contrato.
  const hayRenombre = campos.some((c) => c.clave !== c.swiftNombre);
  if (hayRenombre) {
    l.push("");
    l.push(`${sangria}    enum CodingKeys: String, CodingKey {`);
    for (const c of campos) {
      l.push(
        c.clave === c.swiftNombre
          ? `${sangria}        case ${nombreSeguro(c.swiftNombre)}`
          : `${sangria}        case ${nombreSeguro(c.swiftNombre)} = "${c.clave}"`
      );
    }
    l.push(`${sangria}    }`);
  }

  l.push("");
  l.push(`${sangria}    public init(`);
  l.push(
    campos
      .map((c) => `${sangria}        ${nombreSeguro(c.swiftNombre)}: ${c.tipo}${c.tipo.endsWith("?") ? " = nil" : ""}`)
      .join(",\n")
  );
  l.push(`${sangria}    ) {`);
  for (const c of campos) l.push(`${sangria}        self.${nombreSeguro(c.swiftNombre)} = ${nombreSeguro(c.swiftNombre)}`);
  l.push(`${sangria}    }`);
  l.push(`${sangria}}`);
  return l;
}

// -----------------------------------------------------------------------------

const salidaLineas = [];
salidaLineas.push(
  "// =============================================================================",
  "// GENERADO por scripts/generar-modelos-swift.mjs desde shared/api/openapi.yaml",
  "// NO EDITAR A MANO: se reescribe en cada `npm run generar:modelos`, y el CI",
  "// falla si el archivo commiteado no coincide con lo que el generador produce.",
  "//",
  `// Contrato ${doc.info?.version ?? "?"}`,
  "//",
  "// AGENTS.md §4.2: los modelos de red se generan desde el contrato, no se",
  "// escriben a mano. AGENTS.md §5: a partir de la primera versión en tienda,",
  "// cambiar la forma o el tipo de algo de acá ROMPE apps ya instaladas.",
  "//",
  "// Convenciones del contrato que se ven acá:",
  "//   - Los IDs son String, siempre, aunque hoy sean UUID.",
  "//   - Los tiempos son Int64 de milisegundos epoch. NO son Date: el decoder no",
  "//     inventa zonas horarias, y la conversión es del que presenta.",
  "//   - Las unidades son enteras y base: peso en gramos, altura en milímetros.",
  "//   - Lo que el contrato no marca `required` es opcional en Swift.",
  "// =============================================================================",
  "",
  "import Foundation",
  ""
);

for (const [nombre, esq] of Object.entries(esquemas)) {
  if (ALIAS[nombre]) {
    salidaLineas.push("");
    salidaLineas.push(...comentario(esq.description, ""));
    salidaLineas.push(`public typealias ${enSwift(nombre)} = ${ALIAS[nombre]}`);
    continue;
  }
  if (Array.isArray(esq.enum)) {
    salidaLineas.push("");
    salidaLineas.push(...emitirEnum(enSwift(nombre), esq.enum, esq.description));
    continue;
  }
  if (esq.type === "object" && esq.properties) {
    salidaLineas.push(...emitirStruct(enSwift(nombre), esq));
    continue;
  }
  problemas.push(`${nombre}: esquema de nivel superior que no sé emitir`);
}

salidaLineas.push("");

if (problemas.length) {
  console.error("[generar-modelos-swift] no entiendo estas partes del contrato:");
  for (const p of problemas) console.error("  - " + p);
  console.error("  Antes que generar algo plausible y equivocado, no genero nada.");
  process.exit(1);
}

mkdirSync(dirname(salida), { recursive: true });
writeFileSync(salida, salidaLineas.join("\n"), "utf8");

const cuantos = Object.keys(esquemas).length;
console.log(`[generar-modelos-swift] ${cuantos} esquemas del contrato ${doc.info?.version ?? "?"}`);
console.log(`[generar-modelos-swift]   -> ${salida.replace(raizRepo + "/", "")}`);
