/**
 * infra/cripto.ts — contraseñas, códigos y tokens.
 *
 * AGENTS.md §12:
 *   - contraseñas con bcrypt/argon2, nunca MD5 ni SHA-1  -> argon2id
 *   - códigos y tokens con un generador CRIPTOGRÁFICAMENTE seguro
 *   - JWT con el algoritmo FIJADO EN CÓDIGO, nunca el `alg` del header
 *   - refresh token guardado HASHEADO
 */
import { randomBytes, randomInt, timingSafeEqual, createHash, createHmac, hkdfSync } from "node:crypto";
import { hash as argonHash, verify as argonVerify, Algorithm } from "@node-rs/argon2";
import { SignJWT, jwtVerify } from "jose";
import type { Config } from "../config.js";

/**
 * Parámetros de argon2id. 19 MiB y 2 pasadas es el perfil de referencia de OWASP
 * para argon2id; se elige el de MENOR memoria a propósito, porque esta máquina
 * tiene 3,8 GB y tres proyectos (AGENTS.md §2). Subirlo acá es subir el costo por
 * login en una máquina que no tiene margen.
 */
const ARGON = {
  algorithm: Algorithm.Argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
} as const;

export async function hashearPassword(claro: string): Promise<string> {
  return argonHash(claro, ARGON);
}

export async function verificarPassword(claro: string, hash: string): Promise<boolean> {
  try {
    return await argonVerify(hash, claro, ARGON);
  } catch {
    return false;
  }
}

/**
 * 🛑 Anti-enumeración por TIEMPO (AGENTS.md §12, docs/API.md §3).
 *
 * Cuando el correo no existe, el servidor tiene que gastar lo mismo que cuando
 * existe. Si no, tarda 40 ms en un caso y 300 ms en el otro, y se enumeran las
 * cuentas igual aunque el JSON sea idéntico.
 *
 * Este hash es de una contraseña de descarte y se calcula UNA vez al arrancar.
 */
let hashDummy: string | null = null;

export async function prepararHashDummy(): Promise<void> {
  hashDummy = await hashearPassword(randomBytes(32).toString("hex"));
}

export async function verificarDummy(claro: string): Promise<void> {
  if (hashDummy === null) hashDummy = await hashearPassword(randomBytes(32).toString("hex"));
  await verificarPassword(claro, hashDummy);
}

/** Código de 6 alfanuméricos en mayúscula, como el diseño (`CodigoVerificacion`). */
const ALFABETO_CODIGO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sin I, O, 0, 1
export function generarCodigo(): string {
  let s = "";
  for (let i = 0; i < 6; i++) s += ALFABETO_CODIGO[randomInt(ALFABETO_CODIGO.length)];
  return s;
}

/** Token opaco de 32 bytes. Para refresh, registro y recuperación. */
export function generarTokenOpaco(): string {
  return randomBytes(32).toString("base64url");
}

/**
 * Hash del token para guardarlo. SHA-256 y no argon2 a propósito: el token ya es
 * 32 bytes aleatorios, o sea que no hay nada que adivinar por fuerza bruta, y
 * argon2 en cada refresh sería un costo de CPU por request en una máquina
 * apretada. Lo que argon2 protege —una contraseña que la gente elige mal— acá no
 * aplica.
 */
export function hashearToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/**
 * El refresh que sale de ROTAR `anterior`. Determinístico a propósito (decisión 0013).
 *
 * Si la respuesta de un refresh se pierde —el servidor rotó y el teléfono nunca se
 * enteró—, el teléfono vuelve a mandar el refresh viejo. Con un sucesor al azar eso
 * sólo se puede contestar con OTRO sucesor; con uno derivado, el servidor contesta
 * exactamente el mismo token sin haberlo guardado nunca en claro: de la base sólo
 * conoce el hash.
 *
 * HMAC-SHA256 con una clave derivada del `JWT_SECRET` por HKDF, con su propia
 * etiqueta: sin el secreto del servidor no se puede calcular el sucesor de un refresh
 * robado. Rotar el `JWT_SECRET` sólo afecta a los reintentos en curso en ese momento.
 */
