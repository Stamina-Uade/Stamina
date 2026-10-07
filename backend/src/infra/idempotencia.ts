/**
 * infra/idempotencia.ts — que reintentar no duplique.
 *
 * 🛑 AGENTS.md §5.2: "La app se usa EN EL GIMNASIO Y CORRIENDO, o sea con señal
 * mala o sin señal. Toda mutación que el cliente pueda reintentar lleva una clave
 * de idempotencia generada por el cliente, y el servidor devuelve el mismo
 * resultado ante el mismo pedido en vez de crear un duplicado. Sin esto, un
 * usuario con mala señal termina con la sesión del martes cargada tres veces."
 *
 * Cómo funciona, y por qué así:
 *
 *   1. El cliente manda `Idempotency-Key`. La clave es SUYA: el servidor no la
 *      inventa, porque el que reintenta es el cliente.
 *   2. La clave se guarda junto con el usuario y la ruta. La misma clave de dos
 *      personas distintas, o para dos endpoints distintos, son cosas distintas.
 *   3. Se guarda además el HASH DEL CUERPO. Si llega la misma clave con un cuerpo
 *      distinto, eso NO es un reintento: es un error del cliente, y hay que
 *      gritarlo (409) en vez de devolverle la respuesta de otra cosa.
 *   4. La respuesta se guarda y se devuelve tal cual al reintento, con el mismo
 *      status. Un reintento tiene que ser indistinguible del original.
 *
 * La carrera —dos reintentos que llegan a la vez— la resuelve la BASE, con un
 * insert que choca contra la clave primaria. No un `select` y después un `insert`,
 * que es exactamente donde se cuelan los duplicados.
 */
import { createHash } from "node:crypto";
import type { FastifyReply, FastifyRequest } from "fastify";
import type { Db } from "./db.js";
import { ErrorApi } from "./errores.js";

/** Cuánto vive un registro. Más que cualquier reintento razonable, y no eterno. */
export const VIDA_MS = 24 * 60 * 60 * 1000;

/** Tope del header: una clave es un identificador, no un canal de datos. */
const MAX_LARGO_CLAVE = 200;

export function hashCuerpo(cuerpo: unknown): string {
  // Las claves se ordenan para que {a,b} y {b,a} den el mismo hash: es el mismo
  // pedido escrito distinto, y un cliente que reintenta puede serializar en otro
  // orden.
  const estable = JSON.stringify(cuerpo ?? null, (_k, v) =>
    v !== null && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v as object).sort(([a], [b]) => a.localeCompare(b)))
      : v
  );
  return createHash("sha256").update(estable).digest("hex");
}

export interface Guardado {
  http_status: number;
  respuesta: unknown;
}

