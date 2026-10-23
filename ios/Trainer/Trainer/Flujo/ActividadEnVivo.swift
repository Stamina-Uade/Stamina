import Combine
import Foundation
import SwiftUI
import TrainerCore
#if canImport(ActivityKit)
import ActivityKit
#endif

// =============================================================================
// La actividad en vivo (Live Activity) de una salida, del lado de la app.
//
// Decisión de Iván (2026-10): mientras se graba una salida, la pantalla
// bloqueada muestra una tarjeta como la de Strava —el deporte arriba, el ícono de
// Stamina a la derecha, y Duración, Ritmo y Distancia— y la Dynamic Island, el
// ícono y la duración. Aparece al empezar (también si la salida la graba el reloj
// y el teléfono la sigue en vivo), se va al terminar o descartar, y tocarla abre
// la pantalla de la salida.
//
// Las piezas:
// - `PlanificadorDeActividadEnVivo`: decide CUÁNDO pedir, actualizar o terminar.
//   Es un valor sin ActivityKit, para poder probarlo.
// - `ControladorDeActividadEnVivo`: observa `EstadoHome` y le hace caso al
//   planificador con ActivityKit (iOS 16.2 en adelante; en 16.0 y 16.1 no hace nada).
// - `.actividadEnVivo(de:)`: lo que `RaizHomeView` engancha —el controlador y el
//   `onOpenURL` del enlace—, para que la pantalla no cargue con nada de esto.
//
// La vista vive en la extensión `StaminaEnVivo`; el tipo que viaja entre las dos,
// en `StaminaEnVivo/ActividadEnVivoAtributos.swift`, que compilan ambos targets.
// =============================================================================

/// Lo que importa de la salida en curso, venga del GPS del teléfono o del reloj.
struct LecturaDeSalidaEnVivo: Equatable {
    var deporte: DeporteDeSesion
    var pausada: Bool
    var segundos: Int
    var metros: Int
    var ritmoSegPorKm: Int?
    var unidades: SistemaDeUnidades
    /// Cuándo se midieron esos segundos. El reloj los manda con su hora
    /// (`actualizadoMs`), que puede llegar unos segundos tarde: sin esto, el
    /// cronómetro de la pantalla bloqueada se atrasaría lo que tarde el mensaje.
    var medidoEn: Date
}

/// Cuándo hablar con ActivityKit.
///
/// 🛑 La duración NO se actualiza: la pantalla la cuenta sola desde
/// `inicioDelCronometro`. Ritmo y distancia se mandan como mucho cada
/// `intervaloMinimo` segundos —el sistema limita cuántas actualizaciones acepta y
/// la batería también—, salvo lo que no puede esperar: pausar o reanudar, cambiar
/// de unidades, pasar un kilómetro (o una milla) y un cronómetro que se corrió.
/// En pausa no cambia nada, así que no sale nada.
struct PlanificadorDeActividadEnVivo {
    static let intervaloMinimo: TimeInterval = 10
    /// Cuánto puede correrse el inicio calculado sin mandarlo de nuevo. Los
    /// segundos son enteros y el reloj llega con demora: un segundo de diferencia
    /// es ruido, no un error.
    static let toleranciaDelCronometro: TimeInterval = 2
    /// La distancia se ve con dos decimales: menos de 10 m no cambia lo que se lee.
    static let resolucionDeDistancia = 10

    enum Accion: Equatable {
        case ninguna
        case empezar(DeporteDeSesion, EstadoDeSalidaEnVivo)
        case actualizar(EstadoDeSalidaEnVivo)
        /// Con lo último que se mostró, para que el cierre no cambie los números.
        case terminar(EstadoDeSalidaEnVivo?)
    }

    private(set) var enCurso = false
    private(set) var ultimoEnviado: EstadoDeSalidaEnVivo?
    private(set) var ultimoEnvio: Date?
    private var deporteEnCurso: DeporteDeSesion?

