import XCTest
@testable import TrainerCore

/// B-008: la sesión se renueva sola, una vez, y nunca dos a la vez.
///
/// 🛑 El servidor de mentira se porta como el de verdad en lo que importa: rota el
/// refresh en cada uso y, si le llega uno ya usado, contesta `session_revoked`
/// (`backend/src/dominios/auth/servicio.ts`). Por eso el test de los dos 401
/// concurrentes FALLA si la renovación no es única: la segunda cerraría la sesión.
final class RenovadorDeSesionTests: XCTestCase {

    /// Los reintentos de la regla 4 no duermen acá: si alguno se dispara, corre al
    /// toque y el test lo ve, en vez de seguir andando cuando el test ya terminó.
    private func renovador(_ servidor: ServidorDePrueba, _ almacen: AlmacenEnMemoria,
                           reloj: Int64 = Fixtura.ahora,
                           alCerrar: @escaping @Sendable () -> Void = {}) -> RenovadorDeSesion {
        RenovadorDeSesion(cliente: servidor.cliente(), almacen: almacen, reloj: { reloj },
                          esperar: { _ in }, alCerrar: alCerrar)
    }

    /// Con un reloj que sólo avanza cuando alguien espera: los reintentos se miden
    /// sin tiempo real.
    private func renovador(_ servidor: ServidorDePrueba, _ almacen: AlmacenEnMemoria,
                           tiempo: TiempoDePrueba,
                           esperar: (@Sendable (Int64) async -> Void)? = nil) -> RenovadorDeSesion {
        RenovadorDeSesion(cliente: servidor.cliente(), almacen: almacen, reloj: { tiempo.ahora },
                          esperar: esperar ?? { tiempo.esperar($0) })
    }

