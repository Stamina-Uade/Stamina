/** Envío de desafíos de cuenta. El proveedor de log sólo se admite fuera de producción. */
import nodemailer from "nodemailer";
import type { Config } from "../config.js";

type Proposito = "registro" | "recuperacion";

export interface Correo {
  enviarCodigo(destino: string, codigo: string, proposito: Proposito, nombreCompleto?: string): Promise<void>;
  avisarIntentoDeRegistro(destino: string): Promise<void>;
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

  return {
    async enviarCodigo(destino, codigo, proposito, nombreCompleto) {
      const nombre = limpiarNombre(nombreCompleto);
      const saludo = nombre === null ? "Hola" : `Hola, ${nombre}`;
      const accion = proposito === "registro" ? "validar tu cuenta" : "recuperar tu contraseña";
      await transporte.sendMail({
        from: config.mailFrom,
        to: destino,
        subject: proposito === "registro" ? "Código para validar tu cuenta de Stamina" : "Código para recuperar tu contraseña de Stamina",
        text: `${saludo}:\n\nTu código para ${accion} es ${codigo}. Vence en 15 minutos.\n\nSi no lo pediste, ignorá este correo.\n\nStamina`,
      });
    },
    async avisarIntentoDeRegistro(destino) {
      await transporte.sendMail({
        from: config.mailFrom,
        to: destino,
        subject: "Intento de registro en Stamina",
        text: "Hola:\n\nAlguien intentó crear una cuenta de Stamina con esta dirección. Si fuiste vos, iniciá sesión. Si no, no hace falta hacer nada.\n\nStamina",
      });
    },
  };
}
