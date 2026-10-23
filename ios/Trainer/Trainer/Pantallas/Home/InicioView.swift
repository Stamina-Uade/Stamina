import SwiftUI
import TrainerCore

/// `inicio` — "menos cosas a la vista" (decisión de Iván del 2026-10-23), de arriba
/// hacia abajo:
///
///   la barra fija «Inicio» con el fueguito (`PantallaDePestana`)
///   "Jueves, 22 de octubre" / "Buenas tardes, Iván"
///   HOY: la sesión del día, «Empezar salida» y «Qué llevar: …», que abre la hoja
///        `HojaQueLlevarHoy`; hecha la salida, lo que hiciste y qué toca mañana
///   el objetivo: la carrera, los días que faltan y "Esta semana · 12 de 26 km",
///        sobre una foto; o "Completa tu perfil" / "Ingresa tu nuevo objetivo"
///
/// Se fueron los accesos rápidos (repetían las pestañas), "Tu día" (pasó a la hoja
/// de qué llevar), la carga semanal (quedó en la línea de la semana), la píldora del
/// apto (queda en Perfil) y las píldoras de zona e hidratación de la tarjeta de hoy.
struct InicioView: View {
    @EnvironmentObject private var estado: EstadoHome
    /// El perfil a medio hacer y el camino de vuelta a sus pasos.
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var actividadElegida: Actividad?
    /// La hoja "Qué llevar hoy".
    @State private var mostrarQueLlevar = false
    /// Para la entrada suave de las tarjetas. Con Reducir movimiento no se anima.
    @State private var aparecio = false

    var body: some View {
        PantallaDePestana(Textos.homeTabHome, alRefrescar: { await estado.actualizar() }) {
            FueguitoDeLaBarra()
        } contenido: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                EncabezadoDePestana(saludo, sobretitulo: fechaDeHoy)

                if estado.plan != nil {
                    AvisoDeLoGuardado(seccion: estado.contenido.plan)
                }

                if let plan = estado.plan {
                    tarjetaDeHoy(plan)
                        .entradaDeTarjeta(0, visible: aparecio, movimientoReducido: movimientoReducido)
                }

                tarjetaDelObjetivo
                    .entradaDeTarjeta(1, visible: aparecio, movimientoReducido: movimientoReducido)

                if estado.plan == nil, estado.contenido.plan.problema != nil {
                    SinDatosView(problema: estado.contenido.plan.problema, actualizando: estado.actualizando) {
                        Task { await estado.actualizar() }
                    }
                }
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .onAppear { aparecio = true }
        .sheet(item: $actividadElegida) { actividad in
            DetalleDeActividadView(
                actividad: actividad,
                puntosIniciales: estado.recorridosLocales[actividad.id] ?? AlmacenDeRecorridos.compartido.puntos(para: actividad.id),
                servicio: estado.repositorio.servicioDeActividades(),
                unidades: estado.sistemaDeUnidades
            )
        }
        .sheet(isPresented: $mostrarQueLlevar) {
            if let sesion = estado.sesion {
                HojaQueLlevarHoy(sesion: sesion, unidades: estado.sistemaDeUnidades)
            }
        }
    }

    // MARK: - Saludo

