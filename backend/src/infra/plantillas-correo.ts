/**
 * infra/plantillas-correo.ts — cómo se ven los correos de Stamina.
 *
 * Una tarjeta blanca centrada sobre gris, con el ícono y el nombre arriba, el
 * saludo, un recuadro con el dato importante y la letra chica abajo. En los
 * correos de código el recuadro lleva SÓLO el código, centrado y de todo el ancho
 * (decisión de Iván del 2026-10-23); en los avisos, un título y sus filas.
 *
 * Todos empiezan con "Hola" y el nombre de pila ("Hola Iván,"), o "¡Hola!" sin
 * nombre, y salen en el idioma de la persona (es, en o fr: infra/idioma.ts).
 * El rosa es el de la app (#FF23A7); para TEXTO rosa sobre blanco se usa el rosa
 * oscuro (#C8007F), que es el que pasa contraste AA. Igual que en la landing.
 *
 * Reglas de HTML de correo, que no son las de la web:
 *   - tablas y estilos EN LÍNEA: Gmail y Outlook tiran el <style> o lo recortan
 *   - nada de fuentes web, ni flex, ni grid, ni imágenes de fondo
 *   - siempre una versión en texto plano al lado (la usan los lectores de
 *     pantalla, los relojes y los filtros de spam)
 *
 * Los textos en español van de "tú" (contrato 1.6.0, decisión de Iván del
 * 2026-10-22: la app entera pasó del voseo al tuteo), el inglés es neutro y el
 * francés tutea. Sin emojis, y sin nombrar otras marcas que Google y Apple donde
 * hacen falta (la vinculación).
 *
 * 🛑 Todo lo que viene de afuera (el nombre) se ESCAPA. Un nombre como
 * `<a href=…>` no puede convertirse en un enlace dentro de un correo nuestro.
 */

import type { IdiomaDeCorreo } from "./idioma.js";

