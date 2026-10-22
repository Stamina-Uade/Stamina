/**
 * infra/plantillas-correo.ts — cómo se ven los correos de Stamina.
 *
 * Una tarjeta blanca centrada sobre gris, con el ícono y el nombre arriba, el
 * saludo, un recuadro con el dato importante (el código) y la letra chica abajo.
 * El rosa es el de la app (#FF23A7); para TEXTO rosa sobre blanco se usa el rosa
 * oscuro (#C8007F), que es el que pasa contraste AA. Igual que en la landing.
 *
 * Reglas de HTML de correo, que no son las de la web:
 *   - tablas y estilos EN LÍNEA: Gmail y Outlook tiran el <style> o lo recortan
 *   - nada de fuentes web, ni flex, ni grid, ni imágenes de fondo
 *   - siempre una versión en texto plano al lado (la usan los lectores de
 *     pantalla, los relojes y los filtros de spam)
 *
 * 🛑 Todo lo que viene de afuera (el nombre) se ESCAPA. Un nombre como
 * `<a href=…>` no puede convertirse en un enlace dentro de un correo nuestro.
 */

import type { IdiomaDeCorreo } from "./idioma.js";

export const CID_LOGO = "logo-stamina@stamina.com.ar";

/** Adonde se escribe si algo no cierra. Es el contacto de los textos legales. */
export const CORREO_DE_CONTACTO = "support@stamina.com.ar";

/** Lo que va en todos los correos, en cada idioma. */
const PIE: Record<IdiomaDeCorreo, { lema: string; sinRespuesta: string }> = {
  es: {
    lema: "Stamina · Tu plan de running, a tu ritmo.",
    sinRespuesta: "Este correo se envió desde una dirección que no recibe respuestas.",
  },
  en: {
    lema: "Stamina · Your running plan, at your pace.",
    sinRespuesta: "This email was sent from an address that does not receive replies.",
  },
  fr: {
    lema: "Stamina · Ton plan de course, à ton rythme.",
    sinRespuesta: "Cet e-mail a été envoyé depuis une adresse qui ne reçoit pas de réponses.",
  },
};

const C = {
  fondo: "#F3F2F5",
  tarjeta: "#FFFFFF",
  borde: "#ECEAF0",
  tinta: "#1A0B2E",
  texto: "#3D3550",
  suave: "#7A7287",
  rosa: "#FF23A7",
  rosaTinta: "#C8007F",
  rosaSuave: "#FFF0F8",
  rosaBorde: "#FFD3EC",
} as const;

const FUENTE = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

export function escaparHtml(texto: string): string {
  return texto
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function desescaparHtml(texto: string): string {
  return texto
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&gt;/g, ">")
    .replace(/&lt;/g, "<")
    .replace(/&amp;/g, "&");
}

export interface Fila {
  etiqueta: string;
  valor: string;
}

interface Piezas {
  /** El idioma del correo: el `lang` del HTML y el pie. Sin él, español. */
  idioma?: IdiomaDeCorreo;
  /** Lo que se ve en la bandeja antes de abrirlo. */
  previa: string;
  saludo: string;
  parrafos: string[];
  recuadro: {
    titulo: string;
    /** El código grande. Si falta, el recuadro sólo lleva filas. */
    codigo?: string;
    filas: Fila[];
  };
  /** Letra chica: si no fuiste vos, etc. */
  notas: string[];
  /** La nota que se destaca en rosa (la de seguridad). */
  alerta?: string;
}

function filaHtml(f: Fila): string {
  return `
              <tr><td style="padding:0 0 4px 0;font:600 13px/18px ${FUENTE};color:${C.suave};">${escaparHtml(f.etiqueta)}</td></tr>
              <tr><td style="padding:0 0 16px 0;font:400 15px/22px ${FUENTE};color:${C.tinta};">${escaparHtml(f.valor)}</td></tr>`;
}

