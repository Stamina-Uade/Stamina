/**
 * infra/errores.ts — el envelope de error y los códigos estables.
 *
 * docs/API.md §2: el `code` es CONTRATO, igual que el status HTTP. Los clientes lo
 * mapean a su texto traducido. Cambiar uno publicado es cambiar la API.
 *
 * Por eso la lista vive acá, en un solo lugar, como un tipo: agregar un código es
 * aditivo, y borrar o renombrar uno rompe la compilación de todo lo que lo usa.
 */

export const CODIGOS = {
  // genéricos
  bad_request: 400,
  unauthorized: 401,
  forbidden: 403,
  not_found: 404,
  conflict: 409,
  payload_too_large: 413,
  rate_limited: 429,
  internal: 500,
  service_unavailable: 503,
  unsupported_client: 426,
  // auth y cuenta
  invalid_credentials: 401,
  invalid_code: 400,
  code_expired: 400,
  code_resend_too_soon: 429,
  weak_password: 400,
  invalid_registration_token: 401,
  invalid_reset_token: 401,
  invalid_refresh_token: 401,
  session_revoked: 401,
  profile_incomplete: 400,
  // El aviso de salud. Son DOS codigos y no uno porque la app hace cosas
  // distintas: con `legal_not_accepted` vuelve a la pantalla; con
  // `legal_version_stale` tiene que BAJAR el texto nuevo antes de mostrarlo, o
  // le va a pedir que acepte otra vez el mismo texto viejo.
  legal_not_accepted: 400,
  legal_version_stale: 409,
  // Continuar con Google / Apple (contrato 1.4.0).
  // 2026-10-21 (decisión de Iván): el login, el alta y la recuperación dicen
  // QUÉ pasó en vez de un error genérico. Es a sabiendas: deja saber si un correo
  // tiene cuenta. Lo frena el rate limit estricto de esas rutas (8/min por IP).
  user_not_found: 404,
  wrong_password: 401,
  password_not_set: 409,
  email_already_registered: 409,
  invalid_provider_token: 401,
  provider_not_configured: 503,
  invalid_signup_token: 401,
} as const;

export type CodigoError = keyof typeof CODIGOS;

/**
 * El único error que las rutas tiran. `mensaje` es para el desarrollador y como
 * respaldo: NUNCA lleva datos de salud, de ubicación ni de identidad
 * (AGENTS.md §8), y el cliente muestra su propia traducción del `codigo`.
 */
export class ErrorApi extends Error {
  readonly codigo: CodigoError;
  readonly http: number;
  /** Segundos hasta poder reintentar. Sólo para rate_limited. */
  readonly reintentarEnS?: number;

  constructor(codigo: CodigoError, mensaje: string, reintentarEnS?: number) {
    super(mensaje);
    this.name = "ErrorApi";
    this.codigo = codigo;
    this.http = CODIGOS[codigo];
    if (reintentarEnS !== undefined) this.reintentarEnS = reintentarEnS;
  }
}

export interface CuerpoError {
  error: { code: CodigoError; message: string };
}

export function aCuerpo(e: ErrorApi): CuerpoError {
  return { error: { code: e.codigo, message: e.message } };
}

/**
 * Lo que se le devuelve a un error que NO es un ErrorApi.
 *
 * En producción el detalle no sale nunca: un stack trace en una respuesta cuenta
 * versiones de librerías, rutas del disco y, a veces, datos. En desarrollo sí, que
 * para eso es desarrollo.
 */
export function errorInterno(e: unknown, esProduccion: boolean): CuerpoError {
  const detalle = e instanceof Error ? e.message : String(e);
  return {
    error: {
      code: "internal",
      message: esProduccion ? "Internal error" : `Internal error: ${detalle}`,
    },
  };
}
