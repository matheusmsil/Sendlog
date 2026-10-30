import SwiftData
import SwiftUI

/// The Form sections for logging a strength session: one section per exercise, one row per set.
struct StrengthSections: View {
    @Bindable var session: TrainingSession
    @Environment(\.modelContext) private var context
    @State private var customName = ""
    @State private var showingCustomName = false

    var body: some View {
        ForEach(session.sortedExercises) { exercise in
            ExerciseSection(exercise: exercise) {
                session.exercises.removeAll { $0 == exercise }
                context.delete(exercise)
            }
        }

        Section {
            Menu {
                ForEach(StrengthExercise.presets, id: \.self) { name in
                    Button(name) { session.addExercise(named: name) }
                }
                Divider()
                Button("Outro…") { showingCustomName = true }
            } label: {
                Label("Adicionar exercício", systemImage: "plus.circle.fill")
            }
            .alert("Novo exercício", isPresented: $showingCustomName) {
                TextField("Nome", text: $customName)
                Button("Adicionar") {
                    session.addExercise(named: customName.trimmingCharacters(in: .whitespaces))
                    customName = ""
                }
                Button("Cancelar", role: .cancel) { customName = "" }
            }
        }
    }
}

private struct ExerciseSection: View {
    @Bindable var exercise: StrengthExercise
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context
    @State private var editingLink = false

    var body: some View {
        Section {
            HStack {
                TextField("Exercício", text: $exercise.name).font(.headline)
                VideoButton(url: exercise.video, title: exercise.name)
                Menu {
                    Button {
                        editingLink = true
                    } label: {
                        Label("Link do vídeo…", systemImage: "link")
                    }
                    Button("Apagar exercício", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("Mais opções")
                }
                .buttonStyle(.borderless)
            }

            if !exercise.prescription.isEmpty {
                Label(exercise.prescription, systemImage: "list.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(number: index + 1, set: set)
            }
            .onDelete { offsets in
                let sets = exercise.sortedSets
                for index in offsets {
                    exercise.sets.removeAll { $0 == sets[index] }
                    context.delete(sets[index])
                }
            }

            Button {
                exercise.addSet()
            } label: {
                Label("Adicionar série", systemImage: "plus")
            }
        } footer: {
            if !exercise.sets.isEmpty {
                Text("\(exercise.sets.count) séries · \(exercise.totalReps) reps · volume \(exercise.totalVolume.formatted(.number.precision(.fractionLength(0...1)))) kg")
            }
        }
        .videoLinkAlert(isPresented: $editingLink, link: $exercise.videoURL)
    }
}

private struct SetRow: View {
    let number: Int
    @Bindable var set: ExerciseSet

    var body: some View {
        HStack {
            Text("\(number)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .leading)

            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
            Text("kg").foregroundStyle(.secondary)

            Spacer()

            Stepper(value: $set.reps, in: 0...200) {
                Text("\(set.reps) reps")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
