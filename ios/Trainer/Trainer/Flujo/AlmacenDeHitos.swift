import Foundation
import Combine
import SwiftUI
import TrainerCore

/// Almacén persistente de hitos diarios: entrenamientos completados y pasos registrados.
/// Permite consultar qué se entrenó cada día (incluyendo múltiples sesiones en un mismo día)
/// y cuántos pasos se dieron, preservando los datos de forma local en el dispositivo.
@MainActor
public final class AlmacenDeHitos: ObservableObject {
    public static let compartido = AlmacenDeHitos()

    /// Las claves viejas: hasta esta versión todo vivía en `UserDefaults`, en claro.
    /// Sólo se leen una vez, para migrar (`migrarDesdePreferencias`).
    static let clavePasosLegada = "stamina_hitos_pasos_por_dia"
    static let claveActividadesLegada = "stamina_hitos_actividades_por_dia"
    /// Si lo migrado sin dueño todavía puede adoptarlo la próxima cuenta que entre.
    static let claveHuerfanosAdoptables = "stamina_hitos_huerfanos_adoptables"

    @Published public private(set) var pasosPorDia: [String: Int] = [:]
    /// De dónde salió cada número de `pasosPorDia`, cuándo y si falta subirlo.
    @Published private(set) var registrosDePasos: [String: RegistroDePasos] = [:]
    @Published public private(set) var actividadesPorDia: [String: [Actividad]] = [:]
    @Published public private(set) var todasLasActividades: [Actividad] = []

    private var suscripciones = Set<AnyCancellable>()
    private let carpeta: URL?
    private let preferencias: UserDefaults
    /// De quién son los hitos que están en memoria. `nil`: nadie identificado.
    private(set) var dueno: String?
    /// El archivo de la cuenta existe pero todavía no se pudo leer.
    private var lecturaPendiente = false

