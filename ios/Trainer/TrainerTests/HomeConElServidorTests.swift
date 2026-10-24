import Combine
import Foundation
import Testing
@testable import Trainer
@testable import TrainerCore

// =============================================================================
// El Home con las piezas de verdad —`ServiciosDeLaApp.armar`,
// `RepositorioDelServidor`, `FuenteDelServidor` y la caché en disco— sobre una red
// de mentira (`RedDePrueba`, de `SesionDeVerdadTests`).
//
// Dos cosas que un doble del repositorio no puede probar: que la app de verdad no
// complete con la maqueta del diseño cuando no hay nada, y que lo guardado del
// servidor se vaya con la sesión, por el mismo gancho que borra el llavero.
// =============================================================================

@MainActor
@Suite("El Home con lo que manda el servidor, y nunca con la maqueta")
struct HomeConElServidorTests {

    private let ahora = RenovadorDeSesion.ahoraEnMs()

    private func sesion(_ numero: Int) -> Sesion {
        Sesion(accessToken: "acceso-\(numero)", accessExpiresAtMs: ahora + 900_000,
               refreshToken: "refresco-\(numero)", refreshExpiresAtMs: ahora + 86_400_000, userId: "u-1")
    }

    private func cacheDeUnTest() -> CacheDelServidor {
        CacheDelServidor(nombre: "tests-home-\(UUID().uuidString)")
    }

    private func seriesDeUnTest() -> AlmacenDeSeries {
        AlmacenDeSeries(nombre: "tests-home-\(UUID().uuidString).json")
    }

    /// Un cliente cuyo host no atiende nadie: cada pedido termina en "sin red".
    private func clienteSinRed() -> ClienteAPI {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.protocolClasses = [ProtocoloDeRedDePrueba.self]
        return ClienteAPI(base: URL(string: "https://sin-red-\(UUID().uuidString.lowercased()).invalid/v1")!,
                          sesion: URLSession(configuration: configuracion), idioma: { "es-AR" })
    }

    /// La caché con algo adentro, como la deja una sesión que ya habló con el servidor.
    private func cacheConDatos() -> CacheDelServidor {
        let cache = cacheDeUnTest()
        cache.guardar(["dias": 71], en: .plan, ahoraMs: ahora)
        cache.guardar(["kcal": 2750], en: .nutricion, ahoraMs: ahora)
        cache.guardar(["ejercicios": 6], en: .rutina, ahoraMs: ahora)
        return cache
    }

    private func cacheVacia(_ cache: CacheDelServidor) -> Bool {
        CacheDelServidor.Clave.allCases.allSatisfy { cache.leer($0, como: [String: Int].self) == nil }
    }

    /// Espera a que algo pase, con techo: un test roto falla en vez de colgarse.
    private func esperar(hasta condicion: () -> Bool) async {
        var intentos = 0
        while !condicion(), intentos < 600 {
            try? await Task.sleep(nanoseconds: 5_000_000)
            intentos += 1
        }
    }

    /// 🛑 La primera vez que alguien abre la app, en el sótano del gimnasio: sin nada
    /// guardado y sin red. El Home dice eso; los datos del diseño serían el plan de
    /// otra persona.
    @Test("Sin nada guardado y sin red, el Home no muestra los datos de ejemplo")
    func sinCacheNiRedNoHayMaqueta() async {
        let cache = cacheDeUnTest()
        let series = seriesDeUnTest()
        defer {
            cache.borrarTodo()
            series.borrar()
        }
        let servicios = ServiciosDeLaApp.armar(cliente: clienteSinRed(), almacen: AlmacenEnMemoria(sesion(1)),
                                               series: series, cache: cache)

        let estado = EstadoHome(repositorio: servicios.repositorioDelHome())
        #expect(estado.plan == nil, "al abrir no hay nada guardado")
        await estado.actualizar()

        #expect(estado.plan == nil)
        #expect(estado.bloque == nil)
        #expect(estado.sesion == nil)
        #expect(estado.rutina.isEmpty)
        #expect(estado.objetivoNutricional == nil)
        #expect(estado.comidas.isEmpty)
        #expect(estado.contenido.plan.problema == .sinRed, "la pantalla puede decir por qué no hay nada")
        #expect(estado.contenido.nutricion.problema == .sinRed)
        #expect(estado.repositorio.platosFrecuentes().isEmpty)
        #expect(estado.repositorio.sesionEnCurso().metros == 0, "sin GPS no hay una salida inventada")
    }

