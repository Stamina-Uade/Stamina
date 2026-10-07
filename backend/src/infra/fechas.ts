/**
 * infra/fechas.ts — el día LOCAL de la persona.
 *
 * La API habla en milisegundos epoch (AGENTS.md §5), pero "el plan del martes" o
 * "lo que comí hoy" son días de calendario EN LA ZONA DE LA PERSONA: las 23:30 del
 * lunes en Buenos Aires ya es martes en UTC. Esta cuenta se hace acá y en ningún
 * otro lado, con la zona IANA del perfil y el Intl de Node, que trae los datos de
 * zonas completos.
 */

const formateadores = new Map<string, Intl.DateTimeFormat>();

function formateador(zona: string): Intl.DateTimeFormat {
  let f = formateadores.get(zona);
  if (f === undefined) {
    f = new Intl.DateTimeFormat("en-CA", {
      timeZone: zona,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    });
    formateadores.set(zona, f);
  }
  return f;
}

/** ¿Es una zona IANA que Node conoce? */
export function zonaValida(zona: string): boolean {
  try {
    formateador(zona);
    return true;
  } catch {
    return false;
  }
}

interface Partes {
  anio: number;
  mes: number;
  dia: number;
  hora: number;
  minuto: number;
  segundo: number;
}

function partes(ms: number, zona: string): Partes {
  const valor = (tipo: Intl.DateTimeFormatPartTypes): number => {
    const p = formateador(zona)
      .formatToParts(new Date(ms))
      .find((x) => x.type === tipo);
    return Number(p?.value ?? Number.NaN);
  };
  return {
    anio: valor("year"),
    mes: valor("month"),
    dia: valor("day"),
    hora: valor("hour"),
    minuto: valor("minute"),
    segundo: valor("second"),
  };
}

const dosDigitos = (n: number): string => String(n).padStart(2, "0");

/** "YYYY-MM-DD" del instante, en la zona. */
export function fechaLocal(ms: number, zona: string): string {
  const p = partes(ms, zona);
  return `${p.anio}-${dosDigitos(p.mes)}-${dosDigitos(p.dia)}`;
}

/** Cuánto está la zona adelante de UTC en ese instante, en ms. */
function desfaseMs(ms: number, zona: string): number {
  const p = partes(ms, zona);
  const comoSiFueraUtc = Date.UTC(p.anio, p.mes - 1, p.dia, p.hora, p.minuto, p.segundo);
  return comoSiFueraUtc - Math.floor(ms / 1000) * 1000;
}

/**
 * El instante de las 00:00 locales de una fecha "YYYY-MM-DD".
 *
 * Se parte de la medianoche UTC y se corrige por el desfase de la zona. Son dos
 * pasadas porque el desfase puede cambiar justo ahí (horario de verano): la segunda
 * usa el desfase del instante ya corregido.
 */
export function inicioDelDiaMs(fecha: string, zona: string): number {
  const [anio, mes, dia] = fecha.split("-").map(Number) as [number, number, number];
  const utc = Date.UTC(anio, mes - 1, dia);
  const primera = utc - desfaseMs(utc, zona);
  return utc - desfaseMs(primera, zona);
}

/**
 * "YYYY-MM-DD" de una fecha SIN HORA —nacimiento, fecha de la carrera—, leída en UTC.
 *
 * Los clientes las mandan como la medianoche UTC del día elegido (docs/API.md §1).
 * Leerlas en la zona de la persona las corría un día para atrás en toda América: la
 * medianoche UTC del 15 es el 14 a las 21:00 en Buenos Aires, y el plan ponía la
 * carrera el día anterior. En UTC, además, viajar no le mueve el cumpleaños a nadie.
 */
export function fechaUTC(ms: number): string {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${dosDigitos(d.getUTCMonth() + 1)}-${dosDigitos(d.getUTCDate())}`;
}

/** Años cumplidos a una fecha local. El nacimiento es una fecha sin hora: se lee en UTC. */
export function edadEn(nacimientoMs: number, fecha: string): number {
  const nac = fechaUTC(nacimientoMs);
  const [an, mn, dn] = nac.split("-").map(Number) as [number, number, number];
  const [a, m, d] = fecha.split("-").map(Number) as [number, number, number];
  let edad = a - an;
  if (m < mn || (m === mn && d < dn)) edad -= 1;
  return edad;
}

/** Suma días a una fecha "YYYY-MM-DD". Aritmética de calendario, sin zona. */
export function sumarDias(fecha: string, dias: number): string {
  const [anio, mes, dia] = fecha.split("-").map(Number) as [number, number, number];
  const d = new Date(Date.UTC(anio, mes - 1, dia + dias));
  return `${d.getUTCFullYear()}-${dosDigitos(d.getUTCMonth() + 1)}-${dosDigitos(d.getUTCDate())}`;
}

/** Días entre dos fechas "YYYY-MM-DD" (b - a). */
export function diasEntre(a: string, b: string): number {
  const aMs = Date.parse(`${a}T00:00:00Z`);
  const bMs = Date.parse(`${b}T00:00:00Z`);
  return Math.round((bMs - aMs) / 86_400_000);
}
