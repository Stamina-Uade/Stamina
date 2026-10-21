#!/usr/bin/env node
/**
 * scripts/generar-textos-swift.mjs
 *
 * AGENTS.md §10: **ningún texto visible al usuario va hardcodeado.**
 *
 * El problema de cumplir esa regla con `String(localized: "reg.correo.titulo")`
 * es que la clave es una cadena suelta: un typo compila igual y aparece en
 * pantalla como la clave cruda, en producción. Esto convierte el catálogo en
 * propiedades de Swift, así que **un typo no compila**.
 *
 * Lee     ios/Trainer/Trainer/Recursos/Localizable.xcstrings
 * Escribe ios/Trainer/Trainer/Recursos/TextosGenerados.swift
 *
 * La fuente de verdad es el CATÁLOGO, no este archivo: se edita en Xcode como
 * cualquier traducción y esto se vuelve a correr. Al revés no.
 *
 * Los textos con parámetros salen como funciones, con el tipo que dice el
 * especificador: `%@` es String y `%lld` es Int.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const aca = dirname(fileURLToPath(import.meta.url));
const raizRepo = resolve(aca, "..");

/**
 * Los catálogos. Hay dos porque son dos binarios: el reloj no puede leer el
 * catálogo del teléfono, y meterle los 388 textos de la app a un target que usa
 * 40 sería cargarle peso al binario que menos lugar tiene.
 */
const CATALOGOS = [
  {
    nombre: "Textos",
    entrada: resolve(raizRepo, "ios/Trainer/Trainer/Recursos/Localizable.xcstrings"),
    salida: resolve(raizRepo, "ios/Trainer/Trainer/Recursos/TextosGenerados.swift"),
  },
  {
    nombre: "TextosReloj",
    entrada: resolve(raizRepo, "ios/Trainer/TrainerWatch/Recursos/Localizable.xcstrings"),
    salida: resolve(raizRepo, "ios/Trainer/TrainerWatch/Recursos/TextosGenerados.swift"),
  },
];


