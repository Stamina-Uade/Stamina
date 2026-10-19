import SwiftUI
import TrainerCore

/// Las cinco pantallas de catálogo de `design/nuevo/gimnasio.dc.html`:
/// `catalogo`, `catalogo-filtros`, `catalogo-vacio`, `ficha` y `sustitutos`.
///
/// 🛑 **Nada acá enumera el catálogo.** `ESPECIFICACION.md` §6.4: "50 o 500
/// entradas se ven igual, y un ejercicio nuevo aparece sin desplegar". Por eso
/// no hay ninguna lista completa ni ningún contador del total; sólo búsqueda,
/// filtros y resultados.
struct CatalogoDeEjerciciosView: View {
    @EnvironmentObject var estado: EstadoHome
    @Environment(\.dismiss) private var cerrar
    @StateObject private var catalogo = CatalogoDeEjercicios.compartido

    @State private var busqueda = ""
    @State private var musculos: Set<String> = []
    @State private var equipos: Set<String> = []
    @State private var sinEquipo = false
    @State private var mostrandoFiltros = false
    @State private var fichaAbierta: EjercicioDelCatalogo?

    private var resultados: [EjercicioDelCatalogo] {
        catalogo.buscar(busqueda, musculos: musculos, equipamiento: equipos, sinEquipo: sinEquipo)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: TokensEspaciado.e12) {
                barraDeBusqueda

                if catalogo.cargando {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if catalogo.falloDeRed {
                    VStack(spacing: TokensEspaciado.e12) {
                        Text(Textos.homeDatosSinRed)
                            .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        BotonPrimario(Textos.homeDatosReintentar) {
                            Task { await catalogo.cargar(desde: estado.repositorio.servicioDelCatalogo()) }
                        }
                    }
                    .padding(.horizontal, TokensEspaciado.e16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if resultados.isEmpty {
                    estadoVacio
                } else {
                    ScrollView {
                        VStack(spacing: TokensEspaciado.e8) {
                            ForEach(resultados) { ejercicio in
                                filaDeResultado(ejercicio)
                            }
                        }
                        .padding(.horizontal, TokensEspaciado.e16)
                        .padding(.bottom, TokensEspaciado.e26)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paleta.fondo)
            .navigationTitle(Textos.catalogoTitulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.comunCancelar) { cerrar() }
                }
            }
        }
        .task { await catalogo.cargar(desde: estado.repositorio.servicioDelCatalogo()) }
        .sheet(isPresented: $mostrandoFiltros) {
            HojaDeFiltros(catalogo: catalogo, musculos: $musculos, equipos: $equipos,
                          sinEquipo: $sinEquipo, cantidadDeResultados: resultados.count)
        }
        .sheet(item: $fichaAbierta) { ejercicio in
            FichaDeEjercicioView(ejercicio: ejercicio, catalogo: catalogo) { elegido in
                fichaAbierta = nil
                cerrar()
                _ = elegido
            }
        }
    }

    // MARK: - Buscar y filtrar

    private var barraDeBusqueda: some View {
        VStack(spacing: TokensEspaciado.e10) {
            HStack(spacing: TokensEspaciado.e10) {
                HStack(spacing: TokensEspaciado.e9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Paleta.textoTerciario)
                    TextField("", text: $busqueda,
                              prompt: Text(Textos.catalogoBuscar).foregroundColor(Paleta.textoPlaceholder))
                        .estilo(.campoTexto)
                }
                .padding(.horizontal, TokensEspaciado.e14)
                // 56 pt: el campo del diseño no declaraba altura y era el único
                // accionable que no llegaba al mínimo (ESPECIFICACION §6.5).
                .frame(height: TokensEspaciado.e56)
                .background(Paleta.superficieInput)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Paleta.bordeInput, lineWidth: TokensEspaciado.e1))

                Button { mostrandoFiltros = true } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(hayFiltros ? Paleta.acento : Paleta.textoSecundario)
                        .frame(width: TokensEspaciado.e56, height: TokensEspaciado.e56)
                        .background(hayFiltros ? Paleta.acentoChipActivo : Paleta.superficieInput)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(hayFiltros ? Paleta.acentoSuaveBorde : Paleta.bordeInput,
                                                       lineWidth: TokensEspaciado.e1))
                        .contentShape(Circle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityLabel(Textos.catalogoFiltros)
            }

