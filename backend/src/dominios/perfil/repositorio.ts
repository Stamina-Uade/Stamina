/**
 * dominios/perfil/repositorio.ts
 *
 * 🛑 AGENTS.md §12 (IDOR): TODA lectura y TODA escritura filtran por dueño EN LA
 * MISMA QUERY. No hay ninguna función acá que reciba un id de perfil: sólo reciben
 * el id del usuario autenticado. No existe la forma de pedir el perfil de otro.
 *
 * §8: acá viven peso, altura, sexo biológico, nacimiento y —desde la 1.1.0—
 * embarazo o lactancia. Nada de esto va a un log (ver infra/log.ts) ni sale en un
 * mensaje de error.
 */
import type { Db } from "../../infra/db.js";

export interface PerfilFila {
  usuario_id: string;
  email: string;
  nombre: string | null;
  apellido: string | null;
  nacimiento_ms: number | null;
  sexo_biologico: string | null;
  peso_g: number | null;
  altura_mm: number | null;
  deporte: string | null;
  nivel: string | null;
  objetivo: string | null;
  objetivo_fecha_ms: number | null;
  dias_entrenamiento: unknown;
  zona_horaria: string | null;
  sistema_unidades: string | null;
  descargo_medico_aceptado_en_ms: number | null;
  equipamiento: unknown;
  embarazo_o_lactancia: boolean | null;
  creado_en_ms: number;
  actualizado_en_ms: number;
}

/** Del nombre en la API (snake_case, contrato) a la columna. */
const CAMPOS: ReadonlyArray<readonly [string, string]> = [
  ["first_name", "nombre"],
  ["last_name", "apellido"],
  ["birthdate_ms", "nacimiento_ms"],
  ["biological_sex", "sexo_biologico"],
  ["weight_g", "peso_g"],
  ["height_mm", "altura_mm"],
  ["sport", "deporte"],
  ["level", "nivel"],
  ["goal", "objetivo"],
  ["goal_date_ms", "objetivo_fecha_ms"],
  ["training_days", "dias_entrenamiento"],
  ["timezone", "zona_horaria"],
  ["unit_system", "sistema_unidades"],
  ["equipment", "equipamiento"],
  ["pregnant_or_breastfeeding", "embarazo_o_lactancia"],
];

/** Las columnas jsonb: se serializan antes de viajar. */
const JSONB = new Set(["dias_entrenamiento", "equipamiento"]);

export function crearRepoPerfil(db: Db) {
  return {
    async leer(usuarioId: string): Promise<PerfilFila | null> {
      return db.unaFila<PerfilFila>(
        `select u.id as usuario_id,
                u.email,
                u.creado_en_ms,
                p.nombre, p.apellido, p.nacimiento_ms, p.sexo_biologico,
                p.peso_g, p.altura_mm, p.deporte, p.nivel, p.objetivo,
                p.objetivo_fecha_ms, p.dias_entrenamiento, p.zona_horaria,
                p.sistema_unidades, p.descargo_medico_aceptado_en_ms,
                p.equipamiento, p.embarazo_o_lactancia,
                coalesce(p.actualizado_en_ms, u.actualizado_en_ms) as actualizado_en_ms
           from usuarios u
           left join perfiles p on p.usuario_id = u.id
          -- filtro por dueño en la misma query; borrar cuenta hace DELETE físico
          where u.id = $1`,
        [usuarioId]
      );
    },

    /**
     * Upsert parcial. Sólo toca las claves presentes: `PATCH /me` manda lo que
     * cambia y nada más.
     *
     * Las columnas salen de la lista blanca `CAMPOS` de arriba, nunca del cuerpo
     * del pedido: un identificador dinámico que venga del cliente es inyección
     * aunque los valores estén parametrizados (AGENTS.md §12).
     */
    async guardar(usuarioId: string, entrada: Record<string, unknown>, ahoraMs: number): Promise<void> {
      const columnas: string[] = [];
      const valores: unknown[] = [];

      for (const [api, columna] of CAMPOS) {
        if (!Object.prototype.hasOwnProperty.call(entrada, api)) continue;
        const v = entrada[api];
        columnas.push(columna);
        if (columna === "dias_entrenamiento") valores.push(JSON.stringify(v ?? []));
        else if (JSONB.has(columna)) valores.push(v === null || v === undefined ? null : JSON.stringify(v));
        else valores.push(v);
      }

      if (entrada["medical_disclaimer_accepted"] === true) {
        columnas.push("descargo_medico_aceptado_en_ms");
        valores.push(ahoraMs);
      }

      if (columnas.length === 0) {
        await db.consultar(
          `insert into perfiles (usuario_id, actualizado_en_ms) values ($1, $2)
           on conflict (usuario_id) do update set actualizado_en_ms = excluded.actualizado_en_ms`,
          [usuarioId, ahoraMs]
        );
        return;
      }

      const placeholders = columnas.map((_, i) => `$${i + 3}`);
      const asignaciones = columnas.map((c, i) => `${c} = $${i + 3}`).join(", ");

      await db.consultar(
        `insert into perfiles (usuario_id, actualizado_en_ms, ${columnas.join(", ")})
              values ($1, $2, ${placeholders.join(", ")})
         on conflict (usuario_id) do update
            set actualizado_en_ms = excluded.actualizado_en_ms, ${asignaciones}`,
        [usuarioId, ahoraMs, ...valores]
      );
    },
  };
}

export type RepoPerfil = ReturnType<typeof crearRepoPerfil>;
