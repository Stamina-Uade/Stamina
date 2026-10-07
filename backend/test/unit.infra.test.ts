/**
 * Tests de las piezas puras de infra/ que agregó el motor: el cursor, las fechas
 * locales y la caché en memoria. Ninguna necesita base ni Redis.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import {
  codificarCursor,
  decodificarCursor,
  limiteDe,
  pagina,
  LIMITE_MAXIMO,
  LIMITE_POR_DEFECTO,
} from "../src/infra/paginacion.js";
import { diasEntre, edadEn, fechaLocal, fechaUTC, inicioDelDiaMs, sumarDias, zonaValida } from "../src/infra/fechas.js";
import { crearCacheEnMemoria, MAX_CLAVES_EN_MEMORIA } from "../src/infra/redis.js";
import { ErrorApi } from "../src/infra/errores.js";
import { archivosDeMigracion } from "../src/infra/migrar.js";
import { refreshSucesor } from "../src/infra/cripto.js";

describe("el sucesor de un refresh (decisión 0013)", () => {
  const config = { jwtSecret: new TextEncoder().encode("un-secreto-de-prueba-de-mas-de-32-bytes!!") };

  test("es determinístico y tiene la forma de un token opaco de 32 bytes", () => {
    const a = refreshSucesor(config, "refresh-viejo");
    assert.equal(a, refreshSucesor(config, "refresh-viejo"));
    assert.match(a, /^[A-Za-z0-9_-]{43}$/);
  });

  test("cambia con el refresh y con el secreto del servidor", () => {
    const otro = { jwtSecret: new TextEncoder().encode("otro-secreto-de-prueba-de-mas-de-32-bytes") };
    assert.notEqual(refreshSucesor(config, "a"), refreshSucesor(config, "b"));
    assert.notEqual(refreshSucesor(config, "a"), refreshSucesor(otro, "a"));
  });
});

describe("qué archivos son migraciones", () => {
  test("los ._ que mete el tar de macOS no son migraciones", () => {
    assert.deepEqual(
      archivosDeMigracion(["002_b.sql", "._001_a.sql", "001_a.sql", "LEEME.md", ".DS_Store"]),
      ["001_a.sql", "002_b.sql"]
    );
  });

  test("un .sql con otro formato de nombre falla fuerte, no se saltea", () => {
    assert.throws(() => archivosDeMigracion(["001_a.sql", "8_nueva.sql"]), /8_nueva\.sql/);
  });
});

describe("el cursor opaco", () => {
  test("ida y vuelta", () => {
    const c = codificarCursor([1_757_000_000_000, "gym-2026-09-10"]);
    assert.deepEqual(decodificarCursor(c, ["number", "string"]), [1_757_000_000_000, "gym-2026-09-10"]);
  });

  test("sin cursor es la primera página", () => {
    assert.equal(decodificarCursor(undefined, ["string"]), null);
  });

  test("un cursor roto es un 400, no un 500", () => {
    for (const roto of ["%%%", codificarCursor(["texto"]), codificarCursor([1, 2]), "bnVsbA"]) {
      assert.throws(
        () => decodificarCursor(roto, ["number", "string"]),
        (e: unknown) => e instanceof ErrorApi && e.codigo === "bad_request"
      );
    }
  });

  test("🛑 el límite se clampea en el servidor", () => {
    assert.equal(limiteDe(undefined), LIMITE_POR_DEFECTO);
    assert.equal(limiteDe(100_000), LIMITE_MAXIMO);
    assert.equal(limiteDe(0), 1);
    assert.equal(limiteDe("7"), 7);
  });

  test("la fila de más dice si hay otra página, y no se entrega", () => {
    const filas = [{ id: "a" }, { id: "b" }, { id: "c" }];
    const p = pagina(filas, 2, (f) => [f.id], (f) => f.id);
    assert.deepEqual(p.data, ["a", "b"]);
    assert.equal(p.pagination.has_more, true);
    assert.deepEqual(decodificarCursor(p.pagination.next_cursor, ["string"]), ["b"]);

    const ultima = pagina(filas, 5, (f) => [f.id], (f) => f.id);
    assert.deepEqual(ultima.pagination, { has_more: false });
  });
});

describe("el día local", () => {
  const BA = "America/Argentina/Buenos_Aires";

  test("las 23:30 del lunes en Buenos Aires ya es martes en UTC, y sigue siendo lunes para la persona", () => {
    const ms = Date.UTC(2026, 8, 15, 2, 30); // 2026-09-15 02:30 UTC = 23:30 del 14 en BA
    assert.equal(fechaLocal(ms, BA), "2026-09-14");
    assert.equal(fechaLocal(ms, "UTC"), "2026-09-15");
  });

  test("la medianoche local, en una zona sin horario de verano", () => {
    assert.equal(inicioDelDiaMs("2026-09-10", BA), Date.UTC(2026, 8, 10, 3, 0));
  });

  test("la medianoche local, el día que cambia el horario", () => {
    // Nueva York pasa a horario de verano el 2026-03-08 a las 2:00: la medianoche
    // de ese día todavía es UTC-5.
    assert.equal(inicioDelDiaMs("2026-03-08", "America/New_York"), Date.UTC(2026, 2, 8, 5, 0));
    assert.equal(inicioDelDiaMs("2026-03-09", "America/New_York"), Date.UTC(2026, 2, 9, 4, 0));
  });

  test("edad cumplida, con el nacimiento como fecha sin hora (medianoche UTC)", () => {
    const nacimiento = Date.UTC(1992, 8, 11);
    assert.equal(edadEn(nacimiento, "2026-09-10"), 33);
    assert.equal(edadEn(nacimiento, "2026-09-11"), 34);
  });

  test("una fecha sin hora se lee en UTC: en la zona de Buenos Aires caería el día anterior", () => {
    const carrera = Date.UTC(2026, 10, 15);
    assert.equal(fechaUTC(carrera), "2026-11-15");
    assert.equal(fechaLocal(carrera, BA), "2026-11-14", "el bug que esto evita");
  });

  test("aritmética de calendario", () => {
    assert.equal(sumarDias("2026-02-27", 2), "2026-03-01");
    assert.equal(sumarDias("2026-03-01", -1), "2026-02-28");
    assert.equal(diasEntre("2026-09-10", "2026-10-11"), 31);
  });

  test("una zona que no existe se detecta", () => {
    assert.equal(zonaValida(BA), true);
    assert.equal(zonaValida("Marte/Olympus"), false);
  });
});

describe("la caché en memoria (decisión 0011)", () => {
  test("vence cuando dice el TTL", async () => {
    let ahora = 1_000;
    const cache = crearCacheEnMemoria(() => ahora);
    await cache.poner("k", "v", 60);
    assert.equal(await cache.obtener("k"), "v");
    ahora += 60_000;
    assert.equal(await cache.obtener("k"), null);
  });

  test("incrementar suma sin estirar el vencimiento, como INCR", async () => {
    let ahora = 0;
    const cache = crearCacheEnMemoria(() => ahora);
    assert.equal(await cache.incrementar("rl", 10), 1);
    ahora = 9_000;
    assert.equal(await cache.incrementar("rl", 10), 2);
    ahora = 10_001;
    assert.equal(await cache.incrementar("rl", 10), 1, "venció a los 10 s del primer incremento");
  });

  test("🛑 no hay forma de escribir sin TTL", async () => {
    const cache = crearCacheEnMemoria();
    await assert.rejects(() => cache.poner("k", "v", 0));
  });

  test("🛑 tiene techo de claves: las más viejas se van", async () => {
    const cache = crearCacheEnMemoria(() => 0);
    for (let i = 0; i <= MAX_CLAVES_EN_MEMORIA; i++) await cache.poner(`k${i}`, "v", 60);
    assert.equal(await cache.obtener("k0"), null, "la primera se tiró");
    assert.equal(await cache.obtener(`k${MAX_CLAVES_EN_MEMORIA}`), "v");
  });

  test("dice qué es y no ofrece un cliente de Redis", () => {
    const cache = crearCacheEnMemoria();
    assert.equal(cache.modo, "memoria");
    assert.equal(cache.cliente(), null);
  });
});
