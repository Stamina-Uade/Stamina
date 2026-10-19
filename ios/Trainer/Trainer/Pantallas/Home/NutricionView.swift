import SwiftUI
import TrainerCore

/// `nutricion` — objetivos, hidratación y comidas del servidor.
///
/// 🛑 El tono de todo lo que se ve acá **nunca es punitivo** (AGENTS.md §9.2).
/// No hay rojo por pasarse, ni "te excediste": el texto dice qué falta para lo
/// que viene, que es lo único accionable.
struct NutricionView: View {
    @EnvironmentObject private var estado: EstadoHome

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                EncabezadoDePestana(Textos.homeTabNutricion, sobretitulo: Textos.nutricionSubtitulo)

                if let nutricion = estado.contenido.nutricion.valor {
                    AvisoDeLoGuardado(seccion: estado.contenido.nutricion)
                    if let objetivo = nutricion.objetivo {
                        tarjetaDeCalorias(objetivo, provisional: nutricion.provisional)
                        tarjetaDeHidratacion(objetivo, tomadaMl: nutricion.aguaTomadaMl)
                    } else {
                        tarjetaSinObjetivos(nutricion.motivoSinObjetivo)
                    }
                } else {
                    SinDatosView(problema: estado.contenido.nutricion.problema, actualizando: estado.actualizando) {
                        Task { await estado.actualizar() }
                    }
                }
                // Siempre: una comida se anota aunque todavía no haya llegado nada del
                // servidor, y espera en la cola hasta que suba.
                seccionDeComidas
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Calorías y macros

    /// Lo comido es el número protagonista, sobre el halo rosa; el objetivo y lo
    /// que falta van chicos. Las macros, debajo, como tarjetas de métrica.
    private func tarjetaDeCalorias(_ objetivo: ObjetivoNutricional, provisional: Bool) -> some View {
        let comido = estado.consumido
        let restantes = max(0, objetivo.kcal - comido.kcal)

        return VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            TarjetaHeroe(alto: TokensEspaciado.e56 * 3) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                    PildoraDeEstado(Textos.nutricionKcalRestantes(Formato.kcal(restantes)),
                                    simbolo: "flame.fill", tono: .acento)
                    VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                        MetricaHeroe(Formato.kcal(comido.kcal), unidad: "kcal",
                                     etiquetaAccesible: Textos.nutricionTitulo)
                        Text(Textos.nutricionDeObjetivo(Formato.kcal(objetivo.kcal)))
                            .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    }
                    BarraDeProgreso(fraccion: Double(comido.kcal) / Double(max(objetivo.kcal, 1)),
                                    descripcion: Textos.nutricionTitulo)
                }
            }

            HStack(spacing: TokensEspaciado.e8) {
                TarjetaDeMacro(nombre: Textos.nutricionCarbos, actual: comido.carbohidratosG,
                               objetivo: objetivo.carbohidratosG)
                TarjetaDeMacro(nombre: Textos.nutricionProteina, actual: comido.proteinaG,
                               objetivo: objetivo.proteinaG)
                TarjetaDeMacro(nombre: Textos.nutricionGrasa, actual: comido.grasaG,
                               objetivo: objetivo.grasaG)
            }

            Text(Textos.nutricionHint)
                .estilo(.notaLegal, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)

            // Mientras nadie con formación revise los números, se dice (AGENTS.md §9.2).
            if provisional {
                Text(Textos.nutricionProvisional)
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Sin objetivos

    /// 🛑 AGENTS.md §9.2: cuando el servidor no da objetivos, se dice por qué y se
    /// acompaña. Ningún número de reemplazo, y el tono no reta.
    private func tarjetaSinObjetivos(_ motivo: MotivoSinObjetivos?) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            Text(Textos.nutricionSinObjetivosTitulo)
                .estilo(.tituloCard)
            Text(textoSinObjetivos(motivo))
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    private func textoSinObjetivos(_ motivo: MotivoSinObjetivos?) -> String {
        switch motivo {
        case .perfilIncompleto: return Textos.nutricionSinObjetivosPerfilIncompleto
        case .menorDeEdad: return Textos.nutricionSinObjetivosMenorDeEdad
        case .sexoSinDeclarar: return Textos.nutricionSinObjetivosSexoSinDeclarar
        case .faltaEmbarazoOLactancia: return Textos.nutricionSinObjetivosFaltaEmbarazoOLactancia
        case .embarazoOLactancia: return Textos.nutricionSinObjetivosEmbarazoOLactancia
        case nil: return Textos.homeDatosVacio
        }
    }

    // MARK: - Hidratación

    /// El agua del día. 🛑 Lo tomado se dibuja sólo si se sabe: la API no lo
    /// registra, y ocho vasos medio llenos inventados serían un dato de salud falso.
    @ViewBuilder
    private func tarjetaDeHidratacion(_ objetivo: ObjetivoNutricional, tomadaMl: Int?) -> some View {
        if let objetivoMl = objetivo.aguaMl, objetivoMl > 0 {
            VStack(alignment: .leading, spacing: TokensEspaciado.e11) {
                HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e6) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                    Text(Textos.nutricionHidratacion)
                        .estilo(.tituloSeccion)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }

                Text(textoDelAgua(objetivoMl: objetivoMl, tomadaMl: tomadaMl))
                    .estilo(.metricaMedia)

                // 8 vasos de 400 ml. Los llenos salen de lo que ya se tomó.
                if let tomadaMl {
                    HStack(spacing: TokensEspaciado.e5) {
                        ForEach(0..<8, id: \.self) { indice in
                            let lleno = indice < tomadaMl * 8 / objetivoMl
                            RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous)
                                .fill(lleno ? Paleta.acento : Paleta.superficieControl)
                                .shadow(color: lleno ? Paleta.acentoBrillo : Color.clear,
                                        radius: TokensEspaciado.e4)
                                .frame(maxWidth: .infinity)
                                .frame(height: TokensEspaciado.e26)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel(Textos.nutricionHidratacion)
                    .accessibilityValue(textoDelAgua(objetivoMl: objetivoMl, tomadaMl: tomadaMl))
                }

                if let mililitros = estado.sesion?.avituallamiento?.mililitrosTotales {
                    AvisoSuave(Textos.nutricionHidratacionNota(Formato.litros(mililitros)))
                }
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.vertical, TokensEspaciado.e16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjeta()
        }
    }

    private func textoDelAgua(objetivoMl: Int, tomadaMl: Int?) -> String {
        guard let tomadaMl else { return Textos.nutricionHidratacionObjetivo(Formato.litros(objetivoMl)) }
        return Textos.nutricionHidratacionDe(Formato.litros(tomadaMl), Formato.litros(objetivoMl))
    }

    // MARK: - Comidas

    private var seccionDeComidas: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            EncabezadoDeSeccion(Textos.nutricionComidasDeHoy,
                                detalle: Textos.nutricionResumenComidas(estado.comidas.count,
                                                                        estado.comidas.count + 2))

            ForEach(estado.comidas) { comida in
                FilaDeComida(comida: comida)
            }

            // Lo que el plan sugiere y todavía no se registró: sólo con una salida con
            // horario y con su avituallamiento calculado.
            if let sesion = estado.sesion, let minuto = sesion.minutoDelDia,
               let avituallamiento = sesion.avituallamiento {
                FilaSugerida(hora: minuto,
                             titulo: Textos.nutricionDuranteEntreno,
                             detalle: Textos.nutricionDuranteEntrenoDetalle(avituallamiento.geles,
                                                                            avituallamiento.carbohidratosPorHoraG),
                             deCarrera: true)
                FilaSugerida(hora: minuto + sesion.duracionMinutos + 20,
                             titulo: Textos.nutricionCena,
                             detalle: Textos.nutricionCenaDetalle,
                             deCarrera: false)
            }

            BotonAgregar(Textos.nutricionRegistrar) { estado.modal = .registrarComida }
        }
    }

}

