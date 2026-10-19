import SwiftUI

// =============================================================================
// La barra de pestañas del Home, con el botón flotante de Entreno.
//
// 🪤 Es una barra PROPIA, no un `TabView` del sistema, y conviene decir por qué:
// el diseño pone un botón circular de 62 pt que sobresale por arriba de la barra
// (`top:-24px`), y `TabView` no admite eso. Lo idiomático de iOS gana cuando
// empata (AGENTS.md §10), y acá no empata: el control central es la forma en que
// esta app empieza un entrenamiento.
//
// ESPECIFICACION §9.2 midió los ítems de esta barra en ~39 pt. Acá responden en
// 48 sin mover el dibujo: la barra ya tiene 22 pt de padding inferior donde el
// área crece sin desplazar nada.
// =============================================================================

public struct ItemDePestana: Identifiable, Sendable {
    public let id: String
    public let titulo: String
    public let simbolo: String

    public init(id: String, titulo: String, simbolo: String) {
        self.id = id
        self.titulo = titulo
        self.simbolo = simbolo
    }
}

public struct BarraDePestanas: View {
    private let items: [ItemDePestana]
    private let elegida: String
    private let central: ItemDePestana
    private let alElegir: (String) -> Void
    private let alTocarCentral: () -> Void

    /// - Parameters:
    ///   - items: los cuatro de los costados, dos y dos.
    ///   - central: el botón flotante, que va en el medio.
    public init(items: [ItemDePestana], elegida: String, central: ItemDePestana,
                alElegir: @escaping (String) -> Void, alTocarCentral: @escaping () -> Void) {
        self.items = items
        self.elegida = elegida
        self.central = central
        self.alElegir = alElegir
        self.alTocarCentral = alTocarCentral
    }

    public var body: some View {
        // Rediseño 2026-10: la barra FLOTA, como en el mockup. Es una cápsula
        // apoyada sobre el fondo, separada de los bordes, con el botón central
        // rosa sobresaliendo y con halo. El hueco de abajo sigue siendo zona
        // táctil (ver la nota de arriba sobre los 48 pt).
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(items.prefix(2))) { item in
                boton(item)
            }
            // El hueco donde vive el botón flotante.
            //
            // 🪤 El `height` no es decorativo: `Color` es elástico en los DOS
            // ejes, así que sin alto fijo este hueco estira la barra entera
            // hasta ocupar la pantalla y deja al contenido con su altura ideal.
            Color.clear
                .frame(width: TokensEspaciado.e56 + TokensEspaciado.e14,
                       height: TokensEspaciado.e1)
            ForEach(Array(items.dropFirst(2))) { item in
                boton(item)
            }
        }
        .padding(.horizontal, TokensEspaciado.e8)
        .padding(.vertical, TokensEspaciado.e6)
        .background(
            RoundedRectangle(cornerRadius: TokensRadio.cardDestacada + TokensEspaciado.e8, style: .continuous)
                .fill(Paleta.superficieBarra)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TokensRadio.cardDestacada + TokensEspaciado.e8, style: .continuous)
                .strokeBorder(Paleta.bordeSuperficie, lineWidth: TokensEspaciado.e1)
        )
        .overlay(alignment: .center) { botonCentral }
        .padding(.horizontal, TokensEspaciado.e16)
        .padding(.top, TokensEspaciado.e6)
        .padding(.bottom, TokensEspaciado.e6)
        .background(
            // Un degradado al fondo para que el contenido que pasa por detrás
            // de la barra no compita con ella.
            LinearGradient(colors: [Paleta.fondo.opacity(0), Paleta.fondo],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .bottom)
                .accessibilityHidden(true)
        )
    }

    private func boton(_ item: ItemDePestana) -> some View {
        let activa = item.id == elegida
        return Button { alElegir(item.id) } label: {
            VStack(spacing: TokensEspaciado.e5) {
                Image(systemName: item.simbolo)
                    .font(.system(size: TokensEspaciado.e20, weight: .regular))
                Text(item.titulo)
                    .estilo(.etiquetaSeccion, color: activa ? Paleta.pestanaActiva : Paleta.pestanaInactiva)
                    .textCase(nil)
            }
            .foregroundStyle(activa ? Paleta.pestanaActiva : Paleta.pestanaInactiva)
            .padding(.vertical, TokensEspaciado.e6)
            .frame(maxWidth: .infinity)
            .background {
                if activa {
                    RoundedRectangle(cornerRadius: TokensRadio.card, style: .continuous)
                        .fill(Paleta.acentoChipActivo)
                }
            }
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(item.titulo)
        .accessibilityAddTraits(activa ? [.isButton, .isSelected] : .isButton)
    }

    private var botonCentral: some View {
        Button(action: alTocarCentral) {
            ZStack {
                Circle()
                    .fill(Paleta.acento)
                    .shadow(color: Paleta.acentoBrillo, radius: TokensEspaciado.e16)
                Circle().strokeBorder(Paleta.fondo, lineWidth: TokensEspaciado.e4)
                Image(systemName: central.simbolo)
                    .font(.system(size: TokensEspaciado.e22, weight: .heavy))
                    .foregroundStyle(Paleta.sobreAcento)
            }
            .frame(width: TokensEspaciado.e56 + TokensEspaciado.e4,
                   height: TokensEspaciado.e56 + TokensEspaciado.e4)
            .contentShape(Circle())
        }
        .buttonStyle(EstiloPresionado())
        .offset(y: -TokensEspaciado.e16)
        .accessibilityLabel(central.titulo)
        .accessibilityAddTraits(elegida == central.id ? [.isButton, .isSelected] : .isButton)
    }
}
