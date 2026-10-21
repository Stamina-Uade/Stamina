/**
 * dominios/legal/rutas.ts — `GET /legal`.
 *
 * Es público: el texto se muestra ANTES de que exista la cuenta.
 *
 * La forma de la respuesta es deliberadamente tonta —título, resumen y una lista
 * de bloques con título y cuerpo— porque el texto lo edita quien lo revise, no
 * quien programa. Cuantos menos campos con significado tenga, menos chances de que
 * una corrección de redacción rompa la pantalla.
 */
import type { FastifyInstance, FastifyRequest } from "fastify";
import { cargar, versionLegal, borradores, type ContenidoLegal, type IdiomaLegal } from "./textos.js";

function aBloque(crudo: ContenidoLegal) {
  // `puntos` en el aviso, `secciones` en los términos y la privacidad: los tres
  // son lo mismo para el teléfono, así que se aplanan acá y no allá.
  const partes = crudo.puntos ?? crudo.secciones ?? [];
  return {
    title: crudo.titulo,
    summary: crudo.resumen,
    sections: partes.map((p) => ({ title: p.titulo, body: p.cuerpo })),
    acceptance: crudo.aceptacion,
  };
}

/**
 * En qué idioma van los textos: el primero de `Accept-Language`. Castellano y
 * francés si los pide; cualquier otro, inglés (el idioma por defecto de la app).
 */
export function idiomaLegal(req: Pick<FastifyRequest, "headers">): IdiomaLegal {
  const header = req.headers["accept-language"];
  const primero = (Array.isArray(header) ? header[0] : header)?.split(",")[0]?.trim().toLowerCase() ?? "";
  if (primero.startsWith("es")) return "es";
  if (primero.startsWith("fr")) return "fr";
  return "en";
}

export async function rutasLegales(app: FastifyInstance): Promise<void> {
  app.get("/legal", async (req) => {
    const idioma = idiomaLegal(req);
    const textos = cargar().textos;
    return {
      data: {
        version: versionLegal(),
        language: idioma,
        // Se manda tal como está: en desarrollo y staging la app muestra que el
        // texto todavía no lo revisó nadie. En producción el proceso no arranca
        // con esto en `false`, así que nunca llega un `false` a una persona real.
        reviewed: borradores().length === 0,
        health_notice: aBloque(textos.aviso_de_salud![idioma]),
        terms: aBloque(textos.terminos![idioma]),
        privacy: aBloque(textos.privacidad![idioma]),
      },
    };
  });
}
