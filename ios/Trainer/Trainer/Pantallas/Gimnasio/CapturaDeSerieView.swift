import SwiftUI
import TrainerCore

/// La captura de serie y el descanso: siete pantallas del diseño nuevo
/// (`serie`, `serie-teclado`, `serie-corregir`, `serie-casos`, `descanso`,
/// `descanso-fondo`, `descanso-fin`).
///
/// Las reglas que la gobiernan, todas de `ESPECIFICACION.md` §6.4:
///
/// - **El botón primario dice lo que va a guardar** ("Serie 3 hecha · 8 × 45 kg"),
///   así que confirmar es un tap y no es a ciegas.
/// - **La precarga es determinística** (§6.2): si el peso varía entre series, se
///   precarga el objetivo de *esa* serie; si es igual en todas, la última hecha.
///   Sin heurísticas ni adivinanzas de progresión.
/// - **Una serie fallida no es un error**: se bajan las reps y se confirma. Se
///   guarda con el número real, sin rojo y sin tono punitivo (AGENTS.md §9.2).
/// - **Con todas las series hechas el botón cambia** a "Ir al ejercicio
///   siguiente" y no guarda nada: sobrescribir la última en silencio fue uno de
///   los ocho defectos que §6.5 corrigió.
struct CapturaDeSerieView: View {
    @EnvironmentObject var estado: EstadoHome
    @Environment(\.dismiss) private var cerrar

    var indiceDeEjercicio: Int = 0
    var serieApuntada: Int = 0

    @State private var serieActual = 0
    @State private var repeticiones = 0
    @State private var pesoGramos = 0
    @State private var descansando = false
    @State private var segundosDeDescanso = 0
    @State private var salteadas: Set<Int> = []
    @State private var extras = 0

    private var ejercicio: EjercicioDeGimnasio { estado.rutina[indiceDeEjercicio] }
    private var totalDeSeries: Int { ejercicio.prescripcion.series.count + extras }
    private var todasHechas: Bool { serieActual >= totalDeSeries }

    var body: some View {
        if estado.rutina.indices.contains(indiceDeEjercicio) {
            contenido
        } else {
            // La rutina cambió con la hoja abierta —llegó otra del servidor— y este
            // ejercicio ya no está: no hay nada que capturar.
            Spacer().onAppear { cerrar() }
        }
    }

