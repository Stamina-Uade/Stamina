/**
 * dominios/auth/repositorio.ts — TODO el SQL de auth, en un solo lugar.
 *
 * AGENTS.md §4.4: los repositorios no devuelven objetos HTTP y los controllers no
 * hacen SQL.
 * §12: SQL siempre parametrizado. Las cuentas se borran físicamente en cascada.
 */
import type { Db } from "../../infra/db.js";

export interface UsuarioFila {
  id: string;
  email: string;
  /** `null` en una cuenta que nació con Google o Apple y nunca eligió contraseña. */
  password_hash: string | null;
  creado_en_ms: number;
  actualizado_en_ms: number;
}

export interface SesionFila {
  id: string;
  usuario_id: string;
  familia_id: string;
  vence_en_ms: number;
  usado_en_ms: number | null;
  revocado_en_ms: number | null;
}

/** La sesión que salió de rotar otra, con el hash para confirmar que es la que espera el reintento. */
export interface SucesoraFila extends SesionFila {
  refresh_hash: string;
}

export function crearRepo(db: Db) {
  return {
    // ----------------------------------------------------------- usuarios --
    async buscarUsuarioPorEmail(email: string): Promise<UsuarioFila | null> {
      return db.unaFila<UsuarioFila>(
        `select id, email, password_hash, creado_en_ms, actualizado_en_ms
           from usuarios
          where email = $1`,
        [email]
      );
    },

    async crearUsuario(email: string, passwordHash: string | null, ahoraMs: number): Promise<UsuarioFila> {
      const fila = await db.unaFila<UsuarioFila>(
        `insert into usuarios (email, password_hash, creado_en_ms, actualizado_en_ms)
              values ($1, $2, $3, $3)
           returning id, email, password_hash, creado_en_ms, actualizado_en_ms`,
        [email, passwordHash, ahoraMs]
      );
      if (fila === null) throw new Error("crearUsuario: insert sin filas");
      return fila;
    },

    // ------------------------------------------------ identidades sociales --
    async buscarUsuarioPorIdentidad(proveedor: string, sujeto: string): Promise<UsuarioFila | null> {
      return db.unaFila<UsuarioFila>(
        `select u.id, u.email, u.password_hash, u.creado_en_ms, u.actualizado_en_ms
           from identidades_sociales i
           join usuarios u on u.id = i.usuario_id
          where i.proveedor = $1 and i.sujeto = $2`,
        [proveedor, sujeto]
      );
    },

    /**
     * Vincula una identidad de Google o Apple a una cuenta. Si esa identidad ya
     * estaba vinculada (dos pedidos a la vez), no hace nada: gana el índice único.
     */
    /** `true` si la vinculó; `false` si esa identidad ya estaba vinculada (a ésta u otra cuenta). */
    async vincularIdentidad(
      usuarioId: string, proveedor: string, sujeto: string, email: string | null, ahoraMs: number
    ): Promise<boolean> {
      const fila = await db.unaFila<{ id: string }>(
        `insert into identidades_sociales (usuario_id, proveedor, sujeto, email, creado_en_ms)
              values ($1, $2, $3, $4, $5)
         on conflict (proveedor, sujeto) do nothing
         returning id`,
        [usuarioId, proveedor, sujeto, email, ahoraMs]
      );
      return fila !== null;
    },

    /** Si la cuenta ya tiene una identidad de ese proveedor (otra persona de Google, por ejemplo). */
    async tieneIdentidadDe(usuarioId: string, proveedor: string): Promise<boolean> {
      const fila = await db.unaFila<{ uno: number }>(
        `select 1 as uno from identidades_sociales where usuario_id = $1 and proveedor = $2`,
        [usuarioId, proveedor]
      );
      return fila !== null;
    },

    async cambiarPassword(usuarioId: string, passwordHash: string, ahoraMs: number): Promise<void> {
      await db.consultar(
        `update usuarios set password_hash = $2, actualizado_en_ms = $3
          where id = $1`,
        [usuarioId, passwordHash, ahoraMs]
      );
    },

    // ------------------------------------------------------------ sesiones --
    async crearSesion(
      usuarioId: string,
      familiaId: string | null,
      refreshHash: string,
      ahoraMs: number,
      vidaMs: number,
      /** La sesión que se rotó para abrir ésta; `null` en un login, un alta o una recuperación. */
      anteriorId: string | null = null
    ): Promise<SesionFila> {
      const fila = await db.unaFila<SesionFila>(
        `insert into sesiones (usuario_id, familia_id, refresh_hash, creado_en_ms, vence_en_ms, anterior_id)
              values ($1, coalesce($2::uuid, gen_random_uuid()), $3, $4, $5, $6)
           returning id, usuario_id, familia_id, vence_en_ms, usado_en_ms, revocado_en_ms`,
        [usuarioId, familiaId, refreshHash, ahoraMs, ahoraMs + vidaMs, anteriorId]
      );
      if (fila === null) throw new Error("crearSesion: insert sin filas");
      return fila;
    },

    /**
     * @param bloquear `for update`: el canje de un refresh la lee adentro de una transacción,
     *   para que dos canjes simultáneos del mismo token pasen de a uno (decisión 0013).
     */
    async buscarSesionPorRefresh(refreshHash: string, bloquear = false): Promise<SesionFila | null> {
      return db.unaFila<SesionFila>(
        bloquear
          ? `select id, usuario_id, familia_id, vence_en_ms, usado_en_ms, revocado_en_ms
               from sesiones where refresh_hash = $1 for update`
          : `select id, usuario_id, familia_id, vence_en_ms, usado_en_ms, revocado_en_ms
               from sesiones where refresh_hash = $1`,
        [refreshHash]
      );
    },

    /** La sesión que salió de rotar `sesionId`, bloqueada: se lee para decidir un reintento. */
    async sucesoraDe(sesionId: string): Promise<SucesoraFila | null> {
      return db.unaFila<SucesoraFila>(
        `select id, usuario_id, familia_id, vence_en_ms, usado_en_ms, revocado_en_ms, refresh_hash
           from sesiones where anterior_id = $1 for update`,
        [sesionId]
      );
    },

    async marcarUsada(sesionId: string, ahoraMs: number): Promise<void> {
      await db.consultar(`update sesiones set usado_en_ms = $2 where id = $1`, [sesionId, ahoraMs]);
    },

    /** Revoca la familia entera: la señal de que un refresh se reusó. */
    async revocarFamilia(familiaId: string, ahoraMs: number, motivo: string): Promise<void> {
      await db.consultar(
        `update sesiones set revocado_en_ms = $2, revocado_motivo = $3
          where familia_id = $1 and revocado_en_ms is null`,
        [familiaId, ahoraMs, motivo]
      );
    },

    /**
     * Revoca la familia de una sesión: todo lo que salió de un mismo login. Rotar no revoca
     * (decisión 0013), así que los access de las rotaciones anteriores siguen vivos hasta que
     * vencen; un logout que revocara sólo la fila actual los dejaría andando hasta quince minutos.
     */
    async revocarFamiliaDeSesion(sesionId: string, ahoraMs: number, motivo: string): Promise<void> {
      await db.consultar(
        `update sesiones set revocado_en_ms = $2, revocado_motivo = $3
          where familia_id = (select familia_id from sesiones where id = $1)
            and revocado_en_ms is null`,
        [sesionId, ahoraMs, motivo]
      );
    },

    /** Cambiar la contraseña revoca las demás sesiones (AGENTS.md §12). */
    async revocarTodasDe(usuarioId: string, ahoraMs: number, motivo: string, exceptoSesionId?: string): Promise<void> {
      await db.consultar(
        `update sesiones set revocado_en_ms = $2, revocado_motivo = $3
          where usuario_id = $1 and revocado_en_ms is null
            and ($4::uuid is null or id <> $4::uuid)`,
        [usuarioId, ahoraMs, motivo, exceptoSesionId ?? null]
      );
    },

    async sesionVigente(sesionId: string, ahoraMs: number): Promise<boolean> {
      const fila = await db.unaFila<{ uno: number }>(
        `select 1 as uno from sesiones
          where id = $1 and revocado_en_ms is null and vence_en_ms > $2`,
        [sesionId, ahoraMs]
      );
      return fila !== null;
    },
    /**
     * Deja constancia de que alguien aceptó el aviso de salud y los términos.
     *
     * 🛑 `aceptado_en_ms` es la hora del SERVIDOR. La del teléfono la mueve
     * cualquiera, y una constancia fechada por la otra parte no es una constancia.
     */
    async guardarAceptacionLegal(
      usuarioId: string,
      version: string,
      ahoraMs: number,
      motivo = "registro",
    ): Promise<void> {
      await db.consultar(
        `insert into aceptaciones_legales (usuario_id, version, aceptado_en_ms, motivo, creado_en_ms)
         values ($1, $2, $3, $4, $3)`,
        [usuarioId, version, ahoraMs, motivo],
      );
    },

  };
}

export type RepoAuth = ReturnType<typeof crearRepo>;
