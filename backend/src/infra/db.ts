/**
 * infra/db.ts — el pool de Postgres.
 *
 * AGENTS.md §12: SQL SIEMPRE parametrizado, nunca concatenado. Este módulo no
 * expone ninguna forma de ejecutar una string armada a mano: `consultar` recibe
 * texto con `$1, $2…` y los valores aparte, y es la única puerta.
 *
 * §2.3.3: base propia, rol propio, pool chico. Trainer nunca escribe en la base de
 * HonneLink ni en la de KARPLAST.
 */
import pg from "pg";
import type { Config } from "../config.js";

// Los BIGINT de Postgres llegan como string por el driver, que es correcto para no
// perder precisión. Pero nuestros tiempos son epoch en milisegundos y entran
// cómodos en un Number (Number.MAX_SAFE_INTEGER es el año 287396). Se convierten
// acá, una vez, para que ninguna ruta tenga que acordarse.
pg.types.setTypeParser(pg.types.builtins.INT8, (v: string) => Number.parseInt(v, 10));

/** Fila cruda de Postgres. Los repositorios la estrechan a su interfaz. */
export type Fila = object;

export interface Db {
  consultar<T extends Fila = Fila>(sql: string, valores?: readonly unknown[]): Promise<T[]>;
  unaFila<T extends Fila = Fila>(sql: string, valores?: readonly unknown[]): Promise<T | null>;
  enTransaccion<T>(fn: (tx: Db) => Promise<T>): Promise<T>;
  vivo(): Promise<boolean>;
  cerrar(): Promise<void>;
}

function envolver(ejecutor: pg.Pool | pg.PoolClient): Omit<Db, "cerrar" | "enTransaccion"> {
  return {
    async consultar<T extends Fila = Fila>(sql: string, valores: readonly unknown[] = []) {
      const r = await ejecutor.query(sql, valores as unknown[]);
      return r.rows as T[];
    },
    async unaFila<T extends Fila = Fila>(sql: string, valores: readonly unknown[] = []) {
      const r = await ejecutor.query(sql, valores as unknown[]);
      return (r.rows[0] as T | undefined) ?? null;
    },
    async vivo() {
      try {
        await ejecutor.query("select 1");
        return true;
      } catch {
        return false;
      }
    },
  };
}

export function crearDb(config: Config): Db {
  const pool = new pg.Pool({
    connectionString: config.databaseUrl,
    max: config.pgPoolMax,
    // Una conexión ociosa retenida es una conexión que le falta a los otros dos
    // proyectos de la máquina (§2.3.3).
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    // Si una consulta tarda más que esto, algo está mal y no vale la pena
    // sostenerla ocupando una conexión del cluster compartido.
    statement_timeout: 10_000,
  });

  const base = envolver(pool);

  return {
    ...base,
    async enTransaccion<T>(fn: (tx: Db) => Promise<T>): Promise<T> {
      const cliente = await pool.connect();
      try {
        await cliente.query("begin");
        const tx: Db = {
          ...envolver(cliente),
          enTransaccion: async (f) => f(tx),
          cerrar: async () => {},
        };
        const r = await fn(tx);
        await cliente.query("commit");
        return r;
      } catch (e) {
        await cliente.query("rollback").catch(() => {});
        throw e;
      } finally {
        cliente.release();
      }
    },
    async cerrar() {
      await pool.end();
    },
  };
}
