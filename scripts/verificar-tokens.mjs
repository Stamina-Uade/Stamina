#!/usr/bin/env node
/**
 * scripts/verificar-tokens.mjs — el guardián de AGENTS.md §10.1.
 *
 * > "REGLA: ningún color, tamaño, radio ni fuente se escribe a mano en una
 * >  pantalla. Todo sale de los tokens. Un `#FF5722` suelto en un `.kt` es el
 * >  principio de que Android e iOS dejen de parecerse, y nadie lo va a ver hasta
 * >  tener las dos capturas al lado."
 *
 * Esa regla, sin algo que la haga fallar, dura hasta el primer viernes a las siete
 * de la tarde. Esto la hace fallar. Corre en CI y a mano:
 *
 *     node scripts/verificar-tokens.mjs            # el repo
 *     node scripts/verificar-tokens.mjs <ruta...>  # archivos sueltos
 *
 * Sale con código 1 si encuentra una violación. Sin argumentos de escape: si algo
 * tiene que quedar afuera, se agrega a EXCLUIDOS con el motivo escrito, no con un
 * comentario mágico en la línea.
 */
import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join, relative, resolve, dirname, sep } from "node:path";
import { fileURLToPath } from "node:url";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** Carpetas que se miran. */
const RAICES = ["android", "ios"];

/**
 * Lo que queda afuera, con el motivo. Una exclusión sin motivo es una regla
 * apagada que nadie va a volver a prender.
 */
const EXCLUIDOS = [
  {
    patron: "TokensGenerados",
    motivo: "es el archivo GENERADO desde tokens.json: es el único lugar donde los valores pueden estar escritos",
  },
  {
    // OJO: es `src/main/java`, no `android/app/` entero. La exclusión se achicó el
    // 2026-09-08 al empezar la UI nueva.
    patron: `android${sep}app${sep}src${sep}main${sep}java${sep}`,
    motivo:
      "es la UI Android original, que se DESCARTA entera en la fase 6 (AGENTS.md §1.2). " +
      "Está llena de valores a mano y arreglarla sería trabajo tirado. " +
      "🛑 Esta exclusión se BORRA en el mismo commit que borra esa carpeta. " +
      "La UI NUEVA vive en android/app/src/main/kotlin/ y SÍ se verifica: si estuviera " +
      "excluida toda la app, el guardián no miraría ni una pantalla de las que se están " +
      "escribiendo, que es justo para lo que existe.",
  },
  {
    patron: `android${sep}app${sep}src${sep}test${sep}`,
    motivo:
      "son los tests unitarios de la lógica de dominio original (§1.2: la lógica se " +
      "conserva y se porta). No pintan nada.",
  },
  {
    patron: `android${sep}app${sep}src${sep}androidTest${sep}`,
    motivo: "test instrumentado heredado del template. No pinta nada.",
  },
  { patron: `${sep}build${sep}`, motivo: "artefactos de compilación" },
  { patron: `${sep}.gradle${sep}`, motivo: "artefactos de Gradle" },
];

const EXTENSIONES = [".kt", ".kts", ".swift"];

/**
 * Las reglas. `nivel: "error"` corta el CI; `nivel: "aviso"` sólo informa.
 *
 * Hoy son todas error. Si alguna vez hace falta bajar una a aviso, el motivo va
 * escrito acá al lado, no en la cabeza de nadie.
 */
