import SwiftUI
import TrainerCore

/// `gimnasio` — la rutina del día. Se llega desde la agenda de `inicio`, no
/// desde la barra.
///
/// 🪤 Los chips de serie **ya no tildan a ciegas**. `ESPECIFICACION.md` §6.3 lo
/// dice explícito: el tilde ciego es lo que la captura de serie reemplaza, así
/// que tocar un chip abre la captura apuntada a esa serie.
struct GimnasioView: View {
    @EnvironmentObject private var estado: EstadoHome
    @State private var captura: DestinoDeCaptura?
    @State private var mostrandoCatalogo = false

    struct DestinoDeCaptura: Identifiable {
        let ejercicio: Int
        let serie: Int
        var id: String { "\(ejercicio)-\(serie)" }
    }

    var body: some View {
        VStack(spacing: 0) {
            CabeceraSecundaria(titulo: Textos.homeTabGym) {
                estado.volverDeLaPantallaSecundaria()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                    if estado.rutina.isEmpty {
                        SinDatosView(problema: estado.contenido.rutina.problema, actualizando: estado.actualizando) {
                            Task { await estado.actualizar() }
                        }
                    } else {
                        AvisoDeLoGuardado(seccion: estado.contenido.rutina)

                        Text(Textos.gymSubtitle)
                            .estilo(.labelCampo, color: Paleta.textoTerciario)

                        tarjetaDeProgreso

                        ForEach(Array(estado.rutina.enumerated()), id: \.element.id) { indice, ejercicio in
                            TarjetaDeEjercicio(indice: indice, ejercicio: ejercicio) { serie in
                                captura = DestinoDeCaptura(ejercicio: indice, serie: serie)
                            }
                        }
                    }

                    BotonAgregar(Textos.gymAddExercise) { mostrandoCatalogo = true }

                    BotonPrimario(Textos.gymFinish) {
                        estado.volverDeLaPantallaSecundaria()
                    }
                    .padding(.top, TokensEspaciado.e4)
                }
                .padding(.horizontal, TokensEspaciado.e16)
                .padding(.bottom, TokensEspaciado.e36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $captura) { destino in
            CapturaDeSerieView(indiceDeEjercicio: destino.ejercicio, serieApuntada: destino.serie)
                .environmentObject(estado)
        }
        .sheet(isPresented: $mostrandoCatalogo) {
            CatalogoDeEjerciciosView().environmentObject(estado)
        }
    }

    private var tarjetaDeProgreso: some View {
        let hechas = estado.seriesHechasDeLaRutina
        let total = estado.seriesTotalesDeLaRutina
        let fraccion = Double(hechas) / Double(max(total, 1))

        // Las series hechas son el número protagonista, sobre el halo rosa.
        return TarjetaHeroe(alto: TokensEspaciado.e56 * 3) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                HStack(alignment: .lastTextBaseline) {
                    MetricaHeroe("\(hechas)", unidad: "/ \(total)")
                    Spacer(minLength: TokensEspaciado.e8)
                    PildoraDeEstado(fraccion.formatted(.percent.precision(.fractionLength(0))),
                                    simbolo: "dumbbell.fill", tono: .acento)
                }
                Text(Textos.gymSetsCompleted)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)

                BarraDeProgreso(fraccion: fraccion, descripcion: Textos.gymProgress(hechas, total))

                Text(Textos.gymNote)
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Una tarjeta de ejercicio, con sus chips de serie.
struct TarjetaDeEjercicio: View {
    @EnvironmentObject private var estado: EstadoHome
    let indice: Int
    let ejercicio: EjercicioDeGimnasio
    let alTocarSerie: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            HStack(alignment: .top, spacing: TokensEspaciado.e10) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                    Text(ejercicio.nombre).estilo(.opcionTitulo)
                    Text(prescripcionLegible)
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                    // La columna PREVIA: con esto la persona elige la carga, que el motor
                    // no prescribe.
                    if !seriesPrevias.isEmpty {
                        Text(Textos.gymPrevious(seriesPrevias))
                            .estilo(.notaLegal, color: Paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                PildoraDeEstado(ejercicio.etiqueta,
                                tono: ejercicio.etiqueta == "Para correr" ? .acento : .neutro)
            }

            HStack(spacing: TokensEspaciado.e7) {
                ForEach(Array(ejercicio.prescripcion.series.enumerated()), id: \.element.id) { numero, serie in
                    ChipDeSerie(numero: numero + 1,
                                serie: serie,
                                unidad: ejercicio.prescripcion.unidadDePeso,
                                hecha: numero < estado.seriesHechas(enEjercicio: ejercicio.id),
                                unidades: estado.sistemaDeUnidades) {
                        alTocarSerie(numero)
                    }
                }
            }

            Text(ejercicio.porQue)
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, TokensEspaciado.e14)
        .padding(.vertical, TokensEspaciado.e13)
        .frame(maxWidth: .infinity)
        .tarjeta(radio: TokensRadio.card)
    }

    /// "10 × 12 kg · 8": lo de la vez anterior, serie por serie. Una serie
    /// salteada no se muestra como si se hubiera hecho.
    private var seriesPrevias: String {
        let porTiempo = ejercicio.prescripcion.series.first?.porTiempo ?? false
        return ejercicio.seriesPrevias.filter { !$0.salteada }.map { previa in
            let repeticiones = porTiempo ? "\(previa.repeticiones) s" : "\(previa.repeticiones)"
            guard let gramos = previa.pesoGramos else { return repeticiones }
            return "\(repeticiones) × \(Formato.peso(gramos, unidades: estado.sistemaDeUnidades))"
        }
        .joined(separator: " · ")
    }

    /// La prescripción se **compone para mostrar** y no se guarda como texto
    /// (`ESPECIFICACION.md` §6.2).
    private var prescripcionLegible: String {
        let series = ejercicio.prescripcion.series
        guard let primera = series.first else { return "" }
        let repeticiones = primera.porTiempo ? "\(primera.repeticiones) s" : "\(primera.repeticiones)"
        var partes = ["\(series.count) × \(repeticiones)"]
        if let gramos = primera.pesoGramos {
            partes.append(Formato.peso(gramos, unidades: estado.sistemaDeUnidades))
        }
        partes.append(Textos.gymRestSeconds(ejercicio.prescripcion.descansoSegundos))
        return partes.joined(separator: " · ")
    }
}

/// Un chip de serie. Hecho lleva relleno de acento **y** tilde: nunca sólo color.
struct ChipDeSerie: View {
    let numero: Int
    let serie: SeriePrescrita
    let unidad: UnidadDePeso?
    let hecha: Bool
    let unidades: SistemaDeUnidades
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: TokensEspaciado.e3) {
                if hecha {
                    Image(systemName: "checkmark")
                        .font(.system(size: TokensTipografia.etiquetaSeccionTamano,
                                      weight: .heavy))
                }
                Text(etiqueta)
                    .estilo(.chip, color: hecha ? Paleta.sobreAcento : Paleta.textoSecundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            // Hecha: relleno rosa lleno, tilde y halo. Nunca sólo color.
            .foregroundStyle(hecha ? Paleta.sobreAcento : Paleta.textoSecundario)
            .frame(maxWidth: .infinity)
            .frame(height: TokensTamano.objetivoTactilMinimo)
            .background(hecha ? Paleta.acento : Paleta.superficieHundida)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
                    .strokeBorder(hecha ? Paleta.acento : Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
            )
            .shadow(color: hecha ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e6)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(Textos.gymSetNumber(numero))
        .accessibilityValue(etiqueta)
        .accessibilityAddTraits(hecha ? [.isButton, .isSelected] : .isButton)
    }

    private var etiqueta: String {
        if serie.porTiempo { return "\(serie.repeticiones)s" }
        guard let gramos = serie.pesoGramos, unidad != nil else { return "\(serie.repeticiones)" }
        let kg = Int((Double(gramos) / 1000).rounded())
        return "\(serie.repeticiones)×\(kg)"
    }
}