export function armarHtml(p: Piezas): string {
  const codigo = p.recuadro.codigo === undefined ? "" : `
              <tr><td style="padding:2px 0 18px 0;">
                <span style="display:inline-block;font:800 34px/40px 'SF Mono',Menlo,Consolas,'Courier New',monospace;letter-spacing:8px;color:${C.tinta};">${escaparHtml(p.recuadro.codigo)}</span>
              </td></tr>`;
  const parrafos = p.parrafos
    .map((t) => `<p style="margin:0 0 16px 0;font:400 16px/24px ${FUENTE};color:${C.texto};">${t}</p>`)
    .join("\n");
  const notas = p.notas
    .map((t) => `<p style="margin:0 0 12px 0;font:400 14px/22px ${FUENTE};color:${C.suave};">${escaparHtml(t)}</p>`)
    .join("\n");
  const alerta = p.alerta === undefined ? "" :
    `<p style="margin:0;font:600 14px/22px ${FUENTE};color:${C.rosaTinta};">${escaparHtml(p.alerta)}</p>`;

  const idioma = p.idioma ?? "es";
  return `<!doctype html>
<html lang="${idioma}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>Stamina</title>
</head>
<body style="margin:0;padding:0;background:${C.fondo};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${escaparHtml(p.previa)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${C.fondo};">
  <tr><td align="center" style="padding:32px 12px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background:${C.tarjeta};border:1px solid ${C.borde};border-radius:16px;">
      <tr><td align="center" style="padding:32px 24px 22px 24px;border-bottom:1px solid ${C.borde};">
        <img src="cid:${CID_LOGO}" width="56" height="56" alt="" style="display:block;width:56px;height:56px;border:0;border-radius:13px;">
        <div style="padding-top:12px;font:800 26px/32px ${FUENTE};letter-spacing:-0.5px;color:${C.tinta};">Stamina</div>
        <div style="margin:10px auto 0 auto;width:36px;height:4px;line-height:4px;font-size:0;border-radius:2px;background:${C.rosa};">&nbsp;</div>
      </td></tr>
      <tr><td style="padding:28px 32px 8px 32px;">
        <p style="margin:0 0 16px 0;font:600 17px/24px ${FUENTE};color:${C.tinta};">${escaparHtml(p.saludo)}</p>
        ${parrafos}
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:4px 0 24px 0;background:${C.rosaSuave};border:1px solid ${C.rosaBorde};border-radius:12px;">
          <tr><td style="padding:20px 24px 4px 24px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr><td style="padding:0 0 12px 0;font:700 15px/20px ${FUENTE};color:${C.rosaTinta};border-bottom:1px solid ${C.rosaBorde};">${escaparHtml(p.recuadro.titulo)}</td></tr>
              <tr><td style="height:14px;line-height:14px;font-size:0;">&nbsp;</td></tr>${codigo}${p.recuadro.filas.map(filaHtml).join("")}
            </table>
          </td></tr>
        </table>
        ${notas}
        ${alerta}
      </td></tr>
      <tr><td style="padding:24px 32px 28px 32px;">
        <p style="margin:0;font:400 12px/18px ${FUENTE};color:${C.suave};">${escaparHtml(PIE[idioma].lema)}<br>${escaparHtml(PIE[idioma].sinRespuesta)}</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

export function armarTexto(p: Piezas): string {
  const filas = p.recuadro.filas.map((f) => `${f.etiqueta}: ${f.valor}`);
  return [
    `${p.saludo}`,
    "",
    // Los párrafos son HTML: sin etiquetas y sin entidades, para que el texto
    // plano diga "n'était" y no "n&#39;était".
    ...p.parrafos.map((t) => desescaparHtml(t.replace(/<[^>]+>/g, ""))),
    "",
    p.recuadro.codigo !== undefined ? `${p.recuadro.titulo}: ${p.recuadro.codigo}` : p.recuadro.titulo,
    ...filas,
    "",
    ...p.notas,
    ...(p.alerta !== undefined ? [p.alerta] : []),
    "",
    "Stamina",
  ].join("\n");
}

const FECHA: Record<IdiomaDeCorreo, { locale: string; zona: string }> = {
  es: { locale: "es-AR", zona: "hora de Argentina" },
  en: { locale: "en-US", zona: "Argentina time" },
  fr: { locale: "fr-FR", zona: "heure d'Argentine" },
};

/** "20 oct 2026, 19:13" en la hora de Argentina, que es donde está Stamina. */
export function fechaLegible(ms: number, idioma: IdiomaDeCorreo = "es"): string {
  const f = new Intl.DateTimeFormat(FECHA[idioma].locale, {
    timeZone: "America/Argentina/Buenos_Aires",
    day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit", hour12: false,
  });
  return `${f.format(new Date(ms)).replace(/\./g, "")} (${FECHA[idioma].zona})`;
}

export type Proposito = "registro" | "recuperacion";

export function correoDeCodigo(opciones: {
  codigo: string;
  proposito: Proposito;
  destino: string;
  nombre: string | null;
  ahoraMs: number;
  vidaMin: number;
}): { asunto: string; html: string; texto: string } {
  const esAlta = opciones.proposito === "registro";
  const piezas: Piezas = {
    previa: `Tu código es ${opciones.codigo}. Vence en ${opciones.vidaMin} minutos.`,
    saludo: opciones.nombre === null ? "¡Hola!" : `Hola ${opciones.nombre},`,
    parrafos: [
      esAlta
        ? "Ya casi está. Ingresá este código en la app para validar tu correo y crear tu cuenta de <strong>Stamina</strong>."
        : "Recibimos un pedido para cambiar la contraseña de tu cuenta de <strong>Stamina</strong>. Ingresá este código en la app para seguir.",
    ],
    recuadro: {
      titulo: esAlta ? "Tu código de verificación" : "Tu código para cambiar la contraseña",
      codigo: opciones.codigo,
      filas: [
        { etiqueta: "Correo", valor: opciones.destino },
        { etiqueta: "Vence", valor: `En ${opciones.vidaMin} minutos` },
        { etiqueta: "Pedido", valor: fechaLegible(opciones.ahoraMs) },
      ],
    },
    notas: [
      esAlta
        ? "Si no fuiste vos, podés ignorar este mensaje: sin el código no se crea ninguna cuenta."
        : "Si no fuiste vos, podés ignorar este mensaje: tu contraseña sigue siendo la misma.",
    ],
    alerta: "Nunca te vamos a pedir este código por teléfono, chat ni redes. No se lo pases a nadie.",
  };
  return {
    asunto: esAlta
      ? `${opciones.codigo} es tu código de Stamina`
      : `${opciones.codigo} es tu código para cambiar la contraseña de Stamina`,
    html: armarHtml(piezas),
    texto: armarTexto(piezas),
  };
}

export function correoDeIntentoDeRegistro(opciones: { destino: string; ahoraMs: number }): {
  asunto: string; html: string; texto: string;
} {
  const piezas: Piezas = {
    previa: "Alguien intentó crear una cuenta de Stamina con tu correo.",
    saludo: "¡Hola!",
    parrafos: [
      "Alguien intentó crear una cuenta de <strong>Stamina</strong> con esta dirección, pero ya tenés una.",
    ],
    recuadro: {
      titulo: "Intento de registro",
      filas: [
        { etiqueta: "Correo", valor: opciones.destino },
        { etiqueta: "Fecha", valor: fechaLegible(opciones.ahoraMs) },
      ],
    },
    notas: [
      "Si fuiste vos, entrá con tu contraseña, con Google o con Apple. Si te la olvidaste, tocá «¿Olvidaste tu contraseña?» en la app.",
      "Si no fuiste vos, no hace falta que hagas nada: tu cuenta sigue igual.",
    ],
  };
  return { asunto: "Intento de registro en Stamina", html: armarHtml(piezas), texto: armarTexto(piezas) };
}

export function correoDeVinculacion(opciones: { destino: string; proveedor: "google" | "apple"; ahoraMs: number }): {
  asunto: string; html: string; texto: string;
} {
  const nombre = opciones.proveedor === "google" ? "Google" : "Apple";
  const piezas: Piezas = {
    previa: `Ahora podés entrar a Stamina con ${nombre}.`,
    saludo: "¡Hola!",
    parrafos: [
      `Tu cuenta de <strong>Stamina</strong> ahora también se puede abrir con «Continuar con ${nombre}».`,
    ],
    recuadro: {
      titulo: "Nueva forma de entrar",
      filas: [
        { etiqueta: "Cuenta", valor: opciones.destino },
        { etiqueta: "Con", valor: nombre },
        { etiqueta: "Fecha", valor: fechaLegible(opciones.ahoraMs) },
      ],
    },
    notas: ["Si fuiste vos, no hace falta que hagas nada."],
    alerta: "Si no fuiste vos, cambiá ya la contraseña de tu cuenta de " + nombre + " y la de Stamina desde «¿Olvidaste tu contraseña?».",
  };
  return { asunto: `Ahora entrás a Stamina con ${nombre}`, html: armarHtml(piezas), texto: armarTexto(piezas) };
}

/**
 * El aviso de que la contraseña cambió (contrato 1.6.0). Sale SIEMPRE que se
 * cambia, en el idioma del pedido: desde la 1.6.0 cambiarla ya no cierra las
 * otras sesiones, así que este correo es lo que le permite al dueño enterarse si
 * no fue él.
 */
const CAMBIO_DE_PASSWORD: Record<IdiomaDeCorreo, {
  asunto: string; saludo: string; aviso: string; titulo: string;
  cuenta: string; fecha: string; contacto: string; nota: string;
}> = {
  es: {
    asunto: "Cambiaste la contraseña de Stamina",
    saludo: "¡Hola!",
    aviso: "Cambiaste la contraseña de tu cuenta de Stamina. Si no fuiste tú, escríbenos.",
    titulo: "Contraseña cambiada",
    cuenta: "Cuenta",
    fecha: "Fecha",
    contacto: "Escríbenos a",
    nota: "Si fuiste tú, no hace falta que hagas nada.",
  },
  en: {
    asunto: "Your Stamina password was changed",
    saludo: "Hi!",
    aviso: "You changed the password of your Stamina account. If it wasn't you, write to us.",
    titulo: "Password changed",
    cuenta: "Account",
    fecha: "Date",
    contacto: "Write to us at",
    nota: "If it was you, there is nothing else to do.",
  },
  fr: {
    asunto: "Tu as changé ton mot de passe Stamina",
    saludo: "Bonjour !",
    aviso: "Tu as changé le mot de passe de ton compte Stamina. Si ce n'était pas toi, écris-nous.",
    titulo: "Mot de passe changé",
    cuenta: "Compte",
    fecha: "Date",
    contacto: "Écris-nous à",
    nota: "Si c'était toi, tu n'as rien d'autre à faire.",
  },
};

export function correoDeCambioDePassword(opciones: { destino: string; idioma: IdiomaDeCorreo; ahoraMs: number }): {
  asunto: string; html: string; texto: string;
} {
  const t = CAMBIO_DE_PASSWORD[opciones.idioma];
  const piezas: Piezas = {
    idioma: opciones.idioma,
    previa: t.aviso,
    saludo: t.saludo,
    parrafos: [escaparHtml(t.aviso)],
    recuadro: {
      titulo: t.titulo,
      filas: [
        { etiqueta: t.cuenta, valor: opciones.destino },
        { etiqueta: t.fecha, valor: fechaLegible(opciones.ahoraMs, opciones.idioma) },
        { etiqueta: t.contacto, valor: CORREO_DE_CONTACTO },
      ],
    },
    notas: [t.nota],
  };
  return { asunto: t.asunto, html: armarHtml(piezas), texto: armarTexto(piezas) };
}
