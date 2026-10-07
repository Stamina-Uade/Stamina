/**
 * infra/log.ts — configuración del logger.
 *
 * 🛑 AGENTS.md §8 y §12.1: NADA de datos de salud, de ubicación ni de identidad en
 * los logs. Ni el peso, ni las comidas, ni las coordenadas, ni el correo, ni un
 * token. "Un log con el peso de una persona es una filtración esperando."
 *
 * La lista de abajo no es una recomendación: es lo que pino borra antes de
 * escribir. Y como Fastify loguea el request entero por defecto, hay que ser
 * explícito con lo que se serializa.
 */
import type { Entorno } from "../config.js";

/** Rutas que pino reemplaza por [redactado] antes de escribir la línea. */
export const RUTAS_CENSURADAS = [
  // credenciales y tokens, en cualquier lugar donde aparezcan
  "req.headers.authorization",
  "req.headers.cookie",
  "*.password",
  "*.refresh_token",
  "*.access_token",
  "*.registration_token",
  "*.reset_token",
  "*.code",
  "*.jwt_secret",
  // identidad
  "*.email",
  "*.first_name",
  "*.last_name",
  // datos de salud (§8). Van acá desde ahora, aunque los endpoints que los
  // manejan sean de la fase 7: el día que existan, el log ya está tapado.
  "*.weight_g",
  "*.height_mm",
  "*.birthdate_ms",
  "*.biological_sex",
  "*.heart_rate",
  "*.latitude",
  "*.longitude",
  "*.profile",
  // Lo que agregó el motor (2026-09-10): embarazo, lo que se come, lo que se
  // levanta y el pulso de una salida. Mismo criterio que arriba.
  "*.pregnant_or_breastfeeding",
  "*.equipment",
  "*.kcal",
  "*.carbs_g",
  "*.protein_g",
  "*.fat_g",
  "*.reps",
  "*.avg_hr_bpm",
  "*.max_hr_bpm",
  "*.sets",
  "*.meals",
];

/**
 * Devuelve lo que Fastify espera en `logger`.
 *
 * - production y staging -> JSON plano, que es lo que journald y Grafana leen
 * - development          -> pino-pretty, legible en la terminal
 * - test                 -> `false`, o sea SIN logger: un test que escupe cien
 *                           líneas de log por caso es un test que nadie lee
 */
export function opcionesLogger(nivel: string, entorno: Entorno) {
  if (entorno === "test") return false;
  return {
    level: nivel,
    redact: { paths: RUTAS_CENSURADAS, censor: "[redactado]" },
    // El request completo NO se loguea. Sólo lo que sirve para depurar sin contar
    // nada de la persona: método, ruta sin querystring, y el id de la request.
    serializers: {
      req(req: { method: string; url: string; id: string }) {
        const sinQuery = req.url.split("?")[0];
        return { id: req.id, method: req.method, path: sinQuery };
      },
      res(res: { statusCode: number }) {
        return { statusCode: res.statusCode };
      },
    },
    transport:
      entorno === "development" ? { target: "pino-pretty", options: { colorize: true } } : undefined,
  };
}
