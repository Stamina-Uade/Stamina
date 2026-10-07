import Foundation

/// Regla de selección de idioma de la app:
/// 1. Si el dispositivo está en español (es), inglés (en) o francés (fr), usar ese idioma.
/// 2. Si el dispositivo está en cualquier otro idioma, usar inglés por defecto.
public enum ConfiguracionDeIdioma {
    public static var localeEfectivo: Locale {
        for lang in Locale.preferredLanguages {
            let pref = lang.prefix(2).lowercased()
            if pref == "es" { return Locale(identifier: "es") }
            if pref == "fr" { return Locale(identifier: "fr") }
            if pref == "en" { return Locale(identifier: "en") }
        }
        return Locale(identifier: "en")
    }
}
