/**
 * index.ts — el punto de entrada. Arranca, y se apaga bien.
 */
import { cargarConfigConSecretos } from "./infra/secretos-aws.js";
import { crearDb } from "./infra/db.js";
import { crearCache } from "./infra/redis.js";
import { crearCorreo } from "./infra/correo.js";
import { crearServidor } from "./servidor.js";
import { prepararHashDummy } from "./infra/cripto.js";
import { versionContrato } from "./infra/esquemas.js";
import { verificarParaProduccion } from "./dominios/nutricion/guardarrailes.js";
import { verificarParaProduccion as verificarLegalesParaProduccion } from "./dominios/legal/textos.js";
import { verificarParametrosParaProduccion } from "./dominios/nutricion/objetivos.js";
import type { Contexto } from "./contexto.js";

const config = await cargarConfigConSecretos();
const db = crearDb(config);
const cache = crearCache(config);

const ctx: Contexto = {
  config,
  db,
  cache,
  correo: crearCorreo(config, { info: (o, m) => console.log(m, o) }),
  ahoraMs: () => Date.now(),
};

// El hash de descarte de la anti-enumeración se calcula ANTES de aceptar tráfico:
// si se calculara en el primer login, ese primer login tardaría de más y delataría.
await prepararHashDummy();

// 🛑 AGENTS.md §9.2. En producción, el proceso NO LEVANTA mientras quede un
// guardarrail de nutrición sin revisar por alguien con formación. Los valores
// provisionales existen para poder construir, no para llegarle a una persona.
verificarParaProduccion(config.esProduccion, (m) => console.warn(m));

// 🛑 Lo mismo con el aviso de salud y los términos: los escribió un agente y
// ningún abogado los miró. Un aviso legal sin revisar publicado no defiende a
// nadie — y peor, deja constancia de que se publicó algo que nadie leyó.
verificarLegalesParaProduccion(config.esProduccion, (m) => console.warn(m));

// Y con los parámetros que arman los objetivos del día: mismos criterios, mismo
// archivo de datos, misma traba.
verificarParametrosParaProduccion(config.esProduccion, (m) => console.warn(m));

if (config.entorno === "staging") {
  console.warn(
    "⚠️  entorno STAGING (decisión 0011): arranca con valores provisionales. " +
      "Es para probar con gente conocida, NO para publicar."
  );
}

const app = await crearServidor(ctx);

app.log.info(
  { entorno: config.entorno, puerto: config.puerto, contrato: versionContrato() },
  "trainer: arrancando"
);

// El backend NO migra solo al arrancar (§11): en una máquina compartida, un
// despliegue que migra solo puede tomar un lock sobre una tabla con tráfico
// encima. Las migraciones son un paso aparte: `npm run migrar`.

try {
  await app.listen({ port: config.puerto, host: "127.0.0.1" });
  // 127.0.0.1 a propósito: Apache es el único que llega al proceso. Un backend
  // escuchando en 0.0.0.0 en una máquina compartida está expuesto de más.
} catch (e) {
  app.log.error({ err: e }, "trainer: no pudo arrancar");
  process.exit(1);
}

async function apagar(senal: string): Promise<void> {
  app.log.info({ senal }, "trainer: apagando");
  await app.close();
  await Promise.allSettled([db.cerrar(), cache.cerrar()]);
  process.exit(0);
}

process.on("SIGTERM", () => void apagar("SIGTERM"));
process.on("SIGINT", () => void apagar("SIGINT"));
