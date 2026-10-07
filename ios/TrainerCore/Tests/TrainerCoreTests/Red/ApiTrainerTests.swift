import XCTest
@testable import TrainerCore

/// Los cuerpos que viajan y dónde queda la sesión.
final class ApiTrainerTests: XCTestCase {

    private func api(_ servidor: ServidorDePrueba, _ almacen: AlmacenEnMemoria = AlmacenEnMemoria()) -> ApiTrainer {
        let cliente = servidor.cliente()
        return ApiTrainer(cliente: cliente,
                          renovador: RenovadorDeSesion(cliente: cliente, almacen: almacen,
                                                       reloj: { Fixtura.ahora }))
    }

    // MARK: - Login

    func testEntrarGuardaLaSesionYNoDevuelveLosTokens() async {
        let json = Fixtura.json(Fixtura.sesion(1, usuario: "u-7"))
        let servidor = ServidorDePrueba { _, _ in .datos(json) }
        let almacen = AlmacenEnMemoria()

        let r = await api(servidor, almacen).entrar(correo: "persona@ejemplo.com", clave: "Trainer2026x")

        XCTAssertEqual(r, .ok(SesionAbierta(usuario: "u-7")))
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(1, usuario: "u-7"))
        let pedido = try! XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.ruta, "/v1/auth/login")
        XCTAssertEqual(pedido.json?["email"] as? String, "persona@ejemplo.com")
        XCTAssertEqual(pedido.json?["password"] as? String, "Trainer2026x")
    }

    func testUnLoginRechazadoNoGuardaNada() async {
        let servidor = ServidorDePrueba { _, _ in .error("invalid_credentials", http: 401) }
        let almacen = AlmacenEnMemoria()

        let r = await api(servidor, almacen).entrar(correo: "persona@ejemplo.com", clave: "mal")

        XCTAssertEqual(r, .rechazado(codigo: "invalid_credentials", http: 401))
        XCTAssertNil(almacen.leer())
    }

    // MARK: - Registro

    func testElRegistroUsaSusTresRutasConLosCuerposDelContrato() async {
        let json = Fixtura.json(Fixtura.sesion(1))
        let servidor = ServidorDePrueba { pedido, _ in
            switch pedido.ruta {
            case "/v1/auth/register":
                return .datos(#"{"expires_at_ms":1,"resend_after_ms":2}"#, http: 202)
            case "/v1/auth/register/verify":
                return .datos(#"{"registration_token":"permiso","expires_at_ms":1}"#)
            default:
                return .datos(json, http: 201)
            }
        }
        let almacen = AlmacenEnMemoria()
        let api = api(servidor, almacen)

        let desafio = await api.pedirCodigoDeRegistro(correo: "persona@ejemplo.com")
        let permiso = await api.verificarCodigoDeRegistro(correo: "persona@ejemplo.com", codigo: "A7K2Q9")
        let cuenta = await api.completarRegistro(token: "permiso", clave: "Trainer2026x",
                                                 aceptacion: AceptacionLegal(version: "1.2.0", accepted: true),
                                                 perfil: PerfilEntrada())

        XCTAssertEqual(desafio, .ok(DesafioCorreo(expiresAtMs: 1, resendAfterMs: 2)))
        XCTAssertEqual(permiso.valor?.registrationToken, "permiso")
        XCTAssertEqual(cuenta, .ok(SesionAbierta(usuario: "u-1")))
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(1), "la cuenta nace con la sesión abierta")

        XCTAssertEqual(servidor.pedidos[1].json?["code"] as? String, "A7K2Q9")
        let completar = try! XCTUnwrap(servidor.pedidos[2].json)
        XCTAssertEqual(completar["registration_token"] as? String, "permiso")
        XCTAssertEqual(completar["password"] as? String, "Trainer2026x")
        // El perfil viaja vacío: los once pasos lo guardan después (decisión 0008).
        XCTAssertEqual((completar["profile"] as? [String: Any])?.count, 0)
        let legal = try! XCTUnwrap(completar["legal"] as? [String: Any])
        XCTAssertEqual(legal["version"] as? String, "1.2.0")
        XCTAssertEqual(legal["accepted"] as? Bool, true)
    }

    // MARK: - Recuperación

    func testLaRecuperacionUsaSusTresRutasYEntraConLaSesionNueva() async {
        let json = Fixtura.json(Fixtura.sesion(3))
        let servidor = ServidorDePrueba { pedido, _ in
            switch pedido.ruta {
            case "/v1/auth/password/forgot":
                return .datos(#"{"expires_at_ms":1,"resend_after_ms":2}"#, http: 202)
            case "/v1/auth/password/verify":
                return .datos(#"{"reset_token":"permiso","expires_at_ms":1}"#)
            default:
                return .datos(json)
            }
        }
        let almacen = AlmacenEnMemoria()
        let api = api(servidor, almacen)

        _ = await api.pedirCodigoDeClave(correo: "persona@ejemplo.com")
        let permiso = await api.verificarCodigoDeClave(correo: "persona@ejemplo.com", codigo: "A7K2Q9")
        let entrada = await api.cambiarClave(token: "permiso", clave: "Trainer2027x")

        XCTAssertEqual(permiso.valor?.resetToken, "permiso")
        XCTAssertEqual(entrada, .ok(SesionAbierta(usuario: "u-1")))
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(3))
        XCTAssertEqual(servidor.pedidos.map(\.ruta),
                       ["/v1/auth/password/forgot", "/v1/auth/password/verify", "/v1/auth/password/reset"])
        XCTAssertEqual(servidor.pedidos[2].json?["reset_token"] as? String, "permiso")
    }

    // MARK: - Perfil

    /// docs/API.md §7: en un PATCH, omitir es "no lo toques". Vaciar es `null`.
    func testGuardarPerfilMandaLosNullExplicitosYNadaMas() async {
        let servidor = ServidorDePrueba { _, _ in .datos(Fixtura.perfil) }
        let api = api(servidor, AlmacenEnMemoria(Fixtura.sesion(1)))

        let r = await api.guardarPerfil(PerfilEntrada(firstName: "Iván"), anulando: [.apellido],
                                        claveDeIdempotencia: "intento-9")

        XCTAssertNotNil(r.valor)
        let pedido = try! XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.metodo, "PATCH")
        XCTAssertEqual(pedido.encabezado("Idempotency-Key"), "intento-9")
        let cuerpo = try! XCTUnwrap(pedido.json)
        XCTAssertEqual(Set(cuerpo.keys), ["first_name", "last_name"],
                       "un paso manda lo suyo: un campo de más pisaría lo de otro paso")
        XCTAssertEqual(cuerpo["first_name"] as? String, "Iván")
        XCTAssertTrue(cuerpo["last_name"] is NSNull)
    }

    func testUnNullNuncaPisaUnValorQueSiViene() throws {
        let cuerpo = CuerpoDePerfil(perfil: PerfilEntrada(lastName: "Benítez", goalDateMs: nil),
                                    anulando: [.apellido, .fechaDelObjetivo])

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(cuerpo)) as? [String: Any])

        XCTAssertEqual(json["last_name"] as? String, "Benítez")
        XCTAssertTrue(json["goal_date_ms"] is NSNull)
        XCTAssertEqual(json.count, 2)
    }

    // MARK: - Recorridos

    func testRecorridoViajaAutenticadoConTiempoEpochYSeLeeDelServidor() async {
        let servidor = ServidorDePrueba { _, _ in
            .datos(#"{"points":[{"lat":-34.6,"lon":-58.4,"at_ms":1789999999000}]}"#)
        }
        let api = api(servidor, AlmacenEnMemoria(Fixtura.sesion(1)))
        let puntos = [PuntoDeRecorrido(lat: -34.6, lon: -58.4, atMs: 1_789_999_999_000)]

        let guardado = await api.guardarRecorrido(id: "salida-123", puntos)
        let leido = await api.recorrido(id: "salida-123")

        XCTAssertEqual(guardado.valor?.points, puntos)
        XCTAssertEqual(leido.valor?.points, puntos)
        XCTAssertEqual(servidor.pedidos.map(\.ruta),
                       ["/v1/activities/salida-123/route", "/v1/activities/salida-123/route"])
        XCTAssertEqual(servidor.pedidos.map(\.metodo), ["PUT", "GET"])
        XCTAssertNotNil(servidor.pedidos[0].encabezado("Authorization"))
        let enviado = (servidor.pedidos[0].json?["points"] as? [[String: Any]])?.first
        XCTAssertEqual(enviado?["at_ms"] as? Int64, 1_789_999_999_000)
    }
}