function generar({ nombre: nombreDelEnum, entrada, salida }) {
  const problemas = [];

/**
 * El texto de una localización.
 *
 * Un texto simple lo trae en `stringUnit`. Uno con **plural** lo trae en
 * `variations.plural`, con una entrada por categoría (`one`, `other`, …) y sin
 * `stringUnit` arriba. Sin esto, una clave con plural quedaba con valor vacío,
 * el generador no le detectaba los parámetros y la emitía como propiedad en vez
 * de función: la llamada dejaba de compilar, o peor, mostraba el `%lld` crudo.
 *
 * Se lee la variante `other`, que es la que siempre existe y la que lleva todos
 * los especificadores.
 */
function valorDe(localizacion) {
  if (!localizacion) return "";
  if (localizacion.stringUnit?.value) return localizacion.stringUnit.value;
  const plural = localizacion.variations?.plural;
  if (plural) {
    return plural.other?.stringUnit?.value ?? plural.one?.stringUnit?.value ?? "";
  }
  return "";
}

const aCamel = (clave) =>
  clave
    .split(/[._-]/)
    .filter(Boolean)
    .map((parte, i) => (i === 0 ? parte : parte.charAt(0).toUpperCase() + parte.slice(1)))
    .join("");

/**
 * Los especificadores de formato.
 *
 * Soporta las dos formas, y hace falta que soporte las dos: `%@` posicional
 * implícito, y `%1$@` explícito, que es la que usa cualquier texto de más de un
 * argumento porque el orden de las palabras cambia entre idiomas. Sin esto, un
 * texto con dos parámetros salía como `var` en vez de función y se mostraba con
 * los `%` crudos en pantalla.
 *
 * `%%` es un porcentaje literal y no es un parámetro.
 */
function parametros(valor) {
  const texto = String(valor);
  const encontrados = [...texto.matchAll(/%(?:(\d+)\$)?(@|lld|ld|d|%)/g)]
    .filter((m) => m[2] !== "%");

  const porPosicion = new Map();
  encontrados.forEach((m, i) => {
    const posicion = m[1] ? parseInt(m[1], 10) : i + 1;
    const tipo = m[2] === "@" ? "String" : "Int";
    const previo = porPosicion.get(posicion);
    if (previo && previo !== tipo) {
      problemas.push(`el parámetro %${posicion}$ aparece como ${previo} y como ${tipo}`);
    }
    porPosicion.set(posicion, tipo);
  });

  const maximo = porPosicion.size ? Math.max(...porPosicion.keys()) : 0;
  const salida = [];
  for (let i = 1; i <= maximo; i++) {
    const tipo = porPosicion.get(i);
    if (!tipo) {
      problemas.push(`falta el parámetro %${i}$ (hay hasta %${maximo}$)`);
      salida.push({ nombre: `arg${i}`, tipo: "String" });
    } else {
      salida.push({ nombre: `arg${i}`, tipo });
    }
  }
  return salida;
}

  const catalogo = JSON.parse(readFileSync(entrada, "utf8"));
  const idiomaFuente = catalogo.sourceLanguage ?? "en";
  const todas = Object.keys(catalogo.strings ?? {}).sort();
  /**
   * 🪤 Las claves que no pueden ser una propiedad de Swift se saltean.
   *
   * Son las que Xcode EXTRAE SOLO al compilar: un `Text("\(a) / \(b)")` es una
   * `LocalizedStringKey`, y Xcode la agrega al catálogo como `"%lld / %lld"`, sin
   * traducción y sin `extractionState: "manual"`. El código ya las usa directo, no
   * a través de `Textos`, y `"%lld"` no es un nombre posible. Antes de esto,
   * cualquier compilación en Xcode agregaba una y el generador dejaba de correr
   * — en el teléfono y en el reloj — por claves que nunca iba a emitir.
   */
  const claves = todas.filter((clave) => /^[A-Za-z][A-Za-z0-9._-]*$/.test(clave));
  const salteadas = todas.length - claves.length;
  if (claves.length === 0) {
    console.error(`[generar-textos-swift] ${entrada} no tiene ni una clave`);
    process.exit(1);
  }

  const vistos = new Map();
  const lineas = [];

lineas.push(
  "// =============================================================================",
  "// GENERADO por scripts/generar-textos-swift.mjs desde",
  "// ios/Trainer/Trainer/Recursos/Localizable.xcstrings",
  "//",
  "// NO EDITAR A MANO. Para cambiar un texto se edita el CATÁLOGO —en Xcode, como",
  "// cualquier traducción— y se corre `npm run generar:textos`.",
  "//",
  "// AGENTS.md §10: ningún texto visible al usuario va hardcodeado, y fechas,",
  "// números y unidades se formatean con el locale del sistema. Esto resuelve lo",
  "// primero; lo segundo es de quien presenta el dato.",
  `//`,
  `// ${claves.length} claves · idioma de autoría: ${idiomaFuente}`,
  "// =============================================================================",
  "",
  "import Foundation",
  "",
  "/// Los textos. Una propiedad por clave del catálogo: un typo en una",
  "/// clave deja de ser un bug de producción y pasa a ser un error de compilación.",
  `enum ${nombreDelEnum} {`
);

for (const clave of claves) {
  const entradaClave = catalogo.strings[clave];
  const valorFuente = valorDe(entradaClave?.localizations?.[idiomaFuente]);

  const nombre = aCamel(clave);
  if (vistos.has(nombre)) {
    problemas.push(`"${clave}" y "${vistos.get(nombre)}" dan el mismo nombre en Swift: ${nombre}`);
    continue;
  }
  vistos.set(nombre, clave);

  const idiomas = Object.keys(entradaClave?.localizations ?? {})
    .filter((i) => valorDe(entradaClave.localizations[i]) !== "");
  const faltan = ["es", "en", "fr"].filter((i) => !idiomas.includes(i));
  if (faltan.length) problemas.push(`"${clave}" no está traducida a: ${faltan.join(", ")}`);

  const args = parametros(valorFuente);
  lineas.push("");
  lineas.push(`    /// ${valorFuente.replace(/\n/g, " ").slice(0, 110)}`);
  if (args.length === 0) {
    lineas.push(`    static var ${nombre}: String { String(localized: "${clave}") }`);
  } else {
    const firma = args.map((a) => `_ ${a.nombre}: ${a.tipo}`).join(", ");
    const paso = args.map((a) => a.nombre).join(", ");
    lineas.push(`    static func ${nombre}(${firma}) -> String {`);
    lineas.push(`        String(format: String(localized: "${clave}"), ${paso})`);
    lineas.push(`    }`);
  }
}

lineas.push("}", "");

if (problemas.length) {
  console.error("[generar-textos-swift] el catálogo tiene problemas:");
  for (const p of problemas) console.error("  - " + p);
  console.error("  Una traducción que falta en silencio sale en pantalla en el otro idioma.");
  process.exit(1);
}

writeFileSync(salida, lineas.join("\n"), "utf8");
console.log(`[generar-textos-swift] ${claves.length} claves, ${vistos.size} propiedades` +
  (salteadas ? ` (${salteadas} extraídas por Xcode, salteadas)` : ""));
console.log(`[generar-textos-swift]   -> ${salida.replace(raizRepo + "/", "")}`);
}

for (const catalogo of CATALOGOS) {
  if (!existsSync(catalogo.entrada)) {
    console.log(`[generar-textos-swift] salteado (no existe): ${catalogo.entrada.replace(raizRepo + "/", "")}`);
    continue;
  }
  mkdirSync(dirname(catalogo.salida), { recursive: true });
  generar(catalogo);
}
