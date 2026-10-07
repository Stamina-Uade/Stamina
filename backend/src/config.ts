/**
 * config.ts — lee el entorno UNA vez, al arrancar, y falla fuerte si falta algo.
 *
 * AGENTS.md §3.3: no hay valores por defecto para secretos, ni un modo "si no
 * está, seguimos igual". Un backend que arranca con la mitad de su configuración
 * es un backend que falla en producción a las tres semanas, en un endpoint que
 * nadie probó.
 *
 * §12: EL ENTORNO POR DEFECTO ES PRODUCCIÓN. Si NODE_ENV no está, es producción:
 * errores ocultos y nada de atajos de desarrollo.
 *
 * Los cuatro entornos, y qué afloja cada uno:
 *
 *   production   la regla. Errores ocultos, proxy declarado, secreto real, correo
 *                real, y las trabas de §9.2 y de los textos legales PRENDIDAS.
 *   staging      está en internet igual que producción y se endurece igual —errores
 *                ocultos, proxy declarado, secreto real—, pero deja arrancar con los
 *                valores provisionales. Usa SMTP real y sólo admite un correo
 *                de alta declarado en STAGING_REGISTRATION_EMAIL. Existe para probar la
 *                app con personas conocidas antes de que alguien con formación revise
 *                los números (decisión 0011). NO es para publicar.
 *   development  la máquina de uno.
 *   test         los tests.
 */

export type Entorno = "production" | "staging" | "development" | "test";

function leer(nombre: string): string | undefined {
  const v = process.env[nombre];
  return v === undefined || v === "" ? undefined : v;
}

function obligatoria(nombre: string, faltantes: string[]): string {
  const v = leer(nombre);
  if (v === undefined) {
    faltantes.push(nombre);
    return "";
  }
  return v;
}

function entero(nombre: string, porDefecto: number, min: number, max: number): number {
  const v = leer(nombre);
  if (v === undefined) return porDefecto;
  const n = Number.parseInt(v, 10);
  if (!Number.isInteger(n) || n < min || n > max) {
    throw new Error(`config: ${nombre} tiene que ser un entero entre ${min} y ${max}, llegó "${v}"`);
  }
  return n;
}

export interface ConfigSmtp {
  readonly host: string;
  readonly puerto: number;
  readonly usuario: string;
  readonly clave: string;
  /** `true` = TLS desde el primer byte (465). `false` = STARTTLS (587), que exige TLS igual. */
  readonly tlsDirecto: boolean;
}

export interface Config {
  readonly entorno: Entorno;
  /** Sólo producción. Es lo que prende las trabas de §9.2 y de los textos legales. */
  readonly esProduccion: boolean;
  /**
   * Producción o staging: los dos están en internet. Errores ocultos, secreto de
   * ejemplo prohibido y proxy declarado. Ver el encabezado.
   */
  readonly expuesto: boolean;
  readonly puerto: number;
  readonly nivelLog: string;
  readonly databaseUrl: string;
  readonly pgPoolMax: number;
  /** `null` cuando se declaró `REDIS_URL=disabled` (decisión 0011). */
  readonly redisUrl: string | null;
  readonly redisDb: number;
  readonly redisPrefix: string;
  /** Staging: único correo autorizado a completar un alta. Producción no lo usa. */
  readonly registroPermitido: string | null;
  readonly jwtSecret: Uint8Array;
  readonly accessTtlS: number;
  readonly refreshTtlS: number;
  /**
   * Qué se acepta como IP del cliente. Detrás de Apache hace falta confiar en el
   * proxy o TODAS las requests parecen venir de 127.0.0.1 y el rate limit se
   * vuelve un único bucket global. Pero confiar de más es peor: si el proceso
   * queda expuesto sin proxy, cualquiera manda X-Forwarded-For y se saltea el
   * límite. Por eso NO tiene un default cómodo: se declara, y en un entorno
   * expuesto es obligatoria.
   */
  readonly trustProxy: boolean | string;
  readonly mailProvider: "log" | "smtp";
  readonly mailFrom: string;
  /** Presente sólo con `MAIL_PROVIDER=smtp`. */
  readonly smtp: ConfigSmtp | null;
  /** Versión desplegada. La pone el despliegue; en local queda "dev". */
  readonly version: string;
}