export const CID_LOGO = "logo-stamina@stamina.com.ar";

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
    /** Sin título, el recuadro es sólo el código. */
    titulo?: string;
    /** El código grande, centrado. Si falta, el recuadro sólo lleva filas. */
    codigo?: string;
    filas: Fila[];
  };
  /** Letra chica: si no fuiste tú, etc. */
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
  const titulo = p.recuadro.titulo === undefined ? "" : `
              <tr><td style="padding:0 0 12px 0;font:700 15px/20px ${FUENTE};color:${C.rosaTinta};border-bottom:1px solid ${C.rosaBorde};">${escaparHtml(p.recuadro.titulo)}</td></tr>
              <tr><td style="height:14px;line-height:14px;font-size:0;">&nbsp;</td></tr>`;
  // El letter-spacing también se agrega después de la última letra: el padding de
  // la izquierda lo compensa, para que el código quede centrado de verdad.
  const codigo = p.recuadro.codigo === undefined ? "" : `
              <tr><td align="center" style="padding:4px 0 20px 8px;text-align:center;">
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
${titulo}${codigo}${p.recuadro.filas.map(filaHtml).join("")}
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
    ...(p.recuadro.titulo !== undefined && p.recuadro.codigo !== undefined
      ? [`${p.recuadro.titulo}: ${p.recuadro.codigo}`]
      : [p.recuadro.titulo, p.recuadro.codigo].filter((x): x is string => x !== undefined)),
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

/** "Hola Iván," o "¡Hola!": el saludo de todos los correos, con el nombre de pila. */
export function saludo(nombre: string | null, idioma: IdiomaDeCorreo = "es"): string {
  const t = { es: ["Hola", "¡Hola!"], en: ["Hi", "Hi!"], fr: ["Bonjour", "Bonjour !"] }[idioma];
  return nombre === null ? t[1]! : `${t[0]} ${nombre},`;
}

const CODIGO: Record<IdiomaDeCorreo, {
  previa: (codigo: string, min: number) => string;
  registro: { asunto: (codigo: string) => string; parrafo: (min: number) => string; nota: string };
  recuperacion: { asunto: (codigo: string) => string; parrafo: (min: number) => string; nota: string };
  alerta: string;
}> = {
  es: {
    previa: (c, m) => `Tu código es ${c}. Vence en ${m} minutos.`,
    registro: {
      asunto: (c) => `${c} es tu código de verificación de Stamina`,
      parrafo: (m) => `Ya casi está. Ingresa este código en la app para validar tu correo y crear tu cuenta de <strong>Stamina</strong>. Vence en ${m} minutos.`,
      nota: "Si no fuiste tú, puedes ignorar este mensaje: sin el código no se crea ninguna cuenta.",
    },
    recuperacion: {
      asunto: (c) => `${c} es tu código para cambiar la contraseña de Stamina`,
      parrafo: (m) => `Recibimos un pedido para cambiar la contraseña de tu cuenta de <strong>Stamina</strong>. Ingresa este código en la app para seguir. Vence en ${m} minutos.`,
      nota: "Si no fuiste tú, puedes ignorar este mensaje: tu contraseña sigue siendo la misma.",
    },
    alerta: "Nunca te vamos a pedir este código por teléfono, chat ni redes. No se lo pases a nadie.",
  },
  en: {
    previa: (c, m) => `Your code is ${c}. It expires in ${m} minutes.`,
    registro: {
      asunto: (c) => `${c} is your Stamina verification code`,
      parrafo: (m) => `Almost there. Enter this code in the app to verify your email and create your <strong>Stamina</strong> account. It expires in ${m} minutes.`,
      nota: "If it wasn't you, you can ignore this message: no account is created without the code.",
    },
    recuperacion: {
      asunto: (c) => `${c} is your code to change your Stamina password`,
      parrafo: (m) => `We received a request to change the password of your <strong>Stamina</strong> account. Enter this code in the app to continue. It expires in ${m} minutes.`,
      nota: "If it wasn't you, you can ignore this message: your password stays the same.",
    },
    alerta: "We will never ask you for this code by phone, chat or social media. Don't share it with anyone.",
  },
  fr: {
    previa: (c, m) => `Ton code est ${c}. Il expire dans ${m} minutes.`,
    registro: {
      asunto: (c) => `${c} est ton code de vérification Stamina`,
      parrafo: (m) => `Tu y es presque. Saisis ce code dans l'app pour valider ton e-mail et créer ton compte <strong>Stamina</strong>. Il expire dans ${m} minutes.`,
      nota: "Si ce n'était pas toi, tu peux ignorer ce message : sans le code, aucun compte n'est créé.",
    },
    recuperacion: {
      asunto: (c) => `${c} est ton code pour changer ton mot de passe Stamina`,
      parrafo: (m) => `Nous avons reçu une demande pour changer le mot de passe de ton compte <strong>Stamina</strong>. Saisis ce code dans l'app pour continuer. Il expire dans ${m} minutes.`,
      nota: "Si ce n'était pas toi, tu peux ignorer ce message : ton mot de passe reste le même.",
    },
    alerta: "Nous ne te demanderons jamais ce code par téléphone, chat ou réseaux sociaux. Ne le donne à personne.",
  },
};

/**
 * El código para crear la cuenta o para cambiar la contraseña. El recuadro lleva
 * SÓLO el código: sin título y sin filas (el vencimiento va en el párrafo).
 */
export function correoDeCodigo(opciones: {
  codigo: string;
  proposito: Proposito;
  nombre: string | null;
  idioma?: IdiomaDeCorreo;
  vidaMin: number;
}): { asunto: string; html: string; texto: string } {
  const idioma = opciones.idioma ?? "es";
  const t = CODIGO[idioma];
  const caso = t[opciones.proposito];
  const piezas: Piezas = {
    idioma,
    previa: t.previa(opciones.codigo, opciones.vidaMin),
    saludo: saludo(opciones.nombre, idioma),
    parrafos: [caso.parrafo(opciones.vidaMin)],
    recuadro: { codigo: opciones.codigo, filas: [] },
    notas: [caso.nota],
    alerta: t.alerta,
  };
  return { asunto: caso.asunto(opciones.codigo), html: armarHtml(piezas), texto: armarTexto(piezas) };
}

