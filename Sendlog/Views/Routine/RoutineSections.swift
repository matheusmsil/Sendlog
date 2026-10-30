import SwiftData
import SwiftUI

/// The Form sections for activation and mobility blocks, available in every session type.
struct RoutineSections: View {
    @Bindable var session: TrainingSession
    @Environment(\.modelContext) private var context

    var body: some View {
        ForEach(session.sortedRoutineBlocks) { block in
            RoutineBlockSection(block: block) {
                session.routineBlocks.removeAll { $0 == block }
                context.delete(block)
            }
        }
    }
}

/// Menu buttons for adding an activation or mobility block.
struct AddRoutineBlockButtons: View {
    let session: TrainingSession

    var body: some View {
        ForEach(RoutineKind.allCases) { kind in
            Button {
                session.addRoutineBlock(kind)
            } label: {
                Label("Adicionar bloco de \(kind.title.lowercased())", systemImage: kind.systemImage)
            }
        }
    }
}

private struct RoutineBlockSection: View {
    @Bindable var block: RoutineBlock
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context
    @State private var customName = ""
    @State private var showingCustomName = false

    var body: some View {
        Section {
            HStack {
                Label(block.kind.title, systemImage: block.kind.systemImage).font(.headline)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            ForEach(block.sortedItems) { item in
                RoutineItemRow(item: item)
            }
            .onDelete { offsets in
                let items = block.sortedItems
                for index in offsets {
                    block.items.removeAll { $0 == items[index] }
                    context.delete(items[index])
                }
            }

            Menu {
                ForEach(block.kind.presets, id: \.name) { preset in
                    Button(preset.name) { block.addItem(preset) }
                }
                Divider()
                Button("Outro…") { showingCustomName = true }
            } label: {
                Label("Adicionar exercício", systemImage: "plus")
            }
            .alert("Novo exercício de \(block.kind.title.lowercased())", isPresented: $showingCustomName) {
                TextField("Nome", text: $customName)
                Button("Adicionar") {
                    block.addItem(name: customName.trimmingCharacters(in: .whitespaces), measure: .reps, amount: 10)
                    customName = ""
                }
                Button("Cancelar", role: .cancel) { customName = "" }
            }
        } footer: {
            if !block.items.isEmpty {
                Text("\(block.completedCount) de \(block.items.count) feitos")
            }
        }
    }
}

private struct RoutineItemRow: View {
    @Bindable var item: RoutineItem
    @State private var editingLink = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    item.isDone.toggle()
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isDone ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.borderless)

                TextField("Exercício", text: $item.name)
                VideoButton(url: item.video, title: item.name)
            }

            if !item.prescription.isEmpty {
                Text(item.prescription).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Menu {
                    Picker("Séries", selection: $item.sets) {
                        ForEach(1...6, id: \.self) { Text("\($0) \($0 == 1 ? "série" : "séries")").tag($0) }
                    }
                    Picker("Medida", selection: $item.measure) {
                        ForEach(RoutineMeasure.allCases) { Text($0.title).tag($0) }
                    }
                    Button {
                        editingLink = true
                    } label: {
                        Label("Link do vídeo…", systemImage: "link")
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(item.sets) \(item.sets == 1 ? "série" : "séries")")
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                }
                .buttonStyle(.borderless)

                Stepper(value: $item.amount, in: 0...3600, step: item.measure.step) {
                    Text(item.measure.format(item.amount))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
        .videoLinkAlert(isPresented: $editingLink, link: $item.videoURL)
    }
}
