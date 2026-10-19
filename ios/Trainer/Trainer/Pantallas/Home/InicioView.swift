import SwiftUI
import TrainerCore

/// `inicio` — la pantalla 2 del mockup del MVP, de arriba hacia abajo:
///
///   Stamina · racha · avatar
///   "Viernes 16 de octubre" / "Buen día, Sofi"
///   la píldora del apto físico
///   la tarjeta de la próxima carrera ("23 días para tu media maratón"), o
///   "Ingresá tu nuevo objetivo" si no hay ninguna — siempre hay un objetivo a la vista
///   HOY: la sesión del día y su avituallamiento
///   entrenamientos de hoy, tu día y la carga de la semana
///
/// Las piezas chicas (agenda, gráfico de carga, racha) viven en `InicioPiezas.swift`.
/// El calendario anual se mudó a la pestaña Historial.
struct InicioView: View {
    @EnvironmentObject private var estado: EstadoHome
    @State private var actividadElegida: Actividad?
    @State private var mostrarApto = false

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

                if let plan = estado.plan {
                    if let sesion = estado.sesion {
                        tarjetaDeHoy(sesion)
                        if let avituallamiento = sesion.avituallamiento {
                            chipsDelAvituallamiento(avituallamiento)
                        }
                    } else {
                        tarjetaDeHoySinSalida(plan.hoy)
                    }
                }

                if !estado.actividadesDeHoy.isEmpty {
                    seccionEntrenamientosDeHoy
                }

