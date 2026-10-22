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
  firmarAltaSocial,
  leerAltaSocial,
  firmarReactivacion,
  leerReactivacion,
  firmarVinculo,
  leerVinculo,
} from "../../infra/cripto.js";
import {
  crearVerificadorDeProveedores,
  proveedorEsDuenoDelCorreo,
  type NombreDeProveedor,
} from "../../infra/proveedores.js";
import { crearRepo, type RepoAuth, type SesionFila, type UsuarioFila } from "./repositorio.js";
import { crearTopeDeIntentos } from "./intentos.js";

const VIDA_CODIGO_MS = 15 * 60 * 1000; // 15 min, como el diseño (`reg-codigo`)
const REENVIO_MS = 60 * 1000; //           60 s, como el diseño
const VIDA_TOKEN_PASO_MS = 10 * 60 * 1000;
/** Contrato 1.6.0: al quinto código equivocado, ése queda invalidado (`code_attempts_exceeded`). */
const MAX_INTENTOS_CODIGO = 5;
/**
 * Cuánto se recuerda un código en la caché DESPUÉS de vencer. Sin este margen la
 * clave desaparecía justo a los 15 minutos y el código vencido se contestaba
 * `invalid_code`, que le dice a la persona que lo tipeó mal cuando en realidad
 * tiene que pedir otro. Con la clave viva, el vencido es `code_expired`.
 */
const RECUERDO_CODIGO_MS = VIDA_CODIGO_MS + 60 * 60 * 1000;
/**
 * Cuánto vive el permiso de alta social. Más que el del correo: en el medio la
 * persona revisa sus datos, espera el código y lee el aviso de salud.
 */
const VIDA_ALTA_SOCIAL_MS = 30 * 60 * 1000;
/** Los permisos de vincular y de reactivar (1.6.0): 10 minutos, un solo uso. */
const VIDA_PERMISO_CUENTA_MS = 10 * 60 * 1000;
const DIA_MS = 24 * 60 * 60 * 1000;

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
  /** Se equivocaron cinco veces: ya no vale, ni siquiera el correcto. */
  agotado?: true;
}

function claveCodigo(email: string, proposito: string): string {
  return `auth:codigo:${proposito}:${hashearToken(email)}`;
}

function clavePaso(token: string): string {
  return `auth:paso:${hashearToken(token)}`;
}

/** Lo que contesta `POST /auth/social`. */
export type DesenlaceSocial =
  | { status: "signed_in"; session: Sesion }
  | {
      status: "signup_required";
      signup: { signup_token: string; expires_at_ms: number; email: string | null; email_verified: boolean };
    };