    /// 🛑 Lo que se guardó del servidor es dato de salud de quien se fue.
    @Test("Un session_revoked se lleva la caché del Home junto con el llavero")
    func laCacheSeVaConUnaSesionRevocada() async {
        let red = RedDePrueba { _, ruta in
            ruta == "/v1/me" ? .error("session_revoked", http: 401) : .error("not_found", http: 404)
        }
        let cache = cacheConDatos()
        let series = seriesDeUnTest()
        defer {
            cache.borrarTodo()
            series.borrar()
        }
        #expect(!cacheVacia(cache))
        let almacen = AlmacenEnMemoria(sesion(1))
        let servicios = ServiciosDeLaApp.armar(cliente: red.cliente(), almacen: almacen, series: series, cache: cache)
        let flujo = FlujoEntrada(servicio: servicios.cuenta, consultarVersion: servicios.consultarVersion)
        let escucha = Task { await flujo.escucharCierres() }
        defer { escucha.cancel() }
        try? await Task.sleep(nanoseconds: 100_000_000)

        await flujo.cargarPerfil()
        await esperar { flujo.pantalla == .login }

        #expect(flujo.pantalla == .login)
        #expect(almacen.leer() == nil)
        #expect(cacheVacia(cache), "el plan y la nutrición de quien se fue no quedan para el siguiente")
    }

    @Test("Cerrar sesión se lleva la caché del Home antes de cambiar de pantalla")
    func laCacheSeVaAlCerrarSesion() async {
        let red = RedDePrueba { _, ruta in
            ruta == "/v1/auth/logout" ? .init(http: 204, cuerpo: "") : .error("not_found", http: 404)
        }
        let cache = cacheConDatos()
        let series = seriesDeUnTest()
        defer {
            cache.borrarTodo()
            series.borrar()
        }
        let servicios = ServiciosDeLaApp.armar(cliente: red.cliente(), almacen: AlmacenEnMemoria(sesion(1)),
                                               series: series, cache: cache)
        let flujo = FlujoEntrada(servicio: servicios.cuenta)

        var vaciaAlCambiarDePantalla: Bool?
        let observador = flujo.$pantalla.dropFirst().sink { _ in
            if vaciaAlCambiarDePantalla == nil { vaciaAlCambiarDePantalla = cacheVacia(cache) }
        }
        defer { observador.cancel() }

        await flujo.cerrarSesion()

        #expect(flujo.pantalla == .bienvenida)
        #expect(vaciaAlCambiarDePantalla == true)
    }

    /// AGENTS.md §6: el plan del jueves no depende de tener señal el jueves.
    @Test("Lo que llegó bien se ve al volver a abrir sin red, con el aviso de que es lo guardado")
    func loGuardadoSeVeSinRed() async throws {
        let plan = try FixturasDelServidor.texto("plan")
        let rutina = try FixturasDelServidor.texto("rutina-del-dia")
        let nutricion = try FixturasDelServidor.texto("nutricion-del-dia")
        let red = RedDePrueba { _, ruta in
            switch ruta {
            case "/v1/plan": return .init(http: 200, cuerpo: plan)
            case "/v1/plan/routine": return .init(http: 200, cuerpo: rutina)
            case "/v1/nutrition/day": return .init(http: 200, cuerpo: nutricion)
            default: return .error("not_found", http: 404)
            }
        }
        let cache = cacheDeUnTest()
        let series = seriesDeUnTest()
        defer {
            cache.borrarTodo()
            series.borrar()
        }

        let conRed = ServiciosDeLaApp.armar(cliente: red.cliente(), almacen: AlmacenEnMemoria(sesion(1)),
                                            series: series, cache: cache)
        let primera = EstadoHome(repositorio: conRed.repositorioDelHome())
        await primera.actualizar()
        #expect(primera.bloque?.totalDeSemanas == 11)
        #expect(primera.rutina.count == 6)
        #expect(primera.objetivoNutricional?.kcal == 2_750)
        #expect(!primera.contenido.plan.desactualizada)
        #expect(Set(red.pedidos).isSuperset(of: ["GET /v1/nutrition/day", "GET /v1/plan", "GET /v1/plan/routine"]))

        let sinRed = ServiciosDeLaApp.armar(cliente: clienteSinRed(), almacen: AlmacenEnMemoria(sesion(1)),
                                            series: series, cache: cache)
        let segunda = EstadoHome(repositorio: sinRed.repositorioDelHome())
        #expect(segunda.bloque?.totalDeSemanas == 11, "lo guardado se ve antes de preguntar")
        await segunda.actualizar()

        #expect(segunda.bloque?.totalDeSemanas == 11, "un pedido que falla no borra lo último bueno")
        #expect(segunda.contenido.plan.desactualizada, "y la pantalla puede decir que es lo guardado")
        #expect(segunda.contenido.plan.problema == .sinRed)
    }

