/** Envío de desafíos de cuenta. El proveedor de log sólo se admite fuera de producción. */
import nodemailer from "nodemailer";
import type { Config } from "../config.js";
import {
  CID_LOGO, correoDeCodigo, correoDeIntentoDeRegistro, correoDeNuevoInicio, correoDeVinculacion,
  type AvisoDeAcceso, type Proposito,
} from "./plantillas-correo.js";
import type { IdiomaDeCorreo } from "./idioma.js";
import { LOGO_CORREO_PNG_BASE64 } from "./logo-correo.js";

/** Lo mismo que `VIDA_CODIGO_MS` de auth: el correo dice cuánto dura el código. */
const VIDA_CODIGO_MIN = 15;

/** El remitente con nombre: en la bandeja se lee "Stamina", no la dirección. */
export function remitente(mailFrom: string): string {
  return mailFrom.includes("<") ? mailFrom : `"Stamina" <${mailFrom}>`;
}

/** Lo que un aviso de acceso recibe del servicio; la hora la pone el correo. */
export type DatosDeAviso = Omit<AvisoDeAcceso, "ahoraMs">;

export interface Correo {
  /** @param nombre el nombre de pila, para el "Hola Iván,". */
  enviarCodigo(destino: string, codigo: string, proposito: Proposito, nombre?: string, idioma?: IdiomaDeCorreo): Promise<void>;
  avisarIntentoDeRegistro(destino: string): Promise<void>;
  /** Se vinculó Google o Apple a una cuenta que ya existía. */
  avisarVinculacion(destino: string, proveedor: "google" | "apple", aviso?: DatosDeAviso): Promise<void>;
  /**
   * Se entró a la cuenta desde un dispositivo que nunca había estado en ella
   * (contrato 1.7.0). Opcional en la interfaz sólo para que los dobles de los tests
   * que no lo usan no tengan que implementarlo: `crearCorreo` lo implementa siempre.
   */
  avisarNuevoInicio?(destino: string, aviso: DatosDeAviso): Promise<void>;
}

function limpiarNombre(nombre: string | undefined | null): string | null {
  if (nombre === undefined || nombre === null) return null;
  const limpio = nombre.trim().replace(/\s+/g, " ");
  return limpio.length > 0 ? limpio.slice(0, 80) : null;
}

/** Sin aviso (un doble viejo, o un vínculo sin datos): lo mínimo, en español. */
function avisoCompleto(aviso: DatosDeAviso | undefined, ahoraMs: number): AvisoDeAcceso {
  const base = aviso ?? { nombre: null, idioma: "es" as const, ip: "", dispositivo: null };
  return { ...base, nombre: limpiarNombre(base.nombre), ahoraMs };
}

export function crearCorreo(config: Config, log: { info: (o: object, m: string) => void }): Correo {
  if (config.mailProvider === "log") {
    return {
      async enviarCodigo(_destino, codigo, proposito, _nombre, idioma) {
        log.info({ proposito, idioma, codigo_dev: codigo }, "correo: código generado (proveedor=log, fuera de producción)");
      },
      async avisarIntentoDeRegistro() {
        log.info({}, "correo: intento de registro sobre una cuenta existente (proveedor=log)");
      },
      async avisarVinculacion(_destino, proveedor) {
        log.info({ proveedor }, "correo: se vinculó un proveedor a una cuenta existente (proveedor=log)");
      },
      async avisarNuevoInicio(_destino, aviso) {
        log.info({ idioma: aviso.idioma }, "correo: inicio de sesión desde un dispositivo nuevo (proveedor=log)");
      },
    };
  }

  if (config.smtp === null) throw new Error("correo: falta configuración SMTP");
  const transporte = nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.puerto,
    secure: config.smtp.tlsDirecto,
    requireTLS: !config.smtp.tlsDirecto,
    auth: { user: config.smtp.usuario, pass: config.smtp.clave },
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 15_000,
    tls: { minVersion: "TLSv1.2", rejectUnauthorized: true },
  });

  const de = remitente(config.mailFrom);
  // El ícono viaja adentro del correo (cid:), no como enlace: se ve aunque el
  // cliente bloquee imágenes remotas.
  const logo = {
    filename: "stamina.png",
    content: Buffer.from(LOGO_CORREO_PNG_BASE64, "base64"),
    contentType: "image/png",
    cid: CID_LOGO,
    contentDisposition: "inline" as const,
  };
  async function mandar(destino: string, correo: { asunto: string; texto: string; html: string }): Promise<void> {
    await transporte.sendMail({
      from: de, to: destino, subject: correo.asunto, text: correo.texto, html: correo.html, attachments: [logo],
    });
  }

  return {
    async enviarCodigo(destino, codigo, proposito, nombre, idioma) {
      await mandar(destino, correoDeCodigo({
        codigo, proposito, nombre: limpiarNombre(nombre), idioma: idioma ?? "es", vidaMin: VIDA_CODIGO_MIN,
      }));
    },
    async avisarVinculacion(destino, proveedor, aviso) {
      await mandar(destino, correoDeVinculacion({ ...avisoCompleto(aviso, Date.now()), proveedor }));
    },
    async avisarNuevoInicio(destino, aviso) {
      await mandar(destino, correoDeNuevoInicio(avisoCompleto(aviso, Date.now())));
    },
    async avisarIntentoDeRegistro(destino) {
      await mandar(destino, correoDeIntentoDeRegistro({ destino, ahoraMs: Date.now() }));
    },
  };
}
