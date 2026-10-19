import SwiftUI
import TrainerCore

// MARK: - Lo que se sabe de un día

/// Lo que se puede contar de un día además de su título: el renglón del
/// cronograma (sólo el plan principal) y, si es hoy, la sesión entera. 🛑 No se
/// calcula nada: se junta lo que mandó el servidor.
struct PlanDatosDelDia {
    let planificado: DiaPlanificadoCompartido?
    /// Sólo hoy: es la única sesión completa que llega.
    let sesion: SesionDelDia?
    let esFuerza: Bool
    let esDescanso: Bool
    let zona: ZonaDeIntensidad?

    init(dia: DiaDelPlan, planificado: DiaPlanificadoCompartido? = nil,
         sesion: SesionDelDia? = nil, esFuerzaHoy: Bool = false) {
        self.planificado = planificado
        self.sesion = sesion
        self.esFuerza = esFuerzaHoy || (planificado?.esFuerza ?? false)
        self.esDescanso = planificado?.esDescanso ?? false
        self.zona = sesion?.zona ?? Self.zonaEscrita(en: dia.detalle)
    }

    var minutoDelDia: Int? { sesion?.minutoDelDia ?? planificado?.minutoDelDia }
    var duracionMinutos: Int? { sesion?.duracionMinutos ?? planificado?.duracionMinutos }
    var distanciaMetros: Int? { sesion?.distanciaMetros ?? planificado?.distanciaMetros }

    /// El detalle de la fila es "10 km · Z2": la zona es uno de los pedazos.
    private static func zonaEscrita(en detalle: String) -> ZonaDeIntensidad? {
        for parte in detalle.components(separatedBy: "·") {
            let limpia = parte.trimmingCharacters(in: .whitespaces).lowercased()
            if let zona = ZonaDeIntensidad(rawValue: limpia) { return zona }
        }
        return nil
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

// MARK: - Un día, en la línea de tiempo

/// Un día del plan. Lo hecho se atenúa y lleva tilde; hoy lleva el acento, el
/// brillo y la palabra — nunca sólo el color (AGENTS.md §10.1). Tocarlo lo abre
/// en el lugar y muestra qué hacer, por qué y el botón para hacerlo.
struct FilaDeDiaDelPlan: View {
    @EnvironmentObject private var estado: EstadoHome
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let dia: DiaDelPlan
    let datos: PlanDatosDelDia
    let abierto: Bool
    var esPrimero: Bool = false
    var esUltimo: Bool = false
    let alTocar: () -> Void
    let abrirHistorial: () -> Void

    // Init explícito: con propiedades `private` el memberwise no se ve desde PlanView.
    init(dia: DiaDelPlan, datos: PlanDatosDelDia, abierto: Bool, esPrimero: Bool = false, esUltimo: Bool = false,
         alTocar: @escaping () -> Void, abrirHistorial: @escaping () -> Void) {
        self.dia = dia
        self.datos = datos
        self.abierto = abierto
        self.esPrimero = esPrimero
        self.esUltimo = esUltimo
        self.alTocar = alTocar
        self.abrirHistorial = abrirHistorial
    }

    private var forma: RoundedRectangle {
        RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
    }

    private var transicion: AnyTransition {
        reducirMovimiento ? AnyTransition.opacity
            : AnyTransition.opacity.combined(with: .move(edge: .top))
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: alTocar) { cabecera }
                .buttonStyle(EstiloPresionado())
                .accessibilityElement(children: .combine)
                .accessibilityValue(abierto
                    ? Textos.planDayExpanded
                    : Textos.planDayCollapsed)
                .accessibilityHint(abierto
                    ? Textos.planDayTapToClose
                    : Textos.planDayTapToSee)

            if abierto {
                PlanDetalleDelDia(dia: dia, datos: datos, abrirHistorial: abrirHistorial)
                    .transition(transicion)
            }
        }
        .frame(maxWidth: .infinity)
        .background(dia.esHoy ? Paleta.acentoSuaveFondo : Paleta.superficie)
        .clipShape(forma)
        .overlay(
            forma.strokeBorder(dia.esHoy || abierto ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                               lineWidth: TokensEspaciado.e1)
        )
        .shadow(color: dia.esHoy ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e8)
        .padding(.leading, TokensEspaciado.e26)
        .padding(.vertical, TokensEspaciado.e4)
        .overlay(alignment: .topLeading) { lineaDeTiempo }
    }

