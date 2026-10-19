import Foundation
import Testing
import TrainerCore
@testable import TrainerWatch_Watch_App

@Suite(.serialized)
struct TrainerWatch_Watch_AppTests {

    private static func limpiarEstado() {
        UserDefaults.standard.removeObject(forKey: "usuario_vinculado_id_reloj")
        if let archivo = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("salidas_reloj.json") {
            try? FileManager.default.removeItem(at: archivo)
        }
    }

    @MainActor
    @Test("Sin sesión iniciada el reloj arranca bloqueado en SinTelefonoView")
    func sinSesionArrancaBloqueado() async throws {
        Self.limpiarEstado()
        let estado = EstadoReloj()
        #expect(!estado.estaAutenticado, "sin usuario vinculado ni remoto no debe estar autenticado")
        #expect(estado.pantalla == .sinTelefono, "la pantalla inicial debe ser sinTelefono")
        #expect(estado.motivoSinConexion == .sesionNoIniciada, "el motivo debe ser sesionNoIniciada")

        // Intentar navegar a cualquier pantalla protegida debe ser rechazado
        estado.ir(a: .abrir)
        #expect(estado.pantalla == .sinTelefono, "no debe permitir navegar a abrir sin sesión")

        estado.ir(a: .metricas)
        #expect(estado.pantalla == .sinTelefono, "no debe permitir navegar a metricas sin sesión")

        estado.ir(a: .gimnasio)
        #expect(estado.pantalla == .sinTelefono, "no debe permitir navegar a gimnasio sin sesión")

        // Intentar empezar una salida sin sesión debe bloquearse
        estado.empezar()
        #expect(estado.pantalla == .sinTelefono, "no debe permitir empezar un entrenamiento sin sesión")
    }

    @MainActor
    @Test("Al recibir usuario remoto el reloj se desbloquea")
    func conUsuarioSeDesbloquea() async throws {
        Self.limpiarEstado()
        let estado = EstadoReloj()
        #expect(!estado.estaAutenticado)

        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        // Darle un ciclo al sink para propagar
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(estado.estaAutenticado, "al recibir usuario remoto debe estar autenticado")
        #expect(estado.pantalla == .abrir, "debe pasar a abrir automáticamente al autenticarse")

        // Limpiar para siguientes pruebas
        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("Al cerrar sesión el reloj vuelve a bloquearse inmediatamente")
    func alCerrarSesionSeBloquea() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(estado.estaAutenticado)

        // Simular cierre de sesión
        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(!estado.estaAutenticado, "debe dejar de estar autenticado")
        #expect(estado.pantalla == .sinTelefono, "debe volver a la pantalla de bloqueo")
        #expect(estado.motivoSinConexion == .sesionNoIniciada, "el motivo debe ser sesionNoIniciada")
    }

    @MainActor
    @Test("El icono de deporte en curso coincide exactamente con el seleccionado")
    func iconoDeporteCoincideConSeleccion() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        // MVP sólo running: la caminata queda escondida (ver `MVP`).
        if MVP.permite(.trekking) {
            // 1. Caminata interior
            estado.prepararInicioConCuentaRegresiva(deporte: .trekking, esInterior: true, icono: "figure.walk.treadmill")
            #expect(estado.simboloDeporteEnCurso == "figure.walk.treadmill", "caminata interior debe mostrar la caminadora")
            #expect(estado.simboloDeporteEnCurso != "figure.hiking", "nunca debe mostrar trekking/senderismo")
            estado.cancelarCuentaRegresiva()
            #expect(estado.iconoDeporteEnCurso == nil)

            // 2. Caminata exterior
            estado.prepararInicioConCuentaRegresiva(deporte: .trekking, esInterior: false, icono: "figure.walk")
            #expect(estado.simboloDeporteEnCurso == "figure.walk", "caminata exterior debe mostrar caminante")
            #expect(estado.simboloDeporteEnCurso != "figure.hiking")
            estado.completarCuentaRegresiva()
            #expect(estado.simboloDeporteEnCurso == "figure.walk")
            estado.descartar()
            #expect(estado.iconoDeporteEnCurso == nil)
        }

