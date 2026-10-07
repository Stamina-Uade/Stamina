import SwiftUI
import TrainerCore

/// `inicio` — la cuenta regresiva de "Ahora mismo", la agenda del día y la carga
/// de la semana.
///
/// Es la pantalla que se abre todos los días, así que lo primero que se ve es lo
/// único que importa a esa hora: cuánto falta para entrenar.
struct InicioView: View {
    @EnvironmentObject private var estado: EstadoHome
    @State private var actividadElegida: Actividad?
    @State private var mostrarHistorialCompleto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TokensEspaciado.e13) {
                if let plan = estado.plan {
                    AvisoDeLoGuardado(seccion: estado.contenido.plan)

                    HStack(alignment: .center) {
                        Text(encabezado(plan))
                            .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
                        Spacer()
                        InsigniaDeRacha(racha: plan.racha)
                    }

                    if let sesion = estado.sesion, let minuto = sesion.minutoDelDia {
                        tarjetaAhoraMismo(sesion, minuto: minuto)
                    } else {
                        tarjetaDeHoy(plan.hoy)
                    }

                    if !estado.actividadesDeHoy.isEmpty {
                        seccionEntrenamientosDeHoy
                    }

                    if !estado.agenda.isEmpty {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e9) {
                            TituloDeSeccion(Textos.inicioTuDia)
                            ForEach(estado.agenda) { fila in
                                FilaDeAgendaView(fila: fila)
                            }
                        }
                    }

                    tarjetaCargaSemanal(plan)
                } else {
                    if !estado.actividadesDeHoy.isEmpty {
                        seccionEntrenamientosDeHoy
                    }
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

    /// "Jue 10 sep · semana 1/11": la fecha de HOY, en el idioma de la app.
    private func encabezado(_ plan: PlanDelHome) -> String {
        let idioma = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "es")
        let fecha = Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(idioma))
        guard let semana = plan.semanaDeHoy else { return fecha }
        return Textos.inicioFecha(fecha, semana, plan.bloque.totalDeSemanas)
    }

    // MARK: - "Ahora mismo"

    /// La única tarjeta del producto con el acento de fondo: es la acción del día.
    private func tarjetaAhoraMismo(_ sesion: SesionDelDia, minuto: Int) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
            Text(Textos.inicioAhoraMismo)
                .estilo(.etiquetaSeccion, color: Paleta.sobreAcento)
                .opacity(0.65)

            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                Text(Formato.duracionLarga(minutos: minutosHasta(minuto)))
                    .estilo(.numeroGrande, color: Paleta.sobreAcento)
                if let metros = sesion.distanciaMetros {
                    Text(Textos.inicioCuentaRegresiva(
                        sesion.tipo.lowercased(),
                        Formato.distancia(metros, unidades: estado.sistemaDeUnidades),
                        Formato.hora(minutoDelDia: minuto)))
                        .estilo(.tituloCard, color: Paleta.sobreAcento)
                        .opacity(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(sesion.tipo) · \(Formato.hora(minutoDelDia: minuto))")
                        .estilo(.tituloCard, color: Paleta.sobreAcento)
                        .opacity(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: TokensEspaciado.e8) {
                Button { estado.ir(a: .entreno) } label: {
                    Text(Textos.inicioPrepararSalida)
                        .estilo(.tituloCard, color: Paleta.textoPrimario)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                        .background(Paleta.fondo)
                        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())

                Button { estado.ir(a: .plan) } label: {
                    Text(Textos.inicioVerPlan)
                        .estilo(.tituloCard, color: Paleta.sobreAcento)
                        .padding(.horizontal, TokensEspaciado.e14)
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                        .overlay(
                            RoundedRectangle(cornerRadius: TokensRadio.input, style: .continuous)
                                .strokeBorder(Paleta.sobreAcento.opacity(0.25), lineWidth: TokensEspaciado.e1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
            }
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.acento)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.cardDestacada, style: .continuous))
    }

    /// 8:24 es la hora que fija el diseño para la maqueta. La cuenta se hace
    /// contra la hora real del sistema, que es lo que va a pasar en producción.
    private func minutosHasta(_ minuto: Int) -> Int {
        let ahora = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutoActual = (ahora.hour ?? 8) * 60 + (ahora.minute ?? 24)
        let falta = minuto - minutoActual
        return falta >= 0 ? falta : falta + 24 * 60
    }

    /// Hoy no hay una salida con horario: un descanso, un día de fuerza o un día que
    /// no está en el bloque. Se dice lo que dice el plan, con sus palabras.
    private func tarjetaDeHoy(_ hoy: DiaDeHoy?) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
            Text(Textos.inicioAhoraMismo)
                .estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
            Text(hoy?.titulo ?? Textos.inicioSinPlanHoy)
                .estilo(.tituloCardGrande)
            if let detalle = hoy?.detalle, !detalle.isEmpty {
                Text(detalle)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hoy?.esFuerza == true {
                BotonTexto(Textos.inicioVerRutina) { estado.ir(a: .gimnasio) }
            }
        }
        .padding(TokensEspaciado.e16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    // MARK: - Carga semanal

    private func tarjetaCargaSemanal(_ plan: PlanDelHome) -> some View {
        Button { estado.ir(a: .plan) } label: {
            HStack(alignment: .bottom, spacing: TokensEspaciado.e10) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e8) {
                    Text(Textos.inicioCargaSemanal)
                        .estilo(.labelCampo, color: Paleta.textoTerciario)
                    GraficoDeCarga(metrosPorDia: plan.cargaSemanal,
                                   diaDestacado: plan.indiceDeHoy ?? -1)
                        .frame(height: TokensEspaciado.e36)
                }
                if let semana = plan.bloque.semanas.first(where: { $0.numero == plan.semanaDeHoy }) {
                    VStack(alignment: .trailing, spacing: TokensEspaciado.e2) {
                        Text(Formato.distancia(semana.metrosHechos, unidades: estado.sistemaDeUnidades, decimales: 0))
                            .estilo(.tituloCardGrande)
                        Text(Textos.inicioDePrevistos(
                            Formato.distancia(semana.metrosPrevistos, unidades: estado.sistemaDeUnidades, decimales: 0)))
                            .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                    }
                }
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .padding(.vertical, TokensEspaciado.e13)
            .frame(maxWidth: .infinity)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                    .strokeBorder(Paleta.divisor, lineWidth: TokensEspaciado.e1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
    }

    // MARK: - Entrenamientos de hoy

    private var seccionEntrenamientosDeHoy: some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e9) {
            HStack {
                TituloDeSeccion("ENTRENAMIENTOS DE HOY")
                Spacer()
                Button {
                    mostrarHistorialCompleto = true
                } label: {
                    Text("Ver historial")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Paleta.acento)
                }
            }

            ForEach(estado.actividadesDeHoy) { actividad in
                Button {
                    actividadElegida = actividad
                } label: {
                    HStack(spacing: TokensEspaciado.e12) {
                        ZStack {
                            Circle()
                                .fill(Paleta.acento.opacity(0.18))
                                .frame(width: 42, height: 42)
                            IconoDeporte(deporte: actividad.sport, color: Paleta.acento, tamano: 18)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(nombreDeporte(actividad.sport))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Paleta.textoPrimario)
                                Text("·")
                                    .foregroundStyle(Paleta.textoTerciario)
                                Text(horaActividad(actividad.startedAtMs))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Paleta.textoSecundario)
                            }

                            HStack(spacing: 8) {
                                Text(Formato.distancia(Int(actividad.distanceM ?? 0), unidades: estado.sistemaDeUnidades, decimales: 2))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Paleta.acento)
                                Text("·")
                                    .foregroundStyle(Paleta.textoTerciario)
                                Text(Formato.cronometro(segundos: Int(actividad.durationS)))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Paleta.textoSecundario)

                                if let dist = actividad.distanceM, dist >= 100, actividad.durationS > 0 {
                                    Text("·")
                                        .foregroundStyle(Paleta.textoTerciario)
                                    if actividad.sport == .ciclismo {
                                        Text(Formato.velocidad(metros: Int(dist), segundos: Int(actividad.durationS), unidades: estado.sistemaDeUnidades, decimales: 1))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Paleta.textoSecundario)
                                    } else {
                                        let segsKm = Int((Double(actividad.durationS) * 1000 / Double(dist)).rounded())
                                        Text(Formato.ritmo(segundosPorKm: segsKm, unidades: estado.sistemaDeUnidades) + (estado.sistemaDeUnidades == .imperial ? " /mi" : " /km"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Paleta.textoSecundario)
                                    }
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Paleta.textoTerciario)
                    }
                    .padding(TokensEspaciado.e12)
                    .background(Paleta.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                            .strokeBorder(Paleta.divisor, lineWidth: TokensEspaciado.e1)
                    )
                }
                .buttonStyle(EstiloPresionado())
            }
        }
    }

    private func horaActividad(_ ms: Int64) -> String {
        Date(timeIntervalSince1970: Double(ms) / 1000)
            .formatted(date: .omitted, time: .shortened)
    }

    private func iconoDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return "figure.run"
        case .ciclismo: return "bicycle"
        case .trekking: return "figure.hiking"
        case .natacion: return "figure.pool.swim"
        case .fuerza: return "dumbbell.fill"
        case .otro, .triatlon: return "figure.mixed.cardio"
        }
    }

    private func nombreDeporte(_ deporte: DeporteDeSesion) -> String {
        switch deporte {
        case .running: return Textos.regDeporteRunning
        case .ciclismo: return Textos.regDeporteCiclismo
        case .trekking: return Textos.regDeporteTrekking
        case .triatlon: return Textos.regDeporteTriatlon
        default: return deporte.rawValue.capitalized
        }
    }
}

