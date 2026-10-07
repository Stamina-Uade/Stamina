import SwiftUI
import TrainerCore

/// Registro manual: los valores vienen de la persona y se guardan con
/// `PUT /meals/{id}`. No hay reconocimiento de foto ni comida inventada.
struct RegistrarComidaView: View {
    @EnvironmentObject private var estado: EstadoHome
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var kcal = ""
    @State private var carbohidratos = ""
    @State private var proteina = ""
    @State private var grasa = ""

    private var nombreLimpio: String { nombre.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var valores: (Int, Int, Int, Int)? {
        guard !nombreLimpio.isEmpty, nombreLimpio.count <= 120,
              let energia = Int(kcal), (0...5000).contains(energia),
              let carbos = Int(carbohidratos), (0...1000).contains(carbos),
              let prot = Int(proteina), (0...1000).contains(prot),
              let fat = Int(grasa), (0...1000).contains(fat) else { return nil }
        return (energia, carbos, prot, fat)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TokensEspaciado.e16) {
                    Text(Textos.logManualDetalle)
                        .estilo(.cuerpoSecundario, color: Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)

                    CampoTexto(etiqueta: Textos.logNombre, marcador: Textos.logNombre,
                               texto: $nombre)
                    CampoTexto(etiqueta: "kcal", marcador: "0", texto: $kcal, teclado: .decimal)
                    CampoTexto(etiqueta: Textos.nutricionCarbos + " (g)", marcador: "0",
                               texto: $carbohidratos, teclado: .decimal)
                    CampoTexto(etiqueta: Textos.nutricionProteina + " (g)", marcador: "0",
                               texto: $proteina, teclado: .decimal)
                    CampoTexto(etiqueta: Textos.nutricionGrasa + " (g)", marcador: "0",
                               texto: $grasa, teclado: .decimal)

                    BotonPrimario(Textos.logGuardar, habilitado: valores != nil,
                                  motivoDeshabilitado: Textos.logManualIncompleta) {
                        guardar()
                    }
                }
                .padding(.horizontal, TokensEspaciado.e16)
                .padding(.vertical, TokensEspaciado.e16)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paleta.fondo)
            .navigationTitle(Textos.logTitulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.comunCancelar) { cerrar() }
                }
            }
        }
    }

    private func guardar() {
        guard let (energia, carbos, prot, fat) = valores else { return }
        let ahora = Calendar.current.dateComponents([.hour, .minute], from: Date())
        estado.agregar(Comida(minutoDelDia: (ahora.hour ?? 0) * 60 + (ahora.minute ?? 0),
                             nombre: nombreLimpio, kcal: energia, carbohidratosG: carbos,
                             proteinaG: prot, grasaG: fat))
        cerrar()
    }
}
