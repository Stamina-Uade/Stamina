/**
 * dominios/catalogo/repositorio.ts — el SQL del catálogo de ejercicios.
 *
 * El catálogo no es de nadie: no hay filtro por dueño porque no hay dueño. Lo que
 * sí se filtra siempre es `retirado_en_ms is null` (ver 004_catalogo.sql).
 */
import type { Db } from "../../infra/db.js";

export interface EjercicioFila {
  id: string;
  nombres: Record<string, string | null>;
  patron: string;
  equipamiento: string;
  lado: string;
  unidad: string;
  musculos: Array<{ id: string; rol: string }>;
  sustitutos: Array<{ id: string; tipo: string }>;
  articulaciones: string[];
}

export interface EntradaDiccionarioFila {
  tipo: "patron" | "equipamiento" | "musculo" | "articulacion";
  id: string;
  nombres: Record<string, string | null>;
}

const COLUMNAS = "id, nombres, patron, equipamiento, lado, unidad, musculos, sustitutos, articulaciones";

export function crearRepoCatalogo(db: Db) {
  return {
    /** Keyset por id. Pide `limite + 1` para saber si hay otra página. */
    async pagina(despuesDeId: string | null, limite: number): Promise<EjercicioFila[]> {
      return db.consultar<EjercicioFila>(
        `select ${COLUMNAS}
           from ejercicios
          where retirado_en_ms is null
            and ($1::text is null or id > $1)
          order by id
          limit $2`,
        [despuesDeId, limite + 1]
      );
    },

    /** El catálogo vigente entero. Lo usa el motor de rutina; son cientos de filas, no miles. */
    async vigentes(): Promise<EjercicioFila[]> {
      return db.consultar<EjercicioFila>(
        `select ${COLUMNAS} from ejercicios where retirado_en_ms is null order by id`
      );
    },

    async diccionario(): Promise<EntradaDiccionarioFila[]> {
      return db.consultar<EntradaDiccionarioFila>(
        `select tipo, id, nombres from diccionario_ejercicios order by tipo, id`
      );
    },
  };
}

export type RepoCatalogo = ReturnType<typeof crearRepoCatalogo>;
