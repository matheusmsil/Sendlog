import Charts
import SwiftData
import SwiftUI

enum StatsRange: Int, CaseIterable, Identifiable {
    case month = 4, quarter = 12, half = 26, year = 52

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .month: "4S"
        case .quarter: "12S"
        case .half: "6M"
        case .year: "1A"
        }
    }
}

enum Dashboard: String, CaseIterable, Identifiable {
    case overview, climbing, load, strength

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Geral"
        case .climbing: "Escalada"
        case .load: "Carga"
        case .strength: "Força"
        }
    }
}

struct StatsView: View {
    @Query(filter: #Predicate<TrainingSession> { !$0.isTemplate }, sort: \TrainingSession.date)
    private var allSessions: [TrainingSession]
    @AppStorage("statsRange") private var range: StatsRange = .quarter
    @AppStorage("dashboard") private var dashboard: Dashboard = .overview

    var body: some View {
        let stats = TrainingStats(sessions: allSessions, weekCount: range.rawValue)

        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Picker("Painel", selection: $dashboard) {
                            ForEach(Dashboard.allCases) { Text($0.title).tag($0) }
                        }
                        Picker("Período", selection: $range) {
                            ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if stats.sessions.isEmpty {
                    ContentUnavailableView(
                        "Nada para mostrar ainda",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Registre treinos neste período e seu progresso aparece aqui.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    switch dashboard {
                    case .overview:
                        OverviewSection(stats: stats)
                        if stats.sessions.contains(where: { !$0.routineBlocks.isEmpty }) {
                            PrepStatsSection(stats: stats)
                        }
                    case .climbing:
                        ClimbingDashboard(stats: stats)
                    case .load:
                        LoadDashboard(stats: stats)
                    case .strength:
                        StrengthDashboard(stats: stats)
                    }
                }
            }
            .navigationTitle("Progresso")
        }
    }
}

// MARK: - Overview

private struct OverviewSection: View {
    let stats: TrainingStats
    @State private var selection: Date?

    var body: some View {
        Section("Visão geral") {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(stats.sessions.count)").font(.system(size: 52, weight: .bold))
                Text("treinos nas últimas \(stats.weeks.count) semanas").foregroundStyle(.secondary)
            }

            HStack {
                StatTile(value: Self.formatMinutes(stats.totalMinutes), label: "Tempo de treino")
                StatTile(value: "\(stats.weekStreak) sem", label: "Sequência")
                StatTile(value: stats.averageEffort.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "–", label: "PSE média")
            }

            sessionsChart
        }
    }

    private var sessionsChart: some View {
        let selectedWeek = selection.map(stats.week(of:))
        let kinds = SessionKind.allCases

        return VStack(alignment: .leading, spacing: 10) {
            ChartHeader(title: "Treinos por semana", detail: detail(for: selectedWeek))
            Chart {
                ForEach(stats.sessionsPerWeek) { item in
                    BarMark(x: .value("Semana", item.week, unit: .weekOfYear), y: .value("Treinos", item.count), width: stats.barWidth)
                        .foregroundStyle(by: .value("Tipo", item.kind.title))
                        .opacity(selectedWeek == nil || selectedWeek == item.week ? 1 : 0.35)
                }
            }
            // A fixed domain keeps each type's color the same even when one has no sessions.
            .chartForegroundStyleScale(domain: kinds.map(\.title), range: kinds.map(\.chartColor))
            .chartXSelection(value: $selection)
            .weekAxis(stats)
            .frame(height: 180)
        }
        .padding(.vertical, 6)
    }

    private func detail(for week: Date?) -> String {
        guard let week else { return "Toque numa barra para ver detalhes" }
        let counts = stats.sessionsPerWeek.filter { $0.week == week && $0.count > 0 }
        let parts = counts.map { "\($0.count) \($0.kind.title.lowercased())" }
        return "Semana de \(week.formatted(.dateTime.day().month())): " + (parts.isEmpty ? "nenhum treino" : parts.joined(separator: ", "))
    }

    static func formatMinutes(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Activation & mobility

private struct PrepStatsSection: View {
    let stats: TrainingStats

    var body: some View {
        Section("Ativação e mobilidade") {
            HStack {
                ForEach(RoutineKind.allCases) { kind in
                    StatTile(value: "\(stats.sessionCount(with: kind)) de \(stats.sessions.count)", label: "Treinos com \(kind.title.lowercased())")
                }
            }

            WeeklyBarChart(
                title: "Treinos com ativação ou mobilidade",
                stats: stats,
                values: stats.prepSessionsPerWeek,
                color: ChartPalette.prep,
                format: { "\(Int($0)) treinos" }
            )
        }
    }
}
