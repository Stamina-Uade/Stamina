/**
 * scripts/test/entorno-local.test.mjs
 *
 * `backend/.env.example` y `backend/docker-compose.yml` tienen que decir lo mismo.
 *
 * Este test existe por un error real del 2026-09-08: el compose publicaba Postgres
 * en 5433 y Redis en 6380 —a propósito, para no chocar con otro proyecto— y el
 * .env.example seguía diciendo 5432 y 6379. Siguiendo el ejemplo, que es lo que uno
 * hace, Trainer se conectaba a la base de OTRO proyecto y escribía ahí. Nadie se
 * entera hasta que aparecen tablas raras en la base ajena.
 *
 * Es el mismo error que AGENTS.md §2.3.3 previene en el servidor —base propia y rol
 * propio, nunca la de HonneLink ni la de KARPLAST—, sólo que en local.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const ejemplo = readFileSync(resolve(raiz, "backend/.env.example"), "utf8");
const compose = readFileSync(resolve(raiz, "backend/docker-compose.yml"), "utf8");

/** Los puertos que el compose PUBLICA en la máquina, por servicio. */
function puertoPublicado(servicio) {
  const bloque = compose.split(new RegExp(`^\\s{2}${servicio}:`, "m"))[1];
  assert.ok(bloque, `no encontré el servicio "${servicio}" en docker-compose.yml`);
  const m = /-\s*"(?:127\.0\.0\.1:)?(\d+):\d+"/.exec(bloque);
  assert.ok(m, `el servicio "${servicio}" no publica ningún puerto`);
  return m[1];
}

test("el .env.example apunta al Postgres del compose y no a otro", () => {
  const delCompose = puertoPublicado("postgres");
  const m = /^DATABASE_URL=.*:(\d+)\//m.exec(ejemplo);
  assert.ok(m, "no encontré DATABASE_URL en .env.example");
  assert.equal(
    m[1],
    delCompose,
    `.env.example apunta al puerto ${m[1]} y el compose publica el ${delCompose}. ` +
      "Un puerto de más o de menos y Trainer escribe en la base de otro proyecto.",
  );
});

test("el .env.example apunta al Redis del compose y no a otro", () => {
  const delCompose = puertoPublicado("redis");
  const m = /^REDIS_URL=.*:(\d+)\s*$/m.exec(ejemplo);
  assert.ok(m, "no encontré REDIS_URL en .env.example");
  assert.equal(m[1], delCompose, `.env.example dice ${m[1]} y el compose publica ${delCompose}`);
});