    /// "yyyy-MM-dd" gregoriano, sea cual sea el calendario del teléfono: es también
    /// la fecha que viaja a `PUT /me/steps`, y con un calendario budista "yyyy"
    /// daría 2569.
    private static let formatoFechaClave: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        return df
    }()

    public static func clave(para fecha: Date) -> String {
        formatoFechaClave.string(from: fecha)
    }

    public static func fecha(desde clave: String) -> Date? {
        formatoFechaClave.date(from: clave)
    }

    private convenience init() {
        self.init(carpeta: "hitos", preferencias: .standard,
                  dueno: DuenoDeLosDatosLocales.actual, conectarConLaApp: true)
    }

    /// - Parameters:
    ///   - carpeta: dentro de Application Support. Los tests usan una propia.
    ///   - dueno: la cuenta cuyos hitos se cargan al arrancar.
    ///   - conectarConLaApp: escuchar Salud y los cambios de cuenta. Los tests no.
    init(carpeta: String, preferencias: UserDefaults, dueno: String?, conectarConLaApp: Bool) {
        self.carpeta = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true))?
            .appendingPathComponent(carpeta, isDirectory: true)
        self.preferencias = preferencias
        self.dueno = dueno
        migrarDesdePreferencias()
        if let dueno { adoptarHuerfanos(para: dueno) }
        cargarDeDisco()
        guard conectarConLaApp else { return }
        escucharCambiosDeCuenta()
        #if DEBUG
        // 🛑 Sólo en DEBUG: un binario de release jamás inventa actividades.
        verificarDatosIniciales()
        #endif
    }

    // MARK: - Cuenta

    /// 🛑 POR QUÉ SE SEPARA POR CUENTA Y NO SE BORRA AL CERRAR SESIÓN.
    ///
    /// No todo lo que hay acá está en el servidor: los pasos cargados a mano desde el
    /// calendario existen sólo en este teléfono, y una salida recién terminada se
    /// registra acá antes de que la cola de `SeguimientoDeSalida` la suba. Borrar al
    /// cerrar sesión perdería eso para siempre. Entonces cada cuenta tiene su propio
    /// archivo: al salir se descarga de memoria (la próxima cuenta no ve nada) y al
    /// volver a entrar la misma persona lo recupera entero.
    ///
    /// Por la misma razón el archivo SÍ va al backup de iCloud: para los pasos a mano
    /// es la única copia. Va cifrado hasta el primer desbloqueo, como el resto.
    private func escucharCambiosDeCuenta() {
        NotificationCenter.default.publisher(for: DuenoDeLosDatosLocales.cambio)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] aviso in
                let usuario = aviso.userInfo?[DuenoDeLosDatosLocales.claveUsuario] as? String
                self?.cambiarDeDueno(a: usuario)
            }
            .store(in: &suscripciones)
    }

    /// `nil` es "se cerró la sesión": lo de memoria se descarga, el archivo queda.
    func cambiarDeDueno(a usuario: String?) {
        let nuevo = (usuario?.isEmpty == false) ? usuario : nil
        // Un cierre sin nadie identificado igual cuenta: corta la adopción.
        guard nuevo != dueno || nuevo == nil else { return }
        // Lo que se registró sin nadie identificado (sólo en memoria) es de quien
        // entra ahora: se le suma. Lo de una cuenta que sale ya está en su archivo,
        // porque cada cambio se guarda al toque.
        let sinDueno: HitosEnDisco? = (dueno == nil && archivoActual == nil) ? enMemoria : nil
        dueno = nuevo
        if let nuevo {
            adoptarHuerfanos(para: nuevo)
        } else {
            // Después de un cierre de sesión, lo migrado sin dueño ya no se le da a
            // la próxima cuenta: puede ser de otra persona. Queda guardado aparte.
            preferencias.set(false, forKey: Self.claveHuerfanosAdoptables)
        }
        pasosPorDia = [:]
        registrosDePasos = [:]
        actividadesPorDia = [:]
        cargarDeDisco()
        if nuevo != nil, let sinDueno {
            var unidos = enMemoria
            Self.unir(&unidos, con: sinDueno)
            pasosPorDia = unidos.pasosPorDia
            registrosDePasos = unidos.registrosDePasos ?? [:]
            actividadesPorDia = unidos.actividadesPorDia
            guardarEnDisco()
        }
        recalcularListaPlana()
    }

    // MARK: - Persistencia

    private struct HitosEnDisco: Codable {
        var pasosPorDia: [String: Int]
        var actividadesPorDia: [String: [Actividad]]
        /// Opcional: los archivos de antes de los pasos en el servidor no lo tienen.
        var registrosDePasos: [String: RegistroDePasos]? = nil
    }

    private var enMemoria: HitosEnDisco {
        HitosEnDisco(pasosPorDia: pasosPorDia, actividadesPorDia: actividadesPorDia,
                     registrosDePasos: registrosDePasos)
    }

    private func archivo(de usuario: String) -> URL? {
        carpeta?.appendingPathComponent("usuario-" + Self.nombreSeguro(usuario) + ".json")
    }

    /// Lo que se migró de `UserDefaults` sin saber de quién era.
    private var archivoSinDueno: URL? { carpeta?.appendingPathComponent("sin-dueno.json") }

    /// Dónde se lee y escribe ahora. Sin cuenta identificada: el archivo sin dueño
    /// mientras se pueda adoptar (el arranque justo después de actualizar, con la
    /// sesión abierta y el perfil todavía sin cargar); si no, ninguno: en memoria.
    private var archivoActual: URL? {
        if let dueno { return archivo(de: dueno) }
        return preferencias.bool(forKey: Self.claveHuerfanosAdoptables) ? archivoSinDueno : nil
    }

    /// Una sola vez: lo de `UserDefaults` pasa a un archivo y recién cuando el
    /// archivo quedó escrito se borran las claves viejas. Si algo falla, las claves
    /// siguen ahí y se reintenta en el próximo arranque.
    private func migrarDesdePreferencias() {
        let pasosViejos = preferencias.dictionary(forKey: Self.clavePasosLegada) as? [String: Int]
        let datosViejos = preferencias.data(forKey: Self.claveActividadesLegada)
        guard pasosViejos != nil || datosViejos != nil else { return }
        var actividadesViejas: [String: [Actividad]] = [:]
        if let datosViejos {
            guard let leidas = try? JSONDecoder().decode([String: [Actividad]].self, from: datosViejos) else {
                // Ilegible: no se borra nada. Queda en su clave para un humano.
                return
            }
            actividadesViejas = leidas
        }
        guard let destino = archivoSinDueno else { return }
        var migrado = leer(destino) ?? HitosEnDisco(pasosPorDia: [:], actividadesPorDia: [:])
        Self.unir(&migrado, con: HitosEnDisco(pasosPorDia: pasosViejos ?? [:], actividadesPorDia: actividadesViejas))
        guard escribir(migrado, en: destino) else { return }
        preferencias.removeObject(forKey: Self.clavePasosLegada)
        preferencias.removeObject(forKey: Self.claveActividadesLegada)
        preferencias.set(true, forKey: Self.claveHuerfanosAdoptables)
    }

    /// Lo migrado sin dueño pasa a la primera cuenta que se identifica, siempre que
    /// no haya habido un cierre de sesión en el medio.
    private func adoptarHuerfanos(para usuario: String) {
        guard preferencias.bool(forKey: Self.claveHuerfanosAdoptables),
              let origen = archivoSinDueno, let destino = archivo(de: usuario) else { return }
        guard let huerfanos = leer(origen) else {
            preferencias.set(false, forKey: Self.claveHuerfanosAdoptables)
            return
        }
        var propios = leer(destino) ?? HitosEnDisco(pasosPorDia: [:], actividadesPorDia: [:])
        Self.unir(&propios, con: huerfanos)
        guard escribir(propios, en: destino) else { return }
        try? FileManager.default.removeItem(at: origen)
        preferencias.set(false, forKey: Self.claveHuerfanosAdoptables)
    }

    private func cargarDeDisco() {
        lecturaPendiente = false
        guard let archivoActual else { return }
        guard let guardado = leer(archivoActual) else {
            // Existe pero no se pudo leer (p. ej. antes del primer desbloqueo): hasta
            // leerlo, no se escribe encima.
            lecturaPendiente = FileManager.default.fileExists(atPath: archivoActual.path)
            return
        }
        pasosPorDia = guardado.pasosPorDia
        registrosDePasos = Self.conRegistroParaTodo(guardado.pasosPorDia, guardado.registrosDePasos ?? [:])
        actividadesPorDia = guardado.actividadesPorDia
        recalcularListaPlana()
    }

    /// Los pasos de antes de esta versión no dicen de dónde salieron: valen como
    /// carga manual de "hace mucho" (`actualizadoMs` 1), así suben una vez para que
    /// el historial quede en la cuenta, pero no le ganan a nada de lo que ya haya.
    private static func conRegistroParaTodo(_ pasos: [String: Int],
                                            _ registros: [String: RegistroDePasos]) -> [String: RegistroDePasos] {
        var completos = registros
        for clave in pasos.keys where completos[clave] == nil {
            completos[clave] = RegistroDePasos(fuente: .manual, actualizadoMs: 1, pendiente: true)
        }
        return completos
    }

    private func guardarEnDisco() {
        if let archivoActual, !lecturaPendiente {
            _ = escribir(enMemoria, en: archivoActual)
        }
        recalcularListaPlana()
    }

    /// `nil` si no hay archivo. Si hay uno que no se puede decodificar, se aparta
    /// (`ArchivoIlegible`) antes de seguir: el próximo guardado no lo pisa.
    private func leer(_ url: URL) -> HitosEnDisco? {
        guard let datos = try? Data(contentsOf: url) else { return nil }
        guard let guardado = try? JSONDecoder().decode(HitosEnDisco.self, from: datos) else {
            ArchivoIlegible.apartar(url)
            return nil
        }
        return guardado
    }

    private func escribir(_ hitos: HitosEnDisco, en url: URL) -> Bool {
        guard let carpeta, let datos = try? JSONEncoder().encode(hitos) else { return false }
        do {
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            try datos.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    /// Unión sin pérdida: los pasos se quedan con el mayor (y con el registro de ese
    /// número) y las actividades se juntan por id (gana la que ya estaba en el destino).
    private static func unir(_ destino: inout HitosEnDisco, con otro: HitosEnDisco) {
        var registros = conRegistroParaTodo(destino.pasosPorDia, destino.registrosDePasos ?? [:])
        let deOtro = conRegistroParaTodo(otro.pasosPorDia, otro.registrosDePasos ?? [:])
        for (dia, pasos) in otro.pasosPorDia where pasos > (destino.pasosPorDia[dia] ?? -1) {
            registros[dia] = deOtro[dia]
        }
        destino.registrosDePasos = registros
        destino.pasosPorDia.merge(otro.pasosPorDia) { max($0, $1) }
        for (dia, lista) in otro.actividadesPorDia {
            var actual = destino.actividadesPorDia[dia] ?? []
            for actividad in lista where !actual.contains(where: { $0.id == actividad.id }) {
                actual.append(actividad)
            }
            destino.actividadesPorDia[dia] = actual.sorted { $0.startedAtMs > $1.startedAtMs }
        }
    }

    private static func nombreSeguro(_ id: String) -> String {
        Data(id.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func recalcularListaPlana() {
        let todas = actividadesPorDia.values.flatMap { $0 }
        self.todasLasActividades = todas.sorted { $0.startedAtMs > $1.startedAtMs }
    }

    // MARK: - Gestión de Pasos

    /// El tope del contrato (`DiaDePasosEntrada.steps`): uno más grande sería un 400.
    static let maximoDePasos = 200_000

    /// Carga a mano (ej: 5000 pasos ayer). Queda pendiente de subir, como `manual`.
    public func guardarPasos(_ pasos: Int, para fecha: Date) {
        let clave = Self.clave(para: fecha)
        pasosPorDia[clave] = min(max(0, pasos), Self.maximoDePasos)
        registrosDePasos[clave] = RegistroDePasos(fuente: .manual, actualizadoMs: Self.ahoraMs(), pendiente: true)
        guardarEnDisco()
    }

    /// Obtiene la cantidad de pasos para una fecha dada.
    public func pasos(para fecha: Date) -> Int {
        let clave = Self.clave(para: fecha)
        return pasosPorDia[clave] ?? 0
    }

    /// De dónde salió el número de ese día. `nil` si no hay número.
    func fuenteDePasos(para fecha: Date) -> FuenteDePasos? {
        registrosDePasos[Self.clave(para: fecha)]?.fuente
    }

    /// Lo que leyó Salud. Sólo cambia (y queda pendiente de subir) lo que es distinto
    /// de lo que ya había: abrir la app diez veces no sube diez veces lo mismo.
    ///
    /// Salud gana sobre una carga manual del mismo día: con permiso, el número de
    /// Salud es el de verdad, y la carga a mano sólo existe para cuando no lo hay.
    func registrarDeSalud(_ porDia: [Date: Int], ahoraMs: Int64) {
        var huboCambios = false
        for (fecha, cantidad) in porDia {
            let clave = Self.clave(para: fecha)
            let pasos = min(max(0, cantidad), Self.maximoDePasos)
            if pasosPorDia[clave] == pasos, registrosDePasos[clave]?.fuente == .healthkit { continue }
            pasosPorDia[clave] = pasos
            registrosDePasos[clave] = RegistroDePasos(fuente: .healthkit, actualizadoMs: ahoraMs, pendiente: true)
            huboCambios = true
        }
        if huboCambios { guardarEnDisco() }
    }

    /// Lo que falta subir, del día más viejo al más nuevo. Un día del futuro no sale
    /// (el servidor lo rechazaría): se queda acá hasta que deje de serlo.
    func pasosPendientes(hoy: Date = Date()) -> [DiaDePasosEntrada] {
        let manana = Self.clave(para: Calendar.current.date(byAdding: .day, value: 1, to: hoy) ?? hoy)
        var salida: [DiaDePasosEntrada] = []
        for (clave, registro) in registrosDePasos where registro.pendiente && clave <= manana {
            guard Self.fecha(desde: clave) != nil, let pasos = pasosPorDia[clave] else { continue }
            salida.append(DiaDePasosEntrada(date: clave, steps: Int64(pasos), source: registro.fuente,
                                            updatedAtMs: registro.actualizadoMs))
        }
        return salida.sorted { $0.date < $1.date }
    }

    /// El servidor recibió el lote: lo mandado deja de estar pendiente, salvo que se
    /// haya vuelto a cambiar mientras viajaba. Y lo que contestó se fusiona: si había
    /// algo más nuevo en otro teléfono, queda eso.
    func confirmarSubida(_ enviados: [DiaDePasosEntrada], respuesta: [DiaDePasos]) {
        descartarPendientes(enviados, guardar: false)
        fusionarDelServidor(respuesta, guardar: false)
        guardarEnDisco()
    }

    /// El servidor rechazó el lote (400): no se reintenta para siempre.
    func descartarPendientes(_ enviados: [DiaDePasosEntrada], guardar: Bool = true) {
        for dia in enviados {
            guard var registro = registrosDePasos[dia.date], registro.actualizadoMs == dia.updatedAtMs else { continue }
            registro.pendiente = false
            registrosDePasos[dia.date] = registro
        }
        if guardar { guardarEnDisco() }
    }

    /// Lo que está en el servidor. Gana el más nuevo, igual que allá: así un
    /// teléfono nuevo recupera el historial y uno viejo no pisa lo de otro.
    func fusionarDelServidor(_ dias: [DiaDePasos], guardar: Bool = true) {
        var huboCambios = false
        for dia in dias where Self.fecha(desde: dia.date) != nil {
            let pasos = Int(min(max(0, dia.steps), Int64(Self.maximoDePasos)))
            let local = registrosDePasos[dia.date]
            if local == nil || dia.updatedAtMs > (local?.actualizadoMs ?? 0) {
                pasosPorDia[dia.date] = pasos
                registrosDePasos[dia.date] = RegistroDePasos(fuente: dia.source, actualizadoMs: dia.updatedAtMs,
                                                             pendiente: false)
                huboCambios = true
            } else if var igual = local, igual.pendiente, igual.actualizadoMs == dia.updatedAtMs,
                      pasosPorDia[dia.date] == pasos {
                // Ya estaba allá: subió y se perdió la respuesta.
                igual.pendiente = false
                registrosDePasos[dia.date] = igual
                huboCambios = true
            }
        }
        if huboCambios, guardar { guardarEnDisco() }
    }

    private static func ahoraMs() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1_000).rounded())
    }

    // MARK: - Gestión de Actividades

    /// Registra un entrenamiento asociándolo a su fecha correspondiente.
    public func registrarActividad(_ actividad: Actividad) {
        let fecha = Date(timeIntervalSince1970: Double(actividad.startedAtMs) / 1000)
        let clave = Self.clave(para: fecha)

        var lista = actividadesPorDia[clave] ?? []
        lista.removeAll { $0.id == actividad.id }
        lista.insert(actividad, at: 0)
        lista.sort { $0.startedAtMs > $1.startedAtMs }

        actividadesPorDia[clave] = lista
        guardarEnDisco()
    }

    /// Retorna la lista de entrenamientos realizados en una fecha determinada.
    public func actividades(para fecha: Date) -> [Actividad] {
        let clave = Self.clave(para: fecha)
        return actividadesPorDia[clave] ?? []
    }

    /// Calcula el nivel de intensidad (0 a 4) para el mapa de calor estilo GitHub.
    public func nivelDeActividad(para fecha: Date) -> Int {
        let entrenamientos = actividades(para: fecha)
        if entrenamientos.isEmpty {
            let p = pasos(para: fecha)
            if p >= 10_000 { return 2 }
            if p >= 5_000 { return 1 }
            return 0
        }

        let totalMetros = entrenamientos.reduce(0) { $0 + Int($1.distanceM ?? 0) }
        let cantidad = entrenamientos.count

        if cantidad >= 3 || totalMetros >= 12_000 {
            return 4
        } else if cantidad >= 2 || totalMetros >= 6_000 {
            return 3
        } else if totalMetros >= 3_000 {
            return 2
        } else {
            return 1
        }
    }

    /// Estadísticas acumuladas para el resumen del calendario anual.
    public func resumenAnual() -> (totalSesiones: Int, totalKm: Double, totalPasos: Int, diasEntrenados: Int) {
        var totalMetros = 0
        var totalSesiones = 0
        var diasConEntreno = 0

        for (_, lista) in actividadesPorDia {
            if !lista.isEmpty {
                diasConEntreno += 1
                totalSesiones += lista.count
                totalMetros += lista.reduce(0) { $0 + Int($1.distanceM ?? 0) }
            }
        }

        let totalPasos = pasosPorDia.values.reduce(0, +)
        return (totalSesiones, Double(totalMetros) / 1000.0, totalPasos, diasConEntreno)
    }

    // MARK: - Datos Iniciales de Ejemplo (sólo DEBUG)

    #if DEBUG

    /// Si no hay registros previos, inicializa con el ejemplo solicitado por el usuario:
    /// - Ayer: 5.000 pasos, y 2 sesiones de running (1 km corriendo y 2 km corriendo).
    /// - Días previos para llenar el gráfico anual de GitHub de forma realista.
    private func verificarDatosIniciales() {
        guard actividadesPorDia.isEmpty else { return }

        let cal = Calendar.current
        let hoy = Date()

        // 1. AYER (Ejemplo explícito del usuario: 5000 pasos, 1 km corriendo y 2 km corriendo)
        if let ayer = cal.date(byAdding: .day, value: -1, to: hoy) {
            let claveAyer = Self.clave(para: ayer)
            pasosPorDia[claveAyer] = 5000
            marcarComoEjemplo(claveAyer)

            let baseAyerMs = Int64(cal.startOfDay(for: ayer).timeIntervalSince1970 * 1000)

            // Primer entrenamiento: 1 km corriendo a las 8:30
            let act1 = Actividad(
                id: "ejemplo-ayer-1km",
                sport: .running,
                startedAtMs: baseAyerMs + (8 * 3600 + 30 * 60) * 1000,
                durationS: 320, // 5m 20s
                distanceM: 1000,
                elevationGainM: 12,
                avgHrBpm: 142,
                maxHrBpm: 158,
                kcal: 68,
                device: .telefono,
                createdAtMs: baseAyerMs,
                updatedAtMs: baseAyerMs
            )

            // Segundo entrenamiento: 2 km corriendo a las 18:15
            let act2 = Actividad(
                id: "ejemplo-ayer-2km",
                sport: .running,
                startedAtMs: baseAyerMs + (18 * 3600 + 15 * 60) * 1000,
                durationS: 645, // 10m 45s
                distanceM: 2000,
                elevationGainM: 25,
                avgHrBpm: 151,
                maxHrBpm: 169,
                kcal: 142,
                device: .telefono,
                createdAtMs: baseAyerMs,
                updatedAtMs: baseAyerMs
            )

            actividadesPorDia[claveAyer] = [act1, act2]

            // Guardar rutas GPS locales para poder reproducir el recorrido en 3D
            let ruta1 = generarRutaGPS(
                latBase: -34.5880, lonBase: -58.3900,
                puntosCant: 30, distanciaM: 1000,
                inicioMs: act1.startedAtMs, duracionS: act1.durationS
            )
            AlmacenDeRecorridos.compartido.guardar(id: act1.id, puntos: ruta1)

            let ruta2 = generarRutaGPS(
                latBase: -34.5820, lonBase: -58.3950,
                puntosCant: 50, distanciaM: 2000,
                inicioMs: act2.startedAtMs, duracionS: act2.durationS
            )
            AlmacenDeRecorridos.compartido.guardar(id: act2.id, puntos: ruta2)
        }

        // 2. Historial de semanas anteriores para poblar el calendario anual
        let diasPatron: [(diasAtras: Int, pasos: Int, deporte: DeporteDeSesion, metros: Int, segundos: Int)] = [
            (diasAtras: 3, pasos: 8200, deporte: .running, metros: 5200, segundos: 1620),
            (diasAtras: 4, pasos: 6400, deporte: .ciclismo, metros: 18400, segundos: 2800),
            (diasAtras: 6, pasos: 10200, deporte: .running, metros: 8000, segundos: 2450),
            (diasAtras: 8, pasos: 7100, deporte: .running, metros: 4000, segundos: 1250),
            (diasAtras: 10, pasos: 9300, deporte: .ciclismo, metros: 22000, segundos: 3400),
            (diasAtras: 12, pasos: 5500, deporte: .running, metros: 3000, segundos: 960),
            (diasAtras: 15, pasos: 11000, deporte: .running, metros: 10000, segundos: 3100),
            (diasAtras: 18, pasos: 6000, deporte: .ciclismo, metros: 15000, segundos: 2400),
            (diasAtras: 21, pasos: 8500, deporte: .running, metros: 6500, segundos: 2050),
            (diasAtras: 25, pasos: 7800, deporte: .running, metros: 5000, segundos: 1550),
            (diasAtras: 30, pasos: 12000, deporte: .running, metros: 12000, segundos: 3700),
            (diasAtras: 35, pasos: 6200, deporte: .ciclismo, metros: 20000, segundos: 3100),
            (diasAtras: 42, pasos: 9100, deporte: .running, metros: 7000, segundos: 2200),
            (diasAtras: 48, pasos: 8400, deporte: .running, metros: 5500, segundos: 1700),
            (diasAtras: 56, pasos: 10500, deporte: .ciclismo, metros: 25000, segundos: 3900),
            (diasAtras: 63, pasos: 7200, deporte: .running, metros: 4500, segundos: 1400),
            (diasAtras: 70, pasos: 13000, deporte: .running, metros: 15000, segundos: 4800)
        ]

        for item in diasPatron {
            if let fecha = cal.date(byAdding: .day, value: -item.diasAtras, to: hoy) {
                let clave = Self.clave(para: fecha)
                pasosPorDia[clave] = item.pasos
                marcarComoEjemplo(clave)
                // MVP sólo running: el ejemplo no siembra salidas de bici.
                guard MVP.permite(item.deporte) else { continue }

                let inicioMs = Int64(cal.startOfDay(for: fecha).timeIntervalSince1970 * 1000) + 9 * 3600 * 1000
                let act = Actividad(
                    id: "ejemplo-hist-\(item.diasAtras)",
                    sport: item.deporte,
                    startedAtMs: inicioMs,
                    durationS: Int64(item.segundos),
                    distanceM: Int64(item.metros),
                    elevationGainM: 35,
                    avgHrBpm: 148,
                    maxHrBpm: 165,
                    kcal: Int64(item.metros / 15),
                    device: .telefono,
                    createdAtMs: inicioMs,
                    updatedAtMs: inicioMs
                )
                actividadesPorDia[clave] = [act]
            }
        }

        guardarEnDisco()
    }

    /// Los pasos de ejemplo no son de nadie: nunca suben al servidor.
    private func marcarComoEjemplo(_ clave: String) {
        registrosDePasos[clave] = RegistroDePasos(fuente: .manual, actualizadoMs: 1, pendiente: false)
    }

    private func generarRutaGPS(
        latBase: Double,
        lonBase: Double,
        puntosCant: Int,
        distanciaM: Double,
        inicioMs: Int64,
        duracionS: Int64
    ) -> [PuntoDeRecorrido] {
        var puntos: [PuntoDeRecorrido] = []
        let dtMs = duracionS * 1000 / Int64(max(1, puntosCant))
        for i in 0..<puntosCant {
            let frac = Double(i) / Double(max(1, puntosCant - 1))
            let lat = latBase + (sin(frac * .pi * 2.5) * 0.003) + (frac * 0.007)
            let lon = lonBase + (cos(frac * .pi * 2.0) * 0.004) + (frac * 0.005)
            puntos.append(PuntoDeRecorrido(lat: lat, lon: lon, atMs: inicioMs + Int64(i) * dtMs))
        }
        return puntos
    }
    #endif
}

/// De dónde salió el número de pasos de un día y si falta subirlo (`PUT /me/steps`).
struct RegistroDePasos: Codable, Equatable {
    var fuente: FuenteDePasos
    /// Cuándo se leyó de Salud o se cargó a mano. Decide quién gana, acá y en el servidor.
    var actualizadoMs: Int64
    var pendiente: Bool
}