    /// Decisión 0006, con las piezas de verdad: una serie registrada sale sola, y con
    /// algo pendiente no se trae la sesión antes de mandarlo.
    @Test("Una serie registrada en el Home sale sola al servidor, antes de traer nada")
    func unaSerieSaleSola() async {
        let red = RedDePrueba { _, _ in .error("service_unavailable", http: 503) }
        let cache = cacheDeUnTest()
        let series = seriesDeUnTest()
        // El sincronizador del Home usa el archivo de siempre: se deja como estaba.
        let delHome = AlmacenDeSeries()
        delHome.borrar()
        defer {
            cache.borrarTodo()
            series.borrar()
            delHome.borrar()
        }
        let servicios = ServiciosDeLaApp.armar(cliente: red.cliente(), almacen: AlmacenEnMemoria(sesion(1)),
                                               series: series, cache: cache)
        let estado = EstadoHome(repositorio: servicios.repositorioDelHome())
        let post = "POST /v1/gym/sessions/\(estado.idDeSesion)/sets"

        estado.sincronizador.registrar(clave: ClaveDeSerie(sesion: estado.idDeSesion, ejercicio: "sentadilla", numero: 1),
                                       hecha: true, repeticiones: 8, pesoGramos: 60_000)
        await esperar { red.pedidos.contains(post) }

        #expect(red.pedidos.contains(post))
        #expect(!red.pedidos.contains("GET /v1/gym/sessions/\(estado.idDeSesion)"),
                "con una serie pendiente, traer la sesión antes le ganaría a lo que no se mandó")
        #expect(estado.sincronizador.series.first?.recibidaEnServidorMs == nil, "con un 503, sigue pendiente")
    }

    @Test("Una comida anotada sin señal se ve, espera en la cola y no desaparece al actualizar")
    func unaComidaSinSenal() async {
        let cache = cacheDeUnTest()
        let series = seriesDeUnTest()
        defer {
            cache.borrarTodo()
            series.borrar()
        }
        let servicios = ServiciosDeLaApp.armar(cliente: clienteSinRed(), almacen: AlmacenEnMemoria(sesion(1)),
                                               series: series, cache: cache)
        let estado = EstadoHome(repositorio: servicios.repositorioDelHome())
        let avena = Comida(minutoDelDia: 7 * 60, nombre: "Avena con banana", kcal: 420,
                           carbohidratosG: 72, proteinaG: 12, grasaG: 9)

        estado.agregar(avena)
        await estado.actualizar()

        #expect(estado.comidas.map(\.id) == [avena.id], "lo anotado no desaparece porque el servidor no contestó")
        #expect(cache.leer(.comidasPendientes, como: [OperacionDeComida].self)?.valor.map(\.id) == [avena.id],
                "espera en disco, con su id")

        estado.quitarComida(avena.id)
        await estado.actualizar()

        #expect(estado.comidas.isEmpty, "lo borrado no vuelve")
        #expect(cache.leer(.comidasPendientes, como: [OperacionDeComida].self)?.valor == [.borrar(id: avena.id)],
                "el DELETE espera en la cola, y el PUT que no subió ya no hace falta")
    }

    @Test("Con red, una comida sale con PUT a su id, y borrarla sale con DELETE")
    func unaComidaConRed() async {
        let red = RedDePrueba { metodo, ruta in
            if metodo == "PUT", ruta.hasPrefix("/v1/meals/") {
                let id = ruta.dropFirst("/v1/meals/".count)
                return .init(http: 200, cuerpo: #"{"data":{"id":"\#(id)","eaten_at_ms":1,"name":"Avena","kcal":420,"carbs_g":72,"protein_g":12,"fat_g":9,"created_at_ms":1,"updated_at_ms":1}}"#)
            }
            if metodo == "DELETE" { return .init(http: 204, cuerpo: "") }
            return .error("service_unavailable", http: 503)
        }
        let cache = cacheDeUnTest()
        let series = seriesDeUnTest()
        defer {
            cache.borrarTodo()
            series.borrar()
        }
        let servicios = ServiciosDeLaApp.armar(cliente: red.cliente(), almacen: AlmacenEnMemoria(sesion(1)),
                                               series: series, cache: cache)
        let estado = EstadoHome(repositorio: servicios.repositorioDelHome())
        let avena = Comida(minutoDelDia: 7 * 60, nombre: "Avena con banana", kcal: 420,
                           carbohidratosG: 72, proteinaG: 12, grasaG: 9)
        let sinCola = { cache.leer(.comidasPendientes, como: [OperacionDeComida].self) == nil }

        estado.agregar(avena)
        await esperar { red.pedidos.contains("PUT /v1/meals/\(avena.id)") && sinCola() }

        #expect(red.pedidos.contains("PUT /v1/meals/\(avena.id)"))
        #expect(sinCola(), "subió: no queda nada esperando")

        estado.quitarComida(avena.id)
        await esperar { red.pedidos.contains("DELETE /v1/meals/\(avena.id)") && sinCola() }

        #expect(red.pedidos.contains("DELETE /v1/meals/\(avena.id)"))
        #expect(sinCola())
    }

    /// AGENTS.md §8 y §12.1: dato de salud, cifrado hasta el primer desbloqueo.
    @Test("La caché del Home queda en disco con Data Protection")
    func laCacheEstaProtegida() throws {
        let nombre = "tests-home-\(UUID().uuidString)"
        let cache = CacheDelServidor(nombre: nombre)
        defer { cache.borrarTodo() }
        #expect(cache.guardar(["kcal": 2750], en: .nutricion, ahoraMs: ahora))

        let soporte = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: false)
        let carpeta = soporte.appendingPathComponent(nombre, isDirectory: true)
        let archivo = carpeta.appendingPathComponent("nutricion.json")
        #expect(CacheDelServidor.opcionesDeEscritura.contains(.completeFileProtectionUntilFirstUserAuthentication))
        // 🪤 El simulador no implementa Data Protection y no devuelve la clase del
        // archivo: acá sólo se puede atar la opción con la que se escribe. En un
        // teléfono, el atributo tiene que ser éste.
        let atributos = try FileManager.default.attributesOfItem(atPath: archivo.path)
        if let proteccion = atributos[.protectionKey] as? FileProtectionType {
            #expect(proteccion == .completeUntilFirstUserAuthentication)
        }
        #expect(try carpeta.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }
}