test("el .env.example NO usa los puertos por defecto, que son de quien llegó primero", () => {
  // 5432 y 6379 son los puertos donde ya hay algo en casi cualquier máquina de
  // desarrollo. Que Trainer no los pida es la decisión, no un accidente.
  assert.doesNotMatch(ejemplo, /^DATABASE_URL=.*:5432\//m);
  assert.doesNotMatch(ejemplo, /^REDIS_URL=.*:6379\s*$/m);
});

test("Redis usa índice y prefijo propios (AGENTS.md 2.3.2)", () => {
  assert.match(ejemplo, /^REDIS_DB=\d+/m, "falta REDIS_DB");
  assert.match(ejemplo, /^REDIS_PREFIX=trainer:/m, "el prefijo tiene que ser trainer:");
  assert.doesNotMatch(ejemplo, /^REDIS_DB=0\s*$/m, "el 0 es la base de todos: Trainer usa la suya");
});

test("la base y el rol son propios, nunca los de otro proyecto", () => {
  assert.match(ejemplo, /^DATABASE_URL=postgres:\/\/trainer:[^@]+@[^/]+\/trainer_db/m);
});

test("los scripts del backend leen el .env sin romper produccion", () => {
  const pkg = JSON.parse(readFileSync(resolve(raiz, "backend/package.json"), "utf8"));
  for (const s of ["start", "migrar"]) {
    assert.match(
      pkg.scripts[s],
      /--env-file-if-exists=\.env/,
      `el script "${s}" tiene que leer el .env SI EXISTE: en produccion no hay archivo, ` +
        "las variables las inyecta systemd desde el gestor de secretos",
    );
  }
});

/**
 * Y el que faltaba: que los scripts que corren código COMPILADO apunten a donde
 * TypeScript lo deja de verdad.
 *
 * Existe por otro error real del 2026-09-08: `tsconfig.json` tiene `rootDir: "."`
 * e incluye `src/` y `test/`, así que la salida queda en `dist/src/…` — y
 * `npm start` decía `dist/index.js`. Nunca arrancó. No lo agarró nadie porque
 * `npm test` usa un glob (`dist/**\/*.test.js`) y ese sí encuentra los archivos.
 * El backend tenía 83 tests en verde y un `start` que no existía.
 */
test("los scripts apuntan a donde tsc deja los archivos, no a donde uno cree", () => {
  const tsconfig = JSON.parse(readFileSync(resolve(raiz, "backend/tsconfig.json"), "utf8"));
  const pkg = JSON.parse(readFileSync(resolve(raiz, "backend/package.json"), "utf8"));
  const outDir = tsconfig.compilerOptions.outDir;
  const rootDir = tsconfig.compilerOptions.rootDir;

  // Con rootDir "." la estructura de carpetas se conserva bajo outDir: src/ sigue
  // siendo src/. Con rootDir "src" no.
  const prefijo = rootDir === "." || rootDir === undefined ? `${outDir}/src/` : `${outDir}/`;

  for (const nombre of ["start", "migrar"]) {
    const script = pkg.scripts[nombre];
    const m = /\s(\S+\.js)(\s|$)/.exec(script);
    assert.ok(m, `el script "${nombre}" no corre ningún .js`);
    assert.ok(
      m[1].startsWith(prefijo),
      `"${nombre}" corre ${m[1]}, pero con rootDir "${rootDir}" y outDir "${outDir}" ` +
        `tsc deja los archivos en ${prefijo}… . Eso es un MODULE_NOT_FOUND al arrancar.`,
    );
  }
});

/**
 * Y el prefijo de versión.
 *
 * Tercer error real del mismo día: `openapi.yaml` declara `servers: .../v1` y el
 * backend registra todas sus rutas con `{ prefix: "/v1" }`, pero la base del
 * cliente Android decía `http://10.0.2.2:8082` a secas. Cada llamada se habría
 * llevado un `404 not_found` **con el sobre de error bien formado**, que es la
 * peor manera de fallar: parece que el servidor contestó que no.
 */
test("la base del cliente Android lleva el prefijo que declara el contrato", () => {
  const { parse } = require("yaml");
  const doc = parse(readFileSync(resolve(raiz, "shared/api/openapi.yaml"), "utf8"));
  const url = doc.servers?.[0]?.url;
  assert.ok(url, "el contrato no declara servers[0].url");
  const prefijo = new URL(url.replace("{host}", "ejemplo.invalid")).pathname.replace(/\/$/, "");
  assert.ok(prefijo.length > 0, "servers[0].url no tiene prefijo de ruta");

  const cliente = readFileSync(
    resolve(raiz, "android/core/src/main/kotlin/com/tecladus/trainer/core/red/ClienteApi.kt"),
    "utf8",
  );
  const m = /PREFIJO_DEL_CONTRATO\s*=\s*"([^"]+)"/.exec(cliente);
  assert.ok(m, "ClienteApi.kt no declara PREFIJO_DEL_CONTRATO");
  assert.equal(
    m[1],
    prefijo,
    `el contrato sirve en "${prefijo}" y el cliente usa "${m[1]}". ` +
      "Todas las llamadas se llevarian un 404.",
  );
  assert.match(
    cliente,
    /BASE_EN_EL_EMULADOR\s*=\s*"[^"]+"\s*\+\s*PREFIJO_DEL_CONTRATO/,
    "la base del emulador tiene que componerse con el prefijo, no repetirlo a mano",
  );
});

