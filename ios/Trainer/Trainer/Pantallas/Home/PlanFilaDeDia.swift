import SwiftUI
import TrainerCore

// MARK: - Un día, en la lista de la semana

/// Un día del plan, en una fila igual a las otras seis (2026-10-23): el día, el nombre
/// de la sesión y, a la derecha, la tilde verde si está hecho, "HOY" si es hoy o una
/// flecha si viene. Hoy lleva el borde del color de la app.
///
/// - Los descansos van en gris claro, sin flecha, y no se abren.
/// - Un día que tocaba entrenar y pasó sin nada registrado (`sinHacer`) queda en gris
///   apagado —toda la fila con baja opacidad—, sin cruz, sin rojo, sin ícono. Su hoja
///   ofrece "Lo hice: marcar como hecho".
/// - Tocar un día abre su hoja (`HojaDelDiaDelPlan`) en vez de desplegarse en la lista.
struct FilaDeDiaDelPlan: View {
    @EnvironmentObject private var estado: EstadoHome
    let dia: DiaDelPlan
    let alTocar: () -> Void

    private var forma: RoundedRectangle {
        RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
    }

    var body: some View {
        // Un descanso no es un botón (y no `.disabled`, que lo apagaría como a un día
        // sin hacer): sólo lleva el texto en gris claro.
        if dia.esDescanso {
            contenido.accessibilityElement(children: .combine)
        } else {
            Button(action: alTocar) { contenido }
                .buttonStyle(EstiloPresionado())
                .accessibilityElement(children: .combine)
                .accessibilityHint(Textos.planDayTapToSee)
        }
    }

    private var contenido: some View {
        HStack(spacing: TokensEspaciado.e12) {
            Text(PlanFechas.diaCorto(dia.diaDeLaSemana))
                .estilo(.cuerpoDestacado, color: dia.esHoy ? Paleta.acento : Paleta.textoSecundario)
                .frame(width: TokensEspaciado.e40, alignment: .leading)

            Text(titulo)
                .estilo(.cuerpoSecundario, color: dia.esDescanso ? Paleta.textoTerciario : Paleta.textoPrimario)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let pasos = estado.pasos(para: dia), pasos > 0, !dia.esDescanso {
                Text(Formato.pasos(pasos))
                    .estilo(.notaLegal, color: Paleta.textoTerciario)
                    .monospacedDigit()
            }

            final
        }
        .padding(.horizontal, TokensEspaciado.e14)
        .frame(minHeight: TokensTamano.objetivoTactilMinimo + TokensEspaciado.e8)
        .background(dia.esHoy ? Paleta.acentoSuaveFondo : Paleta.superficie)
        .clipShape(forma)
        .overlay(forma.strokeBorder(dia.esHoy ? Paleta.acento : Paleta.bordeSuperficie,
                                    lineWidth: dia.esHoy ? TokensEspaciado.e2 : TokensEspaciado.e1))
        // El día sin hacer: toda la fila apagada, nada más.
        .opacity(dia.sinHacer ? 0.4 : 1)
        .contentShape(forma)
    }

    /// "Rodaje suave · 6 km".
    private var titulo: String {
        guard !dia.esDescanso, let metros = dia.distanciaMetros, metros > 0 else { return dia.titulo }
        return "\(dia.titulo) · \(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))"
    }

