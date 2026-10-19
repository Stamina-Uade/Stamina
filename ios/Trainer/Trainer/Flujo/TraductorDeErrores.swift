import Foundation
import TrainerCore

// =============================================================================
// De un `Resultado` que salió mal a una frase que se le puede mostrar a alguien.
//
// 🛑 Traduce el `code` del contrato y NUNCA el `message` (docs/API.md §1). El
// mensaje del servidor es para el log de quien programa, está en inglés, y puede
// traer una ruta o un id que no tienen por qué terminar en la pantalla. Por eso
// `Resultado.rechazado` ni siquiera lo trae.
//
// Es la tabla de `recordarTraductorDeErrores()` de Android
// (`pantallas/acceso/Comunes.kt`), con los mismos códigos y el mismo criterio para
// uno que no conoce: se muestra con su nombre técnico en vez de tragárselo. Un
// error mudo cuesta más que uno feo — si el servidor agrega un código, acá se ve.
// =============================================================================

enum TraductorDeErrores {

    static func texto<Valor>(_ resultado: Resultado<Valor>) -> String {
        switch resultado {
        case .ok: return ""
        case .rechazado(let codigo, _): return texto(codigo: codigo)
        case .sinRed: return Textos.errorOffline
        case .respuestaRara: return Textos.errorUnexpectedResponse
        }
    }

    /// Los códigos de docs/API.md §2 que la app puede recibir hoy, más los dos
    /// del aviso legal (`backend/src/infra/errores.ts`).
    static func texto(codigo: String) -> String {
        switch codigo {
        case "bad_request": return Textos.errorBadRequest
        case "unauthorized": return Textos.errorUnauthorized
        case "not_found": return Textos.errorNotFound
        case "conflict": return Textos.errorConflict
        case "rate_limited": return Textos.errorRateLimited
        case "internal": return Textos.errorInternal
        case "service_unavailable": return Textos.errorServerUnavailable
        // 426: la app quedó por debajo del mínimo. Es lo mismo que diría la puerta
        // de versión, y se dice con las mismas palabras.
        case "unsupported_client": return Textos.versionRequiredBody
        case "invalid_credentials": return Textos.errorInvalidCredentials
        case "invalid_code": return Textos.errorInvalidCode
        case "code_expired": return Textos.errorCodeExpired
        case "code_resend_too_soon": return Textos.errorCodeResendTooSoon
        case "weak_password": return Textos.errorWeakPassword
        case "invalid_registration_token": return Textos.errorInvalidRegistrationToken
        case "invalid_reset_token": return Textos.errorInvalidResetToken
        case "invalid_refresh_token": return Textos.errorInvalidRefreshToken
        case "session_revoked": return Textos.errorSessionRevoked
        case "profile_incomplete": return Textos.errorProfileIncomplete
        case "legal_not_accepted": return Textos.errorLegalNotAccepted
        case "legal_version_stale": return Textos.errorLegalVersionStale
        default: return Textos.errorUnknownCode(codigo)
        }
    }
}