/** El backend tiene que registrar sus rutas con el MISMO prefijo. */
test("el backend registra sus rutas con el prefijo del contrato", () => {
  const { parse } = require("yaml");
  const doc = parse(readFileSync(resolve(raiz, "shared/api/openapi.yaml"), "utf8"));
  const prefijo = new URL(doc.servers[0].url.replace("{host}", "ejemplo.invalid")).pathname.replace(/\/$/, "");
  const servidor = readFileSync(resolve(raiz, "backend/src/servidor.ts"), "utf8");
  assert.ok(
    servidor.includes(`prefix: "${prefijo}"`),
    `servidor.ts tiene que registrar con { prefix: "${prefijo}" }`,
  );
});

/**
 * Las reglas de contrasena que la pantalla MUESTRA tienen que ser las que el
 * servidor aplica.
 *
 * Existe por un error que ya cometi: escribi "minimo 12 caracteres" en la
 * pantalla cuando el contrato decia 10. Nadie lo iba a notar mirandolo — habia
 * que abrir los dos archivos al mismo tiempo.
 *
 * La pantalla dibuja TRES reglas (tres barras, tres puntitos), y son estas:
 * largo minimo, una mayuscula, un numero. El servidor rechaza ademas por lista
 * de conocidas y por repeticion, pero esas dos NO se muestran, porque no se
 * pueden anticipar mientras alguien escribe.
 */
const RUTA_PANTALLA_CLAVE =
  "android/app/src/main/kotlin/com/tecladus/trainer/pantallas/acceso/ReglasDeClave.kt";

test("el minimo de contrasena de la pantalla es el del contrato y el del servidor", () => {
  const { parse } = require("yaml");
  const doc = parse(readFileSync(resolve(raiz, "shared/api/openapi.yaml"), "utf8"));
  const delContrato = doc.components?.schemas?.Password?.minLength;
  assert.equal(typeof delContrato, "number", "el contrato no declara Password.minLength");

  const servidor = readFileSync(resolve(raiz, "backend/src/infra/password.ts"), "utf8");
  const delServidor = /LARGO_MINIMO\s*=\s*(\d+)/.exec(servidor);
  assert.ok(delServidor, "password.ts no declara LARGO_MINIMO");
  assert.equal(
    Number(delServidor[1]),
    delContrato,
    `el contrato dice ${delContrato} y el servidor exige ${delServidor[1]}.`,
  );

  const pantalla = readFileSync(resolve(raiz, RUTA_PANTALLA_CLAVE), "utf8");
  const deLaPantalla = /LARGO_MINIMO_DE_CLAVE\s*=\s*(\d+)/.exec(pantalla);
  assert.ok(deLaPantalla, "ReglasDeClave.kt no declara LARGO_MINIMO_DE_CLAVE");
  assert.equal(
    Number(deLaPantalla[1]),
    delContrato,
    `el contrato pide ${delContrato} caracteres y la pantalla muestra ${deLaPantalla[1]}.`,
  );
});

/**
 * Si el servidor deja de exigir mayuscula o numero, la pantalla queda pidiendo de
 * mas: tres puntitos que no se pueden completar de otra forma, para una regla que
 * ya no existe. Y al reves, la pantalla deja pasar algo que el servidor rechaza.
 */
