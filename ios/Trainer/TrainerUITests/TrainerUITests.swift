import XCTest

// =============================================================================
// Tests de UI del flujo de entrada.
//
// 🛑 POR QUÉ EXISTEN. El 2026-09-09 un cambio que compiló sin un solo warning
// dejó las 16 pantallas de `PantallaPaso` **sin contenido y con dos flechas de
// volver**: agregar un parámetro de closure antes del `@ViewBuilder contenido`
// hizo que Swift emparejara la trailing closure con el parámetro equivocado.
// Los 18 tests unitarios pasaban, el build estaba limpio, y la app estaba rota.
//
// Estos tests miran lo único que lo habría detectado: que la pantalla tenga UNA
// flecha y que su contenido esté en pantalla.
// =============================================================================

final class FlujoDeEntradaUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// 🛑 Los tests de UI NO hablan con ningún servidor ni tocan el llavero.
    ///
    /// `-serviciosDePrueba` (sólo en DEBUG, `ServiciosDeLaApp`) arma la app con una
    /// cuenta que contesta "sin red" a todo y sin sesión guardada: cada pantalla
    /// muestra siempre el mismo estado. Antes, lo que se veía en `regAviso` —y la
    /// puerta de versión del arranque— dependía de lo que contestara la red en ese
    /// momento. `-apiBase` a un puerto vacío queda de segunda red.
    static let sinServidor = ["-serviciosDePrueba", "-apiBase", "http://127.0.0.1:9/v1"]

    /// Arranca la app directo en una pantalla, en español y con datos de ejemplo.
    private func abrir(_ pantalla: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-pantallaInicial", pantalla,
            "-datosDeEjemplo",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_AR",
        ] + Self.sinServidor
        app.launch()
        return app
    }

    // MARK: - Una flecha, no dos

    func testCadaPantallaTieneComoMuchoUnaFlechaDeVolver() {
        let conFlecha = ["login", "claveCorreo", "claveCodigo", "claveNueva",
                         "regCorreo", "regCodigo", "regClave", "regAviso", "regTerminos",
                         "regNacimiento", "regSexo",
                         "regCuerpo", "regDeporte", "regNivel", "regObjetivo", "regSalud",
                         "regMedicion", "regDias"]
        for pantalla in conFlecha {
            let app = abrir(pantalla)
            let flechas = app.buttons.matching(identifier: "Volver")
            XCTAssertEqual(flechas.count, 1,
                           "«\(pantalla)» debería tener exactamente una flecha de volver, tiene \(flechas.count)")
            app.terminate()
        }
    }

    /// `regNombre` está acá a propósito: es el primer paso con la cuenta ya creada,
    /// y atrás sólo hay pasos que mandarían un permiso consumido (decisión 0008).
    /// Lleva la barra de avance y no la flecha.
    func testLasPantallasDeEntradaYDeCierreNoTienenFlecha() {
        for pantalla in ["bienvenida", "claveLista", "regListo", "regNombre"] {
            let app = abrir(pantalla)
            XCTAssertEqual(app.buttons.matching(identifier: "Volver").count, 0,
                           "«\(pantalla)» no debería tener flecha de volver")
            app.terminate()
        }
    }

    // MARK: - El contenido está en pantalla

    /// Un texto propio del CONTENIDO de cada pantalla —no del título ni del pie—,
    /// que es justo lo que desapareció cuando la trailing closure se emparejó mal.
    func testCadaPantallaMuestraSuContenido() {
        let esperado: [(String, String)] = [
            ("regNombre", "Nombre"),
            ("regSexo", "Femenino"),
            ("regCuerpo", "Peso (kg)"),
            ("regDeporte", "Running"),
            ("regNivel", "Principiante"),
            ("regObjetivo", "Media maratón"),
            ("regSalud", "Dolor u opresión en el pecho"),
            ("regMedicion", "GPS del teléfono"),
            ("regDias", "Martes"),
            ("claveNueva", "Nueva contraseña"),
            ("claveCorreo", "Correo electrónico"),
            ("regClave", "Nueva contraseña"),
            // Sin servidor el texto legal no baja: lo que tiene que estar es el
            // estado de la pantalla, cargando o sin texto, y nunca un hueco.
            ("regAviso", "Aviso de salud"),
        ]
        for (pantalla, texto) in esperado {
            let app = abrir(pantalla)
            XCTAssertTrue(app.staticTexts[texto].waitForExistence(timeout: 5),
                          "«\(pantalla)» debería mostrar «\(texto)» en su contenido")
            app.terminate()
        }
    }

    // MARK: - Y la flecha hace algo

    /// Un texto que sólo aparece en la pantalla de nacimiento (paso 4). Se busca
    /// por "contiene" porque el título lleva el nombre de la persona adentro.
    private func tituloDeNacimiento(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "¿Cuándo naciste?")
        ).firstMatch
    }

    func testLaFlechaRetrocedeUnPasoDelRegistro() {
        let app = abrir("regCuerpo")                     // paso 8
        XCTAssertTrue(app.staticTexts["Peso (kg)"].waitForExistence(timeout: 5))

        app.buttons["Volver"].tap()                      // -> paso 7, sexo
        XCTAssertTrue(app.staticTexts["Femenino"].waitForExistence(timeout: 5),
                      "volver desde el paso 8 tiene que llevar al 7")

        app.buttons["Volver"].tap()                      // -> paso 6, nacimiento
        XCTAssertTrue(tituloDeNacimiento(app).waitForExistence(timeout: 5),
                      "volver desde el paso 7 tiene que llevar al 6")
    }

    /// El área táctil: la flecha se dibuja chica y tiene que responder en 48 pt.
    /// Se toca cerca del borde de su área, no en el centro del glifo.
    func testLaFlechaResponde48PtYNoSoloElGlifo() {
        let app = abrir("regSexo")                       // paso 7
        let flecha = app.buttons["Volver"]
        XCTAssertTrue(flecha.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(flecha.frame.height, 44,
                                    "el objetivo táctil de la flecha quedó por debajo del mínimo")

        // Esquina inferior izquierda del área, lejos del centro del dibujo.
        flecha.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.88)).tap()
        XCTAssertTrue(tituloDeNacimiento(app).waitForExistence(timeout: 5),
                      "tocar el borde del área táctil tiene que contar como toque")
    }

    // MARK: - El nacimiento no trae una fecha de fábrica

    /// 🛑 Sin `-datosDeEjemplo`: la rueda muestra una fecha, pero nadie la eligió y
    /// "Continuar" tiene que estar apagado. Si SwiftUI escribiera la fecha al dibujar
    /// la rueda, la edad volvería a ser una que la persona no dio.
    func testElNacimientoNoDejaSeguirSinMoverLaRueda() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-pantallaInicial", "regNacimiento",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_AR",
        ] + Self.sinServidor
        app.launch()

        XCTAssertTrue(tituloDeNacimiento(app).waitForExistence(timeout: 5))
        let continuar = app.buttons["Continuar"]
        XCTAssertTrue(continuar.waitForExistence(timeout: 5))
        XCTAssertFalse(continuar.isEnabled, "una fecha que nadie eligió no deja seguir")
    }

    // MARK: - La bienvenida no salta entre fotos

    /// 🛑 El pie de la bienvenida está pegado abajo. Cuando el título y el texto de
    /// una foto medían distinto que los de otra —un título de dos renglones al lado
    /// de uno de uno—, cada cambio de foto movía todo lo de arriba: la marca y el
    /// título.
    ///
    /// Se mira en los dos idiomas a propósito. En español, en el ancho del iPhone
    /// 16 Pro, las tres fotos miden hoy lo mismo; en inglés "Get ready for race
    /// day" entra en un renglón. Mirando sólo el español, el test pasaría también
    /// sin el arreglo.
    func testLaBienvenidaNoSaltaEntreFotos() {
        let casos = [
            (idioma: "es", region: "es_AR", irALaFoto: "Ver la foto %d de 3",
             titulo1: "Entrená y comé según la carga del día",
             titulo3: "Preparate para el día de la carrera"),
            (idioma: "en", region: "en_US", irALaFoto: "Show photo %d of 3",
             titulo1: "Train and eat for the day's load",
             titulo3: "Get ready for race day"),
        ]
        for caso in casos {
            let app = XCUIApplication()
            app.launchArguments = [
                "-pantallaInicial", "bienvenida",
                "-AppleLanguages", "(\(caso.idioma))",
                "-AppleLocale", caso.region,
            ] + Self.sinServidor
            app.launch()

            let marca = app.staticTexts["Stamina"].firstMatch
            XCTAssertTrue(marca.waitForExistence(timeout: 5))

            // Tocar un indicador reinicia el autoplay de 4,2 s: alcanza para medir
            // antes de que la foto cambie sola.
            app.buttons[String(format: caso.irALaFoto, 1)].tap()
            let titulo1 = app.staticTexts[caso.titulo1]
            XCTAssertTrue(titulo1.waitForExistence(timeout: 5))
            let marcaEnLaFoto1 = marca.frame.minY
            let tituloEnLaFoto1 = titulo1.frame.minY

            app.buttons[String(format: caso.irALaFoto, 3)].tap()
            let titulo3 = app.staticTexts[caso.titulo3]
            XCTAssertTrue(titulo3.waitForExistence(timeout: 5))

            XCTAssertEqual(marca.frame.minY, marcaEnLaFoto1, accuracy: 0.5,
                           "«\(caso.idioma)»: la marca se movió al pasar de la foto 1 a la 3")
            XCTAssertEqual(titulo3.frame.minY, tituloEnLaFoto1, accuracy: 0.5,
                           "«\(caso.idioma)»: el título se movió al pasar de la foto 1 a la 3")
            app.terminate()
        }
    }

    // MARK: - La bienvenida se pasa deslizando

    /// Las fotos se pasan con el dedo sin perder el autoplay ni el fundido: hacia
    /// la izquierda la siguiente, hacia la derecha la anterior, y en las puntas da
    /// la vuelta, como el autoplay.
    ///
    /// El recorrido 1 → 3 → 2 → 3 es a propósito: el autoplay sólo va para adelante
    /// (1 → 2 → 3), así que si el gesto no hiciera nada este test no pasa aunque la
    /// foto cambie sola. Cada gesto reinicia los 4,2 s, y se espera menos que eso.
    func testLaBienvenidaSePasaDeslizando() {
        let app = abrir("bienvenida")

        func foto(_ numero: Int) -> XCUIElement { app.buttons["Ver la foto \(numero) de 3"] }
        func quedaElegida(_ numero: Int) -> Bool {
            let elegida = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isSelected == true"), object: foto(numero))
            return XCTWaiter().wait(for: [elegida], timeout: 3) == .completed
        }

        // Tocar la foto 1 reinicia el autoplay: el recorrido arranca de un lugar sabido.
        XCTAssertTrue(foto(1).waitForExistence(timeout: 5))
        foto(1).tap()
        XCTAssertTrue(quedaElegida(1))

        // Un gesto rápido, desde el medio de la pantalla.
        app.swipeRight()
        XCTAssertTrue(quedaElegida(3), "hacia la derecha desde la foto 1 tiene que dar la vuelta a la 3")

        // Uno lento, arrastrando sobre la foto, arriba del pie.
        let derecha = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.3))
        let izquierda = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.3))
        izquierda.press(forDuration: 0.1, thenDragTo: derecha)
        XCTAssertTrue(quedaElegida(2), "hacia la derecha desde la foto 3 tiene que ir a la 2")

        derecha.press(forDuration: 0.1, thenDragTo: izquierda)
        XCTAssertTrue(quedaElegida(3), "hacia la izquierda desde la foto 2 tiene que ir a la 3")

        // Un pulgar que pasa fotos puede empezar arriba de un botón: pasa de foto
        // y no abre el alta.
        let crearCuenta = app.buttons["Crear cuenta gratis"]
        let correo = app.buttons["Enviarme el código"]
        crearCuenta.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            .press(forDuration: 0.1,
                   thenDragTo: crearCuenta.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)))
        XCTAssertTrue(quedaElegida(1), "deslizar arriba del botón tiene que pasar de foto")
        XCTAssertFalse(correo.waitForExistence(timeout: 1), "deslizar arriba del botón no puede abrir el alta")

        // Y tocarlo, sin deslizar, sigue andando.
        crearCuenta.tap()
        XCTAssertTrue(correo.waitForExistence(timeout: 5),
                      "«Crear cuenta gratis» tiene que seguir llevando al correo")
    }

    // MARK: - El correo se juzga al tocar, no mientras se escribe

    /// Iván, probando en el iPhone: con la primera letra ya aparecía "ese correo no
    /// parece válido", y el botón quedaba apagado hasta que el correo pareciera uno.
    /// Ahora se escribe en paz y el botón se prende con algo escrito. El error
    /// aparece al tocarlo, con el teclado todavía arriba, y se va al editar el correo.
    ///
    /// Sin `-datosDeEjemplo`: los campos tienen que arrancar vacíos. Y sólo se
    /// tipean letras, que es justo un correo sin `@`.
    func testElCorreoSeJuzgaAlTocarElBotonYNoMientrasSeEscribe() {
        let error = "Ese correo no parece válido: revisá que tenga @ y dominio."
        let casos: [(pantalla: String, boton: String)] = [
            ("regCorreo", "Enviarme el código"),
            ("claveCorreo", "Enviarme el código"),
            ("login", "Ingresar"),
        ]
        for caso in casos {
            let app = XCUIApplication()
            app.launchArguments = [
                "-pantallaInicial", caso.pantalla,
                "-AppleLanguages", "(es)",
                "-AppleLocale", "es_AR",
            ] + Self.sinServidor
            app.launch()

            let correo = app.textFields["Correo electrónico"]
            let boton = app.buttons[caso.boton]
            XCTAssertTrue(correo.waitForExistence(timeout: 5))
            XCTAssertFalse(boton.isEnabled, "«\(caso.pantalla)»: sin nada escrito, el botón no se prende")

            correo.tap()
            correo.typeText("ivan")
            if caso.pantalla == "login" {
                let clave = app.secureTextFields["Contraseña"]
                clave.tap()
                clave.typeText("x")
            }
            XCTAssertFalse(app.staticTexts[error].exists, "«\(caso.pantalla)»: mientras se escribe, no se juzga")
            XCTAssertTrue(boton.isEnabled, "«\(caso.pantalla)»: con algo escrito, el botón se prende")

            boton.tap()
            XCTAssertTrue(app.staticTexts[error].waitForExistence(timeout: 5),
                          "«\(caso.pantalla)»: al tocar con algo que no parece un correo, aparece el error")

            // El teclado sigue arriba: `typeText` sobre la app, sin tocar ningún
            // campo, falla si nada tiene el foco.
            app.typeText("x")
            if caso.pantalla == "login" {
                XCTAssertTrue(app.staticTexts[error].exists,
                              "«login»: escribir en la contraseña no es corregir el correo")
                correo.tap()
                correo.typeText("x")
            }
            XCTAssertTrue(app.staticTexts[error].waitForNonExistence(timeout: 5),
                          "«\(caso.pantalla)»: editar el correo borra el error")
            app.terminate()
        }
    }

    /// 🛑 El error aparece debajo del campo, y ahí puede no haber lugar: con el
    /// teclado arriba el pie sube, y si el campo quedó al borde de lo que se ve, el
    /// renglón nuevo queda tapado y el toque parece no hacer nada. La pantalla se
    /// desplaza lo justo para mostrarlo.
    ///
    /// Se prueba con letra grande, que deja el campo al borde igual que el teclado:
    /// en los tests el simulador escribe con el teclado de la Mac y no dibuja el
    /// del teléfono.
    func testElErrorDelCorreoQuedaALaVistaAunqueElCampoEsteAlBorde() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-pantallaInicial", "regCorreo",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_AR",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL",
        ] + Self.sinServidor
        app.launch()

        let correo = app.textFields["Correo electrónico"]
        XCTAssertTrue(correo.waitForExistence(timeout: 5))
        correo.tap()
        correo.typeText("ivan")
        app.buttons["Enviarme el código"].tap()

        let error = app.staticTexts["Ese correo no parece válido: revisá que tenga @ y dominio."]
        let pie = app.staticTexts["Al continuar aceptás los términos y la política de privacidad. No mandamos publicidad."]
        XCTAssertTrue(error.waitForExistence(timeout: 5))

        // El desplazamiento es animado: se le da un momento antes de medir.
        let limite = Date().addingTimeInterval(3)
        while error.frame.maxY > pie.frame.minY, Date() < limite {
            usleep(200_000)
        }
        XCTAssertLessThanOrEqual(error.frame.maxY, pie.frame.minY,
                                 "el error quedó debajo del pie, donde no se ve")
    }

    // MARK: - El Home

    /// Arranca la app en una pestaña del Home.
    private func abrirHome(_ pestana: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-pantallaInicial", "home", "-pestanaHome", pestana,
            "-datosDeEjemplo", "-AppleLanguages", "(es)", "-AppleLocale", "es_AR",
        ] + Self.sinServidor
        app.launch()
        return app
    }

    /// Mismo test que el del flujo de entrada, por el mismo motivo: que la
    /// pantalla tenga contenido y no un hueco.
    func testCadaPestanaDelHomeMuestraSuContenido() {
        let esperado: [(String, String)] = [
            ("inicio", "Tu día"),
            ("plan", "Media maratón de Buenos Aires"),
            ("entreno", "Fondo largo"),
            ("nutricion", "Comidas de hoy"),
            ("perfil", "Iván Benítez"),
            ("ajustes", "Unidades"),
            ("gimnasio", "Press plano con barra"),
        ]
        for (pestana, texto) in esperado {
            let app = abrirHome(pestana)
            XCTAssertTrue(app.staticTexts[texto].waitForExistence(timeout: 5),
                          "«\(pestana)» debería mostrar «\(texto)»")
            app.terminate()
        }
    }

    /// La barra de pestañas tiene que dejarle la pantalla al contenido.
    ///
    /// 🛑 Este test existe por un bug concreto: el hueco del botón central era un
    /// `Color.clear` sin alto, `Color` es elástico en los dos ejes, y la barra
    /// se estiraba hasta ocupar media pantalla. Como su fondo es casi negro, el
    /// síntoma parecía "el contenido se corta".
    func testLaBarraNoSeComeLaPantalla() {
        let app = abrirHome("inicio")
        let barra = app.buttons["Inicio"]
        XCTAssertTrue(barra.waitForExistence(timeout: 5))

        let alturaDeLaVentana = app.windows.firstMatch.frame.height
        XCTAssertLessThan(barra.frame.height, alturaDeLaVentana * 0.25,
                          "la barra de pestañas está ocupando media pantalla")
        XCTAssertGreaterThan(barra.frame.minY, alturaDeLaVentana * 0.6,
                             "la barra tendría que estar abajo, no arriba")
    }

    /// `entreno` es la única pestaña a pantalla completa: ahí no va la barra.
    func testEntrenoNoMuestraLaBarra() {
        let app = abrirHome("entreno")
        XCTAssertTrue(app.staticTexts["Fondo largo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Inicio"].exists,
                       "«entreno» es pantalla completa y no lleva barra de pestañas")
    }

    /// La regla que gobierna la captura de serie (`ESPECIFICACION.md` §6.4): el
    /// botón primario **dice lo que va a guardar**, así que confirmar no es a
    /// ciegas.
    func testLaCapturaDeSerieDiceLoQueVaAGuardar() {
        let app = abrirHome("gimnasio")
        XCTAssertTrue(app.staticTexts["Press plano con barra"].waitForExistence(timeout: 5))

        // El tercer chip del primer ejercicio: la serie que sigue.
        app.buttons["Serie 3"].firstMatch.tap()

        let boton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Serie 3 hecha")).firstMatch
        XCTAssertTrue(boton.waitForExistence(timeout: 5),
                      "el botón tiene que decir qué serie guarda y con qué números")
    }

    /// El diseño es de 390x844 y `ESPECIFICACION.md` §8.2 deja pantalla grande
    /// fuera de alcance. Si la app girase, el layout quedaría apretado — y de
    /// paso vuelve inestables a los tests, que fue como se descubrió.
    func testLaAppNoGira() {
        let app = abrir("regSexo")
        XCTAssertTrue(app.staticTexts["Femenino"].waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        // Alto > ancho: la app se sigue dibujando en vertical.
        let marco = app.windows.firstMatch.frame
        XCTAssertGreaterThan(marco.height, marco.width,
                             "la app tendría que quedarse en vertical")
    }
}
