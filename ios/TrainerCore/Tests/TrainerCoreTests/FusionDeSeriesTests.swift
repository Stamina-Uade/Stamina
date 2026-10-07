import XCTest
@testable import TrainerCore

/// Los tests de la política de conflictos (`docs/decisiones/0006`).
///
/// 🛑 Éste es el archivo que más importa del paquete. La fusión corre **en los
/// dos dispositivos por separado** sobre los mismos datos: si no fuera
/// conmutativa, asociativa e idempotente, el teléfono y el reloj llegarían a
/// resultados distintos y divergirían **en silencio**, que es la peor forma de
/// fallar que tiene una sincronización.
final class FusionDeSeriesTests: XCTestCase {

    private func clave(_ numero: Int, ejercicio: String = "press-banca") -> ClaveDeSerie {
        ClaveDeSerie(sesion: "s1", ejercicio: ejercicio, numero: numero)
    }

    private func serie(_ numero: Int, ejercicio: String = "press-banca",
                       hecha: Bool = true, reps: Int = 8, kg: Int? = 45,
                       servidor: Int64? = nil, local: Int64 = 1_000,
                       de dispositivo: Dispositivo = .telefono,
                       salteada: Bool = false, extra: Bool = false) -> SerieRegistrada {
        SerieRegistrada(clave: clave(numero, ejercicio: ejercicio), hecha: hecha,
                        repeticiones: reps, pesoGramos: kg.map { $0 * 1000 },
                        salteada: salteada, esExtra: extra,
                        recibidaEnServidorMs: servidor, registradaLocalMs: local,
                        dispositivo: dispositivo)
    }

    // MARK: - Lo que pidió Iván, al pie de la letra

    /// *"Si toco la misma serie en ambas, que se marque como hecha sin importar
    /// quién la tocó primero."*
    func testLaMismaSerieEnLosDosDispositivosQuedaComoUnaSola() {
        let delReloj = serie(2, local: 2_000, de: .reloj)
        let delTelefono = serie(2, local: 1_000, de: .telefono)

        let unidas = FusionDeSeries.unir([delReloj], [delTelefono])

        XCTAssertEqual(unidas.count, 1, "la misma serie física no puede quedar duplicada")
        XCTAssertTrue(unidas[0].hecha)
    }

    /// *"Si toco 'hecho' en dos sets diferentes, que se junten ambas."*
    func testSeriesDistintasSeUnen() {
        let delReloj = serie(2, de: .reloj)
        let delTelefono = serie(3, de: .telefono)

        let unidas = FusionDeSeries.unir([delReloj], [delTelefono])

        XCTAssertEqual(unidas.count, 2)
        XCTAssertEqual(unidas.map(\.clave.numero).sorted(), [2, 3])
    }

    /// *"Si el reloj tocó 'hice una serie' y abro el celular, que vea lo mismo."*
    func testLoQueRegistroElRelojApareceEnElTelefono() {
        let enElTelefono: [SerieRegistrada] = []
        let delReloj = [serie(1, de: .reloj), serie(2, de: .reloj)]

        let unidas = FusionDeSeries.unir(enElTelefono, delReloj)

        XCTAssertEqual(unidas.count, 2)
        XCTAssertTrue(unidas.allSatisfy(\.hecha))
    }

    // MARK: - Las tres reglas del modelo

    /// Regla 2: `hecha` es monotónica. **Ninguna sincronización desmarca.**
    func testLaSincronizacionNuncaDesmarcaUnaSerie() {
        // El teléfono tiene una versión más nueva, pero SIN marcar.
        let sinMarcar = serie(2, hecha: false, local: 9_000, de: .telefono)
        let marcada = serie(2, hecha: true, local: 1_000, de: .reloj)

        let fusionada = SerieRegistrada.fusionar(sinMarcar, marcada)

        XCTAssertTrue(fusionada.hecha,
                      "una serie marcada no se desmarca porque el otro dispositivo estaba viejo")
    }

    /// Regla 3: la fila viene entera de quien ganó. **Nunca se mezclan campos.**
    func testNuncaSeMezclanLosCamposDeDosVersiones() {
        let delReloj = serie(2, reps: 8, kg: 45, local: 2_000, de: .reloj)
        let delTelefono = serie(2, reps: 6, kg: 40, local: 1_000, de: .telefono)

        let fusionada = SerieRegistrada.fusionar(delReloj, delTelefono)

        // Gana el reloj entero: 8 × 45. Nunca 8 × 40 ni 6 × 45.
        XCTAssertEqual(fusionada.repeticiones, 8)
        XCTAssertEqual(fusionada.pesoGramos, 45_000)
    }

