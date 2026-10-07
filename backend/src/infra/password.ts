/**
 * infra/password.ts — la política de contraseñas, en un solo lugar.
 *
 * Se hace cumplir EN EL SERVIDOR (AGENTS.md §14.1). Que el cliente además la
 * muestre es comodidad, nunca la regla.
 *
 * 🛑 Las tres reglas que el cliente MUESTRA —largo, mayúscula, número— están
 * primeras y en ese orden a propósito: `design/origen/Trainer App.dc.html`
 * (pantalla `fpNew`) dibuja tres puntitos y tres barras, y son estas tres. Si acá
 * se agrega una cuarta regla visible, la pantalla queda mintiendo.
 *
 * Las otras dos —lista de conocidas y repetición— NO se muestran, porque no se
 * pueden anticipar mientras alguien escribe: la lista vive acá y "repetitiva" es
 * una propiedad del resultado, no un objetivo que alguien persiga. Se explican
 * cuando se rechaza, no antes.
 *
 * Sobre exigir mayúscula y número: NIST SP 800-63B recomienda NO pedirlo, porque
 * en la práctica produce `Password1!` en vez de una frase larga. Acá se piden
 * igual porque es una decisión tomada por Iván el 2026-09-09, con el mínimo
 * subido a 10 (el diseño decía 8) para no perder el largo, que es lo que de
 * verdad importa. Queda escrito para que dentro de un año se sepa que no fue un
 * descuido.
 */

/**
 * Las que se rechazan aunque cumplan todo lo demás: tienen largo, mayúscula y
 * número, y aun así son de las primeras que alguien probaría. Es una lista corta
 * y deliberada.
 * No pretende ser una lista completa de 100k — eso es un archivo de datos y va
 * a la fase de endurecimiento (§12).
 */
const CONOCIDAS = new Set([
  // 🛑 Todas EN MINÚSCULA: la comparación se hace sobre `claro.toLowerCase()`.
  // Una entrada con mayúsculas acá no se compara nunca con nada y es una regla
  // apagada que parece prendida.
  "password123",
  "password1234",
  "contrasena123",
  "contraseña123",
  "trainer2026",
  "trainer1234",
  "iloveyou123",
  "qwerty12345",
  "letmein1234",
  "admin123456",
  "welcome1234",
  "abcd1234567",
]);

export type MotivoPassword = "corta" | "larga" | "sin_mayuscula" | "sin_numero" | "conocida" | "repetitiva";
export type ResultadoPassword = { ok: true } | { ok: false; motivo: MotivoPassword };

export const LARGO_MINIMO = 10;
export const LARGO_MAXIMO = 200;

/**
 * Mayúsculas con acento y la Ñ cuentan. Un `[A-Z]` pelado le diría a alguien que
 * escribió `Ángela...` que le falta una mayúscula, que es exactamente el tipo de
 * error que hace que la gente termine poniendo `Password1`.
 */
const MAYUSCULA = /\p{Lu}/u;
const NUMERO = /\p{Nd}/u;

/** Cuántos caracteres distintos hace falta que tenga. `aaaaaaaaaa` no es una contraseña. */
const DISTINTOS_MINIMO = 4;

export function validarPassword(claro: string): ResultadoPassword {
  if (claro.length < LARGO_MINIMO) return { ok: false, motivo: "corta" };
  // El tope no es capricho: argon2 sobre una entrada gigante es CPU regalada, y
  // en una máquina compartida eso es una denegación de servicio barata (§12).
  if (claro.length > LARGO_MAXIMO) return { ok: false, motivo: "larga" };

  if (!MAYUSCULA.test(claro)) return { ok: false, motivo: "sin_mayuscula" };
  if (!NUMERO.test(claro)) return { ok: false, motivo: "sin_numero" };

  const normal = claro.toLowerCase().trim();
  if (CONOCIDAS.has(normal)) return { ok: false, motivo: "conocida" };

  // "Aaaaaaaaa1" tiene largo, mayúscula y número, y ninguna entropía.
  if (new Set(normal).size < DISTINTOS_MINIMO) return { ok: false, motivo: "repetitiva" };

  return { ok: true };
}