        // 3. Carrera interior
        estado.empezar(deporte: .running, esInterior: true, icono: "figure.run.treadmill")
        #expect(estado.simboloDeporteEnCurso == "figure.run.treadmill", "carrera interior debe mostrar cinta")
        estado.descartar()

        if MVP.permite(.ciclismo) {
            // 4. Bicicleta interior
            estado.empezar(deporte: .ciclismo, esInterior: true, icono: "figure.indoor.cycle")
            #expect(estado.simboloDeporteEnCurso == "figure.indoor.cycle", "bici interior debe mostrar ciclo indoor")
            estado.descartar()

            // 5. Bicicleta exterior
            estado.empezar(deporte: .ciclismo, esInterior: false, icono: "bicycle")
            #expect(estado.simboloDeporteEnCurso == "bicycle", "bici exterior debe mostrar bicicleta")
            estado.descartar()
        } else {
            // MVP sólo running: pedir bici arranca una carrera.
            estado.empezar(deporte: .ciclismo, esInterior: false, icono: "bicycle")
            #expect(estado.deporte == .running, "con el MVP sólo running, la bici se graba como carrera")
            estado.descartar()
        }

        // Limpiar sesión
        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("La autopausa y pausar/reanudar no generan recursión ni desbordamiento de pila")
    func autoPausaSinRecursion() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        UserDefaults.standard.set(true, forKey: "pausa_auto_carrera")

        estado.empezar(deporte: .running, esInterior: false)
        #expect(estado.fuenteLocal)

        // Comprobar que pausar, reanudar y descartar se ejecutan limpiamente sin recursión
        estado.pausarOReanudar()
        estado.pausarOReanudar()
        estado.descartar()
        #expect(estado.seguimiento.fase == .detenida)

        UserDefaults.standard.set(false, forKey: "pausa_auto_carrera")
        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("La navegación de entrenamiento permite acceder a métricas, mapa, parciales, controles y música")
    func navegacionEntrenoDestinos() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        estado.empezar(deporte: .running)
        #expect(estado.pantalla == .metricas)

        // Arriba -> Mapa
        estado.ir(a: .mapa)
        #expect(estado.pantalla == .mapa)
        estado.ir(a: .metricas)
        #expect(estado.pantalla == .metricas)

        // Abajo -> Parciales
        estado.ir(a: .parciales)
        #expect(estado.pantalla == .parciales)
        estado.ir(a: .metricas)
        #expect(estado.pantalla == .metricas)

        // Izquierda -> Controles
        estado.ir(a: .controles)
        #expect(estado.pantalla == .controles)
        estado.ir(a: .metricas)
        #expect(estado.pantalla == .metricas)

        // Derecha -> Música
        estado.ir(a: .musica)
        #expect(estado.pantalla == .musica)
        estado.ir(a: .metricas)
        #expect(estado.pantalla == .metricas)

