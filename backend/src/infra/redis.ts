/**
 * infra/redis.ts — la caché: Redis, o un Map del proceso cuando no hay Redis.
 *
 * 🛑 AGENTS.md §2.3.2. Redis es COMPARTIDO con HonneLink y con KARPLAST, y
 * HonneLink lo usa para sus colas. Las reglas no se negocian:
 *
 *   1. índice de base propio  (SELECT 3)
 *   2. prefijo de clave propio (trainer:)
 *   3. jamás FLUSHALL, jamás FLUSHDB, jamás KEYS *
 *   4. TODO lo que se escribe lleva TTL
 *
 * La 4 merece el motivo: ese Redis tiene `maxmemory = 0`, o sea SIN TECHO. Una
 * clave sin vencimiento ahí no es un descuido, es una fuga de memoria que puede
 * voltear los tres proyectos de la máquina. Por eso `poner()` EXIGE un TTL: no hay
 * forma de escribir sin uno.
 *
 * El Redis compartido sigue sin techo. La configuración nueva usa una instancia
 * privada con 16 MB de maxmemory y un límite de 64 MB en systemd; si todavía no
 * se instaló, `REDIS_URL=disabled` mantiene la caché en este proceso.
 */
import { Redis } from "ioredis";
import type { Config } from "../config.js";

export interface Cache {
  /** Qué hay detrás. `memoria` = `REDIS_URL=disabled`. */
  readonly modo: "redis" | "memoria";
  obtener(clave: string): Promise<string | null>;
  /** @param ttlS segundos hasta que vence. Obligatorio, ver el comentario de arriba. */
  poner(clave: string, valor: string, ttlS: number): Promise<void>;
  /** Reserva una clave sólo si no existe; útil para el enfriamiento de reenvíos. */
  ponerSiAusente(clave: string, valor: string, ttlS: number): Promise<boolean>;
  borrar(clave: string): Promise<void>;
  /** Lectura y borrado atómicos para permisos de un solo uso. */
  consumir(clave: string): Promise<string | null>;
  /** Borra sólo si aún contiene este valor, sin aceptar dos verificaciones. */
  consumirSiIgual(clave: string, valor: string): Promise<boolean>;
  /** Incrementa y deja el TTL puesto en el primer incremento. Para rate limit. */
  incrementar(clave: string, ttlS: number): Promise<number>;
  vivo(): Promise<boolean>;
  cerrar(): Promise<void>;
  /** El cliente crudo, para el store de @fastify/rate-limit. `null` sin Redis. */
  cliente(): Redis | null;
}

function exigirTtl(ttlS: number): void {
  if (!Number.isInteger(ttlS) || ttlS <= 0) {
    throw new Error("cache: toda clave lleva TTL > 0. Ver AGENTS.md §2.3.2.");
  }
}

export function crearCache(config: Config): Cache {
  if (config.redisUrl === null) return crearCacheEnMemoria();

  const redis = new Redis(config.redisUrl, {
    db: config.redisDb,
    keyPrefix: config.redisPrefix,
    maxRetriesPerRequest: 2,
    // Si Redis no está, el backend degrada; no se queda colgado reintentando.
    enableOfflineQueue: false,
    lazyConnect: false,
  });

  // Que un fallo de Redis no tire el proceso: Redis es caché y rate limit, no la
  // fuente de verdad. La fuente de verdad es Postgres.
  redis.on("error", () => {});

  return {
    modo: "redis",
    async obtener(clave) {
      return redis.get(clave);
    },
    async poner(clave, valor, ttlS) {
      exigirTtl(ttlS);
      await redis.set(clave, valor, "EX", ttlS);
    },
    async ponerSiAusente(clave, valor, ttlS) {
      exigirTtl(ttlS);
      return (await redis.set(clave, valor, "EX", ttlS, "NX")) === "OK";
    },
    async borrar(clave) {
      await redis.del(clave);
    },
    async consumir(clave) {
      return await redis.eval(
        "local v=redis.call('GET',KEYS[1]); if v then redis.call('DEL',KEYS[1]) end; return v", 1, clave
      ) as string | null;
    },
    async consumirSiIgual(clave, valor) {
      return Number(await redis.eval(
        "if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('DEL',KEYS[1]) else return 0 end",
        1, clave, valor
      )) === 1;
    },
    async incrementar(clave, ttlS) {
      exigirTtl(ttlS);
      // INCR y TTL en una sola operación: una caída entre ambos dejaría una
      // clave permanente en el Redis compartido, que no tiene techo de memoria.
      const n = await redis.eval(
        "local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n",
        1,
        clave,
        ttlS
      );
      return Number(n);
    },
    async vivo() {
      try {
        return (await redis.ping()) === "PONG";
      } catch {
        return false;
      }
    },
    async cerrar() {
      await redis.quit().catch(() => {});
    },
    cliente() {
      return redis;
    },
  };
}

