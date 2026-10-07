#!/usr/bin/env node
/**
 * scripts/generar-tema.mjs
 *
 * AGENTS.md §10.1.3: de `shared/design/tokens.json` se generan el tema de Compose
 * y el de SwiftUI. Los cuatro clientes leen lo generado.
 *
 * §10.1: "ningún color, tamaño, radio ni fuente se escribe a mano en una pantalla.
 * Todo sale de los tokens." Este generador es la mitad de esa regla; la otra mitad
 * es `scripts/verificar-tokens.mjs`, que falla si alguien igual escribe un `#hex`.
 *
 * Escribe:
 *   android/core/src/main/kotlin/com/tecladus/trainer/core/tema/TokensGenerados.kt
 *   ios/TrainerCore/Sources/TrainerCore/TokensGenerados.swift
 *
 * A diferencia de los esquemas del backend, esto SÍ se commitea: una Mac que
 * compila iOS no tiene por qué necesitar Node. El CI verifica que regenerar no
 * produzca diff, que da la misma garantía sin el costo.
 *
 * Correr:  npm run generar:tema
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const tokens = JSON.parse(readFileSync(resolve(raiz, "shared/design/tokens.json"), "utf8"));

const SALIDA_KT = resolve(raiz, "android/core/src/main/kotlin/com/tecladus/trainer/core/tema/TokensGenerados.kt");
const SALIDA_SWIFT = resolve(raiz, "ios/TrainerCore/Sources/TrainerCore/TokensGenerados.swift");
// El acento, además, como color del catálogo de assets: es la perilla que se
// puede girar desde Xcode sin tocar código (decisión 0007 §12).
const SALIDA_COLORSET = resolve(raiz, "ios/Trainer/Trainer/Assets.xcassets/Acento.colorset/Contents.json");
// El reloj tiene su propio catálogo de assets: sin esta copia, `PaletaReloj`
// cae al valor de respaldo y cambiar el acento en Xcode dejaría el reloj del
// color viejo.
const SALIDA_COLORSET_RELOJ = resolve(raiz, "ios/Trainer/TrainerWatch/Assets.xcassets/Acento.colorset/Contents.json");

// ---------------------------------------------------------------- utilidades --

/** "color.telefono.texto_secundario" -> "telefonoTextoSecundario" */
function aCamel(partes) {
  const [primera, ...resto] = partes.join("_").split("_").filter(Boolean);
  return primera + resto.map((p) => p[0].toUpperCase() + p.slice(1)).join("");
}

/**
 * Los tres campos opcionales de un rol tipografico: interlineado, espaciado de
 * letras y mayusculas. Estaban en tokens.json desde la 0.2.0 y NO llegaban al
 * codigo: el generador emitia solo tamano y peso. Una etiqueta de seccion sin su
 * 0.14em de tracking y sin mayusculas no es la misma etiqueta, y el diseno se
 * separa del producto sin que nadie toque un valor.
 *
 * `interlineado` es un multiplicador en el diseno (CSS line-height). Se emite ya
 * multiplicado por el tamano, en la unidad de cada plataforma, porque ni Compose
 * ni SwiftUI toman multiplicadores.
 */
function numeroCorto(n) {
  return String(Math.round(n * 1000) / 1000);
}
function emANumero(valor) {
  // "-0.03em" -> -0.03
  return parseFloat(String(valor).replace(/em$/, ""));
}

function hexA8Digitos(hex, alfa) {
  const h = hex.replace("#", "");
  const rgb = h.length === 3 ? h.split("").map((c) => c + c).join("") : h;
  const a = Math.round((alfa ?? 1) * 255)
    .toString(16)
    .padStart(2, "0")
    .toUpperCase();
  return a + rgb.toUpperCase();
}

/** Recorre color.* y devuelve [{ nombre, hex, alfa, procedencia, nota }]. */
function recolectarColores() {
  const salida = [];
  for (const [grupo, contenido] of Object.entries(tokens.color)) {
    if (grupo.startsWith("_") || typeof contenido !== "object") continue;
    for (const [nombre, t] of Object.entries(contenido)) {
      if (nombre.startsWith("_") || t === null || typeof t !== "object") continue;
      if (!("valor" in t)) continue;
      if (t.valor === null) continue; // hueco de pendientes[]: NO se emite
      // El fondo del documento de diseño no es un color de la app.
      if (nombre === "fondo_lienzo") continue;
      salida.push({
        nombre: aCamel([grupo, nombre]),
        hex: t.valor,
        alfa: typeof t.alfa === "number" ? t.alfa : 1,
        procedencia: Array.isArray(t.procedencia) ? t.procedencia.join(" ") : "",
        nota: typeof t._nota === "string" ? t._nota : "",
      });
    }
  }
  return salida.sort((a, b) => a.nombre.localeCompare(b.nombre));
}

