import Foundation
import UserNotifications

/// Notificación local de fin de entrenamiento. El texto se arma en cada cliente
/// con su catálogo localizado; esta pieza sólo maneja permiso y entrega.
public enum NotificadorDeEntrenamiento {
    public static func configurarPresentacionEnPrimerPlano() {
        UNUserNotificationCenter.current().delegate = DelegadoDeNotificaciones.compartido
    }

    /// Se pide al empezar, cuando la razón del permiso es evidente para la persona.
    public static func preparar() {
        let centro = UNUserNotificationCenter.current()
        centro.getNotificationSettings { ajustes in
            guard ajustes.authorizationStatus == .notDetermined else { return }
            centro.requestAuthorization(options: [.alert]) { _, _ in }
        }
    }

    public static func enviar(id: String, titulo: String, cuerpo: String) {
        let centro = UNUserNotificationCenter.current()
        centro.getNotificationSettings { ajustes in
            switch ajustes.authorizationStatus {
            case .authorized, .provisional:
                agregar(id: id, titulo: titulo, cuerpo: cuerpo, en: centro)
            case .notDetermined:
                // Una salida puede haberse iniciado íntegramente en el reloj. En
                // ese caso el iPhone recién tiene una razón visible para pedir el
                // permiso cuando recibe y guarda el entrenamiento terminado.
                centro.requestAuthorization(options: [.alert]) { autorizado, _ in
                    guard autorizado else { return }
                    agregar(id: id, titulo: titulo, cuerpo: cuerpo, en: centro)
                }
            default:
                break
            }
        }
    }

    public static func actualizarEnCurso(deporte: String, distancia: String, tiempo: String, ritmo: String) {
        let centro = UNUserNotificationCenter.current()
        centro.getNotificationSettings { ajustes in
            guard ajustes.authorizationStatus == .authorized || ajustes.authorizationStatus == .provisional else { return }
            let contenido = UNMutableNotificationContent()
            contenido.title = deporte
            contenido.body = "\(distancia) · \(tiempo) · \(ritmo)"
            contenido.sound = nil
            let pedido = UNNotificationRequest(
                identifier: "entrenamiento-en-curso", content: contenido,
                trigger: nil)
            centro.add(pedido)
        }
    }

    public static func limpiarEnCurso() {
        let centro = UNUserNotificationCenter.current()
        centro.removeDeliveredNotifications(withIdentifiers: ["entrenamiento-en-curso"])
        centro.removePendingNotificationRequests(withIdentifiers: ["entrenamiento-en-curso"])
    }

    public static func programarRecordatorio(id: String, titulo: String, cuerpo: String, fecha: Date) {
        guard fecha > Date() else { return }
        let centro = UNUserNotificationCenter.current()
        centro.getNotificationSettings { ajustes in
            switch ajustes.authorizationStatus {
            case .authorized, .provisional:
                agregarRecordatorio(id: id, titulo: titulo, cuerpo: cuerpo, fecha: fecha, en: centro)
            case .notDetermined:
                centro.requestAuthorization(options: [.alert]) { autorizado, _ in
                    guard autorizado else { return }
                    agregarRecordatorio(id: id, titulo: titulo, cuerpo: cuerpo, fecha: fecha, en: centro)
                }
            default: break
            }
        }
    }

    public static func limpiarRecordatorios() {
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { pedidos in
            let ids = pedidos.map(\.identifier).filter {
                $0.hasPrefix("recordatorio-manana-") || $0.hasPrefix("recordatorio-hora-")
            }
            if !ids.isEmpty {
                centro.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    public static func limpiarAvisosDeCalor() async {
        let centro = UNUserNotificationCenter.current()
        let ids: [String] = await withCheckedContinuation { continuacion in
            centro.getPendingNotificationRequests { pedidos in
                continuacion.resume(returning: pedidos.map(\.identifier).filter {
                    $0.hasPrefix("recordatorio-calor-")
                })
            }
        }
        if !ids.isEmpty { centro.removePendingNotificationRequests(withIdentifiers: ids) }
    }

    private static func agregarRecordatorio(id: String, titulo: String, cuerpo: String,
                                           fecha: Date, en centro: UNUserNotificationCenter) {
        let contenido = UNMutableNotificationContent()
        contenido.title = titulo
        contenido.body = cuerpo
        contenido.sound = nil
        let componentes = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fecha)
        let trigger = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
        let pedido = UNNotificationRequest(identifier: "recordatorio-\(id)", content: contenido, trigger: trigger)
        centro.add(pedido)
    }

    private static func agregar(id: String, titulo: String, cuerpo: String,
                                en centro: UNUserNotificationCenter) {
        let contenido = UNMutableNotificationContent()
        contenido.title = titulo
        contenido.body = cuerpo
        contenido.sound = nil
        let pedido = UNNotificationRequest(
            identifier: "entrenamiento-\(id)", content: contenido,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        centro.add(pedido)
    }
}

private final class DelegadoDeNotificaciones: NSObject, UNUserNotificationCenterDelegate,
                                               @unchecked Sendable {
    static let compartido = DelegadoDeNotificaciones()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
