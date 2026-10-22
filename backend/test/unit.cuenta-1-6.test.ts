/**
 * Contrato 1.6.0 ("Entrar y registrarse"): las piezas que no necesitan base ni
 * Redis. Los recorridos de punta a punta están en integracion.cuenta-1-6.test.ts.
 */
import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { CODIGOS, ErrorApi, aCuerpo } from "../src/infra/errores.js";

describe("el sobre de error con details (1.6.0)", () => {
  test("los códigos nuevos están registrados con su status", () => {
    assert.equal(CODIGOS.too_many_attempts, 429);
    assert.equal(CODIGOS.code_attempts_exceeded, 400);
    assert.equal(CODIGOS.account_link_available, 409);
    assert.equal(CODIGOS.invalid_link_token, 401);
    assert.equal(CODIGOS.account_deactivated, 403);
    assert.equal(CODIGOS.account_pending_deletion, 403);
    assert.equal(CODIGOS.invalid_reactivation_token, 401);
  });

  test("sin details el sobre es el de siempre; con details, sale en error.details", () => {
    assert.deepEqual(aCuerpo(new ErrorApi("wrong_password", "x")), { error: { code: "wrong_password", message: "x" } });
    const e = new ErrorApi("account_pending_deletion", "y", undefined, { reactivation_token: "t", days_remaining: 3 });
    assert.equal(e.http, 403);
    assert.deepEqual(aCuerpo(e), {
      error: { code: "account_pending_deletion", message: "y", details: { reactivation_token: "t", days_remaining: 3 } },
    });
  });
});