                if let plan = estado.plan {
                    if !estado.agenda.isEmpty {
                        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
                            EncabezadoDeSeccion(Textos.inicioTuDia)
                            ForEach(estado.agenda) { fila in
                                FilaDeAgendaView(fila: fila)
                            }
                        }
                    }
                    tarjetaCargaSemanal(plan)
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
        .sheet(item: $actividadElegida) { actividad in
            DetalleDeActividadView(
                actividad: actividad,
                puntosIniciales: estado.recorridosLocales[actividad.id] ?? AlmacenDeRecorridos.compartido.puntos(para: actividad.id),
                servicio: estado.repositorio.servicioDeActividades()
            )
        }
        .sheet(isPresented: $mostrarApto) {
            AptoFisicoView()
        }
    }

    // MARK: - Barra superior: Stamina · racha · avatar

    private var barraSuperior: some View {
        HStack(spacing: TokensEspaciado.e10) {
            Text(MarcaApp.nombre)
                .estilo(.marca, color: Paleta.acento)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let plan = estado.plan {
                InsigniaDeRacha(racha: plan.racha)
            }
            Button { estado.ir(a: .perfil) } label: {
                ZStack {
                    Circle().fill(Paleta.superficieAlterna)
                    Circle().strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
                    if estado.iniciales.isEmpty {
                        Image(systemName: "person.fill")
                            .font(.system(size: TokensTipografia.tituloCardTamano, weight: .bold))
                            .foregroundStyle(Paleta.textoPrimario)
                    } else {
                        Text(estado.iniciales).estilo(.chip, color: Paleta.textoPrimario)
                    }
                }
                .frame(width: TokensEspaciado.e36, height: TokensEspaciado.e36)
                .frame(width: TokensTamano.objetivoTactilMinimo, height: TokensTamano.objetivoTactilMinimo)
                .contentShape(Circle())
            }
            .buttonStyle(EstiloPresionado())
            .accessibilityLabel(Textos.homeTabPerfil)
        }
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

    // MARK: - Píldoras: el apto y la salida en curso

    private var pildoras: some View {
        FlujoHorizontal(espaciado: TokensEspaciado.e6) {
            PildoraDelApto { mostrarApto = true }
            if estado.haySesionEnCurso {
                Button { estado.ir(a: .entreno) } label: {
                    PildoraDeEstado(String(localized: "Salida en curso", comment: "Píldora del inicio mientras se corre"),
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
    @ViewBuilder
    private var tarjetaDelObjetivo: some View {
        if let bloque = estado.bloque, !estado.planVencido {
            tarjetaDeLaCarrera(bloque)
        } else if !(estado.actualizando && estado.plan == nil),
                  estado.contenido.plan.problema == nil || estado.contenido.plan.problema == .perfilIncompleto {
            tarjetaNuevoObjetivo
        }
    }

    private func tarjetaDeLaCarrera(_ bloque: BloqueDelPlan) -> some View {
        Button { estado.ir(a: .plan) } label: {
            TarjetaHeroe(imagen: "BienvenidaRuta", alto: TokensEspaciado.e56 * 4) {
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
                                                ? String(localized: "día", comment: "Unidad de la cuenta regresiva")
                                                : String(localized: "días", comment: "Unidad de la cuenta regresiva"),
                                             etiquetaAccesible: String(localized: "Faltan", comment: "VoiceOver"))
                            } else {
                                MetricaHeroe("\(bloque.semanasQueFaltan)",
                                             unidad: String(localized: "semanas", comment: "Unidad de la cuenta regresiva"),
                                             etiquetaAccesible: String(localized: "Faltan", comment: "VoiceOver"))
                            }
                            Text(String(localized: "para tu \(bloque.evento.lowercased())",
                                        comment: "Debajo de la cuenta regresiva: para tu media maratón"))
                                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: TokensEspaciado.e4) {
                            Text(Textos.inicioVerPlan).estilo(.chip, color: Paleta.textoPrimario)
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
        .accessibilityHint(Textos.inicioVerPlan)
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
    private var tarjetaNuevoObjetivo: some View {
        TarjetaHeroe(imagen: "BienvenidaAmanecer", alto: TokensEspaciado.e56 * 4) {
            VStack(alignment: .leading, spacing: TokensEspaciado.e12) {
                PildoraDeEstado(String(localized: "Sin objetivo activo", comment: "Píldora del inicio sin plan"),
                                simbolo: "flag", tono: .neutro)
                Spacer(minLength: TokensEspaciado.e20)
                Text(String(localized: "Ingresá tu nuevo objetivo", comment: "Título de la tarjeta sin objetivo"))
                    .estilo(.display)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "Elegí tu próxima carrera y armamos el plan semana a semana.",
                            comment: "Explicación de la tarjeta sin objetivo"))
                    .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                BotonPrimario(String(localized: "Elegir objetivo", comment: "Botón de la tarjeta sin objetivo")) {
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
                    Text(String(localized: "Hoy", comment: "Etiqueta de la tarjeta del día en el inicio"))
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
                        Text(String(localized: "faltan", comment: "Debajo de la cuenta regresiva de la salida"))
                            .estilo(.notaLegal, color: Paleta.textoTerciario)
                    }
                    .accessibilityElement(children: .combine)
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

            if sesion.minutoDelDia != nil {
                BotonPrimario(Textos.inicioPrepararSalida) { estado.ir(a: .entreno) }
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

    /// "Sugerido 7:30 · ritmo moderado".
    private func detalleDeLaSesion(_ sesion: SesionDelDia) -> String? {
        var partes: [String] = []
        if let minuto = sesion.minutoDelDia {
            partes.append(String(localized: "Sugerido \(Formato.hora(minutoDelDia: minuto))",
                                 comment: "Hora sugerida de la salida"))
        }
        if let zona = sesion.zona {
            partes.append("\(zona.corta) · \(intensidad(zona))")
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
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

    /// Las píldoras de abajo de la tarjeta de hoy: lo que hay que llevar.
    private func chipsDelAvituallamiento(_ a: AvituallamientoDeSesion) -> some View {
        FlujoHorizontal(espaciado: TokensEspaciado.e6) {
            PildoraDeEstado(String(localized: "Hidratación \(a.mililitrosPorHora) ml/h", comment: "Píldora del inicio"),
                            simbolo: "drop.fill", tono: .acento)
            if a.geles > 0 {
                PildoraDeEstado(String(localized: "\(a.geles) gel", comment: "Píldora del inicio"),
                                simbolo: "bolt.fill")
            }
            PildoraDeEstado("\(a.carbohidratosPorHoraG) g/h", simbolo: "leaf.fill")
        }
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
                alTocar: { estado.ir(a: .historial) })

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