    /// "Jueves, 22 de octubre": la fecha de HOY, en el idioma de la app.
    private var fechaDeHoy: String {
        let idioma = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        return Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(idioma)).capitalizedPrimeraLetra
    }

    /// "Buenas tardes, Iván". Sin nombre cargado queda el saludo solo, nunca "Buen día, ".
    private var saludo: String {
        let hora = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hora {
        case 5..<13: base = Textos.homeGreetingMorning
        case 13..<20: base = Textos.homeGreetingAfternoon
        default: base = Textos.homeGreetingEvening
        }
        guard let nombre = primerNombre else { return base }
        return "\(base), \(nombre)"
    }

    private var primerNombre: String? {
        let partes = estado.nombreCompleto
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
        guard let primero = partes.first, !primero.isEmpty else { return nil }
        return String(primero)
    }

    // MARK: - Hoy

    /// Lo que toca hoy; si ya entrenaste, lo que hiciste. Reemplaza a la sección
    /// "Entrenamientos de hoy".
    @ViewBuilder
    private func tarjetaDeHoy(_ plan: PlanDelHome) -> some View {
        if let hecha = estado.actividadesDeHoy.first {
            tarjetaDeHoyHecha(hecha)
        } else if let sesion = estado.sesion {
            tarjetaDeHoyConSalida(sesion)
        } else {
            tarjetaDeHoySinSalida(plan.hoy)
        }
    }

    /// "HOY · 18:30 / Rodaje suave / 8 km · zona 2, suave / Empezar salida /
    /// Qué llevar: 500 ml/h · 1 gel ›".
    private func tarjetaDeHoyConSalida(_ sesion: SesionDelDia) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                Text(sesion.minutoDelDia.map { Textos.homeTodayAt(Formato.hora(minutoDelDia: $0)) } ?? Textos.commonToday)
                    .estilo(.etiquetaSeccion, color: Paleta.acento)
                Text(sesion.tipo)
                    .estilo(.tituloCardGrande)
                    .fixedSize(horizontal: false, vertical: true)
                if let linea = lineaDeLaSesion(sesion) {
                    Text(linea)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !sesion.notaDelClima.isEmpty {
                HStack(spacing: TokensEspaciado.e6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: TokensTipografia.notaTamano, weight: .semibold))
                        .foregroundStyle(Paleta.acento)
                        .accessibilityHidden(true)
                    Text(sesion.notaDelClima)
                        .estilo(.notaLegal, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            BotonPrimario(estado.haySesionEnCurso ? Textos.homeBackToWorkout : Textos.homeStartWorkout) {
                Haptico.toque()
                estado.ir(a: .entreno)
            }

            if let avituallamiento = sesion.avituallamiento {
                lineaQueLlevar(avituallamiento)
            }
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    /// "8 km · zona 2, suave": la zona en palabras, sin la jerga "Z2".
    private func lineaDeLaSesion(_ sesion: SesionDelDia) -> String? {
        var partes: [String] = []
        if let metros = sesion.distanciaMetros {
            partes.append(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))
        }
        if let zona = sesion.zona {
            partes.append(Textos.zoneWords(zona.numero, zona.sensacion))
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    /// Una sola línea tocable con lo que hay que llevar, con los datos del servidor.
    private func lineaQueLlevar(_ a: AvituallamientoDeSesion) -> some View {
        var partes = [Textos.homeMlPerHour(a.mililitrosPorHora)]
        if a.geles > 0 { partes.append(a.geles == 1 ? Textos.planDayGelOne : Textos.planDayGelsCount(a.geles)) }
        return Button {
            Haptico.toque()
            mostrarQueLlevar = true
        } label: {
            HStack(spacing: TokensEspaciado.e6) {
                Text(Textos.homeWhatToBringLine(partes.joined(separator: " · ")))
                    .estilo(.cuerpoSecundario, color: Paleta.textoAcento)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                    .foregroundStyle(Paleta.textoAcento)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityHint(Textos.homeWhatToBringHint)
    }

    /// "✓ HOY · HECHO / Rodaje suave / 8,02 km · 46:21 · 5:47 /km / Mañana: Descanso".
    /// Los números son los de la salida; tocarla abre su detalle.
    private func tarjetaDeHoyHecha(_ actividad: Actividad) -> some View {
        Button {
            Haptico.toque()
            actividadElegida = actividad
        } label: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                HStack(spacing: TokensEspaciado.e6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                        .foregroundStyle(Paleta.exito)
                        .accessibilityHidden(true)
                    Text(Textos.homeTodayDone)
                        .estilo(.etiquetaSeccion, color: Paleta.exito)
                }
                Text(estado.sesion?.tipo ?? actividad.sport.nombreVisible)
                    .estilo(.tituloCardGrande)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(resumenDe(actividad))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .monospacedDigit()
                if let manana = lineaDeManana {
                    Text(manana)
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                        .padding(.top, TokensEspaciado.e8)
                }
            }
            .padding(TokensEspaciado.e16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjeta()
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Textos.historyRowHint)
    }

    /// "8,02 km · 46:21 · 5:47 /km". Sin distancia, sólo el tiempo.
    private func resumenDe(_ actividad: Actividad) -> String {
        var partes: [String] = []
        if let metros = actividad.distanceM, metros > 0 {
            partes.append(Formato.distancia(Int(metros), unidades: estado.sistemaDeUnidades, decimales: 2))
        }
        partes.append(Formato.cronometro(segundos: Int(actividad.durationS)))
        if let dist = actividad.distanceM, dist >= 100, actividad.durationS > 0 {
            let segsKm = Int((Double(actividad.durationS) * 1000 / Double(dist)).rounded())
            let unidad = estado.sistemaDeUnidades == .imperial ? " /mi" : " /km"
            partes.append(Formato.ritmo(segundosPorKm: segsKm, unidades: estado.sistemaDeUnidades) + unidad)
        }
        return partes.joined(separator: " · ")
    }

    /// "Mañana: Descanso", lo que dice el plan para mañana. Sin plan para mañana, nada.
    private var lineaDeManana: String? {
        guard let manana = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
              let dia = estado.plan?.cronograma.first(where: { $0.fechaIso == PlanFechas.iso(manana) })
        else { return nil }
        var titulo = dia.tipo
        if dia.esDescanso != true, let metros = dia.distanciaMetros, metros > 0 {
            titulo += " · " + Formato.distancia(metros, unidades: estado.sistemaDeUnidades)
        }
        return Textos.homeTomorrow(titulo)
    }

    private func iconoDelDia(fuerza: Bool) -> some View {
        ZStack {
            Circle().fill(Paleta.acentoChipActivo)
            Image(systemName: fuerza ? "dumbbell.fill" : "figure.run")
                .font(.system(size: TokensTipografia.tituloCardGrandeTamano, weight: .bold))
                .foregroundStyle(Paleta.acento)
        }
        .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
        .accessibilityHidden(true)
    }

    /// Hoy no hay una salida: un descanso, un día de fuerza o un día que no está
    /// en el bloque. Se dice lo que dice el plan, con sus palabras.
    private func tarjetaDeHoySinSalida(_ hoy: DiaDeHoy?) -> some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e12) {
            iconoDelDia(fuerza: hoy?.esFuerza == true)
            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                Text(Textos.commonToday)
                    .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                Text(hoy?.titulo ?? Textos.homeNothingPlannedToday)
                    .estilo(.tituloCardGrande)
                    .fixedSize(horizontal: false, vertical: true)
                if let detalle = hoy?.detalle, !detalle.isEmpty {
                    Text(detalle)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if hoy?.esFuerza == true {
                    BotonTexto(Textos.homeViewRoutine) {
                        Haptico.toque()
                        estado.ir(a: .gimnasio)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    // MARK: - El objetivo: siempre hay uno a la vista

    /// Con plan vigente, la carrera con su cuenta regresiva y la semana. Sin plan (o
    /// con el plan terminado), la invitación a elegir el próximo objetivo. Sin red no
    /// se invita: ahí el problema es la conexión, no el objetivo.
    ///
    /// 2026-10-22: con el perfil a medio hacer ("Completar después"), en su lugar
    /// va "Completa tu perfil", que lleva al primer dato que falta. También cuando
    /// lo dice el motor (`profile_incomplete`) y `GET /me` todavía no llegó.
    @ViewBuilder
    private var tarjetaDelObjetivo: some View {
        if flujo.pasoPendienteDelPerfil != nil || estado.faltaPerfil {
            tarjetaCompletaTuPerfil
        } else if let bloque = estado.bloque, !estado.planVencido {
            tarjetaDeLaCarrera(bloque)
        } else if !(estado.actualizando && estado.plan == nil),
                  estado.contenido.plan.problema == nil || estado.contenido.plan.problema == .perfilIncompleto {
            tarjetaNuevoObjetivo
        }
    }

    /// La foto del día para la tarjeta, con su punto de encuadre.
    private var foto: String? { FondosDeTarjeta.imagen(para: .running, contexto: "inicio") }

    /// "Media maratón / Dom 15 mar / 144 días / Esta semana · 12 de 26 km ▬▬▭". Tocarla va a Plan.
    private func tarjetaDeLaCarrera(_ bloque: BloqueDelPlan) -> some View {
        Button {
            Haptico.toque()
            estado.ir(a: .plan)
        } label: {
            TarjetaHeroe(imagen: foto, encuadre: FondosDeTarjeta.encuadre(de: foto), alto: TokensEspaciado.e56 * 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(bloque.evento)
                        .estilo(.tituloCard)
                        .fixedSize(horizontal: false, vertical: true)
                    if let fecha = fechaDeLaCarrera(bloque) {
                        Text(fecha).estilo(.labelCampo, color: Paleta.textoSecundario)
                    }
                    Spacer(minLength: TokensEspaciado.e56)
                    if let dias = estado.diasParaLaCarrera {
                        MetricaHeroe("\(dias)", unidad: dias == 1 ? Textos.commonDay : Textos.commonDays,
                                     etiquetaAccesible: Textos.commonToGo)
                    } else {
                        MetricaHeroe("\(bloque.semanasQueFaltan)", unidad: Textos.commonWeeks,
                                     etiquetaAccesible: Textos.commonToGo)
                    }
                    if let semana = bloque.semanas.first(where: { $0.enCurso }) {
                        lineaDeLaSemana(semana)
                            .padding(.top, TokensEspaciado.e8)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Textos.homeViewPlan)
    }

    /// "Esta semana · 12 de 26 km" y la barra. Los dos números son los del servidor.
    private func lineaDeLaSemana(_ semana: SemanaDelPlan) -> some View {
        let fraccion = semana.metrosPrevistos > 0
            ? min(1, Double(semana.metrosHechos) / Double(semana.metrosPrevistos)) : 0
        return VStack(alignment: .leading, spacing: TokensEspaciado.e6) {
            HStack(spacing: TokensEspaciado.e6) {
                Text(Textos.homeThisWeek).estilo(.labelCampo, color: Paleta.textoSecundario)
                Spacer(minLength: 0)
                Text(Textos.planKmOf(
                    Formato.distanciaNumero(semana.metrosHechos, unidades: estado.sistemaDeUnidades, decimales: 0),
                    Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades, decimales: 0)))
                    .estilo(.labelCampo, color: Paleta.textoPrimario)
                    .monospacedDigit()
            }
            BarraDeProgreso(fraccion: fraccion, descripcion: Textos.homeThisWeek)
        }
    }

    /// "Dom 15 mar". Sólo lo que el plan sabe: sin fecha no hay fecha.
    private func fechaDeLaCarrera(_ bloque: BloqueDelPlan) -> String? {
        guard let ms = bloque.fechaDelEventoMs else { return nil }
        let idioma = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        let fecha = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        return fecha.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(idioma))
            .capitalizedPrimeraLetra
    }

    /// Con el perfil a medias: la tarjeta lleva al primer dato que falta.
    private var tarjetaCompletaTuPerfil: some View {
        TarjetaHeroe(imagen: foto, encuadre: FondosDeTarjeta.encuadre(de: foto), alto: TokensEspaciado.e56 * 4) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                Spacer(minLength: TokensEspaciado.e20)
                Text(Textos.homeCompleteProfileTitle)
                    .estilo(.display)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Textos.homeCompleteProfileBody)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                BotonPrimario(Textos.homeCompleteProfileButton) {
                    Haptico.toque()
                    retomarPerfil()
                }
            }
        }
    }

    /// Al primer hueco del perfil. Si el que avisó fue el motor y el perfil todavía
    /// no llegó, primero se pide: sin él no se sabe a qué paso ir.
    private func retomarPerfil() {
        guard flujo.pasoPendienteDelPerfil == nil else { return flujo.retomarPerfil() }
        Task {
            await flujo.cargarPerfil()
            flujo.retomarPerfil()
        }
    }

    /// Sin objetivo: la tarjeta héroe invita a elegir el próximo. Lleva a Plan,
    /// que es donde vive el selector de metas.
    private var tarjetaNuevoObjetivo: some View {
        TarjetaHeroe(imagen: foto, encuadre: FondosDeTarjeta.encuadre(de: foto), alto: TokensEspaciado.e56 * 4) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                PildoraDeEstado(Textos.homeNoActiveGoal, simbolo: "flag", tono: .neutro)
                Spacer(minLength: TokensEspaciado.e20)
                Text(Textos.homeEnterNewGoal)
                    .estilo(.display)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Textos.homeChooseNextRace)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                BotonPrimario(Textos.homeChooseGoal) {
                    Haptico.toque()
                    estado.ir(a: .plan)
                }
            }
        }
    }
}