    /// Espera a que algo pase, con techo: un test roto falla en vez de colgarse.
    private func esperarHasta(_ condicion: () async -> Bool, techo: TimeInterval = 3) async {
        let limite = Date().addingTimeInterval(techo)
        while await !condicion() {
            guard Date() < limite else { return XCTFail("no pasó a tiempo") }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    /// Un servidor que acepta sólo el access indicado y rota el refresh.
    private func servidorQueRota(aceptando acceso: String, nueva: Sesion,
                                 demoraDeLaRenovacion: TimeInterval = 0) -> ServidorDePrueba {
        let jsonNueva = Fixtura.json(nueva)
        return ServidorDePrueba { pedido, hastaAhora in
            switch (pedido.metodo, pedido.ruta) {
            case (_, "/v1/me"):
                return pedido.encabezado("Authorization") == "Bearer \(acceso)"
                    ? .datos(Fixtura.perfil)
                    : .error("unauthorized", http: 401)
            case ("POST", "/v1/auth/refresh"):
                let usos = hastaAhora.filter { $0.ruta == "/v1/auth/refresh" }.count
                return usos == 1
                    ? .datos(jsonNueva, demora: demoraDeLaRenovacion)
                    : .error("session_revoked", http: 401)
            default:
                return .error("not_found", http: 404)
            }
        }
    }

    // MARK: - Una sola renovación

    func testDosNoAutorizadosAlMismoTiempoGastanUnaSolaRenovacion() async {
        // La renovación tarda: los dos 401 llegan mientras está en vuelo.
        let servidor = servidorQueRota(aceptando: "acceso-2", nueva: Fixtura.sesion(2),
                                       demoraDeLaRenovacion: 0.3)
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)
        let cierres = await renovador.cierres()

        async let a: Resultado<Perfil> = renovador.pedir(.get, "/me")
        async let b: Resultado<Perfil> = renovador.pedir(.get, "/me")
        let (ra, rb) = await (a, b)

        XCTAssertNotNil(ra.valor, "\(ra)")
        XCTAssertNotNil(rb.valor, "\(rb)")
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 1,
                       "dos renovaciones con el mismo refresh revocan la familia entera")
        XCTAssertEqual(servidor.pedidos(a: "/v1/me").count, 4, "dos pedidos y dos reintentos")
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(2))
        let cierre = await Fixtura.primerCierre(de: cierres, espera: 0.2)
        XCTAssertNil(cierre)
    }

    func testElReintentoLlevaElTokenNuevoYLaMismaClaveDeIdempotencia() async {
        let servidor = servidorQueRota(aceptando: "acceso-2", nueva: Fixtura.sesion(2))
        let renovador = renovador(servidor, AlmacenEnMemoria(Fixtura.sesion(1)))

        let r: Resultado<Perfil> = await renovador.pedir(
            .patch, "/me", cuerpo: CuerpoDePerfil(perfil: PerfilEntrada(firstName: "Iván"), anulando: []),
            claveDeIdempotencia: "intento-1")

        XCTAssertNotNil(r.valor)
        let patches = servidor.pedidos(a: "/v1/me")
        XCTAssertEqual(patches.map { $0.encabezado("Authorization") }, ["Bearer acceso-1", "Bearer acceso-2"])
        // Es el MISMO intento: el primero no llegó a escribir porque el token no pasó.
        XCTAssertEqual(patches.map { $0.encabezado("Idempotency-Key") }, ["intento-1", "intento-1"])
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").first?.json?["refresh_token"] as? String,
                       "refresco-1")
    }

    // MARK: - Por adelantado

    func testSiAlAccessLeQuedanMenosDe30SegundosSeRenuevaAntesDePedir() async {
        let servidor = servidorQueRota(aceptando: "acceso-2", nueva: Fixtura.sesion(2))
        let renovador = renovador(servidor, AlmacenEnMemoria(Fixtura.sesion(1, venceEn: 10_000)))

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertNotNil(r.valor)
        XCTAssertEqual(servidor.pedidos.map(\.ruta), ["/v1/auth/refresh", "/v1/me"],
                       "un pedido que sale con un token a punto de vencer llega vencido")
    }

    func testConMasDe30SegundosNoSeRenueva() async {
        let servidor = servidorQueRota(aceptando: "acceso-1", nueva: Fixtura.sesion(2))
        let renovador = renovador(servidor, AlmacenEnMemoria(Fixtura.sesion(1, venceEn: 31_000)))

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertNotNil(r.valor)
        XCTAssertTrue(servidor.pedidos(a: "/v1/auth/refresh").isEmpty)
    }

    /// Con el reloj del teléfono una hora adelantado, cada token recién emitido ya
    /// "vence". Sin la detección, se renovaría antes de CADA pedido.
    func testConElRelojAdelantadoNoSeRenuevaAntesDeCadaPedido() async {
        let servidor = servidorQueRota(aceptando: "acceso-2", nueva: Fixtura.sesion(2))
        let renovador = renovador(servidor, AlmacenEnMemoria(Fixtura.sesion(1)),
                                  reloj: Fixtura.ahora + 3_600_000)

        let primero: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        let segundo: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertNotNil(primero.valor)
        XCTAssertNotNil(segundo.valor)
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 1)
    }

    // MARK: - Un reintento, nunca un bucle

    func testUnNoAutorizadoConElTokenRecienRenovadoCierraSinBucle() async {
        let servidor = servidorQueRota(aceptando: "ninguno", nueva: Fixtura.sesion(2))
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)
        let cierres = await renovador.cierres()

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertEqual(r, .rechazado(codigo: "unauthorized", http: 401))
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 1)
        XCTAssertEqual(servidor.pedidos(a: "/v1/me").count, 2, "un pedido y UN reintento")
        XCTAssertNil(almacen.leer())
        let cierre = await Fixtura.primerCierre(de: cierres)
        XCTAssertEqual(cierre, .rechazada(codigo: "unauthorized"))
    }

    // MARK: - Sesión muerta

    func testUnRefreshInvalidoBorraLasCredencialesYAvisa() async {
        let servidor = ServidorDePrueba { pedido, _ in
            pedido.ruta == "/v1/auth/refresh"
                ? .error("invalid_refresh_token", http: 401)
                : .error("unauthorized", http: 401)
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)
        let cierres = await renovador.cierres()

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertEqual(r, .rechazado(codigo: "invalid_refresh_token", http: 401))
        XCTAssertNil(almacen.leer(), "las credenciales no pueden sobrevivir a una sesión muerta")
        let haySesion = await renovador.haySesion
        XCTAssertFalse(haySesion)
        let cierre = await Fixtura.primerCierre(de: cierres)
        XCTAssertEqual(cierre, .rechazada(codigo: "invalid_refresh_token"))
    }

    func testUnaSesionRevocadaAlRenovarBorraYAvisa() async {
        let servidor = ServidorDePrueba { pedido, _ in
            pedido.ruta == "/v1/auth/refresh"
                ? .error("session_revoked", http: 401)
                : .error("unauthorized", http: 401)
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)
        let cierres = await renovador.cierres()

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertEqual(r, .rechazado(codigo: "session_revoked", http: 401))
        XCTAssertNil(almacen.leer())
        let cierre = await Fixtura.primerCierre(de: cierres)
        XCTAssertEqual(cierre, .rechazada(codigo: "session_revoked"))
    }

    /// `GET /me` comprueba que la sesión siga viva (`exigirSesionViva`): la revocación
    /// puede llegar sin pasar por la renovación.
    func testUnaSesionRevocadaEnUnPedidoComunTambienCierra() async {
        let servidor = ServidorDePrueba { _, _ in .error("session_revoked", http: 401) }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)
        let cierres = await renovador.cierres()

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertEqual(r, .rechazado(codigo: "session_revoked", http: 401))
        XCTAssertTrue(servidor.pedidos(a: "/v1/auth/refresh").isEmpty, "revocada no se arregla renovando")
        XCTAssertNil(almacen.leer())
        let cierre = await Fixtura.primerCierre(de: cierres)
        XCTAssertEqual(cierre, .rechazada(codigo: "session_revoked"))
    }

    func testSinRedAlRenovarNoTiraLasCredenciales() async {
        let servidor = ServidorDePrueba { pedido, _ in
            pedido.ruta == "/v1/auth/refresh" ? .sinRed : .error("unauthorized", http: 401)
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)
        let cierres = await renovador.cierres()

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertEqual(r, .sinRed)
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(1), "sin señal en el sótano no es una sesión muerta")
        let cierre = await Fixtura.primerCierre(de: cierres, espera: 0.2)
        XCTAssertNil(cierre)
    }

    /// Un 429 al renovar no es una sesión muerta, y la pantalla tiene que ver el 429,
    /// no un "se venció la sesión" de una sesión que sigue viva.
    func testUnErrorTransitorioAlRenovarDevuelveEseErrorYNoCierra() async {
        let servidor = ServidorDePrueba { pedido, _ in
            pedido.ruta == "/v1/auth/refresh"
                ? .error("rate_limited", http: 429)
                : .error("unauthorized", http: 401)
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertEqual(r, .rechazado(codigo: "rate_limited", http: 429))
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(1))
        await renovador.esperarLosReintentos()
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 1,
                       "un 429 es una respuesta que llegó: no hay nada que reintentar solo")
    }

    func testSinSesionNoSeTocaLaRed() async {
        let servidor = ServidorDePrueba { _, _ in .datos(Fixtura.perfil) }
        let renovador = renovador(servidor, AlmacenEnMemoria())

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertEqual(r, .rechazado(codigo: "unauthorized", http: 401))
        XCTAssertTrue(servidor.pedidos.isEmpty)
    }

    // MARK: - Cerrar sesión

    func testCerrarSesionRevocaEnElServidorYBorra() async {
        let servidor = ServidorDePrueba { _, _ in .sinContenido }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)
        let cierres = await renovador.cierres()

        await renovador.cerrarSesion()
        XCTAssertNil(almacen.leer(), "el llavero ya está vacío cuando vuelve")
        await renovador.esperarElAvisoDeCierre()

        let logout = try! XCTUnwrap(servidor.pedidos(a: "/v1/auth/logout").first)
        XCTAssertEqual(logout.metodo, "POST")
        XCTAssertEqual(logout.encabezado("Authorization"), "Bearer acceso-1")
        XCTAssertEqual(logout.json?["refresh_token"] as? String, "refresco-1")
        XCTAssertNil(almacen.leer())
        let cierre = await Fixtura.primerCierre(de: cierres)
        XCTAssertEqual(cierre, .laPersonaCerro)
    }

    func testCerrarSesionSinRedBorraIgual() async {
        let servidor = ServidorDePrueba { _, _ in .sinRed }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen)

        await renovador.cerrarSesion()

        XCTAssertNil(almacen.leer(), "salir no puede depender de tener señal")
        let haySesion = await renovador.haySesion
        XCTAssertFalse(haySesion)
    }

    /// Con el access vencido, el logout daría 401 y la sesión quedaría viva del otro
    /// lado: se renueva una vez para revocar lo último.
    func testCerrarSesionConElAccessVencidoRenuevaParaRevocarLoUltimo() async {
        let jsonNueva = Fixtura.json(Fixtura.sesion(2))
        let servidor = ServidorDePrueba { pedido, _ in
            pedido.ruta == "/v1/auth/refresh" ? .datos(jsonNueva) : .sinContenido
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1, venceEn: -1_000))
        let renovador = renovador(servidor, almacen)

        await renovador.cerrarSesion()
        await renovador.esperarElAvisoDeCierre()

        let logout = try! XCTUnwrap(servidor.pedidos(a: "/v1/auth/logout").first)
        XCTAssertEqual(logout.encabezado("Authorization"), "Bearer acceso-2")
        XCTAssertEqual(logout.json?["refresh_token"] as? String, "refresco-2")
        XCTAssertNil(almacen.leer(), "la sesión renovada para cerrar no se vuelve a guardar")
    }

    func testLaSesionGuardadaSeUsaAlArrancar() async {
        let servidor = ServidorDePrueba { _, _ in .datos(Fixtura.perfil) }
        let renovador = renovador(servidor, AlmacenEnMemoria(Fixtura.sesion(1)))

        let haySesion = await renovador.haySesion
        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")

        XCTAssertTrue(haySesion)
        XCTAssertTrue(renovador.habiaSesionAlArrancar, "la app decide Home o bienvenida con esto, sin esperar")
        XCTAssertNotNil(r.valor)
        XCTAssertEqual(servidor.pedidos.first?.encabezado("Authorization"), "Bearer acceso-1")
    }

    /// `habiaSesionAlArrancar` es una foto del arranque: no se mueve con lo que
    /// pase después. Si siguiera a la sesión, cerrar sesión cambiaría la pantalla
    /// inicial de una app que ya arrancó.
    func testHabiaSesionAlArrancarEsLaFotoDelArranque() async {
        let servidor = ServidorDePrueba { _, _ in .sinContenido }
        let conSesion = renovador(servidor, AlmacenEnMemoria(Fixtura.sesion(1)))
        let sinSesion = renovador(servidor, AlmacenEnMemoria())

        await conSesion.cerrarSesion()
        await sinSesion.establecer(Fixtura.sesion(2))

        XCTAssertTrue(conSesion.habiaSesionAlArrancar)
        XCTAssertFalse(sinSesion.habiaSesionAlArrancar)
    }

    // MARK: - Cerrar sesión sin esperar a nadie

    /// 🛑 Antes, cerrar sesión esperaba a la renovación en vuelo —hasta diez
    /// segundos— y RECIÉN después borraba el llavero. Si la app se cerraba en ese
    /// rato, el próximo arranque entraba con la sesión que la persona había cerrado.
    func testCerrarSesionBorraYaAunqueHayaUnaRenovacionEnVuelo() async throws {
        let jsonNueva = Fixtura.json(Fixtura.sesion(2))
        let servidor = ServidorDePrueba { pedido, _ in
            switch pedido.ruta {
            case "/v1/auth/refresh": return .datos(jsonNueva, demora: 1.5)
            case "/v1/auth/logout": return .sinContenido
            default: return .error("unauthorized", http: 401)
            }
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1, venceEn: 10_000))
        let renovador = renovador(servidor, almacen)
        let pedido = Task { () -> Resultado<Perfil> in await renovador.pedir(.get, "/me") }
        await esperarHasta { servidor.pedidos(a: "/v1/auth/refresh").count == 1 }

        let inicio = Date()
        await renovador.cerrarSesion()
        let demora = Date().timeIntervalSince(inicio)

        XCTAssertNil(almacen.leer(), "el llavero se borra antes de volver")
        XCTAssertLessThan(demora, 0.5, "no espera a la renovación que está en vuelo")

        await renovador.esperarElAvisoDeCierre()
        let logout = try XCTUnwrap(servidor.pedidos(a: "/v1/auth/logout").first)
        XCTAssertEqual(logout.json?["refresh_token"] as? String, "refresco-2",
                       "se revoca el refresh de la renovación tardía, no el que ya rotó")
        XCTAssertNil(almacen.leer(), "la renovación que llegó tarde no revive la sesión")
        let respuesta = await pedido.value
        XCTAssertEqual(respuesta, .rechazado(codigo: "unauthorized", http: 401))
    }

    /// Lo que se va con la sesión se va con CUALQUIER cierre: el que pide la persona
    /// y el que decide el servidor.
    func testAlCerrarCorreConCadaCierreDeSesion() async {
        let contador = ContadorDePrueba()

        let alRenovar = renovador(ServidorDePrueba { pedido, _ in
            pedido.ruta == "/v1/auth/refresh"
                ? .error("session_revoked", http: 401)
                : .error("unauthorized", http: 401)
        }, AlmacenEnMemoria(Fixtura.sesion(1)), alCerrar: { contador.sumar() })
        let _: Resultado<Perfil> = await alRenovar.pedir(.get, "/me")
        XCTAssertEqual(contador.valor, 1, "una revocación también se lleva lo que quedó en el teléfono")

        let enUnPedido = renovador(ServidorDePrueba { _, _ in .error("session_revoked", http: 401) },
                                   AlmacenEnMemoria(Fixtura.sesion(1)), alCerrar: { contador.sumar() })
        let _: Resultado<Perfil> = await enUnPedido.pedir(.get, "/me")
        XCTAssertEqual(contador.valor, 2)

        let aMano = renovador(ServidorDePrueba { _, _ in .sinContenido },
                              AlmacenEnMemoria(Fixtura.sesion(1)), alCerrar: { contador.sumar() })
        await aMano.cerrarSesion()
        await aMano.cerrarSesion()
        XCTAssertEqual(contador.valor, 3, "la segunda vez ya no hay sesión que cerrar")
    }

    // MARK: - Regla 4: la respuesta que se perdió

    /// La primera renovación se queda sin respuesta; la segunda rota; una tercera con
    /// el refresh viejo es reuso y el servidor revoca. `/me` sólo acepta el access
    /// nuevo.
    private func servidorQueRotaTrasPerderLaPrimera(demoraDelReintento: TimeInterval = 0) -> ServidorDePrueba {
        let jsonNueva = Fixtura.json(Fixtura.sesion(2))
        return ServidorDePrueba { pedido, hastaAhora in
            switch pedido.ruta {
            case "/v1/me":
                return pedido.encabezado("Authorization") == "Bearer acceso-2"
                    ? .datos(Fixtura.perfil)
                    : .error("unauthorized", http: 401)
            case "/v1/auth/refresh":
                switch hastaAhora.filter({ $0.ruta == "/v1/auth/refresh" }).count {
                case 1: return .sinRed
                case 2: return .datos(jsonNueva, demora: demoraDelReintento)
                default: return .error("session_revoked", http: 401)
                }
            default:
                return .error("not_found", http: 404)
            }
        }
    }

    /// El servidor pudo haber rotado sin que la respuesta volviera, y nadie iba a
    /// volver a pedir a tiempo: la sesión nueva quedaba del otro lado.
    func testUnaRenovacionSinRespuestaSeReintentaSolaConElMismoRefresh() async {
        let jsonNueva = Fixtura.json(Fixtura.sesion(2))
        let servidor = ServidorDePrueba { pedido, hastaAhora in
            guard pedido.ruta == "/v1/auth/refresh" else { return .error("unauthorized", http: 401) }
            switch hastaAhora.filter({ $0.ruta == "/v1/auth/refresh" }).count {
            case 1: return .sinRed
            case 2: return .cruda("<html>502 Bad Gateway</html>", http: 502)
            default: return .datos(jsonNueva)
            }
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let tiempo = TiempoDePrueba()
        let renovador = renovador(servidor, almacen, tiempo: tiempo)
        let cierres = await renovador.cierres()

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        XCTAssertEqual(r, .sinRed, "quien pidió se entera ya: no espera los reintentos")

        await renovador.esperarLosReintentos()

        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").map { $0.json?["refresh_token"] as? String },
                       ["refresco-1", "refresco-1", "refresco-1"], "siempre el MISMO refresh")
        XCTAssertEqual(tiempo.esperas, [5_000, 15_000], "a los 5 y a los 20 segundos del primero")
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(2))
        let cierre = await Fixtura.primerCierre(de: cierres, espera: 0.1)
        XCTAssertNil(cierre)
    }

    /// 🛑 La regla 3 con la 4: mientras el reintento espera, un pedido que necesita
    /// renovar no lo espera —renueva él—, y el reintento, al despertar, ve la sesión
    /// nueva y no gasta el refresh viejo. Si lo gastara, el servidor revocaría todo.
    func testSiUnPedidoRenuevaMientrasElReintentoEsperaNoSaleOtro() async {
        let servidor = servidorQueRotaTrasPerderLaPrimera()
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let tiempo = TiempoDePrueba()
        let compuerta = CompuertaDePrueba()
        let renovador = renovador(servidor, almacen, tiempo: tiempo, esperar: { ms in
            tiempo.esperar(ms)
            await compuerta.pasar()
        })
        let cierres = await renovador.cierres()

        let primero: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        XCTAssertEqual(primero, .sinRed)
        await esperarHasta { compuerta.hayAlguienEsperando }

        let segundo: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        XCTAssertNotNil(segundo.valor, "el pedido no espera al reintento: renueva y sigue")

        compuerta.abrir()
        await renovador.esperarLosReintentos()

        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 2)
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(2))
        let cierre = await Fixtura.primerCierre(de: cierres, espera: 0.1)
        XCTAssertNil(cierre)
    }

    /// Y al revés: si el reintento ya salió, el pedido que necesita renovar espera
    /// ESE en vez de mandar otro.
    func testUnPedidoQueNecesitaRenovarEsperaAlReintentoQueYaSalio() async {
        let servidor = servidorQueRotaTrasPerderLaPrimera(demoraDelReintento: 0.3)
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen, tiempo: TiempoDePrueba())
        let cierres = await renovador.cierres()

        let primero: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        XCTAssertEqual(primero, .sinRed)
        await esperarHasta { servidor.pedidos(a: "/v1/auth/refresh").count == 2 }

        let segundo: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        await renovador.esperarLosReintentos()

        XCTAssertNotNil(segundo.valor)
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 2,
                       "una sola renovación en vuelo, también con los reintentos")
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(2))
        let cierre = await Fixtura.primerCierre(de: cierres, espera: 0.1)
        XCTAssertNil(cierre)
    }

    /// 🛑 Pasados los dos minutos, el mismo refresh ya no devuelve el mismo sucesor:
    /// es reuso y revoca la familia. El reintento no puede ser quien la cierre.
    func testPasadaLaVentanaNoSeReintenta() async {
        let tiempo = TiempoDePrueba()
        let servidor = ServidorDePrueba { pedido, _ in
            guard pedido.ruta == "/v1/auth/refresh" else { return .error("unauthorized", http: 401) }
            // Un pedido que se quedó colgado hasta el timeout de la red, y más.
            tiempo.avanzar(RenovadorDeSesion.ventanaDeReintentoMs + 1_000)
            return .sinRed
        }
        let almacen = AlmacenEnMemoria(Fixtura.sesion(1))
        let renovador = renovador(servidor, almacen, tiempo: tiempo)

        let r: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        await renovador.esperarLosReintentos()

        XCTAssertEqual(r, .sinRed)
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 1)
        XCTAssertEqual(tiempo.esperas, [])
        XCTAssertEqual(almacen.leer(), Fixtura.sesion(1), "sin respuesta no es una sesión muerta")
    }

    /// Cerrar la sesión corta los reintentos: después del cierre no sale ningún
    /// refresh más con el token de quien se fue.
    func testCerrarSesionCortaLosReintentos() async {
        let servidor = ServidorDePrueba { pedido, _ in
            switch pedido.ruta {
            case "/v1/auth/refresh": return .sinRed
            case "/v1/auth/logout": return .sinContenido
            default: return .error("unauthorized", http: 401)
            }
        }
        let tiempo = TiempoDePrueba()
        let compuerta = CompuertaDePrueba()
        let renovador = renovador(servidor, AlmacenEnMemoria(Fixtura.sesion(1)), tiempo: tiempo, esperar: { ms in
            tiempo.esperar(ms)
            await compuerta.pasar()
        })

        let _: Resultado<Perfil> = await renovador.pedir(.get, "/me")
        await esperarHasta { compuerta.hayAlguienEsperando }
        await renovador.cerrarSesion()
        compuerta.abrir()
        await renovador.esperarLosReintentos()
        await renovador.esperarElAvisoDeCierre()

        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/refresh").count, 1)
        XCTAssertEqual(servidor.pedidos(a: "/v1/auth/logout").count, 1)
    }
}
