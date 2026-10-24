/**
 * test/unit.cloudflare.test.ts — detrás de Cloudflare y Apache, `req.ip` es la IP
 * de la persona (infra/cloudflare.ts), y nadie la inventa hablándole directo al
 * servidor.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import Fastify from "fastify";
import { confianzaDeProxy, RANGOS_DE_CLOUDFLARE } from "../src/infra/cloudflare.js";

async function ipVista(trustProxy: boolean | string, xff: string | undefined, socket = "127.0.0.1"): Promise<string> {
  const app = Fastify({ trustProxy: confianzaDeProxy(trustProxy) });
  app.get("/ip", async (req) => ({ ip: req.ip }));
  await app.ready();
  const res = await app.inject({ method: "GET", url: "/ip", remoteAddress: socket, headers: xff ? { "x-forwarded-for": xff } : {} });
  await app.close();
  return (JSON.parse(res.body) as { ip: string }).ip;
}

test("Cloudflare › Apache: la IP es la de la persona, no la del borde", async () => {
  assert.equal(await ipVista("127.0.0.1", "181.93.48.185, 162.158.90.12"), "181.93.48.185");
  assert.equal(await ipVista("127.0.0.1", "2800:810:4e1::5, 2606:4700:10::ac43:1"), "2800:810:4e1::5");
});

test("directo al servidor, sin Cloudflare: queda la IP que anotó Apache aunque mande un X-Forwarded-For inventado", async () => {
  assert.equal(await ipVista("127.0.0.1", "1.1.1.1, 45.67.89.10"), "45.67.89.10");
});

test("sin proxy de confianza no se mira el header; con true se confía en todos, como antes", async () => {
  assert.equal(await ipVista(false, "181.93.48.185, 162.158.90.12", "45.67.89.10"), "45.67.89.10");
  assert.equal(await ipVista(true, "181.93.48.185, 162.158.90.12"), "181.93.48.185");
});

test("la lista de TRUST_PROXY se respeta y se le suman los rangos", () => {
  assert.deepEqual(confianzaDeProxy("127.0.0.1, 10.0.0.0/8"), ["127.0.0.1", "10.0.0.0/8", ...RANGOS_DE_CLOUDFLARE]);
  assert.equal(confianzaDeProxy(false), false);
});
