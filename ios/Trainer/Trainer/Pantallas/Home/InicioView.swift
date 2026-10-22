import SwiftUI
import TrainerCore

/// `inicio` — la pantalla 2 del mockup del MVP, de arriba hacia abajo:
///
///   Stamina · racha (el perfil se abre desde su pestaña)
///   "Viernes 16 de octubre" / "Buen día, Sofi"
///   la píldora del apto físico
///   la tarjeta de la próxima carrera ("23 días para tu media maratón"), o
///   "Ingresá tu nuevo objetivo" si no hay ninguna — siempre hay un objetivo a la vista
///   HOY: la sesión del día y su avituallamiento
///   entrenamientos de hoy, tu día y la carga de la semana
///
/// Las piezas chicas (agenda, gráfico de carga, racha) viven en `InicioPiezas.swift`;
/// los accesos rápidos, la carga semanal y las hojas que explican la jerga, en los
/// otros `Inicio*.swift`. El calendario anual se mudó a la pestaña Historial.
struct InicioView: View {
    @EnvironmentObject private var estado: EstadoHome
    /// El perfil a medio hacer y el camino de vuelta a sus pasos.
    @EnvironmentObject private var flujo: FlujoEntrada
    @Environment(\.accessibilityReduceMotion) private var movimientoReducido
    @State private var actividadElegida: Actividad?
    @State private var mostrarApto = false
    /// La hoja que explica la zona o la hidratación de hoy.
    @State private var explicacion: ExplicacionDeInicio? = nil
    /// Para la entrada suave de las tarjetas. Con Reducir movimiento no se anima.
    @State private var aparecio = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                barraSuperior

                VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                    EncabezadoDePestana(saludo, sobretitulo: fechaDeHoy)
                    pildoras
                }

                if estado.plan != nil {
                    AvisoDeLoGuardado(seccion: estado.contenido.plan)
                }

                tarjetaDelObjetivo
                    .entradaDeTarjeta(0, visible: aparecio, movimientoReducido: movimientoReducido)

                if let plan = estado.plan {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                        if let sesion = estado.sesion {
                            tarjetaDeHoy(sesion)
                            if let avituallamiento = sesion.avituallamiento {
                                chipsDelAvituallamiento(avituallamiento, duracionMinutos: sesion.duracionMinutos)
                            }
                        } else {
                            tarjetaDeHoySinSalida(plan.hoy)
                        }
                    }
                    .entradaDeTarjeta(1, visible: aparecio, movimientoReducido: movimientoReducido)
                }

                InicioAccesosRapidos(abrirApto: { mostrarApto = true })
                    .entradaDeTarjeta(2, visible: aparecio, movimientoReducido: movimientoReducido)

                if !estado.actividadesDeHoy.isEmpty {
                    seccionEntrenamientosDeHoy
                        .entradaDeTarjeta(3, visible: aparecio, movimientoReducido: movimientoReducido)
                }

                if let plan = estado.plan {
                    if !estado.agenda.isEmpty {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                            EncabezadoDeSeccion(Textos.homeYourDay)
                            ForEach(estado.agenda) { fila in
                                FilaDeAgendaView(fila: fila)
                            }
                        }
                        .entradaDeTarjeta(4, visible: aparecio, movimientoReducido: movimientoReducido)
                    }
                    InicioTarjetaDeCarga(plan: plan)
                        .entradaDeTarjeta(5, visible: aparecio, movimientoReducido: movimientoReducido)
                } else if estado.contenido.plan.problema != nil {
                    SinDatosView(problema: estado.contenido.plan.problema, actualizando: estado.actualizando) {
                        Task { await estado.actualizar() }
                    }
                }
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.top, TokensEspaciado.e8)
            .padding(.bottom, TokensEspaciado.e36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Tirar hacia abajo trae lo nuevo, igual que al volver a primer plano.
        .refreshable { await estado.actualizar() }
        .onAppear { aparecio = true }
        .sheet(item: $actividadElegida) { actividad in
            DetalleDeActividadView(
                actividad: actividad,
                puntosIniciales: estado.recorridosLocales[actividad.id] ?? AlmacenDeRecorridos.compartido.puntos(para: actividad.id),
                servicio: estado.repositorio.servicioDeActividades(),
                unidades: estado.sistemaDeUnidades
            )
        }
        .sheet(isPresented: $mostrarApto) {
            AptoFisicoView()
        }
        .sheet(item: $explicacion) { explicacion in
            HojaDeExplicacion(explicacion: explicacion)
        }
    }

    // MARK: - Barra superior: Stamina · racha

    private var barraSuperior: some View {
        HStack(spacing: TokensEspaciado.e6) {
            Text(MarcaApp.nombre)
                .estilo(.marca, color: Paleta.acento)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let plan = estado.plan {
                InsigniaDeRacha(racha: plan.racha)
            }
        }
        // El mismo alto que tenía con el avatar, para que el saludo no suba.
        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
    }

    // MARK: - Saludo

    /// "Viernes 16 de octubre": la fecha de HOY, en el idioma de la app.
    private var fechaDeHoy: String {
        let idioma = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        return Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(idioma)).capitalizedPrimeraLetra
    }

    /// "Buen día, Sofi". Sin nombre cargado queda el saludo solo, nunca "Buen día, ".
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

    // MARK: - Píldoras: el apto y la salida en curso

    private var pildoras: some View {
        FlujoHorizontal(espaciado: TokensEspaciado.e6) {
            PildoraDelApto { mostrarApto = true }
            if estado.haySesionEnCurso {
                Button { estado.ir(a: .entreno) } label: {
                    PildoraDeEstado(Textos.homeWorkoutInProgress,
                                    simbolo: "bolt.fill", tono: .acento)
                }
                .buttonStyle(EstiloPresionado())
                .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            }
        }
    }

    // MARK: - El objetivo: siempre hay uno a la vista

    /// Con plan vigente, la cuenta regresiva de la carrera. Sin plan (o con el plan
    /// terminado), la invitación a elegir el próximo objetivo. Sin red no se invita:
    /// ahí el problema es la conexión, no el objetivo.
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

    private func tarjetaDeLaCarrera(_ bloque: BloqueDelPlan) -> some View {
        Button {
            Haptico.toque()
            estado.ir(a: .plan)
        } label: {
            TarjetaHeroe(imagen: FondosDeTarjeta.imagen(para: .running, contexto: "inicio"), alto: TokensEspaciado.e56 * 4) {
                VStack(alignment: .leading, spacing: 0) {
                    if let pildora = pildoraDeLaCarrera(bloque) {
                        PildoraDeEstado(pildora, simbolo: "flag.fill", tono: .acento)
                    }
                    Spacer(minLength: TokensEspaciado.e56 + TokensEspaciado.e26)
                    HStack(alignment: .bottom, spacing: TokensEspaciado.e12) {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                            if let dias = estado.diasParaLaCarrera {
                                MetricaHeroe("\(dias)",
                                             unidad: dias == 1
                                                ? Textos.commonDay
                                                : Textos.commonDays,
                                             etiquetaAccesible: Textos.commonToGo)
                            } else {
                                MetricaHeroe("\(bloque.semanasQueFaltan)",
                                             unidad: Textos.commonWeeks,
                                             etiquetaAccesible: Textos.commonToGo)
                            }
                            Text(Textos.homeUntilYour(bloque.evento.lowercased()))
                                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: TokensEspaciado.e4) {
                            Text(Textos.homeViewPlan).estilo(.chip, color: Paleta.textoPrimario)
                            Image(systemName: "chevron.right")
                                .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                                .foregroundStyle(Paleta.textoPrimario)
                        }
                        .padding(.horizontal, TokensEspaciado.e12)
                        .padding(.vertical, TokensEspaciado.e8)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                        .accessibilityHidden(true)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityHint(Textos.homeViewPlan)
    }

    /// "Dom 8 nov · 21 km". Sólo lo que el plan sabe: sin fecha no hay fecha.
    private func pildoraDeLaCarrera(_ bloque: BloqueDelPlan) -> String? {
        var partes: [String] = []
        if let ms = bloque.fechaDelEventoMs {
            let idioma = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
            let fecha = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
            partes.append(fecha.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(idioma))
                .capitalizedPrimeraLetra)
        }
        if let metros = bloque.distanciaDelEventoMetros {
            partes.append(Formato.distancia(metros, unidades: estado.sistemaDeUnidades, decimales: 0))
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    /// Sin objetivo: la tarjeta héroe invita a elegir el próximo. Lleva a Plan,
    /// que es donde vive el selector de metas.
    private var tarjetaCompletaTuPerfil: some View {
        TarjetaHeroe(imagen: FondosDeTarjeta.imagen(para: .running, contexto: "inicio"), alto: TokensEspaciado.e56 * 4) {
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

    private var tarjetaNuevoObjetivo: some View {
        TarjetaHeroe(imagen: FondosDeTarjeta.imagen(para: .running, contexto: "inicio"), alto: TokensEspaciado.e56 * 4) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                PildoraDeEstado(Textos.homeNoActiveGoal,
                                simbolo: "flag", tono: .neutro)
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

    // MARK: - Hoy

    /// "HOY · Rodaje suave · 8 km · Sugerido 7:30 · ritmo cómodo". Con hora, lleva
    /// la cuenta regresiva y "Preparar salida".
    private func tarjetaDeHoy(_ sesion: SesionDelDia) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            HStack(alignment: .top, spacing: TokensEspaciado.e12) {
                iconoDelDia(fuerza: false)
                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                    Text(Textos.commonToday)
                        .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                    Text(tituloDeLaSesion(sesion))
                        .estilo(.tituloCardGrande)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detalle = detalleDeLaSesion(sesion) {
                        Text(detalle)
                            .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let minuto = sesion.minutoDelDia {
                    VStack(alignment: .trailing, spacing: TokensEspaciado.e2) {
                        Text(valorDeCuenta(minutosHasta(minuto)))
                            .estilo(.metricaMedia, color: Paleta.acento)
                        Text(Textos.commonToGoLowercase)
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let zona = sesion.zona {
                botonDeLaZona(zona)
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

            if sesion.minutoDelDia != nil {
                BotonPrimario(Textos.homePrepareWorkout) {
                    Haptico.toque()
                    estado.ir(a: .entreno)
                }
            }
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    private func tituloDeLaSesion(_ sesion: SesionDelDia) -> String {
        guard let metros = sesion.distanciaMetros else { return sesion.tipo }
        return "\(sesion.tipo) · \(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))"
    }

    /// "Sugerido 7:30". La zona va aparte, en su píldora tocable.
    private func detalleDeLaSesion(_ sesion: SesionDelDia) -> String? {
        guard let minuto = sesion.minutoDelDia else { return nil }
        return Textos.homeSuggested(Formato.hora(minutoDelDia: minuto))
    }

    /// "Z2 · moderada  ¿Qué es?": la jerga, con la explicación a un toque.
    private func botonDeLaZona(_ zona: ZonaDeIntensidad) -> some View {
        Button {
            Haptico.toque()
            explicacion = .zonas(actual: zona)
        } label: {
            HStack(spacing: TokensEspaciado.e6) {
                PildoraDeEstado("\(zona.corta) · \(InicioTextos.intensidad(zona))", simbolo: "speedometer", tono: .acento)
                Text(Textos.homeWhatIsIt)
                    .estilo(.chip, color: Paleta.textoAcento)
                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                    .foregroundStyle(Paleta.textoAcento)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: TokensTamano.objetivoTactilMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Textos.homeZonesHint)
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

    /// Las píldoras de abajo de la tarjeta de hoy: lo que hay que llevar. Todo el
    /// grupo es un botón que abre la hoja que explica cada número.
    private func chipsDelAvituallamiento(_ a: AvituallamientoDeSesion, duracionMinutos: Int) -> some View {
        Button {
            Haptico.toque()
            explicacion = .avituallamiento(a, duracionMinutos: duracionMinutos)
        } label: {
            FlujoHorizontal(espaciado: TokensEspaciado.e6) {
                PildoraDeEstado(Textos.homeHydrationRate(a.mililitrosPorHora),
                                simbolo: "drop.fill", tono: .acento)
                if a.geles > 0 {
                    PildoraDeEstado(Textos.homeGelCount(a.geles),
                                    simbolo: "bolt.fill")
                }
                PildoraDeEstado("\(a.carbohidratosPorHoraG) g/h", simbolo: "leaf.fill")
                HStack(spacing: TokensEspaciado.e4) {
                    Text(Textos.homeWhatToBring)
                        .estilo(.chip, color: Paleta.textoAcento)
                    Image(systemName: "chevron.right")
                        .font(.system(size: TokensTipografia.chipTamano, weight: .bold))
                        .foregroundStyle(Paleta.textoAcento)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, TokensEspaciado.e6)
            }
            .frame(maxWidth: .infinity, minHeight: TokensTamano.objetivoTactilMinimo, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Textos.homeWhatToBringHint)
    }

    /// "1:36" o "42 min": cuánto falta para la hora sugerida.
    private func valorDeCuenta(_ minutos: Int) -> String {
        let horas = minutos / 60
        let resto = minutos % 60
        guard horas > 0 else { return "\(resto) min" }
        return resto < 10 ? "\(horas):0\(resto) h" : "\(horas):\(resto) h"
    }

    /// La cuenta se hace contra la hora real del sistema.
    private func minutosHasta(_ minuto: Int) -> Int {
        let ahora = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutoActual = (ahora.hour ?? 0) * 60 + (ahora.minute ?? 0)
        let falta = minuto - minutoActual
        return falta >= 0 ? falta : falta + 24 * 60
    }

    // MARK: - Entrenamientos de hoy

    private var seccionEntrenamientosDeHoy: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(
                Textos.homeTodayWorkouts,
                accion: Textos.homeViewHistory,
                alTocar: {
                    Haptico.toque()
                    estado.ir(a: .historial)
                })

            ForEach(estado.actividadesDeHoy) { actividad in
                Button {
                    Haptico.toque()
                    actividadElegida = actividad
                } label: {
                    InicioFilaDeActividad(actividad: actividad, unidades: estado.sistemaDeUnidades)
                }
                .buttonStyle(EstiloPresionado())
            }
        }
    }
}

// MARK: - Fila de una actividad de hoy

/// "Running · 7:42 / 5,02 km · 26:10 · 5'12'' /km".
private struct InicioFilaDeActividad: View {
    let actividad: Actividad
    let unidades: SistemaDeUnidades

    var body: some View {
        HStack(spacing: TokensEspaciado.e12) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                IconoDeporte(deporte: actividad.sport, color: Paleta.acento, tamano: TokensEspaciado.e16)
            }
            .frame(width: TokensEspaciado.e44, height: TokensEspaciado.e44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                HStack(spacing: TokensEspaciado.e6) {
                    Text(actividad.sport.nombreVisible)
                        .estilo(.cuerpoDestacado)
                    Text(verbatim: "·").estilo(.labelCampo, color: Paleta.textoTerciario)
                    Text(hora)
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                }

                HStack(spacing: TokensEspaciado.e6) {
                    Text(Formato.distancia(Int(actividad.distanceM ?? 0), unidades: unidades, decimales: 2))
                        .estilo(.tituloCard, color: Paleta.acento)
                        .monospacedDigit()
                    Text(verbatim: "·").estilo(.labelCampo, color: Paleta.textoTerciario)
                    Text(Formato.cronometro(segundos: Int(actividad.durationS)))
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                        .monospacedDigit()
                    if let ritmo = ritmoOVelocidad {
                        Text(verbatim: "·").estilo(.labelCampo, color: Paleta.textoTerciario)
                        Text(ritmo)
                            .estilo(.labelCampo, color: Paleta.textoSecundario)
                            .monospacedDigit()
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                .foregroundStyle(Paleta.textoTerciario)
                .accessibilityHidden(true)
        }
        .padding(TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
        .contentShape(Rectangle())
    }

    private var hora: String {
        Date(timeIntervalSince1970: Double(actividad.startedAtMs) / 1000)
            .formatted(date: .omitted, time: .shortened)
    }

    /// Velocidad en bici, ritmo en lo demás. Con menos de 100 m no se calcula.
    private var ritmoOVelocidad: String? {
        guard let dist = actividad.distanceM, dist >= 100, actividad.durationS > 0 else { return nil }
        if actividad.sport == .ciclismo {
            return Formato.velocidad(metros: Int(dist), segundos: Int(actividad.durationS),
                                     unidades: unidades, decimales: 1)
        }
        let segsKm = Int((Double(actividad.durationS) * 1000 / Double(dist)).rounded())
        return Formato.ritmo(segundosPorKm: segsKm, unidades: unidades) + (unidades == .imperial ? " /mi" : " /km")
    }
}

private extension String {
    /// "viernes 16 de octubre" → "Viernes 16 de octubre": sólo la primera letra,
    /// `capitalized` subiría también "De" y "Octubre".
    var capitalizedPrimeraLetra: String {
        guard let primera = first else { return self }
        return primera.uppercased() + String(dropFirst())
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
