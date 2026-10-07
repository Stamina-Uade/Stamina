/**
 * scripts/test/perfil-contrato.test.mjs
 *
 * Las once pantallas de perfil escriben en `PATCH /me`, y los números con los que
 * validan —cuánto puede pesar alguien, cuántos caracteres entran en un nombre, qué
 * es un minuto del día válido— están escritos DOS veces: en
 * `shared/api/openapi.yaml` y en `DatosDePerfil.kt`. Este test los ata.
 *
 * No es simetría por gusto. Si el contrato sube el peso máximo a 500 kg y el
 * cliente sigue en 400, la pantalla rechaza un peso que el servidor acepta y no
 * hay forma de darse cuenta desde el teléfono: el botón simplemente no se prende.
 * Al revés es peor — el cliente deja pasar y el 400 llega después del viaje, con
 * un error genérico.
 *
 * Es el mismo mecanismo que `entorno-local.test.mjs` usa para el `.env` y el
 * compose, y el que ata las reglas de contraseña del cliente con las del servidor.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const contrato = parse(readFileSync(resolve(raiz, "shared/api/openapi.yaml"), "utf8"));
const entrada = contrato.components.schemas.PerfilEntrada.properties;
const dia = contrato.components.schemas.DiaEntrenamiento.properties;

const kotlinPerfil = readFileSync(
  resolve(raiz, "android/app/src/main/kotlin/com/tecladus/trainer/pantallas/acceso/DatosDePerfil.kt"),
  "utf8",
);
const kotlinRegistro = readFileSync(
  resolve(raiz, "android/app/src/main/kotlin/com/tecladus/trainer/pantallas/acceso/PantallasDeRegistro.kt"),
  "utf8",
);
const kotlinAcceso = readFileSync(
  resolve(raiz, "android/app/src/main/kotlin/com/tecladus/trainer/pantallas/acceso/FlujoDeAcceso.kt"),
  "utf8",
);
const modelos = readFileSync(
  resolve(raiz, "android/core/src/main/kotlin/com/tecladus/trainer/core/red/ModelosGenerados.kt"),
  "utf8",
);

/** El valor de un `const val NOMBRE = 123` de Kotlin, con o sin guiones bajos. */
function constante(fuente, nombre) {
  const m = new RegExp(`const val ${nombre}\\s*(?::\\s*\\w+)?\\s*=\\s*([0-9_]+)`).exec(fuente);
  assert.ok(m, `no encontré la constante ${nombre}`);
  return Number(m[1].replace(/_/g, ""));
}

test("los topes de peso del cliente son los del contrato", () => {
  assert.equal(constante(kotlinPerfil, "PESO_MINIMO_G"), entrada.weight_g.minimum);
  assert.equal(constante(kotlinPerfil, "PESO_MAXIMO_G"), entrada.weight_g.maximum);
});

test("los topes de altura del cliente son los del contrato", () => {
  assert.equal(constante(kotlinPerfil, "ALTURA_MINIMA_MM"), entrada.height_mm.minimum);
  assert.equal(constante(kotlinPerfil, "ALTURA_MAXIMA_MM"), entrada.height_mm.maximum);
});

/** La rama que no es `null` de un `oneOf: [algo, null]`. */
function ramaConValor(esquema) {
  if (!esquema.oneOf) return esquema;
  const sinNull = esquema.oneOf.filter((x) => x && x.type !== "null");
  assert.equal(sinNull.length, 1, "un oneOf de más de dos ramas no es un opcional");
  return sinNull[0];
}

test("el largo del nombre y el de la zona horaria son los del contrato", () => {
  assert.equal(constante(kotlinPerfil, "LARGO_MAXIMO_DEL_NOMBRE"), entrada.first_name.maxLength);
  assert.equal(constante(kotlinPerfil, "LARGO_MAXIMO_DE_ZONA"), entrada.timezone.maxLength);
  // El apellido se corta con la misma constante que el nombre: si el contrato los
  // separa algún día, esto avisa antes de que se corte de más.
  assert.equal(ramaConValor(entrada.last_name).maxLength, entrada.first_name.maxLength);
});

test("los dos campos que se pueden vaciar aceptan null, y el cliente los manda", () => {
  // 🛑 `PATCH /me` es parcial: una clave ausente deja el valor viejo. Borrar el
  // apellido o sacar la fecha de la carrera sólo se puede mandando null explícito,
  // y para eso el contrato tiene que aceptarlo. Si alguien le saca el null a uno de
  // los dos, la pantalla sigue ofreciendo borrarlo y el servidor sigue sin borrarlo.
  for (const campo of ["last_name", "goal_date_ms"]) {
    const ramas = entrada[campo].oneOf ?? [];
    assert.ok(
      ramas.some((x) => x && x.type === "null"),
      `${campo} tiene que aceptar null: es un campo que se puede vaciar`,
    );
  }
  const camposEnNull = /fun camposEnNull\(([\s\S]*?)\n    }/.exec(kotlinPerfil);
  assert.ok(camposEnNull, "no encontré camposEnNull en DatosDePerfil.kt");
  assert.match(camposEnNull[1], /"last_name"/);
  assert.match(camposEnNull[1], /"goal_date_ms"/);
});

test("los días de entrenamiento respetan el rango del contrato", () => {
  assert.equal(constante(kotlinPerfil, "DIAS_DE_LA_SEMANA"), dia.weekday.maximum);
  assert.equal(constante(kotlinPerfil, "ULTIMO_MINUTO_DEL_DIA"), dia.minute_of_day.maximum);
  assert.equal(entrada.training_days.maxItems, dia.weekday.maximum);
});

