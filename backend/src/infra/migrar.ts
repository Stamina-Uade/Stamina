/**
 * infra/migrar.ts — aplica las migraciones de backend/migraciones/ en orden.
 *
 * AGENTS.md §11:
 *   - las migraciones se versionan en el repositorio, numeradas
 *   - si una migración es prerrequisito del código, CORRE ANTES de desplegar
 *   - el arranque tiene que FALLAR FUERTE si falta una columna que el código
 *     necesita: un `column does not exist` atrapado y devuelto como null se
 *     disfraza de resultado normal y se descubre semanas después
 *
 * Por eso esto es un comando aparte (`npm run migrar`) y NO corre solo al
 * arrancar el servidor: en una máquina compartida, un despliegue que migra solo
 * es un despliegue que puede tomar un lock sobre una tabla mientras hay tráfico.
 */
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { cargarConfigConSecretos } from "./secretos-aws.js";
import { crearDb, type Db } from "./db.js";

/**
 * La carpeta de migraciones se busca SUBIENDO desde este archivo hasta
 * encontrarla, en vez de con una ruta relativa fija.
 *
 * El motivo es concreto y ya rompió una vez: con `rootDir: "."` el compilado
 * queda en `dist/src/infra/`, no en `dist/infra/`, así que un `../../` que
 * funciona en desarrollo apunta a `dist/migraciones` en producción. Un test de
 * integración lo agarró; en el servidor habría sido un despliegue que arranca y
 * migra cero tablas.
 */
function buscarMigraciones(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 6; i++) {
    const candidato = join(dir, "migraciones");
    if (existsSync(candidato)) return candidato;
    const arriba = dirname(dir);
    if (arriba === dir) break;
    dir = arriba;
  }
  throw new Error(
    "migrar: no encontré la carpeta backend/migraciones subiendo desde " +
      dirname(fileURLToPath(import.meta.url))
  );
}

const DIR = buscarMigraciones();

async function asegurarTabla(db: Db): Promise<void> {
  await db.consultar(`
    create table if not exists migraciones (
      nombre        text primary key,
      hash          text   not null,
      aplicada_en_ms bigint not null
    )
  `);
}

/**
 * Qué archivos de la carpeta son migraciones, y en qué orden.
 *
 * Los que empiezan con punto se ignoran: el `tar` de macOS mete `._001_auth.sql`
 * (metadatos AppleDouble, binarios) y el primer despliegue los quiso correr como SQL
 * ("invalid message format"). Un .sql visible con otro formato de nombre, en cambio,
 * es un error de proceso y se dice fuerte: saltearlo en silencio sería desplegar
 * código que espera una tabla que nunca se creó.
 */
export function archivosDeMigracion(nombres: readonly string[]): string[] {
  const sql = nombres.filter((f) => f.endsWith(".sql") && !f.startsWith("."));
  const malos = sql.filter((f) => !/^\d{3}_[a-z0-9_]+\.sql$/.test(f));
  if (malos.length > 0) {
    throw new Error(`migrar: ${malos.join(", ")} no tiene(n) la forma NNN_nombre.sql`);
  }
  return sql.sort();
}

export async function migrar(db: Db, log: (s: string) => void = console.log): Promise<number> {
  await asegurarTabla(db);

  const archivos = archivosDeMigracion(readdirSync(DIR));
  const aplicadas = new Map<string, string>();
  for (const f of await db.consultar<{ nombre: string; hash: string }>("select nombre, hash from migraciones")) {
    aplicadas.set(f.nombre, f.hash);
  }

  let nuevas = 0;
  for (const archivo of archivos) {
    const sql = readFileSync(join(DIR, archivo), "utf8");
    const hash = createHash("sha256").update(sql).digest("hex");
    const ya = aplicadas.get(archivo);

    if (ya !== undefined) {
      // Una migración aplicada que cambió de contenido es un error de proceso, no
      // algo que se pueda "reaplicar": la base ya no coincide con el repositorio.
      if (ya !== hash) {
        throw new Error(
          `migrar: ${archivo} ya está aplicada pero su contenido CAMBIÓ. ` +
            `Una migración aplicada no se edita: escribí una nueva.`
        );
      }
      continue;
    }

    log(`  aplicando ${archivo}`);
    await db.enTransaccion(async (tx) => {
      await tx.consultar(sql);
      await tx.consultar("insert into migraciones (nombre, hash, aplicada_en_ms) values ($1, $2, $3)", [
        archivo,
        hash,
        Date.now(),
      ]);
    });
    nuevas++;
  }

  return nuevas;
}

// Sólo cuando se ejecuta como comando, no cuando lo importa un test.
if (process.argv[1] && process.argv[1].endsWith("migrar.js")) {
  const config = await cargarConfigConSecretos();
  const db = crearDb(config);
  try {
    const n = await migrar(db);
    console.log(n === 0 ? "migrar: no había nada nuevo" : `migrar: ${n} migración(es) aplicada(s)`);
  } catch (e) {
    console.error("migrar: FALLÓ —", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  } finally {
    await db.cerrar();
  }
}