function recolectarPendientes() {
  return (tokens.pendientes ?? []).map((p) => `${p.id}: ${p.que}`);
}

/**
 * El acento y sus derivados. Todo lo de `color.marca` que comparte el hex del
 * acento es el MISMO color con otro alfa, así que en el cliente se deriva de una
 * sola fuente: cambiar el acento cambia el producto entero (ESPECIFICACION §3).
 */
function recolectarAcento() {
  const base = tokens.color.marca.acento.valor;
  const derivados = [];
  for (const [nombre, t] of Object.entries(tokens.color.marca)) {
    if (nombre.startsWith("_") || nombre === "acento") continue;
    if (typeof t?.valor !== "string") continue;
    if (t.valor.toUpperCase() !== base.toUpperCase()) continue;
    if (typeof t.alfa !== "number") continue;
    derivados.push({ nombre: aCamel(["alfa", nombre.replace(/^acento_/, "")]), alfa: t.alfa });
  }
  return { base, derivados: derivados.sort((a, b) => a.nombre.localeCompare(b.nombre)) };
}

const colores = recolectarColores();
const acento = recolectarAcento();
const pendientes = recolectarPendientes();
const roles = tokens.tipografia.roles;
const radios = tokens.radio.roles;
const control = tokens.tamano_control;
const minimoTactil = control?.objetivo_tactil_minimo?.valor ?? null;
const movimiento = tokens.movimiento.duraciones_medidas_ms;

const CABECERA = (lenguaje) => `${lenguaje === "kt" ? "//" : "//"} =============================================================================
// GENERADO por scripts/generar-tema.mjs desde shared/design/tokens.json
// NO EDITAR A MANO: se reescribe en cada \`npm run generar:tema\`, y el CI falla
// si el archivo commiteado no coincide con lo que el generador produce.
//
// tokens.json version ${tokens._meta.version} · extraído el ${tokens._meta.fecha_extraccion}
//
// AGENTS.md §10.1: ningún color, tamaño, radio ni fuente se escribe a mano en una
// pantalla. Todo sale de acá. Un #FF5722 suelto en un .kt es el principio de que
// Android e iOS dejen de parecerse, y nadie lo va a ver hasta tener las dos
// capturas al lado. \`scripts/verificar-tokens.mjs\` lo hace fallar en CI.
//
// ⚠️ El diseño es ÚNICAMENTE OSCURO. No existe tema claro (pendientes[tema-claro]).
// =============================================================================
`;

// ------------------------------------------------------------------- Kotlin --

const kt = [];
kt.push(CABECERA("kt"));
kt.push(`package com.tecladus.trainer.core.tema

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em

/**
 * Colores del diseño, con el alfa ya compuesto en el canal A.
 *
 * \`marcaAcento\` es el DEFAULT del parámetro \`accent\` del tablero
 * (tokens.json → parametros_del_tablero.accent). Es UN token: cambiarlo en
 * tokens.json y regenerar cambia el producto entero desde un solo lugar. Ninguna
 * pantalla lo escribe a mano.
 */
object TokensColor {`);
for (const c of colores) {
  const comentario = [c.procedencia && `procedencia: ${c.procedencia}`, c.nota].filter(Boolean).join(" · ");
  if (comentario) kt.push(`    /** ${comentario} */`);
  kt.push(`    val ${c.nombre}: Color = Color(0x${hexA8Digitos(c.hex, c.alfa)})`);
}
kt.push(`}

/** Escala tipográfica medida en el diseño. Los tamaños van en sp: escalan con el sistema. */
object TokensTipografia {`);
for (const [nombre, r] of Object.entries(roles)) {
  if (nombre.startsWith("_")) continue;
  kt.push(`    val ${aCamel([nombre])}Tamano: TextUnit = ${r.tamano}.sp`);
  kt.push(`    val ${aCamel([nombre])}Peso: FontWeight = FontWeight(${r.peso})`);
  if (typeof r.interlineado === "number") {
    kt.push(`    val ${aCamel([nombre])}Interlineado: TextUnit = ${numeroCorto(r.tamano * r.interlineado)}.sp`);
  }
  if (r.espaciado_letras) {
    kt.push(`    val ${aCamel([nombre])}EspaciadoLetras: TextUnit = (${numeroCorto(emANumero(r.espaciado_letras))}).em`);
  }
  if (r.mayusculas) {
    kt.push(`    val ${aCamel([nombre])}Mayusculas: Boolean = true`);
  }
}
kt.push(`
    /**
     * ⚠️ El diseño usa ${tokens.tipografia.escala_medida_px.length} tamaños distintos, con medios píxeles.
     * NO es una escala modular (pendientes[escala-tipografica]). Portado tal cual a
     * cuatro plataformas se vuelve insostenible: hay que consolidarlo antes de que
     * esto se use en más de una pantalla.
     */
    val ADVERTENCIA_ESCALA = "${tokens.tipografia._advertencia_escala.replace(/"/g, "'")}"
}

/** Radios de esquina. Los del marco del teléfono y del reloj NO se portan. */
object TokensRadio {`);
for (const [nombre, v] of Object.entries(radios)) {
  if (typeof v === "number") kt.push(`    val ${aCamel([nombre])}: Dp = ${v}.dp`);
}
kt.push(`}

/**
 * Espaciado. Es la escala MEDIDA en el diseño, transcripta tal cual y nombrada por
 * su valor — NO una escala consolidada.
 *
 * ⚠️ El diseño usa ${tokens.espaciado.escala_medida_px.length} gaps distintos, casi continuos.
 * Consolidarlos es una decisión de diseño que NO está tomada
 * (pendientes[escala-espaciado]) y este generador no la inventa. Existe acá para
 * que ninguna pantalla tenga que escribir un \`12.dp\` a mano mientras tanto.
 */
object TokensEspaciado {`);
for (const px of tokens.espaciado.escala_medida_px) kt.push(`    val e${px}: Dp = ${px}.dp`);
kt.push(`}

/** Duraciones de animación, en milisegundos. */
object TokensMovimiento {`);
for (const [nombre, v] of Object.entries(movimiento)) kt.push(`    const val ${aCamel([nombre])}: Int = ${v}`);
kt.push(`}

/**
 * 🛑 Objetivo táctil mínimo. AGENTS.md §10.1, sin excepciones.
 *
 * El diseño de design/origen/ NO lo cumple: el detalle, agrupado por tipo de
 * arreglo, está en design/ESPECIFICACION.md §9.2. design/nuevo/gimnasio.dc.html sí.
 */
object TokensTamano {
    val objetivoTactilMinimo: Dp = ${minimoTactil === null ? "48" : minimoTactil}.dp`);