            // El atajo "Sin equipo" lleva tilde además de color: a un centímetro
            // hay chips que sí la llevan (ESPECIFICACION §6.5).
            HStack {
                Button { sinEquipo.toggle() } label: {
                    HStack(spacing: TokensEspaciado.e6) {
                        Image(systemName: sinEquipo ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: TokensTipografia.labelCampoTamano))
                        Text(Textos.catalogoSinEquipo)
                            .estilo(.tituloCard, color: sinEquipo ? Paleta.acento : Paleta.textoSecundario)
                    }
                    .foregroundStyle(sinEquipo ? Paleta.acento : Paleta.textoSecundario)
                    .padding(.horizontal, TokensEspaciado.e12)
                    .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                    .background(sinEquipo ? Paleta.acentoChipActivo : Paleta.superficie)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(sinEquipo ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                                                    lineWidth: TokensEspaciado.e1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPresionado())
                .accessibilityAddTraits(sinEquipo ? [.isButton, .isSelected] : .isButton)
                Spacer()
            }
        }
        .padding(.horizontal, TokensEspaciado.e16)
    }

    private var hayFiltros: Bool { !musculos.isEmpty || !equipos.isEmpty }

    private func filaDeResultado(_ ejercicio: EjercicioDelCatalogo) -> some View {
        Button { fichaAbierta = ejercicio } label: {
            HStack(spacing: TokensEspaciado.e12) {
                VStack(alignment: .leading, spacing: TokensEspaciado.e2) {
                    Text(catalogo.nombre(de: ejercicio)).estilo(.opcionTitulo)
                    Text(descripcionCorta(ejercicio))
                        .estilo(.notaLegal, color: Paleta.textoTerciario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: TokensTipografia.etiquetaSeccionTamano,
                                  weight: TokensTipografia.tituloCardPeso))
                    .foregroundStyle(Paleta.textoTerciario)
            }
            .padding(.horizontal, TokensEspaciado.e14)
            .padding(.vertical, TokensEspaciado.e13)
            .frame(maxWidth: .infinity)
            .tarjeta(radio: TokensRadio.boton)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityElement(children: .combine)
    }

    private func descripcionCorta(_ ejercicio: EjercicioDelCatalogo) -> String {
        let principal = ejercicio.musculos.first(where: \.esPrincipal).map { catalogo.musculo($0.id) }
        return [principal, catalogo.equipamiento(ejercicio.equipamiento)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    // MARK: - `catalogo-vacio`: tres salidas, no un callejón

    private var estadoVacio: some View {
        VStack(spacing: TokensEspaciado.e16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: TokensTipografia.numeroDatoTamano))
                .foregroundStyle(Paleta.textoTerciario)
            Text(Textos.catalogoVacioTitulo)
                .estilo(.tituloCardGrande)
                .multilineTextAlignment(.center)
            Text(Textos.catalogoVacioTexto)
                .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: TokensEspaciado.e8) {
                BotonPrimario(Textos.catalogoVacioAmpliar) {
                    musculos = []; equipos = []; sinEquipo = false; busqueda = ""
                }
                BotonTexto(Textos.catalogoVacioLibre) { cerrar() }
                BotonTexto(Textos.catalogoVacioSugerir, color: Paleta.textoSecundario) {}
            }
            Spacer()
        }
        .padding(.horizontal, TokensEspaciado.e26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - `catalogo-filtros`

struct HojaDeFiltros: View {
    let catalogo: CatalogoDeEjercicios
    @Binding var musculos: Set<String>
    @Binding var equipos: Set<String>
    @Binding var sinEquipo: Bool
    let cantidadDeResultados: Int

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                    grupo(Textos.catalogoMusculo, claves: catalogo.musculosDisponibles,
                          nombre: catalogo.musculo, seleccion: $musculos)
                    grupo(Textos.catalogoEquipamiento, claves: catalogo.equipamientosDisponibles,
                          nombre: catalogo.equipamiento, seleccion: $equipos)
                }
                .padding(TokensEspaciado.e16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paleta.fondo)
            .navigationTitle(Textos.catalogoFiltros)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: TokensEspaciado.e8) {
                    // El botón dice cuántos quedan: es la información que hace
                    // falta antes de cerrar la hoja, no después.
                    BotonPrimario(Textos.catalogoVer(cantidadDeResultados)) { cerrar() }
                    BotonTexto(Textos.catalogoLimpiar, color: Paleta.textoSecundario) {
                        musculos = []; equipos = []; sinEquipo = false
                    }
                }
                .padding(.horizontal, TokensEspaciado.e16)
                .padding(.bottom, TokensEspaciado.e20)
                .background(Paleta.fondo)
            }
        }
    }

    private func grupo(_ titulo: String, claves: [String],
                       nombre: @escaping (String) -> String,
                       seleccion: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e10) {
            TituloDeSeccion(titulo)
            FlujoHorizontal(espaciado: TokensEspaciado.e6) {
                ForEach(claves, id: \.self) { clave in
                    let elegido = seleccion.wrappedValue.contains(clave)
                    Button {
                        if elegido { seleccion.wrappedValue.remove(clave) }
                        else { seleccion.wrappedValue.insert(clave) }
                    } label: {
                        HStack(spacing: TokensEspaciado.e5) {
                            if elegido {
                                Image(systemName: "checkmark")
                                    .font(.system(size: TokensTipografia.etiquetaSeccionTamano,
                                                  weight: TokensTipografia.tituloCardPeso))
                            }
                            Text(nombre(clave))
                                .estilo(.chip, color: elegido ? Paleta.acento : Paleta.textoSecundario)
                        }
                        .foregroundStyle(elegido ? Paleta.acento : Paleta.textoSecundario)
                        .padding(.horizontal, TokensEspaciado.e12)
                        .frame(minHeight: TokensTamano.objetivoTactilMinimo)
                        .background(elegido ? Paleta.acentoChipActivo : Paleta.superficie)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(elegido ? Paleta.acentoSuaveBorde : Paleta.bordeSuperficie,
                                                        lineWidth: TokensEspaciado.e1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloPresionado())
                    .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}

// MARK: - `ficha` y `sustitutos`

struct FichaDeEjercicioView: View {
    let ejercicio: EjercicioDelCatalogo
    let catalogo: CatalogoDeEjercicios
    let alElegir: (EjercicioDelCatalogo) -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var mostrandoSustitutos = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e14) {
                    // El nombre grande arriba, como los títulos del rediseño: la
                    // barra de navegación lo lleva chico y se corta.
                    Text(catalogo.nombre(de: ejercicio))
                        .estilo(.display)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    dato(Textos.fichaMusculoPrincipal, principales)
                    if !secundarios.isEmpty {
                        dato(Textos.fichaMusculoSecundario, secundarios)
                    }
                    dato(Textos.catalogoEquipamiento, catalogo.equipamiento(ejercicio.equipamiento))
                    // El patrón se muestra traducido, no como slug: mostrar
                    // `empuje-horizontal` crudo fue uno de los ocho defectos que
                    // ESPECIFICACION §6.5 corrigió.
                    dato(Textos.fichaPatron, catalogo.patron(ejercicio.patron))

                    BotonPrimario(Textos.fichaUsar) { alElegir(ejercicio) }
                    if !ejercicio.sustitutos.isEmpty {
                        BotonTexto(Textos.fichaSustitutos) { mostrandoSustitutos = true }
                    }
                }
                .padding(TokensEspaciado.e16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paleta.fondo)
            .navigationTitle(catalogo.nombre(de: ejercicio))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.comunVolver) { cerrar() }
                }
            }
        }
        .sheet(isPresented: $mostrandoSustitutos) {
            SustitutosView(original: ejercicio, catalogo: catalogo, alElegir: alElegir)
        }
    }

    private var principales: String {
        ejercicio.musculos.filter(\.esPrincipal).map { catalogo.musculo($0.id) }.joined(separator: ", ")
    }

    private var secundarios: String {
        ejercicio.musculos.filter { !$0.esPrincipal }.map { catalogo.musculo($0.id) }.joined(separator: ", ")
    }

    private func dato(_ etiqueta: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
            Text(etiqueta).estilo(.etiquetaSeccion, color: Paleta.textoTerciario)
            Text(valor).estilo(.opcionTitulo, color: Paleta.textoPrimario)
        }
        .padding(TokensEspaciado.e14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(radio: TokensRadio.boton)
    }
}

