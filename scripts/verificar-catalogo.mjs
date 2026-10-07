#!/usr/bin/env node
/**
 * scripts/verificar-catalogo.mjs — el catálogo es dato, y el dato también se rompe.
 *
 * AGENTS.md §9.1: "El catálogo de ejercicios es dato, no código. Un ejercicio nuevo
 * se agrega sin desplegar." Justamente por eso hace falta algo que lo valide: un
 * ejercicio que se agrega sin desplegar es un ejercicio que nadie compiló.
 *
 * Verifica que:
 *   - no haya ids repetidos
 *   - todo músculo, equipamiento, patrón y articulación exista en su diccionario
 *   - todo sustituto apunte a un ejercicio que existe
 *   - un sustituto no sea el ejercicio mismo
 *   - cada ejercicio tenga al menos un músculo principal
 *   - los nombres de es-AR y en-US estén (los otros dos pueden faltar, y se cuentan)
 *
 * Correr:  node scripts/verificar-catalogo.mjs
 */
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..");
export const RUTA = resolve(RAIZ, "shared/datos/ejercicios.json");

const OBLIGATORIOS = ["es-AR", "en-US"];
const OPCIONALES = ["pt-BR", "ja-JP"];

export function verificar(doc) {
  const errores = [];
  const avisos = [];
  const { diccionarios: dic, ejercicios: lista } = doc;

  const ids = new Set();
  for (const e of lista) {
    if (ids.has(e.id)) errores.push(`id repetido: "${e.id}"`);
    ids.add(e.id);
  }

  for (const e of lista) {
    const donde = `ejercicio "${e.id}"`;

    for (const l of OBLIGATORIOS) {
      if (typeof e.nombre?.[l] !== "string" || e.nombre[l].trim() === "") {
        errores.push(`${donde}: falta el nombre en ${l}`);
      }
    }
    for (const l of OPCIONALES) {
      if (e.nombre?.[l] === null || e.nombre?.[l] === undefined) {
        avisos.push(`${donde}: sin nombre en ${l}`);
      }
    }

    if (dic.patrones[e.patron] === undefined) errores.push(`${donde}: patrón desconocido "${e.patron}"`);
    if (dic.equipamiento[e.equipamiento] === undefined)
      errores.push(`${donde}: equipamiento desconocido "${e.equipamiento}"`);
    if (!["bilateral", "unilateral"].includes(e.lado)) errores.push(`${donde}: lado inválido "${e.lado}"`);
    if (!["reps", "tiempo"].includes(e.unidad)) errores.push(`${donde}: unidad inválida "${e.unidad}"`);

    const principales = (e.musculos ?? []).filter((m) => m.rol === "principal");
    if (principales.length === 0) errores.push(`${donde}: no tiene ningún músculo principal`);
    for (const m of e.musculos ?? []) {
      if (dic.musculos[m.id] === undefined) errores.push(`${donde}: músculo desconocido "${m.id}"`);
      if (!["principal", "secundario"].includes(m.rol)) errores.push(`${donde}: rol inválido "${m.rol}"`);
    }

    for (const a of e.articulaciones ?? []) {
      if (dic.articulaciones[a] === undefined) errores.push(`${donde}: articulación desconocida "${a}"`);
    }

    if ((e.sustitutos ?? []).length === 0) {
      errores.push(`${donde}: sin sustitutos. Sin al menos uno no se puede resolver "no tengo ese equipo"`);
    }
    for (const s of e.sustitutos ?? []) {
      if (!ids.has(s.id)) errores.push(`${donde}: el sustituto "${s.id}" no existe en el catálogo`);
      if (s.id === e.id) errores.push(`${donde}: se lista a sí mismo como sustituto`);
      if (!["mismo-patron", "mismo-musculo"].includes(s.tipo)) {
        errores.push(`${donde}: tipo de sustituto inválido "${s.tipo}"`);
      }
      // Lo declarado tiene que coincidir con el dato: un "mismo-patron" que en
      // realidad cambia de patrón es exactamente la promesa que la pantalla de
      // sustitutos NO puede cumplir ("el plan no cambia de forma").
      const otro = lista.find((x) => x.id === s.id);
      if (otro !== undefined) {
        const mismoPatron = otro.patron === e.patron;
        if (s.tipo === "mismo-patron" && !mismoPatron) {
          errores.push(`${donde}: "${s.id}" está marcado mismo-patron pero es ${otro.patron}, no ${e.patron}`);
        }
        if (s.tipo === "mismo-musculo" && mismoPatron) {
          errores.push(`${donde}: "${s.id}" comparte patrón; márcalo mismo-patron`);
        }
      }
    }
  }

  // Un diccionario con entradas que nadie usa es ruido que crece.
  for (const [clave, dicc] of Object.entries(dic)) {
    const usadas = new Set(
      lista.flatMap((e) => {
        if (clave === "musculos") return (e.musculos ?? []).map((m) => m.id);
        if (clave === "equipamiento") return [e.equipamiento];
        if (clave === "patrones") return [e.patron];
        if (clave === "articulaciones") return e.articulaciones ?? [];
        return [];
      })
    );
    for (const k of Object.keys(dicc)) {
      if (!usadas.has(k)) avisos.push(`diccionario "${clave}": la entrada "${k}" no la usa ningún ejercicio`);
    }
  }

  return { errores, avisos };
}

if (process.argv[1] && process.argv[1].endsWith("verificar-catalogo.mjs")) {
  const doc = JSON.parse(readFileSync(RUTA, "utf8"));
  const { errores, avisos } = verificar(doc);

  for (const a of avisos) console.log(`aviso  ${a}`);
  for (const e of errores) console.log(`ERROR  ${e}`);

  const faltanPt = doc.ejercicios.filter((e) => !e.nombre["pt-BR"]).length;
  const faltanJa = doc.ejercicios.filter((e) => !e.nombre["ja-JP"]).length;

  console.log(
    `\n[verificar-catalogo] ${doc.ejercicios.length} ejercicios, ` +
      `${Object.keys(doc.diccionarios.musculos).length} músculos, ` +
      `${Object.keys(doc.diccionarios.patrones).length} patrones de movimiento.`
  );
  console.log(`[verificar-catalogo] ${errores.length} error(es), ${avisos.length} aviso(s).`);
  console.log(
    `[verificar-catalogo] traducciones pendientes: ${faltanPt} en pt-BR, ${faltanJa} en ja-JP ` +
      `— hacen falta y NO se inventan (necesitan hablante nativo).`
  );
  if (errores.length > 0) process.exit(1);
}
