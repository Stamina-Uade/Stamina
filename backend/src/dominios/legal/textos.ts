/**
 * dominios/legal/textos.ts — el aviso de salud y los términos, y su versión.
 *
 * 🛑 Existe por un motivo concreto, y no es mostrar texto: **lo que se guarda
 * cuando alguien acepta es la VERSIÓN**. Un registro que dice "aceptó los
 * términos" y no dice cuáles no sirve para nada el día que haga falta: los
 * términos cambiaron tres veces desde entonces. Guardar la versión sólo tiene
 * sentido si la versión vive pegada al texto, y por eso los dos están en
 * `shared/datos/textos-legales.json` y no en un `strings.xml` del teléfono.
 *
 * El otro motivo es poder cambiar el texto sin publicar una versión nueva en la
 * tienda. Un aviso legal que tarda una semana en corregirse porque hay que pasar
 * por revisión de Google es un aviso legal que se queda mal escrito.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * LOS TEXTOS NO ESTÁN ACÁ, y hoy están los dos en "borrador": los escribió un
 * agente a pedido de Iván, con el encargo de escribir "los que creas mejor, por
 * ahora". **Ningún abogado los miró**, y faltan la razón social, el domicilio y
 * la jurisdicción, que están como `{{EMPRESA}}`, `{{DOMICILIO}}` y
 * `{{JURISDICCION}}` sin completar — poner una jurisdicción inventada es peor
 * que no poner ninguna.
 *
 * Por eso [verificarParaProduccion] HACE FALLAR EL ARRANQUE en producción
 * mientras quede uno en borrador, igual que los guardarraíles de nutrición.
 * ────────────────────────────────────────────────────────────────────────────
 */
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export type EstadoLegal = "borrador" | "revisado";

interface TextoLegal {
  estado: EstadoLegal;
  revisado_por: string | null;
  revisado_en: string | null;
  titulo: string;
  aceptacion: string;
}

interface Archivo {
  _meta: { version: string; fecha: string };
  textos: Record<string, TextoLegal>;
}

/** Igual que en `guardarrailes.ts`: se busca subiendo, porque el compilado queda en dist/src/… */
function buscarArchivo(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 8; i++) {
    const c = join(dir, "shared/datos/textos-legales.json");
    if (existsSync(c)) return c;
    const arriba = dirname(dir);
    if (arriba === dir) break;
    dir = arriba;
  }
  throw new Error("legal: no encontré shared/datos/textos-legales.json");
}

let cache: Archivo | null = null;
export function cargar(): Archivo {
  if (cache === null) cache = JSON.parse(readFileSync(buscarArchivo(), "utf8")) as Archivo;
  return cache;
}

/** Sólo para tests: vuelve a leer el archivo. */
export function olvidarCache(): void {
  cache = null;
}

/**
 * La versión que se guarda cuando alguien acepta.
 *
 * 🛑 Es la del archivo, no una constante de acá: si alguien edita el texto y se
 * olvida de subir la versión, las aceptaciones nuevas quedan apuntando al texto
 * viejo. Eso lo detecta [verificarParaProduccion] leyendo el archivo, no esto.
 */
export function versionLegal(): string {
  return cargar()._meta.version;
}

/** Los que todavía no revisó nadie. */
export function borradores(): string[] {
  return Object.entries(cargar().textos)
    .filter(([, t]) => t.estado !== "revisado")
    .map(([nombre]) => nombre);
}

/** Los huecos que quedaron sin completar en el texto. */
export function huecosSinCompletar(): string[] {
  const crudo = readFileSync(buscarArchivo(), "utf8");
  return [...new Set([...crudo.matchAll(/\{\{([A-Z_]+)\}\}/g)].map((m) => m[1] as string))];
}

/**
 * En producción, el proceso NO levanta con un texto legal en borrador ni con un
 * hueco sin completar. En desarrollo avisa y sigue.
 */
export function verificarParaProduccion(esProduccion: boolean, avisar: (m: string) => void): void {
  const pendientes = borradores();
  const huecos = huecosSinCompletar();

  if (!esProduccion) {
    if (pendientes.length > 0) {
      avisar(
        `⚠️  ${pendientes.length} texto(s) legal(es) EN BORRADOR: ${pendientes.join(", ")}. ` +
          `Los escribió un agente; ningún abogado los miró. Arranca igual porque no es producción.`
      );
    }
    if (huecos.length > 0) {
      avisar(`⚠️  Textos legales con huecos sin completar: ${huecos.join(", ")}.`);
    }
    return;
  }

  const problemas: string[] = [];
  if (pendientes.length > 0) {
    problemas.push(
      `hay ${pendientes.length} texto(s) en "borrador": ${pendientes.join(", ")}. ` +
        `Los escribió un agente a pedido de Iván; NINGÚN ABOGADO LOS REVISÓ.`
    );
  }
  if (huecos.length > 0) {
    problemas.push(
      `quedan huecos sin completar: ${huecos.join(", ")}. ` +
        `Una jurisdicción o una razón social inventada es peor que ninguna.`
    );
  }

  if (problemas.length > 0) {
    throw new Error(
      "🛑 No arranco en producción: " +
        problemas.join(" Y además, ") +
        " Para destrabarlo: revisar shared/datos/textos-legales.json, poner cada 'estado' en " +
        "'revisado' con quién y cuándo, y completar los huecos."
    );
  }
}
