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
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.prefix(2))) { item in
                boton(item)
            }
            // El hueco donde vive el botón flotante.
            //
            // 🪤 El `height` no es decorativo: `Color` es elástico en los DOS
            // ejes, así que sin alto fijo este hueco estira la barra entera
            // hasta ocupar la pantalla y deja al contenido con su altura ideal.
            // El fondo de la barra es casi negro, así que el síntoma no se ve:
            // parece que el contenido se cortó.
            Color.clear
                .frame(width: TokensEspaciado.e56 + TokensEspaciado.e20,
                       height: TokensEspaciado.e1)
            ForEach(Array(items.dropFirst(2))) { item in
                boton(item)
            }
        }
        .padding(.horizontal, TokensEspaciado.e10)
        .padding(.top, TokensEspaciado.e10)
        .padding(.bottom, TokensEspaciado.e22)
        .background(Paleta.fondoBarra)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Paleta.divisor)
                .frame(height: TokensEspaciado.e1)
        }
        .overlay(alignment: .top) { botonCentral }
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
            .frame(maxWidth: .infinity)
            .objetivoTactilAlto()
        }
        .buttonStyle(EstiloPresionado())
        .accessibilityLabel(item.titulo)
        .accessibilityAddTraits(activa ? [.isButton, .isSelected] : .isButton)
    }

    private var botonCentral: some View {
        Button(action: alTocarCentral) {
            VStack(spacing: TokensEspaciado.e4) {
                ZStack {
                    Circle().fill(Paleta.acento)
                    Circle().strokeBorder(Paleta.fondoBarra, lineWidth: TokensEspaciado.e4)
                    Image(systemName: central.simbolo)
                        .font(.system(size: TokensEspaciado.e26, weight: TokensTipografia.tituloCardPeso))
                        .foregroundStyle(Paleta.sobreAcento)
                }
                .frame(width: TokensTamano.objetivoTactilMinimo + TokensEspaciado.e14,
                       height: TokensTamano.objetivoTactilMinimo + TokensEspaciado.e14)

                Text(central.titulo)
                    .estilo(.etiquetaSeccion, color: elegida == central.id ? Paleta.pestanaActiva : Paleta.pestanaInactiva)
                    .textCase(nil)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPresionado())
        .offset(y: -TokensEspaciado.e26)
        .accessibilityLabel(central.titulo)
    }
}
