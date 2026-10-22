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
  // Contrato 1.6.0 ("Entrar y registrarse", decisión de Iván del 2026-10-22).
  // `too_many_attempts` es el tope POR CORREO (5 contraseñas equivocadas seguidas);
  // el tope por IP sigue siendo `rate_limited`. Son dos porque la app dice cosas
  // distintas: "esta cuenta está bloqueada un rato" no es "estás yendo muy rápido".
  too_many_attempts: 429,
  // Un código de correo agotado (5 equivocados) no es uno vencido (15 minutos): la
  // app explica cada uno a su manera, aunque la salida sea la misma, pedir otro.
  code_attempts_exceeded: 400,
  account_link_available: 409,
  invalid_link_token: 401,
  account_deactivated: 403,
  account_pending_deletion: 403,
  invalid_reactivation_token: 401,
} as const;

export type CodigoError = keyof typeof CODIGOS;

/**
 * `DatosDelError` del contrato (1.6.0): lo que algunos códigos necesitan además
 * del `code` para que la app pueda seguir. Sólo viaja lo que corresponde a ese
 * código, y sólo a quien ya demostró ser la persona.
 */
export interface DatosDelError {
  provider?: "google" | "apple";
  email?: string;
  link_token?: string;
  requires_password?: boolean;
  reactivation_token?: string;
  days_remaining?: number;
}

/**
 * El único error que las rutas tiran. `mensaje` es para el desarrollador y como
 * respaldo: NUNCA lleva datos de salud, de ubicación ni de identidad
 * (AGENTS.md §8), y el cliente muestra su propia traducción del `codigo`.
 */
export class ErrorApi extends Error {
  readonly codigo: CodigoError;
  readonly http: number;
  /** Segundos hasta poder reintentar: sale en `Retry-After`. Para los 429. */
  readonly reintentarEnS?: number;
  /** Sale en `error.details`. */
  readonly detalles?: DatosDelError;

  constructor(codigo: CodigoError, mensaje: string, reintentarEnS?: number, detalles?: DatosDelError) {
    super(mensaje);
    this.name = "ErrorApi";
    this.codigo = codigo;
    this.http = CODIGOS[codigo];
    if (reintentarEnS !== undefined) this.reintentarEnS = reintentarEnS;
    if (detalles !== undefined) this.detalles = detalles;
  }
}

export interface CuerpoError {
  error: { code: CodigoError; message: string; details?: DatosDelError };
}

export function aCuerpo(e: ErrorApi): CuerpoError {
  // Sin `details` cuando no hay: el sobre de siempre, igual que antes de la 1.6.0.
  return e.detalles === undefined
    ? { error: { code: e.codigo, message: e.message } }
    : { error: { code: e.codigo, message: e.message, details: e.detalles } };
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
