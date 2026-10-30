import Charts
import SwiftUI

/// Grade progression, pyramid, style weaknesses and projects.
struct ClimbingDashboard: View {
    let stats: TrainingStats

    var body: some View {
        let climbing = ClimbingAnalytics(stats: stats)

        if climbing.isEmpty {
            ContentUnavailableView(
                "Nenhuma escalada neste período",
                systemImage: "figure.climbing",
                description: Text("Registre treinos de escalada com o grau dos boulders para ver sua pirâmide, evolução e pontos fracos.")
            )
            .listRowBackground(Color.clear)
        } else {
            PerformanceSection(climbing: climbing, stats: stats)
            PyramidSection(climbing: climbing)
            ProgressionSection(climbing: climbing, stats: stats)
            StyleSection(climbing: climbing)
            ProjectsSection(climbing: climbing)
        }
    }
}

// MARK: - Performance

private struct PerformanceSection: View {
    let climbing: ClimbingAnalytics
    let stats: TrainingStats

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text(climbing.maxGrade.map(Grade.label) ?? "–").font(.system(size: 52, weight: .bold))
                Text("maior grau mandado").foregroundStyle(.secondary)
                if let comparison {
                    Label(comparison.text, systemImage: comparison.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            HStack {
                StatTile(value: climbing.flashGrade.map(Grade.label) ?? "–", label: "Grau de flash")
                StatTile(value: climbing.consolidatedGrade.map(Grade.label) ?? "–", label: "Consolidado")
                StatTile(value: climbing.sendRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–", label: "Aproveitamento")
            }

            WeeklyBarChart(
                title: "Subidas por semana",
                stats: stats,
                values: stats.ascentsPerWeek,
                color: ChartPalette.climbing,
                format: { "\(Int($0)) subidas" }
            )
        } header: {
            Text("Desempenho")
        } footer: {
            Text("Consolidado é o maior grau que você mandou \(ClimbingAnalytics.consolidationSends) ou mais vezes. O grau de flash conta boulders mandados de primeira.")
        }
    }

    private var comparison: (text: String, icon: String)? {
        guard let current = climbing.maxGrade else { return nil }
        let period = "as \(stats.weeks.count) semanas anteriores"
        guard let previous = climbing.previousMaxGrade else { return ("Sem boulders com grau nas \(stats.weeks.count) semanas anteriores para comparar", "minus") }
        let difference = current - previous
        switch difference {
        case 1...: return ("\(difference) grau\(difference == 1 ? "" : "s") acima d\(period) (\(Grade.label(previous)))", "arrow.up.right")
        case 0: return ("Igual às \(stats.weeks.count) semanas anteriores", "equal")
        default: return ("\(-difference) grau\(difference == -1 ? "" : "s") abaixo d\(period) (\(Grade.label(previous)))", "arrow.down.right")
        }
    }
}

// MARK: - Pyramid

private struct PyramidSection: View {
    let climbing: ClimbingAnalytics
    @State private var selection: String?

