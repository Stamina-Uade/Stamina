/**
 * dominios/cuenta/repositorio.ts — borrar la cuenta y juntar todo para exportar.
 *
 * 🛑 AGENTS.md §12: cada consulta filtra por `usuario_id` en el mismo SQL. Acá eso
 * pesa más que en ningún otro lado: un export sin ese filtro es una filtración
 * masiva con formato prolijo.
 */
import type { Db } from "../../infra/db.js";
import type { SerieFila, SesionFila } from "../gimnasio/repositorio.js";
import type { ActividadFila } from "../actividades/repositorio.js";
import type { ComidaFila } from "../nutricion/repositorio.js";

export function crearRepoCuenta(db: Db) {
  return {
    /**
     * `undefined` = la cuenta no existe; `null` = existe y no tiene contraseña
     * (nació con Google o Apple).
     */
    async hashDePassword(usuarioId: string): Promise<string | null | undefined> {
      const f = await db.unaFila<{ password_hash: string | null }>(
        `select password_hash from usuarios where id = $1`,
        [usuarioId]
      );
      return f === null ? undefined : f.password_hash;
    },

    /** Borra la cuenta y sus datos dependientes en una sola transacción de PostgreSQL. */
    async borrar(usuarioId: string, _ahoraMs: number): Promise<void> {
      await db.consultar(`delete from usuarios where id = $1`, [usuarioId]);
    },

    async aceptacionesLegales(usuarioId: string) {
      return db.consultar<{ version: string; aceptado_en_ms: number; motivo: string }>(
        `select version, aceptado_en_ms, motivo from aceptaciones_legales
          where usuario_id = $1 order by aceptado_en_ms`,
        [usuarioId]
      );
    },

    async planes(usuarioId: string) {
      return db.consultar<{
        objetivo_id: string | null;
        motor_version: string;
        inicio_fecha: string;
        zona_horaria: string;
        creado_en_ms: number;
        reemplazado_en_ms: number | null;
      }>(
        `select objetivo_id, motor_version, inicio_fecha, zona_horaria, creado_en_ms, reemplazado_en_ms
           from planes where usuario_id = $1
         order by creado_en_ms`,
        [usuarioId]
      );
    },

    async objetivos(usuarioId: string) {
      return db.consultar<{
        id: string; objetivo: string; objetivo_fecha_ms: number | null;
        orden: number; creado_en_ms: number; completado_en_ms: number | null;
      }>(
        `select id, objetivo, objetivo_fecha_ms, orden, creado_en_ms, completado_en_ms
           from objetivos_usuario where usuario_id = $1 order by creado_en_ms`,
        [usuarioId]
      );
    },

    async sesionesDeGimnasio(usuarioId: string): Promise<SesionFila[]> {
      return db.consultar<SesionFila>(
        `select sesion_id, fecha, creada_en_ms, actualizada_en_ms
           from sesiones_gimnasio where usuario_id = $1 order by creada_en_ms`,
        [usuarioId]
      );
    },

    async seriesDeGimnasio(usuarioId: string): Promise<Array<SerieFila & { sesion_id: string }>> {
      return db.consultar<SerieFila & { sesion_id: string }>(
        `select sesion_id, ejercicio_id, numero, hecha, repeticiones, peso_g, salteada, es_extra,
                registrada_local_ms, recibida_en_servidor_ms, dispositivo
           from series_gimnasio where usuario_id = $1
          order by sesion_id, ejercicio_id, numero`,
        [usuarioId]
      );
    },

    async actividades(usuarioId: string): Promise<ActividadFila[]> {
      return db.consultar<ActividadFila>(
        `select id, deporte, inicio_ms, duracion_s, distancia_m, desnivel_m, fc_media_lpm, fc_max_lpm,
                kcal, dispositivo, creada_en_ms, actualizada_en_ms
           from actividades where usuario_id = $1 and borrada_en_ms is null order by inicio_ms`,
        [usuarioId]
      );
    },

    async comidas(usuarioId: string): Promise<ComidaFila[]> {
      return db.consultar<ComidaFila>(
        `select id, comida_en_ms, nombre, kcal, carbohidratos_g, proteina_g, grasa_g, creada_en_ms, actualizada_en_ms
           from comidas where usuario_id = $1 and borrada_en_ms is null order by comida_en_ms`,
        [usuarioId]
      );
    },
  };
}
