import SwiftUI
import TrainerCore

// =============================================================================
// Pasos 4 a 6: nacimiento, sexo biológico y cuerpo. Cada uno guarda lo suyo con
// `PATCH /me` al tocar "Continuar" (decisión 0008).
//
// Los tres piden datos que el motor necesita para calcular, y los tres explican
// **para qué**. Eso no es relleno de copy: pedir sexo biológico sin decir que es
// para estimar sudoración es lo que hace que la gente abandone el registro.
// =============================================================================

/// `reg-nacimiento` · paso 4 de 11
///
/// "Continuar" se habilita con 18 años o más —la edad mínima de los términos—,
/// sin ningún mensaje en pantalla (VoiceOver dice por qué está apagado).
struct RegNacimientoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupBirthTitle(saludo),
                     texto: Textos.signupBirthBody) {
            RuedaDeNacimiento(fecha: fechaDeLaRueda)
                .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.tieneEdadMinima(),
                        motivoDeshabilitado: Textos.signupBirthMustChoose)
        }
    }

    /// 🛑 La rueda siempre muestra ALGUNA fecha, pero mientras nadie la mueva no hay
    /// ninguna elegida: se lee la posición de fábrica y sólo se escribe lo que la
    /// persona elige (ver `DatosRegistro.nacimiento`).
    private var fechaDeLaRueda: Binding<Date> {
        Binding(get: { flujo.datos.nacimiento ?? DatosRegistro.posicionInicialDeLaRueda },
                set: { flujo.datos.nacimiento = $0 })
    }

    private var saludo: String {
        let nombre = flujo.datos.nombre.trimmingCharacters(in: .whitespaces)
        return Textos.signupBirthGreeting(nombre.isEmpty ? Textos.signupNamePlaceholder : nombre)
    }
}

/// `reg-sexo` · paso 5 de 11
///
/// Arranca sin nada elegido: ver `DatosRegistro.sexo`.
struct RegSexoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    private struct Opcion {
        let valor: SexoBiologico
        let titulo: String
    }

    /// Sin texto debajo de cada opción (2026-10-22).
    private var opciones: [Opcion] {
        [
            Opcion(valor: .femenino, titulo: Textos.signupSexFemale),
            Opcion(valor: .masculino, titulo: Textos.signupSexMale),
            Opcion(valor: .sinDeclarar, titulo: Textos.signupSexUndisclosed),
        ]
    }

    var body: some View {
        PantallaPaso(titulo: Textos.signupSexTitle, texto: Textos.signupSexBody) {
            VStack(spacing: TokensEspaciado.e10) {
                ForEach(opciones, id: \.valor) { opcion in
                    FilaOpcion(titulo: opcion.titulo,
                               elegida: flujo.datos.sexo == opcion.valor) {
                        flujo.datos.sexo = opcion.valor
                    }
                }
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.sexo != nil)
        }
    }
}

/// `reg-cuerpo` · paso 6 de 11
///
/// Se escribe en kg y cm; el contrato guarda **gramos y milímetros enteros**
/// (AGENTS.md §5). La conversión vive en `DatosRegistro`, no acá.
struct RegCuerpoView: View {
    @EnvironmentObject private var flujo: FlujoEntrada

    var body: some View {
        PantallaPaso(titulo: Textos.signupBodyTitle, texto: Textos.signupBodyBody) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                    CampoTexto(etiqueta: Textos.signupBodyWeightLabel,
                               marcador: Textos.signupBodyWeightPlaceholder,
                               texto: $flujo.datos.pesoTexto,
                               estilo: .campoNumero, teclado: .decimal)
                    PistaDeCampo(estado: pistaPeso)
                }
                VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                    CampoTexto(etiqueta: Textos.signupBodyHeightLabel,
                               marcador: Textos.signupBodyHeightPlaceholder,
                               texto: $flujo.datos.alturaTexto,
                               estilo: .campoNumero, teclado: .decimal)
                    PistaDeCampo(estado: pistaAltura)
                }
            }
            .disabled(flujo.enCurso)
        } pie: {
            PieDePerfil(habilitado: flujo.datos.cuerpoCompleto)
        }
    }

    private var pistaPeso: EstadoCampo {
        if flujo.datos.pesoTexto.isEmpty { return .neutro }
        return flujo.datos.pesoEnGramos == nil
            ? .error(Textos.signupBodyWeightOutOfRange) : .neutro
    }

    private var pistaAltura: EstadoCampo {
        if flujo.datos.alturaTexto.isEmpty { return .neutro }
        return flujo.datos.alturaEnMilimetros == nil
            ? .error(Textos.signupBodyHeightOutOfRange) : .neutro
    }
}