    var body: some View {
        let pyramid = climbing.pyramid
        let grades = Array(NSOrderedSet(array: pyramid.map { Grade.label($0.grade) })) as? [String] ?? []
        let totals = Dictionary(grouping: pyramid) { Grade.label($0.grade) }.mapValues { $0.reduce(0) { $0 + $1.count } }

        if !pyramid.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    ChartHeader(title: "Pirâmide de graus", detail: detail(pyramid))
                    Chart(pyramid) { item in
                        let label = Grade.label(item.grade)
                        BarMark(x: .value("Mandados", item.count), y: .value("Grau", label), height: .fixed(18))
                            .foregroundStyle(by: .value("Tipo", item.kind.rawValue))
                            .opacity(selection == nil || selection == label ? 1 : 0.35)
                            .annotation(position: .trailing, alignment: .leading) {
                                if item.kind == .worked {
                                    Text("\(totals[label] ?? 0)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                    }
                    .chartForegroundStyleScale(domain: [GradeCount.Kind.flash.rawValue, GradeCount.Kind.worked.rawValue],
                                               range: [ChartPalette.flash, ChartPalette.climbing])
                    .chartYScale(domain: grades)
                    .chartYAxis { AxisMarks(preset: .aligned, position: .leading) { _ in AxisValueLabel(centered: true) } }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartYSelection(value: $selection)
                    .frame(height: CGFloat(grades.count) * 30 + 50)
                }
                .padding(.vertical, 6)

                if let advice = pyramidAdvice {
                    Label(advice, systemImage: "lightbulb")
                        .font(.subheadline)
                }
            } header: {
                Text("Pirâmide")
            } footer: {
                Text("Uma pirâmide sólida tem mais boulders mandados em cada grau abaixo do seu máximo. Uma base estreita costuma indicar que você está forçando graus antes de consolidá-los.")
            }
        }
    }

    private func detail(_ pyramid: [GradeCount]) -> String {
        guard let selection else { return "Mandados por grau · toque num grau para ver detalhes" }
        let atGrade = pyramid.filter { Grade.label($0.grade) == selection }
        let flashes = atGrade.first { $0.kind == .flash }?.count ?? 0
        let worked = atGrade.first { $0.kind == .worked }?.count ?? 0
        return "\(selection): \(flashes) de flash, \(worked) trabalhado\(worked == 1 ? "" : "s")"
    }

    /// Compares the top of the pyramid with the grade just below it.
    private var pyramidAdvice: String? {
        guard let max = climbing.maxGrade else { return nil }
        let sends = climbing.sends.compactMap(\.grade)
        let top = sends.filter { $0 == max }.count
        let below = sends.filter { $0 == max - 1 }.count
        if below < top * 2 {
            return "Só \(below) mandado\(below == 1 ? "" : "s") em \(Grade.label(max - 1)) abaixo dos seus \(top) em \(Grade.label(max)). Consolide \(Grade.label(max - 1)) em estilos diferentes antes de subir de grau."
        }
        return "Boa base: \(below) mandados em \(Grade.label(max - 1)) sustentam seus \(top) em \(Grade.label(max)). Você está pronto para projetar \(Grade.label(max + 1))."
    }
}

// MARK: - Progression

private struct ProgressionSection: View {
    let climbing: ClimbingAnalytics
    let stats: TrainingStats
    @State private var selection: Date?
    @State private var attemptsSelection: String?

    var body: some View {
        let trend = climbing.gradeTrend
        let attempts = climbing.attemptsByGrade

        if !trend.isEmpty || !attempts.isEmpty {
            Section {
                if !trend.isEmpty { trendChart(trend) }
                if !attempts.isEmpty { attemptsChart(attempts) }
            } header: {
                Text("Evolução")
            } footer: {
                Text("Típico é o grau mediano que você mandou na semana. Quando ele sobe, sua base está ficando mais forte, não só o seu melhor dia.")
            }
        }
    }

    private func trendChart(_ trend: [GradeTrendPoint]) -> some View {
        let selectedWeek = selection.map(stats.week(of:))
        let selected = trend.filter { $0.week == selectedWeek }
        let series = [GradeTrendPoint.Series.hardest, .typical]

        return VStack(alignment: .leading, spacing: 10) {
            ChartHeader(
                title: "Evolução de grau",
                detail: selected.isEmpty
                    ? "Toque numa semana para ver detalhes"
                    : "Semana de \(selectedWeek!.formatted(.dateTime.day().month())): " + selected.map { "\($0.series.rawValue.lowercased()) \(Grade.label(Int($0.grade.rounded(.down))))" }.joined(separator: ", ")
            )
            Chart(trend) { point in
                LineMark(x: .value("Semana", point.week, unit: .weekOfYear), y: .value("Grau", point.grade))
                    .foregroundStyle(by: .value("Série", point.series.rawValue))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Semana", point.week, unit: .weekOfYear), y: .value("Grau", point.grade))
                    .foregroundStyle(by: .value("Série", point.series.rawValue))
                    .symbolSize(selectedWeek == point.week ? 110 : 60)
            }
            .chartForegroundStyleScale(domain: series.map(\.rawValue), range: [ChartPalette.climbing, ChartPalette.reference])
            .chartXSelection(value: $selection)
            .gradeAxis(trend.map(\.grade))
            .weekAxis(stats)
            .frame(height: 180)
        }
        .padding(.vertical, 6)
    }