// MARK: - La fila de la agenda

struct FilaDeAgendaView: View {
    @EnvironmentObject private var estado: EstadoHome
    let fila: FilaDeAgenda

    var body: some View {
        HStack(alignment: .top, spacing: TokensEspaciado.e11) {
            Text(Formato.hora(minutoDelDia: fila.minutoDelDia))
                .estilo(.notaLegal, color: fila.clase == .sesion ? Paleta.acento : Paleta.textoTerciario)
                .monospacedDigit()
                .frame(width: TokensEspaciado.e44, alignment: .leading)
                .padding(.top, TokensEspaciado.e12)

            switch fila.clase {
            case .sesion:
                if let sesion = estado.sesion { tarjetaDeLaSesion(sesion) }
            case .simple, .gimnasio:
                tarjetaSimple
            }
        }
    }

    /// La única fila con chips y con "Editar": es la sesión del día.
    private func tarjetaDeLaSesion(_ sesion: SesionDelDia) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e9) {
            HStack(alignment: .firstTextBaseline, spacing: TokensEspaciado.e10) {
                Button { estado.ir(a: .entreno) } label: {
                    Text(titulo(de: sesion))
                        .estilo(.tituloCard)
                        .multilineTextAlignment(.leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                Spacer(minLength: 0)
            }

            // Sin el peso, el servidor no calcula el avituallamiento: no se inventa.
            if let avituallamiento = sesion.avituallamiento {
                FlujoDeChips(chips: chips(de: avituallamiento))

                if let zona = sesion.zona {
                    Text(Textos.inicioNotaHidratacion(
                        avituallamiento.mililitrosPorHora,
                        avituallamiento.carbohidratosPorHoraG,
                        zona.corta,
                        intensidad(zona)))
                        .estilo(.etiquetaSeccion.enMinusculas, color: Paleta.textoTerciario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, TokensEspaciado.e13)
        .padding(.vertical, TokensEspaciado.e12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie)
        .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
    }

    private var tarjetaSimple: some View {
        Button {
            if let destino = fila.destino { estado.ir(a: destino) }
        } label: {
            VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                Text(fila.titulo).estilo(.cuerpoSecundario)
                Text(fila.detalle)
                    .estilo(.notaLegal, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TokensEspaciado.e13)
            .padding(.vertical, TokensEspaciado.e11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.superficie)
            .clipShape(RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TokensRadio.boton, style: .continuous)
                    .strokeBorder(Paleta.divisor, lineWidth: TokensEspaciado.e1)
            )
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .disabled(fila.destino == nil)
        .accessibilityElement(children: .combine)
    }

    /// "Running suave (51 min) · 7,1 km · Z2", con lo que el plan traiga.
    private func titulo(de sesion: SesionDelDia) -> String {
        var partes = [sesion.tipo]
        if let metros = sesion.distanciaMetros {
            partes.append(Formato.distancia(metros, unidades: estado.sistemaDeUnidades))
        }
        if let zona = sesion.zona { partes.append(zona.corta) }
        return partes.joined(separator: " · ")
    }

    private func intensidad(_ zona: ZonaDeIntensidad) -> String {
        switch zona {
        case .z1: return Textos.zonaBaja
        case .z2: return Textos.zonaModerada
        case .z3: return Textos.zonaModeradaAlta
        case .z4: return Textos.zonaAlta
        case .z5: return Textos.zonaMaxima
        }
    }

    private func chips(de avituallamiento: AvituallamientoDeSesion) -> [(String, Bool)] {
        var chips: [(String, Bool)] = []
        if avituallamiento.geles > 0 {
            chips.append(("\(avituallamiento.geles) gel", true))
        }
        chips.append(("\(avituallamiento.mililitrosPorHora) ml/h", false))
        chips.append(("\(avituallamiento.carbohidratosPorHoraG) g/h", false))
        return chips
    }
}

/// Los chips de una fila, que se acomodan solos cuando no entran.
struct FlujoDeChips: View {
    let chips: [(String, Bool)]

    var body: some View {
        // `WrappingHStack` no existe en iOS 16; el layout de flujo se arma con
        // un `Layout` propio, que es la forma que no depende de la versión.
        FlujoHorizontal(espaciado: TokensEspaciado.e6) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                ChipInformativo(texto: chip.0, destacado: chip.1)
            }
        }
    }
}

/// El gráfico de barras de la carga semanal. Siete días, el de hoy en acento.
struct GraficoDeCarga: View {
    let metrosPorDia: [Int]
    let diaDestacado: Int

    var body: some View {
        let maximo = max(metrosPorDia.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: TokensEspaciado.e5) {
            ForEach(Array(metrosPorDia.enumerated()), id: \.offset) { indice, metros in
                RoundedRectangle(cornerRadius: TokensRadio.minimo, style: .continuous)
                    .fill(indice == diaDestacado ? Paleta.acento : Paleta.superficieControl)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(TokensEspaciado.e4,
                                       TokensEspaciado.e36 * CGFloat(metros) / CGFloat(maximo)))
            }
        }
        // Un gráfico decorativo no se lee dato por dato: el número está al lado.
        .accessibilityHidden(true)
    }
}

