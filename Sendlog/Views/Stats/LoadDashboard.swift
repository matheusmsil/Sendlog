import Charts
import SwiftUI

/// Training load, injury-risk ratio and consistency.
struct LoadDashboard: View {
    let stats: TrainingStats

    var body: some View {
        let load = LoadAnalytics(stats: stats)

        LoadStatusSection(load: load, stats: stats)
        RatioSection(load: load, stats: stats)
        ConsistencySection(load: load, stats: stats)
    }
}

extension LoadZone {
    var color: Color {
        switch self {
        case .low: ChartPalette.reference
        case .sweetSpot: ChartPalette.good
        case .caution: ChartPalette.warning
        case .danger: ChartPalette.critical
        }
    }
}

// MARK: - Status & weekly load

private struct LoadStatusSection: View {
    let load: LoadAnalytics
    let stats: TrainingStats
    @State private var selection: Date?

    var body: some View {
        Section {
            if let ratio = load.currentRatio {
                let zone = LoadZone(ratio: ratio)
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(zone.title) · \(ratio.formatted(.number.precision(.fractionLength(2))))").font(.headline)
                        Text(zone.advice).font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: zone.systemImage).foregroundStyle(zone.color).font(.title2)
                }
                .padding(.vertical, 4)
            } else {
                Label("Registre a duração e o esforço (PSE) dos treinos para calcular a carga.", systemImage: "info.circle")
                    .font(.subheadline)
            }

            HStack {
                StatTile(value: "\(load.trainingDays)", label: "Dias de treino")
                StatTile(value: "\(load.restDays)", label: "Dias de descanso")
                StatTile(value: load.totalLoad.formatted(.number.notation(.compactName)), label: "Carga total")
            }

