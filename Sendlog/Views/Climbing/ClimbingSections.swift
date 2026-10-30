import SwiftData
import SwiftUI

/// The Form sections for logging a climbing session: one section per block (e.g. "Repetições · Um pé só").
struct ClimbingSections: View {
    @Bindable var session: TrainingSession
    @Environment(\.modelContext) private var context
    @State private var showingSetup = false

    var body: some View {
        ForEach(session.sortedBlocks) { block in
            ClimbingBlockSection(block: block) {
                session.climbingBlocks.removeAll { $0 == block }
                context.delete(block)
            }
        }

        Section {
            Button {
                showingSetup = true
            } label: {
                Label("Adicionar bloco de escalada", systemImage: "plus.circle.fill")
            }
            .sheet(isPresented: $showingSetup) {
                ClimbingBlockSetupView { style, variation, boulderCount, reps in
                    session.addClimbingBlock(style: style, variation: variation, boulderCount: boulderCount, repsPerBoulder: reps)
                }
            }
        } footer: {
            Text("Um bloco é uma parte do treino, como um circuito ou 5 boulders × 2 entradas com um pé só.")
        }
    }
}

private struct ClimbingBlockSection: View {
    @Bindable var block: ClimbingBlock
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            HStack {
                Text(block.title).font(.headline)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            if !block.notes.isEmpty {
                Label(block.notes, systemImage: "list.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if block.style != .projecting {
                Stepper(value: $block.repsPerBoulder, in: 1...20) {
                    Text("Cada boulder \(block.repsPerBoulder)×")
                }
            }

            ForEach(Array(block.sortedBoulders.enumerated()), id: \.element.id) { index, boulder in
                BoulderRow(number: index + 1, boulder: boulder, block: block)
            }
            .onDelete { offsets in
                let boulders = block.sortedBoulders
                for index in offsets {
                    block.boulders.removeAll { $0 == boulders[index] }
                    context.delete(boulders[index])
                }
            }

            Button {
                block.addBoulder()
            } label: {
                Label("Adicionar boulder", systemImage: "plus")
            }
        } footer: {
            if block.style == .projecting {
                let attempts = block.boulders.reduce(0) { $0 + $1.attempts }
                let sends = block.boulders.filter { $0.completedReps > 0 }.count
                Text("\(attempts) entradas · \(sends) mandado\(sends == 1 ? "" : "s")")
            } else {
                Text("\(block.completedAscents) de \(block.targetAscents) subidas feitas")
            }
        }
    }
}

private struct BoulderRow: View {
    let number: Int
    @Bindable var boulder: Boulder
    let block: ClimbingBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Boulder \(number)", text: $boulder.name)
                TextField("Grau", text: $boulder.grade)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .foregroundStyle(.secondary)
                BoulderTagMenu(boulder: boulder)
            }

            if !boulder.tagSummary.isEmpty {
                Text(boulder.tagSummary).font(.caption).foregroundStyle(.secondary)
            }

            if block.style == .projecting {
                Stepper("Entradas: \(boulder.attempts)", value: $boulder.attempts, in: 0...200)
                Toggle("Mandou", isOn: Binding(
                    get: { boulder.completedReps > 0 },
                    set: { boulder.completedReps = $0 ? 1 : 0 }
                ))
            } else {
                RepTracker(completed: $boulder.completedReps, target: block.repsPerBoulder)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Wall angle, hold types and flash, used by the style and weakness analysis.
private struct BoulderTagMenu: View {
    @Bindable var boulder: Boulder

    var body: some View {
        Menu {
            Picker("Inclinação", selection: $boulder.angle) {
                Text("Não definida").tag(WallAngle?.none)
                ForEach(WallAngle.allCases) { Text($0.title).tag(WallAngle?.some($0)) }
            }
            .pickerStyle(.menu)

            Section("Agarras") {
                ForEach(HoldType.allCases) { hold in
                    Toggle(hold.title, isOn: Binding(
                        get: { boulder.holdTypes.contains(hold) },
                        set: { isOn in
                            if isOn { boulder.holdTypes.insert(hold) } else { boulder.holdTypes.remove(hold) }
                        }
                    ))
                }
            }

            Toggle("Flash (mandou de primeira)", isOn: $boulder.flashed)
        } label: {
            Image(systemName: boulder.tagSummary.isEmpty ? "tag" : "tag.fill")
                .accessibilityLabel("Detalhes do boulder")
        }
        .menuActionDismissBehavior(.disabled)
        .buttonStyle(.borderless)
    }
}

/// One tappable circle per planned ascent. Tapping the last filled circle un-fills it.
private struct RepTracker: View {
    @Binding var completed: Int
    let target: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<target, id: \.self) { index in
                Button {
                    completed = completed == index + 1 ? index : index + 1
                } label: {
                    Image(systemName: index < completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(index < completed ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.borderless)
            }
            Spacer()
            Text("\(min(completed, target))/\(target)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
