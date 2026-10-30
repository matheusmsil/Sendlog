import SwiftUI

struct ClimbingBlockSetupView: View {
    let onCreate: (_ style: ClimbingStyle, _ variation: String, _ boulderCount: Int, _ repsPerBoulder: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var style: ClimbingStyle = .repeats
    @State private var variation = ""
    @State private var boulderCount = 5
    @State private var repsPerBoulder = ClimbingStyle.repeats.defaultRepsPerBoulder

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Formato", selection: $style) {
                        ForEach(ClimbingStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text(style.explanation)
                }

                Section("Variação") {
                    HStack {
                        TextField("Nenhuma", text: $variation)
                        Menu {
                            ForEach(ClimbingBlock.variationPresets, id: \.self) { preset in
                                Button(preset) { variation = preset }
                            }
                            Divider()
                            Button("Nenhuma") { variation = "" }
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }

                Section {
                    Stepper("Boulders: \(boulderCount)", value: $boulderCount, in: 1...40)
                    if style != .projecting {
                        Stepper("Entradas em cada: \(repsPerBoulder)", value: $repsPerBoulder, in: 1...20)
                    }
                } footer: {
                    if style != .projecting {
                        Text("\(boulderCount) × \(repsPerBoulder) = \(boulderCount * repsPerBoulder) subidas")
                    }
                }
            }
            .navigationTitle("Novo bloco de escalada")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: style) { _, newStyle in
                repsPerBoulder = newStyle.defaultRepsPerBoulder
                if newStyle == .projecting { boulderCount = 1 }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") {
                        onCreate(style, variation.trimmingCharacters(in: .whitespaces), boulderCount, repsPerBoulder)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