struct SustitutosView: View {
    let original: EjercicioDelCatalogo
    let catalogo: CatalogoDeEjercicios
    let alElegir: (EjercicioDelCatalogo) -> Void

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TokensEspaciado.e8) {
                    ForEach(original.sustitutos, id: \.id) { sustituto in
                        if let ejercicio = catalogo.ejercicio(sustituto.id) {
                            Button { alElegir(ejercicio) } label: {
                                VStack(alignment: .leading, spacing: TokensEspaciado.e3) {
                                    Text(catalogo.nombre(de: ejercicio)).estilo(.opcionTitulo)
                                    // El MOTIVO de cada sustituto, que es lo que
                                    // el diseño pide mostrar y no sólo el nombre.
                                    Text(motivo(sustituto.tipo))
                                        .estilo(.chip, color: Paleta.acento)
                                }
                                .padding(TokensEspaciado.e14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .tarjeta(radio: TokensRadio.boton)
                                .objetivoTactilAlto()
                            }
                            .buttonStyle(EstiloPresionado())
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(TokensEspaciado.e16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paleta.fondo)
            .navigationTitle(Textos.sustitutosTitulo(catalogo.nombre(de: original)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.comunVolver) { cerrar() }
                }
            }
        }
    }

    private func motivo(_ tipo: String) -> String {
        tipo == "mismo-patron" ? Textos.sustitutosMismoPatron : catalogo.patron(tipo)
    }
}
