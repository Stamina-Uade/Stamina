import SwiftUI
import TrainerCore

/// Ajustes → Datos personales: nombre, nacimiento, sexo, peso y altura. Cada
/// fila se despliega con su editor; "Guardar" manda un solo `PATCH /me` con lo
/// que cambió (`EditorDePerfil.swift`) y el Home lo ve al toque.
struct AjustesPaginaDatosPersonales: View {
    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    let volver: () -> Void

    var body: some View {
        if let perfil = flujo.perfil ?? estado.perfil {
            AjustesEditorDatosPersonales(perfil: perfil, unidades: estado.sistemaDeUnidades, volver: volver)
        } else {
            AjustesCargandoPerfil(titulo: Self.titulo, volver: volver)
        }
    }

    static var titulo: String {
        Textos.settingsPersonalTitle
    }
}

private struct AjustesEditorDatosPersonales: View {
    private enum Campo: Hashable { case nombre, nacimiento, sexo, peso, altura }

    @EnvironmentObject private var estado: EstadoHome
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @StateObject private var guardado = GuardadoDePerfil()

    private let volver: () -> Void
    private let correo: String
    /// Lo que está guardado y lo que se está editando. `borrador != original`
    /// es "hay cambios sin guardar".
    @State private var original: EdicionDePerfil
    @State private var borrador: EdicionDePerfil
    @State private var abierto: Campo?

    init(perfil: Perfil, unidades: SistemaDeUnidades, volver: @escaping () -> Void) {
        let base = EdicionDePerfil(perfil: perfil, unidades: unidades)
        _original = State(initialValue: base)
        _borrador = State(initialValue: base)
        correo = perfil.email
        self.volver = volver
    }

    var body: some View {
        AjustesPaginaDeEdicion(AjustesPaginaDatosPersonales.titulo,
                               hayCambios: borrador != original,
                               puedeGuardar: puedeGuardar,
                               guardado: guardado,
                               guardar: guardar,
                               volver: volver) {
            AjustesSeccion {
                filaNombre
                AjustesDivisorDeFila()
                filaNacimiento
                AjustesDivisorDeFila()
                filaSexo
                AjustesDivisorDeFila()
                AjustesFilaDeDato(simbolo: "envelope.fill", titulo: Self.tituloCorreo, valor: correo)
            }
            AjustesSeccion(Textos.profileYourBody) {
                filaPeso
                AjustesDivisorDeFila()
                filaAltura
            }
        }
        .onChange(of: borrador) { nuevo in guardado.contenidoCambio(hayCambios: nuevo != original) }
    }

    private var puedeGuardar: Bool {
        borrador.esValida(desde: original)
            && borrador.cambios(desde: original, zona: .autoupdatingCurrent) != nil
    }

    // MARK: - Filas

