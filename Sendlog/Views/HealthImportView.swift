import SwiftData
import SwiftUI

/// Lists recent Apple Health workouts so one can be imported as a new session or linked to an existing one.
struct HealthImportView: View {
    let onSelect: (WatchWorkout) -> Void

    @Environment(HealthKitManager.self) private var health
    @Environment(\.dismiss) private var dismiss
    @Query private var healthData: [WorkoutHealthData]
    @State private var workouts: [WatchWorkout] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Treinos do Apple Watch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if !health.isAvailable {
            ContentUnavailableView("Dados de saúde indisponíveis", systemImage: "heart.slash", description: Text("Este aparelho não é compatível com o app Saúde."))
        } else if isLoading {
            ProgressView()
        } else if let errorMessage {
            ContentUnavailableView("Não foi possível carregar os treinos", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
        } else if workouts.isEmpty {
            ContentUnavailableView(
                "Nenhum treino encontrado",
                systemImage: "applewatch",
                description: Text("Nenhum treino nos últimos 30 dias. Se esperava algum, permita o acesso em Ajustes › Saúde › Acesso a Dados e Dispositivos › Sendlog.")
            )
        } else {
            let importedIDs = Set(healthData.compactMap(\.healthWorkoutID))
            List(workouts) { workout in
                let isImported = importedIDs.contains(workout.id)
                Button {
                    onSelect(workout)
                    dismiss()
                } label: {
                    WatchWorkoutRow(workout: workout, isImported: isImported)
                }
                .disabled(isImported)
            }
        }
    }

    private func load() async {
        guard health.isAvailable else { return }
        do {
            workouts = try await health.recentWorkouts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct WatchWorkoutRow: View {
    let workout: WatchWorkout
    let isImported: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.suggestedKind.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName).font(.headline).foregroundStyle(.primary)
                Text(workout.start.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(details).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isImported {
                Text("Registrado").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var details: String {
        var parts = ["\(Int((workout.duration / 60).rounded())) min"]
        if let kcal = workout.activeEnergyKcal { parts.append("\(Int(kcal)) kcal") }
        if let bpm = workout.averageHeartRate { parts.append("\(Int(bpm)) bpm méd.") }
        return parts.joined(separator: " · ")
    }
}