@MainActor
@Suite("Resiliencia del mapa ante aperturas y cierres rápidos")
struct MapaResilienteTests {
    @Test("El gestor de mapa reutiliza la misma instancia sin recrear el contexto Metal")
    func reutilizacionDeMapa() {
        let mapa1 = GestorDeMapa.shared.obtenerMapa()
        let mapa2 = GestorDeMapa.shared.obtenerMapa()
        #expect(mapa1 === mapa2, "la instancia se reutiliza para evitar colisiones y destrucción de Metal")
    }

    @Test("El contenedor aloja y desaloja el mapa sin dejarlo como subvista al cerrar")
    func cicloDeVidaDelContenedor() {
        let contenedor = ContenedorMapaView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        let mapa = GestorDeMapa.shared.obtenerMapa()

        contenedor.alojar(mapa: mapa)
        #expect(mapa.superview === contenedor)

        contenedor.desalojar()
        #expect(mapa.superview == nil, "al cerrar se retira de la jerarquía para que UIKit no lo redimensione durante la animación")
    }

    @Test("Múltiples aperturas y cierres sucesivos en menos de 5 segundos no crashean ni rompen la jerarquía")
    func aperturasYCierresRapidos() {
        for _ in 0..<10 {
            let contenedor = ContenedorMapaView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let mapa = GestorDeMapa.shared.obtenerMapa()
            contenedor.alojar(mapa: mapa)
            #expect(mapa.superview === contenedor)
            contenedor.desalojar()
            #expect(mapa.superview == nil)
        }
    }
}