        estado.descartar()
        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("El detector de series reconoce series y permite continuar unificando parciales")
    func detectorDeSeriesYContinuacion() async throws {
        let detector = DetectorDeSeries.detectar(en: "8 series de 800 m al ritmo máximo")
        #expect(detector != nil)
        #expect(detector?.totalSeries == 8)
        #expect(detector?.metrosPorSerie == 800)

        let detectorX = DetectorDeSeries.detectar(en: "6x1000m")
        #expect(detectorX != nil)
        #expect(detectorX?.totalSeries == 6)
        #expect(detectorX?.metrosPorSerie == 1000)

        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        estado.objetivoSeries = detector
        estado.itemsSeries = (1...8).map { ItemSerieObjetivo(numero: $0, metrosObjetivo: 800) }
        #expect(estado.itemsSeries.count == 8)
        #expect(!estado.objetivoSeriesContinuado)

        // Al finalizar todas las series y tocar "Continuar entrenamiento", se unifica
        estado.continuarTrasFinDeSeries()
        #expect(estado.objetivoSeriesContinuado, "debe unificar y mostrar parciales por km")
        #expect(!estado.mostrarAvisoFinObjetivoSeries)

        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("Los parciales de kilómetro se ordenan de abajo hacia arriba: KM 1 al fondo, en curso arriba")
    func ordenParcialesDeAbajoHaciaArriba() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Simulamos 3 km completados
        estado.parcialesKm = [
            ParcialKilometro(numero: 1, segundos: 300, ritmoSegPorKm: 300, metros: 1000, completado: true),
            ParcialKilometro(numero: 2, segundos: 295, ritmoSegPorKm: 295, metros: 1000, completado: true),
            ParcialKilometro(numero: 3, segundos: 310, ritmoSegPorKm: 310, metros: 1000, completado: true)
        ]

        let visuales = estado.listaParcialesVisuales
        #expect(visuales.last?.numero == 1, "KM 1 debe estar en el fondo (abajo)")
        #expect(visuales.first?.numero == 3, "El KM más reciente completado debe estar en el tope (arriba)")

        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("En día de descanso no se muestra ningún botón de objetivo aunque haya rutina en caché")
    func diaDeDescansoOcultaObjetivos() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Asignamos una rutina remota
        estado.sincronizador.simularRutinaRemota([
            EjercicioCompartido(id: "ej-1", nombre: "Sentadilla", repeticiones: 10, pesoGramos: 60000, series: 4, etiqueta: "Fuerza", unidad: "kg")
        ])

        // Simulamos que hoy es día de descanso
        let sesionDescanso = SesionCompartida(
            tipo: "Descanso total",
            distanciaMetros: nil,
            duracionMinutos: 0,
            minutoDelDia: nil,
            geles: nil,
            esDescanso: true,
            esFuerza: false
        )
        estado.sincronizador.simularSesionRemota(sesionDescanso)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(estado.esDiaDeDescanso, "debe ser día de descanso")
        #expect(estado.sesionCardioPlanificada == nil, "no debe haber sesión de cardio en descanso")
        #expect(!estado.tieneGimnasioHoy, "no debe mostrar botón de gimnasio en descanso")

        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("En día de gimnasio sólo se muestra el botón de la rutina de ejercicios y no el botón cardio de 35 minutos")
    func diaDeGimnasioMuestraSoloUnBoton() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        estado.sincronizador.simularRutinaRemota([
            EjercicioCompartido(id: "ej-1", nombre: "Press Banca", repeticiones: 8, pesoGramos: 70000, series: 4, etiqueta: "Pecho", unidad: "kg")
        ])

        // La sesión del plan es de fuerza (35 min)
        let sesionFuerza = SesionCompartida(
            tipo: "Fuerza para corredores",
            distanciaMetros: nil,
            duracionMinutos: 35,
            minutoDelDia: nil,
            geles: nil,
            esDescanso: false,
            esFuerza: true
        )
        estado.sincronizador.simularSesionRemota(sesionFuerza)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(!estado.esDiaDeDescanso)
        #expect(estado.sesionCardioPlanificada == nil, "la sesión de fuerza no debe ser cardio (elimina el botón de 35 minutos)")
        #expect(estado.tieneGimnasioHoy, "debe mostrar el botón de rutina de gimnasio")

        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    @MainActor
    @Test("En día de cardio se expone el objetivo de distancia en kilómetros o metros")
    func diaDeCardioExponeObjetivo() async throws {
        let estado = EstadoReloj()
        estado.sincronizador.simularUsuarioRemoto("usuario_123")
        try? await Task.sleep(nanoseconds: 10_000_000)

        let sesionCardio = SesionCompartida(
            tipo: "Carrera continua",
            distanciaMetros: 8000,
            duracionMinutos: 45,
            minutoDelDia: nil,
            geles: nil,
            esDescanso: false,
            esFuerza: false
        )
        estado.sincronizador.simularSesionRemota(sesionCardio)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(!estado.esDiaDeDescanso)
        #expect(estado.sesionCardioPlanificada != nil)
        #expect(estado.sesionCardioPlanificada?.distanciaMetros == 8000)

        estado.sincronizador.simularUsuarioRemoto(nil)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