    // MARK: Cabecera (siempre visible)

    private var cabecera: some View {
        HStack(spacing: TokensEspaciado.e10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(nombreDelDia)
                Text(verbatim: "\(dia.numeroDeDia) \(dia.mesCorto)")
            }
            .estilo(.etiquetaSeccion.enMinusculas, color: dia.esHoy ? Paleta.acento : Paleta.textoTerciario)
            .monospacedDigit()
            .frame(width: TokensEspaciado.e34, alignment: .leading)

            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                Text(dia.titulo)
                    .estilo(.cuerpoDestacado)
                    .multilineTextAlignment(.leading)
                HStack(spacing: TokensEspaciado.e6) {
                    if !dia.detalle.isEmpty {
                        Text(dia.detalle)
                            .estilo(.labelCampo, color: Paleta.textoSecundario)
                    }
                    if let pasos = estado.pasos(para: dia), pasos > 0 {
                        pildoraDePasos(pasos)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if dia.hecho {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: TokensTipografia.tituloCardGrandeTamano,
                                  weight: TokensTipografia.tituloCardPeso))
                    .foregroundStyle(Paleta.acento)
                    .accessibilityLabel(Textos.planDone)
            } else if dia.esHoy {
                Text(Textos.planTodayBadge)
                    .estilo(.etiquetaSeccion, color: Paleta.acento)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: TokensTipografia.notaTamano, weight: .bold))
                .foregroundStyle(Paleta.textoTerciario)
                .rotationEffect(.degrees(abierto ? 180 : 0))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, TokensEspaciado.e13)
        .padding(.vertical, TokensEspaciado.e12)
        .frame(maxWidth: .infinity)
        .opacity(dia.hecho && !abierto ? 0.6 : 1)
        .objetivoTactilAlto()
    }

    private func pildoraDePasos(_ pasos: Int) -> some View {
        HStack(spacing: TokensEspaciado.e3) {
            Image(systemName: "figure.walk")
                .font(.system(size: TokensTipografia.etiquetaSeccionTamano, weight: .semibold))
            Text(Formato.pasos(pasos))
                .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                .monospacedDigit()
        }
        .foregroundStyle(Paleta.textoTerciario)
        .padding(.horizontal, TokensEspaciado.e5)
        .padding(.vertical, TokensEspaciado.e2)
        .background(Paleta.superficieAlterna)
        .clipShape(Capsule())
    }

    // MARK: Línea de tiempo

    /// El punto y la línea vertical. Es decoración: el estado ya lo dicen la
    /// tilde y "HOY" dentro de la tarjeta.
    private var lineaDeTiempo: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(esPrimero ? Color.clear : Paleta.acentoSuaveBorde)
                .frame(width: TokensEspaciado.e2, height: TokensEspaciado.e22)
            Circle()
                .fill(colorDelPunto)
                .frame(width: TokensEspaciado.e12, height: TokensEspaciado.e12)
                .overlay(Circle().strokeBorder(dia.hecho || dia.esHoy ? Color.clear : Paleta.bordeSuperficie,
                                               lineWidth: TokensEspaciado.e1))
                .shadow(color: dia.esHoy ? Paleta.acentoBrillo : Color.clear, radius: TokensEspaciado.e6)
            Rectangle()
                .fill(esUltimo ? Color.clear : Paleta.acentoSuaveBorde)
                .frame(width: TokensEspaciado.e2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: TokensEspaciado.e16)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }

    private var colorDelPunto: Color {
        if dia.esHoy || dia.hecho { return Paleta.acento }
        return Paleta.superficieControl
    }

    /// El nombre corto del día, del calendario en el idioma de la app y no de una lista fija.
    private var nombreDelDia: String {
        var calendario = Calendar.current
        calendario.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        let simbolos = calendario.shortWeekdaySymbols
        // `shortWeekdaySymbols` arranca en domingo; el plan arranca en lunes.
        let indice = (dia.diaDeLaSemana % 7)
        return simbolos.indices.contains(indice) ? simbolos[indice].capitalized : ""
    }
}

