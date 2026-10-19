import SwiftUI
import TrainerCore

/// `inicio` — la cuenta regresiva de "Ahora mismo", la agenda del día y la carga
/// de la semana.
///
/// Es la pantalla que se abre todos los días, así que lo primero que se ve es lo
/// único que importa a esa hora: cuánto falta para entrenar.
///
/// Las piezas chicas (agenda, gráfico de carga, racha) viven en `InicioPiezas.swift`.
struct InicioView: View {
    @EnvironmentObject private var estado: EstadoHome
    @State private var actividadElegida: Actividad?
    @State private var mostrarHistorialCompleto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e20) {
                if let plan = estado.plan {
                    AvisoDeLoGuardado(seccion: estado.contenido.plan)

                    encabezadoDePestana(plan)
                    pildoras(plan)

                    if let sesion = estado.sesion, let minuto = sesion.minutoDelDia {
                        tarjetaAhoraMismo(sesion, minuto: minuto)
                    } else {
                        if plan.bloque.semanasQueFaltan > 0 {
                            tarjetaCuentaRegresivaDeCarrera(plan.bloque)
                        }
                        tarjetaDeHoy(plan.hoy)
                    }

                    if !estado.actividadesDeHoy.isEmpty {
                        seccionEntrenamientosDeHoy
                    }

                    if !estado.agenda.isEmpty {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                            EncabezadoDeSeccion(Textos.inicioTuDia)
                            ForEach(estado.agenda) { fila in
                                FilaDeAgendaView(fila: fila)
                            }
                        }
                    }

                    tarjetaCargaSemanal(plan)

                    CalendarioDeHitosView()
                } else {
                    EncabezadoDePestana(saludo, sobretitulo: fechaDeHoy)

                    if !estado.actividadesDeHoy.isEmpty {
                        seccionEntrenamientosDeHoy
                    }

                    CalendarioDeHitosView()

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
        .sheet(item: $actividadElegida) { actividad in
            DetalleDeActividadView(
                actividad: actividad,
                puntosIniciales: estado.recorridosLocales[actividad.id] ?? AlmacenDeRecorridos.compartido.puntos(para: actividad.id),
                servicio: estado.repositorio.servicioDeActividades()
            )
        }
        .sheet(isPresented: $mostrarHistorialCompleto) {
            HistorialDeActividadesView(servicio: estado.repositorio.servicioDeActividades())
        }
    }

    // MARK: - Encabezado

    private func encabezadoDePestana(_ plan: PlanDelHome) -> some View {
        EncabezadoDePestana(saludo, sobretitulo: encabezado(plan)) {
            InsigniaDeRacha(racha: plan.racha)
        }
    }

    /// "Viernes 16 de octubre": la fecha de HOY, en el idioma de la app.
    private var fechaDeHoy: String {
        let idioma = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        return Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(idioma)).capitalizedPrimeraLetra
    }

    /// La fecha y, si hoy cae en el bloque, "semana 3/11".
    private func encabezado(_ plan: PlanDelHome) -> String {
        guard let semana = plan.semanaDeHoy else { return fechaDeHoy }
        return Textos.inicioFecha(fechaDeHoy, semana, plan.bloque.totalDeSemanas)
    }

    /// "Buen día, Sofi". Sin nombre cargado queda el saludo solo, nunca "Buen día, ".
    private var saludo: String {
        let hora = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hora {
        case 5..<13: base = String(localized: "Buen día", comment: "Saludo del inicio, a la mañana")
        case 13..<20: base = String(localized: "Buenas tardes", comment: "Saludo del inicio, a la tarde")
        default: base = String(localized: "Buenas noches", comment: "Saludo del inicio, a la noche")
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

    // MARK: - Píldoras

    /// Sólo estado que existe: salida en curso, semanas que faltan, zona de hoy.
    @ViewBuilder
    private func pildoras(_ plan: PlanDelHome) -> some View {
        let enCurso = estado.haySesionEnCurso
        // La cuenta de semanas ya es la tarjeta grande cuando no hay salida con hora.
        let mostrarSemanas = plan.bloque.semanasQueFaltan > 0 && estado.sesion?.minutoDelDia != nil
        let zona = estado.sesion?.zona
        if enCurso || mostrarSemanas || zona != nil {
            FlujoHorizontal(espaciado: TokensEspaciado.e6) {
                if enCurso {
                    PildoraDeEstado(String(localized: "Salida en curso", comment: "Píldora del inicio mientras se corre"),
                                    tono: .acento)
                }
                if mostrarSemanas {
                    PildoraDeEstado(Textos.planFaltanSemanas(plan.bloque.semanasQueFaltan),
                                    simbolo: "flag.checkered")
                }
                if let zona {
                    PildoraDeEstado(zona.corta, simbolo: "heart.fill")
                }
            }
        }
    }

    // MARK: - "Ahora mismo"

    /// La tarjeta héroe del día: cuánto falta para salir, con foto.
    private func tarjetaAhoraMismo(_ sesion: SesionDelDia, minuto: Int) -> some View {
        let falta = minutosHasta(minuto)
        return TarjetaHeroe(imagen: "BienvenidaRuta") {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                PildoraDeEstado(Textos.inicioAhoraMismo, simbolo: "bolt.fill", tono: .acento)

                VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                    MetricaHeroe(valorDeCuenta(falta), unidad: unidadDeCuenta(falta),
                                 etiquetaAccesible: Textos.inicioAhoraMismo)
                    Text(detalleDeLaSesion(sesion, minuto: minuto))
                        .estilo(.tituloCard, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: TokensEspaciado.e8) {
                    BotonPrimario(Textos.inicioPrepararSalida) { estado.ir(a: .entreno) }
                    BotonTonal(Textos.inicioVerPlan) { estado.ir(a: .plan) }
                        .frame(maxWidth: TokensEspaciado.e56 * 2)
                }
            }
        }
    }

    private func detalleDeLaSesion(_ sesion: SesionDelDia, minuto: Int) -> String {
        if let metros = sesion.distanciaMetros {
            return Textos.inicioCuentaRegresiva(
                sesion.tipo.lowercased(),
                Formato.distancia(metros, unidades: estado.sistemaDeUnidades),
                Formato.hora(minutoDelDia: minuto))
        }
        return "\(sesion.tipo) · \(Formato.hora(minutoDelDia: minuto))"
    }

    /// "1:36" con unidad "h", o "42" con "min": el número grande del mockup.
    private func valorDeCuenta(_ minutos: Int) -> String {
        let horas = minutos / 60
        let resto = minutos % 60
        guard horas > 0 else { return "\(resto)" }
        return resto < 10 ? "\(horas):0\(resto)" : "\(horas):\(resto)"
    }

    private func unidadDeCuenta(_ minutos: Int) -> String {
        minutos >= 60 ? "h" : "min"
    }

    /// 8:24 es la hora que fija el diseño para la maqueta. La cuenta se hace
    /// contra la hora real del sistema, que es lo que va a pasar en producción.
    private func minutosHasta(_ minuto: Int) -> Int {
        let ahora = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutoActual = (ahora.hour ?? 8) * 60 + (ahora.minute ?? 24)
        let falta = minuto - minutoActual
        return falta >= 0 ? falta : falta + 24 * 60
    }

    // MARK: - Cuenta regresiva de la carrera

    /// Sin salida con hora, la tarjeta grande es la carrera: "6 semanas · Media de BA".
    private func tarjetaCuentaRegresivaDeCarrera(_ bloque: BloqueDelPlan) -> some View {
        TarjetaHeroe(imagen: "BienvenidaAmanecer") {
            VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                if !bloque.cuando.isEmpty {
                    PildoraDeEstado(bloque.cuando, simbolo: "flag.checkered", tono: .acento)
                }
                HStack(alignment: .bottom, spacing: TokensEspaciado.e12) {
                    VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                        MetricaHeroe("\(bloque.semanasQueFaltan)",
                                     unidad: String(localized: "semanas", comment: "Unidad de la cuenta regresiva de la carrera"))
                        if !bloque.evento.isEmpty {
                            Text(bloque.evento)
                                .estilo(.tituloCard, color: Paleta.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    BotonTonal(Textos.inicioVerPlan) { estado.ir(a: .plan) }
                        .frame(maxWidth: TokensEspaciado.e56 * 2)
                }
            }
        }
    }

    // MARK: - Hoy

    /// Hoy no hay una salida con horario: un descanso, un día de fuerza o un día que
    /// no está en el bloque. Se dice lo que dice el plan, con sus palabras.
    private func tarjetaDeHoy(_ hoy: DiaDeHoy?) -> some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e12) {
            ZStack {
                Circle().fill(Paleta.acentoChipActivo)
                Image(systemName: hoy?.esFuerza == true ? "dumbbell.fill" : "figure.run")
                    .font(.system(size: TokensTipografia.tituloCardGrandeTamano, weight: .bold))
                    .foregroundStyle(Paleta.acento)
            }
            .frame(width: TokensEspaciado.e40, height: TokensEspaciado.e40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TokensEspaciado.e4) {
                Text(String(localized: "Hoy", comment: "Etiqueta de la tarjeta del día en el inicio"))
                    .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                Text(hoy?.titulo ?? Textos.inicioSinPlanHoy)
                    .estilo(.tituloCardGrande)
                    .fixedSize(horizontal: false, vertical: true)
                if let detalle = hoy?.detalle, !detalle.isEmpty {
                    Text(detalle)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if hoy?.esFuerza == true {
                    BotonTexto(Textos.inicioVerRutina) { estado.ir(a: .gimnasio) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    // MARK: - Carga semanal

    private func tarjetaCargaSemanal(_ plan: PlanDelHome) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(Textos.inicioCargaSemanal)
            Button { estado.ir(a: .plan) } label: {
                VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
                    if let semana = plan.bloque.semanas.first(where: { $0.numero == plan.semanaDeHoy }) {
                        HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e6) {
                            Text(Formato.distancia(semana.metrosHechos, unidades: estado.sistemaDeUnidades, decimales: 0))
                                .estilo(.metricaMedia)
                            Text(Textos.inicioDePrevistos(
                                Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades, decimales: 0)))
                                .estilo(.labelCampo, color: Paleta.textoTerciario)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: TokensTipografia.notaLegalTamano, weight: .semibold))
                                .foregroundStyle(Paleta.textoTerciario)
                                .accessibilityHidden(true)
                        }
                    }
                    GraficoDeCarga(metrosPorDia: plan.cargaSemanal,
                                   diaDestacado: plan.indiceDeHoy ?? -1)
                        .frame(height: TokensEspaciado.e56)
                }
                .padding(TokensEspaciado.e16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tarjeta()
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloPresionado())
        }
    }

    // MARK: - Entrenamientos de hoy

    private var seccionEntrenamientosDeHoy: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            EncabezadoDeSeccion(
                String(localized: "Entrenamientos de hoy", comment: "Título de sección del inicio"),
                accion: String(localized: "Ver historial", comment: "Abre el historial de actividades"),
                alTocar: { mostrarHistorialCompleto = true })

            ForEach(estado.actividadesDeHoy) { actividad in
                Button {
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
                    Text("·").estilo(.labelCampo, color: Paleta.textoTerciario)
                    Text(hora)
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                }

                HStack(spacing: TokensEspaciado.e6) {
                    Text(Formato.distancia(Int(actividad.distanceM ?? 0), unidades: unidades, decimales: 2))
                        .estilo(.tituloCard, color: Paleta.acento)
                        .monospacedDigit()
                    Text("·").estilo(.labelCampo, color: Paleta.textoTerciario)
                    Text(Formato.cronometro(segundos: Int(actividad.durationS)))
                        .estilo(.labelCampo, color: Paleta.textoSecundario)
                        .monospacedDigit()
                    if let ritmo = ritmoOVelocidad {
                        Text("·").estilo(.labelCampo, color: Paleta.textoTerciario)
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