/**
 * Tope de claves en memoria: es la regla 4 llevada al heap. Sin él, alguien que
 * rote IPs contra el rate limit llena la memoria del proceso. Al pasar el tope se
 * tiran las más viejas, que en un rate limit son las que menos importan.
 */
export const MAX_CLAVES_EN_MEMORIA = 10_000;

/**
 * La caché sin Redis: un Map con vencimiento, adentro del proceso.
 *
 * Alcanza porque Trainer corre como UN proceso (una unidad de systemd): ni el
 * rate limit ni la caché de la puerta de versión tienen que compartirse con nadie.
 * El día que haya dos procesos deja de alcanzar, y la salida es volver a Redis
 * con un usuario ACL propio, no con la contraseña de HonneLink.
 */
export function crearCacheEnMemoria(ahoraMs: () => number = () => Date.now()): Cache {
  const datos = new Map<string, { valor: string; venceMs: number }>();

  function vigente(clave: string): { valor: string; venceMs: number } | undefined {
    const e = datos.get(clave);
    if (e === undefined) return undefined;
    if (e.venceMs <= ahoraMs()) {
      datos.delete(clave);
      return undefined;
    }
    return e;
  }

  function guardar(clave: string, valor: string, ttlS: number): void {
    exigirTtl(ttlS);
    // Borrar antes de poner deja la clave al final del orden de inserción del Map,
    // que es lo que usa el recorte de abajo para saber cuáles son las más viejas.
    datos.delete(clave);
    datos.set(clave, { valor, venceMs: ahoraMs() + ttlS * 1000 });
    while (datos.size > MAX_CLAVES_EN_MEMORIA) {
      const masVieja = datos.keys().next().value;
      if (masVieja === undefined) break;
      datos.delete(masVieja);
    }
  }

  return {
    modo: "memoria",
    async obtener(clave) {
      return vigente(clave)?.valor ?? null;
    },
    async poner(clave, valor, ttlS) {
      guardar(clave, valor, ttlS);
    },
    async ponerSiAusente(clave, valor, ttlS) {
      if (vigente(clave) !== undefined) return false;
      guardar(clave, valor, ttlS);
      return true;
    },
    async borrar(clave) {
      datos.delete(clave);
    },
    async consumir(clave) {
      const valor = vigente(clave)?.valor ?? null;
      if (valor !== null) datos.delete(clave);
      return valor;
    },
    async consumirSiIgual(clave, valor) {
      if (vigente(clave)?.valor !== valor) return false;
      datos.delete(clave);
      return true;
    },
    async incrementar(clave, ttlS) {
      const e = vigente(clave);
      if (e === undefined) {
        guardar(clave, "1", ttlS);
        return 1;
      }
      // Igual que INCR en Redis: suma sin tocar el vencimiento.
      const n = Number.parseInt(e.valor, 10) + 1;
      e.valor = String(n);
      return n;
    },
    async vivo() {
      return true;
    },
    async cerrar() {
      datos.clear();
    },
    cliente() {
      return null;
    },
  };
}