            weeklyChart
        } header: {
            Text("Carga de treino")
        } footer: {
            let missing = load.sessionsMissingLoad
            Text("Carga = esforço (PSE 1–10) × minutos, uma forma padrão de comparar escalada, musculação e o resto."
                + (missing > 0 ? " \(missing) treino\(missing == 1 ? "" : "s") sem duração ou esforço conta\(missing == 1 ? "" : "m") como zero." : ""))
        }
    }

    private var weeklyChart: some View {
        let weekly = load.weeklyLoad
        let selectedWeek = selection.map(stats.week(of:))
        let kinds = SessionKind.allCases

        return VStack(alignment: .leading, spacing: 10) {
            ChartHeader(title: "Carga por semana", detail: {
                guard let selectedWeek else { return "Toque numa barra para ver detalhes" }
                let parts = weekly.filter { $0.week == selectedWeek && $0.load > 0 }.map { "\($0.kind.title.lowercased()) \(Int($0.load))" }
                return "Semana de \(selectedWeek.formatted(.dateTime.day().month())): " + (parts.isEmpty ? "sem carga" : parts.joined(separator: ", "))
            }())
            Chart(weekly) { item in
                BarMark(x: .value("Semana", item.week, unit: .weekOfYear), y: .value("Carga", item.load), width: stats.barWidth)
                    .foregroundStyle(by: .value("Tipo", item.kind.title))
                    .opacity(selectedWeek == nil || selectedWeek == item.week ? 1 : 0.35)
            }
            .chartForegroundStyleScale(domain: kinds.map(\.title), range: kinds.map(\.chartColor))
            .chartXSelection(value: $selection)
            .weekAxis(stats)
            .frame(height: 180)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Acute:chronic ratio

private struct RatioSection: View {
    let load: LoadAnalytics
    let stats: TrainingStats
    @State private var selection: Date?

    var body: some View {
        let series = load.ratioSeries

        if series.count > 1, let first = series.first?.day, let last = series.last?.day {
            let high = max(2, (series.map(\.value).max() ?? 0) + 0.2)
            let selected = selection.flatMap { date in series.min { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) } }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    ChartHeader(
                        title: "Carga aguda : crônica",
                        detail: selected.map { "\($0.day.formatted(.dateTime.weekday(.abbreviated).day().month())): \($0.value.formatted(.number.precision(.fractionLength(2)))) · \(LoadZone(ratio: $0.value).title)" }
                            ?? "Últimos 7 dias vs. sua média de 4 semanas · toque para detalhes"
                    )
                    Chart {
                        RectangleMark(xStart: .value("Início", first), xEnd: .value("Fim", last), yStart: .value("Mínimo", 0.8), yEnd: .value("Máximo", 1.3))
                            .foregroundStyle(ChartPalette.good.opacity(0.15))
                        RuleMark(y: .value("Risco", 1.5))
                            .foregroundStyle(ChartPalette.critical.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        ForEach(series) { point in
                            LineMark(x: .value("Dia", point.day, unit: .day), y: .value("Razão", point.value))
                                .foregroundStyle(Color.primary)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                        }
                        if let selected {
                            PointMark(x: .value("Dia", selected.day, unit: .day), y: .value("Razão", selected.value))
                                .symbol {
                                    Circle()
                                        .fill(LoadZone(ratio: selected.value).color)
                                        .frame(width: 10)
                                        .overlay(Circle().stroke(ChartPalette.surface, lineWidth: 2))
                                }
                        }
                    }
                    .chartYScale(domain: 0...high)
                    .chartXSelection(value: $selection)
                    .weekAxis(stats)
                    .frame(height: 190)

                    HStack(spacing: 16) {
                        Label {
                            Text("Zona ideal 0,8–1,3")
                        } icon: {
                            RoundedRectangle(cornerRadius: 2).fill(ChartPalette.good.opacity(0.3)).frame(width: 14, height: 10)
                        }
                        Label {
                            Text("Risco de lesão 1,5+")
                        } icon: {
                            Rectangle().fill(ChartPalette.critical.opacity(0.7)).frame(width: 14, height: 1.5)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } footer: {
                Text("Ficar entre 0,8 e 1,3 significa que você está aumentando a carga aos poucos. Picos acima de 1,5 estão ligados a maior risco de lesão, principalmente nos dedos. É uma referência geral, não um diagnóstico.")
            }
        }
    }
}

// MARK: - Consistency calendar

private struct ConsistencySection: View {
    let load: LoadAnalytics
    let stats: TrainingStats
    @State private var weekSelection: Date?
    @State private var daySelection: String?

    var body: some View {
        let cells = load.calendarCells
        let symbols = Self.weekdaySymbols(stats.calendar)
        let selected = weekSelection.flatMap { date -> CalendarCell? in
            let week = stats.week(of: date)
            return cells.first { $0.week == week && symbols[$0.weekdayIndex - 1] == daySelection }
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                ChartHeader(
                    title: "Calendário de treinos",
                    detail: selected.map { "\($0.day.formatted(.dateTime.weekday(.wide).day().month())): " + ($0.level == 0 ? "descanso" : "carga \(Int($0.load))") }
                        ?? "Cada quadrado é um dia · toque para detalhes"
                )
                Chart(cells) { cell in
                    RectangleMark(
                        x: .value("Semana", cell.week, unit: .weekOfYear),
                        y: .value("Dia", symbols[cell.weekdayIndex - 1]),
                        width: .ratio(0.8),
                        height: .fixed(18)
                    )
                    .foregroundStyle(cell.level == 0 ? ChartPalette.rest : ChartPalette.loadLevels[cell.level - 1])
                    .cornerRadius(3)
                    .opacity(selected == nil || selected?.day == cell.day ? 1 : 0.5)
                }
                .chartYScale(domain: symbols)
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) { _ in AxisValueLabel(centered: true) }
                }
                .chartXSelection(value: $weekSelection)
                .chartYSelection(value: $daySelection)
                .weekAxis(stats)
                .frame(height: 200)

                legend
            }
            .padding(.vertical, 6)
        } header: {
            Text("Constância")
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Descanso").font(.caption2).foregroundStyle(.secondary)
            swatch(ChartPalette.rest)
            Text("Menos").font(.caption2).foregroundStyle(.secondary).padding(.leading, 8)
            ForEach(ChartPalette.loadLevels.indices, id: \.self) { swatch(ChartPalette.loadLevels[$0]) }
            Text("Mais").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
    }

    /// Weekday initials ordered from the calendar's first weekday.
    static func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}
