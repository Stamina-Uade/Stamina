/**
 * infra/ubicacion.ts — "Ciudad, País" para los correos de acceso ("Nuevo inicio de
 * sesión" y "Cuenta conectada con Google/Apple").
 *
 * stamina.com.ar pasa por Cloudflare, que ya sabe de dónde viene cada pedido y lo
 * agrega en headers: `cf-ipcountry` (prendido por default) y `cf-ipcity` /
 * `cf-region` (la regla administrada "Add visitor location headers", gratis en
 * todos los planes). Así no hace falta una base de GeoIP en el servidor ni mandar
 * la IP de nadie a un tercero.
 *
 * 🛑 Sólo se leen detrás de un proxy de confianza (`TRUST_PROXY`): si el servidor
 * queda expuesto sin proxy, cualquiera los inventa. Lo peor que pasa si alguien
 * llega igual al origen con headers falsos es una ubicación mentirosa en un correo
 * informativo, que es lo mismo que puede hacer con un VPN.
 *
 * Lo que no se sabe no se pone: sin ningún dato, null y el correo no lleva la fila.
 */
import type { IncomingHttpHeaders } from "node:http";
import type { IdiomaDeCorreo } from "./idioma.js";

/** Cloudflare: XX = sin datos, T1 = Tor. */
const PAISES_SIN_DATO = new Set(["XX", "T1"]);
const TOPE = 80;

function header(headers: IncomingHttpHeaders, nombre: string): string | null {
  const crudo = headers[nombre];
  const valor = (Array.isArray(crudo) ? crudo[0] : crudo)?.trim();
  if (valor === undefined || valor === "") return null;
  let texto = valor;
  if (texto.includes("%")) {
    try { texto = decodeURIComponent(texto); } catch { /* queda como vino */ }
  }
  // Sin caracteres de control y con un tope: va dentro de un correo.
  texto = texto.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, TOPE);
  return texto === "" ? null : texto;
}

/** "AR" → "Argentina" (o "Argentine" en francés). Un código raro queda como vino. */
export function nombreDePais(codigo: string, idioma: IdiomaDeCorreo): string {
  const c = codigo.toUpperCase();
  if (!/^[A-Z]{2}$/.test(c)) return codigo;
  try {
    return new Intl.DisplayNames([idioma], { type: "region" }).of(c) ?? c;
  } catch {
    return c;
  }
}

/**
 * "Buenos Aires, Argentina"; sin ciudad, "Córdoba, Argentina" con la provincia;
 * sólo el país si es lo único que hay; null si no hay nada o no hay proxy.
 */
export function ubicacionDeCloudflare(
  headers: IncomingHttpHeaders,
  idioma: IdiomaDeCorreo,
  detrasDeProxy: boolean
): string | null {
  if (!detrasDeProxy) return null;
  const codigo = header(headers, "cf-ipcountry");
  const pais = codigo !== null && !PAISES_SIN_DATO.has(codigo.toUpperCase()) ? nombreDePais(codigo, idioma) : null;
  const lugar = header(headers, "cf-ipcity") ?? header(headers, "cf-region");
  const partes = [lugar, pais].filter((x): x is string => x !== null);
  // "Singapur, Singapur" no: si la ciudad y el país se llaman igual, va una vez.
  const unicas = partes.filter((p, i) => partes.findIndex((q) => q.toLowerCase() === p.toLowerCase()) === i);
  return unicas.length === 0 ? null : unicas.join(", ");
}
