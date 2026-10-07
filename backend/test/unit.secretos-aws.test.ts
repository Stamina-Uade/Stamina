import { test } from "node:test";
import assert from "node:assert/strict";
import { cargarConfigConSecretos } from "../src/infra/secretos-aws.js";

const CLAVES = [
  "NODE_ENV", "TRAINER_SECRET_ID", "TRAINER_SECRETS_REGION", "TRUST_PROXY", "MAIL_PROVIDER",
  "MAIL_FROM", "SMTP_HOST", "SMTP_PORT", "DATABASE_URL", "REDIS_URL", "JWT_SECRET",
  "SMTP_USER", "SMTP_PASS", "STAGING_REGISTRATION_EMAIL", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
];

async function entornoDePrueba(fn: () => Promise<void>): Promise<void> {
  const anterior = new Map(CLAVES.map((clave) => [clave, process.env[clave]]));
  try {
    for (const clave of CLAVES) delete process.env[clave];
    Object.assign(process.env, {
      NODE_ENV: "staging",
      TRAINER_SECRET_ID: "stamina/backend/secrets",
      TRAINER_SECRETS_REGION: "us-east-1",
      TRUST_PROXY: "127.0.0.1",
      MAIL_PROVIDER: "smtp",
      MAIL_FROM: "no-reply@stamina.com.ar",
      SMTP_HOST: "email-smtp.us-east-1.amazonaws.com",
      SMTP_PORT: "587",
      STAGING_REGISTRATION_EMAIL: "karkoszkaivan@gmail.com",
    });
    await fn();
  } finally {
    for (const clave of CLAVES) {
      const valor = anterior.get(clave);
      if (valor === undefined) delete process.env[clave];
      else process.env[clave] = valor;
    }
  }
}

const secreto = JSON.stringify({
  DATABASE_URL: "postgres://trainer:test@127.0.0.1:5432/trainer_db",
  REDIS_URL: "redis://:test@127.0.0.1:6381",
  JWT_SECRET: "un-secreto-de-prueba-de-mas-de-treinta-y-dos-bytes",
  SMTP_USER: "SMTPTESTUSER",
  SMTP_PASS: "SMTPTESTPASS",
});

test("carga el secreto una sola vez por arranque y quita las claves del entorno", async () => {
  await entornoDePrueba(async () => {
    let llamadas = 0;
    const config = await cargarConfigConSecretos(async (id, region) => {
      llamadas++;
      assert.equal(id, "stamina/backend/secrets");
      assert.equal(region, "us-east-1");
      return secreto;
    });
    assert.equal(llamadas, 1);
    assert.equal(config.smtp?.usuario, "SMTPTESTUSER");
    assert.equal(config.mailFrom, "no-reply@stamina.com.ar");
    for (const clave of ["DATABASE_URL", "REDIS_URL", "JWT_SECRET", "SMTP_USER", "SMTP_PASS"]) {
      assert.equal(process.env[clave], undefined);
    }
  });
});

test("si AWS falla, no usa valores locales como respaldo", async () => {
  await entornoDePrueba(async () => {
    await assert.rejects(
      cargarConfigConSecretos(async () => { throw new Error("fallo simulado"); }),
      /no se pudo leer el secreto de Trainer/
    );
  });
});

test("rechaza claves locales duplicadas antes de pedir el secreto", async () => {
  await entornoDePrueba(async () => {
    process.env.JWT_SECRET = "secreto-local-de-mas-de-treinta-y-dos-bytes";
    let llamadas = 0;
    await assert.rejects(
      cargarConfigConSecretos(async () => { llamadas++; return secreto; }),
      /claves locales duplicadas/
    );
    assert.equal(llamadas, 0);
  });
});

test("rechaza secretos incompletos sin filtrar sus valores al error", async () => {
  await entornoDePrueba(async () => {
    await assert.rejects(
      cargarConfigConSecretos(async () => JSON.stringify({ DATABASE_URL: "valor-privado" })),
      (error: unknown) => error instanceof Error && !error.message.includes("valor-privado")
    );
  });
});
