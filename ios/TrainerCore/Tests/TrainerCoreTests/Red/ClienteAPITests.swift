import XCTest
@testable import TrainerCore

/// El sobre del contrato (docs/API.md §1) leído por el cliente de verdad.
///
/// Lo que importa acá es que ninguna respuesta —buena, mala o basura— tire una
/// excepción ni se trague el código: cada una tiene que terminar en uno de los
/// cuatro casos de `Resultado`, que es lo único que las pantallas saben mostrar.
final class ClienteAPITests: XCTestCase {

    private static let salud = #"{"status":"ok","version":"0.1.0","dependencies":{"database":"ok","redis":"down"}}"#

    func testElSobreDeDataSeLeeConLosModelosGenerados() async {
        let servidor = ServidorDePrueba { _, _ in .datos(Self.salud) }

        let r: Resultado<Health> = await servidor.cliente().pedir(.get, "/health")

        XCTAssertEqual(r, .ok(Health(status: .ok, version: "0.1.0",
                                     dependencies: EstadoDeDependencias(database: .ok, redis: .down))))
        XCTAssertEqual(servidor.pedidos.first?.ruta, "/v1/health",
                       "sin el /v1 del contrato, cada llamada es un 404 bien formado")
        XCTAssertEqual(servidor.pedidos.first?.metodo, "GET")
    }

    func testElSobreDeErrorDevuelveElCodigoYElStatus() async {
        let servidor = ServidorDePrueba { _, _ in .error("invalid_credentials", http: 401) }

        let r: Resultado<Sesion> = await servidor.cliente().pedir(.post, "/auth/login")

        XCTAssertEqual(r, .rechazado(codigo: "invalid_credentials", http: 401))
    }