    private var filaNombre: some View {
        AjustesFilaDesplegable(simbolo: "person.fill", titulo: Textos.signupNameLabel,
                               valor: nombreCompleto,
                               editado: borrador.nombre != original.nombre || borrador.apellido != original.apellido,
                               abierta: abierto == .nombre, alTocar: { alternar(.nombre) }) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                CampoTexto(etiqueta: Textos.signupNameLabel, marcador: Textos.signupNamePlaceholder,
                           texto: $borrador.nombre, contenido: .nombre)
                CampoTexto(etiqueta: Textos.signupLastNameLabel, marcador: Textos.signupLastNamePlaceholder,
                           texto: $borrador.apellido, contenido: .apellido)
                if borrador.faltaElNombre(desde: original) {
                    PistaDeCampo(estado: .error(Self.faltaNombre))
                }
            }
        }
    }

    private var filaNacimiento: some View {
        AjustesFilaDesplegable(simbolo: "calendar", titulo: Self.tituloNacimiento,
                               valor: borrador.nacimiento.map {
                                   $0.formatted(.dateTime.day().month(.abbreviated).year())
                               } ?? "—",
                               editado: borrador.nacimiento != original.nacimiento,
                               abierta: abierto == .nacimiento, alTocar: { alternar(.nacimiento) }) {
            RuedaDeNacimiento(fecha: fechaDeLaRueda, nota: notaDeEdad)
        }
    }

    private var filaSexo: some View {
        AjustesFilaDesplegable(simbolo: "figure.stand", titulo: Self.tituloSexo,
                               valor: borrador.sexo.map(Self.nombre(de:)) ?? "—",
                               editado: borrador.sexo != original.sexo,
                               abierta: abierto == .sexo, alTocar: { alternar(.sexo) }) {
            VStack(spacing: TokensEspaciado.e8) {
                ForEach(SexoBiologico.allCases, id: \.self) { opcion in
                    FilaOpcion(titulo: Self.nombre(de: opcion), elegida: borrador.sexo == opcion) {
                        Haptico.seleccion()
                        borrador.sexo = opcion
                    }
                }
            }
        }
    }

    private var filaPeso: some View {
        AjustesFilaDesplegable(simbolo: "scalemass.fill", titulo: Textos.profileWeight,
                               valor: borrador.pesoTexto.isEmpty ? "—" : "\(borrador.pesoTexto) \(unidadDePeso)",
                               editado: borrador.pesoTexto != original.pesoTexto,
                               abierta: abierto == .peso, alTocar: { alternar(.peso) }) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                CampoTexto(etiqueta: esMetrico ? Textos.signupBodyWeightLabel : Self.etiquetaPesoEnLibras,
                           marcador: esMetrico ? Textos.signupBodyWeightPlaceholder : "160",
                           texto: $borrador.pesoTexto, estilo: .campoNumero, teclado: .decimal)
                if borrador.pesoInvalido(desde: original) {
                    PistaDeCampo(estado: .error(esMetrico ? Textos.signupBodyWeightOutOfRange
                                                         : Self.pesoFueraDeRangoEnLibras))
                }
            }
        }
    }

    private var filaAltura: some View {
        AjustesFilaDesplegable(simbolo: "ruler.fill", titulo: Textos.profileHeight,
                               valor: valorDeAltura,
                               editado: esMetrico ? borrador.alturaTexto != original.alturaTexto
                                                  : borrador.alturaEnPulgadas != original.alturaEnPulgadas,
                               abierta: abierto == .altura, alTocar: { alternar(.altura) }) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                if esMetrico {
                    CampoTexto(etiqueta: Textos.signupBodyHeightLabel, marcador: Textos.signupBodyHeightPlaceholder,
                               texto: $borrador.alturaTexto, estilo: .campoNumero, teclado: .decimal)
                } else {
                    ruedasDeAlturaImperial
                }
                if borrador.alturaInvalida(desde: original) {
                    PistaDeCampo(estado: .error(esMetrico ? Textos.signupBodyHeightOutOfRange
                                                         : Self.alturaFueraDeRangoImperial))
                }
            }
        }
    }

    // MARK: - Editores

    /// Pies y pulgadas, cada uno en su rueda. Mientras no haya altura cargada
    /// las ruedas se paran en 5′7″, pero nada cambia hasta que se muevan.
    private var ruedasDeAlturaImperial: some View {
        HStack(spacing: 0) {
            Picker(Self.pies, selection: enlaceDePies) {
                ForEach(EdicionDePerfil.piesPosibles, id: \.self) { pies in
                    Text(verbatim: "\(pies)′").tag(pies)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityLabel(Self.pies)

            Picker(Self.pulgadas, selection: enlaceDePulgadas) {
                ForEach(EdicionDePerfil.pulgadasPosibles, id: \.self) { pulgadas in
                    Text(verbatim: "\(pulgadas)″").tag(pulgadas)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityLabel(Self.pulgadas)
        }
        .frame(height: TokensEspaciado.e52 * 3)
        .compositingGroup()
        .background(Paleta.superficieHundida)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
    }

    private var pulgadasDeLaRueda: Int {
        borrador.alturaEnPulgadas ?? EdicionDePerfil.pulgadasIniciales
    }

    private var enlaceDePies: Binding<Int> {
        Binding(get: { min(max(pulgadasDeLaRueda / 12, 2), 8) },
                set: { borrador.alturaEnPulgadas = $0 * 12 + pulgadasDeLaRueda % 12 })
    }

    private var enlaceDePulgadas: Binding<Int> {
        Binding(get: { pulgadasDeLaRueda % 12 },
                set: { borrador.alturaEnPulgadas = min(max(pulgadasDeLaRueda / 12, 2), 8) * 12 + $0 })
    }

    /// Como en el alta: la rueda siempre muestra una fecha, pero sólo se
    /// escribe la que la persona elige.
    private var fechaDeLaRueda: Binding<Date> {
        // Al inicio del día, como el original: volver a la misma fecha no es un cambio.
        Binding(get: { borrador.nacimiento ?? DatosRegistro.posicionInicialDeLaRueda },
                set: { borrador.nacimiento = Calendar.current.startOfDay(for: $0) })
    }

    /// Debajo de la rueda, la edad que da la fecha elegida.
    private var notaDeEdad: String {
        guard let nacimiento = borrador.nacimiento,
              let anios = Calendar.current.dateComponents([.year], from: nacimiento, to: Date()).year
        else { return Textos.signupBirthMustChoose }
        return Textos.profileAgeYears(anios)
    }

    // MARK: - Valores

    private var esMetrico: Bool { borrador.unidades == .metrico }

    private var unidadDePeso: String { esMetrico ? "kg" : "lb" }

    private var nombreCompleto: String {
        let completo = [borrador.nombre, borrador.apellido]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return completo.isEmpty ? "—" : completo
    }

    private var valorDeAltura: String {
        if esMetrico {
            return borrador.alturaTexto.isEmpty ? "—" : "\(borrador.alturaTexto) cm"
        }
        guard let pulgadas = borrador.alturaEnPulgadas else { return "—" }
        return "\(pulgadas / 12)′\(pulgadas % 12)″"
    }

    private static func nombre(de sexo: SexoBiologico) -> String {
        switch sexo {
        case .femenino: return Textos.signupSexFemale
        case .masculino: return Textos.signupSexMale
        case .sinDeclarar: return Textos.signupSexUndisclosed
        }
    }

    // MARK: - Acciones

    private func alternar(_ campo: Campo) {
        Haptico.toque()
        withAnimation(reducirMovimiento ? nil : .spring(response: TokensMovimiento.media, dampingFraction: 0.9)) {
            abierto = abierto == campo ? nil : campo
        }
    }

    private func guardar() {
        guard borrador.esValida(desde: original),
              let cambios = borrador.cambios(desde: original, zona: .autoupdatingCurrent) else { return }
        Task { @MainActor in
            guard let nuevo = await guardado.guardar(cambios, en: flujo) else { return }
            // El Home también lo toma por `flujo.perfil` (`RaizHomeView.aplicar`);
            // esto es para que Perfil e Inicio no esperen ni un redibujo.
            estado.perfil = nuevo
            let base = EdicionDePerfil(perfil: nuevo, unidades: estado.sistemaDeUnidades)
            original = base
            borrador = base
            withAnimation(reducirMovimiento ? nil : .easeOut(duration: TokensMovimiento.rapida)) {
                abierto = nil
            }
        }
    }

    // MARK: - Textos nuevos

    private static let tituloNacimiento = Textos.settingsPersonalBirthdate
    private static let tituloSexo = Textos.settingsPersonalSex
    private static let tituloCorreo = Textos.settingsPersonalEmail
    private static let faltaNombre = Textos.settingsPersonalNameRequired
    private static let etiquetaPesoEnLibras = Textos.settingsPersonalWeightLabelLb
    private static let pesoFueraDeRangoEnLibras = Textos.settingsPersonalWeightOutOfRangeLb
    private static let alturaFueraDeRangoImperial = Textos.settingsPersonalHeightOutOfRangeFt
    private static let pies = Textos.settingsPersonalHeightFeet
    private static let pulgadas = Textos.settingsPersonalHeightInches
}
