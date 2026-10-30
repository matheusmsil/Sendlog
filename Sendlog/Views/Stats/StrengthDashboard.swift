import Charts
import SwiftUI

/// Per-exercise lifting progress plus finger and pulling strength relative to bodyweight.
struct StrengthDashboard: View {
    let stats: TrainingStats

    var body: some View {
        FingerStrengthSection(stats: stats)
        if !stats.exerciseNames.isEmpty {
            StrengthStatsSection(stats: stats)
        }
    }
}

// MARK: - Fingers & pulling

private struct FingerStrengthSection: View {
    let stats: TrainingStats
    @AppStorage("bodyWeightKg") private var bodyWeight: Double = 0
    @Environment(HealthKitManager.self) private var health
    @State private var selection: Date?

    var body: some View {
        let points = stats.strengthToWeight(bodyWeight: bodyWeight)

        Section {
            LabeledContent("Peso corporal") {
                HStack {
                    TextField("0", value: $bodyWeight, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                    Text("kg").foregroundStyle(.secondary)
                    if health.isAvailable {
                        Button {
                            Task {
                                if let kg = try? await health.latestBodyMass() { bodyWeight = (kg * 10).rounded() / 10 }
                            }
                        } label: {
                            Image(systemName: "heart.text.square").accessibilityLabel("Usar peso do app Saúde")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            if bodyWeight <= 0 {
                Text("Informe seu peso corporal para ver a força relativa.").foregroundStyle(.secondary)
            } else if points.isEmpty {
                Label("Registre um exercício chamado \"Hangboard\" (carga adicional na sua régua de teste) ou \"Barra Fixa com Carga\" (carga adicional) para acompanhar a força de dedos e de puxada.", systemImage: "hand.raised")
                    .font(.subheadline)
            } else {
                HStack {
                    ForEach(TrainingStats.strengthToWeightSeries, id: \.0) { series, _ in
                        StatTile(value: best(series, in: points).map { "\(Int($0.rounded()))%" } ?? "–", label: "Melhor \(series.lowercased())")
                    }
                }
                chart(points)
            }
        } header: {
            Text("Dedos e puxada")
        } footer: {
            Text("Força relativa = (peso corporal + carga adicional) ÷ peso corporal. Suspensões costumam ser testadas por 7–10 segundos numa régua de 20 mm; mantenha a mesma régua e o mesmo tempo para comparar os treinos.")
        }
    }

    private func best(_ series: String, in points: [StrengthToWeightPoint]) -> Double? {
        points.filter { $0.series == series }.map(\.percent).max()
    }

    private func chart(_ points: [StrengthToWeightPoint]) -> some View {
        let names = TrainingStats.strengthToWeightSeries.map(\.0)
        let selectedDay = selection.flatMap { date in points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?.date }
        let selected = points.filter { $0.date == selectedDay }

        return VStack(alignment: .leading, spacing: 10) {
            ChartHeader(
                title: "Força relativa (% do peso corporal)",
                detail: selected.isEmpty
                    ? "Toque num ponto para ver detalhes"
                    : "\(selectedDay!.formatted(.dateTime.day().month())): " + selected.map { "\($0.series.lowercased()) \(Int($0.percent.rounded()))% (+\($0.added.formatted()) kg)" }.joined(separator: ", ")
            )
            Chart(points) { point in
                LineMark(x: .value("Data", point.date, unit: .day), y: .value("% do peso corporal", point.percent))
                    .foregroundStyle(by: .value("Exercício", point.series))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Data", point.date, unit: .day), y: .value("% do peso corporal", point.percent))
                    .foregroundStyle(by: .value("Exercício", point.series))
                    .symbolSize(point.date == selectedDay ? 110 : 60)
            }
            // Fingers are climbing-specific (blue); pulling is general strength (orange).
            .chartForegroundStyleScale(domain: names, range: [ChartPalette.climbing, ChartPalette.strength])
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXSelection(value: $selection)
            .weekAxis(stats)
            .frame(height: 180)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Strength

private struct StrengthStatsSection: View {
    let stats: TrainingStats
    @State private var chosenExercise: String?
    @State private var weightSelection: Date?
    @State private var volumeSelection: Date?

    var body: some View {
        let names = stats.exerciseNames
        let exercise = chosenExercise.flatMap { names.contains($0) ? $0 : nil } ?? names[0]
        let points = stats.progress(for: exercise)
        let best = stats.personalBest(for: exercise)

        Section {
            Picker("Exercício", selection: Binding(get: { exercise }, set: { chosenExercise = $0 })) {
                ForEach(names, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            HStack {
                StatTile(value: best.map { "\(Self.kg($0.weight)) × \($0.reps)" } ?? "–", label: "Melhor série")
                StatTile(value: stats.bestEstimatedOneRepMax(for: exercise).map(Self.kg) ?? "–", label: "1RM estimado")
                StatTile(value: "\(points.count)", label: "Treinos")
            }

            weightChart(points)
            volumeChart(points)
        } header: {
            Text("Força")
        } footer: {
            Text("Melhor série e 1RM estimado (fórmula de Epley) consideram todo o seu histórico.")
        }
    }

    private func nearest(_ date: Date?, in points: [ExercisePoint]) -> ExercisePoint? {
        guard let date else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func weightChart(_ points: [ExercisePoint]) -> some View {
        let selected = nearest(weightSelection, in: points)

        return VStack(alignment: .leading, spacing: 10) {
            ChartHeader(
                title: "Série mais pesada (kg)",
                detail: selected.map { "\($0.date.formatted(.dateTime.day().month())): \(Self.kg($0.topWeight))" }
                    ?? "Toque num ponto para ver detalhes"
            )
            Chart(points) { point in
                LineMark(x: .value("Data", point.date, unit: .day), y: .value("Carga", point.topWeight))
                    .foregroundStyle(ChartPalette.strength)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Data", point.date, unit: .day), y: .value("Carga", point.topWeight))
                    .symbol {
                        Circle()
                            .fill(ChartPalette.strength)
                            .frame(width: selected?.date == point.date ? 12 : 9)
                            .overlay(Circle().stroke(ChartPalette.surface, lineWidth: 2))
                    }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXSelection(value: $weightSelection)
            .weekAxis(stats)
            .frame(height: 160)
        }
        .padding(.vertical, 6)
    }

    private func volumeChart(_ points: [ExercisePoint]) -> some View {
        let selected = nearest(volumeSelection, in: points)

        return VStack(alignment: .leading, spacing: 10) {
            ChartHeader(
                title: "Volume por treino (kg × reps)",
                detail: selected.map { "\($0.date.formatted(.dateTime.day().month())): \(Self.kg($0.volume))" }
                    ?? "Toque numa barra para ver detalhes"
            )
            Chart(points) { point in
                BarMark(x: .value("Data", point.date, unit: .day), y: .value("Volume", point.volume), width: .fixed(min(24, 200 / CGFloat(max(points.count, 4)))))
                    .foregroundStyle(ChartPalette.strength.opacity(selected == nil || selected?.date == point.date ? 1 : 0.35))
                    .cornerRadius(4)
            }
            .chartXSelection(value: $volumeSelection)
            .weekAxis(stats)
            .frame(height: 140)
        }
        .padding(.vertical, 6)
    }

    static func kg(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}

