/**
 * infra/proveedores.ts — "Continuar con Google" y "Continuar con Apple".
 *
 * El teléfono hace el inicio de sesión con el proveedor y nos manda el `id_token`
 * que le devolvió. Acá se comprueba que ese token lo firmó de verdad Google o
 * Apple, que es para NUESTRA app y que no es uno viejo reenviado:
 *
 *   - firma contra las claves públicas que publica el proveedor (JWKS), con el
 *     algoritmo fijado en código (RS256), nunca el `alg` del header (§12)
 *   - `iss` del proveedor y `aud` = uno de nuestros client id
 *   - `exp` vigente (lo mira `jose`)
 *   - `nonce`: el teléfono genera uno al azar por intento y nos manda el claro. A
 *     Apple le pasa el SHA-256 (así lo pide Apple) y a Google el claro, así que se
 *     compara con lo que corresponde a cada uno. Sin esto, un id_token robado se
 *     podría reusar mientras no vence.
 *
 * 🛑 Lo único que se usa del token es `sub` (el id estable de la persona en ese
 * proveedor) y el correo con su `email_verified`. El nombre de Apple NO viene en
 * el token: Apple lo da una sola vez al teléfono, y el teléfono lo manda aparte.
 */
import { createHash } from "node:crypto";
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";

export type NombreDeProveedor = "google" | "apple";

export interface IdentidadVerificada {
  proveedor: NombreDeProveedor;
  /** El id de la persona en el proveedor. Estable: no cambia si cambia el correo. */
  sujeto: string;
  /** Normalizado en minúsculas. `null` si el proveedor no lo dio. */
  email: string | null;
  /** Sólo un correo verificado por el proveedor alcanza para vincular con una cuenta existente. */
  emailVerificado: boolean;
  /**
   * Google: el dominio de Workspace (`hd`) si la cuenta es de una organización.
   * Importa para decidir si Google es la AUTORIDAD sobre ese correo (ver
   * `proveedorEsDuenoDelCorreo`).
   */
  dominioGestionado: string | null;
  /** Cuándo vence el id_token (`exp`), para recordar que ya se usó hasta entonces. */
  venceMs: number;
}

/**
 * Si el proveedor es el DUEÑO del correo, y no sólo alguien que lo verificó una vez.
 *
 * Google sólo es autoridad sobre @gmail.com y sobre los dominios de Workspace
 * (`hd`). Una cuenta de Google creada con otro correo (un @hotmail.com, un correo
 * de trabajo reciclado) dice `email_verified: true` porque alguna vez se verificó,
 * pero quien la controla hoy puede no ser el dueño del buzón. Con esos no se
 * vincula a una cuenta existente: sigue el alta, que pide el código al correo.
 *
 * Apple verifica el correo del Apple ID y los relays `@privaterelay` son suyos.
 */
export function proveedorEsDuenoDelCorreo(id: IdentidadVerificada): boolean {
  if (id.email === null || !id.emailVerificado) return false;
  if (id.proveedor === "apple") return true;
  return id.dominioGestionado !== null || /@(gmail|googlemail)\.com$/.test(id.email);
}

export interface VerificadorDeProveedores {
  /** `false` si no hay client id configurado para ese proveedor. */
  configurado(proveedor: NombreDeProveedor): boolean;
  /** `null` si el token no es válido por cualquier motivo. Nunca tira. */
  verificar(proveedor: NombreDeProveedor, idToken: string, nonce: string): Promise<IdentidadVerificada | null>;
}

const EMISORES: Record<NombreDeProveedor, string[]> = {
  google: ["https://accounts.google.com", "accounts.google.com"],
  apple: ["https://appleid.apple.com"],
};

const JWKS_URL: Record<NombreDeProveedor, string> = {
  google: "https://www.googleapis.com/oauth2/v3/certs",
  apple: "https://appleid.apple.com/auth/keys",
};

export function sha256Hex(texto: string): string {
  return createHash("sha256").update(texto).digest("hex");
}

/** `email_verified` llega como booleano en Google y a veces como "true" en Apple. */
function esVerdadero(v: unknown): boolean {
  return v === true || v === "true";
}

export function crearVerificadorDeProveedores(opciones: {
  clientIds: Record<NombreDeProveedor, readonly string[]>;
  /** Para los tests: claves locales en vez de las de internet. */
  claves?: Partial<Record<NombreDeProveedor, JWTVerifyGetKey>>;
}): VerificadorDeProveedores {
  // Se crean una vez: `createRemoteJWKSet` cachea las claves y las vuelve a bajar
  // sólo cuando aparece un `kid` que no conoce (rotación del proveedor).
  const claves: Record<NombreDeProveedor, JWTVerifyGetKey> = {
    google: opciones.claves?.google ?? createRemoteJWKSet(new URL(JWKS_URL.google), { timeoutDuration: 5_000 }),
    apple: opciones.claves?.apple ?? createRemoteJWKSet(new URL(JWKS_URL.apple), { timeoutDuration: 5_000 }),
  };

  return {
    configurado(proveedor) {
      return opciones.clientIds[proveedor].length > 0;
    },

    async verificar(proveedor, idToken, nonce) {
      const audiencias = opciones.clientIds[proveedor];
      if (audiencias.length === 0 || nonce.length < 16) return null;
      try {
        const { payload } = await jwtVerify(idToken, claves[proveedor], {
          algorithms: ["RS256"],
          issuer: EMISORES[proveedor],
          audience: [...audiencias],
          clockTolerance: 60,
        });
        const esperado = proveedor === "apple" ? sha256Hex(nonce) : nonce;
        if (typeof payload["nonce"] !== "string" || payload["nonce"] !== esperado) return null;
        if (typeof payload.sub !== "string" || payload.sub.length === 0) return null;
        const email = typeof payload["email"] === "string" ? payload["email"].trim().toLowerCase() : null;
        const hd = payload["hd"];
        return {
          proveedor,
          sujeto: payload.sub,
          email: email !== null && email.includes("@") ? email : null,
          emailVerificado: email !== null && esVerdadero(payload["email_verified"]),
          dominioGestionado: proveedor === "google" && typeof hd === "string" && hd.length > 0 ? hd.toLowerCase() : null,
          venceMs: typeof payload.exp === "number" ? payload.exp * 1000 : Date.now() + 3_600_000,
        };
      } catch {
        return null;
      }
    },
  };
}