    @ViewBuilder
    private var final: some View {
        if dia.hecho {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: TokensTipografia.tituloCardGrandeTamano, weight: .semibold))
                .foregroundStyle(Paleta.verdeMedidor)
                .accessibilityLabel(Textos.planDone)
        } else if dia.esHoy {
            Text(Textos.planTodayBadge)
                .estilo(.etiquetaSeccion, color: Paleta.acento)
        } else if !dia.esDescanso && !dia.sinHacer {
            Image(systemName: "chevron.right")
                .font(.system(size: TokensTipografia.notaTamano, weight: .bold))
                .foregroundStyle(Paleta.textoTerciario)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - La hoja de un día

/// Lo que antes se desplegaba dentro de la lista, en una hoja a la medida:
///
///   JUEVES 22 · HOY · 18:30
///   Rodaje suave · 8 km
///   [Zona 2 · suave] y qué se siente
///   Qué llevar para tomar: 500 ml de agua con sales · 1 gel
///   «Empezar esta salida» (sólo hoy, como antes)
///
/// Un día sin hacer muestra un solo texto y "Lo hice: marcar como hecho" abajo de todo,
/// con el botón secundario: cuenta para la semana, pero el fueguito no vuelve.
struct HojaDelDiaDelPlan: View {
    @EnvironmentObject private var estado: EstadoHome
    @Environment(\.dismiss) private var cerrar
    let dia: DiaDelPlan
    /// Guarda la marca en el servidor. `false` si no se pudo.
    let alMarcar: () async -> Bool

    @State private var marcando = false
    @State private var fallo = false

    /// Hoy, si el día no trae algo, lo trae la sesión del día (el mismo plan).
    private var sesionDeHoy: SesionDelDia? { dia.esHoy ? estado.sesion : nil }
    private var zona: ZonaDeIntensidad? { dia.zona ?? sesionDeHoy?.zona }
    private var avituallamiento: AvituallamientoDeSesion? { dia.avituallamiento ?? sesionDeHoy?.avituallamiento }
    private var minutoDelDia: Int? { dia.minutoDelDia ?? sesionDeHoy?.minutoDelDia }

    var body: some View {
        HojaAMedida(estimado: dia.sinHacer ? 300 : 420) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                    Text(PlanFechas.encabezado(dia, minuto: minutoDelDia))
                        .estilo(.etiquetaSeccion, color: dia.esHoy ? Paleta.acento : Paleta.textoTerciario)
                    Text(titulo)
                        .estilo(.tituloSeccion)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }

                if dia.sinHacer {
                    sinHacer
                } else {
                    detalle
                }
            }
            .margenesDeHoja()
        }
    }

    private var titulo: String {
        guard let metros = dia.distanciaMetros, metros > 0 else { return dia.titulo }
        return "\(dia.titulo) · \(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))"
    }

    // MARK: El día que pasó sin salida

    private var sinHacer: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
            Text(Textos.planDayMissed)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            if fallo {
                Text(Textos.planDayMarkFailed)
                    .estilo(.labelCampo, color: Paleta.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BotonSecundario(accion: marcar) {
                HStack(spacing: TokensEspaciado.e8) {
                    if marcando { ProgressView().tint(Paleta.textoPrimario) }
                    Text(Textos.planDayMarkDone)
                }
            }
            .disabled(marcando)
        }
    }

    private func marcar() {
        guard !marcando else { return }
        Haptico.toque()
        marcando = true
        fallo = false
        Task {
            let listo = await alMarcar()
            marcando = false
            if listo { cerrar() } else { fallo = true }
        }
    }

    // MARK: Un día con su sesión

    @ViewBuilder
    private var detalle: some View {
        if let zona {
            VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                PildoraDeEstado(Textos.zonePill(zona.numero, zona.sensacion), simbolo: "heart", tono: .acento)
                Text(zona.planExplicacion)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if dia.esFuerza {
            Text(Textos.planDayStrength)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        } else if !dia.detalle.isEmpty, dia.distanciaMetros == nil {
            Text(dia.detalle)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let llevar = queLlevar {
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                Text(Textos.planDayWhatToBring)
                    .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                    .accessibilityAddTraits(.isHeader)
                Text(llevar)
                    .estilo(.cuerpoDestacado)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if dia.abrible {
            BotonPrimario(Textos.planDayStartWorkout) {
                Haptico.toque()
                cerrar()
                estado.ir(a: .entreno)
            }
        } else if dia.esFuerza && dia.esHoy {
            BotonTonal(Textos.planDayViewRoutine) {
                Haptico.toque()
                cerrar()
                estado.ir(a: .gimnasio)
            }
        }
    }

    /// "500 ml de agua con sales · 1 gel", con los números del servidor.
    private var queLlevar: String? {
        guard let a = avituallamiento else { return nil }
        var partes: [String] = []
        if a.mililitrosTotales > 0 { partes.append(Textos.planDayWaterWithSalts(a.mililitrosTotales)) }
        if a.geles > 0 { partes.append(a.geles == 1 ? Textos.planDayGelOne : Textos.planDayGelsCount(a.geles)) }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }
}

// MARK: - Fechas de los días

enum PlanFechas {
    private static var idioma: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
    }

    /// "Lun" a "Dom" (ISO: 1 = lunes), los del catálogo.
    static func diaCorto(_ diaIso: Int) -> String {
        switch diaIso {
        case 1: return Textos.weekdayShortMon
        case 2: return Textos.weekdayShortTue
        case 3: return Textos.weekdayShortWed
        case 4: return Textos.weekdayShortThu
        case 5: return Textos.weekdayShortFri
        case 6: return Textos.weekdayShortSat
        default: return Textos.weekdayShortSun
        }
    }

    /// "JUEVES 22 · HOY · 18:30" (se ve en mayúsculas por el estilo).
    static func encabezado(_ dia: DiaDelPlan, minuto: Int? = nil) -> String {
        var calendario = Calendar(identifier: .gregorian)
        calendario.locale = idioma
        let indice = dia.diaDeLaSemana % 7
        let nombre = calendario.weekdaySymbols.indices.contains(indice) ? calendario.weekdaySymbols[indice] : ""
        var partes = ["\(nombre) \(dia.numeroDeDia)"]
        if dia.esHoy { partes.append(Textos.commonToday) }
        if !dia.sinHacer, let minuto = minuto ?? dia.minutoDelDia { partes.append(Formato.hora(minutoDelDia: minuto)) }
        return partes.joined(separator: " · ")
    }

    /// La fecha como la escribe el cronograma (`yyyy-MM-dd`, zona local).
    static func iso(_ fecha: Date) -> String { formateadorIso.string(from: fecha) }

    private static let formateadorIso: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

// MARK: - Las zonas, en palabras

extension ZonaDeIntensidad {
    /// Qué se siente y para qué sirve, sin jerga: la prueba del habla.
    fileprivate var planExplicacion: String {
        switch self {
        case .z1: return Textos.planDayZone1
        case .z2: return Textos.planDayZone2
        case .z3: return Textos.planDayZone3
        case .z4: return Textos.planDayZone4
        case .z5: return Textos.planDayZone5
        }
    }
}