export function crearIdempotencia(db: Db, ahoraMs: () => number) {
  return {
    /**
     * Reserva la clave, o devuelve lo que ya se guardó para ella.
     *
     * - `{ tipo: "nuevo" }`      -> seguí, es la primera vez
     * - `{ tipo: "repetido" }`   -> devolvé esto tal cual, ya se hizo
     * - `{ tipo: "en-vuelo" }`   -> llegó otro igual y todavía no terminó
     * - lanza `conflict`         -> misma clave, cuerpo distinto
     */
    async reservar(
      clave: string,
      usuarioId: string,
      metodoRuta: string,
      cuerpo: unknown
    ): Promise<{ tipo: "nuevo" } | { tipo: "repetido"; guardado: Guardado } | { tipo: "en-vuelo" }> {
      if (clave.length > MAX_LARGO_CLAVE) {
        throw new ErrorApi("bad_request", "Idempotency-Key is too long");
      }
      const ahora = ahoraMs();
      const hash = hashCuerpo(cuerpo);

      // Un solo viaje a la base, y la carrera la resuelve la PK. `do nothing` +
      // `returning` no devuelve fila cuando hubo choque, así que se lee después.
      const insertado = await db.unaFila<{ clave: string }>(
        `insert into idempotencia (clave, usuario_id, metodo_ruta, cuerpo_hash, creado_en_ms, vence_en_ms)
              values ($1, $2, $3, $4, $5, $6)
         on conflict (clave, usuario_id, metodo_ruta) do nothing
           returning clave`,
        [clave, usuarioId, metodoRuta, hash, ahora, ahora + VIDA_MS]
      );
      if (insertado !== null) return { tipo: "nuevo" };

      const previo = await db.unaFila<{
        cuerpo_hash: string;
        http_status: number | null;
        respuesta: unknown;
        vence_en_ms: number;
      }>(
        `select cuerpo_hash, http_status, respuesta, vence_en_ms
           from idempotencia
          where clave = $1 and usuario_id = $2 and metodo_ruta = $3`,
        [clave, usuarioId, metodoRuta]
      );

      // Venció entre el insert y el select, o lo purgaron: se reintenta limpio.
      if (previo === null) return { tipo: "nuevo" };

      if (previo.vence_en_ms <= ahora) {
        await db.consultar(
          `update idempotencia
              set cuerpo_hash = $4, creado_en_ms = $5, vence_en_ms = $6, http_status = null, respuesta = null
            where clave = $1 and usuario_id = $2 and metodo_ruta = $3`,
          [clave, usuarioId, metodoRuta, hash, ahora, ahora + VIDA_MS]
        );
        return { tipo: "nuevo" };
      }

      // 🛑 Misma clave, otro cuerpo. No es un reintento.
      if (previo.cuerpo_hash !== hash) {
        throw new ErrorApi("conflict", "Idempotency-Key was already used with a different body");
      }

      if (previo.http_status === null) return { tipo: "en-vuelo" };
      return { tipo: "repetido", guardado: { http_status: previo.http_status, respuesta: previo.respuesta } };
    },

    async guardar(
      clave: string,
      usuarioId: string,
      metodoRuta: string,
      httpStatus: number,
      respuesta: unknown
    ): Promise<void> {
      await db.consultar(
        `update idempotencia set http_status = $4, respuesta = $5
          where clave = $1 and usuario_id = $2 and metodo_ruta = $3`,
        [clave, usuarioId, metodoRuta, httpStatus, JSON.stringify(respuesta ?? null)]
      );
    },

    /**
     * Si la operación falló, la reserva se suelta: un 500 no se cachea. Si no, un
     * error transitorio quedaría congelado 24 horas y el cliente no podría
     * reintentar nunca.
     */
    async soltar(clave: string, usuarioId: string, metodoRuta: string): Promise<void> {
      await db.consultar(
        `delete from idempotencia
          where clave = $1 and usuario_id = $2 and metodo_ruta = $3 and http_status is null`,
        [clave, usuarioId, metodoRuta]
      );
    },
  };
}

export type Idempotencia = ReturnType<typeof crearIdempotencia>;

/**
 * Envuelve un handler para que respete `Idempotency-Key`.
 *
 * Si el header no viene, el handler corre normal: la clave es OPCIONAL en la API
 * y obligatoria en el cliente. Un servidor que exige el header rompe a cualquiera
 * que todavía no lo mande, y eso es un cambio de contrato disfrazado.
 */
export function conIdempotencia(
  idem: Idempotencia,
  handler: (req: FastifyRequest, res: FastifyReply) => Promise<unknown>
) {
  return async function (req: FastifyRequest, res: FastifyReply): Promise<unknown> {
    const clave = req.headers["idempotency-key"];
    const usuario = req.usuario;
    if (typeof clave !== "string" || clave === "" || usuario === undefined) {
      return handler(req, res);
    }

    const ruta = `${req.method}:${req.routeOptions?.url ?? req.url}`;
    const reserva = await idem.reservar(clave, usuario.id, ruta, req.body);

    if (reserva.tipo === "repetido") {
      res.code(reserva.guardado.http_status);
      res.header("Idempotency-Replayed", "true");
      return reserva.guardado.respuesta;
    }
    if (reserva.tipo === "en-vuelo") {
      // Otro reintento del mismo pedido todavía está corriendo. Devolver 409 sería
      // mentira —no hay conflicto, hay carrera—, así que se pide reintentar.
      throw new ErrorApi("conflict", "The same request is still in flight", 1);
    }

    try {
      const salida = await handler(req, res);
      await idem.guardar(clave, usuario.id, ruta, res.statusCode, salida);
      return salida;
    } catch (e) {
      await idem.soltar(clave, usuario.id, ruta).catch(() => {});
      throw e;
    }
  };
}
