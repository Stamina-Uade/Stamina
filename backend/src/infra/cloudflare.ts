/**
 * infra/cloudflare.ts — a quién se le cree el X-Forwarded-For.
 *
 * stamina.com.ar pasa por Cloudflare y después por Apache (127.0.0.1) antes de
 * llegar al proceso. Apache agrega al X-Forwarded-For la IP que le habló, que es
 * un borde de Cloudflare; Cloudflare ya puso adelante la de la persona. Si sólo se
 * confía en 127.0.0.1 (`TRUST_PROXY=127.0.0.1`), `req.ip` termina siendo el borde
 * de Cloudflare: todas las personas que entran por el mismo nodo comparten el
 * rate limit, y los correos de acceso muestran una IP que no es la suya.
 *
 * Con una lista de proxies en `TRUST_PROXY`, se suman los rangos publicados de
 * Cloudflare: `req.ip` pasa a ser la IP de la persona. No abre nada: alguien que
 * le habla directo al servidor no viene de una IP de Cloudflare, así que Apache
 * anota su IP real y esa es la que queda, mande el X-Forwarded-For que mande.
 *
 * `TRUST_PROXY=true` (confiar en todos) y `false` quedan como están.
 *
 * Rangos de https://www.cloudflare.com/ips-v4/ y /ips-v6/ (2026-10-24). Cambian
 * muy de vez en cuando; si se agrega uno, va acá.
 */
export const RANGOS_DE_CLOUDFLARE: readonly string[] = [
  "173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22", "141.101.64.0/18",
  "108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22", "198.41.128.0/17",
  "162.158.0.0/15", "104.16.0.0/13", "104.24.0.0/14", "172.64.0.0/13", "131.0.72.0/22",
  "2400:cb00::/32", "2606:4700::/32", "2803:f800::/32", "2405:b500::/32", "2405:8100::/32",
  "2a06:98c0::/29", "2c0f:f248::/32",
];

/** Lo que va en `trustProxy` de Fastify. */
export function confianzaDeProxy(trustProxy: boolean | string): boolean | string[] {
  if (typeof trustProxy === "boolean") return trustProxy;
  const propios = trustProxy.split(",").map((x) => x.trim()).filter((x) => x !== "");
  return [...propios, ...RANGOS_DE_CLOUDFLARE];
}