// MARK: - Fueguitos / Racha estilo Duolingo

struct InsigniaDeRacha: View {
    let racha: RachaHome
    @State private var mostrandoDetalle = false

    var body: some View {
        Button { mostrandoDetalle = true } label: {
            HStack(spacing: TokensEspaciado.e5) {
                Image(systemName: racha.dias > 0 && racha.activaHoy ? "flame.fill" : "flame")
                    .font(.system(size: TokensEspaciado.e16, weight: .bold))
                    .foregroundStyle(racha.dias > 0
                        ? (racha.activaHoy ? Color.orange : Paleta.textoSecundario)
                        : Paleta.textoTerciario)
                Text("\(racha.dias)")
                    .font(.system(size: TokensEspaciado.e14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(racha.dias > 0 ? Paleta.textoPrimario : Paleta.textoSecundario)
            }
            .padding(.horizontal, TokensEspaciado.e10)
            .padding(.vertical, TokensEspaciado.e5)
            .background(
                Capsule()
                    .fill(racha.dias > 0 && racha.activaHoy
                        ? Color.orange.opacity(0.16)
                        : Paleta.superficieOverlay)
            )
            .overlay(
                Capsule()
                    .strokeBorder(racha.dias > 0 && racha.activaHoy
                        ? Color.orange.opacity(0.4)
                        : Paleta.bordeInput, lineWidth: TokensEspaciado.e1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Textos.rachaTitulo): \(racha.dias) \(Textos.rachaDias)")
        .sheet(isPresented: $mostrandoDetalle) {
            DetalleDeRachaView(racha: racha)
        }
    }
}

struct DetalleDeRachaView: View {
    let racha: RachaHome
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        VStack(spacing: TokensEspaciado.e20) {
            Capsule()
                .fill(Paleta.divisor)
                .frame(width: TokensEspaciado.e36, height: TokensEspaciado.e4)
                .padding(.top, TokensEspaciado.e10)

            ZStack {
                Circle()
                    .fill(racha.dias > 0 && racha.activaHoy ? Color.orange.opacity(0.18) : Paleta.superficieOverlay)
                    .frame(width: TokensEspaciado.e44 * 2,
                           height: TokensEspaciado.e44 * 2)
                Image(systemName: racha.dias > 0 && racha.activaHoy ? "flame.fill" : "flame")
                    .font(.system(size: TokensEspaciado.e44, weight: .bold))
                    .foregroundStyle(racha.dias > 0 && racha.activaHoy ? Color.orange : Paleta.textoSecundario)
            }
            .padding(.top, TokensEspaciado.e12)

            VStack(spacing: TokensEspaciado.e4) {
                Text("\(racha.dias) \(Textos.rachaDias)")
                    .estilo(.numeroGrande)
                Text(Textos.rachaTitulo)
                    .estilo(.etiquetaSeccion, color: Paleta.acento)
            }

            VStack(spacing: TokensEspaciado.e10) {
                Text(mensajeDeEstado)
                    .estilo(.tituloCard)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Paleta.textoPrimario)
                    .padding(.horizontal, TokensEspaciado.e16)

                Text(Textos.rachaExplicacion)
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TokensEspaciado.e20)
            }

            Spacer()

            BotonPrimario(Textos.comunListo) {
                cerrar()
            }
            .padding(.horizontal, TokensEspaciado.e16)
            .padding(.bottom, TokensEspaciado.e20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.fondo)
    }

    private var mensajeDeEstado: String {
        if racha.dias > 0 {
            if racha.entrenadoHoy {
                return Textos.rachaDetalleActiva
            } else if !racha.tocaHoy {
                return Textos.rachaDetalleDescanso
            } else {
                return Textos.rachaDetallePendiente
            }
        } else {
            return Textos.rachaDetallePerdida
        }
    }
}