// MARK: - El detalle, desplegado

/// Qué hacer, cómo, por qué y con qué, con el botón para hacerlo. Cada parte
/// aparece sólo si el servidor la mandó: lo que no hay no se rellena.
private struct PlanDetalleDelDia: View {
    @EnvironmentObject private var estado: EstadoHome
    let dia: DiaDelPlan
    let datos: PlanDatosDelDia
    let abrirHistorial: () -> Void

    init(dia: DiaDelPlan, datos: PlanDatosDelDia, abrirHistorial: @escaping () -> Void) {
        self.dia = dia
        self.datos = datos
        self.abrirHistorial = abrirHistorial
    }

    private enum Momento { case pasado, hoy, futuro }

    private var momento: Momento? {
        if dia.esHoy { return .hoy }
        guard let fecha = dia.fecha else { return nil }
        return fecha < Calendar.current.startOfDay(for: Date()) ? .pasado : .futuro
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
            Rectangle()
                .fill(Paleta.divisor)
                .frame(height: TokensEspaciado.e1)
                .accessibilityHidden(true)

            if !datosRapidos.isEmpty {
                FlujoHorizontal(espaciado: TokensEspaciado.e6) {
                    ForEach(datosRapidos) { dato in
                        PlanChipDeDato(simbolo: dato.simbolo, texto: dato.texto)
                    }
                }
            }

            queEs
            estructura
            porQueHoy
            explicacionDeZona
            hidratacion
            clima

            accion
        }
        .padding(.horizontal, TokensEspaciado.e13)
        .padding(.bottom, TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Datos rápidos

    private struct DatoRapido: Identifiable {
        let id: String
        let simbolo: String
        let texto: String
    }

    private var datosRapidos: [DatoRapido] {
        var datosDelDia: [DatoRapido] = []
        if let minuto = datos.minutoDelDia {
            datosDelDia.append(DatoRapido(id: "hora", simbolo: "clock", texto: Formato.hora(minutoDelDia: minuto)))
        }
        if let minutos = datos.duracionMinutos, minutos > 0 {
            datosDelDia.append(DatoRapido(id: "duracion", simbolo: "timer",
                                          texto: Formato.duracionLarga(minutos: minutos)))
        }
        if let metros = datos.distanciaMetros, metros > 0 {
            datosDelDia.append(DatoRapido(id: "distancia", simbolo: "ruler",
                                          texto: Formato.distancia(metros, unidades: estado.sistemaDeUnidades)))
        }
        if let zona = datos.zona {
            datosDelDia.append(DatoRapido(id: "zona", simbolo: "heart",
                                          texto: "\(zona.corta) · \(zona.planIntensidad)"))
        }
        return datosDelDia
    }

    // MARK: Secciones

    /// Lo que es el día cuando no es una salida: descanso o fuerza.
    @ViewBuilder
    private var queEs: some View {
        if datos.esDescanso {
            parrafo(simbolo: "bed.double",
                    Textos.planDayRest)
        } else if datos.esFuerza {
            parrafo(simbolo: "dumbbell",
                    Textos.planDayStrength)
        }
    }

    @ViewBuilder
    private var estructura: some View {
        if let sesion = datos.sesion, !sesion.bloques.isEmpty {
            seccion(Textos.planDaySessionShape,
                    simbolo: "list.bullet") {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    ForEach(sesion.bloques) { bloque in
                        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
                            VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                                Text(bloque.titulo).estilo(.tituloCard)
                                if !bloque.detalle.isEmpty {
                                    Text(bloque.detalle)
                                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if let insignia = bloque.insignia, !insignia.isEmpty {
                                Text(insignia).estilo(.chip, color: Paleta.acento)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if sesion.runWalkRun {
                        Text(Textos.planDayRunWalk)
                            .estilo(.labelCampo, color: Paleta.textoTerciario)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var porQueHoy: some View {
        if let motivos = datos.sesion?.motivos, !motivos.isEmpty {
            seccion(Textos.planDayWhyToday,
                    simbolo: "lightbulb") {
                VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
                    ForEach(Array(motivos.enumerated()), id: \.offset) { _, motivo in
                        HStack(alignment: .top, spacing: TokensEspaciado.e6) {
                            Circle()
                                .fill(Paleta.acento)
                                .frame(width: TokensEspaciado.e5, height: TokensEspaciado.e5)
                                .padding(.top, TokensEspaciado.e6)
                                .accessibilityHidden(true)
                            Text(motivo)
                                .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var explicacionDeZona: some View {
        if let zona = datos.zona {
            seccion(Textos.planDayWhatIs(zona.corta),
                    simbolo: "heart.text.square") {
                Text(zona.planExplicacion)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: "\(Textos.zoneAccessibility(zona.numero)). \(zona.planExplicacion)"))
        }
    }

    private var datosDeHidratacion: [DatoRapido] {
        var lista: [DatoRapido] = []
        if let a = datos.sesion?.avituallamiento {
            if a.mililitrosTotales > 0 {
                lista.append(DatoRapido(id: "agua", simbolo: "drop", texto: Formato.litros(a.mililitrosTotales)))
            }
            if a.geles > 0 {
                lista.append(DatoRapido(id: "geles", simbolo: "bolt", texto: Self.geles(a.geles)))
            }
            if a.sodioMg > 0 {
                lista.append(DatoRapido(id: "sodio", simbolo: "sparkle",
                                        texto: Textos.planDaySodiumMg(a.sodioMg)))
            }
            if a.carbohidratosPorHoraG > 0 {
                lista.append(DatoRapido(id: "carbos", simbolo: "fork.knife",
                                        texto: Textos.planDayCarbsPerHour(a.carbohidratosPorHoraG)))
            }
        } else if let p = datos.planificado {
            if let agua = p.aguaMl, agua > 0 {
                lista.append(DatoRapido(id: "agua", simbolo: "drop", texto: Formato.litros(agua)))
            }
            if let geles = p.geles, geles > 0 {
                lista.append(DatoRapido(id: "geles", simbolo: "bolt", texto: Self.geles(geles)))
            }
            if let sales = p.sales, sales > 0 {
                lista.append(DatoRapido(id: "sales", simbolo: "sparkle",
                                        texto: sales == 1
                                            ? Textos.planDaySaltDoseOne
                                            : Textos.planDaySaltDosesCount(sales)))
            }
        }
        return lista
    }

    private static func geles(_ cantidad: Int) -> String {
        cantidad == 1
            ? Textos.planDayGelOne
            : Textos.planDayGelsCount(cantidad)
    }

    @ViewBuilder
    private var hidratacion: some View {
        let lista = datosDeHidratacion
        if !lista.isEmpty {
            seccion(Textos.planDayWhatToBring,
                    simbolo: "drop.fill") {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    Text(Textos.planDayFuelingBody)
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                    FlujoHorizontal(espaciado: TokensEspaciado.e6) {
                        ForEach(lista) { dato in
                            PlanChipDeDato(simbolo: dato.simbolo, texto: dato.texto)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var clima: some View {
        if let nota = datos.sesion?.notaDelClima, !nota.isEmpty {
            parrafo(simbolo: "cloud.sun", nota)
        }
    }

    // MARK: La acción

    @ViewBuilder
    private var accion: some View {
        if dia.hecho {
            BotonTonal(Textos.planDayViewInHistory) {
                abrirHistorial()
            }
        } else if datos.esFuerza {
            BotonTonal(Textos.planDayViewRoutine) {
                Haptico.toque()
                estado.ir(a: .gimnasio)
            }
        } else if dia.abrible {
            BotonPrimario(Textos.planDayStartWorkout) {
                Haptico.toque()
                estado.ir(a: .entreno)
            }
        } else if !datos.esDescanso, momento == .futuro {
            // `entreno` muestra la salida de HOY: abrir otro día mostraría una
            // sesión que no es la suya. Se dice cuándo se habilita.
            nota(simbolo: "calendar.badge.clock",
                 Textos.planDayAvailableThatDay)
        } else if !datos.esDescanso, momento == .pasado {
            nota(simbolo: "arrow.uturn.forward",
                 Textos.planDayPast)
        }
    }

    // MARK: Piezas

    private func seccion<Contenido: View>(_ titulo: String, simbolo: String,
                                          @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            HStack(spacing: TokensEspaciado.e6) {
                Image(systemName: simbolo)
                    .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                    .foregroundStyle(Paleta.acento)
                    .accessibilityHidden(true)
                Text(titulo)
                    .estilo(.etiquetaSeccion, color: Paleta.textoSecundario)
                    .accessibilityAddTraits(.isHeader)
            }
            contenido()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func parrafo(simbolo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            Image(systemName: simbolo)
                .font(.system(size: TokensTipografia.tituloCardTamano, weight: .semibold))
                .foregroundStyle(Paleta.acento)
                .frame(width: TokensEspaciado.e16)
                .accessibilityHidden(true)
            Text(texto)
                .estilo(.cuerpoSecundario, color: Paleta.textoCuerpo)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nota(simbolo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e8) {
            Image(systemName: simbolo)
                .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                .foregroundStyle(Paleta.textoTerciario)
                .accessibilityHidden(true)
            Text(texto)
                .estilo(.labelCampo, color: Paleta.textoTerciario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TokensEspaciado.e10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficieAlterna)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
    }
}

// MARK: - Chip de un dato

/// "07:00", "51 min", "Z2 · moderada": un dato con su ícono.
struct PlanChipDeDato: View {
    let simbolo: String
    let texto: String

    var body: some View {
        HStack(spacing: TokensEspaciado.e4) {
            Image(systemName: simbolo)
                .font(.system(size: TokensTipografia.chipTamano, weight: .semibold))
                .foregroundStyle(Paleta.acento)
                .accessibilityHidden(true)
            Text(texto)
                .estilo(.chip, color: Paleta.textoPrimario)
                .lineLimit(1)
        }
        .padding(.horizontal, TokensEspaciado.e8)
        .padding(.vertical, TokensEspaciado.e5)
        .background(Paleta.superficieAlterna)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Las zonas, en palabras

extension ZonaDeIntensidad {
    /// "baja", "moderada"… los mismos textos que usa Inicio.
    fileprivate var planIntensidad: String {
        switch self {
        case .z1: return Textos.zoneLow
        case .z2: return Textos.zoneModerate
        case .z3: return Textos.zoneModerateHigh
        case .z4: return Textos.zoneHigh
        case .z5: return Textos.zoneMax
        }
    }

    /// Qué se siente y para qué sirve, sin jerga: la prueba del habla.
    fileprivate var planExplicacion: String {
        switch self {
        case .z1:
            return Textos.planDayZone1
        case .z2:
            return Textos.planDayZone2
        case .z3:
            return Textos.planDayZone3
        case .z4:
            return Textos.planDayZone4
        case .z5:
            return Textos.planDayZone5
        }
    }
}
