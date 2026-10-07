/**
 * dominios/catalogo/sembrar.ts — carga shared/datos/ejercicios.json en la base.
 *
 * AGENTS.md §9.1: el catálogo es DATO. Este comando es lo que hace verdad "un
 * ejercicio nuevo se agrega sin desplegar la app": se edita el JSON, se valida con
 * `npm run verificar:catalogo` en la raíz del repo, y se corre esto en el servidor.
 *
 * - En UNA transacción: o entra el catálogo entero o no entra nada. Uno a medio
 *   cargar tiene sustitutos que apuntan a ejercicios que todavía no existen.
 * - Idempotente: sólo escribe las filas que cambiaron, así que se puede correr en
 *   cada despliegue sin ensuciar `actualizado_en_ms`.
 * - Lo que ya no está en el JSON se marca retirado, no se borra (004_catalogo.sql).
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Db } from "../../infra/db.js";

interface EjercicioSemilla {
  id: string;
  nombre: Record<string, string | null>;
  patron: string;
  equipamiento: string;
  lado: string;
  unidad: string;
  musculos: Array<{ id: string; rol: string }>;
  sustitutos: Array<{ id: string; tipo: string }>;
  articulaciones: string[];
}

interface Semilla {
  _meta: { version: string };
  diccionarios: Record<string, Record<string, Record<string, string | null>>>;
  ejercicios: EjercicioSemilla[];
}

/** Clave del JSON -> tipo de la tabla. */
const TIPOS = {
  patrones: "patron",
  equipamiento: "equipamiento",
  musculos: "musculo",
  articulaciones: "articulacion",
} as const;

/** Igual que en migrar.ts: se busca subiendo, porque el compilado queda en dist/src/… */
export function buscarSemilla(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 8; i++) {
    const c = join(dir, "shared/datos/ejercicios.json");
    if (existsSync(c)) return c;
    const arriba = dirname(dir);
    if (arriba === dir) break;
    dir = arriba;
  }
  throw new Error("sembrar: no encontré shared/datos/ejercicios.json");
}

/**
 * Lo mínimo que rompería la carga. El validador completo es
 * scripts/verificar-catalogo.mjs y corre en CI; esto no lo reemplaza.
 */
function comprobar(semilla: Semilla): void {
  const ids = new Set<string>();
  for (const e of semilla.ejercicios) {
    if (ids.has(e.id)) throw new Error(`sembrar: el id "${e.id}" está repetido`);
    ids.add(e.id);
  }
  for (const e of semilla.ejercicios) {
    for (const s of e.sustitutos) {
      if (!ids.has(s.id)) throw new Error(`sembrar: "${e.id}" tiene un sustituto que no existe: "${s.id}"`);
    }
  }
}

export async function sembrarCatalogo(
  db: Db,
  ahoraMs: number,
  ruta: string = buscarSemilla()
): Promise<{ version: string; ejercicios: number; cambiados: number; retirados: number }> {
  const semilla = JSON.parse(readFileSync(ruta, "utf8")) as Semilla;
  comprobar(semilla);
  const version = semilla._meta.version;

  return db.enTransaccion(async (tx) => {
    for (const [clave, tipo] of Object.entries(TIPOS)) {
      for (const [id, nombres] of Object.entries(semilla.diccionarios[clave] ?? {})) {
        await tx.consultar(
          `insert into diccionario_ejercicios (tipo, id, nombres) values ($1, $2, $3)
           on conflict (tipo, id) do update set nombres = excluded.nombres
            where diccionario_ejercicios.nombres is distinct from excluded.nombres`,
          [tipo, id, JSON.stringify(nombres)]
        );
      }
    }

    let cambiados = 0;
    for (const e of semilla.ejercicios) {
      const filas = await tx.consultar(
        `insert into ejercicios
           (id, nombres, patron, equipamiento, lado, unidad, musculos, sustitutos, articulaciones,
            version_catalogo, actualizado_en_ms, retirado_en_ms)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, null)
         on conflict (id) do update set
           nombres = excluded.nombres, patron = excluded.patron, equipamiento = excluded.equipamiento,
           lado = excluded.lado, unidad = excluded.unidad, musculos = excluded.musculos,
           sustitutos = excluded.sustitutos, articulaciones = excluded.articulaciones,
           version_catalogo = excluded.version_catalogo, actualizado_en_ms = excluded.actualizado_en_ms,
           retirado_en_ms = null
          where (ejercicios.nombres, ejercicios.patron, ejercicios.equipamiento, ejercicios.lado,
                 ejercicios.unidad, ejercicios.musculos, ejercicios.sustitutos, ejercicios.articulaciones)
                is distinct from
                (excluded.nombres, excluded.patron, excluded.equipamiento, excluded.lado,
                 excluded.unidad, excluded.musculos, excluded.sustitutos, excluded.articulaciones)
             or ejercicios.retirado_en_ms is not null
         returning id`,
        [
          e.id,
          JSON.stringify(e.nombre),
          e.patron,
          e.equipamiento,
          e.lado,
          e.unidad,
          JSON.stringify(e.musculos),
          JSON.stringify(e.sustitutos),
          JSON.stringify(e.articulaciones),
          version,
          ahoraMs,
        ]
      );
      cambiados += filas.length;
    }

    const retirados = await tx.consultar<{ id: string }>(
      `update ejercicios set retirado_en_ms = $1
        where retirado_en_ms is null and not (id = any($2::text[]))
    returning id`,
      [ahoraMs, semilla.ejercicios.map((e) => e.id)]
    );

    return { version, ejercicios: semilla.ejercicios.length, cambiados, retirados: retirados.length };
  });
}

// Sólo cuando se ejecuta como comando (`npm run sembrar`), no cuando lo importa un test.
if (process.argv[1] && process.argv[1].endsWith("sembrar.js")) {
  const { cargarConfigConSecretos } = await import("../../infra/secretos-aws.js");
  const { crearDb } = await import("../../infra/db.js");
  const config = await cargarConfigConSecretos();
  const db = crearDb(config);
  try {
    const r = await sembrarCatalogo(db, Date.now());
    console.log(
      `sembrar: catálogo ${r.version} · ${r.ejercicios} ejercicios · ${r.cambiados} escritos · ${r.retirados} retirados`
    );
  } catch (e) {
    console.error("sembrar: FALLÓ —", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  } finally {
    await db.cerrar();
  }
}