test("la barra de progreso numera 1..15 sin huecos ni repetidos", () => {
  const total = constante(kotlinRegistro, "PASOS_DEL_REGISTRO");

  // El alta nueva comienza por `REG_NOMBRE(1)`. Los `null` no cuentan.
  const delAlta = [...kotlinAcceso.matchAll(/^\s{4}[A-Z_]+\((\d+)\),$/gm)].map((m) => Number(m[1]));
  // NOMBRE(5) sigue disponible para completar perfiles previos, pero ya se
  // cargó antes del correo y el alta nueva empieza el perfil en NACIMIENTO(6).
  const delPerfil = [...kotlinPerfil.matchAll(/^\s{4}([A-Z_]+)\((\d+)\),$/gm)]
    .filter((m) => m[1] !== "NOMBRE")
    .map((m) => Number(m[2]));

  assert.equal(delPerfil.length, 10, "el alta nueva tiene diez pasos de perfil después del nombre");
  const todos = [...delAlta, ...delPerfil].sort((a, b) => a - b);
  assert.deepEqual(
    todos,
    Array.from({ length: total }, (_, i) => i + 1),
    `los pasos numerados tienen que ser exactamente 1..${total}. ` +
      "Un hueco deja la barra saltando; un repetido la deja clavada.",
  );
});

test("todo campo que el contrato acepta lo escribe alguna pantalla", () => {
  // camelCase de Kotlin -> snake_case del contrato, leído del modelo GENERADO para
  // no volver a escribir la tabla a mano.
  const bloque = /data class PerfilEntrada\(([\s\S]*?)\n\)/.exec(modelos);
  assert.ok(bloque, "no encontré PerfilEntrada en ModelosGenerados.kt");
  const porCampo = new Map();
  let serial = null;
  for (const linea of bloque[1].split("\n")) {
    const s = /@SerialName\("([a-z_0-9]+)"\)/.exec(linea);
    if (s) { serial = s[1]; continue; }
    const v = /val ([A-Za-z0-9]+):/.exec(linea);
    if (v) { porCampo.set(serial ?? v[1], v[1]); serial = null; }
  }

  /**
   * Lo que a propósito NO llena ninguna pantalla, con el motivo. Una excepción sin
   * motivo escrito es un campo olvidado disfrazado de decisión.
   */
  const aProposito = {
    unit_system:
      "es una preferencia de presentación (AGENTS.md §10) y ninguna de las once " +
      "pantallas la pregunta: va a vivir en Ajustes, que todavía no existe",
    equipment:
      "(contrato 1.1.0) lo pregunta la rutina de gimnasio, no el alta: el diseño no tiene " +
      "esa pantalla y mientras tanto el motor asume sin equipo (docs/PROPUESTA-MOTOR.md §4.3)",
    pregnant_or_breastfeeding:
      "(contrato 1.1.0) lo pregunta nutrición justo antes de mostrar objetivos, y sólo a " +
      "quien declaró sexo femenino (AGENTS.md §9.2). No es un paso del alta: preguntar un " +
      "dato de salud que todavía no se usa es lo que §8 llama pedir de más",
  };

  const cuerpo = /fun loQueGuarda\(([\s\S]*?)\n    }/.exec(kotlinPerfil);
  assert.ok(cuerpo, "no encontré loQueGuarda en DatosDePerfil.kt");

  const sinEscribir = [];
  for (const [snake, camel] of porCampo) {
    if (snake in aProposito) continue;
    if (!new RegExp(`\\b${camel}\\s*=`).test(cuerpo[1])) sinEscribir.push(snake);
  }
  assert.deepEqual(
    sinEscribir,
    [],
    "el contrato acepta estos campos y ninguna pantalla de perfil los llena. " +
      "O se agrega el paso, o se agrega el campo a `aProposito` con el motivo.",
  );
});

test("el paso de medición sigue sin campo en el contrato (B-006)", () => {
  // 🛑 Este test NO defiende el hueco: lo vigila. `regWatch` pregunta con qué mide
  // la persona sus salidas y hoy la respuesta se tira, porque `PerfilEntrada` no
  // tiene dónde ponerla. El día que alguien agregue el campo, este test falla y
  // eso es exactamente lo que tiene que pasar: hay una pantalla esperándolo.
  const candidatos = Object.keys(entrada).filter((k) =>
    /track|device|watch|source|medicion/i.test(k),
  );
  assert.deepEqual(
    candidatos,
    [],
    "el contrato ya tiene dónde guardar la fuente de medición: cableá `regWatch` " +
      "(PasoDePerfil.MEDICION en DatosDePerfil.kt), cerrá B-006 en docs/BLOQUEOS.md " +
      "y borrá este test.",
  );
});

test("los siete objetivos del contrato tienen texto en los dos idiomas", () => {
  const objetivos = contrato.components.schemas.Objetivo.enum;
  assert.equal(objetivos.length, 7, "los siete objetivos cerrados de AGENTS.md §9.1");
  for (const idioma of ["values", "values-en"]) {
    const xml = readFileSync(
      resolve(raiz, `android/app/src/main/res/${idioma}/strings_acceso.xml`),
      "utf8",
    );
    const cuantos = [...xml.matchAll(/<string name="perf_obj_[a-z0-9]+">/g)].length;
    assert.equal(
      cuantos,
      objetivos.length,
      `${idioma}/strings_acceso.xml tiene ${cuantos} objetivos y el contrato ${objetivos.length}`,
    );
  }
});