export function cargarConfig(): Config {
  const faltantes: string[] = [];

  const crudo = leer("NODE_ENV");
  const entorno: Entorno =
    crudo === "development" || crudo === "test" || crudo === "staging" ? crudo : "production";
  const esProduccion = entorno === "production";
  const expuesto = entorno === "production" || entorno === "staging";

  const databaseUrl = obligatoria("DATABASE_URL", faltantes);
  // 🛑 Sin Redis es una DECLARACIÓN (`REDIS_URL=disabled`), no un default: si la
  // variable falta sigue siendo un error de arranque (§3.3). En el servidor
  // compartido Trainer no usa el Redis de HonneLink (decisión 0011).
  const redisCrudo = obligatoria("REDIS_URL", faltantes);
  const jwtSecretTexto = obligatoria("JWT_SECRET", faltantes);
  const registroPermitido = entorno === "staging"
    ? obligatoria("STAGING_REGISTRATION_EMAIL", faltantes).trim().toLowerCase()
    : null;
  if (registroPermitido !== null && registroPermitido !== "" && !registroPermitido.includes("@")) {
    throw new Error("config: STAGING_REGISTRATION_EMAIL debe ser un correo");
  }

  const mailProviderCrudo = leer("MAIL_PROVIDER") ?? "log";
  if (mailProviderCrudo !== "log" && mailProviderCrudo !== "smtp") {
    throw new Error(`config: MAIL_PROVIDER tiene que ser "log" o "smtp", llegó "${mailProviderCrudo}"`);
  }
  let smtp: ConfigSmtp | null = null;
  if (mailProviderCrudo === "smtp") {
    smtp = {
      host: obligatoria("SMTP_HOST", faltantes),
      puerto: entero("SMTP_PORT", 587, 1, 65535),
      usuario: obligatoria("SMTP_USER", faltantes),
      clave: obligatoria("SMTP_PASS", faltantes),
      tlsDirecto: leer("SMTP_TLS_DIRECTO") === "true",
    };
    obligatoria("MAIL_FROM", faltantes);
  }

  const trustProxyCrudo = leer("TRUST_PROXY");
  if (expuesto && trustProxyCrudo === undefined) faltantes.push("TRUST_PROXY");

  if (faltantes.length > 0) {
    throw new Error(
      `config: faltan variables obligatorias: ${faltantes.join(", ")}. ` +
        `En el servidor las no secretas vienen de /etc/trainer/trainer.env y las ` +
        `secretas de AWS Secrets Manager ` +
        `(docs/INFRA-EXTERNA.md); en local salen del .env — ver backend/.env.example.`
    );
  }

  // 32 bytes es el piso para HS256. Un secreto corto no es "menos seguro":
  // es un secreto que se puede adivinar.
  if (Buffer.byteLength(jwtSecretTexto, "utf8") < 32) {
    throw new Error(
      "config: JWT_SECRET tiene que tener al menos 32 bytes. Generalo con: openssl rand -hex 48"
    );
  }
  if (expuesto && jwtSecretTexto.includes("cambiar-esto")) {
    throw new Error(`config: JWT_SECRET es el de ejemplo y el entorno es ${entorno}, que está en internet. No.`);
  }

  // El log sirve en desarrollo local; staging usa SMTP real aunque se permitan
  // provisionales del motor. En producción imprimir códigos sería una fuga.
  if (esProduccion && mailProviderCrudo === "log") {
    throw new Error(
      'config: MAIL_PROVIDER="log" escribe los códigos de verificación en el log. ' +
        "En producción eso es una fuga: configurá un proveedor real."
    );
  }

  return {
    entorno,
    esProduccion,
    expuesto,
    puerto: entero("PORT", 8082, 1, 65535),
    nivelLog: leer("LOG_LEVEL") ?? (expuesto ? "info" : "debug"),
    databaseUrl,
    // Pool chico a propósito: tres proyectos en la máquina (AGENTS.md §2.2 y
    // §2.3.3). Medido el 2026-09-10: 100 conexiones, 21 en uso.
    pgPoolMax: entero("PGPOOL_MAX", 5, 1, 20),
    redisUrl: redisCrudo === "disabled" ? null : redisCrudo,
    redisDb: entero("REDIS_DB", 3, 0, 15),
    redisPrefix: leer("REDIS_PREFIX") ?? "trainer:",
    registroPermitido,
    jwtSecret: new TextEncoder().encode(jwtSecretTexto),
    accessTtlS: entero("ACCESS_TTL_S", 1800, 60, 3600),
    refreshTtlS: entero("REFRESH_TTL_S", 2_592_000, 3600, 15_552_000),
    trustProxy: (() => {
      if (trustProxyCrudo === undefined) return false;
      if (trustProxyCrudo === "true") return true;
      if (trustProxyCrudo === "false") return false;
      return trustProxyCrudo; // lista de IPs o CIDR del proxy
    })(),
    mailProvider: mailProviderCrudo,
    mailFrom: leer("MAIL_FROM") ?? "no-responder@example.invalid",
    smtp,
    version: leer("TRAINER_VERSION") ?? "dev",
  };
}