    func testLaBasuraEsUnaRespuestaRaraYNoUnCrash() async {
        let casos: [(ServidorDePrueba.Respuesta, Int, String)] = [
            (.cruda("<html>502 Bad Gateway</html>", http: 502), 502, "el HTML de un proxy"),
            (.cruda(#"{"hola":1}"#, http: 200), 200, "un 200 sin sobre"),
            (.cruda(#"{"data":{"status":"ok"}}"#, http: 200), 200, "un data al que le faltan campos"),
            (.cruda(#"{"data":{"status":"ok"}}"#, http: 400), 400, "un error sin sobre de error"),
            (.cruda("", http: 200), 200, "un 200 vacío donde se esperaba data"),
            (.cruda(#"{"error":{"code":"x"}}"#, http: 500), 500, "un error sin message"),
        ]
        for (respuesta, http, que) in casos {
            let servidor = ServidorDePrueba { _, _ in respuesta }
            let r: Resultado<Health> = await servidor.cliente().pedir(.get, "/health")
            XCTAssertEqual(r, .respuestaRara(http: http), que)
        }
    }

    func testSinRedEsUnResultadoYNoUnaExcepcion() async {
        for falla: URLError.Code in [.notConnectedToInternet, .timedOut, .cannotConnectToHost] {
            let servidor = ServidorDePrueba { _, _ in ServidorDePrueba.Respuesta(falla: falla) }
            let r: Resultado<Health> = await servidor.cliente().pedir(.get, "/health")
            XCTAssertEqual(r, .sinRed, "\(falla)")
        }
    }

    /// `POST /auth/logout` contesta 204 sin cuerpo.
    func testUn204SeLeeComoSinCuerpo() async {
        let servidor = ServidorDePrueba { _, _ in .sinContenido }

        let r: Resultado<SinCuerpo> = await servidor.cliente().pedir(.post, "/auth/logout")

        XCTAssertEqual(r, .ok(SinCuerpo()))
    }

    func testLosEncabezadosDelContrato() async {
        let servidor = ServidorDePrueba { _, _ in .datos(Fixtura.perfil) }

        let _: Resultado<Perfil> = await servidor.cliente(idioma: "en-US").pedir(
            .patch, "/me", cuerpo: PedidoConCorreo(email: "persona@ejemplo.com"),
            token: "acceso-1", claveDeIdempotencia: "intento-1")

        let pedido = try! XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.metodo, "PATCH")
        XCTAssertEqual(pedido.encabezado("Accept"), "application/json")
        XCTAssertEqual(pedido.encabezado("Accept-Language"), "en-US")
        XCTAssertEqual(pedido.encabezado("Authorization"), "Bearer acceso-1")
        XCTAssertEqual(pedido.encabezado("Idempotency-Key"), "intento-1")
        XCTAssertEqual(pedido.encabezado("Content-Type"), "application/json")
        XCTAssertEqual(pedido.espera, 10, "diez segundos, como Android")
        XCTAssertEqual(pedido.json?["email"] as? String, "persona@ejemplo.com")
    }

    /// La clave es opcional en la API: sin ella no se manda un encabezado vacío.
    func testSinTokenNiClaveNoViajanEsosEncabezados() async {
        let servidor = ServidorDePrueba { _, _ in .datos(Self.salud) }

        let _: Resultado<Health> = await servidor.cliente().pedir(.get, "/health")

        let pedido = try! XCTUnwrap(servidor.pedidos.first)
        XCTAssertNil(pedido.encabezado("Authorization"))
        XCTAssertNil(pedido.encabezado("Idempotency-Key"))
        XCTAssertNil(pedido.encabezado("Content-Type"))
        XCTAssertTrue(pedido.cuerpo.isEmpty)
    }

    func testElIdiomaDelServidorEsElDeLosTextosDeLaApp() {
        XCTAssertEqual(ClienteAPI.idiomaParaElServidor(localizacion: "es"), "es-AR")
        XCTAssertEqual(ClienteAPI.idiomaParaElServidor(localizacion: "en"), "en-US")
        XCTAssertEqual(ClienteAPI.idiomaParaElServidor(localizacion: "en-GB"), "en-US")
        // Sin idioma resuelto, el de desarrollo de la app.
        XCTAssertEqual(ClienteAPI.idiomaParaElServidor(localizacion: nil), "es-AR")
    }

    func testUnaListaPaginadaSeLeeConSuCursor() async {
        struct Cosa: Decodable, Equatable { let id: String }
        let servidor = ServidorDePrueba { pedido, _ in
            pedido.consulta["cursor"] == nil
                ? .cruda(#"{"data":[{"id":"1"},{"id":"2"}],"pagination":{"next_cursor":"eyJ0Ijo+","has_more":true}}"#, http: 200)
                : .cruda(#"{"data":[{"id":"3"}],"pagination":{"has_more":false}}"#, http: 200)
        }
        let cliente = servidor.cliente()

        let primera: Resultado<Pagina<Cosa>> = await cliente.pedirPagina("/cosas", token: "acceso-1")
        XCTAssertEqual(primera, .ok(Pagina(elementos: [Cosa(id: "1"), Cosa(id: "2")],
                                           paginacion: Paginacion(nextCursor: "eyJ0Ijo+", hasMore: true))))

        let cursor = try! XCTUnwrap(primera.valor?.paginacion.nextCursor)
        let segunda: Resultado<Pagina<Cosa>> = await cliente.pedirPagina(
            "/cosas", consulta: [URLQueryItem(name: "cursor", value: cursor)])
        XCTAssertEqual(segunda.valor?.paginacion, Paginacion(nextCursor: nil, hasMore: false))

        // El cursor es opaco y vuelve TAL CUAL: un `+` sin escapar llegaría como espacio.
        XCTAssertEqual(servidor.pedidos.last?.consulta["cursor"], "eyJ0Ijo+")
        XCTAssertEqual(servidor.pedidos.last?.consultaCruda, "cursor=eyJ0Ijo%2B")
    }

    func testUnaListaSinPaginacionEsRara() async {
        struct Cosa: Decodable, Equatable { let id: String }
        let servidor = ServidorDePrueba { _, _ in .datos(#"[{"id":"1"}]"#) }

        let r: Resultado<Pagina<Cosa>> = await servidor.cliente().pedirPagina("/cosas")

        XCTAssertEqual(r, .respuestaRara(http: 200))
    }

    /// Una ruta mal escrita es un bug del cliente: no sale ningún pedido.
    func testUnaRutaSinBarraNoSaleALaRed() async {
        let servidor = ServidorDePrueba { _, _ in .datos(Self.salud) }

        let r: Resultado<Health> = await servidor.cliente().pedir(.get, "health")

        XCTAssertEqual(r, .respuestaRara(http: 0))
        XCTAssertTrue(servidor.pedidos.isEmpty)
    }
}