/**
 * Desde dónde se entró: lo que llevan "Nuevo inicio de sesión" y "Cuenta conectada
 * con Google/Apple". Lo que no se sabe no se pone (nunca una fila con un guion).
 */
export interface AvisoDeAcceso {
  nombre: string | null;
  idioma: IdiomaDeCorreo;
  ip: string;
  /** "Ciudad, País". Hoy siempre null: ver dominios/auth/dispositivos.ts. */
  ubicacion?: string | null;
  /** "iPhone 16 · iOS 26.5" */
  dispositivo: string | null;
  ahoraMs: number;
}

const ACCESO: Record<IdiomaDeCorreo, { ip: string; ubicacion: string; dispositivo: string; hora: string; siFuisteTu: string }> = {
  es: { ip: "Dirección IP", ubicacion: "Ubicación", dispositivo: "Dispositivo", hora: "Hora", siFuisteTu: "Si fuiste tú, no hace falta que hagas nada." },
  en: { ip: "IP address", ubicacion: "Location", dispositivo: "Device", hora: "Time", siFuisteTu: "If it was you, there is nothing else to do." },
  fr: { ip: "Adresse IP", ubicacion: "Localisation", dispositivo: "Appareil", hora: "Heure", siFuisteTu: "Si c'était toi, tu n'as rien d'autre à faire." },
};

function filasDeAcceso(a: AvisoDeAcceso): Fila[] {
  const t = ACCESO[a.idioma];
  return [
    ...(a.ip ? [{ etiqueta: t.ip, valor: a.ip }] : []),
    ...(a.ubicacion ? [{ etiqueta: t.ubicacion, valor: a.ubicacion }] : []),
    ...(a.dispositivo ? [{ etiqueta: t.dispositivo, valor: a.dispositivo }] : []),
    { etiqueta: t.hora, valor: fechaLegible(a.ahoraMs, a.idioma) },
  ];
}

const NUEVO_INICIO: Record<IdiomaDeCorreo, { asunto: string; parrafo: string; titulo: string; alerta: string }> = {
  es: {
    asunto: "Nuevo inicio de sesión en tu cuenta de Stamina",
    parrafo: "Detectamos un inicio de sesión en tu cuenta de <strong>Stamina</strong> desde un dispositivo nuevo.",
    titulo: "Nuevo inicio de sesión",
    alerta: "Si no fuiste tú, cambia tu contraseña desde «¿Olvidaste tu contraseña?» en la app: al terminar, te ofrece cerrar las otras sesiones.",
  },
  en: {
    asunto: "New sign-in to your Stamina account",
    parrafo: "We detected a sign-in to your <strong>Stamina</strong> account from a new device.",
    titulo: "New sign-in",
    alerta: "If it wasn't you, change your password from “Forgot your password?” in the app: when you finish, it offers to sign out your other sessions.",
  },
  fr: {
    asunto: "Nouvelle connexion à ton compte Stamina",
    parrafo: "Nous avons détecté une connexion à ton compte <strong>Stamina</strong> depuis un nouvel appareil.",
    titulo: "Nouvelle connexion",
    alerta: "Si ce n'était pas toi, change ton mot de passe depuis « Mot de passe oublié ? » dans l'app : à la fin, elle te propose de fermer les autres sessions.",
  },
};

/** Se entró a la cuenta desde un dispositivo que nunca había estado en ella (1.7.0). */
export function correoDeNuevoInicio(a: AvisoDeAcceso): { asunto: string; html: string; texto: string } {
  const t = NUEVO_INICIO[a.idioma];
  const piezas: Piezas = {
    idioma: a.idioma,
    previa: desescaparHtml(t.parrafo.replace(/<[^>]+>/g, "")),
    saludo: saludo(a.nombre, a.idioma),
    parrafos: [t.parrafo],
    recuadro: { titulo: t.titulo, filas: filasDeAcceso(a) },
    notas: [ACCESO[a.idioma].siFuisteTu],
    alerta: t.alerta,
  };
  return { asunto: t.asunto, html: armarHtml(piezas), texto: armarTexto(piezas) };
}

