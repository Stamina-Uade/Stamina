/** Envío de desafíos de cuenta. El proveedor de log sólo se admite fuera de producción. */
import nodemailer from "nodemailer";
import type { Config } from "../config.js";
import {
  CID_LOGO, correoDeCodigo, correoDeIntentoDeRegistro, correoDeVinculacion, type Proposito,
} from "./plantillas-correo.js";
import { LOGO_CORREO_PNG_BASE64 } from "./logo-correo.js";

/** Lo mismo que `VIDA_CODIGO_MS` de auth: el correo dice cuánto dura el código. */
const VIDA_CODIGO_MIN = 15;

/** El remitente con nombre: en la bandeja se lee "Stamina", no la dirección. */
export function remitente(mailFrom: string): string {
  return mailFrom.includes("<") ? mailFrom : `"Stamina" <${mailFrom}>`;
}

export interface Correo {
  enviarCodigo(destino: string, codigo: string, proposito: Proposito, nombreCompleto?: string): Promise<void>;
  avisarIntentoDeRegistro(destino: string): Promise<void>;
  /** Se vinculó Google o Apple a una cuenta que ya existía. */
  avisarVinculacion(destino: string, proveedor: "google" | "apple"): Promise<void>;
}

function limpiarNombre(nombre: string | undefined): string | null {
  if (nombre === undefined) return null;
  const limpio = nombre.trim().replace(/\s+/g, " ");
  return limpio.length > 0 ? limpio.slice(0, 161) : null;
}

export function crearCorreo(config: Config, log: { info: (o: object, m: string) => void }): Correo {
  if (config.mailProvider === "log") {
    return {
      async enviarCodigo(_destino, codigo, proposito) {
        log.info({ proposito, codigo_dev: codigo }, "correo: código generado (proveedor=log, fuera de producción)");
      },
      async avisarIntentoDeRegistro() {
        log.info({}, "correo: intento de registro sobre una cuenta existente (proveedor=log)");
      },
      async avisarVinculacion(_destino, proveedor) {
        log.info({ proveedor }, "correo: se vinculó un proveedor a una cuenta existente (proveedor=log)");
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

  return {
    async enviarCodigo(destino, codigo, proposito, nombreCompleto) {
      const correo = correoDeCodigo({
        codigo, proposito, destino, nombre: limpiarNombre(nombreCompleto),
        ahoraMs: Date.now(), vidaMin: VIDA_CODIGO_MIN,
      });
      await transporte.sendMail({
        from: de,
        to: destino,
        subject: correo.asunto,
        text: correo.texto,
        html: correo.html,
        attachments: [logo],
      });
    },
    async avisarVinculacion(destino, proveedor) {
      const correo = correoDeVinculacion({ destino, proveedor, ahoraMs: Date.now() });
      await transporte.sendMail({
        from: de, to: destino, subject: correo.asunto, text: correo.texto, html: correo.html, attachments: [logo],
      });
    },
    async avisarIntentoDeRegistro(destino) {
      const correo = correoDeIntentoDeRegistro({ destino, ahoraMs: Date.now() });
      await transporte.sendMail({
        from: de,
        to: destino,
        subject: correo.asunto,
        text: correo.texto,
        html: correo.html,
        attachments: [logo],
      });
    },
  };
}
