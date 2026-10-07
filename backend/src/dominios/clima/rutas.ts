import type { FastifyInstance } from "fastify";
import type { Contexto } from "../../contexto.js";
import { ErrorApi } from "../../infra/errores.js";
import { cuerpo } from "../../infra/esquemas.js";
import { crearGuardia } from "../auth/guardia.js";

interface Hora { at_ms: number; air_temperature_c: number }
interface EntradaCache { hours: Hora[]; expires: number; lastModified: string | null }
const cache = new Map<string, EntradaCache>();
const FUENTE = "https://api.met.no/weatherapi/locationforecast/2.0/compact";

function extraerHoras(json: unknown, ahora: number): Hora[] {
  const datos = json as { properties?: { timeseries?: Array<{
    time?: string; data?: { instant?: { details?: { air_temperature?: number } } }
  }> } };
  return (datos.properties?.timeseries ?? []).flatMap((item) => {
    const fecha = Date.parse(item.time ?? "");
    const temperatura = item.data?.instant?.details?.air_temperature;
    return Number.isFinite(fecha) && fecha >= ahora && fecha <= ahora + 48 * 60 * 60 * 1000 &&
      typeof temperatura === "number" && Number.isFinite(temperatura)
      ? [{ at_ms: fecha, air_temperature_c: temperatura }]
      : [];
  });
}

export async function rutasClima(app: FastifyInstance, ctx: Contexto): Promise<void> {
  app.post("/weather/forecast", {
    preHandler: crearGuardia(ctx),
    schema: { body: cuerpo("forecastWeather") },
    config: { rateLimit: { max: 6, timeWindow: "1 minute" } },
  }, async (req) => {
    const { lat, lon } = req.body as { lat: number; lon: number };
    // Aproximadamente 11 km. Ni la URL a MET ni el cache contienen GPS preciso.
    const latReducida = (Math.round(lat * 10) / 10).toFixed(1);
    const lonReducida = (Math.round(lon * 10) / 10).toFixed(1);
    const clave = `${latReducida},${lonReducida}`;
    const ahora = ctx.ahoraMs();
    let entrada = cache.get(clave);
    if (entrada === undefined || entrada.expires <= ahora) {
      try {
        const url = `${FUENTE}?lat=${latReducida}&lon=${lonReducida}`;
        const respuesta = await fetch(url, {
          headers: {
            "User-Agent": "Stamina/0.1 (https://stamina.com.ar)",
            "Accept-Encoding": "gzip, deflate",
            ...(entrada?.lastModified ? { "If-Modified-Since": entrada.lastModified } : {}),
          },
          signal: AbortSignal.timeout(5_000),
        });
        if (respuesta.status !== 304 && !respuesta.ok) throw new Error("Forecast provider unavailable");
        const expiresHeader = Date.parse(respuesta.headers.get("expires") ?? "");
        const expires = Number.isFinite(expiresHeader) && expiresHeader > ahora
          ? expiresHeader : ahora + 30 * 60 * 1000;
        if (respuesta.status === 304 && entrada !== undefined) {
          entrada = { ...entrada, expires };
        } else {
          const hours = extraerHoras(await respuesta.json(), ahora);
          if (hours.length === 0) throw new Error("Forecast provider returned no hourly temperatures");
          entrada = { hours, expires, lastModified: respuesta.headers.get("last-modified") };
        }
        if (cache.size >= 128 && !cache.has(clave)) cache.delete(cache.keys().next().value!);
        cache.set(clave, entrada);
      } catch {
        if (entrada === undefined || entrada.expires + 6 * 60 * 60 * 1000 < ahora) {
          throw new ErrorApi("service_unavailable", "Forecast temporarily unavailable");
        }
      }
    }
    return { data: {
      source: "MET Norway", source_url: "https://api.met.no/weatherapi/locationforecast/2.0/",
      hours: entrada.hours.filter((h) => h.at_ms >= ahora),
    } };
  });
}