    /// Regla 3 de la decisión: ordena la llegada AL SERVIDOR, no el reloj local.
    func testLoQueLlegoAlServidorLeGanaALoQueNoLlego() {
        let llegoAlServidor = serie(2, reps: 6, servidor: 500, local: 1, de: .telefono)
        let soloLocalMasNuevo = serie(2, reps: 9, servidor: nil, local: 999_999, de: .reloj)

        let fusionada = SerieRegistrada.fusionar(llegoAlServidor, soloLocalMasNuevo)

        XCTAssertEqual(fusionada.repeticiones, 6,
                       "el reloj de un cliente no ordena contra el del servidor")
    }

    func testEntreDosQueLlegaronAlServidorGanaLaMasNueva() {
        let vieja = serie(2, reps: 6, servidor: 100, de: .telefono)
        let nueva = serie(2, reps: 9, servidor: 200, de: .reloj)

        XCTAssertEqual(SerieRegistrada.fusionar(vieja, nueva).repeticiones, 9)
    }

    // MARK: - 🛑 Las propiedades que hacen que no diverjan

    /// Conmutativa: `a ∪ b == b ∪ a`.
    ///
    /// Sin esto, el teléfono y el reloj fusionan en distinto orden y llegan a
    /// resultados distintos.
    func testLaFusionEsConmutativa() {
        let a = serie(2, reps: 8, local: 1_000, de: .reloj)
        let b = serie(2, reps: 6, local: 1_000, de: .telefono)

        XCTAssertEqual(SerieRegistrada.fusionar(a, b), SerieRegistrada.fusionar(b, a),
                       "con el mismo momento exacto, el desempate por dispositivo tiene que ser estable")
    }

    /// Idempotente: fusionar algo consigo mismo no lo cambia. Es lo que permite
    /// reintentar una sincronización sin miedo.
    func testLaFusionEsIdempotente() {
        let a = serie(2, reps: 8, de: .reloj)
        XCTAssertEqual(SerieRegistrada.fusionar(a, a), a)

        let unaVez = FusionDeSeries.unir([a], [])
        let dosVeces = FusionDeSeries.unir(unaVez, unaVez)
        XCTAssertEqual(unaVez, dosVeces)
    }

    /// Asociativa: `(a ∪ b) ∪ c == a ∪ (b ∪ c)`. Con tres orígenes —teléfono,
    /// reloj y servidor— el orden en que llegan no puede cambiar el resultado.
    func testLaFusionEsAsociativa() {
        let a = serie(2, reps: 8, local: 3_000, de: .reloj)
        let b = serie(2, reps: 6, local: 2_000, de: .telefono)
        let c = serie(2, reps: 7, servidor: 50, local: 1_000, de: .telefono)

        let izquierda = SerieRegistrada.fusionar(SerieRegistrada.fusionar(a, b), c)
        let derecha = SerieRegistrada.fusionar(a, SerieRegistrada.fusionar(b, c))

        XCTAssertEqual(izquierda, derecha)
    }

    /// El caso que motiva todo: los dos sin red, cada uno registrando, y al
    /// reencontrarse los dos tienen que ver **lo mismo**.
    func testLosDosDispositivosLleganAlMismoResultado() {
        let enElReloj = [serie(1, de: .reloj), serie(2, reps: 8, local: 5_000, de: .reloj)]
        let enElTelefono = [serie(2, reps: 6, local: 4_000, de: .telefono), serie(3, de: .telefono)]

        let comoLoVeElReloj = FusionDeSeries.unir(enElReloj, enElTelefono)
        let comoLoVeElTelefono = FusionDeSeries.unir(enElTelefono, enElReloj)

        XCTAssertEqual(comoLoVeElReloj, comoLoVeElTelefono)
        XCTAssertEqual(comoLoVeElReloj.count, 3)
    }

    // MARK: - "Unión, y avisa"

    func testAvisaCuandoQuedanMasSeriesDeLasPrescritas() {
        let series = (1...6).map { serie($0) }
        XCTAssertTrue(FusionDeSeries.hayQueRevisar(series, prescritasPorEjercicio: ["press-banca": 4]))
    }

    func testNoAvisaCuandoLasDeMasSonExtraDeliberadas() {
        var series = (1...4).map { serie($0) }
        series.append(serie(5, extra: true))
        XCTAssertFalse(FusionDeSeries.hayQueRevisar(series, prescritasPorEjercicio: ["press-banca": 4]),
                       "una serie extra que la persona agregó a propósito no es una divergencia")
    }

    func testNoAvisaEnElCasoNormal() {
        let series = (1...4).map { serie($0) }
        XCTAssertFalse(FusionDeSeries.hayQueRevisar(series, prescritasPorEjercicio: ["press-banca": 4]))
    }
}