    private func attemptsChart(_ attempts: [GradeAttempts]) -> some View {
        let selected = attempts.first { Grade.label($0.grade) == attemptsSelection }

        return VStack(alignment: .leading, spacing: 10) {
            ChartHeader(
                title: "Entradas até mandar (boulder máximo)",
                detail: selected.map { "\(Grade.label($0.grade)): média de \($0.averageAttempts.formatted(.number.precision(.fractionLength(1)))) entradas em \($0.sends) boulder\($0.sends == 1 ? "" : "s") mandado\($0.sends == 1 ? "" : "s")" }
                    ?? "Média de entradas por boulder mandado · toque numa barra"
            )
            Chart(attempts) { item in
                BarMark(x: .value("Grau", Grade.label(item.grade)), y: .value("Entradas", item.averageAttempts), width: .fixed(24))
                    .foregroundStyle(ChartPalette.climbing.opacity(selected == nil || selected?.grade == item.grade ? 1 : 0.35))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text(item.averageAttempts.formatted(.number.precision(.fractionLength(1))))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXSelection(value: $attemptsSelection)
            .frame(height: 150)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Style & weaknesses

private struct StyleSection: View {
    let climbing: ClimbingAnalytics

    var body: some View {
        Section {
            if climbing.hasTags {
                if let focus = climbing.focusArea {
                    insight("Treinar a seguir: \(focus.label.lowercased())", "\(focus.rate.formatted(.percent.precision(.fractionLength(0)))) de aproveitamento em \(focus.tried) boulders", icon: "scope")
                }
                if let strength = climbing.strongestArea, strength.id != climbing.focusArea?.id {
                    insight("Ponto forte: \(strength.label.lowercased())", "\(strength.rate.formatted(.percent.precision(.fractionLength(0)))) de aproveitamento em \(strength.tried) boulders", icon: "star")
                }
                TagRateChart(title: "Aproveitamento por inclinação", stats: climbing.byAngle)
                TagRateChart(title: "Aproveitamento por tipo de agarra", stats: climbing.byHold)
            } else {
                Label("Marque a inclinação e as agarras dos boulders (botão de etiqueta ao lado do grau) para descobrir seus pontos fortes e fracos.", systemImage: "tag")
                    .font(.subheadline)
            }
        } header: {
            Text("Estilo")
        } footer: {
            if let floor = climbing.climbsAtYourLevel.floor {
                Text("O aproveitamento usa boulders a partir de \(Grade.label(floor)), perto do seu limite, para o aquecimento não distorcer.")
            } else {
                Text("O aproveitamento usa todos os boulders do período.")
            }
        }
    }

    private func insight(_ title: String, _ detail: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(.tint)
        }
    }
}

private struct TagRateChart: View {
    let title: String
    let stats: [TagStat]

    var body: some View {
        if !stats.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ChartHeader(title: title, detail: "Parte dos boulders tentados que você mandou")
                Chart(stats) { stat in
                    BarMark(x: .value("Aproveitamento", stat.rate * 100), y: .value("Etiqueta", stat.label), height: .fixed(18))
                        .foregroundStyle(ChartPalette.climbing)
                        .cornerRadius(4)
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("\(Int((stat.rate * 100).rounded()))% · \(stat.sent)/\(stat.tried)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                }
                .chartXScale(domain: 0...125)
                .chartYAxis { AxisMarks(preset: .aligned, position: .leading) { _ in AxisValueLabel(centered: true) } }
                .chartXAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    }
                }
                .frame(height: CGFloat(stats.count) * 30 + 30)
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Projects

private struct ProjectsSection: View {
    let climbing: ClimbingAnalytics

    var body: some View {
        let projects = climbing.projects.prefix(8)

        if !projects.isEmpty {
            Section {
                ForEach(projects) { project in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name).font(.headline)
                            Text("\(project.attempts) entradas · \(project.sessions) treino\(project.sessions == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(project.gradeText.isEmpty ? "–" : project.gradeText).font(.headline)
                            if let sent = project.sentDate {
                                Label("Mandou em \(sent.formatted(.dateTime.day().month()))", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Tentado \(project.lastTried.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Projetos")
            } footer: {
                Text("Projetos são boulders com nome nos blocos de Boulder máximo, em todo o seu histórico. Use o mesmo nome em cada treino para acompanhar.")
            }
        }
    }
}
