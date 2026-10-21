/**
 * contexto.ts — lo que las rutas necesitan, en un objeto.
 *
 * Se pasa explícito en vez de vivir en variables globales: es lo que hace que un
 * test pueda levantar el servidor con otra base sin tocar el código.
 */
import type { Config } from "./config.js";
import type { Db } from "./infra/db.js";
import type { Cache } from "./infra/redis.js";
import type { Correo } from "./infra/correo.js";
import type { VerificadorDeProveedores } from "./infra/proveedores.js";

export interface Contexto {
  readonly config: Config;
  readonly db: Db;
  readonly cache: Cache;
  readonly correo: Correo;
  /**
   * Quién verifica los id_token de Google y Apple. Opcional para que los tests que
   * no lo usan no tengan que armarlo: sin él se arma uno con `config.proveedores`.
   */
  readonly proveedores?: VerificadorDeProveedores;
  /** Inyectable para que los tests puedan fijar el reloj. */
  readonly ahoraMs: () => number;
}