for (const [nombre, t] of Object.entries(control)) {
  if (nombre.startsWith("_") || nombre === "objetivo_tactil_minimo") continue;
  if (typeof t?.valor === "number") kt.push(`    val ${aCamel([nombre])}: Dp = ${t.valor}.dp`);
}
kt.push(`}

/**
 * Lo que tokens.json declara PENDIENTE. Está acá, en el código, a propósito: un
 * hueco que sólo vive en un JSON no lo ve nadie.
 */
object TokensPendientes {
    val LISTA: List<String> = listOf(
${pendientes.map((p) => `        ${JSON.stringify(p)}`).join(",\n")}
    )
}
`);

// -------------------------------------------------------------------- Swift --

const sw = [];
sw.push(CABECERA("swift"));
sw.push(`import SwiftUI

/// Colores del diseño, con el alfa ya aplicado.
public enum TokensColor {`);
for (const c of colores) {
  const h = c.hex.replace("#", "");
  const rgb = h.length === 3 ? h.split("").map((x) => x + x).join("") : h;
  const r = parseInt(rgb.slice(0, 2), 16) / 255;
  const g = parseInt(rgb.slice(2, 4), 16) / 255;
  const b = parseInt(rgb.slice(4, 6), 16) / 255;
  const comentario = [c.procedencia && `procedencia: ${c.procedencia}`, c.nota].filter(Boolean).join(" · ");
  if (comentario) sw.push(`    /// ${comentario}`);
  sw.push(
    `    public static let ${c.nombre} = Color(.sRGB, red: ${r.toFixed(4)}, green: ${g.toFixed(4)}, blue: ${b.toFixed(4)}, opacity: ${c.alfa})`
  );
}
sw.push(`}

/// Escala tipográfica medida en el diseño.
public enum TokensTipografia {`);
for (const [nombre, r] of Object.entries(roles)) {
  if (nombre.startsWith("_")) continue;
  sw.push(`    public static let ${aCamel([nombre])}Tamano: CGFloat = ${r.tamano}`);
  sw.push(`    public static let ${aCamel([nombre])}Peso: Font.Weight = ${pesoSwift(r.peso)}`);
  if (typeof r.interlineado === "number") {
    sw.push(`    public static let ${aCamel([nombre])}Interlineado: CGFloat = ${numeroCorto(r.tamano * r.interlineado)}`);
  }
  if (r.espaciado_letras) {
    // SwiftUI .tracking() toma puntos, no em: se convierte con el tamano del rol.
    sw.push(`    public static let ${aCamel([nombre])}EspaciadoLetras: CGFloat = ${numeroCorto(emANumero(r.espaciado_letras) * r.tamano)}`);
  }
  if (r.mayusculas) {
    sw.push(`    public static let ${aCamel([nombre])}Mayusculas: Bool = true`);
  }
}
sw.push(`}

/// Radios de esquina.
public enum TokensRadio {`);
for (const [nombre, v] of Object.entries(radios)) {
  if (typeof v === "number") sw.push(`    public static let ${aCamel([nombre])}: CGFloat = ${v}`);
}
sw.push(`}

/// Espaciado: la escala MEDIDA, transcripta. No es una escala consolidada
/// (pendientes[escala-espaciado]).
public enum TokensEspaciado {`);
for (const px of tokens.espaciado.escala_medida_px) sw.push(`    public static let e${px}: CGFloat = ${px}`);
sw.push(`}

/// Duraciones de animación, en segundos (SwiftUI trabaja en segundos).
public enum TokensMovimiento {`);
for (const [nombre, v] of Object.entries(movimiento)) {
  sw.push(`    public static let ${aCamel([nombre])}: Double = ${(v / 1000).toFixed(3)}`);
}
sw.push(`}

/// 🛑 Objetivo táctil mínimo. AGENTS.md §10.1, sin excepciones.
public enum TokensTamano {
    public static let objetivoTactilMinimo: CGFloat = ${minimoTactil === null ? "48" : minimoTactil}`);