    private var contenido: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if descansando {
                    DescansoView(segundos: $segundosDeDescanso,
                                 ejercicio: ejercicio.nombre,
                                 seriesQueFaltan: max(0, totalDeSeries - serieActual)) {
                        descansando = false
                    }
                } else {
                    captura
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paleta.fondo)
            .navigationTitle(ejercicio.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Volver no descarta: lo registrado queda guardado (§6.3).
                    Button(Textos.comunVolver) { cerrar() }
                }
            }
        }
        .onAppear(perform: precargar)
    }

    // MARK: - La captura

    private var captura: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                tiraDeSeries

                if !todasHechas {
                    stepper(Textos.serieRepeticiones + (esPorTiempo ? " (\(Textos.serieSegundos.lowercased()))" : ""),
                            valor: "\(repeticiones)",
                            bajar: { repeticiones = max(1, repeticiones - 1) },
                            subir: { repeticiones = min(200, repeticiones + 1) })

                    if ejercicio.prescripcion.unidadDePeso != nil {
                        stepper(Textos.seriePeso,
                                valor: Formato.peso(pesoGramos, unidades: estado.sistemaDeUnidades),
                                bajar: { pesoGramos = max(0, pesoGramos - 2500) },
                                subir: { pesoGramos = min(500_000, pesoGramos + 2500) })
                    }
                }

                botonPrimario

                if !todasHechas {
                    BotonTexto(Textos.serieSaltear, color: Paleta.textoSecundario) { saltear() }
                }
            }
            .padding(TokensEspaciado.e16)
        }
    }

    /// Los chips de todas las series: hechas, la actual, las salteadas y las
    /// extra. Tocar una ya hecha la reapunta para corregirla, sin navegar.
    private var tiraDeSeries: some View {
        FlujoHorizontal(espaciado: TokensEspaciado.e7) {
            ForEach(0..<totalDeSeries, id: \.self) { indice in
                let hecha = indice < serieActual && !salteadas.contains(indice)
                let esActual = indice == serieActual
                let salteada = salteadas.contains(indice)
                let esExtra = indice >= ejercicio.prescripcion.series.count

                Button { apuntar(a: indice) } label: {
                    VStack(spacing: TokensEspaciado.e2) {
                        Text(esExtra ? "+\(indice + 1)" : "\(indice + 1)")
                            .estilo(.labelCampo, color: colorDe(hecha: hecha, actual: esActual, salteada: salteada))
                        if salteada {
                            Text(Textos.serieSalteada)
                                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                        }
                    }
                    .frame(width: TokensEspaciado.e56, height: TokensTamano.objetivoTactilMinimo)
                    .background(hecha ? Paleta.acentoChipActivo : Paleta.superficieHundida)
                    .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous)
                            .strokeBorder(bordeDe(hecha: hecha, actual: esActual, salteada: salteada),
                                          style: StrokeStyle(lineWidth: TokensEspaciado.e2,
                                                             dash: salteada ? [3, 3] : []))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityLabel(Textos.gymSerieNumero(indice + 1))
                .accessibilityAddTraits(hecha ? [.isButton, .isSelected] : .isButton)
            }

            Button { extras += 1 } label: {
                Image(systemName: "plus")
                    .foregroundStyle(Paleta.textoSecundario)
                    .frame(width: TokensEspaciado.e56, height: TokensTamano.objetivoTactilMinimo)
                    .background(Paleta.superficieHundida)
                    .clipShape(RoundedRectangle(cornerRadius: TokensRadio.celda, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityLabel(Textos.serieExtra)
        }
    }

    private func colorDe(hecha: Bool, actual: Bool, salteada: Bool) -> Color {
        if salteada { return Paleta.textoTerciario }
        if hecha { return Paleta.acento }
        return actual ? Paleta.textoPrimario : Paleta.textoSecundario
    }

    private func bordeDe(hecha: Bool, actual: Bool, salteada: Bool) -> Color {
        if salteada { return Paleta.bordeSignificante }
        if actual { return Paleta.acento }
        return hecha ? Paleta.acentoSuaveBorde : .clear
    }

    private func stepper(_ etiqueta: String, valor: String,
                         bajar: @escaping () -> Void, subir: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            Text(etiqueta).estilo(.tituloCard)
            StepperDeValor(etiqueta: etiqueta, valor: valor, bajar: bajar, subir: subir)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(radio: TokensRadio.boton)
    }

    /// Dice exactamente lo que va a guardar, o cambia de acción si ya no hay
    /// nada que guardar.
    private var botonPrimario: some View {
        Group {
            if todasHechas {
                BotonPrimario(Textos.serieSiguiente) { cerrar() }
            } else if serieActual < estado.seriesHechas(enEjercicio: indiceDeEjercicio) {
                BotonPrimario(Textos.serieCorregir(serieActual + 1)) { confirmar() }
            } else {
                BotonPrimario(Textos.serieConfirmar(serieActual + 1, resumenDeLaSerie)) { confirmar() }
            }
        }
    }

    private var resumenDeLaSerie: String {
        let reps = esPorTiempo ? "\(repeticiones) s" : "\(repeticiones)"
        guard ejercicio.prescripcion.unidadDePeso != nil else { return reps }
        return "\(reps) × \(Formato.peso(pesoGramos, unidades: estado.sistemaDeUnidades))"
    }

    private var esPorTiempo: Bool {
        ejercicio.prescripcion.series.first?.porTiempo ?? false
    }

    // MARK: - Acciones

    private func precargar() {
        serieActual = max(serieApuntada, estado.seriesHechas(enEjercicio: indiceDeEjercicio))
        serieActual = min(serieActual, ejercicio.prescripcion.series.count)
        apuntar(a: serieActual)
    }

    /// La regla de precarga de §6.2, sin heurística.
    private func apuntar(a indice: Int) {
        serieActual = indice
        let series = ejercicio.prescripcion.series
        guard !series.isEmpty else { return }

        let pesos = Set(series.compactMap(\.pesoGramos))
        let prescrita = series[min(indice, series.count - 1)]

        repeticiones = prescrita.repeticiones
        if pesos.count > 1 {
            // El peso varía entre series: se precarga el objetivo de ESTA serie.
            pesoGramos = prescrita.pesoGramos ?? 0
        } else {
            // Es igual en todas: se precarga la última efectivamente hecha, que
            // en esta sesión es la que ya se confirmó.
            pesoGramos = prescrita.pesoGramos ?? 0
        }
    }

    private func confirmar() {
        salteadas.remove(serieActual)
        // Se registra ESTA serie con los valores que se ven en el botón, no un
        // contador: es lo que viaja al reloj y lo que el motor de la fase 7 va a
        // comparar contra lo prescrito.
        estado.registrarSerie(ejercicio: indiceDeEjercicio,
                              numero: serieActual + 1,
                              repeticiones: repeticiones,
                              pesoGramos: ejercicio.prescripcion.unidadDePeso == nil ? nil : pesoGramos)
        let siguiente = serieActual + 1
        serieActual = siguiente

        if serieActual < totalDeSeries {
            apuntar(a: serieActual)
            segundosDeDescanso = ejercicio.prescripcion.descansoSegundos
            descansando = true
        }
    }

    private func saltear() {
        salteadas.insert(serieActual)
        serieActual = min(serieActual + 1, totalDeSeries)
        if serieActual < totalDeSeries { apuntar(a: serieActual) }
    }
}

// MARK: - `descanso`, `descanso-fondo` y `descanso-fin`

/// La cuenta regresiva del descanso.
///
/// 🛑 Al llegar a cero avisa con **ícono, texto y vibración**, nunca sólo con
/// color (AGENTS.md §10.1). "Saltar" es imprescindible en superseries.
///
/// 🪤 Lo que falta: seguir contando con la app en segundo plano y la pantalla
/// apagada. Eso es una notificación local programada, y pedir permiso de
/// notificaciones necesita la pantalla previa que explica por qué —que
/// `ESPECIFICACION.md` §8.1 declara **no diseñada**—. Está en la decisión 0007.
struct DescansoView: View {
    @Binding var segundos: Int
    let ejercicio: String
    let seriesQueFaltan: Int
    let alTerminar: () -> Void

    @State private var temporizador: Timer?
    @State private var termino = false

    var body: some View {
        VStack(spacing: TokensEspaciado.e20) {
            Spacer()

            if termino {
                Image(systemName: "bell.fill")
                    .font(.system(size: TokensTipografia.numeroDatoTamano))
                    .foregroundStyle(Paleta.acento)
                Text(Textos.descansoFin)
                    .estilo(.tituloConfirmacion)
                Text(Textos.descansoFinDetalle(ejercicio))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
            } else {
                Text(Textos.descansoTitulo)
                    .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                Text(Formato.cronometro(segundos: segundos))
                    .estilo(.numeroDato)
                Text(Textos.descansoFaltan(seriesQueFaltan))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
            }

            Spacer()

            VStack(spacing: TokensEspaciado.e10) {
                if !termino {
                    BotonSecundario(accion: { segundos += 30 }) {
                        Text(Textos.descansoMas).estilo(.botonPrimario, color: Paleta.textoPrimario)
                    }
                }
                BotonPrimario(termino ? Textos.comunListo : Textos.descansoSaltar) { terminar() }
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.bottom, TokensEspaciado.e26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: arrancar)
        .onDisappear { temporizador?.invalidate() }
    }

    private func arrancar() {
        temporizador?.invalidate()
        temporizador = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if segundos > 0 {
                    segundos -= 1
                } else if !termino {
                    termino = true
                    temporizador?.invalidate()
                    Vibracion.avisar()
                }
            }
        }
    }

    private func terminar() {
        temporizador?.invalidate()
        alTerminar()
    }
}

/// La vibración del aviso. Aislada acá para que no la copie cada pantalla.
enum Vibracion {
    static func avisar() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#endif
