/**
 * dominios/plan/motor/fechas.ts — días del calendario, sin reloj.
 *
 * PORT LITERAL de la aritmética de java.time (LocalDate, DayOfWeek, ChronoUnit.DAYS) que usa
 * TrainingPlanGenerator.kt — constantes SIN VERIFICAR contra sus fuentes
 * (docs/PROPUESTA-MOTOR.md §2); acá no hay ninguna de entrenamiento, sólo calendario.
 *
 * Excepción a) del port: JavaScript no tiene LocalDate. Un día viaja como "YYYY-MM-DD" (la fecha
 * LOCAL de la persona, sin hora ni zona) y por dentro es un entero: días desde 1970-01-01, sacado
 * con Date.UTC. UTC no tiene horario de verano, así que un día son siempre 86 400 000 ms; con la
 * hora local, el día del cambio de horario sumar 24 h repite un día o se saltea uno.
 *
 * 🛑 El motor no lee el reloj: ni Date.now(), ni new Date() sin argumentos, ni Math.random.
 * El "hoy" del plan entra como parámetro (docs/PROPUESTA-MOTOR.md §1).
 */

const MS_POR_DIA = 86_400_000;
const FORMATO = /^(\d{4})-(\d{2})-(\d{2})$/;

/** "YYYY-MM-DD" → días desde 1970-01-01. RangeError si el texto no es una fecha que exista. */
export function aDia(fecha: string): number {
  const partes = FORMATO.exec(fecha);
  if (partes === null) throw new RangeError(`fecha inválida: "${fecha}" (se espera YYYY-MM-DD)`);
  const dia = Date.UTC(Number(partes[1]), Number(partes[2]) - 1, Number(partes[3])) / MS_POR_DIA;
  // Date.UTC no se queja: corre el 30 de febrero al 2 de marzo y lleva los años 0 a 99 al siglo
  // XX. Si la vuelta no da el mismo texto, la fecha no existía.
  if (aTexto(dia) !== fecha) throw new RangeError(`fecha inexistente: "${fecha}"`);
  return dia;
}

/** Días desde 1970-01-01 → "YYYY-MM-DD". */
export function aTexto(dia: number): string {
  const f = new Date(dia * MS_POR_DIA);
  const anio = String(f.getUTCFullYear()).padStart(4, "0");
  const mes = String(f.getUTCMonth() + 1).padStart(2, "0");
  const diaDelMes = String(f.getUTCDate()).padStart(2, "0");
  return `${anio}-${mes}-${diaDelMes}`;
}

/** DayOfWeek.value: 1 = lunes … 7 = domingo. El 1970-01-01 fue jueves (4). */
export function diaDeLaSemana(dia: number): number {
  return ((dia % 7) + 7 + 3) % 7 + 1;
}