for (const [nombre, t] of Object.entries(control)) {
  if (nombre.startsWith("_") || nombre === "objetivo_tactil_minimo") continue;
  if (typeof t?.valor === "number") sw.push(`    public static let ${aCamel([nombre])}: CGFloat = ${t.valor}`);
}
const lineasDeAlfa = acento.derivados
  .map((d) => "    public static let " + d.nombre + ": Double = " + d.alfa)
  .join("\n");
sw.push(`}

/// Los alfa con los que el acento se deriva a sí mismo.
///
/// 🛑 El VALOR del acento **no** está acá: vive en el catálogo de assets de la
/// app (Assets.xcassets/Acento.colorset), para poder cambiarlo desde Xcode.
/// Estos son los alfa que Paleta le aplica encima, y salen de tokens.json para
/// que Android e iOS deriven igual.
public enum TokensAcento {
    /// El valor de tokens.json. Es el RESPALDO: se usa si el catálogo de assets
    /// no está disponible (previews del paquete, tests fuera de la app).
    public static let respaldo = Color(.sRGB, red: ${(parseInt(acento.base.slice(1, 3), 16) / 255).toFixed(4)}, green: ${(parseInt(acento.base.slice(3, 5), 16) / 255).toFixed(4)}, blue: ${(parseInt(acento.base.slice(5, 7), 16) / 255).toFixed(4)}, opacity: 1)
    /// El nombre del color en el catálogo de assets.
    public static let nombreEnAssets = "Acento"
${lineasDeAlfa}
}

/// Lo que tokens.json declara PENDIENTE.
public enum TokensPendientes {
    public static let lista: [String] = [
${pendientes.map((p) => `        ${JSON.stringify(p)}`).join(",\n")}
    ]
}
`);

function pesoSwift(n) {
  return { 400: ".regular", 500: ".medium", 600: ".semibold", 700: ".bold" }[n] ?? ".regular";
}

/** El `.colorset` que Xcode muestra y deja editar con el selector de color. */
function colorsetDelAcento(hex) {
  const h = hex.replace("#", "").toUpperCase();
  return JSON.stringify({
    colors: [{
      color: {
        "color-space": "srgb",
        components: {
          alpha: "1.000",
          red: "0x" + h.slice(0, 2),
          green: "0x" + h.slice(2, 4),
          blue: "0x" + h.slice(4, 6),
        },
      },
      idiom: "universal",
    }],
    info: { author: "generar-tema.mjs", version: 1 },
  }, null, 2) + "\n";
}

for (const [ruta, contenido] of [
  [SALIDA_KT, kt.join("\n")],
  [SALIDA_SWIFT, sw.join("\n")],
  [SALIDA_COLORSET, colorsetDelAcento(acento.base)],
  [SALIDA_COLORSET_RELOJ, colorsetDelAcento(acento.base)],
]) {
  mkdirSync(dirname(ruta), { recursive: true });
  writeFileSync(ruta, contenido, "utf8");
}

console.log(
  `[generar-tema] ${colores.length} colores, ${Object.keys(roles).filter((k) => !k.startsWith("_")).length} roles de tipografía, ` +
    `${Object.values(radios).filter((v) => typeof v === "number").length} radios, ${pendientes.length} pendientes`
);
console.log(`[generar-tema]   -> ${SALIDA_KT.replace(raiz + "/", "")}`);
console.log(`[generar-tema]   -> ${SALIDA_SWIFT.replace(raiz + "/", "")}`);
console.log(`[generar-tema]   -> ${SALIDA_COLORSET.replace(raiz + "/", "")}  (acento ${acento.base}, ${acento.derivados.length} derivados)`);
console.log(`[generar-tema]   -> ${SALIDA_COLORSET_RELOJ.replace(raiz + "/", "")}`);