const REGLAS = [
  {
    id: "color-a-mano",
    nivel: "error",
    // #RGB, #RRGGBB, #AARRGGBB y el 0xAARRGGBB de Compose
    regex: /(?:#[0-9A-Fa-f]{3,8}\b|\bColor\s*\(\s*0x[0-9A-Fa-f]{6,8}\b)/g,
    mensaje: "color escrito a mano. Sale de TokensColor (shared/design/tokens.json).",
  },
  {
    id: "tamano-a-mano",
    nivel: "error",
    // 12.dp, 13.5.sp, .dp de un literal. NO matchea variable.dp.
    regex: /(?<![A-Za-z0-9_.])\d+(?:\.\d+)?\.(?:dp|sp)\b/g,
    mensaje: "tamaño escrito a mano. Sale de TokensEspaciado, TokensRadio, TokensTamano o TokensTipografia.",
  },
  {
    id: "fuente-a-mano",
    nivel: "error",
    regex: /\b(?:FontFamily\s*\(|Font\s*\(\s*name\s*:|\.font\s*\(\s*\.custom\s*\()/g,
    mensaje: "familia tipográfica a mano. Sale de los tokens (tipografia.familia).",
  },
  {
    id: "peso-a-mano",
    nivel: "error",
    regex: /\bFontWeight\s*\(\s*\d+\s*\)/g,
    mensaje: "peso tipográfico a mano. Sale de TokensTipografia.",
  },
  {
    id: "objetivo-tactil",
    nivel: "error",
    // Un tamaño mínimo de control escrito a mano: aunque salga de un token, el
    // mínimo es UNO y está en TokensTamano.objetivoTactilMinimo.
    regex: /\b(?:minimumInteractiveComponentSize|defaultMinSize)\s*\(\s*\d/g,
    mensaje: "objetivo táctil a mano. Es TokensTamano.objetivoTactilMinimo (48 dp), sin excepciones.",
  },
];

/** Lo que está en un comentario no cuenta: un hex ahí es documentación, no UI. */
function despejarComentariosYTexto(linea) {
  return linea.replace(/\/\/.*$/, "").replace(/\/\*.*?\*\//g, "");
}

function excluido(rutaRelativa) {
  return EXCLUIDOS.find((e) => rutaRelativa.includes(e.patron));
}

function* archivos(dir) {
  let entradas;
  try {
    entradas = readdirSync(dir);
  } catch {
    return;
  }
  for (const e of entradas) {
    const completo = join(dir, e);
    let st;
    try {
      st = statSync(completo);
    } catch {
      continue;
    }
    if (st.isDirectory()) {
      yield* archivos(completo);
    } else if (EXTENSIONES.some((x) => e.endsWith(x))) {
      yield completo;
    }
  }
}

export function revisarTexto(texto, rutaRelativa = "<memoria>") {
  const hallazgos = [];
  const lineas = texto.split("\n");
  for (let i = 0; i < lineas.length; i++) {
    const limpia = despejarComentariosYTexto(lineas[i]);
    if (limpia.trim() === "") continue;
    for (const regla of REGLAS) {
      regla.regex.lastIndex = 0;
      let m;
      while ((m = regla.regex.exec(limpia)) !== null) {
        hallazgos.push({
          archivo: rutaRelativa,
          linea: i + 1,
          regla: regla.id,
          nivel: regla.nivel,
          encontrado: m[0],
          mensaje: regla.mensaje,
        });
      }
    }
  }
  return hallazgos;
}

/**
 * El único archivo de Android donde puede haber un color escrito a mano, y los
 * únicos dos nombres que puede tener.
 *
 * Existe desde la decisión 0009: el acento de Android sale de `colors.xml` para que
 * cambiar el color del producto sea editar un hex y correr la app. Eso abre una
 * puerta que este guardián tenía cerrada, así que la puerta queda **vigilada**: un
 * `<color>` de más acá adentro es exactamente el basurero de colores sueltos que
 * §10.1 existe para evitar, y ahora entraría sin que nadie lo vea porque el resto
 * del guardián sólo mira `.kt` y `.swift`.
 */
const COLORES_DE_ANDROID = `android${sep}app${sep}src${sep}main${sep}res${sep}values${sep}colors.xml`;

const NOMBRES_PERMITIDOS = new Map([
  ["acento", "es LA fuente del color del producto en Android (decisión 0009)"],
  ["fondo_de_ventana", "es el fondo del instante previo al primer cuadro de Compose"],
]);

/**
 * Revisa que `colors.xml` siga teniendo sólo los colores que puede tener.
 *
 * Devuelve hallazgos con la misma forma que [revisarTexto], para que el comando los
 * imprima igual y no haya dos formatos de error.
 */
export function revisarColoresDeAndroid(texto, rutaRelativa = COLORES_DE_ANDROID) {
  const hallazgos = [];
  const encontrados = new Set();

  for (const m of texto.matchAll(/<color\s+name="([^"]+)"\s*>([^<]*)<\/color>/g)) {
    const [, nombre, valor] = m;
    const linea = texto.slice(0, m.index).split("\n").length;
    encontrados.add(nombre);

    if (!NOMBRES_PERMITIDOS.has(nombre)) {
      hallazgos.push({
        archivo: rutaRelativa,
        linea,
        regla: "color-suelto-en-android",
        nivel: "error",
        encontrado: nombre,
        mensaje:
          "color de más en colors.xml. Acá van SÓLO el acento y el fondo de ventana; " +
          "el resto de la paleta sale de shared/design/tokens.json.",
      });
    }
    if (!/^#[0-9A-Fa-f]{6,8}$/.test(valor.trim())) {
      hallazgos.push({
        archivo: rutaRelativa,
        linea,
        regla: "color-mal-escrito",
        nivel: "error",
        encontrado: valor.trim(),
        mensaje: `«${nombre}» tiene que ser un hex de 6 u 8 dígitos, con el numeral.`,
      });
    }
  }

  for (const [nombre, motivo] of NOMBRES_PERMITIDOS) {
    if (!encontrados.has(nombre)) {
      hallazgos.push({
        archivo: rutaRelativa,
        linea: 1,
        regla: "color-que-falta",
        nivel: "error",
        encontrado: nombre,
        mensaje: `falta «${nombre}» y hace falta: ${motivo}.`,
      });
    }
  }
  return hallazgos;
}

export function revisarRepo(rutas) {
  const objetivos =
    rutas.length > 0
      ? rutas.map((r) => resolve(r))
      : RAICES.map((r) => join(RAIZ, r)).filter((d) => existsSync(d)).flatMap((d) => [...archivos(d)]);

  const hallazgos = [];
  const saltados = new Map();
  let revisados = 0;

  for (const archivo of objetivos) {
    const rel = relative(RAIZ, archivo);
    const ex = excluido(rel);
    if (ex !== undefined) {
      saltados.set(ex.patron, (saltados.get(ex.patron) ?? 0) + 1);
      continue;
    }
    revisados++;
    hallazgos.push(...revisarTexto(readFileSync(archivo, "utf8"), rel));
  }

  // El `colors.xml` de Android no entra por `EXTENSIONES` —si mirara .xml, se
  // quejaría de los 40 drawables vectoriales, que tienen su color adentro por
  // definición—, así que se revisa aparte y siempre que se revise el repo entero.
  if (rutas.length === 0) {
    const completo = join(RAIZ, COLORES_DE_ANDROID);
    if (existsSync(completo)) {
      revisados++;
      hallazgos.push(...revisarColoresDeAndroid(readFileSync(completo, "utf8")));
    }
  }

  return { hallazgos, revisados, saltados };
}

// --------------------------------------------------------------- como comando --
if (process.argv[1] && process.argv[1].endsWith("verificar-tokens.mjs")) {
  const { hallazgos, revisados, saltados } = revisarRepo(process.argv.slice(2));
  const errores = hallazgos.filter((h) => h.nivel === "error");
  const avisos = hallazgos.filter((h) => h.nivel === "aviso");

  for (const h of hallazgos) {
    const etiqueta = h.nivel === "error" ? "ERROR" : "aviso";
    console.log(`${etiqueta} ${h.archivo}:${h.linea}  [${h.regla}]  «${h.encontrado}»\n      ${h.mensaje}`);
  }

  console.log(`\n[verificar-tokens] ${revisados} archivo(s) revisado(s).`);
  for (const [patron, n] of saltados) {
    const motivo = EXCLUIDOS.find((e) => e.patron === patron)?.motivo ?? "";
    console.log(`[verificar-tokens] ${n} salteado(s) por «${patron}»: ${motivo}`);
  }
  console.log(`[verificar-tokens] ${errores.length} error(es), ${avisos.length} aviso(s).`);

  if (errores.length > 0) {
    console.log(
      "\n🛑 AGENTS.md §10.1: ningún color, tamaño, radio ni fuente se escribe a mano en\n" +
        "   una pantalla. Todo sale de los tokens. Si falta un token, se agrega a\n" +
        "   shared/design/tokens.json y se regenera con `npm run generar:tema`.\n" +
        "   La única excepción es el acento de Android, que vive en\n" +
        "   android/app/src/main/res/values/colors.xml (decisión 0009)."
    );
    process.exit(1);
  }
}