extension String {
    /// "viernes 16 de octubre" → "Viernes 16 de octubre": sólo la primera letra,
    /// `capitalized` subiría también "De" y "Octubre".
    var capitalizedPrimeraLetra: String {
        guard let primera = first else { return self }
        return primera.uppercased() + String(dropFirst())
    }
}

extension ZonaDeIntensidad {
    /// "suave", "moderada": cómo se siente la zona, en palabras de todos los días.
    /// Es lo que va en lugar de la sigla en Inicio ("zona 2, suave") y en Plan.
    var sensacion: String {
        switch self {
        case .z1: return Textos.zoneFeel1
        case .z2: return Textos.zoneFeel2
        case .z3: return Textos.zoneFeel3
        case .z4: return Textos.zoneFeel4
        case .z5: return Textos.zoneFeel5
        }
    }
}

// MARK: - Entrada de las tarjetas

/// Cada tarjeta entra con un fundido y un desplazamiento chico, una detrás de
/// otra. Con Reducir movimiento aparecen quietas, ya en su lugar.
private struct EntradaDeTarjeta: ViewModifier {
    let orden: Int
    let visible: Bool
    let movimientoReducido: Bool

    func body(content: Content) -> some View {
        let mostrar = visible || movimientoReducido
        return content
            .opacity(mostrar ? 1 : 0)
            .offset(y: mostrar ? 0 : TokensEspaciado.e12)
            .animation(movimientoReducido
                       ? nil
                       : .easeOut(duration: TokensMovimiento.media).delay(Double(orden) * 0.05),
                       value: visible)
    }
}

private extension View {
    func entradaDeTarjeta(_ orden: Int, visible: Bool, movimientoReducido: Bool) -> some View {
        modifier(EntradaDeTarjeta(orden: orden, visible: visible, movimientoReducido: movimientoReducido))
    }
}
