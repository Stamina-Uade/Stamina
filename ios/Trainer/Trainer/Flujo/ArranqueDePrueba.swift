import Foundation
import TrainerCore

// =============================================================================
// Arrancar la app en una pantalla concreta, con datos de ejemplo.
//
// 🛑 SÓLO EN DEBUG. El bloque entero desaparece del binario de release, así que
// no hay forma de llegar a esto desde una app publicada. Los argumentos de
// lanzamiento los pone Xcode o `simctl`, nunca quien usa la app.
//
// Existe por dos motivos: los tests de UI necesitan entrar a un paso sin
// recorrer los doce anteriores, y revisar una pantalla contra el diseño no
// puede costar quince toques.
//
//   xcrun simctl launch <udid> com.tecladus.Trainer -pantallaInicial regDias -datosDeEjemplo
// =============================================================================

enum ArranqueDePrueba {
    #if DEBUG
    /// 🛑 2026-10-21 (Iván): el esquema de Xcode tenía prendidos `-pantallaInicial
    /// home -datosDeEjemplo`, y la app abría el Home con "Iván Benítez" aunque se
    /// hubiera cerrado la sesión. Ahora nada de esto funciona contra el servidor
    /// de verdad: sólo con los dobles de los tests (`-serviciosDePrueba`), que es
    /// para lo que existe. Sin sesión, la app NUNCA entra al Home.
    private static var conDobles: Bool {
        ProcessInfo.processInfo.arguments.contains(ServiciosDeLaApp.argumentoDeDobles)
    }

    /// La pantalla pedida por argumento, si la hay y si existe.
    static var pantalla: Pantalla? {
        guard conDobles, let slug = valor("-pantallaInicial") else { return nil }
        return Pantalla(rawValue: slug)
    }

    /// Un perfil completo, para ver las pantallas con contenido real en vez de
    /// campos vacíos.
    static var datos: DatosRegistro? {
        guard conDobles, ProcessInfo.processInfo.arguments.contains("-datosDeEjemplo") else { return nil }
        var d = DatosRegistro()
        d.correo = "ivan@trainer.app"
        d.codigo = "A7K2Q9"
        d.nombre = "Iván"
        d.apellido = "Benítez"
        // Las elecciones arrancan vacías en la app de verdad (ver `DatosRegistro`);
        // acá van puestas para revisar las pantallas con una opción elegida.
        d.nacimiento = DatosRegistro.posicionInicialDeLaRueda
        d.sexo = .masculino
        d.pesoTexto = "72"
        d.alturaTexto = "178"
        d.deporte = .running
        d.nivel = .intermedio
        d.objetivo = .mediaMaraton
        return d
    }

    /// Lo que no vive en `DatosRegistro`: los campos del login y de la
    /// recuperación de contraseña. Sin esto no se puede ver el botón primario
    /// **encendido**, que es la mitad de lo que hay que revisar.
    static var credencialesDeEjemplo: (correo: String, clave: String)? {
        guard conDobles, ProcessInfo.processInfo.arguments.contains("-datosDeEjemplo") else { return nil }
        return (correo: "ivan@trainer.app", clave: "Trainer2026")
    }

    /// La pestaña del Home con la que arrancar, para revisar una pantalla sin
    /// recorrer el registro entero.
    static var pestanaHome: PestanaHome? {
        guard conDobles, let slug = valor("-pestanaHome") else { return nil }
        return PestanaHome(rawValue: slug)
    }

    /// Si el Home arranca con la maqueta del diseño (`RepositorioProvisional`) en vez
    /// de hablar con el servidor.
    static var conDatosDeEjemplo: Bool {
        conDobles && ProcessInfo.processInfo.arguments.contains("-datosDeEjemplo")
    }

    private static func valor(_ bandera: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: bandera), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
    #else
    static var pantalla: Pantalla? { nil }
    static var datos: DatosRegistro? { nil }
    static var credencialesDeEjemplo: (correo: String, clave: String)? { nil }
    static var pestanaHome: PestanaHome? { nil }
    /// 🛑 Un binario publicado no tiene cómo mostrar la maqueta en el Home.
    static var conDatosDeEjemplo: Bool { false }
    #endif
}
