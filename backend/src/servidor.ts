/**
 * servidor.ts — arma Fastify y registra los plugins. Sin lógica de negocio (§4.4).
 */
import Fastify, { type FastifyInstance } from "fastify";
import rateLimit from "@fastify/rate-limit";
import type { Contexto } from "./contexto.js";
import { opcionesLogger } from "./infra/log.js";
import { ErrorApi, aCuerpo, errorInterno } from "./infra/errores.js";
import { rutasHealth } from "./dominios/health/rutas.js";
import { rutasVersion } from "./dominios/version/rutas.js";
import { rutasAuth } from "./dominios/auth/rutas.js";
import { rutasPerfil } from "./dominios/perfil/rutas.js";
import { rutasObjetivos } from "./dominios/objetivos/rutas.js";
import { rutasLegales } from "./dominios/legal/rutas.js";
import { rutasCatalogo } from "./dominios/catalogo/rutas.js";
import { rutasPlan } from "./dominios/plan/rutas.js";
import { rutasGimnasio } from "./dominios/gimnasio/rutas.js";
import { rutasActividades } from "./dominios/actividades/rutas.js";
import { rutasNutricion } from "./dominios/nutricion/rutas.js";
import { rutasCuenta } from "./dominios/cuenta/rutas.js";
import { rutasPasos } from "./dominios/pasos/rutas.js";

/** Tope de cuerpo. §12: todo lo que viene del body tiene tope server-side. */
const MAX_BODY_BYTES = 64 * 1024;

export async function crearServidor(ctx: Contexto): Promise<FastifyInstance> {
  const app = Fastify({
    logger: opcionesLogger(ctx.config.nivelLog, ctx.config.entorno),
    trustProxy: ctx.config.trustProxy,
    bodyLimit: MAX_BODY_BYTES,
    // Sin esto, un cuerpo con `__proto__` puede contaminar el prototipo.
    onProtoPoisoning: "remove",
    onConstructorPoisoning: "remove",
    ajv: { customOptions: { removeAdditional: false, allErrors: false, strict: false } },
  });

  // ----------------------------------------------------------- rate limit --
  // 🛑 §12: el bucket sale del PATH, nunca de un parámetro que manda el cliente.
  // `routeOptions.url` es el patrón de la ruta, no la URL que llegó: así
  // /me?x=1 y /me?x=2 caen en el mismo bucket, que es lo que se quiere.
  await app.register(rateLimit, {
    global: true,
    max: 60,
    timeWindow: "1 minute",
    // Sin Redis (decisión 0011) el plugin usa su store en memoria, que alcanza
    // para un solo proceso.
    redis: ctx.cache.cliente() ?? undefined,
    nameSpace: "rl:",
    keyGenerator(req) {
      const ruta = req.routeOptions?.url ?? "desconocida";
      return `${req.method}:${ruta}:${req.ip}`;
    },
    /**
     * 🛑 Tiene que devolver un Error, NO el cuerpo ya armado.
     *
     * @fastify/rate-limit LANZA lo que devuelve esta función. Si se le devuelve un
     * objeto plano —el envelope ya formado— llega al manejador de errores como algo
     * que no es un Error, cae en la rama genérica y el cliente recibe un
     * **500 "internal"** en vez de un 429. Un cliente que ve 500 reintenta; uno que
     * ve 429 con Retry-After, espera.
     *
     * Lo agarró el test "el rate limit de login corta": daba 500 en vez de 429, y
     * de paso hacía fallar a media suite en cascada.
     */
    errorResponseBuilder(_req, contexto) {
      return new ErrorApi("rate_limited", "Too many requests", Math.ceil(contexto.ttl / 1000));
    },
  });

  // ------------------------------------------------------ manejo de errores --
  app.setErrorHandler((err, req, res) => {
    if (err instanceof ErrorApi) {
      if (err.reintentarEnS !== undefined) res.header("Retry-After", String(err.reintentarEnS));
      // `aCuerpo` saca `error.details` cuando el error lo trae (contrato 1.6.0).
      return res.code(err.http).send(aCuerpo(err));
    }
    // Fallo de validación de Fastify/Ajv: el cuerpo no cumple el contrato.
    const validacion = (err as { validation?: Array<{ instancePath?: string }> }).validation;
    if (validacion !== undefined) {
      // La contraseña la rechazan DOS capas: el contrato (largo) y la política del
      // servicio (mayúscula y número, infra/password.ts). Para el cliente eso tiene
      // que ser UN solo código, o no puede mostrar un mensaje coherente: una
      // contraseña corta daría `bad_request` y una sin número `weak_password`.
      const esPassword = validacion.some((v) => (v.instancePath ?? "").includes("password"));
      const e = esPassword
        ? new ErrorApi("weak_password", "Password does not meet the policy")
        : new ErrorApi("bad_request", "Request does not match the contract");
      return res.code(e.http).send(aCuerpo(e));
    }
    if ((err as { statusCode?: number }).statusCode === 413) {
      return res.code(413).send(aCuerpo(new ErrorApi("payload_too_large", "Body is too large")));
    }
    req.log.error({ err }, "error no manejado");
    return res.code(500).send(errorInterno(err, ctx.config.expuesto));
  });

  // --------------------------------------------------------------- staging --
  // En staging cada respuesta lo dice. La app puede mostrar "versión de prueba", y
  // cualquiera que mire el tráfico sabe que no está hablando con producción.
  if (ctx.config.entorno === "staging") {
    app.addHook("onRequest", async (_req, res) => {
      res.header("X-Trainer-Environment", "staging");
    });
  }

  app.setNotFoundHandler((_req, res) => {
    res.code(404).send(aCuerpo(new ErrorApi("not_found", "No such route")));
  });

  // ------------------------------------------------------------------ CORS --
  // §12: CORS NUNCA comodín, ni en desarrollo. No se registra ningún plugin de
  // CORS: los clientes son cuatro apps nativas, no un navegador. El día que haya
  // web, se agrega con una lista de orígenes explícita.

  // ---------------------------------------------------------------- rutas --
  await app.register(
    async (v1) => {
      await rutasHealth(v1, ctx);
      await rutasVersion(v1, ctx);
      await rutasAuth(v1, ctx);
      await rutasPerfil(v1, ctx);
      await rutasObjetivos(v1, ctx);
      await rutasLegales(v1);
      // El motor (contrato 1.1.0).
      await rutasCatalogo(v1, ctx);
      await rutasPlan(v1, ctx);
      await rutasGimnasio(v1, ctx);
      await rutasActividades(v1, ctx);
      await rutasNutricion(v1, ctx);
      // Pasos diarios (contrato 1.3.0).
      await rutasPasos(v1, ctx);
      await rutasCuenta(v1, ctx);
    },
    { prefix: "/v1" }
  );

  return app;
}
