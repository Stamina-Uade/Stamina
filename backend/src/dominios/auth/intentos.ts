/**
 * dominios/auth/intentos.ts — el tope de contraseñas equivocadas (contrato 1.6.0).
 *
 * Dos topes, y hacen falta los dos:
 *
 *   - POR CORREO: 5 contraseñas equivocadas seguidas bloquean ESE correo 15
 *     minutos (`too_many_attempts`), venga de donde venga. El rate limit por IP de
 *     las rutas no alcanza contra quien reparte los intentos entre muchas IP o
 *     teléfonos; éste sí, porque cuenta sobre la cuenta atacada.
 *   - POR IP, entre todos los correos: 20 fallos en 15 minutos (`rate_limited`).
 *     Frena al que prueba UNA contraseña común contra muchos correos, que el tope
 *     por correo no ve nunca.
 *
 * Viven en la caché (Redis cuando está), con TTL como todo lo que se escribe ahí
 * (infra/redis.ts). Las claves llevan el SHA-256 del correo y de la IP, nunca el
 * dato en claro (AGENTS.md §8).
 *
 * Lo que NO hace: decir nada del estado de la cuenta. Quien llama sigue
 * contestando `wrong_password` igual que siempre; esto sólo agrega el bloqueo.
 */
import type { Cache } from "../../infra/redis.js";
import { hashearToken } from "../../infra/cripto.js";

export const MAX_FALLOS_POR_CORREO = 5;
export const BLOQUEO_CORREO_MS = 15 * 60 * 1000;
/**
 * Cuánto se recuerda una racha de fallos de un correo. "Seguidas" no puede ser
 * "para siempre" (todo lleva TTL): una hora desde el primer fallo. Lo que de verdad
 * frena es el bloqueo; esto sólo decide cuándo se olvida una racha corta.
 */
const RACHA_CORREO_MS = 60 * 60 * 1000;

export const MAX_FALLOS_POR_IP = 20;
export const VENTANA_IP_MS = 15 * 60 * 1000;

const segundos = (ms: number): number => Math.max(1, Math.ceil(ms / 1000));

export function crearTopeDeIntentos(cache: Cache, ahoraMs: () => number) {
  const deCorreo = (email: string) => `auth:intentos:correo:${hashearToken(email)}`;
  const deIp = (ip: string) => `auth:intentos:ip:${hashearToken(ip)}`;

  /** Segundos que faltan de un bloqueo, o `null` si no hay. */
  async function restante(clave: string): Promise<number | null> {
    const valor = await cache.obtener(`${clave}:bloqueo`);
    if (valor === null) return null;
    const faltan = Number(valor) - ahoraMs();
    return Number.isFinite(faltan) && faltan > 0 ? segundos(faltan) : null;
  }

  /** Suma un fallo; si llega al tope, bloquea y devuelve los segundos del bloqueo. */
  async function sumar(clave: string, maximo: number, ventanaMs: number, bloqueoMs: number): Promise<number | null> {
    const n = await cache.incrementar(`${clave}:racha`, segundos(ventanaMs));
    if (n < maximo) return null;
    await cache.poner(`${clave}:bloqueo`, String(ahoraMs() + bloqueoMs), segundos(bloqueoMs));
    // La racha arranca de cero cuando termina el bloqueo, no con cuatro ya puestos.
    await cache.borrar(`${clave}:racha`);
    return segundos(bloqueoMs);
  }

  return {
    bloqueoDeCorreo: (email: string) => restante(deCorreo(email)),
    bloqueoDeIp: (ip: string) => restante(deIp(ip)),

    /**
     * Una contraseña equivocada. Con `email` cuenta para los dos topes; sin él
     * (un correo que no tiene cuenta) sólo para el de la IP.
     *
     * @returns los segundos de bloqueo si ESTE fallo bloqueó el correo.
     */
    async fallo(email: string | null, ip: string): Promise<number | null> {
      await sumar(deIp(ip), MAX_FALLOS_POR_IP, VENTANA_IP_MS, VENTANA_IP_MS);
      return email === null ? null : sumar(deCorreo(email), MAX_FALLOS_POR_CORREO, RACHA_CORREO_MS, BLOQUEO_CORREO_MS);
    },

    /** Entró bien, o cambió la contraseña: el correo vuelve a empezar de cero. */
    async reiniciar(email: string): Promise<void> {
      await cache.borrar(`${deCorreo(email)}:racha`);
      await cache.borrar(`${deCorreo(email)}:bloqueo`);
    },
  };
}

export type TopeDeIntentos = ReturnType<typeof crearTopeDeIntentos>;
