/**
 * dominios/auth/servicio.ts — la lógica de auth. Sin HTTP adentro.
 *
 * Todo lo que dice AGENTS.md §12 vive acá, no en las rutas:
 *   - argon2id para contraseñas
 *   - anti-enumeración, incluida la del TIEMPO (verificación dummy)
 *   - refresh hasheado, de un solo uso y con rotación; reuso => revoca la familia, salvo el
 *     reintento de una respuesta perdida, que recibe la misma sucesora (decisión 0013)
 *   - cambiar la contraseña revoca las demás sesiones
 */
import type { Contexto } from "../../contexto.js";
import { ErrorApi } from "../../infra/errores.js";
import { validarPassword } from "../../infra/password.js";
import { versionLegal } from "../legal/textos.js";
import {
  firmarAcceso,
  firmarPasoDeCorreo,
  emailDePasoDeCorreo,
  generarCodigo,
  generarTokenOpaco,
  hashearPassword,
  hashearToken,
  igualSeguro,
  refreshSucesor,
  verificarDummy,
  verificarPassword,
} from "../../infra/cripto.js";
import { crearRepo, type RepoAuth, type SesionFila } from "./repositorio.js";

const VIDA_CODIGO_MS = 15 * 60 * 1000; // 15 min, como el diseño (`reg-codigo`)
const REENVIO_MS = 60 * 1000; //           60 s, como el diseño
const VIDA_TOKEN_PASO_MS = 10 * 60 * 1000;
const MAX_INTENTOS_CODIGO = 3;

/**
 * Cuánto después de canjear un refresh se acepta volver a presentarlo como REINTENTO
 * (decisión 0013).
 *
 * Cubre el sótano del gimnasio: el servidor rotó, la respuesta no llegó y el teléfono
 * vuelve a mandar el refresh viejo en el próximo pedido. Pasado este tiempo, o con la
 * sucesora ya usada, presentarlo es REUSO y revoca la familia. Corto a propósito:
 * mientras dura, quien tenga el refresh viejo recibe el mismo sucesor que el dueño.
 */
const VENTANA_DE_REINTENTO_MS = 2 * 60 * 1000;

export interface Sesion {
  access_token: string;
  access_expires_at_ms: number;
  refresh_token: string;
  refresh_expires_at_ms: number;
  user_id: string;
}

function normalizarEmail(email: string): string {
  return email.trim().toLowerCase();
}

interface CodigoTemporal {
  id: string;
  hash: string;
  venceMs: number;
}

function claveCodigo(email: string, proposito: string): string {
  return `auth:codigo:${proposito}:${hashearToken(email)}`;
}

function clavePaso(token: string): string {
  return `auth:paso:${hashearToken(token)}`;
}