/// Una macro del día: el nombre, lo comido contra el objetivo y su barra rosa.
/// Tiene la forma de `TarjetaMetrica`, más la barra, que esa no lleva.
private struct TarjetaDeMacro: View {
    let nombre: String
    let actual: Int
    let objetivo: Int

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            Text(nombre)
                .estilo(.labelCampo, color: Paleta.textoSecundario)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e2) {
                Text("\(actual)")
                    .estilo(.metricaMedia)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("/\(objetivo) g")
                    .estilo(.labelCampo, color: Paleta.textoTerciario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            BarraDeProgreso(fraccion: Double(actual) / Double(max(objetivo, 1)),
                            alto: TokensEspaciado.e4,
                            descripcion: nombre)
        }
        .padding(.horizontal, TokensEspaciado.e12)
        .padding(.vertical, TokensEspaciado.e11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(radio: TokensRadio.boton)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Filas

struct FilaDeComida: View {
    @EnvironmentObject private var estado: EstadoHome
    let comida: Comida

    var body: some View {
        HStack(spacing: TokensEspaciado.e11) {
            Text(Formato.hora(minutoDelDia: comida.minutoDelDia))
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                .monospacedDigit()
                .frame(width: TokensEspaciado.e40, alignment: .leading)

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(comida.nombre).estilo(.cuerpoSecundario)
                Text(Textos.nutricionMacrosFila(comida.kcal, comida.carbohidratosG, comida.proteinaG))
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { estado.quitarComida(comida.id) } label: {
                Text(Textos.nutricionQuitar)
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
                    .objetivoTactilAlto()
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityLabel("\(Textos.nutricionQuitar) \(comida.nombre)")
        }
        .padding(.horizontal, TokensEspaciado.e13)
        .padding(.vertical, TokensEspaciado.e12)
        .tarjeta()
        .opacity(0.72)
    }
}

/// Lo que el plan sugiere y todavía no se registró. Lo de la carrera lleva el
/// acento porque es parte de la sesión, no una comida más.
struct FilaSugerida: View {
    @EnvironmentObject private var estado: EstadoHome
    let hora: Int
    let titulo: String
    let detalle: String
    let deCarrera: Bool

    var body: some View {
        HStack(spacing: TokensEspaciado.e11) {
            Text(Formato.hora(minutoDelDia: hora))
                .estilo(.etiquetaSeccion.enMinusculas,
                        color: deCarrera ? Paleta.acento : Paleta.textoSecundario)
                .monospacedDigit()
                .frame(width: TokensEspaciado.e40, alignment: .leading)

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(titulo).estilo(.cuerpoSecundario)
                Text(detalle)
                    .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !deCarrera {
                Button { estado.modal = .registrarComida } label: {
                    Text(Textos.nutricionPendiente)
                        .estilo(.notaLegal, color: Paleta.acento)
                        .objetivoTactilAlto()
                }
                .buttonStyle(EstiloPresionado())
            }
        }
        .padding(.horizontal, TokensEspaciado.e13)
        .padding(.vertical, TokensEspaciado.e12)
        .background(deCarrera ? Paleta.acentoSuaveFondo : Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(deCarrera ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                              lineWidth: TokensEspaciado.e1)
        )
    }
}

// MARK: -

extension View {
    /// El fondo y el borde de una tarjeta del Home. Se repite en las siete
    /// pestañas, así que vive en un solo lugar.
    func tarjeta(radio: CGFloat = TokensRadio.card) -> some View {
        background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
    }
}