test("la pantalla y el servidor exigen las mismas tres reglas visibles", () => {
  const servidor = readFileSync(resolve(raiz, "backend/src/infra/password.ts"), "utf8");
  const pantalla = readFileSync(resolve(raiz, RUTA_PANTALLA_CLAVE), "utf8");

  for (const [que, enElServidor] of [
    ["mayuscula", /sin_mayuscula/],
    ["numero", /sin_numero/],
  ]) {
    assert.match(servidor, enElServidor, `el servidor ya no rechaza por falta de ${que}`);
  }

  // La pantalla las nombra por el mismo id que el motivo del servidor.
  for (const id of ["LARGO", "MAYUSCULA", "NUMERO"]) {
    assert.ok(
      pantalla.includes(id),
      `ReglasDeClave.kt no tiene la regla ${id}; la pantalla dibuja tres y son estas`,
    );
  }

  const cuantas = (pantalla.match(/ReglaDeClave\(/g) ?? []).length;
  assert.equal(
    cuantas,
    3,
    `la pantalla define ${cuantas} reglas y el diseno dibuja exactamente 3 barras y 3 puntitos.`,
  );
});

test("la cuenta regresiva para reenviar el codigo es la del servidor", () => {
  const servicio = readFileSync(resolve(raiz, "backend/src/dominios/auth/servicio.ts"), "utf8");
  const m = /REENVIO_MS\s*=\s*(\d+)\s*\*\s*1000/.exec(servicio);
  assert.ok(m, "servicio.ts no declara REENVIO_MS como <segundos> * 1000");

  const pantalla = readFileSync(
    resolve(
      raiz,
      "android/app/src/main/kotlin/com/tecladus/trainer/pantallas/acceso/PantallasDeRegistro.kt",
    ),
    "utf8",
  );
  const n = /SEGUNDOS_PARA_REENVIAR\s*=\s*(\d+)/.exec(pantalla);
  assert.ok(n, "PantallasDeRegistro.kt no declara SEGUNDOS_PARA_REENVIAR");
  assert.equal(
    Number(n[1]),
    Number(m[1]),
    `el servidor espera ${m[1]} s y la pantalla cuenta ${n[1]} s.`,
  );
});

/**
 * `npm run local` tiene que compilar ANTES de migrar y de arrancar.
 *
 * Esto existe por un error que ya paso: `npm start` no compila —corre lo que
 * quedo en dist/ de la ultima vez— asi que arrancar despues de bajarse cambios
 * levanta el servidor VIEJO. Y no falla: contesta bien, con las rutas de antes.
 * Es de los errores mas caros de encontrar, porque todo parece andar.
 *
 * El `&&` de adentro de un script de npm lo interpreta cmd.exe en Windows, no
 * PowerShell, asi que anda igual en PowerShell 5.1 — donde `&&` escrito a mano NO
 * anda. Ese es el otro motivo de que el comando exista.
 */
test("`npm run local` compila, migra, siembra el catálogo y arranca, en ese orden", () => {
  const pkg = JSON.parse(readFileSync(resolve(raiz, "backend/package.json"), "utf8"));
  const local = pkg.scripts?.local;
  assert.equal(typeof local, "string", "backend/package.json no declara el script `local`");

  const pasos = local.split("&&").map((p) => p.trim());
  assert.deepEqual(
    pasos,
    ["npm run build", "npm run migrar", "npm run sembrar", "npm start"],
    "`local` tiene que ser build, migrar, sembrar y start, en ese orden y sin saltear ninguno. " +
      "Sin sembrar, el catálogo está vacío y la rutina del día sale sin ejercicios.",
  );

  // Y `start` NO tiene que compilar por su cuenta: si lo hiciera, `local` estaria
  // compilando dos veces y el comentario de arriba seria mentira.
  assert.ok(
    !String(pkg.scripts?.start ?? "").includes("build"),
    "`start` compila: entonces `local` compila dos veces y este test sobra.",
  );
});

/**
 * La documentacion tiene que mandar al comando que anda, no al que rompe.
 */
test("README.md no le pide a nadie que escriba && en PowerShell", () => {
  const doc = readFileSync(resolve(raiz, "README.md"), "utf8");
  const bloques = [...doc.matchAll(/```powershell\n([\s\S]*?)```/g)].map((m) => m[1]);
  assert.ok(bloques.length > 0, "no encontre ningun bloque de powershell en el documento");
  for (const b of bloques) {
    assert.ok(
      !b.includes("&&"),
      `un bloque de powershell usa &&, que en PowerShell 5.1 no existe:\n${b}`,
    );
  }
});
