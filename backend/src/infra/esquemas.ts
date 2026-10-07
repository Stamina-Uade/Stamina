/**
 * infra/esquemas.ts — el puente entre el contrato y la validación de Fastify.
 *
 * AGENTS.md §4.2 y §14.1: la validación del servidor SALE DEL CONTRATO. El módulo
 * que se importa acá lo genera `scripts/generar-esquemas.mjs` desde
 * shared/api/openapi.yaml, y NO se commitea: si el contrato cambia y nadie
 * regenera, el build falla en vez de servir un esquema viejo.
 */
import { ESQUEMAS } from "../generado/esquemas.js";

export function versionContrato(): string | null {
  return (ESQUEMAS as { _version_contrato: string | null })._version_contrato;
}

/**
 * El esquema del cuerpo de una operación, listo para Fastify.
 *
 * Los `$defs` se cuelgan de cada esquema porque los `$ref` apuntan a `#/$defs/X`,
 * y Ajv resuelve `#` contra la raíz del esquema que se le pasa.
 */
export function cuerpo(operationId: string): object {
  const cuerpos = (ESQUEMAS as { cuerpos: Record<string, object | undefined> }).cuerpos;
  const esquema = cuerpos[operationId];
  if (esquema === undefined) {
    throw new Error(`esquemas: no hay cuerpo para la operación "${operationId}" en el contrato`);
  }
  return { ...esquema, $defs: (ESQUEMAS as { $defs: object }).$defs };
}

/**
 * Los parámetros de ruta y de query de una operación, listos para Fastify:
 * `{ params, querystring }`. Salen del contrato igual que los cuerpos.
 */
export function parametros(operationId: string): { params?: object; querystring?: object } {
  const todos = (ESQUEMAS as unknown as {
    parametros: Record<string, { path?: object; query?: object } | undefined>;
  }).parametros;
  const p = todos[operationId];
  if (p === undefined) {
    throw new Error(`esquemas: la operación "${operationId}" no declara parámetros en el contrato`);
  }
  const $defs = (ESQUEMAS as { $defs: object }).$defs;
  const salida: { params?: object; querystring?: object } = {};
  if (p.path !== undefined) salida.params = { ...p.path, $defs };
  if (p.query !== undefined) salida.querystring = { ...p.query, $defs };
  return salida;
}
