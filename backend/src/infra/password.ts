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
 * Son las ÚNICAS desde el contrato 1.6.0 (decisión de Iván del 2026-10-22).
 * Antes había dos reglas más que no se mostraban —una lista de contraseñas
 * conocidas y "repetitiva" (menos de cuatro caracteres distintos)— y rechazaban
 * con `weak_password` algo que cumplía las tres barras de la pantalla: la persona
 * veía todo en verde y el servidor le decía que no, sin poder explicarle por qué.
 * Ahora `weak_password` quiere decir sólo que falla una de las tres (o que pasa el
 * tope). Lo que protege de verdad contra adivinar es el tope de intentos por
 * correo del login (dominios/auth/intentos.ts), no una lista de doce palabras.
 *
 * Sobre exigir mayúscula y número: NIST SP 800-63B recomienda NO pedirlo, porque
 * en la práctica produce `Password1!` en vez de una frase larga. Acá se piden
 * igual porque es una decisión tomada por Iván el 2026-09-09, con el mínimo
 * subido a 10 (el diseño decía 8) para no perder el largo, que es lo que de
 * verdad importa. Queda escrito para que dentro de un año se sepa que no fue un
 * descuido.
 */

export type MotivoPassword = "corta" | "larga" | "sin_mayuscula" | "sin_numero";
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

export function validarPassword(claro: string): ResultadoPassword {
  if (claro.length < LARGO_MINIMO) return { ok: false, motivo: "corta" };
  // El tope no es capricho: argon2 sobre una entrada gigante es CPU regalada, y
  // en una máquina compartida eso es una denegación de servicio barata (§12).
  if (claro.length > LARGO_MAXIMO) return { ok: false, motivo: "larga" };

  if (!MAYUSCULA.test(claro)) return { ok: false, motivo: "sin_mayuscula" };
  if (!NUMERO.test(claro)) return { ok: false, motivo: "sin_numero" };

  return { ok: true };
}