export function crearServicioAuth(ctx: Contexto) {
  const repo: RepoAuth = crearRepo(ctx.db);
  const proveedores = ctx.proveedores ?? crearVerificadorDeProveedores({
    clientIds: ctx.config.proveedores ?? { google: [], apple: [] },
  });
  const tope = crearTopeDeIntentos(ctx.cache, ctx.ahoraMs);

  /**
   * Antes de mirar una contraseña: la IP y el correo no tienen que estar bloqueados.
   *
   * 🛑 Con el correo bloqueado se gasta lo mismo que una verificación: si no, la
   * respuesta rápida diría "este correo tiene cuenta y alguien le está probando
   * contraseñas", que es más de lo que ya dice `user_not_found`.
   */
  async function exigirSinBloqueo(email: string, password: string, ip: string): Promise<void> {
    const deIp = await tope.bloqueoDeIp(ip);
    if (deIp !== null) throw new ErrorApi("rate_limited", "Too many failed attempts", deIp);
    const deCorreo = await tope.bloqueoDeCorreo(email);
    if (deCorreo !== null) {
      await verificarDummy(password);
      throw new ErrorApi("too_many_attempts", "Too many wrong passwords for this email", deCorreo);
    }
  }

  /**
   * La contraseña de una cuenta, con el tope. Bien: la racha vuelve a cero. Mal:
   * suma, y el fallo que llega al tope ya contesta el bloqueo, para que la app lo
   * diga en ese momento y no después de un sexto intento que no podía andar.
   */
  async function comprobarPassword(email: string, hash: string, password: string, ip: string): Promise<void> {
    if (await verificarPassword(password, hash)) {
      await tope.reiniciar(email);
      return;
    }
    const bloqueo = await tope.fallo(email, ip);
    if (bloqueo !== null) throw new ErrorApi("too_many_attempts", "Too many wrong passwords for this email", bloqueo);
    throw new ErrorApi("wrong_password", "The password does not match");
  }

  /** `password_not_set` con el proveedor con el que nació la cuenta (contrato 1.6.0). */
  async function sinPassword(usuarioId: string): Promise<ErrorApi> {
    const proveedor = await repo.proveedorDeAlta(usuarioId);
    return new ErrorApi(
      "password_not_set", "This account signs in with Google or Apple", undefined,
      proveedor === null ? undefined : { provider: proveedor },
    );
  }

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

  /**
   * 🛑 La puerta de toda sesión que se abre para una cuenta que ya existía (login,
   * Google/Apple, vincular, recuperar): una cuenta desactivada o por borrarse no
   * entra. Contesta el estado con un permiso para `POST /auth/reactivate`, y sólo
   * se llega acá después de que la persona demostró ser ella (contraseña, código o
   * proveedor): a quien no la sabe, el estado no se le dice (contrato 1.6.0).
   */
  async function exigirCuentaActiva(u: UsuarioFila): Promise<void> {
    if (u.borrar_en_ms === null && u.desactivada_en_ms === null) return;
    const ahora = ctx.ahoraMs();
    const reactivation_token = await firmarReactivacion(ctx.config, u.id, ahora, VIDA_PERMISO_CUENTA_MS);
    if (u.borrar_en_ms !== null) {
      // Días enteros, para arriba: con 29,2 días por delante, la persona tiene "30".
      const days_remaining = Math.max(0, Math.ceil((u.borrar_en_ms - ahora) / DIA_MS));
      throw new ErrorApi("account_pending_deletion", "This account is scheduled for deletion", undefined,
        { reactivation_token, days_remaining });
    }
    throw new ErrorApi("account_deactivated", "This account is deactivated", undefined, { reactivation_token });
  }

  async function abrirSesionDe(u: UsuarioFila): Promise<Sesion> {
    await exigirCuentaActiva(u);
    return abrirSesion(u.id, null);
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
    // El código nuevo reemplaza al anterior (pedir otro invalida el que había) y
    // tiene que ser DISTINTO: si la persona recibe dos veces el mismo, cree que el
    // reenvío no anduvo, y uno agotado no puede volver con otro nombre.
    const anterior = await ctx.cache.obtener(clave);
    const hashAnterior = anterior === null ? null : (JSON.parse(anterior) as CodigoTemporal).hash;
    let codigo = generarCodigo();
    while (hashearToken(codigo) === hashAnterior) codigo = generarCodigo();
    const estado: CodigoTemporal = {
      id: generarTokenOpaco(), hash: hashearToken(codigo), venceMs: ahora + VIDA_CODIGO_MS,
    };
    const valor = JSON.stringify(estado);
    await ctx.cache.poner(clave, valor, Math.ceil(RECUERDO_CODIGO_MS / 1000));
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
    // Agotado antes que vencido: si se agotó, eso es lo que la persona tiene que saber.
    if (fila.agotado === true) throw new ErrorApi("code_attempts_exceeded", "Too many wrong codes");
    if (fila.venceMs <= ahora) throw new ErrorApi("code_expired", "Code has expired");

    // El contador vive en la caché con TTL, y en Redis cuando está configurado.
    // La clave lleva el ID aleatorio del desafío, nunca el correo de la persona.
    const claveIntentos = `codigo-intentos:${fila.id}`;
    if (!igualSeguro(hashearToken(codigo.toUpperCase()), fila.hash)) {
      const intentos = await ctx.cache.incrementar(claveIntentos, Math.ceil(RECUERDO_CODIGO_MS / 1000));
      if (intentos >= MAX_INTENTOS_CODIGO) {
        // Se marca agotado en vez de borrarlo: así los pedidos siguientes, incluso
        // con el código correcto, siguen diciendo lo mismo y no `invalid_code`.
        // `consumirSiIgual` primero: si otro pedido ya lo canjeó, no se resucita.
        if (await ctx.cache.consumirSiIgual(clave, valor)) {
          await ctx.cache.poner(clave, JSON.stringify({ ...fila, agotado: true }), Math.ceil(RECUERDO_CODIGO_MS / 1000));
        }
        throw new ErrorApi("code_attempts_exceeded", "Too many wrong codes");
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
     * Si el correo ya tiene cuenta, lo dice (`email_already_registered`): la app
     * ofrece entrar o recuperar la contraseña. Decisión de Iván, 2026-10-21: antes
     * contestaba lo mismo exista o no, para no revelar qué correos tienen cuenta.
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
        throw new ErrorApi("email_already_registered", "An account with this email already exists");
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

    /**
     * Crea la cuenta. Lleva una de dos credenciales: la `password` del alta común o
     * el `socialToken` de `POST /auth/social`, que vincula la identidad de Google o
     * Apple y deja la cuenta sin contraseña.
     */
    async registroCompletar(
      /**
       * El permiso del código del correo. Obligatorio con contraseña. Con
       * Google/Apple sólo hace falta si el proveedor NO verificó el correo: si lo
       * verificó, la cuenta se crea con ese correo sin pedir código.
       */
      registrationToken: string | undefined,
      credencial: { password: string } | { socialToken: string },
      legal: { version: string; accepted: boolean },
    ): Promise<{ sesion: Sesion; usuarioId: string }> {
      const ahoraAlta = ctx.ahoraMs();
      let altaSocial: Awaited<ReturnType<typeof leerAltaSocial>> = null;
      if ("password" in credencial) {
        exigirPasswordValida(credencial.password);
      } else {
        // 🛑 Se lee ANTES de consumir el permiso del correo: un permiso social
        // vencido no tiene que gastar el código que la persona acaba de validar.
        altaSocial = await leerAltaSocial(ctx.config, credencial.socialToken, ahoraAlta);
        if (altaSocial === null) throw new ErrorApi("invalid_signup_token", "Signup token is not valid");
        if (await repo.buscarUsuarioPorIdentidad(altaSocial.proveedor, altaSocial.sujeto) !== null) {
          throw new ErrorApi("conflict", "Account already exists");
        }
      }

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
      let emailDePaso: string | null;
      if (registrationToken === undefined) {
        // Sin código: sólo vale con un correo que Google o Apple ya verificaron.
        if (altaSocial === null || altaSocial.email === null || !altaSocial.emailVerificado) {
          throw new ErrorApi("invalid_registration_token", "Registration token is required");
        }
        emailDePaso = normalizarEmail(altaSocial.email);
      } else {
        emailDePaso = await emailDePasoDeCorreo(ctx.config, registrationToken, "registro", ahora);
        if (emailDePaso === null || await ctx.cache.consumir(clavePaso(registrationToken)) !== "1") {
          throw new ErrorApi("invalid_registration_token", "Registration token is not valid");
        }
      }
      if (ctx.config.registroPermitido !== null && emailDePaso !== ctx.config.registroPermitido) {
        throw new ErrorApi("invalid_registration_token", "Registration token is not valid");
      }

      // Carrera: dos completar con el mismo correo. El índice único de
      // `usuarios_email_unico` es el que decide, no un chequeo previo.
      const yaExiste = await repo.buscarUsuarioPorEmail(emailDePaso);
      if (yaExiste !== null) throw new ErrorApi("conflict", "Account already exists");

      const hash = "password" in credencial ? await hashearPassword(credencial.password) : null;
      // 🛑 En UNA transacción: la cuenta, su identidad social y la constancia legal
      // nacen juntas o no nace nada. Sin esto, dos altas a la vez con el mismo
      // permiso social creaban dos cuentas, y la segunda quedaba sin contraseña y
      // sin identidad: una cuenta a la que no se puede entrar.
      const usuario = await ctx.db.enTransaccion(async (tx) => {
        const r = crearRepo(tx);
        const creado = await r.crearUsuario(emailDePaso, hash, ahora);
        if (altaSocial !== null &&
            !(await r.vincularIdentidad(creado.id, altaSocial.proveedor, altaSocial.sujeto, altaSocial.email, ahora))) {
          throw new ErrorApi("conflict", "Account already exists");
        }
        await r.guardarAceptacionLegal(creado.id, vigente, ahora);
        return creado;
      });
      return { sesion: await abrirSesion(usuario.id, null), usuarioId: usuario.id };
    },

    // --------------------------------------------------------------- login --
    /** @param ip la del pedido: cuenta para el tope de fallos por IP. */
    async login(emailCrudo: string, password: string, ip: string): Promise<Sesion> {
      const email = normalizarEmail(emailCrudo);
      await exigirSinBloqueo(email, password, ip);
      const usuario = await repo.buscarUsuarioPorEmail(email);

      // 2026-10-21 (decisión de Iván): cada caso con su código, para que la app
      // diga "El usuario no existe" o "La contraseña no coincide".
      if (usuario === null) {
        await verificarDummy(password);
        // Probar correos también es un intento fallido para la IP.
        await tope.fallo(null, ip);
        throw new ErrorApi("user_not_found", "There is no account with this email");
      }
      // Una cuenta que nació con Google o Apple no tiene contraseña.
      if (usuario.password_hash === null) {
        await verificarDummy(password);
        throw await sinPassword(usuario.id);
      }
      await comprobarPassword(email, usuario.password_hash, password, ip);
      return abrirSesionDe(usuario);
    },

    // ---------------------------------------------------------- reactivar --
    /**
     * `POST /auth/reactivate` (1.6.0). Canjea el permiso de `account_deactivated` o
     * `account_pending_deletion`: la cuenta vuelve a estar activa —si estaba por
     * borrarse, el borrado se cancela— y se abre la sesión.
     */
    async reactivar(token: string): Promise<Sesion> {
      const ahora = ctx.ahoraMs();
      const permiso = await leerReactivacion(ctx.config, token, ahora);
      if (permiso === null) throw new ErrorApi("invalid_reactivation_token", "Reactivation token is not valid");
      // Un solo uso: se recuerda hasta que vence, y un minuto más por los relojes.
      const ttlS = Math.max(60, Math.ceil((permiso.venceMs - ahora) / 1000) + 60);
      if (!(await ctx.cache.ponerSiAusente(`auth:reactivar:${hashearToken(permiso.jti)}`, "1", ttlS))) {
        throw new ErrorApi("invalid_reactivation_token", "Reactivation token was already used");
      }
      if (!(await repo.reactivar(permiso.usuarioId, ahora))) {
        throw new ErrorApi("invalid_reactivation_token", "Reactivation token is not valid");
      }
      return abrirSesion(permiso.usuarioId, null);
    },

    // -------------------------------------------------- Google y Apple --
    /**
     * `POST /auth/social`. Cuatro desenlaces:
     *
     * 1. La identidad ya está vinculada → se abre la sesión (si la cuenta está
     *    activa; si no, el estado con su permiso de reactivar).
     * 2. No está vinculada y el correo es de una cuenta CON contraseña →
     *    `account_link_available` (1.6.0) con un permiso para
     *    `POST /auth/social/link`. La app pregunta antes de vincular, y el canje
     *    pide la contraseña salvo que el proveedor sea el dueño del correo.
     * 3. No está vinculada, el correo es de una cuenta SIN contraseña (nació con
     *    el otro proveedor) y el proveedor es dueño de ese correo → se vincula sola
     *    y se abre la sesión, como antes de la 1.6.0: es la misma persona y no hay
     *    contraseña que pedirle.
     * 4. Nadie la conoce → `signup_required` con un permiso de alta. El teléfono
     *    sigue con el alta de siempre (nombre, apellido, correo y su código): la
     *    cuenta se crea recién en `register/complete`, con ese permiso en vez de
     *    una contraseña.
     */
    async entrarConProveedor(proveedor: NombreDeProveedor, idToken: string, nonce: string): Promise<DesenlaceSocial> {
      if (!proveedores.configurado(proveedor)) {
        throw new ErrorApi("provider_not_configured", `Sign in with ${proveedor} is not configured`);
      }
      const identidad = await proveedores.verificar(proveedor, idToken, nonce);
      if (identidad === null) throw new ErrorApi("invalid_provider_token", "Provider token is not valid");

      // 🛑 Cada id_token sirve UNA vez. El nonce de Google viaja en claro adentro
      // del token, así que no alcanza contra alguien que se lo robó: lo que lo
      // frena es que el servidor recuerde los que ya aceptó, hasta que vencen.
      const ttlS = Math.max(60, Math.ceil((identidad.venceMs - ctx.ahoraMs()) / 1000) + 60);
      if (!(await ctx.cache.ponerSiAusente(`auth:idtoken:${hashearToken(idToken)}`, "1", ttlS))) {
        throw new ErrorApi("invalid_provider_token", "Provider token was already used");
      }

      const vinculado = await repo.buscarUsuarioPorIdentidad(proveedor, identidad.sujeto);
      if (vinculado !== null) return { status: "signed_in", session: await abrirSesionDe(vinculado) };

      const porCorreo = identidad.email === null ? null : await repo.buscarUsuarioPorEmail(identidad.email);

      // 1.6.0: una cuenta con contraseña no se vincula sola. Se ofrece, y la persona
      // decide en la app. Si esa cuenta ya tiene otra persona del mismo proveedor,
      // no hay nada que ofrecer.
      if (porCorreo !== null && porCorreo.password_hash !== null) {
        if (await repo.tieneIdentidadDe(porCorreo.id, proveedor)) {
          throw new ErrorApi("conflict", "This account already has another identity of this provider");
        }
        // Sin contraseña sólo si el proveedor es el DUEÑO del correo: un Google
        // creado con un @hotmail verificó ese correo alguna vez, pero quien lo
        // controla hoy puede no ser el dueño del buzón (proveedores.ts).
        const requierePassword = !proveedorEsDuenoDelCorreo(identidad);
        const link_token = await firmarVinculo(ctx.config, {
          usuarioId: porCorreo.id, proveedor, sujeto: identidad.sujeto, email: identidad.email, requierePassword,
        }, ctx.ahoraMs(), VIDA_PERMISO_CUENTA_MS);
        throw new ErrorApi("account_link_available", "An account with this email exists and can be linked", undefined, {
          link_token, email: porCorreo.email, provider: proveedor, requires_password: requierePassword,
        });
      }

      // Sin contraseña, se vincula sola sólo si el proveedor es el DUEÑO de ese
      // correo, y si esa cuenta no tiene ya otra persona del mismo proveedor.
      if (identidad.email !== null && proveedorEsDuenoDelCorreo(identidad)) {
        if (porCorreo !== null && !(await repo.tieneIdentidadDe(porCorreo.id, proveedor))) {
          await repo.vincularIdentidad(porCorreo.id, proveedor, identidad.sujeto, identidad.email, ctx.ahoraMs());
          // Que el dueño se entere: una forma nueva de entrar a su cuenta no puede
          // aparecer en silencio. Si el correo falla, igual entra.
          try { await ctx.correo.avisarVinculacion(identidad.email, proveedor); } catch { /* no bloquea */ }
          return { status: "signed_in", session: await abrirSesionDe(porCorreo) };
        }
      }

      // Una cuenta SIN contraseña con ese correo verificado, pero el proveedor no es
      // dueño del correo (un Google creado con un @hotmail): no se vincula sola y
      // tampoco se puede crear otra cuenta con ese correo. Que entre con el
      // proveedor con el que nació, o se ponga una contraseña con "¿Olvidaste tu
      // contraseña?" y vuelva: ahí ya se le ofrece vincular.
      if (identidad.emailVerificado && porCorreo !== null) {
        throw new ErrorApi("conflict", "An account with this email already exists");
      }

      const ahora = ctx.ahoraMs();
      const token = await firmarAltaSocial(
        ctx.config,
        { proveedor, sujeto: identidad.sujeto, email: identidad.email, emailVerificado: identidad.emailVerificado },
        ahora,
        VIDA_ALTA_SOCIAL_MS,
      );
      return {
        status: "signup_required",
        signup: {
          signup_token: token,
          expires_at_ms: ahora + VIDA_ALTA_SOCIAL_MS,
          email: identidad.email,
          email_verified: identidad.emailVerificado,
        },
      };
    },

    /**
     * `POST /auth/social/link` (1.6.0). Canjea el permiso de `account_link_available`:
     * vincula la identidad a la cuenta, le avisa al dueño por correo y abre la sesión.
     *
     * El permiso se gasta recién al vincular: una contraseña mal tipeada no obliga a
     * volver a entrar con el proveedor. Lo que frena probar contraseñas con un mismo
     * permiso es el tope por correo, que acá cuenta igual que en el login.
     *
     * @param ip la del pedido, para el tope de fallos por IP.
     */
    async vincularConPassword(token: string, password: string | undefined, ip: string): Promise<Sesion> {
      const ahora = ctx.ahoraMs();
      const v = await leerVinculo(ctx.config, token, ahora);
      if (v === null) throw new ErrorApi("invalid_link_token", "Link token is not valid");
      const claveUso = `auth:vinculo:${hashearToken(v.jti)}`;
      if (await ctx.cache.obtener(claveUso) !== null) throw new ErrorApi("invalid_link_token", "Link token was already used");
      const usuario = await repo.buscarUsuarioPorId(v.usuarioId);
      if (usuario === null) throw new ErrorApi("invalid_link_token", "Link token is not valid");

      if (v.requierePassword) {
        await exigirSinBloqueo(usuario.email, password ?? "", ip);
        // Sin contraseña es `wrong_password` (contrato), pero no cuenta para el tope:
        // no es un intento de adivinar nada.
        if (password === undefined || usuario.password_hash === null) {
          await verificarDummy(password ?? "");
          throw new ErrorApi("wrong_password", "The password does not match");
        }
        await comprobarPassword(usuario.email, usuario.password_hash, password, ip);
      }

      // Un solo uso: se recuerda hasta que el permiso vence, y un minuto más.
      const ttlS = Math.max(60, Math.ceil((v.venceMs - ahora) / 1000) + 60);
      if (!(await ctx.cache.ponerSiAusente(claveUso, "1", ttlS))) {
        throw new ErrorApi("invalid_link_token", "Link token was already used");
      }
      if (await repo.tieneIdentidadDe(usuario.id, v.proveedor) ||
          !(await repo.vincularIdentidad(usuario.id, v.proveedor, v.sujeto, v.email, ahora))) {
        throw new ErrorApi("conflict", "This identity or provider is already linked");
      }
      // Una forma nueva de entrar a la cuenta no puede aparecer en silencio. Si el
      // correo falla, el vínculo vale igual.
      try { await ctx.correo.avisarVinculacion(usuario.email, v.proveedor); } catch { /* no bloquea */ }
      // Desactivada o por borrarse: el vínculo queda hecho y contesta el estado.
      return abrirSesionDe(usuario);
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
        // Desactivar y borrar revocan las sesiones; esto cubre la que rotó en carrera.
        if (!(await r.cuentaActiva(sesion.usuario_id))) return { tipo: "revocada" } as const;

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
        throw new ErrorApi("user_not_found", "There is no account with this email");
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
      // Cambiar la contraseña reinicia el tope de ese correo (contrato 1.6.0).
      await tope.reiniciar(usuario.email);
      // 🛑 §12: cambiar la contraseña revoca las demás sesiones. Se revoca TODO y
      // se abre una nueva, así que quien cambió la clave no queda afuera.
      await repo.revocarTodasDe(usuario.id, ahora, "cambio_de_password");
      // Con la cuenta desactivada o por borrarse, la contraseña queda cambiada igual
      // y contesta el estado con su permiso, como el login (contrato 1.6.0).
      return abrirSesionDe(usuario);
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