    /// `lectura == nil`: no hay salida (terminó, se descartó o el reloj dejó de
    /// mandar).
    mutating func decidir(_ lectura: LecturaDeSalidaEnVivo?, ahora: Date) -> Accion {
        guard let lectura else {
            guard enCurso else { return .ninguna }
            let final = ultimoEnviado
            olvidar()
            return .terminar(final)
        }
        let nuevo = Self.estado(de: lectura, anterior: ultimoEnviado)
        guard enCurso, let anterior = ultimoEnviado, let ultimoEnvio else {
            enCurso = true
            deporteEnCurso = lectura.deporte
            registrar(nuevo, ahora)
            return .empezar(lectura.deporte, nuevo)
        }
        if let deporteEnCurso, deporteEnCurso != lectura.deporte {
            // Lo fijo de una actividad no se cambia: se cierra y se pide otra.
            olvidar()
            return .terminar(anterior)
        }
        deporteEnCurso = lectura.deporte

        let urgente = anterior.pausada != nuevo.pausada
            || anterior.enMillas != nuevo.enMillas
            || anterior.inicioDelCronometro != nuevo.inicioDelCronometro
            || Self.tramo(anterior) != Self.tramo(nuevo)
        let resolucion = Self.resolucionDeDistancia
        let hayNovedad = anterior.metros / resolucion != nuevo.metros / resolucion
            || anterior.ritmoSegPorKm != nuevo.ritmoSegPorKm
        let pasoElIntervalo = ahora.timeIntervalSince(ultimoEnvio) >= Self.intervaloMinimo
        guard urgente || (hayNovedad && pasoElIntervalo) else { return .ninguna }
        registrar(nuevo, ahora)
        return .actualizar(nuevo)
    }

    /// Una actividad que quedó de antes (la app se cerró en plena salida) se
    /// retoma en vez de pedir otra: no parpadea y no quedan dos.
    mutating func adoptar(_ estado: EstadoDeSalidaEnVivo, deporte: DeporteDeSesion, ahora: Date) {
        enCurso = true
        deporteEnCurso = deporte
        registrar(estado, ahora)
    }

    /// El sistema no la aceptó (o ya no existe): queda como si nunca se hubiera pedido.
    mutating func olvidar() {
        enCurso = false
        ultimoEnviado = nil
        ultimoEnvio = nil
        deporteEnCurso = nil
    }

    private mutating func registrar(_ estado: EstadoDeSalidaEnVivo, _ ahora: Date) {
        ultimoEnviado = estado
        ultimoEnvio = ahora
    }

    /// El kilómetro (o la milla) en el que va la salida.
    static func tramo(_ estado: EstadoDeSalidaEnVivo) -> Int {
        estado.metros / (estado.enMillas ? 1609 : 1000)
    }

    /// Lo que se manda. El inicio del cronómetro se conserva mientras no se
    /// corra más que la tolerancia: así no salta un segundo en cada envío.
    static func estado(de lectura: LecturaDeSalidaEnVivo,
                       anterior: EstadoDeSalidaEnVivo?) -> EstadoDeSalidaEnVivo {
        let calculado = lectura.medidoEn.addingTimeInterval(-TimeInterval(max(0, lectura.segundos)))
        var inicio = calculado
        if let anterior, anterior.pausada == lectura.pausada {
            // En pausa el inicio no se mira (se ve la duración fija), y corriendo
            // sólo cambia si de verdad se corrió.
            if lectura.pausada
                || abs(anterior.inicioDelCronometro.timeIntervalSince(calculado)) <= toleranciaDelCronometro {
                inicio = anterior.inicioDelCronometro
            }
        }
        return EstadoDeSalidaEnVivo(inicioDelCronometro: inicio,
                                    segundos: max(0, lectura.segundos),
                                    pausada: lectura.pausada,
                                    metros: max(0, lectura.metros),
                                    ritmoSegPorKm: lectura.ritmoSegPorKm,
                                    enMillas: lectura.unidades == .imperial)
    }
}

// MARK: - Lo que se lee de EstadoHome

extension LecturaDeSalidaEnVivo {
    /// La salida que se ve en la app, sea del teléfono o del reloj. `nil` sin salida.
    @MainActor
    static func de(_ estado: EstadoHome, ahora: Date = Date()) -> LecturaDeSalidaEnVivo? {
        let pausada: Bool
        switch estado.estadoDeLaSesion {
        case .detenida: return nil
        case .corriendo: pausada = false
        case .pausada: pausada = true
        }
        var deporte = estado.seguimiento.deporteEnCurso ?? .running
        var medidoEn = ahora
        if estado.salidaVieneDelReloj, let remota = estado.sincronizador.salidaRemota {
            deporte = remota.deporte ?? .running
            // Nunca en el futuro: un reloj adelantado no puede restar tiempo.
            medidoEn = min(ahora, Date(timeIntervalSince1970: TimeInterval(remota.actualizadoMs) / 1000))
        }
        return LecturaDeSalidaEnVivo(deporte: deporte, pausada: pausada,
                                     segundos: estado.segundosDeLaSesion,
                                     metros: estado.metrosDeLaSesion,
                                     ritmoSegPorKm: estado.ritmoDeLaSesion,
                                     unidades: estado.sistemaDeUnidades,
                                     medidoEn: medidoEn)
    }
}

// MARK: - ActivityKit

/// Observa el Home y le pide al sistema la actividad, la actualiza y la cierra.
@MainActor
final class ControladorDeActividadEnVivo: ObservableObject {
    /// Si el sistema no la acepta (desactivadas en Ajustes, demasiadas abiertas),
    /// no se insiste en cada cambio: se espera esto.
    static let esperaTrasUnRechazo: TimeInterval = 30

