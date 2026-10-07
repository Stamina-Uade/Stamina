/** Carga el secreto de Trainer una vez por proceso, antes de construir Config. */
import { GetSecretValueCommand, SecretsManagerClient } from "@aws-sdk/client-secrets-manager";
import { cargarConfig, type Config } from "../config.js";

const CLAVES = ["DATABASE_URL", "REDIS_URL", "JWT_SECRET", "SMTP_USER", "SMTP_PASS"] as const;
type Clave = (typeof CLAVES)[number];
type BuscarSecreto = (id: string, region: string) => Promise<string>;

async function buscarEnAws(id: string, region: string): Promise<string> {
  const cliente = new SecretsManagerClient({ region, maxAttempts: 2 });
  try {
    const respuesta = await cliente.send(new GetSecretValueCommand({ SecretId: id }));
    if (respuesta.SecretString === undefined) throw new Error("SecretString ausente");
    return respuesta.SecretString;
  } finally {
    cliente.destroy();
  }
}

function analizarSecreto(texto: string): Record<Clave, string> {
  let objeto: unknown;
  try {
    objeto = JSON.parse(texto);
  } catch {
    throw new Error("secretos: el valor de AWS no es JSON válido");
  }
  if (objeto === null || typeof objeto !== "object" || Array.isArray(objeto)) {
    throw new Error("secretos: el valor de AWS debe ser un objeto JSON");
  }
  const valores = objeto as Record<string, unknown>;
  const presentes = Object.keys(valores);
  if (presentes.length !== CLAVES.length || presentes.some((clave) => !CLAVES.includes(clave as Clave))) {
    throw new Error("secretos: las claves de AWS no coinciden con las cinco esperadas");
  }
  for (const clave of CLAVES) {
    if (typeof valores[clave] !== "string" || valores[clave].length === 0) {
      throw new Error(`secretos: falta ${clave} en AWS`);
    }
  }
  return valores as Record<Clave, string>;
}

/**
 * Sin TRAINER_SECRET_ID, el desarrollo local conserva su .env. Con el ID, AWS es
 * la única fuente: no hay fallback al archivo local si la lectura falla. No se
 * conserva la respuesta en disco ni se vuelve a pedir durante la vida del proceso.
 */
export async function cargarConfigConSecretos(buscar: BuscarSecreto = buscarEnAws): Promise<Config> {
  const id = process.env.TRAINER_SECRET_ID;
  if (id === undefined || id === "") return cargarConfig();
  const region = process.env.TRAINER_SECRETS_REGION;
  if (region === undefined || region === "") throw new Error("secretos: falta TRAINER_SECRETS_REGION");
  if (process.env.AWS_ACCESS_KEY_ID || process.env.AWS_SECRET_ACCESS_KEY) {
    throw new Error("secretos: usar el rol temporal del EC2, no claves AWS estáticas");
  }
  if (CLAVES.some((clave) => process.env[clave] !== undefined)) {
    throw new Error("secretos: hay claves locales duplicadas; dejarlas sólo en AWS");
  }

  let texto: string;
  try {
    texto = await buscar(id, region);
  } catch (e) {
    const nombre = e instanceof Error ? e.name : "Error";
    throw new Error(`secretos: no se pudo leer el secreto de Trainer (${nombre})`);
  }
  const valores = analizarSecreto(texto);
  try {
    for (const clave of CLAVES) process.env[clave] = valores[clave];
    return cargarConfig();
  } finally {
    // Config ya tiene sus copias. No las heredan eventuales procesos hijos.
    for (const clave of CLAVES) delete process.env[clave];
  }
}