export function crearServicioAuth(ctx: Contexto) {
  const repo: RepoAuth = crearRepo(ctx.db);

  async function abrirSesion(usuarioId: string, familiaId: string | null): Promise<Sesion> {
    const ahora = ctx.ahoraMs();
    const refresh = generarTokenOpaco();
    const fila = await repo.crearSesion(
      usuarioId,
      familiaId,
      hashearToken(refresh),
      ahora,
      ctx.config.refreshTtlS * 1000
    );
    return entregar(fila, refresh);
  }

  /** Lo que devuelven login, alta, recuperación y refresh: un access nuevo para `fila`. */
  async function entregar(fila: SesionFila, refresh: string): Promise<Sesion> {
    const acceso = await firmarAcceso(ctx.config, { sub: fila.usuario_id, sid: fila.id });
    return {
      access_token: acceso.token,
      access_expires_at_ms: acceso.venceMs,
      refresh_token: refresh,
      refresh_expires_at_ms: fila.vence_en_ms,
      user_id: fila.usuario_id,
    };
  }

  async function emitirCodigo(email: string, proposito: "registro" | "recuperacion", nombreCompleto?: string) {
    const ahora = ctx.ahoraMs();
    const clave = claveCodigo(email, proposito);
    const enfriamiento = `${clave}:reenvio`;
    if (!(await ctx.cache.ponerSiAusente(enfriamiento, "1", Math.ceil(REENVIO_MS / 1000)))) {
      throw new ErrorApi("code_resend_too_soon", "Wait before requesting another code", Math.ceil(REENVIO_MS / 1000));
    }
    const codigo = generarCodigo();
    const estado: CodigoTemporal = {
      id: generarTokenOpaco(), hash: hashearToken(codigo), venceMs: ahora + VIDA_CODIGO_MS,
    };
    const valor = JSON.stringify(estado);
    await ctx.cache.poner(clave, valor, Math.ceil(VIDA_CODIGO_MS / 1000));
    try {
      await ctx.correo.enviarCodigo(email, codigo, proposito, nombreCompleto);
    } catch {
      // Un SMTP caído no debe bloquear el reintento con un código que nadie recibió.
      await ctx.cache.consumirSiIgual(clave, valor);
      await ctx.cache.borrar(enfriamiento);
      throw new ErrorApi("service_unavailable", "Verification email could not be sent");
    }
    return { expires_at_ms: ahora + VIDA_CODIGO_MS, resend_after_ms: ahora + REENVIO_MS };
  }

  async function verificarCodigo(email: string, codigo: string, proposito: "registro" | "recuperacion") {
    const ahora = ctx.ahoraMs();
    const clave = claveCodigo(email, proposito);
    const valor = await ctx.cache.obtener(clave);
    if (valor === null) throw new ErrorApi("invalid_code", "Code is not valid");
    const fila = JSON.parse(valor) as CodigoTemporal;
    if (fila.venceMs <= ahora) throw new ErrorApi("code_expired", "Code has expired");

    // El contador vive en la caché con TTL, y en Redis cuando está configurado.
    // La clave lleva el ID aleatorio del desafío, nunca el correo de la persona.
    const claveIntentos = `codigo-intentos:${fila.id}`;
    if (!igualSeguro(hashearToken(codigo.toUpperCase()), fila.hash)) {
      const intentos = await ctx.cache.incrementar(claveIntentos, Math.ceil(VIDA_CODIGO_MS / 1000));
      if (intentos >= MAX_INTENTOS_CODIGO) {
        await ctx.cache.consumirSiIgual(clave, valor);
        throw new ErrorApi("code_expired", "Code has expired");
      }
      throw new ErrorApi("invalid_code", "Code is not valid");
    }

    if (!(await ctx.cache.consumirSiIgual(clave, valor))) {
      throw new ErrorApi("invalid_code", "Code is not valid");
    }
    await ctx.cache.borrar(claveIntentos);
    await ctx.cache.borrar(`${clave}:reenvio`);
    const token = await firmarPasoDeCorreo(ctx.config, email, proposito, ahora, VIDA_TOKEN_PASO_MS);
    await ctx.cache.poner(clavePaso(token), "1", Math.ceil(VIDA_TOKEN_PASO_MS / 1000));
    return { token, expires_at_ms: ahora + VIDA_TOKEN_PASO_MS };
  }

  function exigirPasswordValida(claro: string): void {
    const r = validarPassword(claro);
    if (!r.ok) throw new ErrorApi("weak_password", `Password rejected: ${r.motivo}`);
  }

  return {
    repo,

    // ------------------------------------------------------------ registro --
    /**
     * 🛑 Responde lo mismo exista o no la cuenta, y gasta lo mismo en las dos
     * ramas. Si ya existe, al dueño le llega un aviso; a quien preguntó, nada.
     */
    async registroInicio(emailCrudo: string, nombre?: string, apellido?: string) {
      const email = normalizarEmail(emailCrudo);
      if (ctx.config.registroPermitido !== null && email !== ctx.config.registroPermitido) {
        // Staging no acepta cuentas ajenas. La respuesta no revela la lista.
        const ahora = ctx.ahoraMs();
        return { expires_at_ms: ahora + VIDA_CODIGO_MS, resend_after_ms: ahora + REENVIO_MS };
      }
      const existente = await repo.buscarUsuarioPorEmail(email);
      if (existente !== null) {
        // Un pedido repetido al mismo correo no debe convertirse en una cola de
        // mensajes. La clave sólo guarda un hash del correo y vence en Redis.
        const aviso = `auth:aviso-registro:${hashearToken(email)}`;
        if (await ctx.cache.ponerSiAusente(aviso, "1", Math.ceil(REENVIO_MS / 1000))) {
          await ctx.correo.avisarIntentoDeRegistro(email);
        }
        const ahora = ctx.ahoraMs();
        return { expires_at_ms: ahora + VIDA_CODIGO_MS, resend_after_ms: ahora + REENVIO_MS };
      }
      const nombreCompleto = nombre && apellido ? `${nombre.trim()} ${apellido.trim()}` : undefined;
      return emitirCodigo(email, "registro", nombreCompleto);
    },

    async registroVerificar(emailCrudo: string, codigo: string) {
      const email = normalizarEmail(emailCrudo);
      if (ctx.config.registroPermitido !== null && email !== ctx.config.registroPermitido) {
        throw new ErrorApi("invalid_code", "Code is not valid");
      }
      const r = await verificarCodigo(email, codigo, "registro");
      return { registration_token: r.token, expires_at_ms: r.expires_at_ms };
    },

    async registroCompletar(
      registrationToken: string,
      password: string,
      legal: { version: string; accepted: boolean },
    ): Promise<{ sesion: Sesion; usuarioId: string }> {
      exigirPasswordValida(password);

      // 🛑 Se comprueba ANTES de crear nada. Si la persona no aceptó, o aceptó una
      // versión que no es la vigente, no hay cuenta: una cuenta creada sin
      // constancia es justo lo que esta comprobación existe para evitar.
      //
      // Que la versión sea vieja no es un error del cliente que se pueda ignorar:
      // significa que le mostramos un texto que ya no rige. La salida correcta es
      // que el teléfono baje el nuevo y lo vuelva a mostrar, no darlo por aceptado.
      const vigente = versionLegal();
      if (!legal.accepted) {
        throw new ErrorApi("legal_not_accepted", "Legal terms were not accepted");
      }
      if (legal.version !== vigente) {
        throw new ErrorApi("legal_version_stale", `Legal version is ${legal.version}, current is ${vigente}`);
      }

      const ahora = ctx.ahoraMs();
      const emailDePaso = await emailDePasoDeCorreo(ctx.config, registrationToken, "registro", ahora);
      if (emailDePaso === null || await ctx.cache.consumir(clavePaso(registrationToken)) !== "1") {
        throw new ErrorApi("invalid_registration_token", "Registration token is not valid");
      }
      if (ctx.config.registroPermitido !== null && emailDePaso !== ctx.config.registroPermitido) {
        throw new ErrorApi("invalid_registration_token", "Registration token is not valid");
      }

      // Carrera: dos completar con el mismo correo. El índice único de
      // `usuarios_email_unico` es el que decide, no un chequeo previo.
      const yaExiste = await repo.buscarUsuarioPorEmail(emailDePaso);
      if (yaExiste !== null) throw new ErrorApi("conflict", "Account already exists");

      const usuario = await repo.crearUsuario(emailDePaso, await hashearPassword(password), ahora);
      await repo.guardarAceptacionLegal(usuario.id, vigente, ahora);
      return { sesion: await abrirSesion(usuario.id, null), usuarioId: usuario.id };
    },

    // --------------------------------------------------------------- login --
    async login(emailCrudo: string, password: string): Promise<Sesion> {
      const email = normalizarEmail(emailCrudo);
      const usuario = await repo.buscarUsuarioPorEmail(email);

      // 🛑 La rama "no existe" hace el MISMO trabajo que la otra: si no, el tiempo
      // de respuesta enumera las cuentas aunque el JSON sea idéntico.
      if (usuario === null) {
        await verificarDummy(password);
        throw new ErrorApi("invalid_credentials", "Email or password is not valid");
      }

      if (!(await verificarPassword(password, usuario.password_hash))) {
        throw new ErrorApi("invalid_credentials", "Email or password is not valid");
      }
      return abrirSesion(usuario.id, null);
    },

    // ------------------------------------------------------------- refresh --
    async refrescar(refreshToken: string): Promise<Sesion> {
      const ahora = ctx.ahoraMs();
      const sucesor = refreshSucesor(ctx.config, refreshToken);

      // 🛑 En una transacción y con la fila BLOQUEADA. Sin el bloqueo, dos canjes
      // simultáneos del mismo refresh leían los dos "sin usar" y abrían dos cadenas, y la
      // detección de reuso no se enteraba. Con el bloqueo el segundo espera, ve el refresh
      // usado y cae en el reintento.
      //
      // Lo que termina en error se DEVUELVE y se lanza afuera: lanzarlo adentro desharía la
      // revocación de la familia junto con la transacción.
      const desenlace = await ctx.db.enTransaccion(async (tx) => {
        const r = crearRepo(tx);
        const sesion = await r.buscarSesionPorRefresh(hashearToken(refreshToken), true);
        if (sesion === null) return { tipo: "invalido" } as const;

        // 🛑 El canje previo se mira ANTES que la revocación: una sesión de una familia
        // revocada también está usada, y la rama del reuso es la que revoca. Mirar
        // "revocado" primero dejaría muerta la detección de robo sin que nada lo cante.
        if (sesion.usado_en_ms !== null) {
          const sucesora = await r.sucesoraDe(sesion.id);
          const reintento =
            sesion.revocado_en_ms === null &&
            ahora - sesion.usado_en_ms <= VENTANA_DE_REINTENTO_MS &&
            sucesora !== null &&
            sucesora.usado_en_ms === null &&
            sucesora.revocado_en_ms === null &&
            sucesora.vence_en_ms > ahora;
          if (reintento && sucesora !== null) {
            // Otro JWT_SECRET desde el canje: el sucesor ya no se puede recalcular. No es
            // algo que un atacante provoque, así que no revoca nada.
            if (sucesora.refresh_hash !== hashearToken(sucesor)) return { tipo: "invalido" } as const;
            // La respuesta del canje no llegó: LA MISMA sucesora, con un access nuevo.
            return { tipo: "entregar", fila: sucesora } as const;
          }
          // O alguien copió el refresh, o el cliente reintentó tarde. No se puede
          // distinguir, así que se asume lo peor y se revoca la familia entera.
          await r.revocarFamilia(sesion.familia_id, ahora, "reuso_de_refresh");
          return { tipo: "reuso" } as const;
        }
        if (sesion.revocado_en_ms !== null) return { tipo: "revocada" } as const;
        if (sesion.vence_en_ms <= ahora) return { tipo: "vencido" } as const;

        // 🛑 Rotar NO revoca la sesión vieja: sólo la marca usada, y sus access siguen
        // valiendo hasta que vencen. Revocarla dejaba con `session_revoked` a cualquier
        // pedido que viajaba mientras otro renovaba, y el teléfono no puede distinguir eso
        // de una sesión cerrada de verdad. Lo encontró Android (decisión 0013).
        await r.marcarUsada(sesion.id, ahora);
        const fila = await r.crearSesion(
          sesion.usuario_id,
          sesion.familia_id,
          hashearToken(sucesor),
          ahora,
          ctx.config.refreshTtlS * 1000,
          sesion.id
        );
        return { tipo: "entregar", fila } as const;
      });

      switch (desenlace.tipo) {
        case "invalido":
          throw new ErrorApi("invalid_refresh_token", "Refresh token is not valid");
        case "reuso":
          throw new ErrorApi("session_revoked", "Refresh token was already used");
        case "revocada":
          throw new ErrorApi("session_revoked", "Session was revoked");
        case "vencido":
          throw new ErrorApi("invalid_refresh_token", "Refresh token has expired");
        case "entregar":
          return entregar(desenlace.fila, sucesor);
      }
    },

    // -------------------------------------------------------------- logout --
    /** Idempotente: cerrar algo ya cerrado no es un error (docs/API.md §6). */
    async logout(usuarioId: string, sesionActualId: string, refreshToken?: string, todas?: boolean): Promise<void> {
      const ahora = ctx.ahoraMs();
      if (todas === true) {
        await repo.revocarTodasDe(usuarioId, ahora, "logout_todas");
        return;
      }
      if (refreshToken !== undefined) {
        const s = await repo.buscarSesionPorRefresh(hashearToken(refreshToken));
        // Sólo se revoca si es de quien pide: si no, cualquiera con un refresh
        // ajeno cierra sesiones de otro.
        if (s !== null && s.usuario_id === usuarioId) {
          await repo.revocarFamilia(s.familia_id, ahora, "logout");
        }
        return;
      }
      // Sin refresh en el cuerpo se revoca la familia de la sesión con la que se pide, que
      // es la misma cadena de login: rotar no revoca, y la fila sola dejaría vivos los
      // access de las rotaciones anteriores (decisión 0013).
      await repo.revocarFamiliaDeSesion(sesionActualId, ahora, "logout");
    },

    // ------------------------------------------------------- recuperación --
    async recuperacionInicio(emailCrudo: string) {
      const email = normalizarEmail(emailCrudo);
      const usuario = await repo.buscarUsuarioPorEmail(email);
      if (usuario === null) {
        // Misma respuesta y mismo costo que si existiera.
        const ahora = ctx.ahoraMs();
        return { expires_at_ms: ahora + VIDA_CODIGO_MS, resend_after_ms: ahora + REENVIO_MS };
      }
      return emitirCodigo(email, "recuperacion");
    },

    async recuperacionVerificar(emailCrudo: string, codigo: string) {
      const email = normalizarEmail(emailCrudo);
      const r = await verificarCodigo(email, codigo, "recuperacion");
      return { reset_token: r.token, expires_at_ms: r.expires_at_ms };
    },

    async recuperacionAplicar(resetToken: string, password: string): Promise<Sesion> {
      exigirPasswordValida(password);
      const ahora = ctx.ahoraMs();
      const emailDePaso = await emailDePasoDeCorreo(ctx.config, resetToken, "recuperacion", ahora);
      if (emailDePaso === null || await ctx.cache.consumir(clavePaso(resetToken)) !== "1") {
        throw new ErrorApi("invalid_reset_token", "Reset token is not valid");
      }
      const usuario = await repo.buscarUsuarioPorEmail(emailDePaso);
      if (usuario === null) throw new ErrorApi("invalid_reset_token", "Reset token is not valid");

      await repo.cambiarPassword(usuario.id, await hashearPassword(password), ahora);
      // 🛑 §12: cambiar la contraseña revoca las demás sesiones. Se revoca TODO y
      // se abre una nueva, así que quien cambió la clave no queda afuera.
      await repo.revocarTodasDe(usuario.id, ahora, "cambio_de_password");
      return abrirSesion(usuario.id, null);
    },

    /**
     * Un access token sigue siendo válido si su sesión no fue revocada. Rotar no cuenta
     * como revocar (decisión 0013): el access vive hasta su `exp`, que ya verificó `jose`.
     */
    async sesionVigente(sesionId: string): Promise<boolean> {
      return repo.sesionVigente(sesionId, ctx.ahoraMs());
    },

    normalizarEmail,
  };
}

export type ServicioAuth = ReturnType<typeof crearServicioAuth>;