export function refreshSucesor(config: Pick<Config, "jwtSecret">, anterior: string): string {
  const clave = Buffer.from(hkdfSync("sha256", config.jwtSecret, "trainer", "rotacion-de-refresh-v1", 32));
  return createHmac("sha256", clave).update(anterior).digest("base64url");
}

/** Comparación en tiempo constante, para códigos y tokens. */
export function igualSeguro(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ba.length !== bb.length) {
    // Comparar contra sí mismo para no delatar el largo por el tiempo.
    timingSafeEqual(ba, ba);
    return false;
  }
  return timingSafeEqual(ba, bb);
}

// ---------------------------------------------------------------- access JWT --

/** 🛑 Fijado en código. NUNCA se lee el `alg` del header del token (§12). */
const ALG = "HS256";

export interface ClaimsAcceso {
  sub: string;
  /** id de la sesión: deja revocar un access sin esperar a que venza. */
  sid: string;
}

export async function firmarAcceso(config: Config, claims: ClaimsAcceso): Promise<{ token: string; venceMs: number }> {
  const ahora = Math.floor(Date.now() / 1000);
  const vence = ahora + config.accessTtlS;
  const token = await new SignJWT({ sid: claims.sid })
    .setProtectedHeader({ alg: ALG })
    .setSubject(claims.sub)
    .setIssuedAt(ahora)
    .setExpirationTime(vence)
    .setIssuer("trainer")
    .setAudience("trainer-app")
    .sign(config.jwtSecret);
  return { token, venceMs: vence * 1000 };
}

export async function verificarAcceso(config: Config, token: string): Promise<ClaimsAcceso | null> {
  try {
    const { payload } = await jwtVerify(token, config.jwtSecret, {
      algorithms: [ALG], // fijado: un token con alg:none o alg:RS256 se rechaza
      issuer: "trainer",
      audience: "trainer-app",
    });
    const sub = payload.sub;
    const sid = payload["sid"];
    if (typeof sub !== "string" || typeof sid !== "string") return null;
    return { sub, sid };
  } catch {
    return null;
  }
}

/** JWT de un solo uso emitido después de validar el código de correo. */
export async function firmarPasoDeCorreo(
  config: Config,
  email: string,
  proposito: "registro" | "recuperacion",
  ahoraMs: number,
  vidaMs: number
): Promise<string> {
  const emitido = Math.floor(ahoraMs / 1000);
  return new SignJWT({ proposito })
    .setProtectedHeader({ alg: ALG })
    .setSubject(email)
    .setJti(generarTokenOpaco())
    .setIssuedAt(emitido)
    .setExpirationTime(Math.floor((ahoraMs + vidaMs) / 1000))
    .setIssuer("trainer")
    .setAudience("trainer-mail-step")
    .sign(config.jwtSecret);
}

export async function verificarPasoDeCorreo(
  config: Config,
  token: string,
  proposito: "registro" | "recuperacion",
  ahoraMs: number
): Promise<boolean> {
  // Los tokens opacos emitidos antes del despliegue mantienen su ventana de 10 min.
  if (!token.includes(".")) return true;
  try {
    const { payload } = await jwtVerify(token, config.jwtSecret, {
      algorithms: [ALG], issuer: "trainer", audience: "trainer-mail-step",
      currentDate: new Date(ahoraMs),
    });
    return typeof payload.sub === "string" &&
      typeof payload.jti === "string" &&
      payload.proposito === proposito;
  } catch {
    return false;
  }
}

/** Obtiene el correo de un permiso firmado; Redis guarda sólo su huella y uso. */
export async function emailDePasoDeCorreo(
  config: Config,
  token: string,
  proposito: "registro" | "recuperacion",
  ahoraMs: number
): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, config.jwtSecret, {
      algorithms: [ALG], issuer: "trainer", audience: "trainer-mail-step",
      currentDate: new Date(ahoraMs),
    });
    return typeof payload.sub === "string" && typeof payload.jti === "string" &&
      payload.proposito === proposito ? payload.sub : null;
  } catch {
    return null;
  }
}