export function correoDeIntentoDeRegistro(opciones: { destino: string; ahoraMs: number }): {
  asunto: string; html: string; texto: string;
} {
  const piezas: Piezas = {
    previa: "Alguien intentó crear una cuenta de Stamina con tu correo.",
    saludo: "¡Hola!",
    parrafos: [
      "Alguien intentó crear una cuenta de <strong>Stamina</strong> con esta dirección, pero ya tienes una.",
    ],
    recuadro: {
      titulo: "Intento de registro",
      filas: [
        { etiqueta: "Correo", valor: opciones.destino },
        { etiqueta: "Fecha", valor: fechaLegible(opciones.ahoraMs) },
      ],
    },
    notas: [
      "Si fuiste tú, entra con tu contraseña, con Google o con Apple. Si la olvidaste, toca «¿Olvidaste tu contraseña?» en la app.",
      "Si no fuiste tú, no hace falta que hagas nada: tu cuenta sigue igual.",
    ],
  };
  return { asunto: "Intento de registro en Stamina", html: armarHtml(piezas), texto: armarTexto(piezas) };
}

const VINCULACION: Record<IdiomaDeCorreo, {
  asunto: (p: string) => string; parrafo: (p: string) => string; titulo: (p: string) => string; alerta: (p: string) => string;
}> = {
  es: {
    asunto: (p) => `Tu cuenta de Stamina se conectó con ${p}`,
    parrafo: (p) => `Tu cuenta de <strong>Stamina</strong> se conectó con ${p} con éxito.`,
    titulo: (p) => `Cuenta conectada con ${p}`,
    alerta: (p) => `Si no fuiste tú, cambia ya la contraseña de tu cuenta de ${p} y la de Stamina desde «¿Olvidaste tu contraseña?».`,
  },
  en: {
    asunto: (p) => `Your Stamina account was connected to ${p}`,
    parrafo: (p) => `Your <strong>Stamina</strong> account was successfully connected to ${p}.`,
    titulo: (p) => `Account connected to ${p}`,
    alerta: (p) => `If it wasn't you, change the password of your ${p} account and your Stamina password right away, from “Forgot your password?”.`,
  },
  fr: {
    asunto: (p) => `Ton compte Stamina a été connecté à ${p}`,
    parrafo: (p) => `Ton compte <strong>Stamina</strong> a bien été connecté à ${p}.`,
    titulo: (p) => `Compte connecté à ${p}`,
    alerta: (p) => `Si ce n'était pas toi, change tout de suite le mot de passe de ton compte ${p} et celui de Stamina depuis « Mot de passe oublié ? ».`,
  },
};

/** Se vinculó Google o Apple a una cuenta que ya existía: con el mismo recuadro que un inicio nuevo. */
export function correoDeVinculacion(opciones: AvisoDeAcceso & { proveedor: "google" | "apple" }): {
  asunto: string; html: string; texto: string;
} {
  const p = opciones.proveedor === "google" ? "Google" : "Apple";
  const t = VINCULACION[opciones.idioma];
  const piezas: Piezas = {
    idioma: opciones.idioma,
    previa: desescaparHtml(t.parrafo(p).replace(/<[^>]+>/g, "")),
    saludo: saludo(opciones.nombre, opciones.idioma),
    parrafos: [t.parrafo(p)],
    recuadro: { titulo: t.titulo(p), filas: filasDeAcceso(opciones) },
    notas: [ACCESO[opciones.idioma].siFuisteTu],
    alerta: t.alerta(p),
  };
  return { asunto: t.asunto(p), html: armarHtml(piezas), texto: armarTexto(piezas) };
}
