#!/usr/bin/env node
/**
 * scripts/acento-desde-xcode.mjs
 *
 * La vuelta del viaje: leer el acento que se cambió **en Xcode** y bajarlo a
 * `shared/design/tokens.json`, que es la fuente de verdad de los cuatro clientes
 * (AGENTS.md §4.2).
 *
 * Por qué existe. El acento vive en `Assets.xcassets/Acento.colorset` para que
 * se pueda cambiar con el selector de color de Xcode, sin tocar código. Pero si
 * sólo se cambia ahí, **iOS y Android quedan de distinto color** y el CI falla
 * al regenerar el tema. Este script cierra el círculo:
 *
 *   Xcode  ->  tokens.json  ->  generar-tema  ->  Compose + SwiftUI + colorset
 *
 * Correr:  npm run acento:desde-xcode
 */
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const RUTA_COLORSET = resolve(raiz, "ios/Trainer/Trainer/Assets.xcassets/Acento.colorset/Contents.json");
const RUTA_TOKENS = resolve(raiz, "shared/design/tokens.json");

/** Xcode escribe los componentes como "0x7C", como "124" o como "0.486". */
function aByte(valor, quePieza) {
  const s = String(valor).trim();
  let n;
  if (/^0x[0-9a-f]{1,2}$/i.test(s)) n = parseInt(s, 16);
  else if (/^\d+$/.test(s)) n = parseInt(s, 10);
  else if (/^\d*\.\d+$/.test(s)) n = Math.round(parseFloat(s) * 255);
  else throw new Error(`No entiendo el componente ${quePieza}: ${JSON.stringify(valor)}`);
  if (!Number.isInteger(n) || n < 0 || n > 255) {
    throw new Error(`El componente ${quePieza} quedó fuera de 0..255: ${n}`);
  }
  return n;
}

const colorset = JSON.parse(readFileSync(RUTA_COLORSET, "utf8"));
const entrada = (colorset.colors ?? []).find((c) => c.idiom === "universal") ?? colorset.colors?.[0];
if (!entrada?.color?.components) {
  throw new Error(`${RUTA_COLORSET} no tiene un color universal con componentes.`);
}

const espacio = entrada.color["color-space"];
if (espacio && espacio !== "srgb") {
  // Convertir de display-p3 a sRGB no es reencuadrar números: hay colores de P3
  // que sRGB no puede representar. Mejor frenar que emitir un color distinto.
  throw new Error(
    `El colorset está en "${espacio}" y tokens.json habla sRGB. Cambialo a sRGB en Xcode ` +
      `(inspector del color -> Content: sRGB) y volvé a correr esto.`
  );
}

const { red, green, blue, alpha } = entrada.color.components;
const hex =
  "#" +
  [aByte(red, "red"), aByte(green, "green"), aByte(blue, "blue")]
    .map((n) => n.toString(16).padStart(2, "0").toUpperCase())
    .join("");

if (alpha !== undefined && Math.abs(parseFloat(alpha) - 1) > 0.001) {
  throw new Error(
    `El acento tiene alfa ${alpha}. El acento base es opaco; los alfa de los derivados ` +
      `(chip, borde suave, apagado) salen de tokens.json, no de acá.`
  );
}

const crudo = readFileSync(RUTA_TOKENS, "utf8");
const tokens = JSON.parse(crudo);
const anterior = tokens.color.marca.acento.valor.toUpperCase();

if (anterior === hex) {
  console.log(`[acento] Sin cambios: tokens.json y el colorset ya están en ${hex}.`);
  process.exit(0);
}

// Se reemplaza el hex en TODOS los roles de `color.marca` que lo compartían: son
// el mismo color con otro alfa, y si sólo cambiara el base, los chips y bordes
// quedarían del color viejo.
const roles = Object.entries(tokens.color.marca)
  .filter(([n, t]) => !n.startsWith("_") && typeof t?.valor === "string" && t.valor.toUpperCase() === anterior)
  .map(([n]) => n);

let salida = crudo;
for (const rol of roles) {
  const patron = new RegExp(`("${rol}"\\s*:\\s*\\{[^}]*?"valor"\\s*:\\s*")${anterior}(")`, "i");
  if (!patron.test(salida)) throw new Error(`No pude ubicar el rol "${rol}" en tokens.json.`);
  salida = salida.replace(patron, `$1${hex}$2`);
}

// El `rgb` del acento es un dato derivado que quedaría mintiendo.
salida = salida.replace(
  /("rgb"\s*:\s*)\[\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\]/,
  `$1[${aByte(red, "red")}, ${aByte(green, "green")}, ${aByte(blue, "blue")}]`
);

JSON.parse(salida); // que no quede un JSON roto por un reemplazo con mala puntería
writeFileSync(RUTA_TOKENS, salida, "utf8");

console.log(`[acento] ${anterior} -> ${hex} en ${roles.length} roles de color.marca: ${roles.join(", ")}`);
console.log("[acento] Regenerando el tema para los cuatro clientes…\n");
execFileSync(process.execPath, [resolve(raiz, "scripts/generar-tema.mjs")], { stdio: "inherit" });
console.log("\n[acento] Listo. Android e iOS quedaron del mismo color.");