    private var planificador = PlanificadorDeActividadEnVivo()
    private weak var estado: EstadoHome?
    private var suscripciones = Set<AnyCancellable>()
    /// `Activity<AtributosDeSalidaEnVivo>`. Va sin tipo porque esa clase es de
    /// iOS 16.1 y esta propiedad tiene que existir en 16.0.
    private var actividad: AnyObject?
    private var noIntentarAntesDe: Date?

    func observar(_ estado: EstadoHome) {
        guard self.estado !== estado else { return }
        self.estado = estado
        suscripciones.removeAll()
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        retomarLasQueQuedaron()
        // `EstadoHome` cambia muchas veces por segundo (GPS, brújula): se mira como
        // mucho dos veces por segundo. El temporizador cubre lo que cambia sin
        // avisar: la salida del reloj deja de contar si no llega nada en 30 s.
        estado.objectWillChange
            .merge(with: Timer.publish(every: 5, on: .main, in: .common).autoconnect().map { _ in () })
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.evaluar() }
            .store(in: &suscripciones)
        evaluar()
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private func evaluar() {
        guard let estado else { return }
        let ahora = Date()
        let lectura = LecturaDeSalidaEnVivo.de(estado, ahora: ahora)
        if lectura != nil, !planificador.enCurso {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            if let noIntentarAntesDe, ahora < noIntentarAntesDe { return }
        }
        let accion = planificador.decidir(lectura, ahora: ahora)
        ejecutar(accion)
        if case .terminar = accion, lectura != nil {
            // Cambió el deporte: la nueva sale en la misma vuelta.
            ejecutar(planificador.decidir(lectura, ahora: ahora))
        }
    }

    @available(iOS 16.2, *)
    private func ejecutar(_ accion: PlanificadorDeActividadEnVivo.Accion) {
        switch accion {
        case .ninguna:
            break
        case .empezar(let deporte, let contenido):
            do {
                actividad = try Activity.request(
                    attributes: AtributosDeSalidaEnVivo(deporte: deporte),
                    content: ActivityContent(state: contenido, staleDate: nil),
                    pushType: nil)
                noIntentarAntesDe = nil
            } catch {
                planificador.olvidar()
                noIntentarAntesDe = Date().addingTimeInterval(Self.esperaTrasUnRechazo)
            }
        case .actualizar(let contenido):
            // Si la persona la deslizó para sacarla, no se le vuelve a poner.
            guard let actual = actividad as? Activity<AtributosDeSalidaEnVivo>,
                  actual.activityState == .active else { return }
            Task { await actual.update(ActivityContent(state: contenido, staleDate: nil)) }
        case .terminar(let final):
            let actual = actividad as? Activity<AtributosDeSalidaEnVivo>
            actividad = nil
            Task {
                await actual?.end(final.map { ActivityContent(state: $0, staleDate: nil) },
                                  dismissalPolicy: .immediate)
            }
        }
    }

    /// Al abrir la app: si quedó una actividad de antes, se sigue con ésa; si
    /// quedaron más, las otras se cierran. Si no hay salida, la primera vuelta de
    /// `evaluar` la cierra también.
    @available(iOS 16.2, *)
    private func retomarLasQueQuedaron() {
        let abiertas = Activity<AtributosDeSalidaEnVivo>.activities
        let elegida = abiertas.first { $0.activityState == .active }
        for otra in abiertas where otra.id != elegida?.id {
            Task { await otra.end(nil, dismissalPolicy: .immediate) }
        }
        guard let elegida else { return }
        actividad = elegida
        planificador.adoptar(elegida.content.state, deporte: elegida.attributes.deporte, ahora: Date())
    }
    #else
    private func evaluar() {}
    #endif
}

// MARK: - El enganche en la vista

private struct ActividadEnVivoDeLaSalida: ViewModifier {
    let estado: EstadoHome
    @StateObject private var controlador = ControladorDeActividadEnVivo()

    func body(content: Content) -> some View {
        content
            .onAppear { controlador.observar(estado) }
            // Tocar la actividad abre la pantalla de la salida. Sin salida (una
            // actividad vieja que quedó), sólo se abre la app.
            .onOpenURL { url in
                guard EnlaceDeSalidaEnVivo.esDeLaSalida(url), estado.haySesionEnCurso else { return }
                estado.ir(a: .entreno)
            }
    }
}

extension View {
    /// La actividad en vivo de la salida y el enlace que la abre.
    func actividadEnVivo(de estado: EstadoHome) -> some View {
        modifier(ActividadEnVivoDeLaSalida(estado: estado))
    }
}
