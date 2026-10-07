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
import type { FastifyInstance } from "fastify";
import { cargar, versionLegal, borradores } from "./textos.js";

interface Punto {
  titulo: string;
  cuerpo: string;
}

interface AvisoCrudo {
  titulo: string;
  resumen: string;
  puntos?: Punto[];
  secciones?: Punto[];
  aceptacion: string;
}

function aBloque(crudo: AvisoCrudo) {
  // `puntos` en el aviso, `secciones` en los términos: los dos son lo mismo para
  // el teléfono, así que el nombre distinto del archivo se aplana acá y no allá.
  const partes = crudo.puntos ?? crudo.secciones ?? [];
  return {
    title: crudo.titulo,
    summary: crudo.resumen,
    sections: partes.map((p) => ({ title: p.titulo, body: p.cuerpo })),
    acceptance: crudo.aceptacion,
  };
}

export async function rutasLegales(app: FastifyInstance): Promise<void> {
  app.get("/legal", async () => {
    const archivo = cargar().textos as unknown as Record<string, AvisoCrudo>;
    return {
      data: {
        version: versionLegal(),
        // Se manda tal como está: en desarrollo la app puede mostrar que el texto
        // todavía no lo revisó nadie. En producción el proceso no arranca con esto
        // en `false`, así que nunca llega un `false` a una persona real.
        reviewed: borradores().length === 0,
        health_notice: aBloque(archivo.aviso_de_salud as AvisoCrudo),
        terms: aBloque(archivo.terminos as AvisoCrudo),
      },
    };
  });
}
